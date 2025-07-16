#!/bin/sh
# shellcheck source=./scripts/common.sh
BASE_SCRIPTS_DIR=$(dirname "$0")/..
. "$BASE_SCRIPTS_DIR/common.sh"
set -eu

vps_root_dir=$(rootdir)

# Create 'qemu' directory
if [ ! -d "$vps_root_dir/qemu" ]; then
    mkdir -v "$vps_root_dir/qemu"
fi

cd "$vps_root_dir/qemu" || { errormsg "could not cd into openwrt directory"; exit 1; }

target_prefix="openwrt-armvirt-64-"
kernel="${target_prefix}Image"
rootfs="${target_prefix}rootfs-ext4.img"
rootfs_gzip="$rootfs.gz"
container_path="$container_name:$build_dir/openwrt/bin/targets/armvirt/64"
# Copy build files if missing
if [ ! -f "$kernel" ]; then
    docker container cp "$container_path/$kernel" "./"
    docker container cp "$container_path/$rootfs_gzip" "./"
fi


# Decompress rootfs is not yet decompressed
if [ -f "$rootfs_gzip" ]; then
    gzip -d $rootfs_gzip
fi

# Run qemu if binary exists
qemu_binary=qemu-system-aarch64
if hash $qemu_binary; then
    # Runs QEMU in the terminal w/o graphics (only serial)
    # Note: to quit, press CTRL+A, then, press X
    $qemu_binary \
        -M virt -accel hvf -cpu cortex-a57 \
        -nographic \
        -kernel $kernel \
        -drive file=$rootfs,format=raw,if=virtio -append "root=/dev/vda" \
        -device virtio-net,netdev=net1 -netdev user,id=net1,net=192.0.2.0/24
else
    errormsg "missing $qemu_binary. Install qemu (via brew)."
    exit 1
fi