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

# some default values
OPT_UPLOAD_HOST=10.0.0.20
OPT_UPLOAD_USER=sdkinstaller
OPT_UPLOAD_PATH=/var/www/sailfishos

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
                              the uploaded build will be copied to [$OPT_UPLOAD_PATH/<DIR>]
                              the upload directory will be created if it is not there
   -uh | --uhost <HOST>       override default upload host
   -up | --upath <PATH>       override default upload path
   -uu | --uuser <USER>       override default upload user
   -y  | --non-interactive    answer yes to all questions presented by the script
   -f  | --vdi-file <vdi>     use this vdi file [required]
   -c  | --compression <0-9>  compression level of 7z [$OPT_COMPRESSION]
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
        -h | --help ) shift
            usage quit
            ;;
        * )
            usage quit
            ;;
    esac
done

if [[ -n $OPT_VDI ]]; then
    VDIFILE=$OPT_VDI
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
Creating emulator.7z, compression=$OPT_COMPRESSION
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

INSTALL_PATH=$PWD/emulator
mkdir -p $INSTALL_PATH
echo "Hard linking $PWD/$VDI => $INSTALL_PATH/sailfishos.vdi"
ln $PWD/$VDI $INSTALL_PATH/sailfishos.vdi
7z a -mx=$OPT_COMPRESSION emulator.7z $INSTALL_PATH/

if [[ -n "$OPT_UPLOAD" ]]; then
    echo "Uploading emulator.7z"

    # create upload dir
    ssh $OPT_UPLOAD_USER@$OPT_UPLOAD_HOST mkdir -p $OPT_UPLOAD_PATH/$OPT_UL_DIR/
    scp emulator.7z $OPT_UPLOAD_USER@$OPT_UPLOAD_HOST:$OPT_UPLOAD_PATH/$OPT_UL_DIR/
fi
