#!/bin/bash
#
# Builds Qt Creator 3
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

UNAME_SYSTEM=$(uname -s)
UNAME_ARCH=$(uname -m)

OPT_QTDIR=$HOME/invariant/qt-everywhere-opensource-src-5.2.1-build/qtbase
OPT_QTC_SRC=$HOME/src/sailfish-qtcreator3/sailfish-qtcreator3
OPT_INSTALL_ROOT=$HOME/build/qtc3-install

QTC_BUILD_DIR=qtc3-build

OPT_VARIANT="SailfishBeta1"

fail() {
    echo "FAIL: $@"
    exit 1
}

usage() {
    cat <<EOF

Build Qt Creator 3

Usage:
   $(basename $0) [OPTION]

Current values are displayed in [ ]s.

Options:
   -qtc | --qtc-src <DIR>       Qt Creator source directory [$OPT_QTC_SRC]
   -qtcb| --qtc-build <DIR>     Qt Creator build directory (relative) [$QTC_BUILD_DIR]
   -qt  | --qt-dir <DIR>        Qt (install) directory [$OPT_QTDIR]
   -di  | --do-not-install      Don't run make install
   -i   | --install <DIR>       Qt Creator install directory [$OPT_INSTALL_ROOT]
   -v   | --variant <STRING>    Use <STRING> as the build variant [$OPT_VARIANT]
   -r   | --revision <STRING>   Use <STRING> as the build revision [git sha]
   -re  | --revextra <STRING>   Use <STRING> as a revision suffix
   -d   | --docs                Build Qt Creator documentation
   -g   | --gdb                 Build also gdb
   -go  | --gdb-only            Build only gdb
   -gd  | --gdb-download <URL>  Use <URL> to download gdb build deps
   -k   | --keep-template       Keep the Sailfish template code in the package
        | --quick               Do not run configure or clean build dir
   -y   | --non-interactive     answer yes to all questions presented by the script
   -h   | --help                this help

EOF

    # exit if any argument is given
    [[ -n "$1" ]] && exit 1
}

# handle commandline options
while [[ ${1:-} ]]; do
    case "$1" in
	-v | --variant ) shift
	    OPT_VARIANT=$1; shift
	    ;;
	-r | --revision ) shift
	    OPT_REVISION=$1; shift
	    ;;
	-re | --revextra ) shift
	    OPT_REV_EXTRA=$1; shift
	    ;;
	-qtc | --qtc-src ) shift
	    OPT_QTC_SRC=$1; shift
	    ;;
    -qtcb | --qtc-build ) shift
        QTC_BUILD_DIR=$1; shift
        ;;
	-qt | --qt-dir ) shift
	    OPT_QTDIR=$1; shift
	    ;;
    -di | --do-not-install ) shift
        OPT_DO_NOT_INSTALL=1; shift
        ;;
	-i | --install ) shift
	    OPT_INSTALL_ROOT=$1; shift
	    ;;
	-d | --docs ) shift
	    OPT_DOCUMENTATION=1
	    ;;
	-g | --gdb ) shift
	    OPT_GDB=1
	    ;;
	-go | --gdb-only ) shift
	    OPT_GDB=1
	    OPT_GDB_ONLY=1
	    ;;
	-gd | --gdb-download ) shift
	    OPT_GDB_URL=$1; shift
	    if [[ -z $OPT_GDB_URL ]]; then
		fail "gdb download option requires a URL"
	    fi
	    ;;
	-k | --keep-template ) shift
	    OPT_KEEP_TEMPLATE=1
	    ;;
	-y | --non-interactive ) shift
	    OPT_YES=1
	    ;;
	--quick ) shift
	    OPT_QUICK=1
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

if [[ ! -d $OPT_QTC_SRC ]]; then
    fail "Qt Creator source directory [$OPT_QTC_SRC] not found"
fi

if [[ ! -d $OPT_INSTALL_ROOT ]]; then
    mkdir -p $OPT_INSTALL_ROOT
fi

# the default revision is the git hash of Qt Creator src directory
OPT_REVISION=$(git --git-dir=$OPT_QTC_SRC/.git rev-parse --short HEAD 2>/dev/null)

if [[ -z $OPT_REVISION ]]; then
    OPT_REVISION="unknown"
fi

