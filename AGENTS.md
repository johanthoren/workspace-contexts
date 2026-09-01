# Agent setup

This file is for coding agents installing or changing Workspace Contexts on an Omarchy machine. Humans follow [README.md](README.md).

Do not edit `/usr/share/omarchy/`. User files live under `~/.config/`.

## Install on a user's machine

The plugin is two layers. The bar widget is an Omarchy plugin. Super+1 and Super+Ctrl+Left/Right are a Hyprland user module that reads the same JSON. `omarchy plugin add` cannot write Hyprland binds.

1. Check whether Super+1 is already rebound.

```bash
omarchy menu keybindings --print | grep -F "SUPER + 1"
```

Stock Omarchy binds Super+1 to global workspace 1. If the line already says "current context", someone installed this module or an older `workspace_contexts.lua`. Do not add a second `dofile`.

2. Add and enable the plugin.

```bash
omarchy plugin add https://github.com/johanthoren/workspace-contexts.git --enable --yes
omarchy plugin validate "$HOME/.config/omarchy/plugins/io.github.johanthoren.workspace-contexts"
```

The GitHub repo may still be private. If `plugin add` cannot clone, copy the checkout to `~/.config/omarchy/plugins/io.github.johanthoren.workspace-contexts/` (manifest id is the directory name) and run `omarchy-shell shell rescanPlugins`, then `omarchy plugin enable io.github.johanthoren.workspace-contexts`. Enable without `--section` uses `defaultSection` `left`.

3. Do not invent hostnames. First parse copies `contexts.example.json` to `$HOME/.config/omarchy/io.github.johanthoren.workspace-contexts/contexts.json` if that file is missing. If the file already exists, leave it. Never write `contexts.json` inside the plugin checkout. `plugin update` would overwrite it.

4. Load the Hyprland module once from `~/.config/hypr/bindings.lua`.

If the file already has `require("hypr.workspace_contexts")` or another `dofile` of this plugin's `hypr/contexts.lua`, replace that line. Do not stack both.

```lua
dofile(os.getenv("HOME") .. "/.config/omarchy/plugins/io.github.johanthoren.workspace-contexts/hypr/contexts.lua")
```

The Lua file unbinds Super+1..9 (stock global workspaces) before it rebinds them as slots in the current bank. Tell the user Super+1 was global workspace 1.

5. Reload and check.

```bash
hyprctl reload
hyprctl configerrors
omarchy menu keybindings --print | grep -F "current context"
```

`configerrors` must be empty. Super+1 must print "Switch to workspace 1 in current context".

6. Prove the bar. The left section should show slot numbers for the active bank, then a button per `name` in the JSON, colored from the theme keys `blue` / `green` / `magenta` / `yellow` / `cyan` / `red`.

## Change the context list

Edit `$HOME/.config/omarchy/io.github.johanthoren.workspace-contexts/contexts.json`. A row is `{ "name": "...", "base": <int>, "accent": "<color>" }`. Omit `accent` to take the next color in the cycle. Omit `base` to use `index * stride`. Cap is 10 rows. After a `slots` change, run `hyprctl reload` again.

## Change this repo

The git root is `$HOME/code/workspace-contexts`. Do not treat `~/.config/omarchy/plugins/io.github.johanthoren.workspace-contexts` as the source tree. That directory is the install clone Omarchy loads. `omarchy plugin validate` rejects symlinks, so the two paths are two checkouts of the same GitHub remote.

After you commit in `$HOME/code/workspace-contexts`, update the install clone so the running shell sees the files:

```bash
git -C "$HOME/.config/omarchy/plugins/io.github.johanthoren.workspace-contexts" pull --ff-only
```

```bash
python3 parse_contexts_test.py
lua hypr/contexts_test.lua
omarchy plugin validate .
```

`parse_contexts.py --dump` is the filled table QML and Hyprland consume. Do not reimplement bank math in QML or Lua. Do not add Herdr, hostnames, or picker code here.
