#!/bin/bash
set -eu

docker build -t $DOCKER_HUB_LOGIN/rabbitmq:${CI_COMMIT_TAG:-2.2.0}.${CI_COMMIT_SHORT_SHA:-0} .
