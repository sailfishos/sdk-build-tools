#!/bin/bash

VERSION=4.8.5

if [ "$1" == "" ];then
  echo "usage:" "$0 <builddir> <clean>"
  exit 1
fi
if [ "$2" == "clean" ];then
  if [ "$2" == "$PWD" ];then
     echo "no, not your homedir."
     exit 1
  fi
  rm -rf $1
fi

CWD=$PWD
mkdir -p $1
cd $1
#git clone git@gitorious.org:qt/qt.git
cd qt
#git checkout $VERSION

cd $CWD
QTBUILDDIR=Qt-$VERSION-Build-__________WITH_PADDING________
mkdir -p $QTBUILDDIR
cd $QTBUILDDIR
$CWD/$1/qt/configure -release -no-scripttools -qt-zlib -qt-libtiff -qt-libpng -qt-libmng -qt-libjpeg -opensource -confirm-license -nomake examples -nomake demos -prefix $PWD -DENABLE_VIDEO=0 -gtkstyle

#make -j$(getconf _NPROCESSORS_ONLN)
#make install
