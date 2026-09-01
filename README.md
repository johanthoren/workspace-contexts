# How to set up Workspace Contexts

This plugin splits Hyprland workspaces into named banks. The bar shows slot numbers for the active bank, then a button for each bank name. Colors come from the current Omarchy theme.

## Add the plugin

```bash
omarchy plugin add https://github.com/johanthoren/workspace-contexts.git --enable
```

The GitHub repo is private today. Use that same add command after the repo is public. Enable places the widget on the left of the bar.

## Write the context list

The plugin reads `$HOME/.config/omarchy/io.github.johanthoren.workspace-contexts/contexts.json`.

On first parse, the plugin copies `contexts.example.json` there if that file does not exist. To copy it yourself:

```bash
mkdir -p "$HOME/.config/omarchy/io.github.johanthoren.workspace-contexts"
cp "$HOME/.config/omarchy/plugins/io.github.johanthoren.workspace-contexts/contexts.example.json" \
  "$HOME/.config/omarchy/io.github.johanthoren.workspace-contexts/contexts.json"
```

The example file lists three banks. `work` uses workspaces 1 to 9 in blue. `personal` uses 11 to 19 in green. `other` uses 21 to 29 in magenta.

## Bind Super+N to the current bank

Add this line once to `~/.config/hypr/bindings.lua`:

```lua
dofile(os.getenv("HOME") .. "/.config/omarchy/plugins/io.github.johanthoren.workspace-contexts/hypr/contexts.lua")
```

Then reload Hyprland:

```bash
hyprctl reload
```

Super+1 through Super+9 focus slots in the current bank. Super+Shift+N moves a window. Super+Shift+Alt+N moves it without following. Super+Ctrl+Left and Super+Ctrl+Right cycle banks. Super+Ctrl+Shift+Left and Super+Ctrl+Shift+Right move the window to the adjacent bank.

## Add a fourth bank

Edit `contexts.json` and append a row. You can omit `accent`. The parser picks the next name from this cycle: blue, green, magenta, yellow, cyan, red.

```json
{ "name": "notes", "base": 30 }
```

Reload Hyprland if you changed `slots`. Super+Ctrl+Left and Super+Ctrl+Right then cycle all four banks.

The plugin is MIT licensed.
