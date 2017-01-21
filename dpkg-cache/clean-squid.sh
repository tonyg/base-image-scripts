#!/bin/sh
. ./squid-envsetup
./clean-cache-contents.sh
rm -rf squid-${squid_version}/ squid-dist
