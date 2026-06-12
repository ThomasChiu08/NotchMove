# NotchMove

**Developer / 开发者:** Thomas

NotchMove is a native macOS menu bar app focused on one job: reminding you to stand up, stretch, and move during long computer sessions. It presents a notch-shaped reminder overlay on Macs with a notch and uses a centered fallback overlay on other displays.

NotchMove 是一款专注于久坐活动提醒的原生 macOS 菜单栏应用，用于在长时间使用电脑时提醒你站立、伸展和活动。它会在带刘海的 Mac 上显示贴合刘海的提醒浮层，在没有刘海的屏幕上自动使用居中浮层。

## 中文说明

### 主要功能

- 菜单栏常驻提醒，适合长期后台运行。
- 按活跃使用时间触发活动提醒，系统空闲时不会持续累加。
- 支持刘海屏贴合展示，也支持非刘海屏的居中展示。
- 可手动暂停/恢复提醒，也可以立即触发一次提醒。
- 设置窗口支持提醒间隔、工作时间段、工作日限制、声音、悬停预览和自动关闭。
- 统计每日和每周完成的休息次数。
- 日程、AI 添加日程和语音输入代码仍保留在仓库中，但当前主体验默认隐藏这些入口。
- 本地化资源包含 English、简体中文、繁体中文和日文。

### 技术栈

- **语言:** Swift
- **界面:** SwiftUI + AppKit
- **状态管理:** Observation
- **平台:** macOS
- **项目:** Xcode project
- **签名:** Hardened Runtime 已开启，当前仓库配置使用 Apple Development 自动签名
- **Bundle ID:** `com.thomaschiu.developer.NotchMove`

### 本地构建

开发运行：

```bash
./script/build_and_run.sh
```

Release 构建：

```bash
cd NotchMove
xcodebuild -project NotchMove.xcodeproj \
  -scheme NotchMove \
  -configuration Release \
  -destination 'platform=macOS' \
  build
```

### 运行测试

```bash
cd NotchMove
xcodebuild -project NotchMove.xcodeproj \
  -scheme NotchMove \
  -destination 'platform=macOS' \
  test
```

### 打包 DMG

测试版发布包会继续通过签名、Hardened Runtime、隐私声明和 DMG 内容校验。默认会生成带 `test` 和时间戳的新 DMG，并把带界面的 HTML 中文安装/使用说明放进 DMG：

```bash
./script/package_dmg.sh
```

可选覆盖：

```bash
VERSION=1.0 CHANNEL=test BUILD_STAMP=20260501-2330 ./script/package_dmg.sh
DMG_NAME=NotchMove-custom-test.dmg ./script/package_dmg.sh
NOTARIZE=1 NOTARY_PROFILE=notchmove-notary ./script/package_dmg.sh
```

脚本会优先使用本机可用的 Developer ID Application 签名身份；如果没有 Developer ID，会降级使用 Apple Development 身份生成测试包。脚本会校验签名、Hardened Runtime、隐私权限声明、DMG 内容、Applications 快捷方式和 HTML 使用说明。设置 `NOTARIZE=1` 后会提交 notarization、staple，并执行 Gatekeeper 校验。

当前 DMG 背景图资源位于：

```text
NotchMove/Packaging/NotchMove-dmg-background.png
```

Release app 构建产物默认位于：

```text
NotchMove/build/DerivedData/Build/Products/Release/NotchMove.app
```

打包后的 DMG 输出到：

```text
NotchMove/dist/NotchMove-1.0-test-YYYYMMDD-HHMM.dmg
```

给朋友测试时可同时发送 [HTML 中文安装与使用说明](./docs/FRIEND_TEST_INSTALL_USAGE.zh-Hans.html)，纯文本版见 [Markdown 说明](./docs/FRIEND_TEST_INSTALL_USAGE.zh-Hans.md)。

### 运行时结构

- `AppDelegate` 创建并连接偏好设置、统计、活动监控、提醒引擎、菜单栏控制器、设置窗口和刘海浮层控制器。
- `ActivityMonitor` 每 5 秒读取系统空闲时间。
- `ReminderEngine` 负责提醒生命周期，包括定时、暂停、工作时间段、悬停预览、显示和关闭。
- `NotchWindowController` 负责展示提醒浮层，并根据 `ScreenPlacementService` 的结果放置窗口。
- 日程提醒、AI 日程捕获和语音输入属于保留模块，当前不会从菜单栏或控制台主流程启动。
- `PreferencesStore` 和 `BreakStatsStore` 将设置和休息统计持久化到 `UserDefaults`。

