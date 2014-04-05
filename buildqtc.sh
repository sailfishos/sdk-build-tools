#!/bin/bash
#
# Builds Qt Creator and optionally uploads it to a server
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

fail() {
    echo "FAIL: $@"
    exit 1
}

usage() {
    cat <<EOF

Build Qt Creator and optionally upload the result to a server

Usage:
   $(basename $0) [OPTION]

Current values are displayed in [ ]s.

Options:
   -qtc | --qtc-src <DIR>      Qt Creator source directory [$OPT_QTC_SRC]
   -qt  | --qt-dir <DIR>       Qt (install) directory [$OPT_QTDIR]
   -i   | --install <DIR>      Qt Creator install directory [$OPT_INSTALL_ROOT]
   -v   | --variant <STRING>   Use <STRING> as the build variant [$OPT_VARIANT]
   -r   | --revision <STRING>  Use <STRING> as the build revision [git sha]
   -re  | --revextra <STRING>  Use <STRING> as a revision suffix
   -g   | --gdb                Build also gdb
   -go  | --gdb-only           Build only gdb
   -d   | --docs               Build Qt Creator documentation
   -k   | --keep-template      Keep the Sailfish template code in the package
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
	-re | --revextra ) shift
	    OPT_REV_EXTRA=$1; shift
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
	-g | --gdb ) shift
	    OPT_GDB=1
	    ;;
	-go | --gdb-only ) shift
	    OPT_GDB=1
	    OPT_GDB_ONLY=1
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
	-k | --keep-template ) shift
	    OPT_KEEP_TEMPLATE=1
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
   - Use [$PWD] as the build directory
   - Install QtC build results to [$OPT_INSTALL_ROOT]
   - Qt Creator source directory [$OPT_QTC_SRC]
   - Qt directory [$OPT_QTDIR]
EOF
if [[ -z $OPT_GDB_ONLY ]]; then
    echo " 1) Build Qt Creator"
else
    echo " 1) Do NOT build Qt Creator"
fi

if [[ -n $OPT_DOCUMENTATION ]] && [[ -z $OPT_GDB_ONLY ]]; then
    echo " 2) Build documentation"
else
    echo " 2) Do NOT build documentation"
fi

if [[ -n $OPT_GDB ]]; then
    echo " 3) Build GDB"
else
    echo " 3) Do NOT build GDB"
fi

if [[ -n $OPT_UPLOAD ]]; then
    echo " 4) Upload build result as user [$OPT_UPLOAD_USER] to [$OPT_UPLOAD_HOST:$OPT_UPLOAD_PATH/$OPT_UL_DIR]"
else
    echo " 4) Do NOT upload build result anywhere"
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

build_unix_gdb() {
    if [[ -n $OPT_GDB ]]; then
	mkdir -p build-gdb
	pushd build-gdb

	if [[ $UNAME_SYSTEM == "Linux" ]]; then
	    GDB_MAKEFILE=Makefile.linux
	else
	    GDB_MAKEFILE=Makefile.osx
	fi

	make -f $OPT_QTC_SRC/dist/gdb/$GDB_MAKEFILE PATCHDIR=$OPT_QTC_SRC/dist/gdb/patches
        # move the completed package to the parent dir
	mv $SAILFISH_GDB_BASENAME*.7z ..
	popd
    fi
}

