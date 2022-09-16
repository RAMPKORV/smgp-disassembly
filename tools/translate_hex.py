#!/usr/bin/env python3

# Usage:
# cat input.asm | ./translate_hex.py > output.asm

import re
import fileinput

hex_pattern = re.compile('\\$[0-9A-F]{4}')

for line in fileinput.input():
    for match in hex_pattern.findall(line):
        line = line.replace(match, str(int(match[1:], 16)))
    print(line, end='')