更多架构细节见 [ARCHITECTURE.md](./ARCHITECTURE.md)。

## English

### Key Features

- Persistent menu bar app designed for quiet background use.
- Activity-aware reminders based on active computer usage.
- Notch-aligned overlay on supported Macs, with a centered fallback on other displays.
- Manual pause/resume controls and an immediate reminder action.
- Settings for reminder interval, work-hours window, weekdays-only mode, sound, hover preview, and auto-dismiss.
- Daily and weekly completed-break counters.
- Daily schedule, AI schedule capture, and voice-input code remain in the repository, but those entry points are hidden from the default core experience.
- Localized resources for English, Simplified Chinese, Traditional Chinese, and Japanese.

### Tech Stack

- **Language:** Swift
- **UI:** SwiftUI + AppKit
- **State:** Observation
- **Platform:** macOS
- **Project Type:** Xcode project
- **Signing:** Hardened Runtime enabled; current project settings use Apple Development automatic signing
- **Bundle ID:** `com.thomaschiu.developer.NotchMove`

### Build

Development run:

```bash
./script/build_and_run.sh
```

Release build:

```bash
cd NotchMove
xcodebuild -project NotchMove.xcodeproj \
  -scheme NotchMove \
  -configuration Release \
  -destination 'platform=macOS' \
  build
```

### Test

```bash
cd NotchMove
xcodebuild -project NotchMove.xcodeproj \
  -scheme NotchMove \
  -destination 'platform=macOS' \
  test
```

### Package

Test release packages still pass signing, Hardened Runtime, privacy metadata, and DMG content verification. By default the script creates a new timestamped `test` DMG and includes the styled Simplified Chinese HTML install/use guide inside the image:

```bash
./script/package_dmg.sh
```

Optional overrides:

```bash
VERSION=1.0 CHANNEL=test BUILD_STAMP=20260501-2330 ./script/package_dmg.sh
DMG_NAME=NotchMove-custom-test.dmg ./script/package_dmg.sh
NOTARIZE=1 NOTARY_PROFILE=notchmove-notary ./script/package_dmg.sh
```

The script prefers a local Developer ID Application signing identity. If Developer ID is unavailable, it falls back to Apple Development for test packages. It verifies the signature, Hardened Runtime, privacy usage strings, DMG contents, Applications shortcut, and HTML guide. Set `NOTARIZE=1` to submit notarization, staple the result, and run Gatekeeper assessment.

The generated DMG background asset is stored at:

```text
NotchMove/Packaging/NotchMove-dmg-background.png
```

The Release app bundle is produced at:

```text
NotchMove/build/DerivedData/Build/Products/Release/NotchMove.app
```

The packaged DMG is written to:

```text
NotchMove/dist/NotchMove-1.0-test-YYYYMMDD-HHMM.dmg
```

For friend testing, send the [Simplified Chinese HTML install and usage guide](./docs/FRIEND_TEST_INSTALL_USAGE.zh-Hans.html) with the DMG. A plain Markdown version is also available at [docs/FRIEND_TEST_INSTALL_USAGE.zh-Hans.md](./docs/FRIEND_TEST_INSTALL_USAGE.zh-Hans.md).

### Runtime Overview

- `AppDelegate` wires together preferences, statistics, activity monitoring, the reminder engine, the menu bar controller, the settings window, and the notch overlay controller.
- `ActivityMonitor` polls system idle time every 5 seconds.
- `ReminderEngine` owns the reminder lifecycle, including timing, pause state, schedule gating, hover preview, presentation, and dismissal.
- `NotchWindowController` presents the overlay and positions it using `ScreenPlacementService`.
- Schedule reminders, AI schedule capture, and voice input are retained modules, but they are not started from the default menu bar or dashboard flow.
- `PreferencesStore` and `BreakStatsStore` persist settings and break counters through `UserDefaults`.

See [ARCHITECTURE.md](./ARCHITECTURE.md) for a deeper runtime map.
