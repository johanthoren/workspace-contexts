#!/usr/bin/env python3

import json
import os
import re
import sys
from pathlib import Path

PLUGIN_ID = "io.github.johanthoren.workspace-contexts"
ACCENT_CYCLE = ("blue", "green", "magenta", "yellow", "cyan", "red")
TOKYO_NIGHT = {
    "blue": "#7aa2f7",
    "green": "#9ece6a",
    "magenta": "#ad8ee6",
    "yellow": "#e0af68",
    "cyan": "#449dab",
    "red": "#f7768e",
}
DEFAULT_STRIDE = 10
DEFAULT_SLOTS = 9
DEFAULT_MAX_CONTEXTS = 10
# Slots become Super+N binds over the number row, which runs out after ten
# keys. A larger value would bind Super+BackSpace, Super+Tab, Super+Q, and on
# into the letters, silently taking over stock Omarchy shortcuts.
MAX_SLOTS = 10
MAX_WORKSPACE_ID = 99
HEX_RE = re.compile(r"^#[0-9A-Fa-f]{6}$")
SHIPPED_CONTEXTS = (
    {"name": "work", "base": 0, "accent": "blue"},
    {"name": "personal", "base": 10, "accent": "green"},
    {"name": "other", "base": 20, "accent": "magenta"},
)


def example_path():
    return Path(__file__).resolve().parent / "contexts.example.json"


def user_file(home):
    return Path(home) / ".config" / "omarchy" / PLUGIN_ID / "contexts.json"


def default_file():
    return {
        "stride": DEFAULT_STRIDE,
        "slots": DEFAULT_SLOTS,
        "maxContexts": DEFAULT_MAX_CONTEXTS,
        "fallback": dict(TOKYO_NIGHT),
        "contexts": [dict(row) for row in SHIPPED_CONTEXTS],
    }


def _is_int(value):
    if isinstance(value, bool):
        return False
    if isinstance(value, int):
        return True
    return isinstance(value, float) and value.is_integer()


def _as_int(value):
    return int(value)


def _positive_int(value, default, maximum=None):
    if _is_int(value):
        number = _as_int(value)
        if number > 0:
            if maximum is not None and number > maximum:
                return maximum
            return number
    return default


def _parse_fallback(raw):
    fallback = dict(TOKYO_NIGHT)
    if not isinstance(raw, dict):
        return fallback
    for name in ACCENT_CYCLE:
        value = raw.get(name)
        if isinstance(value, str) and HEX_RE.fullmatch(value):
            fallback[name] = value
    return fallback


def parse_obj(data):
    if not isinstance(data, dict) or not isinstance(data.get("contexts"), list):
        return default_file()

    stride = _positive_int(data.get("stride"), DEFAULT_STRIDE)
    slots = _positive_int(data.get("slots"), DEFAULT_SLOTS, MAX_SLOTS)
    max_contexts = _positive_int(data.get("maxContexts"), DEFAULT_MAX_CONTEXTS)
    fallback = _parse_fallback(data.get("fallback"))

    rows = []
    names = set()
    ranges = []

    for index, row in enumerate(data["contexts"]):
        if len(rows) >= max_contexts:
            break
        if not isinstance(row, dict):
            continue
        name = row.get("name")
        if not isinstance(name, str) or name == "" or name in names:
            continue
        if "base" in row:
            if not _is_int(row["base"]):
                continue
            base = _as_int(row["base"])
        else:
            base = index * stride
        # Hyprland rejects id <= 0; drop a bank whose last slot is above MAX_WORKSPACE_ID.
        if base < 0 or base + slots > MAX_WORKSPACE_ID:
            continue
        lo = base + 1
        hi = base + slots
        overlap = False
        for other_lo, other_hi in ranges:
            if not (hi < other_lo or lo > other_hi):
                overlap = True
                break
        if overlap:
            continue
        accent = row.get("accent")
        if not (isinstance(accent, str) and accent in ACCENT_CYCLE):
            accent = ACCENT_CYCLE[len(rows) % len(ACCENT_CYCLE)]
        names.add(name)
        ranges.append((lo, hi))
        rows.append({"name": name, "base": base, "accent": accent})

    if not rows:
        return default_file()

    return {
        "stride": stride,
        "slots": slots,
        "maxContexts": max_contexts,
        "fallback": fallback,
        "contexts": rows,
    }


def seed_if_missing(home):
    path = user_file(home)
    if path.exists():
        return
    try:
        text = example_path().read_text(encoding="utf-8")
        path.parent.mkdir(parents=True, exist_ok=True)
        fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o644)
    except FileExistsError:
        return
    except OSError:
        return
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(text)
    except OSError:
        return


def load(*, home=None):
    if home is None:
        home = os.environ.get("HOME", "")
    home = Path(home)
    path = user_file(home)
    if not path.exists():
        seed_if_missing(home)
    if path.is_file():
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError, json.JSONDecodeError):
            return default_file()
        return parse_obj(data)
    return default_file()


def main(argv=None):
    args = list(sys.argv[1:] if argv is None else argv)
    if args != ["--dump"]:
        sys.stderr.write("usage: parse_contexts.py --dump\n")
        return 2
    json.dump(load(), sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
