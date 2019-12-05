#!/bin/bash
#
# Copyright (C) 2019 Jolla Ltd.
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

# Read VDI header on stdin and output its capacity in megabytes
#
# See https://forums.virtualbox.org/viewtopic.php?p=29267#p29267 for the
# description of VDI header structure
vdi_capacity()
{
    local hex_capacity=
    hex_capacity=$(od --skip-bytes=$((0x170)) --read-bytes=8 \
        --address-radix=n --format=x1 --width=1 --output-duplicates \
        |tac |tr -d ' \n') || return
    echo $((0x$hex_capacity>>20))
}

target_image_to_target_name()
{
    local name=$1
    name=${name%.tar.7z}
    name=${name/-Sailfish_SDK_Target-/-}
    name=${name//_/}
    printf '%s\n' "$name"
}

target_image_to_tooling_image()
{
    local name=$1
    name=${name%-Sailfish_SDK_Target-*}-Sailfish_SDK_Tooling-i486.tar.7z
    printf '%s\n' "$name"
}

target_name_to_tooling_name()
{
    local name=$1
    name=${name%-*}
    printf '%s\n' "$name"
}

make_targets_json()
{
    local url_prefix=$1
    local target_images=$2

    target_images=$(sort --version-sort --reverse <<<"$target_images")

    cat <<END || return
# This file is used by the SDK webapp to present a list of pre-selected targets for
# the Mer SDK to offer for installation
#
[
END
    local target_image=
    for target_image in $target_images; do
        local tooling_image=$(target_image_to_tooling_image "$target_image")
        local target_name=$(target_image_to_target_name "$target_image")
        local tooling_name=$(target_name_to_tooling_name "$target_name")

        cat <<END || return
    { "name": "$target_name",
      "url": "$url_prefix/$target_image",
      "tooling_name": "$tooling_name",
      "tooling_url": "$url_prefix/$tooling_image" },
END
    done |sed '$s/,$//'

    echo "]"
}

update_remote_targets_json()
{
    local targets_upload_path=$1

    local real_upload_path=
    real_upload_path=$(ssh "$OPT_UPLOAD_USER@$OPT_UPLOAD_HOST" \
        "readlink --canonicalize $OPT_UPLOAD_PATH") || return
    local real_targets_dir=
    real_targets_dir=$(ssh "$OPT_UPLOAD_USER@$OPT_UPLOAD_HOST" \
        "readlink --canonicalize $targets_upload_path") || return
    local relative_download_path=
    relative_download_path=${real_targets_dir#$real_upload_path/}

    # real_targets_dir not under real_upload_path?
    if [[ $relative_download_path == /* ]]; then
        fatal "Cannot determine relative download path"
        return 1
    fi

    local target_images=
    target_images=$(ssh "$OPT_UPLOAD_USER@$OPT_UPLOAD_HOST" \
        "find $targets_upload_path/ -name '*-Sailfish_SDK_Target-*.7z' -printf '%f\\n'") || return

    if [[ ! $target_images ]]; then
        fatal "No images found in the upload location. Cannot update targets.json"
        return 1
    fi

    local url_prefix=$DEF_URL_PREFIX/$relative_download_path
    local targets_json=
    targets_json=$(make_targets_json "$url_prefix" "$target_images") || return

    ssh "$OPT_UPLOAD_USER@$OPT_UPLOAD_HOST" "tee $targets_upload_path/targets.json >/dev/null" \
        <<<"$targets_json" || return
}
