#!/bin/bash -x

#cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bk
#cp /etc/nginx/nginx_waiting.conf /etc/nginx/nginx.conf

# Update Yves and Zed Nginx configuration files with the correct domain names
##j2 /etc/nginx/conf.d/vhost-yves.conf.j2 > /etc/nginx/conf.d/vhost-yves.conf
##j2 /etc/nginx/conf.d/vhost-zed.conf.j2 > /etc/nginx/conf.d/vhost-zed.conf
##j2 /etc/nginx/conf.d/vhost-glue.conf.j2 > /etc/nginx/conf.d/vhost-glue.conf
j2 /etc/nginx/sites-available/de-vhost-yves.conf.j2 > /etc/nginx/sites-available/de-vhost-yves.conf
j2 /etc/nginx/sites-available/de-vhost-zed.conf.j2 > /etc/nginx/sites-available/de-vhost-zed.conf
j2 /etc/nginx/sites-available/de-vhost-glue.conf.j2 > /etc/nginx/sites-available/de-vhost-glue.conf
j2 /etc/nginx/sites-available/at-vhost-yves.conf.j2 > /etc/nginx/sites-available/at-vhost-yves.conf
j2 /etc/nginx/sites-available/at-vhost-zed.conf.j2 > /etc/nginx/sites-available/at-vhost-zed.conf
j2 /etc/nginx/sites-available/at-vhost-glue.conf.j2 > /etc/nginx/sites-available/at-vhost-glue.conf
ln -s /etc/nginx/sites-available/de-vhost-yves.conf /etc/nginx/sites-enabled/de-vhost-yves.conf
ln -s /etc/nginx/sites-available/de-vhost-zed.conf /etc/nginx/sites-enabled/de-vhost-zed.conf
ln -s /etc/nginx/sites-available/de-vhost-glue.conf /etc/nginx/sites-enabled/de-vhost-glue.conf
ln -s /etc/nginx/sites-available/at-vhost-yves.conf /etc/nginx/sites-enabled/at-vhost-yves.conf
ln -s /etc/nginx/sites-available/at-vhost-zed.conf /etc/nginx/sites-enabled/at-vhost-zed.conf
ln -s /etc/nginx/sites-available/at-vhost-glue.conf /etc/nginx/sites-enabled/at-vhost-glue.conf

/usr/sbin/nginx -g 'daemon on;' &

# Enable maintenance mode
touch /maintenance_on.flag

# Enable PGPASSWORD for non-interactive working with PostgreSQL if PGPASSWORD is not set
export PGPASSWORD=$POSTGRES_PASSWORD
# Waiting for PostgreSQL database starting
until psql -h $POSTGRES_HOST -p "$POSTGRES_PORT" -U "$POSTGRES_USER" $POSTGRES_DATABASE -c '\l'; do
  echo "Waiting for PostgreSQL..."
  sleep 3
done
echo "PostgreSQL is available now. Good."

# Waiting for the Elasticsearch starting
until curl -s "$ELASTICSEARCH_HOST:$ELASTICSEARCH_PORT" > /dev/null; do
  echo "Waiting for Elasticsearch..."
  sleep 3
done
echo "Elasticsearch is available now. Good."

# Waiting for the RabbitMQ starting
until curl -s "$RABBITMQ_HOST:$RABBITMQ_API_PORT" > /dev/null; do
  echo "Waiting for RabbitMQ..."
  sleep 3
done
echo "RabbitMQ is available now. Good."

# Become more verbose
set -xe

# Put env variables to /versions/vars file for using it in Jenkins jobs
j2 /vars.j2 > /versions/vars

# Install NewRelic php app monitoring
echo $NEWRELIC_KEY | sudo newrelic-install install

# Configure PHP
j2 /usr/local/etc/php/php.ini.j2 > /usr/local/etc/php/php.ini 

# Configure SSMTP
j2 /etc/ssmtp/ssmtp.conf.j2 > /etc/ssmtp/ssmtp.conf

# Put Zed host IP to /etc/hosts file:
echo "127.0.0.1	$ZED_HOST" >> /etc/hosts

#"To build or not to build"
if [ -f /versions/latest_successful_build ]; then
     source  /versions/vars
     APPLICATION_PATH=$(cat /versions/latest_successful_build)
     if [ -L /data ]; then
       echo "An application link already exist"
     else
       sudo rm -rf /data
       ln -s $APPLICATION_PATH /data
     fi
     cd /data
     cp /dockersuite_restore_state.yml config/install/${APPLICATION_ENV:-staging}.yml
     vendor/bin/install -vvv
     chown -R www-data:www-data /data/
else
      /setup_suite.sh
      # Disable maintenance mode to validate LetsEncrypt certificates
      test -f /maintenance_on.flag && rm /maintenance_on.flag
      bash /setup_ssl.sh ${YVES_HOST//www./} $(curl http://checkip.amazonaws.com/ -s) &
fi
#cp /etc/nginx/nginx.conf.bk /etc/nginx/nginx.conf
killall -9 nginx

supervisorctl restart php-fpm
supervisorctl restart nginx

# Unset maintenance flag
test -f /maintenance_on.flag && rm /maintenance_on.flag

chown -R www-data:www-data /data
chown jenkins /versions/

# Call command...
exec $*
