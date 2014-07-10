#!/bin/bash
#
# Refresh MerSDK zypper repositories for SDK release
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

SSU_RELEASE=latest
SSU_DOMAIN=sdkinstaller

SSU_RELEASE_ORIG=latest
# mersdk and emulator are on sailfish domain
SSU_DOMAIN_ORIG=sailfish
# targets are on sales domain
SSU_DOMAIN_ORIG_TARGET=sales

SSU_REFRESH_DOMAIN=10.0.0.20

SSU_INIFILE=/usr/share/ssu/repos.ini

# list here files that are to be removed after refresh has been run
CLEANUP_FILES=/var/log/zypper.log

sdk_user=mersdk

if [[ $(hostname) != "SailfishSDK" ]]; then
    echo "You must run this script in the MerSDK build engine."
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
    exec sudo $0 "$@"
    echo "$0 must be run as root and sudo failed; exiting"
    exit 1
fi

usage()
{
    cat <<EOF

Refresh the zypper repositories in MerSDK.

Without any arguments the following values will be used:
   domain:       $SSU_DOMAIN
   release:      $SSU_RELEASE
   orig release: $SSU_RELEASE_ORIG

Usage:
    $0 [OPTION] [release]

Options:
    -r  | --release           use this release instead of 'latest' in the original ssu urls
    -td | --test-domain       keep test domain
    -y  | --non-interactive   answer 'yes' to all questions from this script
    -h  | --help              this help

EOF
    [[ -n $1 ]] && exit 1
}

while [[ ${1:-} ]]; do
    case "$1" in
	-y | --non-interactive ) shift
	    OPT_YES=1
	    ;;
	-td | --test-domain ) shift
	    OPT_KEEP_TEST_DOMAIN=1
	    ;;
	-r | --release ) shift
	    SSU_RELEASE_ORIG=$1; shift
	    [[ -z $SSU_RELEASE_ORIG ]] && { echo "empty original release given."; exit 1; }
	    ;;
	-h|--help|-*)
	    usage quit
	    ;;
	*)
	    SSU_RELEASE=$1
	    break
	    ;;
    esac
done

cat <<EOF 
####
domain=$SSU_DOMAIN
release=$SSU_RELEASE
original release=$SSU_RELEASE_ORIG

EOF

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

# this temp file must be located in a path the sb2 targets can access
repoini=$(mktemp /home/$sdk_user/repoini.XXXX)

[[ ! -f $repoini ]] && { echo "Could not create tempfile $repoini. Exiting."; exit 1; }

# make sure it's readable
chmod a+r $repoini

# set cleanup handler for the tempfile
trap "{ trap - EXIT; rm -f $repoini; exit 0; }" EXIT

cat <<EOF >$repoini

[$SSU_DOMAIN-domain]
_ca-certificate=/etc/ssl/certs/sailfish-ca.pem
releaseProtocol=http
releaseDomain=$SSU_REFRESH_DOMAIN
releasePath=sdk
secureDomain=%(releaseDomain)
ssuRegDomain=ssu.sailfishos.org
EOF

check_target_visible() {
    local tgt=$1
    local sbox2dir=/home/$sdk_user/.scratchbox2
    . $sbox2dir/$tgt/sb2.config 2>/dev/null
    if [[ ! -d "$SBOX_TARGET_ROOT" ]]; then
	echo "no"
	return
    fi
    echo "yes"
}

get_targets() {
    local tgts=$(sudo -i -u $sdk_user sb2-config -l 2>&1)
    [[ $? -ne 0 ]] && return

    for t in $tgts; do
	if [[ $(check_target_visible $t) == "yes" ]]; then
	    echo $t
	fi
    done
}

refresh_target_repos() {
    [[ -z ${1:-} ]] && return

    local tgt=$1
    local sb2session="sb2 -t $tgt -m sdk-install -R"
    local reposbackup=/home/$sdk_user/t_repos.ini.$$
    echo "#### Refresh $tgt repos"

    # save the original ini file
    sudo -i -u $sdk_user bash -c "$sb2session cp -a $SSU_INIFILE $reposbackup"

    # use sed to append contents of $repoini file to ssu repos.ini
    sudo -i -u $sdk_user bash -c "$sb2session sed -i '$ r $repoini' $SSU_INIFILE"
    sudo -i -u $sdk_user bash -c "$sb2session ssu domain $SSU_DOMAIN"
    sudo -i -u $sdk_user bash -c "$sb2session ssu release $SSU_RELEASE"

    # refresh repos
    sudo -i -u $sdk_user bash -c "$sb2session zypper --non-interactive ref"

    if [[ -z $OPT_KEEP_TEST_DOMAIN ]]; then
        # restore the original ssu status
	sudo -i -u $sdk_user bash -c "$sb2session mv $reposbackup $SSU_INIFILE"
	sudo -i -u $sdk_user bash -c "$sb2session ssu domain $SSU_DOMAIN_ORIG_TARGET"
	sudo -i -u $sdk_user bash -c "$sb2session ssu release $SSU_RELEASE_ORIG"
    else
	rm -f $reposbackup
    fi

    # clean up remaining stuff here
    sudo -i -u $sdk_user bash -c "$sb2session rm -f $CLEANUP_FILES"
    
}

######
#
# Build engine
echo "#### Refresh MerSDK repos"
repoinibackup=/home/$sdk_user/repos.ini.$$
cp -a $SSU_INIFILE $repoinibackup

cat $repoini >> $SSU_INIFILE
ssu domain $SSU_DOMAIN
ssu release $SSU_RELEASE

zypper --non-interactive ref

if [[ -z $OPT_KEEP_TEST_DOMAIN ]]; then
    # restore the original ssu status
    mv $repoinibackup $SSU_INIFILE
    ssu domain $SSU_DOMAIN_ORIG
    ssu release $SSU_RELEASE_ORIG
else
    rm -f $repoinibackup
fi

# cleanup remaining stuff
rm -f $CLEANUP_FILES

######
#
# Targets
targets=$(get_targets)
for target in $targets; do
  refresh_target_repos $target
done

echo "#### Done"
