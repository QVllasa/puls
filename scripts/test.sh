#!/bin/zsh
# Führt die Tests aus – auch ohne Xcode (nur mit den Command Line Tools).
set -euo pipefail
cd "$(dirname "$0")/.."
CLT=/Library/Developer/CommandLineTools/Library/Developer
if [[ -d "$CLT/Frameworks/Testing.framework" ]] && ! xcode-select -p | grep -q Xcode.app; then
    swift test -Xswiftc -F -Xswiftc $CLT/Frameworks -Xlinker -F -Xlinker $CLT/Frameworks \
        -Xlinker -rpath -Xlinker $CLT/Frameworks -Xlinker -rpath -Xlinker $CLT/usr/lib "$@"
else
    swift test "$@"
fi
