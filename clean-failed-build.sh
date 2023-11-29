#!/bin/sh
set -e
rm -f *.raw

ismounted() {
    cat /proc/self/mountinfo | cut -d' ' -f 5 | grep -q "$1"
}

cleanup() {
    if [ -d "$1" ] && ismounted "$1"
    then
        umount "$1"
    fi
}

cleanup `pwd`/target/dev
cleanup `pwd`/target/proc
cleanup `pwd`/target/sys
cleanup `pwd`/target
rmdir target
losetup -d /dev/loop0
