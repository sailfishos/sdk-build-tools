#!/bin/bash
#
# Create installer archives from sb2 tooling/target images in tar.bz2 format
#
# Copyright (C) 2018 Jolla Ltd.
# Contact: Martin Kampas <martin.kampas@jolla.com>
# All rights reserved.
#
# You may use this file under the terms of BSD license as follows:
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#   * Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#   * Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#   * Neither the name of the Jolla Ltd nor the
#     names of its contributors may be used to endorse or promote products
#     derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

. $(dirname $0)/defaults.sh
. $(dirname $0)/utils.sh

set -o nounset
set -o pipefail

synopsis()
{
    cat <<END
usage: setup-sb2-images.sh [-c|--compression <num>] [-n|--dry-run]
           [-P|--max-procs <limit>] [--no-meta] [--no-shared]
           [--shared-path <path>] [-u|--upload <dir>]
           [--uhost <hostname>] [--uuser <username>] [--upath <path>]
           <image.tar.bz2>...
END
}

short_usage()
{
    cat <<END
$(synopsis)

Try 'setup-sb2-images.sh --help' for more information.
END
}

usage()
{
    less --quit-if-one-screen <<END
$(synopsis)

Convert the given sb2 tooling/target images in tar.bz2 format to a format
suitable for use with both SDK Control Centre and SDK installer. Create
.md5sum files and unless the '--no-meta' option is used, create the
corresponding .meta files with 'make-archive-meta.sh' as well. The resulting
files will be placed next to the original files and optionally uploaded to the
build host. When uploaded, the targets.json in the destination directory will
be updated, listing all images found in that directory, i.e., including those
uploaded before.

OPTIONS
    -c, --compression <num>
        Set the 7z compression level from 0 (fast) to 9 (best)

    -n, --dry-run
        Suppress normal operation, show what would be done

    -P, --max-procs
        Limit the maximum number of processors to use. Defaults to N-1
        available processors or 1 on single processor systems

    --no-meta
        Suppress creating meta data files with 'make-archive-meta.sh'

    --no-shared
        See '--upload'.

    --shared-path <path>
        See '--upload'. Relative <path> will be resolved relatively to
        '--upath'. Defaults to [$DEF_SHARED_SB2_IMAGES_PATH]

    -u, --upload <dir>
        Upload results. <dir> is the root directory for this SDK build,
        relative to the global upload path. Files will be uploaded under the
        '<dir>/targets' path. If this path does not exists, a symbolic link
        will be created using this name, pointing to the shared location for
        sb2 images. This can be overriden by '--no-shared', in which case a
        directory will be created instead of the symbolic link. The default
        shared location can be overriden with '--shared-path'.

    --uhost <hostname>
        Override the default upload host [$DEF_UPLOAD_HOST]

    --uuser <username>
        Override the default upload user [$DEF_UPLOAD_USER]

    --upath <path>
        Override the default global upload path [$DEF_UPLOAD_PATH]
END
}

fatal()
{
    echo "setup-sb2-images.sh: fatal: $*" >&2
}

bad_usage()
{
    fatal "$*"
    short_usage >&2
}

xargs_()
{
    xargs --max-procs="$OPT_MAX_PROCS" "$@"
}

recompress()
{
    local files=("$@")

    recompress_worker_initial_args=("$OPT_LEVEL" "$OPT_NO_META" "$BUILD_TOOLS_SRC" "$OPT_DRY_RUN")
    recompress_worker()
    {
        set -o nounset
        set -o pipefail

        local level=$1
        local no_meta=$2
        local build_tools_src=$3
        local dry_run=$4

        local file=$5

        local dirname=
        dirname=$(dirname "$file") || return
        local basename=
        basename=$(basename "$file") || return
        local decompressed_basename=${basename%.bz2}

        local ok=
        recompress_worker_cleanup()
        (
            trap 'echo cleaning up...' INT TERM HUP
            if [[ ! $dry_run ]]; then
                rm -f "$dirname/$decompressed_basename"
                if [[ ! $ok ]]; then
                    rm -f "$dirname/$decompressed_basename.7z"
                    rm -f "$dirname/$decompressed_basename.7z.meta"
                fi
            fi
        )
        trap 'recompress_worker_cleanup; trap - RETURN' RETURN
        trap 'return 1' INT TERM HUP

        _ pushd "$dirname" >/dev/null || return

        echo "Decompressing '$dirname/$basename'..." >&2
        # Pass --force to allow working with input files that are symlinks
        _ bunzip2 --keep --force -- "$basename" || return
        echo "Finished decompressing '$dirname/$basename'" >&2

        basename=$decompressed_basename

        echo "Creating archive '$dirname/$basename.7z'..." >&2
        _ rm -f -- "$basename.7z" || return
        _ 7z a ${level:+-mx="$level"} -- "$basename.7z" "$basename" >/dev/null || return
        _ rm -f -- "$basename" || :
        echo "Finished creating archive '$dirname/$basename.7z'" >&2

        if [[ ! $no_meta ]]; then
            echo "Creating meta data file for '$dirname/$basename.7z" >&2
            _ $build_tools_src/make-archive-meta.sh "$basename.7z" || return
        fi

        md5sum() { command md5sum "$1" > "$2"; }
        _ md5sum "$basename.7z"{,.md5sum}

        _ popd >/dev/null || return

        ok=1
    }
    export -f recompress_worker || return

    printf '%s\n' "${files[@]}" \
        |xargs_ -L1 bash -c 'recompress_worker "$@"' bash "${recompress_worker_initial_args[@]}"
}

set_defaults()
{
    # Use up to N-1 available processors by default
    DEF_MAX_PROCS=
    DEF_MAX_PROCS=$(getconf _NPROCESSORS_ONLN)
    let DEF_MAX_PROCS--
    if (( DEF_MAX_PROCS <= 0 )); then
        DEF_MAX_PROCS=1
    fi

    OPT_H=
    OPT_HELP=
    OPT_DRY_RUN=
    OPT_IMAGES=()
    OPT_LEVEL=
    OPT_MAX_PROCS=$DEF_MAX_PROCS
    OPT_NO_META=
    OPT_NO_SHARED=
    OPT_SHARED_PATH=$DEF_SHARED_SB2_IMAGES_PATH
    OPT_UPLOAD=
    OPT_UPLOAD_DIR=
    OPT_UPLOAD_HOST=$DEF_UPLOAD_HOST
    OPT_UPLOAD_PATH=$DEF_UPLOAD_PATH
    OPT_UPLOAD_USER=$DEF_UPLOAD_USER

    TARGETS_SUBDIR=targets
    OPT_TARGETS_UPLOAD_PATH=$OPT_UPLOAD_PATH/$OPT_UPLOAD_DIR/$TARGETS_SUBDIR
}

