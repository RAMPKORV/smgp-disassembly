; ============================================================
; Hardware registers
; ============================================================
VDP_control_port = $C00004
VDP_data_port    = $C00000
Z80_bus_request  = $A11100

; ============================================================
; Frame dispatch pointers (RAM function pointers)
; Changed each frame to transition game state.
; ============================================================
Frame_callback       = $FFFFFF10 ; main-loop per-frame callback (main game state machine)
Vblank_callback      = $FFFFFF0C ; VBI per-frame callback (tilemap upload, input, palette)
Saved_frame_callback = $FFFFFF2A ; saved Frame_callback, restored when returning from sub-screens

; ============================================================
; Input
; ============================================================
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

; ============================================================
; System / hardware init flags (set at startup from controller port)
; ============================================================
Overseas_flag = $FFFFFF1A ; $FF if overseas/NTSC, $00 if domestic/Japan  (SNE from bit 7)
Pal_flag      = $FFFFFF1B ; $FF if PAL 50 Hz, $00 if NTSC 60 Hz         (SNE from bit 6)

; ============================================================
; VDP state cache
; ============================================================
Saved_vdp_state = $FFFFFF00 ; 4-byte saved VDP register state
Vdp_dma_setup   = $FFFFFF08 ; longword: CRAM or VRAM DMA address command written to VDP control port

; ============================================================
; Hblank stub destination
; ============================================================
Hblank_handler_stub = $FFFFFFD2 ; RAM destination for hblank ISR stub code copied by Install_hblank_handler

; ============================================================
; Title / options menu state  ($FFFF9000 area)
; ============================================================
Title_menu_state          = $FFFF9000 ; current top-level menu page (0=main, 1=new/pw, 2=warm/race/machine/trans, 3=laps)
Title_menu_item_table_ptr = $FFFF9002 ; pointer to text-item list for the current menu page
Title_menu_vdp_command    = $FFFF9006 ; VDP address command used when rendering menu text
Title_menu_cursor         = $FFFF900A ; highlighted row index (0-based)
Title_menu_item_count     = $FFFF900C ; max selectable rows in current menu page
Title_menu_cursor_row     = $FFFF900D ; currently displayed highlight row
Title_menu_row_count      = $FFFF900E ; total visible rows in current menu page
Title_menu_flags          = $FFFF900F ; bit 0 = needs redraw, bit 1 = scroll pending, bit 3 = ?

; ============================================================
; Race event / player state flags  ($FFFF902x area)
; ============================================================
Race_event_flags  = $FFFF902E ; event bits: bit 5 = ?, bit 6 = ?, bit 7 = ?
Player_state_flags = $FFFF902F ; bit 0 = ?, bit 1 = ?, bit 2 = ?, bit 3 = ?, bit 4 = ?

; ============================================================
; Standings / points data  ($FFFF903x area)
; ============================================================
Driver_points_by_team = $FFFF9030 ; points table indexed by team

; ============================================================
; Team / driver selection  ($FFFF904x area)
; ============================================================
Rival_team          = $FFFF9042
Player_team         = $FFFF9043
Drivers_and_teams_map = $FFFF9044 ; mapping table: driver index -> team index

; ============================================================
; Race mode selection flags  ($FFFF914x area)
; ============================================================
Use_world_championship_tracks = $FFFF9140 ; 1 for world championship or practice, 0 for arcade
Track_index_arcade_mode       = $FFFF9142
Track_index                   = $FFFF9144
Race_started                  = $FFFF9146
Practice_mode                 = $FFFF9148
Warm_up                       = $FFFF914A

