#!/bin/sh
vmname=$1
if [ -z "$vmname" ]
then
    echo "Usage: vm-wait.sh <vmname>"
    exit 1
fi

VBoxManage startvm "$vmname" --type headless
$(dirname "$0")/vm-configure.py base ${vmname}

echo
echo "$vmname configured and booting."
until ping -c 1 ${vmname}.local >/dev/null ; do
    echo "waiting for ping to respond..."
done
sleep 2
echo | nc ${vmname}.local 22 | head -1
echo "$vmname is ready."
