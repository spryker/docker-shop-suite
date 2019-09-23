#!/bin/bash -x


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

#Add github/bitbucket/gitlab keys to the system-wide known_hosts file
ssh-keyscan github.com > /etc/ssh/ssh_known_hosts
ssh-keyscan bitbucket.org >> /etc/ssh/ssh_known_hosts
ssh-keyscan gitlab.com >> /etc/ssh/ssh_known_hosts

#Create the Nginx virtualhost for each store
for i in "${STORE[@]}"; do
    export XX=$i
    export xx=$(echo $i | tr [A-Z] [a-z])

    if [ ${SINGLE_STORE} == "yes" ]; then
        mainDomain=${DOMAIN_NAME}
        echo "127.0.0.1   os.${DOMAIN_NAME}" >> /etc/hosts
    else
        mainDomain=${xx}.${DOMAIN_NAME}
    fi

    bash /usr/local/bin/setup_vhosts.sh ${mainDomain} $(getMyAddr public) &
    # Put Zed host IP to /etc/hosts file
    echo "127.0.0.1   os.${xx}.${DOMAIN_NAME}" >> /etc/hosts
done
/usr/sbin/nginx -g 'daemon on;' &

# Enable maintenance mode
touch /maintenance_on.flag

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
sed -i -e "s/@appHost@/$(getMyAddr local)/g" /etc/spryker/jenkins-job.default.xml.twig

if [ ! -f /versions/id_rsa ]; then
  echo -e $(curl -s -H "X-Vault-Token: ${SSH_KEY_TOKEN}" -X GET https://vault.spryker.systems:8200/v1/AWS_instances_common_storage/data/github_ssh_key | jq .data.data.id_rsa | tr -d '\"') > /versions/id_rsa
  chmod 600 /versions/id_rsa
  chown 1000 /versions/id_rsa
fi

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
     cp config/install/restore_spryker_state.yml config/install/${APPLICATION_ENV:-staging}.yml
     vendor/bin/install -vvv
     chown -R www-data:www-data /data/
else
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

     #Deploy Spryker Shop
     /setup_suite.sh
     # Disable maintenance mode to validate LetsEncrypt certificates
     test -f /maintenance_on.flag && rm /maintenance_on.flag
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
