#!/usr/bin/env python3
# Batch 19: Start_streamed_decompression, Continue_streamed_decompression internals
#           and nearby data label
#
# loc_C66  -> Start_stream_decomp_sink_select  (select vdp vs ram emit sink)
# loc_C98  -> Start_stream_decomp_skip         (early-out / RTS shared by start + continue)
# loc_CE4  -> Continue_stream_decomp_inner     (inner decompression loop body)
# loc_D1A  -> Continue_stream_decomp_done      (early-out when rows exhausted)
# loc_D1C  -> Continue_stream_decomp_flush     (advance stream descriptor on row complete)
# loc_D22  -> Continue_stream_desc_shift_loop  (shift descriptor ring buffer)
# loc_D2C  -> Stream_descriptor_table          (descriptor data table)

import re

SOURCE = r'E:\Romhacking\smgp-disassembly\smgp.asm'

RENAMES = [
    ('loc_C66', 'Start_stream_decomp_sink_select'),
    ('loc_C98', 'Start_stream_decomp_skip'),
    ('loc_CE4', 'Continue_stream_decomp_inner'),
    ('loc_D1A', 'Continue_stream_decomp_done'),
    ('loc_D1C', 'Continue_stream_decomp_flush'),
    ('loc_D22', 'Continue_stream_desc_shift_loop'),
    ('loc_D2C', 'Stream_descriptor_table'),
]

with open(SOURCE, encoding='latin-1') as f:
    content = f.read()

total_replacements = 0
for old, new in RENAMES:
    pattern = r'\b' + re.escape(old) + r'\b'
    new_content, count = re.subn(pattern, new, content)
    if count == 0:
        print(f'WARNING: {old} not found')
    else:
        print(f'  {old} -> {new}: {count} replacement(s)')
        total_replacements += count
        content = new_content

# Insert preservation comments above each definition line
for old, new in RENAMES:
    def_pattern = r'^(' + re.escape(new) + r':)'
    def repl(m):
        return f';{old}\n{m.group(1)}'
    new_content, count = re.subn(def_pattern, repl, content, flags=re.MULTILINE)
    if count == 0:
        print(f'WARNING: definition for {new}: not found (preservation comment not inserted)')
    else:
        content = new_content

with open(SOURCE, 'w', encoding='latin-1') as f:
    f.write(content)

print(f'\nDone. {total_replacements} total replacements across {len(RENAMES)} labels.')
