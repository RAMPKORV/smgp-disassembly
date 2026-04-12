;Update_rival_sprite_tiles
Update_rival_sprite_tiles:
; Flashes the rival car's palette entry on alternate frames while the race is
; running.  Writes $0444 (dark) on even frames and $0888 (bright) on odd frames
; to Palette_buffer+$34 and Palette_buffer+$54 (rival car colours).
; Inputs:  Race_started.w — skips entirely if zero (pre-race).
; Modifies: D0, A1, Palette_buffer+$34, Palette_buffer+$54.
	TST.w	Race_started.w
	BEQ.b	Update_rival_sprite_tiles_Return
	MOVE.w	#$0444, D0
	BTST.b	#0, Frame_counter.w
	BEQ.b	Update_rival_sprite_tiles_Write
	MOVE.w	#$0888, D0
Update_rival_sprite_tiles_Write:
	LEA	(Palette_buffer+$34).w, A1
	MOVE.w	D0, (A1)
	MOVE.w	D0, $20(A1)
Update_rival_sprite_tiles_Return:
	RTS
Flagkeeper_car_obj_guard:
; Gate for the flagkeeper car: returns early if a sign DMA is pending this frame.
; Otherwise falls through to Flagkeeper_car_obj_init.
	TST.w	Sign_tileset_dma_pending.w
	BEQ.b	Flagkeeper_car_obj_init
	RTS
Flagkeeper_car_obj_init:
	MOVE.l	#Flagkeeper_car_obj, (A0)
	MOVE.l	#Flagkeeper_car_sprite_frames, $8(A0)
	MOVE.w	#4, $1A(A0)
	MOVE.b	#1, $24(A0)
	LEA	Palette_buffer.w, A1
	MOVE.w	#$044E, $14(A1)
	MOVE.w	#$06AE, $18(A1)
	CLR.w	Player_overtaken_flag.w
Flagkeeper_car_obj:
	MOVE.w	Horizontal_position.w, D0
	SUBI.w	#$0060, D0
	SMI	D7
	BPL.b	Flagkeeper_car_obj_Clamp
	NEG.w	D0
Flagkeeper_car_obj_Clamp:
	CMPI.w	#$00F0, D0
	BCS.b	Flagkeeper_car_obj_Sign
	MOVE.w	#$00F0, D0
Flagkeeper_car_obj_Sign:
	TST.b	D7
	BEQ.b	Flagkeeper_car_obj_Position
	NEG.w	D0
Flagkeeper_car_obj_Position:
	MOVE.w	D0, $12(A0)
	JSR	Compute_ai_screen_x_offset(PC)
	LEA	Ai_screen_x_dispatch_table, A1
	JSR	(A1,D7.w)
	MOVE.w	$E(A0), D0
	BMI.b	Rival_collision_check_Return
	CMPI.w	#$009B, D0
	BCS.b	Rival_collision_check_Return
	MOVE.w	Horizontal_position.w, D0
	MOVE.w	D0, D1
	SUBI.w	#$0040, D0
	CMP.w	$12(A0), D0
	BGE.b	Rival_collision_check_Return
	ADDI.w	#$0050, D0
	CMP.w	$12(A0), D0
	BLE.b	Rival_collision_check_Return
	MOVE.w	#1, Player_overtaken_flag.w
	MOVE.l	#Flagkeeper_car_obj_Bounce, (A0)
	MOVE.w	#$009F, $E(A0)
	MOVE.w	#5, $2E(A0)
	SUBI.w	#$0018, D1
	CMP.w	$12(A0), D1
	BLE.b	Rival_collision_check_Return
	NEG.w	$2E(A0)
;Rival_collision_check_Return
Rival_collision_check_Return:
; Shared return-point for the flagkeeper car collision checks above.
; All collision guard branches that decide "no collision this frame" BRA/BEQ here.
	RTS
Flagkeeper_car_obj_Bounce:
	SUBQ.w	#2, $E(A0)
	BPL.b	Flagkeeper_car_obj_Bounce_move
	JMP	Clear_object_slot
Flagkeeper_car_obj_Bounce_move:
	MOVE.w	$2E(A0), D0
	ADD.w	D0, $12(A0)
	MOVE.w	$E(A0), D4
	MOVE.w	D4, D3
	MOVEQ	#0, D0
	LEA	Ai_screen_y_table, A1
	MOVE.b	(A1,D4.w), D0
	ADD.w	D0, D0
	JSR	Compute_rival_screen_x(PC)
	MOVE.w	$E(A0), D0
	LEA	Ai_screen_y_table_b, A1
	MOVE.b	(A1,D0.w), D0
	MOVE.w	#$0080, D1
	SUB.w	D0, D1
	LSR.w	#2, D1
	MOVEQ	#0, D0
	ADD.w	D1, D0
	ADD.w	D1, D0
	ADD.w	D1, D0
	SUB.w	D0, $16(A0)
	RTS
Apply_sorted_positions_to_cars:
; Writes the sorted placement score pair back to each AI car object slot.
; Score_scratch_buf holds up to 15 object-pointer + placement-pair records
; (each 6 bytes: slot_addr.w, score_a.w, score_b.w).  Null and $FFFF pointers
; are skipped.  The final (15th) entry only receives score_a ($38), not $3A.
; Called once per frame by Update_race_result_scores after sorting.
; Inputs:  Score_scratch_buf.w — 15+1 packed records.
; Modifies: D0, A0, A1.
	LEA	Score_scratch_buf.w, A0
	MOVEQ	#$0000000D, D7
;Apply_sorted_positions_loop
Apply_sorted_positions_loop:
	MOVE.w	(A0)+, D0
	BEQ.b	Apply_sorted_positions_skip
	CMPI.w	#$FFFF, D0
	BEQ.b	Apply_sorted_positions_skip
	MOVEA.w	D0, A1
	MOVE.w	(A0), $38(A1)
	MOVE.w	$2(A0), $3A(A1)
Apply_sorted_positions_skip:
	DBF	D7, Apply_sorted_positions_loop
	MOVE.w	(A0)+, D0
	BEQ.b	Apply_sorted_positions_done
	CMPI.w	#$FFFF, D0
	BEQ.b	Apply_sorted_positions_done
	MOVEA.w	D0, A1
	MOVE.w	(A0), $38(A1)
Apply_sorted_positions_done:
	RTS
Ai_car_init_table_normal:
	dc.l	Ai_car_obj_init_N0
	dc.l	Ai_car_obj_init_N1
	dc.l	Ai_car_obj_init_N2
	dc.l	Ai_car_obj_init_N3
	dc.l	Ai_car_obj_init_N4
	dc.l	Ai_car_obj_init_N5
	dc.l	Ai_car_obj_init_N6
	dc.l	Ai_car_obj_init_N7
Ai_car_init_table_champ:
	dc.l	Ai_car_obj_init_C0
	dc.l	Ai_car_obj_init_C1
	dc.l	Ai_car_obj_init_C2
	dc.l	Ai_car_obj_init_C3
	dc.l	Ai_car_obj_init_C4
	dc.l	Ai_car_obj_init_C5
; 20-byte records consumed by Init_ai_car_fields:
;   0: sprite/tile base long, 4: initial position long, 8: Car_sprite_ptr_table entry,
;  12: flags.w, 14: oscillation.w, 16: x step.w, 18: x base.w.
Ai_car_data_N0:
	dc.b	$00, $01, $0A, $40, $00, $FF, $5B, $00, $00, $01, $2A, $64, $03, $D0, $00, $00, $FF, $C6, $00, $01
Ai_car_data_N1:
	dc.b	$00, $01, $0A, $40, $00, $FF, $5C, $20, $00, $01, $2A, $88, $03, $D9, $00, $09, $FF, $D6, $FF, $FF
Ai_car_data_N2:
	dc.b	$00, $01, $0A, $64, $00, $FF, $5D, $40, $00, $01, $2A, $AC, $03, $E2, $00, $12, $FF, $E6, $00, $01
Ai_car_data_N3:
	dc.b	$00, $01, $0A, $40, $00, $FF, $5E, $60, $00, $01, $2A, $D0, $03, $EB, $00, $1B, $FF, $F6, $FF, $FF
Ai_car_data_N4:
	dc.b	$00, $01, $0A, $40, $00, $FF, $5F, $80, $00, $01, $2A, $F4, $03, $F4, $00, $24, $00, $0A, $00, $01
Ai_car_data_N5:
	dc.b	$00, $01, $0A, $64, $00, $FF, $60, $A0, $00, $01, $2B, $18, $03, $FD, $00, $2D, $00, $1A, $FF, $FF
Ai_car_data_N6:
	dc.b	$00, $01, $0A, $40, $00, $FF, $61, $C0, $00, $01, $2B, $3C, $04, $06, $00, $36, $00, $2A, $00, $01
Ai_car_data_N7:
	dc.b	$00, $01, $0A, $40, $00, $FF, $62, $E0, $00, $01, $2B, $60, $04, $0F, $00, $3F, $00, $3A, $FF, $FF
Ai_car_data_C0:
	dc.b	$00, $01, $0A, $40, $00, $FF, $5B, $00, $00, $01, $2B, $84, $03, $D0, $00, $00, $FF, $D8, $00, $01
Ai_car_data_C1:
	dc.b	$00, $01, $0A, $40, $00, $FF, $5C, $20, $00, $01, $2A, $D0, $03, $D9, $00, $0A, $FF, $E8, $FF, $FF
Ai_car_data_C2:
	dc.b	$00, $01, $0A, $40, $00, $FF, $5D, $40, $00, $01, $2B, $A8, $03, $E2, $00, $14, $FF, $F8, $00, $01
Ai_car_data_C3:
	dc.b	$00, $01, $0A, $88, $00, $FF, $5E, $60, $00, $01, $2B, $CC, $03, $EB, $00, $1E, $00, $08, $FF, $FF
Ai_car_data_C4:
	dc.b	$00, $01, $0A, $40, $00, $FF, $5F, $80, $00, $01, $2B, $60, $03, $F4, $00, $28, $00, $18, $00, $01
Ai_car_data_C5:
	dc.b	$00, $01, $0A, $40, $00, $FF, $60, $A0, $00, $01, $2B, $3C, $03, $FD, $00, $32, $00, $28, $FF, $FF
Ai_lateral_sine_table:
; 128-entry signed-word sine lookup table (full 360° cycle, Q15 fixed-point).
; Values range from $7FFF (+1.0) to $8001 (-1.0).  Followed by two extra longs
; ($00002B00, $00005580) used as angle-step constants by AI lateral oscillation.
	dc.w	$7FFF, $7FD8, $7F61, $7E9C, $7D89, $7C29, $7A7C, $7884, $7641, $73B5, $70E2, $6DC9, $6A6D, $66CF, $62F1, $5ED7, $5A82, $55F5, $5133, $4C3F, $471C, $41CE, $3C56, $36BA, $30FB, $2B1F, $2528, $1F1A, $18F9, $12C8, $0C8C, $0648
	dc.w	$0000, $F9B8, $F374, $ED38, $E707, $E0E6, $DAD8, $D4E1, $CF05, $C946, $C3AA, $BE32, $B8E4, $B3C1, $AECD, $AA0B, $A57E, $A129, $9D0F, $9931, $9593, $9237, $8F1E, $8C4B, $89BF, $877C, $8584, $83D7, $8277, $8164, $809F, $8028
	dc.w	$8001, $8028, $809F, $8164, $8277, $83D7, $8584, $877C, $89BF, $8C4B, $8F1E, $9237, $9593, $9931, $9D0F, $A129, $A57E, $AA0B, $AECD, $B3C1, $B8E4, $BE32, $C3AA, $C946, $CF05, $D4E1, $DAD8, $E0E6, $E707, $ED38, $F374, $F9B8
	dc.w	$0000, $0648, $0C8C, $12C8, $18F9, $1F1A, $2528, $2B1F, $30FB, $36BA, $3C56, $41CE, $471C, $4C3F, $5133, $55F5, $5A82, $5ED7, $62F1, $66CF, $6A6D, $6DC9, $70E2, $73B5, $7641, $7884, $7A7C, $7C29, $7D89, $7E9C, $7F61, $7FD8
	dc.l	$00002B00
	dc.l	$00005580
Bg_ai_car_speed_scale_table:
; Three long-word speed-scale factors for background AI car type-B variants:
; $00008000 (1.0×), $0000AA80 (~1.33×), $0000D500 (~1.66×).
	dc.l	$00008000
	dc.l	$0000AA80
	dc.l	$0000D500
Crash_retire_obj_init:
; Object init handler: sets up a 40-frame countdown then routes to the correct
; post-race screen once the counter expires.  Routing priority:
;   Warm_up mode              → Title_menu
;   Track_index_arcade_mode=0 → Race_finish_results_init (standard finish)
;   championship, WC tracks   → Championship_next_race_init
;   arcade (last track)       → Arcade_car_spec_result_init
;   arcade (finish track)     → Race_finish_credits_init
; Also sets Retire_animation_flag and Spin_off_track_flag to 1.
	MOVE.l	#Crash_retire_obj, (A0)
	MOVE.w	#$0028, $36(A0)
	MOVE.w	#1, Retire_animation_flag.w
	MOVE.w	#1, Spin_off_track_flag.w
Crash_retire_obj:
	SUBQ.w	#1, $36(A0)
	BNE.b	Crash_retire_obj_Rts
	MOVE.l	#Title_menu, D1
	TST.w	Warm_up.w
	BNE.b	Set_retire_frame_callback
	MOVE.l	#Race_finish_results_init, D1
	MOVE.w	Track_index_arcade_mode.w, D0
	BEQ.b	Set_retire_frame_callback
	MOVE.l	#Championship_next_race_init, D1
	TST.w	Use_world_championship_tracks.w
	BNE.b	Set_retire_frame_callback
	MOVE.l	#Arcade_car_spec_result_init, D1
	SUBQ.w	#1, D0
	BEQ.b	Set_retire_frame_callback
	MOVE.l	#Race_finish_credits_init, D1
Set_retire_frame_callback:
; Shared tail: stores D1 into Frame_callback.w and returns.
; All retirement routing branches above load the desired callback address into
; D1 and then BRA/BEQ here to commit it.
	MOVE.l	D1, Frame_callback.w
Crash_retire_obj_Rts:
	RTS
Rival_crowd_car_obj_init:
; Object init handler for the pre-race crowd cars lined up on the starting grid.
; Selects anim data (a/b/c) based on object slot address and championship mode.
; Sets the screen-X position from Countdown_lights_x_pos.w, then decrements it
; by 4 so successive cars are staggered.  Clears the slot if the chosen anim
; data pointer is null.  In normal (non-WC) mode, initialises a lateral oscillation
; period of 8 frames.  Dispatch handler: Rival_crowd_car_obj → Rival_crowd_car_obj_Draw.
	MOVE.l	#Rival_crowd_car_obj, (A0)
	MOVE.l	#Rival_car_anim_data_a, D0
	MOVE.w	#$FC00, D1
	CMPA.w	#$B440, A0
	BNE.b	Rival_crowd_car_obj_init_champ_check
	MOVE.l	#Rival_car_anim_data_c, D0
	MOVE.w	#$F9C0, D1
	MOVE.w	#$009F, Countdown_lights_x_pos.w
	MOVE.l	#Rival_crowd_car_obj_Draw, (A0)
Rival_crowd_car_obj_init_champ_check:
	TST.w	Use_world_championship_tracks.w
	BEQ.b	Rival_crowd_car_obj_init_validate
	TST.w	Track_index_arcade_mode.w
	BEQ.b	Rival_crowd_car_obj_init_validate
	CMPA.w	#$B480, A0
	BNE.b	Rival_crowd_car_obj_init_validate
	MOVE.l	#Rival_car_anim_data_b, D0
Rival_crowd_car_obj_init_validate:
	TST.l	(A0,D1.w)
	BNE.b	Rival_crowd_car_obj_init_store
	JMP	Clear_object_slot
Rival_crowd_car_obj_init_store:
	MOVE.l	D0, $4(A0)
	MOVE.w	D1, $2A(A0)
	MOVE.w	Countdown_lights_x_pos.w, $E(A0)
	SUBQ.w	#4, Countdown_lights_x_pos.w
	TST.w	Use_world_championship_tracks.w
	BNE.b	Rival_crowd_car_obj
	MOVE.w	#8, $2C(A0)
