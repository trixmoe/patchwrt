#!/bin/sh
# shellcheck source=./scripts/common.sh
BASE_SCRIPTS_DIR=$(dirname "$0")/..
. "$BASE_SCRIPTS_DIR/common.sh"

openwrt_dir_fallback=$(rootdir >/dev/null && find . -maxdepth 1 -name "openwrt*" -exec basename {} \; | sort | head -n1)
_OPENWRT_DIR=${openwrt_dir:-$openwrt_dir_fallback}

if [ -z "$_OPENWRT_DIR" ]; then
    errormsg "No OpenWrt directory found.\n"
else
    infomsg "OpenWrt directory selected: $BOLD$UNDERLINE%s$RT\n" "$_OPENWRT_DIR"
fi
