# Changelog

## [0.2.1] - 2026-11-04

- The disk tool is now **Vitals**: one tool for system readings — disk, memory and battery — instead of a tool per
  number. It shows one reading in the menu bar and all of them in the panel.
- No more Prism icon in the menu bar. Each tool's icon carries an "Open Prism" menu item instead, so the hub is
  reachable from any tool. A small Prism icon appears only when every tool is set to panel-only, since otherwise
  there would be no way into the panel at all.
- Fixed the settings window: a tool's page was a nested `Form`, whose preferred size stretched the window to
  1279 points tall, and the segmented controls were squeezed into unusable widths. Tool pages are now plain content
  inside the shell's one form, sidebar-style menus replace the segments, and the window is 600 × 640.
- A tool added in a later version now starts turned on. Previously, anybody who had ever toggled a tool had a saved
  enabled set that silently excluded every tool added after that.

## [0.2.0] - 2026-11-04

Prism: LumosMaxima becomes a small toolbox.

- The app is now Prism, with a hub panel listing every tool, and each tool can be shown as its own menu bar icon or
  only inside the panel — configured per tool in Settings.
- The awake behaviour is unchanged and is now the first tool (`awake`). Its settings, pet age and lid switch are
  migrated once from the old bare keys, so an existing install keeps everything.
- New disk tool (`disk`): free space in the menu bar, a capacity breakdown in the panel, refreshed every minute and
  whenever the panel opens.
- Tools are separate SwiftPM modules that only see the shell, never each other. Adding one is a module plus a line
  in `AppDelegate.registrations()`. A tool can also adopt `MenuBarPresenter` to open its own panel.
- The bundle id is unchanged on purpose, so notification permission and the login item survive.

## [0.1.2] - 2026-11-03

- Clicking the pet opens a small strip with just the four lengths and a close button; a double click opens Settings.
- Dragging the pet follows the pointer exactly. The old SwiftUI `DragGesture` measured its translation in global
  coordinates, which the window moved as it was being dragged, so the pet lagged and often refused to move at all.
  AppKit mouse events with a remembered grab point replace it, with unit tests.
- The length row sits properly below the header instead of being pinned against the divider.
- The menu bar icon is an SF Symbol template, `sun.min` / `sun.max` / `sun.max.fill`, so the system tints it like
  its neighbors on a light, a dark or a tinted menu bar.

## [0.1.1] - 2026-11-03

- "Until I stop it" is now the default length, and it comes first in the panel and in Settings.
- Clicking the pet opens the control panel instead of starting or stopping the session: the same panel the menu
  bar item opens, lifted above the sun, or dropped below it when the pet sits near the top of the screen.

## [0.1.0] - 2026-11-03

First version.

- Keep the Mac awake for 30 minutes, 1 hour, 2 hours, or until stopped, with a kernel power assertion.
- Optionally keep the screen on as well, and show the countdown in the menu bar.
- Keep running with the lid closed through a small root helper, installed with one administrator prompt.
- Stop on low battery at a chosen percentage, with a notification.
- A sun pet that naps when the Mac may sleep, wakes and animates when it may not, and grows with the hours it logs.
- Open at login, a global shortcut, English and Chinese.
- The pet draws in one canvas: 6 fps awake, 3 fps asleep, and no work at all when hidden.

