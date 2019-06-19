#!/bin/sh

echo
set -e
set -u

echo "* Starting AM migration..."
echo

if [ "$#" -ne 5 ]; then
    echo "* Illegal number of arguments."
    echo "* Usage: $0 [hostname] [port] [db_name] [db_username] [input.sql]"
    echo
    echo "* Exiting"
    echo
    exit 1
fi

HOST="$1"
PORT="$2"
DB="$3"
USER="$4"
SQL="$5"

echo "* AM DB hostname: $HOST"
echo "* AM DB port: $PORT"
echo "* AM DB name: $DB"
echo "* AM DB username: $USER"
echo

psql \
    -X \
    -q \
    -h $HOST \
    -p $PORT \
    -U $USER \
    -f $SQL \
    --set AUTOCOMMIT=off \
    --set ON_ERROR_ROLLBACK=on \
    --set ON_ERROR_STOP=off \
    $DB

echo "* Migration finished"
echo
exit 0
