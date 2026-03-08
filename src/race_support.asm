Update_race_timer:
	TST.w	Race_timer_freeze.w
	BNE.b	Update_race_timer_Not_started
	CLR.w	New_lap_flag.w
	TST.w	Race_started.w
	BNE.b	Update_race_timer_Decrement
Update_race_timer_Not_started:
	RTS
Race_timer_countdown_table:
	dc.b	$95, $90, $85, $80, $75, $70, $65, $60, $55, $50, $45, $40, $35, $30, $25, $20, $15, $10, $05, $00
Update_race_timer_Decrement:
	TST.w	Laps_done_flag.w
	BNE.b	Update_race_timer_Not_started
	LEA	Race_timer_bcd.w, A0
	SUBQ.b	#1, (A0)
	BNE.b	Update_race_timer_Sub_tick
	MOVE.b	#$14, (A0)
	MOVEQ	#1, D0
	MOVEQ	#$00000060, D1
	MOVE.b	$2(A0), D2
	ADDI.w	#0, D0
	ABCD	D0, D2
	CMP.b	D1, D2
	BCS.b	Update_race_timer_Seconds_ok
	ADDI.w	#0, D0
	SBCD	D1, D2
	MOVE.b	$1(A0), D3
	ADDI.w	#0, D0
	ABCD	D0, D3
	BCC.b	Update_race_timer_Minutes_ok
	MOVE.l	#$01995999, (A0)
	BRA.b	Update_race_timer_Draw_lap
Update_race_timer_Minutes_ok:
	MOVE.b	D3, $1(A0)
Update_race_timer_Seconds_ok:
	MOVE.b	D2, $2(A0)
Update_race_timer_Sub_tick:
	MOVEQ	#0, D0
	MOVE.b	(A0), D0
	MOVE.b	Race_timer_countdown_table-1(PC,D0.w), $3(A0)
Update_race_timer_Draw_lap:
	MOVE.l	(A0), Lap_time_ptr.w
	CLR.b	Lap_time_ptr.w
	MOVE.w	Best_ai_distance.w, D0
	MOVE.w	Laps_completed.w, D1
	MOVE.w	D1, Best_ai_distance.w
	CMP.w	D1, D0
	BEQ.w	Update_race_timer_Next_lap
	MOVE.w	#1, Placement_change_flag.w
	TST.w	D1
	BEQ.w	Update_race_timer_Next_lap
	MOVE.w	#1, New_lap_flag.w
	MOVE.l	#Lap_end_obj, Main_object_pool.w
	CLR.l	(A0)
	MOVE.b	#$14, (A0)
	TST.w	Track_index_arcade_mode.w
	BEQ.b	Update_race_timer_Lap_store
	ADD.w	D1, D1
	ADD.w	D1, D1
	LEA	Lap_time_ptr.w, A1
	MOVE.l	Lap_time_ptr.w, (A1,D1.w)
Update_race_timer_Lap_store:
	JSR	Update_best_lap_time(PC)
	LEA	Lap_time_table_ptr.w, A1
	LEA	Lap_time_ptr.w, A2
	JSR	Bcd_add_lap_time(PC)
	TST.w	Track_index_arcade_mode.w
	BNE.b	Update_race_timer_Arcade
	TST.w	Warm_up.w
	BNE.b	Update_race_timer_Warmup
	TST.w	Practice_mode.w
	BNE.b	Update_race_timer_Next_lap
	MOVE.w	#1, Overtake_event_flag.w
	BRA.b	Update_race_timer_Alloc_obj
Update_race_timer_Warmup:
	MOVE.w	Title_menu_cursor.w, D0
	ADDQ.w	#1, D0
	CMP.w	Laps_completed.w, D0
	BEQ.b	Update_race_timer_Alloc_obj
	BRA.b	Update_race_timer_Next_lap
Update_race_timer_Arcade:
	MOVE.w	Use_world_championship_tracks.w, D0
	ADD.w	D0, D0
	ADDQ.w	#3, D0
	CMP.w	Laps_completed.w, D0
	BHI.b	Update_race_timer_Next_lap
	JSR	Update_rival_best_lap_time(PC)
Update_race_timer_Alloc_obj:
	MOVE.l	#Crash_retire_obj_init, D1
	JSR	Alloc_aux_object_slot
	MOVE.w	#1, Laps_done_flag.w
;Update_race_timer_Next_lap
Update_race_timer_Next_lap:
	TST.w	Track_index_arcade_mode.w
	BNE.b	Update_race_timer_Champ
	MOVE.l	(A0), D0
	TST.w	Laps_done_flag.w
	BEQ.b	Update_race_timer_Show_current
	MOVE.l	Lap_time_ptr.w, D0
Update_race_timer_Show_current:
	LEA	(Digit_tilemap_buf+$1C).w, A1
	JSR	Pack_hex_digits_to_tilemap
	MOVEQ	#7, D0
	JSR	Copy_digits_to_tilemap_with_suppress
	MOVE.l	#$63180003, D7
	MOVEQ	#7, D6
	MOVEQ	#1, D5
	LEA	(Digit_tilemap_buf+$C).w, A6
	JSR	Queue_tilemap_draw
	MOVE.w	Warm_up.w, D0
	OR.w	Practice_mode.w, D0
	BNE.w	Update_race_timer_Return
	MOVE.w	Current_lap.w, D0
	ADD.w	D0, D0
	ADD.w	D0, D0
	LEA	Track_lap_target_buf.w, A1
	MOVE.l	(A1,D0.w), D0
	CMP.l	Lap_time_ptr.w, D0
	BCC.w	Update_race_timer_Return
	ADDQ.w	#1, Current_lap.w
	MOVE.w	#1, Overtake_event_flag.w
	CMPI.w	#$000E, Current_lap.w
	BNE.w	Update_race_timer_Return
	MOVE.l	#Checkpoint_anim_obj_init, D1
	JSR	Alloc_aux_object_slot
	BRA.w	Update_race_timer_Return
Update_race_timer_Champ:
	TST.w	Ai_active_flag.w
	BNE.b	Update_race_timer_Return
	TST.w	New_lap_flag.w
	BEQ.b	Update_race_timer_Champ_current
	MOVE.w	Best_lap_vdp_step.w, D7
	ADDI.w	#$0040, Best_lap_vdp_step.w
	MOVE.l	Lap_time_ptr.w, D0
	BRA.b	Update_race_timer_Format_display
Update_race_timer_Champ_current:
	MOVE.w	Best_lap_vdp_step.w, D7
	MOVE.l	(A0), D0
