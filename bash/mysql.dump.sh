#!/bin/bash
cd /volume1/@appstore/MariaDB10/usr/local/mariadb10/bin
echo Dumping festinalentebock
./mysqldump -u root -password=DataBaseness11! --opt festinalentebock --add-drop-database --add-drop-table > /volume1/docker/mariadb/backup/20230330_1111_festinalentebock.sql
echo Dumping grafana
./mysqldump -u root -password=DataBaseness11! --opt grafana --add-drop-database --add-drop-table > /volume1/docker/mariadb/backup/20230330_1111_grafana.sql
echo Dumping mail
./mysqldump -u root -password=DataBaseness11! --opt mail --add-drop-database --add-drop-table > /volume1/docker/mariadb/backup/20230330_1111_mail.sql
echo Dumping mainDB
./mysqldump -u root -password=DataBaseness11! --opt mainDB --add-drop-database --add-drop-table > /volume1/docker/mariadb/backup/20230330_1111_mainDB.sql
echo Dumping smarthome
./mysqldump -u root -password=DataBaseness11! --opt smarthome --add-drop-database --add-drop-table > /volume1/docker/mariadb/backup/20230330_1111_smarthome.sql
echo Dumping solaredge
./mysqldump -u root -password=DataBaseness11! --opt solaredge --add-drop-database --add-drop-table > /volume1/docker/mariadb/backup/20230330_1111_solaredge.sql
echo Dumping tcit
./mysqldump -u root -password=DataBaseness11! --opt tcit --add-drop-database --add-drop-table > /volume1/docker/mariadb/backup/20230330_1111_tcit.sql
echo Dumping zpf
./mysqldump -u root -password=DataBaseness11! --opt zpf --add-drop-database --add-drop-table > /volume1/docker/mariadb/backup/20230330_1111_zpf.sql
echo Dumping hass
./mysqldump -u root -password=DataBaseness11! --opt hass --add-drop-database --add-drop-table > /volume1/docker/mariadb/backup/20230330_1111_hass.sql
echo Done!
