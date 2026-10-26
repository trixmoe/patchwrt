#!/bin/sh
# shellcheck source=./scripts/openwrt/common.sh
OPENWRT_SCRIPTS_DIR=$(dirname "$0")/
. "$OPENWRT_SCRIPTS_DIR/common.sh"
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
    printf "  clean            Delete openwrt cache volumes\n"
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
        --build-arg OPENWRT_MODULE="$OPENWRT_MODULE" \
        --target "builder" \
        -t "$image_name" .
}

tools()
{
    patchset=$1

    toolchain_image_name="$(print_toolchain_image_name "$patchset")"
    if [ -n "$OPENWRT_MODULE" ]; then
        toolchain_module_error=" and for OPENWRT_MODULE \"$OPENWRT_MODULE\""
    fi

    docker build \
        --build-arg BUILD_USER="$build_user" --build-arg BUILD_ROOTDIR="$root_dir" --build-arg BUILD_PROJDIR="$proj_dir" \
        --target "toolchain" --build-arg PATCHSET="$patchset" --build-arg OPENWRT_MODULE="$OPENWRT_MODULE" \
        -t "$toolchain_image_name" . || { errormsg "could not build toolchain for \"$patchset\"$toolchain_module_error.\n"; exit 1; }
}

run()
{
    if command -v colima > /dev/null 2>&1 && ! colima status 2>&1 | grep -q virtiofs; then
        warnmsg "Colima does not use virtiofs, this can cause permission issues.\n"
        warnindent "To fix this issue, you must delete the colima VM by running \'colima delete\' and re-run this command, note that IT WILL DELETE ALL DOCKER DATA.\n\n"
        warnmsg "As to avoid any potential issues, some files/directories will not be mounted (e.g. .git).\n"
        warnindent "As such, you cannot commit your patches from the container: the changes will be lost, you would have to push them.\n"
        COLIMA_NO_VIRTIOFS=defined
    fi

    bind_mounts=""
    # Assumption: all modules are OpenWrt directories - this could be changed by e.g. checking for "openwrt" in the names
    MODULE_DIRECTORIES=$(modules_dir)
    ALL_MODULE_DIRECTORIES=$(all_modules_dir)
    if [ -n "$COLIMA_NO_VIRTIOFS" ] || [ -n "$CI" ]; then
        infomsg "Mounting all non-module directory files (excl. hidden directories, e.g. .git).\n"
        # Given we can't do fancy mounts (no virtiofs), we will mount everything manually.
        # This used to be patches-only, but we can do better (as implemented here).
        #
        # CI-specific: we can technically use the "fancy" root mount, but this would *force* us to
        # mount an otherwise useless volume. (given caching is done by toolchain target image layer)
        # **Importantly**: copy-on-new/empty-volume is space/time intensive!
        # By avoiding it, we shorten builds.
        for e in ./*; do
            n=$(basename "$e")
            echo "$ALL_MODULE_DIRECTORIES" | grep -Fqx -- "$n" && continue
            bind_mounts="$bind_mounts --mount type=bind,src=./${n},dst=${build_dir}/${n}"
        done
    else
        infomsg "Mounting root.\n"
        # By mounting the whole root project directory, we can do *everything* from the container, as if it was a VM.
        # Importantly: we must (later step) also cache openwrt's toolchain and other, if we want to avoid long compiles.
        bind_mounts="--mount type=bind,src=./,dst=${build_dir}"
    fi

    volume_mounts=""
    if [ -z "$CI" ]; then
        # Outside of CI, we mount cached volumes to avoid recompilation, we assume all modules are OpenWrt
        # We cache *all* modules to allow for 1 single container image to work for all patchsets and versions
        infomsg "Mounting modules as cached volumes.\n"
        for dir in ${MODULE_DIRECTORIES}; do
            volume_mounts="$volume_mounts --mount type=volume,src=${cached_volume}-$dir,dst=${build_dir}/$dir"
        done
    fi

    # shellcheck disable=SC2016 # this is intended - variable should be evaluated in colima VM
    if command -v colima > /dev/null 2>&1 && sock=$(colima ssh eval 'echo $SSH_AUTH_SOCK' 2>/dev/null) && [ -n "$sock" ]; then
        # Forward colima's ssh-agent socket into the container so ssh works there to
        ssh_agent_args="-v $sock:$sock -e SSH_AUTH_SOCK=$sock"
    fi

    mounts="$bind_mounts $volume_mounts"
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
    all_docker_volumes=$(docker volume ls -q) || {
        errormsg "could not list Docker volumes.\n"
        return 1
    }

    for docker_volume in $all_docker_volumes; do
        case $docker_volume in
            "$cached_volume"|"$cached_volume"-*)
                docker volume rm -- "$docker_volume" || warnmsg "could not remove volume: %s\n" "$docker_volume"
                ;;
        esac
    done
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
