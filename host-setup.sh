#!/bin/bash
# Script to configure qemu/kvm hosts.
export LIBVIRT_DEFAULT_URI=${LIBVIRT_DEFAULT_URI:-qemu:///system}

set -e

#---------------------------------------------------------------------------

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

#---------------------------------------------------------------------------

if [ -z "$1" ]
then
    echo "No lan ethernet device specified: not creating a bridge network."
else
    echo "About to set up a bridge network 'lan' for device $1"

    if ! virsh net-list --all | grep -q '^ lan'
    then
        echo " - defining"
        virsh net-define /dev/stdin <<EOF
<network>
  <name>lan</name>
  <forward dev='$1' mode='bridge'>
    <interface dev='$1'/>
  </forward>
</network>
EOF
    else
        echo " - already defined"
    fi

    read netname netstatus netautostart netpersistent <<< \
         $(virsh net-list --all | grep '^ lan')

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
fi
