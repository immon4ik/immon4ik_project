#!/bin/bash
set -evx

# Переменные для успешного запуска gitlab-runner:
export GITLAB_CI_URL=http://your_gitlab_ip/
export GITLAB_CI_TOKEN=your_runner_token
export RUNNER_NAME=${RANDOM}-gitlab-runner

# Получение пересенных среды docker-gitlab:
docker-machine env docker-gitlab

# Добавление переменных с содержанием сертификатов:
export DOCKER_HOST_CA_FILE=$(cat $DOCKER_CERT_PATH/ca.pem)
export DOCKER_HOST_CERT_FILE=$(cat $DOCKER_CERT_PATH/cert.pem)
export DOCKER_HOST_KEY_FILE=$(cat $DOCKER_CERT_PATH/key.pem)
