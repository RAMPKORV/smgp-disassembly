Race_loop:
	JSR	Wait_for_practice_vblank_cycle(PC)
	CLR.w	Tilemap_queue_count.w
	MOVE.l	#Tilemap_draw_queue, Tilemap_queue_ptr.w
	TST.w	Race_finish_flag.w
	BNE.b	Race_loop_Wait_vblank
	JSR	Handle_pause(PC)
	TST.w	Pause_flag.w
	BEQ.b	Race_loop_Active
	RTS
Race_loop_Active:
	JSR	Update_road_tile_scroll(PC)
	JSR	Update_background_scroll_delta(PC)
	TST.w	Retire_flag.w
	BEQ.b	Race_loop_Update_driving
	CLR.w	Player_shift.w
	CLR.l	Player_rpm.w
	CLR.l	Player_speed_raw.w
	BRA.b	Race_loop_Render
Race_loop_Update_driving:
	JSR	Update_shift(PC)
	JSR	Update_rpm(PC)
	JSR	Update_breaking(PC)
	JSR	Update_engine_sound_pitch(PC)
	JSR	Update_speed(PC)
Race_loop_Render:
	JSR	Render_speed(PC)
	JSR	Advance_lap_checkpoint(PC)
	JSR	Render_placement_display(PC)
	JSR	Update_steering(PC) ; Commenting out disables left/right movement
	JSR	Update_horizontal_position(PC) ; Commenting out disables left/right movement (but visually wheels still turn)
	JSR	Advance_player_distance(PC) ; Commenting out disables visual forward movement (also map) but physically still moves as collisions eventually occur
	JSR	Update_slope_data(PC)
	JSR	Update_race_timer(PC)
	JSR	Update_race_position(PC)
	JSR	Update_gap_to_rival_display(PC)
	JSR	Update_rival_sprite_tiles(PC)
	JSR	Parse_tileset_for_signs(PC) ; Commenting out makes signs have the wrong textures
	JSR	Parse_sign_data(PC) ; Commenting out makes signs and obstacles disappear (physical and visual)
	JSR	Update_pit_prompt(PC)
	JSR	Update_braking_performance(PC)
	JSR	Apply_sorted_positions_to_cars(PC)
Race_loop_Wait_vblank:
	CMPI.w	#4, Practice_vblank_step.w
	BLT.b	Race_loop_Wait_vblank
	JSR	Update_objects_and_build_sprite_buffer(PC) ; Commenting out makes graphics freeze
	JSR	Update_engine_and_tire_sounds(PC) ; Commenting out removes sound
	JSR	Update_road_graphics(PC) ; Commenting out makes road graphics not updates (but signs still move)
	RTS
;$0000375E
; Championship_race_init — initialise a championship-mode race.
; Fades to black, inits H32 VDP with raster-split registers ($8238/$8B03/$9011/$9280).
; Calls Reset_race_state (zeroes all race RAM), Load_track_data, Initialize_race_objects,
; Initialize_road_graphics_state.  Renders one full frame (road + sprites + HUD) to
; pre-populate VRAM, decompresses the HUD asset list, draws lap number and target times.
; Re-enables VBlank, installs Race_loop as Frame_callback and
; Practice_mode_vblank_handler as Vblank_callback.
Championship_race_init:
	JSR	Fade_palette_to_black(PC)
	JSR	Initialize_h32_vdp_state(PC)
	MOVE.w	#$8238, VDP_control_port
	MOVE.w	#$8B03, VDP_control_port
	MOVE.w	#$9011, VDP_control_port
	MOVE.w	#$9280, VDP_control_port
	JSR	Reset_race_state(PC)
	JSR	Load_track_data(PC)
	JSR	Initialize_race_objects(PC)
	JSR	Initialize_road_graphics_state(PC)
	JSR	Advance_player_distance(PC)
	JSR	Update_slope_data(PC)
	JSR	Update_road_graphics(PC)
	JSR	Update_objects_and_build_sprite_buffer(PC)
	LEA	Race_hud_asset_list(PC), A1
	JSR	Decompress_asset_list_to_vdp(PC)
	JSR	Initialize_race_hud(PC)
	JSR	Draw_lap_number_and_times(PC)
	MOVE.l	#Race_loop, Frame_callback.w
	MOVE.l	#Practice_mode_vblank_handler, Vblank_callback.w
	JSR	Halt_audio_sequence
	ANDI	#$F8FF, SR
	JSR	Wait_for_vblank(PC)
	JSR	Wait_for_vblank(PC)
	CLR.w	Practice_vblank_step.w
	MOVE.w	#1, Vblank_enable.w
	MOVE.w	#$8014, VDP_control_port
	MOVE.w	#$8A00, VDP_control_port
	JSR	Wait_for_practice_vblank_cycle(PC)
	MOVE.w	#$8174, VDP_control_port
	RTS
;$00003800
; Arcade_race_init — initialise an arcade-mode race (also used for free-practice races).
; Near-identical to Championship_race_init but calls Init_race_player_state instead of
; Reset_race_state (preserves existing championship state).  Conditionally plays
; Music_race ($10) if Track_index_arcade_mode != 0 (skips music for warmup/demo path).
; Arms Race_loop + Practice_mode_vblank_handler.
Arcade_race_init:
	JSR	Fade_palette_to_black(PC)
	JSR	Initialize_h32_vdp_state(PC)
	MOVE.w	#$8238, VDP_control_port
	MOVE.w	#$8B03, VDP_control_port
	MOVE.w	#$9011, VDP_control_port
	MOVE.w	#$9280, VDP_control_port
	JSR	Init_race_player_state(PC)
	JSR	Load_track_data(PC)
	JSR	Init_race_object_pool(PC)
	JSR	Initialize_road_graphics_state(PC)
	JSR	Advance_player_distance(PC)
	JSR	Update_slope_data(PC)
	JSR	Update_road_graphics(PC)
	JSR	Update_objects_and_build_sprite_buffer(PC)
	JSR	Load_race_hud_graphics(PC)
	JSR	Initialize_race_hud(PC)
	TST.w	Track_index_arcade_mode.w
	BEQ.b	Arcade_race_init_No_music
	MOVE.w	#$0010, Options_cursor_update.w
Arcade_race_init_No_music:
	MOVE.l	#Race_loop, Frame_callback.w
	MOVE.l	#Practice_mode_vblank_handler, Vblank_callback.w
	JSR	Halt_audio_sequence
	ANDI	#$F8FF, SR
	JSR	Wait_for_vblank(PC)
	JSR	Wait_for_vblank(PC)
	MOVE.w	Options_cursor_update.w, Audio_music_cmd ; song = $10 (race music on) or 0 (silent)
	CLR.w	Practice_vblank_step.w
	MOVE.w	#1, Vblank_enable.w
	MOVE.w	#$8014, VDP_control_port
	MOVE.w	#$8A00, VDP_control_port
	JSR	Wait_for_practice_vblank_cycle(PC)
	MOVE.w	#$8174, VDP_control_port
	RTS
;Init_race_object_pool
Init_race_object_pool:
	JSR	Clear_main_object_pool(PC)
	MOVE.l	#$00000F44, (Player_obj+$100).w
	MOVE.l	#$00000F66, (Player_obj+$C0).w
	MOVE.l	#$00007D7A, (Player_obj+$40).w
	MOVE.l	#$00007DAC, (Player_obj+$80).w
	MOVE.l	#$0000A6E2, Flagkeeper_obj_ptr.w
	LEA	(Main_object_pool+$6C0).w, A0
	MOVEQ	#$0000000F, D1
Init_race_object_pool_Obj_loop:
	MOVE.l	#Rival_crowd_car_obj_init, (A0)
	LEA	$40(A0), A0
	DBF	D1, Init_race_object_pool_Obj_loop
	MOVE.l	#$00007AAE, Player_obj.w
	MOVE.w	Warm_up.w, D0
	OR.w	Practice_mode.w, D0
	BNE.b	Init_race_object_pool_Warmup
	TST.w	Track_index_arcade_mode.w
	BNE.b	Init_race_object_pool_Arcade
	MOVE.w	#$0050, D0
	MOVE.w	D0, Horizontal_position.w
	NEG.w	D0
	MOVE.w	D0, Player_x_negated.w
	LEA	Ai_car_array.w, A0
	MOVE.l	#Init_ai_car_hidden, (A0)
	MOVE.w	D0, $12(A0)
	MOVE.w	Track_length.w, D0
	SUBI.w	#$0024, D0
	MOVE.w	D0, $1A(A0)
	MOVE.w	#$013C, D0
	MOVE.w	D0, $30(A0)
	LSL.w	#7, D0
	MOVE.w	D0, $32(A0)
	MOVE.w	#$00C8, $34(A0)
	MOVE.b	#$FC, $2B(A0)
Init_race_object_pool_Warmup:
	MOVE.l	#Gear_diagram_obj_init, (Player_obj+$140).w
	MOVE.w	Track_length.w, D0
	SUBQ.w	#6, D0
	MOVE.w	D0, Player_distance.w
	RTS
Init_race_object_pool_Arcade:
	TST.w	Use_world_championship_tracks.w
	BNE.w	Init_ai_placement_Champ
	CLR.b	Player_team.w
	MOVE.l	#$00008C9E, D2
	MOVE.w	#$0068, D0
	LEA	Ai_placement_data(PC), A1
	TST.w	Practice_flag.w
	BEQ.b	Init_ai_placement_loop
	TST.w	Easy_flag.w
	BEQ.b	Init_ai_placement_loop
	LEA	Ai_placement_data_easy(PC), A1
Init_ai_placement_loop:
	MOVEQ	#0, D6
	LEA	Ai_car_array.w, A0
	MOVE.w	Track_length.w, D1
	SUBQ.w	#6, D1
	MOVEQ	#0, D3
	MOVE.w	Current_lap.w, D4
Init_ai_placement_loop_Body:
	MOVE.b	Player_team.w, D7
	ANDI.w	#$000F, D7
	CMP.w	D6, D7
	BNE.b	Init_ai_placement_loop_Skip_player
	ADDQ.w	#5, A1
	ADDQ.w	#4, A6
Init_ai_placement_loop_Skip_player:
	CMP.w	D4, D3
	BNE.b	Init_ai_placement_loop_Write
	MOVE.w	D0, Temp_x_pos.w
	MOVE.w	D1, Temp_distance.w
	BRA.b	Init_ai_placement_Next
Init_ai_placement_loop_Write:
	MOVE.l	D2, (A0)
	MOVE.w	D1, $1A(A0)
	MOVE.w	D0, $12(A0)
	MOVE.b	(A1)+, D7
	LSL.w	#8, D7
	MOVE.b	(A1)+, D7
	TST.w	Shift_type.w
	BEQ.b	Init_ai_placement_Champ_bonus
	ADDI.w	#$0016, D7
	CMPI.w	#1, Shift_type.w
	BEQ.b	Init_ai_placement_Champ_bonus
	ADDI.w	#$0044, D7
Init_ai_placement_Champ_bonus:
	TST.w	Use_world_championship_tracks.w
	BEQ.b	Init_ai_placement_Champ_offset
	ADD.w	(A6)+, D7
Init_ai_placement_Champ_offset:
	MOVE.w	D7, $30(A0)
	LSL.w	#7, D7
	MOVE.w	D7, $32(A0)
	MOVE.b	(A1)+, D7
	LSL.w	#8, D7
	MOVE.b	(A1)+, D7
	CMPI.w	#2, Track_index_arcade_mode.w
	BNE.b	Init_ai_placement_Accel_cap
	SUBI.w	#$000F, D7
Init_ai_placement_Accel_cap:
	TST.w	Use_world_championship_tracks.w
	BEQ.b	Init_ai_placement_Track3_adj
	ADD.w	(A6)+, D7
	CMPI.w	#3, Track_index.w
	BNE.b	Init_ai_placement_Track3_adj
	SUBQ.w	#6, D7
Init_ai_placement_Track3_adj:
	MOVE.w	D7, $34(A0)
	MOVE.b	(A1)+, $2B(A0)
	LEA	$40(A0), A0
Init_ai_placement_Next:
	SUBI.w	#$000C, D1
	NEG.w	D0
	ADDQ.w	#1, D6
	ADDQ.w	#1, D3
	CMPI.w	#$0010, D3
	BNE.w	Init_ai_placement_loop_Body
	MOVE.w	Temp_x_pos.w, Horizontal_position.w
	MOVE.w	Temp_distance.w, Player_distance.w
	NEG.w	Temp_x_pos.w
	MOVE.w	Temp_x_pos.w, Player_x_negated.w
	TST.w	Use_world_championship_tracks.w
	BNE.b	Init_ai_placement_Rts
	MOVE.w	(Ai_car_array+$30).w, D0
	ADDI.w	#$000F, D0
	MOVE.w	D0, Player_start_grid_arcade.w
	MOVE.w	(Ai_car_array+$34).w, D0
	ADDI.w	#$000F, D0
	MOVE.w	D0, Rival_start_grid_arcade.w
	MOVE.l	#$00008B7A, (Ai_car_array+$380).w
	MOVE.w	#2, (Ai_car_array+$26).w
	MOVE.w	#1, (Ai_car_array+$66).w
	MOVE.w	#1, (Ai_car_array+$126).w
Init_ai_placement_Rts:
	RTS
Init_ai_placement_Champ:
	MOVE.b	Player_team.w, D0
	ANDI.w	#$000F, D0
	LSR.w	#2, D0
	NEG.w	D0
	LSL.w	#4, D0
	LEA	Ai_placement_champ_offsets(PC), A6
	ADDA.w	D0, A6
	LEA	Ai_placement_data_champ(PC), A1
	TST.w	Has_rival_flag.w
	BNE.b	Init_ai_placement_Rival_loop
	MOVE.l	#$00008C74, D2
	MOVE.w	#$0078, D0
	BRA.w	Init_ai_placement_loop
Init_ai_placement_Rival_loop:
	MOVEQ	#0, D6
	LEA	(Ai_car_array+$40).w, A0
	MOVE.w	#$0078, D0
	MOVE.w	Track_length.w, D1
	SUBQ.w	#6, D1
	MOVEQ	#0, D3
	MOVE.w	Rival_grid_position.w, D2
	MOVE.w	Current_lap.w, D4
Init_ai_placement_Rival_loop_Body:
	MOVE.b	Player_team.w, D7
	ANDI.w	#$000F, D7
	CMP.w	D7, D6
	BNE.b	Init_ai_placement_Rival_Skip_player
	ADDQ.w	#5, A1
	ADDQ.w	#4, A6
Init_ai_placement_Rival_Skip_player:
	MOVE.b	Rival_team.w, D7
	ANDI.w	#$000F, D7
	CMP.w	D7, D6
	BNE.b	Init_ai_placement_Rival_Skip_rival
	ADDQ.w	#5, A1
	ADDQ.w	#4, A6
Init_ai_placement_Rival_Skip_rival:
	CMP.w	D2, D3
	BNE.b	Init_ai_placement_Rival_player_slot
	MOVE.w	D0, Screen_data_ptr.w
	MOVE.w	D1, Menu_cursor.w
	BRA.b	Init_ai_placement_Rival_Next
Init_ai_placement_Rival_player_slot:
	CMP.w	D4, D3
	BNE.b	Init_ai_placement_Rival_Write
	MOVE.w	D0, Temp_x_pos.w
	MOVE.w	D1, Temp_distance.w
	BRA.b	Init_ai_placement_Rival_Next
Init_ai_placement_Rival_Write:
	MOVE.l	#Init_rival_car_intro, (A0)
	MOVE.w	D1, $1A(A0)
	MOVE.w	D0, $12(A0)
	MOVE.b	(A1)+, D7
	LSL.w	#8, D7
	MOVE.b	(A1)+, D7
	TST.w	Shift_type.w
	BEQ.b	Init_ai_placement_Rival_Champ_bonus
	ADDI.w	#$0016, D7
	CMPI.w	#1, Shift_type.w
	BEQ.b	Init_ai_placement_Rival_Champ_bonus
	ADDI.w	#$0044, D7
