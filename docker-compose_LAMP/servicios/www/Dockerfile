FROM php:8.0.0-apache
ARG DEBIAN_FRONTEND=noninteractive
RUN docker-php-ext-install pdo pdo_mysql mysqli
RUN a2enmod rewrite