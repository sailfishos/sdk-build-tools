#!/bin/bash

#
# This is preliminary build script to install targets to Mer SDK VM and pack it ready
# for SDK Installer's build.
# (c) 2013 Jolla Ltd. Contact: Jarko Vihriälä <jarko.vihriala@jolla.com>
# License: Jolla Proprietary until further notice.
#
# for tracing: set -x

function createVM {
VBoxManage createvm --name "$VM" --ostype Linux26 --register
VBoxManage modifyvm "$VM" --memory 1024 --vram 128 --accelerate3d off
VBoxManage storagectl "$VM" --name "SATA" --add sata --controller IntelAHCI $SATACOMMAND 1
VBoxManage storageattach "$VM" --storagectl SATA --port 0 --type hdd --mtype normal --medium $VDI
VBoxManage modifyvm "$VM" --nic1 nat --nictype1 virtio
VBoxManage modifyvm "$VM" --nic2 intnet --intnet2 sailfishsdk --nictype2 virtio --macaddress2 08005A11F155
VBoxManage modifyvm "$VM" --bioslogodisplaytime 1
VBoxManage modifyvm "$VM" --natpf1 "guestssh,tcp,127.0.0.1,${SSH_PORT},,22" 
VBoxManage modifyvm "$VM" --natpf1 "guestwww,tcp,127.0.0.1,${HTTP_PORT},,9292"
VBoxManage modifyvm "$VM" --natdnshostresolver1 on
}

function createShares {
# put 'ssh' and 'vmshare' into $SSHCONFIG_PATH
mkdir -p $SSHCONFIG_PATH/ssh/mersdk
VBoxManage sharedfolder add "$VM" --name ssh --hostpath $SSHCONFIG_PATH/ssh
mkdir -p $SSHCONFIG_PATH/vmshare/ssh/private_keys/engine
MYCWD=$PWD
cd $SSHCONFIG_PATH/vmshare/ssh/private_keys/engine
ssh-keygen -t rsa -N "" -f mersdk
cp mersdk.pub $SSHCONFIG_PATH/ssh/mersdk/authorized_keys
cd $MYCWD
VBoxManage sharedfolder add "$VM" --name config --hostpath $SSHCONFIG_PATH/vmshare

# and then 'targets' and 'home' for $INSTALL_PATH
mkdir -p $INSTALL_PATH/targets
VBoxManage sharedfolder add "$VM" --name targets --hostpath $INSTALL_PATH/targets
VBoxManage sharedfolder add "$VM" --name home --hostpath $INSTALL_PATH
}

function startVM {
VBoxManage startvm "$VM"
}


function installTarget {
    # the dumps directory is created outside the VM
    mkdir -p $INSTALL_PATH/dumps

    echo "Installing $1 to $VM"
    if [ "$(echo $1 | grep i486)" != "" ]; then
	echo "This is i486 target"
	TARGET_FILENAME="Jolla-latest-Sailfish_SDK_Target-i486.tar.bz2"
	TOOLCHAIN="Mer-SB2-i486"
    else
	TARGET_FILENAME="Jolla-latest-Sailfish_SDK_Target-armv7hl.tar.bz2"
	TOOLCHAIN="Mer-SB2-armv7hl"
    fi

    if [[ ! -f $TARGET_FILENAME ]]; then
	echo "$TARGET_FILENAME does not exist!"
	return
    fi

    echo "We're waiting here for Mer VDI to come up.."
    cp $TARGET_FILENAME $INSTALL_PATH/

    echo "Creating target..."
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p $SSH_PORT -i $SSHCONFIG_PATH/vmshare/ssh/private_keys/engine/mersdk mersdk@localhost "sdk-manage --target --install --jfdi \"$1\"  \"$TOOLCHAIN\" \"file:///home/mersdk/share/$TARGET_FILENAME\""

    echo "Saving target dumps"
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p $SSH_PORT -i $SSHCONFIG_PATH/vmshare/ssh/private_keys/engine/mersdk mersdk@localhost "sb2 -t $1 qmake -query" > $INSTALL_PATH/dumps/qmake.query.$1

    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p $SSH_PORT -i $SSHCONFIG_PATH/vmshare/ssh/private_keys/engine/mersdk mersdk@localhost "sb2 -t $1 gcc -dumpmachine" > $INSTALL_PATH/dumps/gcc.dumpmachine.$1
}

function checkVBox {
# check that VBox is 4.3 or newer - affects the sataport count.
VBOX_VERSION=$(VBoxManage --version | cut -f -2 -d '.')
VBOX_TOCHECK="4.3"
echo "Using VirtualBox v$VBOX_VERSION"
if [ $(echo "$VBOX_VERSION >= $VBOX_TOCHECK" | bc) -eq 1 ];then
    SATACOMMAND="--portcount"
else
    SATACOMMAND="--sataportcount"
fi
}

function initPaths {
INSTALL_PATH=$PWD/mersdk
mkdir -p $INSTALL_PATH
rm -rf $INSTALL_PATH/*
SSHCONFIG_PATH=$PWD/sshconfig
mkdir -p $SSHCONFIG_PATH
rm -rf $SSHCONFIG_PATH/*
}

function checkIfVMexists {
if [ "$(VBoxManage list vms 2>&1 | grep \"$VM\")" != "" ];then
	echo "$VM already exists"
	VBoxManage unregistervm "$VM" --delete
	echo "Sleeping 5 seconds to let the VM unregister"
	sleep 5
fi
}

function checkForVDI {
    if [[ ! -f "$VDI" ]];then
	echo "VDI file \"$VDI\" does not exist."
	exit 1
    fi
}

function packVM {
echo "Creating 7z package"
# Shut down the VM so it won't interfere (make sure it's down). This
# will probably fail because the shutdown has already done its job, so
# ignore any error output.
VBoxManage controlvm "$VM" poweroff 2>/dev/null
# remove target archive files
rm -f $INSTALL_PATH/*.tar.bz2
# remove stuff that is not meant for the target
rm -rf $INSTALL_PATH/.bash_history
# copy the used VDI file:
echo "Hard linking $PWD/$VDI => $INSTALL_PATH/mer.vdi"
ln -P $PWD/$VDI $INSTALL_PATH/mer.vdi
# and 7z the mersdk with ultra compression
7z a -mx=$OPT_COMPRESSION mersdk.7z $INSTALL_PATH/
}

usage() {
    cat <<EOF
Create mersdk.7z

Usage:
   $0 [OPTION] [VM_NAME]

Options:
   -f | --vdi-file <vdi>    use this vdi file
   -c | --compression <0-9> compression level of 7z [9]
   -u | --unregister        unregister the created VM at the end of run
   -h | --help              this help

EOF

    # exit if any argument is given
    [[ -n "$1" ]] && exit 1
}

# BASIC EXECUTION STARTS HERE:

# ultra compression by default
OPT_COMPRESSION=9
OPT_UNREGISTER=0
OPT_VM=
OPT_VDI=

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
	-u | --unregister ) shift
	    OPT_UNREGISTER=1
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
    VDIFILE=$(find . -iname "*.vdi")
fi

# check if we want to do 'MerSDK.build' or something else.
if [[ -z $OPT_VM ]];then
    VM=MerSDK.build
else
    VM=$OPT_VM
fi

# set some global variables 
SSH_PORT=2222
HTTP_PORT=8080

# get our VDI's formatted filename.
if [[ -n $VDIFILE ]]; then
    VDI=$(basename $VDIFILE)
fi

# check if we even have files
checkForVDI

echo "Creating $VM, compression=$OPT_COMPRESSION, vdi=$VDI"

# clear our workarea:
initPaths

# first do some preliminary checks
checkVBox
checkIfVMexists

# all go, let's do it:
echo "Create new $VM"
createVM
createShares
startVM

# then we install targets to the VDI:
for targetname in "SailfishOS-i486-x86" "SailfishOS-armv7hl"
do
    installTarget $targetname
done

# shut the VM down cleanly so that it has time to flush its disk
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p $SSH_PORT -i $SSHCONFIG_PATH/vmshare/ssh/private_keys/engine/mersdk mersdk@localhost "sdk-shutdown"
echo "Giving VM 5 seconds to really shut down"
sleep 5

# wrap it all up into 7z file for installer:
packVM

if [[ $OPT_UNREGISTER -eq 1 ]]; then
# finally delete the virtual machine we used
    echo "Unregistering $VM"
    VBoxManage unregistervm "$VM" --delete
fi


