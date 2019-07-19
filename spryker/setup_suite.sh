#!/usr/bin/env bash

#Create the current build folder in the /versions
curdate=(`date +%Y-%m-%d_%H-%M`)
APPLICATION_PATH=/versions/$curdate
store_yml="stores:\n"
mkdir -p $APPLICATION_PATH
cd $APPLICATION_PATH

# Avoid ssh dialog question
sudo mkdir ~/.ssh
sudo touch ~/.ssh/known_hosts
sudo chown www-data  ~/.ssh/known_hosts
sudo ssh-keyscan github.com >> ~/.ssh/known_hosts

# Get Spryker shop suite from the official github repo
##curl -H 'Authorization: token $GITHUB_TOKEN' https://github.com/spryker/suite-nonsplit.git
#git clone https://sprykerbot:$GITHUB_TOKEN@github.com/spryker/suite.git ./
git clone https://github.com/spryker-shop/suite.git ./
git checkout master

# Copy maintenance page
rm -rf /maintenance
cp -r ${APPLICATION_PATH}/public/Zed/maintenance /maintenance
# Enable maintenance mode
sudo touch /maintenance_on.flag

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
export COMPOSER_MEMORY_LIMIT=-1
composer global require hirak/prestissimo
composer install
composer require aws/aws-sdk-php

# Enable PGPASSWORD for non-interactive working with PostgreSQL
export PGPASSWORD=$POSTGRES_PASSWORD

#Parse string STORES to the array of country names STORE
IFS=',' read -ra STORE <<< "${STORES}"
#Create the Nginx virtualhost for each store
for i in "${STORE[@]}"; do
    export XX=$i
    export xx=$(echo $i | tr [A-Z] [a-z])
    # Kill all others connections/sessions to the PostgreSQL DB for avoiding an error in the next command
    psql --username=${POSTGRES_USER} --host=${POSTGRES_HOST} ${XX}_${APPLICATION_ENV}_zed -c 'SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE datname = current_database() AND pid <> pg_backend_pid();'
    # Drop the current PostgreSQL DB and create the empty one
    dropdb --if-exists --username=${POSTGRES_USER} --host=${POSTGRES_HOST} ${XX}_${APPLICATION_ENV}_zed
    createdb --username=${POSTGRES_USER} --host=${POSTGRES_HOST} ${XX}_${APPLICATION_ENV}_zed

    # Create Spryker config_local_XX.php store config from the jinja2 template
    j2 /config_local_XX.php.j2 > config/Shared/config_local_${XX}.php

    store_yml="${store_yml}  - ${XX}\n"
done
cp /config_local.php config/Shared/config_local.php
#Copy store.php which fixed the multistore issue
##cp /store.php config/Shared/store.php

# Clean all Redis data
redis-cli -h $REDIS_HOST flushall

# Delete all indexes of the Elasticsearch
curl -XDELETE $ELASTICSEARCH_HOST:$ELASTICSEARCH_PORT/*

#Prepare [production|staging|development].yml only if it doesn't exist
if [ ! -f config/install/${APPLICATION_ENV:-staging}.yml ]; then
    cp config/install/docker.yml /tmp/install_config_buf.yml
    sed -i -r "/env:/,/sections:/d" /tmp/install_config_buf.yml
    cat <<EOF > config/install/${APPLICATION_ENV:-staging}.yml
env:
    APPLICATION_ENV: ${APPLICATION_ENV:-staging}

stores:
${store_yml}
sections:
EOF
    cat  /tmp/install_config_buf.yml >> config/install/${APPLICATION_ENV:-staging}.yml
fi

test -f config/install/${APPLICATION_ENV:-staging}.yml || cp config/install/docker.yml config/install/${APPLICATION_ENV:-staging}.yml

# Delete all default stores, but with `stores:` and `sections:` lines which need to be returned
sed -i -r "/env:/,/sections:/d" config/install/${APPLICATION_ENV:-staging}.yml
echo "env:" > config/install/${APPLICATION_ENV:-staging}.yml
echo "    APPLICATION_ENV: ${APPLICATION_ENV:-staging}" >> config/install/${APPLICATION_ENV:-staging}.yml
echo "" >> config/install/${APPLICATION_ENV:-staging}.yml
echo "stores:" >> config/install/${APPLICATION_ENV:-staging}.yml
echo ${store_yml} >> config/install/${APPLICATION_ENV:-staging}.yml
echo "" >> config/install/${APPLICATION_ENV:-staging}.yml
echo "sections:" >> config/install/${APPLICATION_ENV:-staging}.yml



# Hack for config_default.php and REDIS_HOST/PORT
sed -r -i -e "s/($config\[StorageRedisConstants::STORAGE_REDIS_HOST\]\s*=\s*).*/\1getenv('REDIS_HOST');/g" config/Shared/config_default.php
sed -r -i -e "s/($config\[StorageRedisConstants::STORAGE_REDIS_PORT\]\s*=\s*).*/\16379;/g" config/Shared/config_default.php

#npm cache clean --force

# Full app install
vendor/bin/install -vvv

sudo chown -R www-data:www-data $APPLICATION_PATH
sudo chmod -R g+w $APPLICATION_PATH/data
OLD_APPLICATION_VERSION=$(readlink /data)
sudo rm -rf /data
ln -s $APPLICATION_PATH /data
sudo rm -rf $OLD_APPLICATION_VERSION
sudo chown www-data /versions

echo $APPLICATION_PATH > /versions/latest_successful_build

# Disable maintenance mode
rm /maintenance_on.flag

echo "Spryker shop has been successfully installed"
echo "You could get it with the next links:"
#Parse string STORES to the array of country names STORE
IFS=',' read -ra STORE <<< "${STORES}"
#Create the Nginx virtualhost for each store
for i in "${STORE[@]}"; do
    export XX=$i
    export xx=$(echo $i | tr [A-Z] [a-z])
    echo "Frontend ${XX} (Yves): http://www.${xx}.${DOMAIN_NAME}"
    echo "Backend ${XX}   (Zed): http://os.${xx}.${DOMAIN_NAME}"
    echo "API ${XX}      (Glue): http://glue.${xx}.${DOMAIN_NAME}"
done
echo "Jenkins                : http://os.$(echo ${STORE[0]} | tr [A-Z] [a-z]).${DOMAIN_NAME}:9090"
echo "RabbitMQ               : http://os.$(echo ${STORE[0]} | tr [A-Z] [a-z]).${DOMAIN_NAME}:15672"