Init_ai_placement_Rival_Champ_bonus:
	ADD.w	(A6)+, D7
	MOVE.w	D7, $30(A0)
	LSL.w	#7, D7
	MOVE.w	D7, $32(A0)
	MOVE.b	(A1)+, D7
	LSL.w	#8, D7
	MOVE.b	(A1)+, D7
	ADD.w	(A6)+, D7
	CMPI.w	#3, Track_index.w
	BNE.b	Init_ai_placement_Rival_Track3_adj
	SUBQ.w	#6, D7
Init_ai_placement_Rival_Track3_adj:
	MOVE.w	D7, $34(A0)
	MOVE.b	(A1)+, $2B(A0)
	LEA	$40(A0), A0
Init_ai_placement_Rival_Next:
	SUBI.w	#$000C, D1
	NEG.w	D0
	ADDQ.w	#1, D6
	ADDQ.w	#1, D3
	CMPI.w	#$0010, D3
	BNE.w	Init_ai_placement_Rival_loop_Body
	LEA	Ai_car_array.w, A0
	MOVE.l	#Init_rival_ai_car, (A0)
	MOVE.w	Screen_data_ptr.w, $12(A0)
	MOVE.w	Menu_cursor.w, $1A(A0)
	MOVE.w	Temp_x_pos.w, Horizontal_position.w
	MOVE.w	Temp_distance.w, Player_distance.w
	NEG.w	Temp_x_pos.w
	MOVE.w	Temp_x_pos.w, Player_x_negated.w
	RTS
Initialize_race_objects:
	JSR	Clear_partial_main_object_pool(PC)
	JSR	Clear_aux_object_pool(PC)
	LEA	(Main_object_pool+$6C0).w, A0
	MOVEQ	#$0000000F, D0
Initialize_race_objects_Loop:
	CLR.w	$C(A0)
	CLR.w	$2C(A0)
	CLR.w	$2E(A0)
	LEA	$40(A0), A0
	DBF	D0, Initialize_race_objects_Loop
	MOVE.l	#$00000F44, (Player_obj+$100).w
	MOVE.l	#$00000F66, (Player_obj+$C0).w
	MOVE.l	#$00007D7A, (Player_obj+$40).w
	MOVE.l	#$00007DAC, (Player_obj+$80).w
	MOVE.l	#$00007A3E, Player_obj.w
	MOVE.w	#$0180, D0
	MOVE.w	D0, Horizontal_position.w
	NEG.w	D0
	MOVE.w	D0, Player_x_negated.w
	MOVE.w	#$00B4, D1
	MOVE.w	Total_distance.w, D0
	ADD.w	D1, D0
	MOVE.w	D1, Player_distance.w
	MOVE.w	D0, Player_place_score.w
	RTS
Load_default_control_type_handler:
	MOVE.w	Control_type.w, D0
Load_control_type_handler:
	LSL.w	#2, D0
	LEA	Control_types, A2
	MOVE.l	(A2,D0.w), Control_handler_ptr.w
	RTS
;Init_race_player_state
Init_race_player_state:
	BSR.b	Load_default_control_type_handler
	CMPI.w	#2, Track_index.w
	BCS.b	Init_race_player_state_State_clear
	BCLR.b	#3, Player_state_flags.w
Init_race_player_state_State_clear:
	LEA	Player_shift.w, A0
	MOVEQ	#$0000001F, D0
	JSR	Clear_word_range(PC)
	LEA	Tileset_dirty_flag.w, A0
	MOVEQ	#$0000007F, D0
	JSR	Clear_word_range(PC)
	CLR.w	Total_distance.w
	CLR.w	Checkpoint_index.w
	MOVE.l	#Tilemap_draw_queue, Tilemap_queue_ptr.w
	MOVE.b	#$80, Road_x_offset.w
	MOVE.w	#802, Visual_rpm.w
	MOVE.b	#$14, Race_timer_bcd.w
	MOVE.w	#$E12C, D7
	TST.w	Use_world_championship_tracks.w
	BEQ.b	Init_race_player_state_Lap_vdp
	MOVE.w	#$E0AC, D7
Init_race_player_state_Lap_vdp:
	MOVE.w	D7, Best_lap_vdp_step.w
	CLR.w	Race_started.w
	JSR	Load_team_machine_stats
	TST.w	Track_index_arcade_mode.w
	BNE.b	Init_race_player_state_Arcade
	CLR.w	Current_lap.w
	CLR.w	Race_time_bcd.w
	MOVE.b	#$80, Qualifying_temp_flag_a.w
	MOVE.b	#$80, Qualifying_temp_flag_b.w
	RTS
Init_race_player_state_Arcade:
	CLR.w	Has_rival_flag.w
	TST.w	Use_world_championship_tracks.w
	BNE.b	Init_race_player_state_Champ
	CMPI.w	#2, Track_index_arcade_mode.w
	BEQ.b	Init_race_player_state_Track2
	MOVE.w	Current_lap.w, Player_grid_position.w
	BRA.b	Init_race_player_state_Grid
Init_race_player_state_Track2:
	ADDQ.w	#5, Player_grid_position.w
	MOVE.w	Player_grid_position.w, Current_lap.w
Init_race_player_state_Grid:
	MOVE.l	#$00010001, Placement_anim_state.w
	RTS
Init_race_player_state_Champ:
	MOVE.w	Current_lap.w, Player_grid_position.w
	MOVE.b	Player_team.w, D0
	ANDI.w	#$0030, D0
	BEQ.b	Init_race_player_state_Rts
	MOVE.w	#1, Has_rival_flag.w
	MOVEQ	#0, D7
	MOVE.b	Rival_team.w, D0
	ANDI.w	#$000F, D0
	LEA	Rival_grid_base_table, A0
	MOVE.b	(A0,D0.w), D7
	LEA	Drivers_and_teams_map.w, A0
	MOVE.b	(A0,D0.w), D0
	ANDI.w	#$000F, D0
	BTST.b	#6, Player_team.w
	BEQ.b	Init_race_player_state_Rival_home
	SUBQ.w	#1, D0
Init_race_player_state_Rival_home:
	LEA	Rival_grid_delta_table, A0
	ADD.b	(A0,D0.w), D7
	BPL.b	Init_race_player_state_Rival_grid
	MOVEQ	#0, D7
Init_race_player_state_Rival_grid:
	CMP.w	Player_grid_position.w, D7
	BNE.b	Init_race_player_state_Rival_store
	TST.w	Player_grid_position.w
	BEQ.b	Init_race_player_state_Rival_grid_zero
	SUBQ.w	#1, D7
	BRA.b	Init_race_player_state_Rival_store
Init_race_player_state_Rival_grid_zero:
	MOVEQ	#1, D7
Init_race_player_state_Rival_store:
	MOVE.w	D7, Rival_grid_position.w
Init_race_player_state_Rts:
	RTS
;Clear_word_range
Clear_word_range: ; Copy D0 zeros to A0 upwards
	MOVEQ	#0, D1
Clear_word_range_Loop:
	MOVE.w	D1, (A0)+
	DBF	D0, Clear_word_range_Loop
	RTS
Reset_race_state:
	LEA	Player_shift.w, A0
	MOVEQ	#$0000001F, D0
	JSR	Clear_word_range(PC)
	MOVE.l	Laps_completed.w, D7
	LEA	Tileset_dirty_flag.w, A0
	MOVEQ	#$00000067, D0
	JSR	Clear_word_range(PC)
	MOVE.l	D7, Laps_completed.w
	MOVE.w	#1, Background_zone_prev.w
	MOVE.l	#$FFFFFFFF, Aux_object_counter.w
	JSR	Load_team_machine_stats
	MOVE.l	#Tilemap_draw_queue, Tilemap_queue_ptr.w
	MOVE.b	#$80, Road_x_offset.w
	MOVE.w	#1100, Player_rpm.w
	MOVE.w	#1100, Visual_rpm.w
	MOVE.w	#1, Crash_spin_flag.w
	RTS
;$00003D84
; Championship_warmup_race_frame — per-frame handler for the attract-demo race and
; free-practice/warm-up laps.  Calls Race_loop each frame (full physics + graphics),
; then decrements Race_frame_counter.  When the counter reaches zero, installs
; Driver_standings_init ($CCE0) as Frame_callback, completing one attract cycle.
Championship_warmup_race_frame:
	JSR	Race_loop(PC)
	SUBQ.w	#1, Race_frame_counter.w
	BNE.b	Championship_warmup_race_frame_Rts
	MOVE.l	#$0000CCE0, Frame_callback.w
Championship_warmup_race_frame_Rts:
	RTS
;Practice_mode_init
; Practice_mode_init — initialise a free-practice / warm-up / attract-demo lap.
; Fades to black, inits H32 VDP, calls Init_race_player_state and Load_track_data.
; Sets Race_time_bcd=$0012, loads Replay_input_ptr with recorded attract-demo input data,
; and arms Race_frame_counter=$01F4 (500 frames ≈ 8 s).
; Installs Championship_warmup_race_frame as Frame_callback (no race music).
Practice_mode_init:
	JSR	Fade_palette_to_black(PC)
	JSR	Initialize_h32_vdp_state(PC)
	JSR	Init_race_player_state(PC)
	MOVEQ	#0, D0
	JSR	Load_control_type_handler(PC)
	MOVE.w	#$0012, Race_time_bcd.w
	JSR	Load_track_data(PC)
	JSR	Init_race_object_pool(PC)
	JSR	Initialize_road_graphics_state(PC)
	JSR	Advance_player_distance(PC)
	JSR	Update_slope_data(PC)
	JSR	Update_road_graphics(PC)
	JSR	Update_objects_and_build_sprite_buffer(PC)
	JSR	Load_race_hud_graphics(PC)
	JSR	Initialize_race_hud(PC)
	MOVE.l	#$00001006, Aux_object_pool.w
	MOVE.w	#$01F4, Race_frame_counter.w
	MOVE.l	#$00073E08, Replay_input_ptr.w
	MOVE.l	#Championship_warmup_race_frame, Frame_callback.w
	MOVE.l	#Practice_mode_vblank_handler, Vblank_callback.w
	ANDI	#$F8FF, SR
	JSR	Wait_for_vblank(PC)
	CLR.w	Practice_vblank_step.w
	MOVE.w	#1, Vblank_enable.w
	MOVE.w	#$8014, VDP_control_port
	MOVE.w	#$8A00, VDP_control_port
	JSR	Wait_for_practice_vblank_cycle(PC)
	MOVE.w	#$8174, VDP_control_port
	RTS
Practice_mode_vblank_handler:
	MOVE.l	#$40020010, VDP_control_port
	MOVE.w	#0, VDP_data_port
	MOVE.w	Practice_vblank_step.w, D0 ; Values are 0, 4, 8 cycling. After running with 0, HUD updates. After 4, car moves. After 8, no visual update
	ADDQ.w	#4, D0
	CMPI.w	#$0014, D0
	BCS.b	Practice_vblank_Step_wrap
	MOVEQ	#$00000010, D0
Practice_vblank_Step_wrap:
	MOVE.w	D0, Practice_vblank_step.w
Practice_vblank_Dispatch:
	JMP	Practice_vblank_Dispatch(PC,D0.w)
	BRA.w	Practice_vblank_Step0
	BRA.w	Practice_vblank_Step1
	BRA.w	Practice_vblank_Step2
	BRA.w	Race_loop_commit_tileset
Practice_vblank_Step0:
	TST.w	Tileset_dirty_flag.w
	BEQ.b	Practice_vblank_Step0_Tileset_done
	EORI.w	#$01C0, Tileset_base_offset.w
	CLR.w	Tileset_dirty_flag.w
Practice_vblank_Step0_Tileset_done:
	MOVE.w	#$977F, D7
	MOVE.l	#$96D09560, D6
	MOVE.l	#$940093E0, D5
	MOVE.l	#$68020083, Vdp_dma_setup.w
	MOVE.w	#$8F04, VDP_control_port
	JSR	Send_D567_to_VDP(PC)
	MOVE.w	#$8F02, VDP_control_port
	JSR	Upload_h32_tilemap_buffer_to_vram(PC)
	JSR	Upload_palette_buffer_to_cram_delayed(PC)
	JSR	Flush_pending_dma_transfers(PC)
	JSR	Flush_vdp_mode_and_signs(PC)
	BRA.b	Race_loop_commit_tileset
Practice_vblank_Step1:
	JSR	Flush_road_column_dma(PC)
	JSR	Upload_tilemap_rows_to_vdp(PC)
	JSR	Send_sign_tileset_to_VDP(PC)
	BRA.b	Race_loop_commit_tileset
Practice_vblank_Step2:
	JSR	Update_input_bitset(PC) ; Update_input_bitset called from multiple locations, from here during practice mode
	JSR	Replay_input_update(PC)
	JSR	Update_car_palette_dma(PC)
	JSR	Flush_tilemap_draw_queue(PC)
Race_loop_commit_tileset:
	MOVE.w	#$9D42, D0
	ADD.w	Tileset_base_offset.w, D0
	MOVE.w	D0, Vdp_tileset_commit_value.w
	MOVE.w	#$8A00, VDP_control_port
	RTS
Replay_input_update:
	TST.w	Practice_flag.w
	BNE.b	Replay_input_update_Rts
	LEA	Input_state_bitset.w, A0
	MOVE.b	$1(A0), D7
	ANDI.b	#$80, D7
	MOVEA.l	Replay_input_ptr.w, A1
	MOVE.b	(A1)+, D1
	MOVE.b	(A1), D0
	MOVE.b	D0, (A0)+
	EOR.b	D0, D1
	AND.b	D1, D0
	OR.b	D7, D0
	MOVE.b	D0, (A0)
	MOVE.l	A1, Replay_input_ptr.w
Replay_input_update_Rts:
	RTS
Handle_pause:
	BTST.b	#KEY_START, Input_click_bitset.w
	BEQ.b	Handle_pause_Toggle_check
	NOT.w	Pause_flag.w
	TST.w	Practice_flag.w
	BNE.b	Handle_pause_Toggle_check
	MOVE.w	#9, Selection_count.w
	MOVE.l	#Title_menu, Frame_callback.w
	RTS
Handle_pause_Toggle_check:
	MOVE.w	Pause_prev_state.w, D1
	MOVE.w	Pause_flag.w, D0
	MOVE.w	D0, Pause_prev_state.w
	BNE.b	Handle_pause_Pause
	TST.w	D1
	BNE.b	Handle_pause_Unpause
	RTS
Handle_pause_Unpause:
	JSR	Trigger_music_playback
	CLR.l	Music_beat_counter.w
	LEA	$00FF5980, A6
	LEA	(A6), A4
	MOVE.w	Warm_up.w, D0
	OR.w	Practice_mode.w, D0
	BEQ.b	Handle_pause_Road_tilemap
	BRA.b	Handle_pause_Tilemap
Handle_pause_Pause:
	TST.w	D1
	BNE.b	Handle_pause_Beat
	JSR	Trigger_music_mode_1
Handle_pause_Beat:
	SUBQ.w	#1, Music_beat_counter.w
	BPL.b	Handle_pause_Music
	MOVE.w	#8, Music_beat_counter.w
	NOT.w	Music_beat_flip.w
Handle_pause_Music:
	LEA	$00FF5980, A6
	LEA	(A6), A4
	TST.w	Music_beat_flip.w
	BEQ.b	Handle_pause_Practice_check
	LEA	Pause_tilemap_a(PC), A6
Handle_pause_Practice_check:
	MOVE.w	Warm_up.w, D0
	OR.w	Practice_mode.w, D0
	BEQ.b	Handle_pause_Road_tilemap
	LEA	(A6), A4
	LEA	Pause_tilemap_b(PC), A6
	MOVE.l	#$00005690, D0
	TST.w	Practice_mode.w
	BNE.b	Handle_pause_Quit_check
	MOVE.l	#Title_menu, D0
Handle_pause_Quit_check:
	MOVE.b	Input_state_bitset.w, D1
	ANDI.w	#$0070, D1 ; Keys A+B+C pressed
	CMPI.w	#$0070, D1
	BNE.b	Handle_pause_Tilemap
	MOVE.l	D0, Frame_callback.w
