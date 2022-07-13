#!/bin/sh
# Debian 11, Bullseye
exec /usr/bin/env \
    VDI=bullseye \
    SUITE=bullseye \
    SECURITY=yes \
    BACKPORTS=yes \
    ./build-base-image.sh
