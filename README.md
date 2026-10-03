# Pip: a desktop pet for macOS

A small creature that lives in the bottom-right corner of your screen, above
every window (including full-screen apps). Click it to open a card with:

- **Chat**: talk to Claude (Opus 5.5, low effort for quick replies). Paste an
  Anthropic API key the first time; it's stored in
  `~/Library/Application Support/DesktopPet/api_key` with owner-only permissions.
- **Timer**: a Pomodoro focus/break timer. A ring around Pip shows progress, and
  Pip jumps and chimes when time's up.
- **Notes**: a scratchpad that saves automatically.

Pip's eyes follow your cursor. It blinks, gets happy when you hover or click,
looks focused during a timer, thinks while Claude replies, and falls asleep
after 10 minutes without mouse movement. The window is click-through
everywhere except the pet and the open card.

A paw icon in the menu bar can show or hide Pip, open each tab, start a focus
session, toggle Open at Login, and quit.

## Build and run

Needs the Xcode command line tools (Swift 5.10+) and macOS 13 or later.

```sh
./build.sh            # builds build/DesktopPet.app
./build.sh --install  # also copies it to ~/Applications and launches it
tools/snapshot.sh     # renders preview PNGs of every mood and tab to build/snapshots
```

## How it works

- `Sources/main.swift`: the borderless, transparent, always-on-top panel, the
  menu bar item, cursor polling for eye tracking and click-through, and the
  Core Animation bobbing and breathing.
- `Sources/PetView.swift`: the creature, drawn in SwiftUI as still poses.
- `Sources/CardView.swift`: the speech bubble and the Chat, Timer, Notes card.
- `Sources/Chat.swift`: the Claude Messages API client over plain HTTP.
- `Sources/Pomodoro.swift`, `Sources/Notes.swift`, `Sources/PetModel.swift`: state.

Continuous motion runs in the system compositor, so the app idles around 1% CPU.