Rival_crowd_car_obj:
	TST.w	Countdown_lights_active_flag.w
	BEQ.b	Rival_crowd_car_obj_Draw
	RTS
Rival_crowd_car_obj_Draw:
	MOVE.w	$2A(A0), D0
	MOVEQ	#0, D1
	MOVE.b	$2C(A0,D0.w), D1
	ADDI.w	#$00E8, D1
	ADD.w	$2C(A0), D1
	MOVE.w	D1, $16(A0)
	MOVEQ	#0, D1
	MOVE.b	$2E(A0,D0.w), D1
	ADDI.w	#$0140, D1
	ADD.w	$2E(A0), D1
	MOVE.w	D1, $18(A0)
	JMP	Queue_object_for_sprite_buffer
Gear_diagram_obj_init:
; Object init handler for the gear-diagram HUD sprite shown before the race starts.
; Selects the sprite frame list based on mode: warmup → warmup frames,
; practice → practice frames, normal → normal frames, arcade → clears slot.
; Positions the object at screen-X $9F, Y $120, pixel-X $100.
; Animation timer starts at 10 frames; stores current Player_place_score.w
; in $2A(A0) as a baseline for gear-change detection.
	MOVE.l	#Gear_diagram_sprite_frames_warmup, D0
	TST.w	Warm_up.w
	BNE.b	Gear_diagram_obj_init_done
	MOVE.l	#Gear_diagram_sprite_frames_practice, D0
	TST.w	Practice_mode.w
	BNE.b	Gear_diagram_obj_init_done
	MOVE.l	#Gear_diagram_sprite_frames_normal, D0
	TST.w	Track_index_arcade_mode.w
	BEQ.b	Gear_diagram_obj_init_done
	JMP	Clear_object_slot
Gear_diagram_obj_init_done:
	MOVE.l	D0, $4(A0)
	MOVE.l	#Gear_diagram_obj, (A0)
	MOVE.w	#$009F, $E(A0)
	MOVE.w	#$0120, $16(A0)
	MOVE.w	#$0100, $18(A0)
	MOVE.w	#$000A, $24(A0)
	MOVE.w	Player_place_score.w, $2A(A0)
Gear_diagram_obj:
	MOVEQ	#0, D1
	CMPI.w	#3, $24(A0)
	BCS.b	Gear_diagram_obj_Draw
	MOVEQ	#1, D1
Gear_diagram_obj_Draw:
	BSR.b	Queue_gear_diagram_draw
	TST.w	Race_started.w
	BEQ.b	Gear_diagram_obj_Tick
	SUBQ.w	#2, $16(A0)
	ADDQ.w	#3, $18(A0)
	CMPI.w	#$00E8, $16(A0)
	BNE.b	Gear_diagram_obj_Tick
	MOVE.l	#Gear_diagram_obj_Tick, (A0)
	MOVEQ	#0, D1
	BSR.b	Queue_gear_diagram_draw
Gear_diagram_obj_Tick:
	SUBQ.w	#1, $24(A0)
	BPL.b	Gear_diagram_obj_Timer_ok
	MOVE.w	#$000A, $24(A0)
Gear_diagram_obj_Timer_ok:
	MOVE.w	Player_place_score.w, D0
	SUB.w	$2A(A0), D0
	CMPI.w	#700, D0
	BCC.b	Gear_diagram_obj_Activate
	CMPI.w	#3, $24(A0)
	BCC.b	Gear_diagram_obj_Queue
	RTS
Gear_diagram_obj_Activate:
	MOVE.l	#Queue_object_for_sprite_buffer, (A0)
Gear_diagram_obj_Queue:
	JMP	Queue_object_for_sprite_buffer
Queue_gear_diagram_draw:
; Queues a tilemap draw for the gear/car diagram shown in the HUD.
; D1 = 0 → uses the fixed tilemap at $00FF5980 (standard gear diagram).
; D1 != 0 → uses Crash_approach_tile_data_a or _b depending on Shift_type.w.
; Loads VDP params D7=$65520003, D6=$0E, D5=0, A6=tile data, then tail-calls
; Queue_tilemap_draw.
	MOVE.l	#$65520003, D7
	MOVEQ	#$0000000E, D6
	MOVEQ	#0, D5
	LEA	$00FF5980, A6
	TST.w	D1
	BEQ.b	Queue_gear_diagram_draw_Dispatch
	LEA	Crash_approach_tile_data_a(PC), A6
	TST.w	Shift_type.w
	BEQ.b	Queue_gear_diagram_draw_Dispatch
	LEA	Crash_approach_tile_data_b(PC), A6
Queue_gear_diagram_draw_Dispatch:
	JMP	Queue_tilemap_draw
; Countdown_lights_obj_init (anonymous entry immediately after Queue_gear_diagram_draw):
; Object init handler for the pre-race countdown light bar.  Installs
; Countdown_lights_Wait as the per-frame handler, sets the sprite to
; Sprite_frame_data_126EC, positions at screen-X $9F, Y $FD, pixel-X $84.
; Sets $2C(A0) = 40 (initial hold frames), records Player_place_score.w
; baseline in $2A(A0), and raises Countdown_lights_active_flag.w.
	MOVE.l	#Sprite_frame_data_126EC, $4(A0)
	MOVE.w	#$009F, $E(A0)
	MOVE.w	#$00FD, $16(A0)
	MOVE.w	#$0084, $18(A0)
	MOVE.w	Player_place_score.w, $2A(A0)
	MOVE.w	#$0028, $2C(A0)
	MOVE.w	#$FFFF, Countdown_lights_active_flag.w
	BRA.b	Queue_countdown_lights
Countdown_lights_Wait:
; State 1 of the countdown light state machine.  Decrements the $2C(A0)
; hold counter.  When it reaches 0, fires the pre-race countdown SFX in
; practice mode, resets $2C to 20 and transitions to Countdown_lights_Tick.
	SUBQ.w	#1, $2C(A0)
	BNE.b	Queue_countdown_lights
	TST.w	Practice_flag.w
	BEQ.b	Countdown_lights_Pre_go
	MOVE.w	#Sfx_pre_race_countdown, Audio_sfx_cmd ; pre-race countdown SFX (practice mode)
Countdown_lights_Pre_go:
	MOVE.w	#$0014, $2C(A0)
	MOVE.l	#Countdown_lights_Tick, (A0)
	BRA.b	Queue_countdown_lights
;Countdown_lights_Tick
Countdown_lights_Tick:
; State 2: ticks down the light-reveal counter.  Each frame it updates the
; palette entry at Palette_buffer+$18 from Countdown_lights_tick_x_table using
; the clamped (≥4) counter value.  When the counter expires it sets Race_started,
; resets $2C to 40, $2E to 100, and transitions to Countdown_lights_Slide_out.
; In practice mode, fires the race-start "go" SFX on transition.
	SUBQ.w	#1, $2C(A0)
	BNE.b	Countdown_lights_Tick_frame
	TST.w	Practice_flag.w
	BEQ.b	Countdown_lights_Go
	MOVE.w	#Sfx_race_start_go, Audio_sfx_cmd   ; race start "go" SFX (practice mode)
Countdown_lights_Go:
	MOVE.w	#1, Race_started.w
	MOVE.w	#$0028, $2C(A0)
	MOVE.w	#$0064, $2E(A0)
	MOVE.l	#Countdown_lights_Slide_out, (A0)
Queue_countdown_lights:
; Shared tail: tail-jumps to Queue_object_for_sprite_buffer.
; All countdown-light state handlers BRA here to emit the sprite this frame.
	JMP	Queue_object_for_sprite_buffer
Countdown_lights_Tick_frame:
	MOVE.l	#Sprite_frame_data_12730, $4(A0)
	MOVE.w	$2C(A0), D0
	CMPI.w	#4, D0
	BCS.b	Countdown_lights_Tick_clamp
	MOVEQ	#4, D0
Countdown_lights_Tick_clamp:
	ADD.w	D0, D0
	MOVE.w	Countdown_lights_tick_x_table-2(PC,D0.w), (Palette_buffer+$18).w
	BRA.b	Queue_countdown_lights
;Countdown_lights_Slide_out
Countdown_lights_Slide_out:
; State 3: slides the light bar off-screen.  Decrements $2C(A0); while running
; it updates the palette from Countdown_lights_slide_x_table.  When $2C reaches 0
; it copies $2E(A0) (100) back to $2C and transitions to Countdown_lights_Finish_check.
	SUBQ.w	#1, $2C(A0)
	BNE.b	Countdown_lights_Slide_frame
	MOVE.w	$2E(A0), $2C(A0)
	MOVE.l	#Countdown_lights_Finish_check, (A0)
	BRA.b	Queue_countdown_lights
Countdown_lights_Slide_frame:
	MOVE.l	#Sprite_frame_data_12774, $4(A0)
	MOVE.w	$2C(A0), D0
	CMPI.w	#4, D0
	BCS.b	Countdown_lights_Slide_clamp
	MOVEQ	#4, D0
Countdown_lights_Slide_clamp:
	ADD.w	D0, D0
	MOVE.w	Countdown_lights_slide_x_table(PC,D0.w), (Palette_buffer+$18).w
	BRA.b	Queue_countdown_lights
;Countdown_lights_Finish_check
Countdown_lights_Finish_check:
; State 4: polls whether the player has advanced ≥128 place-score units past the
; baseline stored in $2A(A0).  Once they have, clears Countdown_lights_active_flag
; and removes the object.  Otherwise transitions to Countdown_lights_Flash.
	MOVE.w	Player_place_score.w, D0
	SUB.w	$2A(A0), D0
	CMPI.w	#$0080, D0
	BCS.b	Countdown_lights_Flash
	CLR.w	Countdown_lights_active_flag.w
	JMP	Clear_object_slot
;Countdown_lights_Flash
Countdown_lights_Flash:
; State 5: makes the light bar flash on screen.  Decrements $2C(A0); when it
; reaches 0, resets $2C to 10, $2E to 3, clears Countdown_lights_active_flag,
; and loops back to Countdown_lights_Slide_out for one more pass.
	MOVE.l	#Sprite_frame_data_126EC, $4(A0)
	SUBQ.w	#1, $2C(A0)
	BNE.b	Queue_countdown_lights
	MOVE.w	#$000A, $2C(A0)
	MOVE.w	#3, $2E(A0)
	MOVE.l	#Countdown_lights_Slide_out, (A0)
	CLR.w	Countdown_lights_active_flag.w
	BRA.w	Queue_countdown_lights
Countdown_lights_tick_x_table:
	dc.w	$0008
	dc.w	$000A
	dc.w	$000C
Countdown_lights_slide_x_table:
	dc.w	$000E, $0080, $00A0, $00C0, $00E0
Spawn_background_ai_car_0:
; Allocates an aux-object slot for a second background AI car (type Init_background_ai_car_5)
; using $1E(A0) as the position parameter, then falls through to Init_background_ai_car_0
; to set up the main car (left side, Bg_ai_car_0 frames, spawn X=$FE90).
	MOVE.l	#Init_background_ai_car_5, D1
	MOVE.w	$1E(A0), D0
	JSR	Alloc_aux_object_slot
Init_background_ai_car_0:
; Entry stub: sets up the main left-side car (Bg_ai_car_0 frames, spawn X=$FE90)
; then falls through to Init_background_ai_car_b_screen_right.
	MOVE.l	#Bg_ai_car_0_sprite_frames, D1
	MOVE.w	#$FE90, D0
	BRA.w	Init_background_ai_car_b_screen_right
;Spawn_background_ai_car_1
Spawn_background_ai_car_1:
; Allocates an aux-object slot for a second background AI car (type Init_background_ai_car_4)
; using $1E(A0) as the position parameter, then falls through to Init_background_ai_car_1
; to set up the main car (right side, Bg_ai_car_1 frames, spawn X=$0170).
	MOVE.l	#Init_background_ai_car_4, D1
	MOVE.w	$1E(A0), D0
	JSR	Alloc_aux_object_slot
Init_background_ai_car_1:
	MOVE.l	#Bg_ai_car_1_sprite_frames, D1
	MOVE.w	#$0170, D0
	BRA.w	Init_background_ai_car_b
Init_background_ai_car_2:
	MOVE.l	#Bg_ai_car_2_sprite_frames, D1
	MOVE.w	#$FE90, D0
	BRA.w	Init_background_ai_car_b_screen_right
Init_background_ai_car_3:
	MOVE.l	#Bg_ai_car_3_sprite_frames, D1
	MOVE.w	#$0170, D0
	BRA.w	Init_background_ai_car_b
Init_background_ai_car_4:
	MOVE.l	#Bg_ai_car_4_sprite_frames, D1
	MOVE.w	#$FE80, D0
	BRA.w	Init_background_ai_car_b_screen_right
Init_background_ai_car_5:
	MOVE.l	#Bg_ai_car_5_sprite_frames, D1
	MOVE.w	#$0180, D0
	BRA.w	Init_background_ai_car_b
Init_background_ai_car_6:
	MOVE.l	#Bg_ai_car_6_sprite_frames, D1
	MOVE.w	#$FE90, D0
	BRA.b	Init_background_ai_car_b_screen_right
Init_background_ai_car_7:
	MOVE.l	#Bg_ai_car_7_sprite_frames, D1
	MOVE.w	#$0170, D0
	BRA.b	Init_background_ai_car_b
Init_background_ai_car_8:
	MOVE.l	#Bg_ai_car_8_sprite_frames, D1
	MOVE.w	#$FE90, D0
	BRA.b	Init_background_ai_car_b_screen_right
Init_background_ai_car_9:
	MOVE.l	#Bg_ai_car_9_sprite_frames, D1
	MOVE.w	#$0170, D0
	BRA.b	Init_background_ai_car_b
Init_background_ai_car_10:
	MOVE.l	#Bg_ai_car_10_sprite_frames, D1
	MOVE.w	#$FE9C, D0
	BRA.b	Init_background_ai_car_b_screen_right
Init_background_ai_car_11:
	MOVE.l	#Bg_ai_car_11_sprite_frames, D1
	MOVE.w	#$0164, D0
	BRA.b	Init_background_ai_car_b
Init_background_ai_car_12:
	MOVE.l	#Bg_ai_car_12_sprite_frames, D1
	MOVE.w	#$FE7C, D0
	BRA.b	Init_background_ai_car_b_screen_right
Init_background_ai_car_13:
	MOVE.l	#Bg_ai_car_13_sprite_frames, D1
	MOVE.w	#$0184, D0
	BRA.b	Init_background_ai_car_b
Init_background_ai_car_14:
	MOVE.l	#Bg_ai_car_14_sprite_frames, D1
	MOVE.w	#$0168, D0
	MOVE.w	#$6000, $C(A0)
	BRA.b	Init_background_ai_car_b
Init_background_ai_car_15:
	MOVE.l	#Bg_ai_car_15_sprite_frames, D1
	MOVE.w	#$FE98, D0
	MOVE.w	#$6000, $C(A0)
;Init_background_ai_car_b_screen_right
Init_background_ai_car_b_screen_right:
	MOVE.w	#$FFFF, $12(A0)
Init_background_ai_car_b:
; Init tail for background AI car type-B objects.
; Installs Background_ai_car_b_obj as the update handler, copies D1 to $8(A0) (sprite data),
; sets $24(A0)=2, loads loc_6E894 speed table into $30(A0), D0 to $34(A0).
; Multiple entry stubs above set D1/D0 per car and BRA here or to Init_background_ai_car_b_screen_right
; (which also sets $12(A0)=$FFFF for screen-right spawn before falling here).
	MOVE.l	#Background_ai_car_b_obj, (A0)
	MOVE.l	D1, $8(A0)
	MOVE.w	#2, $24(A0)
	MOVE.l	#Ai_angle_table, $30(A0)
	MOVE.w	D0, $34(A0)
Background_ai_car_b_obj:
; Per-frame update for background AI cars of type B (normal road traffic, no despawn
; check).  Calls Update_ai_car_screen_x, then dispatches lateral update via
; Ai_car_lateral_dispatch_table with D1=$804B, then tail-jumps to
; Check_ai_lateral_bounds_wide.
	JSR	Update_ai_car_screen_x(PC)
	MOVE.w	#$804B, D1
	LEA	Ai_car_lateral_dispatch_table, A1
	JSR	(A1,D7.w)
	BRA.w	Check_ai_lateral_bounds_wide
Background_ai_car_c_obj_init_fast:
	MOVE.l	#Bg_ai_car_c_fast_sprite_frames, D1
	MOVE.w	#$0128, D0
	BRA.b	Background_ai_car_c_obj_init_done
Background_ai_car_c_obj_spawn:
	MOVE.l	#Background_ai_car_c_obj_init_fast, D1
	MOVE.w	$1E(A0), D0
	JSR	Alloc_aux_object_slot
	MOVE.l	#Bg_ai_car_c_sprite_frames, D1
	MOVE.w	#$FED8, D0
	MOVE.w	#$FFFF, $12(A0)
Background_ai_car_c_obj_init_done:
	MOVE.l	#Background_ai_car_c_obj, (A0)
	MOVE.l	D1, $8(A0)
	MOVE.w	#2, $24(A0)
	MOVE.l	#Ai_angle_table_b, $30(A0)
	MOVE.w	D0, $34(A0)
Background_ai_car_c_obj:
; Per-frame update for type-C background AI cars (Special_road_scene traffic, pair).
; Like Background_ai_car_b_obj but also calls Check_despawn_ai_car and uses the
; narrower Check_ai_lateral_bounds instead of the wide variant.
	JSR	Update_ai_car_screen_x(PC)
	MOVE.w	#$804B, D1
	LEA	Ai_car_lateral_dispatch_table, A1
	JSR	(A1,D7.w)
	JSR	Check_despawn_ai_car(PC)
	BRA.w	Check_ai_lateral_bounds
Background_ai_car_d_obj_init:
; Object init handler for type-D background AI cars.  Installs
; Background_ai_car_d_obj, sets sprite data to Background_ai_car_d_sprite_frames,
; and uses the fixed angle/speed table at $00FF5980 instead of Ai_angle_table.
	MOVE.l	#Background_ai_car_d_obj, (A0)
	MOVE.l	#Background_ai_car_d_sprite_frames, $8(A0)
	MOVE.l	#$00FF5980, $30(A0)
Background_ai_car_d_obj:
; Per-frame update for type-D background AI cars (driven near the kerb in special
; road scenes).  Like Background_ai_car_c_obj but computes its own vertical
; position from Ai_screen_y_table_b rather than using the lateral dispatch result
; directly, and writes it into $16(A0).  Also calls Check_despawn_ai_car.
	JSR	Update_ai_car_screen_x(PC)
	MOVE.w	#$804B, D1
	LEA	Ai_car_lateral_dispatch_table, A1
	JSR	(A1,D7.w)
	JSR	Check_despawn_ai_car(PC)
	MOVE.w	$E(A0), D0
	ANDI.w	#$7FFF, D0
	LEA	Ai_screen_y_table_b, A1
	MOVE.b	(A1,D0.w), D0
	SUB.w	D0, $16(A0)
	RTS
Check_despawn_ai_car:
; Pops the return address from the stack and clears the object slot when
; Special_road_scene.w is 0 (scene has ended).  If scene == 1, additionally
; checks whether the car's screen-X pixel position ($18(A0)) falls outside the
; range defined by the first and third aux-object-pool entries (Special_sign_obj_ptr),
; and clears $4(A0) (sprite data ptr) if so — preventing off-screen rendering.
; Returns normally if the scene is still active and the car is in range.
	MOVE.w	Special_road_scene.w, D1
	BNE.b	Check_despawn_ai_car_active
	MOVE.l	(A7)+, D1
	JMP	Clear_object_slot
Check_despawn_ai_car_active:
	SUBQ.w	#1, D1
	BNE.b	Check_despawn_ai_car_rts
	LEA	Special_sign_obj_ptr.w, A1
	MOVE.w	$18(A0), D1
	CMP.w	$18(A1), D1
	BLT.b	Check_despawn_ai_car_clear
	CMP.w	$58(A1), D1
	BLE.b	Check_despawn_ai_car_rts
Check_despawn_ai_car_clear:
	CLR.l	$4(A0)
Check_despawn_ai_car_rts:
	RTS
Ai_car_lateral_dispatch_table:
; Indexed jump table for AI car lateral position / speed adjustment.
; Called via: LEA Ai_car_lateral_dispatch_table, A1 / JSR (A1,D7.w)
; D1 = speed/position parameter passed to the selected handler.
; Index 0 (D7=0):   RTS (no lateral adjustment)
; Index +2:         NOP word ($4E71) padding
; Index +4:         BRA Ai_car_lateral_update_a (type-A lateral update)
; Higher indices:   Additional lateral update variants
; After the JSR returns, the caller continues with lateral bounds checking.
	RTS
	dc.b	$4E, $71
	BRA.w	Ai_car_lateral_update_a
	CMP.w	$E(A0), D1
	BCS.b	Ai_car_lateral_update_b_in_range
	MOVE.l	(A7)+, D0
	JMP	Clear_object_slot
Ai_car_lateral_update_b_in_range:
	LEA	Road_row_y_buf.w, A1
	MOVE.w	(A1,D0.w), $16(A0)
	LSR.w	#1, D0
	ANDI.w	#$FFFE, D0
	LEA	Road_row_x_buf.w, A1
	MOVE.w	(A1,D0.w), D1
	ADDI.w	#$0180, D1
	ADD.w	D3, D3
	MOVEA.l	$30(A0), A1
	MOVE.w	(A1,D3.w), D3
	TST.w	$12(A0)
	BPL.b	Ai_car_lateral_update_b_pos
	NEG.w	D3
Ai_car_lateral_update_b_pos:
	ADD.w	D3, D1
	MOVE.w	D1, $18(A0)
	TST.w	$24(A0)
	BEQ.b	Ai_car_lateral_update_b_draw
	CMPI.w	#$0090, D1
	BCS.b	Ai_car_lateral_update_b_rts
	CMPI.w	#$0170, D1
	BCS.b	Ai_car_lateral_update_b_draw
Ai_car_lateral_update_b_rts:
	RTS
Ai_car_lateral_update_b_draw:
	LEA	Ai_screen_x_to_angle_table, A1
	MOVE.b	(A1,D4.w), D4
	MOVEA.l	$8(A0), A1
	MOVE.l	(A1,D4.w), $4(A0)
	JMP	Queue_object_for_alt_sprite_buffer
Ai_car_lateral_update_a:
	LEA	Road_scale_table.w, A1
	MOVE.w	(A1,D0.w), D1
	SUBI.w	#$002F, D1
	NEG.w	D1
	ADDI.w	#$0130, D1
	MOVE.w	D1, $16(A0)
	LEA	Road_scanline_x_buf.w, A1
	MOVE.w	(A1,D0.w), D1
	ADDI.w	#$0180, D1
	ADD.w	D3, D3
	MOVEA.l	$30(A0), A1
	MOVE.w	(A1,D3.w), D3
	TST.w	$12(A0)
	BPL.b	Ai_car_lateral_update_a_pos
	NEG.w	D3
Ai_car_lateral_update_a_pos:
	ADD.w	D3, D1
	MOVE.w	D1, $18(A0)
	TST.w	$24(A0)
	BEQ.b	Ai_car_lateral_update_a_draw
	CMPI.w	#$0080, D1
	BCS.b	Ai_car_lateral_update_a_rts
	CMPI.w	#$0180, D1
	BCS.b	Ai_car_lateral_update_a_draw
Ai_car_lateral_update_a_rts:
	RTS
Ai_car_lateral_update_a_draw:
	LEA	Ai_screen_x_to_angle_table, A1
	MOVE.b	(A1,D4.w), D4
	MOVEA.l	$8(A0), A1
	MOVE.l	(A1,D4.w), $4(A0)
	JMP	Queue_object_for_sprite_buffer
;Update_ai_car_screen_x
Update_ai_car_screen_x:
; Computes the AI car's screen X displacement relative to the player and writes
; it to $E(A0). Uses a road displacement look-up table at Ai_screen_y_table.
; Inputs:  A0 = AI car object slot; $1E(A0) = AI car track position (horiz.)
; Outputs: $E(A0) = screen X offset; D7 = direction flag (0=ahead, 4=behind)
	MOVE.w	$1E(A0), D0
	SUB.w	Player_place_score.w, D0
	BMI.b	Update_ai_car_screen_x_Behind
	CMPI.w	#$00A1, D0
	BHI.b	Update_ai_car_screen_x_Offscreen
	MOVE.w	#$00A1, D4
	SUB.w	D0, D4
	MOVEQ	#0, D3
	MOVEQ	#4, D7
;Update_ai_car_screen_x_Y_from_table
Update_ai_car_screen_x_Y_from_table:
	LEA	Ai_screen_y_table, A1
	MOVE.b	(A1,D4.w), D0
	EXT.w	D0
	ADD.w	D0, D0
	ADD.w	D4, D3
	MOVE.w	D3, $E(A0)
	RTS
Update_ai_car_screen_x_Offscreen:
	MOVEQ	#0, D7
	MOVE.w	#$FFFF, $E(A0)
	RTS
Update_ai_car_screen_x_Behind:
	NEG.w	D0
	CMPI.w	#$0091, D0
	BHI.b	Update_ai_car_screen_x_Offscreen
	SUBQ.w	#4, D0
	BCS.b	Update_ai_car_screen_x_Offscreen
	MOVE.w	#$0091, D4
	SUB.w	D0, D4
	MOVE.w	#$8000, D3
	MOVEQ	#8, D7
	BRA.b	Update_ai_car_screen_x_Y_from_table
;Crash_car_obj_init
Crash_car_obj_init:
; Object init handler for the primary crash car.  Sets up a four-object crash
; scene: installs Crash_shadow_obj_init into pool slot $2C0, allocates aux-object
; slots for Crash_lateral_follower, two Crash_depth objects, and a second
; Crash_lateral_follower via Alloc/Find_free_aux_object_slot.  Initialises
; this slot with Setup_ai_object_state (spin-left sprite frames, spawn X=$FE80),
; copies the crash-approach palette into Palette_buffer+$76.
	MOVE.l	#Crash_shadow_obj_init, (Main_object_pool+$2C0).w
	ADDI.w	#$0014, $1E(A0)
	MOVE.w	$1E(A0), D0
	MOVE.l	#Crash_lateral_follower_obj_init, D1
	JSR	Alloc_aux_object_slot
	BCS.b	Crash_car_obj_setup
	ADDQ.w	#8, D0
	MOVE.l	#Crash_depth_obj_init, D1
	JSR	Find_free_aux_object_slot
	MOVE.l	#Crash_depth_obj_init_b, D1
	JSR	Find_free_aux_object_slot
	ADDQ.w	#8, D0
	MOVE.l	#Crash_lateral_follower_obj_init_b, D1
	JSR	Find_free_aux_object_slot
Crash_car_obj_setup:
	MOVE.l	#Crash_car_obj2_init, (Main_object_pool+$280).w
	MOVE.w	D0, (Main_object_pool+$29E).w
	MOVE.l	#Crash_car_obj, D0
	MOVE.l	#Crash_car_spin_left_sprite_frames, D1
	MOVEQ	#-1, D2
	MOVE.w	#$FE80, D3
	JSR	Setup_ai_object_state(PC)
	LEA	Crash_approach_palette_data, A1
	LEA	(Palette_buffer+$76).w, A2
	MOVEQ	#4, D0
Crash_car_obj_copy_loop:
	MOVE.w	(A1)+, (A2)+
	DBF	D0, Crash_car_obj_copy_loop
Crash_car_obj:
	JSR	Update_ai_car_screen_x(PC)
	MOVE.w	#$800A, D1
	LEA	Ai_car_lateral_dispatch_table, A1
	JSR	(A1,D7.w)
	TST.w	D7
	BNE.b	Crash_car_obj_update_body
	RTS
Crash_car_obj_update_body:
	JSR	Check_ai_lateral_bounds_wide(PC)
	MOVE.w	$E(A0), D4
	MOVE.w	D4, D1
	ANDI.w	#$7FFF, D4
	LEA	Ai_screen_y_table_b, A1
	MOVE.b	(A1,D4.w), D4
	MOVE.w	D4, D2
	LSR.w	#1, D2
	MOVE.w	$16(A0), D3
	TST.w	$2A(A0)
	BNE.b	Crash_car_obj_left
	TST.w	D1
	BMI.b	Crash_car_obj_behind
Crash_car_obj_screen_right:
	SUB.w	D4, D3
	MOVE.w	D3, Crash_scene_hud_span.w
	SUB.w	D2, D3
	SUBI.w	#$00C2, D3
	BCC.b	Crash_car_obj_clamp_depth
	ADD.w	D3, D2
Crash_car_obj_clamp_depth:
	MOVE.w	D2, Crash_scene_depth.w
	MOVE.w	$E(A0), D0
	LEA	Ai_screen_y_table, A1
	MOVE.b	(A1,D0.w), D0
	CMPI.w	#$005F, D0
	BLS.b	Crash_car_obj_store_hud
	MOVE.w	#$005F, D0
Crash_car_obj_store_hud:
	MOVE.w	D0, HUD_scroll_base.w
	RTS
Crash_car_obj_behind:
	MOVE.w	#2, Special_road_audio_mode.w
	MOVE.l	#Crash_car_spin_behind_sprite_frames, $8(A0)
	MOVE.w	#$FFFF, $2A(A0)
	JSR	Update_ai_car_sprite_frame(PC)
	BRA.b	Crash_car_obj_offscreen
Crash_car_obj_left:
	TST.w	D1
	BMI.b	Crash_car_obj_offscreen
	MOVE.l	#Crash_car_spin_left_sprite_frames, $8(A0)
	CLR.w	$2A(A0)
	JSR	Update_ai_car_sprite_frame(PC)
	BRA.b	Crash_car_obj_screen_right
Crash_car_obj_offscreen:
	ADDQ.w	#1, D1
	BEQ.b	Crash_car_obj_Rts
	SUB.w	D4, D3
	CMPI.w	#$009A, D3
	BCS.b	Crash_car_obj_Rts
	MOVE.w	D3, Crash_scene_prev_shadow.w
	SUBI.w	#$009A, D3
	MOVE.w	D3, Crash_scene_prev_delta.w
Crash_car_obj_Rts:
	RTS
;Crash_car_obj2_init
Crash_car_obj2_init:
; Object init handler for the secondary (behind-player) crash car object.
; Initialises the slot with Setup_ai_object_state (spin-behind sprite frames,
; spawn X=$FE80).  This object tracks the second perspective of the crash
; to compute depth-sorting data (Crash_scene_shadow_base / depth / delta) and
; clears the slot when Special_sign_obj_ptr is null.
	MOVE.l	#Crash_car_obj2, D0
	MOVE.l	#Crash_car_spin_behind_sprite_frames, D1
	MOVEQ	#-1, D2
	MOVE.w	#$FE80, D3
	JSR	Setup_ai_object_state(PC)
Crash_car_obj2:
	TST.l	Special_sign_obj_ptr.w
	BNE.b	Crash_car_obj2_update
	JMP	Clear_object_slot
Crash_car_obj2_update:
	JSR	Update_ai_car_screen_x(PC)
	MOVE.w	#$800A, D1
	LEA	Ai_car_lateral_dispatch_table, A1
	JSR	(A1,D7.w)
	TST.w	D7
	BNE.b	Crash_car_obj2_update_body
	RTS
Crash_car_obj2_update_body:
	JSR	Check_ai_lateral_bounds_wide(PC)
	MOVE.w	$E(A0), D4
	MOVE.w	D4, D1
	ANDI.w	#$7FFF, D4
	LEA	Ai_screen_y_table_b, A1
	MOVE.b	(A1,D4.w), D4
	MOVE.w	D4, D2
	LSR.w	#1, D2
	MOVE.w	$16(A0), D3
	TST.w	$2A(A0)
	BNE.b	Crash_car_obj2_left
	TST.w	D1
	BMI.b	Crash_car_obj2_behind
Crash_car_obj2_screen_right:
	MOVE.w	$E(A0), D0
	LEA	Ai_screen_y_table, A1
	MOVE.b	(A1,D0.w), D0
	CMPI.w	#$005F, D0
	BLS.b	Crash_car_obj2_clamp_depth
	MOVE.w	#$005F, D0
Crash_car_obj2_clamp_depth:
	MOVE.w	HUD_scroll_base.w, D1
	BNE.b	Crash_car_obj2_hud_set
	MOVE.w	#$005F, D1
Crash_car_obj2_hud_set:
	SUB.w	D0, D1
	BNE.b	Crash_car_obj2_hud_nonzero
	CLR.w	HUD_scroll_base.w
	BRA.b	Crash_car_obj2_depth
Crash_car_obj2_hud_nonzero:
	MOVE.w	D0, HUD_scroll_base.w
	SUBQ.w	#1, D1
	MOVE.w	D1, HUD_blank_row_count.w
Crash_car_obj2_depth:
	SUB.w	D4, D3
	MOVE.w	Crash_scene_hud_span.w, D7
	BNE.b	Crash_car_obj2_depth_nonzero
	MOVE.w	D3, Crash_scene_compare_depth.w
	SUBI.w	#$00C2, D3
	MOVE.w	D3, Crash_scene_delta_depth.w
	RTS
Crash_car_obj2_depth_nonzero:
	SUB.w	D3, D7
	BCC.b	Crash_car_obj2_depth_Rts
	MOVE.w	D3, Crash_scene_compare_depth.w
	NEG.w	D7
	SUBQ.w	#1, D7
	MOVE.w	D7, Crash_scene_delta_depth.w
Crash_car_obj2_depth_Rts:
	RTS
Crash_car_obj2_behind:
	CLR.w	Special_road_audio_mode.w
	MOVE.l	#Crash_car_spin_left_sprite_frames, $8(A0)
	MOVE.w	#$FFFF, $2A(A0)
	JSR	Update_ai_car_sprite_frame(PC)
	BRA.b	Crash_car_obj2_offscreen
Crash_car_obj2_left:
	TST.w	D1
	BMI.b	Crash_car_obj2_offscreen
	MOVE.l	#Crash_car_spin_behind_sprite_frames, $8(A0)
	CLR.w	$2A(A0)
	JSR	Update_ai_car_sprite_frame(PC)
	BRA.w	Crash_car_obj2_screen_right
Crash_car_obj2_offscreen:
	ADDQ.w	#1, D1
	BEQ.b	Crash_car_obj2_Rts
	SUB.w	D4, D3
	CMPI.w	#$009A, D3
	BCS.b	Crash_car_obj2_Rts
	MOVE.w	D3, Crash_scene_shadow_base.w
	SUB.w	D2, D3
	SUBI.w	#$009A, D3
	BCC.b	Crash_car_obj2_shadow_clamp
	ADD.w	D3, D2
Crash_car_obj2_shadow_clamp:
	MOVE.w	D2, Crash_scene_shadow_depth.w
	MOVE.w	Crash_scene_prev_shadow.w, D0
	MOVE.w	Crash_scene_shadow_base.w, D1
	SUB.w	D1, D0
	BLS.b	Crash_car_obj2_clear_fc42
	SUBQ.w	#1, D0
	MOVE.w	D0, Crash_scene_prev_delta.w
	RTS
Crash_car_obj2_clear_fc42:
	CLR.w	Crash_scene_prev_shadow.w
Crash_car_obj2_Rts:
	RTS
