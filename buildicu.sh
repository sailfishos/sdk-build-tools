#!/bin/bash
#
# This script build ICU library into subdirectories in the current dir.
#
# ICU sources must be found from the current user's home directory
# $HOME/invariant/icu.
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

UNAME_SYSTEM=$(uname -s)
UNAME_ARCH=$(uname -m)

BASEDIR=$HOME/invariant
SRCDIR_ICU=$BASEDIR/icu
BUILD_DIR=$BASEDIR/icu-build
INSTALL_DIR=$BASEDIR/icu-install

configure_icu() {
    $SRCDIR_ICU/source/runConfigureICU Linux --disable-draft --disable-extras --disable-debug --disable-icuio --disable-layout --disable-tests --disable-samples --enable-release --prefix=$INSTALL_DIR
}

build_icu() {
    rm -rf   $BUILD_DIR
    mkdir -p $BUILD_DIR
    pushd    $BUILD_DIR
    configure_icu
    make -j$(getconf _NPROCESSORS_ONLN)
    make install
    popd
}

fail() {
    echo "FAIL: $@"
    exit 1
}

usage() {
    cat <<EOF
Build ICU library

Required directories:
 $BASEDIR
 $SRCDIR_ICU

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

echo "Using sources from [$SRCDIR_ICU]"

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

if [[ ! -d $BASEDIR ]]; then
    fail "directory [$BASEDIR] does not exist"
fi

if [[ ! -d $SRCDIR_ICU ]]; then
    fail "directory [$SRCDIR_ICU] does not exist"
fi

pushd $BASEDIR || exit 1

# stop in case of errors
set -e

# record start time
BUILD_START=$(date +%s)

if [[ $UNAME_SYSTEM == "Linux" ]]; then
    build_icu
else
    echo Windows or OSX builds are not yet supported.
    exit 0
fi
# record end time
BUILD_END=$(date +%s)

popd

time=$(( BUILD_END - BUILD_START ))
hour=$(( $time / 3600 ))
mins=$(( $time / 60 - 60*$hour ))
secs=$(( $time - 3600*$hour - 60*$mins ))

echo Time used for ICU build: $(printf "%02d:%02d:%02d" $hour $mins $secs)
