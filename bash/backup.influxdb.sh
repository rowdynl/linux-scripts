#!/bin/bash
DBNAME="home_assistant"
docker_id=`/volume1/@appstore/Docker/usr/bin/docker ps -aqf "name=influxdb"`
folder=$(date +%Y%m%d%H%M)
backup_path_docker=/var/lib/influxdb/backup/${folder}_work
backup_path_local=/volume1/docker/influxdb/backup/${folder}_work
echo Creating influxdb backup of database $DBNAME on docker container id $docker_id
echo Better get some coffee
/volume1/@appstore/Docker/usr/bin/docker exec --privileged $docker_id influx backup -t 2m0U4iWzOmiAqdVmHoBqrc1pBaIm_qOT_5LifSGhJPrWFStrZSpD_dXRKYNE9fgOkPGlVP1rlYNZy7JduOOVsw== $backup_path_docker
echo Compressing backupped files
tar -czvf /volume1/docker/influxdb/backup/${folder}_influxdb_${DBNAME}.tgz $backup_path_local/*
echo Cleaning up working folder
rm -r $backup_path_local
backupCount=$(find /volume1/docker/influxdb/backup -type f | wc -l)
echo $backupCount backup files found
if [ "$backupCount" -ge 11 ];
then
	echo - Removing old obsolete backups
	find /volume1/docker/influxdb/backup -mtime +11 -type f -delete
else
	echo - Skipping deletion of old backups
fi
echo Done!