#!/bin/zsh
set -eu
cd "${0:A:h}/.."
app="${1:?Usage: package_pkg.sh /path/to/MenuSlim.app /path/to/output.pkg}"
output="${2:?Missing output PKG path}"
[[ -d "$app/Contents" ]] || { print -u2 'App bundle not found'; exit 1; }
[[ ! -e "$output" ]] || { print -u2 'Output already exists'; exit 1; }
codesign --verify --strict "$app"
mkdir -p build "${output:h}"
staging=$(mktemp -d "$PWD/build/pkg.XXXXXX")
trap 'rm -rf "$staging"' EXIT
mkdir "$staging/root"
ditto "$app" "$staging/root/MenuSlim.app"
pkgbuild --analyze --root "$staging/root" "$staging/components.plist"
python3 - "$staging/components.plist" <<'PY'
import plistlib, sys
from pathlib import Path
path = Path(sys.argv[1])
components = plistlib.loads(path.read_bytes())
assert len(components) == 1 and components[0]['RootRelativeBundlePath'] == 'MenuSlim.app'
components[0]['BundleIsRelocatable'] = False
components[0]['BundleHasStrictIdentifier'] = True
path.write_bytes(plistlib.dumps(components))
PY
pkgbuild --root "$staging/root" --component-plist "$staging/components.plist" \
    --identifier com.yangshuai.MenuSpacing.installer --version 1.0.0 \
    --install-location /Applications --ownership recommended "$output"
