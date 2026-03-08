Update_engine_and_tire_sounds:
; Update the 68K audio engine state for engine and tyre sounds.
; Called once per Race_loop frame (step 24).
;
; This routine writes to the 68K-side audio engine state struct at
; Audio_engine_state ($FF5AC0) to update engine pitch and road-surface SFX.
; The actual Z80 writes happen separately in Update_audio_engine (called from
; the VBI handler, Vblank_interrupt_tail) after the state has been updated here.
;
; Outputs written to audio engine struct (via absolute addresses):
;   Audio_engine_speed ($FF5AC4):  scaled Player_rpm for engine pitch calculation
;   Audio_engine_flags ($FF5AC6):  incremented to indicate engine-sound cycle
;   Audio_engine_vol_ch1 ($FF5AC8): $00FF = silence engine channel 1
;   Audio_engine_vol_ch2 ($FF5ACC): $00FF = silence engine channel 2
;   Audio_sfx_cmd ($FF5AE0):       SFX command byte for road surface / tyre sound
;
; Engine sound logic:
;   - If Practice_flag = 0 (not in race): silence both channels (vol = $00FF).
;   - If Race_finish_flag set: silence both channels.
;   - Otherwise: write Player_rpm (or Visual_rpm pre-race) to Audio_engine_speed.
;     Update_audio_engine will then compute YM2612 pitch from this value.
;
; Tyre/road sound logic (Update_engine_and_tire_sounds_Road_sfx onward):
;   Determines which road-surface SFX to play based on Road_marker_state and
;   Player_speed.  Writes an SFX ID (0=$0010 asphalt, 1=$0011 rough, 2=$0012 gravel,
;   $0B=collision thud) to Audio_sfx_cmd.  The ID is picked up by Update_audio_engine
;   and forwarded to the Z80 as a sound-effect trigger byte.
	TST.w	Practice_flag.w
	BNE.b	Update_engine_and_tire_sounds_Active
Update_engine_and_tire_sounds_Silence:
	MOVE.w	#$00FF, $00FF5AC8
	MOVE.w	#$00FF, $00FF5ACC
	RTS
Update_engine_and_tire_sounds_Active:
	TST.w	Race_finish_flag.w
	BNE.b	Update_engine_and_tire_sounds_Silence
	TST.w	Track_index_arcade_mode.w
	BEQ.b	Update_engine_and_tire_sounds_Champ_rpm
	TST.w	Race_started.w
	BEQ.b	Update_engine_and_tire_sounds_Road_sfx
	MOVE.w	Player_rpm.w, D0
	BRA.b	Update_engine_and_tire_sounds_Clamp_rpm
Update_engine_and_tire_sounds_Champ_rpm:
	MOVE.w	Player_rpm.w, D0
	TST.w	Race_started.w
	BNE.b	Update_engine_and_tire_sounds_Clamp_rpm
	MOVE.w	Visual_rpm.w, D0
Update_engine_and_tire_sounds_Clamp_rpm:
	MOVE.w	#1536, D1 ; visual rpm max?
	CMP.w	D1, D0
	BLS.b	Update_engine_and_tire_sounds_Write_rpm
	MOVE.w	D1, D0 ; D0 = 1536
Update_engine_and_tire_sounds_Write_rpm:
	MOVE.w	D0, $00FF5AC4
	MOVE.w	Special_road_audio_mode.w, D0
	ADDQ.w	#1, D0
	MOVE.w	D0, Audio_engine_flags
Update_engine_and_tire_sounds_Road_sfx:
	MOVE.w	Road_surface_prev_state.w, D0
	MOVE.w	Road_marker_state.w, D2
	MOVE.w	D2, Road_surface_prev_state.w
	BEQ.b	Update_engine_and_tire_sounds_Off_road
	TST.w	D0
	BNE.b	Update_engine_and_tire_sounds_On_road
	CLR.w	Road_sfx_cooldown.w
