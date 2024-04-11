#!/bin/sh

exec >>/root/postbootscript.log 2>&1

echo
echo " --- Booting --- "
date
echo

# Grow the filesystem
# This `---pretend-input-tty` flag (note triple dash!) is undocumented (!)
# See https://unix.stackexchange.com/questions/190317/gnu-parted-resizepart-in-script
#  or https://techtitbits.com/2018/12/using-parteds-resizepart-non-interactively-on-a-busy-partition/
yes | parted ---pretend-input-tty /dev/vda resizepart 1 '100%'
resize2fs /dev/vda1

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
ssh-keygen -A

# (Re)generate machine-id
dbus-uuidgen --ensure=/etc/machine-id
dbus-uuidgen --ensure

echo "Awaiting configuration..."
avahi-publish -s $tmphostname "_personalcloud-configuration._tcp" 22 $allmacs &
avahipid=$!

while [ ! -f /root/personalcloud-configured ]; do
    sleep 5
    echo "Still waiting..."
done

kill $avahipid

chmod a-x $0

reboot
