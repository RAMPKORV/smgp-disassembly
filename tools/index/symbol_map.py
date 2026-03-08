#!/usr/bin/env python3

import json
import os
import re


LISTING_PATH = os.path.join(os.path.dirname(__file__), "..", "..", "smgp.lst")
OUTPUT_PATH = os.path.join(os.path.dirname(__file__), "symbol_map.json")

LABEL_RE = re.compile(r"^([0-9A-F]{8})\s+([A-Za-z_][A-Za-z0-9_]*):\s*$")


def parse_listing(path):
    symbols = {}

    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            match = LABEL_RE.match(line.rstrip("\n"))
            if not match:
                continue

            address_text, label = match.groups()
            symbols[label] = int(address_text, 16)

    return symbols


def main():
    symbols = parse_listing(LISTING_PATH)

    payload = {
        "_meta": {
            "source": "smgp.lst",
            "count": len(symbols),
        },
        "symbols": {label: f"0x{address:06X}" for label, address in sorted(symbols.items(), key=lambda item: item[1])},
    }

    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2, sort_keys=False)
        f.write("\n")

    print(f"Wrote {len(symbols)} symbols to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
