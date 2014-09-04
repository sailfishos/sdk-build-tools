## SDK Build Scripts

### Overview

The scripts in this project are used to build Sailfish SDK in its
production environment. They have some assumptions about the host
environment, but may offer command line options for changing the
default values. The scripts can act as a starting point for adapting
them for personal use if so desired.

Building Qt4 and Qt5 is only necessary once and whenever patches are
applied, otherwise they can be left in the built state and utilized in
subsequent Qt Creator builds.

Qt4 is required for Installer Framework, Qt5 is required for Qt Creator.

### Scripts

Most of the scripts offer a `--help` option.

* `buildqt.sh` - builds Qt4
* `buildqt5.sh` - builds Qt5
* `buildqtc.sh` - builds Qt Creator and cross-gdb for *i486* and *armv7hl* architectures
* `buildicu.sh` - builds the ICU library for Linux and Windows (required for Webkit)
* `buildifw.sh` - builds the Qt Installer Framework binaries
* `buildmaster.sh` - start one or more build tasks in a build host

The other scripts are various helper scripts mostly to package files
into a format suitable for the Installer FW.

### Build hosts

The SDK builds are made in the following host environments:

* Mac:     OS X 10.8.5
* Linux:   Ubuntu 10.04 32/64 bit
* Windows: Windows 7 32 bit

`These are also the oldest host operating system versions the SDK is supported in.`

### Qt versions required for build

* Qt4 from `git://gitorious.org/qt/qt.git` tag `v4.8.5` and fix for [QTBUG-26844][6]
* also https://qt.gitorious.org/qt/qtscript/commit/24d678ce9c3996f46d1069c2b1193e7ec1083fc8

* Qt5 from `http://download.qt-project.org/archive/qt/5.2/5.2.1/single/`
* Qt Installer FW from `git://gitorious.org/installer-framework/installer-framework.git` branch `1.6`

### ICU version

ICU library is required for building Webkit in Linux and in Windows.

For Linux build from sources using the `buildicu.sh` script:

* http://download.icu-project.org/files/icu4c/4.2.1/icu4c-4_2_1-src.tgz

For Windows use a pre-built package:

* http://download.icu-project.org/files/icu4c/4.8.1.1/icu4c-4_8_1_1-Win32-msvc10.zip

### Linux

The following additional packages are required in Ubuntu 10.04

* `build-essential` `pkg-config` `git` `libgtk2.0-dev` `chrpath` `p7zip-full` `libncurses5-dev` `libdbus-1-dev` `ruby` `libgl1-mesa-dev`
  `"^libxcb.*"` `libx11-xcb-dev` `libxrender-dev` `libxi-dev` `flex` `bison` `gperf` `libxslt-dev`

### Mac

The following additional software is required in the build Mac.

* `Xcode 5`, [p7zip][1] and [wget][7].

[1]: http://sourceforge.net/projects/p7zip/
[7]: https://www.gnu.org/software/wget/

### Windows

Windows build uses [Visual Studio Express 2013 for Windows Desktop][2] and [MinGW][4] compilers in a bash
shell provided by a combination of [msysgit][3] and MinGW environments. Also [7-Zip][5] is required on the command line.

Other build requirements include `perl`, `python` and `ruby` and they are documented [here][7].

[2]: http://www.visualstudio.com/en-us/downloads
[3]: http://code.google.com/p/msysgit/
[4]: http://sourceforge.net/projects/mingw/files/Installer/
[5]: http://www.7-zip.org/
[6]: https://bugreports.qt-project.org/browse/QTBUG-26844
[7]: http://qt-project.org/doc/qt-5/windows-requirements.html

