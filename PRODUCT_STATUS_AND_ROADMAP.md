# NotchMove 现状分析与后续规划文档

日期: 2026-04-30

## 1. 文档目的

本文档基于当前代码仓库的实际实现状态，分析 NotchMove 作为一款 macOS 健康提醒软件的现状、优势、缺口、风险和后续应补充的功能。它不是单纯的功能清单，而是面向产品决策和工程落地的规划文档，可作为后续版本迭代、任务拆分、测试验收和发布准备的依据。

## 2. 当前产品定位

NotchMove 当前是一款原生 macOS 菜单栏健康提醒工具。核心目标是在用户长时间使用电脑时，通过贴近 MacBook 刘海区域的轻量浮层，提醒用户站立、伸展和活动。

当前产品更适合定位为:

- 轻量、低打扰的久坐提醒工具。
- 面向 MacBook 刘海屏用户的差异化菜单栏工具。
- 可在后台长期运行的本地优先健康辅助软件。
- 不依赖云端、不需要账号、不收集隐私数据的个人效率/健康工具。

不建议现阶段把它定位成:

- 复杂健康管理平台。
- 团队管理或企业健康打卡软件。
- 运动训练软件。
- 需要重数据、重社交、重订阅体系的产品。

当前最合理的方向是: 先把“提醒可靠、展示优雅、设置清楚、发布可信”做好，再逐步扩展统计、运动建议和长期习惯养成能力。

## 3. 当前已实现能力

### 3.1 应用形态

- 原生 macOS 应用。
- 以菜单栏常驻方式运行。
- 使用 `LSUIElement`，默认不显示 Dock 图标。
- 通过 AppKit 管理菜单栏、设置窗口和浮层窗口。
- 通过 SwiftUI 构建设置页和提醒浮层内容。
- 开启 Hardened Runtime。
- 当前 entitlements 中开启了 App Sandbox。

### 3.2 提醒逻辑

当前提醒逻辑集中在 `ReminderEngine`，这是一个比较好的架构选择。它统一管理:

- 活跃使用时间累积。
- 手动暂停状态。
- 工作时间段限制。
- 悬停预览状态。
- 提醒展示、完成、取消、自动关闭。
- 提醒倒计时与自动关闭任务。

当前默认提醒策略:

- 默认每 30 分钟提醒一次。
- 每 5 秒 tick 一次。
- 通过系统 idle time 判断用户是否活跃。
- 开启 sit-aware 后，如果用户 idle 超过阈值，会重置活跃计时，避免用户已经离开座位后仍然触发提醒。
- 手动触发提醒不受定时器限制。

### 3.3 菜单栏能力

当前菜单栏已经提供:

- 下次提醒剩余时间。
- 今日/本周完成休息次数。
- 暂停/恢复提醒。
- 立即提醒。
- 声音开关。
- 打开设置。
- 退出应用。

菜单栏已经是可用状态，但还偏基础。它适合作为后台工具的主要控制入口，后续应该增强“快速控制”能力。

### 3.4 浮层展示能力

当前浮层能力:

- 刘海屏上贴合刘海区域展示。
- 非刘海屏上使用居中顶部 fallback。
- 使用 `NSPanel` 非激活浮层，不抢焦点。
- 浮层可跨 Space 展示。
- 支持悬停预览。
- 支持提醒时展开刘海。
- 支持倒计时进度环。
- 支持“Stand & Move”完成按钮。
- 支持自动关闭。

当前浮层的视觉方向已经成立: 黑色刘海形状、进度环、简短文案、一个明确动作按钮。作为第一版健康提醒体验已经可用。

### 3.5 多屏支持

当前代码已经具备比基础版更可靠的多屏设计:

- `ScreenPlacementService` 负责纯几何布局。
- `ScreenSelectionService` 负责屏幕选择策略。
- 设置中可选择自动或指定显示器。
- 自动模式优先内建刘海屏，其次内建屏，其次主屏，最后使用列表首个屏幕。
- 指定显示器不可用时会临时降级到自动模式，不清空用户原选择。
- 屏幕参数变化时会重新计算浮层位置。

这是当前项目的一个重要优势，因为很多菜单栏/浮层工具在外接屏场景下容易表现不稳定。

