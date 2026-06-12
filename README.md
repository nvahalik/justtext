# Just Text

A bare-bones macOS scratch editor that pipes its buffer through shell commands. Think [`vipe`](https://joeyh.name/code/moreutils/) with a window: text comes in on stdin, you filter and edit it, and it goes back out on stdout.

The whole app is ~75 lines of SwiftUI in a single file (`JustText.swift`). No Xcode project, no dependencies.

## Features

- **Full-window monospaced editor** — nothing else in the way.
- **Pipe through a command** — press **⇧⌘|**, type any shell command, and the buffer is piped to its stdin and replaced with its stdout (stderr included, so errors show up too). Runs via `/bin/sh -c`, so pipes/flags/args all work.
- **Undo/redo** — **⌘Z** / **⇧⌘Z**. Pipes and normal typing share one undo stack.
- **stdin → buffer** — if launched with piped stdin, the buffer is seeded with it.
- **buffer → stdout** — on quit (or closing the window), the buffer is written to stdout *only if stdout is a pipe/redirect*, never to an interactive terminal.

## Build

Requires the Swift toolchain (ships with Xcode / Command Line Tools).

```sh
sh build.sh
```

This produces `Just Text.app`:

- Compiles `JustText.swift` with `swiftc -O -parse-as-library`.
- Renders the icon (`render_icon.swift` → `icon_1024.png`) and bundles it as `AppIcon.icns`.
- Writes a minimal `Info.plist`.

> Note: `swiftc -parse-as-library` is required because a lone Swift file is otherwise treated as a script, which conflicts with `@main`. (Editors may show a spurious "`'main' attribute cannot be used…`" diagnostic — the build is unaffected.)

## Usage

```sh
# Round-trip a file through the editor
./justtext < input.txt > output.txt

# Filter the clipboard
pbpaste | ./justtext | pbcopy

# Just inspect/edit — output dumps to stdout only when piped
cat data.json | ./justtext
```

`justtext` is a launcher script that forwards stdin into the bundled binary. To use it from anywhere, symlink it onto your `PATH` (keep it next to the `.app`, which it resolves relative to itself):

```sh
ln -s "$PWD/justtext" /usr/local/bin/justtext
```

### In-app

| Shortcut        | Action                                    |
| --------------- | ----------------------------------------- |
| **⇧⌘\|**        | Prompt for a shell command, pipe buffer through it |
| **⌘Z / ⇧⌘Z**    | Undo / redo (pipes and edits)             |
| **⌘W / ⌘Q**     | Close window / quit (flushes stdout)      |

## Alfred integration

Create a **Universal Action** workflow (Alfred Powerpack required):

1. New Blank Workflow → **Inputs → Universal Action**, accepts **Text**.
2. Add an **Actions → Run Script** (`/bin/bash`, input as **argv**):
   ```sh
   printf '%s' "$1" | "/Users/nvahalik/Code/textpad/Just Text.app/Contents/MacOS/JustText" | pbcopy
   ```
3. Wire the Universal Action to the Run Script.

Select text anywhere → Universal Actions (⌘⌥\ by default) → **Just Text** → edit → close → result lands on your clipboard.

## Files

| File               | Purpose                                  |
| ------------------ | ---------------------------------------- |
| `JustText.swift`   | The entire app                           |
| `build.sh`         | Compile + bundle into `Just Text.app`    |
| `render_icon.swift`| Draws `icon_1024.png` via CoreGraphics   |
| `justtext`         | CLI launcher that forwards stdin         |
