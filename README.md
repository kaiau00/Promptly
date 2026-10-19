# Promptly

Native macOS app for a personal, shortcut-driven screen-reading workflow. Use it only where AI assistance is explicitly allowed.

## Quick start

For the simplest setup, download the latest `Promptly.zip` from **Releases**, unzip it, and follow [GETTING_STARTED.md](GETTING_STARTED.md). You do not need Xcode or Terminal for the release download.

## What it does today

- Runs as a menu-bar app, so it does not take focus from the active app.
- Starts with **Control–Shift–|** (the physical backslash key on a US keyboard); change it from Settings to any shortcut with a modifier key.
- Captures the main display only after that shortcut is pressed.
- Uses Apple's on-device Vision OCR to read visible text.
- Sends recognized text to the selected provider when you have supplied its key in Settings: MiniMax M3, OpenAI GPT-5 mini, or Anthropic Claude Haiku 5.5.
- Replaces its visible menu-bar viewfinder icon with the returned answer letter for 5 seconds; click the item to see the concise explanation in its normal menu.

It deliberately does not hide its behavior, suppress macOS privacy indicators, or attempt to defeat site or proctoring controls. The API key is stored in your macOS Keychain; it is not written to source files, configuration files, or the app bundle.

## Build and run

From this folder:

```zsh
chmod +x build-app.sh
./build-app.sh
open "$HOME/Applications/Promptly.app"
```

Requirements: macOS 14 or later and Xcode Command Line Tools (`xcode-select --install`) so the included Swift package can build.

At first capture, allow **Screen Recording** in macOS System Settings when asked. Promptly uses macOS’s registered global-hotkey API, so it does not require Input Monitoring.

The script installs a signed copy in `~/Applications/Promptly.app`. macOS remembers Screen Recording and Keychain approvals by code signature, so the script signs every build with the same certificate, by default a self-signed one named **ChoiceLens Local Development**. Create it once in Keychain Access → Certificate Assistant → Create a Certificate… (Identity Type: Self-Signed Root, Certificate Type: Code Signing); the script stops with these instructions if it is missing. With a stable signature, you approve Screen Recording and Keychain access once instead of after every rebuild. Keep only one copy of the app installed: other copies with the same bundle identifier can reset its permissions.

To use a different install location, set `PROMPTLY_INSTALL_DIR` before running the script. To sign with another identity, such as an Apple Developer ID, set `PROMPTLY_SIGNING_IDENTITY`; set it to `-` for an ad-hoc signature, which makes macOS re-prompt after every build.

## Configure an AI provider

1. Launch `Promptly.app`.
2. Select the viewfinder icon in the menu bar and choose **Settings**.
3. Choose **MiniMax**, **OpenAI**, or **Anthropic**.
4. Paste an API key for that provider and select **Save securely**. Settings reports whether a key is set and offers **Replace key…** without exposing it. Each provider’s key is stored separately in Keychain.

Only text recognized from the scan is sent to the selected provider; screenshots are not uploaded. The app uses MiniMax’s and OpenAI’s Chat Completions APIs and Anthropic’s Messages API.

The API key is read from Keychain once per app launch and retained only in memory for the active session, so scans do not repeatedly prompt for Keychain access.
