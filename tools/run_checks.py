#!/usr/bin/env python3

import json
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SMGP = ROOT / "smgp.asm"
SYMBOL_MAP = ROOT / "tools" / "index" / "symbol_map.json"

EXPECTED_INCLUDES = [
    'include "macros.asm"',
    'include "constants.asm"',
    'include "header.asm"',
    'include "init.asm"',
    'include "src/core.asm"',
    'include "src/menus.asm"',
    'include "src/race.asm"',
    'include "src/driving.asm"',
    'include "src/rendering.asm"',
    'include "src/race_support.asm"',
    'include "src/ai.asm"',
    'include "src/audio_effects.asm"',
    'include "src/objects.asm"',
    'include "src/endgame.asm"',
    'include "src/gameplay.asm"',
]

RAW_ADDR_RE = re.compile(r"(?<![#A-Za-z0-9_])(\$FFFF[0-9A-F]{4}|\$00FF[0-9A-F]{4}|\$A0[0-9A-F]{4}|\$C0000[04])(?:\.(?:w|l))?(?![0-9A-F])")
LOC_LABEL_RE = re.compile(r"^loc_[0-9A-F]+:", re.MULTILINE)

RAW_ADDRESS_ALLOWLIST = {
    Path("src/core.asm"): ["$00FF5980"],
    Path("src/race.asm"): ["$00FF5980", "$00FF5AC2"],
    Path("src/driving.asm"): [],
    Path("src/rendering.asm"): ["$00FF5980"],
    Path("src/menus.asm"): [],
    Path("src/race_support.asm"): ["$00FF5AC2", "$00FF5980"],
    Path("src/ai.asm"): ["$00FF5980", "$00FF5AC2"],
    Path("src/audio_effects.asm"): ["$00FF5AC4", "$00FF5AC8", "$00FF5ACC"],
    Path("src/objects.asm"): ["$00FF5980"],
    Path("src/gameplay.asm"): ["$00FF5980", "$00FF5AC2", "$00FF9100"],
    Path("src/race.asm"): ["$00FF5980", "$00FF5AC2", "$00FF5C40"],
}


def check_include_order(errors):
    lines = [line.strip() for line in SMGP.read_text(encoding="latin-1").splitlines() if line.strip()]
    if lines != EXPECTED_INCLUDES:
        errors.append("smgp.asm include order does not match expected module layout")


def check_symbol_map(errors):
    if not SYMBOL_MAP.exists():
        errors.append("missing tools/index/symbol_map.json")
        return

    payload = json.loads(SYMBOL_MAP.read_text(encoding="utf-8"))
    count = payload.get("_meta", {}).get("count")
    symbols = payload.get("symbols", {})
    if count != len(symbols):
        errors.append("symbol_map.json meta count does not match symbol table size")


def iter_asm_files():
    for path in sorted(ROOT.glob("*.asm")):
        yield path
    for path in sorted((ROOT / "src").glob("*.asm")):
        yield path


def check_no_loc_labels(errors):
    for path in iter_asm_files():
        text = path.read_text(encoding="latin-1")
        if LOC_LABEL_RE.search(text):
            errors.append(f"legacy loc_ label definition found in {path.relative_to(ROOT)}")


def check_raw_addresses(errors):
    allow = {
        Path("header.asm"),
        Path("init.asm"),
        Path("smgp_full.asm"),
        Path("constants.asm"),
        Path("hw_constants.asm"),
        Path("ram_addresses.asm"),
        Path("sound_constants.asm"),
        Path("game_constants.asm"),
    }
    for path in iter_asm_files():
        rel = path.relative_to(ROOT)
        if rel in allow:
            continue
        lines = path.read_text(encoding="latin-1").splitlines()
        allowed_literals = RAW_ADDRESS_ALLOWLIST.get(rel, [])
        for line in lines:
            stripped = line.strip()
            if not stripped or stripped.startswith(";"):
                continue
            if stripped.lower().startswith(("dc.", "dcb", "ds.", "txt macro", "endm", "while ", "if ", "elseif ", "else", "endif", "substr ")):
                continue
            code = line.split(";", 1)[0]
            for match in RAW_ADDR_RE.finditer(code):
                literal = match.group(0)
                if literal in allowed_literals:
                    continue
                errors.append(f"raw address literal {literal} found in {rel}")
                break


def check_split_safety(errors):
    result = subprocess.run(
        [sys.executable, str(ROOT / "tools" / "check_split_addresses.py")],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        message = result.stdout.strip() or result.stderr.strip() or "split-address check failed"
        errors.append(message)


def main():
    errors = []
    check_include_order(errors)
    check_symbol_map(errors)
    check_no_loc_labels(errors)
    check_raw_addresses(errors)
    check_split_safety(errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1

    print("OK: include order, symbol map, loc-label, raw-address, and split checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
