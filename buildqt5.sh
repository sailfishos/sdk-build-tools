#!/bin/bash
#
# This script builds dynamic and static versions of Qt5 into
# subdirectories in the parent directory of the Qt source directory.
#
# Qt5 sources must be found from the current user's home directory
# $HOME/invariant/qt-everywhere-opensource-src-5.5.0 or in in case of
# Windows in C:\invariant\qt-everywhere-opensource-src-5.5.0.
#
# To build a version of Qt other than 5.5.0, change the value of the
# QT_SOURCE_PACKAGE variable.
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

QT_SOURCE_PACKAGE=qt-everywhere-opensource-src-5.5.0

if [[ $UNAME_SYSTEM == "Linux" ]] || [[ $UNAME_SYSTEM == "Darwin" ]]; then
    BASEDIR=$HOME/invariant
    SRCDIR_QT=$BASEDIR/$QT_SOURCE_PACKAGE
    # the padding part in the dynamic build directory is necessary in
    # order to accommodate rpath changes at the end of building Qt
    # Creator, which reads Qt resources from this directory.
    DYN_BUILD_DIR=$BASEDIR/$QT_SOURCE_PACKAGE-build
    STATIC_BUILD_DIR=$BASEDIR/$QT_SOURCE_PACKAGE-static-build
    ICU_INSTALL_DIR=$BASEDIR/icu-install
else
    BASEDIR="/c/invariant"
    SRCDIR_QT="$BASEDIR/$QT_SOURCE_PACKAGE"
    DYN_BUILD_DIR="$BASEDIR/$QT_SOURCE_PACKAGE-build-msvc2012"
    STATIC_BUILD_DIR="$BASEDIR/$QT_SOURCE_PACKAGE-static-build-msvc2012"
    ICU_INSTALL_DIR=$BASEDIR/icu
fi

# common options for unix/windows dynamic build
# the dynamic build is used when building Qt Creator
COMMON_CONFIG_OPTIONS="-release -nomake examples -nomake tests -no-qml-debug -qt-zlib -qt-libpng -qt-libjpeg -qt-pcre -no-sql-mysql -no-sql-odbc -developer-build -confirm-license -opensource -skip qtandroidextras"

LINUX_CONFIG_OPTIONS="-no-eglfs -no-linuxfb -no-kms"

# add these to the COMMON_CONFIG_OPTIONS for static build
# the static build is required to build Qt Installer Framework
COMMON_STATIC_OPTIONS="-static -skip qtwebkit -skip qtxmlpatterns -no-dbus -skip qt3d"

build_dynamic_qt_windows() {
    [[ -z $OPT_DYNAMIC ]] && return

    rm -rf   $DYN_BUILD_DIR
    mkdir -p $DYN_BUILD_DIR
    pushd    $DYN_BUILD_DIR

    cat <<EOF > build-dyn.bat
@echo off
if DEFINED ProgramFiles(x86) set _programs=%ProgramFiles(x86)%
if Not DEFINED ProgramFiles(x86) set _programs=%ProgramFiles%

set PATH=c:\windows;c:\windows\system32;%_programs\windows kits\8.0\windows performance toolkit;%_programs%\7-zip;C:\invariant\bin;c:\python27;c:\perl\bin;c:\ruby193\bin;c:\invariant\icu\bin;C:\invariant\\$QT_SOURCE_PACKAGE\gnuwin32\bin;%_programs%\microsoft sdks\typescript\1.0;c:\windows\system32\wbem;c:\windows\system32\windowspowershell\v1.0;c:\invariant\bin
call "%_programs%\microsoft visual studio 12.0\vc\vcvarsall.bat"

set MAKE=jom
call c:\invariant\\$QT_SOURCE_PACKAGE\configure.bat -make-tool jom $COMMON_CONFIG_OPTIONS -icu -I c:\invariant\icu\include -L c:\invariant\icu\lib -angle -platform win32-msvc2012 -prefix

call jom /j 1
EOF

    cmd //c build-dyn.bat
    popd
}

configure_static_qt5() {
    if [[ $UNAME_SYSTEM == "Linux" ]]; then
        $SRCDIR_QT/configure $COMMON_CONFIG_OPTIONS $LINUX_CONFIG_OPTIONS $COMMON_STATIC_OPTIONS -optimized-qmake -qt-xcb -qt-xkbcommon -gtkstyle -no-gstreamer -no-icu -skip qtsvg -no-warnings-are-errors -no-compile-examples
    else
        $SRCDIR_QT/configure $COMMON_CONFIG_OPTIONS $COMMON_STATIC_OPTIONS -optimized-qmake -no-gstreamer -no-warnings-are-errors
    fi
}

