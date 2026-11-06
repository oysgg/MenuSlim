#!/bin/zsh
set -eu
cd "${0:A:h}/.."
mkdir -p _project/tmp/test/menu-spacing
binary="$PWD/_project/tmp/test/menu-spacing/audit-tests"
localization="$PWD/_project/tmp/test/menu-spacing/localization-tests"
trap 'rm -f "$binary" "$localization"' EXIT
xcrun swiftc Sources/Localization.swift Sources/MenuBarAudit.swift Tests/AuditTests.swift -o "$binary"
"$binary"
xcrun swiftc Sources/Localization.swift Tests/LocalizationTests.swift -o "$localization"
"$localization" "$PWD/Resources"
python3 -m unittest discover -s Tests -v
