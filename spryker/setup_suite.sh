#!/usr/bin/env bash

#Create the current build folder in the /versions
curdate=(`date +%Y-%m-%d_%H-%M`)
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
#git clone https://sprykerbot:$GITHUB_TOKEN@github.com/spryker/suite.git ./
git clone https://github.com/spryker-shop/suite.git ./
git checkout master

# Copy maintenance page
rm -rf /maintenance
cp -r ${APPLICATION_PATH}/public/Zed/maintenance /maintenance

# Swift Mailer AWS configuration
if [ $SMTP_HOST != "127.0.0.1" ]
     then
#        cp /etc/spryker/MailDependencyProvider.php src/Pyz/Zed/Mail/MailDependencyProvider.php
      if [ -f ./src/Pyz/Zed/Mail/MailDependencyProvider.php -a -f /etc/spryker/Mailer.patch ]; then
        patch -p0  ./src/Pyz/Zed/Mail/MailDependencyProvider.php < /etc/spryker/Mailer.patch
      fi
fi

# Install all modules for Spryker
##sudo mkdir -p ~/.composer
##sudo touch ~/.composer/auth.json
##sudo echo '{ "http-basic": {}, ' >  ~/.composer/auth.json
##sudo echo "\"github-oauth\": { \"github.com\": \"$GITHUB_TOKEN\"}}" >>  ~/.composer/auth.json
composer global require hirak/prestissimo
composer install
composer require aws/aws-sdk-php

# Enable PGPASSWORD for non-interactive working with PostgreSQL
export PGPASSWORD=$POSTGRES_PASSWORD
# Kill all others connections/sessions to the PostgreSQL DE DB for avoiding an error in the next command
psql --username=$POSTGRES_USER --host=$POSTGRES_HOST DE_${APPLICATION_ENV}_zed -c 'SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE datname = current_database() AND pid <> pg_backend_pid();'
# Drop the current PostgreSQL DE DB and create the empty one
dropdb --username=$POSTGRES_USER --host=$POSTGRES_HOST DE_${APPLICATION_ENV}_zed
createdb --username=$POSTGRES_USER --host=$POSTGRES_HOST DE_${APPLICATION_ENV}_zed
# Kill all others connections/sessions to the PostgreSQL AT DB for avoiding an error in the next command
psql --username=$POSTGRES_USER --host=$POSTGRES_HOST AT_${APPLICATION_ENV}_zed -c 'SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE datname = current_database() AND pid <> pg_backend_pid();'
# Drop the current PostgreSQL AT DB and create the empty one
dropdb --username=$POSTGRES_USER --host=$POSTGRES_HOST AT_${APPLICATION_ENV}_zed
createdb --username=$POSTGRES_USER --host=$POSTGRES_HOST AT_${APPLICATION_ENV}_zed
# Kill all others connections/sessions to the PostgreSQL US DB for avoiding an error in the next command
psql --username=$POSTGRES_USER --host=$POSTGRES_HOST US_${APPLICATION_ENV}_zed -c 'SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE datname = current_database() AND pid <> pg_backend_pid();'
# Drop the current PostgreSQL US DB and create the empty one
dropdb --username=$POSTGRES_USER --host=$POSTGRES_HOST US_${APPLICATION_ENV}_zed
createdb --username=$POSTGRES_USER --host=$POSTGRES_HOST US_${APPLICATION_ENV}_zed


# Clean all Redis data
redis-cli -h $REDIS_HOST flushall

# Delete all indexes of the Elasticsearch
curl -XDELETE $ELASTICSEARCH_HOST:$ELASTICSEARCH_PORT/*

# Copy config_local.php and config_local_<STORE>.php configs
cp /config_local.php config/Shared/config_local.php
cp /config_local_DE.php config/Shared/config_local_DE.php
cp /config_local_AT.php config/Shared/config_local_AT.php
cp /config_local_US.php config/Shared/config_local_US.php
#Copy store.php which fixed the multistore issue
##cp /store.php config/Shared/store.php
#Copy [production|staging|development].yml only if it doesn't exist
test -f config/install/${APPLICATION_ENV:-staging}.yml || cp /dockersuite_${APPLICATION_ENV:-staging}.yml config/install/${APPLICATION_ENV:-staging}.yml

# Full app install
vendor/bin/install -vvv

sudo chown -R www-data:www-data $APPLICATION_PATH
sudo chmod -R g+w $APPLICATION_PATH/data
OLD_APPLICATION_VERSION=$(readlink /data)
sudo rm -rf /data
ln -s $APPLICATION_PATH /data
sudo rm -rf $OLD_APPLICATION_VERSION
sudo chown jenkins /versions

#Cron jobs generate
updateCronJobs() {
   appHost=$1
   cronJobFile="vendor/spryker/setup/src/Spryker/Zed/Setup/Business/Model/Cronjobs.php"
   if [ -f ${cronJobFile} ]; then
      cd $APPLICATION_PATH
      ## remove it after march release 
      sed -i 's/\\\$destination_release_dir/$destination_release_dir/g' ${cronJobFile}
      ##
      sed -i 's/\$PHP_BIN//g' config/Zed/cronjobs/jobs.php
      patch -p0 < /etc/spryker/Cronjobs.patch
      sed -i "s/appHost/${appHost}/g" ${cronJobFile}
      vendor/bin/console setup:jenkins:generate
   fi
}

# if local build
if [ "${ZED_HOST}" == "os.de.demoshop.local" ]; then
   updateCronJobs "app"
# if build run  on an AWS instance 
elif $(nc -znw 2 169.254.169.254 80); then
   instance_ip=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
   updateCronJobs ${instance_ip}
fi

echo $APPLICATION_PATH > /versions/latest_successful_build

echo "Spryker shop suite has been successfully installed"
echo "You could get it with the next links:"
echo "Frontend DE (Yves): http://www.de.$DOMAIN_NAME"
echo "Frontend AT (Yves): http://www.at.$DOMAIN_NAME"
echo "Frontend US (Yves): http://www.us.$DOMAIN_NAME"
echo "Backend DE  (Zed): http://os.de.$DOMAIN_NAME"
echo "Backend AT  (Zed): http://os.at.$DOMAIN_NAME"
echo "Backend US  (Zed): http://os.us.$DOMAIN_NAME"
echo "Jenkins        : http://os.de.$DOMAIN_NAME:9090"
echo "RabbitMQ       : http://os.de.$DOMAIN_NAME:15672"
