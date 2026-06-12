# NotchMove Loop Backlog

Last updated: 2026-06-12

## Active

No active code item is selected after Cycle 001. The audited high-priority
items from the existing Notch Hub and hover plans are already implemented in
this checkout. The next loop should start from fresh feedback, a failing
verification result, or the blocked signed smoke test.

## Ready

No ready code item is currently selected.

## Blocked

### L006 - Signed manual smoke test

- Category: `manual-qa`, `packaging`
- Source: `docs/qa/notchmove-smoke-test.md`
- Status: blocked
- Blocker: needs a signed local app run and real UI/manual permission checks.
- Acceptance:
  - Menu bar, settings, overlay, and voice input checklist are run on a signed
    local build.
  - Failures become separate loop items.

## Parked

### L007 - AI schedule and voice expansion plans

- Category: `retained-module`
- Source:
  - `docs/plans/2026-04-30-ai-voice-schedule-design.md`
  - `docs/plans/2026-05-01-ai-schedule-assistant-implementation-plan.md`
  - `docs/plans/2026-05-01-ai-input-full-flow-optimization-plan.md`
- Status: parked
- Reason: useful retained modules, but not part of the current
  reminder-first improvement loop unless a concrete release blocker appears.

## Done

### L001 - Establish loop baseline verification

- Category: `verification`
- Source: loop kickoff
- Status: done
- Evidence:
  - `docs/loops/README.md` documents the cycle.
  - `script/loop_verify.sh` runs the standard automated checks.
  - Cycle 001 verification passed on 2026-06-12.

### L002 - Move Camera Mirror session work off the main thread

- Category: `permissions`, `overlay-motion`
- Source: `docs/plans/2026-06-07-notch-hub-review-fix-plan.md`
- Status: done
- Evidence:
  - `CameraMirrorPreview.Coordinator` owns a serial `sessionQueue`.
  - Camera session configuration, `startRunning()`, and `stopRunning()` run on
    that queue.

### L003 - Keep Hub presentation normalized when disabling Hub or widgets

- Category: `core-reminder`, `permissions`
- Source: `docs/plans/2026-06-07-notch-hub-review-fix-plan.md`
- Status: done
- Evidence:
  - `disablingHubCollapsesExpandedPresentation` covers disabling Hub.
  - `disablingActiveWidgetMovesExpandedPresentationToNormalizedSelection`
    covers disabling the active widget.

### L004 - Route production priority through a single resolver

- Category: `core-reminder`, `overlay-motion`
- Source: `docs/plans/2026-06-07-notch-hub-review-fix-plan.md`
- Status: done
- Evidence:
  - `NotchWindowController` and `NotchView` both call
    `NotchHubPresentationResolver.effectiveSurface(...)`.
  - Resolver tests cover voice and active reminder priority over Hub.

### L005 - Hover next reminder preview

- Category: `overlay-motion`, `core-reminder`
- Source: `docs/plans/2026-06-03-hover-next-reminders-plan.md`
- Status: done
- Evidence:
  - `ReminderEngine.nextReminderPreview(at:)` computes break and Pomodoro rows.
  - `NextReminderPreviewView` renders the hover preview.
  - `OverlaySizingRole.dualPreview` and placement tests cover the expanded
    hover sizing path.

### L008 - Gate Media refresh behind Apple Events permission

- Category: `permissions`
- Source: `docs/plans/2026-06-07-notch-hub-review-fix-plan.md`
- Status: done
- Evidence:
  - `NotchHubStore.refreshActiveWidget()` resets media status and returns when
    `allowAppleEvents` is false.
  - `NotchHubStore.refreshMediaStatus()` also guards provider access.
  - `mediaRefreshDoesNotCallProviderUntilAppleEventsAllowed` covers the
    behavior.
