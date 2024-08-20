#!/bin/bash
#
# This script builds dynamic and static versions of Qt5 into
# subdirectories in the parent directory of the Qt source directory.
#
# Qt5 sources must be found from the current user's home directory. Pass
# --help to display the exact path.
#
# Copyright (C) 2014-2019 Jolla Oy
# Copyright (C) 2020 Open Mobile Platform LLC.
#
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

# common options for unix/windows dynamic build
# the dynamic build is used when building Qt Creator
COMMON_CONFIG_OPTIONS="-release -nomake examples -nomake tests -no-qml-debug -qt-zlib -qt-libpng -qt-libjpeg -qt-pcre -no-sql-mysql -no-sql-odbc -developer-build -confirm-license -opensource -skip qtandroidextras -skip qtconnectivity -skip qtlocation"

LINUX_CONFIG_OPTIONS="-no-eglfs -no-linuxfb -no-kms -bundled-xcb-xinput"

# add these to the COMMON_CONFIG_OPTIONS for static build
# the static build is required to build Qt Installer Framework
COMMON_STATIC_OPTIONS="-static -skip qtxmlpatterns -no-dbus -skip qt3d -skip qtquick3d -skip qtwebengine -skip qtconnectivity"

WEBENGINE_OPTIONS="\
-no-feature-webengine-alsa \
-no-feature-webengine-extensions \
-no-feature-webengine-geolocation \
-no-feature-webengine-kerberos \
-no-feature-webengine-pepper-plugins \
-no-feature-webengine-printing-and-pdf \
-no-feature-webengine-proprietary-codecs \
-no-feature-webengine-pulseaudio \
-no-feature-webengine-spellchecker \
-no-feature-webengine-system-ffmpeg \
-no-feature-webengine-system-libwebp \
-no-feature-webengine-system-libxml2 \
-no-feature-webengine-system-opus \
-no-feature-webengine-webchannel \
-no-feature-webengine-webrtc \
"

build_dynamic_qt_windows() {
    [[ -z $OPT_DYNAMIC ]] && return

    rm -rf   $DEF_QT_DYN_BUILD_DIR
    mkdir -p $DEF_QT_DYN_BUILD_DIR
    pushd    $DEF_QT_DYN_BUILD_DIR

    cat <<EOF > build-dyn.bat
@echo off
if DEFINED ProgramFiles(x86) set _programs=%ProgramFiles(x86)%
if Not DEFINED ProgramFiles(x86) set _programs=%ProgramFiles%

set PATH=$(win_path $DEF_PREFIX)\invariant\bin;$(win_path $DEF_ICU_INSTALL_DIR)\bin64;$(win_path $DEF_QT_SRC_DIR)\gnuwin32\bin;$(win_path $DEF_PREFIX)\invariant\bin;%PATH%
call "%_programs%\Microsoft Visual Studio\\$DEF_MSVC_VER\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64 || exit 1

set MAKE=jom
REM NINJAFLAGS is handled by qtwebengine/src/core/gn_run.pro (at least)
set NINJAFLAGS=-j1
call $(win_path $DEF_QT_SRC_DIR)\configure.bat -make-tool jom $COMMON_CONFIG_OPTIONS -skip qtwebengine -icu -I $(win_path $DEF_ICU_INSTALL_DIR)\include -L $(win_path $DEF_ICU_INSTALL_DIR)\lib64 -opengl dynamic -platform $DEF_MSVC_SPEC -prefix "%CD%/qtbase" || exit 1

call jom /j 1 || exit 1
EOF

    cmd //c build-dyn.bat
    popd
}

configure_static_qt5() {
    if [[ $UNAME_SYSTEM == "Linux" ]]; then
        $DEF_QT_SRC_DIR/configure $COMMON_CONFIG_OPTIONS $LINUX_CONFIG_OPTIONS $COMMON_STATIC_OPTIONS -xcb -xkbcommon -no-gstreamer -no-icu -skip qtsvg -no-warnings-are-errors -no-compile-examples
    else
        $DEF_QT_SRC_DIR/configure $COMMON_CONFIG_OPTIONS $COMMON_STATIC_OPTIONS -no-gstreamer -no-warnings-are-errors
    fi
}

configure_dynamic_qt5() {
    if [[ $UNAME_SYSTEM == "Linux" ]]; then
        $DEF_QT_SRC_DIR/configure $COMMON_CONFIG_OPTIONS $LINUX_CONFIG_OPTIONS $WEBENGINE_OPTIONS -xcb -xkbcommon -no-gstreamer -I $DEF_ICU_INSTALL_DIR/include -L $DEF_ICU_INSTALL_DIR/lib -icu -no-warnings-are-errors -no-compile-examples
    else
        $DEF_QT_SRC_DIR/configure $COMMON_CONFIG_OPTIONS -no-gstreamer
    fi
}

