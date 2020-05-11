#!/bin/bash
set -eu

docker build -t $DOCKER_HUB_LOGIN/cloudprober_exporter:prj .
