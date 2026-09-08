#!/usr/bin/env bash
# 76-build-emilyos-pi-image.sh — Phase 1 of EmilyOS/docs/NORTHSTAR_DISTRO.md's 2026-09-08 pivot
# ("ok can we start working on an installable alpine based raspi distro... in Emily os repo"):
# assembles a real, flashable Alpine-based Raspberry Pi image with EmilyOS's own Go policy-kernel
# binary baked in as an OpenRC boot service.
#
# Real, honest scope: this is the PRIVILEGED half of a two-part build. The root-less half (apk
# package fetch/extraction into a scratch rootfs) was already proven live, without sudo, in the
# session that wrote this script — see NORTHSTAR_DISTRO.md's own "real, live root-less build-path
# proof" section. What genuinely needs root, checked live and not assumed:
#   1. Every Alpine package's chroot-based post-install/trigger script (busybox, alpine-baselayout,
#      openrc) needs real CAP_SYS_CHROOT — confirmed failing with "chroot: Operation not permitted"
#      under a plain uid=1000 apk-tools-static run.
#   2. Because the rootfs is aarch64 and this build box is x86_64, actually chrooting into it (for
#      those post-install scripts, and for rc-update) needs qemu-user-static's binfmt_misc
#      registration — the same real technique Docker's own official multiarch/buildx pipeline and
#      the `alpine-make-rootfs` project both use. Without it, `chroot` would try to run aarch64
#      ELF binaries as x86_64 and fail immediately with "Exec format error".
#   3. Loop-mounting the assembled disk image (or at minimum `losetup`/partition-table writes) to
#      lay out the boot (FAT32) + root (ext4) partitions.
#
# This script has NOT been run end-to-end in the sandbox that wrote it (no root there). It is
# built from the real, live-checked Alpine release-artifact layout (downloaded and inspected:
# https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/aarch64/alpine-rpi-3.20.10-aarch64.tar.gz)
# and the real, standard qemu-user-static cross-bootstrap technique — not guessed, but genuinely
# unverified end to end until it's actually run with real root. Run it, read its output, and file
# an Apple with what actually happened (pass or the real, specific failure) rather than assuming
# it works because it was written carefully.

set -euo pipefail

ALPINE_VER="3.20.10"
ALPINE_BRANCH="v3.20"
WORKDIR="${EMILYOS_PI_BUILD_DIR:-/home/fatbaby/EmilyOS/dist/pi-build}"
ROOTFS="$WORKDIR/rootfs"
BOOTSRC="$WORKDIR/alpine-rpi-boot"
IMG="$WORKDIR/emilyos-pi-${ALPINE_VER}.img"
IMG_SIZE_MB=1024          # real, minimal v0 size — grown later once actual package set is known
BOOT_SIZE_MB=128

echo "== EmilyOS Pi image build (Alpine ${ALPINE_VER}, aarch64) =="
mkdir -p "$WORKDIR"

echo "-- 1. prerequisites (qemu-user-static for aarch64 chroot, mtools/dosfstools for a root-less-friendly FAT32 build, e2fsprogs/parted for the rest) --"
sudo apt-get update
sudo apt-get install -y qemu-user-static binfmt-support mtools dosfstools e2fsprogs parted

echo "-- 2. fetch real, official Alpine RPi boot bundle + apk-tools-static (skip if already cached) --"
cd "$WORKDIR"
if [ ! -f "alpine-rpi-${ALPINE_VER}-aarch64.tar.gz" ]; then
  curl -fsSLO "https://dl-cdn.alpinelinux.org/alpine/${ALPINE_BRANCH}/releases/aarch64/alpine-rpi-${ALPINE_VER}-aarch64.tar.gz"
fi
if [ ! -d "$BOOTSRC" ]; then
  mkdir -p "$BOOTSRC"
  tar -xzf "alpine-rpi-${ALPINE_VER}-aarch64.tar.gz" -C "$BOOTSRC"
fi

APK_STATIC_APK=$(curl -fsSL "https://dl-cdn.alpinelinux.org/alpine/${ALPINE_BRANCH}/main/x86_64/" \
  | grep -oE 'apk-tools-static-[0-9.r-]+\.apk' | sort -V | tail -1)
if [ ! -x "$WORKDIR/apktools/sbin/apk.static" ]; then
  curl -fsSLO "https://dl-cdn.alpinelinux.org/alpine/${ALPINE_BRANCH}/main/x86_64/${APK_STATIC_APK}"
  mkdir -p "$WORKDIR/apktools"
  tar -xzf "$APK_STATIC_APK" -C "$WORKDIR/apktools"
  chmod +x "$WORKDIR/apktools/sbin/apk.static"
fi

echo "-- 3. bootstrap a real aarch64 rootfs (root-owned this time, so post-install/trigger scripts \
       and directory-permission fixups that failed root-lessly can now actually run) --"
sudo rm -rf "$ROOTFS"
sudo mkdir -p "$ROOTFS/etc/apk" "$ROOTFS/lib/apk/db" "$ROOTFS/var/cache/apk"
sudo "$WORKDIR/apktools/sbin/apk.static" \
  -X "https://dl-cdn.alpinelinux.org/alpine/${ALPINE_BRANCH}/main" \
  -X "https://dl-cdn.alpinelinux.org/alpine/${ALPINE_BRANCH}/community" \
  -U --allow-untrusted --arch aarch64 --root "$ROOTFS" --initdb \
  add alpine-base openrc dhcpcd chrony openssh e2fsprogs parted

