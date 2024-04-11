#!/bin/sh
# Debian 13, Trixie
exec /usr/bin/env \
    VDI=trixie \
    SUITE=trixie \
    SECURITY=yes \
    BACKPORTS=no \
    ./build-base-image.sh
