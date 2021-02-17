#!/bin/bash
#
# Remove unused shared images from upload host
#
# Copyright (C) 2019 Jolla Ltd.
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
usage: prune-shared.sh [-y|--non-interactive] [--uhost <hostname>]
                       [--uuser <username>] [--upath <path>]
                       [--keep <7zfile>...] <path>
END
}

short_usage()
{
    cat <<END
$(synopsis)

Try 'prune-shared.sh --help' for more information.
END
}

usage()
{
    less --quit-if-one-screen <<END
$(synopsis)

Remove unused shared images from <path> at upload host. Relative <path> will
be resolved against '--upath'. Works equally for images uploaded by
setup-sb2-images.sh and setup-emulator.sh. In case of the former it also
updates the 'targets.json' if it exists in <path>.

This tool does not remove unused files permanently. A directory at
<path>.TRASH will be created to hold the files (re)moved from <path> - it needs
to be cleared manually in order to free the disk space.

OPTIONS
    -y, --non-interactive
        Assume yes to all questions

    --keep <7zfile>...
        Do not remove the <7zfile> and the accompanying meta data files.
        Multiple files may be specified, separated with comma.

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
    echo "prune-shared.sh: fatal: $*" >&2
}

bad_usage()
{
    fatal "$*"
    short_usage >&2
}

set_defaults()
{
    OPT_H=
    OPT_HELP=
    OPT_INTERACTIVE=1
    OPT_KEEP=
    OPT_SHARED_PATH=
    OPT_UPLOAD_HOST=$DEF_UPLOAD_HOST
    OPT_UPLOAD_PATH=$DEF_UPLOAD_PATH
    OPT_UPLOAD_USER=$DEF_UPLOAD_USER
}

parse_opts()
{
    local positional=()
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
            -y|--non-interactive)
                OPT_INTERACTIVE=
                ;;
            --keep)
                if [[ ! ${2:-} ]]; then
                    bad_usage "Argument expected: $1"
                    return 1
                fi
                OPT_KEEP=${2//,/$'\n'}
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
                positional+=("$1")
                ;;
        esac
        shift
    done

    positional+=("$@")

    if [[ ${#positional[@]} -ne 1 ]]; then
        bad_usage "Exactly one positional argument expected"
        return 1
    fi

    OPT_SHARED_PATH=${positional[0]}

    if [[ $OPT_SHARED_PATH && $OPT_SHARED_PATH != /* ]]; then
        OPT_SHARED_PATH=$OPT_UPLOAD_PATH/$OPT_SHARED_PATH
    fi
    OPT_SHARED_PATH=$(ssh "$OPT_UPLOAD_USER@$OPT_UPLOAD_HOST" \
        "realpath --canonicalize-missing $OPT_SHARED_PATH") || return
}

main()
{
    set_defaults || return
    parse_opts "$@" || return

    if [[ $OPT_H ]]; then
        short_usage
        return
    fi

    if [[ $OPT_HELP ]]; then
        usage
        return
    fi

    local used_images=
    used_images=$(ssh "$OPT_UPLOAD_USER@$OPT_UPLOAD_HOST" \
        "find $OPT_UPLOAD_PATH -type l -exec readlink -f {} \\;" \
        |sort -u |sed -n "s,^$OPT_SHARED_PATH/,,p") || return
    local all_images=
    all_images=$(ssh "$OPT_UPLOAD_USER@$OPT_UPLOAD_HOST" "cd $OPT_SHARED_PATH && ls *.7z" |sort) || return

    local unused_images=
    unused_images=$(join -v 1 <(cat <<<"$all_images") <(cat <<<"$used_images")) || return

    local to_remove=()
    to_remove=($(join -v 1 <(cat <<<"$unused_images") <(cat <<<"$OPT_KEEP"))) || return

    if [[ ${#to_remove[*]} -eq 0 ]]; then
        echo "Nothing to be removed" >&2
    else
        to_remove+=("${to_remove[@]/%/.meta}" "${to_remove[@]/%/.md5sum}")

        if [[ $OPT_INTERACTIVE ]]; then
            echo "The following images (and the accompanying files) would be removed from the upload host:"
            echo
            (IFS=$'\n'; sed 's/^/\t/' <<<"${to_remove[*]}" |sort)
            echo
            local YN=
            read -p "Continue? [Y/n] " YN
            [[ $YN && $YN != y ]] && return
        fi

        local trash=$OPT_SHARED_PATH.TRASH
        ssh "$OPT_UPLOAD_USER@$OPT_UPLOAD_HOST" \
            "mkdir -p $trash \
            && cd $OPT_SHARED_PATH \
            && mv -v --target-directory=$trash ${to_remove[*]}"
    fi

    if ssh "$OPT_UPLOAD_USER@$OPT_UPLOAD_HOST" "test -e $OPT_SHARED_PATH/targets.json"; then
        echo "Updating targets.json..." >&2
        update_remote_targets_json "$OPT_SHARED_PATH" || return
    fi
}

main "$@"
