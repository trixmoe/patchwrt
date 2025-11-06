#!/bin/sh
# shellcheck source=./scripts/common.sh
. "$(dirname "$0")/common.sh"

# cd into + save project root
vps_root_dir=$(rootdir)

. "$MODULES_FILE_ROOTDIR"

print_help()
{
    printf "Usage: save-patches.sh\n"
    printf "This script takes commits on modules and saves them as patch files.\n\n"

    printf "  --one    Only save a single tag (generic)\n"
    printf "  --help   Show this help menu\n"
}

while :; do
    case $1 in
        --one)
            one_tag=1
            ;;
        -\?|-help|--help)
            print_help
            exit 0
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

# filter-branch fails if changes aren't stashed
stash_uncomitted_changes()
{
    unset stash_ref
    stash_ref="$(git stash create -q)"
    git reset --hard -q
}

# Unstash if stashed
unstash_uncomitted_changes()
{
    [ -n "${stash_ref}" ] && git stash apply -q "${stash_ref}"
}

# Set committer and commit date -> consistent commit hashes
fix_commiter_info()
{
    module=$1
    upstream_commit=$2
    # shellcheck disable=SC2016
    FILTER_BRANCH_SQUELCH_WARNING=1 git -c user.name='vps' -c user.email='vps@invalid' -c commit.gpgsign=false filter-branch -f --tag-name-filter cat --env-filter 'export GIT_COMMITTER_DATE="$GIT_AUTHOR_DATE"; export GIT_COMMITTER_NAME="vps"; export GIT_COMMITTER_EMAIL="vps@invalid"' "$upstream_commit..HEAD"
}

get_tag()
{
    commit_identifier=$1
    git describe --tags --abbrev=0 "$commit_identifier"
}

get_commit_hash()
{
    commit_identifier=$1
    git rev-parse "$commit_identifier"
}

is_commit_child_of_ancestor()
{
    child=$1
    ancestor=$2
    git merge-base --is-ancestor "$ancestor" "$child"
}

for module in $MODULES; do
    infomsg "Saving patches for module: %s\n" "$module"

    # cd into module directory
    cd "$vps_root_dir" || { errormsg "cannot enter versioned patch system root directory\n"; exit 1; }
    module_dir="" # SC2154/SC2034
    eval module_dir="\$${module}_DIRECTORY"
    cd "$module_dir" || { warnmsg "cannot enter module directory \"%s\"\n" "$module_dir"; continue; }

    stash_uncomitted_changes

    eval upstream_commit="\$${module}_COMMIT"
    fix_commiter_info "$module" "$upstream_commit"

    unstash_uncomitted_changes

    # Get top-most patchset, and do checks
    current_tag=$(get_tag "HEAD") || { errormsg "There are no tags present in \"%s\". Skipping\n" "$module_dir" ; continue; }
    current_tag_id="refs/tags/$current_tag"
    current_commit=$(git rev-parse HEAD)
    if [ "$current_commit" != "$(get_commit_hash "$current_tag_id")" ]; then
        errormsg "HEAD is not tagged. Skipping"
        warnmsg "To avoid saving patches in the wrong patchset, HEAD must be tagged correctly."
        continue
    fi
    saved_patchsets_count=0

    # Save patchsets, as long as there is a tag, and that it is a child of the upstream commit
    while [ -n "$current_tag" ] && is_commit_child_of_ancestor "$current_tag_id" "$upstream_commit" ; do
        unset use_upstream

        # Get oldest commit of current patchset
        # -> might be a tag, which should be younger than upstream commit, otherwise use upstream
        ancestor_tag=$(get_tag "refs/tags/${current_tag}~1") \
            && ancestor_tag_id="refs/tags/$ancestor_tag" \
            && is_commit_child_of_ancestor "$ancestor_tag_id" "$upstream_commit" \
            || use_upstream=1

        # If we use upstream, there are no more patchsets
        if [ -n "$use_upstream" ]; then
            ancestor_tag=""
            ancestor_tag_id=$upstream_commit
        fi

        patchset_dir=$vps_root_dir/patches/$module_dir/$current_tag
        mkdir -p "$patchset_dir"
        rm "$patchset_dir"/*.patch || true # delete old patches
        git format-patch --zero-commit -k --patience -o "$patchset_dir" "$ancestor_tag_id..$current_tag_id"

        saved_patchsets_count=$((saved_patchsets_count+1))
        [ -n "$one_tag" ] && break
        current_tag=$ancestor_tag
        current_tag_id=$ancestor_tag_id
    done

    infomsg "Saved %i patch sets for \"%s\"\n" "$saved_patchsets_count" "$module_dir"
done
