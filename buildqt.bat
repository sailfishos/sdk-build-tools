@echo off

PATH=%PATH%;C:\MinGW\msys\1.0\bin;D:\QtTools;

call "C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC\vcvarsall.bat"
call "D:\QtSrc\qt\configure.exe" -platform win32-msvc2010 -no-scripttools -qt-zlib -qt-libtiff -qt-libpng -qt-libmng -qt-libjpeg -opensource -confirm-license -nomake examples -nomake demos -nomake -prefix
 
call jom
call nmake install