Handle_pause_Tilemap:
	MOVE.l	#$66060003, D7
	MOVEQ	#$00000019, D6
	MOVEQ	#0, D5
	JSR	Queue_tilemap_draw(PC)
	LEA	(A4), A6
Handle_pause_Road_tilemap:
	MOVE.l	#$64980003, D7
	MOVEQ	#8, D6
	MOVEQ	#0, D5
	JMP	Queue_tilemap_draw(PC)
Update_braking_performance:
	MOVEQ	#0, D7
	TST.w	Use_world_championship_tracks.w
	BEQ.b	Handle_pause_Done
	TST.w	Track_index_arcade_mode.w
	BEQ.b	Handle_pause_Done
	MOVE.b	Control_key_brake.w, D0
	BTST.b	D0, Input_click_bitset.w ; if brake key NOT clicked
	BEQ.b	Handle_race_marker_Update ; then skip brake zone processing
	CMPI.w	#$0080, Player_speed.w
	BCS.b	Handle_race_marker_Update
	MOVE.w	Tire_braking_wear_rate_full.w, D0
	SUB.w	D0, Tire_braking_zone_acc.w
	BCC.b	Update_braking_performance_Clamp
	CLR.w	Tire_braking_zone_acc.w
Update_braking_performance_Clamp:
	SUB.w	D0, Tire_braking_durability_a.w
	BCC.b	Handle_race_marker_Update
	ADDI.w	#$0014, Tire_braking_durability_a.w
	MOVEQ	#1, D7
	SUBQ.w	#2, Track_braking_index.w
	BCC.b	Handle_race_marker_Update
	CLR.w	Track_braking_index.w
;Handle_race_marker_Update
Handle_race_marker_Update:
	TST.w	Collision_flag.w
	BEQ.b	Update_braking_performance_Road_marker
	SUBQ.w	#1, Tire_collision_brake_timer.w
	BNE.b	Update_braking_performance_Road_marker
	MOVE.w	#$00F0, Tire_collision_brake_timer.w
	BSR.b	Update_braking_perf_On_collision
Update_braking_performance_Road_marker:
	TST.w	Road_marker_state.w
	BEQ.b	Handle_pause_Done
	TST.w	Player_speed.w
	BEQ.b	Handle_pause_Done
	SUBQ.w	#1, Tire_road_marker_brake_timer.w
	BNE.b	Handle_pause_Done
	MOVE.w	#$0028, Tire_road_marker_brake_timer.w
	BSR.b	Update_braking_perf_On_road_marker
	BSR.b	Update_braking_perf_On_road_marker_b
;Handle_pause_Done
Handle_pause_Done:
	TST.w	D7
	BEQ.b	Update_braking_performance_Overtake
	MOVE.w	D7, Tire_wear_degrade_level.w
	MOVE.w	#$0016, Overtake_flag.w
Update_braking_performance_Overtake:
	RTS
Update_braking_perf_On_collision:
	MOVE.w	Tire_braking_wear_rate.w, D0
	BRA.b	Update_braking_perf_Apply_steering
Update_braking_perf_On_road_marker:
	MOVE.w	Tire_braking_wear_rate.w, D0
	LSR.w	#1, D0
Update_braking_perf_Apply_steering:
	SUB.w	D0, Tire_braking_durability_acc.w
	BCC.b	Update_braking_perf_Steer_ok
	CLR.w	Tire_braking_durability_acc.w
Update_braking_perf_Steer_ok:
	SUB.w	D0, Tire_braking_durability_b.w
	BCC.b	Update_braking_perf_Steer_rts
	ADDI.w	#$0014, Tire_braking_durability_b.w
	MOVEQ	#1, D7
	SUBQ.w	#2, Track_steering_index_b.w
	BCC.b	Update_braking_perf_Steer_rts
	CLR.w	Track_steering_index_b.w
Update_braking_perf_Steer_rts:
	RTS
Update_braking_perf_On_road_marker_b:
	MOVE.w	Tire_steering_wear_rate.w, D0
	ADD.w	D0, D0
	SUB.w	D0, Tire_steering_durability_acc.w
	BCC.b	Update_braking_perf_Steer_b_ok
	CLR.w	Tire_steering_durability_acc.w
Update_braking_perf_Steer_b_ok:
	SUB.w	D0, Tire_steering_durability.w
	BCC.b	Update_braking_perf_Steer_b_rts
	ADDI.w	#$0014, Tire_steering_durability.w
	MOVEQ	#1, D7
	SUBQ.w	#2, Track_steering_index.w
	BCC.b	Update_braking_perf_Steer_b_rts
	CLR.w	Track_steering_index.w
Update_braking_perf_Steer_b_rts:
	RTS
Pause_tilemap_a:
	dc.w	$C7D9, $0000, $C7CA, $0000, $C7DE, $0000, $C7DC, $0000, $C7CE
Pause_tilemap_b:
	dc.w	$87D9, $87DB, $87CE, $87DC, $87DC, $0000, $87CA, $87EA, $0000, $87CB, $87EA, $0000, $87CA, $87D7, $87CD, $0000, $87CC, $0000, $87CF, $87D8, $87DB, $0000, $87D6, $87CE, $87D7, $87DE
Race_hud_asset_list:
	dc.b	$00, $04
	dc.b	$00, $20
	dc.l	Race_hud_tiles_f
	dc.b	$4D, $00
	dc.l	Race_hud_car_tiles
	dc.b	$9F, $20
	dc.l	Race_hud_car_tiles_b
	dc.b	$E7, $00
	dc.l	Race_hud_tiles_d
	dc.b	$EB, $80
	dc.l	Race_hud_tiles_e
Rival_grid_base_table:
	dc.b	$00, $00, $00, $01, $01, $02, $02, $02, $04, $04, $06, $06, $06, $09, $09, $09
Rival_grid_delta_table:
	dc.b	$FD, $FE, $00, $FF, $FE, $01, $01, $02, $01, $01, $00
Ai_placement_data:
	dc.b	$00, $FE, $00, $FD, $01, $01, $40, $00, $E6, $00, $01, $3B, $00, $E3, $00, $01, $36, $00, $E0, $00, $01, $2C, $00, $DD, $00, $01, $27, $00, $DA, $00, $01, $22
	dc.b	$00, $D7, $00, $01, $18, $00, $D4, $FC, $01, $13, $00, $D1, $FC, $01, $0E, $00, $CE, $FC, $01, $04, $00, $CB, $FC, $00, $FA, $00, $C8, $FC, $00, $F0, $00, $C5
	dc.b	$FC, $00, $DC, $00, $C2, $FC, $00, $C3, $00, $BF, $F8, $00
Ai_placement_data_easy:
	dc.b	$A5, $00, $BC, $F8, $00
	dc.b	$01, $36, $00, $D7, $00, $01, $31, $00, $D4, $00, $01, $2C, $00, $D1, $00, $01, $22, $00, $CE, $00, $01, $1D, $00, $CB, $00, $01, $18, $00, $C8, $00, $01, $0E
	dc.b	$00, $C5, $FC, $01, $09, $00, $C2, $FC, $01, $04, $00, $BF, $FC, $00, $FA, $00, $BC, $FC, $00, $F0, $00, $B9, $FC, $00, $E6, $00, $B6, $FC, $00, $D2, $00, $B3
	dc.b	$FC, $00, $B9, $00, $B0, $F8, $00, $9B, $00, $AD, $F8
	dc.b	$00
Ai_placement_data_champ:
	dc.b	$01, $4F, $00, $E8, $08, $01, $4F, $00, $E8, $04, $01, $48, $00, $E0, $08, $01, $42, $00, $E8, $08, $01, $48, $00, $E0, $04, $01, $4F, $00, $E0, $00, $01, $42
	dc.b	$00, $E0, $08, $01, $48, $00, $D8, $00, $01, $42, $00, $D8, $00, $01, $42, $00, $D8, $04, $01, $3C, $00, $E0, $04, $01, $42, $00, $D0, $04, $01, $36, $00, $D8
	dc.b	$08, $01, $36, $00, $D0, $04, $01, $3C, $00, $D8, $00, $01, $36, $00, $D8, $04
	dc.w	$0014, $000F, $0014, $000F, $0014, $000F, $0014, $000F
	dc.w	$0010, $000F, $0010, $000F, $0010, $000F, $0010, $000F, $0005, $0000, $0005, $0000, $0005, $0000, $0005, $0000
Ai_placement_champ_offsets:
	dc.b	$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $FF, $FB, $FF, $F6, $FF, $FB, $FF, $F6, $FF, $FB, $FF, $F6, $FF, $FB, $FF, $F6
	dc.b	$FF, $F6, $FF, $F6, $FF, $F6, $FF, $F6, $FF, $F6, $FF, $F6, $FF, $F6, $FF, $F6, $FF, $F6, $FF, $EC, $FF, $F6, $FF, $EC, $FF, $F6, $FF, $EC, $FF, $F6, $FF, $EC
;$0000429E
; Race_results_frame — per-frame handler for the post-race PRELIMINARY RACE RESULTS screen.
; Each frame alternates writing two cached VDP tilemap rows (blinking "P.P" / placement
; text) from the buffer at $FFFFE800.  Counts down Screen_timer ($021C ≈ 8.5 s) or
; responds to any face-button press.
; On expiry or button press:
;   championship path (Use_world_championship_tracks != 0) → Championship_next_race_init
;   arcade path → resets Track_index_arcade_mode=1, jumps to Arcade_race_init
Race_results_frame:
	JSR	Wait_for_vblank
	LEA	Digit_tilemap_buf.w, A0
	BTST.b	#1, Frame_counter.w
	BEQ.b	Race_results_frame_Bottom
	LEA	$1A(A0), A0
Race_results_frame_Bottom:
	MOVE.l	Screen_timer.w, VDP_control_port
	MOVE.w	#$000C, D0
Race_results_frame_Loop:
	MOVE.w	(A0)+, VDP_data_port
	DBF	D0, Race_results_frame_Loop
	MOVE.b	Input_click_bitset.w, D0
	ANDI.w	#$00F0, D0
	BNE.b	Race_results_frame_Done
	SUBQ.w	#1, Race_frame_counter.w
	BNE.b	Race_results_frame_Rts
Race_results_frame_Done:
	MOVE.l	#$0000BD56, D0
	TST.w	Use_world_championship_tracks.w
	BNE.b	Race_results_frame_Champ
	MOVE.l	#$00003800, D0
	MOVE.w	#1, Track_index_arcade_mode.w
Race_results_frame_Champ:
	MOVE.l	D0, Frame_callback.w
Race_results_frame_Rts:
	RTS
;$000042F8
; Race_finish_results_init — initialise the PRELIMINARY RACE RESULTS screen shown after
; the player crosses the finish line.  Fades to black, halts audio, inits H40 VDP.
; Decompresses the "PRELIMINARY RACE RESULTS" tileset and background tilemap to VRAM.
; Renders placement strings (P.P / 2nd–15th) at fixed screen positions.
; Accumulates a BCD lap-time penalty from a lap-count table ($473C) indexed by
; Current_lap.  Sets Screen_timer=$021C, plays Music_race_results, and installs
; Race_results_frame as the per-frame callback.
Race_finish_results_init:
	JSR	Fade_palette_to_black
	JSR	Halt_audio_sequence
	JSR	Initialize_h40_vdp_state
	MOVE.w	Current_lap.w, Qualifying_temp_lap.w
	MOVE.l	#$70000002, VDP_control_port
	LEA	Race_results_tiles, A0
	JSR	Decompress_to_vdp
	LEA	Race_results_tilemap, A0
	MOVE.w	#$E580, D0
	MOVE.l	#$40000003, D7
	MOVEQ	#$00000027, D6
	MOVEQ	#$0000001B, D5
	JSR	Decompress_tilemap_to_vdp_64_cell_rows
	MOVEQ	#2, D2
	CMPI.w	#$000E, Current_lap.w
	BNE.b	Race_finish_results_init_Skip
	MOVEQ	#3, D2
Race_finish_results_init_Skip:
	LEA	Pre_race_text_ptr_table(PC), A1
	JSR	Draw_packed_list_loop
	JSR	Race_finish_results_init_Shift_lap_times(PC)
	JSR	Race_finish_results_init_Draw_lap_rows(PC)
	LEA	Pre_race_car_intro_palette_sequence, A6
	JSR	Copy_word_run_from_stream
	JSR	Copy_word_run_from_stream
	MOVE.w	Current_lap.w, D0
	TST.b	Lap_time_ptr.w
	BPL.b	Race_finish_results_init_Penalty
	MOVEQ	#$0000000F, D0
Race_finish_results_init_Penalty:
	ADD.w	D0, D0
	LEA	Pre_race_lap_time_offset_table(PC), A0
	MOVE.w	(A0,D0.w), D2
	MOVE.w	Race_time_bcd.w, D0
	MOVEQ	#0, D1
	JSR	Bcd_add_loop
	MOVE.w	D0, Race_time_bcd.w
	TST.w	Player_overtaken_flag.w
	BEQ.b	Race_finish_results_init_Done
	CLR.w	Race_time_bcd.w
	CLR.w	Player_overtaken_flag.w
Race_finish_results_init_Done:
	MOVE.w	#$021C, Race_frame_counter.w
	MOVE.l	#Race_results_frame, Frame_callback.w
	MOVE.l	#$000003D8, Vblank_callback.w
	ANDI	#$F8FF, SR
	JSR	Wait_for_vblank
	JSR	Wait_for_vblank
	MOVE.w	#Music_race_results, Audio_music_cmd ; race finish results screen music
	MOVE.w	#1, Vblank_enable.w
	MOVE.w	#$8174, VDP_control_port
	RTS

Race_finish_results_init_Shift_lap_times:
	MOVE.w	#$000D, D0
	SUB.w	Current_lap.w, D0
	BCS.b	Race_finish_results_init_Store_target
	LEA	(Track_lap_target_buf+$38).w, A0
	LEA	(Track_lap_target_buf+$3C).w, A1
Race_finish_results_init_Shift_loop:
	MOVE.l	-(A0), -(A1)
	DBF	D0, Race_finish_results_init_Shift_loop
Race_finish_results_init_Store_target:
	MOVE.w	Current_lap.w, D0
	ADD.w	D0, D0
	ADD.w	D0, D0
	LEA	Track_lap_target_buf.w, A0
	MOVE.l	Lap_time_ptr.w, (A0,D0.w)
	RTS
Race_finish_results_init_Draw_lap_rows:
	LEA	VDP_data_port, A1
	LEA	Track_lap_target_buf.w, A0
	LEA	(Digit_tilemap_buf+$10).w, A3
	LEA	Pre_race_tile_addr_table(PC), A2
	MOVEQ	#$0000000D, D4
	CMPI.w	#$000E, Current_lap.w
	BNE.b	Race_finish_results_init_Row_loop
	MOVEQ	#$0000000E, D4
Race_finish_results_init_Row_loop:
	MOVE.l	(A0)+, D0
	MOVE.w	#$E000, D3
	JSR	Format_bcd_time_to_tile_buffer
	MOVE.w	(A2)+, D7
	ADDI.w	#$000A, D7
	JSR	Tile_index_to_vdp_command
	MOVE.l	D7, $4(A1)
	MOVE.l	(A3)+, (A1)
	MOVE.l	(A3)+, (A1)
	MOVE.l	(A3)+, (A1)
	MOVE.l	(A3)+, (A1)
	DBF	D4, Race_finish_results_init_Row_loop
	TST.b	Lap_time_ptr.w
	BPL.b	Race_finish_results_init_Current_row
	LEA	Pre_race_text_points_labels(PC), A6
	JSR	Draw_packed_tilemap_to_vdp
Race_finish_results_init_Current_row:
	MOVE.w	Current_lap.w, D0
	ADD.w	D0, D0
	LEA	Pre_race_tile_addr_table(PC), A0
	MOVE.w	(A0,D0.w), D7
	JSR	Tile_index_to_vdp_command
	MOVE.l	D7, Screen_timer.w
	LEA	Digit_tilemap_buf.w, A0
	BCLR.l	#$1E, D7
	MOVE.l	D7, $4(A1)
	MOVE.l	(A1), (A0)+
	MOVE.l	(A1), (A0)+
	MOVE.l	(A1), (A0)+
	MOVE.l	(A1), (A0)+
	MOVE.l	(A1), (A0)+
	MOVE.l	(A1), (A0)+
	MOVE.w	(A1), (A0)+
	MOVEQ	#$0000000C, D0
Race_finish_results_init_Blink_loop:
	MOVE.w	-$1A(A0), D1
	ANDI.w	#$9FFF, D1
	MOVE.w	D1, (A0)+
	DBF	D0, Race_finish_results_init_Blink_loop
	RTS
;$000044A8
; Pre_race_display_frame — per-frame handler for the arcade inter-race countdown overlay
; (the "5, 4, 3…" flashing counter shown before race 2+).
; Writes a pulsing tile word to VDP ($70000003 address) based on Frame_counter parity.
; Copies a 2-of-4-frame palette buffer each frame.  Decrements Race_frame_counter:
;   at $A4 frames → plays Sfx_checkpoint (SFX $06)
;   at $2E frames → plays Sfx_race_start  (SFX $05)
; When the counter reaches zero or a face button is pressed: sets
;   Track_index_arcade_mode=2 and jumps to Arcade_race_init.
Pre_race_display_frame:
	JSR	Wait_for_vblank
	MOVE.b	Frame_counter.w, D0
	MOVE.w	D0, D1
	ANDI.w	#2, D0
	SUBQ.w	#3, D0
	MOVE.l	#$70000003, VDP_control_port
	MOVE.w	D0, VDP_data_port
	ANDI.w	#4, D1
	MULU.w	#$009B, D1
	LEA	Tilemap_work_buf.w, A6
	ADDA.w	D1, A6
	MOVE.l	#$658A0003, D7
	MOVEQ	#$0000001E, D6
	MOVEQ	#9, D5
	JSR	Draw_tilemap_buffer_to_vdp_64_cell_rows
	MOVE.b	Input_click_bitset.w, D0
	ANDI.w	#$00F0, D0
	BNE.b	Pre_race_display_frame_Done
	SUBQ.w	#1, Race_frame_counter.w
	BEQ.b	Pre_race_display_frame_Done
	CMPI.w	#$00A4, Race_frame_counter.w
	BNE.b	Pre_race_display_frame_Countdown_chk2
	MOVE.w	#6, Audio_music_state
Pre_race_display_frame_Countdown_chk2:
	CMPI.w	#$002E, Race_frame_counter.w
	BNE.b	Pre_race_display_frame_Rts
	MOVE.w	#5, Audio_music_state
	BRA.b	Pre_race_display_frame_Rts
Pre_race_display_frame_Done:
	MOVE.w	#2, Track_index_arcade_mode.w
	MOVE.l	#Arcade_race_init, Frame_callback.w
Pre_race_display_frame_Rts:
	RTS
	JSR	Fade_palette_to_black
	JSR	Initialize_h40_vdp_state
	MOVE.w	#$8B00, VDP_control_port
	MOVE.w	#$9209, VDP_control_port
	LEA	Pre_race_asset_list(PC), A1
	JSR	Decompress_asset_list_to_vdp
	LEA	Race_results_tilemap, A0
	MOVE.w	#$E580, D0
	MOVE.l	#$40000003, D7
	MOVEQ	#$00000027, D6
	MOVEQ	#$0000001B, D5
	JSR	Decompress_tilemap_to_vdp_64_cell_rows
	LEA	Championship_screen_tilemap, A0
	MOVE.w	#$E001, D0
	MOVE.l	#$63140003, D7
	MOVEQ	#$00000014, D6
	MOVEQ	#1, D5
	JSR	Decompress_tilemap_to_vdp_64_cell_rows
	LEA	Championship_final_tilemap, A0
	MOVE.w	#$8080, D0
	MOVE.l	#$658A0003, D7
	MOVEQ	#$0000001E, D6
	MOVEQ	#9, D5
	JSR	Decompress_tilemap_to_vdp_64_cell_rows
	LEA	Sprite_attr_buf.w, A0
	MOVE.w	#$010C, D0
	MOVEQ	#1, D1
	MOVEQ	#1, D2
Pre_race_car_sprite_row_loop:
	MOVE.w	#$00A0, D3
	MOVEQ	#7, D4
Pre_race_car_sprite_col_loop:
	MOVE.w	D0, (A0)+
	MOVE.b	#$0F, (A0)+
	MOVE.b	D1, (A0)+
	MOVE.w	#$0432, (A0)+
	MOVE.w	D3, (A0)+
	ADDQ.w	#1, D1
	ADDI.w	#$0020, D3
	DBF	D4, Pre_race_car_sprite_col_loop
	ADDI.w	#$0020, D0
	DBF	D2, Pre_race_car_sprite_row_loop
	CLR.b	-$5(A0)
	LEA	Pre_race_intro_palette_strip_a, A6
	JSR	Copy_word_run_from_stream
	JSR	Copy_word_run_from_stream
	MOVE.w	#$00A5, Race_frame_counter.w
	MOVE.l	#Pre_race_display_frame, Frame_callback.w
	MOVE.l	#$000003D8, Vblank_callback.w
	JSR	Halt_audio_sequence
	ANDI	#$F8FF, SR
	JSR	Wait_for_vblank
	JSR	Wait_for_vblank
	MOVE.w	#1, Vblank_enable.w
	MOVE.w	#$8174, VDP_control_port
	RTS
Pre_race_car_intro_palette_sequence:
	dc.b	$60, $09, $04, $44, $00, $00, $0E, $EE, $08, $88, $08, $CC, $02, $88, $06, $AA, $02, $66, $02, $22, $08, $88, $04, $00, $0E, $66
Pre_race_intro_palette_strip_a:
	dc.b	$02, $0D, $02, $00, $04, $00, $04, $20, $06, $20, $06, $42, $08, $42, $08, $64, $0A, $64, $0A, $86, $0C, $86, $0C, $A8, $0E, $CA, $0E, $EC, $0E, $A8, $60, $0E
	dc.b	$06, $44, $00, $00, $0E, $EE, $09, $99, $0C, $88, $08, $22, $0A, $66, $06, $22, $08, $66, $08, $66, $00, $00, $08, $88, $0A, $AA, $0C, $CC, $0E, $EE
Pre_race_asset_list:
	dc.b	$00, $03
	dc.b	$B0, $00
	dc.l	Race_results_tiles
	dc.b	$00, $20
	dc.l	Pre_race_screen_tiles
	dc.b	$10, $00
	dc.l	Championship_final_tiles
	dc.b	$86, $40
	dc.l	Race_hud_tiles_c
Pre_race_text_ptr_table:
	dc.l	Pre_race_text_results_header
	dc.l	Pre_race_text_positions_1_8
	dc.l	Pre_race_text_positions_9_14
	dc.l	Pre_race_text_position_15
Pre_race_text_results_header:
	dc.b	$E2, $8E, $FB, $87, $C0
	txt "PRELIMINARY", $FA
	txt "RACE", $FA
	txt "RESULTS", $FF
Pre_race_text_positions_1_8:
	dc.b	$E3, $8A, $FB, $E7, $C0
	txt "P.P", $FC
	txt "2ND", $FC
	txt "3RD", $FC
	txt "4TH", $FC
	txt "5TH", $FC
	txt "6TH", $FC
	txt "7TH", $FC
	txt "8TH", $FF, $00
Pre_race_text_positions_9_14:
	dc.b	$E3, $A8, $FA
	txt "9TH", $FC
	txt "10TH", $FC
	txt "11TH", $FC
	txt "12TH", $FC
	txt "13TH", $FC
	txt "14TH", $FF
Pre_race_text_position_15:
	dc.b	$E9, $A8
	txt "15TH", $FF, $00
Pre_race_text_points_labels:
	dc.b	$E9, $B2, $FB, $E7, $C0, $FA, $FA, $2C, $2C, $2C, $2C, $2C, $FA, $FF
Pre_race_tile_addr_table:
	dc.w	$E388, $E488, $E588, $E688, $E788, $E888, $E988, $EA88, $E3A8, $E4A8, $E5A8, $E6A8, $E7A8, $E8A8, $E9A8
Pre_race_lap_time_offset_table:
	dc.w	$0159
	dc.b	$01, $07, $00, $87, $00, $74, $00, $68
	dc.w	$0063
	dc.b	$00, $58, $00, $52, $00, $47, $00, $42, $00, $37, $00, $32, $00, $27, $00, $22, $00, $17
	dc.w	$0000
;$0000475C
Name_entry_frame:
	JSR	Wait_for_vblank
	JSR	Update_car_selection_screen(PC)
	JSR	Upload_palette_buffer_to_vdp(PC)
	LEA	Name_entry_frame_tilemap(PC), A6
	JSR	Draw_packed_tilemap_to_vdp
	JSR	Draw_initials_entry_selection(PC)
	JSR	Draw_initials_entry_buffer(PC)
	JSR	Update_objects_and_build_sprite_buffer
	TST.w	Temp_distance.w
	BEQ.b	Name_entry_frame_Active
	SUBQ.w	#1, Temp_distance.w
	BNE.b	Name_entry_frame_Rts
	MOVE.l	#$00002592, Frame_callback.w
Name_entry_frame_Rts:
	RTS
Name_entry_frame_Active:
	JSR	Update_initials_entry_selection(PC)
	JSR	Handle_initials_entry_button_input(PC)
	MOVEQ	#1, D1
	SUB.b	D1, Name_entry_blink_timer.w
	BNE.b	Name_entry_frame_Bcd_write
	MOVE.b	#$3C, Name_entry_blink_timer.w
	MOVE.b	Race_frame_counter.w, D2
	BNE.b	Name_entry_frame_Bcd_body
Name_entry_frame_Blink_clear:
	JSR	Clear_initials_entry_placeholders(PC)
	MOVE.w	#$005A, Temp_distance.w
	RTS
Name_entry_frame_Bcd_body:
	ADDI.w	#0, D0
	SBCD	D1, D2
	MOVE.b	D2, Race_frame_counter.w
Name_entry_frame_Bcd_write:
	LEA	Digit_tilemap_buf.w, A1
	MOVE.b	Race_frame_counter.w, D1
	MOVEQ	#1, D0
	MOVEQ	#0, D7
	JSR	Unpack_bcd_digits_to_buffer
	MOVEQ	#1, D0
	JSR	Copy_digits_to_tilemap
	MOVE.l	#$6AC40003, D7
	MOVEQ	#1, D6
	MOVEQ	#1, D5
	LEA	Digit_tilemap_buf.w, A6
	JSR	Draw_tilemap_buffer_to_vdp_64_cell_rows
	BTST.b	#KEY_START, Input_click_bitset.w
	BEQ.b	Name_entry_frame_End_rts
	MOVE.w	#$FFFF, Temp_distance.w
	JSR	Clear_initials_entry_placeholders(PC)
	JSR	Draw_initials_entry_buffer(PC)
	MOVE.w	#9, Selection_count.w
	MOVE.l	#Title_menu, Frame_callback.w
Name_entry_frame_End_rts:
	RTS
Handle_initials_entry_button_input:
	MOVE.b	Input_click_bitset.w, D0
	ANDI.w	#$0070, D0
	BEQ.b	Handle_initials_entry_button_input_Done
	MOVEQ	#0, D0
	MOVE.b	Menu_cursor.w, D0
	LEA	Initials_entry_cursor_to_char_table(PC), A0
	MOVE.b	(A0,D0.w), D0
	LSR.w	#1, D0
	CMPI.w	#$001A, D0
	BEQ.w	Name_entry_frame_Blink_clear
	CMPI.w	#$001B, D0
	BEQ.b	Handle_initials_entry_button_input_Delete
	MOVEQ	#0, D1
	MOVE.b	Menu_substate.w, D1
	MOVEA.l	Screen_data_ptr.w, A0
	ADDI.w	#$000A, D0
	MOVE.b	D0, (A0,D1.w)
	ADDQ.b	#1, Menu_substate.w
	CMPI.b	#3, Menu_substate.w
	BNE.b	Handle_initials_entry_button_input_Done
	MOVE.b	#$1C, Menu_cursor.w
Handle_initials_entry_button_input_Done:
	RTS
Handle_initials_entry_button_input_Delete:
	MOVE.b	Menu_substate.w, D1
	MOVEA.l	Screen_data_ptr.w, A0
	MOVE.b	#$36, (A0,D1.w)
	TST.b	Menu_substate.w
	BEQ.b	Handle_initials_entry_button_input_Rts
	SUBQ.b	#1, Menu_substate.w
Handle_initials_entry_button_input_Rts:
	RTS
Draw_initials_entry_buffer:
	MOVEA.l	Screen_data_ptr.w, A0
	TST.w	Temp_distance.w
	BNE.b	Draw_initials_entry_buffer_Draw
	MOVEQ	#0, D0
	BTST.b	#3, Frame_counter.w
	BEQ.b	Draw_initials_entry_buffer_Blank_tile
	MOVEQ	#$00000036, D0
Draw_initials_entry_buffer_Blank_tile:
	MOVEQ	#0, D1
	MOVE.b	Menu_substate.w, D1
	MOVE.b	D0, (A0,D1.w)
Draw_initials_entry_buffer_Draw:
	LEA	VDP_data_port, A5
	MOVE.l	Screen_scroll.w, D0
	ADDI.l	#$00300000, D0
	MOVE.l	D0, $4(A5)
	JMP	Draw_initials_entry_name_tiles_No_blink
Clear_initials_entry_placeholders:
	MOVEA.l	Screen_data_ptr.w, A0
	MOVEQ	#2, D0
Clear_initials_entry_placeholders_Loop:
	CMPI.b	#$36, (A0)
	BNE.b	Clear_initials_entry_placeholders_Next
	CLR.b	(A0)
Clear_initials_entry_placeholders_Next:
	ADDQ.w	#1, A0
	DBF	D0, Clear_initials_entry_placeholders_Loop
	RTS
Update_initials_entry_selection:
	MOVE.b	Input_state_bitset.w, D0
	ANDI.w	#$000C, D0 ; Keys left+right? (assuming D0 high was 0)
	BNE.b	Update_initials_entry_selection_Active
	CLR.b	Selection_repeat_state.w
Update_initials_entry_selection_Rts:
	RTS
Update_initials_entry_selection_Active:
	SUBQ.b	#1, Selection_repeat_state.w
	BPL.b	Update_initials_entry_selection_Rts
	MOVE.b	#7, Selection_repeat_state.w
	MOVE.b	Menu_cursor.w, D1
	BTST.l	#2, D0
	BNE.b	Update_initials_entry_selection_Left
	ADDQ.b	#1, D1
	CMPI.b	#$1D, D1
	BCS.b	Update_initials_entry_Write
	CMPI.b	#3, Menu_substate.w
	BNE.b	Update_initials_entry_selection_Wrap_right
	MOVEQ	#$0000001B, D1
	BRA.b	Update_initials_entry_Write
Update_initials_entry_selection_Wrap_right:
	CLR.w	D1
	BRA.b	Update_initials_entry_Write
Update_initials_entry_selection_Left:
	SUBQ.b	#1, D1
	BCS.b	Update_initials_entry_selection_Wrap_left
	CMPI.b	#3, Menu_substate.w
	BNE.b	Update_initials_entry_Write
	CMPI.b	#$1A, D1
	BNE.b	Update_initials_entry_Write
Update_initials_entry_selection_Wrap_left:
	MOVEQ	#$0000001C, D1
;Update_initials_entry_Write
Update_initials_entry_Write:
	MOVE.b	D1, Menu_cursor.w
	RTS
