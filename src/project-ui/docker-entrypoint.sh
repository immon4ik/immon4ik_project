#!/bin/sh
set -e

sleep 10
cd ui && gunicorn ui:app -b 0.0.0.0
