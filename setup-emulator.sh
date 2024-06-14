#!/bin/bash
#
# SDK emulator creation script
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
. $(dirname $0)/utils.sh

OPT_UPLOAD_HOST=$DEF_UPLOAD_HOST
OPT_UPLOAD_USER=$DEF_UPLOAD_USER
OPT_UPLOAD_PATH=$DEF_UPLOAD_PATH
OPT_BASENAME=$DEF_EMULATOR_BASENAME
OPT_SHARED_PATH=$DEF_SHARED_EMULATORS_PATH

OPT_COMPRESSION=9

fatal() {
    echo "FAIL: $@"
    exit 1
}

checkForVDI() {
    if [[ ! -f "$VDI" ]];then
        fatal "VDI file \"$VDI\" does not exist."
    fi
}

usage() {
    cat <<EOF
Create emulator.7z and optionally upload it to a server.

Usage:
   $(basename $0) -f <vdi> [OPTION]

Options:
   -u  | --upload <DIR>       upload local build result to [$OPT_UPLOAD_HOST] as user [$OPT_UPLOAD_USER]
                              <DIR> is the root directory for this SDK build,
                              relative to the global upload path
                              [$OPT_UPLOAD_PATH]. Files will be uploaded under
                              the '<DIR>/emulators' path. If this path does not
                              exist, a symbolic link will be created using this
                              name, pointing to the shared location for emulator
                              images. This can be overriden by '--no-shared', in
                              which case a a directory will be created instead
                              of the symbolic link. The default shared location
                              can be overriden with '--shared-path'.
   --no-shared                see '--upload'
   --shared-path <PATH>       see '--upload'. Relative <PATH> will be resolved
                              relatively to '--upath' [$DEF_SHARED_EMULATORS_PATH]
   -uh | --uhost <HOST>       override default upload host
   -up | --upath <PATH>       override default upload path
   -uu | --uuser <USER>       override default upload user
   -y  | --non-interactive    answer yes to all questions presented by the script
   --basename <BASENAME>      basename for the resulting archive [$DEF_EMULATOR_BASENAME]
   -rel | --release <REL>     release number [required]
   -f  | --vdi-file <vdi>     use this vdi file [required]
   -c  | --compression <0-9>  compression level of 7z [$OPT_COMPRESSION]
   --no-meta                  suppress creating meta data files with
                              'make-archive-meta.sh'
   -h  | --help               this help

EOF

    # exit if any argument is given
    [[ -n "$1" ]] && exit 1
}


# handle commandline options
while [[ ${1:-} ]]; do
    case "$1" in
        -c | --compression ) shift
            OPT_COMPRESSION=$1; shift
            if [[ $OPT_COMPRESSION != [0123456789] ]]; then
                usage quit
            fi
            ;;
        -u | --upload ) shift
            OPT_UPLOAD=1
            OPT_UL_DIR=$1; shift
            if [[ -z $OPT_UL_DIR ]]; then
                fatal "upload option requires a directory name"
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
        -f | --vdi-file ) shift
            OPT_VDI=$1; shift
            ;;
        --basename ) shift
            OPT_BASENAME=$1; shift
            if [[ -z $OPT_BASENAME ]]; then
                fatal "the --basename option requires an argument"
            fi
            ;;
        -rel | --release ) shift
            OPT_RELEASE=$1; shift
            if [[ -z $OPT_RELEASE ]]; then
                fatal "the --release option requires an argument"
            fi
            ;;
        --no-shared ) shift
            OPT_NO_SHARED=1
            ;;
        --shared-path ) shift
            OPT_SHARED_PATH=$1; shift
            if [[ -z $OPT_SHARED_PATH ]]; then
                fatal "the --shared-path option requires an argument"
            fi
            ;;
        --no-meta ) shift
            OPT_NO_META=1
            ;;
        -h | --help ) shift
            usage quit
            ;;
        * )
            usage quit
            ;;
    esac
done

if [[ -z $OPT_RELEASE ]]; then
    echo "The --release option is required"
    exit 1
