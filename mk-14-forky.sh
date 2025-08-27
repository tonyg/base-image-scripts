#!/bin/sh
# Debian 14, Forky
exec /usr/bin/env \
    VDI=forky \
    SUITE=forky \
    SECURITY=yes \
    BACKPORTS=no \
    ./build-base-image.sh
