#!/bin/bash
#
# Creates meta data files for the given 7z archive files
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

set -o nounset
set -o pipefail

synopsis()
{
    cat <<END
usage: make-archive-meta.sh <7z-archive>...
END
}

short_usage()
{
    cat <<END
$(synopsis)

Try 'make-archive-meta.sh --help' for more information.
END
}

usage()
{
    less --quit-if-one-screen <<END
$(synopsis)

Create meta data files for the given 7z archive files.

These meta data files are required at build time by the sailfish-sdk-installer.

For each passed file a corresponding meta data file will be created in the
current working directory, with the same base name but the ".meta" suffix
added.
END
}

fatal()
{
    echo "make-archive-meta.sh: fatal: $*" >&2
}

bad_usage()
{
    fatal "$*"
    short_usage >&2
}

with_tmp_file()
{
    local file=$1 cmd=("${@:2}")
    local tmp_file=

    with_tmp_file_cleanup()
    (
        trap 'echo cleaning up...' INT TERM HUP
        if [[ $tmp_file ]]; then
            rm -f "$tmp_file"
        fi
    )
    trap 'with_tmp_file_cleanup; trap - RETURN' RETURN
    trap 'return 1' INT TERM HUP

    tmp_file=$(mktemp "$file.XXX") || return

    if "${cmd[@]}" <&3 >"$tmp_file"; then
        cat <"$tmp_file" >"$file" || return
    else
        return $?
    fi
} 3<&0 <&-

get_sha1()
{
    local archive=$1
    sha1sum <"$archive" |cut -d' ' -f1
}

get_uncompressed_size()
{
    local archive=$1

    local sizes=
    sizes=$(7z l -slt "$archive" |sed -n 's/^Size = \([0-9]\+\)$/\1/p') || return

    if [[ ! $sizes ]]; then
        fatal "Empty archive '$archive'?"
        return 1
    fi

    local size= total_size=0
    for size in $sizes; do
        let total_size+=size
    done

    echo "$total_size"
}

get_compressed_size()
{
    local archive=$1

    stat -c "%s" "$archive" || return
}

get_meta_data()
{
    local archive=$1

    local basename=
    basename=$(basename "$archive") || return

    local sha1=
    sha1=$(get_sha1 "$archive") || return

    local uncompressed_size=
    uncompressed_size=$(get_uncompressed_size "$archive") || return

    local compressed_size=
    compressed_size=$(get_compressed_size "$archive") || return

    printf '%s %s %s %s\n' "$basename" "$sha1" "$uncompressed_size" "$compressed_size"
}

main()
{
    local opt_archives=()

    while (( $# > 0 )); do
        case $1 in
            -h)
                short_usage
                return
                ;;
            --help)
                usage
                return
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
                opt_archives+=("$1")
                ;;
        esac
        shift
    done

    opt_archives+=("$@")

    if (( ${#opt_archives[@]} == 0 )); then
        bad_usage "Argument expected"
        return 1
    fi

    local archive=
    for archive in "${opt_archives[@]}"; do
        local meta="$(basename "$archive").meta"
        with_tmp_file "$meta" get_meta_data "$archive" || return
    done
}

main "$@"
