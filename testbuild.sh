#!/bin/bash
#
# Copyright (C) 2014 Jolla Oy
#

UNAME_SYSTEM=$(uname -s)
UNAME_ARCH=$(uname -m)

# some default values
OPT_UPLOAD_HOST=10.0.0.20
OPT_UPLOAD_USER=sdkinstaller
OPT_UPLOAD_PATH=/var/www/sailfishos

OPT_VARIANT="SailfishAlpha4"

CREATOR_SRC=sailfish-qtcreator
BUILD_TOOLS_SRC=sdk-build-tools
INSTALLER_SRC=sailfish-sdk-installer

REQUIRED_SRC_DIRS="$BUILD_TOOLS_SRC $CREATOR_SRC $INSTALLER_SRC"

if [[ $UNAME_SYSTEM == "Linux" ]] || [[ $UNAME_SYSTEM == "Darwin" ]]; then
    BASE_SRC_DIR=$HOME/src
    BASE_BUILD_DIR=$HOME/build
    INVARIANT_DIR=$HOME/invariant
else
    BASE_SRC_DIR=/c/src
    BASE_BUILD_DIR=/c/build
    INVARIANT_DIR=/c/invariant
fi

fail() {
    echo "FAIL: $@"
    exit 1
}

usage() {
    cat <<EOF

Usage:
   $0 [OPTION]

Options:
   -q   | --qtc                Build Qt Creator
   -qd  | --qtc-docs           Build Qt Creator documentation
   -g   | --gdb                Build GDB
   -I   | --ifw                Build Installer Framework
   -i   | --installer          Build installer
   -r   | --repository         Build repository
   -p   | --git-pull           Do git pull in every src repo before building
   -v   | --variant <STRING>   Use <STRING> as the build variant
   -re  | --revextra <STRING>  Use <STRING> as the Qt Creator revision suffix
   -d   | --download <URL>     Use <URL> to download artifacts
   -u   | --upload <DIR>       upload build results
   -uh  | --uhost <HOST>       override default upload host
   -up  | --upath <PATH>       override default upload path
   -uu  | --uuser <USER>       override default upload user
   -y   | --non-interactive    answer yes to all questions presented by the script
   -z   | --dry-run            do nothing, just print out what would happen
   -h   | --help               this help

EOF

    # exit if any argument is given
    [[ -n "$1" ]] && exit 1
}

# handle commandline options
while [[ ${1:-} ]]; do
    case "$1" in
	-q | --qtc ) shift
	    OPT_BUILD_QTC=1
	    REQ_BUILD_DIR=1
	    ;;
	-qd | --qtc-docs ) shift
	    OPT_BUILD_QTC_DOCS=1
	    # docs can only be built with qtc, so let's not set
	    # REQ_BUILD_DIR BUILD_SOMETHING here
	    ;;
	-g | --gdb ) shift
	    OPT_BUILD_GDB=1
	    REQ_BUILD_DIR=1
	    ;;
	-I | --ifw ) shift
	    OPT_BUILD_IFW=1
	    REQ_BUILD_DIR=1
	    ;;
	-i | --installer ) shift
	    OPT_BUILD_INSTALLER=1
	    ;;
	-r | --repository ) shift
	    OPT_BUILD_REPO=1
	    ;;
	-p | --git-pull ) shift
	    OPT_GIT_PULL=1
	    ;;
	-v | --variant ) shift
	    OPT_VARIANT=$1; shift
	    ;;
	-re | --revextra ) shift
	    OPT_REVISION_EXTRA=$1; shift
	    ;;
        -d | --download ) shift
            OPT_DOWNLOAD_URL=$1; shift
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

# some basic requirement checks
if [[ ! -d $INVARIANT_DIR ]]; then
    fail "Directory [$INVARIANT_DIR] does not exist"
fi

for src in $REQUIRED_SRC_DIRS; do
    [[ ! -d $BASE_SRC_DIR/$src ]] && fail "Directory [$BASE_SRC_DIR/$src] does not exist"
done

if [[ -n $OPT_BUILD_INSTALLER ]] || [[ -n $OPT_BUILD_REPO ]] && [[ -z $OPT_DOWNLOAD_URL ]]; then
    fail "Building the installer requires a download url [-d option]"
fi

# dry run function
_() {
    [[ -n $OPT_DRY_RUN ]] && echo $@ || eval $@
}

# helper
get_option() {
    [[ -z $1 ]] && echo "no" ||	echo "yes"
}

