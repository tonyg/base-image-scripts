#!/bin/sh
set -ex
docker build -t base-image-scripts-apk-cache .
docker run -it --rm \
       -p 3130:3130 \
       -v /var/tmp/tonyg-apk-cache:/var/spool/squid \
       base-image-scripts-apk-cache
