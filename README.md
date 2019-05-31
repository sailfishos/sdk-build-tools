## SDK Build Scripts

### Overview

The scripts in this project are used to build Sailfish SDK in its
production environment. They have some assumptions about the host
environment, but may offer command line options for changing the
default values. The scripts can act as a starting point for adapting
them for personal use if so desired.

Building Qt is only necessary once and whenever patches are
applied, otherwise they can be left in the built state and utilized in
subsequent Qt Creator builds.

Static Qt build is required for Installer Framework, dynamic Qt build is
required for Qt Creator and other tools coming with the SDK.

### Scripts

Most of the scripts offer a `--help` option.

* `buildqt5.sh` - builds Qt
* `buildqtc.sh` - builds Qt Creator and cross-gdb for *i486* and *armv7hl* architectures
* `buildicu.sh` - builds the ICU library for Linux and Windows (required for Webkit)
* `buildifw.sh` - builds the Qt Installer Framework binaries
* `buildmaster.sh` - start one or more build tasks in a build host

The other scripts are various helper scripts mostly to package files
into a format suitable for the Installer FW.

### Build hosts

The SDK builds are made in the following host environments:

* Mac:     OS X 10.10
* Linux:   Ubuntu 16.04 32/64 bit
* Windows: Windows 7 32 bit

`These are also the oldest host operating system versions the SDK is supported in.`

### Qt versions required for build

* Qt5 from `http://download.qt.io/archive/qt/5.6/5.6.2/single/`
* Qt Installer FW from `https://github.com/sailfishos/qt-installer-framework` branch `master`

### ICU version

ICU library is required for building Webkit in Linux and in Windows.

For Linux build from sources using the `buildicu.sh` script:

* http://download.icu-project.org/files/icu4c/4.2.1/icu4c-4_2_1-src.tgz

For Windows use a pre-built package:

* http://download.icu-project.org/files/icu4c/4.8.1.1/icu4c-4_8_1_1-Win32-msvc10.zip

### Linux

The following additional packages are required in Ubuntu 16.04

* `build-essential` `p7zip-full` `git` `libgtk2.0-dev` `chrpath` `libncurses5-dev` `libdbus-1-dev`
  `ruby` `libgl1-mesa-dev` `"^libxcb.*"` `libx11-xcb-dev` `libxrender-dev` `libxi-dev` `flex`
  `bison` `gperf` `patchelf`

### Mac

The following additional software is required in the build Mac:

* [Xcode 6 or 7][9], available on the Mac App Store
* `p7zip` and `wget` installed via [MacPorts][1]

[9]: https://itunes.apple.com/fi/app/xcode/id497799835?mt=12
[1]: https://www.macports.org/

The build Mac should be prepared for command line development. To make sure
this is the case, please refer to [Technical Note TN2339][11] "Building from
the Command Line with Xcode FAQ", available in the Apple Mac Developer Library.

[11]: https://developer.apple.com/library/mac/technotes/tn2339/_index.html#//apple_ref/doc/uid/DTS40014588

By default, the build scripts use Qt 5.6.2. To build a different version of Qt,
set the `DEF_QT_VER` variable in the `defaults.sh` script to another version, e.g.:

```
DEF_QT_VER=5.8.0
```

When building p7zip, follow the BUILD instructions in the accompanying README
file. However, to build p7zip (as of writing version 9.38.1) on OS X 10.10 with
Xcode 6, the architecture-specific makefile needs to be modified to use the
correct path for the command line tools. After preparing the makefile with:

```
$ cp makefile.macosx_llvm_64bits makefile.machine
```

change the compiler paths in `makefile.machine` from:

```
CXX=/Developer/usr/bin/llvm-g++
CC=/Developer/usr/bin/llvm-gcc
```

to the paths used by Xcode 6 command line tool shims:

```
CXX=/usr/bin/llvm-g++
CC=/usr/bin/llvm-gcc
```

### Windows

Windows build uses [Visual Studio Express 2015 for Windows Desktop][2] and [MinGW][4] compilers in a bash
shell provided by a combination of [msysgit][3] and MinGW environments. Also [7-Zip][5] is required on the command line.

Other build requirements include `perl`, `python` and `ruby` and they are documented [here][7].

pkg-config and its dependencies (check buildqtc.sh) can be downloaded from locations mentioned [here][8].

[2]: http://www.visualstudio.com/en-us/downloads
[3]: http://code.google.com/p/msysgit/
[4]: http://sourceforge.net/projects/mingw/files/Installer/
[5]: http://www.7-zip.org/
[6]: https://bugreports.qt-project.org/browse/QTBUG-26844
[7]: http://qt-project.org/doc/qt-5/windows-requirements.html
[8]: https://stackoverflow.com/questions/1710922/how-to-install-pkg-config-in-windows
