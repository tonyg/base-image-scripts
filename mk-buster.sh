#!/bin/sh
# Debian 10, Buster
exec /usr/bin/env \
    VDI=buster \
    SUITE=buster \
    SECURITY=oldstyle \
    BACKPORTS=yes \
    PKGS="${PKGS:-python3 python3-apt}" \
    ./build-base-image.sh
