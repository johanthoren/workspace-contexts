#!/usr/bin/env python3

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))
import parse_contexts  # noqa: E402


def names(file):
    return [row["name"] for row in file["contexts"]]


def bases(file):
    return [row["base"] for row in file["contexts"]]


def accents(file):
    return [row["accent"] for row in file["contexts"]]


def write_user(home, payload):
    path = parse_contexts.user_file(home)
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(payload, str):
        path.write_text(payload, encoding="utf-8")
    else:
        path.write_text(json.dumps(payload), encoding="utf-8")
    return path


def test_defaults_missing_file():
    with tempfile.TemporaryDirectory() as tmp:
        home = Path(tmp)
        filled = parse_contexts.load(home=home)
        assert names(filled) == ["work", "personal", "other"], "missing file uses shipped names"
        assert bases(filled) == [0, 10, 20], "missing file uses shipped bases"
        assert accents(filled) == ["blue", "green", "magenta"], "missing file uses shipped accents"
        assert filled["stride"] == 10
        assert filled["slots"] == 9
        assert filled["maxContexts"] == 10
        assert filled["ok"] is True
        assert filled["errors"] == []
        user = parse_contexts.user_file(home)
        assert user.is_file(), "missing file is seeded"
        example = (ROOT / "contexts.example.json").read_text(encoding="utf-8")
        assert user.read_text(encoding="utf-8") == example, "seed copies the example file"


def test_missing_accent_cycle():
    filled = parse_contexts.parse_obj(
        {
            "contexts": [
                {"name": "a", "base": 0},
                {"name": "b", "base": 10},
                {"name": "c", "base": 20},
                {"name": "d", "base": 30},
                {"name": "e", "base": 40},
                {"name": "f", "base": 50},
                {"name": "g", "base": 60},
            ]
        }
    )
    assert accents(filled) == [
        "blue",
        "green",
        "magenta",
        "yellow",
        "cyan",
        "red",
        "blue",
    ], "missing accents walk the cycle and wrap"


def test_missing_base_assignment():
    filled = parse_contexts.parse_obj(
        {
            "contexts": [
                {"name": "a"},
                {"name": "b"},
                {"name": "c"},
            ]
        }
    )
    assert bases(filled) == [0, 10, 20], "missing base is index * stride"

    skipped = parse_contexts.parse_obj(
        {
            "contexts": [
                {"name": ""},
                {"name": "kept"},
            ]
        }
    )
    assert names(skipped) == ["kept"]
    assert bases(skipped) == [10], "missing base uses the source row index"


def test_cap_at_10():
    rows = [{"name": "c%d" % i, "base": i * 10} for i in range(12)]
    filled = parse_contexts.parse_obj({"contexts": rows})
    assert len(filled["contexts"]) == 10, "default maxContexts is 10"
    assert names(filled) == ["c%d" % i for i in range(10)]


def test_slots_capped_at_keyboard_row():
    filled = parse_contexts.parse_obj({"slots": 50, "contexts": [{"name": "a", "base": 0}]})
    assert filled["slots"] == parse_contexts.MAX_SLOTS, "slots above the number row clamp to 10"

    filled = parse_contexts.parse_obj({"slots": 4, "contexts": [{"name": "a", "base": 0}]})
    assert filled["slots"] == 4, "slots inside the number row is kept"

    filled = parse_contexts.parse_obj({"slots": 0, "contexts": [{"name": "a", "base": 0}]})
    assert filled["slots"] == 9, "a non-positive slots falls back to the default"


def test_carry_slot():
    filled = parse_contexts.parse_obj({"contexts": [{"name": "a", "base": 0}]})
    assert filled["carrySlot"] is False, "per-bank slot memory is the default"
    assert parse_contexts.default_file()["carrySlot"] is False, "shipped table carries the key"

    on = parse_contexts.parse_obj({"carrySlot": True, "contexts": [{"name": "a", "base": 0}]})
    assert on["carrySlot"] is True, "carrySlot is read from the file"

    bad = parse_contexts.parse_obj({"carrySlot": "yes", "contexts": [{"name": "a", "base": 0}]})
    assert bad["carrySlot"] is False, "a non-boolean carrySlot falls back to the default"


def test_drop_negative_base():
    filled = parse_contexts.parse_obj(
        {
            "contexts": [
                {"name": "below", "base": -5},
                {"name": "zero", "base": 0},
            ]
        }
    )
    assert names(filled) == ["zero"], "a negative base is dropped"

    only_negative = parse_contexts.parse_obj({"contexts": [{"name": "below", "base": -1}]})
    assert names(only_negative) == ["work", "personal", "other"], "no usable row falls back"
    assert only_negative["ok"] is False
    assert any("negative" in line for line in only_negative["errors"])


def test_drop_huge_base():
    filled = parse_contexts.parse_obj(
        {
            "contexts": [
                {"name": "far", "base": 100},
                {"name": "near", "base": 0},
            ]
        }
    )
    assert names(filled) == ["near"], "a last slot above 99 is dropped"

    kept = parse_contexts.parse_obj({"slots": 9, "contexts": [{"name": "ok", "base": 20}]})
    assert names(kept) == ["ok"], "a last slot at 29 is kept"
    assert bases(kept) == [20]

    omitted = parse_contexts.parse_obj(
        {"stride": 100, "contexts": [{"name": "a"}, {"name": "b"}]}
    )
    assert names(omitted) == ["a"], "an omitted base that overflows is dropped"
    assert bases(omitted) == [0]


def test_drop_overlap():
    filled = parse_contexts.parse_obj(
        {
            "contexts": [
                {"name": "a", "base": 0},
                {"name": "b", "base": 5},
                {"name": "c", "base": 10},
            ]
        }
    )
    assert names(filled) == ["a", "c"], "overlapping bank is dropped"
    assert bases(filled) == [0, 10]
    assert filled["ok"] is True
    assert any("overlaps" in line for line in filled["errors"])


def test_drop_hex_as_accent():
    filled = parse_contexts.parse_obj(
        {
            "contexts": [
                {"name": "a", "base": 0, "accent": "#7aa2f7"},
                {"name": "b", "base": 10, "accent": "purple"},
                {"name": "c", "base": 20, "accent": "green"},
            ]
        }
    )
    assert names(filled) == ["a", "b", "c"]
    assert accents(filled) == ["blue", "green", "green"], "hex and unknown accents cycle-fill"


def test_unique_names():
    filled = parse_contexts.parse_obj(
        {
            "contexts": [
                {"name": "work", "base": 0},
                {"name": "work", "base": 10},
                {"name": "Work", "base": 20},
            ]
        }
    )
    assert names(filled) == ["work", "Work"], "duplicate names drop later rows, case-sensitive"


def test_do_not_overwrite_existing_user_file():
    with tempfile.TemporaryDirectory() as tmp:
        home = Path(tmp)
        original = '{"contexts":[{"name":"kept","base":0,"accent":"blue"}]}'
        path = write_user(home, original)
        filled = parse_contexts.load(home=home)
        assert path.read_text(encoding="utf-8") == original, "existing user file is left untouched"
        assert names(filled) == ["kept"]
        assert filled["ok"] is True

    with tempfile.TemporaryDirectory() as tmp:
        home = Path(tmp)
        garbage = "{not json"
        path = write_user(home, garbage)
        filled = parse_contexts.load(home=home)
        assert path.read_text(encoding="utf-8") == garbage, "invalid user file is not overwritten"
        assert names(filled) == ["work", "personal", "other"]
        assert filled["ok"] is False
        assert filled["errors"], "invalid JSON must report why"


def test_last_good_survives_invalid_json():
    with tempfile.TemporaryDirectory() as tmp:
        home = Path(tmp)
        write_user(home, {"contexts": [{"name": "kept", "base": 0, "accent": "blue"}]})
        first = parse_contexts.load(home=home)
        assert names(first) == ["kept"]
        assert first["ok"] is True
        sidecar = parse_contexts.last_good_path(home)
        assert sidecar.is_file(), "a good parse writes last-good.json"

        write_user(home, "{not json")
        second = parse_contexts.load(home=home)
        assert names(second) == ["kept"], "invalid JSON dumps the last good banks"
        assert second["ok"] is False
        assert second["status"] == "error"
        assert any("could not parse" in line for line in second["errors"])


def test_dump_cli():
    with tempfile.TemporaryDirectory() as tmp:
        env = os.environ.copy()
        env["HOME"] = tmp
        raw = subprocess.check_output(
            [sys.executable, str(ROOT / "parse_contexts.py"), "--dump"],
            env=env,
            text=True,
        )
        filled = json.loads(raw)
        assert names(filled) == ["work", "personal", "other"]
        assert filled["ok"] is True
        assert filled["status"] == "ok"
        user = parse_contexts.user_file(tmp)
        assert user.is_file()


def test_dump_cli_invalid_json_stderr():
    with tempfile.TemporaryDirectory() as tmp:
        write_user(tmp, "{not json")
        env = os.environ.copy()
        env["HOME"] = tmp
        proc = subprocess.run(
            [sys.executable, str(ROOT / "parse_contexts.py"), "--dump"],
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )
        assert proc.returncode == 0, "dump still prints a table on parse failure"
        filled = json.loads(proc.stdout)
        assert filled["ok"] is False
        assert filled["status"] == "error"
        assert names(filled) == ["work", "personal", "other"]
        assert "workspace-contexts:" in proc.stderr
        assert "could not parse" in proc.stderr


def test_not_an_object_is_failed_dump():
    filled = parse_contexts.parse_obj([])
    assert filled["ok"] is False
    assert names(filled) == ["work", "personal", "other"]
    assert any("contexts array" in line for line in filled["errors"])


def test_lua():
    lua = ROOT / "hypr" / "contexts_test.lua"
    with tempfile.TemporaryDirectory() as tmp:
        env = os.environ.copy()
        env["HOME"] = tmp
        env["WORKSPACE_CONTEXTS_TEST"] = "1"
        subprocess.run(
            ["lua5.1", str(lua)],
            check=True,
            cwd=str(ROOT),
            env=env,
        )


def main():
    tests = [
        test_defaults_missing_file,
        test_missing_accent_cycle,
        test_missing_base_assignment,
        test_cap_at_10,
        test_slots_capped_at_keyboard_row,
        test_carry_slot,
        test_drop_negative_base,
        test_drop_huge_base,
        test_drop_overlap,
        test_drop_hex_as_accent,
        test_unique_names,
        test_do_not_overwrite_existing_user_file,
        test_last_good_survives_invalid_json,
        test_dump_cli,
        test_dump_cli_invalid_json_stderr,
        test_not_an_object_is_failed_dump,
        test_lua,
    ]
    for test in tests:
        test()
    print("ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
