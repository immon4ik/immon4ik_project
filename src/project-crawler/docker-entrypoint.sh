#!/bin/sh
set -e

sleep 30
cd crawler && python3 -u crawler.py https://vitkhab.github.io/search_engine_test_site/
