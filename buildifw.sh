#!/bin/bash
#
# Builds installer framework and optionally uploads it to a server
#
# Copyright (C) 2014 Jolla Oy
#

UNAME_SYSTEM=$(uname -s)
UNAME_ARCH=$(uname -m)

# some default values
OPT_UPLOAD_HOST=10.0.0.20
OPT_UPLOAD_USER=sdkinstaller
OPT_UPLOAD_PATH=/var/www/sailfishos

if [[ $UNAME_SYSTEM == "Linux" ]] || [[ $UNAME_SYSTEM == "Darwin" ]]; then
    OPT_QTDIR=$HOME/invariant/qt-4.8.5-static-build
    OPT_QT_SRC_DIR=$HOME/invariant/qt
    OPT_IFW_SRC=$HOME/invariant/installer-framework
else
    OPT_QTDIR="c:\invariant\build-qt-static"
    OPT_IFW_SRC="c:\invariant\installer-framework"
fi

fail() {
    echo "FAIL: $@"
    exit 1
}

usage() {
    cat <<EOF

Build Installer Framework and optionally upload the result to a server

Usage:
   $0 [OPTION]

Current values are displayed in [ ]s.

Options:
   -ifw | --ifw-src <DIR>      Installer FW source directory [$OPT_IFW_SRC]
   -qt  | --qt-dir <DIR>       Static Qt (install) directory [$OPT_QTDIR]
   -qts | --qt-src <DIR>       Qt source directory (required for OSX) [$OPT_QT_SRC_DIR]
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
	    OPT_IFW_SRC=$1; shift
	    ;;
	-qt | --qt-dir ) shift
	    OPT_QTDIR=$1; shift
	    ;;
	-qts | --qts-dir ) shift
	    OPT_QT_SRC_DIR=$1; shift
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

if [[ $UNAME_SYSTEM == "Darwin" ]] && [[ ! -d $OPT_QT_SRC_DIR ]]; then
    fail "Qt source directory [$OPT_QT_SRC_DIR] not found"
fi

if [[ ! -d $OPT_IFW_SRC ]]; then
    fail "Installer framework source directory [$OPT_IFW_SRC] not found"
fi

# summary
cat <<EOF
Summary of chosen actions:
 1) Build Installer Framework
    - Use [$PWD] as the build directory
    - Installer Framework source directory [$OPT_IFW_SRC]
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
    export PATH=$QTDIR/bin:$PATH

    if [[ $UNAME_SYSTEM == "Linux" ]]; then
	$QTDIR/bin/qmake -r $OPT_IFW_SRC/installerfw.pro
    else
	$QTDIR/bin/qmake QT_MENU_NIB_DIR=$OPT_QT_SRC_DIR/src/gui/mac/qt_menu.nib -r $OPT_IFW_SRC/installerfw.pro
    fi

    make -j$(getconf _NPROCESSORS_ONLN)
}

build_windows() {
    # create the build script for windows
    cat <<EOF > build-windows.bat
@echo off

set QTDIR=$OPT_QTDIR
set QMAKESPEC=win32-msvc2010
set PATH=%PATH%;c:\invariant\bin

call "%programfiles%\Microsoft Visual Studio 10.0\VC\vcvarsall.bat"
call %QTDIR%\bin\qmake -r $OPT_IFW_SRC\installerfw.pro
call jom
EOF

    # execute the bat
    cmd //c build-windows.bat
}

# if any step below fails, exit
set -e

if [[ $UNAME_SYSTEM == "Linux" ]] || [[ $UNAME_SYSTEM == "Darwin" ]]; then
    build_unix
else
    build_windows
fi

IFW_PACKAGE_NAME="InstallerFW.7z"

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

# install results
mkdir -p ifw
cp -a bin ifw
7z a -mx=9 $IFW_PACKAGE_NAME ifw

if  [[ -n "$OPT_UPLOAD" ]]; then
    echo "Uploading $IFW_PACKAGE_NAME ..."
    # create upload dir
    ssh $OPT_UPLOAD_USER@$OPT_UPLOAD_HOST mkdir -p $OPT_UPLOAD_PATH/$OPT_UL_DIR/$BUILD_ARCH
    scp $IFW_PACKAGE_NAME $OPT_UPLOAD_USER@$OPT_UPLOAD_HOST:$OPT_UPLOAD_PATH/$OPT_UL_DIR/$BUILD_ARCH/
fi
