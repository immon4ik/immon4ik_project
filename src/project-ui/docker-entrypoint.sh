#!/bin/sh
set -e

cd ui && gunicorn ui:app -b 0.0.0.0