; ============================================================
; Car object struct layout (shared by player and AI cars)
; Struct size: $40 bytes.
; Player object base: $FFFFAE00
; AI/rival car array:  $FFFFB080, 16 entries of $40 bytes each
;
; Field offsets (relative to object base):
;   +$00 .l  update function pointer
;   +$04 .l  palette data
;   +$0E .w  animation state / display flags
;   +$12 .w  horizontal screen X position (signed; $80 = centre lane)
;   +$16 .w  ?
;   +$18 .w  ?
;   +$1A .w  track distance (integer steps from lap start)
;   +$1E .w  placement score (used for race-position comparison)
;   +$22 .w  ?
;   +$26 .w  ?
;   +$28 .w  previous animation frame index
;   +$2B .b  ?
;   +$30 .w  max speed (base value)
;   +$32 .w  max speed × 128
;   +$34 .w  acceleration / secondary speed cap
; ============================================================
Car_obj_x_pos         = $12 ; +$12 .w  horizontal screen X (signed; $80 = centre)
Car_obj_track_dist    = $1A ; +$1A .w  integer track steps from lap start
Car_obj_place_score   = $1E ; +$1E .w  placement comparison score
Car_obj_max_speed     = $30 ; +$30 .w  max speed (base)
Car_obj_max_speed_shl = $32 ; +$32 .w  max speed << 7
Car_obj_accel_cap     = $34 ; +$34 .w  acceleration / secondary speed cap

Player_obj            = $FFFFAE00 ; base address of player car object
Horizontal_position   = $FFFFAE12 ; = Player_obj + Car_obj_x_pos      (.w horizontal position)
Player_distance       = $FFFFAE1A ; = Player_obj + Car_obj_track_dist  (.w track distance)
Player_place_score    = $FFFFAE1E ; = Player_obj + Car_obj_place_score (.w placement score)

Ai_car_array          = $FFFFB080 ; base of AI car object array (16 × $40 bytes)
Ai_car_stride         = $40       ; bytes between consecutive AI car objects
; Rival car (car 0) = Ai_car_array
; Background AI cars (cars 1-15) = Ai_car_array + Ai_car_stride * n
Rival_car_obj         = $FFFFB080 ; = Ai_car_array[0]: the main rival / opponent
Rival_car_place_score = $FFFFB09E ; = Rival_car_obj + Car_obj_place_score

; ============================================================
; Player vehicle state  ($FFFF910x area)
; ============================================================
Player_shift       = $FFFF9100
Player_rpm         = $FFFF9102
Visual_rpm         = $FFFF9104 ; Rendered to gauge
Player_speed       = $FFFF9108
Player_speed_raw   = $FFFF9106 ; pre-integration speed (before copy to Player_speed)
Steering_output    = $FFFF910A ; horizontal steering output fed to road renderer
Road_x_offset      = $FFFF910B ; road X pixel offset ($80 = centre)
Track_boundary_type   = $FFFF910C ; boundary/edge type index (0 = none, 4 = soft, 8 = hard)
Track_boundary_wobble = $FFFF910D ; wobble value when bouncing off boundary
Collision_flag     = $FFFF910E ; non-zero when player is colliding with an obstacle

; ============================================================
; Driving model derived values  ($FFFF911x area)
; ============================================================
Rpm_derivative     = $FFFF9110 ; derivative (rate-of-change) of RPM, used for gauge animation

; ============================================================
; Team / car performance data  ($FFFF915x-918x area)
; ============================================================
Team_car_acceleration  = $FFFF915C
Team_car_engine_data   = $FFFF915E
Engine_data_offset     = $FFFF9180
Acceleration_modifier  = $FFFF9182
Engine_rpm_max         = 1500

; ============================================================
; Track / road state  ($FFFF92xx area)
; ============================================================
Tileset_dirty_flag       = $FFFF9200 ; non-zero = tileset swap pending; $FFFF = just swapped
Tileset_base_offset      = $FFFF9202 ; VDP tile index base offset for road tiles (toggled by tileset swap)
Player_x_negated         = $FFFF9204 ; negation of Horizontal_position, used by road renderer
Track_length             = $FFFF9206 ; 2x value from track header (used as lap-distance modulus)
Road_marker_state        = $FFFF9208 ; state of roadside marker sequence (0=inactive, 1=?, 2=active)
Track_unknown_field_1    = $FFFF920C ; unknown word from track header offset $22
Background_zone_index    = $FFFF920E ; current background-zone index for parallax scroll region
Background_zone_prev     = $FFFF9210 ; previous background-zone index (detects zone transitions)
Background_zone_2_distance = $FFFF9212 ; track distance at which background zone 2 begins
Background_zone_1_distance = $FFFF9214 ; track distance at which background zone 1 begins
Player_distance_steps    = $FFFF9220 ; integer part of accumulated distance (steps since lap start)
Player_distance_fixed    = $FFFF9222 ; fixed-point accumulated distance (fractional + integer)
Minimap_track_map_ptr    = $FFFF9226 ; pointer to minimap position map for current track
Laps_completed           = $FFFF9232 ; number of laps completed by the player this race
Lap_time_ptr             = $FFFF92E0 ; pointer into lap time comparison table
Lap_time_table_ptr       = $FFFF92E4 ; pointer to base of per-lap time table

