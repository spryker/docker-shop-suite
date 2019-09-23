#!/bin/bash

myIp=$2
ZED_HTTPS=0
YVES_HTTPS=0
GLUE_HTTPS=0

test -n "${ZED_HTTPS_ON}" && test "${ZED_HTTPS_ON}" -eq 1 && ZED_HTTPS=1
test -n "${YVES_HTTPS_ON}" && test "${YVES_HTTPS_ON}" -eq 1 && YVES_HTTPS=1
test -n "${GLUE_HTTPS_ON}" && test "${GLUE_HTTPS_ON}" -eq 1 && GLUE_HTTPS=1

# Checking the first input parameter with the domain
mainDomain=$1
test -z ${mainDomain} && echo "No domain specified. Exiting" && exit 1

# Install Dig if it doesn't installed yet
function checkDig(){
  test -z "$(which dig)" && (apt-get update && apt-get install -y dnsutils)
}

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
  checkDig
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
  cd /tmp
  repoDir=/tmp/certbot
  # Get certbot sources
  if [ -d ${repoDir}/.git ]; then
      cd ${repoDir}
      git pull
  else
      git clone https://github.com/certbot/certbot.git ${repoDir}
  fi

  ${repoDir}/letsencrypt-auto certonly --webroot -w /usr/share/nginx/html -d $(echo "${domains}"|sed "s/ / -d /g") -m admin@${mainDomain} --agree-tos -n --expand
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
  j2 /etc/nginx/vhost_templates/${confPrefix}-vhost-${vhostTmpl}.conf.j2 > /etc/nginx/sites-available/vhost-${myDomain}.conf
  if [ ! -L /etc/nginx/sites-enabled/vhost-${myDomain}.conf ]; then
    ln -s /etc/nginx/sites-available/vhost-${myDomain}.conf /etc/nginx/sites-enabled/vhost-${myDomain}.conf
  fi
  unset myDomain
}

processingDomain(){
  vhostTmpl=$1
  subDomain=$2
  mainDomain=$3
  myDomain="${subDomain}.${mainDomain}"

  checkDig
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

# Processing ZED domain(s)
if [ ${ZED_HTTPS} -eq 1 -a ${myIp} != "app" ];then
  # Create tmp vhost conf
  createVhost xx zed os.${mainDomain}
  processingDomain zed os ${mainDomain}
else
  createVhost xx zed os.${mainDomain}
fi

# Processing YVES domain(s)
if [ ${YVES_HTTPS} -eq 1 -a ${myIp} != "app" ];then
  # Create tmp vhost conf
  createVhost xx yves www.${mainDomain}
  processingDomain yves www ${mainDomain}
else
  createVhost xx yves www.${mainDomain}
fi

# Processing GLUE domain(s)
if [ ${GLUE_HTTPS} -eq 1 -a ${myIp} != "app" ];then
  # Create tmp vhost conf
  createVhost xx glue glue.${mainDomain}
  processingDomain glue glue ${mainDomain}
else
  createVhost xx glue glue.${mainDomain}
fi

supervisorctl restart nginx
