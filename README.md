# docker-container-laravel

This all-in-one Docker runtime image is designed specifically for Laravel applications, providing a complete, pre-configured
environment that works seamlessly with any Laravel project. It streamlines setup and handles all essential configurations,
ensuring your Laravel application is ready to run out of the box with minimal effort.

## Images
#### Recent
- `umex/php8.3-laravel-aio:1.1-fpm-alpine`
- `umex/php8.3-laravel-aio:1.1-roadrunner-alpine`
- `umex/php8.3-laravel-aio:1.1-franken-alpine`

#### Legacy
- `umex/php8.3-laravel-aio:1.0-fpm-alpine`

## Configuration

All environment flags are opt-in. Enable them by setting them to `true`.
Nested flags are only available if the parent flag is enabled.

- `ENV_DEV`: Set to `true` to enable development mode.
   - `DEV_FORCE_NPM_INSTALL`: Set to `true` to force npm install on every container start.
   - `DEV_NPM_RUN_DEV`: Set to `true` to run `npm run dev` on every container start.
   - `DEV_ENABLE_XDEBUG`: Set to `true` to enable xdebug.


- `ENV_DEV`: Set to `false` (default) to enable production mode.
   - `PROD_RUN_ARTISAN_MIGRATE`: Set to `true` to run `php artisan migrate` on container start.
   - `PROD_RUN_ARTISAN_DBSEED`: Set to `true` to run `php artisan db:seed` on container start.


- `START_SUPERVISOR`: Set to `true` to start the supervisor service.
   - `ENABLE_QUEUE_WORKER`: Set to `true` to start the queue worker.
   - `ENABLE_HORIZON_WORKER`: Set to `true` to start the horizon worker.

**Check the examples directory for full example docker-compose configurations.**

## xdebug
To enable xdebug, set `DEV_ENABLE_XDEBUG` to `true` in your `docker-compose.yml` file.
You can connect to the xdebug server on port `9003`.

### Example docker-compose.yml for DEVELOPMENT

```yml
# WARNING: Make sure the project-folder-name is unique on your server!
# You should disable port-exposure in production!

networks:
   public:
      external: false
   app:
      external: false

volumes:
   db_volume:
      driver: local

services:
   php:
      container_name: ${APP_NAME}_php
      image: umex/php8.3-laravel-aio:1.1-fpm-alpine
      stop_grace_period: 60s
      volumes:
         - ./:/app
      environment:
         ENV_DEV: true
         DEV_NPM_RUN_DEV: true
         DEV_ENABLE_XDEBUG: true
         ENABLE_SUPERVISOR: true
         ENABLE_HORIZON_WORKER: true
      ports:
         - "8000:8000" # php
         - "5173:5173" # vite
         - "9003:9003" # xdebug
      restart: unless-stopped
      depends_on:
         - mysql
         # - redis
      networks:
         - app
         - public

   mysql:
      container_name: ${APP_NAME}_mysql
      image: mariadb:lts
      # image: mysql:lts
      command:
         - '--character-set-server=utf8mb4'
         - '--collation-server=utf8mb4_unicode_ci'
         - '--skip-name-resolve' # Disable DNS lookups (not needed in Docker, improves performance)
      volumes:
         - db_volume:/var/lib/mysql/:delegated
      cap_add:
         - SYS_NICE # Allow the container to adjust process priority (optional for performance tuning)
      environment:
         MYSQL_ALLOW_EMPTY_PASSWORD: 'false' # Disallow empty password
         MYSQL_INITDB_SKIP_TZINFO: '1' # Skip loading DB time zone tables (improves performance)
         ### Database initialization ###
         MYSQL_ROOT_PASSWORD: ${DB_INIT_ROOT_PASSWORD}
         MYSQL_USER: ${DB_USERNAME}
         MYSQL_PASSWORD: ${DB_PASSWORD}
         MYSQL_DATABASE: ${DB_DATABASE}
      ports:
         - "3306:3306"
      restart: unless-stopped
      networks:
         - app
```

### Adding Redis

To add Redis to your project, add the following service to your `docker-compose.yml` file:

```yml
volumes:
   redis_volume:
      driver: local

redis:
   container_name: ${APP_NAME}_redis
   image: redis:7-alpine
   volumes:
      - redis_volume:/data
   command: [ "redis-server", "--requirepass", "${REDIS_PASSWORD}" ]
   ports:
      - "6379:6379"
   restart: unless-stopped
   networks:
      - app
```

Configure Laravel to use Redis by adding the following to your `config/database.php` file.
You might remove `predis/predis` from your `composer.json` file if you are using phpredis.

```php
'redis' => [
    'client' => 'phpredis',
    // other Redis configurations...
]
```

### Adding wkhtmltopdf

To add wkhtmltopdf to your project, add the following service to your `docker-compose.yml` file:

```yml
wkhtmltopdf:
   container_name: ${APP_NAME}_wkhtmltopdf
   image: umex/wkhtmltopdf-microservice:1.2-alpine
   restart: unless-stopped
   environment:
      MAX_BODY: '150mb'
   networks:
      - app
```
