# NotchMove Improvement Loops

This folder tracks the repeatable loops used to improve NotchMove without
letting the product drift away from its core reminder-first purpose.

## Product Guardrail

NotchMove is a native macOS menu bar utility for movement and focus reminders.
Every loop must protect these constraints:

- Keep the main experience reminder-first.
- Keep the app local-first and lightweight.
- Keep Notch Hub optional and lower priority than voice input and active
  reminders.
- Do not add accounts, cloud sync, analytics, payments, or broad dashboard
  surfaces.
- Preserve staged notch overlay motion and `visibleSize` hit testing.

## Cycle Shape

Each cycle should follow this order:

1. Signal scan
   - Read recent plans, QA notes, release notes, test failures, and user
     feedback.
   - Classify signals into `core-reminder`, `overlay-motion`, `permissions`,
     `packaging`, `localization`, `manual-qa`, or `retained-module`.

2. Scope gate
   - Ask whether the change improves reminders, overlay reliability,
     installation, permissions, or everyday menu bar use.
   - Park anything that mostly expands AI, schedule, voice, or Hub breadth.

3. Pick one small fix
   - Prefer high-risk bugs over visual polish.
   - Prefer existing plans with clear acceptance criteria.
   - Keep each patch small enough to verify in the same cycle.

4. Patch and verify
   - Use focused code changes.
   - Run `script/loop_verify.sh`.
   - For release work, also run `script/package_dmg.sh`.

5. Record the result
   - Update `docs/loops/backlog.md`.
   - Add a cycle note when the result changes product direction, verification
     practice, or release readiness.

## Verification

Default verification:

```sh
script/loop_verify.sh
```

This runs:

- `git diff --check`
- `plutil -lint` on project, entitlements, and localization files
- localization key and placeholder parity across English, Simplified Chinese,
  Traditional Chinese, and Japanese
- source-level privacy, entitlement, Hardened Runtime, and distribution safety
  checks, including a block on Gatekeeper quarantine-bypass instructions
- `xcodebuild test` for the NotchMove scheme

If Swift package state is stale, refresh dependencies first:

```sh
xcodebuild -resolvePackageDependencies \
  -project NotchMove/NotchMove.xcodeproj \
  -scheme NotchMove
```

## Backlog States

- `active`: selected for the current or next cycle.
- `ready`: scoped and ready to implement.
- `blocked`: needs external input, manual device access, credentials, or a
  signed local run.
- `parked`: useful, but not part of the current reminder-first loop.
- `done`: verified or confirmed already implemented.
