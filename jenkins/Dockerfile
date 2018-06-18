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

# Drop back to the regular jenkins user - good practice
USER jenkins

# Make /var/jenkins_home the default directory
RUN cd ~
