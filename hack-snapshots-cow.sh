#!/bin/bash
#
# Hack the build engine to ensure snapshots are CoW copies also under Docker
#
# Copyright (C) 2021 Jolla Oy
# Contact: http://jolla.com/
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

# We need to create a .tar image for Docker, so the snapshots would not be CoW
# copies. At the same time we need to create it now to get the host-side copy
# packaged. -> Create them but purge and reset on first boot.

set -e

rm -rf /srv/mer/targets/*.default/*

cat > /usr/lib/oneshot.d/500-sdk-reset-snapshots.sh <<'EOF'
#!/bin/bash
# Script created by setup-buildengine.sh

sdk-manage() { sudo -u mersdk sdk-manage "$@"; }

targets=$(sdk-manage target list --long |awk '($4 == "-") { print $1 }')
for target in $targets; do
    sdk-manage target snapshot --reset=force $target{,.default}
done
EOF

chmod +x /usr/lib/oneshot.d/500-sdk-reset-snapshots.sh
add-oneshot --late 500-sdk-reset-snapshots.sh
ln -sf /usr/lib/systemd/system/oneshot-root-late.service /etc/systemd/system/multi-user.target.wants/
