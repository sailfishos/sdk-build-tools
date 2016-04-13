#!/bin/bash

if [[ $# -ne 2 ]]; then
    cat <<EOF
usage: $0 OLD-DIRECTORY NEW-DIRECTORY
Both directories must be specified with path relative to \$(dirname \$0).
EOF
    exit 1
fi

set -e

OLD="$1"
NEW="$2"

CP="cp --no-clobber --verbose --no-dereference --preserve=all"

cd "$(dirname "$0")"

mkdir -p "$NEW"

for pkg in emulator \
    examples \
    mersdk \
    qtdocumentation \
    sailfishdocumentation \
    sailfish-template \
    tutorials; do
    $CP --target-directory "$NEW" "$OLD"/$pkg.7z
done

for platf in linux-{32,64} mac windows; do
    mkdir -p "$NEW"/$platf
    $CP --target-directory "$NEW"/$platf "$OLD"/$platf/InstallerFW.7z
    $CP --target-directory "$NEW"/$platf "$OLD"/$platf/sailfish-gdb-*-$platf.7z
    $CP --target-directory "$NEW"/$platf "$OLD"/$platf/sailfish-qt-creator-$platf.7z
done

mkdir -p "$NEW"/targets
$CP --target-directory "$NEW"/targets "$OLD"/targets/*
sed -i "s,/$OLD/,/$NEW/," "$NEW"/targets/targets.json
