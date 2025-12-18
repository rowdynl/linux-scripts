#!/bin/bash
#
# version 0.1
# Script import IP's from blocklist.de
# by Ruedi61, 15.11.2016
#
# DSM 6.0.3 AutoBlockIP Table:
# CREATE TABLE AutoBlockIP(IP varchar(50) PRIMARY KEY,RecordTime date NOT NULL,ExpireTime date NOT NULL,Deny boolean NOT NULL,IPStd varchr(50) NOT NULL);

# Download from www.blocklist.de
# Select Typ: {all} {ssh} {mail} {apache} {imap} {ftp} {sip} {bots} {strongips} {ircbot} {bruteforcelogin}
BLOCKLIST_TYP="all"

# Delete IP after x Day's OR use 0 for permanent block
DELETE_IP_AFTER="11" 

# Show Time this Script need at the bottom; 0=no 1=yes
SHOW_TIME="1"


###############################################################################################################
# Do NOT change after here
UNIXTIME=`date +%s`
UNIXTIME_DELETE_IP=`date -d "+$DELETE_IP_AFTER days" +%s`
wget -q "https://lists.blocklist.de/lists/$BLOCKLIST_TYP.txt" -O /tmp/blocklist.txt

cat "/tmp/blocklist.txt" | while read BLOCKED_IP
do
    # Check if IP valid
    VALID_IPv4=`echo "$BLOCKED_IP" | grep -Eo "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$" | wc -l`

    if [[ $VALID_IPv4 -eq 1 ]]; then
        # Convert IPv4 to IPv6 :)
        IPv4=`echo $BLOCKED_IP | sed 's/\./ /g'`
        IPv6=`printf "0000:0000:0000:0000:0000:FFFF:%02X%02X:%02X%02X" $IPv4`
        CHECK_IF_EXISTS=`sqlite3 /etc/synoautoblock.db "SELECT DENY FROM AutoBlockIP WHERE IP = '$BLOCKED_IP'" | wc -l`
        if [[ $CHECK_IF_EXISTS -lt 1 ]]; then
            INSERT=`sqlite3 /etc/synoautoblock.db "INSERT INTO AutoBlockIP VALUES ('$BLOCKED_IP','$UNIXTIME','$UNIXTIME_DELETE_IP','1','$IPv6','0',NULL)"`
            echo "IP added to Database   -->  $BLOCKED_IP"
        else
			UPDATE=`sqlite3 /etc/synoautoblock.db "UPDATE AutoBlockIP SET ExpireTime = '$UNIXTIME_DELETE_IP' WHERE IP = '$BLOCKED_IP'"`
            echo "IP already in Database, ExpireTime updated -->  $BLOCKED_IP"
        fi
    fi
done

rm /tmp/blocklist.txt

if [[ $SHOW_TIME -eq 1 ]]; then
    END=`date +%s`
    RUNTIME=$((END-UNIXTIME))
    echo "Finish after $RUNTIME Seconds"
fi
exit 0 