Update_engine_and_tire_sounds_On_road:
	CLR.w	Collision_prev_flag.w
	MOVE.w	Player_speed.w, D0
	BEQ.b	Send_collision_sfx
	SUBQ.w	#1, Road_sfx_cooldown.w
	BPL.b	Send_collision_sfx
	LSR.w	#5, D0
	MOVEQ	#5, D1
	SUB.w	D0, D1
	BCS.b	Update_engine_and_tire_sounds_Interval_clamp
	CMPI.w	#1, D1
	BCC.b	Update_engine_and_tire_sounds_Set_interval
Update_engine_and_tire_sounds_Interval_clamp:
	MOVEQ	#1, D1
Update_engine_and_tire_sounds_Set_interval:
	MOVE.w	D1, Road_sfx_cooldown.w
	MOVEQ	#$00000011, D0
	SUBQ.w	#2, D2
	BEQ.b	Update_engine_and_tire_sounds_Write_sfx
	MOVEQ	#$00000012, D0
	TST.w	Horizontal_position.w
	BMI.b	Update_engine_and_tire_sounds_Write_sfx
	MOVEQ	#$00000010, D0
	BRA.b	Update_engine_and_tire_sounds_Write_sfx
Update_engine_and_tire_sounds_Off_road:
	MOVE.w	Collision_prev_flag.w, D0
	MOVE.w	Collision_flag.w, D1
	MOVE.w	D1, Collision_prev_flag.w
	BEQ.b	Send_collision_sfx
	TST.w	D0
	BNE.b	Update_engine_and_tire_sounds_Collision_cooldown
	CLR.w	Collision_sfx_cooldown.w
Update_engine_and_tire_sounds_Collision_cooldown:
	SUBQ.w	#1, Collision_sfx_cooldown.w
	BPL.b	Send_collision_sfx
	MOVE.w	#5, Collision_sfx_cooldown.w
	MOVEQ	#$0000000B, D0
Update_engine_and_tire_sounds_Write_sfx:
	MOVE.w	D0, Audio_sfx_cmd       ; send SFX ID to audio engine
Send_collision_sfx:
	MOVE.w	Overtake_flag.w, D0
	BEQ.b	Update_engine_and_tire_sounds_Overtake_sfx
	MOVE.w	D0, Audio_sfx_cmd       ; send overtake SFX ID to audio engine
	CLR.w	Overtake_flag.w
Update_engine_and_tire_sounds_Overtake_sfx:
	LEA	$00FF5AC8, A4
	LEA	Depth_sort_value.w, A5
	LEA	Depth_sort_leader_ptr.w, A6
	BSR.b	Update_engine_and_tire_sounds_Set_engine_vol
	ADDQ.w	#4, A4
	ADDQ.w	#2, A5
	ADDQ.w	#2, A6
Update_engine_and_tire_sounds_Set_engine_vol:
	MOVE.w	(A5), D0
	BPL.b	Update_engine_and_tire_sounds_Vol_active
Update_engine_and_tire_sounds_Vol_silence:
	MOVE.w	#$00FF, (A4)
	RTS
Update_engine_and_tire_sounds_Vol_active:
	CMPI.w	#$007F, D0
	BCC.b	Update_engine_and_tire_sounds_Vol_silence
	MOVEA.w	(A6), A0
	TST.w	$E(A0)
	BMI.b	Update_engine_and_tire_sounds_Vol_write
	ORI.w	#$0080, D0
Update_engine_and_tire_sounds_Vol_write:
	MOVE.w	D0, (A4)
	MOVEQ	#0, D0
	MOVE.w	Horizontal_position.w, D0
	SUB.w	$12(A0), D0
	SMI	D7
	BPL.w	Update_engine_and_tire_sounds_Pan_clamp
	NEG.w	D0
Update_engine_and_tire_sounds_Pan_clamp:
	LSR.w	#5, D0
	CMPI.w	#7, D0
	BCS.b	Update_engine_and_tire_sounds_Pan_write
	MOVEQ	#7, D0
Update_engine_and_tire_sounds_Pan_write:
	ANDI.w	#8, D7
	OR.w	D7, D0
	MOVE.w	D0, $2(A4)
	RTS
; Sprite frame pointer tables for depth-sorted car rendering.
; Rival variant: indexed from Rival_sprite_depth_frame_ptrs with offset D1 ∈ {-8,-4,0,+4,+8}.
; AI variant:    indexed from Ai_sprite_depth_frame_ptrs  with offset D1 ∈ {-8,-4,0,+4,+8}.
; The two tables share entries at Ai_sprite_depth_frame_ptrs-8 and -4 (= Rival +12 and +16).
	dc.l	Rival_sprite_frames_depth_m8                          ; rival depth -8
	dc.l	Rival_sprite_frames_depth_m4                          ; rival depth -4
Rival_sprite_depth_frame_ptrs:
	dc.l	Rival_sprite_frames_depth0                          ; rival depth  0
	dc.l	Rival_sprite_frames_depth_p4                          ; rival depth +4
	dc.l	Rival_sprite_frames_depth_p8                          ; rival depth +8 / AI depth -8 (shared)
	dc.l	Rival_sprite_frames_depth_p12                          ; rival depth +12 / AI depth -4 (shared)
	dc.l	Ai_sprite_frames_depth0                          ; rival depth +16 / AI depth  0 (shared, = Ai_sprite_depth_frame_ptrs)
Ai_sprite_depth_frame_ptrs:
	dc.l	Ai_sprite_frames_depth_p4                          ; AI depth +4
	dc.l	Ai_sprite_frames_depth_p8                          ; AI depth +8
	dc.l	Ai_sprite_frames_depth_p12                          ; AI depth +12 (unused upper end)
Ai_screen_x_to_angle_table:
	dc.b	$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	dc.b	$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04
	dc.b	$04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08
	dc.b	$08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $10, $10, $10
	dc.b	$10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $14, $14, $14, $14, $14, $14, $14, $14, $14, $18, $18, $18, $18, $18, $18, $18, $1C, $1C, $1C, $1C, $1C, $20
	dc.b	$20, $20
Nearby_rival_car_obj_done:
	JMP	Clear_object_slot
;Nearby_rival_car_obj_init_fast: ; init variant 1 — faster ghost, $2C=1, $2E=6
Nearby_rival_car_obj_init_fast:
	MOVE.l	#$0001061C, D0
	MOVEQ	#1, D1
	MOVEQ	#6, D2
	BRA.b	Nearby_rival_car_obj_setup
;Nearby_rival_car_obj_init_mid: ; init variant 2 — mid-speed ghost, $2C=2, $2E=4
Nearby_rival_car_obj_init_mid:
	MOVE.l	#$000105F8, D0
	MOVEQ	#2, D1
	MOVEQ	#4, D2
	BRA.b	Nearby_rival_car_obj_setup
;Nearby_rival_car_obj_init_slow: ; init variant 3 (alloc sub-objects), fallback if alloc fails
Nearby_rival_car_obj_init_slow:
	MOVE.l	#Nearby_rival_car_obj_init_mid, D1
	JSR	Alloc_and_init_aux_object_slot
	BCS.b	Nearby_rival_car_obj_init_fallback
	MOVE.l	$30(A0), $30(A1)
	MOVE.l	#Nearby_rival_car_obj_init_fast, D1
	JSR	Find_free_aux_slot_loop
	BCS.b	Nearby_rival_car_obj_init_fallback
	MOVE.l	$30(A0), $30(A1)
Nearby_rival_car_obj_init_fallback:
	MOVE.l	#$000105D4, D0
	MOVEQ	#3, D1
	MOVEQ	#2, D2
Nearby_rival_car_obj_setup:
	MOVE.l	#Nearby_rival_car_obj, (A0)
	MOVE.b	#1, $24(A0)
	MOVE.l	D0, $8(A0)
	MOVE.w	D1, $2C(A0)
	MOVE.w	D2, $2E(A0)
Nearby_rival_car_obj:
	MOVE.w	Race_finish_flag.w, D0
	OR.w	Retire_flag.w, D0
	BNE.b	Nearby_rival_car_obj_done
	MOVEA.l	$30(A0), A1
	MOVE.b	$10(A1), D0
	OR.b	$25(A1), D0
	BEQ.b	Nearby_rival_car_obj_done
	BTST.b	#0, Frame_counter.w
	BEQ.b	Nearby_rival_car_obj_Rts
	MOVE.w	$12(A1), $12(A0)
	MOVE.b	$2A(A1), D0
	EXT.w	D0
	MOVE.w	D0, D1
	ADD.w	D0, D0
	ADD.w	D1, D0
	TST.w	$E(A1)
	BMI.b	Nearby_rival_car_obj_Flip
	NEG.w	D0
Nearby_rival_car_obj_Flip:
	ADD.w	D0, $12(A0)
	MOVE.w	$1A(A1), D0
	SUB.w	$2E(A0), D0
	BCC.b	Nearby_rival_car_obj_Wrap
	ADD.w	Track_length.w, D0
Nearby_rival_car_obj_Wrap:
	MOVE.w	D0, $1A(A0)
	JSR	Compute_ai_screen_x_offset(PC)
	TST.w	D7
	BEQ.b	Nearby_rival_car_obj_Rts
	LEA	Ai_screen_x_dispatch_table, A1
	JSR	(A1,D7.w)
	MOVE.w	$E(A0), D0
	ANDI.w	#$7FFF, D0
	LEA	Ai_screen_y_table_b, A1
	MOVE.b	(A1,D0.w), D0
	MOVE.w	D0, D2
	LSR.w	#3, D2
	MOVE.w	$2C(A0), D1
	LSR.w	D1, D0
	ADD.w	D2, D0
	SUB.w	D0, $16(A0)
Nearby_rival_car_obj_Rts:
	RTS
;Race_grid_obj_init_champ: ($9DB8)
; Championship race init: spawns 5 AI cars from Ai_car_init_table_champ,
; sets Frame_callback to loc_BD56 (championship award sequence), then
; falls through to Race_grid_obj common setup.
Race_grid_obj_init_champ:
	MOVE.w	#$FFFF, Player_grid_position.w
	LEA	Ai_car_init_table_champ(PC), A2
	MOVEQ	#4, D3
	BSR.b	Spawn_trackside_objects
	MOVE.l	#$0000BD56, $1E(A0)
	BRA.b	Race_grid_obj
;Spawn_trackside_objects
Spawn_trackside_objects:
	MOVE.w	Track_index_arcade_mode.w, D0
	ADD.w	D0, D0
	MOVE.w	D0, D1
	ADD.w	D0, D0
	ADD.w	D1, D0
	LEA	Race_time_bcd.w, A1
	MOVE.w	#$FFFF, (A1,D0.w)
	MOVE.l	(A2)+, D1
	JSR	Alloc_and_init_aux_object_slot
	BCS.b	Spawn_trackside_objects_Done
	MOVE.l	A0, $26(A1)
Spawn_trackside_objects_Loop:
	MOVE.l	(A2)+, D1
	JSR	Find_free_aux_slot_loop
	BCS.b	Spawn_trackside_objects_Done
	MOVE.l	A0, $26(A1)
	DBF	D3, Spawn_trackside_objects_Loop
Spawn_trackside_objects_Done:
	RTS
;Race_grid_obj_init_normal: ($9E08)
; Normal/arcade race init: spawns 7 AI cars from Ai_car_init_table_normal,
; sets Frame_callback to Pre_race_screen_init (or $2592 if AI active).
Race_grid_obj_init_normal:
	LEA	Ai_car_init_table_normal(PC), A2
	MOVEQ	#6, D3
	BSR.b	Spawn_trackside_objects
	MOVE.l	#Pre_race_screen_init, $1E(A0)
	TST.w	Ai_active_flag.w
	BEQ.b	Race_grid_obj
	MOVE.l	#$00002592, $1E(A0)
Race_grid_obj:
	MOVE.l	#Race_grid_obj_Countdown, (A0)
	MOVE.w	#$FFE2, $2C(A0)
	MOVE.w	#$0180, $2E(A0)
	MOVE.w	#$0082, $22(A0)
	MOVE.w	#Music_race, Audio_music_cmd        ; in-race background music
	TST.w	Ai_active_flag.w
	BEQ.b	Race_grid_obj_Countdown
	MOVE.w	#$00A0, $22(A0)
Race_grid_obj_Countdown:
	JSR	Skip_if_hidden_flag(PC)
	SUBQ.w	#1, $22(A0)
	TST.w	$36(A0)
	BNE.b	Race_grid_obj_Moving
	ADDQ.w	#1, $2C(A0)
	BMI.b	Race_grid_obj_Advance
	SUBQ.w	#8, $2E(A0)
	BNE.b	Race_grid_obj_Advance
	MOVE.w	#$FFFF, $36(A0)
