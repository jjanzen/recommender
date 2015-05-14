IMPORT DATA INTO TABLE SONG.SONGS
FROM '/home/ec2-user/songs.tsv'
RECORD DELIMITED BY '\n'
FIELD DELIMITED BY '\t'
optionally enclosed by '"'
error log 'M4_LOAD.err'