### 3.6 设置能力

当前设置页包含:

- 语言选择。
- 提醒间隔选择。
- sit-aware mode 开关。
- 工作时间段限制。
- 仅工作日提醒。
- 浮层显示屏幕选择。
- 刘海展开开关。
- 悬停预览开关。
- 声音开关。
- 自动关闭开关和关闭时间。
- 今日/本周统计。
- 重置统计。
- 恢复默认设置。
- 版本信息。

设置项覆盖了第一版需要的大部分行为控制，整体偏轻量，没有明显过度设计。

### 3.7 本地化

当前本地化资源覆盖:

- English
- 简体中文
- 繁体中文
- 日文

每个语言文件当前都有 75 行左右，主要覆盖设置页、浮层和菜单栏文案。

需要注意的是，当前本地化是“具备基础能力”，还不是“发布级完成”。后续新增功能时需要建立缺失 key 检查、文案一致性检查和视觉长度检查。

### 3.8 统计能力

当前统计能力:

- 记录今日完成休息次数。
- 记录本周完成休息次数。
- 只有用户点击完成休息时才计入统计。
- 自动关闭、取消、忽略不会计入完成。
- 使用 `UserDefaults` 按日期和周维度存储。

这个设计适合轻量 MVP，但无法支持趋势图、连续天数、历史记录、导出或更细的行为分析。

### 3.9 工程状态

当前工程状态:

- Xcode project。
- Swift + SwiftUI + AppKit。
- 使用 `@Observable`。
- macOS deployment target 当前为 14.0。
- Bundle ID 为 `com.thomaschiu.developer.NotchMove`。
- 项目内已有 DMG 产物 `NotchMove/dist/NotchMove-1.0.dmg`。
- 项目内已有 DMG 背景图资源 `NotchMove/Packaging/NotchMove-dmg-background.png`。
- 当前工作区存在未提交改动和未跟踪文件。

当前测试结果:

- 已执行 `xcodebuild -project NotchMove/NotchMove.xcodeproj -scheme NotchMove -destination 'platform=macOS' test`。
- 结果: `TEST SUCCEEDED`。
- 通过的单元测试覆盖 SchedulePolicy、PreferencesStore、BreakStatsStore、ReminderEngine、ScreenPlacementService、ScreenSelectionService。
- UI tests 目前被标记为 unavailable，本质上是占位，不属于有效 UI 自动化覆盖。

## 4. 当前优势

### 4.1 产品切入点清晰

NotchMove 没有做成泛泛的提醒软件，而是利用 MacBook 刘海区域作为差异化入口。这个方向有辨识度，也符合 macOS 用户对菜单栏小工具的使用习惯。

### 4.2 架构轻量且边界明确

当前架构没有过早引入数据库、账号、云同步或复杂状态层。对一个菜单栏工具来说，这是正确选择。

比较好的边界包括:

- `ReminderEngine` 统一管理提醒生命周期。
- `PreferencesStore` 统一管理偏好读取和保存。
- `BreakStatsStore` 独立管理统计。
- `ScreenPlacementService` 只做几何计算。
- `ScreenSelectionService` 只做显示器选择。
- AppKit 控制器负责系统级窗口和菜单。
- SwiftUI 负责可视界面。

### 4.3 可靠性基础较好

当前单元测试已经覆盖主要纯逻辑和提醒状态切换。对一个第一版工具来说，这比只做 UI 更有长期价值。

### 4.4 隐私负担低

当前产品不需要账号、不需要云端、不需要摄像头、不需要健康数据权限。通过系统 idle time 判断活跃状态，不需要 Accessibility 权限。这对发布、用户信任和安装转化都是优势。

### 4.5 本地化起点较好

一开始就覆盖英文、简体中文、繁体中文和日文，说明产品有国际化意识。后续如果做发布页和 App Store 文案，可以沿用这套语言方向。

## 5. 当前主要问题和缺口

### 5.1 提醒动作太单一

当前提醒浮层只有一个核心动作: Stand & Move。

问题:

- 用户不知道具体该做什么动作。
- 每次提醒内容重复，长期使用容易疲劳。
- 没有区分轻量休息、伸展、走动、喝水、眼睛休息等类型。
- 没有“稍后提醒”或“跳过”这种现实场景常用动作。