Race_grid_obj_Advance:
	MOVE.w	Player_distance.w, D1
	MOVE.w	$2C(A0), D0
	JSR	Wrap_ai_track_position(PC)
	BRA.b	Race_grid_obj_Draw
Race_grid_obj_Moving:
	MOVE.w	#1, $36(A0)
Race_grid_obj_Draw:
	LEA	Race_grid_obj_palette_word-1(PC), A1
	LEA	Crash_car_palette_dma.w, A2
	JSR	Write_3_palette_vdp_bytes
	TST.w	$22(A0)
	BNE.b	Race_grid_obj_Return
	MOVE.l	$1E(A0), Frame_callback.w
Race_grid_obj_Return:
	RTS
	dc.w	$007F
; palette color word written by Write_3_palette_vdp_bytes above
Race_grid_obj_palette_word:
	dc.w	$AD80
;Wrap_ai_track_position
Wrap_ai_track_position:
	ADD.w	D1, D0
	BPL.b	Wrap_ai_track_position_Positive
	ADD.w	Track_length.w, D0
	BRA.b	Wrap_ai_track_position_Done
Wrap_ai_track_position_Positive:
	CMP.w	Track_length.w, D0
	BCS.b	Wrap_ai_track_position_Done
	SUB.w	Track_length.w, D0
Wrap_ai_track_position_Done:
	MOVE.w	D0, $1A(A0)
	RTS
Ai_car_obj_init_C0:
	LEA	Ai_car_data_C0(PC), A1
	BRA.b	Init_ai_car_fields
Ai_car_obj_init_C1:
	LEA	Ai_car_data_C1(PC), A1
	BRA.b	Init_ai_car_fields
Ai_car_obj_init_C2:
	LEA	Ai_car_data_C2(PC), A1
	BRA.b	Init_ai_car_fields
Ai_car_obj_init_C3:
	LEA	Ai_car_data_C3(PC), A1
	BRA.b	Init_ai_car_fields
Ai_car_obj_init_C4:
	LEA	Ai_car_data_C4(PC), A1
	BRA.b	Init_ai_car_fields
Ai_car_obj_init_C5:
	LEA	Ai_car_data_C5(PC), A1
	BRA.b	Init_ai_car_fields
Ai_car_obj_init_N0:
	LEA	Ai_car_data_N0(PC), A1
	BRA.b	Init_ai_car_fields
Ai_car_obj_init_N1:
	LEA	Ai_car_data_N1(PC), A1
	BRA.b	Init_ai_car_fields
Ai_car_obj_init_N2:
	LEA	Ai_car_data_N2(PC), A1
	BRA.b	Init_ai_car_fields
Ai_car_obj_init_N3:
	LEA	Ai_car_data_N3(PC), A1
	BRA.b	Init_ai_car_fields
Ai_car_obj_init_N4:
	LEA	Ai_car_data_N4(PC), A1
	BRA.b	Init_ai_car_fields
Ai_car_obj_init_N5:
	LEA	Ai_car_data_N5(PC), A1
	BRA.b	Init_ai_car_fields
Ai_car_obj_init_N6:
	LEA	Ai_car_data_N6(PC), A1
	BRA.b	Init_ai_car_fields
Ai_car_obj_init_N7:
	LEA	Ai_car_data_N7(PC), A1
Init_ai_car_fields:
; Common AI car object initialization tail.
; Installs loc_9F40 as the update handler pointer, then reads 7 words/longs
; from the data record pointed to by A1:
;   A1[0].l -> $8(A0)   (sprite base / tile index)
;   A1[4].l -> $1E(A0)  (initial track position)
;   A1[8].l -> $30(A0)  (speed lookup table pointer)
;   A1[12].w -> $C(A0)  (VDP tile flags)
;   A1[14].w -> $10(A0) (lateral oscillation range)
;   A1[16].w -> $2E(A0) (screen X step)
;   A1[18].w -> $2A(A0) (screen X base)
; Also sets $22(A0)=$0015, $24(A0)=1.
; All 14 entry stubs above this label load a different A1 data pointer and BRA here.
	MOVE.l	#Ai_car_obj, (A0)
	MOVE.l	(A1)+, $8(A0)
	MOVE.l	(A1)+, $1E(A0)
	MOVE.w	#$0015, $22(A0)
	MOVE.b	#1, $24(A0)
	MOVE.l	(A1)+, $30(A0)
	MOVE.w	(A1)+, $C(A0)
	MOVE.w	(A1)+, $10(A0)
	MOVE.w	(A1)+, $2E(A0)
	MOVE.w	(A1)+, $2A(A0)
Ai_car_obj:
	TST.w	Race_timer_freeze.w
	BEQ.b	Ai_car_obj_Active
	JMP	Queue_object_for_sprite_buffer
Ai_car_obj_Active:
	MOVEA.l	$26(A0), A1
	TST.w	$36(A1)
	BEQ.w	Ai_car_obj_Oscillate
	BPL.b	Ai_car_obj_Sync_pos
	MOVE.w	$1A(A1), $1A(A0)
Ai_car_obj_Sync_pos:
	TST.w	$36(A0)
	BEQ.b	Ai_car_obj_Move
	ORI.b	#$80, $C(A0)
	MOVE.w	$2A(A0), D0
	ADDI.w	#$00A3, D0
	MOVE.w	D0, $E(A0)
	JMP	Queue_object_for_sprite_buffer
Ai_car_obj_Move:
	MOVE.w	$2C(A0), D0
	ADD.w	$2E(A0), D0
	MOVE.w	D0, $2C(A0)
	ASR.w	#4, D0
	ADD.w	Horizontal_position.w, D0
	MOVE.w	D0, $12(A0)
	SUBQ.w	#1, $22(A0)
	SEQ	$36(A0)
	SUBQ.w	#2, $1A(A0)
	MOVEQ	#0, D0
	MOVE.w	$1A(A0), D1
	JSR	Wrap_ai_track_position(PC)
	JSR	Compute_ai_screen_x_offset(PC)
	TST.w	D7
	BEQ.w	Ai_car_obj_Move_Rts
	LEA	Ai_screen_x_dispatch_table, A1
	JSR	(A1,D7.w)
	BCS.b	Ai_car_obj_Move_no_decr
	SUBQ.w	#2, (A1)
Ai_car_obj_Move_no_decr:
	MOVE.w	$E(A0), D0
	ANDI.w	#$7FFF, D0
	LEA	Ai_screen_y_table_b, A1
	MOVE.b	(A1,D0.w), D0
	LSR.w	#1, D0
	SUB.w	D0, $16(A0)
	MOVEA.l	$30(A0), A1
	MOVEA.l	(A1,D4.w), A1
	MOVEA.l	$1E(A0), A2
	JSR	Copy_sprite_frame_data(PC)
	MOVE.w	$2A(A0), D0
	ADD.w	D0, $E(A0)
	JMP	Queue_object_for_sprite_buffer
Ai_car_obj_Oscillate:
	SUBQ.w	#5, $10(A0)
	JSR	Ai_oscillation_phase(PC)
	MULS.w	$2E(A1), D0
	SWAP	D0
	ADD.w	Horizontal_position.w, D0
	MOVE.w	D0, $12(A0)
	JSR	Ai_oscillation_phase_offset(PC)
	MULS.w	$2E(A1), D0
	SWAP	D0
	ASR.w	#5, D0
	MOVE.w	$1A(A1), D1
	JSR	Wrap_ai_track_position(PC)
	JSR	Compute_ai_screen_x_offset(PC)
	TST.w	D7
	BEQ.b	Ai_car_obj_Move_Rts
	LEA	Ai_screen_x_dispatch_table, A1
	JSR	(A1,D7.w)
	MOVE.w	$E(A0), D0
	ANDI.w	#$7FFF, D0
	MOVE.w	D0, D1
	LEA	Ai_screen_y_table_b, A1
	MOVE.b	(A1,D0.w), D0
	LSR.w	#1, D0
	SUB.w	D0, $16(A0)
	LEA	Ai_screen_x_to_angle_table(PC), A1
	MOVE.b	(A1,D1.w), D1
	MOVEA.l	$30(A0), A1
	MOVEA.l	(A1,D1.w), A1
	MOVEA.l	$1E(A0), A2
	JSR	Copy_sprite_frame_data(PC)
Ai_car_obj_Move_Rts:
	RTS
;Copy_sprite_frame_data
Copy_sprite_frame_data:
	MOVEM.l	(A1)+, D0-D7/A3-A6
	MOVEM.l	D0-D7/A3-A6, (A2)
	LEA	$30(A2), A2
	MOVEM.l	(A1)+, D0-D7/A3-A6
	MOVEM.l	D0-D7/A3-A6, (A2)
	LEA	$30(A2), A2
	MOVEM.l	(A1)+, D0-D7/A3-A6
	MOVEM.l	D0-D7/A3-A6, (A2)
	LEA	$30(A2), A2
	MOVEM.l	(A1)+, D0-D7/A3-A6
	MOVEM.l	D0-D7/A3-A6, (A2)
	LEA	$30(A2), A2
	MOVEM.l	(A1)+, D0-D7/A3-A6
	MOVEM.l	D0-D7/A3-A6, (A2)
	LEA	$30(A2), A2
	MOVEM.l	(A1), D0-D7/A3-A6
	MOVEM.l	D0-D7/A3-A6, (A2)
	RTS
Ai_oscillation_phase_offset:
	MOVE.w	$10(A0), D0
	ADDI.w	#$0020, D0
	BRA.b	Ai_oscillation_phase_Lookup
Ai_oscillation_phase:
	MOVE.w	$10(A0), D0
Ai_oscillation_phase_Lookup:
	ANDI.w	#$007F, D0
	ADD.w	D0, D0
	LEA	Ai_lateral_sine_table(PC), A6
	MOVE.w	(A6,D0.w), D0
	RTS
;Rival_dust_obj_init: ($A0CC)
; Allocated by Advance_ai_track_position when a rival car passes at high speed.
; Displays a brief dust/wake effect sprite near the fast-moving rival.
Rival_dust_obj_init:
	MOVE.l	#Rival_dust_obj, (A0)
	MOVE.l	#Player_car_sprite_frames, $8(A0)
	MOVE.b	#1, $24(A0)
	MOVE.w	#9, $36(A0)
Rival_dust_obj:
	MOVE.w	Race_finish_flag.w, D0
	OR.w	Retire_flag.w, D0
	BNE.b	Rival_dust_obj_Done
	MOVE.w	$26(A0), D0
	ADD.w	D0, D0
	ADD.w	D0, D0
	LEA	Speed_to_distance_table, A1
	MOVE.l	(A1,D0.w), D0
	ADD.l	$1A(A0), D0
	SWAP	D0
	CMP.w	Track_length.w, D0
	BCS.b	Rival_dust_obj_No_wrap
	SUB.w	Track_length.w, D0
Rival_dust_obj_No_wrap:
	SWAP	D0
	MOVE.l	D0, $1A(A0)
	JSR	Compute_ai_screen_x_offset(PC)
	LEA	Ai_screen_x_dispatch_table, A1
	JSR	(A1,D7.w)
	SUBQ.w	#1, $36(A0)
	BNE.b	Rival_dust_obj_Rts
Rival_dust_obj_Done:
	JMP	Clear_object_slot
Rival_dust_obj_Rts:
	RTS
;Alloc_and_init_aux_object_slot
Alloc_and_init_aux_object_slot:
	LEA	Aux_object_pool.w, A1
	MOVEQ	#$00000020, D2
;Find_free_aux_slot_loop
Find_free_aux_slot_loop:
	TST.l	(A1)
	BEQ.b	Find_free_aux_slot_loop_Found
	LEA	$40(A1), A1
	DBF	D2, Find_free_aux_slot_loop
	ADDQ.w	#2, D2
	BRA.b	Find_free_aux_slot_loop_Return
Find_free_aux_slot_loop_Found:
	MOVE.l	D1, (A1)
	MOVE.w	D0, $1A(A1)
Find_free_aux_slot_loop_Return:
	RTS
