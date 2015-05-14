/*
Written by Josh Janzen
SEIS 734-01 Spring 2015
*/

# CF ********************************

## step 1: identified users also played same driver song, then increments the also played song +1 for each user
CREATE TABLE expp_team.million_test_cooccur_v2 AS 
SELECT a.song as driver_song_id, b.song as also_song_id,
count(b.play_count) as play_count
from (
select user, song, play_count
from expp_team.million_all) a 
join (
select user, song, play_count
from expp_team.million_all) b 
on a.user = b.user
where a.song != b.song
group by a.song, b.song
having play_count >=1; 

## step 2: create output of driver song ranked of distinct user play count for top 10 rec songs
CREATE TABLE expp_team.million_test_cf_results_v2 AS 
select a.driver_song_id, a.also_song_id, a.play_count, a.rank
from (select driver_song_id, also_song_id, play_count,
row_number() over(partition by driver_song_id order by play_count desc) as rank 
from expp_team.million_test_cooccur_v2) a 
WHERE a.rank <= 10;

# NB ********************************

## step 1: use same table in step 1 of CF 

## step 2: total songs and count of users
CREATE TABLE expp_team.million_test_n AS 
select song, count(distinct user) as count_user
from expp_team.million_all 
group by song; 

## step 3: play count threshold
set play_count_factor=0.1;
CREATE TABLE expp_team.million_test_nb_all_v2 AS 
select a.driver_song_id, a.also_song_id, a.play_count as both, b.count_user, c.count_n_users
,a.play_count/b.count_user as p_y
,(c.count_n_users-a.play_count)/c.count_n_users as p_n
,(a.play_count/b.count_user)/((c.count_n_users-a.play_count)/c.count_n_users) as adjust_p
from (select driver_song_id, also_song_id, play_count from expp_team.million_test_cooccur_v2) as a 
join (select song, count_user from expp_team.million_test_n) as b 
on a.also_song_id = b.song
cross join (select count(distinct user) as count_n_users
from expp_team.million_all) c 
join (
select song, float(float((count(play_count)))*${hiveconf:play_count_factor})as driver_count_threshold 
from expp_team.million_all 
group by song) d 
on a.driver_song_id = d.song
where float(a.play_count) > d.driver_count_threshold
group by a.driver_song_id, a.also_song_id, a.play_count, b.count_user, c.count_n_users;

## step 4: create output of driver song ranked by probability for top 10 songs
CREATE TABLE expp_team.million_test_output_v2 AS 
select a.driver_song_id, a.also_song_id, a.both as play_count, a.adjust_p, a.rank 
from (select driver_song_id, also_song_id, both, adjust_p,
row_number() over(partition by driver_song_id order by adjust_p desc) as rank 
from expp_team.million_test_nb_all_v2) as a 
where a.rank <= 10;

# AR  ********************************

## move to SAP HANA results to hadoop
scp -i ~/Desktop/Rec_Team/keys/jjanzen ~/UST_GPS/SEIS_734/project/song_ar_data_jason.csv a149174-a@pdl01bdput251:/home/a149174-a/
make a dir to put the file in:  hadoop fs -mkdir /teamspace/bdpexpp01/testing_data/association/
hadoop fs -copyFromLocal /home/a149174-a/song_ar_data_jason.csv /teamspace/bdpexpp01/testing_data/association

## step 1: create table in hive
CREATE EXTERNAL TABLE IF NOT EXISTS expp_team.million_test_association ( 
prerule string, 
postrule string,
support float,
confidence float,
lift float) 
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' 
LOCATION '/teamspace/bdpexpp01/testing_data/association/';

## step 2: create output of driver song ranked by confidence for top 10 songs
CREATE TABLE expp_team.million_test_assocation_results AS 
select a.prerule as driver_song_id, a.postrule as also_song_id, a.confidence, a.rank
from (select prerule, postrule, confidence
,row_number() over(partition by prerule order by confidence desc) as rank 
from expp_team.million_train_association) a 
WHERE a.rank <= 10;
