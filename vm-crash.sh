#!/bin/sh
vmname=$1
if [ -z "$vmname" ]
then
    echo "Usage: vm-crash.sh <vmname>"
    exit 1
fi
echo "Will crash vm $vmname! Ctrl-C to cancel, enter to continue."
read dummy

VBoxManage controlvm "$vmname" poweroff