build_dynamic_qt() {
    [[ -z $OPT_DYNAMIC ]] && return

    rm -rf   $DEF_QT_DYN_BUILD_DIR
    mkdir -p $DEF_QT_DYN_BUILD_DIR
    pushd    $DEF_QT_DYN_BUILD_DIR
    # NINJAFLAGS is handled by qtwebengine/src/core/gn_run.pro (at least)
    export NINJAFLAGS=-j$(nproc)
    # qtwebengine assumes python 2 is the default
    if [[ $UNAME_SYSTEM == "Linux" ]]; then
        mkdir select-python-2
        python2=$(which python2)
        ln -s "$python2" select-python-2/python
        export PATH=$PWD/select-python-2:$PATH
    fi
    configure_dynamic_qt5
    make -j$(nproc)
    # no need to make install with -developer-build option
    # make install
    popd
}

build_static_qt_windows() {
    [[ -z $OPT_STATIC ]] && return

    rm -rf   $DEF_QT_STATIC_BUILD_DIR
    mkdir -p $DEF_QT_STATIC_BUILD_DIR
    pushd    $DEF_QT_STATIC_BUILD_DIR

    cat <<EOF > build-dyn.bat
@echo off
if DEFINED ProgramFiles(x86) set _programs=%ProgramFiles(x86)%
if Not DEFINED ProgramFiles(x86) set _programs=%ProgramFiles%

set PATH=$(win_path $DEF_PREFIX)\invariant\bin;$(win_path $DEF_ICU_INSTALL_DIR)\bin64;$(win_path $DEF_QT_SRC_DIR)\gnuwin32\bin;$(win_path $DEF_PREFIX)\invariant\bin;%PATH%
call "%_programs%\Microsoft Visual Studio\\$DEF_MSVC_VER\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64 || exit 1

set MAKE=jom
call $(win_path $DEF_QT_SRC_DIR)\configure.bat -make-tool jom $COMMON_CONFIG_OPTIONS $COMMON_STATIC_OPTIONS -angle -platform $DEF_MSVC_SPEC -static-runtime -prefix "%CD%/qtbase" || exit 1

call jom /j 1 || exit 1
EOF

    cmd //c build-dyn.bat
    popd
}

build_static_qt() {
    [[ -z $OPT_STATIC ]] && return

    rm -rf   $DEF_QT_STATIC_BUILD_DIR
    mkdir -p $DEF_QT_STATIC_BUILD_DIR
    pushd    $DEF_QT_STATIC_BUILD_DIR
    configure_static_qt5
    make -j$(nproc)
    # no need to make install with -developer-build option
    # make install
    popd
}

fail() {
    echo "FAIL: $@"
    exit 1
}

usage() {
    cat <<EOF
Build dynamic and static versions of Qt5

Prerequisites:
 - Qt sources
   [$DEF_QT_SRC_DIR]
 - Build directory for dynamic build (will be created)
   [$DEF_QT_DYN_BUILD_DIR]
 - Build directory for static build (will be created)
   [$DEF_QT_STATIC_BUILD_DIR]

Usage:
   $(basename $0) [OPTION]

Options:
   -d  | --dynamic            build dynamic version (default)
   -s  | --static             build static version
   -y  | --non-interactive    answer yes to all questions presented by the script
   -h  | --help               this help

EOF

    # exit if any argument is given
    [[ -n "$1" ]] && exit 1
}


# handle commandline options
while [[ ${1:-} ]]; do
    case "$1" in
    -d | --dynamic ) shift
        OPT_DYNAMIC=1
        ;;
    -s | --static ) shift
        OPT_STATIC=1
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

if [[ -z $OPT_DYNAMIC ]] && [[ -z $OPT_STATIC ]]; then
    # default: build dynamic only
    OPT_DYNAMIC=1
fi

echo "Using sources from [$DEF_QT_SRC_DIR]"
[[ -n $OPT_DYNAMIC ]] && echo "- Build [dynamic] version of Qt5"
[[ -n $OPT_STATIC ]] && echo "- Build [static] version of Qt5"

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

if [[ ! -d $DEF_QT_SRC_DIR ]]; then
    fail "directory [$DEF_QT_SRC_DIR] does not exist"
fi

# stop in case of errors
set -e


# record start time
BUILD_START=$(date +%s)

if [[ $UNAME_SYSTEM == "Linux" ]] || [[ $UNAME_SYSTEM == "Darwin" ]]; then
    if [[ $UNAME_SYSTEM == "Linux" ]]; then
        export LD_LIBRARY_PATH=$DEF_ICU_INSTALL_DIR/lib
    fi
    build_dynamic_qt
    build_static_qt
else
    build_dynamic_qt_windows
    build_static_qt_windows
fi
# record end time
BUILD_END=$(date +%s)

time=$(( BUILD_END - BUILD_START ))
hour=$(( $time / 3600 ))
mins=$(( $time / 60 - 60*$hour ))
secs=$(( $time - 3600*$hour - 60*$mins ))

echo Time used for Qt5 build: $(printf "%02d:%02d:%02d" $hour $mins $secs)

# For Emacs:
# Local Variables:
# indent-tabs-mode:nil
# tab-width:8
# sh-basic-offset:4
# End:
# For VIM:
# vim:set softtabstop=4 shiftwidth=4 tabstop=8 expandtab:
