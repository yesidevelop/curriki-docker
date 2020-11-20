#!/bin/bash

STORAGE_ZIP=${STORAGE_ZIP:-https://github.com/ActiveLearningStudio/curriki-eks/raw/develop/storage/storage.zip}

if test ! -f '/var/www/html/storage/storage.zip'; then
    curl --compressed -o '/var/www/html/storage/storage.zip' "${STORAGE_ZIP}"
    cd /var/www/html/storage && unzip -q storage.zip
fi
