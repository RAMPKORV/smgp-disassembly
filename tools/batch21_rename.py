#!/usr/bin/env python3
# Batch 21: Queue_object_for_sprite_buffer / Clear_object_pool area internals
#           plus small scaled-sprite object and flag-waving routines
#
# loc_EF4  -> Queue_object_shared_body      (shared body after alt/main A1 setup)
# loc_F10  -> Queue_object_full             (buffer full, return $FFFF)
# loc_F2C  -> Clear_object_pool_loop        (shared DBF loop used by all three Clear_ routines)
# loc_F3C  -> Clear_object_slot_loop        (inner longword-clear loop in Clear_object_slot)
# loc_FA4  -> Scaled_sprite_frame_a_data    (sprite frame data table, style A)
# loc_FBE  -> Scaled_sprite_frame_b_data    (sprite frame data table, style B)
# loc_FCC  -> Scaled_sprite_size_table      (sprite size-index lookup by scale)
# loc_F7A  -> Update_scaled_sprite          (update routine for scaled-sprite object)
# loc_F82  -> Update_scaled_sprite_body     (main body after zero-scale guard)
# loc_1010 -> Update_flag_anim_wrap         (wrap frame counter to 0 after reaching 0x15)
# loc_1022 -> Update_flag_anim_phase2       (select phase-2 tile table)
# loc_1058 -> Update_flag_enqueue_done      (return after conditional enqueue)
# loc_105A -> Flag_anim_tiles_phase1        (tile index table for flag wave, phase 1)
# loc_107E -> Flag_anim_tiles_phase2        (tile index table for flag wave, phase 2)

import re

SOURCE = r'E:\Romhacking\smgp-disassembly\smgp.asm'

RENAMES = [
    ('loc_EF4', 'Queue_object_shared_body'),
    ('loc_F10', 'Queue_object_full'),
    ('loc_F2C', 'Clear_object_pool_loop'),
    ('loc_F3C', 'Clear_object_slot_loop'),
    ('loc_FA4', 'Scaled_sprite_frame_a_data'),
    ('loc_FBE', 'Scaled_sprite_frame_b_data'),
    ('loc_FCC', 'Scaled_sprite_size_table'),
    ('loc_F7A', 'Update_scaled_sprite'),
    ('loc_F82', 'Update_scaled_sprite_body'),
    ('loc_1010', 'Update_flag_anim_wrap'),
    ('loc_1022', 'Update_flag_anim_phase2'),
    ('loc_1058', 'Update_flag_enqueue_done'),
    ('loc_105A', 'Flag_anim_tiles_phase1'),
    ('loc_107E', 'Flag_anim_tiles_phase2'),
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
