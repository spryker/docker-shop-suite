#!/bin/bash

echo "Running init script"

docker_sdk_env(){
  if [ $(env | grep "^SPRYKER_" | wc -l ) -gt 10 ] ; then
    env | grep "^SPRYKER_" >> /versions/vars
    sed -i -e 's/^SPRYKER_/export SPRYKER_/g' -e 's/"/\\\"/g' -e 's/={\\\"/=\"{\\\"/g' -e 's/}}/}}\"/g' /versions/vars
  fi
}

docker_sdk_env