/*
  Song Recommendation Training & Test Set Generation
  Written By Jason Baker
  SEIS 734-01 Spring 2015
  Note: Taste Subset data must be loaded into SONG.TASTESET before running this
  script
*/

set schema song;

/* create a users table to store all unique users in the dataset */
drop table #users;
create local temporary column table #users(uid varchar(50));
insert into #users
select distinct UID from tasteset;

/* sample 1000 users from the users table */
drop table sampleusers;
create column table sampleusers(uid varchar(50));
insert into sampleusers
select LOWER(UID) from #users TABLESAMPLE SYSTEM (.1) limit 1000;

/* generate a testset containing the listening transactions from the 1000 users */
drop table testset;
create column table testset(uid varchar(50), songid varchar(50), playcount int);
insert into testset
select uid, songid, playcount from tasteset
where tasteset.UID in (select UID from sampleusers);

/* generate a training set containing all remaining users */
drop table trainingset;
create column table trainingset(uid varchar(50), songid varchar(50), playcount int);
insert into trainingset
select uid, songid, playcount from tasteset
where tasteset.UID not in (select UID from sampleusers);

export testset as csv into '/vol/vol_HDB/data/export/';
