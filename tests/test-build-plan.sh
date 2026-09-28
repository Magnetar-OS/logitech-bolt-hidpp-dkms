#!/usr/bin/env bash
#
# Offline checks: kernel release and tag to series mapping, patch selection,
# and that every vendored series has a patch that applies to its source with
# no fuzz, as build.sh requires.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR/..

root=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=build.sh
source "$root/build.sh"
# shellcheck source=tools/update-source.sh
source "$root/tools/update-source.sh"

failed=0
expect() {
  local want=$1 got
  shift
  got=$("$@" 2>/dev/null) || got="<error>"
  if [[ $got == "$want" ]]; then
    echo "ok    $*"
  else
    echo "FAIL  $*: expected '$want', got '$got'"
    failed=1
  fi
}

expect v7.3  kernel_series 7.3.0-rc2-1-cachyos-rc
expect v7.2  kernel_series 7.2.5-1-cachyos
expect v7.10 kernel_series 7.10.1-arch1-1
expect "<error>" kernel_series not-a-kernel

expect v7.3  tag_series v7.3-rc3
expect v7.3  tag_series v7.3
expect v7.2  tag_series v7.2.5
expect "<error>" tag_series 7.2.5
expect "<error>" tag_series v7.3-rc3-dirty

expect "$root/patches/v7.3-mx-master4-bolt-divert.patch" series_patch "$root" v7.3
expect "<error>" series_patch "$root" v7.2
expect "<error>" series_patch "$root" v7.1

# Kernels before 7.3 have no Bolt support in hid-logitech-dj, so hidpp never
# drives a Bolt device there and there is nothing to fix. DKMS skips them via
# BUILD_EXCLUSIVE_KERNEL_MIN, which must name the oldest vendored series.
min=$(sed -n 's/^BUILD_EXCLUSIVE_KERNEL_MIN="\(.*\)"$/\1/p' "$root/dkms.conf")
oldest=$(for dir in "$root"/vendor/v*/; do basename "$dir"; done | sort -V | head -n 1)
if [[ -n $min && v$min == "$oldest" ]]; then
  echo "ok    BUILD_EXCLUSIVE_KERNEL_MIN $min is the oldest vendored series"
else
  echo "FAIL  BUILD_EXCLUSIVE_KERNEL_MIN '$min' is not the oldest vendored series $oldest"
  failed=1
fi

for dir in "$root"/vendor/v*/; do
  series=$(basename "$dir")
  if patch_file=$(series_patch "$root" "$series" 2>&1) &&
     patch -d "$dir" -p1 --fuzz=0 --dry-run --silent < "$patch_file" > /dev/null; then
    echo "ok    ${patch_file##*/} applies to vendor/$series ($(< "$dir/TAG"))"
  else
    echo "FAIL  vendor/$series: $patch_file"
    failed=1
  fi
done

exit "$failed"
