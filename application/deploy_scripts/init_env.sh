#!/bin/bash

echo "Running init script"

#Parse string STORES to the array of country names STORE
IFS=',' read -ra STORE <<< "${STORES}"

docker_sdk_env(){
  if [ $(env | grep "^SPRYKER_" | wc -l ) -gt 10 ] ; then
    env | grep "^SPRYKER_" >> /versions/vars
    sed -i -e 's/^SPRYKER_/export SPRYKER_/g' -e 's/"/\\\"/g' -e 's/={\\\"/=\"{\\\"/g' -e 's/}}/}}\"/g' /versions/vars
  fi
}


rabbitMQvh(){

  #Create the RabbitMQ virtualhost for each store
  for i in "${STORE[@]}"; do
    export xx=$(echo $i | tr [A-Z] [a-z])
    curl -i -u ${RABBITMQ_USER}:${RABBITMQ_PASSWORD} -H "content-type:application/json" -XPUT http://${RABBITMQ_HOST}:15672/api/vhosts/${xx}-docker
    echo "The RabbitMQ Vhost ${xx}-docker has been created"
    curl -i -u ${RABBITMQ_USER}:${RABBITMQ_PASSWORD} -H "content-type:application/json" -XPUT -d '{"password":"'"${SPRYKER_BROKER_API_PASSWORD}"'", "tags":"management"}' http://${RABBITMQ_HOST}:15672/api/users/${xx}-docker
    echo "The RabbitMQ user ${xx}-docker has been created"
    curl -i -u ${RABBITMQ_USER}:${RABBITMQ_PASSWORD} -H "content-type:application/json" -XPUT -d '{"configure":".*","write":".*","read":".*"}' http://${RABBITMQ_HOST}:15672/api/permissions/${xx}-docker/${xx}-docker
    echo "The RabbitMQ user ${xx}-docker has got the access to the Vhost ${xx}-docker"
  done
}

docker_sdk_env

rabbitMQvh