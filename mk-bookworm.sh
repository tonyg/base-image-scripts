#!/bin/sh
# Debian 12, Bookworm
exec /usr/bin/env \
    VDI=bookworm \
    SUITE=bookworm \
    SECURITY=yes \
    BACKPORTS=no \
    ./build-base-image.sh
