#!/bin/zsh
set -eu
cd "${0:A:h}/.."
mkdir -p _project/tmp/test/menu-spacing
binary="$PWD/_project/tmp/test/menu-spacing/audit-tests"
trap 'rm -f "$binary"' EXIT
xcrun swiftc Sources/MenuBarAudit.swift Tests/AuditTests.swift -o "$binary"
"$binary"
python3 -m unittest discover -s Tests -v
