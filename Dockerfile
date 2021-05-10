FROM php:8-fpm
ENV DOCKER_KNOWN_VERSION 1.2.2
ENV DOCKER_KNOWN_BRANCH dev
ENV DOCKER_KNOWN_URL https://api.github.com/repos/idno/known/tarball/${DOCKER_KNOWN_BRANCH}
# [NEEDED EXTENSIONS FOR KNOWN as of v1.2.2]
# curl
# dom
# gd
# gettext
# json
# mbstring
# openssl
# pdo
# pdo_mysql
# session
# simplexml

# [EXTENSIONS NEEDED FOR PHP DOCKER IMAGE]
# gd
# gettext
# pdo_mysql

RUN apt-get update \
&& apt-get install -y --no-install-recommends \
    mariadb-client \
    unzip \
&& savedAptMark="$(apt-mark showmanual)" \
&& apt-get install -y --no-install-recommends \
    libfreetype6-dev \
    libjpeg-dev \
    libpng-dev \
&& docker-php-ext-configure gd --with-freetype --with-jpeg \
&& docker-php-ext-install -j$(nproc) gd pdo_mysql gettext opcache \
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
&& apt-mark auto '.*' > /dev/null \
&& apt-mark manual $savedAptMark \
&& ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
    | awk '/=>/ { print $3 }' \
    | sort -u \
    | xargs -r dpkg-query -S \
    | cut -d: -f1 \
    | sort -u \
    | xargs -rt apt-mark manual \
&& apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
&& rm -rf /var/lib/apt/lists/*

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
  echo 'opcache.memory_consumption=128'; \
  echo 'opcache.interned_strings_buffer=8'; \
  echo 'opcache.max_accelerated_files=4000'; \
  echo 'opcache.revalidate_freq=60'; \
  echo 'opcache.fast_shutdown=1'; \
  echo 'opcache.enable_cli=1'; \
} > /usr/local/etc/php/conf.d/opcache-recommended.ini

# PECL extensions
# https://pecl.php.net/package/apcu
RUN pecl install APCu-5.1.20 \
 && docker-php-ext-enable apcu

WORKDIR /var/www/html
COPY config.ini .

 # download Known, make sure link is updated
RUN curl -fsSL $DOCKER_KNOWN_URL | tar -xzf - --strip-components=1 \
&& curl -fsSL https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
&& chmod 644 config.ini \
&& composer install --prefer-dist \
&& composer require idno/twitter

# Add plugins
WORKDIR /var/www/html/IdnoPlugins
RUN  mkdir Markdown \
&& curl -fsSL https://api.github.com/repos/idno/Markdown/tarball/master | tar xzf - --strip-components=1 -C Markdown \
&& mkdir Reactions \
&& curl -fsSL https://api.github.com/repos/kylewm/KnownReactions/tarball/master | tar xzf - --strip-components=1 -C Reactions \
&& mkdir Yourls \
&& curl -fsSL https://api.github.com/repos/danito/KnownYourls/tarball/master | tar xzf - --strip-components=1 -C Yourls \
&& mkdir Journal \
&& curl -fsSL https://api.github.com/repos/andrewgribben/KnownJournal/tarball/master | tar xzf - --strip-components=1 -C Journal

COPY docker-entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

CMD ["php-fpm"]