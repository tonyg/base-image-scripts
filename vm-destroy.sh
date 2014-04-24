#!/bin/sh
vmname=$1

if [ -z "$vmname" ]
then
    echo "Usage: vm-destroy.sh <vmname>"
    exit 1
fi

echo "Will destroy vm $vmname. Enter 'yes' to continue."
read confirmation

if [ "$confirmation" != "yes" ]; then
    echo Aborting because of lack of confirmation.
    exit 1
fi

vminfo="$(VBoxManage showvminfo "$vmname" --machinereadable)"

getfield () {
    echo "$1" | \
	grep "^$2=" | \
	sed -e 's:.*=\(.*\)$:\1:g' | \
	sed -e 's:^"\(.*\)"$:\1:g'
}

if [ -z "$vminfo" ]; then
    echo "Machine not found?"
    exit 1
fi

if [ $(getfield "$vminfo" 'VMState') != poweroff ]; then
    VBoxManage controlvm "$vmname" poweroff
fi

machinestorageuuid=$(getfield "$vminfo" '"IDE Controller-ImageUUID-0-0"')

if [ -n "$machinestorageuuid" ]; then
    VBoxManage storageattach "$vmname" --storagectl "IDE Controller" --port 0 --device 0 --type hdd --medium none
    VBoxManage closemedium disk "$machinestorageuuid" --delete
fi

VBoxManage unregistervm "$vmname" --delete

exit 0
