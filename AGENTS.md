# Agent setup

This file is for coding agents installing or changing Workspace Contexts on an
Omarchy machine. Humans follow [README.md](README.md).

Do not edit `/usr/share/omarchy/`. User files live under `~/.config/`.

## Install on a user's machine

The plugin is two layers. The bar widget is an Omarchy plugin. Super+1 and
Super+Ctrl+Left/Right are a Hyprland user module that reads the same JSON.
`omarchy plugin add` cannot write Hyprland binds.

1. Check whether Super+1 is already rebound.

```bash
omarchy menu keybindings --print | grep -F "SUPER + 1"
```

Stock Omarchy binds Super+1 to global workspace 1. If the line already says
"current context", someone installed this module or an older
`workspace_contexts.lua`. Do not add a second `dofile`.

2. Add and enable the plugin.

```bash
omarchy plugin add https://github.com/johanthoren/workspace-contexts.git --enable --yes
omarchy plugin validate "$HOME/.config/omarchy/plugins/io.github.johanthoren.workspace-contexts"
```

Enable without `--section` uses `defaultSection` `left`. Then take stock
workspaces off the bar, or the left section shows both:

```bash
omarchy plugin disable omarchy.workspaces
```

3. Do not invent hostnames. First parse copies `contexts.example.json` to
`$HOME/.config/omarchy/io.github.johanthoren.workspace-contexts/contexts.json` if
that file is missing. If the file already exists, leave it. Never write
`contexts.json` inside the plugin checkout. `plugin update` would overwrite it.

4. Load the Hyprland module once from `~/.config/hypr/bindings.lua`.

If the file already has `require("hypr.workspace_contexts")` or another `dofile`
of this plugin's `hypr/contexts.lua`, replace that line. Do not stack both.

```lua
dofile(os.getenv("HOME") .. "/.config/omarchy/plugins/io.github.johanthoren.workspace-contexts/hypr/contexts.lua")
```

The Lua file unbinds Super+1..9 (stock global workspaces) before it rebinds them
as slots in the current bank. Tell the user Super+1 was global workspace 1.

5. Reload and check.

```bash
hyprctl reload
hyprctl configerrors
omarchy menu keybindings --print | grep -F "current context"
```

`configerrors` must be empty. Super+1 must print "Switch to workspace 1 in
current context".

6. Prove the bar. The left section should show slot numbers for the active bank,
then a button per `name` in the JSON, colored from the theme keys `blue` /
`green` / `magenta` / `yellow` / `cyan` / `red`.

## Change the context list

Edit `$HOME/.config/omarchy/io.github.johanthoren.workspace-contexts/contexts.json`.
A row is `{ "name": "...", "base": <int>, "accent": "<color>" }`. Omit `accent` to
take the next color in the cycle. Omit `base` to use `index * stride`. A row is
dropped when its name is empty or duplicated, its `base` is negative, its last
workspace id is greater than 99, or its range overlaps an already-accepted bank.
Default cap is 10 rows (`maxContexts`).

`slots` is capped at 10. Slots become Super+N binds across the number row, and a
higher value would reach past it into Super+BackSpace, Super+Tab, and the letters,
silently taking over stock Omarchy shortcuts.

Edits apply on the next keypress. Only a `slots` change needs `hyprctl reload`,
because `slots` decides which keys get bound.

## Change this repo

The git root is `$HOME/code/workspace-contexts`. Do not treat
`~/.config/omarchy/plugins/io.github.johanthoren.workspace-contexts` as the source
tree. That directory is the install clone Omarchy loads. `omarchy plugin validate`
rejects symlinks, so the two paths are two checkouts of the same GitHub remote.

After you commit in `$HOME/code/workspace-contexts`, update the install clone so
the running shell sees the files:

```bash
git -C "$HOME/.config/omarchy/plugins/io.github.johanthoren.workspace-contexts" pull --ff-only
```

```bash
python3 parse_contexts_test.py
omarchy plugin validate .
```

`parse_contexts_test.py` is the entry point. It runs `hypr/contexts_test.lua`
through `lua5.1` under a temporary `HOME`. The Lua file also runs standalone
(`lua5.1 hypr/contexts_test.lua`, from any directory), where it asserts the shape
of the filled table rather than specific names, because it then reads the real
user's `contexts.json`.

`parse_contexts.py --dump` is the filled table QML and Hyprland consume. Do not
reimplement bank math in QML or Lua. Do not add Herdr, hostnames, or picker code
here.

`hypr/contexts.lua` caches the dump against the raw text of `contexts.json`.
Every keybind resolves the current file, and each dump forks a Python interpreter
inside the compositor's Lua VM (~40 ms). Keep the hot path fork-free.
