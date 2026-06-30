# Task Command Center Contract

`bar/FocusPanel.qml` is no longer a multi-page loader. It is a single
keyboard-first task command center.

## Runtime Shape
- `Super+Shift+Return` / `qs ipc call panel focus` opens the floating
  `title:focus-panel` window.
- Layout: filters left, task list center, selected task + active block detail
  right, mode/status bar bottom.
- Modes: `normal`, `search`, `command`, `prompt`, `picker`, `confirm`, `help`.
- Overlays are keyboard-first and never expose mouse-only actions.

## Data / Writes
- `Tasks.all`, `Tasks.done`, `Tasks.projects`, `Tasks.tags` remain the read model.
- `TaskActions` remains the write API:
  `startBlock`, `stopBlock`, `done`, `remove`, `setPriority`, `setDue`,
  `setProject`, `addTag`, `removeTag`, `annotate`, and raw `cmd`.
- Writes are async host-bridge requests; UI shows "queued" and refreshes shortly.

## Config
- Active YAML: `~/.config/quickshell/task-ui.yaml`
- Profiles:
  - `task-ui/themes/dracula.yaml`
  - `task-ui/themes/catppuccin-mocha.yaml`
  - `task-ui/keybinds/default.yaml`
- `TaskUiConfig.qml` reads normalized JSON from `qs-task-ui-config.sh`.
- Help and command palette labels must use `TaskUiConfig.bindLabel(action)`.

## Default Keys
- `↑↓` move, `Enter` start selected block.
- `n` new + start, `e` edit description, `x` done, `s` start/stop.
- `dd` delete with confirmation, `p` cycle priority, `r` due, `+` project,
  `t` tags, `m` note.
- `/` search, `:` command palette, `fp` project picker, `ft` tag picker,
  `fs` status picker, `C` clear filters, `?` help, `Esc` clear/back/close.
