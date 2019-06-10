#!/bin/sh

echo
set -e
set -u

INIT_SQL="./ccd-to-am-migration-init.sql"
MAIN_SQL="./ccd-to-am-migration-main.sql"

echo "* CCD to AM migration..."
echo
read -p "* AM DB hostname: " HOST
read -p "* AM DB port: " PORT
read -p "* AM DB name: " DB
read -p "* AM DB username: " USER
echo

psql \
    -X \
    -q \
    -h $HOST \
    -p $PORT \
    -U $USER \
    -f $INIT_SQL \
    --set AUTOCOMMIT=off \
    --set ON_ERROR_ROLLBACK=on \
    --set ON_ERROR_STOP=off \
    $DB

psql \
    -X \
    -q \
    -h $HOST \
    -p $PORT \
    -U $USER \
    -f $MAIN_SQL \
    --set AUTOCOMMIT=off \
    --set ON_ERROR_ROLLBACK=on \
    --set ON_ERROR_STOP=off \
    $DB

echo "* Migration finished"
echo
exit 0
