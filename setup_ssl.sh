#!/bin/bash

# Checking env variable
test -z ${HTTPS_ON} && exit 0
test ${HTTPS_ON} -eq 0 && exit 0

# Checking the first input parameter with the domain
mainDomain=$1
test -z ${mainDomain} && echo "No domain specified. Exiting" && exit 1

# Checking the second input parameter with the public IP
myIp=$2
test -z ${myIp} && echo "No IP specified. Exiting" && exit 1

# Concatinating all Spryker domains
myDomains="${mainDomain} www.${mainDomain} glue.${mainDomain} os.${mainDomain}"

# Install Dig if it doesn't installed yet
test -z "$(which dig)" && (apt-get update && apt-get install -y dnsutils)

# Function which return the IP address of the domain name input as the first parameter of the function
function resolve_domain(){
  domain=$1
  test -z ${domain} && echo "No domain specified as the parameter of the resolve_domain function. Exiting" && exit 1
  ip=$(dig ${domain} a +short|grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}"|head -n 1)
  echo ${ip}
}

# Checking for DNS records set
for domain in $(echo $myDomains); do
  echo -n "Resolving ${domain}, got \""
  domainIp=$(resolve_domain ${domain})
  echo "${domainIp}\""

  # Check for DNS changes every 20 sec
  while [ "${domainIp}" != "${myIp}" ]; do
      echo "Waiting for DNS changes for ${domain}. It should point to ${myIp}"
      sleep 20
      domainIp=$(resolve_domain ${domain})
  done
  echo "OK"
done

echo "All DNS records exist and are correct"

cd /tmp

repoDir=/tmp/certbot
# Get certbot sources
if [ -d ${repoDir}/.git ]; then
    cd ${repoDir}
    git pull
else
    git clone https://github.com/certbot/certbot.git ${repoDir}
fi

${repoDir}/letsencrypt-auto certonly --webroot -w /usr/share/nginx/html -d $(echo ${myDomains}|sed "s/ / -d /g") -m admin@${mainDomain} --agree-tos -n --expand


ls -la /etc/letsencrypt/live/${mainDomain}/fullchain.pem
ls -la /etc/letsencrypt/live/${mainDomain}/privkey.pem

# Check if certificate and key was generated and put it in the vhosts configs
if [ -L /etc/letsencrypt/live/${mainDomain}/fullchain.pem -a -L /etc/letsencrypt/live/${mainDomain}/privkey.pem ]; then
    fullchain=$(readlink -f /etc/letsencrypt/live/${mainDomain}/fullchain.pem)
    privkey=$(readlink -f /etc/letsencrypt/live/${mainDomain}/privkey.pem)
    if [ -f ${fullchain} -a -f ${privkey} ]; then
        j2 /etc/nginx/conf.d/ssl/ssl.vhost-yves.conf.j2 > /etc/nginx/conf.d/vhost-yves.conf
        j2 /etc/nginx/conf.d/ssl/ssl.vhost-zed.conf.j2 > /etc/nginx/conf.d/vhost-zed.conf
        #j2 /etc/nginx/conf.d/ssl/ssl.vhost-glue.conf.j2 > /etc/nginx/conf.d/vhost-glue.conf

	supervisorctl restart nginx
    fi
fi
