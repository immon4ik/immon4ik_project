#!/bin/bash
set -eu

docker build -t $DOCKER_HUB_LOGIN/rabbitmq_exporter:prj .
