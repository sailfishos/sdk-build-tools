#!/bin/bash

set -x

if [ "$1" == "" ];then
  echo "usage: $0 <qtc installdir> <qtdir> <variant name> <full>"
  exit 1
fi

VARIANT=$4

if [ "$4" == "" ];then
  VARIANT=SailfishAlpha4
fi

if [[ $(uname -m) == "x86_64" ]]; then
	export QMAKESPEC=linux-g++-64
else
	export QMAKESPEC=linux-g++-32
fi

QTC_SRC=$1
export INSTALL_ROOT=$2
export QTDIR=$3
export QT_PRIVATE_HEADERS=$QTDIR/include
export PATH=$QTDIR/bin:$PATH

$QTDIR/bin/qmake $QTC_SRC/qtcreator.pro -r -after "DEFINES+=REVISION=jolla IDE_COPY_SETTINGS_FROM_VARIANT=. IDE_SETTINGSVARIANT=$VARIANT" QTC_PREFIX=

if [ "$5" == "full" ];then
  make -j$(getconf _NPROCESSORS_ONLN)
  make install
  make deployqt
  make bindist_installer
fi
