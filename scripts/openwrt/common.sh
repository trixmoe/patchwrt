#!/bin/sh
# shellcheck source=./scripts/common.sh
BASE_SCRIPTS_DIR=$(dirname "$0")/..
. "$BASE_SCRIPTS_DIR/common.sh"

openwrt_dir_fallback=$(find . -name "openwrt*" -depth 1 -exec basename {} \; | sort | head -n1)
_OPENWRT_DIR=${openwrt_dir:-$openwrt_dir_fallback}

if [ -z "$_OPENWRT_DIR" ]; then
    errormsg "No OpenWrt directory found."
else
    infomsg "OpenWrt directory selected: %s" "$_OPENWRT_DIR"
fi
