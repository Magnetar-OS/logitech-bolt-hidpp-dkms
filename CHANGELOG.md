# Changelog

Notable changes, in the format of [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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
  receiver, on 7.3 kernels.** DKMS builds the patched `hid-logitech-hidpp`
  for each installed 7.3 or later kernel, so a kernel update no longer brings
  back fifteen lines per notch. Kernels before 7.3 never had the bug and keep
  their stock module.
- The build is offline, from vendored upstream source for kernel series 7.3
  (v7.3-rc5), so it works inside pacman's network-less hooks. A kernel from a
  series with no vendored source fails loudly and keeps its stock driver.
- `tools/update-source.sh <tag>` vendors a new series or a newer upstream
  driver and checks the patch still applies.
- The module installs to `updates/dkms`. DKMS keeps the stock module file
  aside while it is installed and restores it on removal.
- Arch package `logitech-bolt-hidpp-dkms-git`.
