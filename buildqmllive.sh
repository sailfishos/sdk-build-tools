#!/bin/bash
#
# Builds Qt QmlLive and optionally uploads it to a server
#
# Copyright (C) 2016 Jolla Ltd.
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

OPT_UPLOAD_HOST=$DEF_UPLOAD_HOST
OPT_UPLOAD_USER=$DEF_UPLOAD_USER
OPT_UPLOAD_PATH=$DEF_UPLOAD_PATH

OPT_QTDIR=$DEF_QT_DYN_BUILD_DIR
OPT_QMLLIVE_SRC_DIR=$DEF_QMLLIVE_SRC_DIR
QMLLIVE_BUILD_DIR=$DEF_QMLLIVE_BUILD_DIR
QMLLIVE_INSTALL_ROOT=$DEF_QMLLIVE_INSTALL_ROOT
OPT_ICU_PATH=$DEF_ICU_INSTALL_DIR
OPT_VARIANT=$DEF_VARIANT

fail() {
    echo "FAIL: $@"
    exit 1
}

usage() {
    cat <<EOF

Build Qt QmlLive and optionally upload the result to a server

Usage:
   $(basename $0) [OPTION]

Current values are displayed in [ ]s.

Options:
   -qmllive | --qmllive-src <DIR>  Qt QmlLive source directory [$OPT_QMLLIVE_SRC_DIR]
   -qt      | --qt-dir <DIR>       Qt (install) directory [$OPT_QTDIR]
   -v       | --variant <STRING>   Use <STRING> as the build variant [$OPT_VARIANT]
   -r       | --revision <STRING>  Use <STRING> as the build revision [git sha]
   -vd      | --version-desc <STRING>  Use <STRING> as a version description (appears
                                   in braces after Qt QmlLive version in About dialog)
            | --quick              Do not run configure or clean build dir
   -u       | --upload <DIR>       upload local build result to [$OPT_UPLOAD_HOST] as user [$OPT_UPLOAD_USER]
                                   the uploaded build will be copied to [$OPT_UPLOAD_PATH/<DIR>]
                                   the upload directory will be created if it is not there
   -uh      | --uhost <HOST>       override default upload host
   -up      | --upath <PATH>       override default upload path
   -uu      | --uuser <USER>       override default upload user
   -y       | --non-interactive    answer yes to all questions presented by the script
   -h       | --help               this help

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
    -vd | --version-desc ) shift
        OPT_VERSION_DESC=$1; shift
        ;;
    -qmllive | --qmllive-src ) shift
        OPT_QMLLIVE_SRC_DIR=$1; shift
        QMLLIVE_BUILD_DIR=$OPT_QMLLIVE_SRC_DIR$DEF_QMLLIVE_BUILD_SUFFIX
        QMLLIVE_INSTALL_ROOT=$OPT_QMLLIVE_SRC_DIR$DEF_QMLLIVE_INSTALL_SUFFIX
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

if [[ ! -d $OPT_QMLLIVE_SRC_DIR ]]; then
    fail "Qt QmlLive source directory [$OPT_QMLLIVE_SRC_DIR] not found"
fi

if [[ ! -d $QMLLIVE_INSTALL_ROOT ]]; then
    mkdir -p $QMLLIVE_INSTALL_ROOT
fi

# the default revision is the git hash of Qt QmlLive src directory
if [[ -z $OPT_REVISION ]]; then
    OPT_REVISION=$(git --git-dir=$OPT_QMLLIVE_SRC_DIR/.git rev-parse --short HEAD 2>/dev/null)
fi

if [[ -z $OPT_REVISION ]]; then
    OPT_REVISION="unknown"
fi

# summary
echo "Summary of chosen actions:"
cat <<EOF
  Qt QmlLive variant [$OPT_VARIANT] revision [$OPT_REVISION]
   - Qt QmlLive source directory [$OPT_QMLLIVE_SRC_DIR]
   - Qt QmlLive build directory [$QMLLIVE_BUILD_DIR]
   - Qt QmlLive installation directory [$QMLLIVE_INSTALL_ROOT]
   - Qt directory [$OPT_QTDIR]
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

setup_unix_qmllive_ccache() {
    # This only needs to be done on OSX at the moment as OSX QMake
    # just plain refuses to obey any command to set the compiler from
    # the outside. Not future proof either, as QMake's internal files
    # are not guaranteed to be stable.
    if [ -f /Users/builder/src/ccache-3.2.2/ccache ]; then
        sed -e 's|macosx.QMAKE_CXX =|macosx.QMAKE_CXX = /Users/builder/src/ccache-3.2.2/ccache |' -i '' .qmake.stash
    fi
}

build_unix_qmllive() {
    export INSTALL_ROOT=$QMLLIVE_INSTALL_ROOT
    export QTDIR=$OPT_QTDIR/qtbase
    export PATH=$QTDIR/bin:$PATH
    export INSTALLER_ARCHIVE=$SAILFISH_QMLLIVE_BASENAME$(build_arch).7z
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$OPT_ICU_PATH/lib

    # clear build workspace
    [[ $OPT_QUICK ]] || rm -rf $QMLLIVE_BUILD_DIR
    mkdir -p $QMLLIVE_BUILD_DIR
    pushd    $QMLLIVE_BUILD_DIR

    if ! [[ $OPT_QUICK ]]; then
        $QTDIR/bin/qmake $OPT_QMLLIVE_SRC_DIR/qmllive.pro -r CONFIG+=release \
                         QMLLIVE_SETTINGS_VARIANT="$OPT_VARIANT" QMLLIVE_REVISION="$OPT_REVISION" \
                         QMLLIVE_VERSION_EXTRA="$OPT_VERSION_DESC" \
                         PREFIX=/ EXAMPLES_PREFIX=/qmllive-examples CONFIG+=no_testcase_installs
    fi

    setup_unix_qmllive_ccache

    make -j$(getconf _NPROCESSORS_ONLN)

    rm -rf $QMLLIVE_INSTALL_ROOT/*
    make install

    # Remove development files
    if [[ $UNAME_SYSTEM == "Darwin" ]]; then
        rm -rf $QMLLIVE_INSTALL_ROOT/include $QMLLIVE_INSTALL_ROOT/lib/pkgconfig \
            $QMLLIVE_INSTALL_ROOT/lib/libqmllive.dylib
    else
        rm -rf $QMLLIVE_INSTALL_ROOT/include $QMLLIVE_INSTALL_ROOT/lib/pkgconfig \
            $QMLLIVE_INSTALL_ROOT/lib/libqmllive.so
    fi

    # Adjust rpath
    if [[ $UNAME_SYSTEM == "Darwin" ]]; then
        install_name_tool -delete_rpath "$QMLLIVE_BUILD_DIR/lib" \
                          -add_rpath '@executable_path/../lib' \
                          -add_rpath '@executable_path/Qt Creator.app/Contents/Frameworks' \
                          $QMLLIVE_INSTALL_ROOT/bin/qmllivebench
        install_name_tool -delete_rpath "$QMLLIVE_BUILD_DIR/lib" \
                          -add_rpath '@executable_path/../lib' \
                          -add_rpath '@executable_path/Qt Creator.app/Contents/Frameworks' \
                          $QMLLIVE_INSTALL_ROOT/bin/qmlliveruntime
        install_name_tool -delete_rpath "$OPT_QTDIR/qtbase/lib" \
                          -add_rpath '@executable_path/../../bin/Qt Creator.app/Contents/Frameworks' \
                          $QMLLIVE_INSTALL_ROOT/libexec/qmllive/previewGenerator
    else
        RPATH='INSTALL_ROOT/lib:INSTALL_ROOT/lib/Qt/lib:INSTALL_ROOT/lib/qtcreator'
        chrpath --replace "${RPATH//INSTALL_ROOT/\$ORIGIN/..}" $QMLLIVE_INSTALL_ROOT/bin/*
        chrpath --replace "${RPATH//INSTALL_ROOT/\$ORIGIN/../..}" $QMLLIVE_INSTALL_ROOT/libexec/qmllive/*
    fi

    popd
}

build_windows_qmllive() {
    # clear build workspace
    [[ $OPT_QUICK ]] || rm -rf $QMLLIVE_BUILD_DIR
    mkdir -p $QMLLIVE_BUILD_DIR
    pushd    $QMLLIVE_BUILD_DIR

    # no more errors allowed
    set -e
    # create the build script for windows
    cat <<EOF > build-windows.bat
@echo off

if DEFINED ProgramFiles(x86) (
    set "_programs=%ProgramFiles(x86)%"
    set _systemdir=%windir%\system
)
if Not DEFINED ProgramFiles(x86) (
    set _programs=%ProgramFiles%
    set _systemdir=%windir%\system32
)

set INSTALL_ROOT=$(win_path $QMLLIVE_INSTALL_ROOT)
set QTDIR=$(win_path $OPT_QTDIR)\qtbase
set QMAKESPEC=win32-msvc$DEF_MSVC_VER
set PATH=%PATH%;%_programs%\7-zip;%QTDIR%\bin;$(win_path $DEF_PREFIX)\invariant\bin;c:\python27;$(win_path $OPT_ICU_PATH)\bin
set INSTALLER_ARCHIVE=$SAILFISH_QMLLIVE_BASENAME$(build_arch).7z

call rmdir /s /q $(win_path $QMLLIVE_INSTALL_ROOT)

call "%_programs%\microsoft visual studio 12.0\vc\vcvarsall.bat"

call %QTDIR%\bin\qmake $(win_path $OPT_QMLLIVE_SRC_DIR)\qmllive.pro -r CONFIG+=release ^
                       QMLLIVE_SETTINGS_VARIANT="$OPT_VARIANT" QMLLIVE_REVISION="$OPT_REVISION" ^
                       QMLLIVE_VERSION_EXTRA="$OPT_VERSION_DESC" ^
                       PREFIX=\. EXAMPLES_PREFIX=\qmllive-examples CONFIG+=no_testcase_installs || exit 1

call jom || exit 1
call nmake install || exit 1
EOF

    # execute the bat
    cmd //c build-windows.bat

    # Remove development files
    rm -rf $QMLLIVE_INSTALL_ROOT/include $QMLLIVE_INSTALL_ROOT/bin/qmllive0.lib

    popd
}

# if any step below fails, exit
set -e

# record start time
BUILD_START=$(date +%s)

if [[ $(build_arch) == "windows" ]]; then
    build_windows_qmllive
else
    build_unix_qmllive
fi

# create package
SAILFISH_QMLLIVE_PACKAGE="sailfish-qmllive-$(build_arch).7z"
rm -f $QMLLIVE_BUILD_DIR/$SAILFISH_QMLLIVE_PACKAGE
7z a $QMLLIVE_BUILD_DIR/$SAILFISH_QMLLIVE_PACKAGE $QMLLIVE_INSTALL_ROOT/*

# record end time
BUILD_END=$(date +%s)

time=$(( BUILD_END - BUILD_START ))
hour=$(( $time / 3600 ))
mins=$(( $time / 60 - 60*$hour ))
secs=$(( $time - 3600*$hour - 60*$mins ))

echo Time used for Qt QmlLive build: $(printf "%02d:%02d:%02d" $hour $mins $secs)

if  [[ -n "$OPT_UPLOAD" ]]; then
    # create upload dir
    ssh $OPT_UPLOAD_USER@$OPT_UPLOAD_HOST mkdir -p $OPT_UPLOAD_PATH/$OPT_UL_DIR/$(build_arch)

    echo "Uploading $SAILFISH_QMLLIVE_PACKAGE ..."
    scp $QMLLIVE_BUILD_DIR/$SAILFISH_QMLLIVE_PACKAGE $OPT_UPLOAD_USER@$OPT_UPLOAD_HOST:$OPT_UPLOAD_PATH/$OPT_UL_DIR/$(build_arch)/
fi

# For Emacs:
# Local Variables:
# indent-tabs-mode:nil
# tab-width:4
# End:
# For VIM:
# vim:set softtabstop=4 shiftwidth=4 tabstop=4 expandtab:
