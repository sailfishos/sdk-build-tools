#!/bin/bash
#
# Builds Qt Creator and optionally uploads it to a server
#

UNAME_SYSTEM=$(uname -s)
UNAME_ARCH=$(uname -m)

# some default values
OPT_UPLOAD_HOST=10.0.0.20
OPT_UPLOAD_USER=sdkinstaller
OPT_UPLOAD_PATH=/var/www/sailfishos

if [[ $UNAME_SYSTEM == "Linux" ]] || [[ $UNAME_SYSTEM == "Darwin" ]]; then
    OPT_QTDIR=$HOME/invariant/qt-4.8.5-build_______________padding___________________
    OPT_QTC_SRC=$HOME/src/sailfish-qtcreator
    OPT_INSTALL_ROOT=$HOME/build/qtc-install
else
    OPT_QTDIR="c:\invariant\build-qt-dynamic"
    OPT_QTC_SRC="c:\src\sailfish-qtcreator"
    OPT_INSTALL_ROOT="c:\build\qtc-install"
fi

OPT_VARIANT="SailfishAlpha4"
OPT_REVISION="Jolla"

fail() {
    echo "FAIL: $@"
    exit 1
}

usage() {
    cat <<EOF

Build Qt Creator and optionally upload the result to a server

Usage:
   $0 [OPTION]

Current values are displayed in [ ]s.

Options:
   -qtc | --qtc-src <DIR>      Qt Creator source directory [$OPT_QTC_SRC]
   -qt  | --qt-dir <DIR>       Qt (install) directory [$OPT_QTDIR]
   -i   | --install <DIR>      Qt Creator install directory [$OPT_INSTALL_ROOT]
   -v   | --variant <STRING>   Use <STRING> as the build variant [$OPT_VARIANT]
   -r   | --revision <STRING>  Use <STRING> as the build revision [$OPT_REVISION]
   -d   | --docs               Build Qt Creator documentation
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
	-v | --variant ) shift
	    OPT_VARIANT=$1; shift
	    ;;
	-r | --revision ) shift
	    OPT_REVISION=$1; shift
	    ;;
	-qtc | --qtc-src ) shift
	    OPT_QTC_SRC=$1; shift
	    ;;
	-qt | --qt-dir ) shift
	    OPT_QTDIR=$1; shift
	    ;;
	-i | --install ) shift
	    OPT_INSTALL_ROOT=$1; shift
	    ;;
	-d | --docs ) shift
	    OPT_DOCUMENTATION=1
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

if [[ ! -d $OPT_QTC_SRC ]]; then
    fail "Qt Creator source directory [$OPT_QTC_SRC] not found"
fi

if [[ ! -d $OPT_INSTALL_ROOT ]]; then
    mkdir -p $OPT_INSTALL_ROOT
fi

# summary
cat <<EOF
Summary of chosen actions:
 1) QT Creator variant [$OPT_VARIANT]
    - Use [$PWD] as the build directory
    - Install build results to [$OPT_INSTALL_ROOT]
    - Qt Creator source directory [$OPT_QTC_SRC]
    - Qt directory [$OPT_QTDIR]
EOF

if [[ -n $OPT_DOCUMENTATION ]]; then
    echo " 2) Build documentation"
else
    echo " 2) Do NOT build documentation"
fi

if [[ -n $OPT_UPLOAD ]]; then
    echo " 3) Upload build result as user [$OPT_UPLOAD_USER] to [$OPT_UPLOAD_HOST:$OPT_UPLOAD_PATH/$OPT_UL_DIR]"
else
    echo " 3) Do NOT upload build result anywhere"
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
    export INSTALL_ROOT=$OPT_INSTALL_ROOT
    export QTDIR=$OPT_QTDIR
    export QT_PRIVATE_HEADERS=$QTDIR/include
    export PATH=$QTDIR/bin:$PATH

    $QTDIR/bin/qmake $OPT_QTC_SRC/qtcreator.pro -r -after "DEFINES+=REVISION=$OPT_REVISION IDE_COPY_SETTINGS_FROM_VARIANT=. IDE_SETTINGSVARIANT=$OPT_VARIANT" QTC_PREFIX=

    make -j$(getconf _NPROCESSORS_ONLN)

    rm -rf $OPT_INSTALL_ROOT/*
    if [[ $UNAME_SYSTEM != "Darwin" ]]; then
	make install
	make deployqt
    fi

    make bindist_installer

    if [[ -n $OPT_DOCUMENTATION ]]; then
	make docs
	make install_docs
    fi
}

build_windows() {
    # create the build script for windows
    cat <<EOF > build-windows.bat
@echo off

set INSTALL_ROOT=$OPT_INSTALL_ROOT
set QTDIR=$OPT_QTDIR
set QMAKESPEC=win32-msvc2010
set QT_PRIVATE_HEADERS=%QTDIR%\install
set PATH=%PATH%;C:\Program Files\7-Zip;%QTDIR%\bin;c:\invariant\bin;c:\Python27

call "C:\Program Files\Microsoft Visual Studio 10.0\VC\vcvarsall.bat"
call %QTDIR%\bin\qmake $OPT_QTC_SRC\qtcreator.pro -r -after "DEFINES+=REVISION=$OPT_REVISION IDE_COPY_SETTINGS_FROM_VARIANT=. IDE_SETTINGSVARIANT=$OPT_VARIANT" QTC_PREFIX= 
call jom
call nmake install
call nmake deployqt
call nmake bindist_installer
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

# rename the build result
SAILFISH_QTC_BASENAME="sailfish-qt-creator-"

if [[ $UNAME_SYSTEM == "Linux" ]]; then
    if [[ $UNAME_ARCH == "x86_64" ]]; then
	BUILD_ARCH="linux-64"
	ln -s qt-creator-linux-x86_64*-installer-archive.7z $SAILFISH_QTC_BASENAME$BUILD_ARCH.7z
    else
	BUILD_ARCH="linux-32"
	ln -s qt-creator-linux-x86-*-installer-archive.7z $SAILFISH_QTC_BASENAME$BUILD_ARCH.7z
    fi
elif [[ $UNAME_SYSTEM == "Darwin" ]]; then
    BUILD_ARCH="mac"
    ln -s qt-creator-mac-*-installer-archive.7z $SAILFISH_QTC_BASENAME$BUILD_ARCH.7z
else
    BUILD_ARCH="windows"
    ln -s qt-creator-windows-*-installer-archive.7z $SAILFISH_QTC_BASENAME$BUILD_ARCH.7z
fi

if  [[ -n "$OPT_UPLOAD" ]]; then
    echo "Uploading $SAILFISH_QTC_BASENAME$BUILD_ARCH.7z ..."
    # create upload dir
    ssh $OPT_UPLOAD_USER@$OPT_UPLOAD_HOST mkdir -p $OPT_UPLOAD_PATH/$OPT_UL_DIR/$BUILD_ARCH
    scp $SAILFISH_QTC_BASENAME$BUILD_ARCH.7z $OPT_UPLOAD_USER@$OPT_UPLOAD_HOST:$OPT_UPLOAD_PATH/$OPT_UL_DIR/$BUILD_ARCH/
fi
