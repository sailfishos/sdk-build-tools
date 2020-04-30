#!/bin/bash
#
# Create file information page for SDK release
#
# Copyright (C) 2017 Jolla Oy
# Contact: Jarkko Lehtoranta <jarkko.lehtoranta@jolla.com>
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

RELEASE="2.0"
CHECK="md5"
PLATFORMS="linux-64 mac windows"

fatal() {
    echo "FAIL: $@"
    exit 1
}

rename_installers() {
    echo "Renaming installers ..."
    for installer in SailfishSDK*; do
        local new_name=$(sed \
                -e "s/\(SailfishSDK\)-\(.*\)-offline-\(.*\)\.\(.*$\)/\1-$RELEASE-\2-offline.\4/" \
                -e "s/linux-/linux/" <<< $installer)
        mv "$installer" "$new_name" || fatal "error renaming $installer"
    done
}

usage() {
    cat <<EOF

Create output that can be used in SDK release file information page.

This will calculate the md5sum for each file and it can take a
while. Be patient.

Usage:
   $(basename $0) [OPTION]

Options:
   -m  | --rename             rename the installers to final names
   -r  | --release [LABEL]    release label [$RELEASE]
   -h  | --help               this help

EOF

    # exit if any argument is given
    [[ -n "$1" ]] && exit 1
}


# handle commandline options
while [[ ${1:-} ]]; do
    case "$1" in
	-m | --rename) shift
	    OPT_RENAME=1
	    ;;
	-r | --release) shift
	    OPT_RELEASE=$1; shift
	    [[ -z $OPT_RELEASE ]] && fatal "release label required"
	    RELEASE=$OPT_RELEASE
	    ;;
        -h | --help ) shift
            usage quit
            ;;
        * )
            usage quit
            ;;
    esac
done

if [[ $OPT_RENAME -eq 1 ]]; then
    rename_installers
fi

cat <<EOF
###### CUT HERE ######

=== File information ===
{| class="wikitable"
|-
! Filename !! Size !! MD5 Hash
EOF

for ARCH in $PLATFORMS; do
    if [[ $ARCH == "mac" ]]; then
	SUFFIX="dmg"
    elif [[ $ARCH == "windows" ]]; then
	SUFFIX="exe"
    else
	SUFFIX="run"
    fi

    FNAME=SailfishSDK-$RELEASE-${ARCH//-/}-$XLINE.$SUFFIX
    [[ ! -f $FNAME ]] && fatal "$FNAME not found."
    md5sum -b $FNAME > $FNAME.$CHECK
    FSIZE=$(stat -c %s $FNAME)
    FSIZE_MIB=$(ls -lh $FNAME | cut -f 5 -d ' ')
    MD5=$(cut -f 1 -d ' ' $FNAME.$CHECK)

    cat <<EOF
|-
| [http://releases.sailfishos.org/sdk/installers/$RELEASE/$FNAME '''$FNAME''']
|| $FSIZE_MIB ($FSIZE bytes)
|| [http://releases.sailfishos.org/sdk/installers/$RELEASE/$FNAME.$CHECK '''$MD5''']
EOF

done

cat <<EOF
|}

##### CUT HERE #####

Cut between the lines and copy paste here:

https://sailfishos.org/wiki/Application_SDK#File_Information

EOF
