# Overview

 - With this dockerfile, we install docker-cli on the debian OS on which the jenkins container is based.
 - We also need to use the root user to download and then switch back to the jenkins user to avoid security vulnerabilities
 - Since we only install docker-cli, we have to connect the jenkins container to the Docker daemon by connecting the docker.sock
