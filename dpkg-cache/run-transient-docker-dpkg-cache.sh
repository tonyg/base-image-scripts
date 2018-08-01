#!/bin/sh
set -ex
docker build -t base-image-scripts-dpkg-cache .
docker run -it --rm \
       -p 3129:3129 \
       -v /var/tmp/tonyg-dpkg-cache:/var/cache/apt-cacher-ng \
       base-image-scripts-dpkg-cache
