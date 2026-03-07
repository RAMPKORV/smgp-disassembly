#!/usr/bin/env python3
"""Replace raw RAM/IO hex literals in smgp.asm with symbolic constant names.

Each entry is (hex_address_without_dollar, symbol_name).
Only replaces occurrences NOT followed by further hex digits (to avoid
partial matches like $FFFFFC00x or $FFFFFC000).
"""

import re
import sys

REPLACEMENTS = [
    # $FFFFCxxx scratch / per-screen temporaries
    ('FFFFFC00', 'Screen_timer'),
    ('FFFFFC04', 'Screen_scroll'),
    ('FFFFFC08', 'Screen_subcounter'),
    ('FFFFFC0C', 'Screen_data_ptr'),
    ('FFFFFC10', 'Menu_cursor'),
    ('FFFFFC12', 'Menu_substate'),
    ('FFFFFC14', 'Temp_x_pos'),
    ('FFFFFC18', 'Temp_distance'),
    ('FFFFFC1C', 'Anim_delay'),
    ('FFFFFC20', 'Frame_counter'),
    ('FFFFFC22', 'Vblank_counter'),
    ('FFFFFC24', 'Practice_vblank_step'),
    ('FFFFFC2A', 'Vblank_enable'),
    ('FFFFFC2C', 'Race_frame_counter'),
    ('FFFFFC32', 'Retire_flash_flag'),
    ('FFFFFC46', 'HUD_scroll_base'),
    ('FFFFFC4A', 'Minimap_scroll_pos'),
    ('FFFFFC4C', 'Minimap_track_offset'),
    ('FFFFFC54', 'Retire_flag'),
    ('FFFFFC58', 'Overtake_flag'),
    ('FFFFFC5C', 'Overtake_delta'),
    ('FFFFFC60', 'Tilemap_queue_count'),
    ('FFFFFC62', 'Tilemap_queue_ptr'),
    ('FFFFFC66', 'Pause_flag'),
    ('FFFFFC68', 'Pause_prev_state'),
    ('FFFFFC6A', 'Music_beat_counter'),
    ('FFFFFC6C', 'Music_beat_flip'),
    ('FFFFFC70', 'New_lap_flag'),
    ('FFFFFC74', 'Overtake_event_flag'),
    ('FFFFFC78', 'Current_placement'),
    ('FFFFFC7C', 'Placement_anim_state'),
    ('FFFFFC7E', 'Placement_anim_state_b'),
    ('FFFFFC80', 'Race_finish_flag'),
    ('FFFFFC82', 'Options_cursor_update'),
    ('FFFFFC84', 'Placement_change_flag'),
    ('FFFFFC88', 'New_placement'),
    ('FFFFFC8A', 'Placement_display_dirty'),
    ('FFFFFC94', 'Aux_object_counter'),
    ('FFFFFCA0', 'Pit_in_flag'),
    # $FFFFFFxx fast-page
    ('FFFFFF00', 'Saved_vdp_state'),
    ('FFFFFF04', 'Input_state_bitset'),
    ('FFFFFF05', 'Input_click_bitset'),
    ('FFFFFF08', 'Vdp_dma_setup'),
    ('FFFFFF0C', 'Vblank_callback'),
    ('FFFFFF10', 'Frame_callback'),
    ('FFFFFF18', 'Practice_flag'),
    ('FFFFFF1A', 'Overseas_flag'),
    ('FFFFFF1B', 'Pal_flag'),
    ('FFFFFF1C', 'Easy_flag'),
    ('FFFFFF1E', 'Control_type'),
    ('FFFFFF20', 'Control_handler_ptr'),
    ('FFFFFF26', 'English_flag'),
    ('FFFFFF2A', 'Saved_frame_callback'),
    ('FFFFFF2E', 'Shift_type'),
    ('FFFFFF30', 'Current_lap'),
    ('FFFFFF32', 'Best_lap_vdp_step'),
    ('FFFFFF34', 'Player_grid_position'),
    ('FFFFFF36', 'Saved_shift_type'),
    ('FFFFFF38', 'Race_time_bcd'),
    ('FFFFFF3A', 'Rival_grid_position'),
    ('FFFFFF4A', 'Saved_shift_type_2'),
    ('FFFFFF4C', 'Selection_count'),
    ('FFFFFF4E', 'Has_rival_flag'),
    ('FFFFFF50', 'Player_overtaken_flag'),
    ('FFFFFF56', 'Total_distance'),
    ('FFFFFF58', 'Replay_input_ptr'),
    ('FFFFFF5C', 'Frame_subtick'),
    ('FFFFFF5E', 'Checkpoint_index'),
    ('FFFFFF60', 'Player_start_grid_arcade'),
    ('FFFFFF62', 'Rival_start_grid_arcade'),
    # $FFFF9xxx gameplay state
    ('FFFF9000', 'Title_menu_state'),
    ('FFFF9002', 'Title_menu_item_table_ptr'),
    ('FFFF9006', 'Title_menu_vdp_command'),
    ('FFFF900A', 'Title_menu_cursor'),
    ('FFFF900C', 'Title_menu_item_count'),
    ('FFFF900D', 'Title_menu_cursor_row'),
    ('FFFF900E', 'Title_menu_row_count'),
    ('FFFF900F', 'Title_menu_flags'),
    ('FFFF902E', 'Race_event_flags'),
    ('FFFF902F', 'Player_state_flags'),
    ('FFFF9030', 'Driver_points_by_team'),
    ('FFFF9042', 'Rival_team'),
    ('FFFF9043', 'Player_team'),
    ('FFFF9044', 'Drivers_and_teams_map'),
    ('FFFF9100', 'Player_shift'),
    ('FFFF9102', 'Player_rpm'),
    ('FFFF9104', 'Visual_rpm'),
    ('FFFF9106', 'Player_speed_raw'),
    ('FFFF9108', 'Player_speed'),
    ('FFFF910A', 'Steering_output'),
    ('FFFF910B', 'Road_x_offset'),
    ('FFFF910C', 'Track_boundary_type'),
    ('FFFF910D', 'Track_boundary_wobble'),
    ('FFFF910E', 'Collision_flag'),
    ('FFFF9110', 'Rpm_derivative'),
    ('FFFF9140', 'Use_world_championship_tracks'),
    ('FFFF9142', 'Track_index_arcade_mode'),
    ('FFFF9144', 'Track_index'),
    ('FFFF9146', 'Race_started'),
    ('FFFF9148', 'Practice_mode'),
    ('FFFF914A', 'Warm_up'),
    ('FFFF915C', 'Team_car_acceleration'),
    ('FFFF915E', 'Team_car_engine_data'),
    ('FFFF9180', 'Engine_data_offset'),
    ('FFFF9182', 'Acceleration_modifier'),
    ('FFFF9200', 'Tileset_dirty_flag'),
    ('FFFF9202', 'Tileset_base_offset'),
    ('FFFF9204', 'Player_x_negated'),
    ('FFFF9206', 'Track_length'),
    ('FFFF9208', 'Road_marker_state'),
    ('FFFF920C', 'Track_unknown_field_1'),
    ('FFFF920E', 'Background_zone_index'),
    ('FFFF9210', 'Background_zone_prev'),
    ('FFFF9212', 'Background_zone_2_distance'),
    ('FFFF9214', 'Background_zone_1_distance'),
    ('FFFF9220', 'Player_distance_steps'),
    ('FFFF9222', 'Player_distance_fixed'),
    ('FFFF9226', 'Minimap_track_map_ptr'),
    ('FFFF9232', 'Laps_completed'),
    ('FFFF92E0', 'Lap_time_ptr'),
    ('FFFF92E4', 'Lap_time_table_ptr'),
    # Hardware
    ('C00004', 'VDP_control_port'),
    ('C00000', 'VDP_data_port'),
    ('A11100', 'Z80_bus_request'),
    # Tilemap draw queue buffer
    ('FFFFE700', 'Tilemap_draw_queue'),
    # Driving model / crash state flags
    ('FFFFFCA4', 'Crash_animation_flag'),
    ('FFFFFCA6', 'Crash_spin_flag'),
    ('FFFFFCA8', 'Retire_animation_flag'),
    ('FFFFFC76', 'Spin_off_track_flag'),
    ('FFFFFCBE', 'Overtake_position_delta'),
    # Track-specific modifier indices
    ('FFFF9160', 'Track_steering_index'),
    ('FFFF9162', 'Track_steering_index_b'),
    ('FFFF9164', 'Track_braking_index'),
    # Replay/AI steering override
    ('FFFFAE38', 'Replay_steer_override'),
    # Sound
    ('FFFFE996', 'Engine_sound_pitch'),
    # Control key mappings (byte fields within Control_handler_ptr longword)
    ('FFFFFF21', 'Control_key_shift_up'),
    ('FFFFFF22', 'Control_key_accel'),
    ('FFFFFF23', 'Control_key_brake'),
]

def main():
    src = 'smgp.asm'
    with open(src, 'r', encoding='utf-8') as f:
        content = f.read()

    total = 0
    for addr, name in REPLACEMENTS:
        # Match $ADDR not followed by more hex digits
        pattern = r'\$' + addr + r'(?![0-9A-Fa-f])'
        count = len(re.findall(pattern, content))
        if count:
            content = re.sub(pattern, name, content)
            total += count
            print(f'  {name}: {count}')

    with open(src, 'w', encoding='utf-8') as f:
        f.write(content)

    print(f'\nTotal replacements: {total}')

if __name__ == '__main__':
    main()
