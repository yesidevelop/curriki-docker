#!/bin/bash

STORAGE_ZIP=${STORAGE_ZIP:-https://github.com/ActiveLearningStudio/curriki-eks/raw/develop/storage/storage.zip}

if test ! -f '/var/www/html/storage/storage.zip'; then
    curl -o '/var/www/html/storage/storage.zip' "${STORAGE_ZIP}"
fi

php /var/www/html/artisan config:cache
php /var/www/html/artisan key:generate
php /var/www/html/artisan passport:install
php /var/www/html/artisan storage:link