Draw_initials_entry_selection:
	MOVEQ	#0, D0
	MOVE.b	Menu_cursor.w, D0
	MOVE.w	D0, D7
	ADD.w	D7, D7
	ADDI.w	#$E80C, D7
	JSR	Set_vdp_command_from_tile_index(PC)
	LEA	Initials_entry_cursor_tile_offset_table(PC), A0
	MOVE.b	(A0,D0.w), D0
	ADDI.w	#$C05F, D0
	MOVE.w	D0, VDP_data_port
	ADDQ.w	#1, D0
	ADDI.l	#$00800000, D7
	MOVE.l	D7, VDP_control_port
	MOVE.w	D0, VDP_data_port
	RTS
Set_vdp_command_from_tile_index:
	JSR	Tile_index_to_vdp_command
	MOVE.l	D7, VDP_control_port
	RTS
;Pre_race_screen_init
Pre_race_screen_init:
	JSR	Fade_palette_to_black
	JSR	Initialize_h40_vdp_state
	JSR	Clear_main_object_pool
	LEA	Pre_race_screen_tilemap, A0
	MOVE.w	#$A030, D0
	MOVE.l	#$608E0003, D7
	MOVEQ	#$00000019, D6
	MOVEQ	#1, D5
	JSR	Decompress_tilemap_to_vdp_64_cell_rows
	JSR	Load_pre_race_qualifying_data(PC)
	BCC.b	Pre_race_screen_init_Not_champ
	JSR	Draw_pre_race_standings_With_target(PC)
	MOVE.w	#$E88E, Screen_scroll.w
	JSR	Read_vram_row_strip_priority(PC)
	BRA.w	Pre_race_screen_init_Common
Pre_race_screen_init_Not_champ:
	JSR	Draw_pre_race_standings(PC)
	MOVE.w	Screen_subcounter.w, D0
	CMPI.w	#5, D0
	BCS.b	Pre_race_screen_init_Clamp_row
	MOVEQ	#4, D0
Pre_race_screen_init_Clamp_row:
	LSL.w	#8, D0
	ADDI.w	#$E30E, D0
	MOVE.w	D0, Screen_scroll.w
	JSR	Read_vram_row_strip_priority(PC)
	JSR	Initialize_race_track_scroll_tables(PC)
	JSR	Pre_race_init_road_vdp(PC)
	MOVE.l	#$00004F5C, Ai_car_array.w
	MOVE.w	#$603C, Race_frame_counter.w
	MOVE.l	#Name_entry_frame, Frame_callback.w
	MOVE.l	#$000003D8, Vblank_callback.w
	JSR	Halt_audio_sequence
	ANDI	#$F8FF, SR
	JSR	Wait_for_vblank
	JSR	Wait_for_vblank
	MOVE.w	#Music_pre_race, Audio_music_cmd    ; pre-race briefing music
	MOVE.w	#1, Vblank_enable.w
	MOVE.w	#$8174, VDP_control_port
	RTS

Pre_race_init_road_vdp:
	LEA	Road_tiles_startup, A0
	LEA	Curve_data, A4
	JSR	Decompress_to_ram
	MOVEQ	#0, D1
	MOVEQ	#$00000029, D0
	LEA	$00FF5C40, A0
	LEA	VDP_data_port, A1
	MOVE.l	#$53200000, VDP_control_port
Pre_race_init_road_vdp_Loop:
	MOVE.l	D1, (A1)
	MOVE.l	D1, (A1)
	MOVE.l	D1, (A1)
	MOVE.l	D1, (A1)
	MOVE.l	(A0)+, (A1)
	MOVE.l	(A0)+, (A1)
	MOVE.l	(A0)+, (A1)
	MOVE.l	(A0)+, (A1)
	MOVE.l	(A0)+, (A1)
	MOVE.l	(A0)+, (A1)
	MOVE.l	(A0)+, (A1)
	MOVE.l	(A0)+, (A1)
	MOVE.l	D1, (A1)
	MOVE.l	D1, (A1)
	MOVE.l	D1, (A1)
	MOVE.l	D1, (A1)
	DBF	D0, Pre_race_init_road_vdp_Loop
	RTS
;Read_vram_row_strip_priority
Read_vram_row_strip_priority:
	MOVE.w	Screen_scroll.w, D7
	JSR	Tile_index_to_vdp_command
	MOVE.l	D7, Screen_scroll.w
	BCLR.l	#$1E, D7
	MOVE.l	D7, VDP_control_port
	LEA	Road_car_priority_buf.w, A0
	MOVEQ	#$0000001F, D0
	MOVE.w	D0, D1
Read_vram_row_strip_priority_Read_loop:
	MOVE.w	VDP_data_port, (A0)+
	DBF	D0, Read_vram_row_strip_priority_Read_loop
Read_vram_row_strip_priority_Clear_loop:
	MOVE.w	-$40(A0), D2
	ANDI.w	#$9FFF, D2
	MOVE.w	D2, (A0)+
	DBF	D1, Read_vram_row_strip_priority_Clear_loop
	RTS
;Upload_palette_buffer_to_vdp
Upload_palette_buffer_to_vdp:
; Write 16 longwords (64 bytes) of palette tile data to the VDP data port
; using the current Screen_scroll address command.
; Used during certain non-race screens (menus, results) to update per-tile
; colour selection data rather than the full CRAM palette.
; Alternates between two 64-byte sub-buffers at $FFFFCE00/$FFFFCE40 on even/odd
; frames (Frame_counter bit 0) to implement double-buffering of the tile strip.
; Does nothing if Screen_scroll is 0.
	MOVE.l	Screen_scroll.w, D0
	BEQ.b	Upload_palette_buffer_to_vdp_Rts
	LEA	VDP_data_port, A6
	MOVE.l	D0, $4(A6)
	LEA	Road_car_priority_buf.w, A0
	MOVE.b	Frame_counter.w, D0
	ANDI.w	#1, D0
	LSL.w	#6, D0
	ADDA.w	D0, A0
	MOVEQ	#$0000000F, D0
Upload_palette_buffer_to_vdp_Loop:
	MOVE.l	(A0)+, (A6)
	DBF	D0, Upload_palette_buffer_to_vdp_Loop
Upload_palette_buffer_to_vdp_Rts:
	RTS
Load_pre_race_qualifying_data:
	LEA	Decomp_stream_buf.w, A0
	MOVE.w	Race_time_bcd.w, (A0)+
	MOVE.b	Qualifying_temp_flag_c.w, (A0)+
	MOVE.b	Qualifying_temp_flag_f.w, (A0)+
	MOVE.b	Qualifying_temp_flag_a.w, (A0)+
	MOVE.b	Qualifying_temp_flag_d.w, (A0)+
	MOVE.w	Qualifying_temp_value_a.w, (A0)+
	MOVE.b	Qualifying_temp_flag_b.w, (A0)+
	MOVE.b	Qualifying_temp_flag_e.w, (A0)+
	MOVE.w	Qualifying_temp_value_b.w, (A0)+
	MOVE.b	#$22, (A0)+
	MOVE.b	#$18, (A0)+
	MOVE.b	#$1E, (A0)+
	CLR.b	(A0)
	MOVE.w	Race_time_bcd.w, D0
	MOVEQ	#0, D1
	MOVEQ	#8, D2
	LEA	Qualifying_time_table_buf.w, A0
Load_pre_race_qualifying_data_Search_loop:
	CMP.w	(A0), D0
	BHI.b	Load_pre_race_qualifying_data_Insert
	ADDQ.w	#1, D1
	LEA	$10(A0), A0
	DBF	D2, Load_pre_race_qualifying_data_Search_loop
	ADDQ.w	#2, D2
	RTS
Load_pre_race_qualifying_data_Insert:
	MOVE.w	D1, Screen_subcounter.w
	MOVEQ	#8, D0
	SUB.w	D1, D0
	BEQ.b	Load_pre_race_qualifying_data_Write
	ADD.w	D0, D0
	ADD.w	D0, D0
	SUBQ.w	#1, D0
	LEA	(Qualifying_time_table_buf+$90).w, A2
	LEA	-$10(A2), A3
Load_pre_race_qualifying_data_Shift_loop:
	MOVE.l	-(A3), -(A2)
	DBF	D0, Load_pre_race_qualifying_data_Shift_loop
Load_pre_race_qualifying_data_Write:
	LEA	Decomp_stream_buf.w, A1
	MOVEQ	#3, D0
Load_pre_race_qualifying_data_Copy_loop:
	MOVE.l	(A1)+, (A0)+
	DBF	D0, Load_pre_race_qualifying_data_Copy_loop
	LEA	-$4(A0), A0
	MOVE.l	A0, Screen_data_ptr.w
	MOVE.b	#$36, (A0)+
	MOVE.b	#$36, (A0)+
	MOVE.b	#$36, (A0)
	RTS
;$00004B76
; Pre_race_preview_car_frame — per-frame handler for the spinning-car pre-race preview
; screen.  Updates the car-selection animation (Update_car_selection_screen), uploads
; palettes, builds the sprite list.
; On START press → plays music 9 (Music_pre_race), returns to Title_menu.
; When Screen_timer expires → transitions to the name/initials entry screen ($2592).
Pre_race_preview_car_frame:
	JSR	Wait_for_vblank
	JSR	Update_car_selection_screen(PC)
	JSR	Upload_palette_buffer_to_vdp(PC)
	JSR	Update_objects_and_build_sprite_buffer
	BTST.b	#KEY_START, Input_click_bitset.w
	BEQ.b	Pre_race_preview_car_frame_No_start
	MOVE.w	#9, Selection_count.w
	MOVE.l	#Title_menu, Frame_callback.w
	RTS
Pre_race_preview_car_frame_No_start:
	SUBQ.w	#1, Race_frame_counter.w
	BNE.b	Pre_race_preview_car_frame_Rts
	MOVE.l	#$00002592, Frame_callback.w
Pre_race_preview_car_frame_Rts:
	RTS
;$00004BB2
; Pre_race_screen_championship_init — initialise the pre-championship spinning-car
; preview screen.  Fades to black, inits H40 VDP, clears objects.
; Decompresses one-row tilemap and the track-panorama background into VRAM.
; Sets up car-preview sprite object and arms Screen_timer=$01E0 (480 frames ≈ 8 s).
; Installs Pre_race_preview_car_frame as the per-frame callback.
Pre_race_screen_championship_init:
	JSR	Fade_palette_to_black
	JSR	Initialize_h40_vdp_state
	JSR	Clear_main_object_pool
	LEA	Pre_race_screen_tilemap, A0
	MOVE.w	#$A030, D0
	MOVE.l	#$610E0003, D7
	MOVEQ	#$00000019, D6
	MOVEQ	#1, D5
	JSR	Decompress_tilemap_to_vdp_64_cell_rows
	JSR	Draw_pre_race_standings_Championship(PC)
Pre_race_screen_init_Common:
	JSR	Initialize_race_track_scroll_tables(PC)
	MOVE.l	#$00004F56, Ai_car_array.w
	MOVE.w	#$01E0, Race_frame_counter.w
	MOVE.l	#Pre_race_preview_car_frame, Frame_callback.w
	MOVE.l	#$000003D8, Vblank_callback.w
	JSR	Halt_audio_sequence
	ANDI	#$F8FF, SR
	JSR	Wait_for_vblank
	JSR	Wait_for_vblank
	MOVE.w	#1, Vblank_enable.w
	MOVE.w	#$8174, VDP_control_port
	RTS

;Initialize_race_track_scroll_tables
Initialize_race_track_scroll_tables:
	LEA	Road_scale_table.w, A0
	LEA	Road_scanline_x_buf.w, A1
	MOVEQ	#$00000077, D0
	MOVE.l	#$00000148, D1
	MOVE.l	#$00003500, D2
	MOVE.w	#$00A0, D3
Initialize_race_track_scroll_tables_Loop:
	SWAP	D1
	ADD.l	D2, D1
	SWAP	D1
	MOVE.w	D1, (A0)+
	ADDQ.w	#1, D3
	MOVE.w	D3, (A1)+
	DBF	D0, Initialize_race_track_scroll_tables_Loop
	LEA	Championship_driver_asset_list(PC), A1
	JSR	Decompress_asset_list_to_vdp
	LEA	Championship_driver_palette_data(PC), A6
	JSR	Copy_word_run_from_stream
	JSR	Copy_word_run_from_stream
	JSR	Copy_word_run_from_stream
	JSR	Copy_word_run_from_stream
	MOVE.w	#$6194, D0
	LEA	Car_select_tilemap, A0
	JMP	Decompress_tilemap_to_buffer
;Update_car_selection_screen
Update_car_selection_screen:
	MOVE.w	Screen_tick.w, D0
	MULU.w	#$02B4, D0
	LEA	Tilemap_work_buf.w, A6
	ADDA.w	D0, A6
	MOVE.l	#$4C000003, D7
	MOVEQ	#8, D6
	MOVEQ	#3, D5
	JSR	Draw_tilemap_buffer_to_vdp_64_cell_rows
	MOVE.l	#$49120003, D7
	MOVEQ	#$0000001E, D6
	MOVEQ	#9, D5
	JSR	Draw_tilemap_buffer_to_vdp_64_cell_rows
	SUBQ.w	#1, Screen_timer.w
	BPL.b	Update_car_selection_screen_Rts
	MOVE.w	#4, Screen_timer.w
	ADDQ.w	#1, Screen_tick.w
	CMPI.w	#3, Screen_tick.w
	BCS.b	Update_car_selection_screen_Rts
	CLR.w	Screen_tick.w
Update_car_selection_screen_Rts:
	RTS
Draw_pre_race_standings:
	LEA	Position_text_1_4(PC), A4
	LEA	Qualifying_time_table_buf.w, A0
	MOVE.w	Screen_subcounter.w, D0
	SUBQ.w	#4, D0
	BLS.b	Draw_pre_race_standings_Offset
	MOVE.w	D0, D1
	ADD.w	D0, D0
	ADD.w	D1, D0
	ADDA.w	D0, A4
	LSL.w	#4, D1
	ADDA.w	D1, A0
Draw_pre_race_standings_Offset:
	MOVE.w	#$E184, D6
	MOVE.w	#5, Screen_item_count.w
	BRA.b	Draw_pre_race_standings_Header
Draw_pre_race_standings_With_target:
	LEA	Position_text_5_9(PC), A4
	LEA	(Qualifying_time_table_buf+$40).w, A0
	MOVE.w	#$E184, D6
	MOVE.w	#5, Screen_item_count.w
	JSR	Draw_pre_race_standings_Header(PC)
	LEA	Decomp_stream_buf.w, A0
	MOVE.w	#$E804, D6
	LEA	Qualifying_rank_position_data(PC), A4
	MOVE.w	Race_time_bcd.w, D0
	LEA	Qualifying_time_thresholds(PC), A6
	MOVEQ	#3, D1
Draw_pre_race_standings_Time_loop:
	CMP.w	(A6)+, D0
	BCC.b	Draw_pre_race_standings_Time_found
	ADDQ.w	#3, A4
	DBF	D1, Draw_pre_race_standings_Time_loop
Draw_pre_race_standings_Time_found:
	MOVE.w	#1, Screen_item_count.w
	LEA	Car_result_column_tilemap_3_laps(PC), A6
	TST.b	$4(A0)
	BMI.b	Update_car_selection_Draw
	LEA	Car_result_column_tilemap_5_laps(PC), A6
	TST.b	$8(A0)
	BMI.b	Update_car_selection_Draw
	LEA	Car_result_column_tilemap_7_laps(PC), A6
	BRA.b	Update_car_selection_Draw
Draw_pre_race_standings_Championship:
	LEA	Position_text_1_4(PC), A4
	LEA	Qualifying_time_table_buf.w, A0
	MOVE.w	#$E204, D6
	MOVE.w	#9, Screen_item_count.w
Draw_pre_race_standings_Header:
	LEA	VDP_data_port, A5
	LEA	Car_result_column_tilemap(PC), A6
	JSR	Draw_packed_tilemap_to_vdp_preset_base
Draw_pre_race_standings_Item:
	LEA	Car_result_row_tilemap(PC), A6
	TST.b	$4(A0)
	BMI.b	Update_car_selection_Draw
	LEA	Car_result_row_tilemap_active_a(PC), A6
	TST.b	$8(A0)
	BMI.b	Update_car_selection_Draw
	LEA	Car_result_row_tilemap_active_ab(PC), A6
