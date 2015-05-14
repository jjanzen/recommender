/*
Written by Josh Janzen
SEIS 734-01 Spring 2015
*/

# NB ********************************

## step 1: pull out 1k test users
CREATE TABLE IF NOT EXISTS expp_team.million_train AS 
SELECT a.user, a.song, a.play_count
FROM expp_team.million_all a 
LEFT JOIN expp_team.million_test b 
ON a.user = b.user 
WHERE b.user is NULL;  

## step 2:  identified users also played same driver song, then increments the also played song +1 for each user
CREATE TABLE expp_team.million_train_nb AS 
SELECT a.song as driver_song_id, b.song as also_song_id,
count(b.play_count) as play_count
from (
select user, song, play_count
from expp_team.million_train) a 
join (
select user, song, play_count
from expp_team.million_train) b 
on a.user = b.user
where a.song != b.song
group by a.song, b.song
having play_count >=1; 

## step 3: total songs and count of users
CREATE TABLE expp_team.million_train_n AS 
select song, count(distinct user) as count_user
from expp_team.million_train
group by song; 

## step 4: play count threshold
set play_count_factor=0.1;
CREATE TABLE expp_team.million_train_nb_all AS 
select a.driver_song_id, a.also_song_id, a.play_count as both, b.count_user, c.count_n_users
,a.play_count/b.count_user as p_y
,(c.count_n_users-a.play_count)/c.count_n_users as p_n
,(a.play_count/b.count_user)/((c.count_n_users-a.play_count)/c.count_n_users) as adjust_p
from (select driver_song_id, also_song_id, play_count from expp_team.million_train_nb) as a 
join (select song, count_user from expp_team.million_train_n) as b 
on a.also_song_id = b.song
cross join (select count(distinct user) as count_n_users
from expp_team.million_train) c 
join (
select song, float(float((count(play_count)))*${hiveconf:play_count_factor}) as driver_count_threshold 
from expp_team.million_train 
group by song) d 
on a.driver_song_id = d.song
where a.play_count > d.driver_count_threshold
group by a.driver_song_id, a.also_song_id, a.play_count, b.count_user, c.count_n_users;

## step 5: create output of driver song ranked by probability for top 10 songs
CREATE TABLE expp_team.million_train_output AS 
select a.driver_song_id, a.also_song_id, a.both as play_count, a.adjust_p, a.rank 
from (select driver_song_id, also_song_id, both, adjust_p,
row_number() over(partition by driver_song_id order by adjust_p desc) as rank 
from expp_team.million_train_nb_all) as a 
where a.rank <= 10;

## step 6: take output from previous and step final output for testing, which matched up predicted to testing set
INSERT OVERWRITE LOCAL DIRECTORY '/home/a149174-a/nb_test_results' ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' 
SELECT b.user, b.song, a.also_song_id, a.play_count, a.adjust_p, a.rank, count(c.song) as predicted_song 
FROM expp_team.million_train_output a 
JOIN expp_team.million_test_first_half b 
ON a.driver_song_id = b.song 
LEFT JOIN expp_team.million_test_second_half c 
ON b.user = c.user  
and a.also_song_id = c.song 
group by b.user, b.song, a.also_song_id, a.play_count, a.adjust_p, a.rank;

## step 7: move out of hadoop to local (which then moved to Microsoft Excel)
cat 000000_0 000001_0 000002_0 >> nb_test_output
scp -i ~/Desktop/Rec_Team/keys/jjanzen a149174-a@pdl01bdput251:/home/a149174-a/nb_test_results/nb_test_output ~/UST_GPS/SEIS_734/project/

# CF ********************************

## step 1: same as step 2 in NB

## step 2: create output of driver song ranked of distinct user play count for top 10 rec songs
CREATE TABLE expp_team.million_train_output_cf AS 
select a.driver_song_id, a.also_song_id, a.both as play_count, a.adjust_p, a.rank 
from (select driver_song_id, also_song_id, both, adjust_p,
row_number() over(partition by driver_song_id order by both desc) as rank 
from expp_team.million_train_nb) as a 
where a.rank <= 10;

## step 3: take output from previous and step final output for testing, which matched up predicted to testing set
INSERT OVERWRITE LOCAL DIRECTORY '/home/a149174-a/cf_test_results' ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' 
SELECT b.user, b.song, a.also_song_id, a.play_count, a.adjust_p, a.rank, count(c.song) as predicted_song 
FROM expp_team.million_train_output_cf a 
JOIN expp_team.million_test_first_half b 
ON a.driver_song_id = b.song 
LEFT JOIN expp_team.million_test_second_half c 
ON b.user = c.user  
and a.also_song_id = c.song 
group by b.user, b.song, a.also_song_id, a.play_count, a.adjust_p, a.rank;

## step 4: move out of hadoop to local (which then moved to Microsoft Excel)
cat 000000_0 000001_0 >> cf_test_output
scp -i ~/Desktop/Rec_Team/keys/jjanzen a149174-a@pdl01bdput251:/home/a149174-a/cf_test_results/cf_test_output ~/UST_GPS/SEIS_734/project/

# AR  ********************************

## move to SAP HANA results to hadoop
scp -i ~/Desktop/Rec_Team/keys/jjanzen ~/UST_GPS/SEIS_734/project/ar_rules_0504_1.csv a149174-a@pdl01bdput251:/home/a149174-a/ar-training/
make a dir to put the file in:  hadoop fs -mkdir /teamspace/bdpexpp01/ar-training/
hadoop fs -copyFromLocal /home/a149174-a/ar-training/ar_rules_0504_1.csv  /teamspace/bdpexpp01/ar-training

## step 1: create table in hive
CREATE EXTERNAL TABLE IF NOT EXISTS expp_team.million_train_association ( 
prerule string, 
postrule string,
support float,
confidence float,
lift float) 
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' 
LOCATION '/teamspace/bdpexpp01/ar-training/';

## step 2: create output of driver song ranked by confidence for top 10 songs
CREATE TABLE expp_team.million_train_output_assocation AS 
select a.prerule as driver_song_id, a.postrule as also_song_id, a.confidence, a.rank
from (select prerule, postrule, confidence
,row_number() over(partition by prerule order by confidence desc) as rank 
from expp_team.million_train_association) a 
WHERE a.rank <= 10;

## step 3: final output for testing, which matched up predicted to testing set
INSERT OVERWRITE LOCAL DIRECTORY '/home/a149174-a/assoc_test_results' ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' 
SELECT b.user, b.song, a.also_song_id, a.confidence, a.rank, count(c.song) as predicted_song 
FROM expp_team.million_train_output_assocation a 
JOIN expp_team.million_test_first_half b 
ON a.driver_song_id = b.song 
LEFT JOIN expp_team.million_test_second_half c 
ON b.user = c.user  
and a.also_song_id = c.song 
group by b.user, b.song, a.also_song_id, a.confidence, a.rank;

## step 4: move out of hadoop to local(which then moved to Microsoft Excel)
cat 000000_0 000001_0 >> assoc_test_results
scp -i ~/Desktop/Rec_Team/keys/jjanzen a149174-a@pdl01bdput251:/home/a149174-a/assoc_test_results/assoc_test_results ~/UST_GPS/SEIS_734/project/
