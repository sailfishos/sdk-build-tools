#!/bin/bash
#
# On Linux this script builds LLVM/Clang libraries into subdirectories in
# the $HOME/invariant dir. LLVM sources must be found from the current user's
# home directory $HOME/invariant/llvm.
#
# On Windows and macOS this script downloads the LLVM/Clang libraries and
# extracts it into the $HOME/invariant dir.
#
#
# Copyright (C) 2014-2019 Jolla Ltd.
# Copyright (C) 2020 Open Mobile Platform LLC.
# Contact: http://jolla.com/
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

configure_llvm() {
    # See Qt Creator's README
    cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$DEF_LLVM_INSTALL_DIR -DLLVM_ENABLE_RTTI=ON $DEF_LLVM_SRC_DIR
}

build_llvm() {
    rm -rf   $DEF_LLVM_BUILD_DIR
    mkdir -p $DEF_LLVM_BUILD_DIR
    pushd    $DEF_LLVM_BUILD_DIR
    configure_llvm
    make -j$(getconf _NPROCESSORS_ONLN)
    rm -rf $DEF_LLVM_INSTALL_DIR
    make install
    popd
}

download_llvm_windows() {
    local download_dest=$DEF_LLVM_DOWNLOAD_DIR/${DEF_WIN_LLVM_DOWNLOAD_URL##*/}
    curl -o $download_dest $DEF_WIN_LLVM_DOWNLOAD_URL
    rm -rf $DEF_LLVM_INSTALL_DIR
    7z -y -o$(dirname $DEF_LLVM_INSTALL_DIR) x $download_dest
    [[ -d $DEF_LLVM_INSTALL_DIR ]] || fail "Fixme: Name of the LLVM/Clang archive root directory has changed"
}

download_llvm_mac() {
    local download_dest=$DEF_LLVM_DOWNLOAD_DIR/${DEF_MAC_LLVM_DOWNLOAD_URL##*/}
    curl -o $download_dest $DEF_MAC_LLVM_DOWNLOAD_URL
    rm -rf $DEF_LLVM_INSTALL_DIR
    7z -y -o$(dirname $DEF_LLVM_INSTALL_DIR) x $download_dest
    [[ -d $DEF_LLVM_INSTALL_DIR ]] || fail "Fixme: Name of the LLVM/Clang archive root directory has changed"
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
Build LLVM/Clang

Prerequisites:
 - LLVM/Clang sources
   [$DEF_LLVM_SRC_DIR]
 - LLVM/Clang build directory (will be created)
   [$DEF_LLVM_BUILD_DIR]
 - LLVM/Clang installation directory (will be created)
   [$DEF_LLVM_INSTALL_DIR]

EOF

    else
        cat <<EOF
Download LLVM/Clang

Prerequisites:
 - Download directory for LLVM/Clang binaries (must exist)
   [$DEF_LLVM_DOWNLOAD_DIR]
 - LLVM/Clang installation directory (will be created)
   [$DEF_LLVM_INSTALL_DIR]

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
    echo "Using sources from [$DEF_LLVM_SRC_DIR]"
elif [[ $(build_arch) == "mac" ]]; then
    echo "Downloading LLVM/Clang from [$DEF_MAC_LLVM_DOWNLOAD_URL]"
else
    echo "Downloading LLVM/Clang from [$DEF_WIN_LLVM_DOWNLOAD_URL]"
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

if [[ $(build_arch) != "linux" && ! -d $DEF_LLVM_DOWNLOAD_DIR ]]; then
    fail "directory [$DEF_LLVM_DOWNLOAD_DIR] does not exist"
fi

if [[ $(build_arch) == "linux" && ! -d $DEF_LLVM_SRC_DIR ]]; then
    fail "directory [$DEF_LLVM_SRC_DIR] does not exist"
fi

# stop in case of errors
set -e

# record start time
BUILD_START=$(date +%s)

if [[ $(build_arch) == "linux" ]]; then
    build_llvm
else
    download_llvm_"$(build_arch)"
fi
# record end time
BUILD_END=$(date +%s)

time=$(( BUILD_END - BUILD_START ))
hour=$(( $time / 3600 ))
mins=$(( $time / 60 - 60*$hour ))
secs=$(( $time - 3600*$hour - 60*$mins ))

echo Time used for LLVM/Clang build: $(printf "%02d:%02d:%02d" $hour $mins $secs)
