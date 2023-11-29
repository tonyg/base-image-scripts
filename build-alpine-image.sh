#!/bin/sh
# Based on build-base-image.sh

SIZE=${SIZE:-10G}
BRANCH=${BRANCH:-edge}
VDI=${VDI:-alpine-${BRANCH}}
ROOTKEY=${ROOTKEY:-base-root-key}
DEVICE=${DEVICE:-$(losetup --find)}
TARGET=${TARGET:-`pwd`/target}
PROXY=${PROXY:-http://localhost:3129/}
MIRROR=${MIRROR:-http://dl-cdn.alpinelinux.org/alpine/}

VDITYPE=${VDITYPE:-qcow2}
VDIEXT=${VDIEXT:-img}

# These defaults are useful for working with ansible.
PKGS=${PKGS:-python3}

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

[ -f apk.static ] || wget https://gitlab.alpinelinux.org/api/v4/projects/5/packages/generic//v2.14.0/x86_64/apk.static
chmod a+x apk.static
chown $(logname) apk.static

if [ ! -f ${ROOTKEY}.pub ]; then
    ssh-keygen -f ${ROOTKEY} -P ""
    chown $(logname) ${ROOTKEY} ${ROOTKEY}.pub
fi

qemu-img create -f raw $VDI.raw $SIZE
parted $VDI.raw mktable msdos
parted $VDI.raw mkpart primary '0%' '100%'
parted $VDI.raw set 1 boot on
losetup -P ${DEVICE} $VDI.raw
mkfs.ext4 -L alpineroot -O ^64bit ${DEVICE}p1

mkdir $TARGET
mount ${DEVICE}p1 $TARGET

http_proxy="${PROXY}" ./apk.static -X ${MIRROR}/${BRANCH}/main -U --allow-untrusted -p $TARGET --initdb add alpine-base

mount --bind /dev $TARGET/dev
mount --bind /proc $TARGET/proc
mount --bind /sys $TARGET/sys

cp /etc/resolv.conf $TARGET/etc/resolv.conf

chroot $TARGET /bin/sh <<EOF
set -e
export http_proxy='${PROXY}'
echo "${MIRROR}/${BRANCH}/main" > /etc/apk/repositories
echo "${MIRROR}/${BRANCH}/community" >> /etc/apk/repositories
apk update
apk upgrade
apk add linux-virt syslinux avahi avahi-tools sudo openssh-server ca-certificates
apk add ${PKGS}
apk cache purge
echo 'auto lo' > /etc/network/interfaces
echo 'iface lo inet loopback' >> /etc/network/interfaces
echo '127.0.0.1 localhost' > /etc/hosts
echo '127.0.1.1 template-alpine' >> /etc/hosts
echo template-alpine > /etc/hostname
dd bs=440 count=1 conv=notrunc if=/usr/share/syslinux/mbr.bin of=${DEVICE}
extlinux --install /boot
sed -e 's:${DEVICE}p1:/dev/vda1:g' -i /boot/extlinux.conf
sed -e 's:TIMEOUT \d\+:TIMEOUT 1:g' -i /boot/extlinux.conf
echo 'LABEL=alpineroot / ext4 rw 0 0' > /etc/fstab
for f in networking sshd avahi-daemon local; do rc-update add \$f default; done
for f in devfs dmesg mdev; do rc-update add \$f sysinit; done
for f in hwclock modules sysctl hostname bootmisc syslog; do rc-update add \$f boot; done
for f in mount-ro killprocs savecache; do rc-update add \$f shutdown; done
sync
sync
sync
EOF

cp image-rc-local.sh $TARGET/etc/local.d/00-image-rc-local.start
cp postbootscript-alpine.sh $TARGET/root/postbootscript.sh

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
