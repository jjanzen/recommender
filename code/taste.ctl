IMPORT DATA INTO TABLE SONG.TASTESET
FROM '/home/ec2-user/train_triplets.txt'
RECORD DELIMITED BY '\n'
FIELD DELIMITED BY '\t'
optionally enclosed by '"'
error log 'M4_LOAD.err'
