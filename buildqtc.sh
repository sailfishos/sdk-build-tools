#!/bin/bash

if [ "$1" == "" ];then
  echo "usage: $0 <qtdir> <variantid> <full>"
  exit 1
fi

VARIANT=$2

if [ "$2" == "" ];then
  VARIANT=SailfishAlpha4
fi

export INSTALL_ROOT=~/QtCreatorInstall
export QTC_SRC=~/QtCreator/digia-qt-creator
export QTDIR=$1
export QMAKESPEC=linux-g++-64
export QT_PRIVATE_HEADERS=$QTDIR/include
export PATH=$QTDIR/bin:$PATH

$QTDIR/bin/qmake $QTC_SRC/qtcreator.pro -r -after "DEFINES+=REVISION=jolla IDE_COPY_SETTINGS_FROM_VARIANT=. IDE_SETTINGSVARIANT=$VARIANT" QTC_PREFIX=

if [ "$3" == "full" ];then
  make -j$(getconf _NPROCESSORS_ONLN)
  make install
  make deployqt
  make bindist_installer
fi
