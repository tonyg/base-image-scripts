#!/bin/sh
. ./squid-envsetup

echo 'Downloading source archive (if not present)...'
[ -f ${squid_archive} ] || \
    wget "http://www.squid-cache.org/Versions/v${squid_topversion}/${squid_topversion}.${squid_midversion}/${squid_archive}"

echo 'Removing previous build...'
rm -rf squid-${squid_version}/

echo 'Untarring source code...'
tar -axf squid-${squid_version}.tar.bz2

echo 'Configuring and building...'
distdir="`pwd`/squid-dist"
(cd squid-${squid_version}/; ./configure --prefix="$distdir" && make -j && make install)
