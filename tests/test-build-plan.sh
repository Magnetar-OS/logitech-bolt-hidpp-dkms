#!/usr/bin/env bash
#
# Offline checks: which kernels are built for at all, kernel release and tag
# to series mapping, patch selection, and that every vendored series has a
# patch that applies to its source with no fuzz, as build.sh requires.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR/..

root=$(cd "$(dirname "$0")/.." && pwd)
# update-source.sh sources build.sh as well.
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

# Only v7.3-rc1 to v7.3-rc5 drive a Bolt receiver through hid-logitech-dj:
# 022eb347ff3a added that in v7.3-rc1 and 3fabd8ec206b reverted it in
# v7.3-rc6. build.sh refuses every other kernel, and DKMS skips it first,
# through BUILD_EXCLUSIVE_KERNEL — which it matches as a regular expression
# against the kernel release, exactly as below.
exclusive=$(sed -n 's/^BUILD_EXCLUSIVE_KERNEL="\(.*\)"$/\1/p' "$root/dkms.conf")
if [[ -n $exclusive && $exclusive == "$AFFECTED_KERNELS" ]]; then
  echo "ok    BUILD_EXCLUSIVE_KERNEL is build.sh's AFFECTED_KERNELS"
else
  echo "FAIL  BUILD_EXCLUSIVE_KERNEL '$exclusive' is not AFFECTED_KERNELS '${AFFECTED_KERNELS-}'"
  failed=1
fi
if grep -q '^BUILD_EXCLUSIVE_KERNEL_M' "$root/dkms.conf"; then
  echo "FAIL  dkms.conf bounds kernels with _MIN/_MAX, which order 7.3.0-1 before 7.3.0-rc5"
  failed=1
fi

# expect_kernel <built|skipped> <kernel release>
expect_kernel() {
  local want=$1 kernel=$2 by_build=skipped by_dkms=skipped
  affected_kernel "$kernel" 2>/dev/null && by_build=built
  [[ -n $exclusive && $kernel =~ $exclusive ]] && by_dkms=built
  if [[ $by_build == "$want" && $by_dkms == "$want" ]]; then
    echo "ok    $kernel is $want"
  else
    echo "FAIL  $kernel: expected $want, build.sh says $by_build, dkms.conf says $by_dkms"
    failed=1
  fi
}

for kernel in 7.3.0-rc1-1-cachyos-rc 7.3.0-rc4-1-cachyos-rc 7.3.0-rc5-2-mainline 7.3.0-rc5; do
  expect_kernel built "$kernel"
done
for kernel in 7.2.9-1-cachyos 7.3.0-rc6-1-cachyos-rc 7.3.0-rc7-1-mainline 7.3.0-rc10-1 \
              7.3.0-1-cachyos 7.3.0-arch1-1 7.3.1-arch1-1 7.4.0-rc1-1-cachyos-rc 17.3.0-rc2-1; do
  expect_kernel skipped "$kernel"
done

# A refused kernel is told why, and what to do about the package.
if message=$(affected_kernel 7.3.0-rc6-1-cachyos-rc 2>&1); then
  echo "FAIL  affected_kernel accepts 7.3.0-rc6-1-cachyos-rc"
  failed=1
elif [[ $message == *7.3.0-rc6-1-cachyos-rc* && $message == *v7.3-rc6* && $message == *README* ]]; then
  echo "ok    a kernel with the revert is told the package is no longer needed"
else
  echo "FAIL  affected_kernel 7.3.0-rc6-1-cachyos-rc says: $message"
  failed=1
fi

# What is vendored has to be source with the bug in it: a tag from the
# affected range, never the reverted driver.
for dir in "$root"/vendor/v*/; do
  tag=$(< "$dir/TAG")
  if [[ $tag =~ ^v([0-9]+)\.([0-9]+)(-rc[0-9]+)?$ ]] &&
     affected_kernel "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.0${BASH_REMATCH[3]}" 2>/dev/null; then
    echo "ok    vendored $tag is a tag with the bug"
  else
    echo "FAIL  vendored $tag is not a tag with the bug"
    failed=1
  fi
done

# update-source.sh checks a refreshed series with the same one-patch rule as
# build.sh: two patches for a series fail the check.
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/vendor/v7.3" "$fixture/patches"
cp -r "$root/vendor/v7.3/." "$fixture/vendor/v7.3/"
cp "$root/patches/v7.3-"*.patch "$fixture/patches/v7.3-a.patch"
cp "$root/patches/v7.3-"*.patch "$fixture/patches/v7.3-b.patch"
if check_patch "$fixture" v7.3 > /dev/null 2>&1; then
  echo "FAIL  check_patch accepts two patches for one series"
  failed=1
else
  echo "ok    check_patch rejects two patches for one series"
fi
if check_patch "$root" v7.3 > /dev/null 2>&1; then
  echo "ok    check_patch $root v7.3"
else
  echo "FAIL  check_patch $root v7.3"
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
