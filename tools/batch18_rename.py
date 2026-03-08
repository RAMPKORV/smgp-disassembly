#!/usr/bin/env python3
# Batch 18: Decompress_tilemap_to_buffer internals, Decode_packed_tilemap_entry internals,
#           Refill_tilemap_bit_buffer internals, Load_streamed_decompression_descriptor internals
#
# loc_AF6  -> Decomp_tilemap_refill
# loc_B06  -> Decomp_tilemap_incrun_loop
# loc_B10  -> Decomp_tilemap_flatrun_loop
# loc_B18  -> Decomp_tilemap_reprun_decode
# loc_B1C  -> Decomp_tilemap_reprun_loop
# loc_B24  -> Decomp_tilemap_ascrun_decode
# loc_B28  -> Decomp_tilemap_ascrun_loop
# loc_B32  -> Decomp_tilemap_descrun_decode
# loc_B36  -> Decomp_tilemap_descrun_loop
# loc_B40  -> Decomp_tilemap_litrun_head
# loc_B46  -> Decomp_tilemap_litrun_loop
# loc_B52  -> Decomp_tilemap_dispatch
# loc_B62  -> Decomp_tilemap_end
# loc_B6C  -> Decomp_tilemap_align
# loc_B74  -> Decomp_tilemap_exit
# loc_B8A  -> Decode_packed_fliph_done
# loc_B98  -> Decode_packed_flipv_done
# loc_BB6  -> Decode_packed_mask_finish
# loc_BC8  -> Decode_packed_enough_bits
# loc_BDA  -> Decode_packed_exact_fit
# loc_C0C  -> Refill_tilemap_bit_buffer_ret
# loc_C28  -> Load_stream_desc_clear_loop
# loc_C36  -> Load_stream_desc_copy_loop
# loc_C3E  -> Load_stream_desc_done

import re

SOURCE = r'E:\Romhacking\smgp-disassembly\smgp.asm'

RENAMES = [
    ('loc_AF6', 'Decomp_tilemap_refill'),
    ('loc_B06', 'Decomp_tilemap_incrun_loop'),
    ('loc_B10', 'Decomp_tilemap_flatrun_loop'),
    ('loc_B18', 'Decomp_tilemap_reprun_decode'),
    ('loc_B1C', 'Decomp_tilemap_reprun_loop'),
    ('loc_B24', 'Decomp_tilemap_ascrun_decode'),
    ('loc_B28', 'Decomp_tilemap_ascrun_loop'),
    ('loc_B32', 'Decomp_tilemap_descrun_decode'),
    ('loc_B36', 'Decomp_tilemap_descrun_loop'),
    ('loc_B40', 'Decomp_tilemap_litrun_head'),
    ('loc_B46', 'Decomp_tilemap_litrun_loop'),
    ('loc_B52', 'Decomp_tilemap_dispatch'),
    ('loc_B62', 'Decomp_tilemap_end'),
    ('loc_B6C', 'Decomp_tilemap_align'),
    ('loc_B74', 'Decomp_tilemap_exit'),
    ('loc_B8A', 'Decode_packed_fliph_done'),
    ('loc_B98', 'Decode_packed_flipv_done'),
    ('loc_BB6', 'Decode_packed_mask_finish'),
    ('loc_BC8', 'Decode_packed_enough_bits'),
    ('loc_BDA', 'Decode_packed_exact_fit'),
    ('loc_C0C', 'Refill_tilemap_bit_buffer_ret'),
    ('loc_C28', 'Load_stream_desc_clear_loop'),
    ('loc_C36', 'Load_stream_desc_copy_loop'),
    ('loc_C3E', 'Load_stream_desc_done'),
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
