#!/bin/sh
# shellcheck source=./scripts/common.sh
BASE_SCRIPTS_DIR=$(dirname "$0")/..
. "$BASE_SCRIPTS_DIR/common.sh"

if [ -n "$OPENWRT_MODULE" ]; then
    openwrt_dir=$(print_module_dir "$OPENWRT_MODULE")
fi

openwrt_dir_fallback=$(rootdir >/dev/null && find . -maxdepth 1 -name "openwrt*" -exec basename {} \; | sort | head -n1)
_OPENWRT_DIR=${openwrt_dir:-$openwrt_dir_fallback}

if [ -z "$_OPENWRT_DIR" ]; then
    errormsg "No OpenWrt module directory found.\n"
    exit 1
elif [ -n "$OPENWRT_MODULE" ] && [ -z "$openwrt_dir" ]; then
    errormsg "No OpenWrt module directory found for OpenWrt module \"%s\".\n" "$OPENWRT_MODULE"
    exit 1
elif [ -z "$openwrt_dir" ]; then
    warnmsg "No OpenWrt module directory manually selected. Automatic selection: $BOLD$UNDERLINE%s$RT\n" "$_OPENWRT_DIR"
else
    infomsg "OpenWrt module directory selected: $BOLD$UNDERLINE%s$RT\n" "$_OPENWRT_DIR"
fi
