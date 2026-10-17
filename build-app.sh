#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
cd "$script_dir"
swift build -c release

install_dir="${PROMPTLY_INSTALL_DIR:-$HOME/Applications}"
app_path="$install_dir/Promptly.app"
signing_identity="${PROMPTLY_SIGNING_IDENTITY:--}"
mkdir -p "$install_dir"
rm -rf "$app_path"
mkdir -p "$app_path/Contents/MacOS"
cp "Info.plist" "$app_path/Contents/Info.plist"
cp ".build/release/ChoiceLens" "$app_path/Contents/MacOS/ChoiceLens"
# Remove Finder metadata before signing; it can invalidate an app signature.
xattr -cr "$app_path"
codesign --force --sign "$signing_identity" "$app_path"
echo "Built $app_path"
