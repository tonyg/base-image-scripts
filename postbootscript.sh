#!/bin/sh

ifaces="$(ls /sys/class/net)"
allmacs=''
chosenmac=''
for iface in $ifaces
do
    macaddr="$(cat /sys/class/net/$iface/address)"
    if [ "$macaddr" != '00:00:00:00:00:00' ]; then
	allmacs="$allmacs $macaddr"
	chosenmac=${chosenmac:-$macaddr}
    fi
done

if [ -z "$chosenmac" ]; then
    echo "Can't decide which MAC address to use for temporary hostname."
    exit 1
fi

tmphostname="tmp-$(echo $chosenmac | tr -d ':')"

dpkg-reconfigure openssh-server

echo "Awaiting configuration..."
avahi-publish -s $tmphostname "_personalcloud-configuration._tcp" 22 $allmacs &

while [ ! -f /root/personalcloud-configured ]; do
    sleep 5
    echo "Still waiting..."
done

kill %1

chmod a-x $0

reboot
