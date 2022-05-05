FROM php:7.4-fpm

RUN apt-get update && \
    apt-get install -y curl

RUN docker-php-ext-install pdo pdo_mysql mysqli && docker-php-ext-enable pdo pdo_mysql mysqli



