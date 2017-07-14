#!/bin/sh

cat > /etc/apt/apt.conf.d/99tonyg-norecommends <<EOF
APT::Install-Recommends "0";
APT::Install-Suggests "0";
EOF

cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback
EOF

ifaces="$(ls /sys/class/net)"
allmacs=''
chosenmac=''
for iface in $ifaces
do
    macaddr="$(cat /sys/class/net/$iface/address)"
    if [ "$macaddr" != '00:00:00:00:00:00' ]; then
	allmacs="$allmacs $macaddr"
	chosenmac=${chosenmac:-$macaddr}

        echo "auto $iface" >> /etc/network/interfaces
        echo "iface $iface inet dhcp" >> /etc/network/interfaces
    fi
done

if [ -z "$chosenmac" ]; then
    echo "Can't decide which MAC address to use for temporary hostname."
    exit 1
fi

tmphostname="tmp-$(echo $chosenmac | tr -d ':')"

# Pick up the net /etc/network/interfaces:
service networking restart

# (Re)generate host keys
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
