#!/bin/bash -x

cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bk
cp /etc/nginx/nginx_waiting.conf /etc/nginx/nginx.conf
/usr/sbin/nginx -g 'daemon on;' &

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

# Update Yves and Zed Nginx configuration files with the correct domain names
j2 /etc/nginx/conf.d/vhost-yves.conf.j2 > /etc/nginx/conf.d/vhost-yves.conf
j2 /etc/nginx/conf.d/vhost-zed.conf.j2 > /etc/nginx/conf.d/vhost-zed.conf
j2 /etc/nginx/conf.d/vhost-glue.conf.j2 > /etc/nginx/conf.d/vhost-glue.conf

# Put Zed host IP to /etc/hosts file:
echo "127.0.0.1	$ZED_HOST" >> /etc/hosts

if [ -f /data/initialize ]
then
    /setup_suite.sh
fi

# Save environment variable to the env.txt for remote Jenkins jobs
##env > /data/deploy/docker/env.txt

cp /etc/nginx/nginx.conf.bk /etc/nginx/nginx.conf
killall -9 nginx

chown -R www-data:www-data /data

# Call command...
exec $*