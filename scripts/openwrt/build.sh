#!/bin/sh
# shellcheck source=./scripts/common.sh
BASE_SCRIPTS_DIR=$(dirname "$0")/..
. "$BASE_SCRIPTS_DIR/common.sh"

print_help()
{
    printf "Usage: build.sh\n"
    printf "This script builds OpenWrt incl. pre-required commands\n\n"

    printf "  --rebuild    Dirty but quicker build\n"
    printf "  --help       Show this help menu\n"
}

unset rebuild
while :; do
    case $1 in
        -\?|-help|--help)
            print_help
            exit 0
            ;;
        --rebuild)
            rebuild=1
            ;;
        --)
            shift
            break
            ;;
        -?*)
            warnmsg 'Ignored unknown parameter: %s\n' "$1"
            ;;
        *)
            break
    esac
    shift
done

vps_root_dir=$(rootdir)

cd "$vps_root_dir/openwrt" || { errormsg "could not cd into openwrt directory"; exit 1; }

if [ -n "$rebuild" ]; then
    board=$(sed -n 's/^CONFIG_TARGET_BOARD="\(.*\)"/\1/p' .config)
    target=$(sed -n 's/^CONFIG_TARGET_SUBTARGET="\(.*\)"/\1/p' .config)
    rm "bin/targets/$board/$target"/openwrt-*
else
    # Create .config from minimal diffconfig
    make defconfig
    # "good practice (...) to ensure quality builds" https://web.archive.org/web/20250602152152/https://openwrt.org/docs/guide-developer/toolchain/use-buildsystem#cleaning_up
    make clean
fi

ncpus=$(nproc)
make "-j$ncpus"