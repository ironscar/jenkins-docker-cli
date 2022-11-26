FROM jenkins/jenkins AS stage1

# configure initial private ssh key to .ssh folder of jenkins user home
COPY private_key_file.txt ~/.ssh/ansible_id_rsa
USER root
RUN chown jenkins:jenkins /~/.ssh/ansible_id_rsa
USER jenkins
RUN chmod 600 /~/.ssh/ansible_id_rsa

# start new stage
FROM stage1

# set root user
USER root

# log folder setup
RUN mkdir /var/log/jenkins
RUN chown -R jenkins:jenkins /var/log/jenkins

# home dir data setup
RUN mkdir /var/cache/jenkins
RUN chown -R jenkins:jenkins /var/cache/jenkins

# docker install
RUN apt-get update && apt-get install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
RUN apt-key fingerprint 0EBFCD88
RUN add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
RUN apt-get update && apt-get install -y docker-ce-cli

# pip and ansible install
RUN apt-get update && apt-get install -y pip
RUN pip3 install ansible
RUN pip3 install setuptools
RUN mkdir -p /etc/ansible
COPY ansible.cfg /etc/ansible

# switch users back
USER jenkins

# set default options
ENV JENKINS_OPTS="--logfile=/var/log/jenkins/jenkins.log --webroot=/var/cache/jenkins/war"
