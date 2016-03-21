#!/bin/bash
#
# Build a documentation package for Sailfish SDK installer
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

OPT_DOCVERSION=$(date +%y%m%d)
OPT_DOCDIR=$PWD
OPT_COMPRESSION=9

QTDOC_NAME=qtdocumentation.7z
SAILDOC_NAME=sailfishdocumentation.7z

failure() {
    echo "Error: $1"
    exit 1
}

usage() {
    cat <<EOF
Create SDK documentation packages and optionally them to a server.

Usage:
   $(basename $0) [OPTION]

Options:
   -v  | --version <STRING>   set documentation version [$OPT_DOCVERSION]
   -d  | --docdir <DIR>       search for .qch files from <DIR> [$OPT_DOCDIR]
   -u  | --upload <DIR>       upload local build result to [$OPT_UPLOAD_HOST] as user [$OPT_UPLOAD_USER]
                              the uploaded build will be copied to [$OPT_UPLOAD_PATH/<DIR>]
                              the upload directory will be created if it is not there
   -uh | --uhost <HOST>       override default upload host
   -up | --upath <PATH>       override default upload path
   -uu | --uuser <USER>       override default upload user
   -y  | --non-interactive    answer yes to all questions presented by the script
   -c  | --compression <0-9> compression level of 7z [$OPT_COMPRESSION]
   -h  | --help              this help

EOF

    # exit if any argument is given
    [[ -n "$1" ]] && exit 1
}


# handle commandline options
while [[ ${1:-} ]]; do
    case "$1" in
        -v | --version ) shift
            OPT_DOCVERSION=$1; shift
            ;;
        -d | --docdir ) shift
            OPT_DOCDIR=$1; shift
            OPT_DOCDIR=$(readlink -f $OPT_DOCDIR)
            ;;
        -u | --upload ) shift
            OPT_UPLOAD=1
            OPT_UL_DIR=$1; shift
            if [[ -z $OPT_UL_DIR ]]; then
                failure "upload option requires a directory name"
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
        -c | --compression ) shift
            OPT_COMPRESSION=$1; shift
            if [[ $OPT_COMPRESSION != [0123456789] ]]; then
                usage quit
            fi
            ;;
        -y | --non-interactive ) shift
            OPT_YES=1
            ;;
        -h | --help ) shift
            usage quit
            ;;
        * )
            shift
            ;;
    esac
done

INSTALL_PATH=$PWD/documentation

# summary
echo "Summary of chosen actions:"
echo "Using .qch files in [$OPT_DOCDIR]"
echo "Workdir [$INSTALL_PATH]"
echo " 1) Create documentation packages with version [$OPT_DOCVERSION]"
if [[ -n $OPT_UPLOAD ]]; then
    echo " 2) Upload packages as user [$OPT_UPLOAD_USER] to [$OPT_UPLOAD_HOST:$OPT_UPLOAD_PATH/$OPT_UL_DIR]"
else
    echo " 2) Do NOT upload packages"
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

mkdir -p $INSTALL_PATH
rm -rf $INSTALL_PATH/*
rm -f $QTDOC_NAME $SAILDOC_NAME

# create Qt documentation package
for NAME in $(ls $OPT_DOCDIR/q*.qch); do
    newname=$(basename $NAME)
    ln $NAME $INSTALL_PATH/${newname%.qch}$OPT_DOCVERSION.qch
done

7z a -mx=$OPT_COMPRESSION $QTDOC_NAME $INSTALL_PATH/
rm -f $INSTALL_PATH/*

# create Sailfish documentation package
for NAME in $(ls $OPT_DOCDIR/sail*.qch $OPT_DOCDIR/lipstick*.qch $OPT_DOCDIR/nemo*.qch); do
    newname=$(basename $NAME)
    ln $NAME $INSTALL_PATH/${newname%.qch}$OPT_DOCVERSION.qch
done

7z a -mx=$OPT_COMPRESSION $SAILDOC_NAME $INSTALL_PATH/
rm -f $INSTALL_PATH/*

if  [ "$OPT_UPLOAD" ]; then
    echo "Uploading documentation"

    # create upload dir
    ssh $OPT_UPLOAD_USER@$OPT_UPLOAD_HOST mkdir -p $OPT_UPLOAD_PATH/$OPT_UL_DIR/
    scp $QTDOC_NAME $SAILDOC_NAME $OPT_UPLOAD_USER@$OPT_UPLOAD_HOST:$OPT_UPLOAD_PATH/$OPT_UL_DIR/
fi
