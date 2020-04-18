#!/bin/bash
set -e

sleep 10
pwd
cd /tmp/ && docker-compose up -d
dockr-compose ps -a
dockr-compose logs mongo_db rabbit_mq crawler ui
