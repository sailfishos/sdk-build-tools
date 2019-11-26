#!/bin/bash
#
# Master script to build parts of or all of the SDK installer
#
# Copyright (C) 2014-2019 Jolla Ltd.
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
OPT_REPO_URL=''

OPT_VARIANT=$DEF_VARIANT
OPT_VARIANT_PRETTY=$DEF_VARIANT_PRETTY
OPT_COPY_FROM_VARIANT=$DEF_COPY_FROM_VARIANT
OPT_RELEASE=$DEF_RELEASE
OPT_RELCYCLE=$DEF_RELCYCLE
OPT_INSTALLER_PROFILE=offline

REQUIRED_SRC_DIRS=($DEF_QTC_SRC_DIR $DEF_QMLLIVE_SRC_DIR $DEF_INSTALLER_SRC_DIR $DEF_IFW_SRC_DIR)

DEFAULT_REMOTE='origin'
INSTALLER_BUILD_OPTIONS=''

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
        | --linguist            Build Qt Linguist
        | --qmllive             Build Qt QmlLive
   -e   | --extra               Extra suffix to installer/repo version
   -p   | --git-pull            Do git pull in every src repo before building
   -v   | --variant <STRING>    Use <STRING> as the build variant [$OPT_VARIANT]
   -vp  | --variant-pretty <STRING>  SDK pretty variant [$OPT_VARIANT_PRETTY] (appears
                                in the installer name and in braces after Qt Creator
                                or QmlLive version in Qt Creator/QmlLive About dialog)
          --copy-from-variant <STRING>  Copy settings from the older variant <STRING>
                                if found [$OPT_COPY_FROM_VARIANT]
        | --branch <STRING>     Build the given branch instead of "master" if it exists.
                                Multiple branches can be given, separated with spaces.
                                Tags and remote tracking branches are also accepted.
        | --release <STRING>    SDK release version [$OPT_RELEASE]
        | --rel-cycle <STRING>  SDK release cycle [$OPT_RELCYCLE]
        | --repourl <STRING>    Update repo location, if set overrides the public repo URL
   -gd  | --gdb-default         Use default download URLs for gdb build deps
   -P   | --installer-profile <STRING>  Choose a profile when building installer.
                                <STRING> can be one of "online", "offline" or "full"
                                [$OPT_INSTALLER_PROFILE]
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
            let numtasks++
            ;;
        -qd | --qtc-docs ) shift
            OPT_BUILD_QTC_DOCS=1
            ;;
        -g | --gdb ) shift
            OPT_BUILD_GDB=1
            let numtasks++
            ;;
        -I | --ifw ) shift
            OPT_BUILD_IFW=1
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
        --linguist ) shift
            OPT_BUILD_LINGUIST=1
            let numtasks++
            ;;
        --qmllive ) shift
            OPT_BUILD_QMLLIVE=1
            let numtask++
            ;;
        -p | --git-pull ) shift
            OPT_GIT_PULL=1
            let numtasks++
            ;;
        -v | --variant ) shift
            OPT_VARIANT=$1; shift
            ;;
        --copy-from-variant ) shift
            OPT_COPY_FROM_VARIANT=$1; shift
            ;;
        --branch ) shift
            OPT_BRANCH=$1; shift
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
        -vp | --variant-pretty ) shift
            OPT_VARIANT_PRETTY=$1; shift
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
        -P | --installer-profile ) shift
            OPT_INSTALLER_PROFILE=$1; shift
            if [[ -z $OPT_UL_DIR ]]; then
                fail "installer profile option requires a profile name"
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
for src in ${REQUIRED_SRC_DIRS[*]}; do
    [[ ! -d $src ]] && fail "Directory [$src] does not exist"
done

if [[ -n $OPT_DL_DIR ]]; then
    OPT_DOWNLOAD_URL=$DEF_URL_PREFIX/$OPT_DL_DIR
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
 Build Qt Linguist . [$(get_option $OPT_BUILD_LINGUIST)]
 Build Qt QmlLive .. [$(get_option $OPT_BUILD_QMLLIVE)]
 Run repogen ....... [$(get_option $OPT_BUILD_REPO)]
 Do Git pull on src  [$(get_option $OPT_GIT_PULL)]
 Use alt. branch ... [$OPT_BRANCH]
 SDK Config Variant  [$OPT_VARIANT]
 SDK Pretty Variant  [$OPT_VARIANT_PRETTY]
 SDK Copy Variant .. [$OPT_COPY_FROM_VARIANT]
 SDK Release Version [$OPT_RELEASE]
 SDK Release Cycle   [$OPT_RELCYCLE]
EOF

if [[ -n $OPT_VERSION_EXTRA ]]; then
    echo " Inst/Repo suffix .. [${OPT_VERSION_EXTRA:- }]"
fi

if [[ -n $OPT_BUILD_INSTALLER ]]; then
    echo " Installer Profile . [$OPT_INSTALLER_PROFILE]"
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

