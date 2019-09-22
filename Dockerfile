FROM php:7.3.8-fpm-alpine3.10

ENV PHP_OPCACHE_VALIDATE_TIMESTAMPS="0" \
    PHP_OPCACHE_MAX_ACCELERATED_FILES="10000" \
    PHP_OPCACHE_MEMORY_CONSUMPTION="192" \
    PHP_OPCACHE_MAX_WASTED_PERCENTAGE="10"

RUN apk info \
    && echo @edge http://nl.alpinelinux.org/alpine/edge/community >> /etc/apk/repositories \
    && echo @edge http://nl.alpinelinux.org/alpine/edge/main >> /etc/apk/repositories \
    && echo @3.8 http://dl-cdn.alpinelinux.org/alpine/v3.8/main >> /etc/apk/repositories \
    && apk update \
    && apk upgrade \
    && apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
    && apk add --no-cache \
        runit \
        nginx \
        zlib-dev \
        libzip-dev \
        libjpeg-turbo-dev \
        libpng-dev \
        libxml2-dev \
        freetype-dev \
        bash \
        git \
        nodejs \
        composer \
        php7-tokenizer \
        php7-simplexml \
        php7-dom \
        mysql-client \
        yarn@edge \
        libgcj@3.8 \
        xvfb \
        chromium@edge \
        chromium-chromedriver@edge \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) \
        gd \
        pdo_mysql \
        zip \
        bcmath \
        exif \
    && docker-php-ext-install \
        zip \
        opcache \
        pcntl \
    && apk del .build-deps

# change default shell
SHELL ["/bin/bash", "-c"]

# create app user
RUN useradd --create-home app
WORKDIR /home/app
USER app

# install wait-for-it
ADD https://github.com/vishnubob/wait-for-it/raw/master/wait-for-it.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/wait-for-it.sh

# copy runit services
COPY ./etc/service/ /etc/service/
RUN find /etc/service/ -name "run" -exec chmod -v +x {} \;

# copy nginx config files
COPY ./etc/nginx/ /etc/nginx/

# copy php config files
COPY ./usr/local/etc/php/ /usr/local/etc/php/
COPY ./usr/local/etc/php-fpm.d/ /usr/local/etc/php-fpm.d/

# configure composer
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV PATH="$PATH:./vendor/bin:~/.composer/vendor/bin"
RUN composer global require hirak/prestissimo

# configure yarn
RUN yarn config set strict-ssl false && \
    yarn global add cross-env

# copy user files and make run scripts executable
COPY home/app/ .
RUN find . -name "run-*.sh" -exec chmod -v +x {} \;

# run the application
CMD /root/run-dev.sh