parse_opts()
{
    while (( $# > 0 )); do
        case $1 in
            -h)
                OPT_H=1
                return
                ;;
            --help)
                OPT_HELP=1
                return
                ;;
            -c|--compression)
                if [[ ! ${2:-} ]]; then
                    bad_usage "Argument expected: $1"
                    return 1
                fi
                OPT_LEVEL=$2
                shift
                ;;
            -n|--dry-run)
                OPT_DRY_RUN=1
                ;;
            -P|--max-procs)
                if [[ ! ${2:-} ]]; then
                    bad_usage "Argument expected: $1"
                    return 1
                fi
                OPT_MAX_PROCS=$2
                shift
                ;;
            --no-meta)
                OPT_NO_META=1
                ;;
            --no-shared)
                OPT_NO_SHARED=1
                ;;
            --shared-path)
                if [[ ! ${2:-} ]]; then
                    bad_usage "Argument expected: $1"
                    return 1
                fi
                OPT_SHARED_PATH=$2
                shift
                ;;
            -u|--upload)
                if [[ ! ${2:-} ]]; then
                    bad_usage "Argument expected: $1"
                    return 1
                fi
                OPT_UPLOAD=1
                OPT_UPLOAD_DIR=$2
                shift
                ;;
            --uhost)
                if [[ ! ${2:-} ]]; then
                    bad_usage "Argument expected: $1"
                    return 1
                fi
                OPT_UPLOAD_HOST=$2
                shift
                ;;
            --upath)
                if [[ ! ${2:-} ]]; then
                    bad_usage "Argument expected: $1"
                    return 1
                fi
                OPT_UPLOAD_PATH=$2
                shift
                ;;
            --uuser)
                if [[ ! ${2:-} ]]; then
                    bad_usage "Argument expected: $1"
                    return 1
                fi
                OPT_UPLOAD_USER=$2
                shift
                ;;
            --)
                shift
                break
                ;;
            -*)
                bad_usage "Unexpected argument: $1"
                return 1
                ;;
            *)
                OPT_IMAGES+=("$1")
                ;;
        esac
        shift
    done

    if [[ $OPT_SHARED_PATH && $OPT_SHARED_PATH != /* ]]; then
        OPT_SHARED_PATH=$OPT_UPLOAD_PATH/$OPT_SHARED_PATH
    fi

    OPT_TARGETS_UPLOAD_PATH=$OPT_UPLOAD_PATH/$OPT_UPLOAD_DIR/$TARGETS_SUBDIR

    OPT_IMAGES+=("$@")

    if (( ${#OPT_IMAGES[@]} == 0 )); then
        bad_usage "Argument expected"
        return 1
    fi
}

setup_dry_run()
{
    if [[ $OPT_DRY_RUN ]]; then
        OPT_MAX_PROCS=1
        _() { printf '%q ' + "$@"; echo; } >&2
    else
        _() { "$@"; }
    fi
    export -f _
}

main()
{
    set_defaults || return
    parse_opts "$@" || return
    setup_dry_run || return

    if [[ $OPT_H ]]; then
        short_usage
        return
    fi

    if [[ $OPT_HELP ]]; then
        usage
        return
    fi

    local decompressed_images=()

    main_cleanup()
    (
        trap 'echo cleaning up...' INT TERM HUP
        if [[ ! $OPT_DRY_RUN ]]; then
            rm -f "${decompressed_images[@]}"
        fi
    )
    trap 'main_cleanup; trap - RETURN' RETURN
    trap 'return 1' INT TERM HUP

    decompressed_images=("${OPT_IMAGES[@]%.bz2}")
    recompress "${OPT_IMAGES[@]}" || return

    if [[ $OPT_UPLOAD ]]; then
        local results=("${decompressed_images[@]/%/.7z}" "${decompressed_images[@]/%/.7z.md5sum}")
        if [[ ! $OPT_NO_META ]]; then
            results+=("${decompressed_images[@]/%/.7z.meta}")
        fi
        echo "Uploading..." >&2
        if [[ $OPT_NO_SHARED ]]; then
            _ ssh "$OPT_UPLOAD_USER@$OPT_UPLOAD_HOST" "mkdir -p $OPT_TARGETS_UPLOAD_PATH" || return
        else
            local target=$(realpath --canonicalize-missing \
                --relative-to="$OPT_UPLOAD_PATH/$OPT_UPLOAD_DIR" "$OPT_SHARED_PATH")
            _ ssh "$OPT_UPLOAD_USER@$OPT_UPLOAD_HOST" "test -e $OPT_TARGETS_UPLOAD_PATH \
                || (mkdir -p $OPT_UPLOAD_PATH/$OPT_UPLOAD_DIR \
                    && ln -s $target $OPT_TARGETS_UPLOAD_PATH)" || return
            # Remove possibly existing targets.json to avoid being noisy updating it twice
            _ ssh "$OPT_UPLOAD_USER@$OPT_UPLOAD_HOST" "rm -f $OPT_TARGETS_UPLOAD_PATH/targets.json"
            echo "Looking for possible unused images on the upload host..." >&2
            _ "$BUILD_TOOLS_SRC/prune-shared.sh" --uhost "$OPT_UPLOAD_HOST" \
                --uuser "$OPT_UPLOAD_USER" --upath "$OPT_UPLOAD_PATH" "$OPT_SHARED_PATH"
        fi
        _ scp "${results[@]}" "$OPT_UPLOAD_USER@$OPT_UPLOAD_HOST:$OPT_TARGETS_UPLOAD_PATH/" || return
        if [[ ! $OPT_DRY_RUN ]]; then
            echo "Updating targets.json..." >&2
            update_remote_targets_json "$OPT_TARGETS_UPLOAD_PATH" || return
        else
            echo "Would update targets.json" >&2
        fi
    fi
}

main "$@"