;Update_car_selection_Draw
Update_car_selection_Draw:
	JSR	Draw_packed_tilemap_to_vdp_preset_base
	LEA	Car_result_shading_tilemap(PC), A6
	JSR	Draw_packed_tilemap_to_vdp_preset_base
	JSR	Draw_car_result_placement_tiles(PC)
	MOVE.w	(A0)+, D0
	MOVEQ	#4, D1
	MOVEQ	#$0000000A, D2
	JSR	Render_number_tiles_at_row_col(PC)
	JSR	Draw_car_result_position_tile(PC)
	JSR	Draw_car_result_nationality_tile(PC)
	JSR	Draw_car_result_time_columns(PC)
	JSR	Draw_initials_entry_name_tiles(PC)
	SUBQ.w	#1, Screen_item_count.w
	BNE.b	Draw_pre_race_standings_Item
	LEA	Car_result_grid_tilemap(PC), A6
	JMP	Draw_packed_tilemap_to_vdp_preset_base
Draw_car_result_placement_tiles:
	MOVE.w	D6, D7
	ADDI.w	#$FF82, D7
	JSR	Set_vdp_command_from_tile_index(PC)
	MOVEQ	#2, D0
	MOVE.w	#$C7C0, D1
Draw_car_result_placement_tiles_Loop:
	MOVEQ	#0, D2
	MOVE.b	(A4)+, D2
	BEQ.b	Draw_car_result_placement_tiles_Write
	ADD.w	D1, D2
Draw_car_result_placement_tiles_Write:
	MOVE.w	D2, (A5)
	DBF	D0, Draw_car_result_placement_tiles_Loop
	RTS
Draw_initials_entry_name_tiles:
	MOVE.w	D6, D7
	ADDI.w	#$FFBA, D7
	JSR	Set_vdp_command_from_tile_index(PC)
	MOVEQ	#1, D7
	BRA.b	Draw_initials_entry_name_tiles_Body
Draw_initials_entry_name_tiles_No_blink:
	MOVEQ	#0, D7
Draw_initials_entry_name_tiles_Body:
	MOVEQ	#2, D0
	MOVE.w	#$C7C0, D1
	TST.w	Temp_distance.w
	BEQ.b	Draw_initials_entry_name_tiles_Loop
	BTST.b	#0, Frame_counter.w
	BEQ.b	Draw_initials_entry_name_tiles_Loop
	MOVE.w	#$87C0, D1
Draw_initials_entry_name_tiles_Loop:
	MOVEQ	#0, D2
	MOVE.b	(A0)+, D2
	BEQ.b	Draw_initials_entry_name_tiles_Store
	CMPI.w	#$0036, D2
	BNE.b	Draw_initials_entry_name_tiles_Write
	TST.w	D7
	BEQ.b	Draw_initials_entry_name_tiles_Write
	MOVEQ	#0, D2
	BRA.b	Draw_initials_entry_name_tiles_Store
Draw_initials_entry_name_tiles_Write:
	ADD.w	D1, D2
Draw_initials_entry_name_tiles_Store:
	MOVE.w	D2, (A5)
	DBF	D0, Draw_initials_entry_name_tiles_Loop
	ADDQ.w	#1, A0
	RTS
Draw_car_result_time_columns:
	MOVEQ	#0, D0
	MOVE.b	(A0)+, D0
	BMI.b	Draw_car_result_time_columns_Retired
	MOVE.w	D6, D7
	ADDI.w	#$FF9A, D7
	MOVE.w	#$001C, D2
	JSR	Draw_car_result_time_value(PC)
	MOVEQ	#0, D0
	MOVE.b	(A0)+, D0
	BMI.b	Draw_car_result_time_columns_Skip
	MOVE.w	D6, D7
	ADDI.w	#$FFAA, D7
	MOVE.w	#$002C, D2
Draw_car_result_time_value:
	MOVEM.w	D7/D0, -(A7)
	MOVE.b	(A0)+, D0
	SWAP	D0
	MOVE.w	(A0)+, D0
	MOVEQ	#6, D1
	JSR	Render_number_tiles_at_row_col(PC)
	MOVEM.w	(A7)+, D0/D7
	JSR	Set_vdp_command_from_tile_index(PC)
	CMPI.w	#9, D0
	BCS.b	Draw_car_result_time_value_Small
	MOVE.w	#$87EC, D0
	BRA.b	Draw_car_result_time_value_Write
Draw_car_result_time_value_Small:
	ADDI.w	#$87C1, D0
Draw_car_result_time_value_Write:
	MOVE.w	D0, (A5)
	MOVE.w	#$87EC, (A5)
	RTS
Draw_car_result_time_columns_Retired:
	ADDQ.w	#7, A0
	MOVE.w	D6, D5
	ADDI.w	#$FF9A, D6
	LEA	Car_result_retired_tilemap(PC), A6
	JSR	Draw_packed_tilemap_to_vdp_preset_base
	ADDI.w	#$0018, D6
	JSR	Draw_packed_tilemap_to_vdp_preset_base
	MOVE.w	D5, D6
	RTS
Draw_car_result_time_columns_Skip:
	ADDQ.w	#3, A0
	MOVE.w	D6, D5
	ADDI.w	#$FFAA, D6
	LEA	Car_result_retired_tilemap(PC), A6
	ADDQ.b	#1, D0
	BEQ.b	Draw_car_result_time_columns_Draw
	LEA	Car_result_dots_tilemap(PC), A6
	ADDQ.w	#8, D6
Draw_car_result_time_columns_Draw:
	JSR	Draw_packed_tilemap_to_vdp_preset_base
	MOVE.w	D5, D6
	RTS
Draw_car_result_position_tile:
	MOVEQ	#0, D0
	MOVE.b	(A0)+, D0
	BNE.b	Draw_car_result_position_tile_Nonzero
	LEA	Nationality_tile_pair_blank(PC), A1
	MOVE.w	D6, D7
	ADDI.w	#$FF94, D7
	BRA.b	Draw_car_result_nationality_tile_Write
Draw_car_result_position_tile_Nonzero:
	ADDQ.w	#1, D0
	JSR	Binary_to_decimal
	MOVE.w	D1, D0
	MOVEQ	#2, D1
	MOVEQ	#$00000014, D2
	JMP	Render_number_tiles_at_row_col(PC)
Draw_car_result_nationality_tile:
	LEA	Nationality_tile_pair_table(PC), A1
	MOVEQ	#0, D0
	MOVE.b	(A0)+, D0
	ADD.w	D0, D0
	ADD.w	D0, D0
	ADDA.w	D0, A1
	MOVE.w	D6, D7
	ADDI.w	#$FFC2, D7
Draw_car_result_nationality_tile_Write:
	JSR	Set_vdp_command_from_tile_index(PC)
	MOVE.l	(A1), (A5)
	RTS
;Render_number_tiles_at_row_col
Render_number_tiles_at_row_col:
	MOVE.w	D6, D7
	SUBI.w	#$0080, D7
	ADD.w	D2, D7
	MOVE.w	#$C7C0, D4
;Render_packed_digits_to_vdp
Render_packed_digits_to_vdp:
	JSR	Set_vdp_command_from_tile_index(PC)
	LEA	Digit_scratch_buf.w, A1
	MOVE.l	D0, (A1)
	MOVEQ	#8, D2
	SUB.w	D1, D2
	LSR.w	#1, D2
	ADDA.w	D2, A1
	LSR.w	#1, D1
	SUBQ.w	#1, D1
	MOVEQ	#$0000000F, D2
	MOVEQ	#0, D3
Render_packed_digits_to_vdp_Loop:
	MOVE.b	(A1)+, D0
	BSR.b	Write_digit_tile_nibble
	TST.w	D1
	BNE.b	Render_packed_digits_to_vdp_Body
	MOVEQ	#1, D3
Render_packed_digits_to_vdp_Body:
	BSR.b	Write_digit_tile_nibble
	DBF	D1, Render_packed_digits_to_vdp_Loop
	RTS
;Write_digit_tile_nibble
Write_digit_tile_nibble:
	ROR.b	#4, D0
	MOVE.w	D0, D5
	AND.w	D2, D5
	BNE.b	Write_digit_tile_nibble_Nonzero
	TST.w	D3
	BNE.b	Write_digit_tile_nibble_Leading_ok
	BRA.b	Write_digit_tile_nibble_Write
Write_digit_tile_nibble_Nonzero:
	MOVEQ	#1, D3
Write_digit_tile_nibble_Leading_ok:
	ADD.w	D4, D5
Write_digit_tile_nibble_Write:
	MOVE.w	D5, (A5)
	RTS
	MOVE.w	#8, $2A(A0)
Car_intro_object_Cooldown:
	SUBQ.w	#1, $36(A0)
	BMI.b	Car_intro_object_Cooldown_Done
	RTS
Car_intro_object_Cooldown_Done:
	MOVE.l	#Car_intro_object_Spin, (A0)
	MOVE.w	#$0100, $C(A0)
	CLR.w	$E(A0)
Car_intro_object_Spin:
	ADDQ.w	#1, $E(A0)
	MOVE.w	$E(A0), D0
	CMPI.w	#$00A1, D0
	BHI.b	Car_intro_object_Spin_Done
	CMPI.w	#$0090, D0
	BNE.b	Car_intro_object_Spin_Body
	MOVE.w	$2A(A0), $00FF5AC2
Car_intro_object_Spin_Body:
	LEA	Ai_screen_y_table, A1
	MOVE.b	(A1,D0.w), D1
	EXT.w	D1
	ADD.w	D1, D1
	LEA	Road_scale_table.w, A1
	MOVE.w	(A1,D1.w), $16(A0)
	LEA	Road_scanline_x_buf.w, A1
	MOVE.w	(A1,D1.w), $18(A0)
	LEA	Ai_screen_x_to_angle_table, A1
	MOVE.b	(A1,D0.w), D0
	LEA	Car_intro_sprite_frame_table, A1
	MOVE.l	(A1,D0.w), $4(A0)
	JMP	Queue_object_for_sprite_buffer
Car_intro_object_Spin_Done:
	MOVE.l	#Car_intro_object_Cooldown, (A0)
	MOVE.w	#$0078, $36(A0)
	RTS
;Championship_mode_init
Championship_mode_init:
	JSR	Fade_palette_to_black
	JSR	Initialize_h40_vdp_state
	JSR	Clear_main_object_pool
	JSR	Initialize_race_track_scroll_tables(PC)
	MOVE.w	#$8200, VDP_control_port
	MOVE.w	#$8300, VDP_control_port
	MOVE.w	#$9011, VDP_control_port
	MOVE.w	#$9206, VDP_control_port
	MOVE.l	#$941F93FF, D6
	MOVE.l	#$40000080, D7
	JSR	Start_vdp_dma_fill
	BTST.b	#2, Player_state_flags.w
	BNE.b	Championship_mode_init_Restored
	JSR	Sort_and_apply_championship_standings(PC)
Championship_mode_init_Restored:
	JSR	Draw_team_driver_lineup(PC)
	MOVEQ	#$0000000F, D0
	LEA	Driver_points_by_team.w, A0
Championship_mode_init_Clear_loop:
	CLR.b	(A0)+
	DBF	D0, Championship_mode_init_Clear_loop
	CLR.w	Track_index.w
	MOVE.b	Player_state_flags.w, D0
	ANDI.b	#$FC, D0
	MOVE.b	D0, Player_state_flags.w
	MOVE.l	#$00004F5C, Ai_car_array.w
	MOVE.w	#$00F8, Anim_delay.w
	MOVE.w	#$000A, Selection_count.w
	MOVE.l	#$0000509C, Frame_callback.w
	MOVE.l	#$000003D8, Vblank_callback.w
	ANDI	#$F8FF, SR
	JSR	Wait_for_vblank
	JSR	Wait_for_vblank
	MOVE.w	#Music_pre_race, Audio_music_cmd    ; pre-race briefing music (championship)
	MOVE.w	#1, Vblank_enable.w
	MOVE.w	#$8174, VDP_control_port
	RTS
;$0000509C
Car_selection_frame:
	JSR	Wait_for_vblank
	MOVE.l	#$40000010, VDP_control_port
	MOVE.w	Anim_delay.w, VDP_data_port
	JSR	Update_car_selection_screen(PC)
	JSR	Update_objects_and_build_sprite_buffer
	MOVE.w	Anim_delay.w, D0
	TST.w	Temp_distance.w
	BEQ.b	Car_selection_frame_Down_step
	MOVE.b	Input_click_bitset.w, D1
	ANDI.w	#$00F0, D1 ; Keys A+B+C+Start
	BEQ.b	Car_selection_frame_Up_check
	MOVE.l	#$0000D6E2, Frame_callback.w
	RTS
Car_selection_frame_Up_check:
	BTST.b	#KEY_UP, Input_state_bitset.w
	BEQ.b	Car_selection_frame_Down_check
	ADDQ.w	#1, D0
	CMPI.w	#$0060, D0
	BLS.b	Car_selection_store_scroll
	SUBQ.w	#1, D0
	BRA.b	Car_selection_store_scroll
Car_selection_frame_Down_check:
	BTST.b	#KEY_DOWN, Input_state_bitset.w
	BEQ.b	Car_selection_frame_Rts
Car_selection_frame_Down_step:
	SUBQ.w	#1, D0
	BPL.b	Car_selection_store_scroll
	MOVE.w	#$FFFF, Temp_distance.w
	MOVEQ	#0, D0
Car_selection_store_scroll:
	MOVE.w	D0, Anim_delay.w
Car_selection_frame_Rts:
	RTS
Initialize_default_lap_times:
; Copy ROM default BCD lap-time records into RAM.
;
; Copies the per-track default best-lap and target-lap time data from ROM
; (Default_lap_time_data) into the Track_lap_time_records block in work RAM.
;
; First pass ($24 iterations = 36 tracks × 4 bytes):
;   Each 4-byte RAM record is filled as: 0x00, rom_byte0, rom_byte1, 0x00.
;   (Minutes=0, seconds=BCD, frames=BCD, sub=0.)
;
; Second pass ($24 iterations = 36 longwords):
;   Copy 36 longwords verbatim (target-lap time table data).
;
; Called once during first-boot initialization before the warm-reboot path.
	LEA	Default_lap_time_data(PC), A0
	LEA	Track_lap_time_records.w, A1 ; base of per-track BCD lap-time records block
	MOVEQ	#$00000023, D0
Initialize_default_lap_times_Loop1:
	CLR.b	(A1)+
	MOVE.b	(A0)+, (A1)+
	MOVE.b	(A0)+, (A1)+
	CLR.b	(A1)+
	DBF	D0, Initialize_default_lap_times_Loop1
	MOVEQ	#$00000023, D0
Initialize_default_lap_times_Loop2:
	MOVE.l	(A0)+, (A1)+
	DBF	D0, Initialize_default_lap_times_Loop2
	RTS
;Write_tile_vdp_command_to_slot
Write_tile_vdp_command_to_slot:
	JSR	Tile_index_to_vdp_command
	MOVE.l	D7, $4(A5)
	ADDQ.w	#1, A2
	SUBQ.w	#1, D1
	RTS
;Copy_tile_bytes_to_slot
Copy_tile_bytes_to_slot:
	MOVEQ	#0, D0
	MOVE.b	(A2)+, D0
	CMPI.w	#$00FF, D0
	BNE.b	Copy_tile_bytes_to_slot_Add
	TST.w	D2
	BNE.b	Copy_tile_bytes_to_slot_Rts
	MOVEQ	#0, D0
	BRA.b	Copy_tile_bytes_to_slot_Write
Copy_tile_bytes_to_slot_Add:
	ADD.w	D4, D0
Copy_tile_bytes_to_slot_Write:
	MOVE.w	D0, (A5)
	DBF	D1, Copy_tile_bytes_to_slot
Copy_tile_bytes_to_slot_Rts:
	RTS
Draw_team_driver_lineup:
	LEA	Lineup_header_tilemap(PC), A6
	JSR	Draw_packed_tilemap_to_vdp
	LEA	VDP_data_port, A5
	MOVE.w	#$0306, D6
	MOVEQ	#0, D5
Draw_team_driver_lineup_Loop:
	MOVE.w	#$87C0, D4
	MOVE.b	Player_team.w, D0
	ANDI.w	#$000F, D0
	CMP.w	D0, D5
	BNE.b	Draw_team_driver_lineup_Other
	MOVEQ	#$00000010, D0
	MOVE.w	#$C7C0, D4
	BRA.b	Draw_team_driver_lineup_Draw
Draw_team_driver_lineup_Other:
	LEA	Drivers_and_teams_map.w, A0
	MOVE.b	(A0,D5.w), D0
	ANDI.w	#$000F, D0
	BTST.b	#6, Player_team.w
	BEQ.b	Draw_team_driver_lineup_Draw
	SUBQ.w	#1, D0
Draw_team_driver_lineup_Draw:
	JSR	Load_driver_name_text_pointer
	MOVE.w	D6, D7
	ADDI.w	#$0016, D7
	JSR	Write_tile_vdp_command_to_slot(PC)
	JSR	Copy_tile_bytes_to_slot(PC)
	MOVEA.l	(A1)+, A2
	MOVE.w	(A1)+, D1
	MOVE.w	D6, D7
	ADDI.w	#$002C, D7
	JSR	Write_tile_vdp_command_to_slot(PC)
	MOVEQ	#0, D2
	JSR	Copy_tile_bytes_to_slot(PC)
	MOVE.w	D5, D0
	JSR	Load_car_spec_text_pointer
	MOVE.w	D6, D7
	JSR	Write_tile_vdp_command_to_slot(PC)
	MOVEQ	#-1, D2
	JSR	Copy_tile_bytes_to_slot(PC)
	ADDI.w	#$0100, D6
	ADDQ.w	#1, D5
	CMPI.w	#$0010, D5
	BNE.b	Draw_team_driver_lineup_Loop
	RTS
Sort_and_apply_championship_standings:
	JSR	Sort_championship_standings(PC)
	LEA	Score_scratch_buf.w, A0
	LEA	Standings_team_order_tmp.w, A1
	LEA	Drivers_and_teams_map.w, A2
	MOVE.b	Player_team.w, D7
	ANDI.w	#$00F0, D7
	MOVEQ	#0, D0
Sort_and_apply_championship_standings_Loop:
	MOVEQ	#0, D1
	MOVE.b	(A0)+, D1
	BPL.b	Sort_and_apply_championship_standings_Named
	OR.w	D0, D7
	MOVE.b	D7, Player_team.w
	MOVEQ	#0, D1
	BRA.b	Sort_and_apply_championship_standings_Store
Sort_and_apply_championship_standings_Named:
	MOVE.b	(A2,D1.w), D1
	ANDI.w	#$000F, D1
Sort_and_apply_championship_standings_Store:
	MOVE.b	D1, (A1)+
	ADDQ.w	#1, D0
	CMPI.w	#$0010, D0
	BNE.b	Sort_and_apply_championship_standings_Loop
	LEA	Standings_team_order_tmp.w, A0
	LEA	Drivers_and_teams_map.w, A1
	MOVEQ	#$0000000F, D0
Sort_and_apply_championship_standings_Copy_loop:
	MOVE.b	(A0)+, (A1)+
	DBF	D0, Sort_and_apply_championship_standings_Copy_loop
	RTS
Lineup_header_tilemap:
	dc.b	$01, $04, $FB, $C7, $C0
	txt "-------", $FA
	txt "NEXT", $FA
	txt "YEAR'S", $FA
	txt "LINE", $FA
	txt "UP", $FA
	txt "--------", $FC
	dc.b $FB, $A7, $C0, $FA
	txt "TEAM"
	dc.b $FA, $FA, $FA, $FA, $FA, $FA, $FA
	txt "DRIVER"
	dc.b	$FA, $FA, $FA, $FA, $FA
	txt "NATIONALITY", $FF
Championship_driver_asset_list:
	dc.b	$00, $05
	dc.b	$32, $80
	dc.l	Championship_driver_tiles_2
	dc.b	$20, $00
	dc.l	Championship_driver_tiles
	dc.b	$00, $20
	dc.l	Championship_driver_screen_tiles
	dc.b	$06, $00
	dc.l	Championship_screen_tiles
	dc.b	$95, $80
	dc.l	Race_hud_tiles_a
	dc.b	$0B, $E0
	dc.l	Race_hud_tiles
Championship_driver_palette_data:
	dc.b	$02, $0E, $00, $00, $0E, $EE, $00, $AE, $06, $E2, $02, $22, $04, $44, $06, $66, $08, $88, $0A, $AA, $0C, $CC, $0E, $EE, $00, $AC, $00, $08, $00, $0C, $08, $22
	dc.b	$22, $01, $00, $00, $02, $2E, $42, $01, $00, $00, $00, $CE, $60, $0F, $08, $AA, $02, $22, $04, $44, $04, $66, $04, $68, $06, $88, $08, $AA, $0A, $AA, $04, $44
	dc.b	$00, $00, $02, $44, $06, $8A, $02, $46, $00, $00, $00, $00, $00, $00
Nationality_tile_pair_table:
	dc.l	$C7CAC7DD
	dc.l	$C7C4C7DC
	dc.l	$C7C7C7DC
Nationality_tile_pair_blank:
	dc.l	$C7D9C7D9
Qualifying_time_thresholds:
	dc.w	$3500, $2500, $1000, $0200
Qualifying_rank_position_data:
	dc.b	$1C, $0A, $00, $00, $0A, $00, $00, $0B, $00, $00, $0C, $00, $00, $0D, $00
Car_result_retired_tilemap:
	dc.b	$FB, $C7, $C0
	txt "RETIRED", $FF
Car_result_dots_tilemap:
	dc.b	$FB, $C7, $C0, $2C, $2C, $FF
Position_text_1_4:
	txt "1ST"
	txt "2ND"
	txt "3RD"
	txt "4TH"
Position_text_5_9:
	txt "5TH"
	txt "6TH"
	txt "7TH"
	txt "8TH"
	txt "9TH"
Car_result_column_tilemap:
	dc.b	$FB, $80, $01, $00, $01, $01, $01, $02, $01, $01, $01, $01, $02, $01, $01, $02, $01, $01, $01, $01, $01, $01, $01, $02, $01, $01, $01, $01, $01, $01, $01, $02
	dc.b	$01, $01, $01, $03, $01, $01, $04, $FD, $05, $06, $07, $08, $09, $0A, $0B, $0C, $0D, $0E, $0F, $10, $11, $12, $13, $14, $15, $16, $17, $18, $05, $19, $1A, $1B
	dc.b	$15, $16, $17, $18, $1C, $1D, $1E, $1F, $20, $21, $22, $05, $FD, $FF
Car_result_column_tilemap_3_laps:
	dc.b	$FB, $80, $01, $00, $01, $01, $01, $02, $01, $01, $01, $01, $02, $01, $01, $02, $01, $01, $01, $01, $01, $01, $01, $02, $01, $01, $01, $01, $01, $01, $01, $02
	dc.b	$01, $01, $01, $03, $01, $01, $04, $FD, $FF
Car_result_column_tilemap_5_laps:
	dc.b	$FB, $80, $01, $00, $01, $01, $01, $02, $01, $01, $01, $01, $02, $01, $01, $02, $01, $01, $01, $25, $26, $27, $01, $02, $01, $01, $01, $01, $01, $01, $01, $02
	dc.b	$01, $01, $01, $03, $01, $01, $04, $FD, $FF
Car_result_column_tilemap_7_laps:
	dc.b	$FB, $80, $01, $00, $01, $01, $01, $02, $01, $01, $01, $01, $02, $01, $01, $02, $01, $01, $01, $25, $26, $27, $01, $02, $01, $01, $01, $25, $26, $27, $01, $02
	dc.b	$01, $01, $01, $03, $01, $01, $04, $FD, $FF
Car_result_grid_tilemap:
	dc.b	$FB, $80, $01, $2B, $01, $01, $01, $2C, $01, $01, $01, $01, $2C, $01, $01, $2C, $01, $01, $01, $01, $01, $01, $01, $2C, $01, $01, $01, $01, $01, $01, $01, $2C
	dc.b	$01, $01, $01, $2D, $01, $01, $2E, $FF
Car_result_shading_tilemap:
	dc.b	$FB, $80, $01, $05, $18, $18, $18, $05, $18, $18, $18, $18, $05, $18, $18, $05, $18, $18, $18, $18, $18, $18, $18, $05, $18, $18, $18, $18, $18, $18, $18, $05
	dc.b	$18, $18, $18, $2A, $18, $18, $05, $FD, $FF
Car_result_row_tilemap:
	dc.b	$FB, $80, $01, $23, $01, $01, $01, $24, $01, $01, $01, $01, $24, $01, $01, $24, $01, $01, $01, $01, $01, $01, $01, $24, $01, $01, $01, $01, $01, $01, $01, $24
	dc.b	$01, $01, $01, $28, $01, $01, $29, $FD, $FF
Car_result_row_tilemap_active_a:
	dc.b	$FB, $80, $01, $23, $01, $01, $01, $24, $01, $01, $01, $01, $24, $01, $01, $24, $01, $01, $01, $25, $26, $27, $01, $24, $01, $01, $01, $01, $01, $01, $01, $24
	dc.b	$01, $01, $01, $28, $01, $01, $29, $FD, $FF
Car_result_row_tilemap_active_ab:
	dc.b	$FB, $80, $01, $23, $01, $01, $01, $24, $01, $01, $01, $01, $24, $01, $01, $24, $01, $01, $01, $25, $26, $27, $01, $24, $01, $01, $01, $25, $26, $27, $01, $24
	dc.b	$01, $01, $01, $28, $01, $01, $29, $FD, $FF
Initials_entry_cursor_tile_offset_table:
	dc.b	$00, $02, $04, $06, $08, $0A
	dc.b	$0C, $0E, $10, $12, $14, $16, $18, $1A, $1C, $1E, $20, $22, $24, $26, $28, $2A, $2C, $2E, $30, $32, $38, $36
	dc.b	$34
	dc.b	$00
Name_entry_frame_tilemap:
	dc.b	$E8, $0C, $FB, $A0, $99
Initials_entry_cursor_to_char_table:
	dc.b	$00, $02, $04, $06, $08, $0A, $0C, $0E, $10, $12, $14, $16, $18, $1A, $1C, $1E, $20, $22, $24, $26, $28, $2A, $2C, $2E, $30, $32, $3E, $36, $34, $FD, $01, $03
	dc.b	$05, $07, $09, $0B, $0D, $0F, $11, $13, $15, $17, $19, $1B, $1D, $1F, $21, $23, $25, $27, $29, $2B, $2D, $2F, $31, $33, $3F, $37, $35, $FF, $00
Default_lap_time_data:
	dc.b	$01, $29, $07, $25, $01, $33, $07, $45, $01, $21, $06, $45, $01, $29, $07, $25, $01, $33, $07, $45, $01, $32, $07, $40, $01, $30, $07, $30, $01, $29, $07, $25
	dc.b	$01, $31, $07, $35, $01, $30, $07, $30, $01, $31, $07, $35, $01, $28, $07, $20, $01, $39, $08, $15, $01, $37, $08, $05, $01, $21, $06, $45, $01, $27, $07, $15
	dc.b	$00, $55, $00, $00, $01, $30, $04, $30
	dc.b	$21, $34, $00, $02, $00, $03, $12, $47, $04, $03, $28, $00, $14, $12, $1D, $00, $20, $34, $01, $01, $01, $03, $28, $40, $07, $03, $28, $40, $14, $0A, $14, $00
	dc.b	$19, $89, $01, $02, $02, $03, $12, $47, $FF, $00, $00, $00, $22, $0A, $16, $00, $13, $28, $04, $02, $00, $03, $12, $47, $04, $03, $28, $00, $1E, $20, $0A, $00
	dc.b	$12, $22, $0E, $02, $00, $03, $28, $40, $04, $03, $28, $40, $20, $0A, $14, $00, $12, $20, $07, $00, $02, $03, $12, $47, $04, $03, $28, $00, $11, $0A, $16, $00
	dc.b	$12, $19, $01, $00, $02, $03, $12, $47, $04, $03, $28, $00, $11, $12, $1B, $00, $10, $30, $09, $00, $FF, $00, $00, $00, $80, $00, $00, $00, $1D, $0A, $17, $00
	dc.b	$10, $00, $00, $02, $FF, $00, $00, $00, $80, $00, $00, $00, $10, $0E, $1B, $00
;$00005616
; Title_menu_frame — per-frame handler for the track-selection sub-screen shown in the
; championship path (from Championship_start_init).  Updates sprites and decrements
; Screen_subcounter.  On directional input adjusts Track_index; on button press routes
; to Options_screen_init (confirm selection) or Title_menu (cancel/back).
Title_menu_frame:
	JSR	Wait_for_vblank
	JSR	Update_objects_and_build_sprite_buffer
	SUBQ.w	#1, Screen_subcounter.w
	BSR.b	Title_menu_frame_Update
	RTS
Title_menu_frame_Update:
	MOVE.w	Screen_scroll.w, D0
	BPL.b	Title_menu_frame_Update_Rts
	MOVE.b	Input_click_bitset.w, D0
	MOVE.b	D0, D1
	BEQ.b	Title_menu_frame_Update_Rts
	BTST.b	#KEY_B, Input_click_bitset.w
	BNE.b	Title_menu_frame_Update_Back
	ANDI.b	#9, D0
	BNE.b	Title_menu_frame_Update_Next
	ANDI.b	#6, D1
	BNE.b	Title_menu_frame_Update_Prev
	MOVE.l	#$00003800, Saved_frame_callback.w
	MOVE.l	#Options_screen_init, Frame_callback.w
	CLR.w	Selection_count.w
Title_menu_frame_Update_Rts:
	RTS
Title_menu_frame_Update_Back:
	MOVE.w	#9, Selection_count.w
	MOVE.l	#Title_menu, Frame_callback.w
	RTS
Title_menu_frame_Update_Next:
	ADDQ.w	#1, Track_preview_index.w
	BRA.b	Title_menu_frame_Update_Wrap
Title_menu_frame_Update_Prev:
	SUBQ.w	#1, Track_preview_index.w
Title_menu_frame_Update_Wrap:
	ANDI.w	#$000F, Track_preview_index.w
	MOVE.w	Track_preview_index.w, Track_index.w
	MOVE.w	#$000F, Screen_scroll.w
	RTS
;$00005690
; Championship_start_init — entry point when the player selects WORLD CHAMPIONSHIP from
; the title menu.  Clears Player_team, fades to black, inits H32 VDP, clears objects.
; Sets Selection_count=$000E (Music_championship_start), Use_world_championship_tracks=1.
; Decompresses the championship intro tilemaps, loads the scrolling team-logo strip,
; and installs Title_menu_frame as the per-frame callback.
Championship_start_init:
	MOVE.b	#0, Player_team.w
	JSR	Fade_palette_to_black
	JSR	Initialize_h32_vdp_state
	JSR	Clear_main_object_pool
	MOVE.w	#$000E, Selection_count.w
	MOVE.w	#$9003, VDP_control_port
	MOVE.w	#1, Use_world_championship_tracks.w
	MOVE.w	Track_preview_index.w, Track_index.w
	MOVE.w	#8, D0
Championship_start_init_Clear_loop:
	MOVE.l	#0, VDP_data_port
	DBF	D0, Championship_start_init_Clear_loop
	LEA	Championship_start_tilemap, A0
	MOVE.w	#$0082, D0
	MOVE.l	#$40000003, D7
	MOVE.w	#$001F, D6
	MOVE.w	#$0011, D5
	JSR	Decompress_tilemap_to_vdp_128_cell_rows
	LEA	Championship_logo_buf.w, A6
	MOVE.l	#$64800003, D7
	MOVE.w	#$001F, D6
	MOVE.w	#9, D5
	JSR	Draw_tilemap_buffer_to_vdp_32_cell_rows
	LEA	Championship_start_curve_data, A0
	LEA	Curve_data, A4
	JSR	Decompress_to_ram
	MOVE.l	#$46400000, VDP_control_port
	LEA	Race_hud_tiles, A0
	JSR	Decompress_to_vdp
	MOVE.l	#$50400000, VDP_control_port
	LEA	Championship_start_tiles, A0
	JSR	Decompress_to_vdp
	LEA	Championship_start_text_tilemap, A6
	JSR	Draw_packed_tilemap_to_vdp
	BSR.w	Load_track_preview_data
	MOVE.w	#$E486, D7
	MOVE.w	#$0019, D0
	MOVE.w	#8, D1
	MOVE.w	#1, D2
	BSR.w	Fill_vram_rect
	MOVE.w	#$E186, D7
	MOVE.w	#6, D0
	MOVE.w	#$000A, D1
	MOVE.w	#1, D2
	BSR.w	Fill_vram_rect
	MOVE.l	#$40200000, VDP_control_port
	MOVE.w	#7, D0
Championship_start_init_Fill_loop:
	MOVE.l	#$FFFFFFFF, VDP_data_port
	DBF	D0, Championship_start_init_Fill_loop
	LEA	Championship_start_palette_stream, A6
	JSR	Copy_word_run_from_stream
	MOVE.w	#$0014, Screen_timer.w
	MOVE.w	#7, Screen_scroll.w
	MOVE.w	Saved_shift_type.w, Shift_type.w
	MOVE.w	#1, Use_world_championship_tracks.w
	CLR.w	Track_index_arcade_mode.w
	MOVE.w	#1, Practice_mode.w
	CLR.w	Warm_up.w
	MOVE.w	#1, Practice_flag.w
	MOVE.w	#Engine_data_offset_practice, Engine_data_offset.w
	CLR.w	Acceleration_modifier.w
	MOVE.l	#Title_menu_frame, Frame_callback.w
	MOVE.l	#$0000584E, Vblank_callback.w
	JSR	Halt_audio_sequence
	ANDI	#$F8FF, SR
	JSR	Wait_for_vblank
	JSR	Wait_for_vblank
	MOVE.w	Selection_count.w, Audio_music_cmd ; song = Music_championship_start (14)
	CLR.w	Selection_count.w
	JSR	Trigger_music_playback
	MOVE.w	#1, Vblank_enable.w
	MOVE.w	#$8174, VDP_control_port
	RTS

;Fill_vram_rect
Fill_vram_rect:
	MOVEM.w	D7/D2/D1/D0, -(A7)
	LSL.w	#6, D1
	ADD.w	D1, D7
	JSR	Tile_index_to_vdp_command
	MOVE.l	D7, VDP_control_port
Fill_vram_rect_Loop:
	MOVE.w	D2, VDP_data_port
	DBF	D0, Fill_vram_rect_Loop
	MOVEM.w	(A7)+, D0-D2/D7
	DBF	D1, Fill_vram_rect
	RTS
;$0000584E
Race_preview_vblank_handler:
	JSR	Upload_h32_tilemap_buffer_to_vram
	JSR	Update_input_bitset
	JSR	Upload_palette_buffer_to_cram
	MOVE.l	#$6A400003, VDP_control_port
	MOVE.w	Screen_subcounter.w, D0
	LSR.w	#1, D0
	MOVE.w	#$00B0, D1
Race_preview_vblank_Fill_loop:
	MOVE.l	D0, VDP_data_port
	DBF	D1, Race_preview_vblank_Fill_loop
	CLR.l	D0
	MOVE.w	Screen_scroll.w, D0
	BMI.b	Race_preview_vblank_Rts
	SUBQ.w	#1, Screen_timer.w
	BNE.b	Race_preview_vblank_Rts
	MOVE.w	#2, Screen_timer.w
	LEA	Curve_data, A1
	MOVE.l	#$40200000, VDP_control_port
	LSL.l	#5, D0
	MOVE.w	#7, D1
Race_preview_vblank_Copy_loop:
	MOVE.l	(A1,D0.w), VDP_data_port
	ADDQ.l	#4, D0
	DBF	D1, Race_preview_vblank_Copy_loop
	SUBQ.w	#1, Screen_scroll.w
	CMPI.w	#7, Screen_scroll.w
	BEQ.b	Load_track_preview_data
Race_preview_vblank_Rts:
	RTS
Load_track_preview_data:
	JSR	Load_track_data_pointer
	MOVEA.l	(A1)+, A0 ; tiles used for minimap
	MOVE.l	#$40400000, VDP_control_port
	JSR	Decompress_to_vdp
	JSR	Load_track_data_pointer
	LEA	$C(A1), A1 ; tile mapping for minimap
	MOVEA.l	(A1)+, A0
	MOVE.l	#$46060003, D7
	MOVE.w	#1, D1
	MOVE.w	#0, D0
	MOVEQ	#6, D6
	MOVEQ	#$0000000A, D5
	JSR	Decompress_tilemap_128cell_with_base
	JSR	Load_track_data_pointer
	MOVEA.l	$4(A1), A0 ; tiles used for background
	MOVE.l	#$70000002, VDP_control_port
	JSR	Decompress_to_vdp
	MOVEA.l	$8(A1), A0
	MOVE.w	#$6000, D0
	JSR	Decompress_tilemap_to_buffer
	JSR	Build_car_tilemap_buffers
	LEA	Decomp_stream_buf.w, A6
	MOVE.l	#$52000003, D7
	MOVE.w	#$00BF, D6
	MOVE.w	#8, D5
	JSR	Draw_tilemap_buffer_to_vdp_128_cell_rows
	CLR.l	D0
	LEA	Track_preview_tilemap_data, A6
	MOVE.w	Track_preview_index.w, D0
	MULS.w	#$003B, D0
	ADDA.l	D0, A6
	LEA	VDP_data_port, A5
	MOVE.w	#$E198, D6
	MOVE.w	#$2032, D0
	JSR	Draw_packed_tilemap_to_vdp_preset_base
	JSR	Load_track_data_pointer
	MOVEA.l	$10(A1), A6 ; background palette
	MOVEQ	#$00000060, D0
	MOVEQ	#$0000000A, D1
	JSR	Copy_word_run_to_buffer
	CLR.w	Screen_subcounter.w
	MOVE.l	#$636A0003, VDP_control_port
	MOVEA.l	$3C(A1), A2
	MOVE.w	#$2000, D3
Draw_bcd_time_to_vdp:
; Format a BCD lap/race time longword from (A2) into a 4-longword tile buffer
; at $FFFFE85C via Format_bcd_time_to_tile_buffer, then write those 16 bytes
; directly to VDP_data_port to update the on-screen time display.
; The VDP must already be positioned to the correct VRAM row by the caller
; (via a prior VDP_control_port write, e.g. $61460003).
; Inputs:
;  A2 = pointer to BCD time longword (minutes/seconds/centiseconds packed)
;  D3 = tile attribute word (palette / priority bits ORed into tile indices)
	MOVE.l	(A2), D0
	LEA	(Digit_tilemap_buf+$5C).w, A3
	JSR	Format_bcd_time_to_tile_buffer
	MOVE.l	(A3)+, VDP_data_port
	MOVE.l	(A3)+, VDP_data_port
	MOVE.l	(A3)+, VDP_data_port
	MOVE.l	(A3)+, VDP_data_port
	RTS
; Update_shift - process gear shift input and update Player_shift / Player_rpm
;
; Called from Race_loop step 6 (drive model update, skipped when retired).
; Dispatches on Shift_type: Automatic (0), 4-shift (1), or 7-shift (2).
;
; Automatic mode:
;   - Manual shift-down key overrides automatic logic (shift down unconditionally).
;   - Auto-upshift when Player_rpm > 1300.
;   - Auto-downshift per gear: shift 1 at rpm < 649, shift 2 at rpm < 865, shift 3 at rpm < 974.
; Manual modes (4-shift / 7-shift):
;   - Respond to button *clicks* (not holds) for both up and down shifts.
;   - Top gear is clamped (shift 3 for 4-shift, shift 6 for 7-shift).
;
; On any gear change, Player_rpm is adjusted to preserve the RPM ratio:
;   upshift:   new_rpm = old_rpm * new_gear / (new_gear + 1)
;   downshift: new_rpm = old_rpm * (old_gear + 1) / old_gear
;
; After a manual shift, queues a tilemap draw to update the on-screen gear indicator.
Update_shift:
	MOVE.b	Control_key_shift_down.w, D5
	MOVE.b	Control_key_shift_up.w, D6
	MOVE.w	Shift_type.w, D0
	ASL.w	#2, D0
	JMP	Update_shift_Dispatch(PC,D0.w) ; Jump based on shift type
Update_shift_Dispatch:
	BRA.w	Update_shift_Auto
	BRA.w	Update_shift_4speed
	BRA.w	Update_shift_7speed
Update_shift_Auto: ; Jump to when shift type is Automatic
	BTST.b	D5, Input_state_bitset.w ; if shift down key pressed
	BNE.w	Update_shift_Down                 ; then shift down (even in automatic!)
	MOVE.w	#3, D0
	CMPI.w	#1300, Player_rpm.w      ; else if rpm > 1300
	BCC.b	Update_shift_Up          ; then shift up
	LEA	Update_shift_Auto_dispatch, A1                 ; else perform automatic shift down check ...
	MOVE.w	Player_shift.w, D0
	ASL.w	#2, D0
	JMP	(A1,D0.w)
Update_shift_Auto_dispatch:
	BRA.w	Update_shift_Return ; shift is 0 (RTS)
	BRA.w	Update_shift_Auto_chk_1 ; shift is 1
	BRA.w	Update_shift_Auto_chk_2 ; shift is 2
	BRA.w	Update_shift_Auto_chk_3 ; shift is 3
Update_shift_Auto_chk_1:
	CMPI.w	#649, Player_rpm.w ; automatic shift down RPM threshold for shift 1
	BCS.b	Update_shift_Down
	RTS
Update_shift_Auto_chk_2:
	CMPI.w	#865, Player_rpm.w ; automatic shift down RPM threshold for shift 2
	BCS.b	Update_shift_Down
	RTS
Update_shift_Auto_chk_3:
	CMPI.w	#974, Player_rpm.w ; automatic shift down RPM threshold for shift 3
	BCS.b	Update_shift_Down
Update_shift_Return:
	RTS
Update_shift_4speed: ; Jump to when shift type is 4-shift
	MOVE.w	#3, D0 ; Max shift
	BRA.b	Update_shift_Manual
Update_shift_7speed: ; Jump to when shift type is 7-shift
	MOVE.w	#6, D0 ; Max shift
Update_shift_Manual:
	BTST.b	D6, Input_click_bitset.w ; if shift up key clicked
	BNE.b	Update_shift_Up         ; then shift up
	BTST.b	D5, Input_click_bitset.w ; else if shift down key clicked
	BNE.b	Update_shift_Down        ; then shift down
	RTS
Update_shift_Up:
	CMP.w	Player_shift.w, D0 ; if max shift
	BEQ.b	Update_shift_Return        ; then RTS
	ADDQ.w	#1, Player_shift.w ; else shift up
	MOVE.w	Player_rpm.w, D0
	MOVE.w	Player_shift.w, D1
	MULS.w	D1, D0
	ADDQ.w	#1, D1
	DIVS.w	D1, D0
	MOVE.w	D0, Player_rpm.w ; new_rpm = old_rpm * new_shift / (new_shift + 1)
	BRA.b	Update_shift_Gear_changed
;Update_shift_Down
Update_shift_Down:
	CMPI.w	#0, Player_shift.w ; if shift 0
	BEQ.b	Update_shift_Return        ; then RTS
Update_shift_Do_down:
	SUBQ.w	#1, Player_shift.w ; else shift down
	MOVE.w	Player_rpm.w, D0
	MOVE.w	Player_shift.w, D1
	ADDQ.w	#2, D1
	MULS.w	D1, D0
	SUBQ.w	#1, D1
	DIVS.w	D1, D0
	MOVE.w	D0, Player_rpm.w ; new_rpm = old_rpm * (old_shift + 1) / old_shift
Update_shift_Gear_changed:
	MOVE.w	Shift_type.w, D0 ; if automatic shift
	BEQ.b	Update_shift_Gear_auto_rts         ; then RTS
	MOVE.l	#$63820003, D7   ; else ...
	MOVEQ	#5, D6
	MOVEQ	#1, D5
	SUBQ.w	#1, D0
	BEQ.b	Update_shift_Display_gear
	MOVEQ	#2, D5
Update_shift_Display_gear:
	MOVE.w	Player_shift.w, D0
	LSL.w	#2, D0
	LEA	Shift_indicator_tilemap_table, A1
	MOVEA.l	(A1,D0.w), A6
	JSR	Queue_tilemap_draw
Update_shift_Gear_auto_rts:
	RTS ; end of Update_shift
Update_rpm_Crash_decel: ; crash/spin deceleration: rpm -= 30/frame, sync visual, auto-downshift when rpm < 700
	SUBI.w	#30, Player_rpm.w
	BCC.b	Update_rpm_Crash_decel_chk
	CLR.w	Player_rpm.w
	BRA.b	Sync_visual_rpm
Update_rpm_Crash_decel_chk:
	CMPI.w	#700, Player_rpm.w
	BCC.b	Sync_visual_rpm
	TST.w	Player_shift.w
	BEQ.b	Sync_visual_rpm
	BSR.b	Update_shift_Do_down
Sync_visual_rpm:
	MOVE.w	Player_rpm.w, Visual_rpm.w
	RTS
Update_rpm_Pre_race_anim: ; pre-race rev animation: visual_rpm ticks down 60/frame (floor 801); if accel held, rises 120/frame (ceiling 1251)
	LEA	Visual_rpm.w, A1
	ADDI.w	#-60, (A1)
	CMPI.w	#801, (A1)
	BCC.b	Update_rpm_Pre_race_anim_up   ; if visual rpm < 801
	MOVE.w	#801, (A1) ; then visual rpm = 801
Update_rpm_Pre_race_anim_up:
	MOVE.b	Control_key_accel.w, D5
	BTST.b	D5, Input_state_bitset.w ; if accelerate key pressed
	BEQ.b	Update_rpm_Pre_race_anim_rts
	ADDI.w	#120, (A1)
	CMPI.w	#1251, (A1)
	BCS.b	Update_rpm_Pre_race_anim_rts    ; if visual rpm >= 1251
	MOVE.w	#1251, (A1) ; then visual rpm = 1251
Update_rpm_Pre_race_anim_rts:
	RTS
; Update_rpm - simulate engine RPM for this frame
;
; Called from Race_loop step 6 (drive model update, skipped when retired).
; Computes the RPM delta for the current frame and writes it to Player_rpm.
; Falls through to Update_visual_rpm.
;
; Execution path:
;   if Race_started == 0  → Update_rpm_Pre_race_anim: pre-race rev animation only
;   if Spin_off_track_flag → Update_rpm_Crash_decel: crash deceleration (-30/frame), sync visual, then return
;   else:
;     1. Update_rpm_Collision_penalty: collision RPM penalty (Rpm_derivative spike)
;     2. Update_rpm_Slipstream: slipstream / drafting boost from nearby AI cars
;     3. Update_rpm_Slope_drag: track-based RPM modifier (Track_phys_slope_value: hill gradient drag)
;     4. Update_rpm_Collision_speed: obstacle collision deceleration
;     5. If brake key held → skip to Update_visual_rpm (Update_breaking handles RPM)
;     6. Read Acceleration_data[shift_type][shift][rpm/50]:
;          bit 7 set → at/over rev limit; skip acceleration
;          else      → apply Acceleration_modifier scaling (−50%/0/+25%/+50%)
;     7. If Road_marker_state active → subtract road-marker drag from acc
;     8. If accelerate key held → ADD acc to Player_rpm (clamp 0..Engine_rpm_max)
;        else → ADD idle decel (shift − 8, negative for gears 0–7)
;   Falls through to Update_visual_rpm.
