#!/bin/sh
# Debian 13, Trixie
exec /usr/bin/env \
    VDI=trixie \
    SUITE=trixie \
    SECURITY=yes \
    BACKPORTS=yes \
    ./build-base-image.sh
