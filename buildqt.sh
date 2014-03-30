#!/bin/bash
#
# This will use the current directory to build dynamic and static
# versions of qt4.
#
# Copyright (C) 2014 Jolla Oy
#
# Qt4 sources must be found from the current user's home directory
# $HOME/invariant/qt or in case of Windows in C:\invariant\qt
#

export LC_ALL=C

UNAME_SYSTEM=$(uname -s)
UNAME_ARCH=$(uname -m)

if [[ $UNAME_SYSTEM == "Linux" ]] || [[ $UNAME_SYSTEM == "Darwin" ]]; then
    BASEDIR=$HOME/invariant
    SRCDIR_QT=$BASEDIR/qt

    DYN_BUILD_DIR=$BASEDIR/qt-4.8.5-build_______________padding___________________
    STATIC_BUILD_DIR=$BASEDIR/qt-4.8.5-static-build
else
    BASEDIR="/c/invariant"
    SRCDIR_QT="$BASEDIR/qt"

    DYN_BUILD_DIR="$BASEDIR/build-qt-dynamic"
    STATIC_BUILD_DIR="$BASEDIR/build-qt-static"

    MY_MKSPECDIR=$SRCDIR_QT/mkspecs/win32-msvc2010
fi

build_static_qt_windows() {
    rm -rf   $STATIC_BUILD_DIR
    mkdir -p $STATIC_BUILD_DIR
    pushd    $STATIC_BUILD_DIR

    cat <<EOF > build-stat.bat
@echo off

PATH=%PATH%;c:\invariant\bin

call "%programfiles%\Microsoft Visual Studio 10.0\VC\vcvarsall.bat"
call "C:\invariant\qt\configure.exe" -release -platform win32-msvc2010 -qt-zlib -qt-libtiff -qt-libpng -qt-libmng -qt-libjpeg -opensource -confirm-license -nomake examples -nomake demos -no-qt3support -no-webkit -no-xmlpatterns -no-dbus -no-declarative -no-phonon -no-opengl -static -prefix
 
call jom
call nmake install

EOF

    # replace the conf file with the proper one for this build
    cp $MY_MKSPECDIR/qmake.conf.static $MY_MKSPECDIR/qmake.conf
    cmd //c build-stat.bat

    popd
}

build_dynamic_qt_windows() {
    rm -rf   $DYN_BUILD_DIR
    mkdir -p $DYN_BUILD_DIR
    pushd    $DYN_BUILD_DIR

    cat <<EOF > build-dyn.bat
@echo off

PATH=%PATH%;c:\invariant\bin

call "%programfiles%\Microsoft Visual Studio 10.0\VC\vcvarsall.bat"
call "C:\invariant\qt\configure.exe" -release -platform win32-msvc2010 -no-scripttools -qt-zlib -qt-libtiff -qt-libpng -qt-libmng -qt-libjpeg -opensource -confirm-license -nomake examples -nomake demos -developer-build -prefix
 
call jom
call nmake install

EOF

    # replace the conf file with the proper one for this build
    cp $MY_MKSPECDIR/qmake.conf.dyn $MY_MKSPECDIR/qmake.conf

    cmd //c build-dyn.bat
    popd
}

# Windows needs different options in the mkspec for static and dynamic
# builds.
#
# http://doc-snapshot.qt-project.org/qtifw-master/ifw-getting-started.html
#
# If you are using e.g. the Microsoft Visual Studio 2010 compiler, you
# edit mkspecs\win32-msvc2010\qmake.conf and replace in the CFLAGS
# sections '-MD' with '-MT'. Furthermore you should remove
# 'embed_manifest_dll' and 'embed_manifest_exe' from CONFIG
#

prepare_windows_build() {
    local orig_conf=$MY_MKSPECDIR/qmake.conf

    # if the created file exists, return
    [[ -e "$orig_conf.static" ]] && return

    # make a copy of the orig file
    cp $orig_conf $MY_MKSPECDIR/$orig_conf.dyn

    # create a static build version
    sed -e "s/embed_manifest_dll embed_manifest_exe//g" -e "s/-MD/-MT/g" $orig_conf > $MY_MKSPECDIR/$orig_conf.static
}

configure_static_qt4() {
    $SRCDIR_QT/configure -static -opensource -confirm-license -release -qt-zlib -qt-libtiff -qt-libpng -qt-libmng -qt-libjpeg -no-phonon -no-phonon-backend -no-dbus -no-opengl -no-qt3support -no-webkit -no-xmlpatterns -no-svg -nomake examples -nomake demos -silent -gtkstyle -no-icu -DENABLE_VIDEO=0 -accessibility -prefix $PWD 
}

configure_dynamic_qt4() {
    $SRCDIR_QT/configure -release -qt-zlib -qt-libtiff -qt-libpng -qt-libmng -qt-libjpeg -opensource -confirm-license -nomake examples -nomake demos -prefix $PWD -no-phonon -no-phonon-backend -gtkstyle -DENABLE_VIDEO=0 -no-icu -silent
}

build_dynamic_qt() {
    rm -rf   $DYN_BUILD_DIR
    mkdir -p $DYN_BUILD_DIR
    pushd    $DYN_BUILD_DIR
    configure_dynamic_qt4
    make -j$(getconf _NPROCESSORS_ONLN)
    make install
    popd
}

build_static_qt() {
    rm -rf   $STATIC_BUILD_DIR
    mkdir -p $STATIC_BUILD_DIR
    pushd    $STATIC_BUILD_DIR
    configure_static_qt4
    make -j$(getconf _NPROCESSORS_ONLN)

# no need to install according to
# http://doc-snapshot.qt-project.org/qtifw-master/ifw-getting-started.html
#    make install

    popd
}

fail() {
    echo "FAIL: $@"
    exit 1
}

if [[ ! -d $BASEDIR ]]; then
    fail "directory [$BASEDIR] does not exist"
fi

if [[ ! -d $SRCDIR_QT ]]; then
    fail "directory [$SRCDIR_QT] does not exist"
fi

pushd $BASEDIR || exit 1

if [[ $UNAME_SYSTEM == "Linux" ]] || [[ $UNAME_SYSTEM == "Darwin" ]]; then
    build_dynamic_qt
    build_static_qt
else
    prepare_windows_build
    build_dynamic_qt_windows
    build_static_qt_windows
fi

popd
