#!/bin/bash
#
# Default configuration shared between SDK build tools
#
# Copyright (C) 2015-2017 Jolla Ltd.
# Contact: Martin Kampas <martin.kampas@jolla.com>
# All rights reserved.
#
# You may use this file under the terms of BSD license as follows:
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#   * Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#   * Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#   * Neither the name of the Jolla Ltd nor the
#     names of its contributors may be used to endorse or promote products
#     derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

# The address of the build host
# Note: This can also be configured dynamically by using the -uh/--uhost
# option in buildmaster.sh
: ${DEF_UPLOAD_HOST:=10.0.0.20}
# The username on the build host
# Note: This can also be configured dynamically by using the -uu/--uuser
# option in buildmaster.sh
: ${DEF_UPLOAD_USER:=sdkinstaller}
# The upload root on the build host
# Note: This can also be configured dynamically by using the -up/--upath
# option in buildmaster.sh
: ${DEF_UPLOAD_PATH:=/var/www/sailfishos}
# The URL pointing to the upload root on the build host
: ${DEF_URL_PREFIX:=http://$DEF_UPLOAD_HOST/sailfishos}

# The download URL for the Windows ICU binaries
DEF_WIN_ICU_DOWNLOAD_URL="$DEF_URL_PREFIX/win32-binary-artifacts/icu/icu4c-4_8_1_1-Win32-msvc10.zip"

# The Qt version to use
DEF_QT_VER=5.12.5

# The Microsoft Visual C++ version to use
DEF_MSVC_VER=2015
DEF_MSVC_VER_ALT=14.0
DEF_MSVC_SPEC=win32-msvc

# The default release version
# Note: This can also be configured dynamically by using the --release
# option in buildmaster.sh
DEF_RELEASE="x.y"

# SDK release cycle
# Note: This can also be configured dynamically by using the --rel-cycle
# option in buildmaster.sh
DEF_RELCYCLE="Stable"

# SDK variant
# Sets the default settings folder name for the Qt Creator and Qt QmlLive
# Note: This can also be configured dynamically by using the -v/--variant
# option in buildmaster.sh
DEF_VARIANT="SailfishOS-SDK"

# SDK pretty variant
# Sets the default base name for the installers and the SDK release name shown
# in the Qt Creator and QmlLive About dialogs
# Note: This can also be configured dynamically by using the -vp/--variant-pretty
# option in buildmaster.sh
DEF_VARIANT_PRETTY="Sailfish 3 SDK"

# ---------------------------------------------------------------------
# General

UNAME_SYSTEM=$(uname -s)
UNAME_ARCH=$(uname -m)

if [[ $UNAME_SYSTEM == "Linux" ]] || [[ $UNAME_SYSTEM == "Darwin" ]]; then
    : ${DEF_PREFIX:=$HOME}
else
    : ${DEF_PREFIX:=/c}
fi

win_path() {
    sed -e 's,^/c$,c:,' -e 's,^/c/,c:\\,' -e 's,/,\\,g' <<<"$1"
}

# no `readlink -f` on macOS
BUILD_TOOLS_SRC=$(cd "$(dirname "$0")" && pwd)

# ---------------------------------------------------------------------
# Qt

# Source directory
DEF_QT_SOURCE_PACKAGE=qt-everywhere-src-$DEF_QT_VER
DEF_QT_SRC_DIR=$DEF_PREFIX/invariant/$DEF_QT_SOURCE_PACKAGE

if [[ $UNAME_SYSTEM == "Linux" ]] || [[ $UNAME_SYSTEM == "Darwin" ]]; then
    # Dynamic Qt build directory on Linux and MacOS
    DEF_QT_DYN_BUILD_DIR=$DEF_PREFIX/invariant/$DEF_QT_SOURCE_PACKAGE-build-rpathpadrpathpad
    # Static Qt build directory on Linux and MacOS
    DEF_QT_STATIC_BUILD_DIR=$DEF_PREFIX/invariant/$DEF_QT_SOURCE_PACKAGE-static-build
else
    # Dynamic Qt build directory on Windows
    DEF_QT_DYN_BUILD_DIR=$DEF_PREFIX/invariant/$DEF_QT_SOURCE_PACKAGE-build-msvc$DEF_MSVC_VER
    # Static Qt build directory on Windows
    DEF_QT_STATIC_BUILD_DIR=$DEF_PREFIX/invariant/$DEF_QT_SOURCE_PACKAGE-static-build-msvc$DEF_MSVC_VER
fi

# ---------------------------------------------------------------------
# ICU

if [[ $UNAME_SYSTEM == "Linux" ]] || [[ $UNAME_SYSTEM == "Darwin" ]]; then
    # ICU build configuration on Linux
    DEF_ICU_SRC_DIR=$DEF_PREFIX/invariant/icu
    DEF_ICU_BUILD_DIR=$DEF_PREFIX/invariant/icu-build
    DEF_ICU_INSTALL_DIR=$DEF_PREFIX/invariant/icu-install
else
    # On Windows upstream ICU binaries are downloaded
    DEF_ICU_DOWNLOAD_DIR=$DEF_PREFIX/invariant
    DEF_ICU_INSTALL_DIR=$DEF_PREFIX/invariant/icu
fi

# ---------------------------------------------------------------------
# Qt Creator

# Source directory
DEF_QTC_SRC_DIR=$DEF_PREFIX/build/sailfish-qtcreator
# Build directory
DEF_QTC_BUILD_SUFFIX=-build
DEF_QTC_BUILD_DIR=$DEF_QTC_SRC_DIR$DEF_QTC_BUILD_SUFFIX
# Install directory
DEF_QTC_INSTALL_SUFFIX=-install
DEF_QTC_INSTALL_ROOT=$DEF_QTC_SRC_DIR$DEF_QTC_INSTALL_SUFFIX

# ---------------------------------------------------------------------
# Qt Linguist

# Install directory
DEF_LINGUIST_INSTALL_ROOT=$DEF_PREFIX/build/linguist-install

# ---------------------------------------------------------------------
# Qt QmlLive

# Source directory
DEF_QMLLIVE_SRC_DIR=$DEF_PREFIX/build/qmllive
# Build directory
DEF_QMLLIVE_BUILD_SUFFIX=-build
DEF_QMLLIVE_BUILD_DIR=$DEF_QMLLIVE_SRC_DIR$DEF_QMLLIVE_BUILD_SUFFIX
# Install directory
DEF_QMLLIVE_INSTALL_SUFFIX=-install
DEF_QMLLIVE_INSTALL_ROOT=$DEF_QMLLIVE_SRC_DIR$DEF_QMLLIVE_INSTALL_SUFFIX

# ---------------------------------------------------------------------
# Installer Framework

# Source directory
DEF_IFW_SRC_DIR=$DEF_PREFIX/invariant/qt-installer-framework
# Build directory
DEF_IFW_BUILD_SUFFIX=-build
DEF_IFW_BUILD_DIR=$DEF_IFW_SRC_DIR$DEF_IFW_BUILD_SUFFIX

# The default name for the Installer Framework package
DEF_IFW_PACKAGE_NAME="InstallerFW.7z"

# ---------------------------------------------------------------------
# Installer

# Source directory
DEF_INSTALLER_SRC_DIR=$DEF_PREFIX/build/sailfish-sdk-installer

# ---------------------------------------------------------------------
# Documentation

# The documentation filter attribute to add to the *.qch files
DEF_DOCS_FILTER_ATTRIBUTE="sailfishos"
# The documentation filter name to add to the *.qch files
# Note: This will show up in the Qt Creator Help section
DEF_DOCS_FILTER_NAME="Sailfish OS"

# ---------------------------------------------------------------------
# Build Engine

# The default base name for the SDK targets
# Note: This will result to targets and kits named as e.g. SailfishOS-<version>-<arch>
DEF_TARGET_BASENAME="SailfishOS"

# ---------------------------------------------------------------------
# Scratchbox2 Images

# The default path to shared location for sb2 images. The '--shared-path' option to
# setup-sb2-images.sh overrides this.
DEF_SHARED_SB2_IMAGES_PATH="targets"

# ---------------------------------------------------------------------
# Emulator

# The default path to shared location for emulator images. The '--shared-path' option to
# setup-emulator.sh overides this.
DEF_SHARED_EMULATORS_PATH="emulators"

# The default base name for emulator images. The '--basename' option to setup-emulator.sh
# overrides this.
DEF_EMULATOR_BASENAME="Sailfish_OS"
