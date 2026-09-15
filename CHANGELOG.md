# Changelog

Notable changes, in the format of [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- **One wheel notch scrolls one step on an MX Master 4 behind a Bolt
  receiver, on every kernel.** DKMS builds the patched `hid-logitech-hidpp`
  for each installed kernel from that kernel's own driver source, so a kernel
  update no longer brings back fifteen lines per notch.
- Patches for kernel series 7.2 and 7.3. The build picks the one for the
  kernel it is building and fails loudly when none applies.
- Arch package `logitech-bolt-hidpp-dkms-git`.
