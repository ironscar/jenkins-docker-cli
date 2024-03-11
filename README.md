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
- ```docker run -d -p 8081:8080 -p 50000:50000 --name=myjenkins --group-add 0 -v //var/run/docker.sock:/var/run/docker.sock --mount source=jenkins-log,target=/var/log/jenkins --mount source=jenkins-data,target=/var/jenkins_home ironscar/jenkins-docker-cli:2.1.0``` for windows
- on the VM however, the group id is not guaranteed to be 0 so run it with stat as it works for linux VM as `--group-add $(stat -c '%g' /var/run/docker.sock)` 

## Setup Jenkins

- create custom jenkins image with docker cli installation, else docker commands directly speified fail
- Create jenkins container as in build & run section
- windows should include a "//var/run/docker.sock" for the host whereas linux should just have "/var/run/docker.sock"
- using group-add without a user adds the specified group to the declared user (by default no user implies root) of the container
- `$(stat -c '%g' /var/run/docker.sock)` can be added after group-add but doesn't work on windows so try to get the group id of the group that has ownership of docker.sock inside the container and add that as value to group-add flag (generally 0)
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

## Setup jenkins container process on VM

- Currently the master node is a vm at `192.168.1.2` (subject to change)
- we have installed docker on the master node as with every other node
- use docker to pull the customized docker image there and run it with all the proper config
- To access this from your host system, go to `192.168.1.2:8081` on your browser assuming the port mapping you run with is set to 8081 for container port 8080 on your vm
- In your actual host, you can go to `/etc` (linux) or `C:/Windows/System32/drivers/etc` (windows) and open the hosts file
- Requires admin privileges to edit this file but we can add ip to name aliases here
- So add `192.168.1.2 jenkins.lev.com` on a new line and save it 
- Now we can access the jenkins process running on the vm from our host browser at `http://jenkins.lev.com:8081`
- Here we can setup jenkins as if it were on our own host
- To get the initial admin password, we can do `sudo docker exec myjenkins3 cat /var/jenkins_home/secrets/initialAdminPassword` inside the vm

## Retreive Jenkins logs

- ```docker cp jenkins-master:/var/log/jenkins/jenkins.log jenkins.log``` to copy the logfile contents if jenkins container is stopped
- If jenkins container no longer exists, the log volume still will so we can create a random container and mount the volume to copy out the logfile as above

## Check Jenkins workspace

- `cd /var/jenkins_home/workspace/{job_branch}` is the workspace for the current branch being built on the current job

---

## Setup Ansible

- Debian system which the jenkins official image uses has python3.9 installed by default
- Install pip, ansible, setuptools, ansible-vault, cryptography (for optimizing vault decryption speed)
- create the ansible directory in etc if not already exists (so we use `-p` flag)
- copy the ansible.cfg file that needs to be used from repository
- need to pick up the private key from somewhere (try below types)
  - method 1:
    - see if you can set the SSH keys in credentials and then update  the ansible commands to use that
  - method 2:
    - see if using ansible plugin jenkins can do something
  - method 3 (did this for now):
    - feed it in as a file and copy into a file in first stage build
- stored the private key as `/~/.ssh/ansible_id_rsa` using method 3 but will look at automated ssh key rotation using ansible thereafter
  - make sure the file has LF endings and not CRLF endings as otherwise the private key is treated as invalid
  - moreover, we have to make sure that the private key is owned by the jenkins user and has permissions 600 to actually allow SSH (updated dockerfile accordingly)
  - lastly, jenkins user cannot ssh into the vms as root user so we have to ssh into them as the vagrant user

---

## Support Ansible Vault

- create jenkins credentials to store the ansible vault password
  - currently stored as username password which gets saved to file and then we have to delete it
  - jenkins allows creating secret files so that is an option to try as keeping a plaintext password file for a little while maybe a security risk [CHECK]
- in jenkinsfile, you would provide this vault password either by creating password-file or providing the secret-file created by jenkins to decrypt the vault
- in case you forget jenkins credentials, we can visit `/script` on jenkins dashboard and paste the contents of `cred-display.groovy` file

---

## Setup jenkins cloud

- Create a new VM for slave node
- Install Java 11 on the slave node by `sudo apt install default-jdk`
  - It should install java in `/usr/lib/jvm/default-java`
  - Go to `/etc/profile.d` and do `sudo vi javaenvvars.sh` and add the env var assignments
  - Set system-wide env variables as `export JAVA_HOME=/usr/lib/jvm/default-java` and `export PATH=$PATH:$JAVA_HOME/bin`
  - Make sure there are no spaces around `=` else it errors out
  - These are run every time a new terminal is connected and sets the env variables
  - Normally, running `export` directly only sets the variables for that terminal session so we must do it this way to make them persistent
- Create a new credential of type SSH key where username is the user which we will login as 
  - We will use `root` and add the private key
  - We can use `vagrant` but for some reason it tends to use root in the ansible step which makes it fail if the steps below are done with vagrant user
- Go to Manage Jenkins > Nodes > Add new node
- Provide details including:
  - Remote root directory as `/var/jenkins` and do `sudo chown <user> jenkins` to update owner of the directory if user is non-root
  - Make sure that this directory exists on slave and the user in username has permissions on this
  - Launch method is `Launch agents via SSH`
  - Host is the ip address of the slave
  - Credential will be the new SSH key credential we created
  - Host key verification strategy is `Known hosts file verification strategy`
- Click save and this will add the new node and attempt to connect to it
- Set number of executors of built-in node to 0 else jenkins issues warnings
  - additionally, we will set the labels on each node, `master` for built-in node and `slave` for all slave nodes
  - for multibranch-pipeline projects, the Jenkinsfile has to be updated with `agent {label 'slave'}`
  - for other freestyle projects, it can be done directly in configuration on dashboard
  - it still executes on slave after this because we set the master executors to 0 
- If something goes wrong, the logs will be available on jenkins UI on that node
- JAVA_HOME maybe at different locations on master and slave so we can change the Tool location in Manage Jenkins > Tools from `/opt/java/openjdk` to `/usr/lib/jvm/default-java` which may not exist on master
- Now this does all the steps perfectly except the ansible one as ansible is not installed
  - So we do the ansible installation steps and private key copy to `/~/.ssh` from the Dockerfile of jenkins for now directly on host using root user
    - ideally do this with the user that jenkins master logs in with as the pip install happens at a user-level
  - Make sure to do `sudo chown <user> /~/.ssh/ansible_id_rsa` if jenkins master uses a non-root user to SSH into slave
  - After this, reboot the machine
  - Make sure to add `/home/vagrant/.local/bin` to PATH after reboot in `/etc/profile.d/javaenvvars.sh` as ansible requires it
    - check this by `echo $PATH` with the user that jenkins master will use to SSH into slave
- Remember that we ought to run the ssh comands from slave for the logged in user to all inventory VMs to add the fingerprint else the ansible command would fail
  - would be nice to have a way to specify the yes prompt automatically 
  - can be done by setting `host_key_checking=no` in ansible config [TEST]
- Later we would want to create a docker container that waits for SSH and has all this setup [TODO]
  - try https://dev.to/s1ntaxe770r/how-to-setup-ssh-within-a-docker-container-i5i 

---

## References

- https://technology.riotgames.com/news/thinking-inside-container productionizing jenkins as a container series
- https://blog.nestybox.com/2019/09/29/jenkins.html containerizing jenkins

---
