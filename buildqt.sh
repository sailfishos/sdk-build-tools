#!/bin/bash

if [ "$2" == "static" ]; then
	STATIC="-static"
fi

$1/configure $STATIC -release -no-scripttools -qt-zlib -qt-libtiff -qt-libpng -qt-libmng -qt-libjpeg -opensource -confirm-license -nomake examples -nomake demos -prefix $PWD -DENABLE_VIDEO=0 -gtkstyle

make -j$(getconf _NPROCESSORS_ONLN)
make install
