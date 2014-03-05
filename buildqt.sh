#!/bin/bash

set -x

QTSRC=$1

CWD=$PWD

if [ -f $QTSRC/Makefile ]; then
	cd $QTSRC
	git clean -xdf
	cd $CWD
fi


function configure_static_qt4 () {
	cd $QTSRC
	./configure -opensource -release -static -accessibility -qt-zlib -qt-libtiff -qt-libpng -qt-libmng -qt-libjpeg -no-phonon -no-dbus -no-opengl -no-qt3support -no-webkit -no-xmlpatterns -no-svg -nomake examples -nomake demos -prefix $1 -confirm-license
}

function configure_qt4 () {
	$QTSRC/configure -release -no-scripttools -qt-zlib -qt-libtiff -qt-libpng -qt-libmng -qt-libjpeg -opensource -confirm-license -nomake examples -nomake demos -prefix $PWD -DENABLE_VIDEO=0 -gtkstyle
}

if [ "$1" == "" ];then
	echo "usage: $0 <QTSRC> <static>"
	exit 1;
fi

if [ "$2" == "static" ];then
	configure_static_qt4 $3
else
	configure_qt4
fi

make -j$(getconf _NPROCESSORS_ONLN)
make install

