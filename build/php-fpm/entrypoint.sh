#!/bin/bash

echo "Running entrypoint.sh..."

shutdown_handler() {
   # NOTE: In the most recent Docker version, logging is disabled once stop signal received :( However it still works.
   echo "STOP signal received..."
   # Add any cleanup or graceful shutdown tasks here

   echo "Killing Supervisor..."
   killall supervisord

   echo "Stopping Laravel Octane..."
   php artisan octane:stop

   echo "Terminating Laravel Horizon..."
   php artisan horizon:terminate

   if [ "$START_REDIS" = "true" ]; then
      echo "Creating Redis snapshot..."
      redis-cli -a $REDIS_PASS SAVE
   fi

   exit 0
}
trap 'shutdown_handler' SIGINT SIGQUIT SIGTERM

cd /app || exit 1

echo "alias pa=\"php artisan\"" > ~/.bashrc

# Check if the Laravel application is not present in /app
if [ ! -f "/app/artisan" ]; then
    echo "No Laravel application found in /app. Exiting..."
    exit 1
else
    echo "Laravel application found in /app."
fi


# Start Redis if not running
if [ "$START_REDIS" = "true" ]; then
   if ! pgrep "redis-server" > /dev/null; then
      echo "Starting Redis..."
      redis-server --requirepass $REDIS_PASS &
   else
       echo "Redis-server is already running."
   fi
else
    echo "START_REDIS is set to false. Redis will not be started."
fi

# Start PHP-FPM if not running
if ! pgrep "php-fpm" > /dev/null; then
   echo "Starting PHP-FPM..."
   php-fpm &
else
    echo "PHP-FPM is already running."
fi

# Start Nginx if not running
if ! pgrep "nginx" > /dev/null; then
   echo "Starting Nginx..."
   nginx &
else
    echo "Nginx is already running."
fi

# Create cache paths: mkdir -p storage/framework/{sessions,views,cache}
echo "Creating cache paths..."
mkdir -p storage/framework/sessions
mkdir -p storage/framework/views
mkdir -p storage/framework/cache

echo "Creating log paths..."
mkdir -p storage/logs/supervisor

echo "============================"
echo "===  Cache paths created ==="
echo "============================"


# Fix storage permissions
echo "Fixing storage permissions..."
chmod -R 755 storage
chown -R www-data:www-data storage
echo "============================"
echo "===  Permissions fixed   ==="
echo "============================"


echo "Installing Composer..."
if [ "$ENV_DEV" = "true" ]; then
   if [ ! -d "vendor" ]; then
      composer install --optimize-autoloader --no-interaction --prefer-dist
   fi
else
   composer install --optimize-autoloader --no-interaction --no-progress --prefer-dist
fi
echo "=========================="
echo "=== Composer installed ==="
echo "=========================="


echo "Installing NPM..."
if [ "$ENV_DEV" = "true" ]; then
   if [ ! -d "node_modules" ]; then
      npm ci --no-audit
   fi
else
   npm ci --no-audit
fi

echo "=========================="
echo "===   NPM installed    ==="
echo "=========================="


echo "Building NPM..."
if [ "$ENV_DEV" = "true" ]; then
   # npm run dev -- --host &
   echo "skipping dev server"
else
   npm run build
fi
echo "=========================="
echo "===     NPM built      ==="
echo "=========================="


echo "Migrating database..."
if [ "$ENV_DEV" = "true" ]; then
   echo "No automatic migrations will run with ENV_DEV=true."
else
   php artisan migrate --force
fi
echo "============================"
echo "=== Migrations completed ==="
echo "============================"


echo "Optimizing Laravel..."
if [ "$ENV_DEV" = "true" ]; then
   php artisan config:clear
   php artisan route:clear
else
   php artisan config:cache
   php artisan route:cache

fi

php artisan view:cache
php artisan icons:cache
php artisan filament:cache-components
echo "============================"
echo "===  Laravel optimized   ==="
echo "============================"


crond start -f -l 8 &
echo "============================"
echo "=== Cron service started ==="
echo "============================"

if [ "$START_SUPERVISOR" = "true" ]; then

   cat /etc/supervisor/conf.d/supervisor-header.conf > /etc/supervisor/conf.d/laravel-worker-compiled.conf

   if [ "$ENABLE_QUEUE_WORKER" = "true" ]; then
      echo "Adding queue supervisor config..."
      echo "" >> /etc/supervisor/conf.d/laravel-worker-compiled.conf
      cat /etc/supervisor/conf.d/queue-worker.conf >> /etc/supervisor/conf.d/laravel-worker-compiled.conf

      if [ "$DEV_ENV" = "true" ]; then
         # Change the log output to stdout
         sed -i 's|stdout_logfile=/app/storage/logs/supervisor/queue-worker.log|stdout_logfile=/dev/stdout|' /etc/supervisor/conf.d/laravel-worker-compiled.conf
      fi
   fi

   if [ "$ENABLE_HORIZON_WORKER" = "true" ]; then
      echo "Adding horizon supervisor config..."
      echo "" >> /etc/supervisor/conf.d/laravel-worker-compiled.conf
      cat /etc/supervisor/conf.d/horizon-worker.conf >> /etc/supervisor/conf.d/laravel-worker-compiled.conf

      if [ "$DEV_ENV" = "true" ]; then
         # Change the log output to stdout
         sed -i 's|stdout_logfile=/app/storage/logs/supervisor/horizon-worker.log|stdout_logfile=/dev/stdout|' /etc/supervisor/conf.d/laravel-worker-compiled.conf
      fi

      echo "============================"
      echo "===   Horizon started    ==="
      echo "============================"
   fi

   supervisord -n -c /etc/supervisor/conf.d/laravel-worker-compiled.conf &

   echo "============================"
   echo "===  Supervisor started  ==="
   echo "============================"
fi

echo "============================"
echo "===      PHP READY       ==="
echo "============================"

# wait forever
while true; do
   tail -f /dev/null &
   wait ${!}
done

