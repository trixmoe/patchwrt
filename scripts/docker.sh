#!/bin/sh
# shellcheck source=./scripts/common.sh
. "$(dirname "$0")/common.sh"

rootdir >/dev/null

build_dir="/vps/build"
cached_volume="vps-cache-$(id -un)"

print_help()
{
    printf "Usage: docker.sh COMMAND\n\n"
    printf "  run    Build and run a development container\n"
    printf "  rm     Kill and delete the existing container\n"
    printf "  clean  Delete openwrt cache volume\n"
}

run()
{
    # We assume macOS usage and M3 Pro machines - this can change over time and probably should be made more generic.
    colima status 2>/dev/null || colima start --cpu 12 --memory 24 --disk 150 --vm-type=vz --mount-type=virtiofs
    docker context use colima
    docker build -t vps:dev .

    if ! colima status 2>&1 | grep -q virtiofs; then
        warnmsg "Colima does not use virtiofs, this can cause permission issues.\n"
        warnindent "To fix this issue, you must delete the colima VM by running \'colima delete\' and re-run this command, note that IT WILL DELETE ALL DOCKER DATA.\n\n"
        warnmsg "As to avoid any potential issues, only the patches will be mounted, not the whole project directory\n."
        warnindent "As such, you cannot commit your patches from the container.\n"
        # (1) Mount ONLY YOUR PATCHES, while (2) keeping (the docker image's) openwrt in a volume
        bind_mount="type=bind,src=./patches,dst=${build_dir}/patches"
    else
        # (1) Mount your project directory at the root folder, while (2) keeping (the docker image's) openwrt in a volume
        bind_mount="type=bind,src=./,dst=${build_dir}"
    fi

    docker run -dt --name vps --mount $bind_mount --mount "type=volume,src=${cached_volume},dst=${build_dir}/openwrt" vps:dev bash
}

rm()
{
    docker kill vps
    docker container rm vps
}

clean_volume()
{
    docker volume rm "${cached_volume}"
}

case $1 in
    run)    run ;;
    rm)     rm ;;
    clean)  rm
            clean_volume ;;
    *)      print_help;;
esac