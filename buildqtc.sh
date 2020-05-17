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

. $(dirname $0)/defaults.sh

OPT_UPLOAD_HOST=$DEF_UPLOAD_HOST
OPT_UPLOAD_USER=$DEF_UPLOAD_USER
OPT_UPLOAD_PATH=$DEF_UPLOAD_PATH

OPT_QTDIR=$DEF_QT_DYN_BUILD_DIR
OPT_LLVM_INSTALL_DIR=$DEF_LLVM_INSTALL_DIR
OPT_QTC_SRC_DIR=$DEF_QTC_SRC_DIR
QTC_BUILD_DIR=$DEF_QTC_BUILD_DIR
QTC_INSTALL_ROOT=$DEF_QTC_INSTALL_ROOT
OPT_ICU_PATH=$DEF_ICU_INSTALL_DIR
OPT_VARIANT=$DEF_VARIANT
OPT_COPY_FROM_VARIANT=$DEF_COPY_FROM_VARIANT

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
   -qtc | --qtc-src <DIR>      Qt Creator source directory [$OPT_QTC_SRC_DIR]
   -qt  | --qt-dir <DIR>       Qt (install) directory [$OPT_QTDIR]
   -v   | --variant <STRING>   Use <STRING> as the build variant [$OPT_VARIANT]
   -vp  | --variant-pretty <STRING>  Use <STRING> as the pretty variant (appears in braces
                               after Qt Creator version in About dialog)
          --copy-from-variant <STRING>  Copy settings from the older variant <STRING>
                                if found [$OPT_COPY_FROM_VARIANT]
   -r   | --revision <STRING>  Use <STRING> as the build revision [git sha]
   -d   | --docs               Build Qt Creator documentation
   -g   | --gdb                Build also gdb
   -go  | --gdb-only           Build only gdb
   -gd  | --gdb-download <URL> Use <URL> to download gdb build deps
   -k   | --keep-template      Keep the Sailfish template code in the package
        | --quick              Do not run configure or clean build dir
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
	--copy-from-variant ) shift
	    OPT_COPY_FROM_VARIANT=$1; shift
	    ;;
	-r | --revision ) shift
	    OPT_REVISION=$1; shift
	    ;;
	-vp | --variant-pretty ) shift
	    OPT_VARIANT_PRETTY=$1; shift
	    ;;
	-qtc | --qtc-src ) shift
	    OPT_QTC_SRC_DIR=$1; shift
        QTC_BUILD_DIR=$OPT_QTC_SRC_DIR$DEF_QTC_BUILD_SUFFIX
        QTC_INSTALL_ROOT=$OPT_QTC_SRC_DIR$DEF_QTC_INSTALL_SUFFIX
	    ;;
	-qt | --qt-dir ) shift
	    OPT_QTDIR=$1; shift
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

if [[ ! -d $OPT_QTC_SRC_DIR ]]; then
    fail "Qt Creator source directory [$OPT_QTC_SRC_DIR] not found"
fi

if [[ ! -d $QTC_INSTALL_ROOT ]]; then
    mkdir -p $QTC_INSTALL_ROOT
fi

# the default revision is the git hash of Qt Creator src directory
if [[ -z $OPT_REVISION ]]; then
    OPT_REVISION=$(git --git-dir=$OPT_QTC_SRC_DIR/.git rev-parse --short HEAD 2>/dev/null)
fi

if [[ -z $OPT_REVISION ]]; then
    OPT_REVISION="unknown"
fi

# summary
echo "Summary of chosen actions:"
cat <<EOF
  QT Creator variant [$OPT_VARIANT] revision [$OPT_REVISION]
   - Qt Creator source directory [$OPT_QTC_SRC_DIR]
   - Qt Creator build directory [$QTC_BUILD_DIR]
   - Qt Creator installation directory [$QTC_INSTALL_ROOT]
   - Qt directory [$OPT_QTDIR]
EOF

if [[ -n $OPT_COPY_FROM_VARIANT ]]; then
    echo "   - Copy settings from older variant [$OPT_COPY_FROM_VARIANT]"
