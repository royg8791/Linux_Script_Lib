#!/bin/bash
#
# script for transfering files from safe01 server to "/home/Informatica/INT/55900_MT_Control/IN"
#
#########################

HOST="safe01.egged.intra"
USER="informatica01@egged.co.il"
PASSWORD="Infor1q2w3e4r5t6y7u8i9o0p"

DESTINATION="/home/Informatica/INT/55900_MT_Control/IN"

SOURCE_PATH_BASE='/Google_Buckets/mot-prod-oprout-003'

cd $DESTINATION

search_date=$(date +%Y%m)

ftp -inv $HOST <<EOF
user $USER $PASSWORD
cd $SOURCE_PATH_BASE
mget $search_date*
bye
EOF

