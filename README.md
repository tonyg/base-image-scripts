# Producing small, reusable qemu debian and alpine images

The idea is to use `debootstrap` resp. `apk.static` to directly install debian or alpine on a
target partition or volume.

See [build-base-image.sh](build-base-image.sh) (Debian) and
[build-alpine-image.sh](build-alpine-image.sh) (Alpine).

# Prerequisites

To build images:

    apt install parted

To configure and run them:

    apt install libvirt-daemon libvirt-daemon-system libvirt-clients avahi-utils
    apt install racket

Add your username to the `libvirt` group.

Run `host-setup.sh`.

If you want to use `personalcloud-images` to hold active VM disk images, make sure it can be
accessed and written to by `libvirt-qemu` group:

    chown :libvirt-qemu personalcloud-images
    chmod g+wx personalcloud-images

This includes `x`-bit access to the folders leading up to `personalcloud-images`!

On WSL2, make sure `ping` is allowed to do its job:

    sudo setcap cap_net_raw+p `which ping`

## Build a Debian image

Start the dpkg cache by

    cd dpkg-cache; ./run-transient-docker-dpkg-cache.sh

In another window,

    sudo ./build-base-image.sh

If things go wrong,

    sudo ./clean-failed-build.sh

(In some cases you may need to clean out the loopback devices by hand with `sudo losetup -d ...`.)

## Build an Alpine image

Start the apk cache by

    cd apk-cache; ./run-transient-docker-apk-cache.sh

In another window,

    sudo ./build-alpine-image.sh

If things go wrong,

    sudo ./clean-failed-build.sh

(In some cases you may need to clean out the loopback devices by hand with `sudo losetup -d ...`.)
