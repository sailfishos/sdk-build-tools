#!/bin/bash
#
# On Linux this script builds ICU library into subdirectories in
# the $HOME/invariant dir. ICU sources must be found from the current user's
# home directory $HOME/invariant/icu.
#
# On Windows this script downloads the ICU library and extracts it into
# the $HOME/invariant dir.
#
#
# Copyright (C) 2014 Jolla Oy
# Contact: Juha Kallioinen <juha.kallioinen@jolla.com>
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

export LC_ALL=C

. $(dirname $0)/defaults.sh
. $(dirname $0)/utils.sh

configure_icu() {
    $DEF_ICU_SRC_DIR/source/runConfigureICU Linux --disable-draft --disable-extras --disable-debug --disable-icuio --disable-layout --disable-tests --disable-samples --enable-release --prefix=$DEF_ICU_INSTALL_DIR
}

build_icu() {
    rm -rf   $DEF_ICU_BUILD_DIR
    mkdir -p $DEF_ICU_BUILD_DIR
    pushd    $DEF_ICU_BUILD_DIR
    configure_icu
    make -j$(nproc)
    rm -rf $DEF_ICU_INSTALL_DIR
    make install
    popd
}

download_icu_win() {
    local download_dest=$DEF_ICU_DOWNLOAD_DIR/${DEF_WIN_ICU_DOWNLOAD_URL##*/}
    curl -o $download_dest $DEF_WIN_ICU_DOWNLOAD_URL
    rm -rf $DEF_ICU_INSTALL_DIR
    7z -y -o$DEF_ICU_INSTALL_DIR x $download_dest
    [[ -d $DEF_ICU_INSTALL_DIR ]] || fail "Fixme: Name of the ICU archive root directory has changed"
}

build_arch() {
    if [[ $UNAME_SYSTEM == "Linux" ]]; then
        echo "linux"
    elif [[ $UNAME_SYSTEM == "Darwin" ]]; then
        echo "mac"
    else
        echo "windows"
    fi
}

fail() {
    echo "FAIL: $@"
    exit 1
}

usage() {
    if [[ $(build_arch) == "linux" ]]; then
        cat <<EOF
Build ICU library

Prerequisites:
 - ICU sources
   [$DEF_ICU_SRC_DIR]
 - ICU build directory (will be created)
   [$DEF_ICU_BUILD_DIR]
 - ICU installation directory (will be created)
   [$DEF_ICU_INSTALL_DIR]

EOF

    elif [[ $(build_arch) == "windows" ]]; then
        cat <<EOF
Download ICU library

Prerequisites:
 - Download directory for ICU binaries (must exist)
   [$DEF_ICU_DOWNLOAD_DIR]
 - ICU installation directory (will be created)
   [$DEF_ICU_INSTALL_DIR]

EOF
    fi

    cat <<EOF
Usage:
   $(basename $0) [OPTION]

Options:
   -y  | --non-interactive    answer yes to all questions presented by the script
   -h  | --help               this help

EOF

    # exit if any argument is given
    [[ -n "$1" ]] && exit 1
}


# handle commandline options
while [[ ${1:-} ]]; do
    case "$1" in
	-y | --non-interactive ) shift
	    OPT_YES=1
	    ;;
	-h | --help ) shift
	    usage quit
	    ;;
	* )
	    usage quit
	    ;;
    esac
done

if [[ $(build_arch) == "linux" ]]; then
    echo "Using sources from [$DEF_ICU_SRC_DIR]"
elif [[ $(build_arch) == "windows" ]]; then
    echo "Downloading ICU from [$DEF_WIN_ICU_DOWNLOAD_URL]"
fi

# confirm
if [[ -z $OPT_YES ]]; then
    while true; do
	read -p "Do you want to continue? (y/n) " answer
	case $answer in
	    [Yy]*)
		break ;;
	    [Nn]*)
		echo "Ok, exiting"
		exit 0
		;;
	    *)
		echo "Please answer yes or no."
		;;
	esac
    done
fi

if [[ $(build_arch) == "windows" && ! -d $DEF_ICU_DOWNLOAD_DIR ]]; then
    fail "directory [$DEF_ICU_DOWNLOAD_DIR] does not exist"
fi

if [[ $(build_arch) == "linux" && ! -d $DEF_ICU_SRC_DIR ]]; then
    fail "directory [$DEF_ICU_SRC_DIR] does not exist"
fi

# stop in case of errors
set -e

# record start time
BUILD_START=$(date +%s)

if [[ $(build_arch) == "linux" ]]; then
    build_icu
elif [[ $(build_arch) == "windows" ]]; then
    download_icu_win
else
    echo This platform is not yet supported.
fi
# record end time
BUILD_END=$(date +%s)

time=$(( BUILD_END - BUILD_START ))
hour=$(( $time / 3600 ))
mins=$(( $time / 60 - 60*$hour ))
secs=$(( $time - 3600*$hour - 60*$mins ))

echo Time used for ICU build: $(printf "%02d:%02d:%02d" $hour $mins $secs)