Crash_lateral_follower_obj_init:
; Object init handler for the lateral-follower crash sub-object (tracks the
; crash car's lateral screen position for depth compositing).  Entry _init
; uses source pool ptr $FFFFAFC0; entry _init_b uses $FFFFB000.  Both call
; Setup_ai_object_state (no sprite, D2=0, spawn X=$0180) and fall through to
; Crash_lateral_follower_obj immediately.
	MOVE.l	#Crash_lateral_follower_obj, D0
	MOVEQ	#0, D2
	MOVE.w	#$0180, D3
	JSR	Setup_ai_object_state(PC)
	MOVE.l	#$FFFFAFC0, $2C(A0)
	BRA.b	Crash_lateral_follower_obj
Crash_lateral_follower_obj_init_b:
	MOVE.l	#Crash_lateral_follower_obj, D0
	MOVEQ	#0, D2
	MOVE.w	#$0180, D3
	JSR	Setup_ai_object_state(PC)
	MOVE.l	#$FFFFB000, $2C(A0)
Crash_lateral_follower_obj:
	TST.l	Special_sign_obj_ptr.w
	BNE.b	Crash_lateral_follower_obj_update
	JMP	Clear_object_slot
Crash_lateral_follower_obj_update:
	MOVEA.l	$2C(A0), A1
	MOVE.l	$8(A1), D0
	ADDI.w	#$0048, D0
	MOVE.l	D0, $8(A0)
	JSR	Update_ai_car_screen_x(PC)
	MOVE.w	#$800A, D1
	LEA	Ai_car_lateral_dispatch_table, A1
	JSR	(A1,D7.w)
	BRA.w	Check_ai_lateral_bounds_wide
Crash_depth_obj_init:
; Object init handler for the crash-depth sub-objects used for shadow compositing.
; Entry _init: spin-behind frames, D2=-1, spawn X=$FE80.
; Entry _init_b: Crash_depth_sprite_frames, D2=0, spawn X=$0180.
; Both use Setup_ai_object_state and clear the slot when Special_sign_obj_ptr=0.
	MOVE.l	#Crash_depth_obj, D0
	MOVE.l	#Crash_car_spin_behind_sprite_frames, D1
	MOVEQ	#-1, D2
	MOVE.w	#$FE80, D3
	JSR	Setup_ai_object_state(PC)
	BRA.b	Crash_depth_obj
Crash_depth_obj_init_b:
	MOVE.l	#Crash_depth_obj, D0
	MOVE.l	#Crash_depth_sprite_frames, D1
	MOVEQ	#0, D2
	MOVE.w	#$0180, D3
	JSR	Setup_ai_object_state(PC)
Crash_depth_obj:
	TST.l	Special_sign_obj_ptr.w
	BNE.b	Crash_depth_obj_update
	JMP	Clear_object_slot
Crash_depth_obj_update:
	JSR	Update_ai_car_screen_x(PC)
	MOVE.w	#$800A, D1
	LEA	Ai_car_lateral_dispatch_table, A1
	JSR	(A1,D7.w)
	BRA.w	Check_ai_lateral_bounds_wide
;Setup_ai_object_state_alt
Setup_ai_object_state_alt:
; Like Setup_ai_object_state but uses the alternate sprite-angle table Ai_angle_table_b.
	MOVE.l	#Ai_angle_table_b, $30(A0)
	BRA.b	Setup_ai_object_state_common
;Setup_ai_object_state
Setup_ai_object_state:
; Initialises an AI car object slot with handler D0, sprite table ptr D1,
; lateral offset D2, spawn param D3, and the standard angle table loc_6E894.
; Inputs:  A0=object slot, D0=handler addr, D1=sprite table ptr,
;          D2=initial lateral offset, D3=spawn parameter
	MOVE.l	#Ai_angle_table, $30(A0)
;Setup_ai_object_state_common
Setup_ai_object_state_common:
	MOVE.l	D0, (A0)
	MOVE.l	D1, $8(A0)
	MOVE.w	D2, $12(A0)
	MOVE.w	D3, $34(A0)
	MOVE.w	#2, $24(A0)
	RTS
;Update_ai_car_sprite_frame
Update_ai_car_sprite_frame:
; Looks up the AI car's screen-X value in the angle table to choose the
; correct sprite frame index and stores it in $4(A0).
	MOVE.w	$E(A0), D0
	ANDI.w	#$7FFF, D0
	LEA	Ai_screen_x_to_angle_table, A1
	MOVE.b	(A1,D0.w), D0
	MOVEA.l	$8(A0), A1
	MOVE.l	(A1,D0.w), $4(A0)
	RTS
Crash_shadow_obj_init:
; Object init handler for the crash shadow sprite.  Installs Crash_shadow_obj,
; sets sprite data to Crash_shadow_sprite_data, and positions pixel-X at $0100.
	MOVE.l	#Crash_shadow_obj, (A0)
	MOVE.l	#Crash_shadow_sprite_data, $4(A0)
	MOVE.w	#$0100, $18(A0)
Crash_shadow_obj:
	LEA	Special_sign_obj_ptr.w, A1
	TST.l	(A1)
	BNE.b	Crash_shadow_obj_check_side
	JMP	Clear_object_slot
Crash_shadow_obj_check_side:
	TST.w	$E(A1)
	BPL.b	Crash_shadow_obj_car1
	LEA	$40(A1), A1
Crash_shadow_obj_car1:
	MOVE.w	$E(A1), D0
	MOVE.w	D0, D1
	ADDQ.w	#1, D0
	BNE.b	Crash_shadow_obj_update
	RTS
Crash_shadow_obj_update:
	MOVE.w	D1, D0
	ANDI.w	#$7FFF, D0
	LEA	Ai_screen_y_table_b, A2
	MOVE.b	(A2,D0.w), D0
	MOVE.w	$16(A1), D2
	SUB.w	D0, D2
	MOVE.w	D2, $16(A0)
	TST.w	D1
	BMI.b	Crash_shadow_obj_left
	ADDQ.w	#2, D1
	CMPI.w	#$00A1, D1
	BHI.b	Crash_shadow_obj_Rts
	MOVE.w	D1, $E(A0)
	JMP	Queue_object_for_sprite_buffer
Crash_shadow_obj_left:
	ANDI.w	#$7FFF, D1
	ADDQ.w	#2, D1
	CMPI.w	#$0091, D1
	BHI.b	Crash_shadow_obj_Rts
	MOVE.w	D1, $E(A0)
	JMP	Queue_object_for_alt_sprite_buffer
Crash_shadow_obj_Rts:
	RTS
Crash_shadow_sprite_data:
	dc.b	$00, $01, $F1, $01, $FF, $FE, $00, $00, $F1, $01, $FF, $FF, $00, $00
Crash_approach_obj_init:
; Object init handler for the approaching-crash-car scene (Special_road_scene=1).
; Sets up crash car and parked observer car objects in pool slots $2C0/$280,
; calls Setup_ai_object_state_alt for the main approach car (spawn X=$FE00),
; copies crash-approach scroll data to Palette_buffer+$76, and sets
; Special_road_scene=1.  Per-frame handler: Crash_approach_obj.
	MOVE.l	#Crash_shadow_obj_init, (Main_object_pool+$2C0).w
	ADDI.w	#$0014, $1E(A0)
	MOVE.w	$1E(A0), D0
	MOVE.l	#Crash_approach_obj_init_b, (Main_object_pool+$280).w
	MOVE.w	D0, (Main_object_pool+$29E).w
	MOVE.l	#Crash_approach_obj, D0
	MOVE.l	#Crash_approach_sprite_frames, D1
	MOVEQ	#-1, D2
	MOVE.w	#$FE00, D3
	JSR	Setup_ai_object_state_alt(PC)
	CLR.w	$24(A0)
	MOVE.w	#1, Special_road_scene.w
	LEA	Crash_approach_scroll_data, A1
	LEA	(Palette_buffer+$76).w, A2
	MOVEQ	#4, D0
Crash_approach_obj_init_Copy_loop:
	MOVE.w	(A1)+, (A2)+
	DBF	D0, Crash_approach_obj_init_Copy_loop
Crash_approach_obj:
	JSR	Update_ai_car_screen_x(PC)
	CMPI.w	#4, D7
	BEQ.b	Crash_approach_obj_Onscreen
	MOVEQ	#2, D0
	MOVE.w	D0, Special_road_scene.w
	MOVE.w	D0, Special_road_audio_mode.w
	MOVE.w	D0, Road_scroll_update_mode.w
	LEA	Crash_approach_scroll_data, A1
	LEA	(Palette_buffer+$36).w, A2
	MOVEQ	#4, D0
Crash_approach_obj_init_Offscreen_copy:
	MOVE.w	(A1)+, (A2)+
	MOVE.w	$8(A1), $1E(A2)
	DBF	D0, Crash_approach_obj_init_Offscreen_copy
	BRA.w	Crash_approach_obj_Park
Crash_approach_obj_Onscreen:
	LEA	Ai_car_lateral_dispatch_table, A1
	JSR	(A1,D7.w)
	JSR	Check_ai_lateral_bounds(PC)
	MOVE.w	$E(A0), D4
	LEA	Ai_screen_y_table_b, A1
	LEA	Ai_screen_y_table, A2
	MOVEQ	#0, D0
	MOVE.b	(A2,D4.w), D0
	CMPI.w	#$005F, D0
	BLS.b	Crash_approach_obj_Onscreen_Clamp
	MOVE.w	#$005F, D0
Crash_approach_obj_Onscreen_Clamp:
	MOVE.w	D0, $2C(A0)
	MOVE.b	(A1,D4.w), D4
	MOVE.w	D4, D2
	LSR.w	#1, D2
	MOVE.w	$16(A0), D3
	SUB.w	D4, D3
	MOVE.w	D3, Crash_scene_hud_span.w
	SUB.w	D2, D3
	SUBI.w	#$00C2, D3
	BCC.b	Crash_approach_obj_Onscreen_Depth
	ADD.w	D3, D2
Crash_approach_obj_Onscreen_Depth:
	MOVE.w	D2, Crash_scene_depth.w
	MOVE.w	#1, Road_scroll_update_mode.w
	RTS
Crash_approach_obj_init_b:
	MOVE.l	#Crash_approach_obj_b, D0
	MOVE.l	#Crash_approach_b_sprite_frames, D1
	MOVEQ	#0, D2
	MOVE.w	#$0200, D3
	JSR	Setup_ai_object_state_alt(PC)
	CLR.w	$24(A0)
Crash_approach_obj_b:
	JSR	Update_ai_car_screen_x(PC)
	TST.w	$E(A0)
	BPL.b	Crash_approach_obj_Reenter
	JMP	Clear_object_slot
Crash_approach_obj_Reenter:
	LEA	Ai_car_lateral_dispatch_table, A1
	JSR	(A1,D7.w)
	JSR	Check_ai_lateral_bounds(PC)
	MOVE.w	#$0432, D7
	MOVE.w	#$0442, D6
	BRA.w	Write_approach_scroll_strip
Crash_approach_obj_Park:
	MOVE.l	#Crash_approach_obj_Park_Poll, (A0)
	ADDI.w	#$00A2, $1E(A0)
	MOVE.w	#$FFFF, Special_road_blank_bg_flag.w
Crash_approach_obj_Park_Poll:
	JSR	Update_ai_car_screen_x(PC)
	CMPI.w	#4, D7
	BEQ.b	Crash_approach_obj_Park_Onscreen
	CLR.w	Special_road_blank_bg_flag.w
	JMP	Clear_object_slot
Crash_approach_obj_Park_Onscreen:
	LEA	Ai_car_lateral_dispatch_table, A1
	JSR	(A1,D7.w)
	CLR.l	$4(A0)
	MOVE.w	$E(A0), D4
	LEA	Ai_screen_y_table, A2
	MOVE.b	(A2,D4.w), D4
	MOVE.w	#$005F, D0
	SUB.w	D4, D0
	BPL.b	Crash_approach_obj_Park_Onscreen_Clamp
	MOVEQ	#0, D0
Crash_approach_obj_Park_Onscreen_Clamp:
	MOVE.w	D0, $2C(A0)
	RTS
Rival_approach_obj_init:
; Object init handler for the rival-approach scene (Special_road_scene=3).
; Like Crash_approach_obj_init but uses Rival_approach_sprite_frames, sets
; $22(A0)=2 (rival scene flag), copies scroll data from Crash_approach_scroll_buf.
; Also copies a sixth palette word from -$8(A2) (scratch buffer).
; Per-frame handler: Rival_approach_obj.
	ADDI.w	#$0014, $1E(A0)
	MOVE.w	$1E(A0), D0
	MOVE.l	#Rival_approach_obj_init_b, (Main_object_pool+$280).w
	MOVE.w	D0, (Main_object_pool+$29E).w
	MOVE.l	#Rival_approach_obj, D0
	MOVE.l	#Rival_approach_sprite_frames, D1
	MOVEQ	#-1, D2
	MOVE.w	#$FE00, D3
	JSR	Setup_ai_object_state_alt(PC)
	CLR.w	$24(A0)
	MOVE.w	#2, $22(A0)
	MOVE.w	#3, Special_road_scene.w
	LEA	Crash_approach_scroll_buf.w, A1
	LEA	(Palette_buffer+$76).w, A2
	MOVEQ	#4, D0
Rival_approach_obj_init_Copy_loop:
	MOVE.w	(A1)+, (A2)+
	DBF	D0, Rival_approach_obj_init_Copy_loop
	MOVE.w	-$A(A1), -$8(A2)
Rival_approach_obj:
	JSR	Update_ai_car_screen_x(PC)
	CMPI.w	#4, D7
	BEQ.b	Rival_approach_obj_Onscreen
	CLR.w	Special_road_scene.w
	CLR.w	Special_road_audio_mode.w
	MOVE.w	#2, Road_column_update_pending.w
	MOVE.w	#2, Road_scroll_update_mode.w
	LEA	Crash_approach_scroll_buf.w, A1
	LEA	(Palette_buffer+$36).w, A2
	MOVEQ	#4, D0
Rival_approach_obj_init_Offscreen_copy:
	MOVE.w	(A1)+, (A2)+
	MOVE.w	$8(A1), $1E(A2)
	DBF	D0, Rival_approach_obj_init_Offscreen_copy
	BRA.w	Crash_approach_obj_Park
Rival_approach_obj_Onscreen:
	MOVE.w	#1, Road_column_update_pending.w
	LEA	Ai_car_lateral_dispatch_table, A1
	JSR	(A1,D7.w)
	JSR	Check_ai_lateral_bounds(PC)
	MOVE.w	$E(A0), D4
	LEA	Ai_screen_y_table_b, A1
	LEA	Ai_screen_y_table, A2
	MOVEQ	#0, D0
	MOVE.b	(A2,D4.w), D0
	CMPI.w	#$005F, D0
	BLS.b	Rival_approach_obj_Onscreen_Clamp
	MOVE.w	#$005F, D0
Rival_approach_obj_Onscreen_Clamp:
	MOVE.w	D0, $2C(A0)
	MOVE.b	(A1,D4.w), D4
	MOVE.w	D4, $28(A0)
	MOVE.w	$16(A0), D3
	SUB.w	D4, D3
	MOVE.w	D3, Crash_scene_compare_depth.w
	SUBI.w	#$00C2, D3
	MOVE.w	D3, Crash_scene_delta_depth.w
	MOVE.w	#1, Road_scroll_update_mode.w
	RTS
Rival_approach_obj_init_b:
	MOVE.l	#Rival_approach_obj_b, D0
	MOVE.l	#Rival_approach_b_sprite_frames, D1
	MOVEQ	#0, D2
	MOVE.w	#$0200, D3
	JSR	Setup_ai_object_state_alt(PC)
	CLR.w	$24(A0)
Rival_approach_obj_b:
	JSR	Update_ai_car_screen_x(PC)
	TST.w	$E(A0)
	BPL.b	Rival_approach_obj_Reenter
	JMP	Clear_object_slot
Rival_approach_obj_Reenter:
	LEA	Ai_car_lateral_dispatch_table, A1
	JSR	(A1,D7.w)
	JSR	Check_ai_lateral_bounds(PC)
	MOVE.w	#$0442, D7
	MOVE.w	#0, D6
Write_approach_scroll_strip:
; Writes the 32-word Road_column_tile_buf for the approaching-car road column.
; D7 = near-zone tile word, D6 = mid/far-zone tile word.
; Divides the road into up to three horizontal strips (near/mid/far) based on
; Road_scroll_origin_x.w and $18(A0) screen-X, proportionally filling
; Road_column_tile_buf with the two tile values.  Falls back to a uniform fill
; if either zone spans the full width.  Sets Road_column_tiles_dirty=$FFFF.
; Inputs:  D7=near tile, D6=far/mid tile, A1→Road_column_tile_buf.
; Modifies: D0-D5, D7, A1.
	LEA	Road_column_tile_buf.w, A1
	MOVE.w	#$0020, D5
	MOVE.w	Road_scroll_origin_x.w, D0
	MOVE.w	$18(A0), D1
	SUBI.w	#$008C, D0
	BMI.b	Write_approach_scroll_strip_BySpeed
	LSR.w	#3, D0
	BEQ.b	Write_approach_scroll_strip_BySpeed
	CMP.w	D5, D0
	BCC.b	Write_approach_scroll_strip_Uniform_Near
	SUBI.w	#$006B, D1
	LSR.w	#3, D1
	CMP.w	D5, D1
	BCC.b	Write_approach_scroll_strip_SwapZones
	SUB.w	D1, D5
	SUB.w	D0, D1
	SUBQ.w	#1, D0
	SUBQ.w	#1, D1
	SUBQ.w	#1, D5
Write_approach_scroll_strip_Near:
	MOVE.w	D7, (A1)+
	DBF	D0, Write_approach_scroll_strip_Near
Write_approach_scroll_strip_Mid:
	MOVE.w	D6, (A1)+
	DBF	D1, Write_approach_scroll_strip_Mid
Write_approach_scroll_strip_Far:
	MOVE.w	D7, (A1)+
	DBF	D5, Write_approach_scroll_strip_Far
	BRA.b	Write_approach_scroll_strip_Done
Write_approach_scroll_strip_SwapZones:
	MOVE.w	D0, D1
	EXG	D6, D7
	BRA.b	Write_approach_scroll_strip_TwoZone
Write_approach_scroll_strip_BySpeed:
	SUBI.w	#$006B, D1
	BMI.b	Write_approach_scroll_strip_Uniform_Near
	LSR.w	#3, D1
	BEQ.b	Write_approach_scroll_strip_Uniform_Near
	CMP.w	D5, D1
	BCC.b	Write_approach_scroll_strip_Uniform_Far
Write_approach_scroll_strip_TwoZone:
	SUB.w	D1, D5
	SUBQ.w	#1, D5
	SUBQ.w	#1, D1
Write_approach_scroll_strip_TwoZone_Near:
	MOVE.w	D6, (A1)+
	DBF	D1, Write_approach_scroll_strip_TwoZone_Near
Write_approach_scroll_strip_TwoZone_Far:
	MOVE.w	D7, (A1)+
	DBF	D5, Write_approach_scroll_strip_TwoZone_Far
	BRA.b	Write_approach_scroll_strip_Done
Write_approach_scroll_strip_Uniform_Far:
	MOVE.w	D6, D0
	SWAP	D0
	MOVE.w	D6, D0
	BRA.b	Write_approach_scroll_strip_Uniform_Fill
Write_approach_scroll_strip_Uniform_Near:
	MOVE.w	D7, D0
	SWAP	D0
	MOVE.w	D7, D0
Write_approach_scroll_strip_Uniform_Fill:
	MOVEQ	#$0000001F, D1
Write_approach_scroll_strip_Uniform_Loop:
	MOVE.l	D0, (A1)+
	DBF	D1, Write_approach_scroll_strip_Uniform_Loop
Write_approach_scroll_strip_Done:
	MOVE.w	#$FFFF, Road_column_tiles_dirty.w
	RTS
;Check_ai_lateral_bounds
Check_ai_lateral_bounds:
; Narrow-bounds variant: tolerance = $00D8.  Falls through to shared entry.
; Checks whether the AI car's screen-X value ($E(A0)) indicates a lateral
; collision with the player.  If the car is in the "in-range" zone and
; Overtake_delta is 0, computes the gap from the player's Horizontal_position
; relative to $34(A0) (spawn side boundary) and $12(A0) (side flag).
; Sets Retire_flag=1 if Player_speed >= 247 and gap > $38 (close approach).
; Check_ai_lateral_bounds_wide uses tolerance $0118 instead.
	MOVE.w	#$00D8, D7
	BRA.b	Check_ai_lateral_bounds_entry
;Check_ai_lateral_bounds_wide
Check_ai_lateral_bounds_wide:
	MOVE.w	#$0118, D7
;Check_ai_lateral_bounds_entry
Check_ai_lateral_bounds_entry:
	TST.w	Overtake_delta.w
	BNE.b	Check_ai_lateral_bounds_wide_Done
	MOVE.w	$E(A0), D0
	BPL.b	Check_ai_lateral_bounds_Positive
	TST.w	$36(A0)
	BNE.b	Check_ai_lateral_bounds_wide_Done
	ADDQ.w	#1, D0
	BEQ.b	Check_ai_lateral_bounds_At_zero
	BRA.b	Check_ai_lateral_bounds_wide_Done
;Check_ai_lateral_bounds_Positive
Check_ai_lateral_bounds_Positive:
	CMPI.w	#$009B, D0
	BCS.b	Check_ai_lateral_bounds_wide_Done
;Check_ai_lateral_bounds_At_zero
Check_ai_lateral_bounds_At_zero:
	TST.w	$12(A0)
	BMI.b	Check_ai_lateral_bounds_Neg_side
	SUB.w	Horizontal_position.w, D7
	BGE.b	Check_ai_lateral_bounds_wide_Done
	BRA.b	Check_ai_lateral_bounds_Apply
;Check_ai_lateral_bounds_Neg_side
Check_ai_lateral_bounds_Neg_side:
	NEG.w	D7
	SUB.w	Horizontal_position.w, D7
	BLE.b	Check_ai_lateral_bounds_wide_Done
;Check_ai_lateral_bounds_Apply
Check_ai_lateral_bounds_Apply:
	BPL.b	Check_ai_lateral_bounds_Positive_d7
	NEG.w	D7
;Check_ai_lateral_bounds_Positive_d7
Check_ai_lateral_bounds_Positive_d7:
	MOVE.w	D7, Crash_lateral_gap.w
	MOVE.w	#1, $36(A0)
	MOVE.w	Horizontal_position.w, D0
	CMP.w	$34(A0), D0
	SGT	Ai_side_flag.w
	CMPI.w	#247, Player_speed.w ; Crash if speed >= 247
	BCS.b	Check_ai_lateral_bounds_wide_Done
	CMPI.w	#$0038, D7
	BLS.b	Check_ai_lateral_bounds_wide_Done
	MOVE.w	#1, Retire_flag.w
Check_ai_lateral_bounds_wide_Done:
	RTS
Crash_approach_scroll_data:
	dc.w	$0000, $0000, $0888, $0222, $0222, $0000, $0000, $0888, $0888, $0222
Crash_approach_palette_data:
	dc.w	$0040, $0AAA, $0AAA, $0444, $0444
Crash_approach_tile_data_a:
	dc.w	$A7CA, $A7DE, $A7DD, $A7D8, $A7D6, $A7CA, $A7DD, $A7D2, $A7CC, $0000, $A7DC, $A7D1, $A7D2, $A7CF, $A7DD
Crash_approach_tile_data_b:
	dc.w	$0000, $A7D6, $A7CA, $A7D7, $A7DE, $A7CA, $A7D5, $0000, $A7DC, $A7D1, $A7D2, $A7CF, $A7DD, $0000, $0000
;Race_result_overlay_frame
Race_result_overlay_frame:
; Per-frame callback for the championship "between-races" animated overlay
; (Special_road_scene approach animation with live HUD).  Each frame:
;   1. Waits for V-blank.
;   2. Writes a tilemap strip to VDP via Write_tilemap_rows_to_vdp.
;   3. Scrolls Screen_data_ptr if Player_state_flags bit 4 is set (loop wrap check).
;   4. Renders the tilemap buffer and car/gear/timer HUD overlays.
;   5. Updates gap display, race position, race timer, and result scores.
;   6. Dispatches through Race_result_phase_table_1 via Race_result_dispatch_phase.
	JSR	Wait_for_vblank
	MOVE.l	#$462E0000, D7
	MOVE.w	Temp_x_pos.w, D0
	LSR.w	#3, D0
Race_result_overlay_frame_Scroll_loop:
	SUBI.l	#$00020000, D7
	DBF	D0, Race_result_overlay_frame_Scroll_loop
	MOVEM.l	D7, -(A7)
	MOVEQ	#6, D6
	MOVEQ	#$0000000A, D5
	LEA	Tilemap_work_buf.w, A6
	MOVE.l	#$01000000, D3
	MOVE.w	#$04C9, D1
	JSR	Write_tilemap_rows_to_vdp
	MOVEM.l	(A7)+, D7
	BTST.b	#4, Player_state_flags.w
	BEQ.b	Race_result_overlay_frame_Render
	SUBI.l	#$00100000, Screen_data_ptr.w
	CMPI.l	#$FD805C60, Screen_data_ptr.w
	BNE.b	Race_result_overlay_frame_Render
	BCLR.b	#4, Player_state_flags.w
	MOVE.l	#$01805C60, Screen_data_ptr.w
	CLR.w	Ai_lap_transition_flag.w
Race_result_overlay_frame_Render:
	LEA	$00FF5980, A6
	ADDI.l	#$000E0000, D7
	MOVEQ	#0, D6
	MOVEQ	#$0000000A, D5
	JSR	Draw_tilemap_buffer_to_vdp_128_cell_rows
	JSR	Draw_car_machine_graphics(PC)
	JSR	Draw_gear_indicator(PC)
	JSR	Draw_race_timer(PC)
	JSR	Update_gap_to_rival_display
	JSR	Update_race_position_Champ
	JSR	Update_race_timer
	BSR.w	Update_race_result_scores
	LEA	Race_result_phase_table_1, A1
	BRA.w	Race_result_dispatch_phase
;$0000B3C0
;Race_result_frame_2
Race_result_frame_2:
; Per-frame callback for the second phase of the result screen (team-select /
; car-intro screen).  Advances Screen_data_ptr by -$120000 per frame, then
; dispatches through Race_result_phase_table_2 via Race_result_dispatch_phase.
	JSR	Wait_for_vblank
	SUBI.l	#$00120000, Screen_data_ptr.w
	LEA	Race_result_phase_table_2, A1
	BRA.w	Race_result_dispatch_phase
;$0000B3D8
;Race_result_frame_3
Race_result_frame_3:
; Per-frame callback for the third phase (championship standings / podium screen).
; Advances Screen_data_ptr by -$90000 per frame.  If Saved_frame_callback is
; non-null, renders championship standings text and processes standings input
; directly; otherwise dispatches through Race_result_phase_table_3.
	JSR	Wait_for_vblank
	SUBI.l	#$00090000, Screen_data_ptr.w
	TST.l	Saved_frame_callback.w
	BNE.b	Race_result_frame_3_Alt
	LEA	Race_result_phase_table_3, A1
	BRA.b	Race_result_dispatch_phase
Race_result_frame_3_Alt:
	BSR.w	Draw_championship_standings_text
	BSR.w	Championship_standings_input
	BSR.w	Draw_lap_counter_tiles
	RTS
;Race_result_dispatch_phase
Race_result_dispatch_phase:
; Sub-dispatcher used by the three result-screen frame callbacks.
; A1 = phase table base.  Reads Anim_delay.w as the table index, calls the
; indexed phase handler, then manages the three-frame race-timer freeze cycle
; (Race_timer_phase / Race_timer_freeze), and finally calls
; Update_objects_and_build_sprite_buffer and Build_result_scroll_table.
	MOVE.w	Anim_delay.w, D0
	MOVEA.l	(A1,D0.w), A1
	JSR	(A1)
	MOVE.w	#$FFFF, Race_timer_freeze.w
	SUBQ.w	#1, Race_timer_phase.w
	BPL.b	Race_result_dispatch_phase_Objects
	MOVE.w	#2, Race_timer_phase.w
	CLR.w	Race_timer_freeze.w
Race_result_dispatch_phase_Objects:
	JSR	Update_objects_and_build_sprite_buffer
	BSR.b	Build_result_scroll_table
	RTS
Race_result_phase_table_1:
	dc.l	Pre_race_scroll_Lap
	dc.l	Race_result_scroll_in
	dc.l	Race_result_mirror_activate
	dc.l	Pre_race_scroll_Advance
Race_result_phase_table_2:
	dc.l	Pre_race_scroll_Lap
	dc.l	Race_result_show_text
	dc.l	Wait_for_button_press
	dc.l	Draw_intro_car_tilemap
	dc.l	Team_select_update_controls
	dc.l	Championship_team_select_confirm
Race_result_phase_table_3:
	dc.l	Pre_race_scroll_Minimap
	dc.l	Podium_minimap_dispatch
	dc.l	Draw_rival_team_message
	dc.l	Wait_for_button_press
	dc.l	Championship_next_race_advance
	dc.l	Championship_podium_load_or_fade
	dc.l	Championship_team_select_update_controls
	dc.l	Wait_for_button_press
	dc.l	Championship_team_select_confirm
	dc.l	Championship_standings_display_setup
	dc.l	Championship_standings_display_setup_Rts
Build_result_scroll_table:
; Fills Screen_scroll_table_buf with per-scanline (H-scroll, V-scroll) pairs
; for the race-result overlay screen.
; The screen is divided into five vertical bands:
;   Sky     ($30 rows) — both channels zeroed.
;   Road    ($60 rows) — horizontal = Temp_x_pos, vertical = Screen_subcounter.
;   Verge   ($18 rows) — horizontal = 0, vertical = Screen_subcounter.
;   Stripe  ($20 rows) — horizontal = Screen_scroll, vertical = Screen_subcounter.
;   Panel_a ( 3 rows)  — horizontal = Screen_data_ptr, vertical = Screen_subcounter.
;   Panel_b ($18 rows) — horizontal = Screen_data_ptr, vertical = Menu_cursor.
; Inputs:  Screen_scroll.w, Screen_subcounter.w, Screen_data_ptr.w,
;          Menu_cursor.w, Temp_x_pos.w.
; Modifies: D0-D5, A1, Screen_scroll_table_buf.
	LEA	Screen_scroll_table_buf.w, A1
	MOVE.w	Screen_scroll.w, D1
	MOVE.w	Screen_subcounter.w, D2
	MOVE.w	Screen_data_ptr.w, D3
	MOVE.w	Menu_cursor.w, D4
	MOVE.w	Temp_x_pos.w, D5
	MOVE.w	#$002F, D0
Build_result_scroll_table_Sky:
	MOVE.w	#0, (A1)+
	MOVE.w	#0, (A1)+
	DBF	D0, Build_result_scroll_table_Sky
	MOVE.w	#$005F, D0
Build_result_scroll_table_Road:
	MOVE.w	D5, (A1)+
	MOVE.w	D2, (A1)+
	DBF	D0, Build_result_scroll_table_Road
	MOVE.w	#$0017, D0
Build_result_scroll_table_Verge:
	MOVE.w	#0, (A1)+
	MOVE.w	D2, (A1)+
	DBF	D0, Build_result_scroll_table_Verge
	MOVE.w	#$001F, D0
Build_result_scroll_table_Stripe:
	MOVE.w	D1, (A1)+
	MOVE.w	D2, (A1)+
	DBF	D0, Build_result_scroll_table_Stripe
	MOVE.w	#2, D0
Build_result_scroll_table_Panel_a:
	MOVE.w	D3, (A1)+
	MOVE.w	D2, (A1)+
	DBF	D0, Build_result_scroll_table_Panel_a
	MOVE.w	#$0017, D0
Build_result_scroll_table_Panel_b:
	MOVE.w	D3, (A1)+
	MOVE.w	D4, (A1)+
	DBF	D0, Build_result_scroll_table_Panel_b
	RTS
Race_result_scroll_in:
	ADDQ.w	#8, Temp_x_pos.w
	CMPI.w	#$00B0, Temp_x_pos.w
	BCS.b	Race_result_scroll_in_Rts
	MOVE.w	#$00B0, Temp_x_pos.w
	ADDQ.w	#4, Anim_delay.w
Race_result_scroll_in_Rts:
	RTS
;Race_result_mirror_activate
Race_result_mirror_activate:
; Activates the rival-car mirror-image palette for the result screen.
; Reads Ai_lap_transition_flag_b.w: if zero, falls through immediately to
; Race_result_event_sequence.  Bit 0 selects between Team_palette_copy_buf
; (bit set = rival A) and Team_palette_copy_buf+$8 (bit clear = rival B).
; Copies four palette words from the selected buffer into Palette_buffer+$2C
; and sets bit 4 of Player_state_flags.w to mark the mirror active.
; Modifies: D0, A1, A2, Palette_buffer+$2C..$33.
	MOVE.b	Ai_lap_transition_flag_b.w, D0
	BEQ.b	Race_result_event_sequence
	LEA	Team_palette_copy_buf.w, A1
	BTST.l	#0, D0
	BNE.b	Race_result_mirror_activate_Copy
	LEA	(Team_palette_copy_buf+$8).w, A1
Race_result_mirror_activate_Copy:
	BSET.b	#4, Player_state_flags.w
	LEA	(Palette_buffer+$2C).w, A2
	MOVE.w	#3, D0
Race_result_mirror_activate_Copy_loop:
	MOVE.w	(A1)+, (A2)+
	DBF	D0, Race_result_mirror_activate_Copy_loop
;Race_result_event_sequence
Race_result_event_sequence:
; Per-frame handler for the race-result tire/pit-event animation sequence.
; Called every frame during the result overlay.
; Counts down Screen_state_byte_1.w; on every 6th frame advances one tire-stat
; event: reads Tire_stat_delta_base.w array and adds each delta to
; Tire_steering_durability_acc.w, clamping to Tire_stat_max_base.w.
; Clears the corresponding bit in Race_event_flags.w when a stat is maxed.
; After tire stats, checks Race_event_flags.w bits 6 and 7 (pit flags):
;   Bit 6: shows/hides pit-stop overlay objects in Aux_object_pool.
;   Bit 7: shows/hides tire-change objects in Aux_object_pool.
; Then calls Race_result_scan_tires to detect when all tire objects are done.
; Modifies: D0-D1, A1-A3, Race_event_flags.w, Tire_steering_durability_acc,
;           Aux_object_pool+$21E/$25E/$29E/$2DE, Screen_state_byte_1.w.
	MOVE.b	Race_event_flags.w, D0
	BEQ.b	Race_result_event_sequence_Flags
	SUBQ.w	#1, Screen_state_byte_1.w
	BNE.b	Race_result_event_sequence_Flags
	MOVE.w	#6, Screen_state_byte_1.w
	LEA	Tire_steering_durability_acc.w, A1
	LEA	Tire_stat_max_base.w, A2
	LEA	Tire_stat_delta_base.w, A3
	MOVE.w	#4, D0
Race_result_event_sequence_Loop:
	MOVE.w	(A3)+, D1
	ADD.w	D1, (A1)
	MOVE.w	(A2)+, D1
	CMP.w	(A1), D1
	BCC.w	Race_result_event_sequence_Next
	MOVE.w	D1, (A1)
	BCLR.b	D0, Race_event_flags.w
Race_result_event_sequence_Next:
	MOVE.w	(A1)+, D1
	DBF	D0, Race_result_event_sequence_Loop
Race_result_event_sequence_Flags:
	BTST.b	#6, Race_event_flags.w
	BEQ.b	Race_result_event_sequence_Pit
	MOVE.b	Race_event_flags.w, D0
	ANDI.b	#$1A, D0
	BNE.b	Race_result_event_sequence_Pit
	BCLR.b	#6, Race_event_flags.w
	MOVE.w	#$FFFF, (Aux_object_pool+$9E).w
	MOVE.w	#$FFFF, (Aux_object_pool+$DE).w
	MOVE.w	#$0010, (Aux_object_pool+$29E).w
	MOVE.w	#$0010, (Aux_object_pool+$2DE).w
Race_result_event_sequence_Pit:
	BTST.b	#7, Race_event_flags.w
	BEQ.b	Race_result_scan_tires
	MOVE.b	Race_event_flags.w, D0
	ANDI.b	#5, D0
	BNE.b	Race_result_scan_tires
	BCLR.b	#7, Race_event_flags.w
	MOVE.w	#$0010, (Aux_object_pool+$21E).w
	MOVE.w	#$0010, (Aux_object_pool+$25E).w
	MOVE.w	#$0010, (Aux_object_pool+$29E).w
	BTST.b	#5, Race_event_flags.w
	BEQ.b	Race_result_scan_tires_Alt
	MOVE.w	#$FFFF, (Aux_object_pool+$29E).w
	BRA.b	Race_result_scan_tires
Race_result_scan_tires_Alt:
	MOVE.w	#$FFFF, (Aux_object_pool+$21E).w
	MOVE.w	#$FFFF, (Aux_object_pool+$25E).w
Race_result_scan_tires:
	LEA	(Aux_object_pool+$1E).w, A1
	MOVE.w	#$000B, D0
Race_result_scan_tires_Loop:
	CMPI.w	#$F000, (A1)
	BCS.b	Race_result_scan_tires_Rts
	ADDA.w	#$0040, A1
	DBF	D0, Race_result_scan_tires_Loop
	ADDQ.w	#4, Anim_delay.w
Race_result_scan_tires_Rts:
	RTS
;Race_result_show_text
Race_result_show_text:
; Loads the team's post-race message and renders it to the dialogue tilemap panel.
; Counts down Screen_state_byte_1.w; returns early unless it reaches zero.
; On the trigger frame: loads font tiles, selects the team's pre-race message text,
; renders it to the tilemap via Render_text_to_tilemap.  If bit 5 of Player_team.w
; is set (rival present), also selects and renders the rival's team name.
; Finally draws the message panel wide and increments Anim_delay by 4.
; Modifies: Font_tile_base.w, Screen_state_byte_1.w, Anim_delay.w, tilemap DMA.
	SUBQ.w	#1, Screen_state_byte_1.w
	BNE.b	Race_result_show_text_Rts
	MOVE.w	#$431D, Font_tile_base.w
	JSR	Load_font_tiles_to_work_buffer
	JSR	Select_team_pre_race_message
	JSR	Render_text_to_tilemap
	BTST.b	#5, Player_team.w
	BEQ.b	Race_result_show_text_Done
	JSR	Select_rival_team_name
	JSR	Render_text_to_tilemap
Race_result_show_text_Done:
	MOVE.l	#$440A0000, D7
	JSR	Draw_message_panel_wide
	ADDQ.w	#4, Anim_delay.w
Race_result_show_text_Rts:
	RTS
;Wait_for_button_press
Wait_for_button_press:
; Frame_callback stub: advances the result screen when A, B, C, or Start is pressed.
; Reads the upper nibble of Input_click_bitset.w (face/start buttons).
; If any of those bits are set, increments Anim_delay.w by 4 (unblocking the
; scheduler to move to the next phase); otherwise returns without advancing.
; Modifies: D0, Anim_delay.w.
	MOVE.b	Input_click_bitset.w, D0
	ANDI.b	#$F0, D0
	BEQ.b	Wait_for_button_press_Rts
	ADDQ.w	#4, Anim_delay.w
Wait_for_button_press_Rts:
	RTS
Draw_intro_car_tilemap:
; Draws the intro car tilemap to VDP during the team-select screen.
; If bit 5 of Player_team.w is set (rival encounter mode), skips the draw and
; adds 8 to Anim_delay.w instead (stall to let a prior DMA finish).
; Otherwise draws Team_select_intro_car_tilemap via Draw_packed_tilemap_to_vdp
; with interrupts masked, advances Anim_delay by 4, and clears Screen_state_byte_1.w.
; Modifies: A6, Anim_delay.w, Screen_state_byte_1.w, VDP state.
	BTST.b	#5, Player_team.w
	BNE.b	Draw_intro_car_tilemap_Queued
	LEA	Team_select_intro_car_tilemap, A6
	ORI	#$0700, SR
	JSR	Draw_packed_tilemap_to_vdp
	ANDI	#$F8FF, SR
	ADDQ.w	#4, Anim_delay.w
	CLR.b	Screen_state_byte_1.w
	RTS
Draw_intro_car_tilemap_Queued:
	ADDQ.w	#8, Anim_delay.w
	RTS
Team_select_update_controls:
; Frame_callback for the arcade-mode team-select screen.  Processes player input
; each frame to select a transmission (manual CO / automatic OO) and confirm team.
; Screen_state_byte_1 tracks gear and confirmation state:
;   bit 0: automatic (OO) mode active
;   bit 3: player has pressed a button and gear is locked in
; On button press (upper bits of Input_click_bitset, mask $FC):
;   bits 2-3 set → set automatic (OO) indicator, set bit 0 of state.
;   bits 2-3 clear (A/B/C/Start) → if manual, advance to championship standings;
;                                   if automatic, return to arcade race init.
; When bit 3 of Screen_state_byte_1 is set: renders the current CO/OO indicator
; to VDP (direct write, interrupts masked).
; Increments Screen_state_byte_1 by 2 and sets Track_index_arcade_mode to 1.
; Modifies: D0, Screen_state_byte_1.w, Track_index_arcade_mode.w,
;           Audio_sfx_cmd, Frame_callback.w, Selection_count.w, VDP.
	ADDQ.b	#2, Screen_state_byte_1.w
	MOVE.w	#1, Track_index_arcade_mode.w
	MOVE.b	Input_click_bitset.w, D0
	ANDI.b	#$FC, D0
	BEQ.b	Team_select_update_controls_Check
	MOVE.w	#Sfx_menu_confirm, Audio_sfx_cmd
	ANDI.b	#$0C, D0
	BEQ.b	Team_select_update_controls_NoShift
	BSR.w	Set_gear_indicator_OO
	ADDQ.b	#1, Screen_state_byte_1.w
	BRA.b	Team_select_update_controls_Check
Team_select_update_controls_NoShift:
	BTST.b	#0, Screen_state_byte_1.w
	BNE.b	Team_select_update_controls_Back
	MOVE.w	#$000E, Selection_count.w
	MOVE.l	#Championship_standings_2_init, Frame_callback.w
	RTS
Team_select_update_controls_Back:
	ANDI.b	#$CF, Player_team.w
	MOVE.l	#Arcade_race_init, Frame_callback.w
	RTS
Team_select_update_controls_Check:
	BTST.b	#3, Screen_state_byte_1.w
	BEQ.b	Set_gear_indicator_OO
	BTST.b	#0, Screen_state_byte_1.w
	BEQ.b	Set_gear_indicator_CO
	ORI	#$0700, SR
	MOVE.l	#$4E160000, VDP_control_port
	MOVE.w	#$434F, VDP_data_port
	MOVE.l	#$4E240000, VDP_control_port
	MOVE.w	#$434D, VDP_data_port
	ANDI	#$F8FF, SR
	RTS
Set_gear_indicator_CO:
; Writes "CO" (manual) to the two gear-indicator tile cells on the VDP.
; Masks interrupts, writes tile word $434D ('C') to VDP address $4E160000
; and tile word $434F ('O') to $4E240000, then unmasks.
; Called from Team_select_update_controls_Check when bit 0 of Screen_state_byte_1 = 0.
; Modifies: VDP_control_port, VDP_data_port, SR.
	ORI	#$0700, SR
	MOVE.l	#$4E160000, VDP_control_port
	MOVE.w	#$434D, VDP_data_port
	MOVE.l	#$4E240000, VDP_control_port
	MOVE.w	#$434F, VDP_data_port
	ANDI	#$F8FF, SR
	RTS
;Set_gear_indicator_OO
Set_gear_indicator_OO:
; Writes "OO" (automatic) to the two gear-indicator tile cells on the VDP.
; Masks interrupts, writes tile word $434F ('O') to VDP address $4E160000
; and tile word $434F ('O') to $4E240000, then unmasks.
; Called from Team_select_update_controls_Check when bit 0 of Screen_state_byte_1 = 1
; or when the player selects automatic transmission.
; Modifies: VDP_control_port, VDP_data_port, SR.
	ORI	#$0700, SR
	MOVE.l	#$4E160000, VDP_control_port
	MOVE.w	#$434F, VDP_data_port
	MOVE.l	#$4E240000, VDP_control_port
	MOVE.w	#$434F, VDP_data_port
	ANDI	#$F8FF, SR
	RTS
Draw_rival_team_message:
; Renders the rival team's post-race message panel.
; Sets Palette_buffer+$44 to bright white ($0EEE) as the dialogue background colour,
; then loads the font tile base, selects the post-race message text, renders it to
; the tilemap, and draws the message panel via Draw_message_panel_wide.
; Increments Anim_delay.w by 4 to advance the result-screen scheduler.
; Modifies: D7, Palette_buffer+$44, Font_tile_base.w, Anim_delay.w, VDP state.
	MOVE.w	#$0EEE, (Palette_buffer+$44).w
	MOVE.w	#$431D, Font_tile_base.w
	JSR	Load_font_tiles_to_work_buffer
	JSR	Select_post_race_message
	JSR	Render_text_to_tilemap
	MOVE.l	#$440A0000, D7
	JSR	Draw_message_panel_wide
	ADDQ.w	#4, Anim_delay.w
	RTS
Championship_next_race_advance:
; Frame_callback stub called after the race-result screen to advance to the next
; championship race or trigger the champion/rival-encounter cutscene.
; Increments Track_index.w.  If Track_index == 16 (all 16 races done):
;   Scans Driver_points_by_team; if no other team has more points than the player,
;   the player has won the championship.
;   - If bit 6 of Player_team.w is set (second year): goes to Championship_final_init.
;   - Otherwise: triggers Championship_driver_select_init + rival encounter music.
; Otherwise (race not over), checks Rival_team flags for a rival dialogue message:
;   - If bits 5 or 7 of Rival_team are set and the rival index is >= player: renders
;     the rival name + message dialogue via Championship_next_race_advance_ShowMsg.
;   - Else: advances Anim_delay by 16 and returns.
; Modifies: Track_index.w, D0-D6, A1-A6, Frame_callback.w, Audio_music_cmd.
	ADDQ.w	#1, Track_index.w
	CMPI.w	#$0010, Track_index.w
	BNE.b	Championship_next_race_advance_Rival
	CLR.l	D0
	LEA	Driver_points_by_team.w, A6
	MOVE.b	Player_team.w, D0
	ANDI.b	#$0F, D0 ; isolate the player's team number
	MOVE.b	(A6,D0.w), D1
	MOVE.w	#$0010, D0
Championship_next_race_advance_Loop:
	CMP.b	(A6)+, D1
	BCS.b	Championship_next_race_advance_Rival
	DBF	D0, Championship_next_race_advance_Loop
	BTST.b	#6, Player_team.w
	BEQ.b	Championship_next_race_advance_RivalEncounter
	MOVE.l	#Championship_final_init, Frame_callback.w
	RTS
Championship_next_race_advance_RivalEncounter:
	MOVE.l	#Championship_driver_select_init, Frame_callback.w
	MOVE.w	#Music_rival_encounter, Audio_music_cmd ; rival team encounter music
	RTS
Championship_next_race_advance_Rival:
	MOVE.b	Rival_team.w, D0
	ANDI.b	#$A0, D0
	BEQ.w	Championship_next_race_advance_Delay
	BTST.b	#5, Rival_team.w
	BNE.b	Championship_next_race_advance_ShowMsg
	MOVE.b	Player_team.w, D0
	MOVE.b	Rival_team.w, D1
	ANDI.b	#$0F, D0 ; isolate the player's team number
	ANDI.b	#$0F, D1 ; isolate the rival's team number
	CMP.b	D0, D1
	BCS.w	Championship_next_race_advance_Delay
	ADDQ.w	#4, Anim_delay.w
	RTS
Championship_next_race_advance_ShowMsg:
	LEA	Dialogue_tilemap_buf.w, A6
	LEA	Championship_podium_text_jp, A1
	LEA	Team_name_display_strings, A2
	MOVE.w	#8, D5
	MOVE.w	#$00BD, D0
	LEA	Podium_name_buffer_jp.w, A4
	MOVE.w	#9, D1
	MOVE.w	#$0014, D6
	MOVE.l	#$4B0C0000, D7
	TST.w	English_flag.w
	BEQ.b	Championship_next_race_advance_ShowMsg_Copy
	LEA	Championship_podium_text_en, A1
	ADDA.l	#$00000090, A2
	MOVE.w	#$00CF, D0
	LEA	Podium_name_buffer_en.w, A4
	MOVE.w	#$000C, D1
	MOVE.w	#$0016, D6
	MOVE.l	#$4B0A0000, D7
Championship_next_race_advance_ShowMsg_Copy:
	CLR.l	D2
	MOVE.b	Rival_team.w, D2
	ANDI.b	#$0F, D2 ; isolate the rival's team number
	MULS.w	D1, D2
	ADDA.l	D2, A2
	LEA	Dialogue_tilemap_buf.w, A3
Championship_next_race_advance_ShowMsg_Name_loop:
	CLR.w	D3
	MOVE.b	(A1)+, D3
	ADDI.w	#$431D, D3
	MOVE.w	D3, (A3)+
	DBF	D0, Championship_next_race_advance_ShowMsg_Name_loop
	SUBQ.w	#1, D1
Championship_next_race_advance_ShowMsg_Msg_loop:
	CLR.w	D3
	MOVE.b	(A2)+, D3
	ADDI.w	#$431D, D3
	MOVE.w	D3, (A4)+
	DBF	D1, Championship_next_race_advance_ShowMsg_Msg_loop
	ORI	#$0700, SR
	JSR	Draw_tilemap_buffer_to_vdp_128_cell_rows
	ANDI	#$F8FF, SR
	ADDQ.w	#8, Anim_delay.w
	RTS
Championship_next_race_advance_Delay:
	ADDI.w	#$0010, Anim_delay.w
	RTS
Championship_podium_load_or_fade:
; Frame_callback for the championship podium/next-race transition screen.
; Two modes based on Aux_object_pool+$80:
;   Non-zero: a podium car animation is still running — clears the slot and returns.
;   Zero:     begins the fade-out / next-rival-name sequence:
;     • Halts audio and waits for two VBlanks.
;     • Plays Sfx_demo_transition twice (one frame apart).
;     • Fades all palette entries in Palette_buffer+$20 for 7 frames by calling
;       Pack_tile_palette_field three times per colour per frame (6-step fade).
;     • Spins on a ~1M-cycle busy loop for a blank pause.
;     • Calls Advance_rival_promotion_state.
;     • Selects the next rival team name and message based on English_flag.w,
;       then copies them into Dialogue_tilemap_buf via the 0x431D tile offset.
;     • Draws the tilemap buffer to VDP and adds 8 to Anim_delay.w.
; Modifies: D0-D6, A0-A4, Palette_buffer, Anim_delay.w, Audio_sfx_cmd.
	TST.l	(Aux_object_pool+$80).w
	BEQ.b	Championship_podium_load_or_fade_Fade
	CLR.l	(Aux_object_pool+$80).w
	RTS
Championship_podium_load_or_fade_Fade:
	JSR	Halt_audio_sequence
	JSR	Wait_for_vblank
	JSR	Wait_for_vblank
	MOVE.w	#Sfx_demo_transition, Audio_sfx_cmd ; screen-transition sound
	JSR	Wait_for_vblank
	MOVE.w	#Sfx_demo_transition, Audio_sfx_cmd ; repeat next frame
	MOVEQ	#6, D0
Championship_podium_load_or_fade_Fade_loop:
	LEA	(Palette_buffer+$20).w, A0
	MOVEQ	#$00000030, D1
Championship_podium_load_or_fade_Palette_loop:
	MOVEQ	#0, D5
	MOVE.w	(A0), D2
	ROL.w	#4, D2
	BSR.w	Pack_tile_palette_field
	BSR.w	Pack_tile_palette_field
	BSR.w	Pack_tile_palette_field
	MOVE.w	D5, (A0)+
	DBF	D1, Championship_podium_load_or_fade_Palette_loop
	MOVE.l	#$0EEE0800, (Palette_buffer+$44).w
	JSR	Wait_for_vblank
	JSR	Wait_for_vblank
	JSR	Wait_for_vblank
	JSR	Wait_for_vblank
	JSR	Wait_for_vblank
	JSR	Wait_for_vblank
	JSR	Wait_for_vblank
	DBF	D0, Championship_podium_load_or_fade_Fade_loop
	MOVE.l	#$00100000, D0
Championship_podium_load_or_fade_Wait:
	SUBQ.l	#1, D0
	BNE.b	Championship_podium_load_or_fade_Wait
	BSR.w	Advance_rival_promotion_state
	LEA	Dialogue_tilemap_buf.w, A6
	LEA	Championship_podium_text_jp, A1
	LEA	Team_name_display_strings, A2
	MOVE.w	#4, D5
	MOVEQ	#$00000054, D4
	MOVE.w	#$0053, D0
	LEA	Podium_name_buffer_jp.w, A4
	MOVE.w	#9, D1
	MOVE.w	#$0014, D6
	MOVE.l	#$4B0C0000, D7
	TST.w	English_flag.w
	BEQ.b	Championship_podium_load_or_fade_Copy
	LEA	Championship_podium_text_en, A1
	ADDA.l	#$00000090, A2
	MOVEQ	#$0000005C, D4
	MOVE.w	#$005B, D0
	LEA	Podium_name_buffer_en.w, A4
	MOVE.w	#$000C, D1
	MOVE.w	#$0016, D6
	MOVE.l	#$4A0A0000, D7
Championship_podium_load_or_fade_Copy:
	CLR.l	D2
	MOVE.b	Rival_team.w, D2
	ANDI.b	#$0F, D2 ; isolate the rival's team number
	MOVE.w	Promoted_teams_bitfield.w, D3
Championship_podium_load_or_fade_Rival_loop:
	ADDQ.b	#1, D2
	BTST.l	D2, D3
	BNE.b	Championship_podium_load_or_fade_Rival_loop
	MULS.w	D1, D2
	ADDA.l	D2, A2
	LEA	Dialogue_tilemap_buf.w, A3
Championship_podium_load_or_fade_Name_loop:
	CLR.w	D3
	MOVE.b	(A1)+, D3
	ADDI.w	#$431D, D3
	MOVE.w	D3, (A3)+
	DBF	D0, Championship_podium_load_or_fade_Name_loop
	ADDA.l	D4, A1
	MOVE.w	#$0016, D0
Championship_podium_load_or_fade_Name2_loop:
	CLR.w	D3
	MOVE.b	(A1)+, D3
	ADDI.w	#$431D, D3
	MOVE.w	D3, (A3)+
	DBF	D0, Championship_podium_load_or_fade_Name2_loop
	SUBQ.w	#1, D1
Championship_podium_load_or_fade_Msg_loop:
	CLR.w	D3
	MOVE.b	(A2)+, D3
	ADDI.w	#$431D, D3
	MOVE.w	D3, (A4)+
	DBF	D1, Championship_podium_load_or_fade_Msg_loop
	ORI	#$0700, SR
	JSR	Draw_tilemap_buffer_to_vdp_128_cell_rows
	ANDI	#$F8FF, SR
	ADDQ.w	#8, Anim_delay.w
	RTS
Pack_tile_palette_field:
; Helper: extracts one 4-bit palette nibble from D2 and packs it into D5.
; Called three times per colour word in Championship_podium_load_or_fade to
; produce a faded/dimmed copy of each channel.
; Algorithm: shift D5 left by 4, rotate D2 left by 4 to expose the next nibble,
; take bits 1-3 of that nibble (mask $000E), subtract 2 with floor at 0, OR into D5.
; Net effect: each RGB channel is decremented by 1 each call (minimum 0).
; Inputs:  D2 = source colour word (rotated each call), D5 = accumulator (0 on first).
; Outputs: D5 updated (bits 11-0 receive the three packed nibbles after 3 calls).
; Modifies: D2, D3, D5.
	LSL.w	#4, D5
	ROL.w	#4, D2
	MOVE.w	D2, D3
	ANDI.w	#$000E, D3
	SUBQ.w	#2, D3
	BCC.b	Pack_tile_palette_field_Nonzero
	MOVEQ	#0, D3
Pack_tile_palette_field_Nonzero:
	OR.w	D3, D5
	RTS
Championship_team_select_update_controls:
; Frame_callback for the championship team-select screen.  Mirrors the structure
; of Team_select_update_controls but operates on championship state and uses the
; championship VDP gear-indicator tile addresses ($5212/$5222 instead of $4E16/$4E24).
; Screen_state_byte_1 tracks gear and confirmation state:
;   bit 0: automatic (OO) mode active
;   bit 3: player has pressed a button and gear is locked in
; On button press (Input_click_bitset mask $FC):
;   bits 2-3 → automatic (OO) selected; set bit 0 of state.
;   bits 2-3 clear → confirm current gear selection:
;     Manual: advance to championship standings (Saved_frame_callback = Championship_standings_init).
;     Automatic: go back to Title_menu.
; Increments Screen_state_byte_1 by 2 each frame.
; Modifies: D0, Screen_state_byte_1.w, Audio_sfx_cmd, Saved_frame_callback.w,
;           Selection_count.w, VDP.
	ADDQ.b	#2, Screen_state_byte_1.w
	MOVE.b	Input_click_bitset.w, D0
	ANDI.b	#$FC, D0
	BEQ.w	Championship_team_select_update_controls_Check
	MOVE.w	#Sfx_menu_confirm, Audio_sfx_cmd
	ANDI.b	#$0C, D0
	BEQ.b	Championship_team_select_update_controls_NoShift
	BSR.w	Set_champ_gear_indicator_OO
	ADDQ.b	#1, Screen_state_byte_1.w
	BRA.w	Championship_team_select_update_controls_Check
Championship_team_select_update_controls_NoShift:
	BTST.b	#0, Screen_state_byte_1.w
	BNE.w	Championship_team_select_update_controls_Back
	MOVE.w	#$000A, Selection_count.w
	MOVE.l	#Championship_standings_init, Saved_frame_callback.w
	RTS
Championship_team_select_update_controls_Back:
	BCLR.b	#5, Rival_team.w
	MOVE.w	#$000A, Selection_count.w
	MOVE.l	#Title_menu, Saved_frame_callback.w
	RTS
Championship_team_select_update_controls_Check:
	BTST.b	#3, Screen_state_byte_1.w
	BEQ.b	Set_champ_gear_indicator_OO
	BTST.b	#0, Screen_state_byte_1.w
	BEQ.b	Set_champ_gear_indicator_CO
	ORI	#$0700, SR
	MOVE.l	#$52120000, VDP_control_port
	MOVE.w	#$434F, VDP_data_port
	MOVE.l	#$52220000, VDP_control_port
	MOVE.w	#$434D, VDP_data_port
	ANDI	#$F8FF, SR
	RTS
Set_champ_gear_indicator_CO:
; Writes "CO" (manual) to the championship team-select gear-indicator cells.
; Uses VDP addresses $52120000 / $52220000 (different from the arcade-mode versions
; at $4E16 / $4E24).  Tile words: $434D ('C'), $434F ('O').
; Modifies: VDP_control_port, VDP_data_port, SR.
	ORI	#$0700, SR
	MOVE.l	#$52120000, VDP_control_port
	MOVE.w	#$434D, VDP_data_port
	MOVE.l	#$52220000, VDP_control_port
	MOVE.w	#$434F, VDP_data_port
	ANDI	#$F8FF, SR
	RTS
;Set_champ_gear_indicator_OO
Set_champ_gear_indicator_OO:
; Writes "OO" (automatic) to the championship team-select gear-indicator cells.
; Uses VDP addresses $52120000 / $52220000.  Both tile words = $434F ('O').
; Modifies: VDP_control_port, VDP_data_port, SR.
	ORI	#$0700, SR
	MOVE.l	#$52120000, VDP_control_port
	MOVE.w	#$434F, VDP_data_port
	MOVE.l	#$52220000, VDP_control_port
	MOVE.w	#$434F, VDP_data_port
	ANDI	#$F8FF, SR
	RTS
;Pre_race_scroll_Lap
Pre_race_scroll_Lap:
; Frame_callback entry-point: "count lap" phase of the between-races scroll.
; Decrements Screen_timer.w by $1070 each frame.  When it goes negative:
;   advances Anim_delay by 4, clears Screen_timer, increments Laps_completed,
;   then falls through to Pre_race_scroll_Update to update scroll positions.
	SUBI.l	#$00001070, Screen_timer.w
	BCC.b	Pre_race_scroll_Update
	ADDQ.w	#4, Anim_delay.w
	CLR.l	Screen_timer.w
	ADDQ.w	#1, Laps_completed.w
	BRA.b	Pre_race_scroll_Update
;Pre_race_scroll_Minimap
Pre_race_scroll_Minimap:
; Frame_callback entry-point: "display minimap" phase of the between-races scroll.
; Dispatches to Podium_minimap_dispatch, then decrements Screen_timer by $1070.
; When it goes negative: advances Anim_delay by 4, clears Screen_timer,
; then falls through to Pre_race_scroll_Update.
	JSR	Podium_minimap_dispatch(PC)
	SUBI.l	#$00001070, Screen_timer.w
	BCC.b	Pre_race_scroll_Update
	ADDQ.w	#4, Anim_delay.w
	CLR.l	Screen_timer.w
	BRA.b	Pre_race_scroll_Update
;Pre_race_scroll_Advance
Pre_race_scroll_Advance:
; Frame_callback entry-point: "advance" phase — scrolls the background panel in
; and eventually transitions to Championship_race_init.
; Decrements Screen_data_ptr by $30000 each frame (panel slides out) and adds
; $F00 to Screen_timer.  When Screen_timer reaches $50000, installs
; Championship_race_init as the next Frame_callback and falls through to
; Pre_race_scroll_Update to apply the final scroll positions this frame.
	SUBI.l	#$00030000, Screen_data_ptr.w
	ADDI.l	#$00000F00, Screen_timer.w
	CMPI.l	#$00050000, Screen_timer.w
	BCS.b	Pre_race_scroll_Update
	MOVE.l	#Championship_race_init, Frame_callback.w
;Pre_race_scroll_Update
Pre_race_scroll_Update:
; Shared tail called by Pre_race_scroll_Lap, _Minimap, and _Advance each frame.
; Updates the H-scroll and V-scroll entries in Aux_object_pool for the background
; rows that make up the between-races podium scroll:
;   - Derives scroll speed from Screen_timer (high word = pixels, low word = subpixels).
;   - Adjusts Screen_scroll and the H-scroll entries for the two top rows.
;   - Accumulates Screen_subcounter and distributes per-row V-scroll values
;     across 10 additional rows.
;   - Clamps the panel scroll speed to $C0000 (fixed-point limit).
;   - Accumulates Menu_cursor with the (doubled) speed.
;   - Subtracts double the speed from Screen_data_ptr.
; Modifies: D0-D3, A1, Screen_scroll.w, Screen_subcounter.w, Menu_cursor.w,
;           Screen_data_ptr.w, Aux_object_pool+$18..$XX.
	LEA	(Aux_object_pool+$18).w, A1
	MOVE.l	Screen_timer.w, D0
	MOVE.l	D0, D1
	SUB.l	D1, Screen_scroll.w
	MOVE.w	Screen_scroll.w, D1
	ADDI.w	#$01A3, D1
	MOVE.w	D1, (A1)
	ADDA.w	#$0040, A1
	ADDI.w	#$003F, D1
	MOVE.w	D1, (A1)
	MOVE.l	D0, D1
	ADD.l	D1, D1
	ADD.l	D1, D1
	MOVE.l	D1, D2
	ADD.l	D2, Screen_subcounter.w
	SWAP	D2
	MOVE.w	#9, D3
Pre_race_scroll_Update_Rows_loop:
	ADDA.w	#$0040, A1
	ADD.w	D2, (A1)
	DBF	D3, Pre_race_scroll_Update_Rows_loop
	ADD.l	D0, D1
	ADD.l	D0, D1
	CMPI.l	#$000C0000, D1
	BCS.b	Pre_race_scroll_Update_Clamp
	MOVE.l	#$000C0000, D1
Pre_race_scroll_Update_Clamp:
	ADD.l	D1, Menu_cursor.w
	ADD.l	D0, D0
	NEG.l	D0
	SUB.l	D0, Screen_data_ptr.w
	RTS
;Championship_team_select_confirm
Championship_team_select_confirm:
; Confirms the player's gear selection on the championship team-select screen.
; Branches based on Track_index_arcade_mode.w and Rival_team flags:
;   Track_index_arcade_mode == 0 (arcade branch):
;     Sets Track_index_arcade_mode to 1.
;     If bit 5 of Player_team set: go to Team_select_screen_init (full team select).
;     Otherwise: advance to Championship_standings_2_init (Selection_count = $E).
;   Track_index_arcade_mode != 0 (championship branch):
;     If bit 7 of Rival_team is clear: return to Title_menu (Selection_count = $A).
;     Otherwise check that the rival's team index >= player's team index;
;       if not, go to Title_menu; if yes, advance to Championship_standings_init.
; Modifies: Track_index_arcade_mode.w, Selection_count.w,
;           Frame_callback.w / Saved_frame_callback.w.
	TST.w	Track_index_arcade_mode.w
	BEQ.b	Championship_team_select_confirm_Arcade
	BTST.b	#7, Rival_team.w
	BNE.b	Championship_team_select_confirm_CheckRival
Championship_team_select_confirm_ToTitle:
	MOVE.w	#$000A, Selection_count.w
	MOVE.l	#Title_menu, Saved_frame_callback.w
	RTS
Championship_team_select_confirm_CheckRival:
	MOVE.b	Player_team.w, D0
	MOVE.b	Rival_team.w, D1
	ANDI.b	#$0F, D0 ; isolate the player's team number
	ANDI.b	#$0F, D1 ; isolate the rival's team number
	CMP.b	D0, D1
	BCS.b	Championship_team_select_confirm_ToTitle
	MOVE.w	#$000A, Selection_count.w
	MOVE.l	#Championship_standings_init, Saved_frame_callback.w
	RTS
Championship_team_select_confirm_Arcade:
	MOVE.w	#1, Track_index_arcade_mode.w
	BTST.b	#5, Player_team.w
	BEQ.b	Championship_team_select_confirm_ArcadeTeam
	MOVE.l	#Team_select_screen_init, Frame_callback.w
	RTS
Championship_team_select_confirm_ArcadeTeam:
	MOVE.w	#$000E, Selection_count.w
	MOVE.l	#Championship_standings_2_init, Frame_callback.w
	RTS
Podium_car_obj_Update:
; Per-frame object update for a podium/finish-screen animated car sprite.
; $1E(A0) holds the remaining-frames counter for the current animation keyframe.
; If $1E(A0) == $FFFF (sentinel), skips the tick and goes straight to queueing.
; Otherwise decrements $1E(A0); when it reaches zero, reads the next keyframe
; from the sequence pointer at $1A(A0): loads the new duration word into $1E(A0),
; the new sprite frame pointer long into $4(A0), and advances $1A(A0) by 6.
; Finally calls Queue_object_for_sprite_buffer to emit the sprite this frame.
; Inputs:  A0 = object slot pointer.
; Modifies: D0, A1, $4(A0), $1A(A0), $1E(A0).
	CMPI.w	#$FFFF, $1E(A0)
	BEQ.b	Podium_car_obj_Update_Queue
Podium_car_obj_Update_Tick:
	SUBQ.w	#1, $1E(A0)
	BNE.b	Podium_car_obj_Update_Queue
	MOVEA.l	$1A(A0), A1
	MOVE.w	(A1)+, $1E(A0)
	MOVE.l	(A1)+, $4(A0)
	ADDQ.l	#6, $1A(A0)
Podium_car_obj_Update_Queue:
	JSR	Queue_object_for_sprite_buffer
	RTS
;$0000BC46
Race_finish_init:
; Initialises the post-race finish screen (single-race / arcade mode).
; Sequence:
;   1. Halts audio, calls Initialize_results_screen, Finish_race_shared_setup.
;   2. Decompresses Finish_screen_tiles to VDP at $67000003.
;   3. Draws the correct packed tilemap (with or without rival) to VDP.
;   4. Draws car machine graphics, gear indicator, and race timer.
;   5. Sets Aux_object_counter to $FFFFFFFF and updates the gap-to-rival display.
;   6. Populates 12 aux object slots with Podium_car_obj_Update_Tick handlers,
;      loading screen positions and animation sequence pointers from Race_finish_car_anim_a.
;   7. Decompresses finish-car tiles to VDP and calls Init_race_result_scores.
;   8. Decompresses the minimap tilemap to buffer.
;   9. Clamps Tire_braking_durability_acc to at least (Tire_stat_max_1 - 5).
;  10. Installs Race_result_overlay_frame as Frame_callback, unmasks interrupts,
;      waits two VBlanks, plays Music_race_result_overlay, enables vblank.
; Modifies: D0, D5-D6, A0-A2, A6, Frame_callback.w, Aux_object_pool, VDP state.
	JSR	Halt_audio_sequence
	BSR.w	Initialize_results_screen
	JSR	Finish_race_shared_setup(PC)
	MOVE.l	#$67000003, VDP_control_port
	LEA	Finish_screen_tiles, A0
	JSR	Decompress_to_vdp
	LEA	Finish_screen_tilemap_with_rival(PC), A6
	TST.w	Has_rival_flag.w
	BNE.b	Race_finish_init_HasRival
	LEA	Finish_screen_tilemap_no_rival(PC), A6
Race_finish_init_HasRival:
	JSR	Draw_packed_tilemap_to_vdp
	JSR	Draw_car_machine_graphics(PC)
	JSR	Draw_gear_indicator(PC)
	JSR	Draw_race_timer(PC)
	MOVE.l	#$FFFFFFFF, Aux_object_counter.w
	JSR	Update_gap_to_rival_display
	MOVE.w	#$000B, D0
	LEA	Aux_object_pool.w, A1
	LEA	Race_finish_car_anim_a, A2
Race_finish_init_Objects_loop:
	MOVE.l	#Podium_car_obj_Update_Tick, (A1)
	MOVE.w	(A2)+, $18(A1)
	MOVE.w	(A2)+, $16(A1)
	MOVE.w	(A2)+, $E(A1)
	MOVE.w	(A2)+, $1E(A1)
	MOVE.l	(A2)+, $4(A1)
	MOVE.l	(A2)+, $1A(A1)
	LEA	$40(A1), A1
	DBF	D0, Race_finish_init_Objects_loop
	MOVE.l	#$46D60000, D7
	LEA	Race_finish_car_tiles, A0
	MOVE.w	#$40E0, D0
	MOVE.w	#$0013, D6
	MOVE.w	#$000B, D5
	JSR	Decompress_tilemap_to_vdp_128_cell_rows
	BSR.w	Init_race_result_scores
	LEA	Finish_screen_tilemap_list(PC), A1
	JSR	Draw_packed_tilemap_list
	JSR	Load_track_data_pointer
	LEA	$C(A1), A1 ; tile mapping for minimap
	MOVEA.l	(A1), A0
	MOVE.w	#$8000, D0
	JSR	Decompress_tilemap_to_buffer
	MOVE.w	Tire_stat_max_1.w, D0
	SUB.w	Tire_braking_durability_acc.w, D0
	CMPI.w	#5, D0
	BCC.b	Race_finish_init_Done
	MOVE.w	Tire_stat_max_1.w, Tire_braking_durability_acc.w
	SUBQ.w	#5, Tire_braking_durability_acc.w
Race_finish_init_Done:
	MOVE.l	#Race_result_overlay_frame, Frame_callback.w
	ANDI	#$F8FF, SR
	JSR	Wait_for_vblank
	JSR	Wait_for_vblank
	MOVE.w	#Music_race_result_overlay, Audio_music_cmd ; race result overlay music
	MOVE.w	#1, Vblank_enable.w
	MOVE.w	#$8174, VDP_control_port
	RTS
;$0000BD56
; Championship_next_race_init — "between races" screen shown after the results screen
; in championship mode.  Two paths based on Track_index_arcade_mode:
;   == 0 (first championship leg): runs Initialize_results_screen, decompresses the
;        podium car tileset, populates three animated car objects, plays
;        Music_championship_next ($0B), installs Race_result_frame_2 as callback.
;   != 0 (mid-championship): also promotes the rival team Drivers_and_teams_map entry,
;        plays Music_championship_next_special ($0D), installs Race_result_frame_3.
; Both paths animate a car driving away before returning to Championship_race_init.
Championship_next_race_init:
	JSR	Clear_main_object_pool
	TST.w	Track_index_arcade_mode.w
	BNE.w	Championship_next_race_init_MidChamp
	BSR.w	Initialize_results_screen
	JSR	Assign_initial_rival_team
	MOVE.l	#$6B800001, VDP_control_port
	LEA	Podium_car_tiles, A0
	JSR	Decompress_to_vdp
	MOVE.w	#2, D0
	LEA	Aux_object_pool.w, A1
	LEA	Race_finish_car_anim_b, A2
Championship_next_race_init_Objects_loop:
	MOVE.l	#Podium_car_obj_Update, (A1)
	MOVE.w	(A2)+, $18(A1)
	MOVE.w	(A2)+, $16(A1)
	MOVE.w	(A2)+, $E(A1)
	MOVE.w	(A2)+, $1E(A1)
	MOVE.l	(A2)+, $4(A1)
	MOVE.l	(A2)+, $1A(A1)
	LEA	$40(A1), A1
	DBF	D0, Championship_next_race_init_Objects_loop
	MOVE.w	#$0EEE, (Palette_buffer+$44).w
	MOVE.w	#$0800, (Palette_buffer+$46).w
	MOVE.l	#Race_result_frame_2, Frame_callback.w
	MOVE.w	#$000D, Selection_count.w
	BTST.b	#5, Player_team.w
	BEQ.b	Championship_next_race_init_Play
	MOVE.w	#$000B, Selection_count.w
Championship_next_race_init_Play:
	JSR	Halt_audio_sequence
	ANDI	#$F8FF, SR
	JSR	Wait_for_vblank
	JSR	Wait_for_vblank
	MOVE.w	Selection_count.w, Audio_music_cmd ; song = Music_championship_next (13) or Music_championship_next_special (11)
	CLR.w	Selection_count.w
	MOVE.w	#1, Vblank_enable.w
	MOVE.w	#$8174, VDP_control_port
	RTS
Championship_next_race_init_MidChamp:
	JSR	Halt_audio_sequence
	BSR.w	Initialize_results_screen
	JSR	Update_player_grid_position
	CLR.l	D0
	CLR.l	D1
	CLR.l	D2
	LEA	Drivers_and_teams_map.w, A1
	MOVE.b	Rival_team.w, D0
	MOVE.b	D0, D1
	ANDI.b	#$0F, D0 ; isolate the rival's team number
	ANDI.b	#$50, D1
	MOVE.b	(A1,D0.w), D2
	ANDI.b	#$0F, D2
	ADD.b	D1, D2
	MOVE.b	D2, (A1,D0.w)
	MOVE.l	#$6B800001, VDP_control_port
	LEA	Podium_car_tiles, A0
	JSR	Decompress_to_vdp
	MOVE.w	#2, D0
	LEA	Aux_object_pool.w, A1
	LEA	Race_finish_car_anim_b, A2
Championship_next_race_init_MidChamp_Objects_loop:
	MOVE.l	#Podium_car_obj_Update, (A1)
	MOVE.w	(A2)+, $18(A1)
	MOVE.w	(A2)+, $16(A1)
	MOVE.w	(A2)+, $E(A1)
	MOVE.w	(A2)+, $1E(A1)
	MOVE.l	(A2)+, $4(A1)
	MOVE.l	(A2)+, $1A(A1)
	LEA	$40(A1), A1
	DBF	D0, Championship_next_race_init_MidChamp_Objects_loop
	MOVE.l	#Race_result_frame_3, Frame_callback.w
	MOVE.w	#$0800, (Palette_buffer+$46).w
	BSR.w	Initialize_standings_order_buffer
	JSR	Initialize_minimap_display_buffers(PC)
	JSR	Draw_track_name_and_championship_standings(PC)
	BTST.b	#5, Player_team.w
	BEQ.b	Championship_next_race_init_MidChamp_NoRival
	MOVE.w	#$000D, Selection_count.w
	MOVE.b	Player_grid_position_b.w, D0
	CMP.b	Rival_grid_position_b.w, D0
	BCS.b	Commit_music_selection
	MOVE.w	#$000B, Selection_count.w
	BRA.b	Commit_music_selection
Championship_next_race_init_MidChamp_NoRival:
	CLR.l	D0
	LEA	Post_race_driver_target_points, A2
	MOVE.b	Player_team.w, D0
	ANDI.b	#$0F, D0 ; isolate the player's team number
	ADD.l	D0, D0
	MOVE.b	(A2,D0.w), D1
	CMP.b	Player_grid_position_b.w, D1
	BCC.b	Championship_next_race_init_MidChamp_Song3
	MOVE.b	$1(A2,D0.w), D1
	CMP.b	Player_grid_position_b.w, D1
	BCC.b	Championship_next_race_init_MidChamp_Song2
	MOVE.w	#$000B, Selection_count.w
	BRA.b	Commit_music_selection
Championship_next_race_init_MidChamp_Song2:
	MOVE.w	#$000B, Selection_count.w
	BRA.b	Commit_music_selection
Championship_next_race_init_MidChamp_Song3:
	MOVE.w	#$000D, Selection_count.w
Commit_music_selection:
; Shared tail used by Championship_next_race_init paths to start the music.
; Unmasks interrupts, waits two VBlanks, writes Selection_count.w to
; Audio_music_cmd (the song ID was placed in Selection_count by the caller),
; enables vblank (Vblank_enable = 1), and sets VDP register $81 = $74.
; Modifies: Audio_music_cmd, Vblank_enable.w, VDP_control_port.
	ANDI	#$F8FF, SR
	JSR	Wait_for_vblank
	JSR	Wait_for_vblank
	MOVE.w	Selection_count.w, Audio_music_cmd ; song selection
	MOVE.w	#1, Vblank_enable.w
	MOVE.w	#$8174, VDP_control_port
	RTS
;$0000BF30
