#!/bin/bash
# Script to configure qemu/kvm hosts.
export LIBVIRT_DEFAULT_URI=${LIBVIRT_DEFAULT_URI:-qemu:///system}

set -e

echo "About to start the default network and mark it autostart."

read netname netstatus netautostart netpersistent <<< \
     $(virsh net-list --all | grep '^ default')
if [ "$netstatus" = "inactive" ]
then
    echo " - starting"
    virsh net-start "$netname"
else
    echo " - already running"
fi
if [ "$netautostart" = "no" ]
then
    echo " - marking autostart"
    virsh net-autostart "$netname"
else
    echo " - already marked autostart"
fi
