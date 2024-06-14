#!/bin/bash
#
# Builds Qt Linguist and optionally uploads it to a server
#
# Copyright (C) 2018 Jolla Ltd.
# Contact: Jarkko Lehtoranta <jarkko.lehtoranta@jolla.com>
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

OPT_UPLOAD_HOST=$DEF_UPLOAD_HOST
OPT_UPLOAD_USER=$DEF_UPLOAD_USER
OPT_UPLOAD_PATH=$DEF_UPLOAD_PATH

OPT_QTDIR=$DEF_QT_DYN_BUILD_DIR
LINGUIST_INSTALL_ROOT=$DEF_LINGUIST_INSTALL_ROOT

fail() {
    echo "FAIL: $@"
    exit 1
}

usage() {
    cat <<EOF

Build Qt Linguist and optionally upload the result to a server

Usage:
   $(basename $0) [OPTION]

Current values are displayed in [ ]s.

Options:
   -ling    | --linguist-install <DIR>  Qt Linguist install directory [$LINGUIST_INSTALL_ROOT]
   -qt      | --qt-dir <DIR>            Qt (install) directory [$OPT_QTDIR]
   -u       | --upload <DIR>            upload local build result to [$OPT_UPLOAD_HOST] as user [$OPT_UPLOAD_USER]
                                        the uploaded build will be copied to [$OPT_UPLOAD_PATH/<DIR>]
                                        the upload directory will be created if it is not there
   -uh      | --uhost <HOST>            override default upload host
   -up      | --upath <PATH>            override default upload path
   -uu      | --uuser <USER>            override default upload user
   -y       | --non-interactive         answer yes to all questions presented by the script
   -h       | --help                    this help

EOF

    # exit if any argument is given
    [[ -n "$1" ]] && exit 1
}

# handle commandline options
while [[ ${1:-} ]]; do
    case "$1" in
    -ling | --linguist-install ) shift
        LINGUIST_INSTALL_ROOT=$1; shift
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

if [[ ! -d $LINGUIST_INSTALL_ROOT ]]; then
    mkdir -p $LINGUIST_INSTALL_ROOT
fi

# summary
echo "Summary of chosen actions:"
cat <<EOF
  Qt Linguist
   - Qt directory [$OPT_QTDIR]
   - Qt Linguist installation directory [$LINGUIST_INSTALL_ROOT]
EOF

if [[ -n $OPT_UPLOAD ]]; then
    echo " Upload build result as user [$OPT_UPLOAD_USER] to [$OPT_UPLOAD_HOST:$OPT_UPLOAD_PATH/$OPT_UL_DIR]"
else
    echo " Do NOT upload build result anywhere"
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
    elif [[ $UNAME_SYSTEM == "Darwin" ]]; then
        echo "mac"
    else
        echo "windows"
    fi
}

build_unix_linguist() {
    export INSTALL_ROOT=$LINGUIST_INSTALL_ROOT
    export QTDIR=$OPT_QTDIR/qtbase
    export PATH=$QTDIR/bin:$PATH
    export INSTALLER_ARCHIVE=$SAILFISH_LINGUIST_BASENAME$(build_arch).7z
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$OPT_ICU_PATH/lib

    # clear build workspace
    rm -rf $LINGUIST_INSTALL_ROOT/*
    pushd    $LINGUIST_INSTALL_ROOT

    mkdir bin

    # Copy Linguist binary from the Qt build directory
    if [[ $UNAME_SYSTEM == "Darwin" ]]; then
        cp -r $OPT_QTDIR/qtbase/bin/Linguist.app bin/
    else
        cp $OPT_QTDIR/qtbase/bin/linguist bin/
    fi

    # Adjust rpath
    if [[ $UNAME_SYSTEM == "Darwin" ]]; then
        install_name_tool -delete_rpath "$QTDIR/lib" \
                          -add_rpath '@executable_path/../../../../lib' \
                          -add_rpath '@executable_path/../../../Qt Creator.app/Contents/Frameworks' \
                          "$LINGUIST_INSTALL_ROOT/bin/Linguist.app/Contents/MacOS/Linguist"
        read -d '' -r QT_CONF_TEMPLATE <<'EOF' || true
# Based on Qt\ Creator.app/Contents/Resources/qt.conf
[Paths]
Prefix = %sQt Creator.app/Contents
Imports = Imports/qtquick1
Qml2Imports = Imports/qtquick2
Plugins = PlugIns
EOF
        printf "$QT_CONF_TEMPLATE" '../../' > "$LINGUIST_INSTALL_ROOT/bin/Linguist.app/Contents/Resources/qt.conf"
    else
        RPATH='INSTALL_ROOT/lib:INSTALL_ROOT/lib/Qt/lib:INSTALL_ROOT/lib/qtcreator'
        find $LINGUIST_INSTALL_ROOT/bin/* -maxdepth 0 -type f | xargs -n1 patchelf --remove-rpath
        find $LINGUIST_INSTALL_ROOT/bin/* -maxdepth 0 -type f | xargs -n1 patchelf --force-rpath --set-rpath "${RPATH//INSTALL_ROOT/\$ORIGIN/..}"
    fi

    popd
}

build_windows_linguist() {
    # clear build workspace
    rm -rf $LINGUIST_INSTALL_ROOT/*
    pushd    $LINGUIST_INSTALL_ROOT

    mkdir bin

    # no more errors allowed
    set -e

    # Copy Linguist binary from the Qt build directory
    cp $OPT_QTDIR/qtbase/bin/linguist.exe bin/

    popd
}

# if any step below fails, exit
set -e

# record start time
BUILD_START=$(date +%s)

if [[ $(build_arch) == "windows" ]]; then
    build_windows_linguist
else
    build_unix_linguist
fi

# create package
SAILFISH_LINGUIST_PACKAGE="sailfish-linguist-$(build_arch).7z"
rm -f $LINGUIST_INSTALL_ROOT/$SAILFISH_LINGUIST_PACKAGE
7z a $LINGUIST_INSTALL_ROOT/$SAILFISH_LINGUIST_PACKAGE $LINGUIST_INSTALL_ROOT/*

# record end time
BUILD_END=$(date +%s)

time=$(( BUILD_END - BUILD_START ))
hour=$(( $time / 3600 ))
mins=$(( $time / 60 - 60*$hour ))
secs=$(( $time - 3600*$hour - 60*$mins ))

echo Time used for Qt Linguist build: $(printf "%02d:%02d:%02d" $hour $mins $secs)

if  [[ -n "$OPT_UPLOAD" ]]; then
    # create upload dir
    ssh $OPT_UPLOAD_USER@$OPT_UPLOAD_HOST mkdir -p $OPT_UPLOAD_PATH/$OPT_UL_DIR/$(build_arch)

    echo "Uploading $SAILFISH_LINGUIST_PACKAGE ..."
    scp $LINGUIST_INSTALL_ROOT/$SAILFISH_LINGUIST_PACKAGE $OPT_UPLOAD_USER@$OPT_UPLOAD_HOST:$OPT_UPLOAD_PATH/$OPT_UL_DIR/$(build_arch)/
fi

# For Emacs:
# Local Variables:
# indent-tabs-mode:nil
# tab-width:8
# sh-basic-offset:4
# End:
# For VIM:
# vim:set softtabstop=4 shiftwidth=4 tabstop=8 expandtab:
