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

mkdir -p "$NEW" || exit

for pkg in "$OLD"/*.7z{,.meta}; do
    $CP --target-directory "$NEW" "$pkg" || exit
done

for platf in linux-{32,64} mac windows; do
    mkdir -p "$NEW/$platf" || exit
    for pkg in "$OLD/$platf"/*.7z; do
	$CP --target-directory "$NEW/$platf" "$pkg" || exit
    done
done

if [[ -L "$OLD/targets" ]]; then
    $CP --target-directory "$NEW" "$OLD/targets" || exit
else
    mkdir -p "$NEW"/targets || exit
    $CP --target-directory "$NEW"/targets "$OLD"/targets/* || exit
    sed -i "s,/$OLD/,/$NEW/," "$NEW"/targets/targets.json || exit
fi

if [[ -L "$OLD/emulators" ]]; then
    $CP --target-directory "$NEW" "$OLD/emulators" || exit
else
    mkdir -p "$NEW"/emulators || exit
    $CP --target-directory "$NEW"/emulators "$OLD"/emulators/* || exit
fi

# released versions are read-only
chmod -R +w "$NEW" || exit
