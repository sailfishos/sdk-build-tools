#!/bin/bash
#
# Creates meta data file for the given sb2 image file
#
# Copyright (C) 2022 Jolla Ltd.
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
usage: make-sb2-image-meta.sh <sb2-image>
END
}

short_usage()
{
    cat <<END
$(synopsis)

Try 'make-sb2-image-meta.sh --help' for more information.
END
}

usage()
{
    less --quit-if-one-screen <<END
$(synopsis)

Create meta data file for the given sb2 image file.

These meta data files are used by sdk-manage at sb2 image installation time.

For the <sb2-image> file a corresponding meta data file will be created in the
current working directory, with the same base name but the ".meta" suffix
added.
END
}

fatal()
{
    echo "make-sb2-image-meta.sh: fatal: $*" >&2
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

get_meta_data()
{
    local archive=$1

    local ssu_ini=
    ssu_ini=$(tar -x --to-stdout -f "$archive" ./etc/ssu/ssu.ini) || return

    local brand=
    brand=$(sed -n 's/^brand=//p' <<<"$ssu_ini") || return
    [[ $brand ]] || { fatal "Failed to determine Brand name"; return 1; }

    local release=
    release=$(sed -n 's/^release=//p' <<<"$ssu_ini") || return
    [[ $release ]] || { fatal "Failed to determine Release version"; return 1; }

    cat <<END
[General]
meta-version=1
brand=$brand
release=$release
END
}

main()
{
    local opt_archive=

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
            -*)
                bad_usage "Unexpected argument: $1"
                return 1
                ;;
            *)
                if [[ ! $opt_archive ]]; then
                    opt_archive=$1
                else
                    bad_usage "Unexpected argument: $1"
                    return 1
                fi
                ;;
        esac
        shift
    done

    if [[ ! $opt_archive ]]; then
        bad_usage "Argument expected"
        return 1
    fi

    local meta="$(basename "$opt_archive").meta"
    with_tmp_file "$meta" get_meta_data "$opt_archive" || return
}

main "$@"
