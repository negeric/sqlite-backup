#!/bin/bash
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
    if [ ! -z "${ENCRYPT_BACKUPS}" ]; then
        cat /etc/enc-key/key
        cat /etc/enc-key/key | gpg --passphrase-fd 0 --batch --quiet --yes -c -o $BACKUP_COMPRESSED.gpg $BACKUP_COMPRESSED
        s3cmd --config=/s3cmd/s3cmd put "$BACKUP_COMPRESSED.gpg" s3://${BUCKET}/$BACKUP_COMPRESSED.gpg --no-mime-magic
        echo "$TIMESTAMP - Encrypted SQLite Backup Succeeded"
    else
        s3cmd --config=/s3cmd/s3cmd put "$BACKUP_COMPRESSED" s3://${BUCKET}/$BACKUP_COMPRESSED --no-mime-magic
        echo "$TIMESTAMP - SQLite Backup Succeeded"
    fi
else 
    echo "$TIMESTAMP - SQLite Backup Failed"
fi

## Directory backup
if [ ! -z "${BACKUP_THIS_DIRECTORY}" ]; then
    if [ -d "${BACKUP_THIS_DIRECTORY}" ]; then
        ARCHIVE_NAME="$(basename ${BACKUP_THIS_DIRECTORY})_$TIMESTAMP.tar.gz"
        echo "$TIMESTAMP - Creating archive $ARCHIVE_NAME"
        tar -czvf $ARCHIVE_NAME_$TIMESTAMP ${BACKUP_THIS_DIRECTORY}
        if [ ! -z "${ENCRYPT_BACKUPS}" ]; then
            cat /etc/enc-key/key | gpg --passphrase-fd 0 --batch --quiet --yes -c -o $ARCHIVE_NAME.gpg $ARCHIVE_NAME
            s3cmd --config=/s3cmd/s3cmd put "$ARCHIVE_NAME.gpg" s3://${BUCKET}/$ARCHIVE_NAME.gpg --no-mime-magic
            echo "$TIMESTAMP - Encrypted Directory Backup Succeeded"
        else
            s3cmd --config=/s3cmd/s3cmd put "$ARCHIVE_NAME" s3://${BUCKET}/$ARCHIVE_NAME --no-mime-magic
            echo "$TIMESTAMP - Directory Backup Succeeded"
        fi
    else
        echo "$TIMESTAMP - Directory does not exist"
    fi
fi

## Perform retention policy
if [ -z "${DAYS_TO_KEEP}" ]; then
    echo "No retention policy set.  Job is complete"
else
    echo "Retention policy configured.  Deleting backups older than ${DAYS_TO_KEEP} days"
    s3cmd --config=/s3cmd/s3cmd ls s3://${BUCKET} | grep " DIR " -v | while read -r line
        do
            createDate=`echo $line | awk {'print $1'}`
            currentDate=`date +'%Y-%m-%d'`            
            dateDiff=$(( (`date -d $currentDate +%s` - `date -d $createDate +%s`) / (24*3600) ))
            if [[ $dateDiff -gt ${DAYS_TO_KEEP} ]]
            then 
                fileName=`echo $line|awk {'print $4'}`
                echo "$fileName is older than ${DAYS_TO_KEEP} days, deleting"
                s3cmd --config=/s3cmd/s3cmd del "$fileName"
            fi
        done;
fi
