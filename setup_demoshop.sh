#!/usr/bin/env bash

APPLICATION_PATH=/data
cd $APPLICATION_PATH

# Get Spryker demoshop from the official github repo
wget https://github.com/spryker/demoshop/archive/master.tar.gz
tar --strip-components=1  -xzf master.tar.gz -C ./
rm master.tar.gz

# Install all modules for Spryker
composer install

# Enable PGPASSWORD for non-interactive working with PostgreSQL
export PGPASSWORD=$POSTGRES_PASSWORD
# Kill all others connections/sessions to the PostgreSQL for avoiding an error in the next command
psql --username=$POSTGRES_USER --host=$POSTGRES_HOST $POSTGRES_DATABASE -c 'SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE datname = current_database() AND pid <> pg_backend_pid();'
# Drop the current PostgreSQL db and create the empty one
dropdb --username=$POSTGRES_USER --host=$POSTGRES_HOST $POSTGRES_DATABASE
createdb --username=$POSTGRES_USER --host=$POSTGRES_HOST $POSTGRES_DATABASE

# Clean all Redis data
redis-cli -h $REDIS_HOST flushall

# Delete the de_search index of the Elasticsearch
curl -XDELETE $ELASTICSEARCH_HOST:$ELASTICSEARCH_PORT/de_search

# Copy the config_local.php config
cp config_local.php config/Shared/config_local.php

#Copy store.php which fixed the multistore issue
cp store.php config/Shared/store.php

# Full app install
vendor/bin/console setup:install

# Import demo data
vendor/bin/console data:import

# Update product label relation
##vendor/bin/console product-label:relations:update

# Run collectors
vendor/bin/console collector:search:export
vendor/bin/console collector:storage:export

# Setup Jenkins cronjobs
##vendor/bin/console setup:jenkins:enable
##vendor/bin/console setup:jenkins:generate

# Install front-end
npm install
for module in braintree; do
  (cd /data/vendor/spryker/${module}/assets/Yves; npm install)
done
for module in gui discount product-relation; do
  (cd /data/vendor/spryker/${module}/assets/Zed; npm install)
done
npm run yves
npm run zed

rm /data/initialize

echo "Spryker demoshop has been successfully installed"
echo "You could get it with the next links:"
echo "Frontend (Yves): http://$YVES_HOST"
echo "Backend   (Zed): http://$ZED_HOST:8081"
