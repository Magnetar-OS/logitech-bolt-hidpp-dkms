# Changelog

Notable changes, in the format of [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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
