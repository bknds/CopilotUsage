# CopilotUsage

A macOS menubar app that shows your GitHub Copilot premium request usage and overage cost in real time.

**Status bar:**

![Status bar](screenshot_statusbar.png)

**Popover panel:**

![Panel](screenshot_panel.png)

## Features

- **Status bar**: shows usage percentage and estimated overage cost (`674% | $68.88 ≈ ¥496`)
- **Popover panel**: detailed breakdown — subscription info, premium usage progress bar, overage count and cost in USD/CNY
- **One-click GitHub login**: uses Device Flow OAuth — no manual token entry, no OAuth App registration required
- **Auto-refresh**: fetches latest usage every 5 minutes
- **Auto-update**: notifies you in the panel when a new version is available
- **Right-click to quit**: right-click the menubar icon for a quick exit menu

## Requirements

- macOS 13 Ventura or later

## Installation

1. Download `CopilotUsage.dmg` from [Releases](../../releases)
2. Open the DMG and drag **CopilotUsage** to your Applications folder
3. On first launch, macOS may show a security warning — go to **System Settings → Privacy & Security** and click **Open Anyway**

## Usage

1. Click the Copilot icon in the menubar
2. Click **一键关联 GitHub 账号** to log in via GitHub Device Flow
3. Your browser will open — enter the 8-character code shown in the app
4. Once authorized, usage data loads automatically

## How It Works

- **Auth**: [GitHub Device Flow](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps#device-flow) using the public Copilot for Neovim client ID (`Iv1.b507a08c87ecfe98`)
- **Data**: GitHub's internal API endpoint `GET /copilot_internal/user`
- **Token storage**: saved locally in `UserDefaults` — never leaves your machine

## Building from Source

Requires Xcode 15+ and Swift 5.9+.

```bash
cd CopilotUsage
swift build -c release
```

## License

MIT
