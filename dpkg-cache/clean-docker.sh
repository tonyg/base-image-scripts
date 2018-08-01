#!/bin/sh
./clean-cache-contents.sh
docker rmi base-image-scripts-dpkg-cache
