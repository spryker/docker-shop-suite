#!/bin/bash

ZED_HTTPS=0
YVES_HTTPS=0
GLUE_HTTPS=0

test -n "${ZED_HTTPS_ON}" && test "${ZED_HTTPS_ON}" -eq 1 && ZED_HTTPS=1
test -n "${YVES_HTTPS_ON}" && test "${YVES_HTTPS_ON}" -eq 1 && YVES_HTTPS=1
test -n "${GLUE_HTTPS_ON}" && test "${GLUE_HTTPS_ON}" -eq 1 && GLUE_HTTPS=1

# Checking the first input parameter with the domain
mainDomain=$1
test -z ${mainDomain} && echo "No domain specified. Exiting" && exit 1

# Checking the second input parameter with the public IP
myIp=$2
test -z ${myIp} && echo "No IP specified. Exiting" && exit 1

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

  echo  ${repoDir}/letsencrypt-auto certonly --webroot -w /usr/share/nginx/html -d $(echo "${domains}"|sed "s/ / -d /g") -m admin@${mainDomain} --agree-tos -n --expand
}

function checkCertificates(){
  domain=$1
  ls -la /etc/letsencrypt/live/${domain}/fullchain.pem
  ls -la /etc/letsencrypt/live/${domain}/privkey.pem
  
  # Check if certificate and key was generated and put it in the vhosts configs
  if [ -L /etc/letsencrypt/live/${domain}/fullchain.pem -a -L /etc/letsencrypt/live/${domain}/privkey.pem ]; then
      fullchain=$(readlink -f /etc/letsencrypt/live/${domain}/fullchain.pem)
      privkey=$(readlink -f /etc/letsencrypt/live/${domain}/privkey.pem)
      if [ -f ${fullchain} -a -f ${privkey} ]; then
        echo OK
      fi
  fi
}

# Processing ZED domain(s)
if [ ${ZED_HTTPS} -eq 1 ];then
  myDomains="os.${mainDomain}"
  checkDig
  for domain in $(echo ${myDomains}); do
    checkDomain ${domain}
  done

  getCertificates "${myDomains}"

  if [ "$(checkCertificates ${mainDomain})" == "OK" ]; then
    echo j2 /etc/nginx/conf.d/ssl/ssl.vhost-zed.conf.j2 > /etc/nginx/conf.d/vhost-zed.conf
  else
    echo "Certificate for ${myDomains} was not created. Canceling HTTPS configuration"
  fi
fi

# Processing YVES domain(s)
if [ ${YVES_HTTPS} -eq 1 ];then
  myDomains="${mainDomain} www.${mainDomain}"
  checkDig
  for domain in $(echo ${myDomains}); do
    checkDomain ${domain}
  done
  getCertificates "${myDomains}"
  if [ "$(checkCertificates ${mainDomain})" == "OK" ]; then
    echo j2 /etc/nginx/conf.d/ssl/ssl.vhost-yves.conf.j2 > /etc/nginx/conf.d/vhost-yves.conf
  else
    echo "Certificate for ${myDomains} was not created. Canceling HTTPS configuration"
  fi
fi

# Processing GLUE domain(s)
if [ ${GLUE_HTTPS} -eq 1 ];then
  myDomains="glue.${mainDomain}"
  checkDig
  for domain in $(echo ${myDomains}); do
    checkDomain ${domain}
  done

  getCertificates "${myDomains}"

  if [ "$(checkCertificates ${mainDomain})" == "OK" ]; then
    echo j2 /etc/nginx/conf.d/ssl/ssl.vhost-glue.conf.j2 > /etc/nginx/conf.d/vhost-glue.conf
  else
    echo "Certificate for ${myDomains} was not created. Canceling HTTPS configuration"
  fi
fi

supervisorctl restart nginx
