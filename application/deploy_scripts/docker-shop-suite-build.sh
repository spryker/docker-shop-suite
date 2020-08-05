#!/bin/bash

. /versions/vars
[ -z $DEBUG_ENABLED ] && set -e || set -ex
IFS=',' read -ra STORE <<< "${STORES}"

help(){
    echo "You need to run the script with one of the options: pre_deploy or post_deploy resetStorages startDeploy endDeploy "
    echo "Example: $0 pre_deploy"
}

resetStorages(){
  [ $RESET_DB == "true" ] && resetDb
  [ $RESET_ES == "true" ] && resetEs
  [ $RESET_REDIS == "true" ] && resetRedis
}


resetRedis(){
  # Clean all Redis data
  redis-cli -h ${SPRYKER_KEY_VALUE_STORE_HOST} flushall
}

resetEs(){
  # Delete all indexes of the Elasticsearch
  curl -XDELETE ${SPRYKER_SEARCH_HOST}:${SPRYKER_SEARCH_PORT}/*
}

resetDb(){
  for i in "${STORE[@]}"; do
    export XX=$i
    export xx=$(echo $i | tr [A-Z] [a-z])
    # Kill all others connections/sessions to the PostgreSQL DB for avoiding an error in the next command
    psql --username=${SPRYKER_DB_USERNAME} --host=${SPRYKER_DB_HOST} postgres -c "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE datname = '${ENV_NAME}_${XX}' AND pid <> pg_backend_pid();"
    # Drop the current PostgreSQL DB and create the empty one
    dropdb --if-exists --username=${SPRYKER_DB_USERNAME} --host=${SPRYKER_DB_HOST} ${ENV_NAME}_${XX}
    createdb --username=${SPRYKER_DB_USERNAME} --host=${SPRYKER_DB_HOST} ${ENV_NAME}_${XX}
  done
}

preDeploy(){
  echo $(date +%Y-%m-%d_%H-%M) > /tmp/curdate
  export APPLICATION_PATH=/versions/$(cat /tmp/curdate)

  mkdir -p /data/.composer
  [ ! -L /data/.composer/cache ] && ln -s  /var/cache/composer /data/.composer/cache

  # Enable maintenance mode
  #touch /tmp/maintenance_on.flag

  mkdir -p  -m775 ${APPLICATION_PATH}

  sudo chown -R jenkins /var/cache/composer

  #cleanup
  rm -f /tmp/build_completed.flag
}

startDeploy(){
  echo "Start of deploy"
}

endDeploy(){
  echo "End of deplooy"

  #Prepare restore_spryker_state.yml (only if it doesn't exist) for future restoring shop after the container restart
  if [ ! -f config/install/restore_spryker_state.yml ]; then
    j2 /etc/spryker/restore_spryker_state.yml.j2 /etc/spryker/stores.yml -o config/install/restore_spryker_state.yml
  fi

  touch /tmp/build_completed.flag
}

cleanDemodata(){
  # Clean hardcoded AT/DE/US stores import data if the store doesn't exist
  for store in AT US DE; do
  if [[ "${STORES}" != *"${store}"* ]]; then
    echo -e "\nClean hardcoded ${store} import data\n" 
     for file in $(find ./ -type f -regex ".*/data/import/.*.csv" -exec grep -nEo "[\,\:\"\ ]${store}([\.\,\:\"]|$)" {} + | cut -d: -f1-2| sort -Vru ); do sed -i -e ${file#*:*}d ${file%:*};done
    rm config/Shared/*_${store}.php
  fi
  done
}

createConfigs(){
  cp config/install/docker.yml config/install/staging.yml
  sed -i -e 's/APPLICATION_ENV: docker/APPLICATION_ENV: staging/g' config/install/staging.yml

  for store in "${STORE[@]}"; do
    cp config/Shared/config_default-docker.php config/Shared/config_default-staging_$store.php
    for storeVar in $PER_STORE_VAR ; do
      sed -i -e "s/${storeVar}/${storeVar}_${store}/g" config/Shared/config_default-staging_${store}.php
    done
  done
}

postDeploy(){
  export APPLICATION_PATH=/versions/$(cat /tmp/curdate)
  cd ${APPLICATION_PATH}
  if [ -L /data ]; then
    OLD_APPLICATION_VERSION=$(readlink /data)
  else
    OLD_APPLICATION_VERSION=/data
  fi

  # Put robots.txt file for avoiding indexing
  cp /etc/nginx/robots.txt public/Yves/robots.txt
  cp /etc/nginx/robots.txt public/Zed/robots.txt
  cp /etc/nginx/robots.txt public/Glue/robots.txt

  chmod -R g+w $APPLICATION_PATH/data
  sudo chown -R www-data:www-data $APPLICATION_PATH
  [ -f $APPLICATION_PATH/composer.json ] && sudo chmod g+w $APPLICATION_PATH/composer.*
  [ -d /data/.composer/cache ] && sudo chmod g+w /data/.composer/cache
  sudo rm -rf /data  || true
  [ -d $OLD_APPLICATION_VERSION ] && sudo rm -rf $OLD_APPLICATION_VERSION
  sudo chmod 600 config/Zed/dev_only_*
  sudo ln -s $APPLICATION_PATH /data

  echo $APPLICATION_PATH > /versions/latest_successful_build

  # Disable maintenance mode
  sudo supervisorctl restart php-fpm
  rm -f /tmp/maintenance_on.flag

  # Print output text with the setup results
  j2 /etc/spryker/setup_output.j2 /etc/spryker/stores.yml
  rm -rf /tmp/curdate
}

[ -z $1 ] && help || $1
