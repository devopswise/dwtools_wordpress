#!/bin/bash

if ! [[ $1 ]]
then
    echo "Error: Backup name missing"
    echo "Please specify a backup name, e.g. 'restore 20141104'"
    echo "Finished: FAILURE"
    exit 1
fi

if [ -z "$WORDPRESS_DB_USER" ]; then echo "Error: WORDPRESS_DB_USER not set"; echo "Finished: FAILURE"; exit 1; fi
if [ -z "$WORDPRESS_DB_NAME" ]; then echo "Error: WORDPRESS_DB_NAME not set"; echo "Finished: FAILURE"; exit 1; fi
if [ -z "$WORDPRESS_DB_PASSWORD" ]; then echo "Error: WORDPRESS_DB_PASSWORD not set"; echo "Finished: FAILURE"; exit 1; fi
if [ -z "$WORDPRESS_DB_HOST" ]; then echo "Error: WORDPRESS_DB_HOST not set"; echo "Finished: FAILURE"; exit 1; fi

if ! [[ $1 =~ ^[a-zA-Z0-9_-]+$ ]]
then
  echo "The given backup name does not match the expected pattern: only characters, digits, underscore and dash are allowed ([a-zA-Z0-9_-])."
  echo 'Finished: FAILURE'
  exit 1
fi

FILES_ARCHIVE="/backups/$1_backup.tar.gz"
SQL_ARCHIVE="/backups/$1_backup.sql.gz"

if [[ ! -f $FILES_ARCHIVE ]]
then
  echo "The file $FILES_ARCHIVE does not exist. Aborting."
  echo "Finished: FAILURE."
  exit 1
fi

if [[ ! -f $SQL_ARCHIVE ]]
then
  echo "The file $SQL_ARCHIVE does not exist. Aborting."
  echo "Finished: FAILURE."
  exit 1
fi


# cleanup html folder
echo "deleting files from /var/www/html/"
rm -R /var/www/html/*

# restore files
echo "restoring files from $FILES_ARCHIVE to /var/www/html"
tar -xzf $FILES_ARCHIVE --directory="/var/www/html/"

# update wp-config.php
sed -i s/"define('DB_NAME', '.*');"/"define('DB_NAME', '$WORDPRESS_DB_NAME');"/g /var/www/html/wp-config.php
sed -i s/"define('DB_USER', '.*');"/"define('DB_USER', '$WORDPRESS_DB_USER');"/g /var/www/html/wp-config.php
sed -i s/"define('DB_PASSWORD', '.*');"/"define('DB_PASSWORD', '$WORDPRESS_DB_PASSWORD');"/g /var/www/html/wp-config.php
sed -i s/"define('DB_HOST', '.*');"/"define('DB_HOST', '$WORDPRESS_DB_HOST');"/g /var/www/html/wp-config.php

# set correct file owner
chown -R www-data:www-data /var/www/html

# restore database
echo "restoring data from mysql dump file $SQL_ARCHIVE"

MYSQL_PORT=`echo $WORDPRESS_DB_HOST | cut -d':' -f2`

re='^[0-9]+$'
if ! [[ $MYSQL_PORT =~ $re ]] ; then
    echo "detected WORDPRESS_DB_HOST without port"
    if [ -z "$WORDPRESS_DB_PORT" ]; then
        WORDPRESS_DB_PORT=3306
    fi
else
    echo "detected WORDPRESS_DB_HOST:PORT notation"
    WORDPRESS_DB_PORT=$MYSQL_PORT
    WORDPRESS_DB_HOST=`echo $WORDPRESS_DB_HOST | cut -d':' -f1`
fi

/bin/wait-for-it.sh -h ${WORDPRESS_DB_HOST} -p ${WORDPRESS_DB_PORT} -t 30

#change wordpress site url if needed
if [[ -z "${WORDPRESS_CHANGE_URL_FROM}" && -z "${WORDPRESS_CHANGE_URL_TO}" ]]; then
  gunzip -c $SQL_ARCHIVE | mysql -u$WORDPRESS_DB_USER -p$WORDPRESS_DB_PASSWORD -h $WORDPRESS_DB_HOST --port=$WORDPRESS_DB_PORT $WORDPRESS_DB_NAME
else
  gunzip -c $SQL_ARCHIVE | sed --expression "s/${WORDPRESS_CHANGE_URL_FROM}/${WORDPRESS_CHANGE_URL_TO}/g" | mysql -u$WORDPRESS_DB_USER -p$WORDPRESS_DB_PASSWORD -h$WORDPRESS_DB_HOST --port=$WORDPRESS_DB_PORT $WORDPRESS_DB_NAME
fi

echo 'Finished: SUCCESS'
