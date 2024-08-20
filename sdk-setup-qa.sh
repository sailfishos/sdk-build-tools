#!/bin/bash
#
# Copyright 2013-2023 Jolla Ltd.
# Contact: Juha Kallioinen <juha.kallioinen@jolla.com>
#
# Change the ssu domain and release for SDK QA purposes
#
# The ssu domain and release will be changed for the build engine, sdk
# emulator and all scratchbox2 targets found in the build engine.
#
# Run this script on the build engine.
#
################################################################

SSU_RELEASE=latest
SSU_DOMAIN=sailfishqa
SSU_REGDOMAIN=10.21.0.20

################################################################
#
sdk_user=mersdk
ssh_keys=/etc/$sdk_user/share/ssh/private_keys/SailfishOS_Emulator/
emu_ip=10.220.220.1

if [[ $(hostname) != "SailfishSDK" ]]; then
    echo "You must run this script in the SailfishSDK build engine."
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
Change the ssu domain and release for the build engine, emulator and
sb2 targets.

Without any arguments the following values will be used:
   domain:     $SSU_DOMAIN
   release:    $SSU_RELEASE
   reg domain: $SSU_REGDOMAIN

Usage:
    $0 [OPTION]

Options:
    -i         ignore connection problems to the Emulator
    -d <ADDR>  use hostname or ip address <ADDR> as the reg domain
    -r <REL>   use <REL> as the release
    -y         answer 'yes' to all questions from this script

EOF
    [[ -n $1 ]] && exit 1
}

OPT_ASK_USER=1
OPT_IGNORE_EMULATOR=0

while [[ ${1:-} ]]; do
    case "$1" in
	-y) shift
	    OPT_ASK_USER=0
	    ;;
	-i) shift
	    OPT_IGNORE_EMULATOR=1
	    ;;
	-d) shift
	    SSU_REGDOMAIN=$1; shift
	    [[ -z $SSU_REGDOMAIN ]] && usage quit
	    ;;
	-r) shift
	    SSU_RELEASE=$1; shift
	    [[ -z $SSU_RELEASE ]] && usage quit
	    ;;
	-h|--help|-*)
	    usage quit
	    ;;
	*)
	    usage quit
	    ;;
    esac
done

if [[ $OPT_IGNORE_EMULATOR -eq 0 ]]; then
    echo "Testing connection to the Emulator ..."
    ssh -F /etc/ssh/ssh_config.sdk -i $ssh_keys/root root@$emu_ip true
    if [[ $? -ne 0 ]]; then
	echo "Could not connect to the Emulator. Please start it or use -i option to ignore this."
	exit 1
    fi
fi

cat <<EOF 
#### Going to execute with these options:
reg domain: [$SSU_REGDOMAIN]
domain:     [$SSU_DOMAIN]
release:    [$SSU_RELEASE]

EOF
[[ $OPT_IGNORE_EMULATOR -eq 1 ]] && echo "(Ignoring the Emulator)"
echo

if [[ $OPT_ASK_USER -gt 0 ]]; then
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
trap "{ rm -f $repoini; exit 0; }" EXIT

#releaseDomain=betarepo-nd27k0.sailfishos.org

cat >$repoini <<EOF

[$SSU_DOMAIN-domain]
_ca-certificate=/etc/ssl/certs/sailfish-ca.pem
releaseProtocol=http
releaseDomain=$SSU_REGDOMAIN
releasePath=sdk
secureDomain=%(releaseDomain)
ssuRegDomain=ssu.sailfishos.org
EOF

check_target_visible() {
    local tgt=$1
    local sbox2dir=/home/$sdk_user/.scratchbox2
    . $sbox2dir/$tgt/sb2.config
    if [ ! -d "$SBOX_TARGET_ROOT" ]; then
	echo "no"
	return
    fi
    echo "yes"
}

get_targets() {
    tgts=$(sudo -i -u $sdk_user sb2-config -l 2>&1)
    [[ $? -ne 0 ]] && return 0

    for t in $tgts; do
	if [[ $(check_target_visible $t) == "yes" ]]; then
	    echo $t
	fi
    done
}

target_change_domain()
{
    local tgt
    [[ -z ${1:-} ]] && return 0

    tgt=$1
    echo "#### Changing $tgt domain"
    # use sed to append contents of $repoini file to ssu repos.ini
    sudo -i -u $sdk_user bash -c "sb2 -t $tgt -m sdk-install -R sed -i '$ r $repoini' /usr/share/ssu/repos.ini" 2>/dev/null
    sudo -i -u $sdk_user bash -c "sb2 -t $tgt -m sdk-install -R ssu domain $SSU_DOMAIN" 2>/dev/null
    sudo -i -u $sdk_user bash -c "sb2 -t $tgt -m sdk-install -R ssu release $SSU_RELEASE" 2>/dev/null
}

######
#
# Build engine
echo "#### Changing BE ssu domain"
cat $repoini >> /usr/share/ssu/repos.ini
ssu domain $SSU_DOMAIN
ssu release $SSU_RELEASE

######
#
# Emulator
if [[ $OPT_IGNORE_EMULATOR -eq 0 ]]; then
    echo "#### Changing Emulator ssu domain"
    cat $repoini | ssh -F /etc/ssh/ssh_config.sdk -i $ssh_keys/root root@$emu_ip "cat >> /usr/share/ssu/repos.ini"
    ssh -F /etc/ssh/ssh_config.sdk -i $ssh_keys/root root@$emu_ip ssu domain $SSU_DOMAIN
    ssh -F /etc/ssh/ssh_config.sdk -i $ssh_keys/root root@$emu_ip ssu release $SSU_RELEASE
else
    echo "#### Ignoring the Emulator"
fi

######
#
# Targets
targets=$(get_targets)
for target in $targets; do
  target_change_domain $target
done

echo "#### Done"

# For Emacs:
# Local Variables:
# indent-tabs-mode:nil
# tab-width:8
# sh-basic-offset:4
# End:
# For VIM:
# vim:set softtabstop=4 shiftwidth=4 tabstop=8 expandtab:
