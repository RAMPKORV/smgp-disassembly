#!/usr/bin/env python3
# Batch 24: BCD time/hex digit internals, DMA flush, crash animation,
#           overtake and placement display animation routines
#
# loc_1622  -> Format_bcd_time_leading_zero   (suppress leading zero in minutes)
# loc_1662  -> Pack_hex_leading_zero          (blank leading digit if zero)
# loc_1666  -> Flush_pending_dma_transfers    (flush all pending DMA slots)
# loc_1688  -> Flush_dma_slot_a_skip          (skip slot A if count zero)
# loc_16AA  -> Flush_dma_slot_b_skip          (skip slot B if count zero)
# loc_16E8  -> Flush_dma_slot_c_skip          (skip slot C if count zero)
# loc_170A  -> Flush_dma_slot_d_skip          (skip slot D if count zero)
# loc_172C  -> Flush_dma_slot_e_skip          (skip slot E if count zero)
# loc_174E  -> Flush_dma_crash_check          (check crash animation flag)
# loc_1766  -> Flush_dma_crash_style_b        (select crash style B tilemap)
# loc_1776  -> Flush_dma_crash_done           (done after optional crash draw)
# loc_1778  -> Update_car_palette_dma         (update car colour DMA from table)
# loc_178E  -> Update_car_palette_send        (send the 3-byte palette DMA)
# loc_17B6  -> Update_hud_overtake_check      (check overtake/placement animation)
# loc_1810  -> Update_overtake_style_b        (overtake style B tilemap)
# loc_182C  -> Update_overtake_lap_clamp      (clamp lap number to 3)
# loc_184A  -> Update_overtake_done           (return from overtake path)
# loc_184C  -> Update_placement_anim_check    (check placement animation state)
# loc_1898  -> Update_placement_lap_clamp     (clamp placement number to 3)
# loc_18C6  -> Update_placement_draw          (draw placement tiles to VRAM)
# loc_18FE  -> Update_placement_anim_b_check  (check placement_anim_state_b)
# loc_194A  -> Update_placement_b_clamp       (clamp grid position to 3)
# loc_1972  -> Update_placement_b_draw        (draw placement_b tiles to VRAM)
# loc_1998  -> Update_placement_b_done        (return)
# loc_19AA  -> Wrap_index_mod10_done          (return from Wrap_index_mod10)

import re

SOURCE = r'E:\Romhacking\smgp-disassembly\smgp.asm'

RENAMES = [
    ('loc_1622', 'Format_bcd_time_leading_zero'),
    ('loc_1662', 'Pack_hex_leading_zero'),
    ('loc_1666', 'Flush_pending_dma_transfers'),
    ('loc_1688', 'Flush_dma_slot_a_skip'),
    ('loc_16AA', 'Flush_dma_slot_b_skip'),
    ('loc_16E8', 'Flush_dma_slot_c_skip'),
    ('loc_170A', 'Flush_dma_slot_d_skip'),
    ('loc_172C', 'Flush_dma_slot_e_skip'),
    ('loc_174E', 'Flush_dma_crash_check'),
    ('loc_1766', 'Flush_dma_crash_style_b'),
    ('loc_1776', 'Flush_dma_crash_done'),
    ('loc_1778', 'Update_car_palette_dma'),
    ('loc_178E', 'Update_car_palette_send'),
    ('loc_17B6', 'Update_hud_overtake_check'),
    ('loc_1810', 'Update_overtake_style_b'),
    ('loc_182C', 'Update_overtake_lap_clamp'),
    ('loc_184A', 'Update_overtake_done'),
    ('loc_184C', 'Update_placement_anim_check'),
    ('loc_1898', 'Update_placement_lap_clamp'),
    ('loc_18C6', 'Update_placement_draw'),
    ('loc_18FE', 'Update_placement_anim_b_check'),
    ('loc_194A', 'Update_placement_b_clamp'),
    ('loc_1972', 'Update_placement_b_draw'),
    ('loc_1998', 'Update_placement_b_done'),
    ('loc_19AA', 'Wrap_index_mod10_done'),
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
