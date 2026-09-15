#!/usr/bin/env bash
#
# DKMS build step for hid-logitech-hidpp with the Bolt wheel-diversion patch.
#
# Kernel headers ship no driver sources, so this downloads the stock driver for
# the exact kernel being built from git.kernel.org, applies the patch written
# for that kernel series, and builds the module out of tree. Every kernel gets
# its own driver plus this patch and nothing else.
#
# DKMS runs it as MAKE[0] with the kernel release and headers directory, and
# appends its own make arguments (LLVM=1 on a clang-built kernel):
#
#   build.sh <kernelver> <kernel_source_dir> [make args...]
#
# Needs network access. Fails, leaving the kernel on its stock driver, when the
# download fails or no patch applies.
set -euo pipefail

readonly KERNEL_GIT=https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
readonly MODULE=hid-logitech-hidpp
readonly MODULE_DIR=drivers/hid
readonly SOURCES=(drivers/hid/hid-logitech-hidpp.c drivers/hid/hid-ids.h drivers/hid/usbhid/usbhid.h)

# Kernel release to upstream tag. The stable tree carries mainline tags too.
#   7.3.0-rc2-1-cachyos-rc -> v7.3-rc2
#   7.3.0-1-cachyos        -> v7.3
#   7.2.5-1-cachyos        -> v7.2.5
kernel_tag() {
  if [[ ! $1 =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(-rc[0-9]+)? ]]; then
    echo "build.sh: unrecognised kernel release '$1'" >&2
    return 1
  fi
  local series="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
  if [[ -n ${BASH_REMATCH[4]} ]]; then
    echo "v$series${BASH_REMATCH[4]}"
  elif [[ ${BASH_REMATCH[3]} == 0 ]]; then
    echo "v$series"
  else
    echo "v$series.${BASH_REMATCH[3]}"
  fi
}

# patches/vX.Y-*.patch applies from kernel series X.Y on. Pick the newest one
# that is not newer than the kernel.
select_patch() {
  local kernelver=$1 dir=$2 series p v best=""
  if [[ ! $kernelver =~ ^([0-9]+\.[0-9]+)\. ]]; then
    echo "build.sh: unrecognised kernel release '$kernelver'" >&2
    return 1
  fi
  series=${BASH_REMATCH[1]}
  while IFS= read -r p; do
    v=${p##*/v}
    v=${v%%-*}
    if [[ $(printf '%s\n' "$v" "$series" | sort -V | head -n1) == "$v" ]]; then
      best=$p
    fi
  done < <(printf '%s\n' "$dir"/v*.patch | sort -V)
  if [[ -z $best || ! -e $best ]]; then
    echo "build.sh: no patch in $dir applies to kernel series $series" >&2
    return 1
  fi
  printf '%s\n' "$best"
}

# fetch <tag> <dest> <path>...
# One transfer at a time over a reused connection: git.kernel.org answers
# concurrent requests with 503, and even sequential ones now and then, which
# curl's backed-off retries ride out.
fetch() {
  local tag=$1 dest=$2 path
  shift 2
  local args=()
  for path in "$@"; do
    mkdir -p "$dest/$(dirname "$path")"
    args+=(-o "$dest/$path" "$KERNEL_GIT/plain/$path?h=$tag")
  done
  curl --fail --silent --show-error --location --retry 6 "${args[@]}"
}

main() {
  if (( $# < 2 )); then
    echo "usage: build.sh <kernelver> <kernel_source_dir> [make args...]" >&2
    return 2
  fi
  local kernelver=$1 ksrc=$2
  shift 2
  local here tag patch_file
  here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  tag=$(kernel_tag "$kernelver")
  patch_file=$(select_patch "$kernelver" "$here/patches")

  rm -rf "$here/src"
  echo "build.sh: fetching $MODULE sources at $tag"
  fetch "$tag" "$here/src" "${SOURCES[@]}"
  echo "build.sh: applying ${patch_file##*/}"
  patch -d "$here/src" -p1 --forward --no-backup-if-mismatch < "$patch_file"

  printf 'obj-m := %s.o\n' "$MODULE" > "$here/src/$MODULE_DIR/Makefile"
  make -j"$(nproc)" -C "$ksrc" M="$here/src/$MODULE_DIR" "$@" modules
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
