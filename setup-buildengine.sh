#!/bin/bash
#
# SDK build engine creation script
#
# Copyright (C) 2014 Jolla Oy
#

# some default values
OPT_UPLOAD_HOST=10.0.0.20
OPT_UPLOAD_USER=sdkinstaller
OPT_UPLOAD_PATH=/var/www/sailfishos


fatal() {
    echo "FAIL: $@"
    exit 1
}

function createVM {
    VBoxManage createvm --basefolder=$VM_BASEFOLDER --name "$VM" --ostype Linux26 --register
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
    pushd $SSHCONFIG_PATH/vmshare/ssh/private_keys/engine
    ssh-keygen -t rsa -N "" -f mersdk
    cp mersdk.pub $SSHCONFIG_PATH/ssh/mersdk/authorized_keys
    popd

    VBoxManage sharedfolder add "$VM" --name config --hostpath $SSHCONFIG_PATH/vmshare

# and then 'targets' and 'home' for $INSTALL_PATH
    mkdir -p $INSTALL_PATH/targets
    VBoxManage sharedfolder add "$VM" --name targets --hostpath $INSTALL_PATH/targets
    VBoxManage sharedfolder add "$VM" --name home --hostpath $INSTALL_PATH
}

function startVM {
    VBoxManage startvm --type headless "$VM"
}


function installTarget {
    # the dumps directory is created outside the VM
    mkdir -p $INSTALL_PATH/dumps

    echo "Installing $1 to $VM"
    if [ "$(echo $1 | grep i486)" != "" ]; then
	echo "This is i486 target"
	TARGET_FILENAME=$OPT_TARGET_I486
	TOOLCHAIN="Mer-SB2-i486"
    else
	TARGET_FILENAME=$OPT_TARGET_ARM
	TOOLCHAIN="Mer-SB2-armv7hl"
    fi

    if [[ ! -f $TARGET_FILENAME ]]; then
	fatal "$TARGET_FILENAME does not exist!"
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
    rm -rf $INSTALL_PATH
    mkdir -p $INSTALL_PATH

    SSHCONFIG_PATH=$PWD/sshconfig
    rm -rf $SSHCONFIG_PATH
    mkdir -p $SSHCONFIG_PATH

    VM_BASEFOLDER=$PWD/basefolder
    rm -rf $VM_BASEFOLDER
    mkdir -p $VM_BASEFOLDER
}

function checkIfVMexists {
    if [ "$(VBoxManage list vms 2>&1 | grep \"$VM\")" != "" ];then
	echo "$VM already exists. Please remove it from VirtualBox before proceeding."
	exit 1
    fi
}

function checkForRequiredFiles {
    if [[ ! -f "$VDI" ]];then
	fatal "VDI file \"$VDI\" does not exist."
    fi

    if [[ ! -f "$OPT_TARGET_ARM" ]]; then
	fatal "Target file $OPT_TARGET_ARM does not exist."
    fi

    if [[ ! -f "$OPT_TARGET_I486" ]]; then
	fatal "Target file $OPT_TARGET_I486 does not exist."
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
    ln $PWD/$VDI $INSTALL_PATH/mer.vdi
# and 7z the mersdk with ultra compression
    7z a -mx=$OPT_COMPRESSION mersdk.7z $INSTALL_PATH/
}

function checkForRunningVms
{
    local running=$(VBoxManage list runningvms 2>/dev/null)

    if [[ -n $running ]]; then
	echo "These virtual machines are running, please stop them before continuing."
	echo $running
	exit 1
    fi
}

usage() {
    cat <<EOF
Create mersdk.7z an optionally upload it to a server.

Usage:
   $0 -f <vdi> [OPTION] [VM_NAME]

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
   -ta | --target-arm <file>  arm target rootstrap [$OPT_TARGET_ARM]
   -ti | --target-i486 <file> i486 target rootstrap [$OPT_TARGET_I486]
   -un | --unregister         unregister the created VM at the end of run
   -h  | --help               this help

EOF

    # exit if any argument is given
    [[ -n "$1" ]] && exit 1
}

# BASIC EXECUTION STARTS HERE:

# ultra compression by default
OPT_COMPRESSION=9
OPT_UNREGISTER=0
OPT_TARGET_ARM="Jolla-latest-Sailfish_SDK_Target-armv7hl.tar.bz2"
OPT_TARGET_I486="Jolla-latest-Sailfish_SDK_Target-i486.tar.bz2"
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
	-ta | --target-arm ) shift
	    OPT_TARGET_ARM=$1; shift
	    ;;
	-ti | --target-i486 ) shift
	    OPT_TARGET_I486=$1; shift
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
	-h | --help ) shift
	    usage quit
	    ;;
	-y | --non-interactive ) shift
	    OPT_YES=1
	    ;;
	-un | --unregister ) shift
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

# check if we have VBoxManage
VBOX_VERSION=$(VBoxManage --version 2>/dev/null | cut -f -2 -d '.')
if [[ -z $VBOX_VERSION ]]; then
    fatal "VBoxManage not found".
fi

# check for running vms
checkForRunningVms

if [[ -n $OPT_VDI ]]; then
    VDIFILE=$OPT_VDI
else
    # Always require a given vdi file
    # VDIFILE=$(find . -iname "*.vdi" | head -1)

    fatal "VDI file option is required (-f filename.vdi)"
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
checkForRequiredFiles

# clear our workarea:
initPaths

# first do some preliminary checks
checkVBox
checkIfVMexists

# all go, let's do it:
cat <<EOF
Creating $VM, compression=$OPT_COMPRESSION
 MerSDK VDI: $VDI
 ARM target: $OPT_TARGET_ARM
i486 target: $OPT_TARGET_I486
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

createVM
createShares
startVM

# then we install targets to the VDI:
for targetname in "SailfishOS-i486" "SailfishOS-armv7hl"
do
    installTarget $targetname
done

# shut the VM down cleanly so that it has time to flush its disk
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p $SSH_PORT -i $SSHCONFIG_PATH/vmshare/ssh/private_keys/engine/mersdk mersdk@localhost "sdk-shutdown"

echo "Giving VM 10 seconds to really shut down ..."

let wait=1
while [[ $wait -lt 11 ]]; do
    let wait++

    if [[ $(VBoxManage list runningvms | grep -c $VM) -ne 0 ]]; then
	echo "waiting ..."
	sleep 1
    else
	break
    fi

    if [[ $wait -ge 11 ]]; then
	echo "WARNING: $VM did not shut down cleanly!"
    fi
done

# wrap it all up into 7z file for installer:
packVM

if [[ -n "$OPT_UPLOAD" ]]; then
    echo "Uploading mersdk.7z"

    # create upload dir
    ssh $OPT_UPLOAD_USER@$OPT_UPLOAD_HOST mkdir -p $OPT_UPLOAD_PATH/$OPT_UL_DIR/
    scp mersdk.7z $OPT_UPLOAD_USER@$OPT_UPLOAD_HOST:$OPT_UPLOAD_PATH/$OPT_UL_DIR/
fi

if [[ $OPT_UNREGISTER -eq 1 ]]; then
# finally delete the virtual machine we used
    echo "Unregistering $VM"
    VBoxManage unregistervm "$VM" --delete
fi