build_unix_qtc() {
    if [[ -z $OPT_GDB_ONLY ]]; then
	export INSTALL_ROOT=$OPT_INSTALL_ROOT
	export QTDIR=$OPT_QTDIR
	export QT_PRIVATE_HEADERS=$QTDIR/include
	export PATH=$QTDIR/bin:$PATH

	$QTDIR/bin/qmake $OPT_QTC_SRC/qtcreator.pro -r -after "DEFINES+=IDE_REVISION=$OPT_REVISION IDE_COPY_SETTINGS_FROM_VARIANT=. IDE_SETTINGSVARIANT=$OPT_VARIANT" QTC_PREFIX=

	make -j$(getconf _NPROCESSORS_ONLN)

	rm -rf $OPT_INSTALL_ROOT/*
	if [[ $UNAME_SYSTEM == "Linux" ]]; then
	    make install
	    make deployqt
	fi

	make bindist_installer

	# name the file to be uploaded
	ln -s qt-creator-*-installer-archive.7z $SAILFISH_QTC_BASENAME$(build_arch).7z

	if [[ -z $OPT_KEEP_TEMPLATE ]]; then
            # remove the sailfish template project from the
            # archive. it will be reinstalled by the installer.
	    7z d $SAILFISH_QTC_BASENAME$(build_arch).7z share/qtcreator/templates/wizards/sailfishos-qtquick2app
	fi

	if [[ -n $OPT_DOCUMENTATION ]]; then
	    make docs
	    make install_docs
	fi
    fi
}

build_windows_gdb() {
    if [[ -n $OPT_GDB ]]; then
	mkdir -p build-gdb
	pushd build-gdb

	GDB_MAKEFILE=Makefile.mingw

        # dirty hax to build gdb in another mingw session, which has
        # the compiler available
        #
        # NOTE: this also requires that qtc sources are in
        # /c/src/sailfish-qtcreator

	cat <<EOF > build-gdb.bat
@echo off
call C:\mingw\msys\1.0\bin\env -u PATH C:\mingw\msys\1.0\bin\bash.exe --rcfile /etc/build_profile --login -c "cd $PWD; make -f /c/src/sailfish-qtcreator/dist/gdb/Makefile.mingw PATCHDIR=/c/src/sailfish-qtcreator/dist/gdb/patches"
EOF
	cmd //c build-gdb.bat

        # move the completed package to the parent dir
	mv $SAILFISH_GDB_BASENAME*.7z ..
	popd
    fi
}

build_windows_qtc() {
    if [[ -z $OPT_GDB_ONLY ]]; then

	# fetch the binary artifacts if they can be found
	#
	# https://git.gitorious.org/qt-creator/binary-artifacts.git
	#
	local binary_artifacts="qtc-win32-binary-artifacts.7z"
	echo "Downloading binary artifacts ..."
	# Allow error code from curl
	set +e
	curl -s -f -o $binary_artifacts http://$OPT_UPLOAD_HOST/sailfishos/win32-binary-artifacts/$binary_artifacts
	[[ $? -ne 0 ]] && echo "NOTE! Downloading binary artifacts failed [ignoring]"

	# no more errors allowed
	set -e
        # create the build script for windows
	cat <<EOF > build-windows.bat
@echo off

if DEFINED ProgramFiles(x86) set _programs=%ProgramFiles(x86)%
if Not DEFINED ProgramFiles(x86) set _programs=%ProgramFiles%

set INSTALL_ROOT=$OPT_INSTALL_ROOT
set QTDIR=$OPT_QTDIR
set QMAKESPEC=win32-msvc2010
set QT_PRIVATE_HEADERS=%QTDIR%\install
set PATH=%PATH%;%_programs%\7-Zip;%QTDIR%\bin;c:\invariant\bin;c:\Python27

call "%_programs%\Microsoft Visual Studio 10.0\VC\vcvarsall.bat"
call %QTDIR%\bin\qmake $OPT_QTC_SRC\qtcreator.pro -r -after "DEFINES+=IDE_REVISION=$OPT_REVISION IDE_COPY_SETTINGS_FROM_VARIANT=. IDE_SETTINGSVARIANT=$OPT_VARIANT" QTC_PREFIX= 
call jom
call nmake install
call nmake deployqt
call nmake bindist_installer
EOF

	rm -rf $OPT_INSTALL_ROOT/*

	if [[ -f $binary_artifacts ]]; then
	    7z x -o$OPT_INSTALL_ROOT $binary_artifacts
	fi

        # execute the bat
	cmd //c build-windows.bat

	# name the file to be uploaded
	ln -s qt-creator-*-installer-archive.7z $SAILFISH_QTC_BASENAME$(build_arch).7z

	if [[ -z $OPT_KEEP_TEMPLATE ]]; then
	    # remove the template project from the archive. it will be
	    # reinstalled by the installer.
	    7z d $SAILFISH_QTC_BASENAME$(build_arch).7z share/qtcreator/templates/wizards/sailfishos-qtquick2app
	fi
    fi
}

# if any step below fails, exit
set -e

# build result files
SAILFISH_QTC_BASENAME="sailfish-qt-creator-"
SAILFISH_GDB_BASENAME="sailfish-gdb-"

if [[ $(build_arch) == "windows" ]]; then
    build_windows_qtc
    build_windows_gdb
else
    build_unix_qtc
    build_unix_gdb
fi

if  [[ -n "$OPT_UPLOAD" ]]; then
    # create upload dir
    ssh $OPT_UPLOAD_USER@$OPT_UPLOAD_HOST mkdir -p $OPT_UPLOAD_PATH/$OPT_UL_DIR/$(build_arch)

    if [[ -z $OPT_GDB_ONLY ]]; then
	echo "Uploading $SAILFISH_QTC_BASENAME$(build_arch).7z ..."
	scp $SAILFISH_QTC_BASENAME$(build_arch).7z $OPT_UPLOAD_USER@$OPT_UPLOAD_HOST:$OPT_UPLOAD_PATH/$OPT_UL_DIR/$(build_arch)/
    fi

    if [[ -n $OPT_GDB ]]; then
	echo "Uploading GDB ..."
	scp $SAILFISH_GDB_BASENAME*.7z $OPT_UPLOAD_USER@$OPT_UPLOAD_HOST:$OPT_UPLOAD_PATH/$OPT_UL_DIR/$(build_arch)/
    fi
fi