Update_race_timer_Format_display:
	MOVE.w	#$C000, D3
	LEA	(Digit_tilemap_buf+$7C).w, A3
	JSR	Format_bcd_time_to_tile_buffer
	JSR	Tile_index_to_vdp_command
	MOVEQ	#7, D6
	MOVEQ	#0, D5
	LEA	(A3), A6
	JSR	Queue_tilemap_draw
	TST.w	Use_world_championship_tracks.w
	BNE.b	Update_race_timer_Return
	MOVE.l	Rival_race_time_bcd.w, Rival_race_time_bcd_prev.w
	LEA	Track_lap_time_base_ptr.w, A1
	LEA	Rival_race_time_bcd.w, A2
	JSR	Bcd_add_lap_time(PC)
	MOVE.l	Rival_race_time_bcd_prev.w, D0
	LEA	(Digit_tilemap_buf+$1C).w, A1
	JSR	Pack_hex_digits_to_tilemap
	MOVEQ	#7, D0
	JSR	Copy_digits_to_tilemap_with_suppress
	MOVE.l	#$606C0003, D7
	MOVEQ	#7, D6
	MOVEQ	#1, D5
	LEA	(Digit_tilemap_buf+$C).w, A6
	JSR	Queue_tilemap_draw
Update_race_timer_Return:
	RTS
Update_best_lap_time:
	MOVEA.l	$4(A0), A1
	MOVE.l	Lap_time_ptr.w, D0
	CMP.l	(A1), D0
	BCC.b	Update_best_lap_Return
	MOVE.l	D0, (A1)
	TST.w	Ai_active_flag.w
	BNE.b	Update_best_lap_Return
	MOVE.w	#$8000, D3
	LEA	(Digit_tilemap_buf+$5C).w, A3
	JSR	Format_bcd_time_to_tile_buffer
	MOVE.l	#$61460003, D7
	TST.w	Track_index_arcade_mode.w
	BEQ.b	Update_best_lap_Draw
	MOVE.l	#$61040003, D7
Update_best_lap_Draw:
	MOVEQ	#7, D6
	MOVEQ	#0, D5
	LEA	(A3), A6
	JSR	Queue_tilemap_draw
Update_best_lap_Return:
	RTS
Update_rival_best_lap_time:
	MOVEA.l	$4(A0), A1
	ADDQ.w	#4, A1
	MOVE.l	Rival_race_time_bcd.w, D0
	CMP.l	(A1), D0
	BCC.b	Update_rival_best_lap_Return
	MOVE.l	D0, (A1)
	MOVE.w	#$8000, D3
	LEA	(Digit_tilemap_buf+$6C).w, A3
	JSR	Format_bcd_time_to_tile_buffer
	MOVE.l	#$61840003, D7
	MOVEQ	#7, D6
	MOVEQ	#0, D5
	LEA	(A3), A6
	JSR	Queue_tilemap_draw
Update_rival_best_lap_Return:
	RTS
;Bcd_add_lap_time
Bcd_add_lap_time:
	MOVEQ	#0, D0
	ADDI.w	#0, D0
	ABCD	-(A1), -(A2)
	ABCD	-(A1), -(A2)
	BCS.b	Bcd_add_lap_time_Carry
	MOVE.b	(A2), D0
	ABCD	-(A1), -(A2)
	MOVEQ	#$00000060, D1
	ADDI.w	#0, D0
	SBCD	D1, D0
	BCS.b	Bcd_add_lap_time_Rts
	MOVE.b	D0, $1(A2)
	MOVE.b	(A2), D0
	MOVEQ	#1, D1
	ABCD	D1, D0
	MOVE.b	D0, (A2)
	BRA.b	Bcd_add_lap_time_Rts
Bcd_add_lap_time_Carry:
	MOVE.b	(A2), D0
	ABCD	-(A1), -(A2)
	MOVEQ	#$00000040, D1
	ADDI.w	#0, D0
	ABCD	D1, D0
	MOVE.b	D0, $1(A2)
Bcd_add_lap_time_Rts:
	RTS
Lap_end_obj:
	TST.w	Ai_active_flag.w
	BNE.b	Lap_end_obj_Clear
	TST.w	Warm_up.w
	BEQ.b	Lap_end_obj_Check_mode
	TST.w	Laps_done_flag.w
	BNE.w	Lap_end_obj_Overtake
	MOVE.l	#$62780003, D7
	MOVE.w	Laps_completed.w, D1
	ADD.w	D1, D1
	ADD.w	D1, D1
	LEA	Lap_number_tilemap_table, A6
	ADDA.w	D1, A6
	MOVEQ	#0, D6
	MOVEQ	#1, D5
	JSR	Queue_tilemap_draw
	BRA.b	Lap_end_obj_Next_lap
Lap_end_obj_Check_mode:
	TST.w	Practice_mode.w
	BNE.b	Lap_end_obj_Next_lap
	TST.w	Track_index_arcade_mode.w
	BNE.b	Lap_end_obj_Arcade
Lap_end_obj_Clear:
	JMP	Clear_object_slot
Lap_end_obj_Arcade:
	JSR	Advance_rival_position_bcd(PC)
	JSR	Award_race_position_points
	MOVE.w	Use_world_championship_tracks.w, D0
	ADD.w	D0, D0
	ADDQ.w	#2, D0
	MOVE.w	Laps_completed.w, D1
	CMP.w	D1, D0
	BNE.b	Lap_end_obj_Not_final
	MOVE.w	#1, $36(A0)
Lap_end_obj_Not_final:
	ADDQ.w	#1, D0
	CMP.w	D1, D0
	BLS.b	Lap_end_obj_Overtake
	MOVE.l	#$62780003, D7
	ADD.w	D1, D1
	ADD.w	D1, D1
	LEA	Lap_number_tilemap_table, A6
	ADDA.w	D1, A6
	MOVEQ	#0, D6
	MOVEQ	#1, D5
	JSR	Queue_tilemap_draw
	MOVEQ	#3, D7
	TST.w	$36(A0)
	BNE.b	Lap_end_obj_Set_sound
	TST.w	Use_world_championship_tracks.w
	BNE.b	Lap_end_obj_Next_lap
	MOVEQ	#2, D7
	MOVE.w	Current_placement.w, D0
	CMP.w	Player_grid_position.w, D0
	BLS.b	Lap_end_obj_Set_sound
	MOVEQ	#1, D7
Lap_end_obj_Set_sound:
	MOVE.w	D7, $2A(A0)
Lap_end_obj_Next_lap:
	TST.w	Overtake_flag.w
	BNE.b	Lap_end_obj_Overtake
	MOVE.w	#1, Overtake_flag.w
Lap_end_obj_Overtake:
	LEA	Crash_car_frame_a(PC), A1
	LEA	Lap_end_tilemap_buf.w, A3
	MOVEQ	#3, D0
Lap_end_obj_Copy_tilemap:
	MOVE.l	(A1)+, (A3)+
	DBF	D0, Lap_end_obj_Copy_tilemap
	MOVE.l	Lap_time_ptr.w, D0
	MOVE.w	#$8000, D3
	LEA	$10(A3), A3
	JSR	Format_bcd_time_to_tile_buffer
	MOVE.l	#Lap_end_obj_Flash, (A0)
	MOVE.w	#$000E, $1C(A0)
