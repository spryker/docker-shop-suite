FROM php:7.2-fpm

# Install tini (init handler)
ADD https://github.com/krallin/tini/releases/download/v0.18.0/tini /tini
RUN chmod +x /tini

# For running APT in non-interactive mode
ENV DEBIAN_FRONTEND noninteractive

# Define build requirements, which can be removed after setup from the container
ENV PHPIZE_DEPS \
  autoconf            \
  build-essential     \
  file                \
  g++                 \
  gcc                 \
  libbz2-dev          \
  libc-client-dev     \
  libc-dev            \
  libcurl4-gnutls-dev \
  libedit-dev         \
  libfreetype6-dev    \
  libgmp-dev          \
  libicu-dev          \
  libjpeg62-turbo-dev \
  libkrb5-dev         \
  libmcrypt-dev       \
  libpng-dev          \
  libpq-dev           \
  libsqlite3-dev      \
  libssh2-1-dev       \
  libxml2-dev         \
  libxslt1-dev        \
  make                \
  pkg-config          \
  re2c


#Fixing the postgresql-client installation issue
RUN mkdir -p /usr/share/man/man7/ && touch /usr/share/man/man7/ABORT.7.gz.dpkg-tmp && \
    mkdir -p /usr/share/man/man1/ && touch /usr/share/man/man1/psql.1.gz

# Set Debian sources
RUN \
  apt-get update && apt-get install -q -y --no-install-recommends \
  wget                \
  gnupg               \
  apt-transport-https \
&& echo "deb https://deb.nodesource.com/node_8.x stretch main" > /etc/apt/sources.list.d/node.list       \
&& wget --quiet -O - https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add -                \
&& echo 'deb http://apt.newrelic.com/debian/ newrelic non-free' > /etc/apt/sources.list.d/newrelic.list  \
&& wget -O- https://download.newrelic.com/548C16BF.gpg | apt-key add - \

# Install Debian packages

&&  apt-get -qy update && apt-get install -q -y --no-install-recommends $PHPIZE_DEPS \
    apt-utils           \
    ca-certificates     \
    curl                \
    debconf             \
    debconf-utils       \
#    gettext-base        \
    git                 \
    git-core            \
    graphviz            \
    libedit2            \
    libgpgme11          \
    libgpgme11-dev      \
#    libmysqlclient18    \
    libpq5              \
    libsqlite3-0        \
#    libssh2-php         \
    jq                  \
    mc                  \
    netcat              \
    nginx               \
    nginx-extras        \
    nodejs              \
    patch               \
    postgresql-client   \
    psmisc              \
    python-dev          \
    python-setuptools   \
    python-pip          \
    redis-tools         \
    rsync               \
    sudo                \
    supervisor          \
    unzip               \
    vim                 \
    zip                 \
    openssh-server      \
    newrelic-php5       \
    dnsutils            \
    certbot             \

  && test -d /var/run/sshd || mkdir /var/run/sshd           \
  && usermod --home /data www-data                          \
  && usermod -s /bin/bash www-data                          \
  && echo "www-data:bigsecretpass" | chpasswd               \

  && useradd -m -s /bin/bash -d /data jenkins               \
  && echo "jenkins:bigsecretpass" | chpasswd                \
  #Add user to group www-data and to sudoers file           \
  && usermod -a -G www-data jenkins                         \
  && echo 'jenkins ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers  \

# Install PHP extensions
  && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
  && docker-php-ext-configure pgsql -with-pgsql=/usr/local/pgsql \
  && docker-php-ext-install -j$(nproc) \
        bcmath      \
        bz2         \
        gd          \
        gmp         \
        iconv       \
        intl        \
        mbstring    \
        mysqli      \
        opcache     \
        pdo         \
        pdo_mysql   \
        pdo_pgsql   \
        pgsql       \
        readline    \
        soap        \
        sockets     \
        xmlrpc      \
        xsl         \
        zip         \

# Install PHP gnupg extension
  && pecl install -o -f gnupg \
  && docker-php-ext-enable gnupg \

# Install PHP redis extension
  && pecl install -o -f redis \
  && rm -rf /tmp/pear \
  && echo "extension=redis.so" > $PHP_INI_DIR/conf.d/docker-php-ext-redis.ini \

# Install jinja2 cli
  && pip install pyaml j2cli jinja2-cli \

# Install composerrm -rf /var/lib/apt/lists/
  && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer \

# Install nmp (after the issue when installation just nodejs is not enough)
  && curl -L https://npmjs.org/install.sh | sudo sh \

