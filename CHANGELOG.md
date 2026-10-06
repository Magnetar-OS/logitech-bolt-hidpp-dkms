# Changelog

Notable changes, in the format of [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Deprecated

- **The package is not needed from kernel 7.3-rc6.** Upstream reverted Bolt
  receiver support in `hid-logitech-dj` (3fabd8ec206b, first in `v7.3-rc6`,
  2026-10-04), which removes the fifteen-lines-per-notch scroll at its
  source. 7.3-rc6, the 7.3 release and later kernels run their stock driver.
  Before booting one, turn off Solaar's Scroll Wheel Diversion and Scroll
  Wheel Resolution (README, "Remove"); remove the package once no 7.3-rc1 to
  7.3-rc5 kernel is installed.

### Changed

- The module is built only for 7.3-rc1 to 7.3-rc5 kernels
  (`BUILD_EXCLUSIVE_KERNEL` in `dkms.conf`). It was built for every 7.3 or
  later kernel, which would have replaced the stock driver on kernels with
  nothing to fix, and failed the DKMS build on 7.4. `build.sh` run by hand
  refuses any other kernel and says why.

### Fixed

- **Unloading the module no longer leaves the MX Master 4's wheel dead.**
  The wheel mode is state in the mouse, and the stock driver ignores the
  diverted HID++ wheel events. The module now puts the wheel back on native,
  low-resolution reporting when it is unloaded or unbound while the mouse is
  awake. README and the package's removal message give the Solaar settings
  to turn off before removing the package or booting a kernel without it,
  since a reboot does not unload the module and Solaar reapplies its saved
  settings.

### Added

- **One wheel notch scrolls one step on an MX Master 4 behind a Bolt
  receiver, on 7.3-rc1 to 7.3-rc5 kernels.** DKMS builds the patched
  `hid-logitech-hidpp` for each of those that is installed, so a kernel
  update among them no longer brings back fifteen lines per notch. Kernels
  before 7.3 never had the bug and keep their stock module.
- The build is offline, from vendored upstream source for kernel series 7.3
  (v7.3-rc5, the last tag with the bug), so it works inside pacman's
  network-less hooks.
- `tools/update-source.sh <tag>` vendors a new series or a newer upstream
  driver and checks the patch still applies.
- The module installs to `updates/dkms`. DKMS keeps the stock module file
  aside while it is installed and restores it on removal.
- Arch package `logitech-bolt-hidpp-dkms-git`.
