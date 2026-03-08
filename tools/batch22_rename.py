#!/usr/bin/env python3
# Batch 22: Load_race_hud_graphics and Initialize_race_hud internals,
#           Draw_lap_number_and_times loop, loc_13F6 (sprite init) internals
#
# loc_1100  -> Load_hud_gfx_monaco_fill_loop  (VRAM fill loop for Monaco track)
# loc_110A  -> Load_hud_gfx_mode_check        (check game mode for HUD tileset)
# loc_1118  -> Load_hud_gfx_practice_check    (check practice mode)
# loc_1126  -> Load_hud_gfx_arcade_check      (check arcade vs championship)
# loc_1132  -> Load_hud_gfx_decomp            (decompress HUD tileset to VRAM)
# loc_1142  -> Load_hud_gfx_done              (return from Load_race_hud_graphics)
# loc_1186  -> Init_hud_clear_plane_a_loop    (clear plane A road rows, loop)
# loc_119E  -> Init_hud_clear_plane_b_loop    (clear plane B road rows, loop)
# loc_11B6  -> Init_hud_clear_road_row_loop   (clear road priority row, loop)
# loc_11E8  -> Init_hud_minimap_champ         (championship minimap VRAM offset)
# loc_1262  -> Init_hud_draw_shift            (draw shift indicator tilemap)
# loc_1274  -> Init_hud_draw_laptime          (draw lap time in arcade/practice mode)
# loc_1296  -> Init_hud_draw_laptime_rival    (draw lap time with rival, arcade mode)
# loc_12D2  -> Init_hud_champ_branch          (championship HUD branch)
# loc_131A  -> Init_hud_champ_race_check      (championship race type check)
# loc_1366  -> Init_hud_rival_present         (rival flag present path)
# loc_1382  -> Init_hud_player_ordinal        (draw player grid position ordinal)
# loc_13CC  -> Draw_lap_times_loop            (lap time draw loop in Draw_lap_number_and_times)
# loc_13F6  -> Initialize_hud_objects         (initialize HUD car-colour sprite objects)
# loc_1418  -> Init_hud_objects_rival         (load rival team palette entry)
# loc_1430  -> Init_hud_objects_car3_check    (check for car 3 team colour clash)
# loc_1440  -> Init_hud_objects_car3_load     (load car 3 palette entry)
# loc_1446  -> Init_hud_objects_copy_palette  (copy palette entries to sprite buffer)

import re

SOURCE = r'E:\Romhacking\smgp-disassembly\smgp.asm'

RENAMES = [
    ('loc_1100', 'Load_hud_gfx_monaco_fill_loop'),
    ('loc_110A', 'Load_hud_gfx_mode_check'),
    ('loc_1118', 'Load_hud_gfx_practice_check'),
    ('loc_1126', 'Load_hud_gfx_arcade_check'),
    ('loc_1132', 'Load_hud_gfx_decomp'),
    ('loc_1142', 'Load_hud_gfx_done'),
    ('loc_1186', 'Init_hud_clear_plane_a_loop'),
    ('loc_119E', 'Init_hud_clear_plane_b_loop'),
    ('loc_11B6', 'Init_hud_clear_road_row_loop'),
    ('loc_11E8', 'Init_hud_minimap_champ'),
    ('loc_1262', 'Init_hud_draw_shift'),
    ('loc_1274', 'Init_hud_draw_laptime'),
    ('loc_1296', 'Init_hud_draw_laptime_rival'),
    ('loc_12D2', 'Init_hud_champ_branch'),
    ('loc_131A', 'Init_hud_champ_race_check'),
    ('loc_1366', 'Init_hud_rival_present'),
    ('loc_1382', 'Init_hud_player_ordinal'),
    ('loc_13CC', 'Draw_lap_times_loop'),
    ('loc_13F6', 'Initialize_hud_objects'),
    ('loc_1418', 'Init_hud_objects_rival'),
    ('loc_1430', 'Init_hud_objects_car3_check'),
    ('loc_1440', 'Init_hud_objects_car3_load'),
    ('loc_1446', 'Init_hud_objects_copy_palette'),
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
