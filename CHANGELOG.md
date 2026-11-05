# Changelog

## [0.1.0] - 2026-11-05

First version.

- A menu bar toolbox. Each tool can be turned on or off, and shown as its own menu bar icon or kept only in the
  hub. When no tool is in the menu bar, a small Prism icon keeps the hub reachable.
- Two panels. A click on a tool's icon opens its quick panel, with that tool's controls only. The hub has one tab
  per tool, with the tool's switches, controls and settings, and a gear tab for open at login, the shortcut and the
  version. ⌃⌥⌘L opens or closes the hub at the pointer.
- Lumos keeps the Mac awake for 30 minutes, 1 hour, 2 hours, or until stopped, with a kernel power assertion. It can
  keep the screen on too, show the time left in the menu bar, stop at a chosen battery level, and tell you when a
  session ends.
- Lumos can keep the Mac running with the lid closed, through a small root helper installed with one administrator
  prompt. The helper checks whether Prism still holds a flag file open, so a crash gets the normal sleep setting
  back within a minute.
- Vitals shows CPU, memory, disk and battery, each reading you pick with its own menu bar icon, and refreshes them
  together every 20 seconds. CPU is split into user and system time; the battery adds its maximum capacity and cycle count.
- Menu bar icons are SF Symbol templates with an optional monospaced number, so the menu bar tints them like the
  system's own.
- English and Chinese.