# summary
cat <<EOF
Summary of chosen actions:
 Build Qt Creator .. [$(get_option $OPT_BUILD_QTC)]
 Build QtC Docs .... [$(get_option $OPT_BUILD_QTC_DOCS)]
 Build GDB ......... [$(get_option $OPT_BUILD_GDB)]
 Build Installer FW  [$(get_option $OPT_BUILD_IFW)]
 Build Installer ... [$(get_option $OPT_BUILD_INSTALLER)]
 Do Git pull on src  [$(get_option $OPT_GIT_PULL)]
 Qt Creator Variant  [$OPT_VARIANT]
 QtC revision extra  [$OPT_REVISION_EXTRA]
EOF

if [[ -n $OPT_DOWNLOAD_URL ]]; then
    echo " Download URL ...... [$OPT_DOWNLOAD_URL]"
fi

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

    for src in $REQUIRED_SRC_DIRS; do
	pushd $BASE_SRC_DIR/$src
	_ git clean -xdf
	_ git reset --hard
	_ git pull
	popd
    done
}

do_create_build_env() {
    [[ -z $REQ_BUILD_DIR ]] && return;

    echo "---------------------------------"
    echo "Creating build environment ..."

    _ rm -rf $BASE_BUILD_DIR/ifw-build
    _ rm -rf $BASE_BUILD_DIR/qtc-build

    _ mkdir -p $BASE_BUILD_DIR/ifw-build
    _ mkdir -p $BASE_BUILD_DIR/qtc-build
}

do_build_ifw() {
    [[ -z $OPT_BUILD_IFW ]] && return;

    echo "---------------------------------"
    echo "Building Installer FW ..."

    pushd $BASE_BUILD_DIR/ifw-build
    _ $BASE_SRC_DIR/$BUILD_TOOLS_SRC/buildifw.sh -y $UPLOAD_OPTIONS
    popd
}

do_build_qtc() {
    # QtC docs cannot be built without also building QtC so let's not
    # check it here
    [[ -z $OPT_BUILD_QTC ]] && [[ -z $OPT_BUILD_GDB ]] && return;

    echo "---------------------------------"

    local options="";

    if [[ -n $OPT_BUILD_QTC ]] && [[ -n $OPT_BUILD_GDB ]]; then
	echo "Building Qt Creator and GDB ..."
	options="--gdb"
    elif [[ -n $OPT_BUILD_QTC ]]; then
	echo "Building Qt Creator ..."
    else
	echo "Building GDB ..."
	options="--gdb-only"
    fi

    if [[ -n $OPT_BUILD_QTC_DOCS ]]; then
	echo "... and QtC Documentation"
	options=$options" --docs"
    fi

    if [[ -n $OPT_VARIANT ]]; then
	options=$options" --variant $OPT_VARIANT"
    fi

    if [[ -n $OPT_REVISION_EXTRA ]]; then
	options=$options" --revextra $OPT_REVISION_EXTRA"
    fi

    pushd $BASE_BUILD_DIR/qtc-build
    _ $BASE_SRC_DIR/$BUILD_TOOLS_SRC/buildqtc.sh -y $options $UPLOAD_OPTIONS
    popd
}

do_build_installer() {
    [[ -z $OPT_BUILD_INSTALLER ]] && return;

    echo "---------------------------------"
    echo "Building Installer ..."

    local options=""

    if [[ -n $OPT_VARIANT ]]; then
	options=$options" --variant $OPT_VARIANT"
    fi

    pushd $BASE_SRC_DIR/$INSTALLER_SRC
    _ $BASE_SRC_DIR/$INSTALLER_SRC/build.sh installer -y $options $UPLOAD_OPTIONS -d $OPT_DOWNLOAD_URL
    popd
}

do_build_repo() {
    [[ -z $OPT_BUILD_REPO ]] && return;

    echo "---------------------------------"
    echo "Building Repository ..."

    pushd $BASE_SRC_DIR/$INSTALLER_SRC
    _ $BASE_SRC_DIR/$INSTALLER_SRC/build.sh repogen -y $UPLOAD_OPTIONS -d $OPT_DOWNLOAD_URL
    popd
}

# record start time
BUILD_START=$(date +%s)

# stop for any failure
set -e

# we have to do these things in a specific order
#
# 1 - git pull
do_git_pull

# 2 - create build directories
do_create_build_env

# 3 - build IFW
do_build_ifw

# 4 - build QtC + Docs + GDB
do_build_qtc

# 5 - build installer
do_build_installer

# 6 - build repository
do_build_repo

# record end time
BUILD_END=$(date +%s)

echo "================================="
echo Time used for build: $(date -u -d @$(( BUILD_END - BUILD_START )) +"%T")
