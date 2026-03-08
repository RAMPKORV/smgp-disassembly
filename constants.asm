; ============================================================
; Hardware registers
; ============================================================
VDP_control_port = $C00004
VDP_data_port    = $C00000
Z80_bus_request  = $A11100  ; write $0100 to request, $0000 to release; bit 0 = bus not yet granted
Z80_reset        = $A11200  ; write $0000 to assert reset, $0100 to release reset
Z80_ram          = $A00000  ; base address of Z80 address space as seen from 68K ($A00000-$A0FFFF)

; I/O port registers ($A10000 area)
; The Mega Drive exposes its controller/expansion ports here.
; All accesses must be bracketed by Z80 bus request/release
; because the Z80 also drives the bus during its ISR.
; Registers exist as 16-bit slots; the 68K accesses data bytes at odd addresses.
; Even addresses carry the upper half of each 16-bit slot (used at boot for settle checks).
Version_register    = $00A10001 ; .b  hardware version byte: bit 7 = overseas, bit 6 = PAL
Io_ctrl_port_1_data = $00A10003 ; .b  controller port 1 data register (read: button state)
Io_ctrl_port_2_data = $00A10005 ; .b  controller port 2 data register
Io_ctrl_port_3_data = $00A10007 ; .b  controller port 3 / expansion port data register
Io_ctrl_port_1_dir  = $00A10009 ; .b  controller port 1 direction register ($40 = TH output)
Io_ctrl_port_2_dir  = $00A1000B ; .b  controller port 2 direction register
Io_ctrl_port_3_dir  = $00A1000D ; .b  controller port 3 / expansion port direction register
; Boot settle check addresses (even = upper byte of 16-bit port slot; reads before RAM init):
Io_port_settle_l    = $00A10008 ; .l  read as longword at boot entry to flush pending I/O state
Io_port_settle_w    = $00A1000C ; .w  read as word in settle-wait loop until both ports are idle

; ============================================================
; VDP display geometry (fast-page RAM, $FFFFFF14-$FFFFFF24)
; Set by Initialize_h40_vdp_state and Initialize_h32_vdp_state.
; ============================================================
Object_update_counter = $FFFFFF14 ; .w  countdown during Update_objects_and_build_sprite_buffer pass
                                    ;     initialised to $4C per frame; decremented per slot;
                                    ;     also used as per-object AI stagger offset (added to Frame_counter)
Vdp_plane_row_bytes   = $FFFFFF16 ; .w  bytes per tilemap row for DMA and scroll computations
                                    ;     $50 (80) in H40 mode, $40 (64) in H32 mode
Vdp_plane_tile_count  = $FFFFFF24 ; .w  total visible tile count used for DMA fill and sprite Y culling
                                    ;     $01C0 (448) in H40 mode, $0180 (384) in H32 mode

; ============================================================
; Track preview cursor (fast-page RAM, $FFFFFF28)
; ============================================================
Track_preview_index   = $FFFFFF28 ; .w  arcade track-select cursor index (0-15); cycles via ±1 + AND #$000F;
                                    ;     copied to Track_index on confirmation

; ============================================================
; Boot / init sentinel (fast-page RAM, $FFFFFFFC)
; ============================================================
Boot_init_sentinel    = $FFFFFFFC ; .l  written $696E6974 ('init') by first-time boot path;
                                    ;     checked each reset to distinguish cold boot from warm reset

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
Input_state_bitset = $FFFFFF04 ; .b  held-key bitset after controller decode (bit 0-7 = up/down/left/right/B/C/A/start)
Input_click_bitset = $FFFFFF05 ; .b  newly-pressed edge bitset for the current frame
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
; Standings / points data  ($FFFF903x-$FFFF907F area)
; ============================================================
Driver_points_by_team = $FFFF9030 ; 16-byte table: accumulated championship points indexed by team number (0-15)

Promoted_teams_bitfield = $FFFF9040 ; .w  16-bit bitmask: bit N set = team N has been promoted as partner/rival during championship
                                     ; read/written in Championship_standings_init and standings rotation routines

; Standings sort buffers (used by Initialize_standings_order_buffer + Rotate_standings_buffer)
Standings_perf_scores = $FFFF905E   ; 16 bytes: per-driver randomised AI performance scores used for display-order sort
Standings_team_order  = $FFFF906E   ; 16 bytes: driver indices sorted ascending by Standings_perf_scores (position 0 = last place)
;                                   ; slot 15 (highest score) = 1st place driver; built by Initialize_standings_order_buffer
;                                   ; read by Build_minimap_player_row_buffer to display team colour strips in order
Standings_points_buf  = $FFFF907E   ; 16 bytes: points earned per Standings_team_order slot this race;
;                                   ; cleared then filled from PointsAwardedPerPlacement by Accumulate_race_points
Font_tile_base        = $FFFF905A   ; .w  base tile index added to decoded text glyphs by Load_font_tiles_to_work_buffer / Render_text_to_tilemap

; ============================================================
; Team / driver selection  ($FFFF904x area)
; ============================================================
Rival_team          = $FFFF9042 ; .b  current rival team/flags byte (low nibble = team index, upper bits = championship state flags)
Player_team         = $FFFF9043 ; .b  selected player team/flags byte (low nibble = team index, bit 6 = year-2/livery flag)
Drivers_and_teams_map = $FFFF9044 ; 17-byte table: driver slot -> team index mapping, immediately following Player_team

; ============================================================
; Race mode selection flags  ($FFFF914x area)
; ============================================================
Use_world_championship_tracks = $FFFF9140 ; 1 for world championship or practice, 0 for arcade
Track_index_arcade_mode       = $FFFF9142 ; .w  arcade race variant / track-select state (0=championship path, 1/2=arcade/demo variants)
Track_index                   = $FFFF9144 ; .w  current Track_data entry index
Track_index_b                 = $FFFF9145 ; .b  low byte alias of Track_index used by save serialization
Race_started                  = $FFFF9146 ; .w  0 before countdown completes, 1 once live race logic is active
Practice_mode                 = $FFFF9148 ; .w  non-zero in free practice flow
Warm_up                       = $FFFF914A ; .w  non-zero in championship warm-up flow

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
Player_shift       = $FFFF9100 ; .w  current gear number (0-6 depending on transmission type)
Player_rpm         = $FFFF9102 ; .w  live engine RPM used by driving model
Visual_rpm         = $FFFF9104 ; .w  smoothed RPM rendered to the HUD gauge
Player_speed_raw   = $FFFF9106 ; .w  pre-integration speed before copy/clamp into Player_speed
Player_speed       = $FFFF9108 ; .w  current speed value used by gameplay and HUD
Steering_output    = $FFFF910A ; .w  signed horizontal steering output fed to road/object renderers
Road_x_offset      = $FFFF910B ; .b  road X pixel centre offset ($80 = centred)
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
Team_car_acceleration  = $FFFF915C ; .w  byte offset into Acceleration_modifiers (0/$02/$04/$06 → index 0-3)
Team_car_engine_data   = $FFFF915E ; .w  byte offset into Engine_data_offset_table (0/$02/$04/$06/$08/$0A → variant 0-5)
Engine_data_offset     = $FFFF9180 ; .w  resolved byte offset into Engine_data for current team's engine variant
Acceleration_modifier  = $FFFF9182 ; .w  signed word acceleration adjustment (-1/0/+1/+2) from Acceleration_modifiers
Engine_rpm_max         = 1500      ; RPM ceiling (rpm gauge clips here)