do_git_pull() {
    [[ -z $OPT_GIT_PULL ]] && return;

    echo "---------------------------------"
    echo "Updating source repositories ..."

    for ((i=0; i < ${#REQUIRED_SRC_DIRS[@]}; ++i)); do
        _ pushd ${REQUIRED_SRC_DIRS[i]}
        _ git clean -xdf --quiet
        _ git reset --hard --quiet

        # With detached HEAD it is easier to reset
        _ git checkout --detach --quiet $DEFAULT_REMOTE/master --

        # Ensure we do not have any tag that was removed remotely
        _ git fetch --prune $DEFAULT_REMOTE "+refs/tags/*:refs/tags/*"

        _ git fetch --tags --prune --all

        local other_checked_out=
        if [[ -n $OPT_BRANCH ]]; then
            local ref=
            for ref in $OPT_BRANCH; do
                if git show-ref --quiet --tags $ref; then
                    _ git checkout --detach $ref --
                    other_checked_out=1
                    break
                elif git show-ref --quiet --verify refs/remotes/$ref; then
                    _ git checkout --detach refs/remotes/$ref --
                    other_checked_out=1
                    break
                elif git show-ref --quiet --verify refs/remotes/$DEFAULT_REMOTE/$ref; then
                    _ git checkout --detach refs/remotes/$DEFAULT_REMOTE/$ref --
                    other_checked_out=1
                    break
                fi
            done
        fi
        if [[ -z $other_checked_out ]]; then
            _ git checkout --detach $DEFAULT_REMOTE/master --
        fi

        _ popd
    done
}

do_build_qt_static() {
    [[ -z $OPT_BUILD_QT_STATIC ]] && return;

    echo "---------------------------------"
    echo "Building Qt (static) ..."

    _ $BUILD_TOOLS_SRC/buildqt5.sh -y --static
}

do_build_qt_dynamic() {
    [[ -z $OPT_BUILD_QT_DYNAMIC ]] && return;

    echo "---------------------------------"
    echo "Building Qt (dynamic) ..."

    _ $BUILD_TOOLS_SRC/buildqt5.sh -y
}

do_build_ifw() {
    [[ -z $OPT_BUILD_IFW ]] && return;

    echo "---------------------------------"
    echo "Building Installer FW ..."

    _ $BUILD_TOOLS_SRC/buildifw_qt5.sh -y $UPLOAD_OPTIONS
}

do_build_icu() {
    [[ -z $OPT_BUILD_ICU ]] || [[ $UNAME_SYSTEM == "Darwin" ]] && return;

    echo "---------------------------------"
    echo "Building ICU ..."

    _ $BUILD_TOOLS_SRC/buildicu.sh -y
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

    if [[ -n $OPT_VARIANT_PRETTY ]]; then
        options=$options" --variant-pretty '$OPT_VARIANT_PRETTY'"
    fi

    if [[ -n $OPT_COPY_FROM_VARIANT ]]; then
        options=$options" --copy-from-variant $OPT_COPY_FROM_VARIANT"
    fi

    if [[ -z $OPT_GDB_DEFAULT ]]; then
        # only set this URL if default is not requested
        options=$options" --gdb-download $DEF_URL_PREFIX/gdb-build-deps"
    fi

    _ $BUILD_TOOLS_SRC/buildqtc.sh -y $options $UPLOAD_OPTIONS
}

do_build_linguist() {
    [[ -z $OPT_BUILD_LINGUIST ]] && return;

    echo "---------------------------------"

    echo "Building Qt Linguist ..."

    _ $BUILD_TOOLS_SRC/buildlinguist.sh -y $UPLOAD_OPTIONS
}

do_build_qmllive() {
    [[ -z $OPT_BUILD_QMLLIVE ]] && return;

    echo "---------------------------------"

    local options=

    echo "Building Qt QmlLive ..."

    if [[ -n $OPT_VARIANT ]]; then
        options=$options" --variant $OPT_VARIANT"
    fi

    if [[ -n $OPT_VARIANT_PRETTY ]]; then
        options=$options" --variant-pretty '$OPT_VARIANT_PRETTY'"
    fi

    _ $BUILD_TOOLS_SRC/buildqmllive.sh -y $options $UPLOAD_OPTIONS
}

do_build_installer() {
    [[ -z $OPT_BUILD_INSTALLER ]] && return;

    echo "---------------------------------"
    echo "Building Installer ..."

    local options=

    if [[ -n $OPT_VARIANT ]]; then
        options=$options" --variant $OPT_VARIANT"
    fi

    if [[ -n $OPT_VARIANT_PRETTY ]]; then
        options=$options" --variant-pretty '$OPT_VARIANT_PRETTY'"
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

    _ pushd $DEF_INSTALLER_SRC_DIR
    _ ./build.sh installer -y $options $UPLOAD_OPTIONS -d $OPT_DOWNLOAD_URL \
        --profile $OPT_INSTALLER_PROFILE $INSTALLER_BUILD_OPTIONS
    _ popd
}

do_override_repo_url() {
    if [[ -n $OPT_REPO_URL ]]; then
        _ sed -e s^http://releases.sailfishos.org/sdk/repository^${OPT_REPO_URL}^g \
            -i~ $BASE_SRC_DIR/$INSTALLER_SRC/config/config-*.xml

       # Daily builds need custom packages.conf strings.
       if [[ $OPT_REPO_URL =~ ^"http://10.0.0.20/sailfishos/daily" ]]; then
           INSTALLER_BUILD_OPTIONS="$INSTALLER_BUILD_OPTIONS --packages-conf packages-daily.conf"
           _ $BASE_SRC_DIR/$INSTALLER_SRC/create-daily-packages-conf.py
       fi
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

    _ pushd $DEF_INSTALLER_SRC_DIR
    _ ./build.sh repogen -y $options -un $UPLOAD_OPTIONS -d $OPT_DOWNLOAD_URL
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

# 2 - build qt static
do_build_qt_static

# 3 - build ICU for linux and windows
do_build_icu

# 4 - build qt dynamic
do_build_qt_dynamic

# 5 - build IFW
do_build_ifw

# 6 override repo url if requested
do_override_repo_url

# 7 - build QtC + Docs + GDB
do_build_qtc

# 8 - build Qt Linguist
do_build_linguist

# 9 - build Qt QmlLive
do_build_qmllive

# 10 - build installer
do_build_installer

# 11 - build repository
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
