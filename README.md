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

Tested with an MX Master 4 for Mac (WPID `B042`) on kernels 7.2.5 and 7.3-rc2.

## How the build works

Kernel headers do not include driver sources. `build.sh` downloads the three
source files for the exact kernel DKMS is building from git.kernel.org, applies
the patch, and builds the module against the installed headers:

| Kernel release           | Source tag | Patch                                  |
|--------------------------|------------|----------------------------------------|
| `7.2.5-1-cachyos`        | `v7.2.5`   | `patches/v7.2-mx-master4-bolt-divert.patch` |
| `7.3.0-rc2-1-cachyos-rc` | `v7.3-rc2` | `patches/v7.3-mx-master4-bolt-divert.patch` |

- `patches/vX.Y-*.patch` applies from kernel series X.Y on, and the newest one
  not newer than the kernel is used. 7.2 has its own copy because one hunk
  anchors on reprogrammable-controls code that only exists from 7.3.
- The sources are vanilla upstream tags, not the distribution's kernel tree.
- A kernel install needs network access.
- If the download fails or the patch stops applying, the DKMS build fails in
  the pacman output and that kernel keeps its stock driver, which means
  15-line scrolling. Add a patch for the new series under `patches/` and
  reinstall.

## Install

Needs the headers package for each kernel, e.g. `linux-cachyos-headers`.

```sh
git clone https://github.com/Magnetar-OS/logitech-bolt-hidpp-dkms
cd logitech-bolt-hidpp-dkms/packaging/arch
makepkg -si
```

The DKMS hook builds the module for every kernel with headers, and the
initramfs hook regenerates the images; the `keyboard` hook puts this driver in
the initramfs. The running kernel keeps the module it loaded at boot, so either
reboot or reload it and power-cycle the mouse once:

```sh
sudo modprobe -r hid_logitech_hidpp && sudo modprobe hid_logitech_hidpp
```

## Update

Kernel updates rebuild the module automatically. To pick up changes to this
repository, run `makepkg -si` again in `packaging/arch`.

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
bash tests/test-build-plan.sh                                  # offline
./build.sh "$(uname -r)" "/usr/lib/modules/$(uname -r)/build"  # real build into src/, no install
```

## Upstream

Not submitted yet. Each patch carries its commit message for
`linux-input@vger.kernel.org`. It explains Solaar issue #2764, "MX Master 3S
Scroll Wheel Resolution inconsistent between Bluetooth and Bolt Dongle".

## License

GPL-2.0-only, the kernel's license.
