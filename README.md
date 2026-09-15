# logitech-bolt-hidpp-dkms

`hid-logitech-hidpp` with high-resolution wheel events diverted to HID++ on
Logitech Bolt receivers, built by DKMS for every installed kernel.

## What it fixes

On a Bolt receiver (`046d:c548`) the stock driver switches an MX Master 4's
wheel into high-resolution mode, 15 steps per notch, and expects to scale those
steps back down. On the Bolt topology `hid-logitech-dj` never hands them to it,
so they reach userspace unscaled: one notch scrolls fifteen lines.

The patch detects the Bolt topology and diverts wheel events to HID++
notifications, which do reach the driver. One notch is one notch again, and
free-spin scrolling stays pixel-smooth. The thumbwheel is kept on native
reporting, because diverting it on this mouse silences it. The full analysis is
the commit message at the top of each patch.

Tested with an MX Master 4 for Mac (WPID `B042`).

## How the build works

Kernel headers do not include driver sources, and pacman runs hooks, DKMS
included, in a network namespace with only loopback. So the repository carries
the source:

- `vendor/vX.Y/` is the unmodified upstream driver, `hid-logitech-hidpp.c` and
  the two headers it includes, for kernel series X.Y, at the tag named in
  `vendor/vX.Y/TAG`.
- `patches/vX.Y-*.patch` is the patch for that series. 7.2 has its own copy
  because one hunk anchors on reprogrammable-controls code that only exists
  from 7.3.
- `build.sh` copies the series matching the kernel DKMS is building, applies
  its patch and builds the module against the installed headers, offline.

| Series | Vendored tag | Patch                              |
|--------|--------------|------------------------------------|
| v7.2   | `v7.2.6`     | `v7.2-mx-master4-bolt-divert.patch` |
| v7.3   | `v7.3-rc3`   | `v7.3-mx-master4-bolt-divert.patch` |

Every kernel in a series runs the vendored driver version, not necessarily its
own point release's. A kernel from a series with no `vendor/` directory fails
its DKMS build in the pacman output and keeps its stock driver, which means
15-line scrolling until the series is added.

The module installs to `updates/dkms`. While it is installed, DKMS keeps the
stock `hid-logitech-hidpp.ko.zst` in
`/var/lib/dkms/logitech-bolt-hidpp/original_module` and puts it back when the
package is removed, so `pacman -Qkk` reports that file missing in the meantime.

## Install

Needs the headers package for each kernel, e.g. `linux-cachyos-headers`.

```sh
git clone https://github.com/Magnetar-OS/logitech-bolt-hidpp-dkms
cd logitech-bolt-hidpp-dkms/packaging/arch
makepkg -si
```

The DKMS hook builds the module for every kernel with headers, and the
initramfs hook regenerates the images. Those images no longer carry
`hid-logitech-hidpp`: the `keyboard` hook only finds it at the stock path,
which DKMS has moved aside. Early boot uses the generic HID driver, and the
patched module takes the receiver's devices over once the root filesystem is
up. The running kernel keeps the module it loaded at boot, so either reboot or
reload it and power-cycle the mouse once:

```sh
sudo modprobe -r hid_logitech_hidpp && sudo modprobe hid_logitech_hidpp
```

## Update

Kernel updates within a vendored series rebuild the module automatically.

For a new kernel series, or an upstream change to the driver:

```sh
tools/update-source.sh v7.4-rc1   # fetches vendor/v7.4, dry-runs patches/v7.4-*.patch
# no patches/v7.4-*.patch yet? copy the newest one and fix it against vendor/v7.4
bash tests/test-build-plan.sh
git add vendor patches && git commit && git push
cd packaging/arch && makepkg -si
```

## Verify

```sh
dkms status logitech-bolt-hidpp
modinfo -n hid_logitech_hidpp   # .../updates/dkms/hid-logitech-hidpp.ko*
```

In `libinput debug-events`, scroll events come from the "MX Master 4" device
and one notch reports a v120 of 120.

## Solaar

Keep `hires-scroll-mode` true and `thumb-scroll-mode` false. Turning wheel
diversion off while leaving resolution on brings the 15× scroll back.

## Remove

```sh
sudo pacman -R logitech-bolt-hidpp-dkms-git
```

## Development

```sh
bash tests/test-build-plan.sh                                  # offline, includes patch dry-runs
./build.sh "$(uname -r)" "/usr/lib/modules/$(uname -r)/build"  # real build into src/, no install
```

## Upstream

Not submitted yet. Each patch carries its commit message for
`linux-input@vger.kernel.org`. It explains Solaar issue #2764, "MX Master 3S
Scroll Wheel Resolution inconsistent between Bluetooth and Bolt Dongle".

## License

GPL-2.0-only, the kernel's license.