fi

if [[ $OPT_SHARED_PATH && $OPT_SHARED_PATH != /* ]]; then
    OPT_SHARED_PATH=$OPT_UPLOAD_PATH/$OPT_SHARED_PATH
fi

ARCHIVE_NAME=$OPT_BASENAME-$OPT_RELEASE-Sailfish_SDK_Emulator.7z

if [[ -n $OPT_VDI ]]; then
    VDIFILE=$OPT_VDI

    if [[ ${VDIFILE: -4} == ".bz2" ]]; then
	echo "unpacking $VDIFILE ..."
	bunzip2 -f -k $VDIFILE
	VDIFILE=${VDIFILE%.bz2}
    fi
else
    # Always require a given vdi file
    # VDIFILE=$(find . -iname "*.vdi" | head -1)

    echo "VDI file option is required (-f filename.vdi)"
    exit 1
fi

# get our VDI's formatted filename.
if [[ -n $VDIFILE ]]; then
    VDI=$(basename $VDIFILE)
fi

# check if we even have files
checkForVDI

# all go, let's do it:
cat <<EOF
Creating $ARCHIVE_NAME, compression=$OPT_COMPRESSION
 Emulator: $OPT_VDI
EOF
if [[ -n $OPT_UPLOAD ]]; then
    echo " Upload build results as user [$OPT_UPLOAD_USER] to [$OPT_UPLOAD_HOST:$OPT_UPLOAD_PATH/$OPT_UL_DIR]"
else
    echo " Do NOT upload build results"
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

echo "Hard linking $PWD/$VDI => sailfishos.vdi"
ln $PWD/$VDI sailfishos.vdi
7z a -mx=$OPT_COMPRESSION $ARCHIVE_NAME sailfishos.vdi
results=($ARCHIVE_NAME)

if [[ -z $OPT_NO_META ]]; then
    vdi_capacity=$(vdi_capacity <sailfishos.vdi)
    $BUILD_TOOLS_SRC/make-archive-meta.sh $ARCHIVE_NAME "vdi_capacity=$vdi_capacity"
    results+=($ARCHIVE_NAME.meta)
fi

if [[ -n "$OPT_UPLOAD" ]]; then
    echo "Uploading $ARCHIVE_NAME"

    # create upload dir
    ssh $OPT_UPLOAD_USER@$OPT_UPLOAD_HOST mkdir -p $OPT_UPLOAD_PATH/$OPT_UL_DIR/
    if [[ -n $OPT_NO_SHARED ]]; then
        ssh $OPT_UPLOAD_USER@$OPT_UPLOAD_HOST mkdir -p $OPT_UPLOAD_PATH/$OPT_UL_DIR/emulators
    else
        target=$(realpath --canonicalize-missing --relative-to=$OPT_UPLOAD_PATH/$OPT_UL_DIR \
            $OPT_SHARED_PATH)
        ssh $OPT_UPLOAD_USER@$OPT_UPLOAD_HOST test -e $OPT_UPLOAD_PATH/$OPT_UL_DIR/emulators \
            "||" ln -s $target $OPT_UPLOAD_PATH/$OPT_UL_DIR/emulators || return
        echo "Looking for possible unused images on the upload host..." >&2
        $BUILD_TOOLS_SRC/prune-shared.sh --uhost "$OPT_UPLOAD_HOST" \
            --uuser "$OPT_UPLOAD_USER" --upath "$OPT_UPLOAD_PATH" "$OPT_SHARED_PATH"
    fi
    rsync --ignore-existing --verbose --info=skip ${results[*]} \
        $OPT_UPLOAD_USER@$OPT_UPLOAD_HOST:$OPT_UPLOAD_PATH/$OPT_UL_DIR/emulators/
fi

# For Emacs:
# Local Variables:
# indent-tabs-mode:nil
# tab-width:8
# sh-basic-offset:4
# End:
# For VIM:
# vim:set softtabstop=4 shiftwidth=4 tabstop=8 expandtab:
