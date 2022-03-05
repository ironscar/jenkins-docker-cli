# Overview

 - With this dockerfile, we do the following:
   - create a log folder and add permissions to write to it via jenkins user
   - create a home dir cache folder and add permissions to write to it via jenkins user
   - install docker-cli on the debian OS on which the jenkins container is based.
   - We also need to use the root user to download and then switch back to the jenkins user to avoid security vulnerabilities
   - Add env props for jenkins to write to the logfile and to the cache directory


- Since we only install docker-cli, we have to connect the jenkins container to the Docker daemon by connecting the docker.sock as shown below
- Mounting the log and data volumes to a new jenkins container will basically carry over all of our configurations on jenkins

## Build & Run Steps

- Create docker data volumes for logs and home-data
- ```docker volume create jenkins-data && docker volume create jenkins-log``` and mount them to jenkins container
- ```docker build -t ironscar/jenkins-docker-cli:2.0.0 .```
- ```docker run -d -p 8081:8080 -p 50000:50000 --name=myjenkins3 --group-add 0 -v //var/run/docker.sock:/var/run/docker.sock --mount source=jenkins-log,target=/var/log/jenkins --mount source=jenkins-data,target=/var/jenkins_home ironscar/jenkins-docker-cli:2.0.0``` for windows

## Setup Jenkins

- create custom jenkins image with docker cli installation, else docker commands directly speified fail
- Create jenkins container as in build & run section
- windows should include a "//var/run/docker.sock" for the host whereas linux should just have "/var/run/docker.sock"
- using group-add without a user adds the specified group to the declared user (by default no user implies root) of the container
- ```$(stat -c '%g' /var/run/docker.sock)``` can be added after group-add but doesn't work on windows so try to get the group id of the group that has ownership of docker.sock inside the container and add that as value to group-add flag (generally 0)
- Install plugins: Maven integration, Docker, Docker pipelines, Pipeline utility steps
- Set up credentials for github and docker registry using manage credentials
- for github, also generate a personal access token from Settings > Developer settings > Personal access tokens (expires in some set time) and then create a new credential in jenkins with password as token and username as anything
- Setting this as a credential in jenkinsfile will give access to token as {credentialName}_PSW
- Manage Jenkins > Configure System > git plugin config lets you set the name of the commit author so that jenkins commits can be differentiated
- registryCredential specified in environment of Jenkinsfile should specify same id as docker registry credential
- Configure tools for jdk by specifying name as JDK (used in Jenkinsfile tools) & /opt/java/openjdk as JAVA_HOME
- Configure maven by naming Maven-3.8.4 and choose to auto-install specific version
- Configure docker by naming Docker-19.03.13 and specify installation root (in this case /usr/bin/docker)
- Create multibranch pipeline and add git as branch source and specify repository url
- Add credentials as created before
- Add filter by regular expression for branches (for starters, just main branch)
- Can configure docker below as well (just credentials will be enough as others get defaulted to default label and dockerhub as registry)
- On save changes, it will index and run build

## Retreive logs

- ```docker cp jenkins-master:/var/log/jenkins/jenkins.log jenkins.log``` to copy the logfile contents if jenkins container is stopped
- If jenkins container no longer exists, the log volume still will so we can create a random container and mount the volume to copy out the logfile as above

## References

- https://technology.riotgames.com/news/thinking-inside-container productionizing jenkins as a container series
- https://blog.nestybox.com/2019/09/29/jenkins.html containerizing jenkins
