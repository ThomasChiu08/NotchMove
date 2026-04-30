# NotchMove

**Developer / 开发者:** Thomas

NotchMove is a native macOS menu bar app that reminds you to stand up, stretch, and move during long computer sessions. It presents a notch-shaped reminder overlay on Macs with a notch and uses a centered fallback overlay on other displays.

NotchMove 是一款原生 macOS 菜单栏应用，用于在长时间使用电脑时提醒你站立、伸展和活动。它会在带刘海的 Mac 上显示贴合刘海的提醒浮层，在没有刘海的屏幕上自动使用居中浮层。

## 中文说明

### 主要功能

- 菜单栏常驻提醒，适合长期后台运行。
- 按活跃使用时间触发活动提醒，系统空闲时不会持续累加。
- 支持刘海屏贴合展示，也支持非刘海屏的居中展示。
- 可手动暂停/恢复提醒，也可以立即触发一次提醒。
- 设置窗口支持提醒间隔、工作时间段、工作日限制、声音、悬停预览和自动关闭。
- 统计每日和每周完成的休息次数。
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
NotchMove/dist/NotchMove-1.0.dmg
```

### 运行时结构

- `AppDelegate` 创建并连接偏好设置、统计、活动监控、提醒引擎、菜单栏控制器、设置窗口和刘海浮层控制器。
- `ActivityMonitor` 每 5 秒读取系统空闲时间。
- `ReminderEngine` 负责提醒生命周期，包括定时、暂停、工作时间段、悬停预览、显示和关闭。
- `NotchWindowController` 负责展示提醒浮层，并根据 `ScreenPlacementService` 的结果放置窗口。
- `PreferencesStore` 和 `BreakStatsStore` 将设置和休息统计持久化到 `UserDefaults`。

更多架构细节见 [ARCHITECTURE.md](./ARCHITECTURE.md)。

## English

### Key Features

- Persistent menu bar app designed for quiet background use.
- Activity-aware reminders based on active computer usage.
- Notch-aligned overlay on supported Macs, with a centered fallback on other displays.
- Manual pause/resume controls and an immediate reminder action.
- Settings for reminder interval, schedule window, weekdays-only mode, sound, hover preview, and auto-dismiss.
- Daily and weekly completed-break counters.
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
NotchMove/dist/NotchMove-1.0.dmg
```

### Runtime Overview

- `AppDelegate` wires together preferences, statistics, activity monitoring, the reminder engine, the menu bar controller, the settings window, and the notch overlay controller.
- `ActivityMonitor` polls system idle time every 5 seconds.
- `ReminderEngine` owns the reminder lifecycle, including timing, pause state, schedule gating, hover preview, presentation, and dismissal.
- `NotchWindowController` presents the overlay and positions it using `ScreenPlacementService`.
- `PreferencesStore` and `BreakStatsStore` persist settings and break counters through `UserDefaults`.

See [ARCHITECTURE.md](./ARCHITECTURE.md) for a deeper runtime map.
