FROM php:7.2-fpm

# Install tini (init handler)
ADD https://github.com/krallin/tini/releases/download/v0.9.0/tini /tini
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
#    libmysqlclient18    \
    libpq5              \
    libsqlite3-0        \
#    libssh2-php         \
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
    redis-tools         \
    rsync               \
    ssmtp               \
    sudo                \
    supervisor          \
    unzip               \
    vim                 \
    wget                \
    zip                 \
    openssh-server      \
    newrelic-php5       \

  && mkdir /var/run/sshd  \
  && useradd -m -s /bin/bash -d /data jenkins               \
  && echo "jenkins:bigsecretpass" | chpasswd                \
  #Add user to group www-data and to sudoers file
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

# Install PHP redis extension
  && pecl install -o -f redis \
  && rm -rf /tmp/pear \
  && echo "extension=redis.so" > $PHP_INI_DIR/conf.d/docker-php-ext-redis.ini \

# Install jinja2 cli
  && easy_install j2cli \

# Install composerrm -rf /var/lib/apt/lists/
  && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer \

# Remove build requirements for php modules
  && apt-get -qy autoremove \
  && apt-get -qy purge $PHPIZE_DEPS \
  && rm -rf /var/lib/apt/lists/*

# Nginx configuration
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/conf.d/ /etc/nginx/conf.d/
COPY nginx/sites-available/ /etc/nginx/sites-available/
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

# Sending email configuration
COPY ssmtp/ssmtp.conf.j2 /etc/ssmtp/ssmtp.conf.j2

# supervisord configuration
COPY supervisord.conf /etc/supervisor/supervisord.conf

# Prepare application
ARG GITHUB_TOKEN

RUN install -d -o www-data -g www-data -m 0755 /data /var/www
RUN mkdir -p /data/data/DE/logs
RUN mkdir -p /versions
RUN chown -R www-data:www-data /data

WORKDIR /data
COPY entrypoint.sh /entrypoint.sh
COPY spryker/config_local.php /config_local.php
COPY spryker/config_local_DE.php /config_local_DE.php
COPY spryker/config_local_AT.php /config_local_AT.php
COPY spryker/config_local_US.php /config_local_US.php
COPY spryker/store.php /store.php
COPY spryker/dockersuite_development.yml /dockersuite_development.yml
COPY spryker/dockersuite_staging.yml /dockersuite_staging.yml
COPY spryker/dockersuite_production.yml /dockersuite_production.yml
COPY spryker/dockersuite_restore_state.yml /dockersuite_restore_state.yml
COPY spryker/setup_suite.sh /setup_suite.sh
COPY spryker/setup_ssl.sh /setup_ssl.sh
COPY spryker/vars.j2 /vars.j2
RUN chmod +x /setup_suite.sh

# Add jenkins authorized_keys
RUN mkdir -p /etc/spryker/jenkins/.ssh
COPY jenkins/id_rsa.pub /etc/spryker/jenkins/.ssh/authorized_keys
RUN sed -i '/^#AuthorizedKeysFile/aAuthorizedKeysFile      .ssh/authorized_keys /etc/spryker/%u/.ssh/authorized_keys\nPort 222 ' /etc/ssh/sshd_config  \
 && chmod 600 /etc/spryker/jenkins/.ssh/authorized_keys \
 && chown jenkins:jenkins /etc/spryker/jenkins/.ssh/authorized_keys
RUN sed -i '/chown\ jenkins/a[[ ! -z "$JENKINS_PUB_SSH_KEY" ]] && echo "$JENKINS_PUB_SSH_KEY" > /etc/spryker/jenkins/.ssh/authorized_keys || echo "SSH key variable is not found. User Jenkins will use default SSH key."' /entrypoint.sh

# Add SwiftMailer AWS configuration
COPY application/app_files/MailDependencyProvider.php /etc/spryker/
COPY application/app_files/Mailer.patch /etc/spryker/
COPY application/app_files/Cronjobs.patch /etc/spryker/

#The workaround for Azure 4 min timeout
#RUN mkdir -p /etc/nginx/waiting
#COPY nginx/waiting/waiting_vhost.conf /etc/nginx/waiting/waiting_vhost.conf
#COPY nginx/waiting/nginx_waiting.conf /etc/nginx/nginx_waiting.conf
#RUN chown -R www-data:www-data /etc/nginx

# Run app with entrypoints
ENTRYPOINT ["/tini", "--", "/entrypoint.sh"]

EXPOSE 8080 8081 222

#STOPSIGNAL SIGQUIT
CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf", "--nodaemon"]
