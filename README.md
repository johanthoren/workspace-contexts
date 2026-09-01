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
you to where you left off.

## Configure

The plugin reads
`~/.config/omarchy/io.github.johanthoren.workspace-contexts/contexts.json`, and
copies `contexts.example.json` there on first run if it is missing. Your file is
never overwritten, including when it fails to parse. Editing it takes effect on
the next keypress; no reload needed unless you change `slots`.

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
accepted. If no row survives, the shipped three are used. `slots` above 10
clamps to 10, because the number row runs out.

Reload Hyprland after changing `slots`, since that decides which keys get bound.

## What the bar shows

The bar shows the first five slots of the active bank, plus any other slot in
that bank that has a window in it. That matches how stock Omarchy's workspace
widget behaves. Slot numbers are bank-local: slot 1 of `personal` reads `1`, not
`11`.

With the shipped configuration, workspaces 10, 20, and 30 belong to no bank.
Landing on one, for example with Super+0, leaves the bar showing the first bank
with no slot underlined. Set `stride` and `slots` to the same value if you would
rather have no gaps.

## Uninstall

Remove the `dofile` line from `~/.config/hypr/bindings.lua`, then:

```bash
hyprctl reload
omarchy plugin remove io.github.johanthoren.workspace-contexts
```

Do not reverse that order. `omarchy plugin remove` then `hyprctl reload` with
the `dofile` line still present is a Lua error: the file is gone, and the rest
of `bindings.lua` does not load. Your `contexts.json` is left in place; delete
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
