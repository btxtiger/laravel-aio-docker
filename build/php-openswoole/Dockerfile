ARG INPUT_PHP="8.3"
ARG IMAGENAME=php:${INPUT_PHP}-cli-alpine

FROM $IMAGENAME

############################################################
###############  GENERAL DEPENDENCIES ######################
############################################################

# Install dependencies including Nginx, Supervisor, Cron, and security tools
RUN apk update && apk add --no-cache \
    bash \
    curl \
    git \
    zip \
    imagemagick \
    mysql-client \
    postgresql-client \
    nano \
    nodejs \
    npm \
    nginx \
    supervisor \
    ca-certificates \
    tzdata \
    && rm -rf /var/cache/apk/*

# PHP Extension installer
ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

# Install PHP Extensions (grouped in one layer for optimization)
RUN chmod +x /usr/local/bin/install-php-extensions && \
    install-php-extensions @composer \
    gd bcmath bz2 calendar iconv intl mbstring \
    mysqli pdo_mysql pdo_pgsql soap zip gmp ldap \
    exif memcached redis imap pcntl openssl tokenizer \
    xml ctype json imagick sockets opcache xdebug openswoole

# Configure Nginx. Add your Nginx configuration file here. This will depend on your Laravel application.
COPY ./build/shared/nginx.octane.conf /etc/nginx/http.d/default.conf

# Configure Supervisor. Add your Supervisor configuration files here.
COPY ./build/shared/supervisor/ /tmp/supervisor/
RUN mkdir -p /etc/supervisor/conf.d/ && cp -n /tmp/supervisor/* /etc/supervisor/conf.d/ && rm -r /tmp/supervisor/

# Configure Cron Jobs (if needed). You can add cron jobs by creating a crontab file and copying it into the container.
COPY ./build/shared/laravel-cron /etc/crontabs/www-data

# Copy custom php.ini configuration
COPY ./build/shared/php.ini /usr/local/etc/php/

# Yes, different path for xdebug config, disabled by default
COPY ./build/shared/xdebug.ini /usr/local/etc/php/conf.d/xdebug.ini.disabled
# Remove xdebug ini file from extension installer
RUN rm /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini

# Set up the application working directory
WORKDIR /app

# Copy the entrypoint script into the container
COPY ./build/shared/entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Expose the port Nginx is reachable on
EXPOSE 80

# Set Bash as the default shell
SHELL ["/bin/bash", "-c"]

ENV PHP_RUNTIME_CONFIG=swoole
ENV PHP_IDE_CONFIG="serverName=laravel"

# Define the command to run on container start
ENTRYPOINT ["/docker-entrypoint.sh"]
