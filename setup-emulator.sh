#!/bin/bash

#
# This is preliminary build script used to setup emulator for SailfishOS SDK
# (c) 2014444lla Ltd. Contact: Jarko Vihriälä <jarko.vihriala@jolla.com>
# License: Jolla Proprietary until further notice.
#
# for tracing: set -x


function checkForVDI {
    if [[ ! -f "$VDI" ]];then
	echo "VDI file \"$VDI\" does not exist."
	exit 1
    fi
}

usage() {
    cat <<EOF
Create emulator.7z

Usage:
   $0 -f <vdi> [OPTION] [VM_NAME]

Options:
   -f | --vdi-file <vdi>    use this vdi file [required]
   -c | --compression <0-9> compression level of 7z [9]
   -h | --help              this help

EOF

    # exit if any argument is given
    [[ -n "$1" ]] && exit 1
}



#
# Execution starts here
#
# handle commandline options
while [[ ${1:-} ]]; do
    case "$1" in
	-c | --compression ) shift
	    OPT_COMPRESSION=$1; shift
	    if [[ $OPT_COMPRESSION != [0123456789] ]]; then
		usage quit
	    fi
	    ;;
	-f | --vdi-file ) shift
	    OPT_VDI=$1; shift
	    ;;
	-h | --help ) shift
	    usage quit
	    ;;
	-* )
	    usage quit
	    ;;
	* )
	    OPT_VM=$1
	    shift
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

INSTALL_PATH=$PWD/emulator
mkdir -p $INSTALL_PATH
echo "Hard linking $PWD/$VDI => $INSTALL_PATH/sailfishos.vdi"
ln -P $PWD/$VDI $INSTALL_PATH/sailfishos.vdi
7z a -mx=$OPT_COMPRESSION emulator.7z $INSTALL_PATH/
