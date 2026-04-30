# NotchMove Notion-Inspired macOS UI Design Plan

Date: 2026-04-30

## Goal

Redesign the NotchMove main console as a quiet personal health workspace: Notion-inspired in structure and density, but native to macOS in controls, accessibility, motion, and restraint.

The UI should help users quickly understand today's schedule, next reminder, break progress, and current tracking state. It should not become a marketing page, a complex health platform, or a SaaS-style admin dashboard.

## Product Principles

- Lightweight: keep the app useful when opened briefly.
- Low interruption: avoid visual noise, large promotional sections, or high-saturation styling.
- Local-first: make settings and statistics feel private and personal.
- Native macOS: prioritize `NavigationSplitView`, `List`, `Form`, `Section`, `Toggle`, `Picker`, `DatePicker`, `Stepper`, and standard keyboard and accessibility behavior.
- Document-like: use Notion-style page hierarchy, property rows, timeline rows, and subtle separators rather than heavy cards.

## Information Architecture

```text
Primary Window
├─ Sidebar
│  ├─ App Status: NotchMove / Tracking or Paused
│  ├─ Workspace
│  │  ├─ Today
│  │  ├─ Schedule
│  │  └─ Breaks
│  └─ Settings
│     ├─ Reminders
│     ├─ Behavior
│     ├─ Statistics
│     ├─ Language
│     ├─ Startup
│     └─ About
├─ Detail Page
│  ├─ PageHeader
│  ├─ Meta Row
│  └─ Document Blocks / Property Lists
└─ Notch Overlay
   ├─ Break Reminder
   └─ Schedule Reminder
```

The primary window should remain a selection-driven macOS split view. The sidebar provides durable workspace structure. The detail pane behaves like a compact document page with editable blocks.

## Page Layouts

### Today

Purpose: answer "what is happening now, what is next, and how am I doing today?"

```text
Today
Next reminder 14:30 · 3 breaks today · Tracking

Today's Rhythm
Current schedule      Focus work · until 15:00
Next schedule         Team sync · 16:00
Stand reminder        in 22 min

Timeline
09:30  Morning focus      Active     5 min before
12:30  Lunch walk         Done       No alert
16:00  Team sync          Upcoming   10 min before

Selected Item Properties
Title
Time
Reminder
Advance notice
Note
```

Guidelines:

- Keep `Today's Rhythm` as a lightweight property group, not a hero card.
- Show current schedule, next schedule, next standing reminder, and current tracking state in the first viewport.
- Render schedule items as compact timeline rows with time, title, status, advance reminder, and optional note.
- Empty state: show a single-line explanation and an `Add schedule item` button.
- If an item is selected, show its details as inline properties in the main pane or a narrow inspector-style region.

### Schedule

Purpose: edit the user's daily rhythm without introducing a full calendar product.

```text
Schedule
Weekday routine · 6 items

Schedule Items
[time] [title] [repeat] [reminder] [note]

Properties
Enabled
Repeat days
Default advance notice
```

Guidelines:

- Prefer a list/table-like schedule editor over a month calendar.
- Keep add, edit, duplicate, delete, and enable/disable actions close to the row.
- Use a sheet only when inline editing would become cramped.

### Breaks

Purpose: summarize rest behavior simply.

```text
Breaks
Today 3 completed · Weekly goal 62%

Today
10:30  Stand & move   2 min
13:20  Stretch        3 min
15:40  Walk           5 min

Weekly Progress
Mon Tue Wed Thu Fri Sat Sun
```

Guidelines:

- Use lightweight numbers and weekly strips.
- Avoid complex charts, health scores, gamification, or trend dashboards.

### Reminders

Use a Notion-style property list while preserving native `Form` behavior.

```text
Reminder interval        [Stepper / Picker]
Advance schedule alert   [Picker]
Sound                    [Toggle]
Auto dismiss             [Toggle + duration Picker]
Immediate reminder       [Button: Remind Now]
```

### Behavior

```text
Pause tracking           [Toggle]
Work hours               [DatePicker range]
Display                  [Picker]
Notch expansion          [Toggle]
Hover preview            [Toggle]
Snooze duration          [Picker]
```

### Statistics

```text
Today
Breaks completed         3
Active time              4h 20m
Skipped reminders        1

This Week
Completion               62%
Best day                 Wednesday
```

Guidelines:

- Keep statistics as property groups and compact summaries.
- Place `Clear Today` and `Reset Statistics` at the bottom with destructive styling and confirmation.

### Language, Startup, About

Guidelines:

- Keep these pages native and sparse.
- About should show version, local-first/privacy note, feedback entry, and acknowledgements if needed.
- Avoid marketing copy.

## Design Tokens

### Color

| Token | Light | Dark | Usage |
| --- | --- | --- | --- |
| `appBackground` | `#FFFFFF` / system background | `#1E1E1E` | Main content |
| `sidebarBackground` | `#F7F7F5` | `#252525` | Sidebar |
| `separator` | `#E6E6E3` | `#333333` | Dividers |
| `textPrimary` | `#1F1F1F` | `#F2F2F2` | Primary text |
| `textSecondary` | `#6B6B66` | `#B8B8B2` | Meta text |
| `accent` | `#2E8B57` or system green | system green | Completion and positive actions |
| `selectedRow` | `#EDEDEB` | `#343434` | Selection |
| `hoverRow` | `#F1F1EF` | `#2D2D2D` | Hover |
| `destructive` | system red | system red | Reset and clear actions |

Prefer semantic system colors and asset catalog colors over hardcoded values in SwiftUI. Use the fixed hex values as design targets, not as mandatory literal values everywhere.

### Typography

| Role | Size | Weight |
| --- | --- | --- |
| Page title | 28 | Semibold |
| Section title | 13 | Semibold |
| Body | 13 | Regular |
| Property label | 13 | Regular |
| Meta / caption | 11-12 | Regular |
| Sidebar item | 13 | Regular |
| Overlay title | 14-15 | Semibold |
| Overlay body | 12-13 | Regular |

Use the macOS system font / SF Pro. Do not introduce web fonts.

### Spacing And Radius

| Token | Value |
| --- | --- |
| Sidebar width | 220-240 |
| Main horizontal inset | 24 |
| Block vertical gap | 12-16 |
| Property row height | 32-38 |
| Schedule row height | 40-48 |
| Selected row radius | 6-8 |
| Block radius | 6-8 |
| Separator height | 1px |

## Component Specifications

### Sidebar

- Use `List(selection:)` with `.listStyle(.sidebar)`.
- Top area shows `NotchMove` and a lightweight state label: `Tracking` or `Paused`.
- Sections:
  - Workspace: Today, Schedule, Breaks.
  - Settings: Reminders, Behavior, Statistics, Language, Startup, About.
- Each row uses one SF Symbol and one text label.
- Icon size should visually sit around 16 px.
- Selection uses subtle gray background and 6-8 px radius.
- Avoid badges, dense counters, and saturated accent rows.

Suggested SF Symbols:

| Page | Symbol |
| --- | --- |
| Today | `sun.max` |
| Schedule | `calendar` |
| Breaks | `figure.stand` |
| Reminders | `bell` |
| Behavior | `slider.horizontal.3` |
| Statistics | `chart.bar` |
| Language | `globe` |
| Startup | `power` |
| About | `info.circle` |

### PageHeader

- Contains page title and a single meta line.
- Meta examples:
  - `Next reminder 14:30 · 3 breaks today · Tracking`
  - `Weekday routine · 6 items`
- Right-side actions are limited to one or two toolbar actions such as `Remind Now`, `Add`, or `Pause`.
- Do not create a hero section.

### PropertyRow

```text
[label]                         [native control]
Reminder interval               [30 min ▾]
Sound                           [Toggle]
Auto dismiss                    [Toggle]
```

Guidelines:

- Left label column width: 160-190.
- Right control area aligns consistently.
- Use subtle row separators.
- Put long explanations below the row in secondary caption text.
- Preserve keyboard navigation and VoiceOver labels.

### ScheduleRow

```text
09:30-11:30   Morning focus       Active      5 min before
              Deep work block                 Optional note
```

Guidelines:

- Use tabular numbers for times.
- Title uses primary text.
- Status uses low-saturation text or small neutral tag.
- Notes use secondary text.
- Hover reveals row actions: edit, duplicate, delete.

### StatsBlock

- Use compact numeric summaries and weekly progress strips.
- Avoid dense charts.
- Keep summaries readable at a glance:
  - `3 breaks`
  - `62% this week`
  - `1 skipped`

### NotchOverlay

Break reminder:

```text
[progress ring]  Time to stretch
                 01:42 remaining
                 Stand & Move     Later
```

Schedule reminder:

```text
[small icon/ring]  Team sync
                   16:00 · starts in 10 min
                   Done           Snooze
```

Guidelines:

- Preserve the black notch-shaped overlay as product identity.
- Background: near black, such as `#050505`.
- Primary text: white.
- Secondary text: white at roughly 65% opacity.
- Completion action: low-saturation green / system green.
- Keep the progress ring compact.
- Use 150-240 ms opacity, scale, and offset transitions.
- Avoid exaggerated bounce, large blur, gradients, or decoration.

## Interaction States

### Hover

- Sidebar rows and schedule rows use a subtle gray background.
- Row-level actions can appear on hover to reduce default visual noise.

### Selected

- Use a neutral selected background.
- Do not fill selected rows with high-saturation accent color.

### Disabled

- Reduce opacity to roughly 45%.
- Keep labels readable.
- Explain why a disabled control is unavailable with secondary caption text when needed.

### Empty

```text
No schedule items for today.
[Add schedule item]
```

Keep empty states short and action-oriented.

### Error

- Use system red text for validation errors, time conflicts, unavailable displays, or permission issues.
- Do not introduce large warning cards unless the error blocks the entire page.

### Destructive

- `Reset`, `Clear Today`, and delete actions use system red.
- Require confirmation with `.confirmationDialog` for irreversible actions.

## SwiftUI Implementation Guidance

Keep the root structure selection-driven:

```swift
NavigationSplitView {
    SidebarView(selection: $selection)
} detail: {
    DetailPage(selection: selection)
}
```

Recommended patterns:

- Sidebar: `List(selection:)`, `Section`, `Label`, `.listStyle(.sidebar)`.
- Detail pages: `ScrollView` with a leading `VStack` and 24 px horizontal page inset.
- Settings pages: keep `Form`, `Section`, `Toggle`, `Picker`, `Stepper`, `DatePicker`, and `Button`.
- Selection state: use `@SceneStorage("selectedPage")` when practical.
- Preferences: use `@AppStorage` or the existing settings service.
- Main actions: expose through toolbar buttons and keyboard-accessible buttons.
- Destructive actions: use `.confirmationDialog`.
- Inline editing: prefer property rows and lightweight sheets over complex custom panels.
- Dark mode: use semantic colors and asset catalog colors.
- Overlay: AppKit should continue to own window placement and notch alignment when SwiftUI alone is insufficient; SwiftUI can render the overlay content.

Implementation should avoid:

- Replacing native forms with fully custom controls.
- Painting the full split view with opaque custom backgrounds.
- Turning each section into a heavy shadowed card.
- Using a push-navigation mental model where stable sidebar selection is clearer.

## Acceptance Checklist

- [ ] Main window still uses `NavigationSplitView`.
- [ ] Sidebar has Workspace and Settings sections.
- [ ] Sidebar shows NotchMove status: `Tracking` or `Paused`.
- [ ] Sidebar icons use SF Symbols at roughly 16 px visual size.
- [ ] Sidebar selection uses neutral gray, not high-saturation color.
- [ ] Today first viewport shows current schedule, next schedule, next stand reminder, and status.
- [ ] Today includes a timeline of schedule items.
- [ ] Today has a concise empty state and `Add schedule item` action.
- [ ] Schedule rows show time, title, reminder state, advance reminder, and note.
- [ ] Schedule editing works through inline properties or a lightweight sheet.
- [ ] Reminders, Behavior, Language, Startup, and About use native `Form` and controls.
- [ ] Statistics uses compact numbers and weekly progress, not complex charts.
- [ ] Destructive actions are visually subdued but clear and require confirmation.
- [ ] Main content background follows macOS system background.
- [ ] Blocks use subtle separators and no heavy shadows.
- [ ] Radius stays within 6-8 px for rows and blocks.
- [ ] Light and dark modes both meet WCAG AA contrast for text.
- [ ] Notch overlay keeps the black notch-shaped identity.
- [ ] Overlay uses white primary text, lower-opacity secondary text, and green completion action.
- [ ] Overlay animations stay within 150-240 ms and use opacity, scale, or offset.
- [ ] Overlay supports `Done` / `Snooze` for schedule reminders.
- [ ] Overlay supports `Stand & Move` / `Later` for break reminders.
- [ ] Keyboard navigation and VoiceOver labels are preserved for all controls.
- [ ] UI contains no landing page, hero section, gradient background, large glass effect, or card-heavy dashboard.

## Out Of Scope

- Marketing page redesign.
- Full calendar app behavior.
- Complex health analytics platform.
- Custom illustration system.
- Replacing native macOS controls with custom web-style controls.
