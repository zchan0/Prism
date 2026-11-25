# Changelog

All notable changes to Prism are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [0.3.0] - 2026-11-25

- Pensieve, a new tool: a history of the last 200 things you copied, whether text, pictures, files or colors. ⇧⌘V
  opens it in the middle of the screen, and the app you were in stays in front. Return puts an item back on the
  clipboard with all its formats, for you to paste.
- Pensieve searches text, file names and colors, and leaves out what apps mark as private, such as passwords. It
  saves the history in ~/Library/Application Support/Prism/Pensieve, a folder only you can open, without encryption.
  Recording can be paused, and the history cleared.
- Pensieve's panel lists the latest 10 items: a click copies one and closes the panel, and *Search* opens the history.
  Its shortcut, recorded with the same field as Portkey's, the pause switch and Clear history are on its page in the
  Prism window.
- The Prism window replaces the hub. It is a regular window with every tool in a list on the left, each with what it
  is doing now, and the chosen tool's page on the right: the switch that turns the tool on or off, its controls, its
  settings, and its Menu Bar card last. *General* holds Appearance, Open at login, the version and Quit Prism.
- The Prism window opens from the gear at the bottom of a tool's panel and from *Prism Settings…* when you
  right-click a tool's icon, both on that tool's page; from the Prism icon when no tool is in the menu bar; when you
  open Prism again while it runs; and by itself the first time Prism runs after a new install.
- A click on a tool's icon opens a panel with that tool alone, and its name and the gear at the bottom.
- Lumos's panel is one card with the time left, a switch and the lengths ∞, 30m, 1h and 2h, which turns amber while
  the Mac is kept awake, and two buttons, Screen and Lid closed, in place of the two switches.
- Portkey's panel lists every app with its shortcut, and a click goes to the app. The apps and their shortcuts are
  edited on Portkey's page in the Prism window, which replaces the Portkey window.
- The Pensieve window shows one line per item, a filter for All, Text, Links, Images or Files at the right of the
  search field, and the keys at the bottom; on macOS 26 it sits on glass. Tab and ⇧Tab go through the filters, and the
  window opens on All. Text includes colors and links.
- A selected picture in the Pensieve window, or a picture the pointer rests on in Pensieve's panel, shows larger next
  to it, with its size in pixels.
- Pensieve keeps 50, 100, 200, 500 or 1000 items, 200 by default; a lower number deletes the oldest at once. Items
  are deleted a day, a week, a month or three months after they were last copied, or never; a month by default.
- Pensieve does not record what is copied while an app on its *Don't record from* list is in front. Passwords and
  Keychain Access are on it until the list is changed.
- ⌘, opens the Prism window on the tool's page while a tool's panel is open, and on Pensieve's page while the
  Pensieve window is.
- *Appearance* on *General* keeps Prism light or dark, or lets it follow the system.
- Lumos's battery note and its errors sit in a card under the Screen and Lid closed buttons, and the battery note is
  shorter: "Stops at 20% battery". *Lid closed* says *Stays awake* while it is on.
- Each tool's line in the Prism window is short: "29 min left", "78.95 GB free", "4 apps", "5 items".

## [0.2.0] - 2026-11-23

- Portkey, a new tool: a global shortcut for each app you add. The shortcut brings the app to the front, opens it if
  it is not running, and hides it if it is in front already. It needs no Accessibility permission.
- Each app gets a shortcut recorded in the Portkey window, any combination with ⌘, ⌃ or ⌥. A shortcut belongs to one
  app at a time, and the window says so under the app when another app has it or macOS refuses it.
- Apps are added from the ones that are open, the ones in the Dock, or any app in Applications, and start without a
  shortcut. The hub and the quick panel show how many apps there are, with a button that opens the window.
- ⌃⌥⌘L no longer opens the hub. The hub opens from the button at the bottom right of a quick panel, from *Open Prism*
  when you right-click a tool's icon, or from the Prism icon when no tool is in the menu bar.

## [0.1.0] - 2026-11-06

First version. It runs on macOS 14 or later, on Apple silicon and Intel.

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

[Unreleased]: https://github.com/zchan0/Prism/compare/v0.2.0...HEAD
[0.3.0]: https://github.com/zchan0/Prism/releases/tag/v0.3.0
[0.2.0]: https://github.com/zchan0/Prism/releases/tag/v0.2.0
[0.1.0]: https://github.com/zchan0/Prism/releases/tag/v0.1.0
