#!/usr/bin/env bash
#
# Replace vendor/vX.Y with the unmodified upstream driver source at <tag>, then
# check that patches/vX.Y-*.patch still applies to it.
#
#   tools/update-source.sh v7.3-rc3
#
# Run by hand, with network access, when a new kernel series arrives or the
# upstream driver changes. Commit the result and reinstall the package. DKMS
# itself never downloads anything.
set -euo pipefail

# series_patch: the same one-patch-per-series rule the DKMS build applies.
# shellcheck source=build.sh
source "$(dirname "${BASH_SOURCE[0]}")/../build.sh"

readonly KERNEL_GIT=https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
readonly SOURCES=(drivers/hid/hid-logitech-hidpp.c drivers/hid/hid-ids.h drivers/hid/usbhid/usbhid.h)

# Tag to series: v7.3-rc3 -> v7.3, v7.2.5 -> v7.2, v7.3 -> v7.3
tag_series() {
  if [[ ! $1 =~ ^v([0-9]+)\.([0-9]+)(\.[0-9]+|-rc[0-9]+)?$ ]]; then
    echo "update-source.sh: '$1' is not a kernel tag like v7.3, v7.3-rc3 or v7.2.5" >&2
    return 1
  fi
  echo "v${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
}

main() {
  if (( $# != 1 )); then
    echo "usage: tools/update-source.sh <tag>" >&2
    return 2
  fi
  local tag=$1 root series staging path
  root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
  series=$(tag_series "$tag")
  staging=$(mktemp -d)
  # shellcheck disable=SC2064 # expand now: $staging is local to main
  trap "rm -rf -- $(printf %q "$staging")" EXIT

  local args=()
  for path in "${SOURCES[@]}"; do
    mkdir -p "$staging/$(dirname "$path")"
    args+=(-o "$staging/$path" "$KERNEL_GIT/plain/$path?h=$tag")
  done
  # One transfer at a time over a reused connection: git.kernel.org answers
  # concurrent requests with 503, and sequential ones now and then, which
  # curl's backed-off retries ride out.
  curl --fail --silent --show-error --location --retry 6 "${args[@]}"
  printf '%s\n' "$tag" > "$staging/TAG"

  rm -rf "$root/vendor/$series"
  mkdir -p "$root/vendor/$series"
  cp -r "$staging/." "$root/vendor/$series/"
  echo "update-source.sh: vendor/$series now holds $tag"

  check_patch "$root" "$series"
}

# check_patch <root> <series>: the series' one patch applies to its vendored
# source with no fuzz, as build.sh will apply it.
check_patch() {
  local root=$1 series=$2 patch_file
  if ! patch_file=$(series_patch "$root" "$series"); then
    echo "update-source.sh: write patches/$series-*.patch against vendor/$series" >&2
    return 1
  fi
  patch -d "$root/vendor/$series" -p1 --fuzz=0 --dry-run < "$patch_file"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
