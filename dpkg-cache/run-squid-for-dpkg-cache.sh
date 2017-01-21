#!/bin/sh
SQUID="$(dirname "$0")/squid-dist/sbin/squid -f $(dirname "$0")/squid-for-dpkg-cache.conf -N -d 999"
$SQUID -z ## create cache dirs
exec $SQUID