Lap_end_obj_Flash:
	TST.w	Player_eliminated.w
	BEQ.b	Lap_end_obj_Flash_tick
	CLR.w	$1A(A0)
	BSR.b	Lap_end_obj_Draw
	BRA.b	Lap_end_obj_Flash_done
Lap_end_obj_Flash_tick:
	SUBQ.w	#1, $22(A0)
	BPL.b	Lap_end_obj_Flash_rts
	MOVE.w	#8, $22(A0)
	NOT.w	$1A(A0)
	SUBQ.w	#1, $1C(A0)
	BPL.b	Lap_end_obj_Flash_visible
Lap_end_obj_Flash_done:
	JMP	Clear_object_slot
Lap_end_obj_Flash_visible:
	CMPI.w	#$000A, $1C(A0)
	BNE.b	Lap_end_obj_Draw
	MOVE.w	$2A(A0), D0
	BEQ.b	Lap_end_obj_Draw
	MOVE.w	D0, $00FF5AC2
Lap_end_obj_Draw:
	LEA	$00FF5980, A6
	LEA	(A6), A4
	TST.w	$1A(A0)
	BEQ.b	Lap_end_obj_Draw_queue
	LEA	Lap_end_tilemap_buf.w, A6
	LEA	Crash_car_frame_b(PC), A4
Lap_end_obj_Draw_queue:
	MOVE.l	#$64D00003, D7
	MOVEQ	#$0000000F, D6
	MOVEQ	#0, D5
	JSR	Queue_tilemap_draw
	TST.w	$36(A0)
	BEQ.b	Lap_end_obj_Flash_rts
	LEA	(A4), A6
	MOVE.l	#$64580003, D7
	MOVEQ	#8, D6
	JSR	Queue_tilemap_draw
Lap_end_obj_Flash_rts:
	RTS
Advance_rival_position_bcd:
	TST.w	Use_world_championship_tracks.w
	BNE.b	Advance_rival_position_bcd_Rts
	LEA	Crash_car_tile_offsets(PC), A1
	MOVE.w	Laps_completed.w, D0
	CMPI.w	#3, D0
	BNE.b	Advance_rival_position_bcd_Offset
	MOVE.w	Player_grid_position.w, D0
	CMPI.w	#8, D0
	BCC.b	Advance_rival_position_bcd_Rts
	LEA	Crash_car_tile_sizes(PC), A1
Advance_rival_position_bcd_Offset:
	ADD.w	D0, D0
	ADDA.w	D0, A1
	LEA	Rival_grid_position.w, A2
	ADDI.w	#0, D0
	ABCD	-(A1), -(A2)
	ABCD	-(A1), -(A2)
	MOVE.w	#1, Placement_display_dirty.w
Advance_rival_position_bcd_Rts:
	RTS
Update_gap_to_rival_display:
	TST.w	Retire_animation_flag.w
	BNE.b	Update_gap_to_rival_Return
	CMPI.w	#$00C8, Aux_object_counter.w
	BCC.b	Update_gap_to_rival_Active
	ADDQ.w	#1, Aux_object_counter.w
	MOVE.w	#$FFFF, Best_ai_place.w
Update_gap_to_rival_Return:
	RTS
Update_gap_to_rival_Active:
	TST.w	Track_index_arcade_mode.w
	BEQ.b	Update_gap_to_rival_Return
	MOVEA.w	Rival_ai_car_ptr.w, A0
	TST.w	Use_world_championship_tracks.w
	BEQ.b	Update_gap_to_rival_Calc
	TST.w	Has_rival_flag.w
	BEQ.b	Update_gap_to_rival_Calc
	LEA	Ai_car_array.w, A0
Update_gap_to_rival_Calc:
	MOVE.w	Player_place_score.w, D0
	MOVE.w	$1E(A0), D1
	CMP.w	D1, D0
	BCC.b	Update_gap_to_rival_Calc_swap
	EXG	D0, D1
Update_gap_to_rival_Calc_swap:
	SUB.w	D1, D0
	MOVEQ	#0, D5
	MOVEQ	#1, D3
	MOVE.w	#$1770, D4
Update_gap_to_rival_Minutes_loop:
	SUB.w	D4, D0
	BCS.b	Update_gap_to_rival_Seconds
	ADDI.w	#0, D0
	ABCD	D3, D5
	BRA.b	Update_gap_to_rival_Minutes_loop
Update_gap_to_rival_Seconds:
	ADD.w	D4, D0
	JSR	Binary_to_decimal
	MOVE.w	D5, D0
	SWAP	D0
	MOVE.w	D1, D0
	LEA	(Digit_tilemap_buf+$3C).w, A1
	JSR	Pack_hex_digits_to_tilemap
	CMPI.w	#$000D, (A1)
	BNE.b	Update_gap_to_rival_Suppress
	TST.w	$2(A1)
	BNE.b	Update_gap_to_rival_Suppress
	MOVE.w	#$000D, $2(A1)
	MOVE.w	#$000D, $4(A1)
Update_gap_to_rival_Suppress:
	MOVEQ	#7, D0
	JSR	Copy_digits_to_tilemap_with_suppress
	MOVEQ	#7, D6
	MOVEQ	#1, D5
	LEA	(Digit_tilemap_buf+$2C).w, A6
	TST.w	Ai_active_flag.w
	BEQ.b	Update_gap_to_rival_Dma
	MOVE.l	#$41000000, D7
	JSR	Draw_tilemap_buffer_to_vdp_128_cell_rows
	BRA.b	Update_gap_to_rival_Position
Update_gap_to_rival_Dma:
	MOVE.l	#$60400003, D7
	JSR	Queue_tilemap_draw
Update_gap_to_rival_Position:
	LEA	Crash_car_frame_table(PC), A6
	TST.w	Has_rival_flag.w
	BEQ.b	Update_gap_to_rival_No_rival
	ADDQ.w	#4, A6
	MOVEQ	#9, D6
	MOVE.w	Player_grid_position.w, D0
	CMP.w	Rival_grid_position.w, D0
	BCS.b	Update_gap_to_rival_Select_pos
	ADDQ.w	#8, A6
	BRA.b	Update_gap_to_rival_Select_pos
Update_gap_to_rival_No_rival:
	MOVEQ	#7, D6
	MOVE.w	Player_grid_position.w, D0
	BEQ.b	Update_gap_to_rival_Select_pos
	ADDQ.w	#8, A6
Update_gap_to_rival_Select_pos:
	CMP.w	Best_ai_place.w, D0
	BEQ.b	Update_gap_to_rival_Rts
	MOVE.w	D0, Best_ai_place.w
	MOVEA.l	(A6), A6
	MOVEQ	#1, D5
	TST.w	Ai_active_flag.w
	BEQ.b	Update_gap_to_rival_Queue_pos
	MOVE.l	#$41100000, D7
	JMP	Draw_tilemap_buffer_to_vdp_128_cell_rows
