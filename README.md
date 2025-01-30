# laravel-aio-docker
[![8.3 Docker Pulls](https://img.shields.io/docker/pulls/umex/php8.3-laravel-aio)](https://hub.docker.com/r/umex/php8.3-laravel-aio)
[![8.4 Docker Pulls](https://img.shields.io/docker/pulls/umex/php8.4-laravel-aio)](https://hub.docker.com/r/umex/php8.4-laravel-aio)

This all-in-one Docker runtime image is designed specifically for Laravel applications, providing a complete, pre-configured
environment that works seamlessly with any Laravel project. It streamlines setup and handles all essential configurations,
ensuring your Laravel application is ready to run out of the box with minimal effort.

## Images
#### Recent
##### Laravel 11
- `umex/php8.4-laravel-aio:1.2-fpm-alpine`
- `umex/php8.4-laravel-aio:1.2-roadrunner-alpine`
##### Laravel 10
- `umex/php8.3-laravel-aio:1.2-fpm-alpine`
- `umex/php8.3-laravel-aio:1.2-roadrunner-alpine`

When switching to a Laravel Octane based image (roadrunner/franken/swoole) for the first time,
the entrypoint will automatically set up all requirements if not already available. 
You can commit the changes to your repository.

#### Legacy
- `umex/php8.3-laravel-aio:1.1-fpm-alpine`
- `umex/php8.3-laravel-aio:1.1-roadrunner-alpine`
- `umex/php8.3-laravel-aio:1.1-franken-alpine`
- `umex/php8.3-laravel-aio:1.1-openswoole-alpine`
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
   - `PROD_SKIP_OPTIMIZE`: Set to `true` to skip optimizations on container start.


- Supervisor will be always started. But workers are partially optional.
   - `ENABLE_QUEUE_WORKER`: Set to `true` to start the queue worker.
   - `ENABLE_HORIZON_WORKER`: Set to `true` to start the horizon worker.


- `SKIP_LARAVEL_BOOT`: Set to `true` to skip the Laravel boot process. Useful for other PHP applications. Only available in `fpm` images.

**Check the examples directory for full example docker-compose configurations.**

## Project Directory Ownership
Linux
```bash
sudo chown -R $USER:www-data /path/to/app
```
MacOS
```bash
sudo chown -R $(whoami):staff /path/to/app
```

## Xdebug
To enable xdebug, set `DEV_ENABLE_XDEBUG` to `true` in your `docker-compose.yml` file.
You can connect to the xdebug server on port `9003`.

#### PHPStorm Configuration
1. Go to `Settings` -> `PHP` -> `Debug`
2. External Connections: **DISABLE** `Break at first line in PHP scripts`
3. Xdebug: **DISABLE** `Force break at first line when no path mapping specified`
4. Xdebug: **DISABLE** `Force break at first line when a script is outside the project`
5. Go to `Settings` -> `PHP` -> `Servers`
6. Add a new server with name "laravel" according to the docker-compose configuration:
   - Name: `laravel`
   - Host: `localhost`
   - Port: `80`
   - Debugger: `Xdebug`
   - **ENABLE**: `Use path mappings`: `path/to/your/project` -> `/app`
7. Install [browser extension](https://www.jetbrains.com/help/phpstorm/browser-debugging-extensions.html) and enable it in the correct tab.
8. Activate telephone icon in PHPStorm to listen for incoming connections.

## Serving Javascript app with integrated nginx
Create a custom nginx.conf in your repository, and mount it in place of the default one.
Also, mount your javascript app in the `/my-app` directory.
```yml
services:
   php:
      volumes:
         - ./nginx.conf:/etc/nginx/http.d/default.conf
         - ../my-app:/js-app
```

In the config file, add the following location block (after `/basic_status`) to serve your javascript app.
```nginx
####################################
####### Start serving JS app #######
####################################
location /app {

    alias /js-app;

    location ~* \.(?:manifest|appcache|html?|xml|json)$ {
        expires -1;
    }

    location ~* \.(jpg|jpeg|png|gif|ico|woff|otf|js|svg|css|txt|wav|mp3|aff|dic)$ {
        add_header Cache-Control "public";
        expires 365d;
        access_log off;
    }

    index index.html;
    try_files $uri $uri/ /index.html =404;
}

location = / {
    return 301 /app;
}
####################################
####### End serving JS app #########
####################################
```

## Custom scripts
You can hook into the boot process by mounting your custom script directories.
The scripts will be executed in alphabetical order.

```yml
services:
   php:
      volumes:
         - ./docker/before-boot:/custom-scripts/before-boot
         - ./docker/after-boot:/custom-scripts/after-boot
```

### Example docker-compose.yml for DEVELOPMENT

```yml
# WARNING: Make sure the project-folder-name is unique on your server!
# You should disable port-exposure in production!

networks:
   app:
      external: false

volumes:
   db_volume:
      driver: local

services:
   php:
      container_name: ${APP_NAME}_php
      image: umex/php8.4-laravel-aio:1.2-fpm-alpine
      stop_grace_period: 60s
      volumes:
         - ./:/app
      environment:
         ENV_DEV: true
         DEV_NPM_RUN_DEV: true
         DEV_ENABLE_XDEBUG: true
         ENABLE_HORIZON_WORKER: true
      ports:
         - "8000:80" # php
         - "5173:5173" # vite
      restart: unless-stopped
      depends_on:
         - mysql
         # - redis
      networks:
         - app

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

### Adding Chromium PDF

To add Chromium PDF to your project, create the following script in `docker/before-boot/setup-pdf-printer.sh`:
```shell
#!/bin/sh

# Update and install necessary tools
apk update && apk add --no-cache \
  chromium \
  nss \
  freetype \
  harfbuzz \
  ca-certificates \
  ttf-freefont \
  libc6-compat \
  gcompat

export PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
```

Then mount it
```yml
services:
   php:
      volumes:
         - ./docker/before-boot:/custom-scripts/before-boot
```

Install the package `spatie/laravel-pdf` and configure it to use the `chrome` driver.

```shell
composer require spatie/laravel-pdf
npm install -S puppeteer
```

```php
<?php

namespace App\Services;

use Spatie\Browsershot\Browsershot;
use Spatie\LaravelPdf\PdfBuilder;

class PDF {
   /**
    * Get printer instance
    */
   public static function getPrinter(): PdfBuilder {
      return \Spatie\LaravelPdf\Support\pdf()->withBrowsershot(function (Browsershot $browsershot) {
         $browsershot->setOption('executablePath', '/usr/bin/chromium-browser');
      });
   }
}

```


### Adding wkhtmltopdf (deprecated)

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


### Adding PhpMyAdmin
```yaml
pma:
   container_name: ${APP_NAME}_pma
   image: phpmyadmin:latest
   environment:
      PMA_HOST: mysql
      PMA_PORT: 3306
      APACHE_PORT: 8080
      UPLOAD_LIMIT: 1G
   restart: unless-stopped
   depends_on:
      - mysql
   networks:
      - app
      - main-nginx-proxy
```

### Debugging nginx configuration
You can print all variables by adding this location in your `nginx.conf` file.
```nginx
 location /debug_status {
     default_type text/plain;
     return 200 "
         scheme: $scheme
         host: $host
         server_addr: $server_addr
         remote_addr: $remote_addr
         remote_port: $remote_port
         request_method: $request_method
         request_uri: $request_uri
         document_uri: $document_uri
         query_string: $query_string
         status: $status
         http_user_agent: $http_user_agent
         http_referer: $http_referer
         http_x_forwarded_for: $http_x_forwarded_for
         http_x_forwarded_proto: $http_x_forwarded_proto
         request_time: $request_time
         upstream_response_time: $upstream_response_time
         request_filename: $request_filename
         content_type: $content_type
         body_bytes_sent: $body_bytes_sent
         bytes_sent: $bytes_sent
         connection: $connection
         connection_requests: $connection_requests
         server_protocol: $server_protocol
         server_port: $server_port
         request: $request
         args: $args
         time_iso8601: $time_iso8601
         msec: $msec
         uri: $uri
     ";
 }
```
