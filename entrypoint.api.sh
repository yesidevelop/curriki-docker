#!/bin/sh

# service apache2 restart &
redis-server &
laravel-echo-server start --force &
php /var/www/html/artisan queue:work --timeout=0 &

# while true; do sleep 1000000000000; done
