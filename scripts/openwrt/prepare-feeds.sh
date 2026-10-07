#!/bin/sh
# shellcheck source=./scripts/openwrt/common.sh
OPENWRT_SCRIPTS_DIR=$(dirname "$0")/
. "$OPENWRT_SCRIPTS_DIR/common.sh"

vps_root_dir=$(rootdir)

cd "$vps_root_dir/$_OPENWRT_DIR" || { errormsg "could not cd into openwrt directory"; exit 1; }

# add RIPE Atlas feed to local files
./scripts/feeds update -a
./scripts/feeds install -a

# feeds commands overwrite the config
git restore .config