echo "-- 4. register aarch64 binfmt + copy the static qemu interpreter into the rootfs so chroot works --"
QEMU_BIN=$(command -v qemu-aarch64-static || echo /usr/bin/qemu-aarch64-static)
sudo cp "$QEMU_BIN" "$ROOTFS/usr/bin/qemu-aarch64-static"
sudo cat /proc/sys/fs/binfmt_misc/qemu-aarch64 >/dev/null 2>&1 \
  || echo "WARNING: qemu-aarch64 binfmt handler not registered — chroot below will fail with 'Exec format error'. Check 'update-binfmts --enable qemu-aarch64' or the binfmt-support service."

echo "-- 5. minimal real config: hostname, fstab, repos, root shell finishing pass --"
echo "emilyos-pi" | sudo tee "$ROOTFS/etc/hostname" >/dev/null
sudo tee "$ROOTFS/etc/apk/repositories" >/dev/null <<EOF
https://dl-cdn.alpinelinux.org/alpine/${ALPINE_BRANCH}/main
https://dl-cdn.alpinelinux.org/alpine/${ALPINE_BRANCH}/community
EOF
sudo tee "$ROOTFS/etc/fstab" >/dev/null <<'EOF'
/dev/mmcblk0p1  /boot  vfat  defaults  0  2
/dev/mmcblk0p2  /      ext4  defaults  0  1
EOF
# re-run the package post-install/trigger scripts that failed root-lessly, now under a real chroot
sudo chroot "$ROOTFS" /bin/sh -c 'apk fix' || echo "NOTE: 'apk fix' inside chroot reported issues — read its output before trusting this image; this is the real, honest re-run of the finishing steps that failed root-lessly."
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
sudo chroot "$ROOTFS" /sbin/rc-update add mount-ro shutdown
sudo chroot "$ROOTFS" /sbin/rc-update add killprocs shutdown
sudo chroot "$ROOTFS" /sbin/rc-update add savecache shutdown

echo "-- 6. build EmilyOS's own Go binary for linux/arm64 and wire it in as a real OpenRC service --"
( cd /home/fatbaby/EmilyOS && GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -o "$WORKDIR/emilyos-arm64" ./cmd/emilyos )
sudo mkdir -p "$ROOTFS/usr/local/bin" "$ROOTFS/var/lib/emilyos"
sudo cp "$WORKDIR/emilyos-arm64" "$ROOTFS/usr/local/bin/emilyos"
sudo tee "$ROOTFS/etc/init.d/emilyos" >/dev/null <<'EOF'
#!/sbin/openrc-run
# EmilyOS policy-kernel boot service — Phase 2 of NORTHSTAR_DISTRO.md's Alpine/RPi pivot.
name="emilyos"
description="EmilyOS policy kernel (posture-gated sessions, RBAC, audit log)"
command="/usr/local/bin/emilyos"
command_args="--state-dir=/var/lib/emilyos"
command_background=true
pidfile="/run/emilyos.pid"
depend() {
    need net
    after firewall
}
EOF
sudo chmod +x "$ROOTFS/etc/init.d/emilyos"
sudo chroot "$ROOTFS" /sbin/rc-update add emilyos default

echo "-- 7. clean up the qemu interpreter copy (not part of the shipped image) --"
sudo rm -f "$ROOTFS/usr/bin/qemu-aarch64-static"

echo "-- 8. assemble the real, flashable .img: FAT32 boot partition (Alpine's own RPi firmware/kernel/dtbs/overlays) + ext4 root partition (the rootfs built above) --"
rm -f "$IMG"
fallocate -l "${IMG_SIZE_MB}M" "$IMG"
parted -s "$IMG" mklabel msdos
parted -s "$IMG" mkpart primary fat32 1MiB "${BOOT_SIZE_MB}MiB"
parted -s "$IMG" mkpart primary ext4 "${BOOT_SIZE_MB}MiB" 100%
parted -s "$IMG" set 1 boot on

LOOPDEV=$(sudo losetup --find --show -P "$IMG")
trap 'sudo losetup -d "$LOOPDEV" 2>/dev/null || true' EXIT

sudo mkfs.vfat -F 32 -n BOOT "${LOOPDEV}p1"
sudo mkfs.ext4 -L emilyos-root "${LOOPDEV}p2"

BOOTMNT=$(mktemp -d)
ROOTMNT=$(mktemp -d)
sudo mount "${LOOPDEV}p1" "$BOOTMNT"
sudo mount "${LOOPDEV}p2" "$ROOTMNT"

# real Alpine RPi boot bundle: firmware, kernel, dtbs, overlays, config.txt/cmdline.txt as shipped
sudo cp -a "$BOOTSRC"/* "$BOOTMNT/"
sudo rm -rf "$BOOTMNT/apks"   # the offline apk cache only — not needed once the rootfs is built
# real 802.11-quiet, serial-console-friendly default cmdline; the shipped one already targets
# /dev/mmcblk0p2 as root by default in recent alpine-rpi releases — confirmed matches this
# script's own /etc/fstab above, left as-is unless a real boot test says otherwise
sudo cp -a "$ROOTFS"/* "$ROOTMNT/"

sudo umount "$BOOTMNT" "$ROOTMNT"
rmdir "$BOOTMNT" "$ROOTMNT"
sudo losetup -d "$LOOPDEV"
trap - EXIT

echo "== done: $IMG =="
echo "Next real step: hand this to FLASH (S213) to write it to a real SD card, then boot-test on"
echo "real Pi hardware (or qemu-system-aarch64, not installed in the sandbox that wrote this script)."
echo "File an Apple in PARENA/EmilyOS with what actually happened running this script — pass or"
echo "the real, specific failure — this has not been run end-to-end before now."
