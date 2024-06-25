#!/bin/bash
#
# Builds installer framework and optionally uploads it to a server
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

. $(dirname $0)/defaults.sh
. $(dirname $0)/utils.sh

OPT_UPLOAD_HOST=$DEF_UPLOAD_HOST
OPT_UPLOAD_USER=$DEF_UPLOAD_USER
OPT_UPLOAD_PATH=$DEF_UPLOAD_PATH

OPT_QTDIR=$DEF_QT_STATIC_BUILD_DIR
OPT_IFW_SRC_DIR=$DEF_IFW_SRC_DIR
IFW_BUILD_DIR=$DEF_IFW_BUILD_DIR

fail() {
    echo "FAIL: $@"
    exit 1
}

usage() {
    cat <<EOF

Build Installer Framework and optionally upload the result to a server

Usage:
   $(basename $0) [OPTION]

Current values are displayed in [ ]s.

Options:
   -ifw | --ifw-src <DIR>      Installer FW source directory [$OPT_IFW_SRC_DIR]
   -qt  | --qt-dir <DIR>       Static Qt (install) directory [$OPT_QTDIR]
   -u   | --upload <DIR>       upload local build result to [$OPT_UPLOAD_HOST] as user [$OPT_UPLOAD_USER]
                               the uploaded build will be copied to [$OPT_UPLOAD_PATH/<DIR>]
                               the upload directory will be created if it is not there
   -uh  | --uhost <HOST>       override default upload host
   -up  | --upath <PATH>       override default upload path
   -uu  | --uuser <USER>       override default upload user
   -y   | --non-interactive    answer yes to all questions presented by the script
   -h   | --help               this help

EOF

    # exit if any argument is given
    [[ -n "$1" ]] && exit 1
}

# handle commandline options
while [[ ${1:-} ]]; do
    case "$1" in
	-ifw | --ifw-src ) shift
	    OPT_IFW_SRC_DIR=$1; shift
        IFW_BUILD_DIR=$OPT_IFW_SRC_DIR$DEF_IFW_BUILD_SUFFIX
	    ;;
	-qt | --qt-dir ) shift
	    OPT_QTDIR=$1; shift
	    ;;
	-u | --upload ) shift
	    OPT_UPLOAD=1
	    OPT_UL_DIR=$1; shift
	    if [[ -z $OPT_UL_DIR ]]; then
		fail "upload option requires a directory name"
	    fi
	    ;;
	-uh | --uhost ) shift;
	    OPT_UPLOAD_HOST=$1; shift
	    ;;
	-up | --upath ) shift;
	    OPT_UPLOAD_PATH=$1; shift
	    ;;
	-uu | --uuser ) shift;
	    OPT_UPLOAD_USER=$1; shift
	    ;;
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

if [[ ! -d $OPT_QTDIR ]]; then
    fail "Qt directory [$OPT_QTDIR] not found"
fi

if [[ ! -d $OPT_IFW_SRC_DIR ]]; then
    fail "Installer framework source directory [$OPT_IFW_SRC_DIR] not found"
fi

# summary
cat <<EOF
Summary of chosen actions:
 1) Build Installer Framework
    - Installer Framework source directory [$OPT_IFW_SRC_DIR]
    - Installer Framework build directory [$IFW_BUILD_DIR]
    - Static Qt directory [$OPT_QTDIR]
EOF

if [[ -n $OPT_UPLOAD ]]; then
    echo " 2) Upload build result as user [$OPT_UPLOAD_USER] to [$OPT_UPLOAD_HOST:$OPT_UPLOAD_PATH/$OPT_UL_DIR]"
else
    echo " 2) Do NOT upload build result anywhere"
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

build_unix() {
    export QTDIR=$OPT_QTDIR
    export PATH=$QTDIR/qtbase/bin:$PATH

    rm -rf   $IFW_BUILD_DIR
    mkdir -p $IFW_BUILD_DIR
    pushd    $IFW_BUILD_DIR

    $QTDIR/qtbase/bin/qmake -r $OPT_IFW_SRC_DIR/installerfw.pro

    make -j$(nproc)
    popd
}

build_windows() {

    rm -rf   $IFW_BUILD_DIR
    mkdir -p $IFW_BUILD_DIR
    pushd    $IFW_BUILD_DIR

    # create the build script for windows
    cat <<EOF > build-windows.bat
@echo off

if DEFINED ProgramFiles(x86) set _programs=%ProgramFiles(x86)%
if Not DEFINED ProgramFiles(x86) set _programs=%ProgramFiles%

set QTDIR=$(win_path $OPT_QTDIR)
set QMAKESPEC=$DEF_MSVC_SPEC
set PATH=$(win_path $DEF_PREFIX)\invariant\bin;%PATH%

call "%_programs%\Microsoft Visual Studio\\$DEF_MSVC_VER\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64

call %QTDIR%\qtbase\bin\qmake -r $(win_path $OPT_IFW_SRC_DIR)\installerfw.pro || exit 1
call jom || exit 1
EOF

    # execute the bat
    cmd //c build-windows.bat

    popd
}

# if any step below fails, exit
set -e

# record start time
BUILD_START=$(date +%s)

if [[ $UNAME_SYSTEM == "Linux" ]] || [[ $UNAME_SYSTEM == "Darwin" ]]; then
    build_unix
else
    build_windows
fi

if [[ $UNAME_SYSTEM == "Linux" ]]; then
    if [[ $UNAME_ARCH == "x86_64" ]]; then
	BUILD_ARCH="linux-64"
    else
	BUILD_ARCH="linux-32"
    fi
elif [[ $UNAME_SYSTEM == "Darwin" ]]; then
    BUILD_ARCH="mac"
else
    BUILD_ARCH="windows"
fi

pushd $IFW_BUILD_DIR

# install results
mkdir -p ifw
cp -a bin ifw
7z a -mx=9 $DEF_IFW_PACKAGE_NAME ifw

# record end time
BUILD_END=$(date +%s)

time=$(( BUILD_END - BUILD_START ))
hour=$(( $time / 3600 ))
mins=$(( $time / 60 - 60*$hour ))
secs=$(( $time - 3600*$hour - 60*$mins ))

echo Time used for IFW build: $(printf "%02d:%02d:%02d" $hour $mins $secs)

if  [[ -n "$OPT_UPLOAD" ]]; then
    echo "Uploading $IFW_PACKAGE_NAME ..."
    # create upload dir
    ssh $OPT_UPLOAD_USER@$OPT_UPLOAD_HOST mkdir -p $OPT_UPLOAD_PATH/$OPT_UL_DIR/$BUILD_ARCH
    scp $DEF_IFW_PACKAGE_NAME $OPT_UPLOAD_USER@$OPT_UPLOAD_HOST:$OPT_UPLOAD_PATH/$OPT_UL_DIR/$BUILD_ARCH/
fi

popd

# For Emacs:
# Local Variables:
# indent-tabs-mode:nil
# tab-width:8
# sh-basic-offset:4
# End:
# For VIM:
# vim:set softtabstop=4 shiftwidth=4 tabstop=8 expandtab:
