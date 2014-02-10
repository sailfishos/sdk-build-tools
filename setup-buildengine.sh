#!/bin/bash

#
# This is preliminary build script to install targets to Mer SDK VM and pack it ready
# for SDK Installer's build.
# (c) 2013 Jolla Ltd. Contact: Jarko Vihriälä <jarko.vihriala@jolla.com>
# Licence: Jolla Proprietary until further notice.
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


function copyTargets {
for targetfilename in $(ls *.tar.bz2)
do
	cp $targetfilename $INSTALL_PATH
done
}

function installTarget {
echo "Installing $1 to $VM"
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p $SSH_PORT -i $SSHCONFIG_PATH/vmshare/ssh/private_keys/engine/mersdk mersdk@localhost "\
	mkdir -p dumps"
if [ "$(echo $1 | grep i486)" != "" ];then
	echo "This is i486 target"
	TARGET_FILENAME="Jolla-latest-Sailfish_SDK_Target-i486.tar.bz2"
	TOOLCHAIN="Mer-SB2-i486"
else
	TARGET_FILENAME="Jolla-latest-Sailfish_SDK_Target-armv7hl.tar.bz2"
	TOOLCHAIN="Mer-SB2-armv7hl"
fi
	echo "We're waiting here to Mer VDI to come up.."
	cp $TARGET_FILENAME $INSTALL_PATH/
	ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p $SSH_PORT -i $SSHCONFIG_PATH/vmshare/ssh/private_keys/engine/mersdk mersdk@localhost "\
		sdk-manage --target --install --jfdi \"$1\"  \"$TOOLCHAIN\" \"file:///home/mersdk/$TARGET_FILENAME\""
	ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p $SSH_PORT -i $SSHCONFIG_PATH/vmshare/ssh/private_keys/engine/mersdk mersdk@localhost "\
		sb2 -t $1 qmake -query > dumps/qmake.query.$1 && sb2 -t $1 gcc -dumpmachine > dumps/gcc.dumpmachine.$1"
}

function checkVBox {
# check that VBox is 4.3 or newer - affects the sataport count.
VBOX_VERSION=$(virtualbox --help | grep "VirtualBox Manager" | cut -d" " -f5 | cut -d"." -f1,2)
VBOX_TOCHECK="4.3"
if [ $(echo "$VBOX_VERSION >= $VBOX_TOCHECK" | bc) -eq 1 ];then
	echo "VBox is fresh enough."
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
fi
}

function checkForVDI {
if [ "$VDIFILE" == "" ];then
	echo "No VDI files found."
	exit
fi
}

function packVM {
# Shut down the VM so it won't interfere.
VBoxManage controlvm "$VM" poweroff
# remove target archive files
rm -f $INSTALL_PATH/*.tar.bz2
# remove stuff that is not meant for the target
rm -rf $INSTALL_PATH/.bash_history
# copy the used VDI file:
cp $PWD/$VDI $INSTALL_PATH/mer.vdi
# and 7z the mersdk!
7z a mersdk.7z $INSTALL_PATH/
}

# BASIC EXECUTION STARTS HERE:
# check if we even have files
VDIFILE=$(find . -iname "*.vdi")
checkForVDI

# check if we want to do 'MerSDK' or something else.
if [ "$1" == "" ];then
	echo "no params given, going with defaults"
	VM=MerSDK
else
	VM=$1
fi

# set some global variables 
SSH_PORT=2222
HTTP_PORT=8080

# get our VDI's formatted filename.
VDI=$(basename $VDIFILE)

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

# finally wrap it all up into 7z file for installer:
packVM







