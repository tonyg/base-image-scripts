#!/bin/sh
# Based on the instructions in making-debian-images.md

SIZE=${SIZE:-10G}
VDI=${VDI:-base}
ROOTKEY=${ROOTKEY:-base-root-key}
DEVICE=${DEVICE:-$(losetup --find)}
TARGET=${TARGET:-`pwd`/target}
PROXY=${PROXY:-http://localhost:3129/}
SUITE=${SUITE:-bookworm}
SECURITY=${SECURITY:-yes}
BACKPORTS=${BACKPORTS:-no}

VDITYPE=${VDITYPE:-qcow2}
VDIEXT=${VDIEXT:-img}

# These defaults are useful for working with ansible.
PKGS=${PKGS:-python3 python3-apt python-is-python3}

if [ `whoami` != 'root' ]; then
    echo "You have to be root to run this. Aborting."
    exit 1
fi

if [ -f "$VDI.$VDIEXT" ]; then
    echo "Uhoh! $VDI.$VDIEXT exists. Aborting."
    exit 1
fi

if [ -z "${DEVICE}" ]; then
    echo "losetup --find couldn't find a device. Aborting."
    exit 1
fi

set -e

apt install --no-install-recommends --no-install-suggests debootstrap

if [ ! -f ${ROOTKEY}.pub ]; then
    ssh-keygen -f ${ROOTKEY} -P ""
    chown $(logname) ${ROOTKEY} ${ROOTKEY}.pub
fi

qemu-img create -f raw $VDI.raw $SIZE
parted $VDI.raw mktable msdos
parted $VDI.raw mkpart primary '0%' '100%'
losetup -P ${DEVICE} $VDI.raw
mkfs.ext4 ${DEVICE}p1

mkdir $TARGET
mount ${DEVICE}p1 $TARGET

http_proxy="${PROXY}" debootstrap ${SUITE} $TARGET http://httpredir.debian.org/debian/

mount --bind /dev $TARGET/dev
mount --bind /proc $TARGET/proc
mount --bind /sys $TARGET/sys

chroot $TARGET <<EOF
set -e
export http_proxy='${PROXY}'
export DEBIAN_FRONTEND=noninteractive
echo "exit 101" > /usr/sbin/policy-rc.d
chmod +x /usr/sbin/policy-rc.d
rm -f /etc/apt/sources.list
echo "deb http://httpredir.debian.org/debian ${SUITE} main contrib non-free" >> /etc/apt/sources.list
echo "deb http://httpredir.debian.org/debian ${SUITE}-updates main contrib non-free" >> /etc/apt/sources.list
if [ "${BACKPORTS}" = "yes" ]; then echo "deb http://httpredir.debian.org/debian ${SUITE}-backports main contrib non-free" >> /etc/apt/sources.list; fi
if [ "${SECURITY}" = "oldstyle" ]; then echo "deb http://security.debian.org/debian-security ${SUITE}/updates main contrib non-free" >> /etc/apt/sources.list; fi
if [ "${SECURITY}" = "yes" ]; then echo "deb http://security.debian.org/debian-security ${SUITE}-security main contrib non-free" >> /etc/apt/sources.list; fi
rm -rf /var/lib/apt/lists
mkdir -p /var/lib/apt/lists/partial
apt-get update
apt-get install -y locales
echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
echo 'LANG=en_US.UTF-8' > /etc/default/locale
locale-gen
apt-get install -y linux-image-amd64 grub-pc
apt-get install -y avahi-daemon avahi-utils libnss-mdns parted
cp /usr/share/doc/avahi-daemon/examples/ssh.service /etc/avahi/services/.
apt-get install -y sudo openssh-server ca-certificates ${PKGS}
apt-get full-upgrade -y --autoremove --purge
apt-get clean
rm -f /etc/ssh/ssh_host_*
rm -f /etc/machine-id /var/lib/dbus/machine-id
echo 'auto lo' > /etc/network/interfaces
echo 'iface lo inet loopback' >> /etc/network/interfaces
echo '127.0.0.1 localhost' > /etc/hosts
echo '127.0.1.1 template-debian' >> /etc/hosts
echo template-debian > /etc/hostname
sed -e 's:GRUB_TIMEOUT=5:GRUB_TIMEOUT=1:' -i /etc/default/grub
update-grub
grub-install --no-floppy --recheck --modules="biosdisk part_msdos" ${DEVICE}
sed -e 's:${DEVICE}p1:/dev/sda1:g' -i /boot/grub/grub.cfg
echo 'rootfs / rootfs rw 0 0' > /etc/fstab
rm /usr/sbin/policy-rc.d
sync
sync
sync
EOF

cp image-rc-local.sh $TARGET/etc/rc.local
cp postbootscript.sh $TARGET/root/.

mkdir -p $TARGET/root/.ssh
chmod 0700 $TARGET/root/.ssh
cp ${ROOTKEY}.pub $TARGET/root/.ssh/authorized_keys
chmod 0644 $TARGET/root/.ssh/authorized_keys

sync
umount $TARGET/dev
umount $TARGET/proc
umount $TARGET/sys
mount -o remount,ro $TARGET
sync
blockdev --flushbufs ${DEVICE}
python3 -c 'import os; os.fsync(open("'${DEVICE}'", "r+b"))'
sleep 1
umount $TARGET
rmdir $TARGET

sync
sleep 1
losetup -d ${DEVICE}
sleep 1

qemu-img convert -f raw -O $VDITYPE $VDI.raw $VDI.$VDIEXT
chown $(logname) $VDI.$VDIEXT
rm $VDI.raw
