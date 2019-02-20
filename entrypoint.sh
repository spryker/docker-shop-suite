#!/bin/bash -x

# Update Yves, Zed and Glue Nginx and PHP configuration files with the correct environment variables
j2 /etc/nginx/conf.d/backends.conf.j2 > /etc/nginx/conf.d/backends.conf
j2 /usr/local/etc/php-fpm.d/yves.conf.j2 > /usr/local/etc/php-fpm.d/yves.conf
j2 /usr/local/etc/php-fpm.d/zed.conf.j2 > /usr/local/etc/php-fpm.d/zed.conf
j2 /usr/local/etc/php-fpm.d/glue.conf.j2 > /usr/local/etc/php-fpm.d/glue.conf
j2 /etc/nginx/conf.d/backends.conf.j2 > /etc/nginx/conf.d/backends.conf
j2 /etc/nginx/sites-available/de-vhost-yves.conf.j2 > /etc/nginx/sites-available/de-vhost-yves.conf
j2 /etc/nginx/sites-available/de-vhost-zed.conf.j2 > /etc/nginx/sites-available/de-vhost-zed.conf
j2 /etc/nginx/sites-available/de-vhost-glue.conf.j2 > /etc/nginx/sites-available/de-vhost-glue.conf
j2 /etc/nginx/sites-available/at-vhost-yves.conf.j2 > /etc/nginx/sites-available/at-vhost-yves.conf
j2 /etc/nginx/sites-available/at-vhost-zed.conf.j2 > /etc/nginx/sites-available/at-vhost-zed.conf
j2 /etc/nginx/sites-available/at-vhost-glue.conf.j2 > /etc/nginx/sites-available/at-vhost-glue.conf
j2 /etc/nginx/sites-available/us-vhost-yves.conf.j2 > /etc/nginx/sites-available/us-vhost-yves.conf
j2 /etc/nginx/sites-available/us-vhost-zed.conf.j2 > /etc/nginx/sites-available/us-vhost-zed.conf
j2 /etc/nginx/sites-available/su-vhost-glue.conf.j2 > /etc/nginx/sites-available/us-vhost-glue.conf
ln -s /etc/nginx/sites-available/de-vhost-yves.conf /etc/nginx/sites-enabled/de-vhost-yves.conf
ln -s /etc/nginx/sites-available/de-vhost-zed.conf /etc/nginx/sites-enabled/de-vhost-zed.conf
ln -s /etc/nginx/sites-available/de-vhost-glue.conf /etc/nginx/sites-enabled/de-vhost-glue.conf
ln -s /etc/nginx/sites-available/at-vhost-yves.conf /etc/nginx/sites-enabled/at-vhost-yves.conf
ln -s /etc/nginx/sites-available/at-vhost-zed.conf /etc/nginx/sites-enabled/at-vhost-zed.conf
ln -s /etc/nginx/sites-available/at-vhost-glue.conf /etc/nginx/sites-enabled/at-vhost-glue.conf
ln -s /etc/nginx/sites-available/us-vhost-yves.conf /etc/nginx/sites-enabled/us-vhost-yves.conf
ln -s /etc/nginx/sites-available/us-vhost-zed.conf /etc/nginx/sites-enabled/us-vhost-zed.conf
ln -s /etc/nginx/sites-available/us-vhost-glue.conf /etc/nginx/sites-enabled/us-vhost-glue.conf

/usr/sbin/nginx -g 'daemon on;' &

# Enable maintenance mode
touch /maintenance_on.flag

# Enable PGPASSWORD for non-interactive working with PostgreSQL if PGPASSWORD is not set
export PGPASSWORD=$POSTGRES_PASSWORD
# Waiting for PostgreSQL database starting
until psql -h $POSTGRES_HOST -p "$POSTGRES_PORT" -U "$POSTGRES_USER" DE_${APPLICATION_ENV}_zed -c '\l'; do
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
echo "127.0.0.1   os.de.${DOMAIN_NAME} os.at.${DOMAIN_NAME} os.us.${DOMAIN_NAME}" >> /etc/hosts

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
      #Create additional RabbitMQ Vhosts:
      curl -i -u $RABBITMQ_USER:$RABBITMQ_PASSWORD -H "content-type:application/json" -XPUT http://${RABBITMQ_HOST}:15672/api/vhosts/%2FAT_staging_zed
      curl -i -u $RABBITMQ_USER:$RABBITMQ_PASSWORD -H "content-type:application/json" -XPUT http://${RABBITMQ_HOST}:15672/api/vhosts/%2FUS_staging_zed
      #Deploy Spryker Shop
      /setup_suite.sh
      # Disable maintenance mode to validate LetsEncrypt certificates
      test -f /maintenance_on.flag && rm /maintenance_on.flag
      bash /setup_ssl.sh de.${DOMAIN_NAME} $(curl http://checkip.amazonaws.com/ -s) &
      bash /setup_ssl.sh at.${DOMAIN_NAME} $(curl http://checkip.amazonaws.com/ -s) &
      bash /setup_ssl.sh us.${DOMAIN_NAME} $(curl http://checkip.amazonaws.com/ -s) &
fi

killall -9 nginx
supervisorctl restart php-fpm
supervisorctl restart nginx

# Unset maintenance flag
test -f /maintenance_on.flag && rm /maintenance_on.flag

chown -R www-data:www-data /data
chown jenkins /versions/

# Call command...
exec $*