; ============================================================
; Decompressed in-memory track/road buffers
; ============================================================
Background_horizontal_displacement = $00FF6300
Background_vertical_displacement   = $00FF7B00
Curve_data                         = $00FF5B00

; ============================================================
; Retire / pause / pit flags  ($FFFFCxxx area, scattered)
; ============================================================
Retire_flash_flag = $FFFFFC32
Retire_flag       = $FFFFFC54
Pause_flag        = $FFFFFC66
Pit_in_flag       = $FFFFFCA0

; ============================================================
; Screen-state scratch variables  ($FFFFFC00-$FFFFFC2F area)
; These are general-purpose per-screen temporaries reused by each screen/handler.
; ============================================================
Screen_timer      = $FFFFFC00 ; countdown or up-counter used by current screen (frames)
Screen_digit      = $FFFFFC01 ; BCD digit value for options laps counter
Screen_tick       = $FFFFFC02 ; per-digit frame countdown in options screen (60 frames/digit)
Screen_scroll     = $FFFFFC04 ; VDP tile address step (scroll/animation position in current screen)
Screen_subcounter = $FFFFFC08 ; small state counter / sub-frame index in current screen
Screen_item_count = $FFFFFC0A ; item count for current rendering pass
Screen_data_ptr   = $FFFFFC0C ; pointer used by current screen (e.g. tilemap list cursor)
Menu_cursor       = $FFFFFC10 ; highlighted item index within current screen menu
Menu_substate     = $FFFFFC12 ; sub-state counter within menu interaction
Temp_x_pos        = $FFFFFC14 ; temporary horizontal position (used during race/AI init)
Temp_distance     = $FFFFFC18 ; temporary distance or race-start countdown value
Anim_delay        = $FFFFFC1C ; animation delay countdown (frames to hold current anim frame)
Frame_counter     = $FFFFFC20 ; free-running byte frame counter, incremented every main loop tick
Vblank_counter    = $FFFFFC22 ; incremented by VBI; polled by Wait_for_vblank for sync
Practice_vblank_step = $FFFFFC24 ; practice mode VBI sub-step (0/4/8/16 cycle for HUD/move/idle)
Vblank_enable     = $FFFFFC2A ; 1 = VBI will invoke Vblank_callback, 0 = VBI skips callback
Race_frame_counter = $FFFFFC2C ; large frame counter / screen-duration countdown for race screens

; ============================================================
; Tilemap draw queue  ($FFFFFC60-$FFFFFC63 area)
; ============================================================
Tilemap_queue_count = $FFFFFC60 ; number of pending tilemap draw entries in the queue
Tilemap_queue_ptr   = $FFFFFC62 ; write pointer into tilemap draw queue buffer ($FFFFE700)

; ============================================================
; Pause / music state  ($FFFFFC68-$FFFFFC6F area)
; ============================================================
Pause_prev_state  = $FFFFFC68 ; previous pause flag value (to detect pause/resume transitions)
Music_beat_counter = $FFFFFC6A ; countdown between music beat ticks (0..8)
Music_beat_flip    = $FFFFFC6C ; toggles each beat (used for flashing / sync effects)