fi

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
    [[ -n $OPT_GDB_URL ]] && echo "    - Download build deps from [$OPT_GDB_URL]"
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

        # Explicitly use bash to prevent built failure e.g. on Ubuntu where /bin/sh defaults to dash
	make -f $OPT_QTC_SRC_DIR/dist/gdb/$GDB_MAKEFILE \
            SHELL=/bin/bash \
	    PATCHDIR=$OPT_QTC_SRC_DIR/dist/gdb/patches $downloads

        # move the completed package to the parent dir
	mv $SAILFISH_GDB_BASENAME*.7z ..
	popd
    fi
}

setup_unix_qtc_ccache() {
    # This only needs to be done on OSX at the moment as OSX QMake
    # just plain refuses to obey any command to set the compiler from
    # the outside. Not future proof either, as QMake's internal files
    # are not guaranteed to be stable.
    if [ -f /Users/builder/src/ccache-3.2.2/ccache ]; then
        sed -e 's|macosx.QMAKE_CXX =|macosx.QMAKE_CXX = /Users/builder/src/ccache-3.2.2/ccache |' -i '' .qmake.stash
    fi
}

build_unix_qtc() {
    if [[ -z $OPT_GDB_ONLY ]]; then
	export INSTALL_ROOT=$QTC_INSTALL_ROOT
	export QTDIR=$OPT_QTDIR/qtbase
	export PATH=$QTDIR/bin:$PATH
	export INSTALLER_ARCHIVE=$SAILFISH_QTC_BASENAME$(build_arch).7z
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$OPT_ICU_PATH/lib
    export LLVM_INSTALL_DIR=$OPT_LLVM_INSTALL_DIR

	# clear build workspace
	[[ $OPT_QUICK ]] || rm -rf $QTC_BUILD_DIR
	mkdir -p $QTC_BUILD_DIR
	pushd    $QTC_BUILD_DIR

    if ! [[ $UNAME_SYSTEM == "Darwin" ]]; then
        EXTRA_QMAKE_LFLAGS="QMAKE_LFLAGS+=-Wl,--disable-new-dtags"
    fi

    if ! [[ $OPT_QUICK ]]; then
        $QTDIR/bin/qmake $OPT_QTC_SRC_DIR/qtcreator.pro CONFIG+=release -r \
            QTC_SHOW_BUILD_DATE=1 \
            -after "DEFINES+=IDE_REVISION=$OPT_REVISION" \
            ${OPT_VARIANT_PRETTY:+"QTCREATOR_DISPLAY_VERSION='$OPT_VARIANT_PRETTY'"} \
            ${OPT_COPY_FROM_VARIANT:+"DEFINES+=IDE_COPY_SETTINGS_FROM_VARIANT=$OPT_COPY_FROM_VARIANT"} \
            "DEFINES+=IDE_SETTINGSVARIANT=$OPT_VARIANT" \
            $EXTRA_QMAKE_LFLAGS \
            QTC_PREFIX=
    fi

	setup_unix_qtc_ccache

	make -j$(getconf _NPROCESSORS_ONLN)

	rm -rf $QTC_INSTALL_ROOT/*
	if [[ $UNAME_SYSTEM == "Linux" ]]; then
	    make install
	fi

    if [[ $UNAME_SYSTEM == "Darwin" ]]; then
        echo -e '#!/bin/sh\nexec "$(dirname "$0")/Qt Creator.app/Contents/MacOS/sfdk" "$@"' \
            > bin/sfdk
        chmod +x bin/sfdk
    fi

	make deployqt

    # Add icu library
    if [[ $UNAME_SYSTEM == "Linux" ]]; then
        cp $OPT_ICU_PATH/lib/lib*.so* $QTC_INSTALL_ROOT/lib/qtcreator
    fi

	make bindist_installer

	if [[ -z $OPT_KEEP_TEMPLATE ]]; then
		# remove the sailfish template project from the
		# archive. it will be reinstalled by the installer.
		if [[ $UNAME_SYSTEM == "Darwin" ]]; then
		    7z d $SAILFISH_QTC_BASENAME$(build_arch).7z "bin/Qt Creator.app/Contents/Resources/templates/wizards/sailfishos-qtquick2app"
		else
			7z d $SAILFISH_QTC_BASENAME$(build_arch).7z share/qtcreator/templates/wizards/sailfishos-qtquick2app
		fi
	fi

	if [[ -n $OPT_DOCUMENTATION ]]; then
	    make docs
	    make install_docs
	fi

	popd
    fi
}

build_windows_gdb() {
    if [[ -n $OPT_GDB ]]; then
	rm -rf   gdb-build
	mkdir -p gdb-build
	pushd    gdb-build

	GDB_MAKEFILE=Makefile.mingw

	local downloads
	if [[ -n $OPT_GDB_URL ]]; then
	    downloads="DOWNLOAD_URL=$OPT_GDB_URL"
	fi

        # dirty hax to build gdb in another mingw session, which has
        # the compiler available
        #
        # NOTE: this also requires that qtc sources are in
        # /c/src/sailfish-qtcreator

	cat <<EOF > build-gdb.bat
@echo off
call C:\mingw\msys\1.0\bin\env -u PATH C:\mingw\msys\1.0\bin\bash.exe --rcfile /etc/build_profile --login -c "cd $PWD; make -f $OPT_QTC_SRC_DIR/dist/gdb/Makefile.mingw PATCHDIR=$OPT_QTC_SRC_DIR/dist/gdb/patches $downloads" || exit 1
EOF
	cmd //c build-gdb.bat

        # move the completed package to the parent dir
	mv $SAILFISH_GDB_BASENAME*.7z ..
	popd
    fi
}

build_windows_qtc() {
    if [[ -z $OPT_GDB_ONLY ]]; then
	# clear build workspace
	[[ $OPT_QUICK ]] || rm -rf $QTC_BUILD_DIR
	mkdir -p $QTC_BUILD_DIR
	pushd    $QTC_BUILD_DIR

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

	local opengl32sw_lib="opengl32sw-32.7z"
	curl -s -f -o $opengl32sw_lib http://$OPT_UPLOAD_HOST/sailfishos/win32-binary-artifacts/opengl/$opengl32sw_lib

    local pkg_config_libs="pkg-config_0.26-1_win32.zip \
        gettext-runtime_0.18.1.1-2_win32.zip \
        glib_2.28.8-1_win32.zip"
    for lib in $pkg_config_libs; do
        curl -s -f -O http://$OPT_UPLOAD_HOST/sailfishos/win32-binary-artifacts/pkg-config/$lib
    done

        # create the build script for windows
	cat <<EOF > build-windows.bat
@echo off

if DEFINED ProgramFiles(x86) (
    set "_programs=%ProgramFiles(x86)%"
)
if Not DEFINED ProgramFiles(x86) (
    set _programs=%ProgramFiles%
)


set INSTALL_ROOT=$(win_path $QTC_INSTALL_ROOT)
set QTDIR=$(win_path $OPT_QTDIR)\qtbase
set QMAKESPEC=$DEF_MSVC_SPEC
set PATH=%PATH%;%_programs%\7-zip;%QTDIR%\bin;$(win_path $DEF_PREFIX)\invariant\bin;c:\python27;$(win_path $OPT_ICU_PATH)\bin
set LLVM_INSTALL_DIR=$(win_path $OPT_LLVM_INSTALL_DIR)
set INSTALLER_ARCHIVE=$SAILFISH_QTC_BASENAME$(build_arch).7z

call rmdir /s /q $(win_path $QTC_INSTALL_ROOT)

if exist $binary_artifacts (
  call 7z x -o$(win_path $QTC_INSTALL_ROOT) $binary_artifacts
)

call "%_programs%\microsoft visual studio $DEF_MSVC_VER_ALT\vc\vcvarsall.bat"

call %QTDIR%\bin\qmake $(win_path $OPT_QTC_SRC_DIR)\qtcreator.pro CONFIG+=release -r ^
    QTC_SHOW_BUILD_DATE=1 ^
    -after "DEFINES+=IDE_REVISION=$OPT_REVISION" ^
    ${OPT_COPY_FROM_VARIANT:+"'DEFINES+=IDE_COPY_SETTINGS_FROM_VARIANT=$OPT_COPY_FROM_VARIANT'"} ^
    "DEFINES+=IDE_SETTINGSVARIANT=$OPT_VARIANT" ^
    "QTCREATOR_DISPLAY_VERSION='$OPT_VARIANT_PRETTY'" ^
    QTC_PREFIX= || exit 1

call jom || exit 1
call nmake install || exit 1
call nmake deployqt || exit 1

rem copy all the necessary libraries to the install directory
copy %QTDIR%\bin\libEGL.dll %INSTALL_ROOT%\bin || exit 1
copy %QTDIR%\bin\libGLESv2*.dll %INSTALL_ROOT%\bin || exit 1
call 7z x -o%INSTALL_ROOT%\bin $opengl32sw_lib
for %%i in ($pkg_config_libs) do (
    call 7z x -o%INSTALL_ROOT% %%i < NUL || exit 1
)
copy "%_programs%\microsoft visual studio $DEF_MSVC_VER_ALT\vc\bin\D3Dcompiler_*.dll" %INSTALL_ROOT%\bin || exit 1
pushd "%_programs%\microsoft visual studio $DEF_MSVC_VER_ALT\vc\redist\x86\microsoft.vc*.crt" ^
    && copy "*.dll" %INSTALL_ROOT%\bin ^
    && popd || exit 1
copy "%windir%\system32\msvc*100.dll" %INSTALL_ROOT%\bin || exit 1
copy $(win_path $OPT_ICU_PATH)\bin\*.dll %INSTALL_ROOT%\bin || exit 1

call nmake bindist_installer || exit 1
EOF

        # execute the bat
	cmd //c build-windows.bat

	if [[ -z $OPT_KEEP_TEMPLATE ]]; then
	    # remove the template project from the archive. it will be
	    # reinstalled by the installer.
	    7z d $SAILFISH_QTC_BASENAME$(build_arch).7z share/qtcreator/templates/wizards/sailfishos-qtquick2app
	fi

	popd
    fi
}

# if any step below fails, exit
set -e

# build result files
SAILFISH_QTC_BASENAME="sailfish-qt-creator-"
SAILFISH_GDB_BASENAME="sailfish-gdb-"

# record start time
BUILD_START=$(date +%s)

if [[ $(build_arch) == "windows" ]]; then
    build_windows_qtc
    build_windows_gdb
else
    build_unix_qtc
    build_unix_gdb
fi

# record end time
BUILD_END=$(date +%s)

time=$(( BUILD_END - BUILD_START ))
hour=$(( $time / 3600 ))
mins=$(( $time / 60 - 60*$hour ))
secs=$(( $time - 3600*$hour - 60*$mins ))

echo Time used for QtC build: $(printf "%02d:%02d:%02d" $hour $mins $secs)

if  [[ -n "$OPT_UPLOAD" ]]; then
    # create upload dir
    ssh $OPT_UPLOAD_USER@$OPT_UPLOAD_HOST mkdir -p $OPT_UPLOAD_PATH/$OPT_UL_DIR/$(build_arch)

    if [[ -z $OPT_GDB_ONLY ]]; then
	echo "Uploading $SAILFISH_QTC_BASENAME$(build_arch).7z ..."
	scp $QTC_BUILD_DIR/$SAILFISH_QTC_BASENAME$(build_arch).7z $OPT_UPLOAD_USER@$OPT_UPLOAD_HOST:$OPT_UPLOAD_PATH/$OPT_UL_DIR/$(build_arch)/
    fi

    if [[ -n $OPT_GDB ]]; then
	echo "Uploading GDB ..."
	scp $SAILFISH_GDB_BASENAME*.7z $OPT_UPLOAD_USER@$OPT_UPLOAD_HOST:$OPT_UPLOAD_PATH/$OPT_UL_DIR/$(build_arch)/
    fi
fi

# For Emacs:
# Local Variables:
# indent-tabs-mode:nil
# tab-width:4
# End:
# For VIM:
# vim:set softtabstop=4 shiftwidth=4 tabstop=4 expandtab:
