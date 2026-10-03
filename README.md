# Pip: a desktop pet for macOS

A small 8-bit mint slime with a leaf sprout that lives in the bottom-right corner of your screen,
above every window (including full-screen apps). It's styled like a retro video
game: pixel-art sprite, RPG dialog windows, arcade fonts and chiptune sound
effects. Click it to open a game-menu card with:

- **Talk**: chat with Claude (Opus 5.5, low effort for quick replies). Paste an
  Anthropic API key the first time; it's stored in
  `~/Library/Application Support/DesktopPet/api_key` with owner-only permissions.
- **Quest**: a Pomodoro focus/break timer with a segmented progress bar. While it
  runs, a status window sits next to Pip, and Pip hops and plays a level-up
  jingle when time's up.
- **Log**: a scratchpad "quest log" that saves automatically.

Pip's eyes follow your cursor. It blinks, gets happy when you hover or click,
looks focused during a timer, thinks while Claude replies, and falls asleep
after 10 minutes without mouse movement. The window is click-through
everywhere except the pet and the open card.

Pip hides when the Mac goes to sleep or the laptop lid closes (even when an
external display keeps the Mac awake), and comes back when you wake the Mac or
open the lid. A running focus timer pauses while you're away. It stays through
screen lock and the screensaver. If you hide Pip from the menu, it stays hidden
after wake. Turn on Open at Login if you want it back after a restart.

A game controller icon in the menu bar can show or hide Pip, open each tab, start
a focus session, turn sound effects on or off, toggle Open at Login, and quit.

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
- `Sources/PetView.swift`: the 20x16 pixel slime sprite, its faces per mood, and the dialog box.
- `Sources/Theme.swift`: pixel fonts, colors, window frames, buttons, and the
  square-wave sound effects (synthesized in code, no audio files).
- `Sources/CardView.swift`: the speech bubble and the Chat, Timer, Notes card.
- `Sources/Chat.swift`: the Claude Messages API client over plain HTTP.
- `Sources/Pomodoro.swift`, `Sources/Notes.swift`, `Sources/PetModel.swift`: state.

Continuous motion runs in the system compositor, so the app idles under 1% CPU.

Fonts: [Press Start 2P](https://fonts.google.com/specimen/Press+Start+2P) and
[VT323](https://fonts.google.com/specimen/VT323), both under the SIL Open Font
License (copies in `Resources/Fonts`).
