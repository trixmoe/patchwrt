#!/bin/sh
# shellcheck source=./scripts/common.sh
. "$(dirname "$0")/common.sh"
set -e
# shellcheck disable=SC3040 # Set pipefail if it works in a subshell, disregard if unsupported
(set -o pipefail 2> /dev/null) && set -o pipefail

rootdir >/dev/null

print_help()
{
    printf "Usage: docker.sh COMMAND\n\n"
    printf "  start            Start colima\n"
    printf "  build            Build the image\n"
    printf "  tools [patchset] Build the toolchain for [patchset]\n"
    printf "  run              Run a development container\n"
    printf "  all              Start, Build and Run a container\n"
    printf "  rm               Kill and delete the existing container\n"
    printf "  clean            Delete openwrt cache volume\n"
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

            colima status 2>/dev/null || colima start -c "$nproc" -m "$mem" --ssh-agent --vm-type=vz --mount-type=virtiofs || { errormsg "colima could not be started.\n"; return 1; }
            docker context use colima || { errormsg "switching to colima Docker context failed\n"; return 1; }
        else
            errormsg "Docker Engine is not running. Please start the Docker Engine manually."
            return 1
        fi
    fi
}

build()
{
    [ ! -d patches ] && mkdir -v patches # Ensure patches directory exist (required)
    docker build \
        --build-arg BUILD_USER="$build_user" --build-arg BUILD_ROOTDIR="$root_dir" --build-arg BUILD_PROJDIR="$proj_dir" \
        --target "builder" \
        -t "$image_name" .
}

tools()
{
    patchset=$1
    docker build \
        --build-arg BUILD_USER="$build_user" --build-arg BUILD_ROOTDIR="$root_dir" --build-arg BUILD_PROJDIR="$proj_dir" \
        --target "toolchain" --build-arg PATCHSET="$patchset" \
        -t "$image_name-toolchain-$(printf '%s' "$patchset" | tr '_' '-')" . || { errormsg "could not build toolchain for \"$patchset\".\n"; exit 1; }
}

run()
{
    if command -v colima > /dev/null 2>&1 && ! colima status 2>&1 | grep -q virtiofs; then
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

    if [ -n "$CI" ]; then
        # Unlike local dev, CI doesn't use a cached volume, instead the cache lives in the image instead, which also
        # avoids docker's slow copy-on-empty behavior with empty volumes. We still need to overwrite non-cached files 
        # (e.g. Makefile) with the current ones instead of the cached versions.
        EXCLUDES=$(grep "_DIRECTORY=" modules | cut -d= -f2)
        for e in ./*; do
            n=$(basename "$e")
            echo "$EXCLUDES" | grep -qx "$n" && continue
            mounts="$mounts --mount type=bind,src=./${n},dst=${build_dir}/${n}"
        done
    else
        mounts="--mount $bind_mount --mount type=volume,src=${cached_volume},dst=${build_dir}/openwrt"
    fi

    # shellcheck disable=SC2016 # this is intended - variable should be evaluated in colima VM
    if command -v colima > /dev/null 2>&1 && sock=$(colima ssh eval 'echo $SSH_AUTH_SOCK' 2>/dev/null) && [ -n "$sock" ]; then
        # Forward colima's ssh-agent socket into the container so ssh works there to
        ssh_agent_args="-v $sock:$sock -e SSH_AUTH_SOCK=$sock"
    fi

    # shellcheck disable=SC2086 # ssh_agent_args represents arguments
    docker run --name "$container_name" \
        $mounts $ssh_agent_args \
        -dt "$image_name" bash
}

rm()
{
    [ "$(docker ps -q -f "name=$container_name")" ] && docker kill "$container_name"
    docker container rm "$container_name"
}

clean_volume()
{
    docker volume rm "${cached_volume}"
}

# No arguments -> help
if [ $# -eq 0 ]; then
    print_help
fi

# Parse multiple arguments (e.g. 'start build') w/o triggering help
while [ $# -gt 0 ]; do
    case $1 in
        start)  start_docker ;;
        build)  build ;;
        tools)  tools "$2"
                shift;;
        run)    run ;;
        all)    start_docker
                build
                run ;;
        rm)     rm ;;
        clean)  clean_volume ;;
        *)      print_help
                break;;
    esac

    shift
done
