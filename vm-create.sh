#!/bin/sh
vmname=$1
nettype=$2
ifacename=$3
basevdi=$4

RAM=${RAM:-256}
VMGROUPS=${VMGROUPS:-/personalcloud}
CPUS=${CPUS:-1}

if [ $(whoami) = "root" ]
then
    echo "Don't run this script as root."
    exit 1
fi

if [ -z "$vmname" -o -z "$nettype" -o -z "$ifacename" -o -z "$basevdi" -o ! -r "$basevdi" ]
then
    echo "Usage: vm-create.sh <vmname> (bridged|hostonly) <ifacename> <basevdi>"
    echo "Available bridged ifacenames:"
    VBoxManage list bridgedifs | grep ^Name
    echo "Available hostonly ifacenames:"
    VBoxManage list hostonlyifs | grep ^Name
    exit 1
fi

getfield () {
    echo "$1" | \
	grep "^$2=" | \
	sed -e 's:.*=\(.*\)$:\1:g' | \
	sed -e 's:^"\(.*\)"$:\1:g'
}

common_setup () {
    VBoxManage modifyhd "$basevdi" --type immutable --compact
    VBoxManage createvm --name "$vmname" --ostype Debian_64 --register
    VBoxManage modifyvm "$vmname" --memory ${RAM} --groups ${VMGROUPS} --audio none --cpus ${CPUS}
    VBoxManage storagectl "$vmname" --name "IDE Controller" --add ide
    VBoxManage storageattach "$vmname" --storagectl "IDE Controller" --port 0 --device 0 --type hdd --medium "$basevdi"

    vminfo="$(VBoxManage showvminfo "$vmname" --machinereadable)"
    diskuuid="$(getfield "$vminfo" '"IDE Controller-ImageUUID-0-0"')"

    VBoxManage modifyhd "$diskuuid" --autoreset off
}

case $nettype in
    bridged)
        echo "Will create vm $vmname, bridging to $ifacename. Ctrl-C to cancel, enter to continue."
	read dummy
	common_setup
	VBoxManage modifyvm "$vmname" --nic1 bridged --bridgeadapter1 "$ifacename"
	;;
    hostonly)
	echo "Will create vm $vmname, attached to host-only network $ifacename. Ctrl-C to cancel, enter to continue."
	read dummy
	common_setup
	VBoxManage modifyvm "$vmname" \
	    --nic1 nat \
	    --nic2 hostonly --hostonlyadapter2 "$ifacename"
	;;
    *)
	echo "Invalid nettype: choose one of bridged or hostonly."
	exit 1
esac

exit 0
