# Build Your Vote Microservice Version 2

## Prerequisite
We assume you are at the end of [step 1](https://github.com/IBM/Java-MicroProfile-Microservices-on-Istio#1-get-and-build-the-application-code) for our Java MicroProfile Microservices on Istio example.

## Build your Vote Microservice Version 2 on Ubuntu/Linux

> If you are using Linux, you don't have to run Ubuntu on Docker.

Run Ubuntu on Docker

```shell
docker run -it ubuntu /bin/bash
```
> If you are not in privilege mode, please add `sudo` for all the following commands.

Install all the necessary CLIs and plugins.

```shell
apt-get update
apt-get install git
apt-get install curl
apt-get install openjdk-8-jdk
apt-get install maven
apt install docker.io
curl -L public.dhe.ibm.com/cloud/bluemix/cli/bluemix-cli/Bluemix_CLI_0.5.4_amd64.tar.gz > Bluemix_CLI.tar.gz
tar -xvf Bluemix_CLI.tar.gz
./Bluemix_CLI/install_bluemix_cli
bx plugin install IBM-Containers -r Bluemix
```

Now after you have all the CLIs, clone the repository.

```shell
git clone https://github.com/WASdev/sample.microservicebuilder.vote.git
cd sample.microservicebuilder.vote
```

Build your application using Maven.
```shell
mvn clean package
```

To build your own docker image, you have to connect your docker server to IBM containers because only IBM containers can install the necessary assets on the beta version of WebSphere Liberty. To do this, run the following commands

```shell
bx login -a https://api.ng.bluemix.net
bx ic init
bx ic build -t microservice-vote-cloudant .
```

Now **exit** your ubuntu and modify *manifests/deploy-vote.yaml*. Change `docker.io/tomcli/microservice-vote-cloudant` to `registry.ng.bluemix.net/<namespace>/microservice-vote-cloudant` (replace `<namespace>` with your namespace).

Your image should be built on your Bluemix container registry. Now you can move on to [step 2](https://github.com/IBM/Java-MicroProfile-Microservices-on-Istio#2-deploy-application-microservices-and-istio-envoys).
