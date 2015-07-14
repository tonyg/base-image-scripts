#!/bin/sh
# Based on the instructions in making-debian-images.md

SIZE=${SIZE:-10G}
VDI=${VDI:-base}
DEVICE=${DEVICE:-loop0}
TARGET=${TARGET:-`pwd`/target}
PROXY=${PROXY:-http://localhost:3129/}
SUITE=${SUITE:-jessie}

# These defaults are useful for working with ansible.
PKGS=${PKGS:-python python-apt}

if [ `whoami` != 'root' ]; then
    echo "You have to be root to run this. Aborting."
    exit 1
fi

if [ -f "$VDI.vdi" ]; then
    echo "Uhoh! $VDI.vdi exists. Aborting."
    exit 1
fi

set -e

if [ ! -f ${VDI}-root-key.pub ]; then
    ssh-keygen -f ${VDI}-root-key -P ""
    chown $(logname) ${VDI}-root-key ${VDI}-root-key.pub
fi

qemu-img create -f raw $VDI.raw $SIZE
parted $VDI.raw mktable msdos
parted $VDI.raw mkpart primary '0%' '100%'
losetup -P /dev/${DEVICE} $VDI.raw
mkfs.ext4 /dev/${DEVICE}p1

mkdir $TARGET
mount /dev/${DEVICE}p1 $TARGET

http_proxy="${PROXY}" debootstrap ${SUITE} $TARGET

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
echo "deb http://ftp.us.debian.org/debian ${SUITE} main contrib non-free" >> /etc/apt/sources.list
echo "deb http://ftp.us.debian.org/debian ${SUITE}-updates main contrib non-free" >> /etc/apt/sources.list
echo "deb http://security.debian.org/ ${SUITE}/updates main contrib non-free" >> /etc/apt/sources.list
rm -rf /var/lib/apt/lists
mkdir -p /var/lib/apt/lists/partial
apt-get update
apt-get install -y locales
echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
echo 'LANG=en_US.UTF-8' > /etc/default/locale
locale-gen
apt-get install -y linux-image-amd64 grub-pc
apt-get install -y avahi-daemon avahi-utils libnss-mdns
apt-get install -y sudo openssh-server ${PKGS}
rm /etc/ssh/ssh_host_*
echo 'auto lo' > /etc/network/interfaces
echo 'iface lo inet loopback' >> /etc/network/interfaces
echo 'auto eth0' >> /etc/network/interfaces
echo 'iface eth0 inet dhcp' >> /etc/network/interfaces
echo 'auto eth1' >> /etc/network/interfaces
echo 'iface eth1 inet dhcp' >> /etc/network/interfaces
echo '127.0.0.1 localhost' > /etc/hosts
echo '127.0.1.1 template-debian' >> /etc/hosts
echo template-debian > /etc/hostname
sed -e 's:GRUB_TIMEOUT=5:GRUB_TIMEOUT=1:' -i /etc/default/grub
update-grub
grub-install --no-floppy --recheck --modules="biosdisk part_msdos" /dev/${DEVICE}
sed -e 's:/dev/${DEVICE}p1:/dev/sda1:g' -i /boot/grub/grub.cfg
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
cp ${VDI}-root-key.pub $TARGET/root/.ssh/authorized_keys
chmod 0644 $TARGET/root/.ssh/authorized_keys

sync
umount $TARGET/dev
umount $TARGET/proc
umount $TARGET/sys
mount -o remount,ro $TARGET
sync
blockdev --flushbufs /dev/${DEVICE}
python -c 'import os; os.fsync(open("/dev/'${DEVICE}'", "r+b"))'
sleep 1
umount $TARGET
rmdir $TARGET

sync
sleep 1
losetup -d /dev/${DEVICE}
sleep 1

qemu-img convert -f raw -O vdi $VDI.raw $VDI.vdi
chown $(logname) $VDI.vdi
sudo -u $(logname) VBoxManage modifyhd $VDI.vdi --type immutable --compact
rm $VDI.raw
