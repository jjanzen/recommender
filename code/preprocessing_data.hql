/*
Written by Josh Janzen
SEIS 734-01 Spring 2015
*/

## step 1: move to hadoop
scp -i ~/Desktop/Rec_Team/keys/jjanzen train_triplets.txt username@user:/home/username/
make a dir to put the file in:  hadoop fs -mkdir /teamspace/bdpexpp01/testing_data
hadoop fs -copyFromLocal /home/username/train_triplets.txt  /teamspace/bdpexpp01/testing_data

## step 2: create table in hive
CREATE EXTERNAL TABLE IF NOT EXISTS hdfs_database.million_all ( 
user string, 
song string,
play_count int) 
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' 
LOCATION '/teamspace/bdpexpp01/testing_data/';
