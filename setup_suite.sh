#!/usr/bin/env bash

#Create the current build folder in the /versions
curdate=(`date +%d.%m.%Y-%H.%M`)
APPLICATION_PATH=/versions/$curdate
mkdir -p $APPLICATION_PATH
cd $APPLICATION_PATH

# Avoid ssh dialog question
sudo mkdir ~/.ssh
sudo touch ~/.ssh/known_hosts
sudo chown jenkins  ~/.ssh/known_hosts
sudo ssh-keyscan github.com >> ~/.ssh/known_hosts

# Get Spryker shop suite from the official github repo
##curl -H 'Authorization: token $GITHUB_TOKEN' https://github.com/spryker/suite-nonsplit.git
git clone https://sprykerbot:$GITHUB_TOKEN@github.com/spryker/suite.git ./
git checkout master

# Install all modules for Spryker
##sudo mkdir -p ~/.composer
##sudo touch ~/.composer/auth.json
##sudo echo '{ "http-basic": {}, ' >  ~/.composer/auth.json
##sudo echo "\"github-oauth\": { \"github.com\": \"$GITHUB_TOKEN\"}}" >>  ~/.composer/auth.json
composer global require hirak/prestissimo
composer require aws/aws-sdk-php
composer install

# Enable PGPASSWORD for non-interactive working with PostgreSQL
export PGPASSWORD=$POSTGRES_PASSWORD
# Kill all others connections/sessions to the PostgreSQL for avoiding an error in the next command
psql --username=$POSTGRES_USER --host=$POSTGRES_HOST $POSTGRES_DATABASE -c 'SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE datname = current_database() AND pid <> pg_backend_pid();'
# Drop the current PostgreSQL db and create the empty one
dropdb --username=$POSTGRES_USER --host=$POSTGRES_HOST $POSTGRES_DATABASE
#createdb --username=$POSTGRES_USER --host=$POSTGRES_HOST $POSTGRES_DATABASE

# Clean all Redis data
redis-cli -h $REDIS_HOST flushall

# Delete all indexes of the Elasticsearch
curl -XDELETE $ELASTICSEARCH_HOST:$ELASTICSEARCH_PORT/*

# Copy config_local.php config
cp /versions/config_local.php config/Shared/config_local.php
#Copy store.php which fixed the multistore issue
cp /versions/store.php config/Shared/store.php
#Copy store.php which fixed the multistore issue
cp /versions/dockersuite.yml config/install/dockersuite.yml

# Full app install
vendor/bin/install -vvv

sudo chown -R www-data:www-data $APPLICATION_PATH
sudo chmod -R g+w $APPLICATION_PATH/data
OLD_APPLICATION_VERSION=$(readlink /data)
sudo rm -rf /data
ln -s $APPLICATION_PATH /data
sudo rm -rf $OLD_APPLICATION_VERSION

# Delete installation flag file
rm /data/initialize

echo "Spryker shop suite has been successfully installed"
echo "You could get it with the next links:"
echo "Frontend (Yves): http://$YVES_HOST"
echo "Backend   (Zed): http://$ZED_HOST:8081"
