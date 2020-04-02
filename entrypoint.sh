#!/bin/sh
# Check preconditions
[ -z "${SOURCE_DATABASE}" ] && echo "SOURCE_DATABASE not set!" && exit 1;
[ -z "${BUCKET}" ] && echo "BUCKET not set!" && exit 1;
[ -z "${BACKUP_NAME}" ] && echo "BACKUP_NAME not set!" && exit 1;
SOURCE_DIR=$(dirname "${SOURCE_DATABASE}")
TIMESTAMP=$(date '+%F-%H%M%S')
BACKUP_FILE="${BACKUP_NAME}_${TIMESTAMP}"
BACKUP_COMPRESSED="${BACKUP_FILE}.tar.gz"

## Start the backup
/usr/bin/sqlite3 ${SOURCE_DATABASE} ".backup $BACKUP_FILE"

if [ $? -eq 0 ]; then
    tar -czvf $BACKUP_COMPRESSED $BACKUP_FILE
    s3cmd --config=/s3cmd/s3cmd put "$BACKUP_COMPRESSED" s3://${BUCKET}/$BACKUP_COMPRESSED --no-mime-magic
    echo "$TIMESTAMP - Backup Succeeded"
else 
    echo "$TIMESTAMP - Backup Failed"
fi

## Perform retention policy
if [ -z "${DAYS_TO_KEEP}" ]; then
    s3cmd --config=/s3cmd/s3cmd ls s3://${BUCKET} | while read -r line;
        do
            createDate=`echo $line | awk {'print $1" "$2'}`
            createDate=`date -d"$createDate" +%s`
            olderThan=`date -d"-${DAYS_TO_KEEP}" +%s`
            if [[ $createDate -lt $olderThan ]]
            then 
                fileName=`echo $line|awk {'print $4'}`
                echo "$fileName is older than ${DAYS_TO_KEEP} days, deleting"
                if [[ $fileName != "" ]]
                then
                    s3cmd --config=/s3cmd/s3cmd del "$fileName"
                fi
            fi
        done;
fi