; Engine_data_offset value used in practice / warm-up / attract mode (no team-specific engine):
; corresponds to Engine_data variant 2 ($003C = 2 × $001E), the mid-strength engine row.
Engine_data_offset_practice = $003C

; ============================================================
; Track / road state  ($FFFF92xx area)
; ============================================================
Tileset_dirty_flag       = $FFFF9200 ; non-zero = tileset swap pending; $FFFF = just swapped
Tileset_base_offset      = $FFFF9202 ; VDP tile index base offset for road tiles (toggled by tileset swap)
Background_zone_0_flag_b = $FFFF9211 ; .b  low-byte flag used when deciding whether sky rows need filling
Player_x_negated         = $FFFF9204 ; negation of Horizontal_position, used by road renderer
Track_length             = $FFFF9206 ; 2x value from track header (used as lap-distance modulus)
Road_marker_state        = $FFFF9208 ; state of roadside marker sequence (0=inactive, 1=?, 2=active)
Track_horizon_override_flag = $FFFF920C ; Track_data +$20: 1 = use special horizon/sky colour override (West Germany, Italy, Belgium); 0 = default sky
                                       ; was Track_unknown_field_1
Track_phys_slope_value   = $FFFF920A ; current physical-slope byte for the player's track position
                                      ; (looked up from Physical_slope_data[Player_distance/4] each frame;
                                      ;  used by Update_rpm to modulate RPM on hills: negative = uphill drag)
Road_curve_prev_buf     = $FFFF91BA ; previous per-segment road-curve X values used for interpolation smoothing
; ============================================================
; Sign / trackside object state  ($FFFF924x-$FFFF925F area)
;
; Signs are roadside objects (advertising hoardings, barriers, etc.) placed
; at specific distances along each track.  Two parallel streams drive them:
;
;   Sign data stream (Track_data +$24):
;     4 bytes per record: distance.w, count.b, sign_id.b
;     Terminated by $FFFF distance word (high bit set → BPL falls through).
;     At terminator, Signs_data_ptr is reset to Signs_data_start_ptr (new lap).
;     sign_id indexes Sign_lookup_table (×4) → pointer to frame-index list.
;     Signs_in_row_count signs are spaced $0010 apart at Signs_location.
;
;   Tileset stream (Track_data +$28):
;     4 bytes per record: distance.w, tileset_offset.w
;     Terminated by $FFFF distance word.
;     tileset_offset indexes Sign_tileset_table → 10-byte DMA descriptor written
;     to Sign_tileset_buf ($FFFF925C): DMA src (4 bytes), DMA length (2 bytes),
;     second word (2 bytes), $FFFF sentinel (2 bytes).
;
; Both streams are polled each frame via Parse_tileset_for_signs /
; Parse_sign_data when Player_distance is within 120 ($78) units of the entry.
; ============================================================
Signs_data_start_ptr  = $FFFF9240 ; pointer to start of sign data stream for current track (reset each lap)
Signs_data_ptr        = $FFFF9244 ; current read position in sign data stream
Sign_table_entry_start = $FFFF9248 ; pointer to first byte of current sign's frame-index list
Sign_table_entry_ptr  = $FFFF924C ; current read position in sign's frame-index list
Signs_location        = $FFFF9250 ; track-distance of the current sign (spacing +$0010 per sign in row)
Signs_in_row_count    = $FFFF9252 ; how many signs remain in the current sign-row group
Signs_tileset_start_ptr = $FFFF9254 ; pointer to start of sign tileset stream (reset each lap)
Signs_tileset_ptr     = $FFFF9258 ; current read position in sign tileset stream
Sign_tileset_buf      = $FFFF925C ; 10-byte DMA descriptor for current sign tileset:
                                   ;   dc.l  DMA source address
                                   ;   dc.w  DMA transfer length
                                   ;   dc.w  secondary word field
                                   ;   dc.w  $FFFF sentinel
Sign_tileset_dma_word_2 = $FFFF9260 ; sign tileset DMA descriptor word 2 (rolling source offset)
Sign_tileset_dma_word_3 = $FFFF9262 ; sign tileset DMA descriptor word 3 (rolling DMA length)

Track_placement_distance_table = $FFFF922C ; 3 packed placement checkpoint distances (dc.w × 3):
                                            ; [0] = Track_length (initialised from track header),
                                            ; [1],[2] = sub-lap quarter-point distances loaded from loc_FDCA
Track_sky_palette_ptr_buf = $FFFF922E ; .l  cached Track_data +$1C sky/background palette pointer for current track
Track_placement_seq_ptr  = $FFFF9284 ; pointer into current position in the placement-update sequence table
                                     ; (points into loc_73CA or loc_73DC depending on arcade sub-variant)
Road_column_update_state = $FFFF9276 ; .w  road-column DMA state (0=idle, 1=single-column update, 2=full refresh)
Road_scroll_distance_prev = $FFFF9266 ; cached Player_distance_steps used to detect when road-column scroll data must be rebuilt
Road_column_src_ptr     = $FFFF9268 ; .l  current source pointer for road-column DMA writes
Road_column_step        = $FFFF9274 ; .w  step/offset descriptor paired with Road_column_src_ptr
Road_column_tile_base   = $FFFF926C ; .w  tile base for normal road-column DMA upload
Road_column_priority_ptr = $FFFF926E ; .l  source pointer for priority-layer road-column DMA upload
Road_column_priority_step = $FFFF9272 ; .w  step/offset descriptor for priority road-column upload
Road_column_tiles_dirty = $FFFF927C ; .w  non-zero when the temporary road-column tile buffer must be uploaded first
Road_column_update_pending = $FFFF927E ; .w  0=no column update, 1=single update, 2=full update with edge columns
Road_sign_rotation_index = $FFFF922A ; .w  rotating 0/2/4 index selecting the active sign-row pattern entry
Sign_tileset_dma_pending = $FFFF9264 ; .w  non-zero when a sign tileset DMA upload is pending this frame
Depth_sort_leader_ptr   = $FFFF928C ; .w  object pointer of the front-most AI car selected during depth sort
Depth_sort_prev_ptr     = $FFFF928E ; .w  object pointer of the second front-most AI car during depth sort
Track_lap_time_base_ptr  = $FFFF92FC ; Track_data +$3C: pointer into Track_lap_time_records for current track
                                     ; (base = $FFFFFD00 + 8 × track_index; used by Draw_bcd_time_to_vdp)
Background_zone_index    = $FFFF920E ; current background-zone index for parallax scroll region
Background_zone_prev     = $FFFF9210 ; previous background-zone index (detects zone transitions)
Background_zone_2_distance = $FFFF9212 ; track distance at which background zone 2 begins
Background_zone_1_distance = $FFFF9214 ; track distance at which background zone 1 begins
Player_distance_steps    = $FFFF9220 ; integer part of accumulated distance (steps since lap start)
Player_distance_fixed    = $FFFF9222 ; fixed-point accumulated distance (fractional + integer)
Minimap_track_map_ptr    = $FFFF9226 ; pointer to minimap position map for current track
Special_road_scene      = $FFFF9238 ; .w  special road-scene mode for crash/rival approach sequences (0=normal, 1/2/3=special render modes)
Special_road_scene_b    = $FFFF9239 ; .b  low byte alias of Special_road_scene used for quick bit tests
Special_road_audio_mode = $FFFF923A ; .w  companion special-scene mode word fed into Audio_engine_flags updates
Special_road_blank_bg_flag = $FFFF923C ; .w  non-zero forces blank background row data during special road scenes
Background_vertical_offset = $FFFF9236 ; .w  sampled background vertical displacement for current player distance
Laps_completed           = $FFFF9232 ; number of laps completed by the player this race
Lap_time_ptr             = $FFFF92E0 ; pointer into lap time comparison table
Lap_time_table_ptr       = $FFFF92E4 ; pointer to base of per-lap time table
Rival_race_time_bcd_prev = $FFFF92D8 ; previous/copy buffer for rival BCD race time during lap accumulation
Rival_race_time_bcd      = $FFFF92DC ; rival BCD race time accumulator / display source

; ============================================================
; Track lap time records  ($FFFFFD00 area)
; ============================================================
; Initialised by loc_510A at startup from ROM data at loc_553E.
; Structure: 37 entries × 8 bytes, packed as two sub-blocks:
;   First block: 37 × 4-byte BCD records (format: $00, tens, units, $00)
;                at $FFFFFD00; each track's pointer (Track_data +$3C) points
;                to a sub-range of these 8-byte slots.
;   Second block: 37 × 4-byte data records starting immediately after.
; The per-track pointer (Track_lap_time_base_ptr) selects 8 bytes per track.
; Used by Draw_bcd_time_to_vdp to render best-lap / target-time on the HUD.
Track_lap_time_records   = $FFFFFD00 ; base of per-track BCD lap-time record block (8 bytes/track × 19 tracks = 152 bytes)

Road_scroll_update_mode  = $FFFF9280 ; .w  road-scroll rebuild mode (0=idle, 1=rebuild with rails, 2=rebuild without rail update)
Road_scroll_updated_flag = $FFFF9282 ; .w  set to 1 after Update_road_tile_scroll finishes rebuilding buffers

; ============================================================
; Per-lap target time buffer  ($FFFFAD40)
; ============================================================
; Initialised by Load_track_data from the Track_data +$40 pointer (loc_10176 etc.).
; Contains 15 expanded 4-byte BCD records ($00, tens, units, $00) for each lap.
; Written at race start; each entry is compared against the player's lap time
; to decide whether to advance the lap counter in championship mode.
Track_lap_target_buf     = $FFFFAD40 ; 15 × 4-byte expanded per-lap BCD target times for current track

; ============================================================
; Decompressed in-memory track/road buffers
; ============================================================
Background_horizontal_displacement = $00FF6300
Background_vertical_displacement   = $00FF7B00
Curve_data                         = $00FF5B00
Visual_slope_data                  = $00FF7300 ; Track_data +$34: RLE-decompressed visual slope stream (read by Update_slope_data)
Physical_slope_data                = $00FF8300 ; Track_data +$38: RLE-decompressed physical slope stream (drives RPM gravity modifier)

; ============================================================
; Retire / pause / pit flags  ($FFFFCxxx area, scattered)
; ============================================================
Retire_flash_flag = $FFFFFC32
Ai_lap_transition_flag = $FFFFFCC0 ; .w  lap-transition notifier (1=player lap crossed, 2=rival lap crossed)
Ai_lap_transition_flag_b = $FFFFFCC1 ; .b  low byte alias of Ai_lap_transition_flag
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
Screen_flash_state = $FFFFFC03 ; .b  generic flashing/toggle state byte for team-select and endgame screens
Name_entry_blink_timer = $FFFFFC2D ; .b  frame timer controlling initials-entry cursor blink cadence
Screen_state_word_0 = $FFFFFC06 ; .w  general per-screen scratch word; reused as Name_entry row index and Endgame bitfield
Screen_scroll     = $FFFFFC04 ; VDP tile address step (scroll/animation position in current screen)
Screen_subcounter = $FFFFFC08 ; small state counter / sub-frame index in current screen
Screen_item_count = $FFFFFC0A ; item count for current rendering pass
Screen_item_count_b = $FFFFFC0B ; .b  low byte alias of Screen_item_count used for cursor flash tests
Screen_data_ptr   = $FFFFFC0C ; pointer used by current screen (e.g. tilemap list cursor)
Menu_cursor_blink_state = $FFFFFC0D ; .b  cursor blink/toggle state for team-select and driver-select screens
Rival_dialogue_state = $FFFFFC0E ; .b  state bits for the rival dialogue panel open/selection flow
Menu_cursor       = $FFFFFC10 ; highlighted item index within current screen menu
Selection_repeat_state = $FFFFFC11 ; .b  per-screen repeat/blink counter used by initials/championship selection cursors
Menu_substate     = $FFFFFC12 ; sub-state counter within menu interaction
Temp_x_pos        = $FFFFFC14 ; temporary horizontal position (used during race/AI init)
Screen_state_word_1 = $FFFFFC16 ; .w  general per-screen scratch word; team-select marker bitfield / text scroll index
Temp_distance     = $FFFFFC18 ; temporary distance or race-start countdown value
Screen_state_byte_0 = $FFFFFC19 ; .b  general per-screen scratch byte; reused as driver/team text index and blink counter
Screen_state_byte_1 = $FFFFFC1A ; .b/.w  general per-screen scratch state; reused for timers, flags, and text row counts
Screen_state_byte_2 = $FFFFFC1B ; .b  companion scratch byte for screen-local text/tilemap dimensions
Anim_delay        = $FFFFFC1C ; animation delay countdown (frames to hold current anim frame)
Team_select_state = $FFFFFC1E ; .w  Team_select_frame dispatch index (0,4,8,12,16)
Frame_counter     = $FFFFFC20 ; free-running byte frame counter, incremented every main loop tick
Vblank_counter    = $FFFFFC22 ; incremented by VBI; polled by Wait_for_vblank for sync
Practice_vblank_step = $FFFFFC24 ; practice mode VBI sub-step (0/4/8/16 cycle for HUD/move/idle)
Sprite_slots_remaining = $FFFFFC30 ; .w  remaining sprite-link slots while Build_sprites_* assembles SAT
Countdown_lights_x_pos = $FFFFFC2E ; .w  current X position for the countdown lights object
Countdown_lights_active_flag = $FFFFFC34 ; .w  non-zero while the countdown lights object is active
Crash_scene_hud_span = $FFFFFC36 ; .w  width/span used when blanking HUD/road rows during crash scenes
Crash_scene_depth = $FFFFFC38 ; .w  crash-scene depth value derived from AI screen Y
Crash_scene_shadow_base = $FFFFFC3A ; .w  base shadow span for secondary crash-car overlay logic
Crash_scene_shadow_depth = $FFFFFC3C ; .w  shadow depth value derived from crash-car overlay logic
Crash_scene_compare_depth = $FFFFFC3E ; .w  stored comparison depth for special-road overlay updates
Crash_scene_delta_depth = $FFFFFC40 ; .w  delta derived from Crash_scene_compare_depth
Crash_scene_prev_shadow = $FFFFFC42 ; .w  previous crash-scene shadow span
Crash_scene_prev_delta = $FFFFFC44 ; .w  previous crash-scene shadow delta
HUD_blank_row_count = $FFFFFC48 ; .w  number of HUD/road rows to blank during special crash scenes
Collision_sfx_cooldown = $FFFFFC4E ; .w  cooldown timer between collision SFX triggers
Road_sfx_cooldown = $FFFFFC50 ; .w  cooldown timer between road-surface SFX triggers
Crash_lateral_gap = $FFFFFC52 ; .w  lateral gap captured during crash/bounds checks
Collision_prev_flag = $FFFFFC56 ; .w  previous Collision_flag sample for edge detection
Collision_speed_penalty = $FFFFFC5A ; .w  temporary RPM/speed penalty derived from crash lateral gap
Road_surface_prev_state = $FFFFFC5E ; .w  previous Road_marker_state sample for edge detection
Road_sign_fill_flag = $FFFFFC86 ; .w  latch indicating a sign row was drawn this frame
Lap_checkpoint_target = $FFFFFC8E ; .w  next Player_place_score checkpoint that awards placement points
Car_palette_dma_id = $FFFFFCA2 ; .w  pending car-livery palette DMA selection
Race_position_award_cooldown = $FFFFFCAE ; .w  cooldown timer for repeated checkpoint/place award SFX
Binary_to_decimal_bcd_scratch = $FFFFFCFC ; 4-byte BCD scratch used by Binary_to_decimal
Dma_queue_slot_a = $FFFFFCD2 ; 10-byte pending DMA descriptor slot A
Crash_sync_palette_dma = $FFFFFCD8 ; palette DMA descriptor used by Crash_obj_sync_player / RPM gauge helpers
Retire_flash_palette_dma = $FFFFFCEA ; palette DMA descriptor used by retire flash effect
Slide_car_palette_dma = $FFFFFCF0 ; palette DMA descriptor used by slide-car intro effect
Crash_car_palette_dma = $FFFFFCF6 ; palette DMA descriptor used by crash-car palette setup
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
Finish_line_sign_active = $FFFFFC72 ; set to 1 when the finish-line flagkeeper sign has been triggered;
                                     ; blocks further sign/tileset spawning until next lap reset
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
; Control key mapping ($FFFFFF20-$FFFFFF23):
;   Loaded as a longword from Control_types table.
;   Each byte is a KEY_* bit index used with BTST against Input_state_bitset.
Control_key_shift_down  = $FFFFFF20 ; byte: bit index of the shift-down key for current control type
Control_key_shift_up    = $FFFFFF21 ; byte: bit index of the shift-up key for current control type
Control_key_accel       = $FFFFFF22 ; byte: bit index of the accelerate key for current control type
Control_key_brake       = $FFFFFF23 ; byte: bit index of the brake key for current control type
Control_handler_ptr     = $FFFFFF20 ; longword: all 4 key bit indices packed (loaded from Control_types)
Easy_flag               = $FFFFFF1C ; 0 = normal difficulty, 1 = easy difficulty
Control_type            = $FFFFFF1E ; 0=type A (brake/accel buttons), 1=type B, etc.
English_flag            = $FFFFFF26 ; 0 = Japanese text, 1 = English text
Shift_type              = $FFFFFF2E ; 0 = automatic, 1 = 4-shift, 2 = 7-shift
Practice_flag           = $FFFFFF18 ; 1 = warm-up or practice mode active, 0 = real race

