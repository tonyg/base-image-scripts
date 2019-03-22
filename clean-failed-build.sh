#!/bin/sh
set -e
rm -f *.raw
umount target/dev
umount target/proc
umount target/sys
umount target
rmdir target
losetup -d /dev/loop0
