#!/bin/sh
# Builds a customised debian netinst iso using a preseed script.
# After http://blog.g0blin.co.uk/programming/ubuntu-preseed-virtualbox-and-hetzner-eq4-virtual-machines/
# and http://garfield001.wordpress.com/2012/05/30/modifying-bootable-debian-iso-image-with-preseed-for-automatic-installation/
set -e

sourceiso="$1"
targethostname="$2"
targetrootpassword="$3"
if [ -z "$sourceiso" -o -z "$targethostname" -o -z "$targetrootpassword" ]; then
    echo "Usage: $0 <some-debian-netinst.iso> <newhostname> <newrootpassword>"
    exit 1
fi

ensuredir () {
    if [ -e "$1" ]; then
	rmdir "$1"
    fi
    mkdir "$1"
}

#targetiso="$(basename "$sourceiso" .iso)-custom-$(date '+%Y%m%d%H%M%S').iso"
targetiso="$(basename "$sourceiso" .iso)-custom.iso"

ensuredir customiso
ensuredir mountpoint
ensuredir custominitrd

## Mount source ISO and copy it somewhere useful

mount -o loop,ro "$sourceiso" mountpoint
rsync -a -H --exclude=TRANS.TBL mountpoint/. customiso/.
umount mountpoint
rmdir mountpoint

## Extract initrd and place preseed in it

gzip -d < customiso/install.amd/initrd.gz | \
  (cd custominitrd; cpio --extract --make-directories --no-absolute-filenames)
cat debian-preseed.txt | \
    sed \
        -e "s/@HOSTNAME@/$targethostname/g" \
        -e "s/@ROOTPASSWORD@/$targetrootpassword/g" \
    > custominitrd/preseed.cfg

## Rebuild initrd after modifications

chmod +w customiso/install.amd/initrd.gz
(cd custominitrd; find . | cpio -H newc --create | gzip -9) > customiso/install.amd/initrd.gz
chmod -w customiso/install.amd/initrd.gz

## Set timeout to nonzero so that it chooses the "Install" option from the boot menu

chmod +w customiso/isolinux/isolinux.cfg
sed -e 's/timeout 0/timeout 1/' -i customiso/isolinux/isolinux.cfg
chmod -w customiso/isolinux/isolinux.cfg

## Rebuild the checksums

chmod +w customiso/md5sum.txt
(cd customiso; md5sum `find -follow -type f`) > customiso/md5sum.txt
chmod -w customiso/md5sum.txt

## Rebuild the ISO after modifications

genisoimage \
    -o $targetiso -r -J -no-emul-boot -boot-load-size 4 -boot-info-table \
    -b isolinux/isolinux.bin -c isolinux/boot.cat ./customiso

## Clean up

rm -rf customiso
rm -rf custominitrd
