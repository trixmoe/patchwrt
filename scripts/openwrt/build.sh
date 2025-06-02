#!/bin/sh
# shellcheck source=./scripts/common.sh
BASE_SCRIPTS_DIR=$(dirname "$0")/..
. "$BASE_SCRIPTS_DIR/common.sh"

vps_root_dir=$(rootdir)

cd "$vps_root_dir/openwrt" || { errormsg "could not cd into openwrt directory"; exit; }

# Create .config from minimal diffconfig
make defconfig
# "good practice (...) to ensure quality builds" https://web.archive.org/web/20250602152152/https://openwrt.org/docs/guide-developer/toolchain/use-buildsystem#cleaning_up
make clean

ncpus=$(nproc)
make "-j$ncpus"