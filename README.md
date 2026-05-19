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
3. **First launch**: macOS will block the app with "无法打开" — fix it with one of these methods:

   **方法一（推荐）：** 打开终端，运行：
   ```bash
   xattr -cr /Applications/CopilotUsage.app
   ```
   然后正常双击打开即可。

   **方法二：** 在 Finder 中右键点击 app → **打开** → 弹窗中点击**打开**

   **方法三：** 系统设置 → 隐私与安全性 → 找到拦截提示 → 点击**仍要打开**

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
