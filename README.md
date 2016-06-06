# Debootstrapping a reusable VirtualBox debian image

(Based on `me.org` journal entry of 2010-04-15 14:24:46.)

The idea here is to use `debootstrap` to directly install debian on a
target partition or volume.

## Mount a .vdi file in order to configure it

Creating a dynamically-expanding VDI called `base.vdi` of size 10,000 megabytes:

    VBoxManage createhd --filename base --size 10000

Attaching it as if it were a block device:

	sudo modprobe nbd max_part=16
	sudo qemu-nbd -c /dev/nbd0 base.vdi
	sleep 1

Now use fdisk on `/dev/nbd0`. Don't forget the bootable flag on the
new partition you create!

    sudo fdisk /dev/nbd0

After fdisk writes and exits, `/dev/nbd0p1` should exist.

	sudo mkfs.ext4 /dev/nbd0p1

Now you can mount the partition to some target directory.

## Install squid-deb-proxy

    sudo apt-get install squid-deb-proxy

Change `/etc/squid-deb-proxy/squid-deb-proxy.conf`'s `http_port` from
8000 to 3129. Then,

    sudo /etc/init.d/squid-deb-proxy start

## Debootstrap the initial installation

Below I've written `$TARGET` to denote the directory upon which the
target partition is mounted, e.g. `/mnt` or `$(pwd)/target` etc.

    export TARGET=`pwd`/target
	mkdir $TARGET
	sudo mount /dev/nbd0p1 $TARGET

Make sure to mount `/dev`, `/proc` and `/sys` on the target filesystem
so that installing grub works.

These instructions assume you're using squid-deb-proxy.

See [here](http://jpetazzo.github.io/2013/10/06/policy-rc-d-do-not-start-services-automatically/)
for information on the `policy-rc.d` trick for avoiding service
startup.

	sudo http_proxy='http://localhost:3129/' debootstrap wheezy $TARGET
	sudo mount --bind /dev $TARGET/dev
	sudo mount --bind /proc $TARGET/proc
	sudo mount --bind /sys $TARGET/sys
	sudo chroot $TARGET
	export http_proxy='http://localhost:3129/'
	export DEBIAN_FRONTEND=noninteractive
	echo "exit 101" > /usr/sbin/policy-rc.d
    chmod +x /usr/sbin/policy-rc.d
    rm -f /etc/apt/sources.list
	echo "deb http://ftp.us.debian.org/debian wheezy main contrib non-free" >> /etc/apt/sources.list
	echo "deb http://ftp.us.debian.org/debian wheezy-updates main contrib non-free" >> /etc/apt/sources.list
	echo "deb http://security.debian.org/ wheezy/updates main contrib non-free" >> /etc/apt/sources.list
	rm -rf /var/lib/apt/lists
	mkdir -p /var/lib/apt/lists/partial
	apt-get update
    apt-get install -y locales
	echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
	echo 'LANG=en_US.UTF-8' > /etc/default/locale
	locale-gen
	apt-get install -y linux-image-amd64 grub-pc
    apt-get install -y avahi-daemon avahi-utils libnss-mdns
	apt-get install -y sudo openssh-server
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
	grub-install --no-floppy --recheck --modules="biosdisk part_msdos" /dev/nbd0
	sed -e 's:/dev/nbd0p1:/dev/sda1:g' -i /boot/grub/grub.cfg
	rm /usr/sbin/policy-rc.d

Now exit the chroot. Set up rc.local to run a post-boot script, if one
is present and executable:

    sudo cp image-rc-local.sh $TARGET/etc/rc.local
    sudo cp postbootscript.sh $TARGET/root/.

Make an SSH key and copy it in as root's authorized_keys file:

    ssh-keygen -f base-root-key -P ""
	sudo mkdir -p $TARGET/root/.ssh
	sudo chmod 0700 $TARGET/root/.ssh
	sudo cp base-root-key.pub $TARGET/root/.ssh/authorized_keys
	sudo chmod 0644 $TARGET/root/.ssh/authorized_keys

Unmount the image:

	sudo umount $TARGET/dev
	sudo umount $TARGET/proc
	sudo umount $TARGET/sys
	sudo umount $TARGET

(OPTIONAL AND POSSIBLY DANGEROUS? zerofree seems to corrupt things
sometimes.) Clean out zero blocks, and fsck it (NOTE: make sure the
device name is correct!):

	sudo zerofree -v /dev/nbd0p1
	sudo fsck -f /dev/nbd0p1

Finally, detach the device; if you're using a VDI, use `qemu-nbd`:

    sync
	sleep 1
    sudo qemu-nbd -d /dev/nbd0
	sleep 1

At this point, you can mark the disk image immutable, in virtualbox
terminology. Use VBoxManage:

    VBoxManage modifyhd base.vdi --type immutable --compact

Don't forget the compact flag, which annihilates the zeroed out blocks
we put in just now.

See [`vm-create.sh`](vm-create.sh) for a script which creates new VMs
based off the immutable image.

The general idea (for *bridged* configurations) is as follows:

	VBoxManage createvm --name "$vmname" --ostype Debian_64 --register
	VBoxManage modifyvm "$vmname" --memory 256 --nic1 bridged --bridgeadapter1 "$bridgeif"
	VBoxManage storagectl "$vmname" --name "IDE Controller" --add ide
	VBoxManage storageattach "$vmname" --storagectl "IDE Controller" --port 0 --device 0 --type hdd --medium "$basevdi"
	VBoxManage modifyhd $(VBoxManage showvminfo "$vmname" --machinereadable | grep '^"IDE Controller-ImageUUID-0-0"' | sed -e 's:.*="\(.*\)":\1:g') --autoreset off

If, when you start such a new machine, you get a
`VERR_GENERAL_FAILURE` and it won't start, make sure the
"--bridgeadapter1" argument is correct for your system. Using the GUI
to see the available options may help.

Now when you attach the base disk image to a VM, it will use a
differencing disk just for that VM. However, by default it will also
reset the VM to the base disk image every time you reboot it! Stopping
this is the purpose of the modifyhd command above.

In order to change the hostname of the new guest,

	echo newhostname > /etc/hostname
	echo '127.0.0.1 localhost' > /etc/hosts
	echo '127.0.1.1 newhostname' >> /etc/hosts

and reboot. These steps are included in the postbootscript.sh script
inserted by `vm-create.sh`.

# VBoxManage tips

To remove an image file:

    vboxmanage list hdds
    vboxmanage closemedium disk <uuid> --delete
