#!/bin/bash
#
# This script build dynamic and static versions of Qt4 into
# subdirectories in the current dir.
#
# Qt4 sources must be found from the current user's home directory
# $HOME/invariant/qt or in case of Windows in C:\invariant\qt
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

if [[ $UNAME_SYSTEM == "Linux" ]] || [[ $UNAME_SYSTEM == "Darwin" ]]; then
    BASEDIR=$HOME/invariant
    SRCDIR_QT=$BASEDIR/qt
    # the padding part in the dynamic build directory is necessary in
    # order to accommodate rpath changes at the end of the build
    DYN_BUILD_DIR=$BASEDIR/qt-4.8.5-build_______________padding___________________
    STATIC_BUILD_DIR=$BASEDIR/qt-4.8.5-static-build
else
    BASEDIR="/c/invariant"
    SRCDIR_QT="$BASEDIR/qt"
    DYN_BUILD_DIR="$BASEDIR/build-qt-dynamic"
    STATIC_BUILD_DIR="$BASEDIR/build-qt-static"

    MY_MKSPECDIR=$SRCDIR_QT/mkspecs/win32-msvc2010
fi

# common options for unix/windows dynamic build
# the dynamic build is used when building Qt Creator
COMMON_CONFIG_OPTIONS="-release -confirm-license -opensource -nomake demos -nomake examples -qt-libjpeg -qt-libmng -qt-libpng -qt-libtiff -qt-zlib -no-phonon -no-phonon-backend -no-scripttools -no-multimedia -developer-build"

# add these to the COMMON_CONFIG_OPTIONS for static build
# the static build is required to build Qt Installer Framework
COMMON_STATIC_OPTIONS="-static -no-qt3support -no-webkit -no-xmlpatterns -no-dbus -no-opengl -accessibility -no-declarative"

build_static_qt_windows() {
    rm -rf   $STATIC_BUILD_DIR
    mkdir -p $STATIC_BUILD_DIR
    pushd    $STATIC_BUILD_DIR

    cat <<EOF > build-stat.bat
@echo off
if DEFINED ProgramFiles(x86) set _programs=%ProgramFiles(x86)%
if Not DEFINED ProgramFiles(x86) set _programs=%ProgramFiles%

PATH=%PATH%;c:\invariant\bin

call "%_programs%\Microsoft Visual Studio 10.0\VC\vcvarsall.bat"
call "C:\invariant\qt\configure.exe" $COMMON_CONFIG_OPTIONS $COMMON_STATIC_OPTIONS -platform win32-msvc2010 -prefix

call jom
EOF

    # replace the conf file with the proper one for this build
    cp $MY_MKSPECDIR/qmake.conf.static $MY_MKSPECDIR/qmake.conf
    cmd //c build-stat.bat

    popd
}

build_dynamic_qt_windows() {
    rm -rf   $DYN_BUILD_DIR
    mkdir -p $DYN_BUILD_DIR
    pushd    $DYN_BUILD_DIR

    cat <<EOF > build-dyn.bat
@echo off
if DEFINED ProgramFiles(x86) set _programs=%ProgramFiles(x86)%
if Not DEFINED ProgramFiles(x86) set _programs=%ProgramFiles%

PATH=%PATH%;c:\invariant\bin

call "%_programs%\Microsoft Visual Studio 10.0\VC\vcvarsall.bat"
call "C:\invariant\qt\configure.exe" $COMMON_CONFIG_OPTIONS -platform win32-msvc2010 -prefix
 
call jom
EOF

    # replace the conf file with the proper one for this build
    cp $MY_MKSPECDIR/qmake.conf.dyn $MY_MKSPECDIR/qmake.conf

    cmd //c build-dyn.bat
    popd
}

# Windows needs different options in the mkspec for static and dynamic
# builds.
#
# http://doc-snapshot.qt-project.org/qtifw-master/ifw-getting-started.html
#
# If you are using e.g. the Microsoft Visual Studio 2010 compiler, you
# edit mkspecs\win32-msvc2010\qmake.conf and replace in the CFLAGS
# sections '-MD' with '-MT'. Furthermore you should remove
# 'embed_manifest_dll' and 'embed_manifest_exe' from CONFIG
#
prepare_windows_build() {
    local orig_conf=$MY_MKSPECDIR/qmake.conf

    # if the created file exists, return
    [[ -e "$orig_conf.static" ]] && return

    # make a copy of the orig file
    cp $orig_conf $orig_conf.dyn

    # create a static build version
    sed -e "s/embed_manifest_dll embed_manifest_exe//g" -e "s/-MD/-MT/g" $orig_conf > $orig_conf.static
}

configure_static_qt4() {
    $SRCDIR_QT/configure $COMMON_CONFIG_OPTIONS $COMMON_STATIC_OPTIONS -silent -no-icu -optimized-qmake -no-svg -gtkstyle -DENABLE_VIDEO=0 -prefix $PWD
}

configure_dynamic_qt4() {
    $SRCDIR_QT/configure $COMMON_CONFIG_OPTIONS -silent -no-icu -optimized-qmake -gtkstyle -DENABLE_VIDEO=0 -prefix $PWD
}

build_dynamic_qt() {
    rm -rf   $DYN_BUILD_DIR
    mkdir -p $DYN_BUILD_DIR
    pushd    $DYN_BUILD_DIR
    configure_dynamic_qt4
    make -j$(getconf _NPROCESSORS_ONLN)
    # no need to make install with -developer-build option
    # make install
    popd
}

build_static_qt() {
    rm -rf   $STATIC_BUILD_DIR
    mkdir -p $STATIC_BUILD_DIR
    pushd    $STATIC_BUILD_DIR
    configure_static_qt4
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
Build dynamic and static versions of Qt4

Required directories:
 $BASEDIR
 $SRCDIR_QT

Usage:
   $0 [OPTION]

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

cat <<EOF
Build dynamic and static Qt4 libraries using sources in
 $SRCDIR_QT
EOF

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

if [[ $UNAME_SYSTEM == "Linux" ]] || [[ $UNAME_SYSTEM == "Darwin" ]]; then
    build_dynamic_qt
    build_static_qt
else
    prepare_windows_build
    build_dynamic_qt_windows
    build_static_qt_windows
fi

popd
