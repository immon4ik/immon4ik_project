#!/bin/bash
set -evx

mkdir -p $DOCKER_CERT_PATH
echo "$DOCKER_HOST_CA_FILE" > $DOCKER_CERT_PATH/ca.pem
echo "$DOCKER_HOST_CERT_FILE" > $DOCKER_CERT_PATH/cert.pem
echo "$DOCKER_HOST_KEY_FILE" > $DOCKER_CERT_PATH/key.pem
echo "DOCKER_CERT_PATH=$DOCKER_CERT_PATH"
ls -a $DOCKER_CERT_PATH
echo "DOCKER_HOST=$DOCKER_HOST"
docker info
docker login -u $DOCKER_HUB_LOGIN -p $DOCKER_HUB_PASSWORD
apk add py-pip python-dev libffi-dev openssl-dev gcc libc-dev make
pip install docker-compose
docker-compose --version
docker ps -as
docker image ls
source ./src/.env
echo ${UI_PORT}
docker-compose -f ./src/docker-compose.yml config
