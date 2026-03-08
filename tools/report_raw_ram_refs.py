#!/usr/bin/env python3

import collections
import pathlib
import re


ROOT = pathlib.Path(__file__).resolve().parents[1]
ASM_PATH = ROOT / 'smgp.asm'
CONSTANTS_PATH = ROOT / 'constants.asm'

ADDR_RE = re.compile(r'(?<!#)\$(FFFF[0-9A-F]{4}|FFFFFF[0-9A-F]{2})\.(?:w|l)\b')
CONST_RE = re.compile(r'^([A-Za-z0-9_]+)\s*=\s*\$(FFFF[0-9A-F]{4}|FFFFFF[0-9A-F]{2})\b')


def safe_text(text):
    return text.encode('ascii', 'replace').decode('ascii')


def load_constants():
    constants_by_addr = collections.defaultdict(list)
    with CONSTANTS_PATH.open(encoding='utf-8') as f:
        for line in f:
            match = CONST_RE.match(line.strip())
            if not match:
                continue
            name, addr = match.groups()
            constants_by_addr[addr].append(name)
    return constants_by_addr


def iter_code_refs():
    with ASM_PATH.open(encoding='utf-8') as f:
        for line_number, raw_line in enumerate(f, 1):
            code = raw_line.split(';', 1)[0]
            for match in ADDR_RE.finditer(code):
                addr = match.group(1)
                yield addr, line_number, raw_line.rstrip('\n')


def main():
    constants_by_addr = load_constants()
    refs_by_addr = collections.defaultdict(list)

    for addr, line_number, line in iter_code_refs():
        refs_by_addr[addr].append((line_number, line))

    unresolved = []
    resolved = []
    for addr, refs in sorted(refs_by_addr.items(), key=lambda item: (-len(item[1]), item[0])):
        bucket = resolved if addr in constants_by_addr else unresolved
        bucket.append((addr, refs))

    print('RAW RAM REFERENCES IN CODE')
    print(f'total unique addresses: {len(refs_by_addr)}')
    print(f'with constants: {len(resolved)}')
    print(f'without constants: {len(unresolved)}')
    print()

    print('UNRESOLVED')
    for addr, refs in unresolved:
        print(f'${addr} count={len(refs)}')
        for line_number, line in refs[:5]:
            print(f'  {line_number}: {safe_text(line.strip())}')
        if len(refs) > 5:
            print(f'  ... {len(refs) - 5} more')
    print()

    print('RESOLVED BUT STILL RAW')
    for addr, refs in resolved:
        names = ', '.join(constants_by_addr[addr])
        print(f'${addr} -> {names} count={len(refs)}')
        for line_number, line in refs[:3]:
            print(f'  {line_number}: {safe_text(line.strip())}')
        if len(refs) > 3:
            print(f'  ... {len(refs) - 3} more')


if __name__ == '__main__':
    main()
