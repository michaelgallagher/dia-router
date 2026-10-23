#!/bin/zsh
# Build Dia Router, install it to ~/Applications and register it with macOS.
set -euo pipefail

cd "${0:A:h}"

app="build/Dia Router.app"
dest="$HOME/Applications/Dia Router.app"
rules_dir="$HOME/.config/dia-router"

rm -rf build
mkdir -p "$app/Contents/MacOS"
cp Info.plist "$app/Contents/Info.plist"
xcrun swiftc -O -swift-version 5 Sources/main.swift -o "$app/Contents/MacOS/DiaRouter"
codesign --force --sign - "$app"

pkill -x DiaRouter 2>/dev/null || true
mkdir -p "$HOME/Applications"
rm -rf "$dest"
cp -R "$app" "$dest"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$dest"

if [[ ! -f "$rules_dir/rules.json" ]]; then
  mkdir -p "$rules_dir"
  cp rules.example.json "$rules_dir/rules.json"
  echo "Created $rules_dir/rules.json from the example. Edit it to set your rules."
fi

echo "Installed $dest"
