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

Building Qt5 is only required for the generated documentation.

### Scripts

Most of the scripts offer a `--help` option.

* `buildqt.sh` - builds dynamic and static versions of Qt4
* `buildqt5.sh` - builds Qt5 for documentation purposes
* `buildqtc.sh` - builds Qt Creator and cross-gdb for *i486* and *armv7hl* architectures
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
* Qt5 from `git://gitorious.org/qt/qt5.git` tag `v5.1.1`
* Qt Installer FW from `git://gitorious.org/installer-framework/installer-framework.git` branch `1.4`

[6]: https://bugreports.qt-project.org/browse/QTBUG-26844

### Linux

The following additional packages are required in Ubuntu 10.04

* `build-essential` `libgtk2.0-dev` `chrpath` `p7zip-full` `libncurses5-dev`

and additionally for building Qt5 documentation:

* `libgl1-mesa-dev`

### Mac

The following additional software is required in the build Mac.

* `Xcode 5`, [p7zip][1] and [wget][7].

[1]: http://sourceforge.net/projects/p7zip/
[7]: https://www.gnu.org/software/wget/

### Windows

Windows build uses [MSVC2010][2] and [MinGW][4] compilers in a bash
shell provided by a combination of [msysgit][3] and MinGW
environments. Also [7-Zip][5] is required on the command line.

[2]: http://www.visualstudio.com/en-us/downloads#d-2010-express
[3]: http://code.google.com/p/msysgit/
[4]: http://sourceforge.net/projects/mingw/files/Installer/
[5]: http://www.7-zip.org/