# Remove build requirements for php modules
  && apt-get -qy autoremove \
  && apt-get -qy purge $PHPIZE_DEPS \
  && rm -rf /var/lib/apt/lists/*

# Nginx configuration
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/robots.txt /etc/nginx/robots.txt
COPY nginx/conf.d/ /etc/nginx/conf.d/
COPY nginx/vhost_templates/ /etc/nginx/vhost_templates/
COPY nginx/maintenance.conf /etc/nginx/maintenance.conf
COPY nginx/maintenance.html /maintenance/index.html
COPY nginx/fastcgi_params /etc/nginx/fastcgi_params

# PHP-FPM configuration
RUN rm -f /usr/local/etc/php-fpm.d/*
COPY php/php-fpm.conf /usr/local/etc/php-fpm.conf
COPY php/php.ini.j2 /usr/local/etc/php/php.ini.j2
COPY php/pool.d/*.conf.j2 /usr/local/etc/php-fpm.d/
#RUN echo "memory_limit = 2G" >> /usr/local/etc/php/php.ini
# Opcache configuration
COPY php/ext/opcache.ini /tmp/opcache.ini
RUN cat /tmp/opcache.ini >> /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini

# supervisord configuration
COPY supervisord.conf /etc/supervisor/supervisord.conf

# Prepare application
ARG GITHUB_TOKEN

RUN install -d -o www-data -g www-data -m 0755 /data /var/www
RUN mkdir -p /data/data/DE/logs
RUN mkdir -p /versions
RUN mkdir -p /etc/spryker
RUN chown -R www-data:www-data /data

WORKDIR /data
COPY entrypoint.sh /entrypoint.sh
COPY spryker/config_local.php.j2 /etc/spryker/config_local.php.j2
COPY spryker/config_local_XX.php.j2 /etc/spryker/config_local_XX.php.j2
COPY spryker/config_local_nonsplit.php.j2 /etc/spryker/config_local_nonsplit.php.j2
COPY spryker/config_local_XX_nonsplit.php.j2 /etc/spryker/config_local_XX_nonsplit.php.j2
COPY spryker/stores.php /etc/spryker/stores.php
COPY spryker/StockConfig.php.j2 /etc/spryker/StockConfig.php.j2
COPY spryker/frontend-build-config.json.j2 /etc/spryker/frontend-build-config.json.j2
COPY spryker/install_spryker.yml.j2 /etc/spryker/install_spryker.yml.j2
COPY spryker/restore_spryker_state.yml.j2 /etc/spryker/restore_spryker_state.yml.j2
COPY spryker/setup_suite.sh /setup_suite.sh
COPY spryker/setup_vhosts.sh /usr/local/bin/setup_vhosts.sh
COPY spryker/vars.j2 /etc/spryker/vars.j2
COPY spryker/setup_output.j2 /etc/spryker/setup_output.j2
COPY spryker/ssh_config /etc/ssh/ssh_config
RUN chmod +x /setup_suite.sh

# Add jenkins authorized_keys
RUN mkdir -p /etc/spryker/www-data/.ssh \
 && mkdir -p /etc/spryker/jenkins/.ssh
COPY jenkins/id_rsa.pub /etc/spryker/www-data/.ssh/authorized_keys 
COPY jenkins/id_rsa.pub /etc/spryker/jenkins/.ssh/authorized_keys
RUN sed -i '/^#AuthorizedKeysFile/aAuthorizedKeysFile      .ssh/authorized_keys /etc/spryker/%u/.ssh/authorized_keys\nPort 222 ' /etc/ssh/sshd_config  \
 && chmod 600 /etc/spryker/www-data/.ssh/authorized_keys \
 && chmod 600 /etc/spryker/jenkins/.ssh/authorized_keys \
 && chown www-data:www-data /etc/spryker/www-data/.ssh/authorized_keys \
 && chown jenkins:jenkins /etc/spryker/jenkins/.ssh/authorized_keys

# Add SwiftMailer AWS configuration
COPY application/app_files/MailDependencyProvider.php /etc/spryker/
COPY application/app_files/Mailer.patch /etc/spryker/
COPY application/app_files/localMailer.patch /etc/spryker/
COPY application/app_files/jenkins-job.default.xml.twig /etc/spryker/

#The workaround for Azure 4 min timeout
#RUN mkdir -p /etc/nginx/waiting
#COPY nginx/waiting/waiting_vhost.conf /etc/nginx/waiting/waiting_vhost.conf
#COPY nginx/waiting/nginx_waiting.conf /etc/nginx/nginx_waiting.conf
#RUN chown -R www-data:www-data /etc/nginx

# Run app with entrypoints
ENTRYPOINT ["/tini", "--", "/entrypoint.sh"]

EXPOSE 80 222 443

#STOPSIGNAL SIGQUIT
CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf", "--nodaemon"]