Update_gap_to_rival_Queue_pos:
	MOVE.l	#$60500003, D7
	JSR	Queue_tilemap_draw
Update_gap_to_rival_Rts:
	RTS
;Crash_car_tile_offsets
Crash_car_tile_offsets:
	dc.b	$01, $00, $02, $00, $10, $00
;Crash_car_tile_sizes
Crash_car_tile_sizes:
	dc.b	$08, $00, $06, $00, $05, $00, $04, $50, $04, $00, $03, $50, $03, $00
;Crash_car_frame_a
Crash_car_frame_a:
	dc.l	$C7D5C7CA, $C7D90000, $C7DDC7D2, $C7D6C7CE
;Crash_car_frame_b
Crash_car_frame_b:
	dc.w	$C7CF, $C7D2, $C7D7, $C7CA, $C7D5, $0000, $C7D5, $C7CA, $C7D9
;Crash_car_frame_table
Crash_car_frame_table:
	dc.l	Crash_car_frame_0
	dc.l	Crash_car_frame_2
	dc.l	Crash_car_frame_1
	dc.l	Crash_car_frame_3
;Crash_car_frame_0
Crash_car_frame_0:
	dc.w	$0000, $0000, $0000, $0000, $0000, $84B6, $0000, $0000, $A7CF, $A7DB, $A7D8, $A7D6, $0000, $84B7, $A7D7, $A7CD
;Crash_car_frame_1
Crash_car_frame_1:
	dc.w	$0000, $0000, $0000, $84B4, $0000, $0000, $0000, $0000, $A7DD, $A7D8, $0000, $84B5, $A7DC, $A7DD, $0000, $0000
;Crash_car_frame_2
Crash_car_frame_2:
	dc.w	$0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $A7CF, $A7DB, $A7D8, $A7D6, $0000, $A7DB, $A7D2, $A7DF, $A7CA, $A7D5
;Crash_car_frame_3
Crash_car_frame_3:
	dc.w	$0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $A7DD, $A7D8, $0000, $A7DB, $A7D2, $A7DF, $A7CA, $A7D5, $0000, $0000
	MOVE.l	#Crash_obj_phase1, (A0)
	MOVE.l	#Sprite_frame_data_129AE, $4(A0)
	MOVE.w	#$009F, $E(A0)
	MOVE.w	#$0178, $16(A0)
	MOVE.w	#$0130, $18(A0)
	MOVE.w	#$FFFF, $28(A0)
	MOVE.w	#1, Crash_animation_flag.w
	MOVE.w	#2, $38(A0)
Crash_obj_phase1:
	SUBQ.w	#2, $18(A0)
	SUBQ.w	#1, $16(A0)
	CMPI.w	#$0160, $16(A0)
	BNE.b	Crash_obj_phase1_queue
	MOVE.l	#Crash_obj_phase2, (A0)
	MOVE.w	#2, Crash_animation_flag.w
	CLR.w	$38(A0)
	CLR.w	Crash_spin_flag.w
Crash_obj_phase1_queue:
	CMPI.w	#$0175, $16(A0)
	BNE.b	Crash_obj_phase1_sprite
	MOVE.w	#4, $00FF5AC2
Crash_obj_phase1_sprite:
	JSR	Queue_object_for_sprite_buffer
	BRA.w	Update_gap_to_rival_Update_pos
	MOVE.l	#Crash_obj_phase2, (A0)
	MOVE.l	#Sprite_frame_data_129AE, $4(A0)
	MOVE.w	#$009F, $E(A0)
	MOVE.w	#$0160, $16(A0)
	MOVE.w	#$0100, $18(A0)
	MOVE.w	$1A(A0), D0
	MOVE.w	D0, $1E(A0)
	ADDI.w	#$003C, D0
	MOVE.w	D0, Lap_checkpoint_target.w
	MOVE.w	#$FFFF, $28(A0)
	MOVE.w	#$FFFF, Laps_completed.w
	MOVE.w	#$FFFF, Best_ai_distance.w
Crash_obj_phase2:
	TST.w	Race_finish_flag.w
	BNE.w	Crash_obj_Rts
	MOVE.w	$1E(A0), Depth_sort_buf.w
	MOVE.w	#$FFFF, Score_scratch_buf.w
	MOVE.w	Player_speed.w, $26(A0)
	TST.w	Pit_in_flag.w
	BEQ.b	Crash_obj_Normal
	TST.w	$38(A0)
	BNE.b	Crash_obj_Pit
	MOVE.w	$1A(A0), D0
	CMP.w	Background_zone_2_distance.w, D0
	BCS.b	Crash_obj_Normal
	TST.w	$38(A0)
	BNE.b	Crash_obj_Pit
	ADDQ.w	#1, $38(A0)
	MOVE.w	#1, Crash_animation_flag.w
Crash_obj_Pit:
	CMPI.w	#$00FF, Player_speed.w
	BCS.b	Crash_obj_Pit_slow
	CLR.w	Crash_spin_flag.w
	MOVE.w	#1, Spin_off_track_flag.w
Crash_obj_Pit_slow:
	CMPI.w	#$0080, Player_speed.w
	BCC.b	Crash_obj_Pit_spin
	MOVE.w	#1, Crash_spin_flag.w
	CLR.w	Spin_off_track_flag.w
Crash_obj_Pit_spin:
	ADDQ.w	#2, $18(A0)
	ADDQ.w	#1, $16(A0)
	CMPI.w	#$0178, $16(A0)
	BNE.b	Crash_obj_Pit_sprite
	MOVE.l	#$0000BC46, Frame_callback.w
Crash_obj_Pit_sprite:
	JSR	Queue_object_for_sprite_buffer
	BRA.w	Update_gap_to_rival_Update_pos
Crash_obj_Normal:
	TST.w	Retire_flag.w
	BEQ.b	Crash_obj_Overtake
	TST.w	$36(A0)
	BEQ.b	Crash_obj_Retire
Crash_obj_Rts:
	RTS
Crash_obj_Retire:
	MOVE.w	#$1234, $28(A0)
	MOVEQ	#0, D7
	JSR	Update_gap_to_rival_Steering(PC)
	LEA	Collision_palette_buf.w, A2
	MOVE.l	#Retire_car_obj_init_low, D1
	MOVE.l	#Slide_car_obj_init_from_bottom, D3
	TST.b	Ai_side_flag.w
	BNE.b	Crash_obj_Retire_palette
	ADDQ.w	#6, A2
	MOVE.l	#Retire_car_obj_init_high, D1
	MOVE.l	#Slide_car_obj_init_from_top, D3
Crash_obj_Retire_palette:
	LEA	Crash_retire_palette_bytes, A1
	JSR	Write_3_palette_vdp_bytes(PC)
	JSR	Alloc_aux_object_slot
	BCS.b	Crash_obj_Retire_done
	MOVE.w	D3, D1
	JSR	Find_free_aux_object_slot
