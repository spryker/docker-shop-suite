FROM jenkins/jenkins:lts

# For running APT in non-interactive mode
ENV DEBIAN_FRONTEND noninteractive

# Change user to root for making installations
USER root

# Install mc
RUN apt-get -qy update && apt-get install -q -y --no-install-recommends \
  mc        \
  sshpass

# Jenkins main configuration file
COPY jenkins/config.xml /var/jenkins_home/config.xml

# Install plugins defined in plugins.txt
COPY jenkins/plugins.txt /usr/share/jenkins/plugins.txt
RUN /usr/local/bin/plugins.sh /usr/share/jenkins/plugins.txt
# Make jenkins user owner by jenkins_home
RUN chown -R jenkins:jenkins /var/jenkins_home 

# SSH credentials
RUN sed -i '/var\/jenkins_home/a[[ ! -z "$JENKINS_SSH_KEY" ]] && echo "$JENKINS_SSH_KEY" | base64 -d > $JENKINS_HOME/.ssh/id_rsa || echo "SSH key variable is not found. User Jenkins will use default SSH key."' /usr/local/bin/jenkins.sh
RUN sed -i '/var\/jenkins_home/a[[ ! -z "$ZED_HOST" ]] && sed -i 's/localhost/\"\$ZED_HOST\"/g' /var/jenkins_home/org.jvnet.hudson.plugins.SSHBuildWrapper.xml || echo "ZED_HOST variable in not defined"' /usr/local/bin/jenkins.sh
RUN sed -i '/var\/jenkins_home/a[[ -f /usr/share/jenkins/config/credentials.xml ]] && mv /usr/share/jenkins/config/{.,}* $JENKINS_HOME/  || echo "The configuration file was not found" ' /usr/local/bin/jenkins.sh

RUN mkdir -p /usr/share/jenkins/config/.ssh
COPY jenkins/id_rsa  /usr/share/jenkins/config/.ssh/id_rsa
COPY jenkins/org.jvnet.hudson.plugins.SSHBuildWrapper.xml  /usr/share/jenkins/config/org.jvnet.hudson.plugins.SSHBuildWrapper.xml
COPY jenkins/credentials.xml   /usr/share/jenkins/config/credentials.xml
RUN chown -R jenkins:jenkins  /usr/share/jenkins/config \
 && chmod 600 /usr/share/jenkins/config/.ssh/id_rsa \
 && sed -i 's/ OPENSSH / RSA /g' /usr/share/jenkins/config/.ssh/id_rsa

# Drop back to the regular jenkins user - good practice
USER jenkins
# Make /var/jenkins_home the default directory
RUN cd ~
