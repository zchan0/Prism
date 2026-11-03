# Changelog

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