建议:

- 增加 Snooze，支持 5/10/15 分钟后再提醒。
- 增加 Skip，本次不计入完成。
- 增加动作建议，例如 Neck stretch、Shoulder roll、Walk 1 minute、Look away 20 seconds。
- 增加简短动作说明，但保持浮层轻量。
- 可以先内置 8-12 个动作，不要一开始做复杂内容管理系统。

### 5.2 暂停能力不够精细

当前只有手动暂停/恢复。

现实使用中更常见的是:

- 暂停 15 分钟。
- 暂停 30 分钟。
- 暂停 1 小时。
- 暂停到明天。
- 会议期间暂停。

建议:

- 菜单栏增加“暂停一段时间”子菜单。
- 设置中保留默认暂停时长。
- `ReminderEngine` 增加 `pauseUntil` 状态。
- 到期后自动恢复，并在菜单栏显示剩余暂停时间。

### 5.3 缺少开机自启动

菜单栏工具通常需要开机自动运行，否则用户很容易忘记打开。

建议:

- 增加“登录时启动”开关。
- 使用 ServiceManagement 的现代 API 管理 login item。
- 首次启动引导中提示用户开启。
- 不要默认强制开启，应由用户确认。

### 5.4 缺少首次启动引导

当前用户首次打开后可能不知道:

- 应用在菜单栏哪里。
- 为什么没有 Dock 图标。
- 浮层会显示在哪里。
- sit-aware 是什么意思。
- 是否会采集隐私数据。

建议增加轻量 onboarding:

- 第一步: 说明 NotchMove 在菜单栏运行。
- 第二步: 选择提醒间隔和是否登录时启动。
- 第三步: 选择显示器策略。
- 第四步: 说明隐私: 本地运行，不上传数据，不需要摄像头/麦克风/辅助功能权限。
- 最后提供“测试提醒”按钮。

### 5.5 统计过于基础

当前只有今日和本周计数。

这能满足 MVP，但不能帮助用户形成长期习惯。

建议分阶段扩展:

- 第一阶段: 每日目标和完成率。
- 第二阶段: 最近 7 天趋势。
- 第三阶段: 连续完成天数 streak。
- 第四阶段: 历史列表和导出。

数据层建议:

- 只保留今日/本周时，`UserDefaults` 足够。
- 一旦要做历史趋势，应增加 `BreakEvent` 记录。
- 可选方案是 SwiftData，也可以先用轻量 JSON 文件。
- 不建议为了当前统计立即引入复杂数据库。

### 5.6 日程模型偏简单

当前日程只有一个工作时间段，且只有 weekdays-only 开关。

问题:

- 无法设置午休时段。
- 无法设置不同工作日不同时间。
- 无法设置周末例外。
- 无法设置“专注时段”或“会议时段”。

建议:

- 短期: 增加“午休暂停”或“排除时间段”。
- 中期: 支持多个时间段。
- 长期: 支持按星期自定义 schedule。
- 不建议第一阶段做日历集成，成本和隐私解释都更高。

### 5.7 “sit-aware”命名可能过度承诺

当前 sit-aware 实际是基于系统 idle time 推断用户可能离开电脑。它并不能真正知道用户是否站起来，也不能检测坐姿。

建议:

- 文案上避免让用户误解为姿态检测。
- 可以改成更清楚的表达，例如“空闲时暂停计时”或“离开电脑时重置计时”。
- 英文也可以考虑从 Sit-aware mode 改成 Idle-aware reminders。

### 5.8 辅助功能体验需要补齐

当前 UI 视觉上可用，但还缺少明确的辅助功能策略。

需要评估:

- 浮层按钮 VoiceOver 标签是否足够。
- 非激活 NSPanel 中按钮的键盘可达性。
- Reduce Motion 开启时是否应该降低动画。
- Increase Contrast 下浮层是否可读。
- 文案在四种语言下是否会挤压按钮。
- 小屏、外接屏、菜单栏高度变化时是否会重叠。

建议:

- 给关键按钮和图标增加 accessibilityLabel。
- 响应 `accessibilityReduceMotion`。
- 为本地化长文案做布局检查。
- 增加手动 QA checklist。

### 5.9 发布流程不完整

当前仓库有 DMG 产物，但发布流程还不够工程化。

缺口:

- 缺少明确打包脚本。
- 缺少签名和 notarization 文档。
- 缺少 release checklist。
- 缺少版本号递增规则。
- 缺少更新机制。
- `dist/` 和 `build/` 这类产物出现在工作区，需要确认是否应该进入版本控制。

建议:

- 增加 `scripts/package_dmg.sh`。
- 增加 `docs/RELEASE_CHECKLIST.md`。
- 明确 Debug/Release 签名区别。
- 发布前执行 build、test、DMG 安装 smoke test。
- 如果独立分发，考虑 Sparkle 自动更新。
- 如果走 App Store，需要提前确认 sandbox、login item、菜单栏工具审核策略。

### 5.10 UI 自动化仍然缺失

当前 UI tests 被标记 unavailable，说明默认测试路径没有真正覆盖用户界面。

建议:

- 不要急着做完整 UI 自动化。
- 先做可控的 smoke harness:
  - 启动应用。
  - 打开菜单栏。
  - 打开设置窗口。
  - 点击测试提醒。
  - 验证设置窗口存在。
- 对 SwiftUI 视图增加 Preview/Snapshot 或轻量视觉检查。
- 对本地化文本长度做静态检查。

### 5.11 缺少诊断能力

多屏浮层、菜单栏应用、后台提醒都可能出现用户机器特定问题。当前已有 OSLog，但用户无法导出诊断信息。

建议:

- 增加“复制诊断信息”按钮。
- 内容包含:
  - App version/build。
  - macOS version。
  - 是否沙盒。
  - 当前屏幕列表和 displayID。
  - 当前 overlay display mode。
  - 当前 schedule 状态。
  - 当前 pause 状态。
  - 当前 reminder interval。
- 不包含个人文件路径、用户名、应用列表等敏感信息。

### 5.12 产品反馈闭环缺失

当前软件无法引导用户反馈问题。

建议:

- 设置页增加 Feedback / Report Issue。
- 可以先用 mailto 或 GitHub issue 链接。
- 独立分发时增加官网或 README 中的反馈入口。

## 6. 建议新增功能清单

下面按照优先级划分。优先级不是“功能好不好”，而是“对这个产品能否真正可用、可发布、可留存”的影响。

## 7. P0: 发布前必须补齐

### 7.1 登录时启动

必要性:

- 菜单栏健康提醒软件如果不能自动启动，留存会明显下降。

建议实现:

- 设置页 General 区增加 `Launch at Login`。
- 使用 ServiceManagement 管理。
- 首次启动引导中让用户选择。

验收标准:

- 用户开启后，重启登录会自动启动 NotchMove。
- 用户关闭后，不再自动启动。
- 开关状态和系统 login item 状态一致。

### 7.2 Snooze 和 Skip

必要性:

- 真实使用中，用户经常正在会议、写代码、演示或专注工作，不能立即站起来。

建议实现:

- 浮层增加 Snooze 按钮。
- 菜单栏在提醒展示时提供 Snooze。
- Skip 关闭本次提醒但不计入完成。
- Snooze 不计入完成，且在指定时间后再次提醒。

验收标准:

- Snooze 后浮层关闭，并在设定时间后再次出现。
- Skip 后浮层关闭，不增加统计。
- Complete 后才增加统计。
- 手动暂停时取消 pending snooze。

### 7.3 临时暂停

必要性:

- 当前“暂停/恢复”容易被用户忘记恢复。

建议实现:

- 菜单栏增加 Pause for 15 min / 30 min / 1 hour / Until tomorrow。
- 设置页可配置默认快速暂停时长。
- 菜单栏显示暂停剩余时间。

验收标准:

- 到期后自动恢复提醒。
- 重启应用后仍能恢复 pauseUntil 状态。
- 手动恢复会清除 pauseUntil。

### 7.4 首次启动引导

必要性:

- Accessory app 没有 Dock 图标，新用户容易误以为应用没有启动。

建议实现:

- 首次启动显示一个简短设置窗口。
- 包含菜单栏位置说明、提醒间隔、登录启动、显示器选择、测试提醒。

验收标准:

- 新用户首次启动会看到 onboarding。
- 完成后不再重复出现。
- 设置中可以重新打开 onboarding 或帮助。

### 7.5 发布和打包流程

必要性:

- 当前已有 DMG 产物，但流程需要可重复。

建议实现:

- 增加打包脚本。
- 增加 release checklist。
- 明确签名、notarization、DMG 验证步骤。

验收标准:

- 从干净 checkout 可以一条命令生成 Release app 和 DMG。
- DMG 可打开、可拖拽安装、安装后可启动。
- 发布产物版本号正确。
- `xcodebuild test` 通过。

## 8. P1: 提升核心体验

### 8.1 动作建议库

建议:

- 内置 8-12 个微动作:
  - Stand up
  - Shoulder rolls
  - Neck stretch
  - Wrist stretch
  - Look 20 feet away
  - Walk for 1 minute
  - Drink water
  - Deep breathing
- 每次提醒随机或轮换一个动作。
- 设置中允许关闭动作建议，只保留通用提醒。

价值:

- 降低重复提醒疲劳。
- 让用户知道下一步具体做什么。
- 增加“完成休息”的心理反馈。

### 8.2 每日目标和 7 天趋势

建议:

- 设置每日目标，例如每天 6 次。
- 菜单栏显示 `3/6 breaks today`。
- 设置页显示最近 7 天条形图。

价值:

- 让统计从“计数”变成“习惯反馈”。
- 不需要复杂历史页面，也能明显提升产品完整度。

### 8.3 多屏说明和诊断

建议:

- 设置页 display picker footer 明确说明自动策略。
- 增加“测试浮层位置”按钮。
- 增加“复制诊断信息”。

价值:

- 降低外接屏场景的用户困惑。
- 方便排查少数设备上的屏幕几何问题。

### 8.4 设置页信息架构调整

当前设置页所有内容都在一个 Form 中，功能继续增加后会变长。

建议分区:

- General: language, launch at login。
- Reminders: interval, idle-aware, snooze, auto-dismiss。
- Schedule: work hours, weekdays, excluded periods。
- Display: overlay display, notch expansion, hover preview, test overlay。
- Stats: today/week/goal/history/reset。
- Privacy & About: version, diagnostics, feedback。

价值:

- 后续新增功能不会让设置页变得混乱。
- 用户更容易找到开关。

### 8.5 更细的提醒状态展示

建议:

- 菜单栏图标或 tooltip 显示当前状态:
  - Tracking
  - Paused
  - Outside schedule
  - Reminder active
  - Snoozed
- 菜单中显示更清楚的下一次提醒时间。

价值:

- 用户知道软件是否正常工作。
- 降低“为什么没有提醒”的困惑。

## 9. P2: 增强留存和专业度

### 9.1 自动更新

如果选择独立分发，建议使用 Sparkle。

价值:

- 用户不需要手动下载新 DMG。
- 可以快速修复多屏、签名、兼容性问题。

注意:

- Sparkle 会增加发布配置复杂度。
- 需要签名更新包。
- 需要维护 appcast。

### 9.2 更完整历史记录

建议新增 `BreakEvent`:

- id
- timestamp
- outcome
- movementType
- reminderSource
- durationSeconds
- snoozedBeforeCompletion

价值:

- 支持趋势图、streak、目标完成率。
- 支持未来导出。

注意:

- 这时可以考虑 SwiftData。
- 在此之前，不建议为了简单统计提前迁移数据层。

### 9.3 Focus Mode 集成

建议:

- 检测系统专注模式或允许用户手动设置“专注时段低打扰”。
- 或先做应用内“会议模式”。

注意:

- 不要过早依赖日历/系统状态集成。
- 先用简单的临时暂停和 schedule 解决 80% 场景。

### 9.4 通知 fallback

当前主要是浮层提醒。可以考虑在某些场景增加通知 fallback:

- 浮层被用户关闭太多次。
- 外接屏/全屏应用下浮层不明显。
- 用户选择通知模式。

注意:

- 通知需要权限，可能增加首次启动摩擦。
- 建议作为可选项，不要默认强制。

## 10. P3: 暂不建议优先做的功能

以下功能不是不能做，而是不适合当前阶段优先投入:

- 账号系统。
- 云同步。
- 团队管理后台。
- AI 生成运动建议。
- 摄像头姿态识别。
- Apple Health 深度集成。
- 复杂成就系统。
- 付费订阅墙。
- 完整日历读取。

原因:

- 会显著增加隐私解释、权限、审核和维护成本。
- 当前产品最重要的是把本地提醒体验做稳。
- 未验证留存前，不应过早增加重系统。

## 11. 建议数据模型演进

### 11.1 当前继续保留 UserDefaults

适合继续用 `UserDefaults` 的内容:

- 提醒间隔。
- 声音开关。
- idle-aware 开关。
- schedule 设置。
- 语言。
- display mode。
- launch at login preference。
- onboarding 是否完成。
- quick pause 默认值。

### 11.2 新增轻量状态

建议新增:

- `pauseUntil: Date?`
- `snoozeUntil: Date?`
- `dailyGoal: Int`
- `onboardingCompleted: Bool`
- `selectedMovementMode`

这些仍然可以先放在 `UserDefaults`。

### 11.3 当需要历史趋势时再新增事件存储

建议 `BreakEvent` 数据结构:

```swift
struct BreakEvent: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let outcome: ReminderOutcome
    let movementID: String?
    let reminderSource: ReminderSource
    let durationSeconds: TimeInterval
    let snoozeCount: Int
}
```

建议 `ReminderSource`:

```swift
enum ReminderSource: String, Codable {
    case automatic
    case manual
    case snoozed
}
```

工程建议:

- 如果只做最近 7 天趋势，可以先用 JSON 文件或按天 `UserDefaults` 聚合。
- 如果要做完整历史、筛选、导出，再考虑 SwiftData。

## 12. 建议交互设计

### 12.1 菜单栏

建议菜单结构:

- Status: Next reminder in 18 min。
- Today: 3/6 breaks。
- Remind me now。
- Pause:
  - Pause 15 min
  - Pause 30 min
  - Pause 1 hour
  - Pause until tomorrow
  - Resume
- Sound on reminder。
- Settings。
- Feedback。
- Quit NotchMove。

提醒正在展示时:

- Complete break。
- Snooze 10 min。
- Skip this reminder。

### 12.2 浮层

建议提醒浮层内容:

- 图标/进度环。
- 主标题: Time to stretch。
- 动作建议: Shoulder rolls for 30 seconds。
- 次要信息: Auto-dismiss in 55s。
- 主按钮: Done。
- 次按钮: Snooze。
- 文本按钮或菜单: Skip。

注意:

- 浮层空间很小，不要塞过多说明。
- 长文案应放到设置或帮助页。
- 日文和繁体中文会影响布局，需要做长度检查。

### 12.3 设置页

建议新增设置项:

- Launch at login。
- Daily goal。
- Default snooze duration。
- Temporary pause options。
- Test overlay。
- Copy diagnostics。
- Feedback。

建议保留:

- 当前语言切换。
- 当前提醒间隔。
- 当前工作时间。
- 当前显示器选择。
- 当前统计。

## 13. 工程落地建议

### 13.1 低风险优先改动

可以先做:

- 文案调整: 把 sit-aware 解释得更准确。
- 菜单栏增加临时暂停。
- 浮层增加 Snooze/Skip。
- 设置页增加 launch at login。
- 增加 release checklist。
- 增加 diagnostic info 生成器。

这些改动主要围绕现有 `Preferences`、`ReminderEngine`、`MenuBarController` 和 `SettingsView`，不需要大改架构。

### 13.2 中等风险改动

需要更谨慎:

- Onboarding window。
- 运动建议库。
- 7 天统计趋势。
- 自动更新。
- UI 自动化 harness。

这些会引入新视图、新状态或发布流程，应该分独立 PR/任务做。

### 13.3 高风险改动

建议暂缓:

- 数据层整体迁移。
- 复杂日历/专注模式集成。
- 云同步。
- 摄像头/姿态检测。

这些会改变产品复杂度和用户信任边界。

## 14. 测试计划建议

### 14.1 单元测试

新增功能后应补充:

- pauseUntil 到期自动恢复。
- Snooze 后不计入统计。
- Skip 后不计入统计。
- Complete 后计入统计。
- schedule blocked 时取消 snooze。
- 手动暂停时取消当前提醒。
- launch at login preference 保存。
- daily goal 计算。
- BreakEvent 聚合逻辑。

### 14.2 UI/交互测试

建议最小 smoke test:

- 应用可以启动。
- 菜单栏 item 存在。
- 设置窗口可以打开。
- 修改提醒间隔后持久化。
- 修改语言后设置窗口和菜单文本刷新。
- 手动触发提醒后浮层出现。
- 点击完成后统计增加。

### 14.3 手动 QA 矩阵

显示器:

- 仅内建刘海屏。
- 仅非刘海外接屏。
- 内建屏 + 外接屏。
- 外接屏设为主屏。
- 合盖模式。
- 插拔外接屏。

系统场景:

- 全屏应用。
- 多个 Space。
- 锁屏后恢复。
- 睡眠后恢复。
- 菜单栏自动隐藏。
- Reduce Motion。
- Increase Contrast。

语言:

- English。
- 简体中文。
- 繁体中文。
- 日文。

发布:

- Debug 构建。
- Release 构建。
- DMG 安装。
- 从 Applications 启动。
- 重启后登录启动。

## 15. 发布准备清单

建议发布前必须完成:

- `xcodebuild test` 通过。
- Release build 成功。
- DMG 可重复生成。
- App 签名正确。
- Notarization 成功。
- DMG 安装后可启动。
- 菜单栏 item 可见。
- 设置窗口可打开。
- 手动提醒可展示。
- 自动提醒可触发。
- 完成休息会增加统计。
- 退出后重启，偏好仍保留。
- 多屏选择可用。
- 四种语言无明显截断。
- README 有安装和反馈入口。
- 隐私说明清楚。

## 16. 建议版本路线图

### 16.1 v1.0 Beta: 稳定可用

目标:

- 让产品具备真实日常使用能力。

建议包含:

- 登录时启动。
- Snooze/Skip。
- 临时暂停。
- 首次启动引导。
- 发布脚本和 release checklist。
- 多屏 QA。
- 基础诊断信息。

### 16.2 v1.1: 体验增强

目标:

- 降低重复提醒疲劳，提高完成率。

建议包含:

- 动作建议库。
- 每日目标。
- 菜单栏显示目标进度。
- 7 天趋势。
- 设置页重组。
- 更完整的本地化检查。

### 16.3 v1.2: 分发和留存

目标:

- 降低升级成本，建立反馈闭环。

建议包含:

- 自动更新。
- Feedback/Report Issue。
- 诊断导出。
- 更完善的 release pipeline。
- 轻量官网或下载页。

### 16.4 v2.0: 习惯养成

目标:

- 从提醒工具升级为轻量健康习惯工具。

可能包含:

- 完整历史记录。
- Streak。
- 自定义动作库。
- 多 schedule profiles。
- 可选通知 fallback。
- 可选数据导出。

## 17. 当前最建议立即做的 10 件事

1. 增加登录时启动。
2. 增加 Snooze 和 Skip。
3. 增加临时暂停，避免用户忘记恢复。
4. 增加首次启动引导，解释菜单栏运行方式。
5. 补 release checklist 和打包脚本。
6. 增加“测试提醒/测试浮层位置”按钮。
7. 增加多屏诊断信息导出。
8. 将 sit-aware 文案改得更准确。
9. 增加每日目标和菜单栏进度。
10. 建立最小 UI smoke test。

## 18. 结论

NotchMove 当前已经不是空壳项目，而是具备核心提醒闭环的 macOS 菜单栏工具。它的基础架构、提醒状态管理、多屏几何处理、本地化和单元测试都已经有较好的起点。

下一阶段最重要的不是增加很多复杂功能，而是补齐真实用户日常使用时一定会遇到的能力: 登录自启动、临时暂停、Snooze/Skip、首次启动引导、发布流程和基础诊断。完成这些之后，再做动作建议库、每日目标和趋势统计，产品会从“能提醒”提升到“愿意长期用”。

建议保持当前轻量本地工具的产品边界，避免过早引入账号、云同步、复杂健康数据和重权限能力。NotchMove 最应该先赢的是可靠、低打扰、优雅、可信。
