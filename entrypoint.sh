#!/bin/bash -x

# Priveous build mark check
if [ -f /versions/latest_build_failed ]; then
  rm /versions/latest_build_failed /versions/latest_successful_build
  exit 1
fi

touch /versions/latest_build_failed

# Update authorized_keys for users
[[ ! -z "$WWWDATA_PUB_SSH_KEY" ]] && echo "$WWWDATA_PUB_SSH_KEY"  | base64 -d > /etc/spryker/www-data/.ssh/authorized_keys || echo "SSH key variable is not found. User www-data will use default SSH key."
[[ ! -z "$JENKINS_PUB_SSH_KEY" ]] && echo "$JENKINS_PUB_SSH_KEY"  | base64 -d > /etc/spryker/jenkins/.ssh/authorized_keys || echo "SSH key variable is not found. User Jenkins will use default SSH key."

# Update Yves, Zed and Glue Nginx and PHP configuration files with the correct environment variables
j2 /etc/nginx/conf.d/backends.conf.j2 > /etc/nginx/conf.d/backends.conf
j2 /usr/local/etc/php-fpm.d/yves.conf.j2 > /usr/local/etc/php-fpm.d/yves.conf
j2 /usr/local/etc/php-fpm.d/zed.conf.j2 > /usr/local/etc/php-fpm.d/zed.conf
j2 /usr/local/etc/php-fpm.d/glue.conf.j2 > /usr/local/etc/php-fpm.d/glue.conf
j2 /etc/nginx/conf.d/backends.conf.j2 > /etc/nginx/conf.d/backends.conf
#Parse string STORES to the array of country names STORE
IFS=',' read -ra STORE <<< "${STORES}"

