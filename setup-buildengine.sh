#!/bin/bash

#set -x

function createvm {
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

function createshares {
mkdir -p $INSTALL_PATH/ssh/mersdk
VBoxManage sharedfolder add "$VM" --name ssh --hostpath $INSTALL_PATH/ssh
mkdir -p $INSTALL_PATH/vmshare/ssh/private_keys/engine
MYCWD=$PWD
cd $INSTALL_PATH/vmshare/ssh/private_keys/engine
ssh-keygen -t rsa -N "" -f mersdk
cp mersdk.pub $INSTALL_PATH/ssh/mersdk/authorized_keys
cd $MYCWD
VBoxManage sharedfolder add "$VM" --name config --hostpath $INSTALL_PATH/vmshare
VBoxManage sharedfolder add "$VM" --name home --hostpath $INSTALL_PATH
mkdir -p $INSTALL_PATH/targets
VBoxManage sharedfolder add "$VM" --name targets --hostpath $INSTALL_PATH/targets
}

function startvm {
VBoxManage startvm "$VM"
}


function installtargets {
for targetname in $(ls *.tar.bz2)
do
	cp $targetname $INSTALL_PATH
done
}

# check that VBox is 4.3 or newer - affects the sataport count.
VBOX_VERSION=$(virtualbox --help | grep "VirtualBox Manager" | cut -d" " -f5 | cut -d"." -f1,2)
VBOX_TOCHECK="4.3"
if [ $(echo "$VBOX_VERSION >= $VBOX_TOCHECK" | bc) -eq 1 ];then
	echo "VBox is fresh enough."
	SATACOMMAND="--portcount"
else
	 SATACOMMAND="--sataportcount"
fi

INSTALL_PATH=$PWD/mersdk
rm -rf $INSTALL_PATH
mkdir $INSTALL_PATH

# check if we even have files
VDIFILE=$(find . -iname "*.vdi")

if [ "$1" == "" ];then
	echo "no params given, going with defaults"
	VM=MerSDK
else
	VM=$1
fi

SSH_PORT=2222
HTTP_PORT=8080
VDI=$(basename $VDIFILE)


if [ "$(VBoxManage list vms 2>&1 | grep \"$VM\")" != "" ];then
	echo "$VM already exists"
	VBoxManage unregistervm "$VM" --delete
fi

echo "Create new $VM"

createvm
createshares
startvm
installtargets