; ============================================================
; Lap / overtake event flags  ($FFFFFC70-$FFFFFC8F area)
; ============================================================
New_lap_flag         = $FFFFFC70 ; set to 1 when player completes a lap
Overtake_event_flag  = $FFFFFC74 ; set to 1 when player overtakes an AI car
Current_placement    = $FFFFFC78 ; player's current race position (1-based ordinal)
Placement_anim_state = $FFFFFC7C ; animation state for placement ordinal display (0/1/3)
Placement_anim_state_b = $FFFFFC7E ; secondary animation state for rival placement display
Race_finish_flag     = $FFFFFC80 ; set to 1 when the race finish line has been crossed
Options_cursor_update = $FFFFFC82 ; non-zero = options screen cursor moved, needs VDP update
Placement_change_flag = $FFFFFC84 ; set to 1 when player's placement changes during race
New_placement        = $FFFFFC88 ; new placement value to animate toward
Placement_display_dirty = $FFFFFC8A ; non-zero = placement display needs to be redrawn

; ============================================================
; Miscellaneous race counters  ($FFFFFC9x area)
; ============================================================
Aux_object_counter = $FFFFFC94 ; frame counter for aux object pool (used by race init)

; ============================================================
; Road scroll / minimap state  ($FFFFFC46-$FFFFFC5F area)
; ============================================================
HUD_scroll_base   = $FFFFFC46 ; HUD background scroll base tile index
Minimap_scroll_pos = $FFFFFC4A ; minimap row scroll position (pixel offset)
Minimap_track_offset = $FFFFFC4C ; minimap tile offset for current track position
Overtake_flag     = $FFFFFC58 ; 1 = player is currently overtaking an opponent
Overtake_delta    = $FFFFFC5C ; signed delta for overtake position animation

; ============================================================
; Fast-page game-mode flags  ($FFFFFFxx area)
; ============================================================
Control_handler_ptr = $FFFFFF20 ; pointer to current control input handler (set by Load_control_type_handler)
Easy_flag           = $FFFFFF1C ; 0 = normal difficulty, 1 = easy difficulty
Control_type        = $FFFFFF1E ; 0=type A (brake/accel buttons), 1=type B, etc.
English_flag        = $FFFFFF26 ; 0 = Japanese text, 1 = English text
Shift_type          = $FFFFFF2E ; 0 = automatic, 1 = 4-shift, 2 = 7-shift
Practice_flag       = $FFFFFF18 ; 1 = warm-up or practice mode active, 0 = real race

; ============================================================
; Race / standings state  ($FFFFFF30-$FFFFFF5F area)
; ============================================================
Current_lap          = $FFFFFF30 ; player's current lap number (0-based; race ends when this reaches 14)
Best_lap_vdp_step    = $FFFFFF32 ; VDP tile address step used when drawing best lap time digits
Player_grid_position = $FFFFFF34 ; player's starting grid position for current race
Saved_shift_type     = $FFFFFF36 ; copy of Shift_type saved when entering options screen
Race_time_bcd        = $FFFFFF38 ; BCD-encoded total accumulated race time (e.g. $1800 = 18:00)
Rival_grid_position  = $FFFFFF3A ; rival car's starting grid position
Saved_shift_type_2   = $FFFFFF4A ; second copy of Shift_type (preserved across sub-screens)
Selection_count      = $FFFFFF4C ; number of selectable items in the current car/team picker
Has_rival_flag       = $FFFFFF4E ; 1 = a rival car is present in this race, 0 = no rival
Player_overtaken_flag = $FFFFFF50 ; set to 1 when an AI car overtakes the player
Total_distance       = $FFFFFF56 ; cumulative total distance driven across all laps (track-length units)
Replay_input_ptr     = $FFFFFF58 ; pointer into the replay / warm-up input data stream
Frame_subtick        = $FFFFFF5C ; sub-tick counter within each display frame (0-3 cycle)
Checkpoint_index     = $FFFFFF5E ; index of the last passed track checkpoint (0-14)
Player_start_grid_arcade = $FFFFFF60 ; player's calculated starting grid position (arcade mode)
Rival_start_grid_arcade  = $FFFFFF62 ; rival's calculated starting grid position (arcade mode)

; ============================================================
; Tilemap draw queue buffer ($FFFFE700)
; ============================================================
Tilemap_draw_queue = $FFFFE700 ; buffer for pending tilemap draw commands; each entry:
                                ;   dc.l  VDP address command
                                ;   dc.l  source tilemap pointer
                                ;   dc.b  tile columns - 1
                                ;   dc.b  tile rows - 1