function getMyAddr(){
  addrScope=$1
  # if build run on an AWS instance
  if $(nc -znw 2 169.254.169.254 80); then
    myaddr=$(curl http://169.254.169.254/latest/meta-data/${addrScope}-ipv4)
  else
    # if local build
    myaddr=app
  fi
  echo ${myaddr}
}

# Add composer cache directory
mkdir -p -m775 /var/cache/composer

# Change owner of /versions and /var/cache/composer directories
chown jenkins:www-data /versions /var/cache/composer

# Add github/bitbucket/gitlab keys to the system-wide known_hosts file
ssh-keyscan github.com > /etc/ssh/ssh_known_hosts
ssh-keyscan bitbucket.org >> /etc/ssh/ssh_known_hosts
ssh-keyscan gitlab.com >> /etc/ssh/ssh_known_hosts

# Create a temporary file with the list of stores for using in install config
echo "APPLICATION_ENV: ${APPLICATION_ENV}" > /etc/spryker/stores.yml
echo "DOMAIN_NAME: ${DOMAIN_NAME}" >> /etc/spryker/stores.yml
echo "SINGLE_STORE: '${SINGLE_STORE}'" >> /etc/spryker/stores.yml
echo "stores:" >> /etc/spryker/stores.yml
for i in "${STORE[@]}"; do
    XX=$i
    echo "  - ${XX}" >> /etc/spryker/stores.yml
done

/usr/sbin/nginx -g 'daemon on;' &
bash /usr/local/bin/setup_vhosts.sh $(getMyAddr public) &

# Enable PGPASSWORD for non-interactive working with PostgreSQL if PGPASSWORD is not set
export PGPASSWORD=${POSTGRES_PASSWORD}
# Waiting for PostgreSQL database starting
until psql -h ${POSTGRES_HOST} -p "${POSTGRES_PORT}" -U "${POSTGRES_USER}" ${ENV_NAME} -c '\l'; do
  echo "Waiting for PostgreSQL..."
  sleep 3
done
echo "PostgreSQL is available now. Good."

# Waiting for the Elasticsearch starting
until curl -s "${ELASTICSEARCH_HOST}:${ELASTICSEARCH_PORT}" > /dev/null; do
  echo "Waiting for Elasticsearch..."
  sleep 3
done
echo "Elasticsearch is available now. Good."

# Waiting for the RabbitMQ starting
until curl -s "${RABBITMQ_HOST}:${RABBITMQ_API_PORT}" > /dev/null; do
  echo "Waiting for RabbitMQ..."
  sleep 3
done
echo "RabbitMQ is available now. Good."

# Become more verbose
set -xe

# Put env variables to /versions/vars file for using it in Jenkins jobs
j2 /etc/spryker/vars.j2 > /versions/vars

# Install NewRelic php app monitoring
if [ ! -z ${NEWRELIC_KEY} ]; then
  echo ${NEWRELIC_KEY} | sudo newrelic-install install
fi

# Configure PHP
j2 /usr/local/etc/php/php.ini.j2 > /usr/local/etc/php/php.ini

# Getting template for Jenkins jobs
if [ -z ${SPRYKER_PRIVATE_DNS_ZONE} ]; then
  sed -i -e "s/@appHost@/$(getMyAddr local)/g" /etc/spryker/jenkins-job.default.xml.twig
else
  sed -i -e "s/@appHost@/${ENV_NAME}.${SPRYKER_PRIVATE_DNS_ZONE}/g" /etc/spryker/jenkins-job.default.xml.twig
fi

if [ ! -f /versions/id_rsa -a ! -z ${GITHUB_SSH_KEY} ]; then
  echo ${GITHUB_SSH_KEY} | base64 --decode > /versions/id_rsa
  chmod 600 /versions/id_rsa
  chown 1000 /versions/id_rsa
fi

# Clean all Redis data
redis-cli -h $REDIS_HOST flushall

# Delete all indexes of the Elasticsearch
curl -XDELETE $ELASTICSEARCH_HOST:$ELASTICSEARCH_PORT/*

#Parse string STORES to the array of country names STORE
IFS=',' read -ra STORE <<< "${STORES}"
#Create the RabbitMQ virtualhost for each store
for i in "${STORE[@]}"; do
  export XX=$i
  curl -i -u ${RABBITMQ_USER}:${RABBITMQ_PASSWORD} -H "content-type:application/json" -XPUT http://${RABBITMQ_HOST}:15672/api/vhosts/%2F${XX}_staging_zed
  echo "The RabbitMQ Vhost ${XX}_${APPLICATION_ENV}_zed has been created"
  curl -i -u ${RABBITMQ_USER}:${RABBITMQ_PASSWORD} -H "content-type:application/json" -XPUT -d '{"password":"'"${RABBITMQ_PASSWORD}${XX}"'", "tags":"management"}' http://${RABBITMQ_HOST}:15672/api/users/${XX}_${APPLICATION_ENV}
  echo "The RabbitMQ user ${XX}_${APPLICATION_ENV} has been created"
  curl -i -u ${RABBITMQ_USER}:${RABBITMQ_PASSWORD} -H "content-type:application/json" -XPUT -d '{"configure":".*","write":".*","read":".*"}' http://${RABBITMQ_HOST}:15672/api/permissions/%2F${XX}_${APPLICATION_ENV}_zed/${XX}_${APPLICATION_ENV}
  echo "The RabbitMQ user ${XX}_${APPLICATION_ENV} has got the access to the Vhost ${XX}_${APPLICATION_ENV}_zed"
done

#"To build or not to build"
if [ -f /versions/latest_successful_build ]; then
     source  /versions/vars
     APPLICATION_PATH=$(cat /versions/latest_successful_build)
     if [ -L /data ]; then
       echo "An application link already exist"
     else
       sudo rm -rf /data
       ln -s ${APPLICATION_PATH} /data
     fi
     cd /data
     j2 /etc/spryker/restore_spryker_state.yml.j2 /etc/spryker/stores.yml -o config/install/${APPLICATION_ENV:-staging}.yml
     vendor/bin/install -vvv
     # Unset maintenance flag
     test -f /tmp/maintenance_on.flag && rm /tmp/maintenance_on.flag
elif [ -z ${INITIAL_SPRYKER_REPOSITORY} ]; then
     chown jenkins:jenkins /data
else
    #Deploy Spryker Shop
     /setup_suite.sh
     # Disable maintenance mode to validate LetsEncrypt certificates
     test -f /tmp/maintenance_on.flag && rm /tmp/maintenance_on.flag
     chown -R www-data:www-data /data
fi

until ! $(ps auxf| grep -q "[l]etsencrypt") ; do
 sleep 5
 echo "Letsencrypt running... Awaiting process finalization..."
done
killall -9 nginx

rm -f /versions/latest_build_failed

# Call command...
exec $*
