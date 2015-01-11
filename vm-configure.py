#!/usr/bin/env python2
import sys
import re
import os
import socket
import glob
import threading
import subprocess

vdi = 'base' if len(sys.argv) < 2 else sys.argv[1]
await = sys.argv[2] if len(sys.argv) >= 3 else None

###########################################################################

def machineuuids():
    result = []
    with os.popen('VBoxManage list runningvms') as f:
        for line in f.readlines():
            m = re.match('^.*{([^}]+)}.*$', line)
            if m:
                result.append(m.group(1))
    return result

def stripquotes(s):
    return s[1:-1] if len(s) > 0 and s[0] == '"' else s

_vminfo = {}
def vminfo(vmname):
    if vmname not in _vminfo:
        result = {}
        with os.popen('VBoxManage showvminfo %s --machinereadable' % (vmname,)) as f:
            for line in f.readlines():
                (key,val) = line.strip().split('=', 1)
                key = stripquotes(key)
                val = stripquotes(val)
                result[key] = val
        _vminfo[vmname] = result
    return _vminfo[vmname]

def configure_host(vmname, ipaddr):
    print 'Configuring', ipaddr, 'to have name', vmname
    cmdvars = {'ip': ipaddr, 'vdi': vdi}
    cmd = 'SSH_AUTH_SOCK= ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i %(vdi)s-root-key root@%(ip)s sh' % cmdvars
    (to_remote, from_remote) = os.popen2(cmd)
    scriptvars = {'vmname': vmname}
    to_remote.write('''
if [ -f /root/personalcloud-configured ]; then
  echo "Skipping %(vmname)s - already configured"
else
  if [ "%(vmname)s" != "$(hostname -s)" ]; then
    echo "Updating hostname from $(hostname -s) to %(vmname)s"
    echo "%(vmname)s" > /etc/hostname
    echo "127.0.0.1 localhost" > /etc/hosts
    echo "127.0.1.1 "%(vmname)s"" >> /etc/hosts
    hostname "%(vmname)s"
  else
    echo "Hostname is already configured."
  fi
  echo "Configuration complete."
  touch /root/personalcloud-configured
fi
''' % scriptvars)
    to_remote.close()
    result = from_remote.read()
    from_remote.close()
    return result

def find_and_configure_host(macaddr, ipaddr):
    for uuid in machineuuids():
        v = vminfo(uuid)
        for card in range(1,9):
            cardmac = v.get('macaddress%d' % (card,), False)
            if cardmac == macaddr:
                vmname = v['name']
                print configure_host(vmname, ipaddr)
                sys.stdout.flush()
                if await and vmname == await:
                    print 'Configuration of awaited VM', vmname, 'complete.'
                    sys.stdout.flush()
                    global mainloop_running
                    mainloop_running = False

###########################################################################

def popen(command):
    return subprocess.Popen(command, stdout = subprocess.PIPE, shell = True)

def osx_ip_of_service(servicename):
    p = popen('dns-sd -L %s _personalcloud-configuration._tcp' % (servicename,))
    while True:
        line = p.stdout.readline().strip()
        m = re.search('can be reached at ([^ ]*):([^ ]*)', line)
        if m:
            ipaddr = m.group(1)
            portstr = m.group(2)
            if portstr != '22':
                print 'WARNING: service %s seems to be running ssh on port %s' % (servicename, portstr)
            p.terminate()
            return ipaddr

if await:
    print 'Awaiting VM', await, '...'
    sys.stdout.flush()
mainloop_running = True
if os.system('which dns-sd >/dev/null') == 0:
    p = popen('dns-sd -B _personalcloud-configuration._tcp')
    f = p.stdout
    while mainloop_running:
        fields = re.split(' +', f.readline().strip())
        if len(fields) >= 6 and fields[5] == '_personalcloud-configuration._tcp.' and fields[1] == 'Add':
            servicename = fields[6]
            macaddr = servicename.split('-')[-1].upper()
            if len(macaddr) != 12: continue
            ipaddr = osx_ip_of_service(servicename)
            print servicename, ipaddr, macaddr
            find_and_configure_host(macaddr, ipaddr)
    p.terminate()
elif os.system('which avahi-browse >/dev/null') == 0:
    p = popen('avahi-browse -p -k -r _personalcloud-configuration._tcp')
    f = p.stdout
    while mainloop_running:
        fields = f.readline().strip().split(';', 9)
        if fields[0] == '=' and fields[2] == 'IPv4':
            servicename = fields[3]
            ipaddr = fields[7]
            macaddrs = fields[9].upper().replace(':', '').replace('"', '').split()
            print servicename, ipaddr, macaddrs
            for macaddr in macaddrs:
                find_and_configure_host(macaddr, ipaddr)
    p.terminate()
else:
    raise Exception('Neither dns-sd nor avahi-browse is available - cannot continue')
