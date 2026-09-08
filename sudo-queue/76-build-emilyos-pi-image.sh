#!/usr/bin/env bash
# 76-build-emilyos-pi-image.sh — the PRIVILEGED half of EmilyOS/docs/NORTHSTAR_DISTRO.md's Alpine/
# Raspberry Pi image build (2026-09-08 pivot + two same-day refinements). Run
# `EmilyOS/packaging/scripts/build-pi-image-rootless.sh` FIRST (no root needed) — it fetches
# Alpine's own official RPi boot bundle, bootstraps an aarch64 rootfs via apk-tools-static, builds
# the real FAT32 boot image via mtools, AND (as of the second refinement) root-lessly bootstraps
# an aarch64 cross-toolchain and successfully cross-compiles EmilyOS's own Go binary into that
# rootfs — the cgo cross-compilation gap this script used to have to retry with a freshly
# apt-installed toolchain is closed root-lessly now, so that step is gone from here entirely.
#
# This script does only the parts that genuinely need root, each checked live in the session that
# wrote this rather than assumed:
#   1. Alpine's package post-install/trigger scripts (busybox, alpine-baselayout, openrc) run via
#      a real `chroot`, needing CAP_SYS_CHROOT — confirmed failing with "chroot: Operation not
#      permitted" under a plain uid=1000 apk-tools-static run.
#   2. The rootfs is aarch64, this build box is x86_64 — chrooting into it needs
#      qemu-user-static's binfmt_misc registration (the same real technique Docker's own official
#      multiarch/buildx pipeline and the `alpine-make-rootfs` project both use).
#   3. `mke2fs -d <rootfs>` (populating an ext4 image straight from a directory tree, no mount
#      needed) ALSO needs root, not just the chroot step — found live: Alpine's own busybox-suid
#      package ships `/bin/bbsuid` as mode `---x--x--x` (execute-only, unreadable even by its own
#      owning user), which a non-root reader genuinely cannot copy. Root bypasses DAC checks
#      entirely, so this is a non-issue here.
#
# What this script deliberately does NOT do, because the root-less half already proved it doesn't
# need root: cross-compile EmilyOS's own Go binary (done root-lessly now, see above), build the
# FAT32 boot image (mtools operates on a plain file, no mount), partition the final combined .img
# (parted operates on a plain file directly), or loop-mount/`losetup` anything at all — the whole
# assembly is done via `dd` at exact byte offsets into a plain file, verified byte-identical
# against the source sub-images in the same session that wrote this script.
#
# This script has NOT been run end-to-end (no root in the sandbox that wrote it, past this exact
# point). Run it, read its output, and file an Apple with what actually happened — pass or the
# real, specific failure — rather than assuming success because it was written carefully.

set -euo pipefail

ALPINE_VER="3.20.10"
WORKDIR="${EMILYOS_PI_BUILD_DIR:-/home/fatbaby/EmilyOS/dist/pi-build}"
ROOTFS="$WORKDIR/rootfs"
BOOT_IMG="$WORKDIR/boot.img"
ROOT_IMG="$WORKDIR/root.img"
IMG="$WORKDIR/emilyos-pi-${ALPINE_VER}.img"
BOOT_SIZE_MB=200
ROOT_SIZE_MB=768   # real, minimal v0 size — grow once the actual finished package set is known

if [ ! -d "$ROOTFS" ] || [ ! -f "$BOOT_IMG" ]; then
  echo "ERROR: $ROOTFS and/or $BOOT_IMG not found. Run"
  echo "  EmilyOS/packaging/scripts/build-pi-image-rootless.sh"
  echo "first (no root needed) — this script builds on top of its output, it doesn't redo it."
  exit 1
fi

echo "== 1. prerequisites: qemu-user-static (aarch64-on-x86_64 chroot) =="
sudo apt-get update
sudo apt-get install -y qemu-user-static binfmt-support