configure_dynamic_qt5() {
    # The argument to '-i' is mandatory for compatibility with mac
    sed -i~ '/^[[:space:]]*WEBKIT_CONFIG[[:space:]]*+=.*\<video\>/s/^/#/' \
        $SRCDIR_QT/qtwebkit/Tools/qmake/mkspecs/features/features.prf

    if [[ $UNAME_SYSTEM == "Linux" ]]; then
        $SRCDIR_QT/configure $COMMON_CONFIG_OPTIONS $LINUX_CONFIG_OPTIONS -optimized-qmake -qt-xcb -qt-xkbcommon -gtkstyle -no-gstreamer -I $ICU_INSTALL_DIR/include -L $ICU_INSTALL_DIR/lib -icu -no-warnings-are-errors -no-compile-examples
    else
        $SRCDIR_QT/configure $COMMON_CONFIG_OPTIONS -optimized-qmake -no-gstreamer
    fi
}

build_dynamic_qt() {
    [[ -z $OPT_DYNAMIC ]] && return

    rm -rf   $DYN_BUILD_DIR
    mkdir -p $DYN_BUILD_DIR
    pushd    $DYN_BUILD_DIR
    configure_dynamic_qt5
    make -j$(getconf _NPROCESSORS_ONLN)
    # no need to make install with -developer-build option
    # make install
    popd
}

build_static_qt_windows() {
    [[ -z $OPT_STATIC ]] && return

    rm -rf   $STATIC_BUILD_DIR
    mkdir -p $STATIC_BUILD_DIR
    pushd    $STATIC_BUILD_DIR

    cat <<EOF > build-dyn.bat
@echo off
if DEFINED ProgramFiles(x86) set _programs=%ProgramFiles(x86)%
if Not DEFINED ProgramFiles(x86) set _programs=%ProgramFiles%

set PATH=c:\windows;c:\windows\system32;%_programs\windows kits\8.0\windows performance toolkit;%_programs%\7-zip;C:\invariant\bin;c:\python27;c:\perl\bin;c:\ruby193\bin;c:\invariant\icu\bin;C:\invariant\\$QT_SOURCE_PACKAGE\gnuwin32\bin;%_programs%\microsoft sdks\typescript\1.0;c:\windows\system32\wbem;c:\windows\system32\windowspowershell\v1.0;c:\invariant\bin
call "%_programs%\microsoft visual studio 12.0\vc\vcvarsall.bat"

set MAKE=jom
call c:\invariant\\$QT_SOURCE_PACKAGE\configure.bat -make-tool jom $COMMON_CONFIG_OPTIONS $COMMON_STATIC_OPTIONS -angle -platform win32-msvc2012 -static-runtime -prefix

call jom /j 1
EOF

    cmd //c build-dyn.bat
    popd
}

build_static_qt() {
    [[ -z $OPT_STATIC ]] && return

    rm -rf   $STATIC_BUILD_DIR
    mkdir -p $STATIC_BUILD_DIR
    pushd    $STATIC_BUILD_DIR
    configure_static_qt5
    make -j$(getconf _NPROCESSORS_ONLN)
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

Required directories:
 $BASEDIR
 $SRCDIR_QT

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

echo "Using sources from [$SRCDIR_QT]"
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

if [[ ! -d $BASEDIR ]]; then
    fail "directory [$BASEDIR] does not exist"
fi

if [[ ! -d $SRCDIR_QT ]]; then
    fail "directory [$SRCDIR_QT] does not exist"
fi

pushd $BASEDIR || exit 1

# stop in case of errors
set -e


# record start time
BUILD_START=$(date +%s)

if [[ $UNAME_SYSTEM == "Linux" ]] || [[ $UNAME_SYSTEM == "Darwin" ]]; then
    if [[ $UNAME_SYSTEM == "Linux" ]]; then
        export LD_LIBRARY_PATH=$ICU_INSTALL_DIR/lib
    fi
    build_dynamic_qt
    build_static_qt
else
    build_dynamic_qt_windows
    build_static_qt_windows
fi
# record end time
BUILD_END=$(date +%s)

popd

time=$(( BUILD_END - BUILD_START ))
hour=$(( $time / 3600 ))
mins=$(( $time / 60 - 60*$hour ))
secs=$(( $time - 3600*$hour - 60*$mins ))

echo Time used for Qt5 build: $(printf "%02d:%02d:%02d" $hour $mins $secs)

# For Emacs:
# Local Variables:
# indent-tabs-mode:nil
# tab-width:4
# End:
# For VIM:
# vim:set softtabstop=4 shiftwidth=4 tabstop=4 expandtab:
