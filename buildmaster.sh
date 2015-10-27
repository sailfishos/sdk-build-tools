#!/bin/bash
#
# Master script to build parts of or all of the SDK installer
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

OPT_VARIANT="SailfishBetaX"
OPT_RELEASE="yydd"
OPT_RELCYCLE="Beta"

OPT_REVISION_EXTRA="+git"

OPT_REPO_URL=''

DEFAULT_URL_PREFIX=http://$OPT_UPLOAD_HOST/sailfishos
CREATOR_SRC=sailfish-qtcreator
BUILD_TOOLS_SRC=sdk-build-tools
INSTALLER_SRC=sailfish-sdk-installer

# keep these following two in sync
REQUIRED_SRC_DIRS=($BUILD_TOOLS_SRC $CREATOR_SRC $INSTALLER_SRC)
REQUIRED_GIT_DEVEL_BRANCHES=(master next next)
REQUIRED_GIT_RELEASE_BRANCHES=(master master sdk-release)

if [[ $UNAME_SYSTEM == "Linux" ]] || [[ $UNAME_SYSTEM == "Darwin" ]]; then
    BASE_SRC_DIR=$HOME/src
    BASE_BUILD_DIR=$HOME/build
    INVARIANT_DIR=$HOME/invariant
else
    BASE_SRC_DIR=/c/src
    BASE_BUILD_DIR=/c/build
    INVARIANT_DIR=/c/invariant
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

fail() {
    echo "FAIL: $@"
    exit 1
}

usage() {
    cat <<EOF

Build control script

Usage:
   $(basename $0) [OPTION]

Options:
   -q   | --qtc                 Build Qt Creator
   -qd  | --qtc-docs            Build QtC documentation (requires -q)
   -g   | --gdb                 Build GDB
   -i   | --installer           Build installer
   -r   | --repogen             Build SDK update repository
   -I   | --ifw                 Build Installer Framework
        | --qt-static           Build Qt (static - required for Installer framework)
        | --qt-dynamic          Build Qt (dynamic - required for QtC)
   -icu | --icu-build           Build ICU library (Linux and Windows)
   -e   | --extra               Extra suffix to installer/repo version
   -p   | --git-pull            Do git pull in every src repo before building
   -v   | --variant <STRING>    Use <STRING> as the build variant [$OPT_VARIANT]
        | --release-build       Do a release build
        | --release <STRING>    SDK release version [$OPT_RELEASE]
        | --rel-cycle <STRING>  SDK release cycle [$OPT_RELCYCLE]
        | --repourl <STRING>    Update repo location, if set overrides the public repo URL
   -re  | --revextra <STRING>   Use <STRING> as the Qt Creator revision suffix
   -gd  | --gdb-default         Use default download URLs for gdb build deps
   -d   | --download <URL>      Use <URL> to download artifacts
   -D   | --dload-def <DIR>     Create download URL using <DIR> as the source dir
   -u   | --upload <DIR>        upload build results
   -uh  | --uhost <HOST>        override default upload host
   -up  | --upath <PATH>        override default upload path
   -uu  | --uuser <USER>        override default upload user
   -y   | --non-interactive     answer yes to all questions from this script
   -z   | --dry-run             do nothing, just print out what would happen
   -h   | --help                this help

EOF

    # exit if any argument is given
    [[ -n "$1" ]] && exit 1
}

# handle commandline options
while [[ ${1:-} ]]; do
    # Keep it during the transition to not break Jenkins config
    case "$1" in
        -qt4 ) echo "The switch '-qt4' is deprecated. Use '--qt-static' instead";;
        -qt5 ) echo "The switch '-qt5' is deprecated. Use '--qt-dynamic' instead";;
    esac

    case "$1" in
        -q | --qtc ) shift
            OPT_BUILD_QTC=1
            REQ_BUILD_DIR=1
            let numtasks++
            ;;
        -qd | --qtc-docs ) shift
            OPT_BUILD_QTC_DOCS=1
            # docs can only be built with QtC, so let's not set
            # REQ_BUILD_DIR here, also not a task on its own
            ;;
        -g | --gdb ) shift
            OPT_BUILD_GDB=1
            REQ_BUILD_DIR=1
            let numtasks++
            ;;
        -I | --ifw ) shift
            OPT_BUILD_IFW=1
            REQ_BUILD_DIR=1
            let numtasks++
            ;;
        -i | --installer ) shift
            OPT_BUILD_INSTALLER=1
            let numtasks++
            ;;
        -r | --repogen ) shift
            OPT_BUILD_REPO=1
            let numtasks++
            ;;
        -icu | --icu-build ) shift
            OPT_BUILD_ICU=1
            let numtasks++
            ;;
        -qt4 | --qt-static ) shift
            OPT_BUILD_QT_STATIC=1
            let numtasks++
            ;;
        -qt5 | --qt-dynamic ) shift
            OPT_BUILD_QT_DYNAMIC=1
            let numtasks++
            ;;
        -p | --git-pull ) shift
            OPT_GIT_PULL=1
            let numtasks++
            ;;
        -v | --variant ) shift
            OPT_VARIANT=$1; shift
            ;;
        --release-build ) shift
            OPT_RELEASE_BUILD=1
            ;;
        --release ) shift
            OPT_RELEASE=$1; shift
            ;;
        --rel-cycle ) shift
            OPT_RELCYCLE=$1; shift
            ;;
        --repourl ) shift
            OPT_REPO_URL=$1; shift
            ;;
        -re | --revextra ) shift
            OPT_REVISION_EXTRA=$1; shift
            ;;
        -e | --extra ) shift
            OPT_VERSION_EXTRA=$1; shift
            ;;
        -d | --download ) shift
            OPT_DOWNLOAD_URL=$1; shift
            if [[ -z $OPT_DOWNLOAD_URL ]]; then
                fail "download option requires a valid URL"
            fi
            ;;
        -D | --dload-def ) shift
            OPT_DL_DIR=$1; shift
            if [[ -z $OPT_DL_DIR ]]; then
                fail "download option requires a directory name"
            fi
            ;;
        -gd | --gdb-default ) shift
            OPT_GDB_DEFAULT=1
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
        -z | --dry-run ) shift
            OPT_DRY_RUN=1
            ;;
        -h | --help ) shift
            usage quit
            ;;
        * )
            usage quit
            ;;
    esac
done

# is there anything to do?
[[ $numtasks -eq 0 ]] && usage quit

# some basic requirement checks
if [[ ! -d $INVARIANT_DIR ]]; then
    fail "Directory [$INVARIANT_DIR] does not exist"
fi

for src in ${REQUIRED_SRC_DIRS[*]}; do
    [[ ! -d $BASE_SRC_DIR/$src ]] && fail "Directory [$BASE_SRC_DIR/$src] does not exist"
done

if [[ -n $OPT_DL_DIR ]]; then
    OPT_DOWNLOAD_URL=$DEFAULT_URL_PREFIX/$OPT_DL_DIR
fi

if [[ -n $OPT_BUILD_INSTALLER ]] || [[ -n $OPT_BUILD_REPO ]] && [[ -z $OPT_DOWNLOAD_URL ]]; then
    fail "Building the installer requires a download url [-d or -D]"
fi

# dry run function
_() {
    [[ -n $OPT_DRY_RUN ]] && echo "$@" || eval $@
}

# helper
get_option() {
    [[ -z $1 ]] && echo " " || echo "X"
}

# summary
cat <<EOF
Summary of chosen actions:
 Build Qt Creator .. [$(get_option $OPT_BUILD_QTC)]
 Build QtC Docs .... [$(get_option $OPT_BUILD_QTC_DOCS)]
 Build GDB ......... [$(get_option $OPT_BUILD_GDB)]
 Build Installer FW  [$(get_option $OPT_BUILD_IFW)]
 Build Installer ... [$(get_option $OPT_BUILD_INSTALLER)]
 Build Qt (static) . [$(get_option $OPT_BUILD_QT_STATIC)]
 Build Qt (dynamic)  [$(get_option $OPT_BUILD_QT_DYNAMIC)]
 Build ICU ......... [$(get_option $OPT_BUILD_ICU)]
 Run repogen ....... [$(get_option $OPT_BUILD_REPO)]
 Do Git pull on src  [$(get_option $OPT_GIT_PULL)]
 Do a release build  [$(get_option $OPT_RELEASE_BUILD)]
 SDK Config Variant  [$OPT_VARIANT]
 SDK Release Version [$OPT_RELEASE]
 SDK Release Cycle   [$OPT_RELCYCLE]
EOF

if [[ -n $OPT_BUILD_QTC ]]; then
    echo " QtC revision suffx  [${OPT_REVISION_EXTRA:- }]"
fi

if [[ -n $OPT_VERSION_EXTRA ]]; then
    echo " Inst/Repo suffix .. [${OPT_VERSION_EXTRA:- }]"
fi

echo " Build architecture  [$(build_arch)]"

if [[ -n $OPT_DOWNLOAD_URL ]]; then
    echo " Download URL ...... [$OPT_DOWNLOAD_URL]"
fi

if [[ -n $OPT_UPLOAD ]]; then
    echo " Upload as [$OPT_UPLOAD_USER] to [$OPT_UPLOAD_HOST:$OPT_UPLOAD_PATH/$OPT_UL_DIR]"
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

