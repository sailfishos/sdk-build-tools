#!/bin/bash
#
# This will use the current directory to build dynamic and static
# versions of qt4.
#
# Qt4 sources must be found from the current user's home directory
# $HOME/invariant/qt
#

export LC_ALL=C

BASEDIR=$HOME/invariant
SRCDIR_QT=$BASEDIR/qt

DYN_BUILD_DIR=$BASEDIR/qt-4.8.5-build_______________padding___________________
STATIC_BUILD_DIR=$BASEDIR/qt-4.8.5-static-build

configure_static_qt4()
{
    $SRCDIR_QT/configure -static -opensource -confirm-license -release -qt-zlib -qt-libtiff -qt-libpng -qt-libmng -qt-libjpeg -no-phonon -no-phonon-backend -no-dbus -no-opengl -no-qt3support -no-webkit -no-xmlpatterns -no-svg -nomake examples -nomake demos -silent -gtkstyle -no-icu -DENABLE_VIDEO=0 -accessibility -prefix $PWD 
}

configure_dynamic_qt4()
{
    $SRCDIR_QT/configure -release -qt-zlib -qt-libtiff -qt-libpng -qt-libmng -qt-libjpeg -opensource -confirm-license -nomake examples -nomake demos -prefix $PWD -no-phonon -no-phonon-backend -gtkstyle -DENABLE_VIDEO=0 -no-icu -silent
}

build_dyn_qt()
{
    rm -rf $DYN_BUILD_DIR
    mkdir -p $DYN_BUILD_DIR
    pushd $DYN_BUILD_DIR
    configure_dynamic_qt4
    make -j$(getconf _NPROCESSORS_ONLN)
    make install
    popd
}

build_static_qt()
{
    rm -rf $STATIC_BUILD_DIR
    mkdir -p $STATIC_BUILD_DIR
    pushd $STATIC_BUILD_DIR
    configure_static_qt4
    make -j$(getconf _NPROCESSORS_ONLN)

# no need to install according to
# http://doc-snapshot.qt-project.org/qtifw-master/ifw-getting-started.html
#    make install

    popd
}

fail()
{
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

build_dyn_qt
build_static_qt

popd
