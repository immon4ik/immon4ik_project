#!/bin/bash
set -eu

docker build -t $DOCKER_HUB_LOGIN/grafana:prj .
