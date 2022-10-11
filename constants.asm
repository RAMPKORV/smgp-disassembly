VDP_control_port = $C00004
VDP_data_port = $C00000
Z80_bus_request = $A11100

Player_shift = $FFFF9100
Player_rpm = $FFFF9102
Visual_rpm = $FFFF9104 ; Rendered to gauge
Player_speed = $FFFF9108

Horizontal_position = $FFFFAE12
Player_distance = $FFFFAE1A ; resets each lap

Driver_points_by_team = $FFFF9030
Rival_team = $FFFF9042
Player_team = $FFFF9043
Drivers_and_teams_map = $FFFF9044;
Use_world_championship_tracks = $FFFF9140 ; 1 for world championship or practice, 0 for arcade
Track_index_arcade_mode = $FFFF9142
Track_index = $FFFF9144
Track_length = $FFFF9206 ; 2x value from track selection
Race_started = $FFFF9146
Practice_mode = $FFFF9148
Warm_up = $FFFF914A

; Decompressed in-memory data
Background_horizontal_displacement = $00FF6300
Background_vertical_displacement = $00FF7B00
Curve_data = $00FF5B00

Team_car_acceleration = $FFFF915C
Team_car_engine_data = $FFFF915E
Engine_data_offset = $FFFF9180
Acceleration_modifier = $FFFF9182
Engine_rpm_max = 1500
Retire_flash_flag = $FFFFFC32;
Retire_flag = $FFFFFC54
Pause_flag = $FFFFFC66;
Pit_in_flag = $FFFFFCA0;
English_flag = $FFFFFF26 ; 0 = Japanese, 1 = English
Shift_type = $FFFFFF2E ; 0 = automatic, 1 = 4-shift, 2 = 7-shift
Easy_flag = $FFFFFF1C ; 0 = normal, 1 = easy
Control_type = $FFFFFF1E;

Input_state_bitset = $FFFFFF04
Input_click_bitset = $FFFFFF05
KEY_START = 7
KEY_A     = 6
KEY_C     = 5
KEY_B     = 4
KEY_RIGHT = 3
KEY_LEFT  = 2
KEY_DOWN  = 1
KEY_UP    = 0
