#!/usr/bin/env bash

#Create the current build folder in the /versions
echo $(date +%Y-%m-%d_%H-%M) | sudo -u jenkins tee /tmp/curdate
export APPLICATION_PATH=/versions/$(cat /tmp/curdate)
mkdir -p  -m775 ${APPLICATION_PATH}
cd $APPLICATION_PATH

# Add composer cache link
mkdir -p /data/.composer
[ ! -L /data/.composer/cache ] && ln -s  /var/cache/composer /data/.composer/cache

# Get Spryker shop suite from the official github repo
##curl -H 'Authorization: token $GITHUB_TOKEN' https://github.com/spryker/suite-nonsplit.git
#git clone https://sprykerbot:$GITHUB_TOKEN@github.com/spryker/suite.git ./
git clone  ${INITIAL_SPRYKER_REPOSITORY} ./
git checkout ${INITIAL_SPRYKER_BRANCH}

# Copy maintenance page
rm -rf /maintenance
cp -r ${APPLICATION_PATH}/public/Zed/maintenance /maintenance
# Enable maintenance mode
sudo -u jenkins touch /tmp/maintenance_on.flag

mailerPatch(){
  patchName=$1
  if [ -f ./src/Pyz/Zed/Mail/MailDependencyProvider.php -a -f /etc/spryker/${patchName}.patch ]; then
    patch -p0  ./src/Pyz/Zed/Mail/MailDependencyProvider.php < /etc/spryker/${patchName}.patch
  fi
}
# Swift Mailer AWS configuration
if [ $SMTP_HOST == "mailhog" ]; then
    mailerPatch localMailer
else
   mailerPatch Mailer
fi

# Install all modules for Spryker
##sudo mkdir -p ~/.composer
##sudo touch ~/.composer/auth.json
##sudo echo '{ "http-basic": {}, ' >  ~/.composer/auth.json
##sudo echo "\"github-oauth\": { \"github.com\": \"$GITHUB_TOKEN\"}}" >>  ~/.composer/auth.json
export COMPOSER_MEMORY_LIMIT=-1
composer global require hirak/prestissimo
composer install
composer require --no-update aws/aws-sdk-php

# Enable PGPASSWORD for non-interactive working with PostgreSQL
export PGPASSWORD=$POSTGRES_PASSWORD

#Parse string STORES to the array of country names STORE
IFS=',' read -ra STORE <<< "${STORES}"
#Create the Nginx virtualhost for each store
for i in "${STORE[@]}"; do
    export XX=$i
    export xx=$(echo $i | tr [A-Z] [a-z])
    # Kill all others connections/sessions to the PostgreSQL DB for avoiding an error in the next command
    psql --username=${POSTGRES_USER} --host=${POSTGRES_HOST} postgres -c "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE datname = '${ENV_NAME}_${XX}' AND pid <> pg_backend_pid();"
    # Drop the current PostgreSQL DB and create the empty one
    dropdb --if-exists --username=${POSTGRES_USER} --host=${POSTGRES_HOST} ${ENV_NAME}_${XX}
    createdb --username=${POSTGRES_USER} --host=${POSTGRES_HOST} ${ENV_NAME}_${XX}

    # Create Spryker config_local_XX.php store config from the jinja2 template
    j2 /etc/spryker/config_local_XX.php.j2 > config/Shared/config_local_${XX}.php
done

# Clean hardcoded AT/DE/US stores import data if the store doesn't exist
for store in AT US DE; do
if [[ "${STORES}" != *"${store}"* ]]; then
   echo -e "\nClean hardcoded ${store} import data\n"
   for file in $(find ./ -type f -regex ".*/data/import/.*.csv" -exec grep -nEo "[\.\,\:\ ]${store}([\.\,\:\ ]|$)" {} + | cut -d: -f1-2| sort -Vru ); do sed -i -e ${file#*:*}d ${file%:*};done
   rm config/Shared/*_${store}.php
fi
done

# Create Spryker main config config_local.php from the jinja2 template
j2 /etc/spryker/config_local.php.j2 /etc/spryker/stores.yml -o config/Shared/config_local.php

# Create the frontend config frontend-build-config.json from the jinja2 template
j2 /etc/spryker/frontend-build-config.json.j2 /etc/spryker/stores.yml -o config/Yves/frontend-build-config.json

# Create the Stock config StockConfig.php from the jinja2 template
j2 /etc/spryker/StockConfig.php.j2 /etc/spryker/stores.yml -o src/Pyz/Zed/Stock/StockConfig.php

#Copy stores.php which fixed the multistore hardcoded data
if [[ "${STORES}" == "DE" ]]; then
    cp /etc/spryker/stores.php config/Shared/stores.php
fi

# Hack for config_default.php and REDIS_HOST/PORT
sed -r -i -e "s/($config\[StorageRedisConstants::STORAGE_REDIS_HOST\]\s*=\s*).*/\1getenv('REDIS_HOST');/g" config/Shared/config_default.php
sed -r -i -e "s/($config\[StorageRedisConstants::STORAGE_REDIS_PORT\]\s*=\s*).*/\16379;/g" config/Shared/config_default.php

#Prepare [production|staging|development].yml only if it doesn't exist
if [ ! -f config/install/${APPLICATION_ENV:-staging}.yml ]; then
    j2 /etc/spryker/install_spryker.yml.j2 /etc/spryker/stores.yml -o config/install/${APPLICATION_ENV:-staging}.yml
fi
#Prepare restore_spryker_state.yml (only if it doesn't exist) for future restoring shop after the container restart
if [ ! -f config/install/restore_spryker_state.yml ]; then
    j2 /etc/spryker/restore_spryker_state.yml.j2 /etc/spryker/stores.yml -o config/install/restore_spryker_state.yml
fi

#npm cache clean --force

#vendor/bin/console propel:install

# Full app install
vendor/bin/install -vvv

#Optimize autoloader which creates a map with all classes and their locations
composer dumpautoload -o

# Post build script

OLD_APPLICATION_VERSION=$(readlink /data)

# Put robots.txt file for avoiding indexing
cp /etc/nginx/robots.txt public/Yves/robots.txt
cp /etc/nginx/robots.txt public/Zed/robots.txt
cp /etc/nginx/robots.txt public/Glue/robots.txt
cp /etc/nginx/robots.txt public/Driver/robots.txt

# Swift Mailer AWS configuration
if [ -f ./src/Pyz/Zed/Mail/MailDependencyProvider.php -a -f /etc/spryker/Mailer.patch ]; then
      patch -p0  ./src/Pyz/Zed/Mail/MailDependencyProvider.php < /etc/spryker/Mailer.patch
fi

chmod -R g+w $APPLICATION_PATH/data
sudo chown -R www-data:www-data $APPLICATION_PATH
sudo chmod 600 config/Zed/*.key
sudo rm -rf /data
sudo ln -s $APPLICATION_PATH /data
sudo rm -rf $OLD_APPLICATION_VERSION

echo $APPLICATION_PATH | sudo -u jenkins tee /versions/latest_successful_build

# Disable maintenance mode
sudo supervisorctl restart php-fpm
rm /tmp/maintenance_on.flag

# Print output text with the setup results
j2 /etc/spryker/setup_output.j2 /etc/spryker/stores.yml

# Remove time stamp
rm -rf /tmp/curdate
