#!/bin/bash
# Check for existence of MySQL password and initalize database.
# Script sources:
# https://github.com/idno/Known-Docker/blob/master/docker-entrypoint.sh
# https://github.com/egoexpress/docker-known/blob/master/docker-entrypoint.sh

set -e

me=`basename -- "$0"`

if [ -z "$KNOWN_MYSQL_PASSWORD" ]; then
    echo >&2 "$me: error: \$KNOWN_MYSQL_PASSWORD environment variable must be set:"
    exit 1
fi

echo "dbpass = '$KNOWN_MYSQL_PASSWORD'" >> /var/www/html/config.ini

# Fix permissions for the uploads directory
chown -R root:www-data /var/www/html
chmod -R 650 /var/www/html
chmod -R 775 /var/www/html/Uploads

# Wait for MariaDB server to start.
DB_CONNECT=0
echo "$me: Connecting to database"
for ((i=0;i<10;i++)); do
    if mysql -h mysql -u known -p$KNOWN_MYSQL_PASSWORD -e "status" &> /dev/null; then
        DB_CONNECT=1
        echo "$me: Connected to database"
        break
    fi
    echo "$me: Waiting 5s for MariaDB service to start..."
    sleep 5
done
# if connected, create db(command below is idempotent)
if [[ $DB_CONNECT -eq 1 ]]; then
    echo "$me: creating database known"
    mysql -h mysql -u known -p$KNOWN_MYSQL_PASSWORD known < /var/www/html/warmup/schemas/mysql/mysql.sql
else
    echo >&2 "$me: error: Cannot connect to MariaDB. Exiting"
    exit 2
fi

echo "$me: Successfully connected to MariaDB service"    
exec "$@"