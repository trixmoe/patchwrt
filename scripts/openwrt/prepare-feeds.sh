#!/bin/sh
# shellcheck source=./scripts/common.sh
BASE_SCRIPTS_DIR=$(dirname "$0")/..
. "$BASE_SCRIPTS_DIR/common.sh"

vps_root_dir=$(rootdir)

cd "$vps_root_dir/openwrt" || { errormsg "could not cd into openwrt directory"; exit; }

# add RIPE Atlas feed to local files
./scripts/feeds update -a
./scripts/feeds install -a

# feeds commands overwrite the config
git restore .config