#!/bin/sh
# shellcheck source=./scripts/common.sh
. "$(dirname "$0")/common.sh"
set -e

rootdir >/dev/null

print_help()
{
    printf "Usage: docker.sh COMMAND\n\n"
    printf "  start  Start colima\n"
    printf "  run    Build and run a development container\n"
    printf "  rm     Kill and delete the existing container\n"
    printf "  clean  Delete openwrt cache volume\n"
}

start_docker()
{
    if ! docker ps >/dev/null; then
        if colima >/dev/null; then
            nproc=$(getconf _NPROCESSORS_ONLN)
            case "$(uname -s)" in
                Linux*)     mem=$(awk '/MemTotal/ {print int($2/(1024^2))}' /proc/meminfo);;
                Darwin*)    mem=$(awk "BEGIN {print int($(sysctl -n hw.memsize)/(1024)^3)}");;
                *)          { errormsg "could not detect platform to start colima\n"; exit 1; }
            esac

            colima status 2>/dev/null || colima start -c "$nproc" -m "$mem" --vm-type=vz --mount-type=virtiofs || { errormsg "colima could not be started.\n"; return 1; }
            docker context use colima || { errormsg "switching to colima Docker context failed\n"; return 1; }
        else
            errormsg "Docker Engine is not running. Please start the Docker Engine manually."
            return 1
        fi
    fi
}

build()
{
    docker build \
        --build-arg BUILD_USER="$build_user" --build-arg BUILD_ROOTDIR="$root_dir" --build-arg BUILD_PROJDIR="$proj_dir" \
        -t "$image_name" .
}

run()
{
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
    docker run -dt --name "$container_name" --mount "$bind_mount" --mount "type=volume,src=${cached_volume},dst=${build_dir}/openwrt" "$image_name" bash
}

rm()
{
    docker kill "$container_name"
    docker container rm "$container_name"
}

clean_volume()
{
    docker volume rm "${cached_volume}"
}

case $1 in
    start)  start_docker ;;
    build)  start_docker
            build ;;
    run)    start_docker
            build
            run ;;
    rm)     rm ;;
    clean)  rm
            clean_volume ;;
    *)      print_help;;
esac