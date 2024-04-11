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

TARGET=${TARGET:-$(find `pwd` -type d -iname 'target-*')}
cleanup `pwd`/${TARGET}/dev
cleanup `pwd`/${TARGET}/proc
cleanup `pwd`/${TARGET}/sys
cleanup `pwd`/${TARGET}
rmdir ${TARGET}
losetup -d /dev/loop0
