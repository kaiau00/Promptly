#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
cd "$script_dir"

# macOS remembers Screen Recording and Keychain access by code signature. An
# ad-hoc signature ("-") changes on every build, so each rebuild re-prompts.
# Signing with the same certificate every time keeps those approvals.
default_identity="ChoiceLens Local Development"
signing_identity="${PROMPTLY_SIGNING_IDENTITY:-$default_identity}"

if [[ "$signing_identity" == "-" ]]; then
    echo "warning: ad-hoc signing; macOS will ask for Screen Recording and Keychain access again after this build." >&2
elif ! security find-identity -p codesigning | grep -qF "\"$signing_identity\""; then
    cat >&2 <<EOF
error: code-signing identity "$signing_identity" was not found in your keychain.

Create a self-signed one once: Keychain Access → Certificate Assistant →
Create a Certificate…, name it "$default_identity", Identity Type
"Self-Signed Root", Certificate Type "Code Signing".

Or set PROMPTLY_SIGNING_IDENTITY to another identity, or to "-" to sign
ad-hoc (macOS will then re-prompt for permissions after every build).
EOF
    exit 1
fi

swift build -c release

install_dir="${PROMPTLY_INSTALL_DIR:-$HOME/Applications}"
app_path="$install_dir/Promptly.app"
mkdir -p "$install_dir"
rm -rf "$app_path"
mkdir -p "$app_path/Contents/MacOS"
cp "Info.plist" "$app_path/Contents/Info.plist"
cp ".build/release/ChoiceLens" "$app_path/Contents/MacOS/ChoiceLens"
# Remove Finder metadata before signing; it can invalidate an app signature.
xattr -cr "$app_path"
codesign --force --sign "$signing_identity" "$app_path"
echo "Built $app_path (signed with: $signing_identity)"
