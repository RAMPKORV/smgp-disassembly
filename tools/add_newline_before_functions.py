#!/usr/bin/env python3

import sys
import re

if len(sys.argv) != 2:
    print('Usage: %s in.asm > out.asm' % sys.argv[0])
    sys.exit(1)

infile = sys.argv[1]

function_call = re.compile(r'(JSR|BSR.b|BSR.w)\t(loc_[A-Z0-9]+)')
function_def = re.compile(r'(loc_[A-Z0-9]+):')

with open(infile) as f:
    functions = set(m[1] for m in function_call.findall(f.read()))

with open(infile) as f:
    for line in f.readlines():
        match = function_def.match(line)
        if match and match.group(1) in functions:
            print('')
        print(line, end='')