if [[ -n $OPT_REV_EXTRA ]]; then
    OPT_REVISION=$OPT_REVISION$OPT_REV_EXTRA
fi

# summary
echo "Summary of chosen actions:"
cat <<EOF
  QT Creator variant [$OPT_VARIANT] revision [$OPT_REVISION]
   - Use [$PWD/$QTC_BUILD_DIR] as the build directory
   - Qt Creator source directory [$OPT_QTC_SRC]
   - Qt directory [$OPT_QTDIR]
EOF
if [[ -z $OPT_GDB_ONLY ]]; then
    echo " 1) Build Qt Creator"
else
    echo " 1) Do NOT build Qt Creator"
fi
if [[ -n $OPT_DO_NOT_INSTALL ]]; then
    echo " 2) Do NOT install Qt Creator"
else
    echo " 2) Install Qt Creator to [$OPT_INSTALL_ROOT]"
fi

if [[ -n $OPT_DOCUMENTATION ]] && [[ -z $OPT_GDB_ONLY ]]; then
    echo " 3) Build documentation"
else
    echo " 3) Do NOT build documentation"
fi

if [[ -n $OPT_GDB ]]; then
    echo " 4) Build GDB"
    [[ -n $OPT_GDB_URL ]] && echo "    - Download build deps from [$OPT_GDB_URL]"
else
    echo " 4) Do NOT build GDB"
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

build_arch() {
    if [[ $UNAME_SYSTEM == "Linux" ]]; then
	if [[ $UNAME_ARCH == "x86_64" ]]; then
	    echo "linux-64"
	else
	    echo "linux-32"
	fi
    fi
}

build_unix_gdb() {
    if [[ -n $OPT_GDB ]]; then
	rm -rf   gdb-build
	mkdir -p gdb-build
	pushd    gdb-build

	if [[ $UNAME_SYSTEM == "Linux" ]]; then
	    GDB_MAKEFILE=Makefile.linux
	else
	    GDB_MAKEFILE=Makefile.osx
	fi

	local downloads
	if [[ -n $OPT_GDB_URL ]]; then
	    downloads="DOWNLOAD_URL=$OPT_GDB_URL"
	fi

	make -f $OPT_QTC_SRC/dist/gdb/$GDB_MAKEFILE \
	    PATCHDIR=$OPT_QTC_SRC/dist/gdb/patches $downloads

	popd
    fi
}

build_unix_qtc() {
    if [[ -z $OPT_GDB_ONLY ]]; then
	export INSTALL_ROOT=$OPT_INSTALL_ROOT
	export QTDIR=$OPT_QTDIR
	export QT_PRIVATE_HEADERS=$QTDIR/include
	export PATH=$QTDIR/bin:$PATH

	# clear build workspace
	[[ $OPT_QUICK ]] || rm -rf $QTC_BUILD_DIR
	mkdir -p $QTC_BUILD_DIR
	pushd    $QTC_BUILD_DIR

	[[ $OPT_QUICK ]] || $QTDIR/bin/qmake $OPT_QTC_SRC/qtcreator.pro -r CONFIG+=debug -after "DEFINES+=IDE_REVISION=$OPT_REVISION IDE_COPY_SETTINGS_FROM_VARIANT=. IDE_SETTINGSVARIANT=$OPT_VARIANT" QTC_PREFIX=

	make -j$(getconf _NPROCESSORS_ONLN)

	rm -rf $OPT_INSTALL_ROOT/*
	if [[ -z $OPT_DO_NOT_INSTALL && $UNAME_SYSTEM == "Linux" ]]; then
	    make install
	    make deployqt
	fi

	if [[ -n $OPT_DOCUMENTATION ]]; then
	    make docs
        if [[ -z $OPT_DO_NOT_INSTALL ]]; then
    	    make install_docs
        fi
	fi

	popd
    fi
}

# if any step below fails, exit
set -e

# record start time
BUILD_START=$(date +%s)

build_unix_qtc
build_unix_gdb

# record end time
BUILD_END=$(date +%s)

time=$(( BUILD_END - BUILD_START ))
hour=$(( $time / 3600 ))
mins=$(( $time / 60 - 60*$hour ))
secs=$(( $time - 3600*$hour - 60*$mins ))

echo Time used for QtC build: $(printf "%02d:%02d:%02d" $hour $mins $secs)

