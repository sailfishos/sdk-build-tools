#!/bin/bash
#
# Default configuration shared between SDK build tools
#
# Copyright (C) 2015-2016 Jolla Ltd.
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

: ${DEF_UPLOAD_HOST:=10.0.0.20}
: ${DEF_UPLOAD_USER:=sdkinstaller}
: ${DEF_UPLOAD_PATH:=/var/www/sailfishos}
: ${DEF_URL_PREFIX:=http://$DEF_UPLOAD_HOST/sailfishos}

DEF_WIN_ICU_DOWNLOAD_URL="$DEF_URL_PREFIX/win32-binary-artifacts/icu/icu4c-4_8_1_1-Win32-msvc10.zip"
DEF_QT_VER=5.6.2
DEF_MSVC_VER=2015
DEF_MSVC_VER_ALT=14.0
DEF_IFW_VER=2.0.5

DEF_RELEASE="yydd"
DEF_RELCYCLE="Beta"
DEF_VARIANT="SailfishOS-SDK"
DEF_VERSION_DESC="git"

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

BUILD_TOOLS_SRC=$(dirname $0)

# ---------------------------------------------------------------------
# Qt

DEF_QT_SOURCE_PACKAGE=qt-everywhere-opensource-src-$DEF_QT_VER
DEF_QT_SRC_DIR=$DEF_PREFIX/invariant/$DEF_QT_SOURCE_PACKAGE

if [[ $UNAME_SYSTEM == "Linux" ]] || [[ $UNAME_SYSTEM == "Darwin" ]]; then
    DEF_QT_DYN_BUILD_DIR=$DEF_PREFIX/invariant/$DEF_QT_SOURCE_PACKAGE-build
    DEF_QT_STATIC_BUILD_DIR=$DEF_PREFIX/invariant/$DEF_QT_SOURCE_PACKAGE-static-build
else
    DEF_QT_DYN_BUILD_DIR=$DEF_PREFIX/invariant/$DEF_QT_SOURCE_PACKAGE-build-msvc$DEF_MSVC_VER
    DEF_QT_STATIC_BUILD_DIR=$DEF_PREFIX/invariant/$DEF_QT_SOURCE_PACKAGE-static-build-msvc$DEF_MSVC_VER
fi

# ---------------------------------------------------------------------
# ICU

if [[ $UNAME_SYSTEM == "Linux" ]] || [[ $UNAME_SYSTEM == "Darwin" ]]; then
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

DEF_QTC_SRC_DIR=$DEF_PREFIX/build/sailfish-qtcreator
DEF_QTC_BUILD_SUFFIX=-build
DEF_QTC_BUILD_DIR=$DEF_QTC_SRC_DIR$DEF_QTC_BUILD_SUFFIX
DEF_QTC_INSTALL_SUFFIX=-install
DEF_QTC_INSTALL_ROOT=$DEF_QTC_SRC_DIR$DEF_QTC_INSTALL_SUFFIX

# ---------------------------------------------------------------------
# Qt QmlLive

DEF_QMLLIVE_SRC_DIR=$DEF_PREFIX/build/qmllive
DEF_QMLLIVE_BUILD_SUFFIX=-build
DEF_QMLLIVE_BUILD_DIR=$DEF_QMLLIVE_SRC_DIR$DEF_QMLLIVE_BUILD_SUFFIX
DEF_QMLLIVE_INSTALL_SUFFIX=-install
DEF_QMLLIVE_INSTALL_ROOT=$DEF_QMLLIVE_SRC_DIR$DEF_QMLLIVE_INSTALL_SUFFIX

# ---------------------------------------------------------------------
# Installer Framework

DEF_IFW_SRC_DIR=$DEF_PREFIX/invariant/installer-framework-$DEF_IFW_VER
DEF_IFW_BUILD_SUFFIX=-build
DEF_IFW_BUILD_DIR=$DEF_IFW_SRC_DIR$DEF_IFW_BUILD_SUFFIX
DEF_IFW_PACKAGE_NAME="InstallerFW.7z"

# ---------------------------------------------------------------------
# Installer

DEF_INSTALLER_SRC_DIR=$DEF_PREFIX/build/sailfish-sdk-installer

# ---------------------------------------------------------------------
# Documentation

DEF_DOCS_FILTER_ATTRIBUTE="sailfishos"
DEF_DOCS_FILTER_NAME="Sailfish OS"
