# Troubleshooting

## GUI and command-line tools

To use `virsh`,

    . vm-env
    virsh

The `vm-env` snippet sets the `LIBVIRT_DEFAULT_URI` environment
variable appropriately.

For a GUI,

    virt-manager

## "Requested operation is not valid: network 'default' is not active"

You may see this:

    error: Failed to start domain <THEMACHINENAME>
    error: Requested operation is not valid: network 'default' is not active

Your qemu/libvirt setup hasn't enabled the default network.

Did you remember to run `host-setup.sh`?

In `virt-manager`, "start" the `default` virtual network, and mark it
for autostart. Or,

    virsh net-start default
    virsh net-autostart default
