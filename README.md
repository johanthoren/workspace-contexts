# Workspace Contexts

An Omarchy plugin that splits Hyprland workspaces into named banks.

Instead of ten flat workspaces, you get several banks of nine. Super+1 through
Super+9 always mean "slot 1 through 9 of the bank I am in", and Super+Ctrl+Left
and Super+Ctrl+Right move between banks. The bar shows the slots for the active
bank, then a button for each bank name, colored from the current Omarchy theme.

The shipped configuration gives you three banks: `work` on workspaces 1 to 9 in
blue, `personal` on 11 to 19 in green, and `other` on 21 to 29 in magenta.

## Requirements

- Omarchy with the Quickshell bar and the Hyprland Lua configuration
- `python3` at `/usr/bin/python3`
- `lua5.1`, to run the test suite

## Install

```bash
omarchy plugin add https://github.com/johanthoren/workspace-contexts.git --enable
```

`--enable` places the widget on the left of the bar, after stock
`omarchy.workspaces`. This widget replaces that one:

```bash
omarchy plugin disable omarchy.workspaces
```

That installs the bar widget. The keybindings are a separate layer, because
`omarchy plugin add` cannot write Hyprland binds. Add this line once to
`~/.config/hypr/bindings.lua`:

```lua
dofile(os.getenv("HOME") .. "/.config/omarchy/plugins/io.github.johanthoren.workspace-contexts/hypr/contexts.lua")
```

Then reload Hyprland:

```bash
hyprctl reload
```

## Keys

| Keys | Action |
| --- | --- |
| Super+1 to Super+9 | Focus a slot in the current bank |
| Super+Shift+1 to Super+Shift+9 | Move the window to that slot and follow it |
| Super+Shift+Alt+1 to Super+Shift+Alt+9 | Move the window to that slot without following |
| Super+Ctrl+Left / Right | Go to the previous or next bank |
| Super+Ctrl+Shift+Left / Right | Move the window to the adjacent bank |

Super+1 through Super+9 were stock Omarchy's global workspaces 1 to 9. The Lua
module unbinds them before rebinding them as slots. Super+0 stays stock global
workspace 10 while `slots` is 9, the default. `slots: 10` rebinds Super+0 as
slot 10 of the current bank. Super+Ctrl+Left and Super+Ctrl+Right were stock's
grouped-window focus. Super+Shift+N, the letter, stays stock Editor.

Each bank remembers the slot you last used in it, so returning to a bank returns
you to where you left off. Clicking a bank name on the bar does the same.

## Configure

The plugin reads
`~/.config/omarchy/io.github.johanthoren.workspace-contexts/contexts.json`, and
copies `contexts.example.json` there on first run if it is missing. Your file is
never overwritten, including when it fails to parse. A parse failure keeps the
last good dump, from
`~/.local/state/omarchy/io.github.johanthoren.workspace-contexts/last-good.json`
if needed, and writes the reason to stderr. Editing a valid file takes effect on
the next keypress. Reload Hyprland after you change `slots`.

```json
{
  "stride": 10,
  "slots": 9,
  "maxContexts": 10,
  "contexts": [
    { "name": "work", "base": 0, "accent": "blue" },
    { "name": "personal", "base": 10, "accent": "green" },
    { "name": "other", "base": 20, "accent": "magenta" }
  ]
}
```

| Key | Meaning |
| --- | --- |
| `stride` | Spacing between banks that omit `base`. Default 10. |
| `slots` | Workspaces per bank, and how many Super+N keys get bound. Default 9, capped at 10. |
| `maxContexts` | How many rows to read before stopping. Default 10. |
| `fallback` | Hex colors used when the theme does not define an accent. |
| `contexts[].name` | The bar label. Must be unique. |
| `contexts[].base` | Bank occupies `base + 1` through `base + slots`. Optional, defaults to `index * stride`. |
| `contexts[].accent` | One of blue, green, magenta, yellow, cyan, red. Optional. |

To add a fourth bank, append a row. Omit `accent` and the parser takes the next
color in the cycle: blue, green, magenta, yellow, cyan, red.

```json
{ "name": "notes", "base": 30 }
```

A row is dropped if its name is empty or a duplicate, its `base` is negative,
its last workspace id is greater than 99, or its range overlaps a bank already
accepted. Dropped rows stay in your file. The dump keeps the rows that survived
and names the drops on stderr. If no row survives, or the file is not JSON, the
bar and keys keep the last good dump. On first run, with nothing to keep, they
use the shipped three. `slots` above 10 clamps to 10, because the number row
runs out.

Reload Hyprland after changing `slots`, since that decides which keys get bound.

## What the bar shows

The bar shows the first five slots of the active bank, plus any other slot in
that bank that has a window in it. That matches how stock Omarchy's workspace
widget behaves. Slot numbers are bank-local: slot 1 of `personal` reads `1`, not
`11`.

With the shipped configuration, workspaces 10, 20, and 30 belong to no bank.
Landing on one, for example with Super+0, leaves the bar showing the last bank
you were in, with no slot underlined. Super+1 stays in that bank. If you have
not visited a bank yet, the first bank is shown. Set `stride` and `slots` to the
same value if you would rather have no gaps.

## Update

```bash
omarchy plugin update io.github.johanthoren.workspace-contexts
hyprctl reload
```

`hyprctl reload` rebinds Super+1 through Super+9 from the new module. The bar
widget reloads from the plugin files on its own.

## Disable

```bash
omarchy plugin disable io.github.johanthoren.workspace-contexts
```

That only removes the bar widget. Super+1 through Super+9 stay as slots until
you comment out or delete the `dofile` line in `~/.config/hypr/bindings.lua` and
run `hyprctl reload`.

## If the bar jumps to work, personal, other

Your `contexts.json` failed to parse on first load, before anything was cached.
The file itself is still yours. Check it:

```bash
python3 ~/.config/omarchy/plugins/io.github.johanthoren.workspace-contexts/parse_contexts.py --dump
```

Warnings print on stderr. The JSON on stdout is the table the bar and keys
would use. Fix the file, then press Super+1 or edit the file again. A typo after
the plugin has already loaded keeps your previous banks.

To see the same warnings from the bar or compositor:

```bash
journalctl --user --since "5 min ago" | grep workspace-contexts
```

## Uninstall

Remove the `dofile` line from `~/.config/hypr/bindings.lua`, then:

```bash
hyprctl reload
omarchy plugin remove io.github.johanthoren.workspace-contexts
omarchy plugin enable omarchy.workspaces --section left
```

Do not reverse the first two steps. `omarchy plugin remove` then `hyprctl reload`
with the `dofile` line still present is a Lua error: the file is gone, and the
rest of `bindings.lua` does not load. Disabling the widget never restored stock
workspace keys. The `dofile` removal plus reload does that. Your `contexts.json`
is left in place. Delete
`~/.config/omarchy/io.github.johanthoren.workspace-contexts/` to remove it.

## Develop

`parse_contexts.py --dump` prints the filled table that both the widget and the
Hyprland module consume. Bank math lives there and is not reimplemented in QML or
Lua. See [AGENTS.md](AGENTS.md) for the repository layout.

```bash
python3 parse_contexts_test.py
omarchy plugin validate .
```

`parse_contexts_test.py` runs the Lua tests too, under a temporary `HOME`.

## License

MIT. See [LICENSE](LICENSE).
