#!/bin/bash
set -evx

# Переменные для успешного запуска gitlab-runner:
export GITLAB_CI_URL=your_gitlab_ip
export GITLAB_CI_TOKEN=your_runner_token
export RUNNER_NAME=${RANDOM}-gitlab-runner

# Получение пересенных среды docker-gitlab:
docker-machine env docker-gitlab

# Добавление переменных с содержанием сертификатов:
export DOCKER_HOST_CA_FILE=$(cat $DOCKER_CERT_PATH/ca.pem)
export DOCKER_HOST_CERT_FILE=$(cat $DOCKER_CERT_PATH/cert.pem)
export DOCKER_HOST_KEY_FILE=$(cat $DOCKER_CERT_PATH/key.pem)

# Запускаем gitlab-runner:
docker run -d --name $RUNNER_NAME --restart always \
  -v /srv/${RUNNER_NAME}/config:/etc/gitlab-runner \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /home/docker-user/crt:/builds/homework/example \
  gitlab/gitlab-runner:latest

# Регистрируем и добавляем переменные сертификатов в запущенный gitlab-runner:
docker exec -it $RUNNER_NAME gitlab-runner register \
  --run-untagged \
  --locked=false \
  --non-interactive \
  --url ${GITLAB_CI_URL:-http://127.0.0.1} \
  --registration-token $GITLAB_CI_TOKEN \
  --description "docker-runner" \
  --tag-list "linux,xenial,ubuntu,docker" \
  --executor docker \
  --docker-image "alpine:latest" \
  --docker-privileged \
  --docker-volumes "docker-certs-client:/certs/client" \
  --env "DOCKER_DRIVER=overlay2" \
  --env "DOCKER_TLS_CERTDIR=/certs" \
  --env "DOCKER_HOST_CA_FILE=$(cat $DOCKER_CERT_PATH/ca.pem)" \
  --env "DOCKER_HOST_CERT_FILE=$(cat $DOCKER_CERT_PATH/cert.pem)" \
  --env "DOCKER_HOST_KEY_FILE=$(cat $DOCKER_CERT_PATH/key.pem)"