; ============================================================
; Race / standings state  ($FFFFFF30-$FFFFFF5F area)
; ============================================================
Current_lap          = $FFFFFF30 ; player's current lap number (0-based; race ends when this reaches 14)
Best_lap_vdp_step    = $FFFFFF32 ; VDP tile address step used when drawing best lap time digits
Player_grid_position = $FFFFFF34 ; player's starting grid position for current race
Player_grid_position_b = $FFFFFF35 ; .b  low byte alias of Player_grid_position, used in standings/message comparisons
Saved_shift_type     = $FFFFFF36 ; copy of Shift_type saved when entering options screen
Race_time_bcd        = $FFFFFF38 ; BCD-encoded total accumulated race time (e.g. $1800 = 18:00)
Rival_grid_position  = $FFFFFF3A ; rival car's starting grid position
Rival_grid_position_b = $FFFFFF3B ; .b  low byte alias of Rival_grid_position, used in standings/message comparisons
Saved_shift_type_2   = $FFFFFF4A ; second copy of Shift_type (preserved across sub-screens)
Selection_count      = $FFFFFF4C ; number of selectable items in the current car/team picker
Has_rival_flag       = $FFFFFF4E ; 1 = a rival car is present in this race, 0 = no rival
Player_overtaken_flag = $FFFFFF50 ; set to 1 when an AI car overtakes the player
Steering_divisor_straight = $FFFFFF52 ; Track_data +$44 low word: steering sensitivity divisor on straights
                                       ; (fed into DIVS to scale steering output; larger = less sensitive)
Steering_divisor_curve    = $FFFFFF54 ; Track_data +$44 high word: steering sensitivity divisor on curves
                                       ; (same scale as Steering_divisor_straight; most tracks = $002B)
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

; ============================================================
; Crash / spin / retire / overtake animation state  ($FFFFCAxxx area)
; ============================================================
Crash_animation_flag  = $FFFFFCA4 ; non-zero while crash/spin animation is playing (also used by Update_breaking)
Crash_spin_flag       = $FFFFFCA6 ; non-zero while player is in a spin/off-track slide state
                                   ; suppresses normal driving model (Update_rpm, Update_breaking)
Retire_animation_flag = $FFFFFCA8 ; non-zero while retire/DNF cut-scene is playing

; ============================================================
; Driving model spin/crash state  ($FFFFFC76)
; ============================================================
Spin_off_track_flag = $FFFFFC76 ; non-zero when player has spun and is fully off-track
                                  ; → Update_rpm decelerates by 30/frame; Update_speed clamped

; ============================================================
; Overtake / position animation state  ($FFFFCBxx area)
; ============================================================
Overtake_position_delta = $FFFFFCBE ; signed word: incremental position offset during overtake animation;
                                     ; inhibits horizontal position update while non-zero

; ============================================================
; Track-specific steering and braking modifier indices  ($FFFF916x area)
; ============================================================
Track_steering_index  = $FFFF9160 ; index into steering parameter delta table (set per track)
Track_steering_index_b = $FFFF9162 ; secondary index for steering divisor adjustment
Track_braking_index   = $FFFF9164 ; index into braking strength modifier table (set per track)

; ============================================================
; Replay / AI steering override state  ($FFFFAE38)
; ============================================================
Replay_steer_override = $FFFFAE38 ; 0=player, 1=force right, other=force left
                                   ; used by warm-up replay and AI control injection

; ============================================================
; Sound control register
; ============================================================
Engine_sound_pitch = $FFFFE996 ; word written to control engine sound pitch:
                                ;   $022E (558)  = normal engine tone
                                ;   $0E86 (3718) = high-pitch shift-warning pulse

; ============================================================
; Audio engine state struct at $FF5AC0 (68K-side audio driver state)
;
; The 68K drives its own YM2612/PSG-based engine sound system using a 68K-side
; audio engine state struct at $FF5AC0.  The per-frame update routine
; (Update_audio_engine, called once per Race_loop frame) reads RPM/speed/shift
; state, encodes note data via Encode_z80_note, and then writes the encoded
; bytes directly to the Z80 RAM window ($A01FA0-$A01FC6) using the Z80 bus
; arbitration sequence in Write_byte_to_z80_ram.  The struct is also used to
; sequence music playback commands and per-channel volume envelopes.
;
; Struct base: $FF5AC0  (A6 in Update_audio_engine)
; Scratch buffer: $FF5AF0  (A4 in Update_audio_engine; 12 bytes of note data)
;
; Field offsets (all .w unless noted):
;   +$00  music command latch  – game code writes a song ID here to queue a track change
;   +$02  music mode/state     – bits 0-3 = active mode; written $000F to silence all channels
;   +$04  engine speed word    – scaled player speed for pitch calculation
;   +$06  channel flags        – bit 0 = engine sound active; bit 1 = ?
;   +$08  PSG ch1 note         – note/frequency index for PSG channel 1 ($00FF = silent)
;   +$0A  PSG ch1 pitch bend
;   +$0C  PSG ch2 note         – note/frequency index for PSG channel 2 ($00FF = silent)
;   +$0E  PSG ch2 pitch bend
;   +$12  fade-in/out counter  – counts down to 0; non-zero suppresses volume write
;   +$14  previous shift word  – last sampled Player_shift value for change detection
;   +$16  vibrato/bend counter – decrements; controls vibrato depth modulation
;   +$18  volume word          – current volume level sent to Z80
;   +$1A  pitch word           – current base pitch sent to Z80 (derived from speed)
;   +$1C  frame counter        – free-running +1 per Update_audio_engine call
;   +$1E  engine flags byte    – bit 0 = rev-up/screech active; bit 1 = fade-in pending
;   +$20  note step counter    – counts through the loc_762AA note-sequence table (mod $001F)
;   +$22  sequence timer       – countdown to next note-sequence step; $8000 = halted
;   +$24  command-latch byte   – pending per-channel command byte; 0 = no command
;   +$26  screech hold counter – frames to hold the screech/rev note
;   +$28  PSG channel data     – two-byte PSG state packed as longword
;   +$29  screech decay counter
;
; Audio_engine_state = $FF5AC0
; Audio_engine_scratch = $FF5AF0  (12-byte buffer used by Encode_z80_note calls)
; ============================================================
Audio_engine_state    = $00FF5AC0 ; base of 68K audio engine state struct
Audio_engine_scratch  = $00FF5AF0 ; 12-byte per-frame note data scratch buffer

; Audio engine control fields (absolute addresses for use outside the update routine):
Audio_music_cmd     = $00FF5AC0   ; +$00 .w  music track command latch (game code writes song ID here)
Audio_music_state   = $00FF5AC2   ; +$02 .w  music mode/state word
Audio_engine_speed  = $00FF5AC4   ; +$04 .w  scaled speed word for engine pitch calculation
Audio_engine_flags  = $00FF5AC6   ; +$06 .w  channel enable flags (bit 0 = engine on)
Audio_engine_vol_ch1 = $00FF5AC8  ; +$08 .w  PSG channel 1 volume/note word ($00FF = silent)
Audio_engine_vol_ch2 = $00FF5ACC  ; +$0C .w  PSG channel 2 volume/note word ($00FF = silent)
Audio_sfx_cmd       = $00FF5AE0   ; +$20 .w  sound-effect command port (game code writes SFX ID here)
Audio_seq_timer     = $00FF5AE2   ; +$22 .w  sequence countdown timer ($8000 = halted)
Audio_ctrl_mode     = $00FF5AE4   ; +$24 .b  audio control mode byte ($80 = trigger playback, $01 = mode 1)

; Z80 RAM communication addresses (offsets within Z80 address space at $A00000):
; These are the specific Z80 RAM locations the 68K writes to via Write_byte_to_z80_ram.
; Actual Z80 RAM is 8 KB at Z80 offsets $0000-$1FFF.
Z80_audio_music_cmd = $00A01C09   ; Z80 RAM: music command byte (song ID $81-$8F -> $01-$0F)
Z80_audio_sfx_cmd_b = $00A01C0D   ; Z80 RAM: SFX command slot B (3 bytes)
Z80_audio_sfx_cmd_c = $00A01C10   ; Z80 RAM: SFX command slot C (1 byte)
Z80_audio_engine_ch1 = $00A01FA0  ; Z80 RAM: PSG engine channel 1 note data (6 bytes)
Z80_audio_engine_ch1b = $00A01FA2 ; Z80 RAM: PSG engine channel 1 note data (16 bytes, long block)
Z80_audio_engine_ch2 = $00A01FC0  ; Z80 RAM: PSG engine channel 2 note data (6 bytes)
Z80_audio_engine_ch2b = $00A01FC2 ; Z80 RAM: PSG engine channel 2 note data (4 bytes, long block)
Z80_audio_pitch_sfm  = $00A01FB3  ; Z80 RAM: FM engine pitch/mode byte
Z80_audio_key_on     = $00A01FB7  ; Z80 RAM: key-on/off command byte for YM2612 channel

; ------------------------------------------------------------
; Music track IDs (written to Audio_music_cmd before Trigger_music_playback)
; The 68K encodes the final Z80 command as $80 + song_id.
; ------------------------------------------------------------
Music_credits            = 2    ; credits scroll screen
Music_pre_race           = 3    ; pre-race briefing screen (both arcade and championship)
Music_race_results       = 5    ; race finish results screen (Race_results_frame)
Music_title_screen       = 6    ; title screen / attract mode
Music_race               = 7    ; in-race music (triggered at race start via AI car init)
Music_game_over          = 8    ; game over confirm screen
Music_team_select        = 9    ; team / driver select screen
Music_championship_start = 14   ; championship start screen (driver/team intro)
Music_championship_next  = 13   ; next race in championship (standard team)
Music_championship_next_special = 11 ; next race in championship (special/Marlboro team path)
Music_race_result_overlay = $0C ; race result overlay screen (Race_result_overlay_frame)
Music_rival_encounter    = $11  ; rival team encounter / briefing screen (attract and championship)
Music_championship_final = $0F  ; championship final ending cutscene

; Arcade race music is set from Options_cursor_update ($10 = music on, 0 = silent)

; ------------------------------------------------------------
; Sound effect IDs (written to Audio_sfx_cmd)
; ------------------------------------------------------------
Sfx_menu_cursor          = $02  ; menu cursor move / option scroll sound
Sfx_pre_race_countdown   = $04  ; pre-race countdown (practice mode path)
Sfx_race_start_go        = $05  ; race start "go" signal (practice mode path)
Sfx_checkpoint           = $06  ; checkpoint / lap marker event
Sfx_menu_confirm         = $0E  ; menu item confirm / navigation sound
Sfx_collision_thud       = $0B  ; car collision thud
Sfx_asphalt              = $10  ; on-road tyre/surface sound
Sfx_rough_road           = $11  ; rough road surface (Road_marker_state == 2)
Sfx_gravel               = $12  ; gravel / grass off-road
Sfx_demo_transition      = $1B  ; attract/demo button-press screen transition (written twice)

; ============================================================
; Title / options menu state values
; ============================================================
; Title_menu_state values:
Title_menu_state_main      = 0 ; main menu (World Championship, Free Practice, Options, Arcade)
Title_menu_state_newpw     = 1 ; new/password sub-menu (New Game, Password)
Title_menu_state_champ     = 2 ; championship sub-menu (Warm Up, Race, Machine, Transmission);
                                ;   also shows track preview art
Title_menu_state_arcade    = 3 ; arcade/track-select sub-menu (track chooser)

; Shift_type values (Shift_type = $FFFFFF2E):
Shift_auto   = 0 ; automatic transmission
Shift_4speed = 1 ; 4-speed manual
Shift_7speed = 2 ; 7-speed manual

; Control_type values (Control_type = $FFFFFF1E):
; Values 0-5 are valid; the options screen wraps at 6 back to 0.
Control_type_count = 6 ; total number of control configurations

; Placement_anim_state values (Placement_anim_state = $FFFFFC7C):
Placement_anim_idle        = 0 ; no change animation running
Placement_anim_counting    = 1 ; animating position change (blinking)
Placement_anim_finished    = 3 ; position animation complete (holds final tile)

; ============================================================
; RAM buffer base addresses
; ============================================================
; Object pools — each slot is $40 bytes wide.
Main_object_pool = $FFFFAD80 ; base of main object pool (76 slots × $40 bytes);
                               ;   cleared by Clear_main_object_pool;
                               ;   iterated by Update_objects_and_build_sprite_buffer
Aux_object_pool  = $FFFFB840 ; base of auxiliary object pool (signs, flagkeeper, tunnel objects;
                               ;   $21 slots × $40 bytes); cleared by Clear_aux_object_pool
Car_spec_marker_delay   = $FFFFB88E ; .b  frame delay for the car-spec road-marker sequence
Car_spec_marker_index   = $FFFFB892 ; .w  sequence index for car-spec road-marker updates
Car_spec_marker_end     = $FFFFB896 ; .w  end step count for current car-spec road-marker entry
Car_spec_marker_vdp_cmd = $FFFFB8CE ; .l  current VDP command for car-spec road-marker tile updates
Car_spec_marker_src_ptr = $FFFFB8D2 ; .l  source pointer for car-spec road-marker text/tile data
Car_spec_marker_step    = $FFFFB8D6 ; .w  current step within the active car-spec marker entry
Driver_spec_marker_delay   = $FFFFB90E ; .b  frame delay for the driver-spec road-marker sequence
Driver_spec_marker_index   = $FFFFB912 ; .w  sequence index for driver-spec road-marker updates
Driver_spec_marker_end     = $FFFFB916 ; .w  end step count for current driver-spec road-marker entry
Driver_spec_marker_vdp_cmd = $FFFFB94E ; .l  current VDP command for driver-spec road-marker tile updates
Driver_spec_marker_src_ptr = $FFFFB952 ; .l  source pointer for driver-spec road-marker text/tile data
Driver_spec_marker_step    = $FFFFB956 ; .w  current step within the active driver-spec marker entry
Road_blank_row_count = $FFFFAFEC ; .w  row span used when blanking retire/sign background rows

; Sprite attribute table shadow buffer
Sprite_attr_buf  = $FFFF9AC0 ; sprite attribute table RAM buffer ($280 bytes);
                               ;   built each frame by Update_objects_and_build_sprite_buffer,
                               ;   then DMA'd to VDP sprite table at $F800

; Road rendering tables
Road_scale_table = $FFFF9700 ; per-scanline road scale + displacement table (60 pairs of words);
                               ;   initialised once per race by init routine near $8060;
                               ;   read by road renderer to compute per-row scaling and object depth sort
Road_bg_curve_interp_buf = $FFFF9300 ; background curve interpolation buffer combined into Road_row_x_buf
Road_row_x_buf   = $FFFF9400 ; coarse road-row X buffer used by road-edge and AI lateral position code
Road_row_y_buf   = $FFFF9480 ; coarse road-row Y-position buffer built by Initialize_road_graphics_state
Road_curve_interp_buf = $FFFF9658 ; current per-segment road-curve X values before smoothing into scanlines
Road_scanline_x_buf = $FFFF9600 ; fine per-scanline road X displacement buffer for renderer and AI lateral lookup
Road_tile_id_buf = $FFFF9900 ; road tile ID buffer consumed by Update_road_graphics tile assembly

; Championship intro tilemap buffer
Championship_logo_buf = $FFFFEE80 ; tilemap buffer used during Championship_start_init for
                                     ;   scrolling team-logo strip decompression ($80 tiles)

; Prebuilt UI tilemap buffer banks created by Initialize_ui_tilemap_buffers.
Ui_tilemap_panel_a      = $FFFFD400
Ui_tilemap_panel_a_alt  = $FFFFD410
Ui_tilemap_panel_b_alt  = $FFFFD440
Ui_tilemap_panel_b      = $FFFFD470
Ui_tilemap_panel_a_copy = $FFFFD680
Ui_tilemap_panel_c      = $FFFFD6C0
Ui_tilemap_panel_d      = $FFFFD6F0
Ui_tilemap_scratch_a    = $FFFFD900
Ui_tilemap_panel_e      = $FFFFD92C
Ui_tilemap_panel_f      = $FFFFD9B0
Ui_tilemap_panel_g      = $FFFFD950
Ui_tilemap_panel_h      = $FFFFD980
Ui_tilemap_scratch_b    = $FFFFE000
Ui_tilemap_panel_i      = $FFFFE080
Ui_tilemap_panel_j      = $FFFFE0B0
Screen_scroll_table_buf = $FFFF9D40 ; generic per-line scroll table buffer used by results/finale screens

Special_sign_obj_ptr    = $FFFFAFC0 ; .l  pointer/state block for the current special sign / crash-car helper object

Podium_minimap_state    = $FFFFC480 ; .w  podium/results minimap dispatch state index
Podium_minimap_vdp_base = $FFFFC482 ; .w  current VDP tile base for podium minimap row streaming
Podium_minimap_cell_x   = $FFFFC486 ; .w  current cell X offset while streaming minimap rows
Podium_minimap_row      = $FFFFC488 ; .w  current minimap row index while streaming
Podium_minimap_src_ptr  = $FFFFC48A ; .l  current source pointer for podium minimap tile data

; ============================================================
; General-purpose work RAM range
; ============================================================
Work_ram_start = $FFFF8000 ; start of game work RAM; EntryPoint bulk-clears $7000 bytes
                            ;   ($FFFF8000–$FFFFEFFE) to zero on cold boot
Road_car_scroll_buf = $FFFF8B00 ; 9-row circular road-car tilemap scroll buffer used by opponent-column updates
Road_car_priority_buf = $FFFFCE00 ; base of priority-flip road-car tile buffer generated by Build_car_tilemap_buffers
Team_palette_copy_buf = $FFFF8FD2 ; 8-byte RAM mirror of the selected team palette chunk copied into CRAM shadow
Standings_team_order_tmp = $FFFF8FC0 ; temporary 16-byte standings/team-order scratch buffer before copy back to Drivers_and_teams_map
Sprite_link_buf_main = $FFFFA280 ; main sprite-link bookkeeping buffer used while building the SAT
Sprite_link_buf_alt = $FFFFA7B0 ; alternate sprite-link bookkeeping buffer for secondary object queueing
Bg_sprite_row_buf = $FFFFA7A0 ; background sprite row accumulator used by Build_sprites_*
Fg_sprite_row_buf = $FFFFAC30 ; foreground sprite row accumulator used by Build_sprites_*
Crash_approach_scroll_buf = $FFFFAD00 ; copied crash/rival-approach scroll-strip data used by special road scenes
Player_obj_field_14 = $FFFFAD14 ; Player_obj +$14 temporary per-frame sprite/road state field
Placement_anim_ptr = $FFFFADC0 ; current placement animation handler / script pointer
Road_scroll_origin_x = $FFFFAFD8 ; .w  road scroll/origin X position used when building background and approach strips
Opponent_scroll_column_span = $FFFFAFE8 ; .w  number of opponent scroll columns to update this frame
Flagkeeper_obj_ptr = $FFFFAF80 ; handler/object pointer for the flagkeeper cutscene helper object
Player_state_save_buf = $FFFFFF80 ; 64-byte save/load scratch buffer for password/name-entry state

