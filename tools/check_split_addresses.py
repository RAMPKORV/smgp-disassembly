#!/usr/bin/env python3

import json
import os
import re
import sys


ROOT = os.path.dirname(os.path.dirname(__file__))
LISTING_PATH = os.path.join(ROOT, "smgp.lst")
SYMBOL_MAP_PATH = os.path.join(ROOT, "tools", "index", "symbol_map.json")

LABEL_RE = re.compile(r"^([0-9A-F]{8})\s+([A-Za-z_][A-Za-z0-9_]*):\s*$")


def parse_listing(path):
    symbols = {}

    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            match = LABEL_RE.match(line.rstrip("\n"))
            if match:
                address_text, label = match.groups()
                symbols[label] = int(address_text, 16)

    return symbols


def load_baseline(path):
    with open(path, encoding="utf-8") as f:
        payload = json.load(f)

    return {label: int(address, 16) for label, address in payload["symbols"].items()}


def main():
    baseline = load_baseline(SYMBOL_MAP_PATH)
    current = parse_listing(LISTING_PATH)

    missing = sorted(label for label in baseline if label not in current)
    moved = []

    for label, old_addr in baseline.items():
        new_addr = current.get(label)
        if new_addr is not None and new_addr != old_addr:
            moved.append((label, old_addr, new_addr))

    extra = sorted(label for label in current if label not in baseline)

    if not missing and not moved and not extra:
        print(f"OK: {len(baseline)} symbols match baseline addresses")
        return 0

    if not missing and not moved and extra:
        print(f"OK: {len(baseline)} baseline symbols match addresses; {len(extra)} new symbols added")
        for label in extra[:20]:
            print(f"  EXTRA {label}")
        return 0

    if missing:
        print(f"Missing symbols: {len(missing)}")
        for label in missing[:20]:
            print(f"  MISSING {label}")

    if moved:
        print(f"Moved symbols: {len(moved)}")
        for label, old_addr, new_addr in moved[:20]:
            print(f"  MOVED {label}: 0x{old_addr:06X} -> 0x{new_addr:06X}")

    if extra:
        print(f"New symbols not in baseline: {len(extra)}")
        for label in extra[:20]:
            print(f"  EXTRA {label}")

    return 1


if __name__ == "__main__":
    sys.exit(main())
