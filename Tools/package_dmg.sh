#!/bin/zsh
set -eu
cd "${0:A:h}/.."
app="${1:?Usage: package_dmg.sh /path/to/MenuSlim.app /path/to/output.dmg}"
output="${2:?Missing output DMG path}"
[[ -d "$app/Contents" ]] || { print -u2 'App bundle not found'; exit 1; }
[[ ! -e "$output" ]] || { print -u2 'Output already exists'; exit 1; }
codesign --verify --strict "$app"
mkdir -p build "${output:h}"
staging=$(mktemp -d "$PWD/build/dmg.XXXXXX")
trap 'rm -rf "$staging"' EXIT
ditto "$app" "$staging/MenuSlim.app"
ln -s /Applications "$staging/Applications"
mkdir -p "$staging/.background"
xcrun swift Tools/render_installer.swift "$staging/.background/installer.png"
python3 Tools/installer_layout.py "$staging/.DS_Store" 'MenuSlim 1.0.0'
cp docs/INSTALL.txt "$staging/.background/INSTALL.txt"
cp docs/licenses/dsstore-BSD-3-Clause.txt "$staging/.background/THIRD-PARTY-LICENSE.txt"
hdiutil create -quiet -format UDZO -volname 'MenuSlim 1.0.0' -srcfolder "$staging" "$output"
hdiutil verify "$output"