echo "== 2. register aarch64 binfmt + copy the static qemu interpreter into the rootfs so chroot works =="
QEMU_BIN=$(command -v qemu-aarch64-static || echo /usr/bin/qemu-aarch64-static)
sudo cp "$QEMU_BIN" "$ROOTFS/usr/bin/qemu-aarch64-static"
sudo cat /proc/sys/fs/binfmt_misc/qemu-aarch64 >/dev/null 2>&1 \
  || echo "WARNING: qemu-aarch64 binfmt handler not registered — chroot below will fail with 'Exec format error'. Check 'update-binfmts --enable qemu-aarch64' or the binfmt-support service."

echo "== 3. re-run the package post-install/trigger scripts + service registration that failed
       root-lessly, now under a real chroot =="
sudo chroot "$ROOTFS" /bin/sh -c 'apk fix' \
  || echo "NOTE: 'apk fix' inside chroot reported issues — read its output before trusting this image."
sudo chroot "$ROOTFS" /sbin/rc-update add devfs sysinit
sudo chroot "$ROOTFS" /sbin/rc-update add dmesg sysinit
sudo chroot "$ROOTFS" /sbin/rc-update add mdev sysinit
sudo chroot "$ROOTFS" /sbin/rc-update add hwclock boot
sudo chroot "$ROOTFS" /sbin/rc-update add modules boot
sudo chroot "$ROOTFS" /sbin/rc-update add sysctl boot
sudo chroot "$ROOTFS" /sbin/rc-update add hostname boot
sudo chroot "$ROOTFS" /sbin/rc-update add bootmisc boot
sudo chroot "$ROOTFS" /sbin/rc-update add syslog boot
sudo chroot "$ROOTFS" /sbin/rc-update add dhcpcd default
sudo chroot "$ROOTFS" /sbin/rc-update add sshd default
sudo chroot "$ROOTFS" /sbin/rc-update add chronyd default
sudo chroot "$ROOTFS" /sbin/rc-update add emilyos default
sudo chroot "$ROOTFS" /sbin/rc-update add mount-ro shutdown
sudo chroot "$ROOTFS" /sbin/rc-update add killprocs shutdown
sudo chroot "$ROOTFS" /sbin/rc-update add savecache shutdown
sudo rm -f "$ROOTFS/var/lib/emilyos/PENDING_RC_UPDATE"

echo "== 4. clean up the qemu interpreter copy (not part of the shipped image) =="
sudo rm -f "$ROOTFS/usr/bin/qemu-aarch64-static"

echo "== 5. build the ext4 root image straight from the finished rootfs/ tree (mke2fs -d, root
       needed only because it must read Alpine's own execute-only bbsuid helper — see this
       script's own header comment) — no mount, no loop device =="
sudo rm -f "$ROOT_IMG"
fallocate -l "${ROOT_SIZE_MB}M" "$ROOT_IMG"
sudo mke2fs -q -F -L emilyos-root -d "$ROOTFS" "$ROOT_IMG"
sudo chown "$(id -u):$(id -g)" "$ROOT_IMG"

echo "== 6. partition a plain file (parted operates on regular files directly, no loop device) +
       dd-assemble the boot.img (already built root-lessly) and this root.img at their exact byte
       offsets =="
rm -f "$IMG"
IMG_SIZE_MB=$(( BOOT_SIZE_MB + ROOT_SIZE_MB + 4 ))
fallocate -l "${IMG_SIZE_MB}M" "$IMG"
parted -s "$IMG" mklabel msdos
parted -s "$IMG" mkpart primary fat32 1MiB "$(( 1 + BOOT_SIZE_MB ))MiB"
parted -s "$IMG" mkpart primary ext4 "$(( 1 + BOOT_SIZE_MB ))MiB" 100%
parted -s "$IMG" set 1 boot on

dd if="$BOOT_IMG" of="$IMG" bs=1M seek=1 conv=notrunc status=none
dd if="$ROOT_IMG" of="$IMG" bs=1M seek="$(( 1 + BOOT_SIZE_MB ))" conv=notrunc status=none

echo "== done: $IMG =="
echo "Next real step: hand this to FLASH (S213) to write it to a real SD card, then boot-test on"
echo "real Pi hardware (or qemu-system-aarch64, not installed in the sandbox that wrote this script)."
echo "File an Apple in EmilyOS with what actually happened running this script — pass or the real,"
echo "specific failure — this has not been run end-to-end before now."
