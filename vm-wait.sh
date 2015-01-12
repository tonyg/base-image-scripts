#!/bin/sh
vmname=$1
vdi=${2:-base}
if [ -z "$vmname" -o -z "$vdi" ]
then
    echo "Usage: vm-wait.sh <vmname> <basevdibasename>"
    exit 1
fi

VBoxManage startvm "$vmname" --type headless
$(dirname "$0")/vm-configure.py ${vdi} ${vmname}

echo
echo "$vmname configured and booting."
until ping -c 1 ${vmname}.local >/dev/null ; do
    echo "waiting for ping to respond..."
done
sleep 2
echo | nc ${vmname}.local 22 | head -1
echo "$vmname is ready."