; ============================================================
; Decompressor scratch buffers  ($FFFFFA00, $FFFFEA00)
; ============================================================
Decomp_code_table = $FFFFFA00 ; 256-entry Huffman decode table built by
                                ;   Build_decompression_code_table (512 bytes);
                                ;   reused by every Decompress_to_vdp / Decompress_to_ram call
Tilemap_work_buf  = $FFFFEA00 ; 256-word general decompress/tilemap work buffer;
                                ;   used by Draw_packed_tilemap_to_vdp, Build_car_tilemap_buffers,
                                ;   and various tilemap decompression calls
Attract_anim_tile_buf = $FFFFF200 ; animation tile upload buffer for attract/startup car-cell effects
Attract_anim_cell_count = $FFFFFB08 ; .w  queued attract-animation cell count / active-cell tracker
Attract_anim_slot_buf = $FFFFFB0E ; two-word attract-animation slot timer/state buffer
Attract_anim_restore_flag = $FFFFFB12 ; .b  set when Attract_anim_cell_update queued a restore write
Attract_anim_restore_buf = $FFFFFB00 ; cached cell record restored by Attract_anim_cell_update
Attract_anim_queue_buf = $FFFFF9F8 ; queued attract-animation cell update records
Tilemap_row_upload_queue = $FFFF91BC ; 7-slot queue of pending tilemap-row uploads consumed by Upload_tilemap_rows_to_vdp
Qualifying_time_table_buf = $FFFFFD90 ; 9-entry pre-race qualifying/ranking table (16 bytes per entry)

Save_checksum_nibble_0 = $FFFFFFBC ; lowest stored checksum nibble in save buffer
Save_checksum_nibble_1 = $FFFFFFBD
Save_checksum_nibble_2 = $FFFFFFBE
Save_checksum_nibble_3 = $FFFFFFBF ; highest stored checksum nibble in save buffer
Qualifying_temp_lap = $FFFFFF3C ; temporary qualifying/credits lap field
Qualifying_temp_flag_c = $FFFFFF3D
Qualifying_temp_flag_a = $FFFFFF3F ; temporary qualifying/credits state byte A
Qualifying_temp_grid_alt = $FFFFFF3E
Qualifying_temp_rival_time_alt = $FFFFFF40
Qualifying_temp_flag_d = $FFFFFF41
Qualifying_temp_value_a = $FFFFFF42
Qualifying_temp_flag_b = $FFFFFF45 ; temporary qualifying/credits state byte B
Qualifying_temp_flag_e = $FFFFFF47
Qualifying_temp_value_b = $FFFFFF48
Qualifying_temp_flag_f = $FFFFFF4B
Qualifying_temp_grid = $FFFFFF44 ; temporary qualifying/credits grid field
Qualifying_temp_rival_time = $FFFFFF46 ; temporary qualifying/credits rival-time field
Pending_save_load_flag = $FFFFFFB9 ; non-zero when name-entry should load player state from save buffer

Endgame_screen_copy_buf = $FFFF9F00 ; temporary sprite/tilemap copy buffer used by endgame screen assembly

Standings_presort_flags_a = $FFFF8F8F ; temporary presort flag array for championship standings
Standings_presort_flags_b = $FFFF8FAF ; temporary presort team index array for championship standings
Vdp_dma_fill_data = $FFFFFF0A ; data word written after Vdp_dma_setup during DMA fill helper
English_flag_b = $FFFFFF27 ; low byte alias of English_flag used by startup language detection
Vdp_tileset_commit_value = $FFFFFFF0 ; cached VDP tileset/plane setup value written at end of Race_loop_commit_tileset

; ============================================================
; Palette CRAM shadow buffer  ($FFFFE980)
; ============================================================
Palette_buffer = $FFFFE980 ; 64-entry (128-byte) CRAM shadow palette;
                             ;   written by HUD init and portrait init;
                             ;   DMA'd to VDP CRAM each VBlank
Digit_tilemap_buf = $FFFFE800 ; small tilemap scratch buffer used for speed/score/time digit rendering
Road_column_tile_buf = $FFFFE900 ; temporary 16-longword tile buffer uploaded by Flush_road_column_dma
Road_hscroll_buf = $FFFFF600 ; 224-line HScroll shadow buffer streamed to VDP each frame
Lap_end_tilemap_buf = $FFFFE88C ; lap-end/overtake tilemap buffer
Render_text_buffer_en = $FFFFF71E ; English text renderer destination buffer
Render_text_buffer_jp = $FFFFF74A ; Japanese text renderer destination buffer
Podium_name_buffer_jp = $FFFFF71C ; championship podium name buffer (Japanese layout)
Podium_name_buffer_en = $FFFFF78C ; championship podium name buffer (English layout)

; ============================================================
; Streaming decompression descriptor buffer  ($FFFFC080)
;
; Used by Load_streamed_decompression_descriptor / Start_streamed_decompression /
; Continue_streamed_decompression for multi-frame tile streaming.
;
; Layout (longwords, all .l unless noted):
;   +$00 .l  source ROM pointer (A0 current read position in compressed stream)
;   +$04 .w  tile base offset for VDP DMA (updated by +$80 per stripe)
;   +$40 .l  decode jump address (loc_A32 or loc_A32+$0A depending on bit 15)
;   +$44 .l  D0 saved state
;   +$48 .l  D1 saved state
;   +$4C .l  D2 saved state
;   +$50 .l  D5 saved state
;   +$54 .l  D6 saved state
;   +$58 .w  remaining rows to decompress (decrements each stripe)
;   +$5A .w  tiles-per-stripe step (reset to 4 each stripe)
; ============================================================
Decomp_stream_buf      = $FFFFC080 ; base of streaming decompression state buffer
Decomp_stream_src_ptr  = $FFFFC080 ; +$00 .l  current compressed-stream source pointer
Decomp_stream_tile_ofs = $FFFFC084 ; +$04 .w  current VDP tile base offset (+=  $80 per stripe)
Decomp_stream_jump_ptr = $FFFFC0C0 ; +$40 .l  decode routine jump target
Decomp_stream_d0       = $FFFFC0C4 ; +$44 .l  saved D0 (bit-buffer accumulator)
Decomp_stream_d1       = $FFFFC0C8 ; +$48 .l  saved D1
Decomp_stream_d2       = $FFFFC0CC ; +$4C .l  saved D2
Decomp_stream_d5       = $FFFFC0D0 ; +$50 .l  saved D5 (bit window)
Decomp_stream_d6       = $FFFFC0D4 ; +$54 .l  saved D6 (remaining bits)
Decomp_stream_rows     = $FFFFC0D8 ; +$58 .w  remaining decompression rows
Decomp_stream_step     = $FFFFC0DA ; +$5A .w  per-stripe tile step (reset to 4)

Dialogue_tilemap_buf   = $FFFFF6F0 ; text/message tilemap work buffer used by team/rival dialogue and message panels

; ============================================================
; Object depth-sort buffers  ($FFFF8F80, $FFFF8FA0)
; ============================================================
; Written at the start of every Update_objects_and_build_sprite_buffer call.
; Depth_sort_buf holds 16 × .w placement scores for all AI cars, used to
; sort race standings.  Score_scratch_buf holds the corresponding 2-digit
; BCD decimal values assembled for the standings minimap display.
Depth_sort_buf       = $FFFF8F80 ; 16 × .w   AI car placement scores (initialised to $FFFF)
Score_scratch_buf    = $FFFF8FA0 ; 16 × .w   packed BCD scores for standings display
Score_scratch_names  = $FFFF8F90 ; 16 × .b   driver index bytes for sorted standings rows
Score_scratch_pts    = $FFFF8FB0 ; per-team points accumulator for standings totals
Depth_sort_value     = $FFFF9288 ; .l  current depth-sort comparison value (best seen so far;
                                   ;     initialised to $FFFFFFFF each frame)
Depth_sort_prev      = $FFFF928A ; .w  previous depth-sort value (for next-best step)

; ============================================================
; Race timer BCD struct  ($FFFF92F8)
; ============================================================
; 4-byte struct updated every 20 frames (1 second real-time at 20fps tick):
;   +$00 .b  frame countdown (initialised to $14 = 20; decrements each Race_loop tick)
;   +$01 .b  BCD minutes tens
;   +$02 .b  BCD seconds (00–59)
;   +$03 .b  display-rate index (lookup into loc_7400 BCD sub-second table)
; Stored as a longword into Lap_time_ptr each tick.
Race_timer_bcd = $FFFF92F8 ; 4-byte BCD lap timer struct (see Update_race_timer)

; ============================================================
; AI car tracking pointers  ($FFFFFC90–$FFFFFCAA)
; ============================================================
; Set during placement-sort scan in Update_race_position each frame.
Best_ai_car_ptr    = $FFFFFCAA ; .w  pointer to AI car object with highest placement score
Second_ai_car_ptr  = $FFFFFC92 ; .w  pointer to AI car with second-highest placement score
Rival_ai_car_ptr   = $FFFFFC90 ; .w  pointer to the main rival car object used for
                                 ;     comparison during placement updates
Best_ai_place      = $FFFFFC96 ; .w  highest AI placement score seen this frame ($FFFF = init)
Best_ai_distance   = $FFFF9234 ; .w  track distance of the leading AI car (used for lead detection)

; ============================================================
; Race placement threshold  ($FFFFFC7A)
; ============================================================
Placement_next_threshold = $FFFFFC7A ; .w  next position boundary from placement-sequence table;
                                       ;     compared against Current_placement each frame

; ============================================================
; Race outcome / elimination flags
; ============================================================
Laps_done_flag      = $FFFFFC6E ; .w  set to 1 when the race lap count has been reached;
                                  ;     also set at Race_finish; blocks lap timer and triggers
                                  ;     result screens
Player_eliminated   = $FFFFFCAC ; .w  0 = in race; 1 = time/position eliminated;
                                  ;     $FFFF = player absent from standings (no championship entry)
Placement_award_pending = $FFFFFC8C ; .w  set to 1 when placement changed and points must be awarded;
                                      ;     cleared after Award_race_position_points is called
Race_timer_freeze   = $FFFFFCB6 ; .w  non-zero while race timer is frozen (e.g. result screen);
                                  ;     $FFFF = freeze; 0 = running; set by Race_result_overlay_frame
Race_timer_phase    = $FFFFFCB8 ; .w  0..2 sub-phase counter for freeze/resume cycle in result screen

; ============================================================
; AI overtake mechanics  ($FFFFFCBA, $FFFFFCB4, $FFFFFC9A–$FFFFFC9E)
; ============================================================
Ai_x_delta        = $FFFFFCBA ; .w  AI car horizontal position delta for current overtake step
Ai_speed_delta    = $FFFFFCB4 ; .w  AI speed contribution applied to player_speed during overtake
Ai_overtake_ready = $FFFFFC98 ; .w  set to 1 when AI overtake step has been computed
Ai_speed_override = $FFFFFC9A ; .w  if non-zero, overrides Player_speed_raw with this value
                                ;     (set from Ai_speed_delta during overtake; cleared after apply)
Ai_side_flag      = $FFFFFC9C ; .b  SGT result: 1 if AI is to the right of player, 0 if left
Pit_prompt_flag   = $FFFFFC9E ; .w  set to 1 when pit-entry prompt should be shown;
                                ;     cleared each frame by Update_pit_prompt

; ============================================================
; Digit rendering scratch buffer  ($FFFFFCB0)
; ============================================================
Digit_scratch_buf  = $FFFFFCB0 ; 8-byte scratch buffer used by Render_packed_digits_to_vdp;
                                  ;   holds binary-to-decimal nibble output for up to 4 digits

; ============================================================
; AI active / collision state  ($FFFFFCBC, $FFFFFCDE)
; ============================================================
Ai_active_flag  = $FFFFFCBC ; .w  non-zero while AI collision/placement update is in progress
Collision_palette_buf = $FFFFFCDE ; pointer used by Write_3_palette_vdp_bytes during
                                    ;   collision-flash palette swap (6-byte palette data address)

; ============================================================
; Tire wear / braking performance  ($FFFF9010–$FFFF902C, $FFFF9150–$FFFF9172)
; ============================================================
; Durability cap values (used by result-screen binary→decimal display)
Tire_stat_max_base      = $FFFF9010 ; .w  max cap for race stat 0 (accel bar cap)
Tire_stat_max_1         = $FFFF9012 ; .w  max cap for race stat 1
Tire_stat_max_2         = $FFFF9014 ; .w  max cap for race stat 2
Tire_stat_max_3         = $FFFF9016 ; .w  max cap for race stat 3
Tire_stat_max_4         = $FFFF9018 ; .w  max cap for race stat 4
; Durability accumulators (decremented each relevant event; shown on result screen)
Tire_steering_durability_acc  = $FFFF901A ; .w  steering durability accumulator (shown as steering bar)
Tire_braking_durability_acc   = $FFFF901C ; .w  braking durability accumulator
Tire_accel_durability_acc     = $FFFF901E ; .w  accel/acceleration durability accumulator
Tire_braking_zone_acc         = $FFFF9020 ; .w  braking-zone durability channel (player-brake-triggered)
Tire_engine_durability_acc    = $FFFF9022 ; .w  engine durability accumulator
; Per-tick delta values for stat accumulation
Tire_stat_delta_base    = $FFFF9024 ; .w  per-tick delta for stat 0
; (stats 1–4 follow at +2, +4, +6, +8)
; Wear rates (set from team/car data at race start)
Tire_wear_degrade_level = $FFFF9150 ; .w  tire wear degradation level written on degrade event:
                                     ;     1 = steering degraded; 2 = engine/accel degraded
Tire_accel_wear_rate    = $FFFF9152 ; .w  accel wear rate (team car data × multiplier)
Tire_engine_wear_rate   = $FFFF9154 ; .w  engine wear rate
Tire_steering_wear_rate = $FFFF9156 ; .w  steering wear rate
Tire_braking_wear_rate  = $FFFF9158 ; .w  braking wear rate (4× base)
Tire_braking_wear_rate_full = $FFFF915A ; .w  full braking wear rate (used in braking zone)
; Durability counters (decremented by wear rates; trigger degrade event on underflow)
Tire_accel_durability   = $FFFF9166 ; .w  accel durability counter
Tire_engine_durability  = $FFFF9168 ; .w  engine durability counter
Tire_steering_durability = $FFFF916A ; .w  steering durability counter
Tire_braking_durability_b = $FFFF916C ; .w  braking durability counter B (road-marker collision)
Tire_braking_durability_a = $FFFF916E ; .w  braking durability counter A (player-brake triggered)
; Braking event timers
Tire_collision_brake_timer  = $FFFF9170 ; .w  collision braking event countdown (init $00F0)
Tire_road_marker_brake_timer = $FFFF9172 ; .w  road-marker braking event countdown (init $0028)
