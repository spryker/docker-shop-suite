#!/bin/bash

set -x

# Change working directory
cd /tmp/

#Parse string STORES to the array of country names STORE
IFS=',' read -ra STORE <<< "${STORES}"

myIp=$1
ZED_HTTPS=0
YVES_HTTPS=0
GLUE_HTTPS=0
DRIVER_HTTPS=0
ZED_VARIABLES='zed:os'
YVES_VARIABLES='yves:www'
GLUE_VARIABLES='glue:glue'
DRIVER_VARIABLES='driver:driver'

test -n "${ZED_HTTPS_ON}" && test "${ZED_HTTPS_ON}" -eq 1 && ZED_HTTPS=1
test -n "${YVES_HTTPS_ON}" && test "${YVES_HTTPS_ON}" -eq 1 && YVES_HTTPS=1
test -n "${GLUE_HTTPS_ON}" && test "${GLUE_HTTPS_ON}" -eq 1 && GLUE_HTTPS=1
test -n "${DRIVER_HTTPS_ON}" && test "${DRIVER_HTTPS_ON}" -eq 1 && DRIVER_HTTPS=1

# Function which return the IP address of the domain name input as the first parameter of the function
function resolveDomain(){
  domain=$1
  test -z ${domain} && echo "No domain specified as the parameter of the resolveDomain function. Exiting" && exit 1
  ip=$(dig ${domain} a +short|grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}"|head -n 1)
  echo ${ip}
}

#Checking that domain resolves with correct IP
function checkDomain(){
  domain=$1
  echo -n "Resolving ${domain}, got \""
  domainIp=$(resolveDomain ${domain})
  echo "${domainIp}\""

  while [ "${domainIp}" != "${myIp}" ]; do
    echo "Waiting for DNS changes for ${domain}. It should point to ${myIp}"
    sleep 20
    domainIp=$(resolveDomain ${domain})
  done
  echo "OK"
}

function getCertificates(){
  domains="$1"
  # Wait for nginx
  until curl -s "${domains}:80" > /dev/null; do
    echo "Awaiting for nginx"
    sleep 2
  done
  # Check if maintenance enabled
  [ -f  /tmp/maintenance_on.flag ] && rm -f  /tmp/maintenance_on.flag

  letsencrypt certonly --webroot -w /usr/share/nginx/html -d $(echo "${domains}"|sed "s/ / -d /g") -m admin@${mainDomain} --agree-tos -n --expand
}

function checkCertificates(){
  domain=$1

  # Check if certificate and key was generated and put it in the vhosts configs
  if [ -L /etc/letsencrypt/live/${domain}/fullchain.pem -a -L /etc/letsencrypt/live/${domain}/privkey.pem ]; then
      fullchain=$(readlink -f /etc/letsencrypt/live/${domain}/fullchain.pem)
      privkey=$(readlink -f /etc/letsencrypt/live/${domain}/privkey.pem)
      if [ -f ${fullchain} -a -f ${privkey} ]; then
        echo OK
      fi
  fi
}

createVhost(){
  confPrefix=$1
  vhostTmpl=$2
  export myDomain=$3
  j2 /etc/nginx/vhost_templates/${confPrefix}-vhost-${vhostTmpl}.conf.j2 -o /etc/nginx/sites-available/vhost-${myDomain}.conf
  if [ ! -L /etc/nginx/sites-enabled/vhost-${myDomain}.conf ]; then
    ln -s /etc/nginx/sites-available/vhost-${myDomain}.conf /etc/nginx/sites-enabled/vhost-${myDomain}.conf
  fi
}

processingDomain(){
  vhostTmpl=$1
  subDomain=$2
  mainDomain=$3
  myDomain="${subDomain}.${mainDomain}"

  checkDomain ${myDomain}

  getCertificates "${myDomain}"
  if [ "$(checkCertificates ${myDomain})" == "OK" ]; then
    createVhost ssl ${vhostTmpl} ${myDomain}
    echo "The SSL web server config has been configured for ${mainDomain}"
  else
    echo "Cert for ${myDomain} not found"
  fi
  unset myDomain
}


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

  # Processing domain(s)
  for APP in ZED YVES GLUE DRIVER; do
    appConfig=${APP}_VARIABLES
    appHttps=${APP}_HTTPS

    if [ ${!appHttps} -eq 1 -a ${myIp} != "app" ];then
      # Create tmp vhost conf
      createVhost xx ${!appConfig%:*} ${!appConfig#*:*}.${mainDomain}
      # Start nginx or reload if it already running
      if [ $(ps auxf| grep "[n]ginx" | wc -l ) -gt 0 ]; then
        /usr/sbin/nginx -s reload
      else
        /usr/sbin/nginx -g 'daemon on;' &
      fi
      # Get certificate and create vhost conf if https enabled
      processingDomain ${!appConfig%:*} ${!appConfig#*:*} ${mainDomain}
    else
      # Create vhost conf if https disabled
      createVhost xx ${!appConfig%:*} ${!appConfig#*:*}.${mainDomain}
    fi
  done
    # Put Zed host IP to /etc/hosts file
    echo "127.0.0.1   os.${xx}.${DOMAIN_NAME}" >> /etc/hosts

done

# Enable maintenance mode
sudo -u jenkins touch /tmp/maintenance_on.flag

supervisorctl restart nginx
