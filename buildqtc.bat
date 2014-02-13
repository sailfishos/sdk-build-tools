@echo off

set INSTALL_ROOT=D:\QtCreator\Install
set QTDIR=D:\qt-4.8.4-build____PADDING_____MORE_PADDING____
set QMAKESPEC=win32-msvc2010
set QT_PRIVATE_HEADERS=%QTDIR%\install
set VARIANT=SailfishAlpha4
set PATH=%PATH%;C:\Program Files\7-Zip;%QTDIR%\bin

call "C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC\vcvarsall.bat"
call %QTDIR%\bin\qmake D:\QtCreator\digia-qt-creator\qtcreator.pro -r -after "DEFINES+=REVISION=jolla IDE_COPY_SETTINGS_FROM_VARIANT=. IDE_SETTINGSVARIANT=%VARIANT%" QTC_PREFIX=
call nmake
call nmake install
call nmake deployqt
call nmake bindist_installer