Crash_obj_Retire_done:
	JSR	Decrement_lap_time_bcd(PC)
	MOVE.w	#1, $36(A0)
	MOVE.w	#$000F, $00FF5AC2
	RTS
Crash_obj_Overtake:
	CLR.w	Collision_speed_penalty.w
	MOVE.w	Overtake_delta.w, D0
	BEQ.b	Crash_obj_Overtake2
	BMI.b	Crash_obj_Overtake_neg
	ADDI.w	#$0038, $12(A0)
	SUBQ.w	#1, D0
	BRA.b	Crash_obj_Overtake_write
Crash_obj_Overtake_neg:
	SUBI.w	#$0038, $12(A0)
	ADDQ.w	#1, D0
Crash_obj_Overtake_write:
	MOVE.w	D0, Overtake_delta.w
	CLR.w	Crash_lateral_gap.w
	BRA.b	Crash_obj_Speed_delta
Crash_obj_Overtake2:
	MOVE.w	Crash_lateral_gap.w, D0
	BEQ.b	Crash_obj_Speed_delta
	MOVE.w	D0, Collision_speed_penalty.w
	LSR.w	#6, D0
	ADDQ.w	#1, D0
	MOVE.w	D0, Overtake_delta.w
	TST.w	$12(A0)
	BMI.b	Crash_obj_Overtake2_sign
	NEG.w	Overtake_delta.w
Crash_obj_Overtake2_sign:
	MOVEQ	#$0000001E, D0
	TST.b	Ai_side_flag.w
	BNE.b	Crash_obj_Overtake2_flag
	MOVEQ	#$0000001C, D0
Crash_obj_Overtake2_flag:
	TST.w	Overtake_flag.w
	BNE.b	Crash_obj_Overtake2_done
	MOVE.w	D0, Overtake_flag.w
Crash_obj_Overtake2_done:
	JSR	Decrement_lap_time_bcd(PC)
	JSR	Update_tire_wear_counter(PC)
Crash_obj_Speed_delta:
	CLR.w	Ai_speed_override.w
	MOVE.w	Overtake_position_delta.w, D0
	BEQ.b	Crash_obj_Overtake_ready
	BMI.b	Crash_obj_Speed_neg
	ADDI.w	#$0014, $12(A0)
	SUBQ.w	#1, D0
	BRA.b	Crash_obj_Speed_write
Crash_obj_Speed_neg:
	SUBI.w	#$0014, $12(A0)
	ADDQ.w	#1, D0
Crash_obj_Speed_write:
	MOVE.w	D0, Overtake_position_delta.w
	CLR.w	Ai_x_delta.w
	CLR.w	Ai_overtake_ready.w
	BRA.b	Crash_anim_Position_clamp
Crash_obj_Overtake_ready:
	MOVE.w	Ai_overtake_ready.w, D0
	BEQ.b	Crash_anim_Position_clamp
	MOVE.w	Ai_speed_delta.w, Ai_speed_override.w
	JSR	Decrement_lap_time_bcd(PC)
	JSR	Update_tire_wear_counter(PC)
	MOVE.w	Ai_x_delta.w, Overtake_position_delta.w
	CLR.w	Ai_x_delta.w
	CLR.w	Ai_overtake_ready.w
Crash_anim_Position_clamp:
	MOVE.w	#$00E0, D6
	MOVE.w	#$0140, D7
	MOVE.w	$12(A0), D0
	BMI.b	Update_gap_to_rival_Negate
	TST.w	Background_zone_index.w
	BEQ.b	Update_gap_to_rival_Classify
	MOVE.w	$1A(A0), D5
	CMPI.w	#$00AF, D5
	BCS.b	Update_gap_to_rival_Classify
	CMPI.w	#$014F, D5
	BLS.b	Update_gap_to_rival_Tunnel_adjust
	CMP.w	Background_zone_2_distance.w, D5
	BCS.b	Update_gap_to_rival_Classify
	CMP.w	Background_zone_1_distance.w, D5
	BCC.b	Update_gap_to_rival_Classify
Update_gap_to_rival_Tunnel_adjust:
	ADDI.w	#$0040, D6
	ADDI.w	#$0040, D7
	BRA.b	Update_gap_to_rival_Classify
Update_gap_to_rival_Negate:
	NEG.w	D0
;Update_gap_to_rival_Classify
Update_gap_to_rival_Classify:
	MOVEQ	#0, D1
	CMP.w	D6, D0
	BCS.b	Update_gap_to_rival_Write_state
	ADDQ.w	#1, D1
	CMP.w	D7, D0
	BCS.b	Update_gap_to_rival_Write_state
	ADDQ.w	#1, D1
Update_gap_to_rival_Write_state:
	MOVE.w	D1, Road_marker_state.w
Update_gap_to_rival_Update_pos:
	MOVE.w	$1A(A0), D0
	JSR	Compute_minimap_index(PC)
	MOVEQ	#0, D7
	MOVE.w	Player_speed.w, D0
	BEQ.b	Update_gap_to_rival_Steering
	SUBQ.w	#1, $8(A0)
	BPL.b	Update_gap_to_rival_Steering
	LSR.w	#5, D0
	MOVEQ	#5, D1
	SUB.w	D0, D1
	BCC.b	Update_gap_to_rival_Calc_frame
	MOVEQ	#0, D1
Update_gap_to_rival_Calc_frame:
	MOVE.w	D1, $8(A0)
	MOVE.w	$A(A0), D0
	ADDQ.w	#8, D0
	CMPI.w	#$0018, D0
	BCS.b	Update_gap_to_rival_Wrap_frame
	MOVEQ	#0, D0
Update_gap_to_rival_Wrap_frame:
	MOVE.w	D0, $A(A0)
	ADDQ.w	#1, D7
Update_gap_to_rival_Steering:
	MOVEQ	#0, D2
	MOVE.b	Steering_output.w, D0
	SMI	D1
	BEQ.b	Update_gap_to_rival_Steering_done
	BPL.b	Update_gap_to_rival_Steering_abs
	NEG.b	D0
Update_gap_to_rival_Steering_abs:
	ADDQ.w	#1, D2
	SUBI.w	#$0024, D0
	BCS.b	Update_gap_to_rival_Steering_done
	ADDQ.w	#1, D2
	SUBI.w	#$0023, D0
	BCS.b	Update_gap_to_rival_Steering_done
	ADDQ.w	#1, D2
Update_gap_to_rival_Steering_done:
	TST.b	D1
	BEQ.b	Update_gap_to_rival_Steering_apply
	NEG.w	D2
Update_gap_to_rival_Steering_apply:
	ADDQ.w	#3, D2
	MOVE.w	$28(A0), D1
	MOVE.w	D2, $28(A0)
	CMP.w	D2, D1
	BEQ.b	Update_gap_to_rival_Palette_done
	ADDQ.w	#1, D7
