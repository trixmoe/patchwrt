#!/bin/sh
# shellcheck source=./scripts/common.sh

OPENWRT_SCRIPTS_DIR=${OPENWRT_SCRIPTS_DIR:-$(dirname "$0")}
BASE_SCRIPTS_DIR=${BASE_SCRIPTS_DIR:-$OPENWRT_SCRIPTS_DIR/..}
. "$BASE_SCRIPTS_DIR/common.sh"

if [ -n "$OPENWRT_MODULE" ]; then
    openwrt_dir=$(print_module_dir "$OPENWRT_MODULE")
fi

openwrt_dir_fallback=$(rootdir >/dev/null && find . -maxdepth 1 -name "openwrt*" -exec basename {} \; | sort | head -n1)
_OPENWRT_DIR=${openwrt_dir:-$openwrt_dir_fallback}

OPENWRT_MODULE_LOWERCASE="$(printf '%s' "$OPENWRT_MODULE" | tr '[:upper:]' '[:lower:]')"

verify_openwrt_module() {
    if [ -z "$_OPENWRT_DIR" ]; then
        errormsg "No OpenWrt module directory found.\n"
        return 1
    elif [ -n "$OPENWRT_MODULE" ] && [ -z "$openwrt_dir" ]; then
        errormsg "No OpenWrt module directory found for OpenWrt module \"%s\".\n" "$OPENWRT_MODULE"
        exit 1
    elif [ -z "$openwrt_dir" ]; then
        warnmsg "No OpenWrt module directory manually selected. Automatic selection: $BOLD$UNDERLINE%s$RT\n" "$_OPENWRT_DIR"
    else
        infomsg "OpenWrt module directory selected: $BOLD$UNDERLINE%s$RT\n" "$_OPENWRT_DIR"
    fi
}

print_toolchain_image_name() {
    patchset=$1
    if [ -z "$patchset" ]; then
        errormsg "Patchset has to be specified for toolchain image."
        return 1
    fi
    toolchain_image_name="$image_name-toolchain-$(printf '%s' "$patchset" | tr '[:upper:]' '[:lower:]')"
    if [ -n "$OPENWRT_MODULE" ]; then
        toolchain_image_name="$toolchain_image_name-$OPENWRT_MODULE_LOWERCASE"
    fi
    printf "%s" "$toolchain_image_name"
}

# Given that conatiner registries are per-project, the "$image_name" adds unnecessary length.
# As such, we shorten it.
print_remote_toolchain_image_name() {
    patchset=$1
    if [ -z "$patchset" ]; then
        errormsg "Patchset has to be specified for toolchain image."
        return 1
    fi
    if [ -z "$OPENWRT_MODULE" ]; then
        errormsg "OpenWrt module has to be specificed for remote toolchain image."
        return 1
    fi

    remote_image_name="toolchain-$(printf '%s' "$patchset" | tr '[:upper:]' '[:lower:]')-${OPENWRT_MODULE_LOWERCASE}"
    printf "%s" "$remote_image_name"
}