if [[ -n $OPT_UPLOAD ]]; then
    UPLOAD_OPTIONS="-u $OPT_UL_DIR"

    [[ -n $OPT_UPLOAD_HOST ]] && UPLOAD_OPTIONS=$UPLOAD_OPTIONS" -uh $OPT_UPLOAD_HOST"
    [[ -n $OPT_UPLOAD_PATH ]] && UPLOAD_OPTIONS=$UPLOAD_OPTIONS" -up $OPT_UPLOAD_PATH"
    [[ -n $OPT_UPLOAD_USER ]] && UPLOAD_OPTIONS=$UPLOAD_OPTIONS" -uu $OPT_UPLOAD_USER"
fi

# use the correct branches for release/devel build of the sdk
if [[ -n $OPT_RELEASE_BUILD ]]; then
    REQUIRED_GIT_BRANCHES=(${REQUIRED_GIT_RELEASE_BRANCHES[@]})
else
    REQUIRED_GIT_BRANCHES=(${REQUIRED_GIT_DEVEL_BRANCHES[@]})
fi

do_git_pull() {
    [[ -z $OPT_GIT_PULL ]] && return;

    echo "---------------------------------"
    echo "Updating source repositories ..."

    for ((i=0; i < ${#REQUIRED_SRC_DIRS[@]}; ++i)); do
        _ pushd $BASE_SRC_DIR/${REQUIRED_SRC_DIRS[i]}
        _ git clean -xdf
        _ git reset --hard
        _ git checkout ${REQUIRED_GIT_BRANCHES[i]}
        _ git pull
        _ popd
    done
}

do_create_build_env() {
    [[ -z $REQ_BUILD_DIR ]] && return;

    echo "---------------------------------"
    echo "Creating build environment ..."

    if [[ -n $OPT_BUILD_IFW ]]; then
        _ rm -rf $BASE_BUILD_DIR/ifw-build
        _ mkdir -p $BASE_BUILD_DIR/ifw-build
    fi

    if [[ -n $OPT_BUILD_QTC ]]; then
        _ rm -rf $BASE_BUILD_DIR/qtc-build
        _ mkdir -p $BASE_BUILD_DIR/qtc-build
    fi
}

do_build_qt_static() {
    [[ -z $OPT_BUILD_QT_STATIC ]] && return;

    echo "---------------------------------"
    echo "Building Qt (static) ..."

    _ pushd $INVARIANT_DIR
    _ $BASE_SRC_DIR/$BUILD_TOOLS_SRC/buildqt5.sh -y --static
    _ popd
}

do_build_qt_dynamic() {
    [[ -z $OPT_BUILD_QT_DYNAMIC ]] && return;

    echo "---------------------------------"
    echo "Building Qt (dynamic) ..."

    _ pushd $INVARIANT_DIR
    _ $BASE_SRC_DIR/$BUILD_TOOLS_SRC/buildqt5.sh -y
    _ popd
}

do_build_ifw() {
    [[ -z $OPT_BUILD_IFW ]] && return;

    echo "---------------------------------"
    echo "Building Installer FW ..."

    _ pushd $BASE_BUILD_DIR/ifw-build
    _ $BASE_SRC_DIR/$BUILD_TOOLS_SRC/buildifw_qt5.sh -y $UPLOAD_OPTIONS
    _ popd
}

do_build_icu() {
    [[ -z $OPT_BUILD_ICU ]] || [[ $UNAME_SYSTEM == "Darwin" ]] && return;

    echo "---------------------------------"
    echo "Building ICU ..."

    _ pushd $INVARIANT_DIR
    _ $BASE_SRC_DIR/$BUILD_TOOLS_SRC/buildicu.sh -y
    _ popd
}

do_build_qtc() {
    # QtC docs cannot be built without also building QtC so let's not
    # check it here
    [[ -z $OPT_BUILD_QTC ]] && [[ -z $OPT_BUILD_GDB ]] && return;

    echo "---------------------------------"

    local options=

    if [[ -n $OPT_BUILD_QTC ]] && [[ -n $OPT_BUILD_GDB ]]; then
        echo "Building Qt Creator and GDB ..."
        options="--gdb"
    elif [[ -n $OPT_BUILD_QTC ]]; then
        echo "Building Qt Creator ..."
    else
        echo "Building GDB ..."
        options="--gdb-only"
    fi

    if [[ -n $OPT_BUILD_QTC_DOCS ]] && [[ -n $OPT_BUILD_QTC ]]; then
        echo "... and QtC Documentation"
        options=$options" --docs"
    fi

    if [[ -n $OPT_VARIANT ]]; then
        options=$options" --variant $OPT_VARIANT"
    fi

    if [[ -n $OPT_REVISION_EXTRA ]]; then
        options=$options" --revextra $OPT_REVISION_EXTRA"
    fi

    if [[ -z $OPT_GDB_DEFAULT ]]; then
        # only set this URL if default is not requested
        options=$options" --gdb-download $DEFAULT_URL_PREFIX/gdb-build-deps"
    fi

    _ pushd $BASE_BUILD_DIR/qtc-build
    _ $BASE_SRC_DIR/$BUILD_TOOLS_SRC/buildqtc.sh -y $options $UPLOAD_OPTIONS
    _ popd
}

do_build_installer() {
    [[ -z $OPT_BUILD_INSTALLER ]] && return;

    echo "---------------------------------"
    echo "Building Installer ..."

    local options=

    if [[ -n $OPT_VARIANT ]]; then
        options=$options" --variant $OPT_VARIANT"
    fi

    if [[ -n $OPT_RELEASE ]]; then
        options=$options" --release $OPT_RELEASE"
    fi

    if [[ -n $OPT_RELCYCLE ]]; then
        options=$options" --rel-cycle $OPT_RELCYCLE"
    fi

    if [[ -n $OPT_VERSION_EXTRA ]]; then
        options=$options" --extra $OPT_VERSION_EXTRA"
    fi

    _ pushd $BASE_SRC_DIR/$INSTALLER_SRC
    _ $BASE_SRC_DIR/$INSTALLER_SRC/build.sh installer -y $options $UPLOAD_OPTIONS -d $OPT_DOWNLOAD_URL
    _ popd
}

do_override_repo_url() {
    if [[ "x$OPT_REPO_URL" != "x" ]]; then
       _ sed -e s%http://releases.sailfishos.org/sdk/repository%${OPT_REPO_URL}%g --in-place $BASE_SRC_DIR/$INSTALLER_SRC/config/config-linux-32.xml
       _ sed -e s%http://releases.sailfishos.org/sdk/repository%${OPT_REPO_URL}%g --in-place $BASE_SRC_DIR/$INSTALLER_SRC/config/config-linux-64.xml
       _ sed -e s%http://releases.sailfishos.org/sdk/repository%${OPT_REPO_URL}%g --in-place $BASE_SRC_DIR/$INSTALLER_SRC/config/config-mac.xml
       _ sed -e s%http://releases.sailfishos.org/sdk/repository%${OPT_REPO_URL}%g --in-place $BASE_SRC_DIR/$INSTALLER_SRC/config/config-windows.xml
    fi

}

do_build_repo() {
    [[ -z $OPT_BUILD_REPO ]] && return;

    echo "---------------------------------"
    echo "Building Repository ..."

    local options=

    if [[ -n $OPT_VARIANT ]]; then
        options=$options" --variant $OPT_VARIANT"
    fi

    if [[ -n $OPT_RELEASE ]]; then
        options=$options" --release $OPT_RELEASE"
    fi

    if [[ -n $OPT_RELCYCLE ]]; then
        options=$options" --rel-cycle $OPT_RELCYCLE"
    fi

    if [[ -n $OPT_VERSION_EXTRA ]]; then
        options=$options" --extra $OPT_VERSION_EXTRA"
    fi

    _ pushd $BASE_SRC_DIR/$INSTALLER_SRC
    _ $BASE_SRC_DIR/$INSTALLER_SRC/build.sh repogen -y $options -un $UPLOAD_OPTIONS -d $OPT_DOWNLOAD_URL
    _ popd
}

# record start time
BUILD_START=$(date +%s)

# stop for any failure
set -e

# these steps have to be done in a specific order
#
# 1 - git pull
do_git_pull

# 2 - create build directories
do_create_build_env

# 3 - build qt static
do_build_qt_static

# 3.5 - build ICU for linux and windows
do_build_icu

# 4 - build qt dynamic
do_build_qt_dynamic

# 5 - build IFW
do_build_ifw

# 6 override repo url if requested
do_override_repo_url

# 7 - build QtC + Docs + GDB
do_build_qtc

# 8 - build installer
do_build_installer

# 9 - build repository
do_build_repo

# record end time
BUILD_END=$(date +%s)

echo "================================="
time=$(( BUILD_END - BUILD_START ))
hour=$(( $time / 3600 ))
mins=$(( $time / 60 - 60*$hour ))
secs=$(( $time - 3600*$hour - 60*$mins ))

echo Time used for build: $(printf "%02d:%02d:%02d" $hour $mins $secs)

# For Emacs:
# Local Variables:
# indent-tabs-mode:nil
# tab-width:4
# End:
# For VIM:
# vim:set softtabstop=4 shiftwidth=4 tabstop=4 expandtab:
