#!/usr/bin/env python3

import json
import re
import sys
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SYMBOL_MAP_PATH = ROOT / "tools" / "index" / "symbol_map.json"
OUTPUT_PATH = ROOT / "tools" / "index" / "hidden_pointer_candidates.json"

CONST_FILES = {
    "ram": ROOT / "ram_addresses.asm",
    "sound": ROOT / "sound_constants.asm",
}

ASM_FILES = [
    ROOT / "header.asm",
    ROOT / "init.asm",
    ROOT / "src" / "core.asm",
    ROOT / "src" / "menus.asm",
    ROOT / "src" / "race.asm",
    ROOT / "src" / "driving.asm",
    ROOT / "src" / "rendering.asm",
    ROOT / "src" / "race_support.asm",
    ROOT / "src" / "ai.asm",
    ROOT / "src" / "audio_effects.asm",
    ROOT / "src" / "objects.asm",
    ROOT / "src" / "gameplay.asm",
]

LABEL_EXCLUDE_RE = re.compile(r"(?:_palette|_tilemap|_tile_data|_tiles|_sprite|_frame|_sign_data|_sign_tileset|_road_style|_finish_line_style|_displacement|_sine_table)", re.IGNORECASE)

LABEL_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*):")
CONST_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(\$[0-9A-F]+|\d+)")
DATA_RE = re.compile(r"^\s*dc\.(l|w|b)\s+(.*)$")
HEX_RE = re.compile(r"^\$([0-9A-F]+)$")
DEC_RE = re.compile(r"^\d+$")
LOW_VALUE_CUTOFF = 0x0800
LABEL_SKIP_EXACT = {
    "Boot_init_data",
    "Vdp_init_register_table",
    "Track_data",
    "Speed_to_distance_table",
}
LABEL_TUPLE_EXCLUDE_RE = re.compile(r"(?:_data|_table|_grid|_layout|_anim|_stream|_code)", re.IGNORECASE)
TUPLE_BYTE_MIN = 0x10000
TUPLE_WORD_MIN = 0x10000
TUPLE_START_RE = re.compile(r"^\$00, \$02, \$[0-9A-F]{2}, \$[0-9A-F]{2}$")


def load_symbol_map():
    payload = json.loads(SYMBOL_MAP_PATH.read_text(encoding="utf-8"))
    addresses = {}
    for label, value in payload["symbols"].items():
        address = int(value, 16)
        addresses.setdefault(address, []).append(label)
    return addresses


def load_constants():
    addresses = {}
    for category, path in CONST_FILES.items():
        for line in path.read_text(encoding="latin-1").splitlines():
            match = CONST_RE.match(line.strip())
            if not match:
                continue
            name, value_text = match.groups()
            value = parse_number(value_text)
            if value is None:
                continue
            if value < 0x10000:
                continue
            addresses.setdefault(value, []).append({"name": name, "category": category})
    return addresses


def parse_number(token):
    token = token.strip()
    match = HEX_RE.match(token)
    if match:
        return int(match.group(1), 16)
    if DEC_RE.match(token):
        return int(token, 10)
    return None


def normalized_values(width, value):
    values = [value & 0xFFFFFFFF]
    if width == "w" and value >= 0x8000:
        values.append(0xFFFF0000 | value)
    return values


def classify_value(width, value, symbol_addresses, constant_addresses):
    if width == "w" and value < LOW_VALUE_CUTOFF:
        return None
    for candidate in normalized_values(width, value):
        if candidate in constant_addresses:
            targets = constant_addresses[candidate]
            return {
                "kind": targets[0]["category"],
                "target_names": [item["name"] for item in targets],
                "target_address": f"0x{candidate:08X}",
            }
        if candidate in symbol_addresses:
            return {
                "kind": "rom",
                "target_names": symbol_addresses[candidate],
                "target_address": f"0x{candidate:06X}",
            }
    return None


def token_is_symbolic(token):
    return bool(re.search(r"[A-Za-z_]", token))


def token_should_ignore(value):
    return value in {0, 0xFFFF, 0xFFFFFFFF}


def should_skip_label(label):
    if label in LABEL_SKIP_EXACT:
        return True
    return bool(label and LABEL_EXCLUDE_RE.search(label))


def should_skip_tuple_label(label):
    if should_skip_label(label):
        return True
    return bool(label and LABEL_TUPLE_EXCLUDE_RE.search(label))


def scan_tuple_run(path, label, width, entries, symbol_addresses, constant_addresses):
    candidates = []
    tuple_size = 4 if width == "b" else 2
    directive = f"dc.{width}*{tuple_size}"

    if len(entries) < tuple_size:
        return candidates

    for start in range(len(entries) - tuple_size + 1):
        window = entries[start:start + tuple_size]
        if width == "b":
            tuple_text = ", ".join(entry["token"] for entry in window)
            if not TUPLE_START_RE.match(tuple_text):
                continue
        if width == "b":
            value = 0
            for entry in window:
                value = (value << 8) | entry["value"]
            if value < TUPLE_BYTE_MIN:
                continue
        else:
            value = (window[0]["value"] << 16) | window[1]["value"]
            if value < TUPLE_WORD_MIN:
                continue

        result = classify_value("l", value, symbol_addresses, constant_addresses)
        if result is None:
            continue

        candidates.append(
            {
                "file": str(path.relative_to(ROOT)).replace("\\", "/"),
                "line": window[0]["line"],
                "label": label,
                "directive": directive,
                "operand_index": window[0]["operand_index"],
                "literal": ", ".join(entry["token"] for entry in window),
                "kind": result["kind"],
                "target_address": result["target_address"],
                "target_names": result["target_names"],
            }
        )

    return candidates


def scan_file(path, symbol_addresses, constant_addresses):
    candidates = []
    current_label = None
    lines = path.read_text(encoding="latin-1").splitlines()
    tuple_width = None
    tuple_label = None
    tuple_entries = []

    def flush_tuple_run():
        nonlocal tuple_width, tuple_label, tuple_entries, candidates
        if tuple_width in {"b", "w"} and tuple_entries and not should_skip_tuple_label(tuple_label):
            candidates.extend(scan_tuple_run(path, tuple_label, tuple_width, tuple_entries, symbol_addresses, constant_addresses))
        tuple_width = None
        tuple_label = None
        tuple_entries = []

    for line_number, line in enumerate(lines, 1):
        code = line.split(";", 1)[0].rstrip()
        label_match = LABEL_RE.match(code)
        if label_match:
            flush_tuple_run()
            current_label = label_match.group(1)

        match = DATA_RE.match(code)
        if not match:
            flush_tuple_run()
            continue

        width, operands = match.groups()
        numeric_entries = []

        for index, token in enumerate(operands.split(","), 1):
            token = token.strip()
            if not token or token_is_symbolic(token):
                continue

            value = parse_number(token)
            if value is None or token_should_ignore(value):
                continue

            numeric_entries.append(
                {
                    "line": line_number,
                    "operand_index": index,
                    "token": token,
                    "value": value,
                }
            )

            if width == "w":
                value &= 0xFFFF

            if width == "b":
                continue

            result = classify_value(width, value, symbol_addresses, constant_addresses)
            if result is None:
                continue

            if should_skip_label(current_label):
                continue

            candidates.append(
                {
                    "file": str(path.relative_to(ROOT)).replace("\\", "/"),
                    "line": line_number,
                    "label": current_label,
                    "directive": f"dc.{width}",
                    "operand_index": index,
                    "literal": token,
                    "kind": result["kind"],
                    "target_address": result["target_address"],
                    "target_names": result["target_names"],
                }
            )

        if width in {"b", "w"}:
            if tuple_width != width or tuple_label != current_label:
                flush_tuple_run()
                tuple_width = width
                tuple_label = current_label
            tuple_entries.extend(numeric_entries)
        else:
            flush_tuple_run()

    flush_tuple_run()
    return candidates


def main():
    symbol_addresses = load_symbol_map()
    constant_addresses = load_constants()

    candidates = []
    for path in ASM_FILES:
        candidates.extend(scan_file(path, symbol_addresses, constant_addresses))

    by_kind = Counter(candidate["kind"] for candidate in candidates)
    by_file = Counter(candidate["file"] for candidate in candidates)
    by_directive = Counter(candidate["directive"] for candidate in candidates)
    strong_candidates = [candidate for candidate in candidates if candidate["directive"] in {"dc.l", "dc.b*4", "dc.w*2"}]

    payload = {
        "_meta": {
            "source": "assembly data definitions + symbol map + split constants",
            "candidate_count": len(candidates),
            "strong_candidate_count": len(strong_candidates),
            "by_kind": dict(sorted(by_kind.items())),
            "by_file": dict(sorted(by_file.items())),
            "by_directive": dict(sorted(by_directive.items())),
            "notes": [
                "Numeric dc.l/dc.w operands are scanned directly.",
                "Contiguous numeric dc.b tuples are scanned as 4-byte big-endian addresses.",
                "Contiguous numeric dc.w tuples are scanned as 2-word big-endian addresses.",
                "Existing symbolic references are excluded.",
                "dc.w values are checked both raw and sign-extended to $FFFFxxxx.",
                f"dc.w values below 0x{LOW_VALUE_CUTOFF:04X} are ignored as likely scalar data/noise.",
                "This is a conservative first-pass report meant to seed PTR-002, not a proof that every candidate is a real pointer.",
            ],
        },
        "strong_candidates": strong_candidates,
        "candidates": candidates,
    }

    OUTPUT_PATH.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

    print(f"Wrote {len(candidates)} pointer candidates to {OUTPUT_PATH}")
    print(f"  strong dc.l candidates: {len(strong_candidates)}")
    for kind, count in sorted(by_kind.items()):
        print(f"  {kind}: {count}")
    for file_name, count in by_file.most_common(8):
        print(f"  file {file_name}: {count}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
