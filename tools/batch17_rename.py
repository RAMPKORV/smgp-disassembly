#!/usr/bin/env python3
# Batch 17: Huffman decompressor internals and Build_decompression_code_table internals
# loc_98A  -> Decompress_shared_body
# loc_998  -> Decompress_code_table_skip
# loc_9BA  -> Decompress_huffman_decode
# loc_9E2  -> Decompress_huffman_next_nibble
# loc_9F0  -> Decompress_huffman_shift_out
# loc_9F2  -> Decompress_huffman_emit_nibble
# loc_A00  -> Decompress_huffman_loop_back
# loc_A06  -> Decompress_huffman_extended
# loc_A14  -> Decompress_huffman_ext_reload
# loc_A32  -> Decompress_vdp_emit_group
# loc_A48  -> Decompress_ram_emit_group
# loc_A60  -> Build_code_table_next_entry
# loc_A68  -> Build_code_table_process
# loc_A6A  -> Build_code_table_read_slot
# loc_A98  -> Build_code_table_multi
# loc_AA4  -> Build_code_table_fill_loop

import re

SOURCE = r'E:\Romhacking\smgp-disassembly\smgp.asm'

RENAMES = [
    ('loc_98A',  'Decompress_shared_body'),
    ('loc_998',  'Decompress_code_table_skip'),
    ('loc_9BA',  'Decompress_huffman_decode'),
    ('loc_9E2',  'Decompress_huffman_next_nibble'),
    ('loc_9F0',  'Decompress_huffman_shift_out'),
    ('loc_9F2',  'Decompress_huffman_emit_nibble'),
    ('loc_A00',  'Decompress_huffman_loop_back'),
    ('loc_A06',  'Decompress_huffman_extended'),
    ('loc_A14',  'Decompress_huffman_ext_reload'),
    ('loc_A32',  'Decompress_vdp_emit_group'),
    ('loc_A48',  'Decompress_ram_emit_group'),
    ('loc_A60',  'Build_code_table_next_entry'),
    ('loc_A68',  'Build_code_table_process'),
    ('loc_A6A',  'Build_code_table_read_slot'),
    ('loc_A98',  'Build_code_table_multi'),
    ('loc_AA4',  'Build_code_table_fill_loop'),
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
    # Match the label definition: "new:" at column 0 (possibly followed by more on same line)
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
