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
cp docs/INSTALL.txt "$staging/安装说明 Installation.txt"
hdiutil create -quiet -format UDZO -volname 'MenuSlim 1.0.0' -srcfolder "$staging" "$output"
hdiutil verify "$output"