Update_gap_to_rival_Palette_done:
	TST.w	D7
	BEQ.b	Update_gap_to_rival_Palette_skip
	ADD.w	D2, D2
	ADD.w	D2, D2
	ADD.w	D2, D2
	MOVE.w	D2, D1
	ADD.w	D2, D2
	ADD.w	D2, D1
	MOVE.w	$A(A0), D0
	ADD.w	D1, D0
	LEA	Crash_collision_palette_table, A1
	ADDA.w	D0, A1
	LEA	Collision_palette_buf.w, A2
	JSR	Write_3_palette_vdp_bytes(PC)
	ADDQ.w	#2, A1
	JSR	Write_3_palette_vdp_bytes(PC)
Update_gap_to_rival_Palette_skip:
	RTS
	MOVE.l	#Crash_obj_sync_player, (A0)
	MOVE.w	#$00A1, $E(A0)
	MOVE.w	#$FFFF, $28(A0)
Crash_obj_sync_player:
	LEA	Player_obj.w, A3
	MOVE.w	$16(A3), $16(A0)
	MOVE.w	$18(A3), $18(A0)
	LEA	Crash_sync_gauge_palette_table, A1
	LEA	Crash_sync_palette_dma.w, A2
	MOVE.w	$28(A3), D0
	BRA.b	Crash_obj_gauge_write
	MOVE.l	#Crash_obj_rpm_gauge, (A0)
	MOVE.w	#$00A1, $E(A0)
	MOVE.w	#$0128, $16(A0)
	MOVE.w	#$0090, $18(A0)
	MOVE.w	#$FFFF, $28(A0)
Crash_obj_rpm_gauge:
	MOVE.w	Visual_rpm.w, D0
	CMPI.w	#Engine_rpm_max, D0 ; ...
	BCS.b	Crash_obj_rpm_clamp  ; if D0 >= max
	MOVE.w	#Engine_rpm_max, D0 ; then D0 = max
Crash_obj_rpm_clamp:
	CMPI.w	#700, D0
	BCC.b	Crash_obj_rpm_div50  ; if D0 < 700
	DIVS.w	#100, D0             ; then D0 = D0/100
	BRA.b	Crash_obj_gauge_apply
Crash_obj_rpm_div50:             ; else
	DIVS.w	#50, D0              ; ...
	SUBQ.w	#7, D0               ; D0 = D0/50-7
Crash_obj_gauge_apply:
	LEA	Crash_rpm_gauge_palette_table, A1
	LEA	Dma_queue_slot_a.w, A2
Crash_obj_gauge_write:
	MOVE.w	$28(A0), D1
	MOVE.w	D0, $28(A0)
	CMP.w	D0, D1
	BEQ.b	Crash_obj_gauge_done
	LSL.w	#3, D0
	ADDA.w	D0, A1
	MOVE.l	$3(A1), $4(A0)
	JSR	Write_3_palette_vdp_bytes(PC)
Crash_obj_gauge_done:
	JMP	Queue_object_for_sprite_buffer
;Write_3_palette_vdp_bytes
Write_3_palette_vdp_bytes:
; Appends 3 pairs of (VDP register command byte, colour value byte) to (A2)+,
; covering CRAM registers $97, $96, $95. Source bytes read from (A1)+.
	MOVE.b	#$97, (A2)+
	MOVE.b	(A1)+, (A2)+
	MOVE.b	#$96, (A2)+
	MOVE.b	(A1)+, (A2)+
	MOVE.b	#$95, (A2)+
	MOVE.b	(A1), (A2)+
	RTS
Retire_car_obj_decel_table:
	dc.b	$0C
	dc.b	$0A
Retire_car_obj_init_low:
	MOVE.w	#$00C8, $18(A0)
	BRA.b	Retire_car_obj_init_common
Retire_car_obj_init_high:
	MOVE.w	#$0138, $18(A0)
Retire_car_obj_init_common:
	MOVE.l	#Retire_car_obj_anim, (A0)
	MOVE.l	#Sprite_frame_data_12652, $4(A0)
	MOVE.w	#$00A1, $E(A0)
	MOVE.w	#$0170, $16(A0)
	MOVE.w	#$000F, $30(A0)
	MOVE.w	#1, Retire_flash_flag.w
Retire_car_obj_anim:
	SUBI.l	#$0000F000, $30(A0)
	MOVE.w	$30(A0), D0
	SUB.w	D0, $16(A0)
	MOVE.w	$16(A0), D0
	CMPI.w	#$0170, D0
	BLS.b	Retire_car_obj_flash
	MOVE.w	#$0170, $16(A0)
	MOVE.w	$2E(A0), D0
	MOVEQ	#0, D1
	MOVE.w	D1, $32(A0)
	MOVE.b	Retire_car_obj_decel_table(PC,D0.w), D1
	MOVE.w	D1, $30(A0)
	ADDQ.w	#1, D0
	MOVE.w	D0, $2E(A0)
	CMPI.w	#3, D0
	BCS.b	Retire_car_obj_flash
	CLR.w	Retire_flash_flag.w
	MOVE.l	#Race_finish_obj, (A0)
	CLR.w	$36(A0)
	MOVE.w	#3, $34(A0)
Retire_car_obj_flash:
	SUBQ.w	#1, $36(A0)
	BPL.b	Retire_car_obj_queue
	MOVE.w	#1, $36(A0)
	ADDQ.w	#1, $34(A0)
	MOVE.w	$34(A0), D0
	ANDI.w	#7, D0
	ADD.w	D0, D0
	ADD.w	D0, D0
	LEA	Retire_flash_palette_table, A1
	ADDA.w	D0, A1
	LEA	Retire_flash_palette_dma.w, A2
	JSR	Write_3_palette_vdp_bytes(PC)
Retire_car_obj_queue:
	JMP	Queue_object_for_sprite_buffer
Slide_car_obj_init_from_bottom:
	MOVE.l	#Player_car_sprite_frames_crash, $8(A0)
	MOVE.w	#$00F0, $18(A0)
	MOVE.w	#$FFF9, $2E(A0)
	BRA.b	Slide_car_obj_init_common
Slide_car_obj_init_from_top:
	MOVE.l	#Player_car_sprite_frames_normal, $8(A0)
	MOVE.w	#$0110, $18(A0)
	MOVE.w	#7, $2E(A0)
Slide_car_obj_init_common:
	MOVE.l	#Slide_car_obj_set_palette, (A0)
	MOVE.w	#$00A1, $E(A0)
	MOVE.w	#$0178, $16(A0)
	MOVE.w	#6, $2C(A0)
	RTS
Slide_car_obj_set_palette:
	MOVE.l	#Slide_car_obj_move, (A0)
	LEA	Car_sprite_ptr_table, A1
	LEA	Slide_car_palette_dma.w, A2
	JSR	Write_3_palette_vdp_bytes(PC)
