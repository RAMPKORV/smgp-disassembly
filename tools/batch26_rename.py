#!/usr/bin/env python3
"""
Batch 26 label renames — background palettes, road/sideline/finish-line style data,
per-track lap-time target tables, sprite-frame pointer tables, and small internal
code branches.

All labels are data tables that are already annotated by comments in Track_data.
Renaming them makes the data section self-describing without requiring Track_data
comments as the only cross-reference.

Groups:
  A) Background palette tables (1 per championship track + Monaco arcade variants)
     loc_FDCA  -> Track_sky_palette_ptr           (word pointed to by MOVE.l loc_FDCA)
     loc_FDCE  -> San_Marino_bg_palette
     loc_FDE4  -> Monaco_bg_palette
     loc_FDFA  -> Mexico_bg_palette
     loc_FE10  -> France_bg_palette
     loc_FE26  -> Great_Britain_bg_palette
     loc_FE3C  -> West_Germany_bg_palette
     loc_FE52  -> Hungary_bg_palette
     loc_FE68  -> Belgium_bg_palette
     loc_FE7E  -> Portugal_bg_palette
     loc_FE94  -> Spain_bg_palette
     loc_FEAA  -> Australia_bg_palette
     loc_FEC0  -> Usa_bg_palette
     loc_FED6  -> Japan_bg_palette
     loc_FEEC  -> Canada_bg_palette
     loc_FF04  -> Italy_bg_palette
     loc_FF18  -> Brazil_bg_palette
     loc_FF2E  -> Monaco_arcade_bg_palette
     loc_FF44  -> Monaco_arcade_wet_bg_palette

  B) Road style data tables (sideline, road, finish line — 3 per track)
     loc_FF5C  -> Monaco_arcade_sideline_style
     loc_FF64  -> Monaco_arcade_road_style
     loc_FF6E  -> Monaco_arcade_finish_line_style
     loc_FF78  -> Monaco_arcade_wet_sideline_style
     loc_FF82  -> Monaco_arcade_wet_road_style
     loc_FF8C  -> Monaco_arcade_wet_finish_line_style
     loc_FF96  -> San_Marino_sideline_style
     loc_FFA0  -> San_Marino_road_style
     loc_FFAA  -> San_Marino_finish_line_style
     loc_FFB4  -> Brazil_sideline_style
     loc_FFBE  -> Brazil_road_style
     loc_FFC8  -> Brazil_finish_line_style
     loc_FFD2  -> France_sideline_style
     loc_FFDC  -> France_road_style
     loc_FFE6  -> France_finish_line_style
     loc_FFF0  -> Hungary_sideline_style
     loc_FFFA  -> Hungary_road_style
     loc_10004 -> Hungary_finish_line_style
     loc_1000E -> West_Germany_sideline_style
     loc_10018 -> West_Germany_road_style
     loc_10022 -> West_Germany_finish_line_style
     loc_1002C -> Usa_sideline_style
     loc_10036 -> Usa_road_style
     loc_10040 -> Usa_finish_line_style
     loc_1004A -> Canada_sideline_style
     loc_10054 -> Canada_road_style
     loc_1005E -> Canada_finish_line_style
     loc_10068 -> Great_Britain_sideline_style
     loc_10072 -> Great_Britain_road_style
     loc_1007C -> Great_Britain_finish_line_style
     loc_10086 -> Italy_sideline_style
     loc_10090 -> Italy_road_style
     loc_1009A -> Italy_finish_line_style
     loc_100A4 -> Portugal_sideline_style
     loc_100AE -> Portugal_road_style
     loc_100B8 -> Portugal_finish_line_style
     loc_100C2 -> Spain_sideline_style
     loc_100CC -> Spain_road_style
     loc_100D6 -> Spain_finish_line_style
     loc_100E0 -> Mexico_sideline_style
     loc_100EA -> Mexico_road_style
     loc_100F4 -> Mexico_finish_line_style
     loc_100FE -> Japan_sideline_style
     loc_10108 -> Japan_road_style
     loc_10112 -> Japan_finish_line_style
     loc_1011C -> Belgium_sideline_style
     loc_10126 -> Belgium_road_style
     loc_10130 -> Belgium_finish_line_style
     loc_1013A -> Australia_sideline_style
     loc_10144 -> Australia_road_style
     loc_1014E -> Australia_finish_line_style
     loc_10158 -> Monaco_sideline_style
     loc_10162 -> Monaco_road_style
     loc_1016C -> Monaco_finish_line_style

  C) Per-track lap-time target tables (15 × 3-byte BCD entries each)
     loc_10176 -> San_Marino_lap_targets
     loc_101A4 -> Brazil_lap_targets
     loc_101D2 -> France_lap_targets
     loc_10200 -> Hungary_lap_targets
     loc_1022E -> West_Germany_lap_targets       (note: Hockenheim)
     loc_1025C -> Canada_lap_targets
     loc_1028A -> Great_Britain_lap_targets
     loc_102B8 -> Italy_lap_targets
     loc_102E6 -> Spain_lap_targets
     loc_10314 -> Mexico_lap_targets
     loc_10342 -> Japan_lap_targets
     loc_10370 -> Australia_lap_targets
     loc_1039E -> Portugal_lap_targets
     loc_103CC -> Belgium_lap_targets
     loc_103FA -> Usa_lap_targets
     loc_10428 -> Monaco_lap_targets
     loc_10456 -> Monaco_arcade_lap_targets

  D) Sprite frame pointer tables for depth-sorted car rendering
     loc_10484 -> Rival_sprite_frames_depth0
     loc_104A8 -> Rival_sprite_frames_depth_m4
     loc_104CC -> Rival_sprite_frames_depth_p4
     loc_104F0 -> Rival_sprite_frames_depth_m8
     loc_10514 -> Rival_sprite_frames_depth_p8
     loc_10538 -> Ai_sprite_frames_depth_p4
     loc_10550 -> Ai_sprite_frames_depth_p8
     loc_10568 -> Ai_sprite_frames_depth0
     loc_10580 -> Ai_sprite_frames_depth_p12
     loc_10598 -> Rival_sprite_frames_depth_p12
     loc_105B0 -> Player_car_sprite_frames

  E) Internal code branch/loop labels
     loc_A27E  -> Apply_sorted_positions_loop
     loc_AB04  -> Update_ai_car_screen_x_Y_from_table
     loc_AB24  -> Update_ai_car_screen_x_Behind   (already has label assigned below it; this is the entry)
     loc_97EA  -> Assign_ai_sprite_depth_frame_apply
     loc_B258  -> Check_ai_lateral_bounds_entry
     loc_B270  -> Check_ai_lateral_bounds_Positive
     loc_B276  -> Check_ai_lateral_bounds_At_zero
     loc_B284  -> Check_ai_lateral_bounds_Neg_side
     loc_B28C  -> Check_ai_lateral_bounds_Apply
     loc_B290  -> Check_ai_lateral_bounds_Positive_d7

  F) Car tile frame + minimap data
     loc_7968  -> Crash_car_tile_offsets
     loc_796E  -> Crash_car_tile_sizes
     loc_797C  -> Crash_car_frame_a
     loc_798C  -> Crash_car_frame_b
     loc_799E  -> Crash_car_frame_table
     loc_79AE  -> Crash_car_frame_0
     loc_79CE  -> Crash_car_frame_1
     loc_79EE  -> Crash_car_frame_2
     loc_7A16  -> Crash_car_frame_3

  G) Sprite frame tile data table entry-point index
     loc_10640 -> Player_car_sprite_frames_crash
     loc_10648 -> Player_car_sprite_frames_normal
"""

import re
import sys

SRC = 'smgp.asm'

# Each tuple: (old_label, new_label)
RENAMES = [
    # A) Background palettes
    ('loc_FDCA', 'Track_sky_palette_ptr'),
    ('loc_FDCE', 'San_Marino_bg_palette'),
    ('loc_FDE4', 'Monaco_bg_palette'),
    ('loc_FDFA', 'Mexico_bg_palette'),
    ('loc_FE10', 'France_bg_palette'),
    ('loc_FE26', 'Great_Britain_bg_palette'),
    ('loc_FE3C', 'West_Germany_bg_palette'),
    ('loc_FE52', 'Hungary_bg_palette'),
    ('loc_FE68', 'Belgium_bg_palette'),
    ('loc_FE7E', 'Portugal_bg_palette'),
    ('loc_FE94', 'Spain_bg_palette'),
    ('loc_FEAA', 'Australia_bg_palette'),
    ('loc_FEC0', 'Usa_bg_palette'),
    ('loc_FED6', 'Japan_bg_palette'),
    ('loc_FEEC', 'Canada_bg_palette'),
    ('loc_FF04', 'Italy_bg_palette'),
    ('loc_FF18', 'Brazil_bg_palette'),
    ('loc_FF2E', 'Monaco_arcade_bg_palette'),
    ('loc_FF44', 'Monaco_arcade_wet_bg_palette'),
    # B) Road style data
    ('loc_FF5C', 'Monaco_arcade_sideline_style'),
    ('loc_FF64', 'Monaco_arcade_road_style'),
    ('loc_FF6E', 'Monaco_arcade_finish_line_style'),
    ('loc_FF78', 'Monaco_arcade_wet_sideline_style'),
    ('loc_FF82', 'Monaco_arcade_wet_road_style'),
    ('loc_FF8C', 'Monaco_arcade_wet_finish_line_style'),
    ('loc_FF96', 'San_Marino_sideline_style'),
    ('loc_FFA0', 'San_Marino_road_style'),
    ('loc_FFAA', 'San_Marino_finish_line_style'),
    ('loc_FFB4', 'Brazil_sideline_style'),
    ('loc_FFBE', 'Brazil_road_style'),
    ('loc_FFC8', 'Brazil_finish_line_style'),
    ('loc_FFD2', 'France_sideline_style'),
    ('loc_FFDC', 'France_road_style'),
    ('loc_FFE6', 'France_finish_line_style'),
    ('loc_FFF0', 'Hungary_sideline_style'),
    ('loc_FFFA', 'Hungary_road_style'),
    ('loc_10004', 'Hungary_finish_line_style'),
    ('loc_1000E', 'West_Germany_sideline_style'),
    ('loc_10018', 'West_Germany_road_style'),
    ('loc_10022', 'West_Germany_finish_line_style'),
    ('loc_1002C', 'Usa_sideline_style'),
    ('loc_10036', 'Usa_road_style'),
    ('loc_10040', 'Usa_finish_line_style'),
    ('loc_1004A', 'Canada_sideline_style'),
    ('loc_10054', 'Canada_road_style'),
    ('loc_1005E', 'Canada_finish_line_style'),
    ('loc_10068', 'Great_Britain_sideline_style'),
    ('loc_10072', 'Great_Britain_road_style'),
    ('loc_1007C', 'Great_Britain_finish_line_style'),
    ('loc_10086', 'Italy_sideline_style'),
    ('loc_10090', 'Italy_road_style'),
    ('loc_1009A', 'Italy_finish_line_style'),
    ('loc_100A4', 'Portugal_sideline_style'),
    ('loc_100AE', 'Portugal_road_style'),
    ('loc_100B8', 'Portugal_finish_line_style'),
    ('loc_100C2', 'Spain_sideline_style'),
    ('loc_100CC', 'Spain_road_style'),
    ('loc_100D6', 'Spain_finish_line_style'),
    ('loc_100E0', 'Mexico_sideline_style'),
    ('loc_100EA', 'Mexico_road_style'),
    ('loc_100F4', 'Mexico_finish_line_style'),
    ('loc_100FE', 'Japan_sideline_style'),
    ('loc_10108', 'Japan_road_style'),
    ('loc_10112', 'Japan_finish_line_style'),
    ('loc_1011C', 'Belgium_sideline_style'),
    ('loc_10126', 'Belgium_road_style'),
    ('loc_10130', 'Belgium_finish_line_style'),
    ('loc_1013A', 'Australia_sideline_style'),
    ('loc_10144', 'Australia_road_style'),
    ('loc_1014E', 'Australia_finish_line_style'),
    ('loc_10158', 'Monaco_sideline_style'),
    ('loc_10162', 'Monaco_road_style'),
    ('loc_1016C', 'Monaco_finish_line_style'),
    # C) Lap-time target tables
    ('loc_10176', 'San_Marino_lap_targets'),
    ('loc_101A4', 'Brazil_lap_targets'),
    ('loc_101D2', 'France_lap_targets'),
    ('loc_10200', 'Hungary_lap_targets'),
    ('loc_1022E', 'West_Germany_lap_targets'),
    ('loc_1025C', 'Canada_lap_targets'),
    ('loc_1028A', 'Great_Britain_lap_targets'),
    ('loc_102B8', 'Italy_lap_targets'),
    ('loc_102E6', 'Spain_lap_targets'),
    ('loc_10314', 'Mexico_lap_targets'),
    ('loc_10342', 'Japan_lap_targets'),
    ('loc_10370', 'Australia_lap_targets'),
    ('loc_1039E', 'Portugal_lap_targets'),
    ('loc_103CC', 'Belgium_lap_targets'),
    ('loc_103FA', 'Usa_lap_targets'),
    ('loc_10428', 'Monaco_lap_targets'),
    ('loc_10456', 'Monaco_arcade_lap_targets'),
    # D) Sprite frame pointer tables
    ('loc_10484', 'Rival_sprite_frames_depth0'),
    ('loc_104A8', 'Rival_sprite_frames_depth_m4'),
    ('loc_104CC', 'Rival_sprite_frames_depth_p4'),
    ('loc_104F0', 'Rival_sprite_frames_depth_m8'),
    ('loc_10514', 'Rival_sprite_frames_depth_p8'),
    ('loc_10538', 'Ai_sprite_frames_depth_p4'),
    ('loc_10550', 'Ai_sprite_frames_depth_p8'),
    ('loc_10568', 'Ai_sprite_frames_depth0'),
    ('loc_10580', 'Ai_sprite_frames_depth_p12'),
    ('loc_10598', 'Rival_sprite_frames_depth_p12'),
    ('loc_105B0', 'Player_car_sprite_frames'),
    # E) Code branch/loop labels
    ('loc_A27E',  'Apply_sorted_positions_loop'),
    ('loc_AB04',  'Update_ai_car_screen_x_Y_from_table'),
    # loc_AB24 already has Update_ai_car_screen_x_Behind as the next label — skip
    ('loc_97EA',  'Assign_ai_sprite_depth_frame_apply'),
    ('loc_B258',  'Check_ai_lateral_bounds_entry'),
    ('loc_B270',  'Check_ai_lateral_bounds_Positive'),
    ('loc_B276',  'Check_ai_lateral_bounds_At_zero'),
    ('loc_B284',  'Check_ai_lateral_bounds_Neg_side'),
    ('loc_B28C',  'Check_ai_lateral_bounds_Apply'),
    ('loc_B290',  'Check_ai_lateral_bounds_Positive_d7'),
    # F) Crash car frame data
    ('loc_7968',  'Crash_car_tile_offsets'),
    ('loc_796E',  'Crash_car_tile_sizes'),
    ('loc_797C',  'Crash_car_frame_a'),
    ('loc_798C',  'Crash_car_frame_b'),
    ('loc_799E',  'Crash_car_frame_table'),
    ('loc_79AE',  'Crash_car_frame_0'),
    ('loc_79CE',  'Crash_car_frame_1'),
    ('loc_79EE',  'Crash_car_frame_2'),
    ('loc_7A16',  'Crash_car_frame_3'),
    # G) Player car sprite frame index
    ('loc_10640', 'Player_car_sprite_frames_crash'),
    ('loc_10648', 'Player_car_sprite_frames_normal'),
]


def main():
    with open(SRC, 'r', encoding='latin-1') as f:
        src = f.read()

    # Verify no name collisions with existing labels
    new_names = [new for _, new in RENAMES]
    for new in new_names:
        if re.search(r'^' + re.escape(new) + r':', src, flags=re.MULTILINE):
            print(f'ERROR: target name {new!r} already exists as a label definition!', file=sys.stderr)
            sys.exit(1)

    total_replacements = 0
    for old, new in RENAMES:
        # Add ;loc_XXXX preservation comment above each definition
        def_pattern = re.compile(r'^(' + re.escape(old) + r':)', re.MULTILINE)
        def_replacement = f';{old}\n{new}:'
        src, n_def = def_pattern.subn(def_replacement, src)
        if n_def == 0:
            print(f'WARNING: definition of {old} not found', file=sys.stderr)

        # Replace all references (not definitions — those were already handled above)
        ref_pattern = re.compile(r'\b' + re.escape(old) + r'\b')
        src, n_ref = ref_pattern.subn(new, src)

        total = n_def + n_ref
        total_replacements += total
        print(f'{old} -> {new}: {n_def} def, {n_ref} refs, {total} total')

    with open(SRC, 'w', encoding='latin-1') as f:
        f.write(src)

    print(f'\nDone. {total_replacements} total replacements across {len(RENAMES)} labels.')


if __name__ == '__main__':
    main()
