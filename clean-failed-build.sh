#!/bin/sh
set -e
rm -f *.raw
if [ -d target/dev ]; then umount target/dev; fi
if [ -d target/proc ]; then umount target/proc; fi
if [ -d target/sys ]; then umount target/sys; fi
if [ -d target ]; then umount target || true; rmdir target; fi
losetup -d /dev/loop0