Slide_car_obj_move:
	MOVE.w	$2C(A0), D0
	SUB.w	D0, $16(A0)
	MOVE.w	$2E(A0), D0
	BMI.b	Slide_car_obj_move_up
	ADD.w	D0, $18(A0)
	MOVE.w	$18(A0), D0
	CMPI.w	#$01A0, D0
	BHI.w	Slide_car_obj_done
	CMPI.w	#$0150, D0
	BCS.b	Slide_car_obj_draw
	MOVE.w	#6, D0
	BRA.b	Slide_car_obj_bounce
Slide_car_obj_move_up:
	ADD.w	D0, $18(A0)
	MOVE.w	$18(A0), D0
	CMPI.w	#$0060, D0
	BCS.w	Slide_car_obj_done
	CMPI.w	#$00B0, D0
	BHI.b	Slide_car_obj_draw
	MOVE.w	#$FFFA, D0
Slide_car_obj_bounce:
	MOVE.w	#4, $2C(A0)
	MOVE.w	D0, $2E(A0)
	MOVE.w	#4, $22(A0)
Slide_car_obj_draw:
	MOVE.w	$22(A0), D0
	MOVEA.l	$8(A0), A1
	MOVE.l	(A1,D0.w), $4(A0)
	JMP	Queue_object_for_sprite_buffer
Slide_car_obj_done:
	JMP	Clear_object_slot
Race_finish_obj:
	MOVE.w	#1, Laps_done_flag.w
	MOVE.w	#1, Race_finish_flag.w
	CLR.w	Audio_engine_flags
	TST.w	Warm_up.w
	BNE.b	Race_finish_obj_Warmup_init
	TST.w	Practice_mode.w
	BNE.w	Race_finish_obj_Practice_init
	TST.w	Track_index_arcade_mode.w
	BEQ.b	Race_finish_obj_Normal_init
	TST.w	Use_world_championship_tracks.w
	BNE.b	Race_finish_obj_Championship
	MOVE.l	#$00009E08, D1
	JSR	Alloc_aux_object_slot
	MOVE.l	#Queue_object_for_sprite_buffer, (A0)
	JMP	Queue_object_for_sprite_buffer
Race_finish_obj_Championship:
	MOVE.l	#$00009DB8, D1
	JSR	Alloc_aux_object_slot
	MOVE.l	#Queue_object_for_sprite_buffer, (A0)
	JMP	Queue_object_for_sprite_buffer
Race_finish_obj_Normal_init:
	MOVE.l	#Race_finish_obj_Normal_wait, (A0)
	MOVE.w	#$001E, $36(A0)
Race_finish_obj_Normal_wait:
	SUBQ.w	#1, $36(A0)
	BEQ.b	Race_finish_obj_Show_results
	JMP	Queue_object_for_sprite_buffer
Race_finish_obj_Show_results:
	MOVE.w	#$000E, Current_lap.w
	MOVE.b	#$FF, Lap_time_ptr.w
	MOVE.l	#Race_finish_results_init, Frame_callback.w
	RTS
Race_finish_obj_Warmup_init:
	MOVE.l	#Race_finish_obj_Warmup_wait, (A0)
	MOVE.w	#$001E, $36(A0)
Race_finish_obj_Warmup_wait:
	SUBQ.w	#1, $36(A0)
	BEQ.b	Race_finish_obj_Warmup_done
	JMP	Queue_object_for_sprite_buffer
Race_finish_obj_Warmup_done:
	MOVE.l	#Title_menu, Frame_callback.w
	RTS
Race_finish_obj_Practice_init:
	MOVE.l	#Race_finish_obj_Practice_wait, (A0)
	MOVE.w	#$001E, $36(A0)
Race_finish_obj_Practice_wait:
	SUBQ.w	#1, $36(A0)
	BEQ.b	Race_finish_obj_Practice_done
	JMP	Queue_object_for_sprite_buffer
Race_finish_obj_Practice_done:
	MOVE.l	#$00005690, Frame_callback.w
	RTS
Checkpoint_anim_obj_init:
	MOVE.l	#Checkpoint_anim_obj, (A0)
	MOVE.w	#$0028, $36(A0)
Checkpoint_anim_obj:
	MOVE.b	Frame_counter.w, D0
	ANDI.w	#1, D0
	ADDQ.w	#1, D0
	MOVE.w	D0, Overtake_event_flag.w
	MOVE.w	Retire_animation_flag.w, D0
	OR.w	Retire_flag.w, D0
	BNE.b	Checkpoint_anim_obj_Rts
	SUBQ.w	#1, $1C(A0)
	BPL.b	Checkpoint_anim_obj_Countdown
	MOVE.w	#4, $1C(A0)
	MOVE.w	#Sfx_checkpoint, Audio_sfx_cmd      ; checkpoint / lap event SFX
Checkpoint_anim_obj_Countdown:
	SUBQ.w	#1, $36(A0)
	BNE.b	Checkpoint_anim_obj_Rts
	MOVE.b	#$FF, Lap_time_ptr.w
	MOVE.l	#Race_finish_results_init, Frame_callback.w
Checkpoint_anim_obj_Rts:
	RTS
;Compute_minimap_index
Compute_minimap_index:
; Convert a raw track distance in D0 to a word-aligned minimap position index.
; Shifts D0 right by 5 and clears bit 0, giving a 2-byte-aligned index into
; the minimap position map.  Falls through to Load_minimap_position.
; Inputs:  D0 = track distance (e.g. Car_obj_dist field)
	MOVEQ	#0, D1
	MOVEQ	#0, D2
	LSR.w	#5, D0
	ANDI.w	#$FFFE, D0
;Load_minimap_position
Load_minimap_position:
; Read the (x, y) minimap pixel position for a car at track index D0 and
; store the two bytes into the object slot at +$2C (x) and +$2E (y).
; The position map is a flat array of (x,y) pairs indexed by track position;
; Minimap_track_map_ptr holds the address of the current track's map.
; Inputs:  D0 = minimap position index (word-aligned), A0 = object slot
	MOVEA.l	Minimap_track_map_ptr.w, A1
	MOVE.b	(A1,D0.w), $2C(A0)
	MOVE.b	$1(A1,D0.w), $2E(A0)
	RTS
Compute_curve_speed_factor:
	MOVE.w	#$05AF, D0
	MOVE.w	$1A(A0), D1
	LSR.w	#2, D1
	LEA	Curve_data+1, A1
	MOVE.b	(A1,D1.w), D1
	BCLR.l	#6, D1
	SNE	D2
	EXT.w	D1
	BEQ.b	Compute_curve_speed_factor_Rts
	MOVE.w	$12(A0), D3
	SMI	D4
	BPL.b	Compute_curve_speed_factor_Abs
	NEG.w	D3
Compute_curve_speed_factor_Abs:
	SUBI.w	#$0020, D3
	BCS.b	Compute_curve_speed_factor_Rts
	LSR.w	#5, D3
	CMPI.w	#8, D3
	BCS.b	Compute_curve_speed_factor_Clamp
	MOVEQ	#7, D3
