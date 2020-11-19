#!/bin/bash

cp /var/www/html/env/.env /var/www/html/.env
php /var/www/html/artisan config:cache
php /var/www/html/artisan key:generate
php /var/www/html/artisan passport:install
php /var/www/html/artisan storage:link
php /var/www/html/artisan config:cache
chmod 777 -R /var/www/html/storage
service apache2 restart
while true; do sleep 10000000 ; done
