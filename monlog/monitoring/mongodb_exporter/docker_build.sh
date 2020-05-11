#!/bin/bash
set -eu

docker build -t $DOCKER_HUB_LOGIN/mongodb_exporter:prj .