Compute_curve_speed_factor_Clamp:
	TST.b	D4
	BNE.b	Compute_curve_speed_factor_Left
	ADDQ.w	#8, D3
	BRA.b	Compute_curve_speed_factor_Right
Compute_curve_speed_factor_Left:
	MOVEQ	#7, D7
	SUB.w	D3, D7
	MOVE.w	D7, D3
Compute_curve_speed_factor_Right:
	TST.b	D2
	BEQ.b	Compute_curve_speed_factor_Lookup
	MOVEQ	#$0000000F, D7
	SUB.w	D3, D7
	MOVE.w	D7, D3
Compute_curve_speed_factor_Lookup:
	ADD.w	D3, D3
	LSL.w	#5, D1
	ADD.w	D3, D1
	LEA	Curve_speed_factor_table, A1
	MOVE.w	(A1,D1.w), D0
Compute_curve_speed_factor_Rts:
	RTS
; Update_horizontal_position - integrate curve displacement and steering into Horizontal_position
;
; Called from Race_loop step 11.
; Horizontal_position is a signed 32-bit fixed-point value: integer part (word) is the lane
; offset in screen pixels, with 0 = track centre.
;
; Each frame:
;   1. If Overtake_delta or Overtake_position_delta are non-zero: skip (overtake animation controls position).
;   2. If speed == 0: skip.
;   3. Read curve data at current track step:
;        curve displacement = curve_sharpness × speed  (positive = pushed to outside of turn)
;   4. Steering contribution = (Steering_output << 6) / divisor  (scaled by speed at low speeds)
;        divisor from Steering_divisor_straight/Steering_divisor_curve table; in championship mode adjusted per track via Track_steering_index_b.
;   5. Integrate both into Horizontal_position, clamped to ±$01900000 (±$01500000 on some tracks).
;   6. Collision detection: if on a curve, steering hard into the curve (|Steering_output| ≥ $64),
;      car is far off-centre, and speed ≥ $20 → set Collision_flag = $FFFF.
; Player_x_negated = −Horizontal_position.w is written for the road renderer.
Update_horizontal_position:
	CLR.w	Collision_flag.w
	LEA	Steering_divisor_straight.w, A0
	LEA	Steering_curve_divisors(PC), A2
	MOVE.w	Overtake_delta.w, D3
	OR.w	Overtake_position_delta.w, D3
	BNE.w	Update_horizontal_position_Done
	MOVE.w	Player_speed.w, D3
	BEQ.w	Update_horizontal_position_Done
	MOVE.l	#$01900000, D6
	CMPI.w	#2, Special_road_scene.w
	BCS.b	Update_horizontal_position_Load_curve
	MOVE.l	#$01500000, D6
Update_horizontal_position_Load_curve:
	MOVE.l	Horizontal_position.w, D7
	MOVEQ	#0, D0
	MOVE.w	Player_distance.w, D1
	LSR.w	#2, D1
	LEA	Curve_data+1, A1
	MOVE.b	(A1,D1.w), D0 ; read curve data at step
	MOVE.w	D0, D5
	BEQ.b	Update_horizontal_position_Apply_steering ; jump if straight. Upcoming instructions calculate horizontal position displacement from turning
	ADDQ.w	#2, A0
	ADDQ.w	#2, A2
	BCLR.l	#6, D0 ; zero the bit indicating left/right turn
	SNE	D1 ; D1=$FF if right turn, else D1=$00
	ADD.w	D0, D0
	LEA	Curve_displacement_table(PC), A1
	MOVE.w	(A1,D0.w), D0
	MULU.w	D3, D0 ; D0 = curve sharpness * player speed
	TST.b	D1
	BEQ.b	Update_horizontal_position_Apply_steering ; jump if left turn
	NEG.l	D0 ; when right turn, negate so car is displaced left
Update_horizontal_position_Apply_steering:
	MOVE.b	Steering_output.w, D1
	EXT.w	D1
	CMPI.w	#$0081, D3
	BCC.b	Update_horizontal_position_Steering_full
	MULS.w	D3, D1
	ASR.w	#7, D1
Update_horizontal_position_Steering_full:
	LSL.w	#6, D1
	EXT.l	D1
	MOVE.w	(A0), D2
	TST.w	Use_world_championship_tracks.w
	BEQ.b	Update_horizontal_position_Compute_delta
	TST.w	Practice_mode.w
	BNE.b	Update_horizontal_position_Compute_delta
	MOVE.w	Track_steering_index_b.w, D0 ; Why is D0 overwritten here before previous calculation is used?
	ADD.w	D0, D0
	ADD.w	(A2,D0.w), D2
Update_horizontal_position_Compute_delta:
	DIVS.w	D2, D1
	SWAP	D1
	CLR.w	D1
	ASR.l	#3, D1
	ADD.l	D0, D1
	ADD.l	D1, D7
	SMI	D0
	BPL.b	Update_horizontal_position_Clamp_pos
	NEG.l	D7
Update_horizontal_position_Clamp_pos:
	CMP.l	D6, D7
	BCS.b	Update_horizontal_position_Within_boundary
	MOVE.l	D6, D7
Update_horizontal_position_Within_boundary:
	TST.b	D0
	BEQ.b	Update_horizontal_position_Restore_sign
	NEG.l	D7
Update_horizontal_position_Restore_sign:
	MOVE.l	D7, Horizontal_position.w ; commenting out makes car never mode sideways
	TST.l	D1
	BEQ.b	Update_horizontal_position_Done
	MOVE.w	D5, D0
	ANDI.w	#$003F, D0
	BEQ.b	Update_horizontal_position_Done
	MOVE.b	Steering_output.w, D0
	SMI	D7
	BPL.b	Update_horizontal_position_Steering_abs
	NEG.b	D0
Update_horizontal_position_Steering_abs:
	CMPI.b	#$64, D0
	BCS.b	Update_horizontal_position_Done
	BTST.l	#6, D5
	BNE.b	Update_horizontal_position_Right_turn_collision
	TST.b	D7
	BEQ.b	Update_horizontal_position_Done
	CMPI.l	#$FFFF4000, D1
	BLT.b	Update_horizontal_position_Done
	BRA.b	Update_horizontal_position_Set_collision
Update_horizontal_position_Right_turn_collision:
	TST.b	D7
	BNE.b	Update_horizontal_position_Done
	CMPI.l	#$0000C000, D1
	BGT.b	Update_horizontal_position_Done
Update_horizontal_position_Set_collision:
	CMPI.w	#$0020, Player_speed.w
	BCS.b	Update_horizontal_position_Done
	MOVE.w	#$FFFF, Collision_flag.w
Update_horizontal_position_Done:
	MOVE.w	Horizontal_position.w, D0
	NEG.w	D0
	MOVE.w	D0, Player_x_negated.w
	RTS
