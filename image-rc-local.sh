#!/bin/sh
# rc.local for base images

if [ -x /root/postbootscript.sh ]; then
    /root/postbootscript.sh
fi

exit 0
