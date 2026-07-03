## climbing.ge — PHP-FPM application image
## Multi-stage build: composer deps -> frontend assets -> runtime image
##
## Build context is the `html/` project root; the `configs` context
## (see docker-compose.yml additional_contexts) supplies files from docker/php/.

ARG PHP_VERSION=8.2

#############################################
# Stage 1: PHP dependencies (composer)
#############################################
FROM composer:2 AS vendor

WORKDIR /app

COPY composer.json composer.lock ./

RUN composer install \
    --no-dev \
    --no-scripts \
    --no-autoloader \
    --no-progress \
    --ignore-platform-reqs

COPY . .

RUN composer dump-autoload --optimize --no-dev \
    && composer run-script post-autoload-dump --no-dev || true

#############################################
# Stage 2: frontend assets (node / laravel-mix)
#############################################
FROM node:20-bullseye AS frontend

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm ci --no-audit --no-fund

COPY . .
COPY --from=vendor /app/vendor ./vendor

RUN npm run build || npm run dev

#############################################
# Stage 3: runtime image
#############################################
FROM php:${PHP_VERSION}-fpm-bullseye AS runtime

ARG WWWUSER=1000
ARG WWWGROUP=1000

ENV MAKEFLAGS="-j1"

RUN apt-get update && apt-get install -y --no-install-recommends \
        libpng-dev \
        libjpeg62-turbo-dev \
        libwebp-dev \
        libfreetype6-dev \
        libzip-dev \
        libicu-dev \
        libxml2-dev \
        libonig-dev \
        libcurl4-openssl-dev \
        libssl-dev \
        unzip \
        git \
        cron \
        supervisor \
    && docker-php-ext-configure gd --with-jpeg --with-webp --with-freetype \
    && docker-php-ext-install \
        pdo_mysql \
        mysqli \
        gd \
        zip \
        bcmath \
        exif \
        intl \
        pcntl \
        opcache \
        soap \
    && curl -sSL https://pecl.php.net/get/redis-6.2.0.tgz -o /tmp/redis.tgz \
    && pecl install /tmp/redis.tgz \
    && rm /tmp/redis.tgz \
    && docker-php-ext-enable redis \
    && rm -rf /var/lib/apt/lists/*

# Match host UID/GID so bind-mounted files keep correct ownership
RUN groupmod -g ${WWWGROUP} www-data 2>/dev/null || true \
    && usermod -u ${WWWUSER} -g ${WWWGROUP} www-data 2>/dev/null || true

COPY --from=configs php.ini /usr/local/etc/php/conf.d/99-climbing.ini
COPY --from=configs www.conf /usr/local/etc/php-fpm.d/zz-www.conf
COPY --from=configs entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /var/www/html

COPY --chown=www-data:www-data . .
COPY --from=vendor --chown=www-data:www-data /app/vendor ./vendor
COPY --from=frontend --chown=www-data:www-data /app/public/assets ./public/assets
COPY --from=frontend --chown=www-data:www-data /app/public/mix-manifest.json ./public/mix-manifest.json

RUN mkdir -p storage/framework/{cache,sessions,testing,views} storage/logs bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R ug+rwX storage bootstrap/cache

USER www-data

ENTRYPOINT ["entrypoint.sh"]
CMD ["php-fpm"]
