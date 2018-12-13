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
        mailConfigurationFile="src/Pyz/Zed/Mail/MailDependencyProvider.php"
        glossaryFile="data/import/glossary.csv"

        if [ grep -Fq "addMailer" $mailConfigurationFile ]
            then
                echo "Swift configuration alredy exist"
            else
                echo no
                sed -i '/ provideBusinessLayerDependencies/ {
                r /etc/ssmtp/swiftMailer.conf
                N
                }' $mailConfigurationFile
                sed -i '/Mail\\OrderShippedMailTypePlugin/a use Spryker\\Zed\\Mail\\Dependency\\Mailer\\MailToMailerBridge;\nuse Swift_Mailer;\nuse Swift_Message;\nuse Swift_SmtpTransport;\n' $mailConfigurationFile
        fi
        if [ -f $glossaryFile ]
           then
                sed -i -e 's/demoshop@spryker.com/no-replay@demo-spryker.com/g' -e 's/demoshop@spryker.de/no-replay@demo-spryker.com/g' $glossaryFile
           else
                echo "The glossary.csv file does not exist"
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
# Kill all others connections/sessions to the PostgreSQL for avoiding an error in the next command
psql --username=$POSTGRES_USER --host=$POSTGRES_HOST $POSTGRES_DATABASE -c 'SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE datname = current_database() AND pid <> pg_backend_pid();'
# Drop the current PostgreSQL db and create the empty one
dropdb --username=$POSTGRES_USER --host=$POSTGRES_HOST $POSTGRES_DATABASE
createdb --username=$POSTGRES_USER --host=$POSTGRES_HOST $POSTGRES_DATABASE

# Clean all Redis data
redis-cli -h $REDIS_HOST flushall

# Delete all indexes of the Elasticsearch
curl -XDELETE $ELASTICSEARCH_HOST:$ELASTICSEARCH_PORT/*

# Copy config_local.php config
cp /config_local.php config/Shared/config_local.php
#Copy store.php which fixed the multistore issue
cp /store.php config/Shared/store.php
#Copy store.php which fixed the multistore issue
cp /dockersuite.yml config/install/$APPLICATION_ENV.yml

# Full app install
vendor/bin/install -vvv

sudo chown -R www-data:www-data $APPLICATION_PATH
sudo chmod -R g+w $APPLICATION_PATH/data
OLD_APPLICATION_VERSION=$(readlink /data)
sudo rm -rf /data
ln -s $APPLICATION_PATH /data
sudo rm -rf $OLD_APPLICATION_VERSION
sudo chown jenkins /versions

echo "Spryker shop suite has been successfully installed"
echo "You could get it with the next links:"
echo "Frontend (Yves): http://$YVES_HOST"
echo "Backend   (Zed): http://$ZED_HOST"
