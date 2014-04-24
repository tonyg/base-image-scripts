#!/bin/sh
vmname=$1
if [ -z "$vmname" ]
then
    echo "Usage: vm-start.sh <vmname>"
    exit 1
fi

VBoxManage startvm "$vmname" --type headless
