#!/usr/bin/env python3
# Batch 23: Tilemap draw queue internals, Render_placement_display,
#           digit tile packing, Binary_to_decimal internals
#
# loc_2250  -> Team_colour_palette_table       (8-byte colour entries per team)
# loc_148E  -> Flush_tilemap_queue_loop        (process each entry in the queue)
# loc_14A4  -> Flush_tilemap_queue_done        (return when queue empty)
# loc_14AC  -> Render_placement_display_body   (body after dirty check)
# loc_14E8  -> Unpack_placement_zero           (zero digit - suppress if no prior digit)
# loc_14EE  -> Unpack_placement_store          (store tile word, advance pointer)
# loc_14F0  -> Unpack_placement_nop            (no-op / fall-through return)
# loc_14F2  -> Unpack_placement_units          (always emit units digit including zero)
# loc_1530  -> Unpack_bcd_digits_loop          (inner loop of Unpack_bcd_digits_to_buffer)
# loc_154A  -> Copy_digits_shared_body         (shared body after suppress mode set)
# loc_1556  -> Copy_digits_loop                (inner digit copy loop)
# loc_1566  -> Copy_digits_nonzero             (non-zero digit path, set suppress=on)
# loc_1568  -> Copy_digits_emit               (emit both tile rows for this digit)
# loc_1586  -> Binary_to_decimal_loop          (bit-iteration loop)
# loc_158E  -> Binary_to_decimal_bit_set       (ABCD add path for set bits)
# loc_159C  -> Binary_to_decimal_next          (DBF back to loop top)

import re

SOURCE = r'E:\Romhacking\smgp-disassembly\smgp.asm'

RENAMES = [
    ('loc_2250', 'Team_colour_palette_table'),
    ('loc_148E', 'Flush_tilemap_queue_loop'),
    ('loc_14A4', 'Flush_tilemap_queue_done'),
    ('loc_14AC', 'Render_placement_display_body'),
    ('loc_14E8', 'Unpack_placement_zero'),
    ('loc_14EE', 'Unpack_placement_store'),
    ('loc_14F0', 'Unpack_placement_nop'),
    ('loc_14F2', 'Unpack_placement_units'),
    ('loc_1530', 'Unpack_bcd_digits_loop'),
    ('loc_154A', 'Copy_digits_shared_body'),
    ('loc_1556', 'Copy_digits_loop'),
    ('loc_1566', 'Copy_digits_nonzero'),
    ('loc_1568', 'Copy_digits_emit'),
    ('loc_1586', 'Binary_to_decimal_loop'),
    ('loc_158E', 'Binary_to_decimal_bit_set'),
    ('loc_159C', 'Binary_to_decimal_next'),
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
