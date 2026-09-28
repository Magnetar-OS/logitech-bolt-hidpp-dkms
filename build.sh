#!/usr/bin/env bash
#
# DKMS build step for hid-logitech-hidpp with the Bolt wheel-diversion patch.
#
# vendor/vX.Y holds the unmodified upstream driver source for kernel series
# X.Y (tools/update-source.sh fetches it), and patches/vX.Y-*.patch is the
# patch for that series. This copies the source for the kernel being built,
# applies the patch and builds the module out of tree against the kernel's
# headers. It never touches the network: pacman runs hooks, and so DKMS, in
# a network namespace with only loopback.
#
# DKMS runs it as MAKE[0] with the kernel release and headers directory, and
# appends its own make arguments (LLVM=1 on a clang-built kernel):
#
#   build.sh <kernelver> <kernel_source_dir> [make args...]
#
# A kernel from a series with no vendored source fails its build, and keeps its
# stock driver, rather than getting another series' driver.
set -euo pipefail

readonly MODULE=hid-logitech-hidpp
readonly MODULE_DIR=drivers/hid

# Kernel release to series: 7.3.0-rc2-1-cachyos-rc -> v7.3
kernel_series() {
  if [[ ! $1 =~ ^([0-9]+)\.([0-9]+)\. ]]; then
    echo "build.sh: unrecognised kernel release '$1'" >&2
    return 1
  fi
  echo "v${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
}

# series_patch <root> <series>: the one patch for a vendored series.
series_patch() {
  local root=$1 series=$2
  if [[ ! -f $root/vendor/$series/TAG ]]; then
    echo "build.sh: no vendored source for kernel series $series; run tools/update-source.sh" >&2
    return 1
  fi
  local patches=("$root/patches/$series"-*.patch)
  if (( ${#patches[@]} != 1 )) || [[ ! -f ${patches[0]} ]]; then
    echo "build.sh: expected exactly one patches/$series-*.patch" >&2
    return 1
  fi
  printf '%s\n' "${patches[0]}"
}

main() {
  if (( $# < 2 )); then
    echo "usage: build.sh <kernelver> <kernel_source_dir> [make args...]" >&2
    return 2
  fi
  local kernelver=$1 ksrc=$2
  shift 2
  local root series patch_file
  root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  series=$(kernel_series "$kernelver")
  patch_file=$(series_patch "$root" "$series")

  rm -rf "$root/src"
  mkdir -p "$root/src"
  cp -r "$root/vendor/$series/." "$root/src/"
  rm "$root/src/TAG"
  echo "build.sh: $MODULE from $(< "$root/vendor/$series/TAG"), applying ${patch_file##*/}"
  # --fuzz=0: a hunk whose context has drifted fails the build instead of
  # landing wherever two lines of context still match.
  patch -d "$root/src" -p1 --forward --fuzz=0 --no-backup-if-mismatch < "$patch_file"

  printf 'obj-m := %s.o\n' "$MODULE" > "$root/src/$MODULE_DIR/Makefile"
  make -j"$(nproc)" -C "$ksrc" M="$root/src/$MODULE_DIR" "$@" modules
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
