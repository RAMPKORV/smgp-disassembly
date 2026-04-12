Draw_track_name_and_championship_standings:
	LEA	Minimap_round_label_tilemap(PC), A6
	JSR	Draw_packed_tilemap_to_vdp
	MOVE.w	Track_index.w, D0
	ADDQ.w	#1, D0
	MOVE.w	#$C7C1, D1
	SUBI.w	#$000A, D0
	BCC.b	Draw_track_name_and_championship_standings_Lo
	ADDI.w	#$000A, D0
	MOVEQ	#0, D1
Draw_track_name_and_championship_standings_Lo:
	MOVE.w	D1, (A5)
	ADDI.w	#$C7C0, D0
	MOVE.w	D0, (A5)
	MOVE.w	Track_index.w, D0
	LSL.w	#2, D0
	MOVEA.l	Track_name_tilemap_ptrs(PC,D0.w), A6
	MOVE.w	#$021A, D6
	MOVE.w	#$87C0, D0
	JSR	Draw_packed_tilemap_to_vdp_preset_base
	MOVE.w	#0, (A5)
	MOVE.w	#$87D0, (A5)
	MOVE.w	#$87D9, (A5)
	RTS
Track_name_tilemap_ptrs: ; Track names
	dc.l	Track_name_San_Marino
	dc.l	Track_name_Brazil
	dc.l	Track_name_France
	dc.l	Track_name_Hungary
	dc.l	Track_name_West_Germany
	dc.l	Track_name_USA
	dc.l	Track_name_Canada
	dc.l	Track_name_Great_Britain
	dc.l	Track_name_Italy
	dc.l	Track_name_Portugal
	dc.l	Track_name_Spain
	dc.l	Track_name_Mexico
	dc.l	Track_name_Japan
	dc.l	Track_name_Belgium
	dc.l	Track_name_Australia
	dc.l	Track_name_Monaco
Finish_race_shared_setup:
	MOVE.w	#$FFFF, Ai_active_flag.w
	JSR	Clear_partial_main_object_pool
	JSR	Clear_aux_object_pool
	MOVE.w	Track_length.w, D1
	ADD.w	D1, Total_distance.w
	MOVE.w	Total_distance.w, Player_place_score.w
	ADDI.w	#$0040, Best_lap_vdp_step.w
	LEA	Player_obj.w, A0
	MOVEQ	#-2, D0
	JSR	Load_minimap_position
	LEA	(Main_object_pool+$6C0).w, A0
	MOVEQ	#$0000000F, D0
Finish_race_shared_setup_AI_loop:
	MOVE.w	#$2000, $C(A0)
	MOVE.w	#$FFC8, $2C(A0)
	MOVE.w	#$FFF0, $2E(A0)
	LEA	$40(A0), A0
	DBF	D0, Finish_race_shared_setup_AI_loop
	MOVE.w	#$8000, D1
	LEA	Road_row_x_buf.w, A0
	MOVEQ	#$0000003F, D0
Finish_race_shared_setup_Buf1_loop:
	MOVE.w	D1, (A0)+
	DBF	D0, Finish_race_shared_setup_Buf1_loop
	LEA	Road_scanline_x_buf.w, A0
	MOVEQ	#$0000007F, D0
Finish_race_shared_setup_Buf2_loop:
	MOVE.w	D1, (A0)+
	DBF	D0, Finish_race_shared_setup_Buf2_loop
	RTS
;Draw_car_machine_graphics
Draw_car_machine_graphics:
	TST.w	Has_rival_flag.w
	BEQ.b	Draw_car_machine_graphics_Player
	MOVE.w	Rival_grid_position.w, D1
	MOVE.l	#$44260000, D7
	BSR.b	Draw_placement_tilemap
Draw_car_machine_graphics_Player:
	MOVE.w	Player_grid_position.w, D1
	MOVE.l	#$441C0000, D7
Draw_placement_tilemap:
	LSL.w	#4, D1
	LEA	Placement_ordinal_tilemap, A6
	ADDA.w	D1, A6
	MOVEQ	#3, D6
	MOVEQ	#1, D5
	JMP	Draw_tilemap_buffer_to_vdp_128_cell_rows
;Draw_gear_indicator
Draw_gear_indicator:
	MOVE.w	Laps_completed.w, D0
	LSL.w	#2, D0
	LEA	Lap_number_tilemap_table, A6
	ADDA.w	D0, A6
	MOVEQ	#0, D6
	MOVEQ	#1, D5
	MOVE.l	#$44360000, D7
	JMP	Draw_tilemap_buffer_to_vdp_128_cell_rows
;Draw_race_timer
Draw_race_timer:
	MOVE.l	Race_timer_bcd.w, D0
	MOVE.w	#$C000, D3
	LEA	(Digit_tilemap_buf+$7C).w, A3
	JSR	Format_bcd_time_to_tile_buffer
	MOVE.l	#$422C0000, D7
	MOVEQ	#7, D6
	MOVEQ	#0, D5
	LEA	(A3), A6
	JMP	Draw_tilemap_buffer_to_vdp_128_cell_rows
Initialize_minimap_display_buffers:
	LEA	Decomp_stream_buf.w, A0
	MOVE.w	#$013F, D0
	MOVEQ	#0, D1
Initialize_minimap_display_buffers_Clear_loop:
	MOVE.l	D1, (A0)+
	DBF	D0, Initialize_minimap_display_buffers_Clear_loop
	JSR	Build_minimap_player_row_buffer(PC)
	JSR	Build_minimap_standings_row_buffer(PC)
	MOVE.l	#$FFFFC080, Podium_minimap_src_ptr.w
	MOVE.w	#$0406, Podium_minimap_vdp_base.w
	RTS
Podium_minimap_dispatch:
	MOVE.w	Podium_minimap_state.w, D0
	JMP	Podium_minimap_dispatch_Table(PC,D0.w)
Podium_minimap_dispatch_Table:
	BRA.w	Podium_minimap_Scroll
	BRA.w	Podium_minimap_Wait_button
	BRA.w	Podium_minimap_Show
	BRA.w	Podium_minimap_Scroll
	BRA.w	Podium_minimap_Wait_button
	BRA.w	Podium_minimap_Show
	ADDQ.w	#4, Anim_delay.w
	RTS
Podium_minimap_Wait_button:
	MOVE.b	Input_click_bitset.w, D0
	ANDI.w	#$00F0, D0
	BEQ.b	Podium_minimap_Wait_button_Rts
Podium_minimap_Advance:
	ADDQ.w	#4, Podium_minimap_state.w
Podium_minimap_Wait_button_Rts:
	RTS
Podium_minimap_Show:
	MOVE.w	#$0406, Podium_minimap_vdp_base.w
	MOVE.w	#$0206, D0
	MOVE.w	#$0600, D1
	LEA	Draw_tilemap_buffer_to_vdp_128_cell_rows, A1
	MOVE.l	#$FFFFC280, Podium_minimap_src_ptr.w
	CLR.w	Podium_minimap_cell_x.w
	CLR.w	Podium_minimap_row.w
	MOVE.w	D0, D7
	JSR	Tile_index_to_vdp_command
	MOVEQ	#$00000019, D6
	MOVEQ	#4, D5
	LEA	$00FF5980, A6
	JSR	(A1)
	ADD.w	D1, D0
	MOVE.w	D0, D7
	JSR	Tile_index_to_vdp_command
	MOVEQ	#4, D5
	LEA	$00FF5980, A6
	JSR	(A1)
	ADD.w	D1, D0
	MOVE.w	D0, D7
	JSR	Tile_index_to_vdp_command
	MOVEQ	#4, D5
	LEA	$00FF5980, A6
	JSR	(A1)
	BRA.b	Podium_minimap_Advance
Podium_minimap_Scroll:
	MOVE.w	#$0100, D1
	MOVE.w	#$0200, D2
	MOVE.w	Podium_minimap_vdp_base.w, D7
	ADD.w	Podium_minimap_cell_x.w, D7
	JSR	Tile_index_to_vdp_command
	MOVE.l	D7, VDP_control_port
	MOVE.w	Podium_minimap_row.w, D0
	BEQ.b	Podium_minimap_Scroll_Row
	CMPI.w	#7, D0
	BNE.b	Podium_minimap_Scroll_Cell
Podium_minimap_Scroll_Row:
	MOVEA.l	Podium_minimap_src_ptr.w, A0
	CMPI.w	#$FFFF, (A0)
	BEQ.b	Podium_minimap_Advance2
	MOVEQ	#$00000019, D0
Podium_minimap_Scroll_Row_loop:
	MOVE.w	(A0)+, VDP_data_port
	DBF	D0, Podium_minimap_Scroll_Row_loop
	MOVE.l	A0, Podium_minimap_src_ptr.w
	ADD.w	D2, Podium_minimap_vdp_base.w
	ADDQ.w	#1, Podium_minimap_row.w
	CMPI.w	#8, Podium_minimap_row.w
	BNE.b	Podium_minimap_Scroll_Row_Rts
	SUB.w	D1, Podium_minimap_vdp_base.w
Podium_minimap_Scroll_Row_Rts:
	RTS
Podium_minimap_Scroll_Cell:
	MOVEA.l	Podium_minimap_src_ptr.w, A0
	MOVE.w	(A0)+, VDP_data_port
	MOVE.l	A0, Podium_minimap_src_ptr.w
	MOVE.w	Podium_minimap_cell_x.w, D0
	ADDQ.w	#2, D0
	CMPI.w	#$0034, D0
	BCS.b	Podium_minimap_Scroll_Cell_Store
	ADD.w	D2, Podium_minimap_vdp_base.w
	MOVE.w	Podium_minimap_row.w, D0
	ADDQ.w	#1, D0
	CMPI.w	#7, D0
	BNE.b	Podium_minimap_Scroll_Cell_Row
	SUB.w	D1, Podium_minimap_vdp_base.w
Podium_minimap_Scroll_Cell_Row:
	MOVE.w	D0, Podium_minimap_row.w
	CMPI.w	#9, D0
	BNE.b	Podium_minimap_Scroll_Cell_Rts
Podium_minimap_Advance2:
	ADDQ.w	#4, Podium_minimap_state.w
Podium_minimap_Scroll_Cell_Rts:
	MOVEQ	#0, D0
Podium_minimap_Scroll_Cell_Store:
	MOVE.w	D0, Podium_minimap_cell_x.w
	RTS
Init_result_score_data:
	dc.w	$07E0
	dc.w	$0EE0
	dc.b	$10, $F6
	dc.w	$07F6
	dc.w	$0EF6
Init_result_score_data_2:
	dc.l	$07D80ED8
	dc.b	$10, $EE, $07, $EE, $0E, $EE
Finish_screen_tilemap_with_rival:
	dc.b	$04, $04, $FB, $A7, $C0
	txt "POSITION"
	dc.b $FC, $FA
	txt "YOU"
	dc.b $2B
	txt "RIVAL"
	dc.b $28, $FA, $FA, $FA, $FA, $FA, $2B, $FF
Finish_screen_tilemap_no_rival:
	dc.b	$04, $06, $FB, $A7, $C0, $22, $18, $1E, $1B, $FC, $FA, $19, $18, $1C, $12, $1D, $12, $18, $17, $28, $FF, $00
Finish_screen_tilemap_list:
	dc.b	$00, $07
	dc.l	Finish_screen_tilemap_time
	dc.l	Finish_screen_tilemap_lap
	dc.l	Finish_screen_tilemap_gap
	dc.l	Finish_screen_tilemap_pos1
	dc.l	Finish_screen_tilemap_pos2
	dc.l	Finish_screen_tilemap_pos3
	dc.l	Finish_screen_tilemap_pos4
	dc.l	Finish_screen_tilemap_pos5
Finish_screen_tilemap_time:
	dc.b	$01, $2C, $FB, $A7, $C0, $15, $0A, $19, $FA, $1D, $12, $16, $0E, $FF
Finish_screen_tilemap_lap:
	dc.b	$04, $30, $15, $0A, $19, $FF
Finish_screen_tilemap_gap:
	dc.b	$04, $38, $FB, $C4, $AC, $1C, $10, $FC, $1D, $11, $FF, $00
Finish_screen_tilemap_pos1:
	dc.b	$07, $DE, $FB, $43, $1D, $2B, $FF, $00
Finish_screen_tilemap_pos2:
	dc.b	$0E, $DE, $2B, $FF
Finish_screen_tilemap_pos3:
	dc.b	$10, $F4, $2B, $FF
Finish_screen_tilemap_pos4:
	dc.b	$07, $F4, $2B, $FF
Finish_screen_tilemap_pos5:
	dc.b	$0E, $F4, $2B, $FF
;Minimap_team_colour_strips
Minimap_team_colour_strips:
	dc.w	$0000, $87C1, $A7DC, $A7DD, $0000, $87C2, $A7D7, $A7CD, $0000, $87C3, $A7DB, $A7CD, $0000, $87C4, $A7DD, $A7D1, $0000, $87C5, $A7DD, $A7D1, $0000, $87C6, $A7DD, $A7D1, $0000, $87C7, $A7DD, $A7D1, $0000, $87C8, $A7DD, $A7D1
	dc.b	$00, $00, $87, $C9, $A7, $DD, $A7, $D1, $87, $C1, $87, $C0, $A7, $DD, $A7, $D1
	dc.w	$87C1, $87C1, $A7DD, $A7D1
	dc.b	$87, $C1, $87, $C2, $A7, $DD, $A7, $D1, $87, $C1, $87, $C3, $A7, $DD, $A7, $D1, $87, $C1, $87, $C4, $A7, $DD, $A7, $D1, $87, $C1, $87, $C5, $A7, $DD, $A7, $D1
	dc.w	$87C1, $87C6, $A7DD, $A7D1
Minimap_player_header_template:
	dc.w	$C7EC, $C7EC, $C7EC, $C7EC, $C7EC, $C7EC, $C7EC, $C7EC, $0000, $C7DB, $C7CE, $C7DC, $C7DE, $C7D5, $C7DD, $C7DC, $0000, $C7EC, $C7EC, $C7EC, $C7EC, $C7EC, $C7EC, $C7EC, $C7EC, $C7EC
Minimap_standings_header_template:
	dc.w	$C7EC, $0000, $C7CD, $C7DB, $C7D2, $C7DF, $C7CE, $C7DB, $C7E6, $C7DC, $0000, $C7D9, $C7D8, $C7D2, $C7D7, $C7DD, $0000, $C7DB, $C7CA, $C7D7, $C7D4, $C7D2, $C7D7, $C7D0, $0000, $C7EC
Driver_name_tile_offsets:
	dc.b	$22, $18, $1E, $00
Minimap_player_row_extras:
	dc.w	$0000, $87EC, $87EC, $87EC
Minimap_round_label_tilemap:
	dc.b	$02, $06, $FB, $C7, $C0, $1B, $18, $1E, $17, $0D, $FA, $FF
Track_name_San_Marino:
	txt "SAN", $FA
	txt "MARINO", $FF
Track_name_Brazil:
	txt "BRAZIL", $FF
Track_name_France:
	txt "FRANCE", $FF
Track_name_Hungary:
	txt "HUNGARY", $FF
Track_name_West_Germany:
	txt "WEST", $FA
	txt "GERMANY", $FF
Track_name_USA:
	txt "U.S.A.", $FF
Track_name_Canada:
	txt "CANADA", $FF
Track_name_Great_Britain:
	txt "GREAT", $FA
	txt "BRITAIN", $FF
Track_name_Italy:
	txt "ITALY", $FF
Track_name_Portugal:
	txt "PORTUGAL", $FF
Track_name_Spain:
	txt "SPAIN", $FF
Track_name_Mexico:
	txt "MEXICO", $FF
Track_name_Japan:
	txt "JAPAN", $FF
Track_name_Belgium:
	txt "BELGIUM", $FF
Track_name_Australia:
	txt "AUSTRALIA", $FF
Track_name_Monaco:
	txt "MONACO", $FF
	dc.b	$00
;Copy_words_A5_to_A6
Copy_words_A5_to_A6:
; Copies D7+1 words from (A5)+ to (A6)+.
	MOVE.w	(A5)+, (A6)+
	DBF	D7, Copy_words_A5_to_A6
	RTS
;Load_driver_name_text_pointer
Load_driver_name_text_pointer:
	LEA	Driver_info_table, A1
	MULS.w	#$000C, D0
	ADDA.l	D0, A1
	MOVEA.l	(A1)+, A2
	MOVE.w	(A1)+, D1
	RTS
;Load_car_spec_text_pointer
Load_car_spec_text_pointer:
	LEA	Car_spec_text_table, A1
	MULS.w	#$0012, D0
	ADDA.l	D0, A1
	MOVEA.l	(A1)+, A2
	MOVE.w	(A1)+, D1
	RTS
Build_minimap_player_row_buffer:
; Build the minimap display row buffer for the player-position view
; (used in the race standings/minimap panel).
; Copies a 26-word header template from Minimap_player_header_template into $FFFFC080, then
; for each of 6 standings rows copies a 4-word team-colour strip from
; Minimap_team_colour_strips and writes the driver name + car spec text tiles for the
; matching driver at that position into the buffer row.
; Output buffer: $FFFFC080 (consumed by Draw_packed_tilemap_to_vdp later)
	LEA	Decomp_stream_buf.w, A6
	LEA	Minimap_player_header_template(PC), A5
	MOVEQ	#$00000019, D7
	JSR	Copy_words_A5_to_A6(PC)
	MOVEQ	#5, D6
	LEA	Minimap_team_colour_strips(PC), A4
	LEA	Standings_team_order.w, A3
Build_minimap_player_row_buffer_Row_loop:
	ADDQ.w	#2, A6
	MOVEQ	#3, D7
	LEA	(A4), A5
	JSR	Copy_words_A5_to_A6(PC)
	LEA	(A5), A4
	ADDQ.w	#2, A6
	LEA	Driver_name_tile_offsets-1(PC), A2
	MOVEQ	#3, D1
	MOVE.b	(A3), D0
	ANDI.w	#$000F, D0
	MOVE.b	Player_team.w, D2
	ANDI.w	#$000F, D2
	CMP.w	D2, D0
	BEQ.b	Build_minimap_player_row_buffer_Tiles
	LEA	Drivers_and_teams_map.w, A1
	MOVE.b	(A1,D0.w), D0
	ANDI.w	#$000F, D0
	BTST.b	#6, Player_team.w
	BEQ.b	Build_minimap_player_row_buffer_Name
	SUBQ.w	#1, D0
Build_minimap_player_row_buffer_Name:
	JSR	Load_driver_name_text_pointer(PC)
Build_minimap_player_row_buffer_Tiles:
	SUBQ.w	#1, D1
	ADDQ.w	#1, A2
	MOVEQ	#0, D3
Build_minimap_player_row_buffer_Name_loop:
	MOVEQ	#0, D0
	MOVE.b	(A2)+, D0
	ADDI.w	#$87C0, D0
	MOVE.w	D0, (A6,D3.w)
	ADDQ.w	#2, D3
	DBF	D1, Build_minimap_player_row_buffer_Name_loop
	LEA	$14(A6), A6
	MOVE.w	#$C7F4, (A6)+
	MOVE.b	(A3)+, D0
	ANDI.w	#$000F, D0
	JSR	Load_car_spec_text_pointer(PC)
	ADDQ.w	#1, A2
	MOVEQ	#2, D5
Build_minimap_player_row_buffer_Car_loop:
	MOVEQ	#0, D0
	MOVE.b	(A2)+, D0
	ADDI.w	#$C7C0, D0
	MOVE.w	D0, (A6)+
	DBF	D5, Build_minimap_player_row_buffer_Car_loop
	MOVE.w	#$C7F5, (A6)
	LEA	$C(A6), A6
	DBF	D6, Build_minimap_player_row_buffer_Row_loop
	MOVE.w	#$FFFF, (A6)
	CMPI.w	#5, Player_grid_position.w
	BLS.b	Build_minimap_player_row_buffer_Rts
	MOVEQ	#$00000019, D0
Build_minimap_player_row_buffer_Pad_loop:
	MOVE.w	#$C7EC, (A6)+
	DBF	D0, Build_minimap_player_row_buffer_Pad_loop
	LEA	Minimap_player_row_extras(PC), A5
	ADDQ.w	#2, A6
	MOVE.w	Player_grid_position.w, D0
	BMI.b	Build_minimap_player_row_buffer_Player
	LSL.w	#3, D0
	LEA	Minimap_team_colour_strips(PC), A5
	ADDA.w	D0, A5
Build_minimap_player_row_buffer_Player:
	MOVEQ	#3, D7
	JSR	Copy_words_A5_to_A6(PC)
	ADDQ.w	#2, A6
	MOVE.w	#$87E2, (A6)+
	MOVE.w	#$87D8, (A6)+
	MOVE.w	#$87DE, (A6)
	LEA	$10(A6), A6
	MOVE.w	#$C7F4, (A6)+
	MOVE.b	Player_team.w, D0
	ANDI.w	#$000F, D0
	JSR	Load_car_spec_text_pointer(PC)
	ADDQ.w	#1, A2
	MOVEQ	#2, D5
Build_minimap_player_row_buffer_Player_car_loop:
	MOVEQ	#0, D0
	MOVE.b	(A2)+, D0
	ADDI.w	#$C7C0, D0
	MOVE.w	D0, (A6)+
	DBF	D5, Build_minimap_player_row_buffer_Player_car_loop
	MOVE.w	#$C7F5, (A6)
Build_minimap_player_row_buffer_Rts:
	RTS
Build_minimap_standings_row_buffer:
; Build the minimap display row buffer for the championship standings view.
; Sorts the standings via Sort_championship_standings, converts each of 16
; scores from binary to 2-digit decimal via Binary_to_decimal, copies the
; header template from Minimap_standings_header_template into $FFFFC280, then for each of 6 rows
; writes the team-colour strip, driver name, car spec, and score digit tiles
; from the sorted standings and $FFFF8FA0 score buffer.
; Output buffer: $FFFFC280
	JSR	Sort_championship_standings(PC)
	LEA	Score_scratch_names.w, A6
	LEA	Score_scratch_buf.w, A5
	MOVEQ	#$0000000F, D7
Build_minimap_standings_row_buffer_Score_loop:
	MOVEQ	#0, D0
	MOVE.b	-(A6), D0
	JSR	Binary_to_decimal
	MOVE.w	D1, -(A5)
	DBF	D7, Build_minimap_standings_row_buffer_Score_loop
	LEA	(Decomp_stream_buf+$200).w, A6
	LEA	Minimap_standings_header_template(PC), A5
	MOVEQ	#$00000019, D7
	JSR	Copy_words_A5_to_A6(PC)
	MOVEQ	#5, D6
	LEA	Minimap_team_colour_strips(PC), A4
	LEA	Score_scratch_buf.w, A3
	LEA	Depth_sort_buf.w, A0
Build_minimap_standings_row_buffer_Row_loop:
	ADDQ.w	#2, A6
	MOVEQ	#3, D7
	MOVEQ	#0, D0
	MOVE.b	$10(A3), D0
	LSL.w	#3, D0
	LEA	(A4,D0.w), A5
	JSR	Copy_words_A5_to_A6(PC)
	ADDQ.w	#2, A6
	LEA	Driver_name_tile_offsets-1(PC), A2
	MOVEQ	#3, D1
	MOVEQ	#0, D0
	MOVE.b	(A3), D0
	BPL.b	Build_minimap_standings_row_buffer_Name
	MOVE.w	#$FFFF, Player_eliminated.w
	BRA.b	Build_minimap_standings_row_buffer_Tiles
Build_minimap_standings_row_buffer_Name:
	LEA	Drivers_and_teams_map.w, A1
	MOVE.b	(A1,D0.w), D0
	ANDI.w	#$000F, D0
	BTST.b	#6, Player_team.w
	BEQ.b	Build_minimap_standings_row_buffer_Name_load
	SUBQ.w	#1, D0
Build_minimap_standings_row_buffer_Name_load:
	JSR	Load_driver_name_text_pointer(PC)
Build_minimap_standings_row_buffer_Tiles:
	SUBQ.w	#1, D1
	ADDQ.w	#1, A2
	MOVEQ	#0, D3
Build_minimap_standings_row_buffer_Name_loop:
	MOVEQ	#0, D0
	MOVE.b	(A2)+, D0
	ADDI.w	#$87C0, D0
	MOVE.w	D0, (A6,D3.w)
	ADDQ.w	#2, D3
	DBF	D1, Build_minimap_standings_row_buffer_Name_loop
	LEA	$14(A6), A6
	MOVE.w	#$C7F4, (A6)+
	MOVEQ	#0, D0
	MOVE.b	(A3)+, D0
	BPL.b	Build_minimap_standings_row_buffer_Car
	MOVE.b	Player_team.w, D0
	ANDI.w	#$000F, D0
Build_minimap_standings_row_buffer_Car:
	JSR	Load_car_spec_text_pointer(PC)
	ADDQ.w	#1, A2
	MOVEQ	#2, D5
Build_minimap_standings_row_buffer_Car_loop:
	MOVEQ	#0, D0
	MOVE.b	(A2)+, D0
	ADDI.w	#$C7C0, D0
	MOVE.w	D0, (A6)+
	DBF	D5, Build_minimap_standings_row_buffer_Car_loop
	MOVE.w	#$C7F5, (A6)
	ADDQ.w	#4, A6
	MOVEQ	#0, D3
	MOVE.b	(A0)+, D0
	JSR	Write_digit_or_blank_tile(PC)
	MOVE.b	(A0), D0
	LSR.w	#4, D0
	JSR	Write_digit_or_blank_tile(PC)
	MOVEQ	#-1, D3
	MOVE.b	(A0)+, D0
	JSR	Write_digit_or_blank_tile(PC)
	ADDQ.w	#2, A6
	DBF	D6, Build_minimap_standings_row_buffer_Row_loop
	MOVE.w	#$FFFF, (A6)
	MOVEQ	#0, D1
	MOVEQ	#$0000000E, D0
	LEA	Score_scratch_buf.w, A0
Build_minimap_standings_row_buffer_Count_loop:
	TST.b	(A0)+
	BMI.b	Build_minimap_standings_row_buffer_Player
	ADDQ.w	#1, D1
	DBF	D0, Build_minimap_standings_row_buffer_Count_loop
Build_minimap_standings_row_buffer_Player:
	TST.w	Player_eliminated.w
	BNE.w	Build_minimap_standings_row_buffer_Rts
	MOVEQ	#$00000019, D0
Build_minimap_standings_row_buffer_Pad_loop:
	MOVE.w	#$C7EC, (A6)+
	DBF	D0, Build_minimap_standings_row_buffer_Pad_loop
	LEA	Minimap_player_row_extras(PC), A5
	ADDQ.w	#2, A6
	MOVE.b	Player_team.w, D0
	ANDI.w	#$000F, D0
	LEA	Driver_points_by_team.w, A0
	TST.b	(A0,D0.w)
	BEQ.b	Build_minimap_standings_row_buffer_Player_colour
	LEA	Score_scratch_pts.w, A0
	MOVEQ	#0, D0
	MOVE.b	(A0,D1.w), D0
	LSL.w	#3, D0
	LEA	Minimap_team_colour_strips(PC), A5
	ADDA.w	D0, A5
Build_minimap_standings_row_buffer_Player_colour:
	MOVEQ	#3, D7
	JSR	Copy_words_A5_to_A6(PC)
	ADDQ.w	#2, A6
	MOVE.w	#$87E2, (A6)+
	MOVE.w	#$87D8, (A6)+
	MOVE.w	#$87DE, (A6)
	LEA	$10(A6), A6
	MOVE.w	#$C7F4, (A6)+
	MOVE.w	D1, D2
	MOVE.b	Player_team.w, D0
	ANDI.w	#$000F, D0
	JSR	Load_car_spec_text_pointer(PC)
	ADDQ.w	#1, A2
	MOVEQ	#2, D5
Build_minimap_standings_row_buffer_Player_car_loop:
	MOVEQ	#0, D0
	MOVE.b	(A2)+, D0
	ADDI.w	#$C7C0, D0
	MOVE.w	D0, (A6)+
	DBF	D5, Build_minimap_standings_row_buffer_Player_car_loop
	MOVE.w	#$C7F5, (A6)
	ADDQ.w	#4, A6
	LEA	Depth_sort_buf.w, A0
	ADD.w	D2, D2
	ADDA.w	D2, A0
	MOVEQ	#0, D3
	MOVE.b	(A0)+, D0
	JSR	Write_digit_or_blank_tile(PC)
	MOVE.b	(A0), D0
	LSR.w	#4, D0
	JSR	Write_digit_or_blank_tile(PC)
	MOVEQ	#-1, D3
	MOVE.b	(A0)+, D0
	JSR	Write_digit_or_blank_tile(PC)
Build_minimap_standings_row_buffer_Rts:
	RTS
;Write_digit_or_blank_tile
Write_digit_or_blank_tile:
; Writes a digit tile or a blank tile to the scoreboard tilemap buffer (A6)+.
; If D0 low nibble == 0 and D3 == 0 (leading zero), writes 0 (blank).
; Otherwise writes $87C0 + D0 (digit tile) and sets D3 = $FFFF (seen non-zero).
; Inputs:  D0 = digit value (0-9), D3 = leading-zero flag (0 = suppress)
; Output:  (A6)+ = tile word; D3 updated
	ANDI.w	#$000F, D0
	BNE.b	Write_digit_or_blank_tile_Nonzero
	TST.w	D3
	BNE.b	Write_digit_or_blank_tile_Nonzero
	BRA.b	Write_digit_or_blank_tile_Write
Write_digit_or_blank_tile_Nonzero:
	MOVE.w	#$FFFF, D3
	ADDI.w	#$87C0, D0
Write_digit_or_blank_tile_Write:
	MOVE.w	D0, (A6)+
	RTS
;Sort_championship_standings
Sort_championship_standings:
	LEA	Depth_sort_buf.w, A6
	LEA	Driver_points_by_team.w, A5
	MOVEQ	#7, D7
	JSR	Copy_words_A5_to_A6(PC)
	LEA	Score_scratch_buf.w, A0
	MOVEQ	#0, D0
Sort_championship_standings_Init_loop:
	MOVE.b	D0, (A0,D0.w)
	ADDQ.w	#1, D0
	CMPI.w	#$0010, D0
	BNE.b	Sort_championship_standings_Init_loop
	MOVE.b	Player_team.w, D0
	ANDI.w	#$000F, D0
	MOVE.b	#$FF, (A0,D0.w)
	LEA	Standings_presort_flags_a.w, A0
	LEA	Standings_presort_flags_b.w, A1
	MOVEQ	#$0000000E, D0
Sort_championship_standings_Presort_loop:
	TST.b	(A1)
	BPL.b	Sort_championship_standings_Presort_next
	MOVE.b	(A1), D1
	MOVE.b	-$1(A1), (A1)
	MOVE.b	D1, -$1(A1)
	MOVE.b	(A0), D1
	MOVE.b	-$1(A0), (A0)
	MOVE.b	D1, -$1(A0)
Sort_championship_standings_Presort_next:
	SUBQ.w	#1, A0
	SUBQ.w	#1, A1
	DBF	D0, Sort_championship_standings_Presort_loop
	MOVEQ	#$0000000F, D0
Sort_championship_standings_Sort_loop:
	MOVEQ	#$0000000E, D1
	LEA	Depth_sort_buf.w, A1
	LEA	Score_scratch_buf.w, A2
Sort_championship_standings_Sort_inner:
	MOVE.b	(A1), D2
	CMP.b	$1(A1), D2
	BCC.b	Sort_championship_standings_Sort_inner_next
	MOVE.b	$1(A1), (A1)
	MOVE.b	D2, $1(A1)
	MOVE.b	(A2), D2
	MOVE.b	$1(A2), (A2)
	MOVE.b	D2, $1(A2)
Sort_championship_standings_Sort_inner_next:
	ADDQ.w	#1, A1
	ADDQ.w	#1, A2
	DBF	D1, Sort_championship_standings_Sort_inner
	DBF	D0, Sort_championship_standings_Sort_loop
	LEA	Depth_sort_buf.w, A0
	MOVE.b	(A0)+, D0
	LEA	Score_scratch_pts.w, A1
	MOVEQ	#0, D1
	MOVE.b	D1, (A1)+
	MOVEQ	#0, D2
	MOVEQ	#$0000000E, D7
Sort_championship_standings_Score_loop:
	ADDQ.w	#1, D2
	CMP.b	(A0)+, D0
	BEQ.b	Sort_championship_standings_Score_next
	MOVE.b	-$1(A0), D0
	MOVE.w	D2, D1
Sort_championship_standings_Score_next:
	MOVE.b	D1, (A1)+
	DBF	D7, Sort_championship_standings_Score_loop
	RTS
Championship_standings_display_setup:
	CLR.b	Title_menu_flags.w
	CLR.w	Title_menu_state.w
	LEA	Road_scale_table.w, A0
	MOVEQ	#$0000003B, D0
	MOVEQ	#$0000002F, D1
Championship_standings_display_setup_Scale_loop:
	MOVE.w	D1, (A0)+
	MOVE.w	D1, (A0)+
	SUBQ.w	#1, D1
	DBF	D0, Championship_standings_display_setup_Scale_loop
	LEA	Road_row_x_buf.w, A0
	MOVE.w	#$003F, D0
Championship_standings_display_setup_Buf1_loop:
	MOVE.w	#$8000, (A0)+
	DBF	D0, Championship_standings_display_setup_Buf1_loop
	LEA	Road_scanline_x_buf.w, A0
	MOVE.w	#$007F, D0
Championship_standings_display_setup_Buf2_loop:
	MOVE.w	#$FF80, (A0)+
	DBF	D0, Championship_standings_display_setup_Buf2_loop
	MOVE.w	#$FFFF, Ai_active_flag.w
	MOVE.l	#$00009E08, D1
	JSR	Alloc_aux_object_slot
	ADDQ.w	#4, Anim_delay.w
Championship_standings_display_setup_Rts:
	RTS
Championship_standings_text_16_races:
	dc.b	$10, $12, $FB, $43, $1D, $37, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $39, $FC, $3A, $32, $32, $17, $0E, $21, $1D, $32, $1B, $18, $1E
	dc.b	$17, $0D, $32, $3B, $FC, $3A, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $3B, $FC, $3A, $32, $32, $19, $0A, $1C, $1C, $20, $18, $1B, $0D
	dc.b	$32, $32, $32, $3B, $FC, $3C, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3E, $FF, $00
Championship_standings_text_final:
	dc.b	$10, $12, $FB, $43, $1D, $37, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $39, $FC, $3A, $32, $32, $17, $0E, $21, $1D, $32, $22, $0E, $0A, $1B
	dc.b	$32, $3B, $FC, $3A, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $3B, $FC, $3A, $32, $32, $19, $0A, $1C, $1C, $20, $18, $1B, $0D, $32, $32, $3B
	dc.b	$FC, $3C, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3E, $FF
Draw_championship_standings_text:
	LEA	Championship_standings_text_16_races, A6
	CMPI.w	#$0010, Track_index.w
	BNE.b	Draw_championship_standings_text_Draw
	LEA	Championship_standings_text_final, A6
Draw_championship_standings_text_Draw:
	ORI	#$0700, SR
	JSR	Draw_packed_tilemap_to_vdp
	ANDI	#$F8FF, SR
	RTS

Championship_standings_input:
	MOVE.b	Input_click_bitset.w, D0
	ANDI.b	#$F3, D0
	BEQ.b	Championship_standings_input_Rts
	MOVE.w	#Sfx_menu_confirm, Audio_sfx_cmd
	ANDI.b	#$F0, D0
	BNE.b	Championship_standings_input_Accept
	CLR.b	Screen_state_byte_0.w
	BSR.b	Draw_lap_counter_tiles
	ADDQ.b	#1, Temp_distance.w
	RTS
Championship_standings_input_Accept:
	CMPI.w	#$0010, Track_index.w
	BNE.b	Championship_standings_input_Accept_Next
	MOVE.l	#$00004FDC, Saved_frame_callback.w
Championship_standings_input_Accept_Next:
	MOVE.l	Saved_frame_callback.w, Frame_callback.w
	BTST.b	#0, Temp_distance.w
	BEQ.b	Championship_standings_input_Rts
	MOVE.l	#$0000F288, Frame_callback.w
Championship_standings_input_Rts:
	RTS
;Draw_lap_counter_tiles
Draw_lap_counter_tiles:
	MOVE.l	#$51160000, D7
	BTST.b	#0, Temp_distance.w
	BEQ.b	Draw_lap_counter_tiles_A
	MOVE.l	#$53160000, D7
Draw_lap_counter_tiles_A:
	MOVE.w	#$434F, D0
	BTST.b	#2, Screen_state_byte_0.w
	BEQ.b	Draw_lap_counter_tiles_B
	MOVE.w	#$434D, D0
Draw_lap_counter_tiles_B:
	ORI	#$0700, SR
	MOVE.l	D7, VDP_control_port
	MOVE.w	D0, VDP_data_port
	ANDI	#$F8FF, SR
	ADDQ.b	#1, Screen_state_byte_0.w
	BSR.w	Build_result_scroll_table
	RTS
;$0000CBEE
; Driver_standings_frame — per-frame handler for the scrolling championship standings
; screen (attract-mode cycle and post-championship display).
; Three sub-states dispatched by Screen_scroll index:
;   0 (scroll-in) — advances H-scroll by 2 rows every 2 frames, writing one new
;                   standings row per step from the standings text buffer.
;   1 (pause)     — counts down Temp_distance.
;   2 (exit)      — jumps to Pre_race_screen_championship_init.
; On START press at any sub-state → returns to Title_menu.
Driver_standings_frame:
	JSR	Wait_for_vblank
	ADDQ.w	#1, Screen_subcounter.w
	MOVE.w	Screen_subcounter.w, D0
	LSR.w	#1, D0
	ANDI.w	#1, D0
	SUBQ.w	#1, D0
	MOVE.l	#$40020010, VDP_control_port
	MOVE.w	D0, VDP_data_port
	BSR.b	Driver_standings_frame_Check_start
	LEA	Driver_standings_frame_dispatch_table, A1
	MOVE.w	Temp_x_pos.w, D0
	MOVEA.l	(A1,D0.w), A2
	JSR	(A2)
	JMP	Update_objects_and_build_sprite_buffer
Driver_standings_frame_dispatch_table:
	dc.l	Driver_standings_frame_Scroll
	dc.l	Driver_standings_frame_Pause
	dc.l	Driver_standings_frame_Exit
	dc.b	$4E, $75
Driver_standings_frame_Check_start:
	BTST.b	#KEY_START, Input_click_bitset.w
	BEQ.b	Driver_standings_frame_Check_start_Rts
	MOVE.w	#9, Selection_count.w
	MOVE.l	#Title_menu, Frame_callback.w
Driver_standings_frame_Check_start_Rts:
	RTS
Driver_standings_frame_Scroll:
	SUBQ.w	#1, Screen_data_ptr.w
	BNE.b	Driver_standings_frame_Scroll_Rts
	MOVE.w	#2, Screen_data_ptr.w
	ADDQ.w	#2, Screen_scroll.w
	CMPI.w	#$001A, Screen_scroll.w
	BEQ.b	Driver_standings_frame_Scroll_Done
	LEA	Driver_standings_hscroll_offsets, A1
	MOVE.w	Menu_cursor.w, D0
	MOVE.w	(A1,D0.w), D2
	LEA	(Palette_buffer+$20).w, A1
	MOVE.w	Screen_scroll.w, D0
	MOVE.w	D2, (A1,D0.w)
	RTS
Driver_standings_frame_Scroll_Done:
	LEA	Driver_standings_scroll_done_dispatch, A1
	SUBQ.w	#4, Screen_timer.w
	BCS.w	Driver_standings_frame_Next_state
	MOVE.w	Screen_timer.w, D0
	MOVE.l	(A1,D0.w), D1
	LEA	Driver_standings_aux_object_ptrs, A1
	MOVE.w	Menu_cursor.w, D0
	ADD.w	D0, D0
	MOVEA.l	(A1,D0.w), A2
	MOVE.l	D1, (A2)
	ADDQ.w	#2, Menu_cursor.w
	LEA	(Palette_buffer+$20).w, A1
	MOVE.w	#$000E, D0
Driver_standings_frame_Scroll_Done_loop:
	MOVE.w	#$0400, (A1)+
	DBF	D0, Driver_standings_frame_Scroll_Done_loop
	CLR.w	Screen_scroll.w
Driver_standings_frame_Scroll_Rts:
	RTS
Driver_standings_frame_Pause:
	SUBQ.w	#1, Temp_distance.w
	BEQ.b	Driver_standings_frame_Next_state
	RTS
Driver_standings_frame_Exit:
	MOVE.l	#Pre_race_screen_championship_init, Frame_callback.w
	RTS
Driver_standings_frame_Next_state:
	ADDQ.w	#4, Temp_x_pos.w
	RTS
;$0000CCE0
; Driver_standings_init — initialise the scrolling championship standings screen.
; Fades to black, inits H40 VDP, clears objects.
; Decompresses two standings tilemaps (from loc_CDD4 asset list) into VRAM.
; Sets up three sprite objects for the scrolling driver-name column.
; Draws the standings text list and palette strip.
; Arms a 26-row ($1A) H-scroll machine and installs Driver_standings_frame.
Driver_standings_init:
	JSR	Fade_palette_to_black
	JSR	Initialize_h40_vdp_state
	JSR	Clear_main_object_pool
	LEA	Driver_standings_tilemap_list(PC), A1
	JSR	Decompress_asset_list_to_vdp
	LEA	Driver_standings_decomp_records, A1
	MOVE.w	#3, D1
Driver_standings_init_Decomp_loop:
	MOVEM.w	D1, -(A7)
	MOVEA.l	(A1)+, A0
	MOVE.w	(A1)+, D0
	MOVE.l	(A1)+, D7
	MOVE.w	(A1)+, D6
	MOVE.w	(A1)+, D5
	MOVEM.l	A1, -(A7)
	JSR	Decompress_tilemap_to_vdp_64_cell_rows
	MOVEM.l	(A7)+, A1
	MOVEM.w	(A7)+, D1
	DBF	D1, Driver_standings_init_Decomp_loop
	LEA	Aux_object_pool.w, A1
	MOVE.w	#2, D0
Driver_standings_init_Objects_loop:
	MOVE.l	#Queue_object_for_sprite_buffer, (A1)
	MOVE.w	#$0158, $18(A1)
	MOVE.w	#$0110, $16(A1)
	MOVE.l	#Driver_standings_default_sprite, $4(A1)
	LEA	$40(A1), A1
	DBF	D0, Driver_standings_init_Objects_loop
	MOVE.l	#$00001032, Main_object_pool.w
	LEA	Driver_standings_packed_tilemap_list, A1
	JSR	Draw_packed_tilemap_list
	LEA	Driver_standings_palette_stream, A6
	JSR	Copy_word_run_from_stream
	LEA	(Palette_buffer+$20).w, A1
	MOVE.w	#$000E, D0
Driver_standings_init_Hscroll_loop:
	MOVE.w	#$0400, (A1)+
	DBF	D0, Driver_standings_init_Hscroll_loop
	MOVE.l	#$00000EEE, (Palette_buffer+$2).w
	MOVE.w	#$000A, Screen_data_ptr.w
	MOVE.w	#$0096, Temp_distance.w
	MOVE.w	#$0034, Screen_timer.w
	MOVE.l	#Driver_standings_frame, Frame_callback.w
	MOVE.l	#$000003D8, Vblank_callback.w
	JSR	Halt_audio_sequence
	ANDI	#$F8FF, SR
	JSR	Wait_for_vblank
	JSR	Wait_for_vblank
	MOVE.w	#1, Vblank_enable.w
	MOVE.w	#$8174, VDP_control_port
	RTS
Driver_standings_tilemap_list:
	dc.b	$00, $01
	dc.b	$00, $20
	dc.l	Driver_standings_tilemap_compressed_5
	dc.b	$2C, $E0
	dc.l	Driver_portrait_tiles_compressed
;$0000CDE2
; Team_select_frame — per-frame handler for the team (car) selection screen.
; Updates sprites and dispatches through a 5-state sub-machine ($FFFFFC1E index):
;   state 0 — animates driver portrait and car-stat tiles scrolling into view
;   state 1 — displays the team message panel
;   state 4 — reads player input:
;              if re-selecting after a championship race (bit 7 of Player_team set)
;                → restores Saved_frame_callback (back to championship sequence)
;              else → jumps to Arcade_race_init ($3800)
Team_select_frame:
	JSR	Wait_for_vblank
	JSR	Update_objects_and_build_sprite_buffer
	LEA	Team_select_dispatch_table, A1
	MOVE.w	Team_select_state.w, D0
	MOVEA.l	(A1,D0.w), A1
	JSR	(A1)
	RTS
Team_select_dispatch_table:
	dc.l	Team_select_phase0
	dc.l	Team_select_phase1
	dc.l	Team_select_phase2
	dc.l	Team_select_phase3
	dc.l	Team_select_phase4
Team_select_phase0:
	ANDI.b	#$F1, Screen_state_word_1.w
	CMPI.w	#5, Screen_item_count.w
	BEQ.w	Team_select_phase0_marker_a
	BSR.w	Advance_team_stat_display
	BSET.b	#1, Screen_state_word_1.w
Team_select_phase0_marker_a:
	CMPI.w	#4, Car_spec_marker_index.w
	BEQ.b	Team_select_phase0_marker_b
	BSR.w	Advance_road_marker_sequence_a
	BSET.b	#2, Screen_state_word_1.w
Team_select_phase0_marker_b:
	CMPI.w	#3, Driver_spec_marker_index.w
	BEQ.b	Team_select_phase0_check_done
	BSR.w	Advance_road_marker_sequence_b
	BSET.b	#3, Screen_state_word_1.w
Team_select_phase0_check_done:
	MOVE.b	Screen_state_word_1.w, D0
	ANDI.b	#$0E, D0
	BNE.b	Team_select_phase0_rts
	BTST.b	#7, Player_team.w
	BEQ.b	Team_select_phase0_no_rival
	ADDI.w	#$0010, Team_select_state.w
	RTS
Team_select_phase0_no_rival:
	BTST.b	#5, Player_team.w
	BEQ.b	Team_select_phase0_advance
Team_select_phase0_rival_loop:
	MOVE.b	Rival_team.w, D0
	ANDI.b	#$50, D0
	BEQ.b	Team_select_phase0_rival_done
	LEA	Team_message_tilemap_table, A1
	ADDA.l	#$00000010, A1
	BSR.w	Load_team_message_tiles
	CMPI.w	#4, Team_select_state.w
	BNE.b	Team_select_phase0_rival_loop
	SUBQ.w	#4, Team_select_state.w
Team_select_phase0_rival_done:
	ADDI.w	#$000C, Team_select_state.w
	RTS
Team_select_phase0_advance:
	ADDQ.w	#4, Team_select_state.w
Team_select_phase0_rts:
	RTS
Team_select_phase1:
	LEA	Team_message_tilemap_table, A1
Load_team_message_tiles:
	TST.w	English_flag.w
	BEQ.b	Load_team_message_tiles_team_a
	ADDA.l	#8, A1
Load_team_message_tiles_team_a:
	LEA	Drivers_and_teams_map.w, A2
	MOVE.b	Rival_team.w, D0
	ANDI.b	#$0F, D0 ; isolate the rival's team number
	MOVE.b	(A2,D0.w), D0
	ANDI.b	#$50, D0
	BNE.b	Load_team_message_tiles_copy
	ADDA.l	#4, A1
Load_team_message_tiles_copy:
	MOVEA.l	(A1), A2
	MOVE.w	(A2)+, Anim_delay.w
	MOVE.b	(A2)+, Screen_state_byte_1.w
	MOVE.b	(A2)+, Screen_state_byte_2.w
	LEA	Dialogue_tilemap_buf.w, A3
	MOVE.w	#$00E6, D0
Load_team_message_tiles_loop:
	CLR.w	D1
	MOVE.b	(A2)+, D1
	ADDI.w	#$431D, D1
	MOVE.w	D1, (A3)+
	DBF	D0, Load_team_message_tiles_loop
	CLR.l	D0
	LEA	Drivers_and_teams_map.w, A1
	MOVE.b	Rival_team.w, D0
	ANDI.b	#$0F, D0 ; isolate the rival's team number
	MOVE.b	(A1,D0.w), D1
	ANDI.b	#$50, D1
	BEQ.b	Load_team_message_tiles_scroll
	LEA	Team_message_result_text_jp, A1
	LEA	Dialogue_tilemap_buf.w, A2
	ADDA.l	#$0000008C, A2
	MOVE.w	#3, D1
	TST.w	English_flag.w
	BEQ.b	Load_team_message_tiles_jp_name
	LEA	Team_message_result_text_en, A1
	ADDA.l	#8, A2
	MOVE.w	#7, D1
Load_team_message_tiles_jp_name:
	BTST.b	#4, Rival_team.w
	BNE.b	Load_team_message_tiles_name_b
	ADDA.l	#4, A1
Load_team_message_tiles_name_b:
	MOVEA.l	(A1), A3
Load_team_message_tiles_name_loop:
	CLR.w	D0
	MOVE.b	(A3)+, D0
	ADDI.w	#$431D, D0
	MOVE.w	D0, (A2)+
	DBF	D1, Load_team_message_tiles_name_loop
Load_team_message_tiles_scroll:
	SUBQ.w	#1, Menu_cursor.w
	BCC.w	Load_team_message_tiles_rts
	CLR.w	Menu_cursor.w
	LEA	Dialogue_tilemap_buf.w, A6
	MOVE.w	Anim_delay.w, D7
	JSR	Tile_index_to_vdp_command
	CLR.w	D6
	MOVE.b	Screen_state_byte_1.w, D6
	MOVE.w	Menu_substate.w, D5
	ORI	#$0700, SR
	JSR	Draw_tilemap_buffer_to_vdp_64_cell_rows
	ANDI	#$F8FF, SR
	ADDQ.w	#1, Menu_substate.w
	CLR.w	D0
	MOVE.b	Screen_state_byte_2.w, D0
	CMP.w	Menu_substate.w, D0
	BNE.w	Load_team_message_tiles_rts
	ADDQ.w	#4, Team_select_state.w
Load_team_message_tiles_rts:
	RTS
Team_select_phase2:
	BSR.w	Load_rival_dialogue_pointer
	MOVE.b	Input_click_bitset.w, D0
	ANDI.b	#$FC, D0
	BEQ.w	Team_select_phase2_rts
	MOVE.w	#Sfx_menu_confirm, Audio_sfx_cmd
	ANDI.b	#$0C, D0
	BNE.w	Team_select_phase2_dn
	BTST.b	#KEY_B, Input_click_bitset.w
	BNE.w	Team_select_phase2_back
	BTST.b	#0, Menu_cursor_blink_state.w
	BNE.b	Team_select_phase2_back
	BSET.b	#2, Rival_dialogue_state.w
	BSR.w	Load_rival_dialogue_pointer
	ADDQ.w	#4, Team_select_state.w
	RTS
Team_select_phase2_back:
	MOVE.l	#$0000E94C, Frame_callback.w
	RTS
Team_select_phase2_dn:
	BCLR.b	#2, Rival_dialogue_state.w
	BSR.w	Load_rival_dialogue_pointer
	ADDQ.b	#1, Menu_cursor_blink_state.w
Team_select_phase2_rts:
	RTS
Team_select_phase3:
	MOVE.w	#$431D, Font_tile_base.w
	JSR	Load_font_tiles_to_work_buffer
	JSR	Select_team_message_before_race
	JSR	Render_text_to_tilemap
	MOVE.l	#$6A980003, D7
	JSR	Draw_message_panel_narrow
	ADDQ.w	#4, Team_select_state.w
	RTS
Team_select_phase4:
	MOVE.b	Input_click_bitset.w, D0
	ANDI.b	#$F0, D0
	BEQ.b	Team_select_phase4_rts
	BTST.b	#7, Player_team.w
	BEQ.b	Team_select_phase4_new
	BCLR.b	#7, Player_team.w
	MOVE.l	Saved_frame_callback.w, Frame_callback.w
	RTS
Team_select_phase4_new:
	BTST.b	#5, Player_team.w
	BNE.b	Team_select_phase4_go
	BCLR.b	#5, Player_team.w
	BSET.b	#4, Player_team.w
Team_select_phase4_go:
	MOVE.l	#$00003800, Frame_callback.w
Team_select_phase4_rts:
	RTS
Advance_team_stat_display:
	SUBQ.b	#1, Screen_tick.w
	BNE.w	Advance_team_stat_display_rts
	MOVE.b	#1, Screen_tick.w
	LEA	TeamMachineScreenStats, A1
	CLR.w	D0
	MOVE.b	Temp_distance.w, D0
	MULS.w	#7, D0
	ADDA.l	D0, A1
	MOVE.w	Screen_item_count.w, D0
	MOVE.b	(A1,D0.w), D1
	DIVS.w	#5, D1
	CMP.b	Screen_data_ptr.w, D1
	BEQ.b	Advance_team_stat_display_done
	MOVE.l	#$4D120003, D7
	MOVE.w	Screen_item_count.w, D0
Advance_team_stat_display_row_loop:
	ADDI.l	#$00060000, D7
	DBF	D0, Advance_team_stat_display_row_loop
	CLR.w	D0
	MOVE.b	Screen_data_ptr.w, D0
	LSR.w	#1, D0
Advance_team_stat_display_col_loop:
	ADDI.l	#$FF800000, D7
	DBF	D0, Advance_team_stat_display_col_loop
	MOVE.w	#$42C0, D0
	BTST.b	#0, Screen_data_ptr.w
	BNE.b	Advance_team_stat_display_write
	ADDQ.w	#1, D0
Advance_team_stat_display_write:
	ORI	#$0700, SR
	MOVE.l	D7, VDP_control_port
	MOVE.w	D0, VDP_data_port
	ADDI.w	#$0800, D0
	MOVE.w	D0, VDP_data_port
	ANDI	#$F8FF, SR
	ADDQ.b	#1, Screen_data_ptr.w
	RTS
Advance_team_stat_display_done:
	CLR.b	Screen_data_ptr.w
	ADDQ.w	#1, Screen_item_count.w
Advance_team_stat_display_rts:
	RTS
Advance_road_marker_sequence_a:
	SUBQ.b	#1, Car_spec_marker_delay.w
	BNE.b	Advance_road_marker_sequence_a_rts
	MOVE.b	#4, Car_spec_marker_delay.w
	MOVE.w	Car_spec_marker_step.w, D0
	CMP.w	Car_spec_marker_end.w, D0
	BEQ.b	Advance_road_marker_sequence_a_next
	MOVE.l	Car_spec_marker_vdp_cmd.w, D7
	MOVEA.l	Car_spec_marker_src_ptr.w, A1
	BSR.w	Step_road_marker_tile
	ADDQ.w	#1, Car_spec_marker_step.w
Advance_road_marker_sequence_a_rts:
	RTS
Advance_road_marker_sequence_a_next:
	LEA	Car_road_marker_vdp_cmds, A1
	MOVE.w	Car_spec_marker_index.w, D0
	LSL.w	#2, D0
	MOVE.l	(A1,D0.w), Car_spec_marker_vdp_cmd.w
	CLR.l	D0
	MOVE.b	Temp_distance.w, D0
	MULS.w	#$0012, D0
	LEA	Car_spec_text_table, A1
	ADDA.l	D0, A1
	MOVE.w	Car_spec_marker_index.w, D0
	MULS.w	#6, D0
	ADDA.l	D0, A1
	MOVE.l	(A1)+, Car_spec_marker_src_ptr.w
	MOVE.w	(A1)+, Car_spec_marker_end.w
	CLR.w	Car_spec_marker_step.w
	ADDQ.w	#1, Car_spec_marker_index.w
	RTS
Advance_road_marker_sequence_b:
; Advance the second road-marker animation sequence (throttled to every 6 frames).
; Decrements $FFFFB90E frame counter; when it reaches 0 resets it to 6 and
; calls Step_road_marker_tile to step the marker sprite at $FFFFB94E/$FFFFB952.
; When the sequence index ($FFFFB956) equals the end index ($FFFFB916),
; reloads the marker pointer from Driver_road_marker_vdp_cmds and the step table from Driver_info_table
; using Race_frame_counter as the sequence selector.
	SUBQ.b	#1, Driver_spec_marker_delay.w
	BNE.b	Advance_road_marker_sequence_b_rts
	MOVE.b	#6, Driver_spec_marker_delay.w
	MOVE.w	Driver_spec_marker_step.w, D0
	CMP.w	Driver_spec_marker_end.w, D0
	BEQ.b	Advance_road_marker_sequence_b_next
	MOVE.l	Driver_spec_marker_vdp_cmd.w, D7
	MOVEA.l	Driver_spec_marker_src_ptr.w, A1
	BSR.w	Step_road_marker_tile
	ADDQ.w	#1, Driver_spec_marker_step.w
Advance_road_marker_sequence_b_rts:
	RTS
Advance_road_marker_sequence_b_next:
	LEA	Driver_road_marker_vdp_cmds, A1
	MOVE.w	Driver_spec_marker_index.w, D0
	LSL.w	#2, D0
	MOVE.l	(A1,D0.w), Driver_spec_marker_vdp_cmd.w
	CLR.l	D0
	MOVE.b	Screen_state_byte_0.w, D0
	MULS.w	#$000C, D0
	LEA	Driver_info_table, A1
	ADDA.l	D0, A1
	MOVE.w	Driver_spec_marker_index.w, D0
	MULS.w	#6, D0
	ADDA.l	D0, A1
	MOVE.l	(A1)+, Driver_spec_marker_src_ptr.w
	MOVE.w	(A1)+, Driver_spec_marker_end.w
	CLR.w	Driver_spec_marker_step.w
	ADDQ.w	#1, Driver_spec_marker_index.w
	RTS
Step_road_marker_tile:
	ADDI.l	#$00020000, D7
	ADDA.l	#1, A1
	DBF	D0, Step_road_marker_tile
	CLR.w	D0
	MOVE.b	(A1), D0
	CMPI.b	#$FF, D0
	BNE.b	Step_road_marker_tile_done
	MOVE.w	#$F840, D0
Step_road_marker_tile_done:
	ADDI.w	#$47C0, D0
	ORI	#$0700, SR
	MOVE.l	D7, VDP_control_port
	MOVE.w	D0, VDP_data_port
	ANDI	#$F8FF, SR
	RTS

;Load_rival_dialogue_pointer
Load_rival_dialogue_pointer:
	LEA	Rival_dialogue_tile_index_table, A1
	TST.w	English_flag.w
	BEQ.b	Load_rival_dialogue_pointer_Jp
	ADDA.l	#8, A1
Load_rival_dialogue_pointer_Jp:
	BTST.b	#0, Menu_cursor_blink_state.w
	BEQ.b	Load_rival_dialogue_pointer_Player2
	ADDA.l	#2, A1
Load_rival_dialogue_pointer_Player2:
	CLR.l	D0
	LEA	Drivers_and_teams_map.w, A2
	MOVE.b	Rival_team.w, D0
	ANDI.b	#$0F, D0 ; isolate the rival's team number
	MOVE.b	(A2,D0.w), D0
	ANDI.b	#$50, D0
	BEQ.b	Load_rival_dialogue_pointer_Render
	ADDA.l	#4, A1
Load_rival_dialogue_pointer_Render:
	MOVE.w	(A1), D7
	JSR	Tile_index_to_vdp_command
	MOVE.w	#$434D, D0
	BTST.b	#2, Rival_dialogue_state.w
	BNE.b	Load_rival_dialogue_pointer_Open
	MOVE.w	#$434F, D0
Load_rival_dialogue_pointer_Open:
	ORI	#$0700, SR
	MOVE.l	D7, VDP_control_port
	MOVE.w	D0, VDP_data_port
	ANDI	#$F8FF, SR
	ADDQ.b	#1, Rival_dialogue_state.w
	RTS
	SUBQ.b	#1, Screen_digit.w
	BNE.b	Team_select_aux_object_Rts
	MOVE.b	#2, Screen_digit.w
	SUBQ.w	#1, Screen_subcounter.w
	BEQ.b	Team_select_aux_object_Done
	ADDQ.w	#1, (Aux_object_pool+$18).w
	MOVE.w	Screen_subcounter.w, D0
	ANDI.w	#$FFF8, D0
	LSR.w	#1, D0
	LEA	Car_width_vdp_cmd_table, A1
	MOVE.l	(A1,D0.w), D1
	MOVE.l	D1, (Aux_object_pool+$4).w
Team_select_aux_object_Rts:
	JMP	Queue_object_for_sprite_buffer
	dc.b	$4E, $75
Team_select_aux_object_Done:
	CLR.l	Aux_object_pool.w
	RTS
;Team_select_screen_init
; Team_select_screen_init — initialise the team / car selection screen.
; Fades to black, inits H40 VDP ($8238/$9011/$9280), clears objects.
; Conditionally branches on bit 7 of Player_team (re-select after championship race)
; to skip full reinitialisation of the championship state.
; Loads: shared title tileset, team-logo tiles, driver portrait tiles (from
;   DriverPortraitTiles table, index from $FFFFFC19), car-stat tiles, team name/flag
;   tiles, message panel, and scrolling palette strip.
; Renders current championship points, arms Team_select_frame as callback.
Team_select_screen_init:
	JSR	Fade_palette_to_black
	JSR	Initialize_h40_vdp_state
	JSR	Clear_main_object_pool
	MOVE.w	#$8238, VDP_control_port
	MOVE.w	#$9011, VDP_control_port
	MOVE.w	#$9280, VDP_control_port
	BTST.b	#7, Player_team.w
	BEQ.b	Team_select_screen_init_New_team
	MOVE.b	Player_team.w, D0
	ANDI.b	#$0F, D0 ; isolate the player's team number
	MOVE.b	D0, Temp_distance.w
	MOVE.b	#$10, Screen_state_byte_0.w
	BRA.b	Team_select_screen_init_Setup
Team_select_screen_init_New_team:
	CLR.l	D0
	LEA	Drivers_and_teams_map.w, A1
	MOVE.b	Rival_team.w, D0
	ANDI.b	#$0F, D0 ; isolate the rival's team number
	MOVE.b	D0, Temp_distance.w
	MOVE.b	(A1,D0.w), D1
	ANDI.b	#$0F, D1
	MOVE.b	D1, Screen_state_byte_0.w
	BTST.b	#6, Player_team.w
	BEQ.b	Team_select_screen_init_Setup
	SUBQ.b	#1, Screen_state_byte_0.w
Team_select_screen_init_Setup:
	MOVE.l	#$63A00001, VDP_control_port
	LEA	Race_common_tiles, A0
	JSR	Decompress_to_vdp
	MOVE.l	#$6B800001, VDP_control_port
	LEA	Podium_car_tiles, A0
	JSR	Decompress_to_vdp
	LEA	Car_stats_deco_tiles, A0
	MOVE.l	#$50000000, VDP_control_port
	JSR	Decompress_to_vdp
	CLR.l	D0
	LEA	DriverPortraitTiles, A1
	MOVE.b	Screen_state_byte_0.w, D0
	LSL.l	#2, D0
	MOVEA.l	(A1,D0.w), A0
	MOVE.l	#$40200000, VDP_control_port
	JSR	Decompress_to_vdp
	CLR.l	D0
	LEA	Car_stat_tiles_table, A1
	LEA	TeamMachineScreenStats, A2
	CLR.l	D0
	MOVE.b	Temp_distance.w, D0
	MULS.w	#7, D0
	CLR.l	D1
	MOVE.b	$5(A2,D0.w), D1
	LSL.l	#2, D1
	MOVEA.l	(A1,D1.w), A0
	MOVE.l	#$48200000, VDP_control_port
	JSR	Decompress_to_vdp
	MOVE.l	#$7A000001, VDP_control_port
	LEA	Race_hud_tiles, A0
	JSR	Decompress_to_vdp
	CLR.l	D0
	LEA	DriverPortraitTileMappings, A1
	MOVE.b	Screen_state_byte_0.w, D0
	LSL.l	#2, D0
	MOVEA.l	(A1,D0.w), A0
	MOVE.w	#1, D0
	MOVE.l	#$49040003, D7
	MOVE.w	#7, D6
	MOVE.w	#7, D5
	JSR	Decompress_tilemap_to_vdp_64_cell_rows
	LEA	Car_stat_row_tilemap_table, A1
	LEA	TeamMachineScreenStats, A2
	CLR.w	D0
	MOVE.b	Temp_distance.w, D0
	MULS.w	#7, D0
	CLR.l	D1
	MOVE.b	$5(A2,D0.w), D1
	LSL.l	#2, D1
	MOVEA.l	(A1,D1.w), A0
	MOVE.w	#$4041, D0
	MOVE.l	#$47360003, D7
	MOVE.w	#$000A, D6
	MOVE.w	#$000C, D5
	JSR	Decompress_tilemap_to_vdp_64_cell_rows
	LEA	Car_stats_bar_tilemap, A0
	MOVE.w	#$4080, D0
	MOVE.l	#$4D160003, D7
	MOVE.w	#$000F, D6
	MOVE.w	#0, D5
	JSR	Decompress_tilemap_to_vdp_64_cell_rows
	LEA	Car_stats_screen_tilemap_list, A1
	JSR	Draw_packed_tilemap_list
	LEA	Team_select_scrollbar_tilemap, A0
	MOVE.w	#$6080, D0
	JSR	Decompress_tilemap_to_buffer
	CLR.l	D0
	CLR.l	D1
	LEA	Drivers_and_teams_map.w, A1
	MOVE.b	Rival_team.w, D0
	BTST.b	#7, Player_team.w
	BEQ.b	Team_select_screen_init_Show_rival
	MOVE.b	Player_team.w, D0
Team_select_screen_init_Show_rival:
	ANDI.b	#$0F, D0 ; isolate the player's team number
	LEA	Driver_points_by_team.w, A1
	MOVE.b	(A1,D0.w), D0
	JSR	Binary_to_decimal
	MOVE.w	D1, D0
	MOVE.w	#4, D1
	MOVE.w	#$47C0, D4
	MOVE.w	#$EC34, D7
	LEA	VDP_data_port, A5
	JSR	Render_packed_digits_to_vdp
	CLR.l	D0
	LEA	Team_name_tilemap_table, A1
	MOVE.b	Temp_distance.w, D0
	LSL.b	#2, D0
	MOVEA.l	(A1,D0.w), A6
	JSR	Draw_packed_tilemap_to_vdp
	CLR.l	D0
	MOVE.b	Screen_state_byte_0.w, D0
	LSL.l	#5, D0
	LEA	Driver_portrait_palette_streams, A6
	ADDA.l	D0, A6
	JSR	Copy_word_run_from_stream
	BTST.b	#7, Player_team.w
	BEQ.b	Team_select_screen_init_Scrollbar
	CLR.l	D0
	LEA	Team_select_camera_scroll_data, A1
	MOVE.b	Player_team.w, D0
	ANDI.b	#$0F, D0 ; isolate the player's team number
	LSL.l	#3, D0
	ADDA.l	D0, A1
	MOVE.w	(A1)+, (Palette_buffer+$10).w
	MOVE.w	(A1)+, (Palette_buffer+$12).w
	MOVE.w	(A1)+, (Palette_buffer+$14).w
	MOVE.w	(A1)+, (Palette_buffer+$1C).w
Team_select_screen_init_Scrollbar:
	LEA	Car_select_bg_vdp_stream, A6
	JSR	Copy_word_run_from_stream
	CLR.l	D0
	MOVE.b	Temp_distance.w, D0
	MULS.w	#$0038, D0
	ADDI.w	#$000A, D0
	LEA	Team_palette_data, A1
	ADDA.l	D0, A1
	LEA	(Palette_buffer+$6C).w, A2
	MOVE.w	#3, D0
Team_select_screen_init_Palette_loop:
	MOVE.w	(A1)+, (A2)+
	DBF	D0, Team_select_screen_init_Palette_loop
	MOVE.l	#$0000D274, Aux_object_pool.w
	MOVE.w	#$0170, (Aux_object_pool+$18).w
	MOVE.w	#$0128, (Aux_object_pool+$16).w
	MOVE.w	#1, (Aux_object_pool+$E).w
	MOVE.l	#$0002025A, (Aux_object_pool+$4).w
	MOVE.b	#5, Screen_digit.w
	MOVE.b	#5, Screen_tick.w
	MOVE.b	#5, Car_spec_marker_delay.w
	MOVE.b	#5, Driver_spec_marker_delay.w
	MOVE.b	#5, Screen_timer.w
	MOVE.b	#5, Screen_flash_state.w
	MOVE.w	#$0038, Screen_subcounter.w
	MOVE.w	#$0096, Temp_x_pos.w
	MOVE.l	#Team_select_frame, Frame_callback.w
	MOVE.l	#$0000D5B6, Vblank_callback.w
	ANDI	#$F8FF, SR
	JSR	Wait_for_vblank
	MOVE.w	#1, Vblank_enable.w
	MOVE.w	#$8174, VDP_control_port
	RTS
;$0000D5B6
Team_select_vblank_handler:
	JSR	Upload_h40_tilemap_buffer_to_vram
	JSR	Update_input_bitset
	JSR	Upload_palette_buffer_to_cram
	SUBQ.b	#1, Screen_timer.w
	BNE.b	Team_select_vblank_handler_Flash
	MOVE.b	#7, Screen_timer.w
	ADDI.l	#$00000114, Screen_scroll.w
	CMPI.l	#$00000CF0, Screen_scroll.w
	BNE.b	Team_select_vblank_handler_Scroll_wrap
	CLR.l	Screen_scroll.w
Team_select_vblank_handler_Scroll_wrap:
	MOVE.l	Screen_scroll.w, D0
	LEA	Tilemap_work_buf.w, A6
	ADDA.l	D0, A6
	MOVE.l	#$43060003, D7
	MOVEQ	#$00000016, D6
	MOVEQ	#5, D5
	JSR	Draw_tilemap_buffer_to_vdp_64_cell_rows
Team_select_vblank_handler_Flash:
	CMPI.b	#$10, Screen_state_byte_0.w
	BNE.b	Team_select_vblank_handler_Rts
	MOVE.w	#$0016, D0
	SUBQ.b	#1, Screen_flash_state.w
	BTST.b	#4, Screen_flash_state.w
	BEQ.b	Team_select_vblank_handler_Flash_dim
	MOVE.w	#$0035, D0
Team_select_vblank_handler_Flash_dim:
	MOVE.l	#$4A8C0003, VDP_control_port
	MOVE.w	D0, VDP_data_port
Team_select_vblank_handler_Rts:
	RTS
Team_select_camera_scroll_data:
	dc.w	$000A, $00AC, $044E, $0006
	dc.b	$00, $0A, $00, $08, $04, $2E, $00, $06, $00, $AC, $0C, $22, $04, $CE, $00, $68, $00, $AC, $02, $60, $04, $CE, $00, $68, $0A, $22, $00, $AC, $0E, $66, $08, $02
	dc.b	$0A, $AA, $08, $02, $0C, $CC, $06, $66, $00, $AE, $00, $8C, $02, $CE, $00, $6A, $0C, $C0, $0A, $A6, $0C, $C8, $0A, $60, $0A, $A4, $0C, $20, $0C, $C8, $06, $60
	dc.b	$00, $2C, $0A, $AA, $02, $8E, $00, $06, $0A, $22, $00, $A2, $0E, $66, $08, $02
	dc.w	$00AC, $0AAA, $04CE, $0068
	dc.b	$02, $A0, $02, $AC, $08, $E6, $02, $60, $06, $88, $0A, $AA, $08, $AA, $04, $66, $04, $44, $02, $AC, $08, $88, $02, $22, $00, $4E, $0C, $CC, $04, $8E, $00, $28
;$0000D6B2
Game_over_frame:
	JSR	Wait_for_vblank
	JSR	Update_objects_and_build_sprite_buffer
	BSR.b	Game_over_check_input
	SUBQ.w	#1, Screen_timer.w
	BEQ.b	Game_over_set_title
	RTS
Game_over_check_input:
	MOVE.b	Input_click_bitset.w, D0
	ANDI.b	#$F0, D0
	BEQ.b	Game_over_check_input_Rts
Game_over_set_title:
	MOVE.w	#2, Title_menu_state.w
	MOVE.l	#Title_menu, Frame_callback.w
Game_over_check_input_Rts:
	RTS
;Championship_standings_init
; Championship_standings_init — initialise the end-of-season championship standings
; overlay screen (shown after the final race).
; Fades to black, inits H40 VDP, clears objects.
; Clears Player_state_flags bits 0 and 1 (crash/spin flags).
; Decompresses the championship-final standings tilemaps.
; Loads team, driver, and points data into the standings display buffer.
; Installs Championship_team_select_frame as the per-frame callback.
Championship_standings_init:
	JSR	Fade_palette_to_black
	JSR	Initialize_h40_vdp_state
	JSR	Clear_main_object_pool
	BCLR.b	#0, Player_state_flags.w
	BCLR.b	#1, Player_state_flags.w
	MOVE.w	#$8238, VDP_control_port
	MOVE.w	#$8338, VDP_control_port
	MOVE.w	#$9011, VDP_control_port
	MOVE.w	#$9280, VDP_control_port
	MOVE.b	Rival_team.w, D0
	ANDI.b	#$A0, D0
	BEQ.w	Championship_standings_init_Load_assets
	BTST.b	#7, Rival_team.w
	BEQ.w	Championship_standings_init_Swap_simple
	MOVE.b	Player_team.w, D0
	MOVE.b	Rival_team.w, D1
	ANDI.b	#$0F, D0 ; isolate the player's team number
	ANDI.b	#$0F, D1 ; isolate the rival's team number
	CMP.b	D0, D1
	BCS.w	Championship_standings_init_Swap_simple
	CLR.l	D0
	CLR.l	D1
	CLR.l	D2
	LEA	Driver_points_by_team.w, A1
	MOVE.b	Player_team.w, D0
	MOVE.b	Rival_team.w, D1
	MOVE.b	D1, D2
	ADDQ.b	#1, D2
	ANDI.b	#$0F, D0 ; isolate the player's team number
	ANDI.b	#$0F, D1 ; isolate the rival's team number
	ANDI.b	#$0F, D2 ; isolate rival's team number + 1
	MOVE.b	(A1,D0.w), D3
	MOVE.b	(A1,D1.w), D4
	MOVE.b	(A1,D2.w), D5
	MOVE.b	D4, (A1,D0.w)
	MOVE.b	D5, (A1,D1.w)
	MOVE.b	D3, (A1,D2.w)
	CLR.l	D0
	CLR.l	D1
	LEA	Drivers_and_teams_map.w, A1
	LEA	Promoted_teams_bitfield.w, A2
	MOVE.b	Player_team.w, D0
	MOVE.b	Rival_team.w, D1
	ANDI.b	#$0F, D0 ; isolate the player's team number
	ANDI.b	#$0F, D1 ; isolate the rival's team number
	MOVE.w	(A2), D4
	BSET.l	D0, D4
	MOVE.w	D4, (A2)
	MOVE.b	(A1,D1.w), D2
	MOVE.b	D2, (A1,D0.w)
	MOVE.b	D1, D3
Championship_standings_init_Find_slot:
	ADDQ.b	#1, D3
	BTST.l	D3, D4
	BNE.b	Championship_standings_init_Find_slot
	MOVE.b	(A1,D3.w), D4
	MOVE.b	D4, (A1,D1.w)
	ANDI.b	#$40, Player_team.w
	ADD.b	D3, Player_team.w
	CLR.b	(A1,D3.w)
	BRA.b	Championship_standings_init_Swap_done
Championship_standings_init_Swap_simple:
	CLR.l	D0
	CLR.l	D1
	LEA	Driver_points_by_team.w, A1
	MOVE.b	Player_team.w, D0
	MOVE.b	Rival_team.w, D1
	ANDI.b	#$0F, D0 ; isolate the player's team number
	ANDI.b	#$0F, D1 ; isolate the rival's team number
	MOVE.b	(A1,D0.w), D2
	MOVE.b	(A1,D1.w), D3
	MOVE.b	D3, (A1,D0.w)
	MOVE.b	D2, (A1,D1.w)
	CLR.l	D0
	CLR.l	D1
	LEA	Drivers_and_teams_map.w, A1
	MOVE.b	Player_team.w, D0
	MOVE.b	Rival_team.w, D1
	ANDI.b	#$0F, D0 ; isolate the player's team number
	ANDI.b	#$0F, D1 ; isolate the rival's team number
	MOVE.b	(A1,D1.w), D2
	MOVE.b	D2, (A1,D0.w)
	ANDI.b	#$40, Player_team.w
	ADD.b	D1, Player_team.w
	CLR.b	(A1,D1.w)
Championship_standings_init_Swap_done:
	MOVE.w	#$FFFF, D0
	MOVE.b	#$0C, D1
	BTST.b	#6, Player_team.w
	BEQ.b	Championship_standings_init_Player_slot
	ADDQ.b	#1, D1
Championship_standings_init_Player_slot:
	LEA	Drivers_and_teams_map.w, A1
	LEA	Driver_points_by_team.w, A2
Championship_standings_init_Player_slot_loop:
	ADDQ.w	#1, D0
	CMP.b	(A1,D0.w), D1
	BNE.b	Championship_standings_init_Player_slot_loop
	MOVE.b	D0, D7
	MOVE.b	Player_team.w, D1
	ANDI.b	#$0F, D1 ; isolate the player's team number
	CMP.b	D0, D1
	BCC.b	Championship_standings_init_Player_ok
	SUB.b	D1, D0
	CMPI.b	#1, D0
	BEQ.b	Championship_standings_init_Player_ok
	MOVE.b	-$1(A1,D7.w), D0
	MOVE.b	(A1,D7.w), D1
	MOVE.b	D1, -$1(A1,D7.w)
	MOVE.b	D0, (A1,D7.w)
	MOVE.b	-$1(A2,D7.w), D0
	MOVE.b	(A2,D7.w), D1
	MOVE.b	D1, -$1(A2,D7.w)
	MOVE.b	D0, (A2,D7.w)
Championship_standings_init_Player_ok:
	BCLR.b	#5, Player_team.w
	BSET.b	#4, Player_team.w
	CLR.b	Rival_team.w
	LEA	Drivers_and_teams_map.w, A1
	MOVE.w	#$000F, D0
Championship_standings_init_Strip_upper_loop:
	MOVE.b	(A1), D1
	ANDI.b	#$0F, D1
	MOVE.b	D1, (A1)+
	DBF	D0, Championship_standings_init_Strip_upper_loop
Championship_standings_init_Load_assets:
	MOVE.l	#$40200000, VDP_control_port
	LEA	Championship_standings_compressed_tilemap, A0
	JSR	Decompress_to_vdp
	MOVE.l	#$63A00001, VDP_control_port
	LEA	Race_common_tiles, A0
	JSR	Decompress_to_vdp
	MOVE.l	#$6B800001, VDP_control_port
	LEA	Podium_car_tiles, A0
	JSR	Decompress_to_vdp
	MOVE.l	#$7A000001, VDP_control_port
	LEA	Race_hud_tiles, A0
	JSR	Decompress_to_vdp
	LEA	Championship_standings_tilemap_descriptors, A1
	MOVE.w	#2, D1
Championship_standings_init_Tilemaps_loop:
	MOVEM.w	D1, -(A7)
	MOVEA.l	(A1)+, A0
	MOVE.w	(A1)+, D0
	MOVE.l	(A1)+, D7
	MOVE.w	(A1)+, D6
	MOVE.w	(A1)+, D5
	MOVEM.l	A1, -(A7)
	JSR	Decompress_tilemap_to_vdp_64_cell_rows
	MOVEM.l	(A7)+, A1
	MOVEM.w	(A7)+, D1
	DBF	D1, Championship_standings_init_Tilemaps_loop
	CLR.l	D0
	MOVE.b	Player_team.w, D0
	ANDI.b	#$0F, D0 ; isolate the player's team number
	LSL.w	#2, D0
	LEA	Team_intro_layout_table, A1
	ADDA.l	D0, A1
	MOVEA.l	(A1), A2
	MOVE.w	(A2)+, D1
Championship_standings_init_Intro_loop:
	MOVEM.w	D1, -(A7)
	MOVEA.l	(A2)+, A0
	MOVE.w	(A2)+, D0
	MOVE.l	(A2)+, D7
	MOVE.w	(A2)+, D6
	MOVE.w	(A2)+, D5
	MOVEM.l	A2, -(A7)
	JSR	Decompress_tilemap_to_vdp_64_cell_rows
	MOVEM.l	(A7)+, A2
	MOVEM.w	(A7)+, D1
	DBF	D1, Championship_standings_init_Intro_loop
	CLR.l	D0
	LEA	Team_name_tilemap_table, A1
	MOVE.b	Player_team.w, D0
	ANDI.b	#$0F, D0 ; isolate the player's team number
	LSL.b	#2, D0
	MOVEA.l	(A1,D0.w), A6
	JSR	Draw_packed_tilemap_to_vdp
	MOVE.w	#$431D, Font_tile_base.w
	JSR	Load_font_tiles_to_work_buffer
	JSR	Select_team_intro_text
	JSR	Render_text_to_tilemap
	MOVE.l	#$62920003, D7
	JSR	Draw_message_panel_narrow
	LEA	Team_intro_vdp_word_run, A6
	JSR	Copy_word_run_from_stream
	CLR.l	D0
	MOVE.b	Player_team.w, D0
	ANDI.b	#$0F, D0 ; isolate the player's team number
	MULS.w	#$0038, D0
	LEA	Team_palette_data, A2
	ADDA.l	D0, A2
	LEA	Palette_buffer.w, A1
	MOVE.w	(A2)+, $6(A1)
	MOVE.l	(A2)+, $A(A1)
	MOVE.l	(A2)+, $E(A1)
	MOVE.l	(A2)+, $2C(A1)
	MOVE.l	(A2)+, $30(A1)
	MOVE.l	(A2)+, $50(A1)
	MOVE.l	(A2)+, $54(A1)
	MOVE.l	(A2)+, $58(A1)
	MOVE.w	(A2)+, $5C(A1)
	MOVE.l	(A2)+, $68(A1)
	MOVE.l	(A2)+, $6C(A1)
	MOVE.l	(A2)+, $70(A1)
	MOVE.l	(A2)+, $74(A1)
	MOVE.l	(A2)+, $78(A1)
	MOVE.l	(A2)+, $7C(A1)
	MOVE.l	#Game_over_frame, Frame_callback.w
	MOVE.l	#$000003D8, Vblank_callback.w
	MOVE.w	Selection_count.w, Audio_music_cmd ; song selection (game over path)
	CLR.w	Selection_count.w
	ANDI	#$F8FF, SR
	JSR	Wait_for_vblank
	MOVE.w	#1, Vblank_enable.w
	MOVE.w	#$8174, VDP_control_port
	RTS
;$0000DA3C
Game_over_confirm_frame:
	JSR	Wait_for_vblank
	MOVE.b	Input_click_bitset.w, D0
	ANDI.w	#$00F0, D0
	BNE.b	Game_over_confirm_frame_Exit
	SUBQ.w	#1, Screen_timer.w
	BNE.b	Game_over_confirm_frame_Rts
Game_over_confirm_frame_Exit:
	MOVE.l	#$0000DF2A, Frame_callback.w
Game_over_confirm_frame_Rts:
	RTS
	JSR	Fade_palette_to_black
	JSR	Initialize_h40_vdp_state
	MOVE.l	#$40200000, VDP_control_port
	LEA	Game_over_tiles, A0
	JSR	Decompress_to_vdp
	LEA	Game_over_tilemap, A0
	MOVE.w	#$6001, D0
	MOVE.l	#$41280003, D7
	MOVEQ	#$00000010, D6
	MOVEQ	#$00000017, D5
	JSR	Decompress_tilemap_to_vdp_64_cell_rows
	LEA	Game_over_screen_asset_list(PC), A1
	JSR	Draw_packed_tilemap_list
	LEA	Game_over_palette_stream, A6
	JSR	Copy_word_run_from_stream
	MOVE.w	#$021C, Screen_timer.w
	MOVE.l	#Game_over_confirm_frame, Frame_callback.w
	MOVE.l	#$000003D8, Vblank_callback.w
	JSR	Halt_audio_sequence
	ANDI	#$F8FF, SR
	JSR	Wait_for_vblank
	JSR	Wait_for_vblank
	MOVE.w	#Music_game_over, Audio_music_cmd   ; game over screen music
	MOVE.w	#1, Vblank_enable.w
	MOVE.w	#$8174, VDP_control_port
	RTS
	include "src/endgame_game_over_data.asm"
;$0000DB30
Credits_scroll_frame:
	JSR	Wait_for_vblank
	BSR.b	Credits_scroll_update
	JSR	Update_objects_and_build_sprite_buffer
	BSR.b	Credits_scroll_check_input
	RTS
Credits_scroll_check_input:
	MOVE.b	Input_click_bitset.w, D0
	ANDI.w	#$00F0, D0
	BNE.b	Credits_scroll_exit
	RTS
Credits_scroll_exit:
	MOVE.l	Saved_frame_callback.w, Frame_callback.w
	RTS
Credits_scroll_update:
	LEA	Race_finish_buffer_ptr_table, A1
	MOVE.w	Screen_subcounter.w, D0
	ADD.w	D0, D0
	MOVEA.l	(A1,D0.w), A6
	MOVE.l	#$668A0003, D7
	MOVEQ	#$0000000C, D6
	MOVEQ	#$0000000C, D5
	JSR	Draw_tilemap_buffer_to_vdp_64_cell_rows
	SUBQ.w	#1, Screen_timer.w
	BEQ.b	Credits_scroll_exit
	SUBQ.w	#1, Screen_scroll.w
	BNE.b	Credits_scroll_update_Rts
	MOVE.w	#$000F, Screen_scroll.w
	ADDQ.w	#2, Screen_subcounter.w
	ANDI.w	#6, Screen_subcounter.w
	LEA	Credits_scroll_wiggle_offsets, A1
	MOVE.w	Screen_subcounter.w, D0
	MOVE.w	(A1,D0.w), D1
	LEA	(Aux_object_pool+$40).w, A2
	MOVE.w	#2, D0
Credits_scroll_wiggle_loop:
	ADD.w	D1, $16(A2)
	ADDA.w	#$0040, A2
	DBF	D0, Credits_scroll_wiggle_loop
Credits_scroll_update_Rts:
	RTS
Credits_scroll_wiggle_offsets:
	dc.w	6, -6, -2, 2
Race_finish_credits_init:
	JSR	Fade_palette_to_black
	JSR	Halt_audio_sequence
	JSR	Initialize_h40_vdp_state
	JSR	Clear_main_object_pool
	MOVE.w	Player_grid_position.w, Qualifying_temp_grid.w
	MOVE.l	Rival_race_time_bcd.w, Qualifying_temp_rival_time.w
	JSR	Accumulate_bcd_race_time(PC)
	TST.w	Player_overtaken_flag.w
	BEQ.b	Race_finish_credits_init_Assets
	CLR.w	Race_time_bcd.w
	CLR.w	Player_overtaken_flag.w
Race_finish_credits_init_Assets:
	LEA	Race_finish_asset_list(PC), A1
	JSR	Decompress_asset_list_to_vdp
	LEA	Race_finish_layout_tilemap, A0
	MOVE.w	#$2001, D0
	MOVE.l	#$41060003, D7
	MOVEQ	#$00000010, D6
	MOVEQ	#$00000017, D5
	JSR	Decompress_tilemap_to_vdp_64_cell_rows
	MOVE.w	#$C001, D0
	LEA	Race_finish_buf_tilemap_3, A0
	JSR	Decompress_tilemap_to_buffer
	LEA	(Tilemap_work_buf+$2A4).w, A5
	JSR	Copy_ea00_block_to_a5(PC)
	LEA	Race_finish_buf_tilemap_2, A0
	JSR	Decompress_tilemap_to_buffer
	LEA	(Tilemap_work_buf+$152).w, A5
	JSR	Copy_ea00_block_to_a5(PC)
	LEA	(Tilemap_work_buf+$3F6).w, A5
	JSR	Copy_ea00_block_to_a5(PC)
	LEA	Race_finish_buf_tilemap_1, A0
	JSR	Decompress_tilemap_to_buffer
	MOVE.w	#3, D0
	LEA	Aux_object_pool.w, A1
	LEA	Race_finish_object_init_data, A2
Race_finish_credits_init_Objects_loop:
	MOVE.l	#Queue_object_for_sprite_buffer, (A1)
	MOVE.w	(A2)+, $18(A1)
	MOVE.w	(A2)+, $16(A1)
	MOVE.l	(A2)+, $4(A1)
	LEA	$40(A1), A1
	DBF	D0, Race_finish_credits_init_Objects_loop
	LEA	Race_finish_tilemap_list(PC), A1
	JSR	Draw_packed_tilemap_list
	MOVE.w	#$E232, Screen_timer.w
	MOVE.w	#$E33E, Screen_scroll.w
	JSR	Draw_car_selection_screen
	LEA	Race_finish_lap_time_ptrs(PC), A3
	LEA	Race_finish_tile_attr_data(PC), A4
	MOVE.w	#4, Screen_timer.w
	JSR	Draw_car_stat_rows
	MOVE.w	#$EC3A, Screen_timer.w
	JSR	Draw_bcd_value_display
	MOVE.w	Easy_flag.w, D0
	OR.w	Qualifying_temp_grid.w, D0
	BNE.b	Race_finish_credits_init_Normal
	CMPI.w	#2, Saved_shift_type_2.w
	BNE.b	Race_finish_credits_init_Normal
	CMPI.w	#$3500, Race_time_bcd.w
	BCS.b	Race_finish_credits_init_Normal
	MOVE.l	#$0000DA5C, D0
	BRA.b	Race_finish_credits_init_Set_callback
Race_finish_credits_init_Normal:
	MOVE.l	#$0000DF2A, D0
	CMPI.w	#2, Player_grid_position.w
	BLS.b	Race_finish_credits_init_Set_callback
	MOVE.l	#$00004976, D0
Race_finish_credits_init_Set_callback:
	MOVE.l	D0, Saved_frame_callback.w
	LEA	Race_finish_palette_stream, A6
	JSR	Copy_word_run_from_stream
	MOVE.w	#1, Screen_scroll.w
	MOVE.w	#$0168, Screen_timer.w
	MOVE.l	#Credits_scroll_frame, Frame_callback.w
	MOVE.l	#$000003D8, Vblank_callback.w
	ANDI	#$F8FF, SR
	JSR	Wait_for_vblank
	JSR	Wait_for_vblank
	MOVE.w	#Music_credits, Audio_music_cmd     ; credits scroll music
	MOVE.w	#1, Vblank_enable.w
	MOVE.w	#$8174, VDP_control_port
	CMPI.b	#$70, Input_state_bitset.w ; Keys A+B+C
	BEQ.b	Race_finish_credits_init_Quick_skip
	RTS
Race_finish_credits_init_Quick_skip:
	LEA	Aux_object_pool.w, A1
	LEA	(Aux_object_pool+$C0).w, A2
	ADDI.w	#$FFD8, (Aux_object_pool+$16).w
	ADDQ.w	#3, (Aux_object_pool+$18).w
	MOVE.w	#$003F, D0
Race_finish_credits_init_Quick_skip_loop:
	MOVE.b	(A1)+, (A2)+
	DBF	D0, Race_finish_credits_init_Quick_skip_loop
	CLR.l	Aux_object_pool.w
	RTS
;Copy_ea00_block_to_a5
Copy_ea00_block_to_a5:
	LEA	Tilemap_work_buf.w, A6
	MOVE.w	#$00A8, D1
Copy_ea00_block_to_a5_loop:
	MOVE.w	(A6)+, (A5)+
	DBF	D1, Copy_ea00_block_to_a5_loop
	RTS
;Accumulate_bcd_race_time
Accumulate_bcd_race_time:
	MOVEQ	#0, D0
	MOVEQ	#0, D1
	MOVE.b	(Rival_race_time_bcd+2).w, D0
	MOVEQ	#$00000060, D2
	MOVE.b	(Rival_race_time_bcd+1).w, D1
	SUBQ.w	#1, D1
	BSR.b	Bcd_add_loop
	MOVE.w	#$0190, D2
	ADDI.w	#0, D0
	SBCD	D0, D2
	ROR.w	#8, D0
	ROR.w	#8, D2
	SBCD	D0, D2
	ROR.w	#8, D0
	ROR.w	#8, D2
	BCS.b	Accumulate_bcd_race_time_Rts
	MOVE.w	Race_time_bcd.w, D0
	MOVEQ	#9, D1
	BSR.b	Bcd_add_loop
	MOVE.w	D0, Race_time_bcd.w
	RTS
;Bcd_add_loop
Bcd_add_loop:
	ADDI.w	#0, D0
	ABCD	D2, D0
	ROR.w	#8, D0
	ROR.w	#8, D2
	ABCD	D2, D0
	ROR.w	#8, D0
	ROR.w	#8, D2
	DBF	D1, Bcd_add_loop
Accumulate_bcd_race_time_Rts:
	RTS
	include "src/endgame_result_data.asm"
;$0000DE46
Credits_object_anim_frame:
	JSR	Wait_for_vblank
	JSR	Update_objects_and_build_sprite_buffer
	MOVE.b	Input_click_bitset.w, D0
	ANDI.w	#$00F0, D0
	BNE.w	Credits_exit
	RTS
Credits_car_obj_update:
	CMPI.w	#$0140, Driver_spec_marker_step.w
	BEQ.w	Credits_car_setup
	TST.w	$12(A0)
	BNE.b	Credits_car_obj_ascend
	MOVE.l	#$FFF80000, D0
	MOVE.l	#Credits_car_frame_b, (Aux_object_pool+$84).w
	CMPI.w	#$0180, $18(A0)
	BCC.b	Credits_car_apply_y_delta
	MOVE.l	#$FFFA0000, D0
	MOVE.l	#Credits_car_frame_c, (Aux_object_pool+$84).w
	CMPI.w	#$0148, $18(A0)
	BCC.b	Credits_car_apply_y_delta
	MOVE.l	#$FFFC0000, D0
	MOVE.l	#Credits_car_frame_d, (Aux_object_pool+$84).w
	CMPI.w	#$0124, $18(A0)
	BCC.b	Credits_car_apply_y_delta
	MOVE.l	#$FFFE8000, D0
	MOVE.l	#Credits_car_frame_e, (Aux_object_pool+$84).w
	CMPI.w	#$0112, $18(A0)
	BCC.b	Credits_car_apply_y_delta
	MOVE.w	#$FFFF, $12(A0)
	MOVE.l	#Driver_standings_default_sprite, (Aux_object_pool+$84).w
Credits_car_obj_ascend:
	MOVE.l	#$00004000, D0
Credits_car_apply_y_delta:
	ADD.l	D0, $52(A0)
	MOVE.w	$52(A0), D0
	MOVE.w	D0, $18(A0)
	TST.w	$10(A0)
	BNE.b	Credits_car_obj_scroll_x_inc
	MOVE.l	#$FFFFA000, D0
	CMPI.w	#$00EA, $16(A0)
	BNE.b	Credits_car_obj_apply_x
	MOVE.w	#$FFFF, $10(A0)
	MOVE.w	#0, $C(A0)
Credits_car_obj_scroll_x_inc:
	MOVE.l	#$00010000, D0
	ADDI.l	#$FFFFF800, (Aux_object_pool+$58).w
Credits_car_obj_apply_x:
	ADD.l	D0, $58(A0)
	MOVE.w	$58(A0), D0
	MOVE.w	D0, $16(A0)
	JSR	Queue_object_for_sprite_buffer
	RTS
;$0000DF2A
Credits_sequence_init:
	JSR	Fade_palette_to_black
	JSR	Halt_audio_sequence
	JSR	Initialize_h40_vdp_state
	JSR	Clear_main_object_pool
	LEA	Credits_asset_list(PC), A1
	JSR	Decompress_asset_list_to_vdp
	LEA	Credits_tilemap_1, A0
	MOVE.w	#$421B, D0
	MOVE.l	#$40000003, D7
	MOVEQ	#$00000027, D6
	MOVEQ	#$0000000D, D5
	JSR	Decompress_tilemap_to_vdp_64_cell_rows
	LEA	Credits_tilemap_2, A0
	MOVE.w	#$421B, D0
	MOVE.l	#$4C000003, D7
	MOVEQ	#$00000015, D6
	MOVEQ	#3, D5
	JSR	Decompress_tilemap_to_vdp_64_cell_rows
	LEA	Credits_tilemap_3, A0
	MOVE.w	#$E001, D0
	MOVE.l	#$66000003, D7
	MOVEQ	#$00000027, D6
	MOVEQ	#$0000000F, D5
	JSR	Decompress_tilemap_to_vdp_64_cell_rows
	BSR.w	Credits_car_setup
	LEA	Credits_palette_stream, A6
	JSR	Copy_word_run_from_stream
	MOVE.l	#Credits_object_anim_frame, Frame_callback.w
	MOVE.l	#$000003D8, Vblank_callback.w
	ANDI	#$F8FF, SR
	JSR	Wait_for_vblank
	JSR	Wait_for_vblank
	MOVE.w	#1, Vblank_enable.w
	MOVE.w	#$8174, VDP_control_port
	RTS

Credits_car_setup:
	CMPI.w	#4, Screen_timer.w
	BEQ.b	Credits_exit
	MOVE.w	#$000E, $00FF5AC2
	LEA	Aux_object_pool.w, A1
	LEA	Credits_car_frame_table, A2
	LEA	Credits_car_sprite_table, A3
	LEA	(Palette_buffer+$2).w, A4
	MOVE.w	#2, D0
	MOVE.w	#$0010, D1
Credits_car_setup_loop:
	MOVE.l	#Credits_car_obj_update, (A1)
	MOVE.w	#$0228, $18(A1)
	MOVE.w	#$0228, $52(A1)
	CLR.w	$12(A1)
	MOVE.w	#$0110, $16(A1)
	MOVE.w	#$0110, $58(A1)
	CLR.w	$10(A1)
	MOVE.w	#$8000, $C(A1)
	MOVE.w	D1, $E(A1)
	MOVE.l	(A2)+, $4(A1)
	SUBQ.w	#4, D1
	ADDA.w	#$0080, A1
	DBF	D0, Credits_car_setup_loop
	MOVE.w	Screen_timer.w, D0
	MULS.w	#$001C, D0
	ADDA.l	D0, A3
	MOVE.w	#7, D0
Credits_car_scroll_loop:
	MOVE.l	(A3)+, (A4)+
	DBF	D0, Credits_car_scroll_loop
	ADDQ.w	#1, Screen_timer.w
	RTS
Credits_exit:
	MOVE.l	#$00004976, Frame_callback.w
	RTS
	include "src/endgame_credits_data.asm"
;$0000E088
Endgame_car_anim_frame:
	JSR	Wait_for_vblank
	TST.w	Screen_subcounter.w
	BEQ.b	Endgame_car_anim_update
	LEA	Endgame_car_anim_tile_table-2(PC), A6
	BTST.b	#5, Frame_counter.w
	BNE.b	Endgame_car_anim_alt_buf
	LEA	$00FF5980, A6
Endgame_car_anim_alt_buf:
	MOVE.l	#$69A40003, D7
	MOVEQ	#$00000012, D6
	MOVEQ	#0, D5
	JSR	Draw_tilemap_buffer_to_vdp_64_cell_rows
Endgame_car_anim_update:
	JSR	Update_objects_and_build_sprite_buffer
	MOVE.b	Input_click_bitset.w, D0
	ANDI.w	#$00F0, D0
	BNE.b	Endgame_car_anim_restore_cb
	SUBQ.w	#1, Race_frame_counter.w
	BNE.b	Endgame_car_anim_Rts
Endgame_car_anim_restore_cb:
	MOVE.l	Saved_frame_callback.w, Frame_callback.w
Endgame_car_anim_Rts:
	RTS
Arcade_car_spec_result_init:
	JSR	Fade_palette_to_black
	JSR	Halt_audio_sequence
	JSR	Initialize_h40_vdp_state
	JSR	Clear_main_object_pool
	MOVE.w	Player_grid_position.w, Qualifying_temp_grid_alt.w
	MOVE.l	Rival_race_time_bcd.w, Qualifying_temp_rival_time_alt.w
	JSR	Accumulate_bcd_race_time
	TST.w	Player_overtaken_flag.w
	BEQ.b	Arcade_car_spec_continue
	CLR.w	Race_time_bcd.w
	CLR.w	Player_overtaken_flag.w
Arcade_car_spec_continue:
	LEA	Arcade_car_spec_asset_list(PC), A1
	JSR	Decompress_asset_list_to_vdp
	LEA	Arcade_car_spec_tilemap_3, A0
	MOVE.w	#$2001, D0
	MOVE.l	#$41000003, D7
	MOVEQ	#$00000027, D6
	MOVEQ	#$0000000A, D5
	JSR	Decompress_tilemap_to_vdp_64_cell_rows
	LEA	Arcade_car_spec_tilemap_1, A0
	MOVE.w	#$6001, D0
	MOVE.l	#$62080003, D7
	MOVEQ	#$00000014, D6
	MOVEQ	#8, D5
	JSR	Decompress_tilemap_to_vdp_64_cell_rows
	LEA	Arcade_car_spec_tilemap_2, A0
	MOVE.w	#$4001, D0
	MOVE.l	#$64380003, D7
	MOVEQ	#7, D6
	MOVEQ	#4, D5
	JSR	Decompress_tilemap_to_vdp_64_cell_rows
	LEA	Aux_object_pool.w, A0
	LEA	Arcade_car_spec_car_positions(PC), A1
	MOVEQ	#3, D0
Arcade_car_spec_obj_loop:
	MOVE.l	#Queue_object_for_sprite_buffer, (A0)
	MOVE.w	(A1)+, $18(A0)
	MOVE.w	(A1)+, $16(A0)
	MOVE.l	(A1)+, $4(A0)
	LEA	$40(A0), A0
	DBF	D0, Arcade_car_spec_obj_loop
	LEA	Arcade_car_spec_tilemap_list(PC), A1
	JSR	Draw_packed_tilemap_list
	MOVE.w	#$E7AA, Screen_timer.w
	MOVE.w	#$E8B6, Screen_scroll.w
	JSR	Draw_car_selection_screen(PC)
	LEA	Arcade_car_spec_stat_ptrs(PC), A3
	LEA	Arcade_car_spec_vdp_addrs(PC), A4
	MOVE.w	#4, Screen_timer.w
	JSR	Draw_car_stat_rows(PC)
	MOVE.w	#$EC30, Screen_timer.w
	JSR	Draw_bcd_value_display(PC)
	LEA	Arcade_car_spec_palette_stream, A6
	JSR	Copy_word_run_from_stream
	MOVE.w	#$010E, D0
	MOVEQ	#4, D1
	MOVE.l	#$0000452A, D2
	MOVEQ	#1, D3
	CMPI.w	#2, Player_grid_position.w
	BLS.b	Arcade_car_spec_setup_cbs
	MOVE.w	#$0168, D0
	MOVEQ	#2, D1
	MOVE.l	#$00004976, D2
	MOVEQ	#0, D3
Arcade_car_spec_setup_cbs:
	MOVE.w	D0, Race_frame_counter.w
	MOVE.w	D1, Options_cursor_update.w
	MOVE.l	D2, Saved_frame_callback.w
	MOVE.w	D3, Screen_subcounter.w
	MOVE.l	#Endgame_car_anim_frame, Frame_callback.w
	MOVE.l	#$000003D8, Vblank_callback.w
	ANDI	#$F8FF, SR
	JSR	Wait_for_vblank
	JSR	Wait_for_vblank
	MOVE.w	Options_cursor_update.w, Audio_music_cmd ; song = $10 (race music on) or 0 (silent)
	MOVE.w	#1, Vblank_enable.w
	MOVE.w	#$8174, VDP_control_port
	RTS

;Draw_car_selection_screen
Draw_car_selection_screen:
	LEA	Car_select_tile_row_a, A6
	MOVE.w	Screen_timer.w, D7
	JSR	Tile_index_to_vdp_command
	MOVEQ	#5, D6
	MOVEQ	#2, D5
	JSR	Draw_tilemap_buffer_to_vdp_64_cell_rows
	MOVE.w	Player_grid_position.w, D0
	JSR	Wrap_index_mod10
	LEA	Player_placement_palette_cmds, A0
	JSR	Load_palette_vdp_commands_from_table
	MOVE.l	#$94009390, D5
	MOVE.l	#$53400082, Vdp_dma_setup.w
	JSR	Send_D567_to_VDP
	MOVE.w	D0, D4
	JSR	Load_palette_vdp_commands_from_table
	MOVE.l	#$54600082, Vdp_dma_setup.w
	JSR	Send_D567_to_VDP
	MOVE.w	Player_grid_position.w, D0
	CMPI.w	#3, D0
	BLS.b	Draw_car_selection_clamp
	MOVEQ	#3, D0
Draw_car_selection_clamp:
	ADD.w	D0, D0
	ADD.w	D0, D0
	MOVE.w	Screen_scroll.w, D7
	JSR	Tile_index_to_vdp_command
	MOVE.l	D7, VDP_control_port
	LEA	Placement_tile_data, A0
	MOVE.l	(A0,D0.w), VDP_data_port
	RTS
;Draw_car_stat_rows
Draw_car_stat_rows:
	MOVEA.l	(A3)+, A6
	MOVE.l	(A6), D0
	LEA	(Digit_tilemap_buf+$10).w, A1
	JSR	Pack_hex_digits_to_tilemap
	MOVEQ	#7, D0
	JSR	Copy_digits_to_tilemap_with_suppress
	MOVE.w	(A4)+, D7
	JSR	Tile_index_to_vdp_command
	MOVEQ	#7, D6
	MOVEQ	#1, D5
	LEA	Digit_tilemap_buf.w, A6
	JSR	Draw_tilemap_buffer_to_vdp_64_cell_rows
	SUBQ.w	#1, Screen_timer.w
	BNE.b	Draw_car_stat_rows
	RTS
;Draw_bcd_value_display
Draw_bcd_value_display:
	LEA	Digit_tilemap_buf.w, A1
	MOVE.w	Race_time_bcd.w, D1
	MOVEQ	#3, D0
	MOVEQ	#0, D7
	JSR	Unpack_bcd_digits_to_buffer
	MOVEQ	#3, D0
	JSR	Copy_digits_to_tilemap
	MOVE.w	Screen_timer.w, D7
	JSR	Tile_index_to_vdp_command
	MOVEQ	#3, D6
	MOVEQ	#1, D5
	LEA	Digit_tilemap_buf.w, A6
	JMP	Draw_tilemap_buffer_to_vdp_64_cell_rows
	include "src/endgame_data.asm"
;$0000E3D6
; Championship_team_select_frame — per-frame handler for the championship team-pairing
; (rival selection) screen.  Dispatches a 6-state machine via Screen_scroll index:
;   states 0–1 — scroll team-logo and car-stat tiles into view from data table
;   state 2    — pause
;   state 3    — waits for player button press, cycles through rival-car choices
;   states 4–5 — handle final confirmation of rival team
; On confirm: sets Saved_frame_callback=$E94C (Championship_standings_2_init) and
;   jumps to Team_select_screen_init.
Championship_team_select_frame:
	JSR	Wait_for_vblank
	JSR	Update_objects_and_build_sprite_buffer
	LEA	Championship_team_select_dispatch, A1
	MOVE.w	Screen_scroll.w, D0
	MOVEA.l	(A1,D0.w), A2
	JSR	(A2)
	RTS
Championship_team_select_dispatch:
	dc.l	Championship_team_select_scroll_logo
	dc.l	Championship_team_select_init_objs
	dc.l	Championship_team_select_substate_Copy_row
	dc.l	Championship_team_select_substate_Scroll_text
	dc.l	Championship_team_select_input
	dc.l	Championship_team_select_to_title
Championship_team_select_scroll_logo:
	SUBQ.w	#1, Screen_subcounter.w
	BNE.b	Championship_team_select_logo_Rts
	MOVE.w	#$0014, Screen_subcounter.w
	LEA	(Palette_buffer+$60).w, A1
	LEA	Championship_team_select_logo_vdp_data, A2
	MOVE.w	Screen_data_ptr.w, D0
	ADDA.l	D0, A2
	MOVE.w	#7, D0
Championship_team_select_logo_loop:
	MOVE.l	(A2)+, (A1)+
	DBF	D0, Championship_team_select_logo_loop
	SUBI.w	#$0020, Screen_data_ptr.w
	BCS.w	Championship_team_select_scroll_reset
Championship_team_select_logo_Rts:
	RTS
Championship_team_select_init_objs:
	SUBQ.w	#1, Screen_subcounter.w
	BNE.w	Championship_team_select_substate_Rts
	LEA	Aux_object_pool.w, A1
	MOVE.l	#$0000E722, (A1)
	MOVE.w	#$0120, $18(A1)
	MOVE.w	#$0120, $16(A1)
	MOVE.w	#1, $E(A1)
	MOVE.l	#Team_select_car_sprite_frame_a, $4(A1)
	LEA	$40(A1), A1
	MOVE.l	#$0000E722, (A1)
	MOVE.w	#$0120, $18(A1)
	MOVE.w	#$0128, $16(A1)
	MOVE.w	#1, $E(A1)
	MOVE.l	#Team_select_car_sprite_frame_b, $4(A1)
	LEA	$40(A1), A1
	MOVE.l	#$0000E722, (A1)
	MOVE.w	#$00F4, $18(A1)
	MOVE.w	#$0148, $16(A1)
	MOVE.w	#1, $E(A1)
	MOVE.l	#Team_select_car_sprite_frame_c, $4(A1)
	LEA	$40(A1), A1
	MOVE.l	#$0000E722, (A1)
	MOVE.w	#$014C, $18(A1)
	MOVE.w	#$0148, $16(A1)
	MOVE.w	#1, $E(A1)
	MOVE.l	#Team_select_car_sprite_frame_d, $4(A1)
	BSR.w	Championship_team_select_scroll_reset
Championship_team_select_substate_Rts:
	RTS
Championship_team_select_substate_Copy_row:
	SUBQ.w	#1, Screen_subcounter.w
	BNE.b	Championship_team_select_substate_Rts
	MOVE.w	#1, Screen_subcounter.w
	SUBQ.w	#1, Temp_x_pos.w
	BNE.b	Championship_team_select_copy_row_Rts
	MOVE.w	#8, Temp_x_pos.w
	CMPI.w	#$005A, Screen_state_word_1.w
	BEQ.w	Championship_team_select_scroll_reset
	MOVEA.l	Temp_distance.w, A1
	LEA	Standings_perf_scores.w, A2
	MOVE.b	#$5F, D0
Championship_team_select_tilemap_loop:
	MOVE.b	(A1)+, (A2)+
	DBF	D0, Championship_team_select_tilemap_loop
	LEA	Standings_perf_scores.w, A6
	MOVE.w	Screen_state_word_1.w, D0
	ADDQ.w	#5, D0
	MOVE.b	#$FF, (A6,D0.w)
	ORI	#$0700, SR
	JSR	Draw_packed_tilemap_to_vdp
	ANDI	#$F8FF, SR
	ADDQ.w	#1, Screen_state_word_1.w
Championship_team_select_copy_row_Rts:
	RTS
Championship_team_select_substate_Scroll_text:
	TST.b	Menu_substate.w
	BEQ.b	Championship_team_select_text_body
	ADDQ.w	#8, Screen_scroll.w
Championship_team_select_text_body:
	SUBQ.w	#1, Screen_subcounter.w
	BNE.b	Championship_team_select_text_Rts
	LEA	Championship_team_select_banner_text, A6
	ORI	#$0700, SR
	JSR	Draw_packed_tilemap_to_vdp
	ANDI	#$F8FF, SR
	BSR.w	Championship_team_select_scroll_reset
Championship_team_select_text_Rts:
	RTS
Championship_team_select_input:
	BSR.b	Championship_team_select_animate_cursor
	MOVE.b	Input_click_bitset.w, D0
	ANDI.b	#$E3, D0
	BEQ.b	Championship_team_select_animate_cursor
	MOVE.w	#Sfx_menu_confirm, Audio_sfx_cmd
	ANDI.b	#$E0, D0
	BNE.b	Championship_team_select_face_btn
	CLR.b	Menu_cursor.w
	BSR.b	Championship_team_select_animate_cursor
	ADDQ.b	#1, Selection_repeat_state.w
	RTS
Championship_team_select_face_btn:
	BSET.b	#2, Player_state_flags.w
	MOVE.l	#$00004FDC, Frame_callback.w
	BTST.b	#0, Selection_repeat_state.w
	BEQ.b	Championship_team_select_input_Rts
	MOVE.l	#$00004FDC, Saved_frame_callback.w
	MOVE.l	#$0000F288, Frame_callback.w
Championship_team_select_input_Rts:
	RTS
Championship_team_select_animate_cursor:
	MOVE.l	#$6B320003, D7
	BTST.b	#0, Selection_repeat_state.w
	BEQ.b	Championship_team_select_blink_c1
	MOVE.l	#$6C320003, D7
Championship_team_select_blink_c1:
	MOVE.w	#$C41A, D0
	BTST.b	#3, Menu_cursor.w
	BEQ.b	Championship_team_select_blink_draw
	MOVE.w	#$C418, D0
Championship_team_select_blink_draw:
	ORI	#$0700, SR
	MOVE.l	D7, VDP_control_port
	MOVE.w	D0, VDP_data_port
	ANDI	#$F8FF, SR
	ADDQ.b	#1, Menu_cursor.w
	RTS
Championship_team_select_to_title:
	MOVE.l	#$00002592, Frame_callback.w
	RTS

Championship_team_select_scroll_reset:
	MOVE.w	#$0050, Screen_subcounter.w
	ADDQ.w	#4, Screen_scroll.w
	RTS
;$0000E600
Championship_driver_select_init:
	JSR	Fade_palette_to_black
	JSR	Initialize_h40_vdp_state
	JSR	Clear_main_object_pool
	MOVE.w	#$8238, VDP_control_port
	MOVE.w	#$9011, VDP_control_port
	MOVE.w	#$9280, VDP_control_port
	MOVE.l	#$40200000, VDP_control_port
	LEA	Championship_driver_select_tiles_b, A0
	JSR	Decompress_to_vdp
	MOVE.l	#$68C00000, VDP_control_port
	LEA	Championship_driver_select_tiles, A0
	JSR	Decompress_to_vdp
	MOVE.l	#$7D000001, VDP_control_port
	LEA	Race_common_tiles, A0
	JSR	Decompress_to_vdp
	LEA	Championship_driver_select_tilemap, A0
	MOVE.w	#$6146, D0
	MOVE.l	#$60000003, D7
	MOVE.w	#$0027, D6
	MOVE.w	#$001B, D5
	JSR	Decompress_tilemap_to_vdp_64_cell_rows
	MOVE.l	#$00033756, Temp_distance.w
	BTST.b	#6, Player_team.w
	BEQ.b	Championship_driver_select_not_leader
	CLR.l	D0
	LEA	Driver_points_by_team.w, A1
	MOVE.b	Player_team.w, D0
	ANDI.b	#$0F, D0 ; isolate the player's team number
	MOVE.b	(A1,D0.w), D1
	MOVE.w	#$0010, D0
Championship_driver_select_leader_loop:
	CMP.b	(A1)+, D1
	BCS.b	Championship_driver_select_not_leader
	DBF	D0, Championship_driver_select_leader_loop
	MOVE.l	#$000337B4, Temp_distance.w
	MOVE.b	#$FF, Menu_substate.w
	BRA.b	Championship_driver_select_continue
Championship_driver_select_not_leader:
	BSET.b	#6, Player_team.w
Championship_driver_select_continue:
	JSR	Clear_driver_points
	JSR	Initialize_drivers_and_teams
	LEA	Championship_driver_select_cram_data, A6
	JSR	Copy_word_run_from_stream
	MOVE.w	#$0014, Screen_subcounter.w
	MOVE.w	#$000A, Temp_x_pos.w
	MOVE.w	#$00A0, Screen_data_ptr.w
	MOVE.l	#Championship_team_select_frame, Frame_callback.w
	MOVE.l	#$000003D8, Vblank_callback.w
	ANDI	#$F8FF, SR
	JSR	Wait_for_vblank
	MOVE.w	#1, Vblank_enable.w
	MOVE.w	#$8174, VDP_control_port
	RTS
Queue_sprite_thunk:
	JSR	Queue_object_for_sprite_buffer
	RTS
Championship_team_select_banner_text:
	dc.b	$EA, $AE, $FB, $C3, $E8, $37, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $39, $FD, $3A, $32, $32, $17, $0E, $21, $1D, $32, $22, $0E, $0A, $1B
	dc.b	$32, $3B, $FD, $3A, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $3B, $FD, $3A, $32, $32, $19, $0A, $1C, $1C, $20, $18, $1B, $0D, $32, $32, $3B
	dc.b	$FD, $3C, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3E, $FF
;$0000E77A
; Championship_podium_frame — per-frame handler for the end-of-season podium screen.
; Updates sprites and checks whether the player's team number matches the champion slot
; (stored in Screen_timer).
; Handles directional input to scroll between driver portraits.
; On confirm (face button): stores the selected rival into Rival_team,
;   sets Saved_frame_callback=Championship_standings_2_init ($E94C),
;   and jumps to Team_select_screen_init.
; On "skip" button: jumps directly to Arcade_race_init (starts new season immediately).
Championship_podium_frame:
	JSR	Wait_for_vblank
	JSR	Update_objects_and_build_sprite_buffer
	BSR.w	Championship_podium_update_portrait_anim
	BSR.w	Championship_podium_check_champion
	RTS
Championship_podium_check_champion:
	MOVE.b	Player_team.w, D0
	MOVE.b	Screen_timer.w, D1
	ANDI.b	#$0F, D0 ; isolate the player's team number
	BCLR.b	#7, Player_team.w
	CMP.b	D0, D1
	BNE.b	Championship_podium_input
	BSET.b	#7, Player_team.w
Championship_podium_input:
	MOVE.b	Input_click_bitset.w, D0
	BEQ.w	Championship_podium_Done
	ANDI.b	#$E0, D0
	BNE.b	Championship_podium_confirm
	BTST.b	#0, Screen_tick.w
	BEQ.b	Championship_podium_input_dir
	MOVE.b	#1, Screen_digit.w
	BSR.w	Championship_podium_update_portrait_anim
Championship_podium_input_dir:
	BTST.b	#KEY_UP, Input_click_bitset.w
	BNE.b	Championship_podium_prev_driver
	BTST.b	#KEY_DOWN, Input_click_bitset.w
	BNE.b	Championship_podium_next_driver
	CMPI.b	#$18, Screen_timer.w
	BEQ.b	Championship_podium_Rts
	BTST.b	#KEY_LEFT, Input_click_bitset.w
	BNE.w	Championship_podium_toggle_page
	BTST.b	#KEY_RIGHT, Input_click_bitset.w
	BNE.w	Championship_podium_toggle_page
Championship_podium_Rts:
	RTS
Championship_podium_confirm:
	MOVE.w	#Sfx_menu_confirm, Audio_sfx_cmd
	CMPI.b	#$18, Screen_timer.w
	BEQ.w	Championship_podium_to_new_season
	CLR.w	D0
	MOVE.b	Screen_timer.w, D0
	MOVE.b	D0, Rival_team.w
	LEA	Drivers_and_teams_map.w, A1
	MOVE.b	(A1,D0.w), D1
	ANDI.b	#$50, D1
	ADD.b	D1, Rival_team.w
	MOVE.l	#$0000E94C, Saved_frame_callback.w
	MOVE.l	#$0000D2B0, Frame_callback.w
	RTS
Championship_podium_prev_driver:
	MOVE.w	#Sfx_menu_confirm, Audio_sfx_cmd
	MOVE.b	Screen_timer.w, D0
	SUBQ.b	#1, D0
	ANDI.b	#7, D0
	ANDI.b	#8, Screen_timer.w
	ADD.b	D0, Screen_timer.w
	RTS
Championship_podium_next_driver:
	MOVE.w	#Sfx_menu_confirm, Audio_sfx_cmd
	CMPI.b	#$0F, Screen_timer.w
	BEQ.b	Championship_podium_set_24
	CMPI.b	#$18, Screen_timer.w
	BEQ.b	Championship_podium_set_08
	MOVE.b	Screen_timer.w, D0
	ADDQ.b	#1, D0
	ANDI.b	#7, D0
	ANDI.b	#8, Screen_timer.w
	ADD.b	D0, Screen_timer.w
	RTS
Championship_podium_set_24:
	MOVE.b	#$18, Screen_timer.w
	RTS
Championship_podium_set_08:
	MOVE.b	#8, Screen_timer.w
	RTS
Championship_podium_toggle_page:
	MOVE.w	#Sfx_menu_confirm, Audio_sfx_cmd
	EORI.b	#8, Screen_timer.w
	RTS
Championship_podium_to_new_season:
	ANDI.b	#$CF, Player_team.w
	MOVE.l	#$00003800, Frame_callback.w
Championship_podium_Done:
	RTS
Championship_podium_update_portrait_anim:
	SUBQ.b	#1, Screen_digit.w
	BNE.w	Championship_podium_portrait_Rts
	MOVE.b	#3, Screen_digit.w
	CMPI.b	#$18, Screen_timer.w
	BNE.b	Championship_podium_portrait_D7
	MOVE.w	#$ECAC, D7
	BRA.b	Championship_podium_portrait_draw
Championship_podium_portrait_D7:
	MOVE.w	#$E388, D7
	BTST.b	#3, Screen_timer.w
	BEQ.b	Championship_podium_portrait_row
	MOVE.w	#$E3AC, D7
Championship_podium_portrait_row:
	CLR.w	D0
	MOVE.b	Screen_timer.w, D0
	BTST.b	#2, Screen_timer.w
	BEQ.b	Championship_podium_portrait_cmd
	ADDI.w	#$0080, D7
Championship_podium_portrait_cmd:
	ANDI.b	#7, D0
	MULS.w	#$0100, D0
	ADD.w	D0, D7
Championship_podium_portrait_draw:
	JSR	Tile_index_to_vdp_command
	MOVE.l	D7, D6
	BCLR.l	#$1E, D7
	LEA	Screen_data_ptr.w, A1
	MOVE.w	#9, D0
	ORI	#$0700, SR
	MOVE.l	D7, VDP_control_port
Championship_podium_portrait_read_loop:
	MOVE.w	VDP_data_port, (A1)+
	DBF	D0, Championship_podium_portrait_read_loop
	LEA	Screen_data_ptr.w, A1
	MOVE.w	#9, D0
	MOVE.l	D6, VDP_control_port
Championship_podium_portrait_write_loop:
	MOVE.w	(A1)+, D1
	ADDI.w	#$C000, D1
	MOVE.w	D1, VDP_data_port
	DBF	D0, Championship_podium_portrait_write_loop
	ANDI	#$F8FF, SR
	ADDQ.b	#1, Screen_tick.w
Championship_podium_portrait_Rts:
	RTS
;$0000E94C
; Championship_standings_2_init — initialise the second championship standings screen
; (shown after team selection at season-end, before starting the new season).
; Fades to black, inits H40 VDP ($8238/$9011/$9280), clears objects.
; Decompresses championship standings art at $40200000 in VRAM.
; Loads updated team and driver standings data and installs the appropriate
; per-frame callback to display the final season standings before looping.
Championship_standings_2_init:
	JSR	Fade_palette_to_black
	JSR	Initialize_h40_vdp_state
	JSR	Clear_main_object_pool
	MOVE.w	#$8238, VDP_control_port
	MOVE.w	#$9011, VDP_control_port
	MOVE.w	#$9280, VDP_control_port
	MOVE.l	#$40200000, VDP_control_port
	LEA	Championship_standings_tiles_b, A0
	JSR	Decompress_to_vdp
	LEA	Championship_standings_tiles, A0
	MOVE.w	#$6001, D0
	MOVE.l	#$40000003, D7
	MOVE.w	#$0027, D6
	MOVE.w	#$001B, D5
	JSR	Decompress_tilemap_to_vdp_64_cell_rows
	LEA	Championship_standings_tilemap_list, A1
	JSR	Draw_packed_tilemap_list
	LEA	Championship_standings_vdp_word_run, A6
	JSR	Copy_word_run_from_stream
	MOVE.w	#$00CE, (Palette_buffer+$4).w
	MOVE.w	#$000C, (Palette_buffer+$24).w
	MOVE.w	#$0EEE, (Palette_buffer+$44).w
	MOVE.b	#1, Screen_digit.w
	MOVE.l	#Championship_podium_frame, Frame_callback.w
	MOVE.l	#$000003D8, Vblank_callback.w
	BCLR.b	#5, Player_team.w
	MOVE.b	Rival_team.w, D0
	ANDI.b	#$0F, D0 ; isolate the rival's team number
	MOVE.b	D0, Screen_timer.w
	MOVE.b	Player_team.w, D0
	ANDI.b	#$0F, D0  ; isolate the player's team number
	MOVE.w	#$E388, D7
	BTST.l	#3, D0
	BEQ.b	Options_arcade_init_Vdp_cmd
	MOVE.w	#$E3AC, D7
Options_arcade_init_Vdp_cmd:
	BTST.l	#2, D0
	BEQ.b	Options_arcade_init_Team_bits
	ADDI.w	#$0080, D7
Options_arcade_init_Team_bits:
	ANDI.b	#7, D0
	MULS.w	#$0100, D0
	ADD.w	D0, D7
	JSR	Tile_index_to_vdp_command
	MOVE.l	D7, D6
	BCLR.l	#$1E, D7
	LEA	Screen_data_ptr.w, A1
	MOVE.w	#9, D0
	MOVE.l	D7, VDP_control_port
Options_arcade_init_Read_loop:
	MOVE.w	VDP_data_port, (A1)+
	DBF	D0, Options_arcade_init_Read_loop
	LEA	Screen_data_ptr.w, A1
	MOVE.w	#9, D0
	MOVE.l	D6, VDP_control_port
Options_arcade_init_Write_loop:
	MOVE.w	(A1)+, D1
	ADDI.w	#$2000, D1
	MOVE.w	D1, VDP_data_port
	DBF	D0, Options_arcade_init_Write_loop
	ANDI	#$F8FF, SR
	MOVE.w	Selection_count.w, Audio_music_cmd ; song selection (options screen)
	CLR.w	Selection_count.w
	JSR	Wait_for_vblank
	MOVE.w	#1, Vblank_enable.w
	MOVE.w	#$8174, VDP_control_port
	RTS
;$0000EA8E
Options_screen_frame:
	JSR	Wait_for_vblank
	BSR.b	Options_handle_input
	BSR.w	Draw_conditional_overlay_tile
	ADDQ.b	#1, Screen_scroll.w
	RTS
Options_handle_input:
	MOVE.b	Input_click_bitset.w, D0
	BEQ.b	Options_input_Return
	JSR	Halt_audio_sequence
	MOVE.b	Input_click_bitset.w, D0
	BTST.b	#KEY_B, Input_click_bitset.w
	BNE.w	Options_back_to_title
	BTST.b	#KEY_UP, Input_click_bitset.w
	BNE.w	Options_handle_up
	BTST.b	#KEY_DOWN, Input_click_bitset.w
	BNE.w	Options_handle_down
	LEA	Options_input_dispatch_table, A1
	MOVE.w	Screen_timer.w, D1
	ADD.w	D1, D1
	ADD.w	D1, D1
	MOVEA.l	(A1,D1.w), A2
	JSR	(A2)
;Options_input_Return
Options_input_Return:
	RTS
Options_handle_up:
	MOVE.w	#Sfx_menu_confirm, Audio_sfx_cmd
	CLR.b	Screen_scroll.w
	BSR.w	Draw_conditional_overlay_tile
	TST.w	Screen_timer.w
	BEQ.b	Options_up_Rts
	SUBQ.w	#1, Screen_timer.w
	RTS
Options_up_Rts:
	MOVE.w	#6, Screen_timer.w
	RTS
Options_handle_down:
	MOVE.w	#Sfx_menu_confirm, Audio_sfx_cmd
	CLR.b	Screen_scroll.w
	BSR.w	Draw_conditional_overlay_tile
	CMPI.w	#6, Screen_timer.w
	BEQ.b	Options_down_Rts
	ADDQ.w	#1, Screen_timer.w
	RTS
Options_down_Rts:
	CLR.w	Screen_timer.w
	RTS
Options_control_type_input:
	ANDI.b	#$0C, D0
	BEQ.b	Options_input_Return
	BTST.l	#2, D0
	BEQ.b	Options_control_type_inc
	SUBQ.w	#1, Control_type.w
	BCC.b	Options_redraw_control_type
	MOVE.w	#5, Control_type.w
	BRA.b	Options_redraw_control_type
Options_control_type_inc:
	ADDQ.w	#1, Control_type.w
	CMPI.w	#6, Control_type.w
	BNE.b	Options_redraw_control_type
	CLR.w	Control_type.w
Options_redraw_control_type:
	MOVE.w	Control_type.w, D0
	ASL.w	#2, D0
	LEA	Control_layout_table, A4
	MOVEA.l	(A4,D0.w), A1
	ORI	#$0700, SR
	JSR	Draw_packed_tilemap_list
	ANDI	#$F8FF, SR
	RTS
Options_easy_input:
	ANDI.b	#$0C, D0
	BEQ.w	Options_input_Return
	ADDQ.w	#1, Easy_flag.w

Options_redraw_easy:
	ANDI.w	#1, Easy_flag.w
	MOVE.w	Easy_flag.w, D0
	ASL.w	#2, D0
	LEA	Options_jp_text_table, A1
	MOVEA.l	(A1,D0.w), A6
	ORI	#$0700, SR
	JSR	Draw_packed_tilemap_to_vdp
	ANDI	#$F8FF, SR
	RTS
Options_language_input:
	ANDI.b	#$0C, D0
	BEQ.w	Options_input_Return
	ADDQ.w	#1, English_flag.w

Options_redraw_language:
	ANDI.w	#1, English_flag.w
	LEA	Options_en_text_table, A2
	CLR.w	D0
	TST.w	English_flag.w
	BEQ.b	Options_language_Jp
	MOVE.b	#4, D0
Options_language_Jp:
	MOVEA.l	(A2,D0.w), A6
	ORI	#$0700, SR
	JSR	Draw_packed_tilemap_to_vdp
	ANDI	#$F8FF, SR
	RTS
Options_music_input:
	ANDI.b	#$E0, D0
	BNE.b	Options_music_play
	BTST.b	#KEY_LEFT, Input_click_bitset.w
	BEQ.b	Options_music_inc
	SUBQ.w	#1, Temp_x_pos.w
	BCC.b	Options_redraw_music_select
	MOVE.w	#$000E, Temp_x_pos.w
	BRA.b	Options_redraw_music_select
Options_music_inc:
	ADDQ.w	#1, Temp_x_pos.w
	CMPI.w	#$000F, Temp_x_pos.w
	BNE.b	Options_redraw_music_select
	CLR.w	Temp_x_pos.w

Options_redraw_music_select:
	MOVE.w	Temp_x_pos.w, D0
	ASL.w	#2, D0
	LEA	Race_quotes_table, A1
	MOVEA.l	(A1,D0.w), A6
	ORI	#$0700, SR
	JSR	Draw_packed_tilemap_to_vdp
	ANDI	#$F8FF, SR
	RTS
Options_music_play:
	MOVE.w	Temp_x_pos.w, D0
	ADDQ.w	#1, D0
	MOVE.w	D0, Audio_music_cmd         ; song = Temp_x_pos + 1 (options scroll music)
	RTS
Options_units_input:
	MOVE.b	Input_click_bitset.w, D0
	ANDI.b	#$E0, D0
	BNE.b	Options_units_play_sfx
	BTST.b	#KEY_LEFT, Input_click_bitset.w
	BEQ.b	Options_units_inc
	SUBQ.w	#1, Temp_distance.w
	BCC.b	Options_redraw_units
	MOVE.w	#$0010, Temp_distance.w
	BRA.b	Options_redraw_units
Options_units_inc:
	ADDQ.w	#1, Temp_distance.w
	CMPI.w	#$0011, Temp_distance.w
	BNE.b	Options_redraw_units
	CLR.w	Temp_distance.w
Options_redraw_units:
	MOVE.w	Temp_distance.w, D0
	JSR	Binary_to_decimal
	LEA	VDP_data_port, A5
	MOVE.w	D1, D0
	MOVE.w	#2, D1
	MOVE.w	#$07C0, D4
	MOVE.w	#$E4AA, D7
	ORI	#$0700, SR
	JSR	Render_packed_digits_to_vdp
	ANDI	#$F8FF, SR
	RTS
Options_units_play_sfx:
	LEA	Race_quote_index_table, A1
	MOVE.w	Temp_distance.w, D0
	CLR.w	D1
	MOVE.b	(A1,D0.w), D1
	MOVE.w	D1, Audio_sfx_cmd           ; SFX looked up by Temp_distance from table
	RTS
Options_transmission_input:
	MOVE.b	Input_click_bitset.w, D0
	ANDI.b	#$E0, D0
	BNE.b	Options_transmission_play_sfx
	BTST.b	#KEY_LEFT, Input_click_bitset.w
	BEQ.b	Options_transmission_inc
	SUBQ.w	#1, Anim_delay.w
	BCC.b	Options_redraw_transmission
	MOVE.w	#5, Anim_delay.w
	BRA.b	Options_redraw_transmission
Options_transmission_inc:
	ADDQ.w	#1, Anim_delay.w
	CMPI.w	#6, Anim_delay.w
	BNE.b	Options_redraw_transmission
	CLR.w	Anim_delay.w

Options_redraw_transmission:
	MOVE.w	Anim_delay.w, D0
	ASL.w	#2, D0
	LEA	Championship_intro_text_table, A1
	MOVEA.l	(A1,D0.w), A6
	ORI	#$0700, SR
	JSR	Draw_packed_tilemap_to_vdp
	ANDI	#$F8FF, SR
	RTS
Options_transmission_play_sfx:
	JSR	Wait_for_vblank
	LEA	Championship_intro_sequence, A1
	MOVE.w	Anim_delay.w, D0
	CLR.w	D1
	MOVE.b	(A1,D0.w), D1
	MOVE.w	D1, $00FF5AC2
	RTS
Options_back_to_title:
	MOVE.b	Input_click_bitset.w, D0
	ANDI.b	#$F0, D0
	BEQ.w	Options_input_Return
	MOVE.w	#9, Selection_count.w
	MOVE.l	#Title_menu, Frame_callback.w
	RTS
Options_input_dispatch_table:
	dc.l	Options_control_type_input
	dc.l	Options_easy_input
	dc.l	Options_language_input
	dc.l	Options_music_input
	dc.l	Options_units_input
	dc.l	Options_transmission_input
	dc.l	Options_back_to_title
;Draw_conditional_overlay_tile
Draw_conditional_overlay_tile:
	BTST.b	#2, Screen_scroll.w
	BEQ.b	Draw_conditional_overlay_tile_Blank
	MOVE.w	#$4224, D0
	BRA.b	Draw_conditional_overlay_tile_Cmd
Draw_conditional_overlay_tile_Blank:
	CLR.w	D0
Draw_conditional_overlay_tile_Cmd:
	MOVE.l	#$62140003, D7
	MOVE.w	Screen_timer.w, D1
Draw_conditional_overlay_tile_Loop:
	ADDI.l	#$00800000, D7
	DBF	D1, Draw_conditional_overlay_tile_Loop
	ORI	#$0700, SR
	MOVE.l	D7, VDP_control_port
	MOVE.w	D0, VDP_data_port
	ANDI	#$F8FF, SR
	RTS
;$0000ED90
Options_screen_champ_init:
	JSR	Fade_palette_to_black
	JSR	Initialize_h40_vdp_state
	MOVE.l	#$40200000, VDP_control_port
	LEA	Options_screen_champ_tiles, A0
	JSR	Decompress_to_vdp
	MOVE.l	#$7E800000, VDP_control_port
	LEA	Race_common_tiles, A0
	JSR	Decompress_to_vdp
	LEA	Options_screen_champ_tilemap, A0
	MOVE.w	#$6001, D0
	MOVE.l	#$47840003, D7
	MOVE.w	#$0022, D6
	MOVE.w	#$000A, D5
	JSR	Decompress_tilemap_to_vdp_64_cell_rows
	LEA	Championship_intro_text_block, A6
	JSR	Draw_packed_tilemap_to_vdp
	BSR.w	Options_redraw_control_type
	BSR.w	Options_redraw_easy
	BSR.w	Options_redraw_language
	BSR.w	Options_redraw_music_select
	BSR.w	Options_redraw_units
	BSR.w	Options_redraw_transmission
	LEA	Options_screen_cram_data, A6
	JSR	Copy_word_run_from_stream
	MOVE.w	#$00EE, (Palette_buffer+$4).w
	MOVE.w	#$0EEE, (Palette_buffer+$24).w
	MOVE.l	#$000E0000, (Palette_buffer+$44).w
	MOVE.l	#Options_screen_frame, Frame_callback.w
	MOVE.l	#$000003D8, Vblank_callback.w
	JSR	Halt_audio_sequence
	ANDI	#$F8FF, SR
	JSR	Wait_for_vblank
	JSR	Wait_for_vblank
	MOVE.w	#1, Vblank_enable.w
	MOVE.w	#$8174, VDP_control_port
	RTS

Control_types: ; keys for Shift down, Shift up, Accelerate, Break
	dc.b	KEY_UP, KEY_DOWN, KEY_B, KEY_A ; =$00010406, Type A
	dc.b	KEY_DOWN, KEY_UP, KEY_B, KEY_A ; =$01000406, Type B
	dc.b	KEY_UP, KEY_DOWN, KEY_A, KEY_B ; =$00010604, Type C
	dc.b	KEY_DOWN, KEY_UP, KEY_A, KEY_B ; =$01000604, Type D
	dc.b	KEY_A, KEY_B, KEY_DOWN, KEY_UP ; =$06040100, Type E
	dc.b	KEY_A, KEY_B, KEY_UP, KEY_DOWN ; =$06040001, Type F
;$0000EE78
Team_select_driver_frame:
	JSR	Wait_for_vblank
	BSR.w	Team_select_driver_input
	BSR.w	Team_select_driver_draw_cursor
	RTS
Team_select_driver_input:
	MOVE.b	Input_click_bitset.w, D0
	ANDI.b	#$F3, D0
	BEQ.b	Team_select_driver_Rts
	MOVE.w	#Sfx_menu_confirm, Audio_sfx_cmd
	ANDI.b	#$F0, D0
	BNE.b	Team_select_driver_Check_cheat
	CLR.b	Screen_data_ptr.w
	BSR.b	Team_select_driver_draw_cursor
	ADDQ.b	#1, Menu_cursor_blink_state.w
	RTS
Team_select_driver_Check_cheat:
	JSR	Compute_save_data_checksum
	MOVE.b	D1, D0
	ANDI.b	#$0F, D0
	CMP.b	Save_checksum_nibble_3.w, D0
	BNE.w	Demo_screen_transition
	LSR.b	#4, D1
	CMP.b	Save_checksum_nibble_2.w, D1
	BNE.w	Demo_screen_transition
	MOVE.b	D2, D0
	ANDI.b	#$0F, D0
	CMP.b	Save_checksum_nibble_1.w, D0
	BNE.w	Demo_screen_transition
	LSR.b	#4, D2
	CMP.b	Save_checksum_nibble_0.w, D2
	BNE.w	Demo_screen_transition
	BTST.b	#0, Menu_cursor_blink_state.w
	BEQ.b	Team_select_driver_Restore_cb
	CLR.b	Title_menu_flags.w
	CLR.w	Title_menu_state.w
	MOVE.l	#$00002592, Frame_callback.w
	RTS
Team_select_driver_Restore_cb:
	MOVE.l	Saved_frame_callback.w, Frame_callback.w
Team_select_driver_Rts:
	RTS
Team_select_driver_draw_cursor:
	MOVE.l	#$4FAA0003, D7
	BTST.b	#0, Menu_cursor_blink_state.w
	BEQ.b	Team_select_driver_Cursor_tile
	MOVE.l	#$50AA0003, D7
Team_select_driver_Cursor_tile:
	MOVE.w	#$2096, D0
	BTST.b	#2, Screen_data_ptr.w
	BEQ.b	Team_select_driver_Cursor_draw
	MOVE.w	#$2094, D0
Team_select_driver_Cursor_draw:
	ORI	#$0700, SR
	MOVE.l	D7, VDP_control_port
	MOVE.w	D0, VDP_data_port
	ANDI	#$F8FF, SR
	ADDQ.b	#1, Screen_data_ptr.w
	RTS
;$0000EF42
Name_entry_frame_2:
	JSR	Wait_for_vblank
	JSR	Update_objects_and_build_sprite_buffer
	BSR.w	Name_entry_handle_input
	BSR.w	Draw_cursor_tile
	BSR.w	Name_entry_update_bg_colors
	RTS
Name_entry_handle_input:
	MOVE.b	Input_click_bitset.w, D0
	BEQ.w	Name_entry_Return
	MOVE.w	#9, D7
	MOVE.l	#$04440444, (Palette_buffer+$2).w
	ANDI.b	#$E0, D0
	BNE.w	Name_entry_button_press
	BTST.b	#KEY_B, Input_state_bitset.w
	BNE.w	Name_entry_b_held
	BTST.b	#KEY_UP, Input_click_bitset.w
	BNE.b	Name_entry_up
	BTST.b	#KEY_DOWN, Input_click_bitset.w
	BNE.b	Name_entry_down
	BTST.b	#KEY_RIGHT, Input_click_bitset.w
	BNE.b	Name_entry_right
	MOVE.w	#Sfx_menu_confirm, Audio_sfx_cmd
	MOVE.w	Screen_timer.w, D0
	BEQ.b	Name_entry_col_wrap
	SUBQ.w	#1, Screen_timer.w
	RTS
Name_entry_col_wrap:
	MOVE.w	#$000D, Screen_timer.w
	RTS
Name_entry_up:
	MOVE.w	#Sfx_menu_confirm, Audio_sfx_cmd
	MOVE.w	Screen_tick.w, D0
	BEQ.b	Name_entry_up_wrap
	SUBQ.w	#1, Screen_tick.w
	RTS
Name_entry_up_wrap:
	MOVE.w	#4, Screen_tick.w
	RTS
Name_entry_down:
	MOVE.w	#Sfx_menu_confirm, Audio_sfx_cmd
	CMPI.w	#4, Screen_tick.w
	BEQ.b	Name_entry_down_wrap
	ADDQ.w	#1, Screen_tick.w
	RTS
Name_entry_down_wrap:
	CLR.w	Screen_tick.w
	RTS
Name_entry_right:
	MOVE.w	#Sfx_menu_confirm, Audio_sfx_cmd
	CMPI.w	#$000D, Screen_timer.w
	BEQ.b	Name_entry_right_wrap
	ADDQ.w	#1, Screen_timer.w
	RTS
Name_entry_right_wrap:
	CLR.w	Screen_timer.w
	RTS
Name_entry_b_held:
	MOVE.b	Input_click_bitset.w, D0
	ANDI.b	#$0F, D0
	BEQ.b	Name_entry_b_Rts
	BTST.b	#KEY_UP, Input_click_bitset.w
	BNE.w	Name_entry_cursor_up
	BTST.b	#KEY_DOWN, Input_click_bitset.w
	BNE.w	Name_entry_cursor_down
	BTST.b	#KEY_LEFT, Input_click_bitset.w
	BNE.w	Name_entry_cursor_left
	BTST.b	#KEY_RIGHT, Input_click_bitset.w
	BNE.w	Name_entry_confirm_selection
Name_entry_b_Rts:
	RTS
Name_entry_button_press:
	MOVE.w	Screen_timer.w, D0
	MOVE.w	Screen_tick.w, D1
	MULS.w	#$000E, D1
	ADD.w	D1, D0
	CMPI.w	#$0044, D0
	BEQ.b	Name_entry_confirm_selection
	CMPI.w	#$0043, D0
	BEQ.b	Name_entry_cursor_left
	CMPI.w	#$0045, D0
	BEQ.w	Name_entry_load_save
	LEA	Player_state_save_buf.w, A1
	MOVE.w	Screen_tick.w, D0
	MULS.w	#$000E, D0
	ADD.w	Screen_timer.w, D0
	MOVE.w	Screen_state_word_0.w, D1
	MULS.w	#$0010, D1
	ADD.w	Screen_scroll.w, D1
	MOVE.b	D0, (A1,D1.w)
	BSR.w	Endgame_init_clear_portrait_cells
	CMPI.w	#$000F, Screen_scroll.w
	BNE.b	Name_entry_confirm_selection
	CMPI.w	#3, Screen_state_word_0.w
	BNE.b	Name_entry_confirm_selection
	MOVE.w	#$000D, Screen_timer.w
	MOVE.w	#4, Screen_tick.w
Name_entry_confirm_selection:
	MOVE.w	#Sfx_menu_confirm, Audio_sfx_cmd
	CLR.w	Screen_item_count.w
	BSR.w	Draw_cursor_tile
	CMPI.w	#$000F, Screen_scroll.w
	BEQ.b	Name_entry_next_row
	ADDQ.w	#1, Screen_scroll.w
	RTS
Name_entry_next_row:
	CMPI.w	#3, Screen_state_word_0.w
	BEQ.w	Name_entry_Return
	ADDQ.w	#1, Screen_state_word_0.w
	CLR.w	Screen_scroll.w
	RTS
Name_entry_cursor_left:
	MOVE.w	#Sfx_menu_confirm, Audio_sfx_cmd
	CLR.w	Screen_item_count.w
	BSR.w	Draw_cursor_tile
	MOVE.w	Screen_scroll.w, D0
	BEQ.b	Name_entry_cursor_left_row
	SUBQ.w	#1, Screen_scroll.w
	RTS
Name_entry_cursor_left_row:
	MOVE.w	Screen_state_word_0.w, D1
	BEQ.w	Name_entry_Return
	SUBQ.w	#1, Screen_state_word_0.w
	MOVE.w	#$000F, Screen_scroll.w
	RTS
Name_entry_cursor_up:
	MOVE.w	#Sfx_menu_confirm, Audio_sfx_cmd
	CLR.w	Screen_item_count.w
	BSR.w	Draw_cursor_tile
	MOVE.w	Screen_state_word_0.w, D0
	BEQ.b	Name_entry_cursor_up_Rts
	SUBQ.w	#1, Screen_state_word_0.w
Name_entry_cursor_up_Rts:
	RTS
Name_entry_cursor_down:
	MOVE.w	#Sfx_menu_confirm, Audio_sfx_cmd
	CLR.w	Screen_item_count.w
	BSR.w	Draw_cursor_tile
	CMPI.w	#3, Screen_state_word_0.w
	BEQ.b	Name_entry_cursor_down_Rts
	ADDQ.w	#1, Screen_state_word_0.w
Name_entry_cursor_down_Rts:
	RTS
Name_entry_load_save:
	MOVE.b	Pending_save_load_flag.w, D0
	BEQ.b	Demo_screen_transition
	JSR	Load_player_state_from_buffer
	JSR	Compute_save_data_checksum
	MOVE.b	D1, D0
	ANDI.b	#$0F, D0
	CMP.b	Save_checksum_nibble_3.w, D0
	BNE.w	Demo_screen_transition
	LSR.b	#4, D1
	CMP.b	Save_checksum_nibble_2.w, D1
	BNE.w	Demo_screen_transition
	MOVE.b	D2, D0
	ANDI.b	#$0F, D0
	CMP.b	Save_checksum_nibble_1.w, D0
	BNE.w	Demo_screen_transition
	LSR.b	#4, D2
	CMP.b	Save_checksum_nibble_0.w, D2
	BNE.b	Demo_screen_transition
	MOVE.l	Saved_frame_callback.w, Frame_callback.w
Name_entry_Return:
	RTS
Demo_screen_transition:
; Screen-wipe palette fade for demo/attract/title transitions.
; Plays Sfx_demo_transition sound, then runs a 5-step palette fade
; using the table at Demo_screen_transition_palette (5 palette command pairs, 20 vblanks each).
; Called when the attract demo detects a button mismatch or save-data
; checksum failure, forcing a return to the title cycle.
	MOVE.w	#Sfx_demo_transition, Audio_sfx_cmd ; screen-transition sound
	LEA	Demo_screen_transition_palette, A1
	MOVE.w	#4, D0
Demo_screen_transition_Loop:
	MOVE.l	(A1)+, (Palette_buffer+$2).w
	MOVE.w	#$0014, D1
Demo_screen_transition_Wait:
	MOVEM.l	A1/D1/D0, -(A7)
	JSR	Wait_for_vblank
	MOVEM.l	(A7)+, D0/D1/A1
	DBF	D1, Demo_screen_transition_Wait
	DBF	D0, Demo_screen_transition_Loop
	RTS
Demo_screen_transition_palette:
	dc.b	$04, $44, $04, $46, $04, $44, $04, $48, $02, $22, $04, $4A, $02, $22, $04, $4C, $00, $00, $04, $4E
Draw_cursor_tile:
	MOVE.w	#0, D6
	BTST.b	#2, Screen_item_count_b.w
	BEQ.b	Draw_cursor_tile_Cmd
	MOVE.w	#$6050, D6
Draw_cursor_tile_Cmd:
	MOVE.w	#$C988, D7
	MOVE.w	Screen_state_word_0.w, D0
	LSL.w	#8, D0
	ADD.w	D0, D7
	MOVE.w	Screen_scroll.w, D0
	LSL.w	#1, D0
	ADD.w	D0, D7
	CLR.l	D0
	MOVE.w	Screen_scroll.w, D0
	DIVS.w	#4, D0
	LSL.w	#2, D0
	ADD.w	D0, D7
	JSR	Tile_index_to_vdp_command
	ORI	#$0700, SR
	MOVE.l	D7, VDP_control_port
	MOVE.w	D6, VDP_data_port
	ANDI	#$F8FF, SR
	ADDQ.w	#1, Screen_item_count.w
	RTS
Name_entry_update_bg_colors:
	LEA	Name_entry_bg_colors_phase0, A1
	LEA	(Palette_buffer+$30).w, A2
	MOVE.w	Screen_subcounter.w, D0
	ANDI.w	#$000C, D0
	JMP	(A1,D0.w)
Name_entry_bg_colors_phase0:
	MOVE.w	#$06EE, (A2)+
	MOVE.w	#$04CE, (A2)+
	MOVE.w	#$02AE, (A2)+
	MOVE.w	#$028E, (A2)+
	MOVE.w	#$06EE, (A2)+
	MOVE.w	#$04CE, (A2)+
	MOVE.w	#$02AE, (A2)+
	MOVE.w	#$028E, (A2)+
	SUBQ.w	#1, Screen_subcounter.w
	BTST.b	#KEY_B, Input_state_bitset.w
	BEQ.b	Name_entry_bg_colors_Rts
	ADDQ.w	#2, Screen_subcounter.w
Name_entry_bg_colors_Rts:
	RTS
	MOVE.w	Screen_timer.w, D0
	LSL.w	#4, D0
	ADDI.w	#$0094, D0
	MOVE.w	D0, $18(A0)
	MOVE.w	Screen_tick.w, D0
	LSL.w	#4, D0
	ADDI.w	#$00C0, D0
	MOVE.w	D0, $16(A0)
	JSR	Queue_object_for_sprite_buffer
	RTS
;$0000F288
Save_name_entry_init:
	JSR	Save_player_state_to_buffer
	BSR.w	Endgame_init_clear_vdp
	MOVE.l	#$40020010, VDP_control_port
	MOVE.w	#$0048, VDP_data_port
	LEA	Name_entry_tilemap_a, A6
	JSR	Draw_packed_tilemap_to_vdp
	LEA	Name_entry_tilemap_b, A6
	JSR	Draw_packed_tilemap_to_vdp
	MOVE.l	#Team_select_driver_frame, Frame_callback.w
	ANDI	#$F8FF, SR
	JSR	Wait_for_vblank
	MOVE.w	#1, Vblank_enable.w
	MOVE.w	#$8174, VDP_control_port
	RTS
;Endgame_sequence_init
Endgame_sequence_init:
	BSR.w	Endgame_init_clear_vdp
	MOVE.l	#$0000F264, Aux_object_pool.w
	MOVE.w	#1, (Aux_object_pool+$E).w
	MOVE.l	#$00039EEC, (Aux_object_pool+$4).w
	BSR.w	Endgame_init_draw_race_nums
	LEA	Endgame_tilemap_a, A6
	JSR	Draw_packed_tilemap_to_vdp
	LEA	Endgame_tilemap_b, A6
	JSR	Draw_packed_tilemap_to_vdp
	MOVE.l	#Name_entry_frame_2, Frame_callback.w
	ANDI	#$F8FF, SR
	JSR	Wait_for_vblank
	MOVE.w	#1, Vblank_enable.w
	MOVE.w	#$8174, VDP_control_port
	RTS

Endgame_init_clear_vdp:
	JSR	Fade_palette_to_black
	JSR	Initialize_h32_vdp_state
	JSR	Clear_main_object_pool
	MOVE.w	#$8238, VDP_control_port
	MOVE.w	#$9011, VDP_control_port
	MOVE.w	#$9280, VDP_control_port
	MOVE.l	#$40200000, VDP_control_port
	LEA	Endgame_tiles_a, A0
	JSR	Decompress_to_vdp
	MOVE.l	#$41400000, VDP_control_port
	LEA	Endgame_tiles_b, A0
	JSR	Decompress_to_vdp
	MOVE.l	#$4C800000, VDP_control_port
	LEA	Race_common_tiles, A0
	JSR	Decompress_to_vdp
	MOVE.l	#$04440444, (Palette_buffer+$2).w
	MOVE.l	#$0EEE0800, (Palette_buffer+$24).w
	MOVE.l	#$04440EEE, (Palette_buffer+$60).w
	MOVE.l	#$00EE0000, (Palette_buffer+$64).w
	MOVE.l	#$00E0000E, (Palette_buffer+$68).w
	MOVE.w	#$0EE0, (Palette_buffer+$6C).w
	BSR.w	Endgame_init_clear_portrait_cells
	MOVE.l	#Default_vblank_handler_h32, Vblank_callback.w
	RTS
Endgame_init_draw_race_nums:
	MOVE.w	#$C302, D6
	MOVE.l	#$0000600A, D0
	MOVE.w	#4, D1
Endgame_init_draw_nums_row_loop:
	MOVE.w	D6, D7
	JSR	Tile_index_to_vdp_command
	MOVE.l	D7, VDP_control_port
	MOVE.w	#$000D, D2
Endgame_init_draw_nums_cell_loop:
	MOVE.l	D0, VDP_data_port
	ADDQ.w	#1, D0
	DBF	D2, Endgame_init_draw_nums_cell_loop
	ADDI.w	#$0100, D6
	DBF	D1, Endgame_init_draw_nums_row_loop
	RTS
Endgame_init_clear_portrait_cells:
	LEA	Player_state_save_buf.w, A1
	MOVE.w	#$600A, D0
	MOVE.w	#$C908, D6
	MOVE.w	#3, D1
Endgame_init_clear_portrait_row_loop:
	MOVE.w	D6, D7
	JSR	Tile_index_to_vdp_command
	MOVE.w	#3, D2
	ORI	#$0700, SR
	MOVE.l	D7, VDP_control_port
Endgame_init_clear_portrait_col_loop:
	MOVE.w	#3, D3
Endgame_init_clear_portrait_pixel_loop:
	CLR.w	D4
	MOVE.b	(A1)+, D4
	ADD.w	D0, D4
	MOVE.w	D4, VDP_data_port
	DBF	D3, Endgame_init_clear_portrait_pixel_loop
	MOVE.l	#0, VDP_data_port
	DBF	D2, Endgame_init_clear_portrait_col_loop
	ANDI	#$F8FF, SR
	ADDI.w	#$0100, D6
	DBF	D1, Endgame_init_clear_portrait_row_loop
	RTS
Select_team_message_before_race:
	CLR.l	D0
	CLR.l	D6
	CLR.l	D7
	LEA	Drivers_and_teams_map.w, A1
	MOVE.b	Rival_team.w, D0
	ANDI.b	#$0F, D0 ; isolate the rival's team number
	BTST.b	#6, Player_team.w
	BEQ.b	Select_team_message_before_race_offset
	SUBI.l	#$00000024, D6
	BTST.b	#5, Player_team.w
	BNE.b	Select_team_message_before_race_offset
	ADDI.l	#$00000010, D6
Select_team_message_before_race_offset:
	MOVE.b	(A1,D0.w), D7
	ANDI.b	#$0F, D7
	MULS.w	#$0024, D7
	ADD.l	D6, D7
	LEA	Team_msg_jp_table, A1
	TST.w	English_flag.w
	BEQ.b	Select_team_message_before_race_lang
	ADDA.l	#$00000240, A1
Select_team_message_before_race_lang:
	BTST.b	#5, Player_team.w
	BEQ.b	Select_team_message_before_race_normal
	MOVEA.l	$20(A1,D7.w), A6
	RTS
Select_team_message_before_race_normal:
	CLR.l	D0
	LEA	Drivers_and_teams_map.w, A2
	MOVE.b	Rival_team.w, D0
	ANDI.b	#$0F, D0 ; isolate the rival's team number
	BTST.b	#4, (A2,D0.w)
	BNE.b	Select_team_message_before_race_lose
	BTST.b	#6, (A2,D0.w)
	BNE.b	Select_team_message_before_race_partner
	CLR.l	D0
	CLR.l	D1
	LEA	Drivers_and_teams_map.w, A2
	MOVE.b	Rival_team.w, D0
	MOVE.b	Player_team.w, D1
	ANDI.b	#$0F, D0 ; isolate the rival's team number
	ANDI.b	#$0F, D1 ; isolate the player's team number
	CMP.b	D0, D1
	BCC.b	Select_team_message_before_race_win
	MOVEA.l	$4(A1,D7.w), A6
	RTS
Select_team_message_before_race_win:
	MOVEA.l	(A1,D7.w), A6
	RTS
Select_team_message_before_race_lose:
	MOVEA.l	$C(A1,D7.w), A6
	RTS
Select_team_message_before_race_partner:
	MOVEA.l	$8(A1,D7.w), A6
	RTS
Select_team_intro_text:
	CLR.l	D7
	MOVE.b	Player_team.w, D7
	ANDI.b	#$0F, D7 ; isolate the player's team number
	LSL.l	#2, D7
	LEA	Team_intro_table, A1
	TST.w	English_flag.w
	BEQ.b	Select_team_intro_text_lang
	ADDA.l	#$00000080, A1
Select_team_intro_text_lang:
	BTST.b	#6, Player_team.w
	BEQ.b	Select_team_intro_text_load
	ADDA.l	#$00000040, A1
Select_team_intro_text_load:
	MOVEA.l	(A1,D7.w), A6
	RTS
Select_team_pre_race_message:
	LEA	TeamMessagesBeforeRace, A1
	TST.w	English_flag.w
	BEQ.b	Select_team_pre_race_message_lang
	ADDA.l	#$00000044, A1
Select_team_pre_race_message_lang:
	BTST.b	#5, Player_team.w
	BEQ.b	Select_team_pre_race_message_by_track
	MOVEA.l	(A1), A6
	RTS
Select_team_pre_race_message_by_track:
	CLR.l	D0
	MOVE.w	Track_index.w, D0
	LSL.l	#2, D0
	MOVEA.l	$4(A1,D0.w), A6
	RTS
Select_rival_team_name:
	LEA	Team_name_strings_table, A1
	TST.w	English_flag.w
	BEQ.b	Select_rival_team_name_lang
	ADDA.l	#$00000040, A1
Select_rival_team_name_lang:
	CLR.l	D0
	MOVE.b	Rival_team.w, D0
	ANDI.b	#$0F, D0 ; isolate the rival's team number
	LSL.l	#2, D0
	MOVEA.l	(A1,D0.w), A6
	RTS
Select_post_race_message:
	CLR.l	D7
	MOVE.b	Player_team.w, D7
	ANDI.b	#$0F, D7 ; isolate the player's team number
	MULS.w	#$0028, D7
	LEA	Team_msg_after_race_table, A1
	TST.w	English_flag.w
	BEQ.b	Select_post_race_message_lang
	ADDA.l	#$00000280, A1
Select_post_race_message_lang:
	CMPI.w	#$000F, Track_index.w
	BNE.b	Select_post_race_message_normal
	MOVE.b	Rival_team.w, D0
	ANDI.b	#$0F, D0 ; isolate the rival's team number
	MOVE.b	D0, Rival_team.w
	ANDI.b	#$F8, Player_state_flags.w
	CLR.l	D0
	LEA	Driver_points_by_team.w, A6
	MOVE.b	Player_team.w, D0
	ANDI.b	#$0F, D0 ; isolate the player's team number
	MOVE.b	(A6,D0.w), D1
	MOVE.w	#$0010, D0
Select_post_race_message_Scan:
	CMP.b	(A6)+, D1
	BCS.b	Select_post_race_message_Win
	DBF	D0, Select_post_race_message_Scan
	MOVEA.l	$5C(A1), A6
	RTS
Select_post_race_message_Win:
	MOVEA.l	$8(A1), A6
	RTS
Select_post_race_message_normal:
	BTST.b	#1, Player_state_flags.w
	BNE.w	Select_post_race_message_Swap
	MOVE.b	Player_team.w, D0
	ANDI.b	#$30, D0
	BNE.b	Select_post_race_message_Rival
	CMPI.w	#$FFFF, Player_grid_position.w
	BEQ.b	Select_post_race_message_Lose
	CLR.l	D0
	LEA	Post_race_driver_target_points, A2
	MOVE.b	Player_team.w, D0
	ANDI.b	#$0F, D0 ; isolate the player's team number
	ADD.l	D0, D0
	MOVE.b	(A2,D0.w), D1
	CMP.b	Player_grid_position_b.w, D1
	BCC.b	Select_post_race_message_Promote
	MOVE.b	$1(A2,D0.w), D1
	CMP.b	Player_grid_position_b.w, D1
	BCC.b	Select_post_race_message_Partner
Select_post_race_message_Lose:
	MOVEA.l	$8(A1,D7.w), A6
	MOVE.w	#$000B, Selection_count.w
	RTS
Select_post_race_message_Partner:
	MOVEA.l	$4(A1,D7.w), A6
	MOVE.w	#$000B, Selection_count.w
	RTS
Select_post_race_message_Promote:
	MOVEA.l	(A1,D7.w), A6
	MOVE.w	#$000D, Selection_count.w
	RTS
Select_post_race_message_Rival:
	BTST.b	#5, Rival_team.w
	BNE.b	Select_post_race_message_Same_team
	BTST.b	#7, Rival_team.w
	BNE.b	Select_post_race_message_New_partner
	MOVE.b	Player_team.w, D0
	MOVE.b	Rival_team.w, D1
	ANDI.b	#$0F, D0 ; isolate the player's team number
	ANDI.b	#$0F, D1 ; isolate the rival's team number
	CMP.b	D0, D1
	BCS.b	Select_post_race_message_Rival_lose
	MOVE.b	Player_grid_position_b.w, D0
	MOVE.b	Rival_grid_position_b.w, D1
	ANDI.b	#$0F, D0
	ANDI.b	#$0F, D1
	CMP.b	D0, D1
	BCC.b	Select_post_race_message_Rival_win
	MOVEA.l	$18(A1,D7.w), A6
	RTS
Select_post_race_message_Rival_win:
	MOVEA.l	$10(A1,D7.w), A6
	RTS
Select_post_race_message_Rival_lose:
	MOVE.b	Player_grid_position_b.w, D0
	MOVE.b	Rival_grid_position_b.w, D1
	ANDI.b	#$0F, D0
	ANDI.b	#$0F, D1
	CMP.b	D0, D1
	BCC.b	Select_post_race_message_Rival_tie
	MOVEA.l	$14(A1,D7.w), A6
	RTS
Select_post_race_message_Rival_tie:
	MOVEA.l	$C(A1,D7.w), A6
	RTS
Select_post_race_message_Same_team:
	MOVE.b	Player_team.w, D0
	MOVE.b	Rival_team.w, D1
	ANDI.b	#$0F, D0 ; isolate the player's team number
	ANDI.b	#$0F, D1 ; isolate the rival's team number
	CMP.b	D0, D1
	BCS.b	Select_post_race_message_Same_lose
	MOVEA.l	$24(A1,D7.w), A6
	RTS
Select_post_race_message_Same_lose:
	MOVEA.l	$20(A1,D7.w), A6
	RTS
Select_post_race_message_New_partner:
	MOVE.b	Player_team.w, D0
	MOVE.b	Rival_team.w, D1
	ANDI.b	#$0F, D0 ; isolate the player's team number
	ANDI.b	#$0F, D1 ; isolate the rival's team number
	CMP.b	D0, D1
	BCC.b	Select_post_race_message_New_partner_lose
	MOVEA.l	$14(A1,D7.w), A6
	RTS
Select_post_race_message_New_partner_lose:
	MOVEA.l	$1C(A1,D7.w), A6
	RTS
Select_post_race_message_Swap:
	MOVE.b	Player_team.w, D0
	MOVE.b	Rival_team.w, D1
	ANDI.b	#$0F, D0 ; isolate the player's team number
	ANDI.b	#$0F, D1 ; isolate the rival's team number
	CMP.b	D0, D1
	BCC.b	Select_post_race_message_Swap_set
	MOVE.b	Player_team.w, D0
	ANDI.b	#$0F, D0 ; isolate the player's team number
	MOVE.b	D0, Rival_team.w
Select_post_race_message_Swap_set:
	BSET.b	#6, Rival_team.w
	BSET.b	#7, Rival_team.w
	BRA.b	Select_post_race_message_New_partner
Post_race_driver_target_points:
; Per-team race finish position thresholds for post-race dialogue selection.
; Indexed as: Post_race_driver_target_points[team_number * 2]
; Byte 0 (even): promote_threshold — finish at or above this position → promotion message
; Byte 1 (odd):  partner_threshold  — finish at or above this position → partner message
; (positions 1=1st ... higher value = worse finish required)
; 16 teams × 2 bytes = 32 bytes
	dc.b	$02, $05 ; team 0:  Madonna    (promote ≤ 2nd, partner ≤ 5th)
	dc.b	$02, $05 ; team 1:  Firenze    (promote ≤ 2nd, partner ≤ 5th)
	dc.b	$02, $05 ; team 2:  Millions   (promote ≤ 2nd, partner ≤ 5th)
	dc.b	$02, $05 ; team 3:  Bestowal   (promote ≤ 2nd, partner ≤ 5th)
	dc.b	$02, $05 ; team 4:  Blanche    (promote ≤ 2nd, partner ≤ 5th)
	dc.b	$03, $06 ; team 5:  Tyrant     (promote ≤ 3rd, partner ≤ 6th)
	dc.b	$04, $07 ; team 6:  Losel      (promote ≤ 4th, partner ≤ 7th)
	dc.b	$05, $08 ; team 7:  May        (promote ≤ 5th, partner ≤ 8th)
	dc.b	$06, $09 ; team 8:  Bullets    (promote ≤ 6th, partner ≤ 9th)
	dc.b	$06, $0A ; team 9:  Dardan     (promote ≤ 6th, partner ≤ 10th)
	dc.b	$07, $0A ; team 10: Linden     (promote ≤ 7th, partner ≤ 10th)
	dc.b	$07, $0B ; team 11: Minarae    (promote ≤ 7th, partner ≤ 11th)
	dc.b	$08, $0C ; team 12: Rigel      (promote ≤ 8th, partner ≤ 12th)
	dc.b	$08, $0C ; team 13: Comet      (promote ≤ 8th, partner ≤ 12th)
	dc.b	$08, $0C ; team 14: Orchis     (promote ≤ 8th, partner ≤ 12th)
	dc.b	$08, $0D ; team 15: Zero Force (promote ≤ 8th, partner ≤ 13th)
;Load_font_tiles_to_work_buffer
Load_font_tiles_to_work_buffer:
	LEA	Dialogue_tilemap_buf.w, A1
	MOVE.w	#$0083, D0
	LEA	Rival_dialogue_blank_tilemap, A2
	TST.w	English_flag.w
	BEQ.b	Load_font_tiles_Loop
	LEA	Rival_dialogue_blink_tilemap, A2
Load_font_tiles_Loop:
	CLR.w	D1
	MOVE.b	(A2)+, D1
	ADD.w	Font_tile_base.w, D1
	MOVE.w	D1, (A1)+
	DBF	D0, Load_font_tiles_Loop
	RTS
;Render_text_to_tilemap
Render_text_to_tilemap:
; Decode a custom-encoded text string from A6 into the HUD tilemap work buffer.
; Used for team messages, lap standings, driver names, and menu text.
;
; Control bytes:
;  $FF = end of string (RTS)
;  $FD = advance to next line in the same text row
;  $FC = advance two lines
;  $DF-$FF range = two-byte kanji (tile index remapped via lookup)
;  Other multi-byte ranges = accented/special characters remapped to tile indices
;  Otherwise: tile = byte + $FFFF905A (tile base for font)
;
; Buffer layout:
;  Japanese (English_flag == 0): starts at $FFFFF74A, 44 (0x2C) words per row
;  English  (English_flag != 0): starts at $FFFFF71E, 44 words per row
;
; Inputs:
;  A6 = pointer to encoded text string (consumed)
;  $FFFF905A = tile base index (font tileset offset)
	LEA	Render_text_buffer_jp.w, A1
	TST.w	English_flag.w
	BEQ.b	Render_text_En
	LEA	Render_text_buffer_en.w, A1
Render_text_En:
	MOVE.w	#$002C, D0
Render_text_Next_line:
	LEA	(A1), A2
Render_text_Next_char:
	CLR.w	D1
	MOVE.b	(A6)+, D1
	CMPI.b	#$FF, D1
	BEQ.b	Render_text_End
	CMPI.b	#$FD, D1
	BEQ.b	Render_text_Next_row
	CMPI.b	#$FC, D1
	BEQ.b	Render_text_Skip_row
	CMPI.b	#$DF, D1
	BCC.b	Render_text_Special_DF
	CMPI.b	#$DA, D1
	BCC.b	Render_text_Special_DA
	CMPI.b	#$D5, D1
	BCC.b	Render_text_Special_D5
	CMPI.b	#$C6, D1
	BCC.b	Render_text_Special_C6
	CMPI.b	#$C1, D1
	BCC.b	Render_text_Special_C1
	CMPI.b	#$B2, D1
	BCC.b	Render_text_Special_B2
Render_text_Write_tile:
	ADD.w	Font_tile_base.w, D1
	MOVE.w	D1, (A1)+
	BRA.b	Render_text_Next_char
Render_text_End:
	RTS
Render_text_Next_row:
	LEA	$2C(A2), A1
	BRA.b	Render_text_Next_line
Render_text_Skip_row:
	LEA	$58(A2), A1
	BRA.b	Render_text_Next_line
Render_text_Special_DF:
	SUBI.b	#$4A, D1
	BRA.b	Render_text_special_char_with_tile_77
Render_text_Special_DA:
	SUBI.b	#$82, D1
	BRA.b	Render_text_special_char_with_tile_77
Render_text_Special_D5:
	SUBI.b	#$40, D1
	BRA.b	Render_text_special_char_with_tile_76
Render_text_Special_C1:
	SUBI.b	#$69, D1
	BRA.b	Render_text_special_char_with_tile_76
Render_text_Special_C6:
	SUBI.b	#$45, D1
	BRA.b	Render_text_special_char_with_tile_76
Render_text_Special_B2:
	SUBI.b	#$6E, D1
Render_text_special_char_with_tile_76:
	MOVE.w	#$0076, D2
	BRA.b	Render_text_Special_write
Render_text_special_char_with_tile_77:
	MOVE.w	#$0077, D2
Render_text_Special_write:
	LEA	-$2C(A1), A3
	ADD.w	Font_tile_base.w, D2
	MOVE.w	D2, (A3)
	BRA.b	Render_text_Write_tile
;Draw_message_panel_narrow
Draw_message_panel_narrow:
	BSR.b	Setup_message_panel_dimensions
	JSR	Draw_tilemap_buffer_to_vdp_64_cell_rows
	RTS
;Draw_message_panel_wide
Draw_message_panel_wide:
	BSR.b	Setup_message_panel_dimensions
	JSR	Draw_tilemap_buffer_to_vdp_128_cell_rows
	RTS
Setup_message_panel_dimensions:
	LEA	Dialogue_tilemap_buf.w, A6
	MOVE.w	#5, D5
	TST.w	English_flag.w
	BEQ.b	Setup_message_panel_Jp
	MOVE.w	#4, D5
Setup_message_panel_Jp:
	MOVE.w	#$0015, D6
	RTS
;Load_track_data_pointer
Load_track_data_pointer:
; Loads A1 with a pointer to the current track's entry in Track_data.
; Uses Track_index for championship mode or Track_index_arcade_mode for arcade.
	MOVE.w	Use_world_championship_tracks.w, D0
	EORI.w	#1, D0
	BEQ.b	Load_track_data_pointer_Champ ; jump if Use_world_championship_tracks == 1
	MOVE.w	#$0480, D0 ; $0480 = 1152 = 72*16 = offset from Track_data to arcade tracks
	MOVE.w	Track_index_arcade_mode.w, D1
	MULU.w	#$0048, D1
	ADD.w	D1, D0
Load_track_data_pointer_Champ:
	MOVE.w	Track_index.w, D1
	MULU.w	#$0048, D1 ; Multiply by 72. Each track in Track_data is 18*4=72 bytes.
	ADD.w	D1, D0 ; D0 = row offset? (before adding D1)
	LEA	Track_data(PC), A1
	ADDA.w	D0, A1 ; A1 = A1 + 72*track_idx + row_offset?
	RTS
	include	"src/track_config_data.asm"
	include	"src/sprite_frame_data.asm"
; Assign_initial_rival_team
; Called from Championship_next_race_init (first race leg) to select the player's
; initial rival. Three paths:
;   bit 2 set in Player_state_flags  → rival pre-assigned (Bullets, team #8); clear bit 2, set bit 3
;   player has no team (team# == 0) → choose rival from remaining unoccupied team slots
;   player has a named team          → choose next higher team as rival
Assign_initial_rival_team:
	BTST.b	#2, Player_state_flags.w
	BEQ.b	Assign_initial_rival_team_NoTeam
	BCLR.b	#2, Player_state_flags.w
	BSET.b	#3, Player_state_flags.w
	MOVE.b	#8, Rival_team.w ; You get challenged by Bullets (Team #8)
	BCLR.b	#4, Player_team.w
	BSET.b	#5, Player_team.w
	RTS
Assign_initial_rival_team_NoTeam:
	MOVE.b	Player_team.w, D0
	ANDI.b	#$0F, D0 ; isolate the player's team number
	BNE.w	Assign_initial_rival_team_HasTeam
	BTST.b	#6, Rival_team.w
	BEQ.b	Assign_initial_rival_team_PickSlot
	BCLR.b	#4, Player_team.w
	BSET.b	#5, Player_team.w
	RTS
Assign_initial_rival_team_PickSlot:
	CLR.l	D0
	LEA	Drivers_and_teams_map.w, A1
	MOVE.b	Rival_team.w, D0
	ANDI.b	#$0F, D0 ; isolate the rival's team number
	BTST.b	#4, Rival_team.w
	BEQ.b	Assign_initial_rival_team_ClearSlot
	BSET.b	#4, (A1,D0.w)
	BRA.b	Assign_initial_rival_team_FindBest
Assign_initial_rival_team_ClearSlot:
	BCLR.b	#4, (A1,D0.w)
Assign_initial_rival_team_FindBest:
	LEA	(Driver_points_by_team+1).w, A2
	MOVE.b	(A2)+, D0
	MOVEQ	#$0000000E, D1
	MOVEQ	#1, D2
	MOVE.l	D2, D3
Assign_initial_rival_team_FindBest_Loop:
	CMP.b	(A2), D0
	BCS.b	Assign_initial_rival_team_FindBest_Better
Assign_initial_rival_team_FindBest_Next:
	ADDA.l	#1, A2
	ADDQ.w	#1, D2
	DBF	D1, Assign_initial_rival_team_FindBest_Loop
	BRA.b	Assign_initial_rival_team_Assign
Assign_initial_rival_team_FindBest_Better:
	MOVE.b	(A2), D0
	MOVE.l	D2, D3
	BRA.b	Assign_initial_rival_team_FindBest_Next
Assign_initial_rival_team_Assign:
	CMPI.l	#1, D3
	BEQ.b	Assign_initial_rival_team_Assign_Set
	ADDQ.l	#1, D3
Assign_initial_rival_team_Assign_Set:
	MOVE.b	(A1,D3.w), D1
	ANDI.b	#$F0, D1
	ADD.b	D3, D1
	MOVE.b	D1, Rival_team.w
	BCLR.b	#4, Player_team.w
	BSET.b	#5, Player_team.w
	RTS
Assign_initial_rival_team_HasTeam:
	MOVE.b	Player_team.w, D0
	ANDI.b	#$30, D0
	BNE.b	Assign_initial_rival_team_Promoted
	MOVE.b	Player_team.w, D0
	ANDI.b	#$0F, D0 ; isolate the player's team number
	CMPI.b	#$0F, D0
	BEQ.w	Clear_rival_promotion_flag
	CLR.l	D0
	LEA	Drivers_and_teams_map.w, A1
	MOVE.b	Player_team.w, D0
	ANDI.b	#$0F, D0 ; isolate the player's team number
	ADDQ.b	#1, D0
	MOVE.b	(A1,D0.w), D1
	ANDI.b	#$F0, D1
	ADD.b	D0, D1
	MOVE.b	D1, Rival_team.w
	BCLR.b	#4, Player_team.w
	BSET.b	#5, Player_team.w
	RTS
Assign_initial_rival_team_Promoted:
	MOVE.b	Player_team.w, D0
	MOVE.b	Rival_team.w, D1
	ANDI.b	#$0F, D0 ; isolate the player's team number
	ANDI.b	#$0F, D1 ; isolate the rival's team number
	CMP.b	D0, D1
	BCC.b	Assign_initial_rival_team_RivalAhead
	BTST.b	#7, Rival_team.w
	BEQ.w	Clear_rival_promotion_flag
	MOVE.b	Player_team.w, D0
	ANDI.b	#$0F, D0 ; isolate the player's team number
	CMPI.b	#$0F, D0
	BEQ.b	Clear_rival_promotion_flag
	CLR.l	D0
	LEA	Drivers_and_teams_map.w, A1
	MOVE.b	Player_team.w, D0
	ANDI.b	#$0F, D0 ; isolate the player's team number
	ADDQ.b	#1, D0
	MOVE.b	(A1,D0.w), D1
	ANDI.b	#$F0, D1
	ADD.b	D0, D1
	MOVE.b	D1, Rival_team.w
	BCLR.b	#4, Player_team.w
	BSET.b	#5, Player_team.w
	RTS
Assign_initial_rival_team_RivalAhead:
	BTST.b	#6, Rival_team.w
	BEQ.b	Clear_rival_promotion_flag
	BCLR.b	#4, Player_team.w
	BSET.b	#5, Player_team.w
	RTS
Clear_rival_promotion_flag:
	BCLR.b	#5, Player_team.w
	RTS

; Update_player_grid_position
; Called from Championship_next_race_init_MidChamp.
; If Player_grid_position is $FFFF (unset), advances Player_state_flags bits 0/1
; to track whether the player has been placed on the grid yet.
; Then updates rival promotion state based on current team standings and promotion flags.
Update_player_grid_position:
	CMPI.w	#$FFFF, Player_grid_position.w
	BNE.b	Update_player_grid_position_Placed
	BTST.b	#0, Player_state_flags.w
	BNE.b	Update_player_grid_position_Mark2
	BSET.b	#0, Player_state_flags.w
	BRA.b	Update_player_grid_position_Placed
Update_player_grid_position_Mark2:
	BSET.b	#1, Player_state_flags.w
Update_player_grid_position_Placed:
	MOVE.b	Player_team.w, D0
	ANDI.b	#$30, D0
	BEQ.b	Update_player_grid_position_Rts
	MOVE.b	Player_grid_position_b.w, D0
	MOVE.b	Rival_grid_position_b.w, D1
	CMP.b	D0, D1
	BCC.w	Update_player_grid_position_RivalWins
	MOVE.b	Rival_team.w, D0
	ANDI.b	#$CF, D0
	MOVE.b	D0, Rival_team.w
	BTST.b	#6, Rival_team.w
	BNE.b	Update_player_grid_position_PromoteFull
	BSET.b	#6, Rival_team.w
	RTS
Update_player_grid_position_PromoteFull:
	BSET.b	#7, Rival_team.w
	RTS
Update_player_grid_position_RivalWins:
	MOVE.b	Rival_team.w, D0
	ANDI.b	#$3F, D0
	MOVE.b	D0, Rival_team.w
	BTST.b	#4, Rival_team.w
	BNE.b	Update_player_grid_position_SetBit5
	MOVE.w	Promoted_teams_bitfield.w, D1
	MOVE.b	Rival_team.w, D0
	ANDI.b	#$0F, D0 ; isolate the rival's team number
	BTST.l	D0, D1
	BNE.b	Update_player_grid_position_Rts
	BSET.b	#4, Rival_team.w
	RTS
Update_player_grid_position_SetBit5:
	BSET.b	#5, Rival_team.w
	RTS
Update_player_grid_position_Rts:
	RTS

; Advance_rival_promotion_state
; Called from Championship_podium_load_or_fade to update the rival driver's
; promotion state for the next championship race.
; Checks whether the rival is eligible for promotion (bits in Rival_team).
; If the rival team slot >= rival+4 is taken (bit set in Promoted_teams_bitfield),
; pops the return address and sets Anim_delay instead (display-friendly skip path).
Advance_rival_promotion_state:
	MOVE.b	Rival_team.w, D0
	ANDI.b	#$A0, D0
	BEQ.w	Advance_rival_promotion_state_Rts
	BTST.b	#7, Rival_team.w
	BEQ.b	Advance_rival_promotion_state_Rts
	MOVE.b	Player_team.w, D0
	MOVE.b	Rival_team.w, D1
	ANDI.b	#$0F, D0 ; isolate the player's team number
	ANDI.b	#$0F, D1 ; isolate the rival's team number
	CMP.b	D0, D1
	BCS.b	Advance_rival_promotion_state_Rts
	CLR.l	D1
	LEA	Drivers_and_teams_map.w, A1
	MOVE.w	Promoted_teams_bitfield.w, D0
	MOVE.b	Rival_team.w, D1
	ANDI.b	#$0F, D1 ; isolate the rival's team number
Advance_rival_promotion_state_Loop:
	ADDQ.b	#1, D1
	CMPI.b	#$10, D1
	BCC.w	Advance_rival_promotion_state_DelayAndRts
	MOVE.b	Rival_team.w, D5
	ANDI.b	#$0F, D5 ; isolate the rival's team number
	ADDQ.b	#4, D5
	CMP.b	D5, D1
	BCC.w	Advance_rival_promotion_state_DelayAndRts
	BTST.l	D1, D0
	BNE.b	Advance_rival_promotion_state_Loop
Advance_rival_promotion_state_Rts:
	RTS
Advance_rival_promotion_state_DelayAndRts:
	MOVE.w	#$0024, Anim_delay.w
	MOVE.l	(A7)+, D0
	RTS
; Initialize_standings_order_buffer
; Called from Championship_next_race_init_MidChamp to set up the standings
; display order for the inter-race screen.  Fills Standings_team_order with
; identity 0-15, then generates a random AI performance score for each
; driver (using Ai_performance_factor_by_team and Ai_performance_table),
; biases player/rival to 0 (top slot), offsets all scores by +2, and
; bubble-sorts Standings_team_order ascending by Standings_perf_scores.
; Finally rotates Standings_team_order so the player and rival appear at
; the correct positions.
Initialize_standings_order_buffer:
	LEA	Standings_team_order.w, A1
	MOVE.w	#$000F, D0
	CLR.b	D1
Initialize_standings_order_buffer_Fill_loop:
	MOVE.b	D1, (A1)+
	ADDQ.b	#1, D1
	DBF	D0, Initialize_standings_order_buffer_Fill_loop
	LEA	Standings_perf_scores.w, A6
	MOVE.w	#$000F, D7
Initialize_standings_order_buffer_Score_loop:
	JSR	Prng
	MOVE.b	D0, D1
	ANDI.l	#7, D1
	CLR.l	D2
	CLR.l	D3
	CLR.l	D4
	LEA	Drivers_and_teams_map.w, A1
	MOVE.b	(A1,D7.w), D2
	ANDI.b	#$0F, D2 ; isolate the team number
	BTST.b	#6, Player_team.w
	BEQ.b	Initialize_standings_order_buffer_NoBonus
	ADDQ.b	#1, D2
Initialize_standings_order_buffer_NoBonus:
	LEA	Ai_performance_factor_by_team, A1
	MOVE.b	(A1,D7.w), D3
	LEA	Ai_performance_table, A1
	LSL.l	#3, D2
	ADDA.l	D2, A1
	MOVE.b	(A1,D1.w), D4
	MULS.w	D3, D4
	MOVE.b	D4, (A6,D7.w)
	DBF	D7, Initialize_standings_order_buffer_Score_loop
	LEA	Standings_perf_scores.w, A1
	MOVE.w	#$000F, D0
Initialize_standings_order_buffer_Offset_loop:
	ADDQ.b	#2, (A1)+
	DBF	D0, Initialize_standings_order_buffer_Offset_loop
	CLR.l	D0
	LEA	Standings_perf_scores.w, A1
	MOVE.b	Player_team.w, D0
	ANDI.b	#$0F, D0 ; isolate the player's team number
	CLR.b	(A1,D0.w)
	MOVE.b	Player_team.w, D0
	ANDI.b	#$30, D0
	BEQ.b	Initialize_standings_order_buffer_NoRival
	MOVE.b	Rival_team.w, D0
	ANDI.b	#$0F, D0 ; isolate the rival's team number
	CLR.b	(A1,D0.w)
Initialize_standings_order_buffer_NoRival:
	MOVEQ	#$0000000F, D0
Initialize_standings_order_buffer_Sort_outer:
	MOVEQ	#$0000000E, D1
	LEA	Standings_perf_scores.w, A1
	LEA	Standings_team_order.w, A2
Initialize_standings_order_buffer_Sort_inner:
	MOVE.b	(A1), D2
	CMP.b	$1(A1), D2
	BCC.b	Initialize_standings_order_buffer_Sort_noswap
	MOVE.b	$1(A1), (A1)
	MOVE.b	D2, $1(A1)
	MOVE.b	(A2), D2
	MOVE.b	$1(A2), (A2)
	MOVE.b	D2, $1(A2)
Initialize_standings_order_buffer_Sort_noswap:
	ADDQ.w	#1, A1
	ADDQ.w	#1, A2
	DBF	D1, Initialize_standings_order_buffer_Sort_inner
	DBF	D0, Initialize_standings_order_buffer_Sort_outer
	MOVE.b	Player_team.w, D0
	ANDI.b	#$30, D0
	BNE.b	Initialize_standings_order_buffer_HasRival
	BSR.b	Rotate_standings_buffer
	BRA.w	Accumulate_race_points
Initialize_standings_order_buffer_HasRival:
	MOVE.b	Player_grid_position_b.w, D0
	CMP.b	Rival_grid_position_b.w, D0
	BCS.b	Initialize_standings_order_buffer_RivalFirst
	BSR.b	Rotate_standings_buffer_Rival
	BSR.b	Rotate_standings_buffer
	BRA.w	Accumulate_race_points
Initialize_standings_order_buffer_RivalFirst:
	BSR.b	Rotate_standings_buffer
	BSR.b	Rotate_standings_buffer_Rival
	BRA.w	Accumulate_race_points
;Rotate_standings_buffer
Rotate_standings_buffer:
	CLR.l	D0
	LEA	Standings_team_order.w, A1
	LEA	(Standings_points_buf-1).w, A2
	LEA	$1(A2), A3
	MOVE.b	Player_grid_position_b.w, D0
	ANDI.b	#$0F, D0
	ADDA.l	D0, A1
	MOVE.w	#$000F, D1
	SUB.w	D0, D1
Rotate_standings_buffer_Loop:
	MOVE.b	-(A2), -(A3)
	DBF	D1, Rotate_standings_buffer_Loop
	MOVE.b	Player_team.w, D0
	ANDI.b	#$0F, D0 ; isolate the player's team number
	MOVE.b	D0, (A1)
	RTS
Rotate_standings_buffer_Rival:
	CLR.l	D0
	LEA	Standings_team_order.w, A1
	LEA	(Standings_points_buf-1).w, A2
	LEA	$1(A2), A3
	MOVE.b	Rival_grid_position_b.w, D0
	ANDI.b	#$0F, D0
	ADDA.l	D0, A1
	MOVE.w	#$000F, D1
	SUB.w	D0, D1
Rotate_standings_buffer_Rival_Loop:
	MOVE.b	-(A2), -(A3)
	DBF	D1, Rotate_standings_buffer_Rival_Loop
	MOVE.b	Rival_team.w, D0
	ANDI.b	#$0F, D0 ; isolate the rival's team number
	MOVE.b	D0, (A1)
	RTS
Accumulate_race_points:
	LEA	Standings_points_buf.w, A1
	MOVE.w	#$000F, D0
Accumulate_race_points_Clear_loop:
	CLR.b	(A1)+
	DBF	D0, Accumulate_race_points_Clear_loop
	CLR.l	D2
	LEA	PointsAwardedPerPlacement, A1
	LEA	Standings_team_order.w, A2
	LEA	Standings_points_buf.w, A3
	MOVE.w	#5, D0
Accumulate_race_points_Dist_loop:
	MOVE.b	(A1,D0.w), D1
	MOVE.b	(A2,D0.w), D2
	MOVE.b	D1, (A3,D2.w)
	DBF	D0, Accumulate_race_points_Dist_loop
	CLR.l	D2
	CLR.l	D3
	LEA	Standings_points_buf.w, A1
	LEA	Drivers_and_teams_map.w, A2
	LEA	Driver_points_by_team.w, A3
	MOVE.w	#$000F, D0
Accumulate_race_points_Assign_loop:
	MOVE.b	(A2,D3.w), D2
	ANDI.b	#$0F, D2
	MOVE.b	(A1,D2.w), D1
	ADD.b	D1, (A3,D2.w)
	ADDQ.w	#1, D3
	DBF	D0, Accumulate_race_points_Assign_loop
	RTS
;Initialize_drivers_and_teams
Initialize_drivers_and_teams:
; Resets championship driver/team state and loads the year-appropriate driver map.
; Clears Driver_points_by_team (16 bytes at $FFFF9030) and Rival_team.
; Then copies 17 bytes from InitialDriversAndTeamMap (year 1) or
; SecondYearDriversAndTeamsMap (year 2, when bit 6 of Player_team is set) into
; Player_team..Drivers_and_teams_map ($FFFF9043..$FFFF9054).
; Called at championship start to initialise the 16-driver roster for the season.
	LEA	Driver_points_by_team.w, A1
	MOVE.w	#$000F, D0
Initialize_drivers_and_teams_Clear_loop:
	CLR.b	(A1)+
	DBF	D0, Initialize_drivers_and_teams_Clear_loop
	CLR.b	Rival_team.w
	LEA	Player_team.w, A1
	LEA	InitialDriversAndTeamMap, A2
	BTST.b	#6, Player_team.w
	BEQ.b	Initialize_drivers_and_teams_UseMap
	LEA	SecondYearDriversAndTeamsMap, A2
Initialize_drivers_and_teams_UseMap:
	MOVE.w	#$0010, D0
Initialize_drivers_and_teams_Copy_loop:
	MOVE.b	(A2)+, (A1)+
	DBF	D0, Initialize_drivers_and_teams_Copy_loop
	RTS
;Load_team_machine_stats
Load_team_machine_stats:
; Loads team machine screen bar values, tire wear parameters, and car
; characteristics for the currently selected Player_team.
;
; Reads TeamMachineScreenStats[player_team_num * 7]:
;   bytes 0-4 → ENG/TM/SUS/TIRE/BRA bar heights, written in pairs to
;               Tire_stat_max and Tire_stat_durability_acc pairs ($9010-$9023)
;               so each stat bar value initialises both the cap and accumulator.
;   byte 6    → tire wear delta, written to all 5 Tire_stat_delta slots ($9025-$902D low bytes)
;
; Reads Team_engine_multiplier[player_team_num] for tire wear rates.
; Reads Team_car_characteristics[player_team_num * 5] for car attributes.
; On Track_index==1 (first race) and Track_index==$0B (12th race),
;   applies extra multiplier adjustments to the braking wear rate.
	CLR.w	D0
	LEA	TeamMachineScreenStats, A1
	MOVE.b	Player_team.w, D0
	ANDI.b	#$0F, D0 ; isolate the player's team number
	MULS.w	#7, D0
	ADDA.l	D0, A1
	MOVE.b	(A1), (Tire_stat_max_2+1).w   ; ENG bar → Tire_stat_max_2 low byte (copy A)
	MOVE.b	(A1)+, (Tire_accel_durability_acc+1).w  ; ENG bar → Tire_accel_durability_acc low byte (copy B)
	MOVE.b	(A1), (Tire_stat_max_4+1).w   ; TM bar → Tire_stat_max_4 low byte (copy A)
	MOVE.b	(A1)+, (Tire_engine_durability_acc+1).w  ; TM bar → Tire_engine_durability_acc low byte (copy B)
	MOVE.b	(A1), (Tire_stat_max_base+1).w   ; SUS. bar → Tire_stat_max_base low byte (copy A)
	MOVE.b	(A1)+, (Tire_steering_durability_acc+1).w  ; SUS. bar → Tire_steering_durability_acc low byte (copy B)
	MOVE.b	(A1), (Tire_stat_max_1+1).w   ; TIRE bar → Tire_stat_max_1 low byte (copy A)
	MOVE.b	(A1)+, (Tire_braking_durability_acc+1).w  ; TIRE bar → Tire_braking_durability_acc low byte (copy B)
	MOVE.b	(A1), (Tire_stat_max_3+1).w   ; BRA. bar → Tire_stat_max_3 low byte (copy A)
	MOVE.b	(A1)+, (Tire_braking_zone_acc+1).w  ; BRA. bar → Tire_braking_zone_acc+1 (copy B)
	MOVE.b	$1(A1), (Tire_stat_delta_base+5).w ; tire wear delta → Tire_stat_delta slot 2 low byte
	MOVE.b	$1(A1), (Tire_stat_delta_base+9).w ; tire wear delta → Tire_stat_delta slot 4 low byte
	MOVE.b	$1(A1), (Tire_stat_delta_base+1).w ; tire wear delta → Tire_stat_delta slot 0 low byte
	MOVE.b	$1(A1), (Tire_stat_delta_base+3).w ; tire wear delta → Tire_stat_delta slot 1 low byte
	MOVE.b	$1(A1), (Tire_stat_delta_base+7).w ; tire wear delta → Tire_stat_delta slot 3 low byte
	MOVE.b	Player_team.w, D0
	ANDI.w	#$000F, D0
	LEA	Team_engine_multiplier(PC), A0
	MOVE.b	(A0,D0.w), D0
	MOVE.w	D0, Tire_braking_wear_rate_full.w ; full braking wear rate = multiplier
	MOVE.w	D0, Tire_steering_wear_rate.w    ; steering wear rate = multiplier
	MOVE.w	D0, D1
	ADD.w	D1, D1
	ADD.w	D1, D1                           ; D1 = multiplier * 4
	MOVE.w	D1, Tire_braking_wear_rate.w     ; braking wear rate = multiplier * 4
	CMPI.w	#1, Track_index.w
	BNE.b	Load_team_machine_stats_NoFirst
	ADD.w	D0, Tire_braking_wear_rate.w     ; track 1 bonus: braking wear += multiplier
	ADD.w	D0, Tire_braking_wear_rate.w     ; total = multiplier * 6 on first race
Load_team_machine_stats_NoFirst:
	MOVE.w	D1, Tire_engine_wear_rate.w      ; engine wear rate = multiplier * 4
	MOVE.w	D0, Tire_accel_wear_rate.w       ; accel wear rate = multiplier (base)
	ADD.w	D0, Tire_accel_wear_rate.w       ; accel wear rate += multiplier
	ADD.w	D0, Tire_accel_wear_rate.w       ; total = multiplier * 3
	CMPI.w	#$000B, Track_index.w
	BNE.b	Load_team_machine_stats_NoLast
	ADD.w	D0, Tire_accel_wear_rate.w       ; track 11 ($0B) bonus: accel wear += multiplier
Load_team_machine_stats_NoLast:
	MOVE.b	Player_team.w, D0
	ANDI.w	#$000F, D0
	MULU.w	#5, D0
	LEA	Team_car_characteristics(PC), A0
	ADDA.w	D0, A0
	LEA	Team_car_acceleration.w, A1
	MOVEQ	#4, D0
Load_team_machine_stats_Char_loop:
	MOVEQ	#0, D1
	MOVE.b	(A0)+, D1
	MOVE.w	D1, (A1)+ ; stores: Team_car_acceleration, Team_car_engine_data, Track_steering_index, Track_steering_index_b, Track_braking_index
	DBF	D0, Load_team_machine_stats_Char_loop
	MOVE.w	#$0014, Tire_accel_durability.w
	MOVE.w	#$0014, Tire_engine_durability.w
	MOVE.w	#$0014, Tire_steering_durability.w
	MOVE.w	#$0014, Tire_braking_durability_b.w
	MOVE.w	#$0014, Tire_braking_durability_a.w
	MOVE.w	#$00F0, Tire_collision_brake_timer.w
	MOVE.w	#$0028, Tire_road_marker_brake_timer.w
	CLR.w	Tire_wear_degrade_level.w
	TST.w	Use_world_championship_tracks.w
	BEQ.b	Load_team_car_data_Rts
	TST.w	Practice_mode.w
	BNE.b	Load_team_car_data_Rts
;locx_13152:
Load_team_car_data:
	MOVE.w	Team_car_acceleration.w, D0
	LEA	Acceleration_modifiers(PC), A1
	MOVE.w	(A1,D0.w), Acceleration_modifier.w
	MOVE.w	Team_car_engine_data.w, D0
	LEA	Engine_data_offset_table(PC), A1
	MOVE.w	(A1,D0.w), Engine_data_offset.w
Load_team_car_data_Rts:
	RTS
Save_player_state_to_buffer:
	LEA	Player_state_save_buf.w, A1
	MOVE.w	#$003F, D7
Save_player_state_clear_loop:
	CLR.b	(A1)+
	DBF	D7, Save_player_state_clear_loop
	LEA	Player_state_save_buf.w, A1
	LEA	Player_state_flags.w, A2
	MOVE.w	#$0024, D7
Save_player_state_lo_loop:
	MOVE.b	(A2)+, D0
	ANDI.b	#$1F, D0
	MOVE.b	D0, (A1)+
	DBF	D7, Save_player_state_lo_loop
	LEA	Player_state_flags.w, A2
	MOVE.w	#$0012, D7
Save_player_state_hi_loop:
	MOVE.b	(A2)+, D0
	LSR.b	#5, D0
	ANDI.b	#7, D0
	MOVE.b	(A2)+, D1
	LSR.b	#2, D1
	ANDI.b	#$38, D1
	ADD.b	D1, D0
	MOVE.b	D0, (A1)+
	DBF	D7, Save_player_state_hi_loop
	MOVE.b	Track_index_b.w, (A1)+
	MOVE.l	Saved_frame_callback.w, D0
	CMPI.l	#$0000D6E2, D0
	BEQ.b	Save_mode_standings
	CMPI.l	#Title_menu, D0
	BEQ.b	Save_mode_title
	CMPI.l	#Championship_mode_init, D0
	BEQ.b	Save_mode_championship
	MOVE.b	#4, (A1)+
	BRA.b	Finalize_save_data_buffer
Save_mode_championship:
	MOVE.b	#3, (A1)+
	BRA.b	Finalize_save_data_buffer
Save_mode_title:
	MOVE.b	#2, (A1)+
	BRA.b	Finalize_save_data_buffer
Save_mode_standings:
	MOVE.b	#1, (A1)+
Finalize_save_data_buffer:
	BSR.w	Compute_save_data_checksum
	MOVE.b	D1, D0
	ANDI.b	#$0F, D0
	MOVE.b	D0, Save_checksum_nibble_3.w
	LSR.b	#4, D1
	MOVE.b	D1, Save_checksum_nibble_2.w
	MOVE.b	D2, D0
	ANDI.b	#$0F, D0
	MOVE.b	D0, Save_checksum_nibble_1.w
	LSR.b	#4, D2
	MOVE.b	D2, Save_checksum_nibble_0.w
	ANDI.b	#$0F, Player_state_flags.w
	RTS
Load_player_state_from_buffer:
	LEA	Player_state_flags.w, A1
	MOVE.w	#$0024, D7
Load_player_state_clear_loop:
	CLR.b	(A1)+
	DBF	D7, Load_player_state_clear_loop
	CLR.w	Track_index.w
	CLR.l	Saved_frame_callback.w
	LEA	Player_state_save_buf.w, A1
	LEA	Player_state_flags.w, A2
	MOVE.w	#$0024, D7
Load_player_state_copy_loop:
	MOVE.b	(A1)+, D0
	MOVE.b	D0, (A2)+
	DBF	D7, Load_player_state_copy_loop
	LEA	Player_state_flags.w, A2
	MOVE.w	#$0012, D7
Load_player_state_hi_loop:
	MOVE.b	(A1), D0
	ANDI.b	#7, D0
	LSL.b	#5, D0
	ADD.b	D0, (A2)+
	MOVE.b	(A1)+, D0
	ANDI.b	#$38, D0
	LSL.b	#2, D0
	ADD.b	D0, (A2)+
	DBF	D7, Load_player_state_hi_loop
	MOVE.b	(A1)+, Track_index_b.w
	MOVE.b	(A1)+, D0
	CMPI.b	#1, D0
	BEQ.b	Load_mode_standings
	CMPI.b	#2, D0
	BEQ.b	Load_mode_title
	CMPI.b	#3, D0
	BEQ.b	Load_mode_championship
	MOVE.l	#0, Saved_frame_callback.w
	BRA.b	Restore_saved_frame_callback
Load_mode_championship:
	MOVE.l	#Championship_mode_init, Saved_frame_callback.w
	BRA.b	Restore_saved_frame_callback
Load_mode_title:
	MOVE.l	#Title_menu, Saved_frame_callback.w
	BRA.b	Restore_saved_frame_callback
Load_mode_standings:
	MOVE.l	#Championship_standings_init, Saved_frame_callback.w
Restore_saved_frame_callback:
	RTS
;Compute_save_data_checksum
Compute_save_data_checksum:
	LEA	Player_state_save_buf.w, A0
	MOVE.w	#$001C, D0
	MOVE.b	#0, D1
	MOVE.b	#0, D2
Compute_save_data_checksum_loop:
	MOVE.b	D2, D3
	MOVE.b	(A0), D4
	EOR.b	D4, D3
	MOVE.b	D3, D2
	ADDA.l	#1, A0
	MOVE.b	D1, D3
	MOVE.b	(A0), D4
	EOR.b	D4, D3
	MOVE.b	D3, D1
	ADDA.l	#1, A0
	LSR.b	#1, D1
	ROXR.b	#1, D2
	BCC.b	Compute_save_data_checksum_next
	MOVE.b	D1, D3
	EORI.b	#$88, D3
	MOVE.b	D3, D1
	MOVE.b	D2, D3
	EORI.b	#$10, D3
	MOVE.b	D3, D2
Compute_save_data_checksum_next:
	DBF	D0, Compute_save_data_checksum_loop
	RTS
PointsAwardedPerPlacement:
; Points earned by finishing 1st through 6th in a race
; (positions 7th and beyond score 0)
	dc.b 9, 6, 4, 3, 2, 1
Ai_performance_factor_by_team:
; Per-team AI performance multiplier used by Initialize_standings_order_buffer.
; Indexed by team number (0=Madonna best, 15=Zero Force worst).
; Final score = Ai_performance_table[team*8 + rng(0-7)] * factor
; Higher factor → team appears higher in standings display more consistently.
	dc.b	$0F, $0D, $0C, $0B, $0A, $0A, $0A, $0A, $08, $08, $08, $08, $02, $02, $01, $01
Ai_performance_table:
; Base score table for standings display (not actual race AI speed).
; Each team has 8 entries (indexed by random 3-bit value).
; Multiplied by Ai_performance_factor_by_team to produce the final
; sort score used by Initialize_standings_order_buffer.
; Teams 0-3 (top): high base scores; teams 12-15 (bottom): near-zero scores.
; Indexed as: Ai_performance_table[team * 8 + rng_low_3bits]
; 16 teams × 8 entries = 128 bytes
	dc.b	$06, $06, $06, $06, $09, $09, $09, $09 ; team 0: Madonna
	dc.b	$01, $02, $03, $04, $06, $06, $09, $09 ; team 1: Firenze
	dc.b	$01, $02, $02, $03, $04, $06, $06, $09 ; team 2: Millions
	dc.b	$01, $01, $02, $03, $03, $04, $06, $09 ; team 3: Bestowal
	dc.b	$00, $01, $02, $02, $03, $04, $04, $06 ; team 4: Blanche
	dc.b	$00, $00, $01, $01, $02, $03, $03, $09 ; team 5: Tyrant
	dc.b	$00, $00, $01, $01, $02, $02, $03, $03 ; team 6: Losel
	dc.b	$00, $00, $00, $01, $01, $01, $02, $02 ; team 7: May
	dc.b	$00, $00, $00, $00, $00, $00, $00, $02 ; team 8: Bullets
	dc.b	$00, $00, $01, $01, $01, $01, $01, $01 ; team 9: Dardan
	dc.b	$01, $01, $01, $01, $01, $01, $01, $01 ; team 10: Linden
	dc.b	$00, $00, $00, $00, $00, $00, $01, $01 ; team 11: Minarae
	dc.b	$00, $02, $02, $03, $06, $09, $09, $09 ; team 12: Rigel (wild card — high peak scores)
	dc.b	$00, $00, $00, $01, $01, $01, $01, $01 ; team 13: Comet
	dc.b	$01, $01, $01, $01, $02, $02, $03, $03 ; team 14: Orchis
	dc.b	$00, $00, $00, $00, $01, $01, $01, $01 ; team 15: Zero Force
InitialDriversAndTeamMap:
; Copied into Player_team..Drivers_and_teams_map at championship start (year 1).
; Byte 0: Player_team ($1B = team 11 / Minarae, no rival flag set)
; Bytes 1-16: team assignment for each of the 16 non-player driver slots
;   (each byte = team index 0-15; driver slot 11/$0B = 0 = Madonna rival)
; Byte 17: Rival_team initial value ($00 = none)
	dc.b	$1B ; Player starting team (year 1: Minarae, team 11)
	dc.b	$01, $02, $03, $04, $05, $06, $07, $08, $09, $0A, $0B, $00, $0C, $0D, $0E, $0F ; driver→team map
	dc.b	$00 ; Rival_team = none initially
SecondYearDriversAndTeamsMap:
; Copied into Player_team..Drivers_and_teams_map at championship start (year 2,
; when bit 6 of Player_team is set).  Shuffles teams relative to year 1.
; Byte 0: Player_team ($50 = bit 6 set + team 0 / Madonna, year-2 livery flag)
; Bytes 1-16: driver→team map for year 2 lineup
; Byte 17: Rival_team initial value ($00 = none)
	dc.b	$50 ; Player starting team (year 2: Madonna, team 0, year-2 flag)
	dc.b	$50, $0D, $05, $03, $06, $02, $07, $0B, $01, $04, $0C, $0F, $0A, $08, $09, $0E ; driver→team map
	dc.b	$00 ; Rival_team = none initially
Team_engine_multiplier:
; Tire wear base multiplier indexed by team number (0-15).
; Value 1 or 2. Written to Tire_steering_wear_rate, Tire_braking_wear_rate_full,
; and Tire_steering_wear_rate. Doubled for Tire_engine_wear_rate and base
; Tire_accel_wear_rate. Teams with value 2 have 2× baseline tire wear.
	dc.b	$01, $01, $01, $01, $02, $01, $02, $02, $02, $01, $02, $01, $02, $02, $02, $02
Team_car_characteristics:
; 5 bytes per team (16 teams), loaded by Load_team_machine_stats into:
;   byte 0 → Team_car_acceleration  (index into Acceleration_modifiers: 0-3 → -25%/0/+25%/+50%)
;   byte 1 → Team_car_engine_data   (index into Engine_data_offset_table: 0-5 → row offset in Engine_data)
;   byte 2 → Track_steering_index   (steering sensitivity selector for straight sections)
;   byte 3 → Track_steering_index_b (steering sensitivity selector for curved sections)
;   byte 4 → Track_braking_index    (braking track-quality modifier selector)
	dc.b	$06, $0A, $06, $08, $0A ; Madonna
	dc.b	$04, $0A, $08, $08, $0A ; Firenze
	dc.b	$06, $08, $08, $06, $0A ; Millions
	dc.b	$06, $06, $08, $08, $0A ; Bestowal
	dc.b	$04, $08, $06, $06, $08 ; Blanche
	dc.b	$02, $0A, $04, $06, $0A ; Tyrant
	dc.b	$06, $06, $06, $06, $08 ; Losel
	dc.b	$02, $08, $04, $04, $08 ; May
	dc.b	$02, $06, $04, $04, $06 ; Bullets
	dc.b	$04, $06, $04, $04, $04 ; Dardan
	dc.b	$04, $04, $06, $06, $08 ; Linden
	dc.b	$04, $06, $02, $04, $04 ; Minarae
	dc.b	$06, $04, $04, $04, $04 ; Rigel
	dc.b	$04, $04, $04, $02, $04 ; Comet
	dc.b	$02, $04, $02, $04, $04 ; Orchis
	dc.b	$04, $04, $04, $04, $02 ; Zero Force
Acceleration_modifiers:
; Signed word adjustment to acceleration RPM delta, indexed by Team_car_acceleration (0-3).
; Applied in Update_rpm when computing the team-specific acceleration boost/penalty.
; Values: index 0→-1 (slow/penalty), 1→0 (baseline), 2→+2 (fast), 3→+1 (medium boost)
	dc.w	-1, 0, 2, 1
;locx_1340C:
Engine_data_offset_table:
; Byte offset into Engine_data for each team's engine variant, indexed by Team_car_engine_data (0-5).
; Each Engine_data row is $1E ($30 = 30) bytes: auto (4 words) + 4-shift (4 words) + 7-shift (7 words).
; Offset 0=$0000 (rows 0-2, strongest), $001E (rows 3-5), ... $0096 (rows 15-17, weakest practice variant).
	dc.w	$0000 ; variant 0 (strongest: e.g. Madonna/Firenze/Tyrant)
	dc.w	$001E ; variant 1
	dc.w	$003C ; variant 2 (Engine_data_offset_practice: default for practice/warm-up/attract)
	dc.w	$005A ; variant 3
	dc.w	$0078 ; variant 4
	dc.w	$0096 ; variant 5 (weakest)
;$00013418
Endgame_sequence_frame:
	JSR	Wait_for_vblank
	SUBQ.w	#1, Screen_state_word_1.w
	BCC.b	Endgame_frame_Rts
	ADDQ.w	#1, Screen_state_word_1.w
	SUBQ.w	#1, Temp_x_pos.w
	BCC.b	Endgame_frame_portrait_tick
	ADDQ.w	#1, Temp_x_pos.w
	BTST.b	#1, Screen_state_word_0.w
	BNE.w	Update_endgame_portrait_animation
	BTST.b	#2, Screen_state_word_0.w
	BNE.w	Update_endgame_portrait_animation
	CMPI.w	#$0090, (Aux_object_pool+$316).w
	BCC.b	Endgame_frame_music_trigger
	BTST.b	#5, Screen_state_word_0.w
	BNE.b	Endgame_frame_music_trigger
	BSET.b	#5, Screen_state_word_0.w
	MOVE.w	#Music_rival_encounter, Audio_music_cmd ; rival team encounter music
Endgame_frame_music_trigger:
	TST.l	(Aux_object_pool+$300).w
	BNE.b	Endgame_frame_scroll_update
	MOVE.l	#$0000E600, Frame_callback.w
Endgame_frame_scroll_update:
	BSR.b	Endgame_frame_update_scroll_right
	BSR.b	Endgame_frame_update_scroll_left
Endgame_frame_portrait_tick:
	BTST.b	#0, Screen_state_word_0.w
	BNE.w	Draw_endgame_portrait_tilemap_select
	BSR.w	Endgame_frame_copy_screen_data
Endgame_frame_Rts:
	RTS
Endgame_frame_update_scroll_right:
	BTST.b	#3, Screen_state_word_0.w
	BEQ.w	Endgame_scroll_right_inc
	BRA.w	Endgame_scroll_right_dec
Endgame_frame_update_scroll_left:
	BTST.b	#4, Screen_state_word_0.w
	BEQ.w	Endgame_scroll_left_dec
	BRA.w	Endgame_scroll_left_inc
Endgame_scroll_right_inc:
	LEA	(Screen_scroll_table_buf+$40).w, A1
	CLR.l	D7
	MOVE.w	Menu_cursor.w, D7
	LSL.l	#2, D7
	ADDA.l	D7, A1
	ADDI.w	#$0010, (A1)+
	ADDA.l	#2, A1
	ADDI.w	#$0010, (A1)
	CMPI.w	#$0060, (A1)
	BNE.b	Endgame_scroll_right_Rts
	ADDQ.w	#2, Menu_cursor.w
	CMPI.w	#$0050, Menu_cursor.w
	BNE.b	Endgame_scroll_right_Rts
	CLR.w	Menu_cursor.w
	BSET.b	#3, Screen_state_word_0.w
Endgame_scroll_right_Rts:
	RTS
Endgame_scroll_left_dec:
	LEA	(Screen_scroll_table_buf+$3E).w, A1
	CLR.l	D7
	MOVE.w	Menu_substate.w, D7
	LSL.l	#2, D7
	ADDA.l	D7, A1
	SUBI.w	#$0010, (A1)+
	ADDA.l	#2, A1
	SUBI.w	#$0010, (A1)
	CMPI.w	#$FFA0, (A1)
	BNE.b	Endgame_scroll_left_Rts
	SUBQ.w	#2, Menu_substate.w
	BNE.b	Endgame_scroll_left_Rts
	MOVE.w	#$0050, Menu_substate.w
	BSET.b	#4, Screen_state_word_0.w
Endgame_scroll_left_Rts:
	RTS
Endgame_scroll_right_dec:
	LEA	(Screen_scroll_table_buf+$40).w, A1
	CLR.l	D7
	MOVE.w	Menu_cursor.w, D7
	LSL.l	#2, D7
	ADDA.l	D7, A1
	SUBI.w	#$0010, (A1)+
	ADDA.l	#2, A1
	SUBI.w	#$0010, (A1)
	BNE.b	Endgame_scroll_right_dec_Rts
	ADDQ.w	#2, Menu_cursor.w
	CMPI.w	#$0050, Menu_cursor.w
	BNE.b	Endgame_scroll_right_dec_Rts
	CLR.w	Menu_cursor.w
	BCLR.b	#3, Screen_state_word_0.w
	BSET.b	#1, Screen_state_word_0.w
Endgame_scroll_right_dec_Rts:
	RTS
Endgame_scroll_left_inc:
	LEA	(Screen_scroll_table_buf+$3E).w, A1
	CLR.l	D7
	MOVE.w	Menu_substate.w, D7
	LSL.l	#2, D7
	ADDA.l	D7, A1
	ADDI.w	#$0010, (A1)+
	ADDA.l	#2, A1
	ADDI.w	#$0010, (A1)
	BNE.b	Endgame_scroll_left_inc_Rts
	SUBQ.w	#2, Menu_substate.w
	BNE.b	Endgame_scroll_left_inc_Rts
	MOVE.w	#$0050, Menu_substate.w
	BCLR.b	#4, Screen_state_word_0.w
	BSET.b	#2, Screen_state_word_0.w
Endgame_scroll_left_inc_Rts:
	RTS
Endgame_frame_copy_screen_data:
	LEA	Endgame_screen_copy_buf.w, A1
	MOVE.w	Screen_data_ptr.w, D0
	MOVE.w	#$0070, D7
Endgame_frame_copy_screen_data_loop:
	MOVE.l	D0, (A1)+
	DBF	D7, Endgame_frame_copy_screen_data_loop
	RTS
Endgame_star_obj:
	SUBQ.w	#1, $1A(A0)
	BNE.w	Endgame_star_obj_queue
	ADDQ.w	#1, $1A(A0)
	SUBI.l	#$00004000, $12(A0)
	MOVE.w	$12(A0), $16(A0)
	CMPI.w	#$0080, $16(A0)
	BNE.b	Endgame_star_obj_queue
	CLR.l	(A0)
Endgame_star_obj_queue:
	JSR	Queue_object_for_sprite_buffer
	RTS
;$000135C6
Championship_final_init:
	JSR	Halt_audio_sequence
	JSR	Fade_palette_to_black
	MOVE.w	#Music_championship_final, Audio_music_cmd ; championship final ending music
	MOVE.w	#$0400, (Palette_buffer+$60).w
	JSR	Wait_for_vblank
	JSR	Initialize_h40_vdp_state
	JSR	Clear_main_object_pool
	MOVE.w	#$8200, VDP_control_port
	MOVE.w	#$8C81, VDP_control_port
	MOVE.w	#$9003, VDP_control_port
	MOVE.w	#$9200, VDP_control_port
	MOVE.l	#$941F93FF, D6
	MOVE.l	#$40000080, D7
	JSR	Start_vdp_dma_fill
	LEA	Screen_scroll_table_buf.w, A1
	MOVE.w	#$00E0, D0
Championship_final_init_clear_loop:
	CLR.l	(A1)+
	DBF	D0, Championship_final_init_clear_loop
	BSR.w	Load_all_driver_portraits
	MOVE.l	#$5C200002, VDP_control_port
	LEA	Championship_final_tiles, A0
	JSR	Decompress_to_vdp
	LEA	Championship_final_tilemap, A0
	MOVE.w	#$64E1, D0
	JSR	Decompress_tilemap_to_buffer
	LEA	(Championship_logo_buf+$58).w, A1
	LEA	(Championship_logo_buf+$DC).w, A2
	MOVE.w	#$026C, D0
Championship_final_init_copy_loop:
	MOVE.w	-(A1), -(A2)
	DBF	D0, Championship_final_init_copy_loop
	MOVE.b	#$64, Screen_timer.w
	MOVE.b	#1, Screen_tick.w
	MOVE.l	#Endgame_sequence_frame, Frame_callback.w
	MOVE.l	#Endgame_vblank_handler, Vblank_callback.w
	LEA	Championship_final_star_data_table, A1
	MOVE.w	#$000B, D0
Championship_final_init_obj_loop:
	MOVE.w	D0, D1
	LEA	(Aux_object_pool+$40).w, A2
	MULS.w	#$0040, D1
	ADDA.l	D1, A2
	MOVE.l	#Endgame_star_obj, (A2)
	MOVE.w	#$011C, $18(A2)
	MOVE.w	#$0188, $12(A2)
	MOVE.w	#$0188, $16(A2)
	MOVE.w	#1, $E(A2)
	MOVE.w	D0, D1
	LSL.w	#2, D1
	MOVE.l	(A1,D1.w), D2
	MOVE.l	D2, $4(A2)
	MOVE.w	D0, D1
	LSL.w	#4, D1
	LSL.w	#5, D1
	ADDQ.w	#1, D1
	MOVE.w	D1, $1A(A2)
	DBF	D0, Championship_final_init_obj_loop
	LEA	Car_select_bg_vdp_stream, A6
	JSR	Copy_word_run_from_stream
	LEA	Championship_final_bg_palette, A1
	LEA	(Palette_buffer+$62).w, A2
	MOVE.w	#$000E, D0
Championship_final_init_palette_loop:
	MOVE.w	(A1)+, (A2)+
	DBF	D0, Championship_final_init_palette_loop
	MOVE.l	#$00000EEE, (Palette_buffer+$2).w
	MOVE.w	#$0400, (Palette_buffer+$60).w
	BSET.b	#1, Screen_state_word_0.w
	BSR.w	Update_endgame_portrait_animation
	MOVE.w	#0, Menu_cursor.w
	MOVE.w	#$0050, Menu_substate.w
	BSET.b	#4, Screen_state_word_0.w
	LEA	(Screen_scroll_table_buf+$3E).w, A1
	MOVE.w	#$0051, D0
Championship_final_init_scroll_loop:
	MOVE.w	#$FFA0, (A1)+
	ADDA.l	#2, A1
	DBF	D0, Championship_final_init_scroll_loop
	MOVE.w	#$049C, Temp_x_pos.w
	MOVE.w	#$020D, Screen_state_word_1.w
	ANDI	#$F8FF, SR
	JSR	Wait_for_vblank
	MOVE.w	#1, Vblank_enable.w
	MOVE.w	#$8174, VDP_control_port
	RTS
Load_all_driver_portraits:
	MOVE.w	#$000F, D0
Load_driver_portrait_loop:
	CLR.l	D1
	MOVE.w	D0, D1
	LEA	DriverPortraitTiles, A1
	LSL.l	#2, D1
	MOVEA.l	(A1,D1.w), A0
	MOVE.w	#$1C20, D7
	CLR.l	D1
	MOVE.w	D0, D1
	MULS.w	#$0800, D1
	ADD.w	D1, D7
	JSR	Tile_index_to_vdp_command
	MOVE.l	D7, VDP_control_port
	JSR	Decompress_to_vdp
	DBF	D0, Load_driver_portrait_loop
	RTS
Championship_final_bg_palette:
	dc.w	$0200, $0400, $0420, $0620, $0642, $0842, $0864, $0A64, $0A86, $0C86, $0CA8, $0ECA, $0EEC, $0EA8, $0000
Draw_endgame_portrait_tilemap_select:
	BCLR.b	#0, Screen_state_word_0.w
	LEA	(Tilemap_work_buf+$84).w, A6
	BTST.b	#0, Screen_flash_state.w
	BEQ.b	Draw_endgame_portrait_tilemap_draw
	LEA	(Tilemap_work_buf+$2F0).w, A6
Draw_endgame_portrait_tilemap_draw:
	MOVE.l	#$4F0A0003, D7
	MOVEQ	#$0000001E, D6
	MOVEQ	#9, D5
	ORI	#$0700, SR
	JSR	Draw_tilemap_buffer_to_vdp_128_cell_rows
	ANDI	#$F8FF, SR
	ADDQ.b	#1, Screen_flash_state.w
	RTS
Update_endgame_portrait_animation:
	BTST.b	#1, Screen_state_word_0.w
	BNE.b	Update_endgame_portrait_fade
	BCLR.b	#2, Screen_state_word_0.w
	BSR.w	Load_endgame_portrait_tilemap
	MOVE.w	#$20E1, D0
	MOVE.l	#$44520003, D7
	BSR.w	Draw_endgame_portrait_tilemap
	LEA	(Palette_buffer+$22).w, A1
	BSR.w	Copy_endgame_portrait_palette_strip
	ADDQ.b	#1, Screen_digit.w
	CMPI.b	#$10, Screen_digit.w
	BCS.b	Update_endgame_portrait_tick_a
	CLR.b	Screen_digit.w
Update_endgame_portrait_tick_a:
	RTS
Update_endgame_portrait_fade:
	BCLR.b	#1, Screen_state_word_0.w
	BSR.w	Load_endgame_portrait_tilemap
	MOVE.w	#$40E1, D0
	MOVE.l	#$44EE0000, D7
	BSR.w	Draw_endgame_portrait_tilemap
	LEA	(Palette_buffer+$42).w, A1
	BSR.w	Copy_endgame_portrait_palette_strip
	ADDQ.b	#1, Screen_digit.w
	CMPI.b	#$10, Screen_digit.w
	BCS.b	Update_endgame_portrait_tick_b
	CLR.b	Screen_digit.w
Update_endgame_portrait_tick_b:
	RTS
Load_endgame_portrait_tilemap:
	CLR.l	D0
	CLR.l	D1
	LEA	DriverPortraitTileMappings, A1
	MOVE.b	Screen_digit.w, D0
	LSL.l	#2, D0
	MOVEA.l	(A1,D0.w), A0
	MOVE.w	#7, D6
	MOVE.w	#7, D5
	MOVE.b	Screen_digit.w, D1
	MULS.w	#$0040, D1
	RTS
Draw_endgame_portrait_tilemap:
	ADD.w	D1, D0
	JSR	Decompress_tilemap_to_buffer
	LEA	Tilemap_work_buf.w, A6
	CMPI.w	#$00F0, (Aux_object_pool+$316).w
	BCC.b	Draw_endgame_portrait_vdp
	MOVE.w	#$0040, D0
Draw_endgame_portrait_clear_loop:
	CLR.w	(A6)+
	DBF	D0, Draw_endgame_portrait_clear_loop
	LEA	Tilemap_work_buf.w, A6
Draw_endgame_portrait_vdp:
	ORI	#$0700, SR
	JSR	Draw_tilemap_buffer_to_vdp_128_cell_rows
	ANDI	#$F8FF, SR
	RTS
Copy_endgame_portrait_palette_strip:
	CLR.l	D0
	MOVE.b	Screen_digit.w, D0
	LSL.l	#5, D0
	ADDQ.l	#2, D0
	LEA	Driver_portrait_palette_streams, A6
	ADDA.l	D0, A6
	MOVE.w	#$000E, D0
Copy_endgame_portrait_palette_loop:
	MOVE.w	(A6)+, (A1)+
	DBF	D0, Copy_endgame_portrait_palette_loop
	RTS
;$000138CE
Endgame_vblank_handler:
	JSR	Upload_h40_tilemap_buffer_to_vram
	JSR	Update_input_bitset
	JSR	Upload_palette_buffer_to_cram
	SUBQ.b	#1, Screen_tick.w
	BNE.b	Endgame_vblank_scroll
	BSET.b	#0, Screen_state_word_0.w
	MOVE.b	#3, Screen_tick.w
Endgame_vblank_scroll:
	MOVE.w	#$977F, D7
	MOVE.l	#$96CE95A0, D6
	MOVE.l	#$940193C0, D5
	MOVE.l	#$70000083, Vdp_dma_setup.w
	JSR	Send_D567_to_VDP
	ADDQ.b	#1, Screen_scroll.w
	MOVE.b	Screen_scroll.w, D0
	LSR.l	#1, D0
	ANDI.l	#1, D0
	ADD.w	D0, D0
	MOVE.w	D0, Screen_data_ptr.w
	TST.w	Temp_x_pos.w
	BEQ.w	Endgame_vblank_objects
	RTS
Endgame_vblank_objects:
	JSR	Update_objects_and_build_sprite_buffer
	RTS
Championship_final_star_data_table:
	dc.l	Championship_final_star_frames_0
	dc.l	Championship_final_star_frames_1
	dc.l	Championship_final_star_frames_2
	dc.l	Championship_final_star_frames_3
	dc.l	Championship_final_star_frames_4
	dc.l	Championship_final_star_frames_5
	dc.l	Championship_final_star_frames_6
	dc.l	Championship_final_star_frames_7
	dc.l	Championship_final_star_frames_8
	dc.l	Championship_final_star_frames_9
	dc.l	Championship_final_star_frames_10
	dc.l	Championship_final_star_frames_11
Championship_final_star_frames_0:
	dc.b	$00, $04, $EC, $00, $87, $DC, $FF, $F0, $EC, $00, $87, $DD, $FF, $F8, $EC, $00, $87, $CA, $00, $00, $EC, $00, $87, $CF, $00, $08, $EC, $00, $87, $CF, $00, $10
Championship_final_star_frames_1:
	dc.b	$00, $0F, $E0, $00, $87, $CD, $FF, $E4, $E0, $00, $87, $D2, $FF, $EC, $E0, $00, $87, $DB, $FF, $F4, $E0, $00, $87, $CE, $FF, $FC, $E0, $00, $87, $CC, $00, $04
	dc.b	$E0, $00, $87, $DD, $00, $0C, $E0, $00, $87, $D8, $00, $14, $E0, $00, $87, $DB, $00, $1C, $F0, $00, $87, $E0, $FF, $E0, $F0, $00, $87, $D2, $FF, $E8, $F0, $00
	dc.b	$87, $D5, $FF, $F0, $F0, $00, $87, $D5, $FF, $F8, $F0, $00, $87, $CC, $00, $08, $F0, $00, $87, $CA, $00, $10, $F0, $00, $87, $D7, $00, $18, $F0, $00, $87, $CE
	dc.b	$00, $20
Championship_final_star_frames_2:
	dc.b	$00, $0B, $E0, $00, $87, $CD, $FF, $E4, $E0, $00, $87, $CE, $FF, $EC, $E0, $00, $87, $DC, $FF, $F4, $E0, $00, $87, $D2, $FF, $FC, $E0, $00, $87, $D0
	dc.b	$00, $04, $E0, $00, $87, $D7, $00, $0C, $E0, $00, $87, $CE, $00, $14, $E0, $00, $87, $DB, $00, $1C, $F0, $00, $87, $D4, $FF, $F4, $F0, $00, $87, $CA, $FF, $FC
	dc.b	$F0, $00, $87, $D4, $00, $04, $F0, $00, $87, $D2, $00, $0C
Championship_final_star_frames_3:
	dc.b	$00, $0F, $E0, $00, $87, $DC, $FF, $CC, $E0, $00, $87, $D8, $FF, $D4, $E0, $00, $87, $DE, $FF, $DC
	dc.b	$E0, $00, $87, $D7, $FF, $E4, $E0, $00, $87, $CD, $FF, $EC, $E0, $00, $87, $CE, $FF, $FC, $E0, $00, $87, $CF, $00, $04, $E0, $00, $87, $CF, $00, $0C, $E0, $00
	dc.b	$87, $CE, $00, $14, $E0, $00, $87, $CC, $00, $1C, $E0, $00, $87, $DD, $00, $24, $E0, $00, $87, $CB, $00, $34, $E0, $00, $87, $E2, $00, $3C, $F0, $00, $87, $D7
	dc.b	$FF, $F8, $F0, $00, $87, $CA, $00, $00, $F0, $00, $87, $D8, $00, $08
Championship_final_star_frames_4:
	dc.b	$00, $0E, $E0, $00, $87, $D6, $FF, $CC, $E0, $00, $87, $DE, $FF, $D4, $E0, $00, $87, $DC
	dc.b	$FF, $DC, $E0, $00, $87, $D2, $FF, $E4, $E0, $00, $87, $CC, $FF, $EC, $E0, $00, $87, $CC, $FF, $FC, $E0, $00, $87, $D8, $00, $04, $E0, $00, $87, $D6, $00, $0C
	dc.b	$E0, $00, $87, $D9, $00, $14, $E0, $00, $87, $D8, $00, $1C, $E0, $00, $87, $DC, $00, $24, $E0, $00, $87, $CE, $00, $2C, $E0, $00, $87, $DB, $00, $34, $F0, $00
	dc.b	$87, $CB, $FF, $FC, $F0, $00, $87, $D8, $00, $04
Championship_final_star_frames_5:
	dc.b	$00, $15, $DE, $00, $87, $D9, $FF, $DC, $DE, $00, $87, $DB, $FF, $E4, $DE, $00, $87, $D8, $FF, $EC, $DE, $00
	dc.b	$87, $D0, $FF, $F4, $DE, $00, $87, $DB, $FF, $FC, $DE, $00, $87, $CA, $00, $04, $DE, $00, $87, $D6, $00, $0C, $DE, $00, $87, $D6, $00, $14, $DE, $00, $87, $CE
	dc.b	$00, $1C, $DE, $00, $87, $DB, $00, $24, $ED, $00, $87, $D1, $FF, $E8, $ED, $00, $87, $CA, $FF, $F0, $ED, $00, $87, $D6, $FF, $F8, $ED, $00, $87, $DD, $00, $08
	dc.b	$ED, $00, $87, $CA, $00, $10, $ED, $00, $87, $D4, $00, $18, $F8, $00, $87, $D6, $FF, $EC, $F8, $00, $87, $E9, $FF, $F4, $F8, $00, $87, $E0, $FF, $FC, $F8, $00
	dc.b	$87, $CA, $00, $04, $F8, $00, $87, $D4, $00, $0C, $F8, $00, $87, $CA, $00, $14
Championship_final_star_frames_6:
	dc.b	$00, $14, $E0, $00, $87, $CE, $FF, $CC, $E0, $00, $87, $D7, $FF, $D4, $E0, $00
	dc.b	$87, $D0, $FF, $DC, $E0, $00, $87, $D5, $FF, $E4, $E0, $00, $87, $D2, $FF, $EC, $E0, $00, $87, $DC, $FF, $F4, $E0, $00, $87, $D1, $FF, $FC, $E0, $00, $87, $CE
	dc.b	$00, $0C, $E0, $00, $87, $CD, $00, $14, $E0, $00, $87, $D2, $00, $1C, $E0, $00, $87, $DD, $00, $24, $E0, $00, $87, $D8, $00, $2C, $E0, $00, $87, $DB, $00, $34
	dc.b	$F0, $00, $87, $DC, $FF, $E4, $F0, $00, $87, $CA, $FF, $EC, $F0, $00, $87, $D4, $FF, $F4, $F0, $00, $87, $D2, $FF, $FC, $F0, $00, $87, $D7, $00, $0C, $F0, $00
	dc.b	$87, $E2, $00, $14, $F0, $00, $87, $CA, $00, $1C
Championship_final_star_frames_7:
	dc.b	$00, $12, $E0, $00, $87, $CA, $FF, $BA, $E0, $00, $87, $DC, $FF, $C2, $E0, $00, $87, $DC, $FF, $CA, $E0, $00
	dc.b	$87, $D2, $FF, $D2, $E0, $00, $87, $DC, $FF, $DA, $E0, $00, $87, $DD, $FF, $E2, $E0, $00, $87, $CA, $FF, $EA, $E0, $00, $87, $D7, $FF, $F2, $E0, $00, $87, $DD
	dc.b	$FF, $FA, $E0, $00, $87, $CD, $00, $0D, $E0, $00, $87, $D2, $00, $15, $E0, $00, $87, $DB, $00, $1D, $E0, $00, $87, $CE, $00, $25, $E0, $00, $87, $CC, $00, $2D
	dc.b	$E0, $00, $87, $DD, $00, $35, $E0, $00, $87, $D8, $00, $3D, $E0, $00, $87, $DB, $00, $45, $F0, $00, $87, $DC, $FF, $FC, $F0, $00, $87, $C2, $00, $04
Championship_final_star_frames_8:
	dc.b	$00, $10, $E0, $00, $87, $DD, $FF, $D8, $E0, $00, $87, $CE, $FF, $E0, $E0, $00, $87, $DC, $FF, $E8, $E0, $00, $87, $DD, $FF, $F0, $E0, $00, $87, $CD, $00, $00, $E0, $00
	dc.b	$87, $DB, $00, $08, $E0, $00, $87, $D2, $00, $10, $E0, $00, $87, $DF, $00, $18, $E0, $00, $87, $CE, $00, $20, $E0, $00, $87, $DB, $00, $28, $F0, $00, $87, $D4
	dc.b	$FF, $E8, $F0, $00, $87, $E2, $FF, $F0, $F0, $00, $87, $CA, $FF, $F8, $F0, $00, $87, $D6, $00, $00, $F0, $00, $87, $DE, $00, $08, $F0, $00, $87, $DB, $00, $10
	dc.b	$F0, $00, $87, $CA, $00, $18
Championship_final_star_frames_9:
	dc.b	$00, $15, $E0, $00, $87, $DC, $FF, $C0, $E0, $00, $87, $D9, $FF, $C8, $E0, $00, $87, $CE, $FF, $D0, $E0, $00, $87, $CC, $FF, $D8
	dc.b	$E0, $00, $87, $D2, $FF, $E0, $E0, $00, $87, $CA, $FF, $E8, $E0, $00, $87, $D5, $FF, $F0, $E0, $00, $87, $DD, $00, $00, $E0, $00, $87, $D1, $00, $08, $E0, $00
	dc.b	$87, $CA, $00, $10, $E0, $00, $87, $D7, $00, $18, $E0, $00, $87, $D4, $00, $20, $E0, $00, $87, $DC, $00, $28, $E0, $00, $87, $DD, $00, $38, $E0, $00, $87, $D8
	dc.b	$00, $40, $F0, $00, $87, $CB, $FF, $E8, $F0, $00, $87, $DB, $FF, $F0, $F0, $00, $87, $D8, $FF, $F8, $F0, $00, $87, $DC, $00, $00, $F0, $00, $87, $C4, $00, $08
	dc.b	$F0, $00, $87, $C0, $00, $10, $F0, $00, $87, $C0, $00, $18
Championship_final_star_frames_10:
	dc.b	$00, $00, $F8, $00, $00, $00, $00, $00
Championship_final_star_frames_11:
	dc.b	$00, $0F, $DE, $00, $87, $D9, $FF, $E4, $DE, $00, $87, $DB
	dc.b	$FF, $EC, $DE, $00, $87, $D8, $FF, $F4, $DE, $00, $87, $CD, $FF, $FC, $DE, $00, $87, $DE, $00, $04, $DE, $00, $87, $CC, $00, $0C, $DE, $00, $87, $CE, $00, $14
	dc.b	$DE, $00, $87, $CD, $00, $1C, $EB, $00, $87, $CB, $FF, $FC, $EB, $00, $87, $E2, $00, $04, $F8, $00, $87, $D1, $FF, $E8, $F8, $00, $87, $CA, $FF, $F0, $F8, $00
	dc.b	$87, $D6, $FF, $F8, $F8, $00, $87, $DD, $00, $08, $F8, $00, $87, $CA, $00, $10, $F8, $00, $87, $D4, $00, $18, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF
Championship_podium_text_jp:
	dc.b	$37, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $39, $3A, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32
	dc.b	$20, $0A, $17, $1D, $1C, $32, $22, $18, $1E, $3B, $3A, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $3B, $3A
	dc.b	$18, $17, $32, $1D, $11, $0E, $12, $1B, $32, $1D, $0E, $0A, $16, $29, $29, $29, $32, $32, $32, $3B
	dc.b	$3A, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $3B, $3A, $0C, $11, $0A, $17, $10, $0E, $32, $1D, $0E, $0A
	dc.b	$16, $1C, $2E, $32, $32, $32, $32, $32, $32, $3B, $3A, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $3B, $3A
	dc.b	$32, $32, $32, $22, $0E, $1C, $32, $32, $32, $32, $32, $17, $18, $32, $32, $32, $32, $32, $32, $3B
	dc.b	$3C, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3E, $00
Championship_podium_text_en:
	dc.b	$37, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $39, $3A, $22, $18, $1E, $26, $1B, $0E, $32, $18
	dc.b	$0F, $0F, $0E, $1B, $0E, $0D, $32, $0A, $32, $1C, $0E, $0A, $1D, $3B, $3A, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32
	dc.b	$32, $32, $32, $32, $3B, $3A, $0B, $22, $32, $1D, $0E, $0A, $16, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $3B, $3A, $32, $32, $32
	dc.b	$32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $3B, $3A, $20, $12, $15, $15, $32, $22, $18, $1E, $32, $0A, $0C, $0C
	dc.b	$0E, $19, $1D, $2E, $32, $32, $32, $32, $32, $3B, $3A, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32
	dc.b	$3B, $3A, $32, $32, $32, $32, $22, $0E, $1C, $32, $32, $32, $32, $32, $17, $18, $32, $32, $32, $32, $32, $32, $32, $3B
	dc.b	'<=====================>'
	dc.b	$00
Team_select_intro_car_tilemap:
	dc.b	$0B, $10, $FB, $43, $1D, $37, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $38, $39, $FC, $3A, $32, $1C, $0E, $15, $0E, $0C, $1D, $32
	dc.b	$1B, $12, $1F, $0A, $15, $2E, $32, $3B, $FC, $3A, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $3B, $FC, $3A, $32, $32, $32, $22
	dc.b	$0E, $1C, $32, $32, $32, $32, $17, $18, $32, $32, $32, $3B, $FC, $3C, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3E, $FF, $00
	dc.b	$47, $D8, $00, $00, $4E, $D8, $00, $00, $50, $EE, $00, $00, $47, $EE, $00, $00, $4E, $EE, $00, $00
	include "src/result_screen_lists.asm"
Race_finish_car_anim_a:
	dc.w	$0000, $0148, $0008, $0088
	dc.b	$00, $01, $4C, $1C, $00, $01, $47, $34, $00, $00, $01, $48, $00, $08, $00, $88, $00, $01, $4C, $24, $00, $01, $47, $40, $FE, $0A, $01, $4A, $00, $18, $00, $88
	dc.b	$00, $01, $4A, $6C, $00, $01, $47, $4C, $FE, $48, $01, $4A, $00, $18, $00, $88, $00, $01, $4A, $96, $00, $01, $47, $70, $FE, $18, $01, $4A, $00, $20, $00, $88
	dc.b	$00, $01, $4A, $C0, $00, $01, $47, $AC, $FE, $32, $01, $4A, $00, $20, $00, $88, $00, $01, $4A, $CE, $00, $01, $47, $B8, $FD, $F4, $01, $4A, $00, $20, $00, $88
	dc.b	$00, $01, $4A, $48, $00, $01, $47, $94, $FE, $56, $01, $4A, $00, $20, $00, $88, $00, $01, $4A, $48, $00, $01, $47, $A0, $FE, $3A, $01, $4A, $00, $10, $00, $58
	dc.b	$00, $01, $4B, $B0, $00, $01, $47, $C4, $FE, $39, $01, $4A, $00, $08, $00, $58, $00, $01, $4A, $48, $00, $01, $47, $FA, $FE, $68, $01, $46, $00, $01, $00, $44
	dc.b	$00, $01, $4B, $46, $00, $01, $48, $30, $FD, $E8, $01, $46, $00, $01, $00, $4C, $00, $01, $4A, $DC, $00, $01, $48, $4E
Race_finish_car_anim_b:
	dc.w	$0000, $0148, $0008, $FFFF
	dc.b	$00, $01, $4C, $1C, $00, $00, $00, $00, $00, $00, $01, $48, $00, $08, $FF, $FF, $00, $01, $4C, $24, $00, $00, $00, $00, $FE, $38, $01, $4A, $00, $10, $00, $60
	dc.b	$00, $01, $4B, $B0, $00, $01, $48, $6C, $00, $18, $00, $01, $4A, $48, $FF, $FF, $00, $01, $4C, $1C, $00, $18, $00, $01, $4A, $48, $FF, $FF, $00, $01, $4C, $24
	dc.b	$00, $04, $00, $01, $4A, $74, $00, $06, $00, $01, $4A, $88, $00, $06, $00, $01, $4A, $6C, $00, $04, $00, $01, $4A, $B2, $00, $04, $00, $01, $4A, $9E, $FF, $FF
	dc.b	$00, $01, $4A, $96, $00, $04, $00, $01, $4A, $9E, $00, $06, $00, $01, $4A, $B2, $00, $06, $00, $01, $4A, $96, $00, $04, $00, $01, $4A, $88, $00, $04, $00, $01
	dc.b	$4A, $74, $FF, $FF, $00, $01, $4A, $6C, $00, $0A, $00, $01, $4A, $48, $FF, $FF, $00, $01, $4A, $CE, $00, $0A, $00, $01, $4A, $48, $FF, $FF, $00, $01, $4A, $C0
	dc.b	$00, $10, $00, $01, $4A, $C0, $FF, $FF, $00, $01, $4A, $48, $00, $10, $00, $01, $4A, $CE, $FF, $FF, $00, $01, $4A, $48, $00, $04, $00, $01, $4B, $CA, $00, $04
	dc.b	$00, $01, $4B, $D8, $00, $0C, $00, $01, $4B, $CA, $0F, $FF, $00, $01, $4B, $B0, $00, $08, $00, $01, $4B, $CA, $00, $06, $00, $01, $4B, $D8, $00, $04, $00, $01
	dc.b	$4B, $CA, $00, $04, $00, $01, $4B, $B0, $FF, $FF, $00, $01, $4B, $E6, $00, $08, $00, $01, $4A, $48, $00, $0C, $00, $01, $4A, $50, $0F, $FF, $00, $01, $4A, $5E
	dc.b	$00, $08, $00, $01, $4A, $50, $FF, $FF, $00, $01, $4A, $48, $00, $04, $00, $01, $4B, $FA, $0F, $FF, $00, $01, $4C, $08, $00, $04, $00, $01, $4B, $FA, $FF, $FF
	dc.b	$00, $01, $4B, $E6, $00, $06, $00, $01, $4B, $5A, $00, $0C, $00, $01, $4B, $6E, $0F, $FF, $00, $01, $4B, $82, $00, $08, $00, $01, $4B, $6E, $FF, $FF, $00, $01
	dc.b	$4B, $9C, $00, $08, $00, $01, $4B, $04, $0F, $FF, $00, $01, $4B, $18, $00, $0C, $00, $01, $4B, $04, $00, $06, $00, $01, $4A, $F0, $FF, $FF, $00, $01, $4B, $32
	dc.b	$00, $05, $00, $01, $4B, $FA, $FF, $FF, $00, $01, $4C, $08
Team_name_display_strings:
	txt " MADONNA "
	txt " FIRENZE "
	txt "MILLIONS "
	txt "BESTOWAL "
	txt " BLANCHE "
	txt " TYRANT  "
	txt "  LOSEL  "
	txt "   MAY   "
	txt "BULLETS  "
	txt " DARDAN  "
	txt " LINDEN  "
	txt "MINARAE  "
	txt "  RIGEL  "
	txt "  COMET  "
	txt " ORCHIS  "
	txt "ZEROFORCE"
	txt " MADONNA... "
	txt " FIRENZE... "
	txt " MILLIONS..."
	txt " BESTOWAL..."
	txt " BLANCHE... "
	txt " TYRANT.... "
	txt " LOSEL....  "
	txt " MAY....    "
	txt " BULLETS... "
	txt " DARDAN.... "
	txt " LINDEN.... "
	txt " MINARAE... "
	txt " RIGEL....  "
	txt " COMET....  "
	txt " ORCHIS.... "
	txt "ZEROFORCE..."
	include "src/result_sprite_anim_data.asm"
	include "src/result_screen_assets.asm"
	include "src/result_screen_tiles_b.asm"
	include "src/driver_standings_data.asm"
	dc.l	$669A0003
	include "src/car_spec_text_data.asm"
	include "src/car_select_metadata.asm"
	include "src/driver_portrait_tilemaps.asm"
	include "src/driver_portrait_tiles.asm"
Team_select_scrollbar_tilemap:
	dc.b	$0A, $03, $00, $00, $00, $00, $01, $61, $9F, $19, $C1, $E0, $20, $98, $6C, $98, $C9, $8C, $09, $00, $0D
	dc.b	$C2
	dc.b	$80, $06
	dc.b	$E0
	dc.b	$C0, $03, $70, $1E, $0E, $00, $02
	dc.b	$04
	dc.b	$E9, $0C, $9C, $B9, $CB, $1E, $B8, $D0, $00, $DC, $08, $00, $6E, $23, $81, $A0, $32, $E7, $26, $78, $49, $40, $48, $E3, $C2, $48, $F0, $D2, $81, $0D
	dc.b	$C0
	dc.b	$A0, $4C, $00, $89, $0D, $B0, $D3, $0D, $62, $90, $0D, $33, $C2, $48, $F0, $D0, $3C, $54, $0F, $11, $B0, $91, $11, $93, $14, $3C, $24, $CF, $09, $23, $C0, $80
	dc.b	$10
	dc.b	$40
	dc.b	$A2, $78, $08, $02, $E8, $0F, $A6, $33, $21, $A0, $4A, $E7, $2E, $64, $00, $37, $01, $73, $1F, $44, $07, $D3, $11, $D3, $19, $31, $93, $18, $0E, $09, $14
	dc.b	$85
	dc.b	$04, $8A
	dc.b	$42
	dc.b	$7F, $82, $DC
	dc.b	$BE
	dc.b	$8E, $65, $C0, $77, $4A, $E7
	dc.b	$21
	dc.b	$8D, $71
	dc.b	$17
	dc.b	$DC, $BB
	dc.b	$AB
	dc.b	$F1, $5E, $B0, $37, $D2, $BD
	dc.b	$5C
	dc.b	$87, $81, $77
	dc.b	$D7
	dc.b	$79, $9C, $6B, $F1, $C0, $7D
	dc.b	$33
	dc.b	$AF, $9A, $B8, $95, $7F, $88, $AE
	dc.b	$2A
	dc.b	$DA, $38, $95, $69, $CD, $8A, $D8, $C6, $F5, $7F, $C4, $AD
	dc.b	$E9
	dc.b	$EF, $59, $2C, $4B, $04, $9E, $15, $A5, $E0, $10
	dc.b	$5B
	dc.b	$D6, $8F, $82, $C9
	dc.b	$A7
	dc.b	$85, $6E
	dc.b	$10
	dc.b	$DE, $B6
	dc.b	$DC
	dc.b	$56, $98, $00
	dc.b	$31
	dc.b	$A7, $B2, $78, $D3, $C9, $AC, $6A, $0A, $86, $A5, $01, $5B, $3A, $8C
	dc.b	$70
	dc.b	$11, $0D, $2A, $1E, $9E, $45, $2C, $E0, $24
	dc.b	$F9
	dc.b	$14, $9B, $80, $90
	dc.b	$E7
	dc.b	$52, $04, $B7, $AA, $16, $55, $32, $47, $42, $AB
	dc.b	$F0
	dc.b	$14, $EC, $6A, $9B, $C0, $52
	dc.b	$71
	dc.b	$AA, $47, $21, $44, $54, $30, $00, $CC, $92
	dc.b	$A8
	dc.b	$63, $48, $E6, $B7, $25, $22, $F8, $52, $DF, $98, $5A
	dc.b	$A5
	dc.b	$A2, $59
	dc.b	$85
	dc.b	$96, $C4, $B1, $4F, $7A, $65
	dc.b	$62
	dc.b	$4B, $AE, $01, $1C, $96, $F4, $DE, $C6, $99
	dc.b	$C9
	dc.b	$E3, $4E, $EE, $01, $13, $A5, $3A
	dc.b	$90
	dc.b	$C2, $9C
	dc.b	$1C
	dc.b	$31, $B9, $6C, $48, $8D, $C1, $01
	dc.b	$31
	dc.b	$A2, $1B, $DA, $11, $3D, $BC, $68, $BD, $C0, $16
	dc.b	$B4
	dc.b	$A2, $CA, $FB, $91, $B5, $7D, $E8, $FA, $B7, $14, $8A, $08, $9C, $49, $11, $D4, $0D
	dc.b	$D2
	dc.b	$14, $0D
	dc.b	$D2
	dc.b	$11, $20
	dc.b	$C2
	dc.b	$0B, $1A, $40
	dc.b	$A9
	dc.b	$FC
Car_stats_bar_tilemap:
	dc.b	$0A, $00, $02, $30, $02, $30, $3F, $F8
Car_stats_deco_tiles:
	dc.b	$02, $46, $80, $06, $26, $16, $28, $26, $31, $37, $67, $47, $5F, $57, $70, $67, $72, $74, $03, $81, $04, $02, $15, $0D, $25, $10, $36, $29, $46, $2B, $56, $34
	dc.b	$66, $30, $75, $0B, $83, $07, $6A, $18, $EB, $84, $03, $00, $15, $0C, $26, $2E, $37, $6B, $47, $6D, $58, $DF, $68, $F4, $77, $5E, $85, $06, $23, $18, $F0, $86
	dc.b	$05, $12, $17, $66, $27, $6E, $38, $EA, $48, $F1, $58, $EF, $68, $E6, $76, $32, $87, $06, $27, $17, $74, $28, $F3, $38, $F7, $78, $DE, $88, $05, $0E, $16, $22
	dc.b	$26, $2A, $37, $6C, $48, $EE, $57, $71, $68, $F6, $75, $0F, $89, $05, $0A, $16, $2D, $27, $76, $38, $F2, $78, $E7, $8A, $04, $04, $16, $2C, $28, $F5, $FF, $33
	dc.b	$33, $33, $33, $33, $3C, $F2, $AB, $3C, $94, $E2, $CF, $25, $38, $B3, $C9, $14, $59, $E4, $2D, $33, $37, $B5, $D0, $71, $54, $55, $41, $50, $51, $28, $94, $5D
	dc.b	$88, $CC, $DE, $D7, $43, $B8, $9C, $51, $35, $44, $A2, $53, $94, $4A, $85, $A6, $66, $F7, $BD, $4E, $53, $94, $E5, $3B, $9C, $CC, $DF, $54, $1C, $55, $15, $44
	dc.b	$A7, $2A, $0A, $2F, $E4, $92, $88, $CC, $DE, $D7, $41, $C5, $51, $55, $05, $41, $45, $D8, $94, $4A, $23, $33, $D9, $AB, $16, $B9, $52, $C5, $C4, $E4, $96, $2A
	dc.b	$25, $24, $B1, $6A, $84, $B9, $48, $28, $B3, $F5, $67, $94, $F9, $B3, $C8, $74, $CF, $2B, $B3, $C8, $37, $3C, $81, $5F, $90, $29, $9A, $A8, $28, $B2, $CB, $7A
	dc.b	$F2, $CF, $96, $A6, $A8, $94, $56, $E5, $96, $F5, $E5, $DF, $54, $5A, $B1, $55, $5C, $F9, $65, $BD, $79, $71, $53, $B0, $9D, $A8, $B5, $3B, $B4, $14, $59, $65
	dc.b	$BD, $79, $71, $2A, $FD, $4A, $C7, $53, $55, $05, $16, $59, $6F, $5E, $59, $EA, $E4, $A2, $50, $96, $3B, $A7, $96, $39, $BA, $4B, $1F, $32, $96, $37, $14, $B1
	dc.b	$80, $95, $F2, $12, $BE, $42, $46, $66, $77, $67, $65, $98, $B1, $3C, $31, $62, $78, $50, $4C, $F5, $33, $3B, $D1, $A4, $69, $FF, $5F, $DA, $A4, $69, $1D, $91
	dc.b	$A0, $41, $60, $B0, $CC, $F6, $B6, $64, $8D, $2E, $6F, $ED, $43, $7F, $74, $C2, $B0, $23, $1A, $85, $9E, $40, $AF, $C8, $15, $F9, $02, $BF, $21, $16, $79, $0B
	dc.b	$69, $95, $D4, $C8, $69, $20, $47, $A8, $CD, $FC, $F7, $97, $C1, $4E, $D5, $29, $AD, $AA, $8B, $76, $4C, $A7, $F1, $E7, $BC, $BD, $9D, $51, $13, $B5, $16, $AA
	dc.b	$8A, $5A, $8B, $54, $52, $29, $6A, $2D, $4F, $77, $3D, $E5, $E6, $2C, $C5, $9B, $62, $A6, $96, $AE, $E5, $51, $DD, $6C, $CF, $E7, $BC, $BF, $1A, $A8, $21, $2B
	dc.b	$E4, $25, $7C, $84, $B1, $A8, $4B, $1E, $C2, $53, $37, $5C, $B4, $12, $85, $04, $25, $03, $33, $A2, $17, $52, $C4, $04, $20, $C4, $21, $06, $21, $0A, $58, $66
	dc.b	$6C, $26, $13, $10, $7A, $8F, $E5, $47, $EB, $FF, $58, $EC, $F0, $48, $D2, $33, $33, $D7, $9C, $58, $CC, $63, $F5, $8C, $51, $FB, $54, $14, $24, $69, $1A, $33
	dc.b	$12, $62, $32, $82, $DB, $41, $6D, $A0, $B6, $D0, $5B, $68, $2D, $B4, $16, $DA, $0A, $F6, $B4, $BD, $7A, $F5, $EB, $D7, $AF, $6B, $6A, $15, $CD, $61, $5C, $D4
	dc.b	$05, $73, $63, $6D, $CD, $46, $DC, $D0, $DB, $AB, $B9, $A9, $A4, $81, $39, $A0, $A4, $0A, $4D, $05, $20, $52, $26, $14, $81, $4E, $41, $B2, $1A, $48, $69, $21
	dc.b	$A4, $81, $4E, $FC, $B2, $FE, $3E, $E8, $7B, $AD, $75, $CF, $0C, $B2, $CA, $49, $3A, $D6, $B5, $D7, $98, $B3, $17, $53, $41, $66, $49, $C1, $4E, $53, $A6, $81
	dc.b	$75, $B2, $96, $46, $20, $CF, $00, $DC, $B2, $F1, $D5, $9A, $B9, $F3, $2D, $70, $62, $E0, $FC, $B2, $DE, $2F, $F3, $D6, $17, $48, $68, $E9, $11, $09, $42, $4E
	dc.b	$21, $22, $05, $98, $84, $A1, $D0, $84, $88, $34, $10, $95, $20, $84, $AE, $20, $42, $50, $9C, $10, $95, $21, $A0, $98, $42, $9B, $A9, $04, $2B, $04, $30, $15
	dc.b	$82, $15, $82, $15, $82, $62, $31, $18, $97, $AF, $5E, $BD, $7A, $F5, $EB, $07, $A8, $99, $37, $E6, $F4, $9B, $D2, $6F, $49, $BD, $26, $F4, $9B, $D3, $12, $DB
	dc.b	$41, $6D, $A0, $B6, $D0, $5B, $68, $D2, $8D, $28, $D2, $8D, $2F, $5E, $BC, $0A, $E2, $B9, $A1, $6B, $5D, $37, $35, $1B, $75, $77, $57, $73, $52, $0C, $6A, $60
	dc.b	$98, $33, $04, $AE, $43, $49, $D6, $5D, $29, $9C, $BA, $53, $3A, $74, $C2, $78, $74, $D3, $CD, $BE, $74, $85, $B7, $A2, $04, $2E, $8D, $40, $DF, $7A, $7A, $26
	dc.b	$1B, $EB, $10, $D7, $4E, $DA, $D8, $B5, $AD, $77, $46, $23, $04, $0A, $3F, $C7, $75, $FE, $38, $12, $7F, $39, $0A, $CF, $D7, $24, $07, $83, $1A, $C8, $D9, $0B
	dc.b	$AB, $65, $22, $00, $B5, $F8, $0A, $C2, $D6, $BC, $02, $D6, $D1, $01, $18, $87, $42, $62, $CA, $3F, $3A, $44, $6B, $8E, $7A, $C1, $0A, $42, $E1, $38, $21, $28
	dc.b	$06, $89, $F4, $09, $0F, $EB, $B7, $CD, $84, $0A, $E2, $0B, $9C, $56, $3A, $68, $08, $60, $30, $04, $20, $20, $20, $17, $80, $C0, $36, $F5, $ED, $F6, $B1, $6B
	dc.b	$5A, $F4, $F4, $9B, $5B, $44, $C0, $85, $33, $61, $36, $13, $61, $36, $13, $60, $66, $66, $63, $83, $0C, $E8, $D2, $81, $5E, $35, $E3, $5E, $BA, $76, $C2, $8B
	dc.b	$A0, $6B, $5A, $D6, $B5, $AC, $F4, $4C, $02, $D6, $B5, $AC, $8E, $1E, $6B, $A4, $2D, $64, $17, $09, $AE, $20, $D3, $C0, $2D, $6B, $5A, $D6, $61, $A3, $F6, $AB
	dc.b	$5A, $D6, $B5, $9E, $B8, $D6, $B5, $AD, $6B, $81, $88, $0E, $95, $86, $8A, $EE, $AD, $19, $58, $20, $BA, $75, $9D, $22, $0C, $68, $80, $80, $80, $5A, $F0, $66
	dc.b	$87, $84, $D8, $4D, $84, $DA, $51, $5E, $35, $E3, $49, $99, $99, $9E, $2E, $E4, $EE, $4E, $E4, $E3, $33, $D9, $96, $59, $65, $24, $CC, $66, $6F, $83, $A0, $E2
	dc.b	$A8, $AA, $83, $A0, $EB, $49, $45, $D8, $CC, $DF, $07, $41, $C5, $51, $38, $9D, $07, $13, $89, $C4, $A2, $54, $14, $66, $6F, $D9, $0E, $E2, $A9, $4E, $53, $A0
	dc.b	$EF, $EC, $92, $8C, $CD, $F0, $74, $1C, $55, $15, $50, $74, $1C, $5D, $89, $44, $A3, $33, $E3, $44, $22, $95, $04, $E2, $72, $A5, $41, $38, $AD, $95, $10, $52
	dc.b	$48, $CC, $CC, $CE, $67, $5F, $53, $8A, $89, $6A, $53, $88, $72, $76, $75, $55, $8A, $B5, $39, $4E, $A1, $5D, $6A, $8A, $85, $4A, $7D, $9A, $A5, $3A, $AA, $24
	dc.b	$E3, $67, $19, $24, $AC, $2D, $C0, $A4, $CD, $C8, $13, $29, $4F, $96, $59, $65, $99, $AA, $82, $8B, $29, $F9, $B7, $AF, $2F, $BB, $AF, $DB, $AD, $AA, $25, $15
	dc.b	$B9, $65, $BD, $79, $6A, $E5, $12, $AF, $F3, $E5, $96, $F5, $E5, $B4, $37, $16, $86, $E3, $DA, $0A, $2C, $B2, $DE, $BC, $B3, $36, $AA, $0A, $2C, $B2, $DE, $BC
	dc.b	$BC, $F4, $E7, $A5, $44, $AB, $25, $47, $7D, $1D, $53, $CA, $8F, $71, $2A, $2E, $21, $2A, $20, $C9, $50, $5A, $E5, $46, $D9, $19, $99, $F0, $24, $8D, $31, $42
	dc.b	$1E, $18, $D8, $2C, $C4, $92, $E3, $33, $38, $EC, $66, $3F, $C5, $14, $7F, $28, $51, $BE, $66, $73, $0E, $00, $AF, $82, $4B, $E2, $CB, $E8, $49, $9C, $90, $81
	dc.b	$9D, $E6, $25, $C8, $09, $91, $D9, $1D, $97, $7E, $D5, $2E, $8D, $23, $B0, $AE, $8D, $23, $A2, $5A, $A5, $55, $16, $EC, $61, $32, $17, $59, $77, $ED, $6C, $8D
	dc.b	$3F, $EB, $FA, $54, $F0, $4F, $0B, $02, $31, $3D, $95, $DD, $D8, $AA, $52, $5A, $D5, $77, $06, $AA, $A5, $46, $CD, $8A, $F0, $66, $C4, $8D, $9B, $32, $CB, $2F
	dc.b	$19, $F2, $CD, $3F, $34, $FC, $DD, $3B, $F8, $E6, $D9, $D5, $57, $8D, $BC, $53, $FD, $37, $97, $3F, $36, $AC, $CA, $CF, $2E, $B9, $2B, $1C, $DD, $72, $9E, $87
	dc.b	$F3, $DE, $5F, $7C, $F0, $0D, $C5, $A1, $B8, $B4, $37, $17, $F3, $DE, $5D, $73, $99, $9D, $0F, $E7, $BC, $B3, $CF, $01, $9D, $AC, $CE, $57, $3F, $9E, $F2, $F3
	dc.b	$D3, $B6, $54, $6D, $95, $1B, $65, $46, $C1, $26, $79, $09, $7A, $48, $46, $DB, $A4, $C2, $D7, $22, $06, $66, $C4, $09, $18, $48, $D2, $34, $8D, $3F, $EB, $FC
	dc.b	$5B, $3F, $6A, $9E, $16, $46, $0C, $CC, $72, $B0, $5F, $FD, $28, $CF, $1A, $78, $0C, $6C, $F0, $17, $DA, $09, $94, $21, $21, $32, $84, $2D, $74, $35, $09, $94
	dc.b	$21, $21, $02, $A1, $A2, $14, $21, $08, $50, $84, $21, $BE, $53, $6F, $97, $A1, $6F, $C0, $34, $40, $60, $30, $18, $0C, $F0, $05, $88, $C0, $42, $86, $88, $67
	dc.b	$10, $CE, $21, $9C, $43, $38, $80, $2D, $F4, $2F, $46, $ED, $86, $DB, $0B, $6A, $37, $6D, $3B, $61, $BE, $97, $AF, $5E, $BD, $7A, $F5, $EB, $C3, $AB, $59, $79
	dc.b	$EB, $2F, $3D, $64, $1B, $AC, $A3, $6E, $B2, $8E, $5B, $E4, $27, $DB, $0E, $9D, $FD, $37, $4F, $9B, $CE, $53, $EE, $F3, $F1, $F3, $F1, $F3, $CD, $3E, $6F, $E3
	dc.b	$EE, $F7, $CB, $2C, $BA, $BD, $F3, $40, $74, $93, $42, $D6, $BE, $62, $EF, $64, $A1, $62, $D7, $AA, $54, $85, $AD, $65, $29, $F4, $CC, $B5, $D2, $30, $BB, $41
	dc.b	$18, $A4, $47, $F9, $E9, $F9, $4A, $7E, $0D, $CD, $9E, $99, $7E, $95, $A3, $C3, $41, $3A, $E0, $C6, $FE, $D6, $86, $53, $30, $AC, $4D, $5D, $D4, $DD, $4E, $BA
	dc.b	$76, $C3, $6D, $37, $A4, $5B, $F2, $2D, $F9, $16, $FC, $9B, $B6, $4D, $DB, $26, $ED, $93, $76, $CE, $D6, $20, $4B, $D7, $AF, $5E, $BD, $7A, $E2, $BC, $2C, $65
	dc.b	$1B, $F4, $7A, $4D, $E9, $37, $A4, $DE, $93, $7A, $4D, $E8, $66, $66, $66, $7C, $2E, $A1, $A2, $14, $34, $42, $8D, $28, $D3, $1A, $F1, $AF, $1A, $F5, $AE, $01
	dc.b	$78, $26, $13, $61, $36, $94, $69, $46, $94, $6B, $21, $80, $6F, $EE, $89, $1B, $9C, $B5, $37, $39, $23, $73, $90, $8C, $B3, $B5, $0B, $3B, $41, $04, $6E, $B4
	dc.b	$80, $26, $60, $CC, $11, $78, $26, $09, $85, $ED, $A4, $C6, $B2, $01, $A1, $6B, $5A, $EB, $DB, $0D, $7A, $32, $12, $68, $A6, $75, $E1, $3E, $01, $7E, $7E, $3E
	dc.b	$7D, $5D, $1B, $BA, $72, $F3, $C3, $A5, $37, $10, $5A, $D6, $B5, $AD, $7A, $05, $AD, $78, $6D, $5A, $D6, $B5, $E8, $1B, $77, $E7, $BA, $C7, $80, $FD, $F6, $DF
	dc.b	$D7, $41, $98, $32, $31, $4B, $23, $D1, $8B, $2F, $C7, $61, $F8, $E4, $A6, $66, $8A, $E6, $21, $0C, $48, $40, $46, $17, $4B, $34, $8C, $2D, $6D, $99, $A2, $99
	dc.b	$86, $8C, $5B, $16, $BA, $EE, $9D, $6B, $18, $31, $AC, $6B, $34, $0B, $D0, $53, $E8, $40, $98, $D1, $48, $5A, $D6, $B5, $D3, $AC, $84, $CD, $10, $13, $61, $36
	dc.b	$13, $61, $36, $13, $69, $46, $94, $6B, $A4, $CC, $CC, $CC, $EB, $33, $33, $3A, $01, $9D, $F8, $5F, $04, $97, $C3, $6F, $90, $2E, $00, $AF, $5E, $BF, $72, $D6
	dc.b	$B5, $AD, $6B, $0B, $5A, $D6, $B5, $AD, $6B, $5A, $D6, $B5, $AC, $A8, $AF, $91, $02, $15, $82, $0B, $5A, $D6, $BA, $4F, $41, $80, $5A, $F0, $0B, $59, $19, $06
	dc.b	$85, $AD, $6B, $5E, $00, $98, $6B, $D2, $65, $E1, $45, $77, $57, $71, $9D, $23, $41, $80, $5D, $23, $06, $68, $66, $B5, $AD, $6B, $59, $9E, $94, $57, $8D, $78
	dc.b	$D3, $9D, $A2, $F8, $33, $33, $3B, $F1, $5F, $AA, $FD, $57, $EA, $CF, $B3, $3E, $C3, $3E, $34, $77, $6A, $7B, $B5, $3D, $EF, $33, $37, $72, $D5, $15, $F7, $75
	dc.b	$C5, $8D, $5D, $71, $4D, $DD, $D6, $E3, $33, $33, $33, $71, $99, $99, $E3, $D5, $47, $7D, $1D, $F4, $77, $99, $9D, $19, $65, $96, $5D, $E6, $67, $CC, $EE, $61
	dc.b	$CC, $39, $95, $21, $E2, $0C, $CD, $FA, $DC, $2A, $0E, $0E, $63, $98, $A0, $A6, $28, $2A, $E5, $05, $19, $9F, $76, $2F, $F6, $1F, $E9, $1C, $E6, $66, $6F, $F4
	dc.b	$72, $83, $83, $98, $E6, $2B, $5A, $8C, $CC, $DD, $C8, $72, $1C, $81, $99, $99, $9F, $09, $70, $9E, $57, $E7, $96, $A3, $33, $33, $EA, $CF, $3D, $93, $EE, $99
	dc.b	$B3, $D9, $3A, $A5, $9D, $51, $6A, $C5, $51, $75, $D0, $AA, $BA, $E8, $89, $2A, $A1, $A9, $BA, $66, $A7, $54, $CD, $AA, $D9, $76, $FD, $D6, $A8, $95, $B3, $53
	dc.b	$DD, $6F, $15, $77, $4B, $A6, $C4, $E8, $95, $58, $A4, $89, $14, $8E, $48, $A7, $54, $EA, $9D, $EF, $7B, $D1, $EF, $F6, $9D, $1F, $DD, $A9, $EF, $7B, $DF, $17
	dc.b	$F2, $95, $15, $9D, $9D, $AA, $2B, $EE, $EB, $8B, $1A, $BA, $E2, $9B, $BB, $AD, $FA, $9E, $A9, $D5, $EB, $14, $A2, $52, $54, $66, $6E, $E5, $AA, $2B, $EE, $FD
	dc.b	$9C, $A8, $D9, $2E, $B9, $55, $E3, $47, $50, $2A, $37, $02, $95, $1B, $81, $4A, $8C, $D3, $B2, $54, $75, $02, $A3, $9A, $6C, $BB, $C4, $83, $59, $26, $89, $31
	dc.b	$B9, $A1, $22, $12, $19, $88, $14, $84, $81, $09, $0C, $B2, $CA, $4C, $F1, $56, $43, $74, $FB, $99, $E3, $3C, $87, $88, $E6, $2E, $62, $E6, $26, $28, $28, $5B
	dc.b	$96, $5B, $D7, $97, $04, $18, $C1, $98, $FF, $65, $99, $65, $BD, $79, $6B, $5E, $FA, $86, $5C, $C3, $FA, $F7, $96, $43, $46, $57, $AF, $90, $E4, $39, $0E, $43
	dc.b	$90, $E4, $39, $03, $33, $3C, $5A, $13, $16, $A3, $68, $AD, $26, $24, $A5, $26, $24, $AC, $CC, $EC, $8D, $23, $48, $E6, $1F, $E5, $21, $1D, $91, $FA, $93, $12
	dc.b	$E4, $6E, $D3, $33, $31, $C9, $07, $0B, $AF, $B0, $8C, $CC, $CC, $F3, $AA, $FD, $AE, $CF, $6C, $59, $D5, $9B, $56, $2A, $EA, $A1, $5E, $33, $29, $D2, $42, $CC
	dc.b	$A7, $66, $24, $CC, $EC, $D6, $6E, $76, $E4, $CC, $EE, $F8, $BA, $B6, $4F, $99, $4E, $54, $59, $94, $C5, $39, $52, $70, $B5, $1C, $24, $A4, $72, $39, $41, $C1
	dc.b	$CA, $0E, $0A, $73, $11, $C1, $42, $25, $3A, $D7, $29, $FD, $CA, $88, $2A, $25, $07, $28, $2A, $26, $29, $8A, $0E, $0A, $0A, $16, $85, $31, $42, $21, $12, $9C
	dc.b	$A7, $5A, $E0, $A7, $EC, $F2, $70, $89, $41, $51, $2A, $20, $A8, $95, $12, $85, $4A, $88, $2A, $A0, $E5, $0A, $94, $1D, $6D, $4A, $7B, $AD, $70, $55, $41, $CC
	dc.b	$D8, $14, $15, $B1, $9C, $55, $EC, $A7, $BD, $EF, $E2, $3B, $83, $6A, $A5, $22, $80, $B1, $CA, $6D, $8D, $73, $52, $97, $BE, $F4, $19, $E1, $FB, $A6, $B2, $32
	dc.b	$41, $63, $43, $50, $59, $5A, $15, $85, $17, $7B, $B9, $B5, $F5, $24, $76, $47, $77, $FD, $7F, $AA, $91, $B1, $23, $48, $EC, $2B, $A3, $40, $99, $65, $96, $40
	dc.b	$BB, $E3, $05, $E7, $99, $23, $05, $E7, $20, $8C, $2F, $3C, $B2, $CB, $2C, $B2, $CB, $2E, $62, $E6, $2E, $62, $E6, $77, $54, $F9, $95, $CC, $39, $8B, $9A, $96
	dc.b	$63, $06, $63, $06, $62, $FE, $7B, $CB, $A4, $2D, $6B, $83, $F9, $EF, $2D, $74, $EB, $86, $D6, $EF, $FB, $0F, $EC, $A5, $E1, $5D, $D5, $EB, $E4, $39, $0E, $43
	dc.b	$90, $E4, $39, $0E, $40, $B8, $12, $60, $30, $0B, $59, $08, $06, $D9, $85, $9A, $6A, $8E, $94, $2D, $B4, $EB, $20, $85, $AD, $A8, $4C, $20, $B6, $A6, $09, $82
	dc.b	$57, $71, $67, $D7, $9F, $59, $0A, $05, $21, $6A, $76, $09, $5D, $B5, $F9, $62, $AA, $A5, $35, $B5, $66, $B6, $AD, $CD, $52, $2A, $76, $A9, $29, $E8, $AB, $2D
	dc.b	$2B, $0A, $C5, $7A, $B9, $0B, $D5, $48, $AE, $F8, $BA, $A7, $AB, $74, $FB, $3C, $D1, $51, $36, $7B, $2D, $71, $4F, $EA, $A8, $8A, $DB, $15, $11, $2B, $D5, $51
	dc.b	$13, $DE, $F2, $4F, $EC, $AD, $6B, $21, $A3, $DE, $FE, $7A, $47, $6A, $C5, $B5, $8B, $6B, $16, $BE, $2D, $4E, $FD, $9B, $F9, $FF, $D3, $3F, $FA, $67, $FE, $CF
	dc.b	$4F, $E4, $F9, $FB, $4B, $53, $BB, $DD, $CD, $FE, $74, $FF, $39, $7F, $9C, $BF, $CE, $5F, $E7, $5C, $06, $83, $01, $80, $C1, $84, $20, $C6, $88, $02, $04, $CC
	dc.b	$3D, $74, $B3, $01, $80, $5E, $09, $82, $2D, $BE, $85, $E8, $DD, $F6, $EF, $B7, $D0, $BD, $0B, $6A, $36, $F3, $3C, $F7, $FA, $6F, $94, $FE, $93, $FA, $4F, $E8
	dc.b	$5E, $85, $E8, $53, $F3, $4F, $CD, $D3, $BF, $A7, $7F, $4E, $FF, $3F, $1F, $3F, $1F, $3C, $BA, $8B, $98, $B9, $8B, $98, $B9, $8B, $98, $B9, $8B, $BE, $7A, $C6
	dc.b	$03, $01, $80, $5A, $D6, $B5, $AD, $6B, $D0, $25, $2C, $F0, $6D, $CD, $0D, $61, $7E, $3B, $50, $C3, $5C, $36, $B7, $7C, $AF, $5E, $BD, $E8, $5B, $E4, $13, $83
	dc.b	$0A, $FD, $D7, $C1, $33, $38, $26, $67, $04, $83, $3D, $39, $E9, $3C, $5D, $C2, $2B, $EA, $8B, $82, $9C, $66, $7C, $84, $23, $B3, $4B, $01, $3A, $96, $13, $B0
	dc.b	$A2, $17, $51, $00, $DC, $6B, $D6, $B5, $AE, $90, $B5, $AD, $6B, $AE, $C5, $E0, $29, $CF, $04, $D6, $DD, $F2, $1C, $0B, $95, $90, $EC, $5E, $A4, $8A, $45, $92
	dc.b	$29, $14, $EB, $35, $B6, $CD, $F6, $E7, $D6, $7F, $BA, $B5, $C5, $FB, $A5, $44, $DF, $55, $44, $DF, $55, $44, $5F, $BA, $54, $50, $B1, $51, $23, $2C, $55, $57
	dc.b	$27, $92, $D6, $16, $B5, $E1, $ED, $FE, $98, $AB, $16, $D6, $2D, $AC, $5B, $58, $B6, $B1, $6B, $58, $42, $DF, $E5, $76, $EE, $B6, $7F, $2F, $7E, $DF, $C7, $ED
	dc.b	$FC, $7B, $7F, $AE, $AF, $36, $CE, $3D, $CA, $EF, $70, $4C, $DE, $FF, $38, $FF, $3A, $7F, $9C, $7F, $9C, $BA, $10, $F3, $21, $39, $0F, $32, $D7, $BD, $EE, $20
	dc.b	$81, $A9, $04, $61, $06, $8F, $52, $48, $08, $C1, $24, $35, $46, $84, $21, $60, $6A, $41, $8D, $4A, $42, $D3, $04, $5A, $D7, $82, $40, $41, $34, $F5, $86, $B4
	dc.b	$86, $B4, $85, $D5, $85, $AD, $6B, $87, $A3, $77, $DA, $C6, $85, $AD, $6B, $5D, $33, $F8, $AD, $6B, $5F, $A5, $3B, $57, $E3, $3A, $D6, $B5, $E0, $C5, $85, $E0
	dc.b	$30, $0B, $5A, $D6, $16, $08, $52, $3F, $5D, $48, $2F, $CF, $53, $AE, $9D, $7A, $33, $40, $42, $B1, $08, $EB, $0B, $68, $C1, $34, $66, $83, $44, $15, $A0, $AD
	dc.b	$95, $85, $96, $7A, $73, $D3, $9E, $17, $DA, $2F, $B7, $83, $78, $17, $2D, $F6, $99, $99, $99, $9E, $06, $66, $66, $67, $C9, $86, $66, $66, $67, $BE, $DA, $37
	dc.b	$CC, $CC, $CC, $F4, $45, $6D, $85, $1B, $E6, $66, $67, $FD, $9E, $8B, $BD, $8E, $D3, $33, $3D, $EA, $7D, $F5, $D3, $78, $CC, $CF, $7B, $7B, $09, $D9, $A5, $EE
	dc.b	$0C, $A3, $7C, $C8, $69, $3E, $13, $AF, $06, $41, $85, $BE, $57, $8A, $6F, $4D, $11, $7A, $05, $C1, $95, $B1, $7A, $05, $AD, $6B, $5A, $D6, $B8, $02, $13, $2D
	dc.b	$6B, $5A, $D7, $A3, $0D, $6B, $5A, $D7, $80, $33, $83, $16, $B5, $AD, $66, $78, $AE, $90, $D0, $B5, $D6, $C3, $33, $98, $93, $41, $58, $9A, $0C, $C4, $98, $66
	dc.b	$66, $66, $74, $55, $7D, $DD, $77, $DD, $A9, $D7, $EA, $BF, $55, $FA, $8C, $DF, $FF, $3D, $4E, $D4, $ED, $4E, $D4, $F7, $BD, $C6, $67, $D7, $16, $7D, $4E, $EB
	dc.b	$8A, $8E, $EE, $B7, $EA, $79, $99, $99, $9E, $A8, $AF, $C5, $D7, $11, $99, $99, $9F, $0D, $74, $6F, $99, $99, $F2, $94, $DC, $C3, $98, $78, $B0, $CC, $CF, $2C
	dc.b	$B2, $12, $BA, $45, $23, $33, $3E, $69, $B9, $A6, $E6, $99, $3B, $CC, $CC, $CF, $3E, $E5, $63, $DF, $37, $31, $99, $99, $E3, $AB, $3E, $69, $E5, $9F, $34, $FE
	dc.b	$26, $7C, $95, $CA, $7E, $45, $C1, $BC, $1B, $BB, $18, $D5, $35, $B1, $75, $B9, $55, $7E, $CF, $64, $1D, $3E, $6D, $9A, $8B, $57, $85, $CE, $2D, $51, $B5, $92
	dc.b	$2B, $90, $3B, $9F, $B6, $3D, $CA, $A3, $BA, $D9, $B8, $AA, $6A, $B3, $74, $2A, $B3, $74, $D9, $6D, $9B, $2D, $47, $BD, $EF, $FD, $D7, $75, $9C, $52, $AB, $14
	dc.b	$96, $92, $3D, $EF, $7B, $DE, $F7, $23, $DF, $56, $A7, $BD, $EF, $7B, $DF, $11, $D5, $7F, $8D, $0F, $7E, $C4, $E2, $AA, $94, $F3, $33, $77, $2D, $99, $F8, $D0
	dc.b	$A4, $7F, $13, $33, $33, $37, $72, $D9, $C3, $7E, $8D, $FA, $37, $E8, $DB, $3D, $1A, $F3, $51, $AD, $B4, $6D, $2A, $3D, $3A, $88, $48, $75, $16, $61, $D4, $42
	dc.b	$53, $F8, $B3, $22, $EA, $9F, $31, $73, $17, $33, $0B, $30, $2D, $CC, $29, $15, $D9, $98, $52, $29, $30, $A4, $59, $65, $96, $52, $2E, $F9, $B9, $A6, $2E, $F9
	dc.b	$8B, $BE, $6E, $A9, $F3, $4D, $CD, $37, $34, $DC, $C6, $66, $66, $5C, $08, $67, $6B, $33, $93, $08, $CC, $E8, $59, $5E, $B8, $91, $8B, $D0, $F8, $29, $D7, $D4
	dc.b	$E9, $34, $4C, $A8, $A4, $5A, $DD, $9A, $C6, $10, $CC, $51, $A4, $61, $B2, $A6, $E2, $CB, $2C, $B2, $CB, $2C, $A3, $CB, $34, $F9, $65, $96, $E7, $77, $C5, $E3
	dc.b	$56, $EE, $EC, $DC, $73, $71, $93, $94, $41, $55, $28, $AD, $0A, $88, $2A, $20, $A7, $28, $AA, $25, $39, $45, $12, $8A, $A0, $4C, $53, $94, $F7, $C4, $DA, $89
	dc.b	$D6, $95, $44, $E0, $A2, $54, $44, $A8, $08, $88, $29, $CA, $11, $10, $A8, $44, $4F, $79, $44, $A2, $53, $88, $12, $9A, $A7, $5A, $41, $AA, $A9, $44, $E2, $57
	dc.b	$12, $57, $12, $53, $DF, $13, $6E, $50, $72, $87, $67, $05, $38, $2A, $A5, $07, $05, $6C, $0E, $0A, $D8, $A7, $05, $3D, $FE, $C3, $8A, $87, $10, $AE, $E5, $0E
	dc.b	$21, $5C, $43, $DE, $F7, $BD, $EF, $7B, $DE, $FE, $2A, $7B, $FD, $8B, $D9, $1E, $F7, $DA, $96, $A2, $92, $A4, $F2, $7A, $89, $45, $12, $93, $B2, $44, $8F, $97
	dc.b	$1C, $DD, $D9, $A6, $4A, $BA, $91, $C9, $E3, $17, $7A, $A5, $69, $59, $E3, $EB, $96, $52, $3C, $DB, $FD, $4C, $6F, $7B, $53, $9A, $CF, $15, $77, $C6, $5D, $EC
	dc.b	$A2, $F6, $FB, $76, $C2, $E6, $82, $61, $31, $A0, $99, $5B, $2B, $66, $1C, $C0, $99, $1E, $E2, $D6, $57, $10, $68, $D0, $35, $30, $45, $AF, $2C, $BA, $77, $93
	dc.b	$27, $EA, $46, $8E, $99, $99, $01, $3C, $88, $20, $68, $9D, $B6, $06, $8E, $69, $B9, $A6, $E6, $9B, $9A, $6E, $A9, $F3, $4D, $CD, $37, $34, $D3, $F7, $99, $9A
	dc.b	$B8, $5B, $7F, $B6, $3F, $C9, $A3, $9F, $FB, $38, $93, $1B, $43, $44, $15, $31, $32, $30, $4A, $68, $8E, $16, $95, $90, $51, $31, $20, $A2, $15, $A8, $AC, $5A
	dc.b	$D6, $B5, $AD, $6D, $D5, $A6, $A8, $C5, $6C, $AD, $23, $65, $68, $43, $46, $68, $13, $41, $80, $C1, $85, $CC, $51, $F7, $C3, $A9, $D0, $DD, $10, $6E, $6E, $D0
	dc.b	$4F, $28, $27, $90, $6A, $79, $49, $EF, $7C, $5C, $FC, $FC, $FC, $FF, $C9, $7B, $DF, $DB, $BB, $B5, $9F, $C9, $F5, $FE, $4F, $AF, $97, $EE, $BB, $3D, $EF, $7F
	dc.b	$F6, $6C, $F2, $72, $37, $C9, $C8, $DF, $27, $23, $5E, $F7, $BF, $FF, $4B, $5A, $DE, $F7, $6A, $77, $F0, $DF, $FF, $AC, $06, $8C, $D1, $8F, $7F, $FC, $DE, $9F
	dc.b	$E9, $D7, $E5, $72, $79, $32, $CF, $27, $BF, $FE, $6F, $E7, $E7, $E7, $FF, $4C, $EF, $7F, $E8, $EA, $CD, $57, $8D, $BF, $D7, $56, $F6, $F7, $F9, $FB, $B7, $6C
	dc.b	$CB, $2E, $AD, $ED, $ED, $ED, $EC, $B2, $CB, $2D, $ED, $ED, $ED, $EF, $12, $05, $E3, $0E, $AA, $65, $E7, $4F, $BD, $3E, $F0, $1E, $F4, $FB, $AE, $B6, $68, $10
	dc.b	$57, $65, $6C, $4D, $19, $A2, $0A, $E3, $B1, $6B, $5A, $D7, $80, $C2, $36, $57, $AA, $3C, $2C, $1A, $59, $80, $41, $5D, $82, $BF, $5D, $02, $68, $83, $44, $13
	dc.b	$F7, $CD, $3F, $7C, $C5, $3F, $8C, $CD, $F1, $99, $B3, $F5, $4C, $D9, $FA, $A6, $6C, $FB, $A7, $99, $B3, $E6, $9C, $CC, $CC, $CE, $65, $5F, $ED, $9F, $CB, $85
	dc.b	$B7, $FB, $63, $FC, $99, $B9, $F9, $D1, $48, $41, $2D, $4B, $58, $A4, $E7, $E7, $E7, $E7, $E7, $E7, $0A, $24, $52, $79, $05, $21, $73, $F6, $6A, $08, $29, $A9
	dc.b	$4A, $9B, $63, $45, $B5, $8B, $6B, $16, $B5, $8D, $EC, $D6, $17, $66, $DD, $58, $8C, $52, $08, $2C, $86, $0C, $D2, $3D, $51, $8A, $E3, $D4, $CA, $E3, $62, $C8
	dc.b	$22, $F4, $4D, $05, $9A, $25, $76, $69, $1A, $57, $1B, $1A, $8D, $4F, $24, $6F, $F2, $58, $5F, $C9, $87, $F2, $5A, $9F, $C9, $24, $FE, $C9, $7F, $A4, $73, $F3
	dc.b	$F3, $FF, $65, $3F, $D2, $9F, $D9, $B3, $F9, $3E, $BF, $C9, $F5, $F2, $FF, $D2, $76, $FE, $57, $6F, $E5, $76, $FE, $57, $6F, $E5, $76, $FE, $57, $6F, $E5, $76
	dc.b	$FE, $57, $FA, $5C, $8D, $F2, $72, $37, $C9, $C8, $DF, $27, $23, $7C, $9C, $8D, $F2, $72, $37, $C9, $C8, $DF, $E4, $D4, $B5, $AD, $6B, $5B, $77, $DF, $A3, $34
	dc.b	$66, $81, $34, $B3, $4B, $0B, $6D, $97, $7F, $29, $E3, $D7, $CB, $F7, $5E, $5F, $BA, $F2, $FD, $D7, $97, $EE, $BC, $BF, $75, $E5, $FB, $AE, $D3, $D5, $DB, $A7
	dc.b	$F6, $7A, $7F, $27, $CF, $CB, $CC, $76, $F7, $2B, $7F, $AE, $AF, $EB, $96, $F6, $F6, $F6, $F0, $E8, $49, $E6, $42, $72, $4F, $30, $53, $95, $85, $3B, $67, $84
	dc.b	$E5, $BD, $BD, $BD, $BD, $E6, $8C, $9D, $3C, $D1, $93, $A3, $67, $24, $29, $DB, $D2, $13, $96, $F6, $F6, $F6, $F0, $FF, $38, $FF, $39, $7F, $9C, $B7, $B7, $B7
	dc.b	$BC, $E0, $3D, $E9, $F7, $80, $EA, $9E, $1F, $C7, $87, $F1, $E1, $FD, $70, $5F, $D7, $83, $2B, $08, $34, $42, $15, $84, $8F, $48, $C5, $61, $6B, $20, $B5, $AD
	dc.b	$6B, $5A, $DA, $C8, $30, $99, $A2, $02, $14, $84, $A5, $84, $95, $A0, $80, $26, $24, $05, $82, $00, $AC, $80, $B0, $42, $66, $F0, $6F, $02, $E4, $46, $66, $67
	dc.b	$8F, $95, $FE, $DC, $81, $99, $99, $F3, $F3, $DE, $33, $33, $3E, $7E, $7B, $D8, $ED, $BF, $71, $99, $F9, $35, $9E, $42, $1B, $ED, $F4, $2B, $C6, $66, $30, $D7
	dc.b	$00, $DD, $B1, $AD, $9A, $19, $9B, $63, $48, $31, $23, $68, $6A, $57, $45, $39, $DA, $66, $7C, $3F, $F4, $B3, $33, $33, $3F, $FD, $2E, $8D, $F3, $33, $33, $FE
	dc.b	$57, $6A, $EC, $56, $D8, $19, $99, $9F, $3F, $6F, $E5, $2C, $CC, $CC, $F9, $FF, $F5, $80, $33, $33, $3E, $7F, $FD, $2C, $CC, $CC, $FF, $93, $E7, $FB, $AF, $76
	dc.b	$42, $E3, $33, $33, $DE, $DE, $61, $6D, $33, $33, $3D, $ED, $E6, $8A, $CC, $CC, $CF, $7B, $CD, $75, $99, $99, $9F, $F9, $D6, $B2, $33, $33, $35, $AD, $77, $B3
	dc.b	$EB, $33, $3A, $42, $2C, $22, $D7, $75, $66, $67, $4B, $1A, $C5, $AD, $7A, $19, $9D, $81, $A2, $86, $43, $1A, $73, $B4, $19, $99, $99, $9E, $2A, $D5, $7D, $09
	dc.b	$57, $D0, $95, $7D, $09, $57, $D0, $95, $9D, $20, $67, $D6, $ED, $51, $51, $A9, $EF, $F6, $57, $B2, $BD, $8C, $CC, $E2, $E1, $B3, $3F, $1A, $1E, $66, $66, $66
	dc.b	$74, $6D, $51, $99, $99, $99, $BC, $CC, $CC, $CC, $F8, $E6, $33, $33, $33, $BF, $96, $E3, $33, $33, $3C, $DC, $33, $19, $99, $99, $F5, $75, $CD, $DF, $AB, $9B
	dc.b	$51, $99, $99, $FE, $8E, $FF, $F4, $E5, $37, $EC, $FA, $B8, $29, $D7, $EA, $CF, $56, $AC, $63, $9F, $33, $B1, $84, $7A, $A8, $6C, $B5, $16, $AA, $0A, $7D, $DA
	dc.b	$B7, $2B, $A5, $BB, $15, $0E, $BD, $96, $FE, $8E, $32, $89, $5E, $CA, $D5, $1B, $51, $D2, $9F, $53, $6C, $CD, $3B, $6C, $89, $49, $FD, $9B, $15, $EC, $AF, $65
	dc.b	$7B, $5B, $C5, $15, $C5, $2D, $EE, $4E, $D5, $04, $ED, $10, $7B, $DE, $F7, $0F, $66, $3D, $3B, $BF, $75, $C7, $86, $CC, $FC, $68, $7B, $DF, $B2, $C7, $23, $EF
	dc.b	$DD, $9F, $5E, $7D, $79, $F5, $C5, $40, $DD, $B0, $17, $47, $59, $13, $09, $FE, $8E, $DF, $8B, $5F, $90, $FF, $3E, $5B, $CB, $4D, $26, $72, $54, $85, $EA, $E4
	dc.b	$6A, $73, $AB, $7B, $2D, $E5, $E3, $83, $9A, $99, $89, $4D, $76, $EF, $E4, $EE, $FE, $3F, $34, $FB, $BF, $8F, $BA, $BD, $D7, $F2, $DC, $0A, $E2, $90, $29, $0C
	dc.b	$CD, $91, $4A, $E2, $64, $89, $92, $29, $0C, $B2, $CB, $37, $0C, $DC, $33, $70, $CD, $C3, $37, $0C, $DC, $33, $70, $CC, $66, $66, $77, $C7, $21, $C1, $97, $C9
	dc.b	$86, $67, $33, $3C, $12, $34, $1F, $D5, $11, $A4, $69, $18, $6E, $FB, $76, $94, $64, $66, $71, $B1, $B8, $8D, $26, $68, $F5, $6A, $56, $CC, $01, $99, $99, $99
	dc.b	$0B, $F2, $05, $9E, $2E, $52, $E1, $28, $F3, $F5, $63, $BA, $2A, $33, $6C, $CD, $DD, $2F, $6D, $5C, $7A, $FC, $7F, $46, $51, $89, $7E, $8E, $40, $A5, $FA, $3E
	dc.b	$A6, $78, $6E, $FD, $1C, $8B, $37, $5F, $7E, $AC, $B9, $B5, $65, $96, $59, $65, $97, $88, $8F, $C5, $89, $E3, $3E, $59, $38, $75, $33, $C2, $4C, $FF, $AF, $ED
	dc.b	$53, $C1, $3F, $4A, $82, $34, $8D, $23, $61, $66, $E3, $1D, $4A, $45, $39, $85, $62, $91, $5F, $D5, $0A, $F0, $DF, $40, $B0, $85, $63, $6C, $04, $C2, $7D, $AE
	dc.b	$11, $28, $22, $9C, $C7, $28, $22, $92, $DD, $7E, $4E, $0E, $68, $42, $54, $4C, $24, $B6, $28, $07, $29, $F5, $28, $98, $A7, $05, $44, $C8, $99, $50, $A9, $42
	dc.b	$25, $0A, $85, $41, $51, $28, $54, $1E, $F8, $94, $3B, $94, $E1, $DC, $4A, $0A, $EE, $0A, $1C, $59, $EC, $1E, $F7, $D8, $A4, $7B, $D4, $E5, $3A, $D7, $BD, $F5
	dc.b	$49, $29, $9A, $29, $7F, $2A, $2D, $DD, $A2, $EA, $EC, $EE, $F8, $BB, $E2, $EF, $8B, $BF, $1A, $EC, $15, $A9, $29, $B6, $C6, $F9, $50, $DD, $7B, $BF, $8F, $CD
	dc.b	$3F, $7F, $4B, $FB, $BF, $95, $BB, $F9, $39, $A3, $FE, $4C, $99, $7E, $EC, $F7, $47, $D2, $E2, $09, $3D, $C5, $76, $52, $FF, $AB, $3D, $42, $08, $D3, $C1, $3F
	dc.b	$EB, $FA, $54, $8D, $23, $FF, $D0, $B1, $89, $B7, $37, $0F, $0E, $17, $58, $C9, $BF, $4B, $AC, $BC, $36, $94, $7A, $E0, $17, $81, $99, $97, $22, $1C, $08, $70
	dc.b	$68, $BE, $D0, $74, $13, $33, $90, $21, $9E, $03, $3D, $39, $E0, $AC, $ED, $51, $67, $25, $37, $3A, $A1, $74, $01, $32, $11, $D2, $AD, $15, $A2, $96, $B5, $AD
	dc.b	$6B, $5E, $89, $A2, $2A, $B5, $14, $70, $45, $3A, $37, $36, $DD, $80, $84, $D1, $57, $14, $6C, $25, $7E, $95, $D1, $92, $AA, $F0, $7C, $6E, $6F, $18, $DE, $FD
	dc.b	$9D, $72, $11, $75, $BB, $34, $5D, $6E, $DC, $ED, $55, $6E, $D9, $D5, $B3, $AB, $67, $55, $59, $65, $96, $5D, $53, $F7, $F4, $F1, $F3, $EA, $F7, $DD, $D0, $A2
	dc.b	$DD, $D2, $EC, $D3, $96, $BF, $32, $D7, $3B, $76, $CE, $DD, $B3, $B9, $5B, $62, $4D, $B1, $6F, $A0, $4B, $8B, $7D, $A9, $B5, $A9, $AE, $9D, $74, $DD, $5D, $D5
	dc.b	$DC, $94, $A0, $D0, $2D, $6B, $5A, $D6, $B8, $25, $4D, $0D, $AA, $BA, $A9, $05, $16, $91, $52, $CB, $6B, $16, $E9, $6B, $DF, $B3, $AD, $F5, $73, $FF, $25, $9F
	dc.b	$D9, $05, $FD, $90, $4F, $7B, $DD, $CF, $79, $BB, $5B, $BF, $0D, $AF, $7F, $3F, $3D, $DF, $C9, $67, $F6, $42, $9D, $FD, $98, $BF, $93, $57, $8D, $52, $F7, $ED
	dc.b	$FC, $7B, $7F, $AF, $6F, $F5, $D5, $FE, $75, $6F, $7F, $9E, $5B, $DF, $D7, $2F, $7A, $7D, $E9, $F7, $A7, $DE, $9F, $7A, $7D, $E9, $9C, $42, $EA, $EE, $D1, $9A
	dc.b	$33, $01, $80, $5A, $EF, $5E, $BD, $7A, $F0, $20, $5A, $F4, $62, $DA, $16, $B5, $AE, $91, $84, $64, $29, $1A, $89, $90, $B1, $A2, $FC, $06, $70, $D1, $9C, $34
	dc.b	$67, $46, $8C, $E8, $D1, $9E, $36, $8C, $E8, $D0, $66, $66, $78, $AB, $82, $8A, $FA, $9B, $9D, $50, $C5, $54, $D0, $AA, $E6, $56, $8A, $5A, $EB, $8A, $9F, $22
	dc.b	$E2, $A5, $E0, $9A, $29, $D4, $A2, $A2, $82, $A5, $B1, $5D, $51, $2A, $51, $BF, $B8, $95, $C5, $4F, $7B, $DE, $F7, $BD, $EF, $7B, $DE, $FD, $9D, $BD, $95, $57
	dc.b	$8D, $5E, $31, $77, $C5, $BB, $CD, $CA, $97, $BB, $95, $FC, $78, $95, $E7, $B1, $5D, $3B, $B3, $42, $A9, $4E, $DD, $9D, $1E, $F7, $BD, $FE, $CA, $DF, $72, $B7
	dc.b	$DC, $A6, $13, $09, $CA, $21, $4B, $95, $A3, $94, $95, $BA, $DA, $DD, $6D, $77, $25, $22, $02, $01, $A8, $20, $20, $17, $80, $21, $5B, $16, $1B, $A9, $05, $69
	dc.b	$A9, $2B, $08, $34, $0B, $83, $16, $B5, $D6, $2D, $A5, $96, $D6, $2D, $AC, $5B, $58, $B5, $AC, $21, $6C, $10, $85, $B0, $42, $1C, $E0, $BF, $B2, $0B, $FB, $20
	dc.b	$BF, $B2, $0B, $FB, $20, $BF, $B2, $0B, $FB, $20, $BF, $B2, $C8, $6B, $54, $2E, $B6, $0C, $B5, $D0, $16, $C5, $0B, $6A, $85, $B5, $06, $AB, $62, $9F, $17, $F2
	dc.b	$6A, $F2, $9E, $AF, $29, $EA, $ED, $D2, $AE, $DD, $2A, $B7, $CE, $AB, $7C, $E2, $B7, $7B, $7B, $FA, $E5, $39, $74, $29, $FD, $4A, $76, $F4, $24, $6A, $14, $E9
	dc.b	$09, $DB, $BD, $FD, $76, $FB, $D3, $EF, $4F, $BC, $A7, $6F, $4C, $DD, $1B, $FD, $76, $FB, $D3, $D1, $65, $B5, $6B, $5C, $02, $D6, $B5, $B6, $82, $64, $2C, $6B
	dc.b	$1A, $C6, $B1, $A2, $91, $83, $34, $DB, $5D, $CB, $80, $CF, $01, $9E, $17, $DA, $2F, $94, $7C, $08, $70, $06, $66, $67, $C0, $19, $99, $E2, $A6, $C5, $8A, $A0
	dc.b	$94, $31, $21, $7A, $8D, $F3, $33, $EE, $54, $56, $79, $45, $4A, $54, $C6, $A2, $A2, $64, $3D, $66, $F4, $33, $7B, $BA, $DE, $E5, $6C, $FF, $4F, $EE, $A9, $DF
	dc.b	$6D, $FB, $8F, $8D, $AF, $7B, $FF, $B5, $16, $96, $5E, $3E, $CF, $FE, $4B, $DE, $FF, $DD, $6C, $63, $52, $AB, $CF, $53, $FB, $92, $AF, $56, $54, $8C, $73, $1C
	dc.b	$8F, $E3, $79, $EF, $47, $23, $93, $65, $C9, $56, $D4, $7C, $5F, $FA, $BD, $12, $92, $98, $94, $94, $C5, $6A, $42, $2B, $52, $15, $5A, $8D, $AA, $D4, $05, $FC
	dc.b	$AB, $D7, $57, $75, $61, $06, $03, $00, $B5, $8C, $2E, $5D, $71, $E1, $60, $AC, $24, $62, $00, $98, $82, $C0, $DD, $AB, $9A, $BC, $48, $23, $7B, $10, $46, $F6
	dc.b	$46, $17, $EE, $99, $A0, $2E, $04, $67, $CB, $FD, $2E, $E7, $FD, $D2, $CC, $CC, $F3, $EC, $E7, $57, $AB, $58, $46, $66, $67, $8F, $97, $BD, $95, $83, $33, $33
	dc.b	$35, $D2, $0C, $CC, $CC, $F1, $AC, $11, $99, $99, $99, $D1, $E8, $66, $66, $66, $7A, $19, $99, $99, $99, $9E, $36, $C5, $9D, $0A, $AC, $50, $95, $54, $CA, $42
	dc.b	$55, $53, $29, $09, $5B, $14, $D4, $55, $46, $66, $67, $29, $BA, $67, $94, $FE, $3A, $A7, $E6, $3A, $14, $EF, $D1, $BA, $65, $3B, $F8, $73, $3B, $AA, $29, $A9
	dc.b	$8F, $AE, $B8, $F5, $17, $E8, $DC, $5A, $9C, $5F, $B3, $76, $6B, $60, $AD, $8A, $6A, $AA, $D4, $E5, $12, $B8, $A9, $15, $13, $73, $47, $6B, $9B, $9A, $35, $49
	dc.b	$C5, $14, $9D, $2F, $E4, $C5, $3D, $AF, $77, $F2, $6C, $8B, $D6, $D4, $AB, $B3, $95, $57, $F1, $FC, $22, $EA, $77, $84, $5E, $7D, $AA, $6B, $D0, $58, $43, $F9
	dc.b	$4A, $B1, $91, $29, $CA, $AB, $7B, $2D, $E5, $BC, $22, $90, $15, $81, $14, $8A, $4B, $5D, $E5, $12, $B7, $B2, $DE, $5D, $59, $B1, $B7, $76, $28, $AD, $D8, $A9
	dc.b	$D2, $E9, $8F, $49, $09, $63, $BA, $79, $63, $D3, $76, $2D, $DC, $66, $66, $74, $0E, $51, $F0, $8D, $38, $30, $CC, $E6, $1E, $02, $36, $7F, $D5, $23, $4F, $0F
	dc.b	$FD, $04, $16, $6F, $99, $9C, $63, $C0, $63, $E1, $AE, $8B, $1A, $08, $4C, $94, $B2, $61, $A0, $33, $33, $33, $38, $CF, $84, $FC, $A7, $E1, $3C, $AF, $CF, $21
	dc.b	$9E, $7D, $D9, $F7, $3B, $1D, $D1, $51, $3E, $6A, $B2, $DC, $56, $16, $A4, $92, $5D, $2D, $5E, $29, $D7, $27, $6E, $EB, $95, $52, $EB, $CD, $B3, $AF, $35, $5D
	dc.b	$7B, $BF, $47, $E3, $D6, $EF, $1D, $5C, $C8, $39, $AC, $EF, $4C, $B2, $CB, $DE, $D9, $74, $EE, $CD, $57, $6C, $D1, $20, $50, $CD, $10, $B4, $66, $88, $5A, $99
	dc.b	$A2, $52, $5B, $9A, $AB, $95, $B1, $4E, $9A, $25, $6C, $92, $39, $3B, $82, $AC, $EE, $46, $2A, $A4, $52, $05, $54, $2D, $4D, $91, $A7, $1C, $61, $47, $E9, $61
	dc.b	$E1, $2B, $5B, $D9, $D2, $51, $77, $4A, $32, $64, $62, $26, $27, $E9, $5D, $1A, $7F, $54, $24, $69, $E0, $87, $FF, $5E, $77, $C7, $77, $FD, $7F, $4A, $3F, $8A
	dc.b	$C2, $48, $FD, $43, $68, $DD, $8F, $86, $EC, $6D, $DD, $8C, $5B, $A6, $24, $F0, $CD, $38, $F0, $64, $73, $82, $F0, $68, $9C, $BD, $41, $09, $DA, $10, $CC, $D3
	dc.b	$C0, $47, $77, $FD, $7F, $6B, $67, $87, $FE, $AE, $B0, $20, $33, $31, $1D, $99, $FC, $11, $98, $D8, $08, $63, $64, $05, $0C, $80, $36, $5F, $8D, $97, $EE, $BF
	dc.b	$75, $FB, $AF, $DD, $7C, $99, $7C, $81, $5E, $F4, $2B, $DB, $54, $5B, $54, $DD, $AA, $83, $09, $5A, $29, $78, $5D, $06, $2D, $6B, $5A, $F0, $E4, $5C, $88, $70
	dc.b	$6F, $08, $08, $F1, $D1, $8D, $18, $E9, $19, $99, $99, $D0, $E1, $1E, $39, $9C, $D0, $59, $A2, $A1, $B2, $53, $95, $44, $AA, $42, $9A, $55, $21, $24, $FD, $D6
	dc.b	$D4, $96, $BA, $3E, $3D, $6E, $F5, $27, $75, $A2, $91, $49, $FA, $3D, $9F, $A3, $73, $47, $5E, $E6, $75, $C5, $9B, $F4, $75, $66, $EB, $EE, $97, $5F, $74, $B5
	dc.b	$71, $97, $B4, $9F, $96, $59, $65, $96, $59, $77, $EA, $DD, $B1, $1D, $9B, $8E, $6E, $39, $B8, $E6, $E3, $9A, $7D, $89, $9B, $A3, $41, $4E, $D1, $FB, $AE, $E5
	dc.b	$3B, $B3, $FB, $87, $B0, $FE, $1A, $91, $DF, $BA, $0D, $73, $29, $89, $19, $08, $87, $FA, $85, $82, $CB, $D7, $AF, $5E, $61, $7A, $17, $A7, $F2, $81, $7A, $DC
	dc.b	$41, $36, $92, $16, $D2, $42, $D6, $D4, $2D, $64, $8D, $D6, $48, $0B, $59, $20, $21, $4D, $D5, $DD, $5D, $D5, $DD, $5D, $DA, $05, $90, $C2, $F5, $EB, $D7, $98
	dc.b	$40, $81, $0C, $02, $D6, $C8, $0A, $05, $22, $39, $85, $2C, $99, $90, $41, $33, $08, $21, $09, $88, $35, $08, $4C, $41, $BA, $99, $31, $30, $90, $72, $85, $F8
	dc.b	$5F, $85, $F0, $DE, $01, $5C, $02, $B8, $28, $B8, $2A, $0A, $D1, $58, $2B, $45, $2D, $70, $4A, $A1, $DC, $D4, $FE, $4A, $D6, $B5, $AD, $EF, $E7, $21, $43, $63
	dc.b	$99, $B9, $E1, $C8, $B9, $36, $EC, $5E, $FB, $78, $E3, $3A, $AA, $8E, $89, $D5, $54, $15, $B2, $82, $53, $91, $49, $42, $A2, $B5, $D6, $F1, $54, $5D, $4E, $53
	dc.b	$B3, $26, $6E, $EE, $B7, $BE, $25, $7B, $29, $EF, $7B, $DE, $F7, $F1, $57, $77, $6A, $BC, $92, $2B, $76, $5B, $C7, $9A, $7D, $DF, $C7, $97, $F9, $D5, $FE, $74
	dc.b	$FF, $3A, $7F, $9D, $EF, $9E, $C5, $7E, $EA, $75, $7F, $6A, $7B, $7F, $74, $53, $F6, $48, $76, $46, $A0, $B7, $F9, $41, $EF, $46, $36, $25, $0A, $62, $53, $43
	dc.b	$62, $55, $C5, $52, $AE, $2A, $95, $71, $54, $A8, $95, $B1, $4E, $B7, $62, $9B, $73, $42, $D6, $B5, $AD, $30, $45, $90, $6A, $0D, $13, $08, $F0, $4C, $06, $08
	dc.b	$34, $66, $08, $B5, $97, $58, $D3, $51, $47, $80, $9A, $98, $C8, $4D, $A0, $C0, $67, $68, $24, $14, $34, $13, $28, $6E, $BA, $1B, $76, $30, $05, $8C, $19, $8C
	dc.b	$0C, $E8, $53, $73, $A9, $AE, $CE, $A2, $8B, $39, $7A, $DF, $26, $63, $B4, $CD, $1E, $FF, $6F, $FD, $5E, $59, $9B, $DE, $FB, $38, $DD, $FC, $A5, $99, $C5, $FD
	dc.b	$97, $FB, $2B, $8D, $BF, $FA, $AD, $89, $9E, $93, $AA, $77, $4E, $F7, $C4, $AE, $3C, $EA, $FF, $50, $2D, $64, $08, $F8, $DB, $B1, $4F, $A9, $5E, $DF, $FA, $5A
	dc.b	$CF, $9D, $EF, $7F, $FE, $B4, $62, $CF, $F9, $2F, $EC, $F7, $BD, $9F, $DA, $59, $BF, $9D, $EF, $7F, $FE, $96, $6E, $57, $1B, $76, $29, $CA, $A9, $42, $DA, $95
	dc.b	$72, $A2, $55, $8A, $7C, $4A, $89, $48, $C4, $35, $60, $AC, $1C, $9A, $39, $05, $6E, $52, $0A, $55, $48, $5B, $4F, $4B, $30, $4C, $11, $6B, $5E, $00, $DA, $CC
	dc.b	$ED, $17, $D0, $85, $F2, $65, $F2, $1C, $18, $66, $67, $C9, $4E, $55, $F5, $12, $B3, $DA, $56, $E2, $E8, $3B, $17, $41, $D8, $BA, $0E, $BF, $26, $D5, $44, $8B
	dc.b	$B2, $51, $22, $B6, $CA, $24, $51, $5B, $44, $8B, $DE, $89, $4F, $D5, $44, $8B, $CE, $54, $4A, $13, $C9, $E9, $6A, $76, $77, $F6, $94, $E5, $3B, $CA, $2F, $75
	dc.b	$43, $A9, $50, $D5, $2E, $94, $E6, $25, $75, $2B, $65, $B1, $75, $D4, $A4, $8B, $F4, $71, $27, $55, $4A, $8F, $F4, $71, $B6, $36, $F5, $D3, $2F, $E1, $B7, $37
	dc.b	$E8, $F7, $3F, $F7, $4A, $B1, $56, $29, $15, $65, $B1, $29, $D6, $BA, $3F, $F3, $C7, $CD, $1B, $A7, $96, $A9, $74, $CC, $ED, $D3, $C2, $57, $D4, $52, $BE, $A2
	dc.b	$95, $F7, $14, $AF, $CE, $52, $BF, $29, $E5, $7E, $72, $95, $F6, $C8, $CC, $CE, $8B, $B3, $84, $F0, $C4, $7E, $D7, $10, $91, $A4, $78, $8F, $58, $CC, $F9, $04
	dc.b	$B9, $2E, $8D, $23, $48, $D3, $FE, $BF, $D5, $4F, $D2, $D9, $1A, $47, $EA, $66, $CF, $D2, $A7, $85, $DF, $CA, $64, $2E, $8C, $34, $40, $17, $83, $6E, $24, $61
	dc.b	$02, $33, $8E, $C0, $DA, $11, $94, $CD, $72, $EB, $0D, $9F, $A8, $A7, $EF, $A2, $45, $C2, $45, $C2, $45, $FB, $5A, $24, $55, $2A, $89, $15, $4A, $A2, $45, $8A
	dc.b	$BB, $E2, $97, $B4, $DD, $3C, $68, $9F, $71, $4B, $B4, $A3, $90, $94, $6E, $EF, $53, $BC, $63, $77, $33, $B2, $E6, $8C, $BF, $67, $99, $52, $25, $47, $6E, $EF
	dc.b	$D1, $C6, $37, $7E, $CF, $AA, $3E, $BF, $17, $75, $F5, $3B, $F4, $7B, $9C, $0A, $3E, $BF, $1E, $98, $EE, $9F, $3E, $E7, $2B, $F4, $BD, $5B, $3A, $B6, $78, $E3
	dc.b	$E2, $EC, $A2, $98, $A5, $C0, $A5, $7E, $32, $96, $72, $71, $4B, $16, $B8, $A5, $44, $26, $29, $51, $0E, $69, $F6, $75, $19, $90, $48, $D2, $34, $8D, $AC, $FD
	dc.b	$AB, $6E, $B2, $36, $82, $D7, $39, $6D, $29, $74, $63, $41, $9C, $69, $1D, $85, $47, $81, $5D, $1D, $90, $BA, $32, $05, $63, $23, $0D, $16, $6F, $B5, $86, $67
	dc.b	$E0, $91, $A4, $68, $3F, $EB, $64, $69, $E1, $60, $B0, $59, $79, $86, $66, $63, $94, $65, $C1, $07, $06, $1D, $DE, $B4, $6D, $4A, $13, $6D, $05, $B6, $8D, $FA
	dc.b	$37, $E8, $DF, $A0, $10, $26, $7F, $68, $25, $EB, $DE, $8E, $F4, $77, $A3, $B7, $C9, $CC, $26, $35, $CC, $46, $35, $88, $2B, $08, $CA, $58, $D6, $40, $23, $6E
	dc.b	$20, $49, $04, $20, $49, $48, $6A, $52, $AF, $65, $7B, $2A, $2E, $BA, $A3, $57, $12, $50, $77, $FE, $84, $12, $D4, $1F, $BA, $51, $39, $A1, $38, $AB, $D9, $5C
	dc.b	$6D, $97, $75, $B2, $FE, $D2, $A5, $A6, $66, $10, $29, $F3, $7A, $82, $9E, $5A, $B9, $9D, $DF, $17, $8D, $5D, $4E, $8E, $2D, $CE, $8E, $AC, $DD, $D1, $CB, $64
	dc.b	$7D, $B6, $46, $E5, $39, $BF, $A3, $CC, $E2, $FD, $9B, $A5, $E1, $FB, $3E, $EE, $BE, $3D, $75, $13, $8B, $AC, $A2, $53, $8B, $AC, $A2, $8D, $C5, $AB, $C3, $53
	dc.b	$BB, $DC, $AE, $F7, $2B, $9A, $2E, $FA, $BC, $52, $AE, $A9, $EA, $F1, $D9, $9B, $54, $9E, $F7, $BF, $FF, $4B, $AF, $D4, $85, $94, $F7, $21, $0E, $28, $51, $75
	dc.b	$C4, $A2, $EE, $B0, $58, $A7, $56, $CB, $03, $41, $24, $42, $94, $72, $A9, $B8, $90, $AE, $AF, $5B, $50, $81, $0B, $09, $CC, $6B, $11, $C4, $20, $09, $C4, $2B
	dc.b	$71, $0C, $2F, $5E, $BD, $7A, $F5, $EB, $C0, $AE, $2D, $A5, $7D, $85, $7D, $85, $7D, $85, $7D, $85, $7D, $85, $7D, $85, $7C, $81, $72, $AC, $50, $2B, $A0, $57
	dc.b	$40, $AE, $81, $5D, $02, $BA, $05, $74, $0A, $C4, $01, $3B, $07, $60, $EC, $1D, $83, $B0, $76, $8E, $C1, $D0, $04, $98, $26, $09, $82, $60, $C8, $73, $A9, $FE
	dc.b	$CD, $55, $90, $45, $44, $43, $F7, $51, $52, $85, $15, $28, $A8, $A9, $E7, $7B, $E1, $EB, $9B, $49, $E4, $82, $B9, $DA, $12, $13, $D2, $10, $A7, $E7, $7B, $ED
	dc.b	$8B, $C2, $24, $57, $14, $57, $14, $B7, $BA, $C5, $77, $76, $F6, $B7, $8D, $BE, $DF, $A3, $EE, $EB, $E3, $D7, $ED, $A9, $EF, $E3, $AB, $67, $7F, $72, $A7, $CD
	dc.b	$3D, $4A, $9E, $53, $94, $56, $F4, $6C, $56, $A4, $ED, $8A, $D4, $9D, $B1, $7F, $65, $CA, $F6, $57, $16, $2E, $9B, $29, $B2, $94, $14, $A0, $D3, $9D, $EF, $20
	dc.b	$85, $6A, $12, $12, $44, $A1, $04, $89, $42, $09, $12, $08, $24, $4A, $42, $E7, $7B, $F4, $76, $0E, $AC, $13, $A9, $0D, $71, $33, $4F, $24, $6E, $CB, $50, $BB
	dc.b	$94, $84, $E6, $86, $B1, $6B, $5A, $D6, $B5, $D3, $7E, $17, $E1, $7E, $17, $E1, $7E, $17, $E1, $7E, $06, $66, $67, $8B, $0C, $CE, $88, $EB, $C6, $BC, $45, $3B
	dc.b	$61, $BE, $DC, $FA, $CC, $EB, $71, $3A, $B7, $12, $AB, $71, $3A, $97, $14, $54, $B8, $AC, $A5, $50, $33, $7F, $3B, $DF, $FF, $A5, $99, $D4, $AD, $9F, $C9, $F6
	dc.b	$57, $B5, $B1, $7F, $2A, $D7, $53, $FB, $A9, $AE, $A4, $F3, $2A, $5B, $24, $AC, $CF, $7D, $4A, $E3, $6F, $FE, $96, $6A, $F6, $E7, $53, $FD, $BF, $F4, $8B, $3E
	dc.b	$5D, $CA, $27, $7F, $65, $0B, $BA, $D2, $E2, $A2, $FF, $52, $C8, $CD, $6E, $C1, $D8, $3B, $07, $69, $32, $8C, $F9, $37, $83, $78, $11, $99, $99, $9C, $DB, $E7
	dc.b	$C8, $72, $1C, $87, $21, $C8, $1D, $E3, $BA, $66, $50, $31, $BA, $6B, $A6, $DB, $8B, $26, $D7, $33, $0E, $8B, $C6, $C9, $BD, $26, $66, $2C, $9B, $D2, $66, $4D
	dc.b	$AE, $6D, $A7, $78, $CC, $CC, $E6, $61, $DF, $BC, $7B, $F9, $D9, $C1, $9C, $19, $C1, $93, $30, $E6, $BC, $6C, $C5, $93, $5D, $35, $D3, $7A, $4C, $C9, $84, $CC
	dc.b	$99, $98, $B0, $E6, $BC, $66, $66, $6C, $3E, $17, $8F, $5C, $CC, $99, $98, $B2, $6D, $73, $33, $16, $4C, $C9, $B5, $CD, $71, $DE, $36, $4D, $AE, $66, $4C, $CC
	dc.b	$59, $36, $B9, $99, $8B, $26, $64, $DA, $CE, $6B, $C7, $C8, $19, $9B, $0F, $85, $E3, $DB, $36, $B9, $99, $36, $B9, $99, $36, $B9, $99, $36, $B9, $99, $33, $0E
	dc.b	$F1, $B2, $8D, $73, $32, $66, $62, $C9, $B7, $E8, $66, $2C, $9B, $59, $DE, $33, $33, $33, $3B, $C7, $AE, $8D, $73, $32, $6D, $FA, $35, $CC, $C9, $B7, $E8, $61
	dc.b	$DE, $36, $63, $74, $CC, $99, $93, $09, $99, $33, $26, $BA, $8D, $73, $32, $66, $4C, $0F, $7C, $CE, $81, $C8, $72, $1C, $84, $CC, $33, $CF, $FF, $5F, $FA, $FF
	dc.b	$D4, $FF, $EB, $FF, $5F, $FA, $99, $99, $9F, $FD, $7F, $EB, $FF, $5F, $FF, $7F, $FB, $FF, $DF, $FE, $FF, $F7, $FF, $BF, $FD, $FF, $EF, $FF, $7F, $FB, $FF, $DF
	dc.b	$FE, $FF, $F7, $FF, $BF, $FD, $FF, $EF, $FF, $7F, $FB, $FF, $DF, $FE, $FF, $F7, $FF, $BF, $FD, $FF, $EF, $FF, $7F, $FB, $FF, $DF, $FE, $FF, $F7, $FF, $BF, $FD
	dc.b	$FF, $E0
Car_width_vdp_cmd_table:
	dc.l	Car_width_vdp_cmds_2row
	dc.l	Car_width_vdp_cmds_4row
	dc.l	Car_width_vdp_cmds_6row
	dc.l	Car_width_vdp_cmds_8row
	dc.l	Car_width_vdp_cmds_10row
	dc.l	Car_width_vdp_cmds_12row
	dc.l	Car_width_vdp_cmds_14row
Car_width_vdp_cmds_14row:
	dc.b	$00, $0D, $F0, $03, $42, $C2, $00, $00, $D0, $03, $42, $C2, $00, $00, $F0, $03, $42, $C2, $00, $08, $D0, $03, $42, $C2, $00, $08, $F0, $03, $42, $C2, $00, $10
	dc.b	$D0, $03, $42, $C2, $00, $10, $F0, $03, $42, $C2, $00, $18, $D0, $03, $42, $C2, $00, $18, $F0, $03, $42, $C2, $00, $20, $D0, $03, $42, $C2, $00, $20, $F0, $03
	dc.b	$42, $C2, $00, $28, $D0, $03, $42, $C2, $00, $28, $F0, $03, $42, $C2, $00, $30, $D0, $03, $42, $C2, $00, $30
Car_width_vdp_cmds_12row:
	dc.b	$00, $0B, $F0, $03, $42, $C2, $00, $00, $D0, $03, $42, $C2, $00, $00, $F0, $03, $42, $C2, $00, $08, $D0, $03, $42, $C2, $00, $08, $F0, $03, $42, $C2, $00, $10
	dc.b	$D0, $03, $42, $C2, $00, $10, $F0, $03, $42, $C2, $00, $18, $D0, $03, $42, $C2, $00, $18, $F0, $03, $42, $C2, $00, $20, $D0, $03, $42, $C2, $00, $20, $F0, $03
	dc.b	$42, $C2, $00, $28, $D0, $03, $42, $C2, $00, $28
Car_width_vdp_cmds_10row:
	dc.b	$00, $09, $F0, $03, $42, $C2, $00, $00, $D0, $03, $42, $C2, $00, $00, $F0, $03, $42, $C2, $00, $08, $D0, $03, $42, $C2, $00, $08, $F0, $03, $42, $C2, $00, $10
	dc.b	$D0, $03, $42, $C2, $00, $10, $F0, $03, $42, $C2, $00, $18, $D0, $03, $42, $C2, $00, $18, $F0, $03, $42, $C2, $00, $20, $D0, $03, $42, $C2, $00, $20
Car_width_vdp_cmds_8row:
	dc.b	$00, $07
	dc.b	$F0, $03, $42, $C2, $00, $00, $D0, $03, $42, $C2, $00, $00, $F0, $03, $42, $C2, $00, $08, $D0, $03, $42, $C2, $00, $08, $F0, $03, $42, $C2, $00, $10, $D0, $03
	dc.b	$42, $C2, $00, $10, $F0, $03, $42, $C2, $00, $18, $D0, $03, $42, $C2, $00, $18
Car_width_vdp_cmds_6row:
	dc.b	$00, $05, $F0, $03, $42, $C2, $00, $00, $D0, $03, $42, $C2, $00, $00, $F0, $03
	dc.b	$42, $C2, $00, $08, $D0, $03, $42, $C2, $00, $08, $F0, $03, $42, $C2, $00, $10, $D0, $03, $42, $C2, $00, $10
Car_width_vdp_cmds_4row:
	dc.b	$00, $03, $F0, $03, $42, $C2, $00, $00, $D0, $03, $42, $C2, $00, $00, $F0, $03, $42, $C2, $00, $08, $D0, $03, $42, $C2, $00, $08
Car_width_vdp_cmds_2row:
	dc.b	$00, $01,	$F0, $03, $42, $C2, $00, $00, $D0, $03, $42, $C2, $00, $00
Car_stat_row_tilemap_table:
	dc.l	Car_stat_row_tilemap_0
	dc.l	Car_stat_row_tilemap_1
	dc.l	Car_stat_row_tilemap_2
	dc.l	Car_stat_row_tilemap_3
	dc.l	Car_stat_row_tilemap_4
Car_stat_row_tilemap_0:
	dc.b	$06, $01, $00, $01, $00, $03, $09, $78, $20, $14, $07, $9C, $50, $60, $00, $28, $12, $10, $40, $26, $1A, $10, $40, $24, $12, $50, $40, $22, $12, $70, $40, $22
	dc.b	$0A, $90, $40, $20, $0A, $B0, $40, $20, $02, $D0, $40, $24, $2C, $10, $09, $0B, $04, $02, $41, $A3, $1C, $00, $5F, $C0
Car_stat_row_tilemap_1:
	dc.b	$06, $00, $00, $00, $00, $02, $09, $70, $30, $86, $BC, $10, $D4, $09, $08, $21, $A6, $0A, $00, $21, $04, $34, $A0, $0E, $1A, $10, $43, $44, $34, $00, $42, $08
	dc.b	$68, $84, $9C, $10, $D0, $07, $82, $AA, $41, $0D, $00, $16, $82, $1A, $42, $C1, $0D, $21, $60, $86, $90, $68, $C7, $0C, $2F, $E0
Car_stat_row_tilemap_2:
	dc.b	$06, $00, $00, $01, $00, $03, $09, $78, $20, $28, $12, $10, $40, $50, $24, $20, $80, $98, $68, $41, $01, $30, $52, $82, $02, $41, $25, $04, $04, $42, $4E, $08
	dc.b	$08, $06, $9C, $10, $10, $05, $58, $20, $24, $2C, $10, $12, $16, $08, $09, $06, $8C, $70, $02, $FE
Car_stat_row_tilemap_3:
	dc.b	$06, $00, $00, $01, $00, $03, $09, $78, $20, $31, $04, $05, $40, $46, $08, $0A, $04, $84, $10, $13, $0D, $08, $20, $24, $22, $10, $40, $44, $24, $E0, $80, $80
	dc.b	$4A, $41, $01, $00, $55, $82, $02, $42, $C1, $01, $21, $60, $80, $90, $68, $C7, $00, $2F, $E0, $00
Car_stat_row_tilemap_4:
	dc.b	$06, $00, $00, $01, $00, $03, $09, $78, $20, $31, $04, $05, $40, $46, $08, $0A, $04, $84, $10, $13, $0D, $08, $20, $24, $22, $10, $40, $44, $24, $E0, $80, $80
	dc.b	$4A, $41, $01, $00, $55, $82, $02, $42, $C1, $01, $21, $60, $80, $90, $68, $C7, $00, $2F, $E0, $00
Car_stat_tiles_table:
	dc.l	Car_stat_tiles_0
	dc.l	Car_stat_tiles_1
	dc.l	Car_stat_tiles_2
	dc.l	Car_stat_tiles_3
	dc.l	Car_stat_tiles_4
Car_stat_tiles_0:
	dc.b	$00, $2B, $80, $05, $18, $27, $76, $67, $7B, $75, $16, $84, $07, $77, $8A, $04, $06, $15, $14, $28, $F8, $36, $39, $8B, $04, $07, $15, $13, $27, $7A, $36, $3A
	dc.b	$8C, $04, $08, $15, $15, $8D, $03, $01, $16, $33, $26, $36, $37, $78, $77, $79, $8E, $05, $12, $16, $37, $26, $32, $35, $1A, $45, $17, $53, $02, $66, $38, $73
	dc.b	$00, $FF, $B5, $AD, $6B, $5A, $D6, $FD, $87, $ED, $3F, $61, $DF, $DF, $ED, $3F, $61, $DF, $DF, $7B, $5A, $DD, $BB, $E3, $F8, $98, $EF, $8E, $FF, $C0, $EF, $8F
	dc.b	$E2, $7B, $EF, $DB, $F8, $96, $B5, $B0, $00, $00, $00, $00, $03, $86, $4C, $98, $71, $F1, $95, $35, $4B, $B0, $00, $64, $DC, $32, $64, $DC, $32, $64, $DC, $30
	dc.b	$00, $01, $97, $52, $F5, $A7, $00, $01, $C7, $A1, $31, $30, $C9, $B8, $64, $C9, $B8, $64, $C9, $86, $9D, $3A, $74, $E9, $D3, $A7, $4E, $00, $51, $7A, $EA, $B7
	dc.b	$85, $0A, $02, $71, $FB, $C1, $51, $02, $00, $00, $70, $C9, $B8, $64, $C9, $B4, $D7, $79, $36, $9E, $4D, $77, $4E, $9D, $3A, $7E, $1C, $6A, $14, $28, $50, $A1
	dc.b	$42, $85, $00, $00, $00, $4C, $9B, $4D, $C3, $26, $D3, $C9, $B4, $F2, $6B, $BC, $9B, $4E, $9D, $3D, $DE, $F0, $F7, $85, $0A, $14, $28, $50, $A0, $69, $93, $70
	dc.b	$C9, $B2, $7D, $DB, $27, $DD, $B2, $7D, $DB, $27, $C9, $B7, $74, $FA, $89, $3E, $A2, $4F, $A8, $50, $A1, $42, $85, $01, $32, $64, $C9, $B7, $7D, $E9, $BB, $CA
	dc.b	$9B, $CF, $53, $CA, $27, $95, $72, $7D, $44, $9F, $51, $27, $D4, $5E, $B7, $8B, $D4, $01, $2A, $E5, $FA, $C0, $00, $00, $01, $7F, $F5, $79, $20, $09, $7F, $28
	dc.b	$B4, $B6, $A1, $6C, $A9, $9B, $6F, $4C, $E4, $77, $A1, $DD, $B7, $DB, $72, $25, $33, $32, $FC, $9E, $7C, $50, $F2, $7E, $33, $A1, $A1, $E4, $D3, $C9, $1D, $1F
	dc.b	$54, $3C, $9A, $1A, $6D, $43, $CF, $8A, $6D, $97, $27, $2F, $E6, $89, $9E, $8F, $27, $F9, $5B, $50, $F2, $68, $69, $B5, $0F, $27, $E3, $C8, $E8, $FA, $62, $A8
	dc.b	$6F, $43, $7A, $1B, $B6, $77, $CC, $27, $21, $7F, $AF, $C9, $00, $01, $29, $99, $97, $94, $CC, $CB, $CB, $F9, $79, $CB, $69, $97, $D7, $81, $2F, $E6, $18, $95
	dc.b	$4D, $4C, $3F, $89, $9E, $8F, $AC, $E6, $66, $7A, $33, $F2, $44, $1F, $F6, $1A, $E7, $59, $99, $ED, $33, $D7, $89, $ED, $97, $47, $2F, $E6, $8F, $F6, $6D, $53
	dc.b	$53, $3D, $A6, $7A, $33, $33, $DA, $67, $A3, $EB, $C8, $02, $66, $F3, $37, $99, $BB, $E7, $7C, $C0, $0B, $FD, $9E, $48, $00, $01, $2F, $E6, $18, $95, $4D, $4C
	dc.b	$4A, $A6, $A6, $25, $FE, $D0, $00, $83, $53, $2F, $D6, $1A, $99, $7F, $70, $CA, $BF, $CD, $96, $60, $00, $65, $53, $5C, $E5, $53, $5C, $E5, $FC, $CC, $E5, $FD
	dc.b	$D0, $00, $B7, $F4, $33, $FE, $81, $F7, $9F, $F4, $0F, $B3, $6B, $5B, $1B, $63, $C7, $E4, $0E, $0F, $6D, $B1, $E3, $07, $F2, $07, $F8, $07, $06, $D6, $B7, $63
	dc.b	$83, $D8, $E0, $E3, $3C, $67, $83, $83, $83, $83, $D8, $F6, $3D, $8F, $63, $6B, $60, $00
Car_stat_tiles_1:
	dc.b	$00, $2C, $80, $05, $18, $26, $3A, $67, $7B, $75, $17, $84, $07, $76, $8A, $04, $06, $15, $14, $36, $38, $8B, $05, $0F, $15, $0E, $27, $7A, $36, $39, $8C, $05
	dc.b	$13, $15, $15, $8D, $03, $02, $15, $1A, $26, $32, $37, $77, $77, $78, $8E, $05, $12, $16, $33, $26, $36, $36, $37, $45, $16, $54, $08, $67, $79, $72, $00, $FF
	dc.b	$FD, $87, $ED, $3F, $61, $DB, $DF, $ED, $3F, $61, $DB, $DF, $6B, $DE, $FD, $76, $C7, $F1, $31, $DB, $1D, $BF, $81, $DB, $1F, $C4, $F7, $DB, $AF, $E2, $5E, $F7
	dc.b	$C0, $00, $05, $EF, $7B, $DE, $F7, $B8, $00, $11, $40, $00, $97, $FE, $80, $00, $F3, $FA, $A0, $00, $DD, $A1, $A1, $A2, $96, $68, $68, $68, $60, $0C, $E8, $50
	dc.b	$60, $03, $76, $86, $86, $86, $86, $08, $7D, $9C, $00, $FD, $B9, $CD, $D6, $79, $6A, $81, $FE, $B1, $E1, $FF, $C0, $07, $1E, $87, $0F, $00, $03, $CB, $6E, $DE
	dc.b	$5A, $1A, $1A, $1A, $CF, $6B, $3E, $4D, $BB, $E1, $FE, $5F, $67, $59, $F6, $9B, $ED, $3B, $56, $D3, $89, $C4, $C9, $7E, $B3, $6A, $DA, $60, $07, $9F, $D6, $15
	dc.b	$2A, $4C, $02, $1A, $1A, $1B, $CB, $43, $6C, $FC, $DB, $67, $E6, $DB, $3F, $36, $D9, $F0, $F8, $7E, $F3, $93, $F7, $9C, $9F, $BC, $E2, $71, $38, $9C, $4E, $26
	dc.b	$00, $00, $43, $43, $43, $43, $66, $FC, $E9, $9B, $E5, $4C, $DD, $BB, $B6, $9B, $66, $F8, $7E, $F3, $93, $F7, $9C, $9F, $BC, $ED, $5B, $4E, $D5, $21, $DB, $57
	dc.b	$7A, $ED, $FA, $C0, $00, $0B, $7F, $AB, $C2, $02, $5F, $CA, $4D, $2C, $A8, $9B, $6A, $69, $B3, $A6, $A4, $B3, $A2, $CD, $B3, $CB, $34, $49, $C9, $C9, $FC, $2E
	dc.b	$3B, $D1, $70, $BF, $55, $AA, $2A, $2E, $15, $3C, $23, $95, $EA, $8B, $85, $45, $4C, $A8, $B8, $EF, $4C, $B6, $E1, $6D, $FC, $D1, $CB, $95, $C2, $FE, $56, $54
	dc.b	$5C, $2A, $2A, $65, $45, $C2, $FD, $57, $83, $95, $E9, $94, $51, $5A, $8A, $D4, $56, $6D, $5B, $44, $3D, $11, $FE, $BF, $08, $00, $93, $93, $93, $E4, $E4, $E4
	dc.b	$F9, $7F, $2F, $52, $C9, $C9, $FB, $F7, $25, $FC, $C5, $39, $55, $55, $4D, $FD, $DC, $B9, $5E, $B4, $E4, $E5, $CA, $77, $84, $4D, $7F, $B1, $57, $55, $72, $76
	dc.b	$4E, $5C, $F7, $76, $5B, $72, $B6, $FE, $69, $FE, $CC, $AA, $AA, $9D, $93, $97, $29, $C9, $D9, $39, $72, $BD, $78, $01, $CA, $CE, $56, $72, $B3, $F5, $6D, $01
	dc.b	$1F, $EC, $F0, $80, $02, $5F, $CC, $53, $95, $55, $54, $E5, $55, $55, $39, $7F, $B4, $02, $6A, $AA, $5F, $AC, $55, $52, $FE, $E2, $95, $7F, $9B, $2D, $00, $29
	dc.b	$55, $57, $52, $AA, $AE, $A5, $FC, $CD, $4B, $FB, $A0, $17, $FE, $86, $BF, $A0, $BD, $EB, $FA, $0B, $DA, $BD, $EF, $8C, $B1, $DF, $F2, $0B, $0B, $AC, $B1, $DF
	dc.b	$0B, $F2, $0B, $F8, $0B, $0A, $F7, $BF, $4B, $0B, $A5, $85, $8D, $63, $58, $58, $58, $58, $5D, $2E, $97, $4B, $A5, $7B, $E0, $00
Car_stat_tiles_2:
	dc.b	$00, $2F, $80, $05, $1A, $26, $3A, $67, $7B, $75, $17, $84, $07, $77, $8A, $03, $02, $15, $15, $36, $39, $8B, $04, $06, $15, $13, $27, $78, $37, $76, $8C, $04
	dc.b	$07, $15, $19, $8D, $03, $01, $16, $37, $26, $38, $37, $79, $77, $7A, $8E, $05, $12, $15, $16, $25, $11, $35, $18, $46, $36, $55, $10, $65, $14, $73, $00, $FF
	dc.b	$BD, $EF, $7B, $DE, $F7, $FD, $87, $ED, $3F, $61, $DF, $DF, $ED, $3F, $61, $DF, $DF, $7B, $DE, $FD, $77, $D7, $F1, $35, $DF, $5D, $FF, $81, $DF, $5F, $C4, $F7
	dc.b	$DF, $AF, $E2, $5E, $F7, $D0, $00, $00, $00, $00, $51, $41, $41, $41, $01, $B7, $FE, $80, $00, $08, $21, $50, $82, $08, $2C, $2A, $28, $2A, $28, $2A, $28, $2A
	dc.b	$20, $00, $00, $4B, $FF, $63, $64, $00, $02, $62, $62, $2A, $8A, $0A, $8A, $8A, $0A, $8A, $08, $59, $A0, $D0, $68, $34, $1A, $8D, $06, $83, $6C, $E0, $0C, $7E
	dc.b	$F2, $D9, $D9, $E0, $E0, $45, $83, $06, $97, $EB, $30, $D1, $C8, $70, $E3, $65, $45, $05, $45, $16, $B2, $C3, $59, $45, $AC, $B0, $D6, $51, $68, $B6, $1E, $4D
	dc.b	$87, $B3, $61, $E0, $F4, $78, $3D, $1E, $0E, $00, $C2, $A2, $82, $A2, $82, $A2, $B2, $C3, $59, $45, $A8, $D0, $6A, $34, $5E, $CD, $87, $B3, $45, $EC, $D1, $78
	dc.b	$BD, $1E, $0F, $47, $00, $00, $00, $00, $08, $2C, $2A, $28, $28, $B4, $55, $9A, $2A, $2D, $65, $16, $B2, $C3, $41, $A2, $D8, $7B, $34, $5E, $8F, $07, $A3, $C1
	dc.b	$E0, $F4, $70, $00, $1B, $2D, $AB, $8A, $C7, $F5, $56, $F1, $05, $05, $B5, $71, $5D, $96, $D3, $8F, $8B, $78, $16, $FD, $64, $5A, $0D, $87, $93, $61, $E4, $D8
	dc.b	$78, $3E, $D9, $C6, $44, $1C, $00, $00, $14, $FE, $58, $FF, $E0, $00, $0C, $7E, $F2, $2E, $00, $00, $00, $29, $FE, $AF, $44, $01, $2F, $E5, $15, $2E, $2A, $54
	dc.b	$6B, $BA, $B5, $77, $91, $B5, $4D, $95, $B8, $B1, $12, $99, $99, $6E, $4F, $3E, $6A, $79, $3F, $AA, $DE, $A6, $A7, $93, $5F, $44, $76, $3E, $2A, $79, $35, $35
	dc.b	$E2, $A7, $9F, $35, $E2, $3C, $98, $FF, $34, $4C, $F6, $3C, $9F, $E5, $71, $53, $C9, $A9, $AF, $15, $3C, $9F, $D5, $7A, $1D, $8F, $84, $61, $53, $B5, $4E, $D5
	dc.b	$3B, $2D, $F6, $DC, $41, $88, $87, $FA, $FD, $10, $00, $12, $99, $99, $69, $4C, $CC, $B4, $BF, $97, $BC, $B8, $99, $6C, $79, $12, $FE, $61, $79, $64, $E4, $BB
	dc.b	$79, $99, $EC, $7C, $6F, $33, $33, $D8, $CF, $D1, $0E, $7F, $D8, $73, $BE, $66, $67, $C4, $CF, $6F, $33, $E2, $3D, $8C, $7F, $9A, $3F, $D9, $C6, $4E, $4C, $F8
	dc.b	$99, $EC, $66, $67, $C4, $CF, $63, $E3, $D0, $02, $67, $69, $9D, $A6, $76, $6D, $F6, $DC, $01, $0F, $F6, $7A, $20, $00, $04, $BF, $98, $5E, $59, $39, $2F, $2C
	dc.b	$9C, $97, $97, $FB, $40, $01, $CE, $4C, $BF, $58, $72, $65, $FD, $C3, $2C, $FF, $36, $5B, $80, $01, $96, $4E, $77, $96, $4E, $77, $97, $F3, $37, $97, $F7, $40
	dc.b	$02, $FF, $D0, $DF, $FA, $07, $DE, $FF, $D0, $3E, $CD, $EF, $7D, $71, $AF, $3F, $90, $3A, $3D, $71, $AF, $3A, $3F, $90, $3F, $C0, $3A, $37, $BD, $FA, $3A, $3D
	dc.b	$1D, $1D, $6F, $AD, $F4, $74, $74, $74, $7A, $3D, $1E, $8F, $46, $F7, $D0, $00
Car_stat_tiles_3:
	dc.b	$00, $2C, $80, $05, $18, $26, $3A, $67, $7B, $75, $16, $84, $07, $77, $8A, $04, $06, $15, $15, $36, $38, $8B, $05, $0F, $15, $12, $27, $7A, $36, $39, $8C, $05
	dc.b	$13, $15, $14, $8D, $03, $02, $15, $1A, $26, $36, $37, $78, $77, $79, $8E, $05, $0E, $16, $32, $26, $37, $36, $33, $45, $17, $54, $08, $67, $76, $72, $00, $FF
	dc.b	$B5, $AD, $6B, $5A, $D6, $FD, $87, $ED, $3F, $61, $DF, $DF, $ED, $3F, $61, $DF, $DF, $7B, $5A, $DD, $77, $C7, $F1, $31, $DF, $1D, $FF, $81, $DF, $1F, $C4, $F7
	dc.b	$DF, $AF, $E2, $5A, $D6, $C0, $00, $00, $00, $19, $7F, $28, $68, $68, $68, $68, $68, $6E, $CD, $0D, $15, $BB, $00, $01, $51, $86, $18, $61, $86, $0E, $CD, $D9
	dc.b	$A1, $A1, $BB, $34, $34, $36, $6C, $00, $5E, $59, $CB, $39, $00, $5F, $FB, $6E, $7C, $3C, $00, $0F, $44, $89, $00, $0D, $D9, $A1, $A1, $B3, $6E, $CD, $0D, $77
	dc.b	$B5, $DF, $0F, $87, $C3, $E1, $F9, $CD, $CF, $87, $C4, $EF, $4C, $E9, $79, $C4, $E2, $60, $EF, $E6, $3A, $97, $98, $00, $76, $7D, $0A, $14, $28, $00, $00, $76
	dc.b	$68, $6B, $B4, $37, $66, $DD, $F9, $36, $EF, $C9, $B7, $7E, $4D, $BB, $E1, $F0, $FC, $E6, $E7, $E7, $37, $3F, $39, $C4, $E2, $71, $38, $9C, $4C, $00, $08, $6B
	dc.b	$D7, $3A, $E4, $FB, $B4, $34, $36, $EF, $C9, $B7, $7E, $4D, $BB, $F2, $6C, $A5, $9C, $B3, $9B, $F3, $A6, $4F, $CE, $6E, $7E, $73, $89, $C4, $E2, $77, $A0, $47
	dc.b	$EA, $9D, $E9, $DC, $8E, $FF, $E0, $04, $53, $7F, $D6, $00, $00, $17, $FF, $57, $94, $03, $BF, $94, $99, $DB, $55, $36, $F5, $D3, $65, $5D, $39, $65, $55, $93
	dc.b	$65, $B6, $48, $74, $94, $93, $F8, $5C, $78, $AA, $E1, $7E, $AB, $55, $55, $5C, $2A, $F9, $47, $2B, $D5, $57, $0A, $AA, $BB, $55, $71, $E2, $BB, $6F, $C2, $DF
	dc.b	$F9, $A4, $97, $2B, $85, $FC, $AD, $AA, $B8, $55, $55, $DA, $AB, $85, $FA, $AF, $27, $2B, $D3, $28, $AA, $BD, $55, $EA, $AE, $DA, $BE, $88, $7A, $23, $FD, $7E
	dc.b	$50, $00, $E9, $29, $27, $BA, $4A, $49, $EE, $FE, $5E, $9D, $B4, $93, $F3, $F0, $3B, $F9, $8A, $6E, $A2, $A2, $9B, $FC, $49, $72, $BD, $6A, $4A, $4B, $95, $2F
	dc.b	$28, $9A, $FF, $62, $A6, $A9, $25, $2D, $A4, $B9, $F1, $2D, $B7, $E5, $6F, $FC, $D3, $FD, $9B, $51, $51, $4B, $69, $2E, $54, $94, $B6, $92, $E5, $7A, $F2, $04
	dc.b	$95, $E4, $AF, $25, $77, $EA, $FA, $02, $3F, $D9, $E5, $00, $03, $BF, $98, $A6, $EA, $2A, $29, $BA, $8A, $8A, $6E, $FF, $68, $04, $D5, $13, $BF, $58, $A8, $9D
	dc.b	$FD, $C4, $EA, $7F, $35, $DA, $00, $4E, $A2, $A6, $9D, $45, $4D, $3B, $F9, $9A, $77, $F7, $40, $2D, $FD, $0D, $7F, $41, $7B, $D7, $F4, $17, $B5, $6B, $5B, $1B
	dc.b	$63, $C7, $E4, $16, $17, $5B, $63, $C6, $17, $E4, $17, $F0, $16, $15, $AD, $6E, $96, $17, $4B, $0B, $1A, $C6, $B0, $B0, $B0, $B0, $BA, $5D, $2E, $97, $4A, $D6
	dc.b	$C0, $00
Car_stat_tiles_4:
	dc.b	$00, $2C, $80, $05, $18, $26, $3A, $67, $7B, $75, $16, $84, $07, $77, $8A, $04, $06, $15, $15, $36, $38, $8B, $05, $0F, $15, $12, $27, $7A, $36, $39, $8C, $05
	dc.b	$13, $15, $14, $8D, $03, $02, $15, $1A, $26, $36, $37, $78, $77, $79, $8E, $05, $0E, $16, $32, $26, $37, $36, $33, $45, $17, $54, $08, $67, $76, $72, $00, $FF
	dc.b	$B5, $AD, $6B, $5A, $D6, $FD, $87, $ED, $3F, $61, $DF, $DF, $ED, $3F, $61, $DF, $DF, $7B, $5A, $DD, $77, $C7, $F1, $31, $DF, $1D, $FF, $81, $DF, $1F, $C4, $F7
	dc.b	$DF, $AF, $E2, $5A, $D6, $C0, $00, $00, $00, $19, $7F, $28, $68, $68, $68, $68, $68, $6E, $CD, $0D, $15, $BB, $00, $01, $51, $86, $18, $61, $86, $0E, $CD, $D9
	dc.b	$A1, $A1, $BB, $34, $34, $36, $6C, $00, $5E, $59, $CB, $39, $00, $5F, $FB, $6E, $7C, $3C, $00, $0F, $44, $89, $00, $0D, $D9, $A1, $A1, $B3, $6E, $CD, $0D, $77
	dc.b	$B5, $DF, $0F, $87, $C3, $E1, $F9, $CD, $CF, $87, $C4, $EF, $4C, $E9, $79, $C4, $E2, $60, $EF, $E6, $3A, $97, $98, $00, $76, $7D, $0A, $14, $28, $00, $00, $76
	dc.b	$68, $6B, $B4, $37, $66, $DD, $F9, $36, $EF, $C9, $B7, $7E, $4D, $BB, $E1, $F0, $FC, $E6, $E7, $E7, $37, $3F, $39, $C4, $E2, $71, $38, $9C, $4C, $00, $08, $6B
	dc.b	$D7, $3A, $E4, $FB, $B4, $34, $36, $EF, $C9, $B7, $7E, $4D, $BB, $F2, $6C, $A5, $9C, $B3, $9B, $F3, $A6, $4F, $CE, $6E, $7E, $73, $89, $C4, $E2, $77, $A0, $47
	dc.b	$EA, $9D, $E9, $DC, $8E, $FF, $E0, $04, $53, $7F, $D6, $00, $00, $17, $FF, $57, $94, $03, $BF, $94, $99, $DB, $55, $36, $F5, $D3, $65, $5D, $39, $65, $55, $93
	dc.b	$65, $B6, $48, $74, $94, $93, $F8, $5C, $78, $AA, $E1, $7E, $AB, $55, $55, $5C, $2A, $F9, $47, $2B, $D5, $57, $0A, $AA, $BB, $55, $71, $E2, $BB, $6F, $C2, $DF
	dc.b	$F9, $A4, $97, $2B, $85, $FC, $AD, $AA, $B8, $55, $55, $DA, $AB, $85, $FA, $AF, $27, $2B, $D3, $28, $AA, $BD, $55, $EA, $AE, $DA, $BE, $88, $7A, $23, $FD, $7E
	dc.b	$50, $00, $E9, $29, $27, $BA, $4A, $49, $EE, $FE, $5E, $9D, $B4, $93, $F3, $F0, $3B, $F9, $8A, $6E, $A2, $A2, $9B, $FC, $49, $72, $BD, $6A, $4A, $4B, $95, $2F
	dc.b	$28, $9A, $FF, $62, $A6, $A9, $25, $2D, $A4, $B9, $F1, $2D, $B7, $E5, $6F, $FC, $D3, $FD, $9B, $51, $51, $4B, $69, $2E, $54, $94, $B6, $92, $E5, $7A, $F2, $04
	dc.b	$95, $E4, $AF, $25, $77, $EA, $FA, $02, $3F, $D9, $E5, $00, $03, $BF, $98, $A6, $EA, $2A, $29, $BA, $8A, $8A, $6E, $FF, $68, $04, $D5, $13, $BF, $58, $A8, $9D
	dc.b	$FD, $C4, $EA, $7F, $35, $DA, $00, $4E, $A2, $A6, $9D, $45, $4D, $3B, $F9, $9A, $77, $F7, $40, $2D, $FD, $0D, $7F, $41, $7B, $D7, $F4, $17, $B5, $6B, $5B, $1B
	dc.b	$63, $C7, $E4, $16, $17, $5B, $63, $C6, $17, $E4, $17, $F0, $16, $15, $AD, $6E, $96, $17, $4B, $0B, $1A, $C6, $B0, $B0, $B0, $B0, $BA, $5D, $2E, $97, $4A, $D6
	dc.b	$C0, $00
;Team_intro_vdp_word_run
Team_intro_vdp_word_run:
	dc.b	$02, $3E, $00, $00, $00, $00, $00, $40, $0E, $EE, $00, $A0, $0A, $CC, $0A, $EA, $06, $C6, $06, $66, $0E, $CA, $0A, $AA, $06, $88, $04, $66, $02, $44, $04, $44
	dc.b	$00, $00, $00, $00, $0E, $C0, $0E, $EE, $02, $22, $06, $66, $02, $4E, $00, $0A, $00, $CC, $00, $88, $04, $44, $0E, $CA, $0E, $C8, $0E, $C6, $0E, $C4, $0E, $C2
	dc.b	$00, $00, $00, $00, $0E, $EE, $08, $00, $06, $AE, $04, $6A, $02, $48, $00, $26, $0C, $CC, $08, $88, $04, $44, $06, $6E, $02, $2C, $02, $06, $02, $44, $00, $00
	dc.b	$08, $AA, $00, $00, $00, $EE, $00, $00, $06, $AE, $04, $6A, $0A, $AA, $0E, $EE, $02, $48, $06, $66, $00, $6C, $02, $AE, $00, $26, $0E, $EE, $08, $AA, $02, $44
Team_palette_data: ; Team palette (everywhere except while driving)
	dc.b	$00, $06, $00, $0C, $00, $EC, $0A, $AE, $00, $0E  ; Madonna truck
	dc.w	$000E, $0008, $00EE, $0088                        ; Madonna car
	dc.b	$0E, $EE, $0A, $AA, $06, $66, $06, $6E, $02, $2C, $00, $04, $00, $00, $06, $AE, $04, $6A, $0A, $AA, $0E, $EE, $02, $48, $08, $88, $02, $22, $06, $66, $00, $26
	dc.b	$0E, $EE, $0A, $AA, $02, $44
	dc.b	$02, $22, $04, $44, $00, $0A, $0C, $CC, $06, $66  ; Firenze truck
	dc.w	$000C, $0008, $000C, $0008                        ; Firenze car
	dc.b	$02, $4E, $00, $0A, $00, $06, $0E, $EE, $08, $88, $04, $44, $00, $00, $06, $AE, $04, $6A, $0A, $AA, $0E, $EE, $02, $48, $06, $66, $00, $0C, $00, $04, $00, $26
	dc.b	$00, $00, $02, $44, $02, $46
	dc.b $08, $02, $0A, $22, $00, $AC, $0E, $88, $0E, $44   ; Millions truck
	dc.w	$0A22, $0802, $00EE, $0088                        ; Millions car
	dc.b	$04, $EE, $00, $AC, $00, $68, $06, $66, $04, $44, $02, $22, $00, $00, $06, $AE, $04, $6A, $0A, $AA, $0E, $EE, $02, $48, $00, $08, $00, $0A, $04, $4E, $00, $26
	dc.b	$00, $00, $00, $00, $02, $44
	dc.b	$00, $60, $00, $82, $00, $AC, $0A, $EA, $06, $C6  ; Bestowal truck
	dc.w	$0282, $0260, $02CE, $0068                        ; Bestowal car
	dc.b	$04, $EE, $00, $AC, $00, $68, $0E, $EE, $0A, $AA, $06, $66, $00, $00, $06, $AE, $04, $6A, $0A, $AA, $0E, $EE, $02, $48, $06, $66, $0A, $22, $0E, $22, $00, $26
	dc.b	$00, $00, $00, $00, $02, $44
	dc.b	$06, $66, $0A, $AA, $08, $22, $0E, $EE, $0C, $CC  ; Blanche truck
	dc.w	$0CCC, $0666, $0A22, $0400                        ; Blanche car
	dc.b	$0C, $86, $0A, $42, $08, $20, $0E, $EE, $0C, $CC, $06, $66, $00, $00, $06, $AE, $04, $6A, $00, $AC, $02, $EE, $02, $48, $00, $6A, $00, $0C, $00, $04, $00, $26
	dc.b	$00, $00, $02, $44, $02, $68
	dc.b	$06, $00, $0E, $00, $0C, $CC, $0E, $A8, $0E, $42  ; Tyrant truck
	dc.w	$0E02, $0802, $0CCC, $0888                        ; Tyrant car
	dc.b	$0E, $EE, $0A, $AA, $06, $66, $0C, $44, $08, $22, $04, $00, $00, $00, $06, $AE, $04, $6A, $00, $CE, $06, $EE, $02, $48, $06, $66, $0A, $22, $0E, $22, $00, $26
	dc.b	$00, $00, $00, $00, $02, $44
	dc.b	$00, $48, $00, $8C, $00, $8C, $0A, $EE, $04, $AE  ; Losel truck
	dc.w	$00AE, $006A, $00AE, $006A                        ; Losel car
	dc.b	$04, $EE, $00, $AC, $00, $6A, $0E, $EE, $0A, $AA, $06, $66, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	dc.b	$00, $00, $00, $00, $00, $00
	dc.b	$08, $40, $0C, $A0, $0C, $A0, $0E, $EC, $0E, $C6  ; May truck
	dc.w	$0CC0, $0A60, $0CC0, $0A60                        ; May car
	dc.b	$0E, $EE, $0A, $AA, $06, $66, $0C, $44, $08, $22, $02, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	dc.b	$00, $00, $00, $00, $00, $00
	dc.b	$06, $00, $0E, $22, $0C, $C0, $0E, $AA, $0E, $44  ; Bullets truck
	dc.w	$0E24, $0802, $0EE8, $0AA0                        ; Bullets car
	dc.b	$0E, $E8, $0C, $C2, $08, $60, $0E, $EE, $0A, $AA, $06, $66, $00, $00, $06, $AE, $04, $6A, $00, $CE, $06, $EE, $02, $48, $00, $8A, $00, $08, $00, $2E, $00, $26
	dc.b	$0E, $EE, $0A, $AA, $02, $44
	dc.b	$00, $04, $00, $28, $0C, $CC, $08, $AE, $02, $4E  ; Dardan truck
	dc.w	$004E, $0028, $004E, $0028                        ; Dardan car
	dc.b	$0E, $EE, $0A, $AA, $06, $66, $0A, $66, $08, $44, $04, $22, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	dc.b	$00, $00, $00, $00, $00, $00
	dc.b	$0A, $00, $0E, $44, $0E, $86, $0E, $AA, $0E, $66  ; Linden truck
	dc.w	$0E24, $0A02, $0E24, $0A02                        ; Linden car
	dc.b	$0C, $CC, $08, $88, $04, $44, $0E, $66, $0C, $22, $04, $00, $00, $00, $08, $CE, $04, $8A, $02, $68, $00, $46, $0E, $80, $0E, $20, $00, $00, $0E, $EE, $0A, $AA
	dc.b	$06, $66, $06, $CE, $02, $44
	dc.b	$00, $46, $00, $AC, $0C, $CC, $0A, $EE, $04, $CE  ; Minarae truck
	dc.w	$0CCC, $0666, $00CE, $0068                        ; Minarae car
	dc.b	$0E, $EE, $0A, $AA, $06, $66, $06, $66, $04, $44, $02, $22, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	dc.b	$00, $00, $00, $00, $00, $00
	dc.b	$02, $40, $02, $A0, $04, $C6, $0A, $EA, $08, $E4  ; Rigel truck
	dc.w	$04C0, $0260, $04C0, $0260                        ; Rigel car
	dc.b	$0E, $EE, $0A, $AA, $04, $44, $0E, $EE, $0A, $AA, $04, $44, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	dc.b	$00, $00, $00, $00, $00, $00
	dc.b	$04, $44, $06, $88, $0A, $CC, $0E, $EE, $0A, $CC  ; Comet truck
	dc.w	$0CCC, $0688, $0CCC, $0688                        ; Comet car
	dc.b	$0E, $EE, $0A, $AA, $06, $66, $06, $66, $04, $44, $02, $22, $00, $00, $08, $CE, $04, $8A, $02, $68, $00, $46, $0E, $80, $0E, $20, $00, $00, $0E, $EE, $0A, $AA
	dc.b	$06, $66, $06, $CE, $02, $44
	dc.b	$02, $22, $04, $44, $00, $AC, $0A, $AA, $06, $66  ; Orchis truck
	dc.w	$0444, $0222, $00EE, $008A                        ; Orchis car
	dc.b	$0E, $EE, $0A, $AA, $06, $66, $0C, $66, $0A, $44, $04, $22, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	dc.b	$00, $00, $00, $00, $00, $00
	dc.b	$06, $66, $0A, $AA, $00, $4A, $0E, $EE, $0C, $CC  ; Zeroforce truck
	dc.w	$0CCC, $0666, $004E, $0028                        ; Zeroforce car
	dc.b	$0E, $EE, $08, $88, $04, $44, $02, $4E, $00, $2A, $00, $04, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	dc.b	$00, $00, $00, $00, $00, $00
; 16-entry pointer table: per-team intro animation layout records (one per team)
Team_intro_layout_table: ; Pointers to team introduction layouts
	dc.l	Team_intro_layout_Madonna ; Madonna
	dc.l	Team_intro_layout_Firenze ; Firenze
	dc.l	Team_intro_layout_Millions ; Millions
	dc.l	Team_intro_layout_Bestowal ; Bestowal
	dc.l	Team_intro_layout_Blanche ; Blanche
	dc.l	Team_intro_layout_Tyrant ; Tyrant
	dc.l	Team_intro_layout_Losel ; Losel
	dc.l	Team_intro_layout_May ; May
	dc.l	Team_intro_layout_Bullets ; Bullets
	dc.l	Team_intro_layout_Dardan ; Dardan
	dc.l	Team_intro_layout_Linden ; Linden
	dc.l	Team_intro_layout_Minarae ; Minarae
	dc.l	Team_intro_layout_Rigel ; Rigel
	dc.l	Team_intro_layout_Comet ; Comet
	dc.l	Team_intro_layout_Orchis ; Orchis
	dc.l	Team_intro_layout_ZeroForce ; ZeroForce
Team_intro_layout_Madonna:
	dc.w	$000C ; Num items in table ($C=12, meaning table has 13 items)
	dc.l	Intro_sprite_data_21F14
	dc.b	$40, $01, $69, $06, $00, $03, $00, $02, $00, $07 ; One row per item. Format: ?, ?, y-tile, x-tile, ?, ?, ?, ?, ?, ?
	dc.l	Intro_sprite_data_21F54
	dc.b	$40, $01, $69, $0C, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F1E
	dc.b	$40, $01, $69, $12, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21EF6
	dc.b	$40, $01, $69, $18, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F4A
	dc.b	$40, $01, $69, $30, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F6C
	dc.b	$60, $01, $68, $B6, $00, $03, $00, $03, $00, $08
	dc.l	Intro_sprite_data_21F14
	dc.b	$40, $01, $69, $3E, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F1E
	dc.b	$40, $01, $69, $44, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21EC0
	dc.b	$20, $01, $6C, $82, $00, $03, $00, $01, $00, $03
	dc.l	Intro_sprite_data_21ECC
	dc.b	$20, $01, $6D, $0C, $00, $03, $00, $04, $00, $01
	dc.l	Intro_sprite_data_21ECC
	dc.b	$20, $01, $6D, $16, $00, $03, $00, $04, $00, $01
	dc.l	Team_intro_anim_data
	dc.b	$20, $01, $6D, $32, $00, $03, $00, $04, $00, $01
	dc.l	Team_intro_anim_data
	dc.b	$20, $01, $6D, $3C, $00, $03, $00, $04, $00, $01
Team_intro_layout_Firenze:
	dc.w  	$000B
	dc.l	Intro_sprite_data_21EF6
	dc.b	$40, $01, $69, $06, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F54
	dc.b	$40, $01, $69, $0C, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F02
	dc.b	$40, $01, $69, $12, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F4A
	dc.b	$40, $01, $69, $18, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F2E
	dc.b	$40, $01, $69, $30, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F14
	dc.b	$40, $01, $69, $36, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F54
	dc.b	$40, $01, $69, $3C, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F42
	dc.b	$60, $01, $69, $42, $00, $03, $00, $01, $00, $07
	dc.l	Intro_sprite_data_21EC0
	dc.b	$20, $01, $6C, $82, $00, $03, $00, $01, $00, $03
	dc.l	Team_intro_anim_data
	dc.b	$20, $01, $6D, $0A, $00, $03, $00, $04, $00, $01
	dc.l	Team_intro_anim_data
	dc.b	$20, $01, $6D, $14, $00, $03, $00, $04, $00, $01
	dc.l	Intro_sprite_data_21ECC
	dc.b	$20, $01, $6D, $42, $00, $03, $00, $04, $00, $01
Team_intro_layout_Millions:
	dc.w	$000B
	dc.l	Intro_sprite_data_21F2E
	dc.b	$40, $01, $69, $08, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F54
	dc.b	$40, $01, $69, $0E, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F3A
	dc.b	$60, $01, $69, $14, $00, $03, $00, $01, $00, $07
	dc.l	Intro_sprite_data_21F4A
	dc.b	$40, $01, $69, $18, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21EF6
	dc.b	$40, $01, $69, $30, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F1E
	dc.b	$40, $01, $69, $36, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F14
	dc.b	$40, $01, $69, $3C, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F54
	dc.b	$40, $01, $69, $42, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21EC0
	dc.b	$20, $01, $6C, $82, $00, $03, $00, $01, $00, $03
	dc.l	Intro_sprite_data_21EC0
	dc.b	$20, $01, $6C, $86, $00, $03, $00, $01, $00, $03
	dc.l	Intro_sprite_data_21ED4
	dc.b	$20, $01, $6D, $3E, $00, $03, $00, $06, $00, $01
	dc.l	Intro_sprite_data_21ED4
	dc.b	$20, $01, $6D, $30, $00, $03, $00, $06, $00, $01
Team_intro_layout_Bestowal:
	dc.w	$000A
	dc.l	Intro_sprite_data_21F54
	dc.b	$40, $01, $69, $0C, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21EF6
	dc.b	$40, $01, $69, $12, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F14
	dc.b	$40, $01, $69, $18, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F3A
	dc.b	$60, $01, $69, $30, $00, $03, $00, $01, $00, $07
	dc.l	Intro_sprite_data_21F4A
	dc.b	$40, $01, $69, $34, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F2E
	dc.b	$40, $01, $69, $3A, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F1E
	dc.b	$40, $01, $69, $40, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21ECC
	dc.b	$20, $01, $6D, $06, $00, $03, $00, $04, $00, $01
	dc.l	Intro_sprite_data_21ECC
	dc.b	$20, $01, $6D, $10, $00, $03, $00, $04, $00, $01
	dc.l	Team_intro_anim_data
	dc.b	$20, $01, $6D, $3A, $00, $03, $00, $04, $00, $01
	dc.l	Team_intro_anim_data
	dc.b	$20, $01, $6D, $44, $00, $03, $00, $04, $00, $01
Team_intro_layout_Blanche:
	dc.w	$000A
	dc.l	Intro_sprite_data_21F14
	dc.b	$40, $01, $69, $08, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F54
	dc.b	$40, $01, $69, $0E, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F2E
	dc.b	$40, $01, $69, $14, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F42
	dc.b	$60, $01, $69, $1A, $00, $03, $00, $01, $00, $07
	dc.l	Intro_sprite_data_21F4A
	dc.b	$40, $01, $69, $30, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F1E
	dc.b	$40, $01, $69, $36, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F2E
	dc.b	$40, $01, $69, $3C, $00, $03, $00, $02, $00, $07
	dc.l	Team_intro_anim_data
	dc.b	$20, $01, $6D, $04, $00, $03, $00, $04, $00, $01
	dc.l	Intro_sprite_data_21ED4
	dc.b	$20, $01, $6D, $12, $00, $03, $00, $06, $00, $01
	dc.l	Intro_sprite_data_21EC0
	dc.b	$20, $01, $6C, $C4, $00, $03, $00, $01, $00, $03
	dc.l	Intro_sprite_data_21EC0
	dc.b	$20, $01, $6C, $CA, $00, $03, $00, $01, $00, $03
Team_intro_layout_Tyrant:
	dc.w	$0009
	dc.l	Intro_sprite_data_21F3A
	dc.b	$60, $01, $69, $0E, $00, $03, $00, $01, $00, $07
	dc.l	Intro_sprite_data_21F1E
	dc.b	$40, $01, $69, $12, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F54
	dc.b	$40, $01, $69, $18, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F4A
	dc.b	$40, $01, $69, $30, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21EF6
	dc.b	$40, $01, $69, $36, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F14
	dc.b	$40, $01, $69, $3C, $00, $03, $00, $02, $00, $07
	dc.l	Team_intro_anim_data
	dc.b	$20, $01, $6D, $06, $00, $03, $00, $04, $00, $01
	dc.l	Team_intro_anim_data
	dc.b	$20, $01, $6D, $12, $00, $03, $00, $04, $00, $01
	dc.l	Intro_sprite_data_21ECC
	dc.b	$20, $01, $6D, $3C, $00, $03, $00, $04, $00, $01
	dc.l	Intro_sprite_data_21EC0
	dc.b	$20, $01, $6C, $C8, $00, $03, $00, $01, $00, $03
Team_intro_layout_Losel:
	dc.w	$0009
	dc.l	Intro_sprite_data_21EF6
	dc.b	$40, $01, $69, $0C, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F4A
	dc.b	$40, $01, $69, $12, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F1E
	dc.b	$40, $01, $69, $18, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F14
	dc.b	$40, $01, $69, $30, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F02
	dc.b	$40, $01, $69, $36, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F2E
	dc.b	$40, $01, $69, $3C, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21ECC
	dc.b	$20, $01, $6D, $04, $00, $03, $00, $04, $00, $01
	dc.l	Intro_sprite_data_21ECC
	dc.b	$20, $01, $6D, $0E, $00, $03, $00, $04, $00, $01
	dc.l	Intro_sprite_data_21ECC
	dc.b	$20, $01, $6D, $18, $00, $03, $00, $04, $00, $01
	dc.l	Team_intro_anim_data
	dc.b	$20, $01, $6D, $40, $00, $03, $00, $04, $00, $01
Team_intro_layout_May:
	dc.w	$0008
	dc.l	Intro_sprite_data_21F2E
	dc.b	$40, $01, $69, $0C, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F02
	dc.b	$40, $01, $69, $12, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F1E
	dc.b	$40, $01, $69, $18, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F2E
	dc.b	$40, $01, $69, $30, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F54
	dc.b	$40, $01, $69, $36, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F4A
	dc.b	$40, $01, $69, $3C, $00, $03, $00, $02, $00, $07
	dc.l	Team_intro_anim_data
	dc.b	$20, $01, $6D, $10, $00, $03, $00, $04, $00, $01
	dc.l	Intro_sprite_data_21ED4
	dc.b	$20, $01, $6D, $32, $00, $03, $00, $06, $00, $01
	dc.l	Intro_sprite_data_21ED4
	dc.b	$20, $01, $6D, $40, $00, $03, $00, $06, $00, $01
Team_intro_layout_Bullets:
	dc.w	$0007
	dc.l	Intro_sprite_data_21F6C
	dc.b	$60, $01, $68, $90, $00, $03, $00, $03, $00, $08
	dc.l	Intro_sprite_data_21F14
	dc.b	$40, $01, $69, $18, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21EF6
	dc.b	$40, $01, $69, $30, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F4A
	dc.b	$40, $01, $69, $36, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F1E
	dc.b	$40, $01, $69, $3C, $00, $03, $00, $02, $00, $07
	dc.l	Team_intro_anim_data
	dc.b	$20, $01, $6D, $06, $00, $03, $00, $04, $00, $01
	dc.l	Team_intro_anim_data
	dc.b	$20, $01, $6D, $10, $00, $03, $00, $04, $00, $01
	dc.l	Intro_sprite_data_21EC0
	dc.b	$20, $01, $6C, $C4, $00, $03, $00, $01, $00, $03
Team_intro_layout_Dardan:
	dc.w	$0009
	dc.l	Intro_sprite_data_21EF6
	dc.b	$40, $01, $69, $0C, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F1E
	dc.b	$40, $01, $69, $12, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F4A
	dc.b	$40, $01, $69, $18, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21EF6
	dc.b	$40, $01, $69, $30, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F14
	dc.b	$40, $01, $69, $36, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F54
	dc.b	$40, $01, $69, $3C, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21ECC
	dc.b	$20, $01, $6D, $06, $00, $03, $00, $04, $00, $01
	dc.l	Intro_sprite_data_21EC0
	dc.b	$20, $01, $6C, $C2, $00, $03, $00, $01, $00, $03
	dc.l	Intro_sprite_data_21EC0
	dc.b	$20, $01, $6C, $C6, $00, $03, $00, $01, $00, $03
	dc.l	Intro_sprite_data_21EC0
	dc.b	$20, $01, $6C, $CA, $00, $03, $00, $01, $00, $03
Team_intro_layout_Linden: ; Linden team introduction layout
	dc.w	$0007
	dc.l	Intro_sprite_data_21F1E
	dc.b	$40, $01, $69, $12, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F62
	dc.b	$60, $01, $69, $18, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F2E
	dc.b	$40, $01, $69, $30, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F14
	dc.b	$40, $01, $69, $36, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F54
	dc.b	$40, $01, $69, $3C, $00, $03, $00, $02, $00, $07
	dc.l	Team_intro_anim_data
	dc.b	$20, $01, $6D, $04, $00, $03, $00, $04, $00, $01
	dc.l	Intro_sprite_data_21ECC
	dc.b	$20, $01, $6D, $38, $00, $03, $00, $04, $00, $01
	dc.l	Intro_sprite_data_21ECC
	dc.b	$20, $01, $6D, $42, $00, $03, $00, $04, $00, $01
Team_intro_layout_Minarae: ; Minarae team introduction layout
	dc.w	$0006
	dc.l	Intro_sprite_data_21F4A
	dc.b	$40, $01, $69, $12, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F1E
	dc.b	$40, $01, $69, $18, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F54
	dc.b	$40, $01, $69, $30, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F1E
	dc.b	$40, $01, $69, $36, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21EF6
	dc.b	$40, $01, $69, $3C, $00, $03, $00, $02, $00, $07
	dc.l	Team_intro_anim_data
	dc.b	$20, $01, $6D, $06, $00, $03, $00, $04, $00, $01
	dc.l	Intro_sprite_data_21ECC
	dc.b	$20, $01, $6D, $40, $00, $03, $00, $04, $00, $01
Team_intro_layout_Rigel:
	dc.w	$0006
	dc.l	Intro_sprite_data_21F02
	dc.b	$40, $01, $69, $12, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F1E
	dc.b	$40, $01, $69, $18, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F4A
	dc.b	$40, $01, $69, $30, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F2E
	dc.b	$40, $01, $69, $36, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21ED4
	dc.b	$20, $01, $6D, $08, $00, $03, $00, $06, $00, $01
	dc.l	Intro_sprite_data_21ED4
	dc.b	$20, $01, $6D, $16, $00, $03, $00, $06, $00, $01
	dc.l	Intro_sprite_data_21E9C
	dc.b	$00, $01, $6D, $3C, $00, $03, $00, $07, $00, $00
Team_intro_layout_Comet:
	dc.w	$0005
	dc.l	Intro_sprite_data_21F1E
	dc.b	$40, $01, $69, $10, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F54
	dc.b	$40, $01, $69, $16, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F62
	dc.b	$60, $01, $69, $30, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F14
	dc.b	$40, $01, $69, $36, $00, $03, $00, $02, $00, $07
	dc.l	Team_intro_anim_data
	dc.b	$20, $01, $6D, $08, $00, $03, $00, $04, $00, $01
	dc.l	Intro_sprite_data_21E9C
	dc.b	$00, $01, $6D, $3C, $00, $03, $00, $07, $00, $00
Team_intro_layout_Orchis:
	dc.w	$0006
	dc.l	Intro_sprite_data_21F4A
	dc.b	$40, $01, $69, $04, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F02
	dc.b	$40, $01, $69, $18, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21EF6
	dc.b	$40, $01, $69, $30, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F54
	dc.b	$40, $01, $69, $36, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21EC0
	dc.b	$20, $01, $6C, $8C, $00, $03, $00, $01, $00, $03
	dc.l	Intro_sprite_data_21EC0
	dc.b	$20, $01, $6C, $90, $00, $03, $00, $01, $00, $03
	dc.l	Intro_sprite_data_21E9C
	dc.b	$00, $01, $6D, $3C, $00, $03, $00, $07, $00, $00
Team_intro_layout_ZeroForce:
	dc.w	$0003
	dc.l	Intro_sprite_data_21EF6
	dc.b	$40, $01, $69, $2E, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F4A
	dc.b	$40, $01, $69, $18, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21F14
	dc.b	$40, $01, $69, $36, $00, $03, $00, $02, $00, $07
	dc.l	Intro_sprite_data_21E9C
	dc.b	$00, $01, $6D, $3C, $00, $03, $00, $07, $00, $00
Team_name_tilemap_table: ; Team names (except in menu)
	dc.l	Team_name_tilemap_Madonna
	dc.l	Team_name_tilemap_Firenze
	dc.l	Team_name_tilemap_Millions
	dc.l	Team_name_tilemap_Bestowal
	dc.l	Team_name_tilemap_Blanche
	dc.l	Team_name_tilemap_Tyrant
	dc.l	Team_name_tilemap_Losel
	dc.l	Team_name_tilemap_May
	dc.l	Team_name_tilemap_Bullets
	dc.l	Team_name_tilemap_Dardan
	dc.l	Team_name_tilemap_Linden
	dc.l	Team_name_tilemap_Minarae
	dc.l	Team_name_tilemap_Rigel
	dc.l	Team_name_tilemap_Comet
	dc.l	Team_name_tilemap_Orchis
	dc.l	Team_name_tilemap_ZeroForce
Team_name_tilemap_Madonna:
	dc.b	$E1, $86, $FB, $63, $D0, $18, $00, $06, $1C, $1A, $1A, $00, $FD, $19, $01, $07, $1D, $1B, $1B, $01, $FF, $00
Team_name_tilemap_Firenze:
	dc.b	$E1, $86, $FB, $63, $D0, $0A, $10, $22, $08, $1A, $32, $08, $FD, $0B, $11, $23, $09, $1B, $33, $09, $FF, $00
Team_name_tilemap_Millions:
	dc.b	$E1, $86, $FB, $63, $D0, $18, $10, $16, $16, $10, $1C, $1A, $24, $FD, $19, $11, $17, $17, $11, $1D, $1B, $25, $FF, $00
Team_name_tilemap_Bestowal:
	dc.b	$E1, $86, $FB, $63, $D0, $02, $08, $24, $26, $1C, $2C, $00, $16, $FD, $03, $09, $25, $27, $1D, $2D, $01, $17, $FF, $00
Team_name_tilemap_Blanche:
	dc.b	$E1, $86, $FB, $63, $D0, $02, $16, $00, $1A, $04, $0E, $08, $FD, $03, $17, $01, $1B, $05, $0F, $09, $FF, $00
Team_name_tilemap_Tyrant:
	dc.b	$E1, $86, $FB, $63, $D0, $26, $30, $22, $00, $1A, $26, $FD, $27, $31, $23, $01, $1B, $27, $FF, $00
Team_name_tilemap_Losel:
	dc.b	$E1, $86, $FB, $63, $D0, $16, $1C, $24, $08, $16, $FD, $17, $1D, $25, $09, $17, $FF, $00
Team_name_tilemap_May:
	dc.b	$E1, $86, $FB, $63, $D0, $18, $00, $30, $FD, $19, $01, $31, $FF, $00
Team_name_tilemap_Bullets:
	dc.b	$E1, $86, $FB, $63, $D0, $02, $28, $16, $16, $08, $26, $24, $FD, $03, $29, $17, $17, $09, $27, $25, $FF, $00
Team_name_tilemap_Dardan:
	dc.b	$E1, $86, $FB, $63, $D0, $06, $00, $22, $06, $00, $1A, $FD, $07, $01, $23, $07, $01, $1B, $FF, $00
Team_name_tilemap_Linden:
	dc.b	$E1, $86, $FB, $63, $D0, $16, $10, $1A, $06, $08, $1A, $FD, $17, $11, $1B, $07, $09, $1B, $FF, $00
Team_name_tilemap_Minarae:
	dc.b	$E1, $86, $FB, $63, $D0, $18, $10, $1A, $00, $22, $00, $08, $FD, $19, $11, $1B, $01, $23, $01, $09, $FF, $00
Team_name_tilemap_Rigel:
	dc.b	$E1, $86, $FB, $63, $D0, $22, $10, $0C, $08, $16, $FD, $23, $11, $0D, $09, $17, $FF, $00
Team_name_tilemap_Comet:
	dc.b	$E1, $86, $FB, $63, $D0, $04, $1C, $18, $08, $26, $FD, $05, $1D, $19, $09, $27, $FF, $00
Team_name_tilemap_Orchis:
	dc.b	$E1, $86, $FB, $63, $D0, $1C, $22, $04, $0E, $10, $24, $FD, $1D, $23, $05, $0F, $11, $25, $FF, $00
Team_name_tilemap_ZeroForce:
	dc.b	$E1, $86, $FB, $63, $D0, $32, $08, $22, $1C, $0A, $1C, $22, $04, $08, $FD, $33, $09, $23, $1D, $0B, $1D, $23, $05, $09, $FF, $00
Championship_standings_tilemap_descriptors:
	dc.l	Championship_standings_tilemap_1
	dc.b	$20, $01, $40, $00, $00, $03, $00, $27, $00, $08
	dc.l	Championship_standings_tilemap_2
	dc.b	$00, $01, $44, $80, $00, $03, $00, $27, $00, $12
	dc.l	Championship_standings_tilemap_3
	dc.b	$20, $01, $6A, $9E, $00, $03, $00, $08, $00, $04
Championship_standings_tilemap_1:
	dc.b	$03, $00, $00, $01, $00, $01, $01, $F7, $DF, $7D, $F7, $DF, $7D, $F7, $80, $9E, $A7, $A8, $C8, $09, $EE, $7B, $8C, $C0, $9F, $27, $C8, $D0, $09, $F6, $7D, $8D
	dc.b	$40, $9F, $A7, $E8, $DB, $F8
Championship_standings_tilemap_2:
	dc.b	$08, $03, $00, $07, $00, $00, $02, $78, $0F, $3C, $07, $8C, $03
	dc.b	$83
	dc.b	$44, $08, $80, $04
	dc.b	$03
	dc.b	$CD, $0A, $02, $00, $70, $1C, $18, $08, $68, $7C, $41, $04, $34, $1E, $20, $38, $00, $07, $14, $50, $00, $01, $0E, $88, $A8, $00, $8A
	dc.b	$80
	dc.b	$00, $3C, $50, $20, $18, $00, $B0, $30, $C1, $90, $A7, $83, $91, $C1, $C0, $A0, $01, $01, $42, $08, $85, $80, $14
	dc.b	$05
	dc.b	$10, $2B, $A2, $15
	dc.b	$44
	dc.b	$0A, $E8, $85, $51, $02, $B8, $01, $50, $3C, $72, $D0, $20, $18, $61, $78, $D8, $42, $C1, $E6, $05, $7C, $C2, $CC, $7F, $1E, $02, $02, $82, $20
	dc.b	$8B
	dc.b	$00, $41, $03, $08, $58, $3C, $C0, $AE, $00, $58, $24, $21, $04, $3E, $92, $30, $8E, $20
	dc.b	$89
	dc.b	$01, $64, $F0, $AE, $00, $56, $0C, $00, $AC, $0A, $21, $59, $9C, $C4, $71, $04, $48, $0B, $27, $05, $62, $D1, $0A, $C5, $80, $39
	dc.b	$89
	dc.b	$00, $69, $03, $90, $82, $24
	dc.b	$05
	dc.b	$93, $02, $B1, $E8, $85, $61, $C2, $21, $C3, $80, $45
	dc.b	$03
	dc.b	$00, $41, $03, $08, $59, $28, $2B, $22, $88, $57, $48, $84, $0A, $01, $34, $2F, $12, $34, $41, $06, $78, $59, $18, $2C, $A4, $42
	dc.b	$01
	dc.b	$08, $A3, $2A, $79, $5D, $0C, $AE, $06, $91, $08, $04, $02, $C4, $08, $05, $88, $50, $04, $10, $60, $08, $22, $41, $A7, $BC, $17, $94, $F5, $3C, $5E
	dc.b	$53
	dc.b	$D4, $F1, $79, $4F
	dc.b	$53
	dc.b	$C2, $42, $10, $41, $A4, $42
	dc.b	$0B
	dc.b	$00, $B5, $0A, $00, $82, $24, $10, $B3, $C1, $A2, $16
	dc.b	$05
	dc.b	$86, $88, $58, $16
	dc.b	$1A
	dc.b	$21, $60, $58, $2F, $31, $04, $CA, $75, $82, $CA, $44, $20, $10, $0D, $80, $E0, $08, $20, $42, $10, $60, $1B, $A1, $7B, $34, $42, $C0, $B0, $D1, $0B, $02, $C3
	dc.b	$44, $2C, $0B, $0D, $10, $B0, $2C, $0A, $00, $58, $0F, $21, $04, $DD, $79, $01, $46, $58, $82, $14, $F1, $06, $18, $82, $0B, $E0, $BE, $FB, $EF, $BE, $FB, $1F
	dc.b	$C0, $00
Intro_sprite_data_21E9C:
	dc.b	$08, $00, $00, $EF, $00, $EF, $1F, $F8
Championship_standings_tilemap_3:
	dc.b	$09, $01, $00, $F7, $00, $00, $44, $3E, $17, $BA, $62, $22, $26, $1C, $0C, $08, $18, $00, $98, $F0, $91, $39, $E1, $C8, $6E, $19, $85
	dc.b	$FF
;Intro_sprite_data_21EC0
Intro_sprite_data_21EC0:
	dc.b	$09, $01, $01, $10, $01, $10, $02, $06, $20, $2F, $F0, $00
;Intro_sprite_data_21ECC
Intro_sprite_data_21ECC:
	dc.b	$09, $00, $01, $17, $01, $17, $27, $F8
;Intro_sprite_data_21ED4
Intro_sprite_data_21ED4:
	dc.b	$09, $01, $00, $FA, $00, $FA, $80, $90
	dc.b	$81
	dc.b	$45, $22, $E7, $91
	dc.b	$1F
	dc.b	$59, $0A, $49, $49, $0D, $E5, $87
	dc.b	$21
	dc.b	$B9, $27, $F0, $00
Team_intro_anim_data:
	dc.b	$09, $00, $01, $25, $01, $25, $27, $F8
;Intro_sprite_data_21EF6
Intro_sprite_data_21EF6:
	dc.b	$09, $00, $01, $2F, $00, $00, $40, $04, $0F, $13, $F8, $00
;Intro_sprite_data_21F02
Intro_sprite_data_21F02:
	dc.b	$09, $00, $01, $45, $00, $00, $40, $64, $01, $40, $14, $01, $40, $14, $01, $43, $F8, $00
;Intro_sprite_data_21F14
Intro_sprite_data_21F14:
	dc.b	$09, $00, $01, $56, $00, $00, $05, $03, $C4, $FE
;Intro_sprite_data_21F1E
Intro_sprite_data_21F1E:
	dc.b	$09, $00, $01, $3E, $00, $00, $43, $8D, $B4, $01, $76, $DC, $05, $5B, $E7, $F0
;Intro_sprite_data_21F2E
Intro_sprite_data_21F2E:
	dc.b	$09, $00, $01, $82, $00, $00, $40, $04, $0F, $13, $F8, $00
;Intro_sprite_data_21F3A
Intro_sprite_data_21F3A:
	dc.b	$09, $00, $01, $98, $01, $98, $3F, $F8
;Intro_sprite_data_21F42
Intro_sprite_data_21F42:
	dc.b	$09, $00, $01, $A8, $01, $A8, $3F, $F8
;Intro_sprite_data_21F4A
Intro_sprite_data_21F4A:
	dc.b	$09, $00, $01, $B8, $00, $00, $05, $03, $C4, $FE
;Intro_sprite_data_21F54
Intro_sprite_data_21F54:
	dc.b	$09, $02, $01, $CF, $00, $00, $40, $04, $0D, $81, $A0
	dc.b	$8B
	dc.b	$FC, $00
Intro_sprite_data_21F62:
	dc.b	$09, $00, $01, $E4, $00, $00, $05, $03, $C4, $FE
Intro_sprite_data_21F6C: ; Woman with umbrella
	dc.b	$0A, $00, $01, $FB, $00, $00, $1D, $00, $90, $09, $00, $91, $05, $10, $51, $17, $F8, $00
Championship_standings_compressed_tilemap:
	dc.b	$82, $16, $80, $03, $01, $14, $05, $25, $0D, $35, $10, $45, $11, $55, $12, $65, $18, $73, $00, $81, $04, $04, $16, $34, $27, $71, $82, $05, $0E, $18, $E4, $83
	dc.b	$05, $0C, $17, $6D, $84, $05, $14, $17, $70, $85, $06, $27, $18, $E9, $86, $05, $16, $18, $E6, $87, $05, $15, $17, $6F, $28, $EE, $88, $05, $0F, $17, $6E, $89
	dc.b	$06, $2F, $18, $EC, $8A, $06, $2E, $18, $E5, $8B, $07, $6C, $18, $EA, $8C, $06, $35, $18, $EB, $8D, $06, $26, $18, $E8, $8E, $06, $33, $18, $E7, $8F, $06, $32
	dc.b	$FF, $00, $00, $00, $FF, $90, $00, $00, $00, $02, $63, $31, $98, $CC, $7F, $FB, $FF, $DF, $FE, $CC, $66, $33, $19, $80, $05, $0A, $14, $28, $7F, $E3, $FF, $1F
	dc.b	$F8, $A1, $42, $85, $00, $05, $85, $85, $85, $87, $FE, $7F, $F3, $FF, $9B, $0B, $0B, $0B, $00, $05, $0A, $14, $28, $7F, $E3, $FF, $1F, $F8, $A1, $42, $85, $00
	dc.b	$06, $A6, $A6, $A6, $A7, $FE, $FF, $F7, $FF, $BD, $92, $C9, $64, $B2, $00, $00, $03, $FE, $20, $00, $00, $00, $01, $FF, $20, $BF, $B2, $5E, $48, $72, $00, $07
	dc.b	$FC, $82, $FF, $C8, $00, $25, $FF, $21, $FF, $2F, $F9, $00, $00, $00, $08, $FE, $89, $BC, $9F, $A4, $57, $7F, $12, $14, $83, $B8, $2F, $24, $5C, $D7, $5B, $90
	dc.b	$43, $F6, $51, $A0, $18, $E0, $5C, $D7, $07, $5B, $90, $47, $F6, $52, $A0, $10, $71, $E0, $E0, $DE, $4B, $38, $37, $FC, $4B, $FD, $46, $FF, $10, $47, $F4, $40
	dc.b	$BA, $DC, $81, $BF, $E2, $3F, $D4, $5F, $EA, $05, $FF, $10, $02, $3F, $B2, $5E, $43, $C2, $1C, $25, $C2, $2E, $03, $93, $99, $C1, $C0, $00, $31, $B3, $FD, $20
	dc.b	$00, $DF, $E4, $9E, $C8, $DF, $8F, $FC, $80, $07, $F6, $40, $5F, $E9, $6C, $BC, $09, $38, $09, $38, $B8, $38, $0C, $39, $AE, $2E, $02, $0E, $2E, $0A, $E2, $CD
	dc.b	$3F, $46, $73, $FE, $ED, $DF, $F6, $FF, $37, $FD, $3F, $E4, $07, $FE, $FF, $FB, $FF, $6F, $FB, $7F, $D3, $FE, $40, $7F, $AE, $9F, $ED, $CB, $FC, $D3, $7F, $59
	dc.b	$7F, $A8, $BF, $D2, $01, $7F, $C8, $E3, $FF, $FF, $F6, $97, $35, $CD, $A3, $68, $DB, $36, $C0, $2E, $5F, $E2, $FF, $FF, $FF, $4B, $9A, $E6, $D1, $B4, $6D, $9B
	dc.b	$60, $17, $FA, $5C, $FF, $DF, $61, $FF, $6E, $65, $CD, $73, $68, $DA, $36, $CD, $B0, $0B, $CF, $FD, $83, $63, $FC, $1B, $14, $92, $2F, $EC, $63, $FA, $60, $01
	dc.b	$E2, $6C, $BF, $C1, $36, $92, $1B, $7E, $C5, $50, $FE, $98, $03, $C6, $1F, $C6, $8F, $24, $5C, $5C, $04, $1C, $5C, $72, $96, $52, $CA, $0E, $33, $45, $D8, $CA
	dc.b	$68, $E5, $2C, $80, $00, $00, $00, $00, $00, $25, $94, $B2, $96, $42, $59, $2B, $A2, $E7, $DC, $BF, $9F, $87, $E7, $D5, $CF, $8B, $9E, $E8, $39, $EE, $83, $9F
	dc.b	$17, $3E, $4F, $E4, $2E, $6B, $97, $90, $00, $00, $01, $6C, $00, $00, $0D, $9F, $D6, $00, $06, $D9, $DF, $BD, $6D, $3F, $7B, $0F, $DB, $4C, $7F, $AC, $00, $1F
	dc.b	$FD, $FF, $EF, $FD, $BF, $EC, $00, $13, $62, $6C, $5B, $13, $FF, $8C, $FF, $1F, $20, $00, $0B, $FC, $7C, $80, $00, $00, $0F, $FC, $C0, $00, $00, $FF, $D4, $BF
	dc.b	$F5, $C2, $3F, $A6, $28, $BF, $B1, $B1, $49, $58, $FF, $05, $7F, $AC, $15, $DF, $CF, $59, $A5, $96, $3F, $DE, $7F, $C5, $77, $FA, $3F, $E9, $FF, $DF, $FE, $01
	dc.b	$FF, $FF, $F9, $7F, $E3, $FE, $9F, $FD, $FD, $E6, $D4, $BD, $B9, $17, $3D, $CB, $91, $73, $DC, $7F, $3E, $5C, $F7, $2F, $E8, $9E, $EF, $D3, $7E, $A1, $C7, $F4
	dc.b	$DF, $A4, $FE, $37, $EF, $5D, $FA, $DF, $D5, $DF, $6F, $D5, $B5, $C5, $C2, $4E, $2E, $3F, $C6, $5D, $9F, $C6, $71, $D9, $FD, $6A, $5B, $FF, $BF, $CB, $D1, $98
	dc.b	$70, $8E, $E3, $FB, $B2, $E5, $FD, $DC, $7F, $8D, $4D, $79, $8F, $F3, $51, $FA, $FE, $EE, $6F, $CF, $BA, $E0, $00, $86, $69, $9E, $B0, $FD, $EF, $23, $7F, $5B
	dc.b	$C2, $D1, $FD, $A0, $00, $01, $33, $7F, $E9, $FB, $40, $00, $03, $FE, $9F, $F4, $C3, $A4, $F9, $3E, $59, $81, $8C, $F7, $3A, $A1, $7B, $85, $40, $AC, $AB, $0E
	dc.b	$E6, $FF, $5C, $00, $1B, $FB, $76, $D6, $15, $86, $F8, $6F, $5D, $E0, $00, $7B, $8E, $F5, $AA, $D5, $B5, $85, $56, $A7, $B8, $D4, $00, $17, $79, $DE, $77, $AD
	dc.b	$56, $A1, $7F, $EE, $00, $0B, $BD, $77, $9A, $E2, $B8, $AC, $37, $9A, $80, $00, $8D, $65, $56, $EF, $5D, $E0, $01, $FB, $71, $1A, $CA, $A2, $A3, $15, $00, $09
	dc.b	$6F, $5F, $DB, $8F, $ED, $50, $00, $01, $FE, $D5, $04, $3F, $75, $40, $00, $0D, $FD, $D5, $00, $00, $00, $1A, $FF, $D5, $3D, $AF, $E4, $2E, $83, $CE, $41, $C0
	dc.b	$45, $D9, $17, $53, $F5, $3C, $85, $CD, $BF, $F7, $0D, $72, $D1, $ED, $B0, $00, $36, $7A, $76, $51, $69, $D3, $8C, $AE, $9F, $19, $4E, $DC, $CB, $8E, $52, $74
	dc.b	$AC, $6E, $6E, $67, $37, $C2, $8F, $FE, $A4, $3F, $68, $00, $00, $1B, $41, $D4, $B0, $00, $01, $8D, $91, $75, $00, $00, $01, $7F, $E9, $33, $DC, $E0, $00, $00
	dc.b	$55, $B9, $EE, $9D, $BD, $C2, $A0, $00, $6A, $B5, $85, $56, $A7, $78, $00, $08, $6F, $85, $61, $55, $A9, $EE, $00, $00, $16, $AB, $59, $54, $D4, $EF, $00, $00
	dc.b	$07, $71, $A8, $00, $0C, $6F, $85, $71, $53, $BC, $00, $00, $6D, $56, $A6, $AB, $55, $AA, $D4, $00, $0D, $65, $51, $59, $54, $00, $00, $AA, $D4, $36, $6F, $DD
	dc.b	$7E, $B6, $75, $9C, $FE, $94, $CF, $0E, $93, $D2, $DE, $95, $9D, $7A, $65, $D2, $67, $59, $CF, $E9, $40, $6C, $EB, $38, $8F, $4C, $BA, $44, $67, $59, $C0, $33
	dc.b	$9F, $DA, $99, $DB, $FA, $59, $74, $CA, $79, $74, $B6, $73, $FB, $53, $38, $FD, $8F, $4E, $77, $45, $8B, $FB, $78, $FE, $AC, $00, $21, $AE, $FD, $69, $5C, $A8
	dc.b	$1B, $FB, $78, $75, $0D, $80, $6C, $87, $ED, $E9, $07, $CE, $F0, $00, $02, $2E, $C9, $69, $FA, $9E, $57, $D1, $B3, $06, $D3, $19, $80, $05, $19, $7D, $1B, $98
	dc.b	$B8, $DD, $3C, $28, $5D, $90, $00, $42, $E7, $EB, $98, $00, $00, $3F, $72, $C9, $F6, $FE, $F8, $00, $04, $7B, $A5, $BE, $35, $00, $00, $B5, $C7, $74, $B7, $80
	dc.b	$00, $11, $FF, $BF, $EE, $FF, $7F, $1D, $B9, $FE, $DD, $66, $5F, $D5, $80, $04, $26, $FD, $65, $2B, $CA, $0D, $3F, $AE, $DE, $A8, $EC, $5D, $81, $AC, $86, $C0
	dc.b	$6E, $AF, $F3, $2A, $3F, $EE, $7F, $B6, $23, $FA, $B1, $1F, $D5, $C5, $FB, $19, $A8, $03, $5E, $EC, $B5, $A1, $FF, $F7, $F1, $9C, $BF, $C8, $75, $A5, $9B, $F3
	dc.b	$00, $0F, $FF, $2A, $37, $45, $46, $E9, $FF, $E0, $00, $FF, $F6, $7F, $E6, $3F, $E8, $00, $01, $FF, $EF, $EB, $2F, $F2, $39, $A5, $9B, $F3, $01, $7F, $94, $0F
	dc.b	$3F, $F1, $33, $C5, $87, $EB, $AD, $B2, $D9, $EA, $04, $32, $C3, $9A, $FE, $55, $B6, $62, $36, $37, $1D, $59, $9B, $F9, $E9, $74, $C0, $09, $67, $8A, $09, $5E
	dc.b	$6A, $CD, $6E, $5B, $E8, $02, $D9, $D0, $CC, $E6, $F1, $0B, $CF, $F6, $66, $3F, $DD, $2F, $00, $1C, $F0, $EC, $E5, $70, $11, $B1, $B5, $D4, $B0, $00, $00, $0F
	dc.b	$EC, $F7, $CE, $C0, $00, $C5, $63, $DC, $DF, $DB, $C3, $78, $02, $1B, $E3, $FB, $78, $55, $7F, $8F, $0F, $DB, $C6, $A0, $00, $17, $F8, $ED, $FE, $BC, $77, $CB
	dc.b	$BB, $1D, $D2, $DE, $00, $00, $0A, $E3, $7E, $37, $E3, $BA, $5F, $B7, $35, $87, $70, $00, $00, $35, $6B, $F6, $59, $00, $00, $FE, $AE, $1F, $B3, $87, $ED, $21
	dc.b	$75, $75, $AB, $36, $73, $37, $A8, $4B, $A8, $41, $9B, $17, $F5, $6B, $FD, $33, $FE, $49, $BF, $B9, $53, $FA, $B1, $1F, $D5, $88, $FF, $6C, $FF, $CF, $FE, $9F
	dc.b	$D9, $9D, $9F, $DB, $AA, $7F, $F4, $00, $07, $FF, $47, $FF, $40, $00, $4D, $FE, $63, $FE, $BF, $FE, $80, $00, $FF, $E8, $FF, $E8, $C5, $80, $13, $5B, $F5, $BA
	dc.b	$7E, $AD, $BB, $57, $F5, $AB, $90, $9A, $CB, $37, $E7, $E6, $00, $1E, $8B, $1C, $A1, $31, $9B, $4E, $B9, $9B, $FB, $82, $E5, $77, $E9, $0E, $4B, $68, $4D, $8B
	dc.b	$62, $D2, $D6, $96, $8B, $E9, $2A, $37, $F6, $D0, $7F, $74, $2E, $E9, $AC, $29, $C9, $68, $F3, $05, $B1, $B6, $60, $49, $EE, $93, $F5, $12, $B0, $84, $D6, $5F
	dc.b	$D6, $52, $1F, $A6, $7C, $39, $C0, $00, $2E, $7F, $A3, $DF, $7E, $40, $01, $8A, $CB, $7C, $3B, $A3, $BC, $1A, $AE, $F3, $BD, $77, $9E, $E3, $BC, $D5, $7B, $80
	dc.b	$1F, $B7, $35, $3F, $C7, $6D, $4D, $4E, $F6, $F7, $03, $BC, $00, $B5, $35, $5A, $88, $FE, $DC, $FF, $DE, $A6, $A0, $08, $54, $D4, $47, $FE, $FF, $F7, $3F, $E7
	dc.b	$5F, $DB, $9A, $80, $6B, $0A, $83, $FD, $75, $FF, $BE, $F8, $77, $00, $2B, $0D, $F8, $AC, $77, $9A, $E3, $7A, $EF, $35, $3B, $C0, $8F, $71, $AB, $7B, $B1, $BE
	dc.b	$15, $C6, $F3, $BC, $EF, $8E, $F9, $54, $2E, $CD, $77, $65, $B3, $98, $00, $00, $13, $1F, $D1, $9E, $80, $00, $00, $4C, $00, $00, $0C, $7F, $FB, $FF, $7F, $FD
	dc.b	$FF, $B7, $FE, $FF, $FA, $07, $ED, $96, $C7, $F7, $70, $FD, $EC, $3F, $6D, $0F, $DD, $C3, $F7, $A0, $4A, $67, $4C, $6C, $05, $B1, $B3, $13, $00, $0D, $A6, $74
	dc.b	$C1, $B6, $3F, $D6, $D8, $7F, $B7, $31, $FE, $E8, $00, $D8, $4B, $FE, $DF, $FB, $FF, $E8, $02, $1C, $2C, $0D, $B1, $B3, $13, $00, $31, $34, $7A, $C0, $00, $01
	dc.b	$7F, $E9, $33, $7D, $AE, $0D, $BA, $93, $47, $93, $29, $3D, $D3, $47, $37, $E5, $27, $BA, $B2, $7E, $5D, $D9, $5F, $95, $66, $18, $A8, $C5, $40, $0B, $BE, $1F
	dc.b	$B7, $86, $F9, $7F, $DF, $FE, $E0, $08, $54, $D6, $3F, $B7, $1F, $C7, $35, $3F, $F7, $00, $1A, $9A, $AD, $57, $B8, $EF, $6D, $63, $56, $D4, $FF, $DF, $79, $EE
	dc.b	$02, $15, $35, $02, $55, $3F, $F7, $FE, $38, $00, $D6, $15, $6F, $ED, $CD, $4F, $FD, $FF, $EF, $FE, $70, $01, $AC, $AB, $8D, $F2, $FF, $BF, $FD, $C0, $0B, $53
	dc.b	$55, $AC, $37, $9A, $8D, $E7, $79, $A9, $FF, $BE, $2A, $01, $AA, $D5, $BB, $CF, $F5, $E5, $55, $A9, $A9, $A9, $FE, $BA, $EF, $02, $5F, $F7, $FE, $C1, $9F, $F9
	dc.b	$0B, $97, $F2, $17, $2F, $E4, $2E, $CF, $E4, $2D, $3F, $90, $DF, $E4, $2D, $3F, $B0, $73, $79, $9F, $F9, $0B, $92, $FE, $A1, $CF, $6F, $EA, $2E, $7B, $7F, $71
	dc.b	$0F, $D4, $47, $F5, $0B, $45, $FD, $C1, $CF, $FF, $1F, $F8, $FF, $C7, $FE, $3F, $F1, $FF, $8F, $FC, $7F, $E3, $F5, $16, $C6, $76, $C6, $60, $00, $3F, $54, $FC
	dc.b	$CF, $07, $17, $5B, $33, $43, $67, $5B, $30, $00, $10, $FD, $57, $ED, $00, $2E, $C6, $58, $9B, $16, $C5, $9D, $FD, $63, $4F, $EB, $00, $00, $1F, $F6, $B1, $FE
	dc.b	$B0, $00, $0B, $2F, $F0, $8D, $8F, $F1, $2C, $B6, $E4, $36, $00, $01, $FB, $2B, $37, $F8, $8D, $FD, $15, $DA, $BE, $ED, $70, $FC, $38, $00, $04, $FC, $35, $BB
	dc.b	$AE, $D9, $61, $C9, $27, $E5, $2A, $39, $24, $FC, $A5, $47, $24, $9F, $94, $38, $1B, $BF, $69, $FF, $8F, $FC, $7F, $E3, $FF, $1F, $F8, $FF, $C7, $FC, $BF, $E4
	dc.b	$00, $00, $7F, $CB, $5B, $B5, $FD, $95, $80, $00, $66, $FC, $DB, $43, $FD, $25, $FD, $B6, $CA, $72, $2F, $47, $EF, $CC, $C7, $F3, $E7, $A2, $33, $2C, $C7, $F3
	dc.b	$ED, $A2, $E4, $66, $06, $86, $FE, $88, $DB, $93, $2E, $4E, $6F, $F9, $03, $FF, $40, $06, $3F, $8C, $FB, $AD, $FC, $27, $9B, $0F, $E2, $05, $7E, $1E, $07, $33
	dc.b	$EE, $E6, $D6, $9C, $8F, $3F, $A2, $07, $82, $FE, $90, $FE, $A1, $AE, $3F, $A8, $02, $37, $F0, $CF, $85, $80, $0A, $E6, $B9, $B4, $6D, $1B, $66, $D8, $2A, $7F
	dc.b	$B9, $7F, $B4, $5D, $70, $C3, $AE, $1F, $BA, $6B, $8F, $EA, $87, $E8, $97, $F4, $9F, $AA, $8D, $0E, $65, $D9, $B7, $3C, $5C, $D7, $66, $79, $E9, $FA, $25, $FD
	dc.b	$77, $EA, $9D, $9C, $73, $8B, $E7, $BB, $5C, $DA, $FC, $A5, $47, $24, $9F, $93, $5C, $B4, $72, $2D, $1A, $FC, $96, $CD, $A3, $92, $4F, $CA, $54, $CC, $00, $5C
	dc.b	$D7, $36, $8D, $A3, $6C, $DB, $00, $00, $6B, $9A, $E6, $D1, $B4, $6D, $9B, $69, $39, $5D, $07, $2B, $80, $05, $CD, $73, $68, $DA, $36, $CD, $B4, $1C, $AE, $83
	dc.b	$95, $C0, $00, $17, $FE, $DF, $F2, $FF, $A7, $FF, $8B, $8B, $8B, $8B, $81, $71, $71, $71, $77, $FF, $BF, $ED, $FF, $2F, $EA, $3A, $80, $00, $3F, $AC, $6D, $FF
	dc.b	$2E, $17, $DA, $FF, $D2, $00, $00, $E6, $D9, $4D, $9F, $A6, $FF, $91, $E1, $7F, $00, $00, $00, $37, $85, $FC, $2E, $0F, $C3, $C0, $18, $7E, $1E, $DB, $96, $E3
	dc.b	$FA, $88, $FE, $A0, $01, $1F, $D4, $47, $F5, $12, $DC, $E7, $DC, $1A, $F6, $BA, $E1, $72, $BD, $AE, $10, $7B, $5C, $21, $CD, $2C, $C3, $7F, $95, $4E, $4F, $FD
	dc.b	$0B, $A5, $9E, $33, $C3, $F0, $F7, $5D, $27, $62, $E7, $5D, $1C, $C1, $75, $C2, $1B, $37, $5D, $0C, $B0, $E9, $E4, $FC, $B0, $E9, $E4, $FC, $B0, $E9, $E4, $FC
	dc.b	$A1, $FA, $27, $FE, $C8, $FF, $98, $00, $00, $77, $FB, $4F, $FA, $40, $00, $0F, $FC, $FF, $E4, $00, $00, $FF, $B7, $FD, $80, $00, $0F, $FB, $7F, $DB, $FE, $80
	dc.b	$62, $92, $A4, $A8, $69, $FC, $2E, $67, $7F, $DB, $82, $D2, $14, $34, $85, $0D, $0D, $21, $49, $50, $63, $F4, $85, $DC, $1D, $0B, $2D, $80, $6D, $00, $10, $E0
	dc.b	$EA, $1B, $42, $CB, $65, $FD, $20, $11, $FD, $20, $11, $74, $C6, $DF, $B4, $76, $53, $59, $D0, $76, $53, $59, $D0, $76, $4E, $B3, $A0, $EC, $A6, $D9, $7C, $3F
	dc.b	$7A, $07, $FD, $31, $49, $52, $54, $5F, $DC, $D1, $BF, $BD, $02, $1F, $FD, $FF, $E8, $C6, $B8, $CC, $01, $FE, $DC, $BF, $FB, $FF, $47, $1C, $DF, $9B, $F3, $7D
	dc.b	$8D, $1D, $47, $58, $CC, $BF, $AF, $E4, $6F, $EB, $DC, $D7, $17, $2B, $8D, $E8, $C4, $D6, $6C, $FF, $9B, $93, $32, $FD, $A4, $3F, $5C, $DC, $A5, $32, $D2, $D1
	dc.b	$99, $D6, $12, $4D, $F7, $F4, $1A, $62, $F3, $FD, $D3, $34, $A6, $00, $0E, $1F, $BC, $E0, $7F, $B0, $AF, $83, $CB, $E4, $F6, $BC, $3D, $AF, $37, $38, $7E, $A1
	dc.b	$CB, $CA, $5E, $EB, $80, $C3, $F0, $F0, $22, $F7, $42, $E3, $B8, $03, $FA, $88, $FE, $A0, $0C, $3D, $C3, $F7, $07, $F7, $0D, $DC, $D7, $88, $BD, $5F, $17, $B5
	dc.b	$E6, $E7, $1D, $D1, $7A, $B9, $FF, $AA, $3B, $AE, $5F, $ED, $17, $1F, $E5, $05, $75, $C3, $0E, $B8, $7E, $AA, $D0, $77, $2D, $3F, $44, $77, $1F, $DD, $3A, $EF
	dc.b	$D4, $2E, $72, $CD, $5D, $73, $73, $8B, $CD, $CD, $E4, $E5, $34, $FD, $11, $FD, $53, $B2, $FD, $53, $5F, $96, $1D, $3C, $9F, $96, $1D, $3E, $32, $C3, $81, $77
	dc.b	$ED, $3A, $E8, $00, $00, $07, $7F, $90, $00, $04, $1E, $5F, $07, $AB, $E1, $B8, $01, $17, $B5, $ED, $7B, $5F, $07, $8C, $3C, $00, $24, $FC, $6E, $93, $E3, $C3
	dc.b	$AD, $78, $36, $86, $90, $A1, $A4, $28, $69, $0A, $1A, $4A, $92, $A0, $0B, $FC, $40, $02, $D0, $01, $1E, $1F, $B8, $6F, $F6, $01, $DD, $0D, $CD, $78, $7B, $5E
	dc.b	$6E, $71, $DD, $17, $AB, $B8, $73, $D3, $AF, $31, $FF, $61, $FF, $20, $07, $F9, $2F, $C4, $DF, $F6, $1F, $F2, $00, $5B, $19, $7F, $A7, $FF, $63, $FE, $40, $08
	dc.b	$70, $BE, $9F, $A9, $A2, $CC, $7F, $57, $CC, $2C, $BF, $D2, $E0, $00, $E1, $FC, $2A, $2F, $F0, $B0, $E5, $A3, $5D, $6E, $10, $BA, $8B, $48, $3C, $D0, $D3, $97
	dc.b	$92, $EF, $D2, $7F, $29, $77, $1D, $D7, $35, $EA, $E2, $F2, $F8, $65, $07, $BB, $29, $64, $72, $2F, $2F, $6B, $9E, $5E, $66, $39, $3C, $BF, $93, $F3, $F7, $2B
	dc.b	$FF, $44, $20, $F6, $BA, $E0, $D7, $B5, $D7, $06, $BD, $AE, $10, $FD, $43, $5E, $DC, $CB, $CB, $D7, $39, $3F, $3C, $4E, $AE, $FD, $53, $B2, $A3, $8F, $FA, $97
	dc.b	$F7, $50, $FD, $53, $9E, $0B, $AE, $18, $75, $D1, $E4, $97, $2B, $AE, $8E, $78, $CC, $BB, $74, $37, $2B, $E4, $FC, $3E, $4F, $01, $BF, $F8, $DC, $BF, $B8, $6B
	dc.b	$F0, $F1, $2D, $C0, $43, $FF, $1B, $97, $F7, $0A, $FC, $3F, $1B, $80, $10, $FF, $C6, $BF, $E8, $00, $50, $00, $0E, $E3, $BA, $E6, $BD, $5C, $5E, $5E, $0B, $DD
	dc.b	$94, $B2, $2E, $DC, $5E, $D7, $AB, $CC, $C7, $25, $7F, $27, $E7, $EE, $3C, $3F, $7D, $C0, $62, $70, $25, $38, $94, $EB, $FC, $53, $36, $26, $00, $00, $0F, $F0
	dc.b	$7F, $52, $22, $F0, $1E, $03, $C3, $EE, $18, $75, $C3, $F9, $4A, $E3, $FB, $A0, $D7, $5C, $1B, $CC, $DD, $C7, $30, $DE, $45, $BA, $9F, $A2, $6F, $F2, $B9, $23
	dc.b	$9C, $B3, $57, $5C, $DC, $C6, $7B, $B6, $49, $04, $90, $49, $24, $98, $FF, $8F, $F0, $40, $00, $0F, $F8, $9F, $DC, $35, $3F, $73, $C4, $00, $00, $FD, $8E, $5F
	dc.b	$A9, $FD, $8E, $5F, $A9, $00, $00, $00, $8F, $EB, $0F, $EB, $26, $72, $3B, $55, $46, $16, $1F, $D6, $4D, $9F, $E8, $A3, $FA, $C1, $1F, $D6, $37, $AD, $53, $5E
	dc.b	$84, $E4, $42, $9F, $A3, $EA, $7E, $BB, $4B, $3A, $8D, $1C, $5C, $5C, $CD, $DA, $A1, $43, $C4, $FF, $F3, $FD, $9A, $7F, $09, $36, $FE, $7E, $7B, $A7, $67, $E7
	dc.b	$D6, $EC, $8E, $54, $6D, $CD, $D9, $FA, $FF, $D2, $E4, $CE, $46, $7E, $CA, $6E, $B9, $BF, $58, $7F, $D8, $5C, $87, $89, $42, $C7, $7E, $8D, $C7, $F7, $FB, $3F
	dc.b	$3F, $AE, $5C, $0D, $20, $FD, $9F, $CF, $72, $39, $85, $85, $8D, $47, $23, $90, $A3, $7F, $58, $DD, $3F, $5A, $8C, $73, $17, $4D, $67, $A9, $DB, $C8, $79, $3F
	dc.b	$4B, $5F, $CF, $D6, $D3, $F3, $54, $B0, $B1, $76, $EA, $9F, $A3, $2C, $5D, $7F, $DB, $FE, $C3, $C5, $50, $EB, $FA, $3E, $45, $4C, $8F, $E7, $CB, $1C, $69, $B2
	dc.b	$99, $2E, $DF, $D4, $7E, $8C, $B2, $3A, $7F, $77, $AC, $1E, $BE, $8F, $D6, $1E, $30, $D5, $5C, $C7, $23, $90, $FE, $8D, $C8, $C5, $62, $E8, $53, $FD, $BA, $80
	dc.b	$04, $DA, $E1, $3A, $E0, $93, $75, $C3, $50, $00, $00, $06, $D9, $3B, $21, $64, $EC, $00, $00, $3F, $53, $77, $65, $DF, $B9, $BB, $B2, $EB, $C0, $0D, $DD, $17
	dc.b	$F6, $3E, $08, $A8, $BD, $90, $FE, $4E, $9F, $A9, $00, $00, $3F, $F3, $FB, $9C, $9E, $34, $12, $CB, $38, $D5, $25, $5D, $25, $BC, $76, $72, $EB, $B3, $97, $4F
	dc.b	$E9, $C1, $1B, $CF, $F9, $FC, $FF, $5E, $3F, $C3, $9F, $F9, $F0, $F3, $7B, $FF, $62, $5D, $87, $14, $FD, $C2, $14, $18, $49, $21, $FE, $C1, $7C, $B7, $6C, $DD
	dc.b	$B3, $F5, $05, $85, $18, $74, $54, $28, $DF, $CF, $FE, $BB, $2F, $D7, $0F, $F0, $9F, $F3, $97, $C9, $FA, $5A, $0F, $41, $2C, $F2, $C2, $56, $3A, $56, $3B, $C0
	dc.b	$9D, $9F, $B5, $34, $CC, $E4, $72, $86, $47, $23, $91, $CF, $FB, $F7, $7E, $7C, $E4, $72, $5C, $8E, $47, $23, $91, $CC, $E6, $73, $3C, $E7, $33, $99, $CC, $FF
	dc.b	$47, $3A, $64, $72, $39, $2D, $C7, $23, $91, $CB, $9F, $23, $FA, $E5, $9F, $2C, $E7, $43, $9C, $72, $C6, $73, $B7, $36, $FE, $94, $F0, $4A, $38, $EE, $8D, $FA
	dc.b	$46, $FD, $C1, $77, $9A, $F3, $56, $DA, $2F, $3E, $5F, $CE, $87, $F6, $F4, $FD, $D5, $F6, $FE, $09, $D4, $FF, $23, $32, $C8, $A2, $FE, $9A, $FA, $B7, $F5, $C5
	dc.b	$03, $7A, $93, $36, $E7, $63, $75, $3F, $4B, $31, $B4, $2C, $76, $CE, $B3, $ED, $0B, $9A, $E6, $DC, $F6, $2E, $CC, $CE, $66, $CB, $63, $99, $D6, $1A, $97, $D0
	dc.b	$F3, $14, $98, $DC, $72, $39, $1C, $8E, $79, $1C, $8E, $45, $27, $3F, $AE, $39, $2E, $65, $27, $CF, $28, $65, $29, $F3, $8F, $4B, $73, $FD, $2A, $CE, $02, $CE
	dc.b	$67, $33, $99, $D6, $73, $39, $9C, $CE, $00, $9E, $13, $97, $C3, $64, $E5, $8A, $F8, $67, $3C, $A6, $00, $35, $EC, $DC, $5F, $7F, $F4, $58, $ED, $7F, $93, $B4
	dc.b	$FE, $AE, $75, $9A, $7F, $D5, $9D, $86, $67, $CF, $B0, $CF, $B1, $B3, $EC, $9F, $64, $A7, $D9, $3B, $7F, $71, $32, $2F, $EB, $F4, $BD, $F9, $AE, $6B, $3A, $CF
	dc.b	$A2, $E7, $B0, $D3, $36, $F5, $59, $A9, $0B, $3D, $BB, $30, $CF, $E4, $1F, $D8, $F2, $DF, $A0, $0B, $32, $CC, $B3, $19, $96, $63, $D1, $29, $80, $FD, $4F, $27
	dc.b	$EA, $40, $09, $8A, $4F, $2E, $1F, $D1, $1A, $5F, $FC, $80, $DF, $E0, $B7, $F8, $2D, $FE, $0A, $FF, $63, $FE, $23, $FF, $03, $FE, $3F, $F1, $FF, $8F, $FE, $3F
	dc.b	$E2, $3F, $91, $FA, $98, $A2, $FF, $45, $7F, $C2, $7F, $C2, $7F, $F1, $FF, $11, $FA, $8D, $BF, $A8, $5C, $FA, $73, $54, $39, $2E, $65, $15, $3A, $60, $87, $A8
	dc.b	$A1, $DD, $FB, $9D, $DF, $F1, $02, $53, $B2, $59, $49, $36, $39, $BA, $45, $02, $F4, $EC, $8F, $4E, $C0, $31, $B2, $5B, $33, $96, $C1, $38, $1A, $43, $40, $D9
	dc.b	$E1, $C3, $64, $78, $6C, $9C, $01, $0D, $21, $A2, $A0, $59, $F6, $52, $09, $4B, $A8, $B4, $9E, $53, $D1, $6E, $C6, $58, $C8, $E8, $78, $DC, $91, $45, $A7, $54
	dc.b	$F0, $A7, $2D, $04, $F4, $5A, $5C, $B4, $9D, $6D, $94, $AD, $94, $A7, $B9, $15, $27, $43, $48, $65, $0D, $29, $72, $D3, $49, $CA, $47, $86, $80, $06, $4E, $DD
	dc.b	$0D, $B2, $84, $E6, $7C, $E9, $A3, $52, $73, $3E, $94, $3A, $70, $00, $03, $C0, $50, $46, $80, $00, $38, $0A, $47, $43, $41, $45, $48, $D0, $50, $37, $F8, $9C
	dc.b	$42, $6E, $95, $E5, $E1, $F1, $BD, $5E, $1E, $1F, $C7, $F9, $02, $3B, $83, $C4, $5E, $00, $DC, $00, $78, $78, $78, $7C, $3F, $70, $78, $5F, $86, $47, $33, $B2
	dc.b	$37, $51, $00, $01, $F7, $FE, $93, $8B, $99, $D7, $33, $7A, $BB, $1E, $DE, $3D, $52, $E5, $E2, $00, $E3, $FC, $80, $D4, $C3, $F9, $3F, $63, $B0, $F5, $6E, $5B
	dc.b	$BF, $82, $03, $E3, $B8, $BC, $3E, $28, $BF, $A8, $57, $DF, $FA, $26, $E8, $7A, $95, $16, $ED, $37, $5E, $3F, $90, $1E, $1E, $1A, $8E, $D7, $71, $76, $B7, $DD
	dc.b	$46, $DD, $40, $00, $BC, $00, $07, $F2, $57, $FB, $23, $0F, $93, $F0, $80, $1F, $EC, $94, $FF, $C9, $DD, $B7, $71, $7C, $9E, $B3, $2C, $CB, $31, $99, $66, $3D
	dc.b	$12, $98, $0D, $C9, $D4, $25, $FC, $16, $FF, $05, $BF, $C1, $5F, $EC, $2F, $F4, $47, $37, $F6, $17, $F5, $D0, $D4, $EA, $7F, $5C, $BA, $CB, $5C, $7E, $B2, $3F
	dc.b	$AC, $8E, $A7, $58, $67, $C9, $FC, $E1, $17, $5E, $EC, $CA, $14, $D8, $DC, $CA, $37, $62, $E4, $04, $7F, $5D, $A5, $FC, $D2, $C8, $65, $7B, $90, $A1, $46, $BD
	dc.b	$C5, $0A, $1D, $8A, $F6, $47, $F5, $6C, $8F, $EA, $D9, $CD, $C6, $E4, $B9, $7B, $87, $70, $CC, $01, $8B, $FF, $CE, $05, $45, $45, $40, $8F, $1B, $BF, $6C, $75
	dc.b	$3A, $CB, $AE, $5A, $CB, $50, $75, $85, $B7, $CB, $4B, $6F, $5F, $D3, $5E, $F3, $BE, $3B, $83, $C3, $7F, $92, $DF, $E0, $B7, $F8, $23, $BB, $8C, $E9, $2C, $81
	dc.b	$7E, $2F, $49, $69, $2F, $D8, $84, $6C, $FF, $B7, $B4, $D6, $C8, $00, $07, $34, $B4, $AF, $32, $CD, $BC, $E9, $BC, $00, $00, $1D, $C0, $0C, $7E, $C5, $A9, $04
	dc.b	$28, $6B, $3D, $15, $15, $C5, $29, $53, $A7, $E9, $27, $B2, $61, $F8, $4C, $5E, $06, $1F, $1D, $C5, $FF, $B7, $FC, $FB, $74, $62, $31, $15, $8E, $4E, $42, $96
	dc.b	$62, $3B, $4D, $C5, $18, $5D, $64, $DD, $64, $36, $D8, $74, $BF, $4B, $1B, $DB, $99, $C9, $8B, $FA, $8B, $3F, $B1, $06, $2F, $03, $1B, $83, $E3, $FA, $83, $7E
	dc.b	$EB, $E0, $87, $46, $DE, $92, $42, $8C, $45, $79, $4C, $24, $5F, $91, $64, $53, $35, $67, $63, $F5, $98, $ED, $2C, $73, $0B, $15, $1C, $C2, $C3, $A1, $E2, $5D
	dc.b	$B4, $E8, $53, $91, $88, $58, $87, $8A, $B9, $88, $51, $87, $47, $14, $DA, $85, $0F, $65, $D7, $A1, $49, $31, $5F, $16, $24, $9C, $85, $EB, $B5, $15, $ED, $61
	dc.b	$CB, $38, $E6, $8C, $6F, $2D, $4B, $2B, $CA, $B6, $6D, $CC, $6B, $0D, $4B, $15, $C8, $C8, $59, $5C, $AC, $2C, $5A, $AB, $0F, $EB, $2F, $06, $E3, $79, $D0, $DC
	dc.b	$C2, $C5, $D3, $69, $62, $A1, $47, $6D, $28, $CE, $27, $6A, $39, $76, $9D, $A8, $C2, $E6, $21, $62, $38, $A3, $1C, $87, $93, $F4, $65, $F9, $EB, $F9, $FB, $AF
	dc.b	$6A, $6D, $85, $4A, $49, $1C, $C8, $B1, $02, $45, $04, $39, $5F, $AC, $D4, $B9, $EA, $90, $43, $71, $D0, $B1, $AC, $57, $94, $5B, $98, $F4, $29, $0B, $98, $51
	dc.b	$BF, $AA, $0B, $CB, $FB, $96, $23, $BF, $A6, $74, $62, $ED, $3A, $2F, $E8, $DA, $C3, $B5, $52, $4C, $05, $92, $65, $CC, $E4, $4B, $EE, $37, $1D, $1E, $D6, $14
	dc.b	$96, $8C, $83, $31, $72, $32, $E8, $5C, $CB, $A3, $CB, $1B, $A3, $7B, $C0, $00, $46, $E2, $92, $42, $FE, $53, $73, $34, $8B, $15, $19, $0E, $31, $46, $49, $80
	dc.b	$A0, $63, $58, $76, $F2, $9B, $AF, $BA, $F0, $00, $0C, $C3, $31, $74, $2E, $7D, $F8, $48, $B1, $06, $12, $4C, $29, $24, $93, $0B, $39, $56, $E6, $ED, $83, $24
	dc.b	$C5, $46, $43, $6A, $41, $87, $6C, $3F, $47, $16, $2B, $20, $C5, $65, $CB, $FA, $AB, $D8, $00, $00, $62, $F8, $3E, $F7, $C2, $FE, $30, $61, $46, $35, $36, $6E
	dc.b	$D8, $B9, $E3, $3F, $E0, $81, $CA, $B7, $DD, $D9, $17, $16, $41, $8E, $46, $1D, $90, $BD, $FB, $32, $E7, $A6, $C5, $4F, $DF, $71, $02, $E0, $2E, $97, $50, $4E
	dc.b	$76, $F1, $E7, $00, $01, $1F, $E6, $0D, $4C, $CD, $E1, $39, $D7, $BB, $6A, $D7, $F5, $56, $AC, $E6, $DC, $66, $EB, $00, $09, $B1, $4C, $3B, $1B, $00, $12, $BA
	dc.b	$37, $5F, $1B, $98, $8E, $83, $12, $37, $23, $7F, $4D, $36, $5F, $A9, $AA, $6D, $34, $B4, $11, $DA, $5B, $65, $9C, $AE, $4A, $B1, $F6, $DA, $95, $54, $7D, $52
	dc.b	$AA, $85, $2F, $B6, $2A, $F5, $9E, $9B, $AC, $F5, $D5, $26, $8A, $74, $00, $00, $17, $FE, $E1, $6E, $45, $48, $23, $5C, $B3, $67, $A3, $23, $91, $63, $74, $39
	dc.b	$32, $1B, $51, $B6, $62, $CC, $B7, $E7, $36, $B9, $33, $95, $A8, $C4, $54, $6E, $8B, $A6, $11, $51, $AC, $E2, $58, $AC, $3A, $41, $87, $46, $36, $EC, $BA, $F2
	dc.b	$3D, $85, $85, $1C, $A8, $58, $85, $C5, $88, $A9, $06, $1B, $2A, $56, $0C, $6F, $33, $50, $EC, $DC, $B6, $57, $1F, $DC, $EB, $D1, $49, $9A, $85, $8D, $E3, $B5
	dc.b	$BA, $1D, $AB, $FC, $36, $FF, $5D, $7F, $8C, $8B, $53, $53, $56, $EB, $B3, $59, $AF, $7D, $26, $82, $14, $BD, $A8, $ED, $B7, $B6, $A9, $8E, $5D, $88, $21, $30
	dc.b	$54, $9B, $F5, $93, $27, $41, $43, $C5, $6F, $28, $51, $AF, $D0, $47, $79, $40, $21, $D5, $D7, $D1, $5B, $09, $55, $00, $C5, $71, $6C, $32, $7E, $13, $EF, $33
	dc.b	$C6, $B1, $40, $8D, $60, $1A, $39, $1A, $C6, $D5, $BF, $A5, $B2, $DA, $79, $30, $4A, $C3, $19, $09, $B5, $8A, $16, $74, $DA, $A7, $75, $C5, $89, $51, $06, $20
	dc.b	$92, $4D, $58, $CC, $31, $CA, $B7, $BE, $FB, $A4, $8C, $6A, $3D, $51, $73, $5F, $D4, $9C, $CE, $51, $FD, $77, $EC, $40, $BA, $F9, $33, $1A, $5F, $1E, $C7, $A7
	dc.b	$3C, $B2, $3C, $FF, $C1, $FD, $70, $00, $01, $84, $18, $B6, $1D, $89, $CF, $EC, $5A, $90, $46, $D2, $CD, $45, $46, $4F, $4B, $35, $17, $45, $AB, $BF, $46, $8D
	dc.b	$63, $98, $8E, $43, $6A, $4F, $4B, $4E, $00, $37, $C6, $EB, $D9, $0B, $D8, $11, $8D, $B9, $87, $8C, $F4, $FD, $7D, $EF, $D8, $E4, $E4, $AB, $6C, $C7, $2D, $C5
	dc.b	$96, $AD, $2C, $F3, $7A, $1E, $E4, $62, $14, $DB, $99, $42, $9A, $9C, $8A, $2A, $33, $2E, $4D, $0B, $EF, $B9, $F7, $3E, $F7, $80, $1E, $1E, $2E, $C3, $23, $BB
	dc.b	$B3, $97, $72, $DE, $C5, $46, $B3, $17, $41, $16, $B0, $46, $FE, $B5, $88, $6C, $8B, $52, $C5, $63, $90, $ED, $7E, $7D, $19, $BF, $48, $7E, $8C, $A3, $7F, $47
	dc.b	$A6, $11, $A8, $51, $89, $04, $DA, $87, $43, $FB, $3F, $D8, $FE, $CD, $5C, $FB, $EE, $BC, $B1, $0D, $CD, $61, $DA, $19, $26, $65, $1E, $88, $DC, $A9, $68, $A3
	dc.b	$98, $B7, $55, $CC, $33, $DE, $F5, $62, $D9, $B5, $47, $31, $51, $77, $E8, $C8, $D4, $D6, $91, $A9, $49, $26, $10, $BF, $B3, $F5, $14, $9C, $E8, $D4, $54, $82
	dc.b	$2F, $F0, $76, $D2, $7D, $DD, $36, $A9, $B7, $2A, $D5, $37, $AE, $F3, $DC, $DA, $AC, $FB, $26, $CF, $2B, $FA, $99, $66, $68, $C6, $B3, $46, $59, $BA, $1B, $36
	dc.b	$A8, $67, $94, $F1, $49, $C4, $B5, $8E, $BB, $31, $5C, $54, $62, $B8, $A8, $1F, $AC, $D9, $D6, $A8, $B5, $43, $53, $A1, $43, $BC, $D4, $A1, $4B, $55, $51, $74
	dc.b	$C2, $36, $AD, $46, $D6, $55, $D7, $F5, $BA, $F5, $00, $2A, $00, $C6, $C8, $EB, $B2, $49, $50, $30, $98, $49, $4C, $13, $66, $BF, $AD, $EB, $B1, $A9, $98, $A3
	dc.b	$6B, $2A, $86, $CC, $DA, $CB, $7E, $8D, $45, $48, $EF, $EB, $5E, $8D, $80, $00, $00, $D9, $2D, $70, $83, $08, $06, $10, $75, $6B, $31, $EB, $B4, $50, $EF, $35
	dc.b	$86, $F9, $56, $48, $6A, $6A, $B3, $2E, $F4, $82, $54, $D9, $A8, $6A, $76, $4C, $BA, $CC, $6A, $31, $5C, $54, $4A, $A0, $EC, $8E, $BD, $50, $D6, $53, $08, $E9
	dc.b	$AC, $C7, $9D, $23, $CF, $FC, $10, $35, $EA, $99, $66, $D6, $A6, $B0, $DF, $64, $99, $B5, $9B, $AD, $53, $59, $9B, $CE, $DE, $3C, $FC, $40, $EA, $D4, $46, $D5
	dc.b	$96, $BD, $03, $38, $71, $CC, $00, $00, $97, $EC, $5A, $90, $48, $52, $7A, $1D, $0D, $10, $A5, $4E, $93, $FE, $92, $C8, $00, $03, $17, $C6, $F7, $E9, $FB, $7C
	dc.b	$F2, $BE, $C5, $1C, $C4, $67, $31, $66, $9C, $95, $4B, $31, $1D, $A2, $EC, $46, $17, $59, $B6, $43, $6D, $86, $E7, $57, $4B, $17, $B8, $E6, $B9, $31, $3F, $51
	dc.b	$CC, $FE, $C0, $00, $0F, $0F, $BE, $3B, $AF, $5F, $D4, $42, $F2, $81, $23, $A3, $22, $85, $90, $62, $A0, $85, $D9, $75, $DE, $FB, $AD, $77, $EB, $51, $CC, $C8
	dc.b	$BB, $42, $E5, $64, $78, $ED, $A2, $14, $5D, $B4, $5E, $2A, $8C, $43, $C5, $AC, $72, $2A, $17, $31, $D7, $BF, $F5, $3A, $17, $C5, $24, $C6, $DE, $D6, $22, $A3
	dc.b	$58, $33, $E8, $73, $73, $72, $1B, $9B, $FA, $49, $CD, $67, $A4, $98, $98, $64, $6B, $64, $C5, $86, $36, $4A, $E3, $49, $ED, $3F, $0E, $74, $2C, $FD, $92, $7E
	dc.b	$8F, $F6, $2C, $D2, $BA, $FE, $B6, $B6, $99, $EE, $DA, $7A, $B6, $A3, $0B, $BF, $66, $9B, $57, $69, $71, $66, $99, $F4, $67, $FA, $97, $F1, $74, $3F, $47, $68
	dc.b	$6B, $CC, $04, $59, $74, $99, $8E, $58, $72, $8C, $30, $01, $26, $03, $CB, $7F, $2D, $EC, $4F, $D1, $B5, $9A, $2B, $0B, $0B, $0A, $7E, $8D, $58, $A8, $7F, $46
	dc.b	$D4, $6B, $15, $19, $24, $6B, $0B, $11, $DF, $BA, $BE, $E0, $18, $00, $B8, $4A, $E8, $DE, $F0, $04, $98, $98, $60, $1B, $AE, $3C, $AC, $70, $29, $0D, $24, $8C
	dc.b	$46, $41, $85, $85, $D2, $62, $45, $85, $8A, $C2, $CE, $CB, $8D, $D7, $96, $09, $5C, $06, $C1, $84, $17, $5F, $71, $BB, $B2, $E3, $B6, $E5, $64, $98, $36, $9D
	dc.b	$AA, $C2, $C2, $C6, $FE, $8E, $3B, $4E, $C8, $6D, $3B, $3F, $B5, $7B, $00, $00, $61, $98, $B8, $01, $24, $6F, $3E, $90, $E7, $E2, $06, $9F, $AA, $BF, $97, $A9
	dc.b	$76, $7E, $8E, $4C, $3F, $BB, $3D, $4F, $86, $4D, $FD, $8E, $7C, $40, $BB, $0C, $17, $CB, $70, $4E, $76, $F1, $E7, $00, $00, $21, $36, $BF, $AB, $D4, $CC, $95
	dc.b	$FD, $1D, $75, $0B, $5F, $D2, $54, $CD, $FE, $C0, $00, $12, $EC, $8D, $FF, $D1, $AB, $FB, $0D, $8D, $9D, $6A, $D9, $68, $E4, $71, $B2, $59, $87, $69, $43, $B1
	dc.b	$18, $A8, $6E, $36, $42, $93, $5E, $59, $6D, $0B, $11, $89, $92, $E4, $52, $FD, $DC, $CF, $EC, $00, $00, $F1, $BA, $3F, $A8, $37, $76, $3E, $0C, $2C, $41, $14
	dc.b	$8D, $C5, $0B, $20, $C4, $C2, $46, $E9, $BF, $3E, $6F, $7D, $D6, $9B, $AD, $88, $E6, $64, $5D, $A1, $72, $B1, $A8, $78, $ED, $A2, $A2, $ED, $A2, $F1, $54, $62
	dc.b	$1E, $2B, $B7, $45, $42, $8C, $D1, $FF, $A9, $D3, $09, $26, $36, $F6, $B1, $15, $1A, $C1, $FA, $F7, $45, $C9, $73, $6E, $AC, $FC, $DD, $37, $41, $0A, $49, $87
	dc.b	$39, $24, $6A, $8C, $48, $EF, $64, $B6, $57, $1B, $2E, $7F, $EE, $58, $BC, $4E, $D5, $67, $1D, $A7, $33, $B5, $0B, $35, $39, $ED, $2C, $D5, $C8, $66, $64, $D9
	dc.b	$B8, $BB, $4C, $9A, $E9, $9D, $B7, $47, $21, $46, $1E, $9B, $54, $B0, $B2, $1A, $E9, $17, $14, $64, $51, $96, $82, $32, $D1, $65, $A5, $AE, $2E, $8F, $2E, $18
	dc.b	$30, $CC, $33, $0C, $C3, $07, $2E, $FB, $54, $B1, $66, $28, $DD, $A6, $66, $B9, $88, $C3, $D0, $E4, $62, $31, $58, $E5, $DA, $BB, $50, $ED, $82, $6D, $6E, $D2
	dc.b	$CF, $DD, $5F, $75, $E8, $2F, $C2, $61, $24, $97, $C9, $2F, $12, $7D, $F0, $E5, $18, $66, $18, $30, $C1, $86, $5C, $FF, $DD, $6D, $72, $1B, $9B, $A3, $16, $E2
	dc.b	$C4, $DB, $06, $16, $45, $81, $58, $DB, $8E, $DC, $31, $D7, $37, $94, $68, $30, $92, $43, $7C, $92, $4C, $C5, $DD, $8D, $E5, $12, $66, $36, $E1, $80, $61, $97
	dc.b	$5F, $74, $58, $19, $1F, $D1, $C2, $E5, $64, $99, $86, $01, $B6, $17, $39, $25, $A4, $B6, $C9, $81, $86, $F8, $30, $A4, $98, $91, $E5, $EC, $5E, $58, $DC, $21
	dc.b	$CE, $9F, $AB, $39, $9C, $A3, $CF, $FC, $10, $2F, $E5, $8B, $01, $BA, $3D, $5F, $DE, $1A, $7F, $78, $0B, $AF, $BA, $F7, $C5, $DA, $41, $9A, $43, $AB, $F5, $01
	dc.b	$33, $3F, $D1, $CC, $00, $00, $00, $20, $C2, $00, $0E, $91, $45, $D2, $17, $F0, $28, $B7, $CD, $A5, $1A, $F9, $F8, $4E, $85, $24, $80, $00, $36, $47, $5D, $87
	dc.b	$57, $CF, $BA, $6E, $5B, $E6, $4E, $B8, $EA, $51, $B7, $CC, $52, $66, $CD, $4E, $8B, $E3, $7E, $75, $6D, $7A, $92, $6B, $A8, $B3, $1D, $4E, $46, $96, $BA, $BD
	dc.b	$49, $CF, $2D, $52, $2C, $4D, $62, $98, $E3, $1C, $B1, $7E, $1E, $53, $F7, $74, $D5, $CC, $3F, $AC, $6A, $6A, $AE, $54, $9D, $A8, $B3, $1E, $2A, $8F, $6B, $16
	dc.b	$65, $42, $85, $1E, $A8, $E5, $99, $B6, $A1, $A1, $7F, $31, $9C, $D0, $E7, $C8, $BA, $6A, $E6, $CC, $51, $74, $33, $1E, $3B, $56, $F9, $F2, $D5, $B3, $B7, $20
	dc.b	$BC, $1F, $3C, $DF, $A6, $54, $CA, $1A, $64, $75, $AA, $ED, $1A, $AE, $B5, $00, $1E, $63, $72, $4C, $96, $37, $EB, $74, $58, $75, $BA, $3A, $AB, $33, $BA, $FD
	dc.b	$4E, $B6, $33, $51, $7A, $D5, $26, $BF, $F7, $93, $35, $8B, $71, $D2, $D9, $2E, $C6, $3A, $92, $A8, $37, $66, $CC, $F2, $CD, $69, $32, $2A, $00, $15, $FA, $F3
	dc.b	$D3, $59, $E8, $58, $75, $2F, $86, $B0, $42, $C3, $AA, $CC, $DE, $B5, $7A, $B3, $58, $4C, $DD, $62, $CE, $B6, $EE, $D7, $37, $51, $B3, $09, $90, $14, $92, $46
	dc.b	$93, $14, $85, $26, $5A, $45, $21, $3A, $64, $EE, $0D, $66, $A3, $58, $B3, $51, $AC, $59, $AD, $A3, $70, $D6, $3B, $AD, $3F, $08, $52, $2F, $10, $48, $50, $2C
	dc.b	$F2, $41, $07, $DD, $D3, $1A, $88, $3E, $3A, $5F, $F9, $FC, $FF, $3F, $FA, $EF, $FF, $80, $77, $4F, $46, $BD, $78, $C2, $63, $34, $26, $D2, $F6, $DF, $49, $E9
	dc.b	$99, $FC, $FF, $EC, $72, $4F, $CF, $80, $00, $02, $29, $92, $41, $01, $AD, $21, $A3, $E7, $00, $0C, $86, $52, $E7, $CA, $3A, $64, $53, $5E, $96, $A2, $DE, $91
	dc.b	$BD, $E1, $23, $7A, $4D, $1E, $8D, $5A, $8B, $4D, $5B, $3D, $78, $4D, $3A, $65, $3D, $A7, $7C, $F3, $5F, $9C, $7A, $F0, $92, $49, $B1, $7C, $AF, $C5, $F3, $DB
	dc.b	$83, $67, $A3, $98, $EA, $4F, $48, $38, $A3, $66, $C6, $65, $85, $19, $16, $39, $B9, $69, $1B, $F2, $4C, $23, $69, $5A, $4C, $E6, $6F, $0C, $54, $29, $06, $4C
	dc.b	$90, $4C, $CC, $CD, $45, $9A, $08, $6F, $33, $35, $16, $68, $73, $14, $63, $B7, $B7, $24, $12, $C9, $24, $83, $34, $08, $E8, $E6, $66, $DE, $BD, $16, $7A, $D4
	dc.b	$CC, $22, $CC, $A6, $83, $0B, $0C, $EA, $EC, $69, $2D, $25, $3F, $0D, $4B, $EF, $7C, $A7, $94, $D1, $7C, $C1, $66, $8C, $D4, $01, $27, $FD, $24, $DB, $A8, $8D
	dc.b	$9E, $48, $06, $27, $92, $08, $F0, $9D, $77, $50, $4A, $88, $22, $F3, $34, $A9, $8E, $8C, $27, $09, $DB, $3D, $0A, $4E, $22, $93, $4B, $A2, $53, $04, $92, $63
	dc.b	$84, $27, $A0, $00, $00, $38, $42, $7A, $02, $83, $13, $49, $04, $D2, $98, $CF, $17, $F4, $B7, $A6, $48, $12, $34, $5F, $DF, $5C, $BF, $AE, $6F, $3B, $79, $FF
	dc.b	$74, $1F, $3D, $31, $9D, $D1, $C8, $A4, $1D, $A6, $C8, $24, $F2, $D9, $9E, $C0, $00, $00, $41, $04, $9F, $7C, $B4, $97, $60, $3F, $B1, $6A, $41, $1B, $53, $4A
	dc.b	$94, $35, $65, $11, $8D, $AF, $09, $E8, $6F, $36, $34, $5B, $17, $D5, $27, $D2, $BA, $4A, $F7, $E1, $04, $AF, $48, $76, $61, $23, $79, $42, $FB, $4F, $4E, $BC
	dc.b	$D0, $A1, $61, $61, $4B, $ED, $42, $C4, $B3, $CE, $CB, $14, $B3, $E1, $A5, $E8, $5E, $CC, $8E, $71, $75, $5C, $53, $61, $7B, $0B, $1C, $FD, $85, $2F, $4B, $EE
	dc.b	$D1, $E0, $01, $B8, $3C, $47, $F5, $1D, $97, $76, $05, $BC, $2E, $D6, $DE, $AC, $2C, $6F, $3A, $B2, $33, $16, $04, $BD, $33, $B6, $5B, $18, $7F, $70, $A8, $F3
	dc.b	$B9, $3B, $22, $90, $FD, $42, $E8, $C5, $DC, $DD, $AA, $F6, $ED, $D1, $58, $58, $8B, $7A, $5D, $7B, $11, $5F, $14, $96, $D4, $9A, $91, $D5, $0C, $E5, $97, $16
	dc.b	$2A, $36, $E7, $2A, $36, $72, $8E, $9C, $DE, $67, $E4, $4B, $AF, $6B, $10, $4C, $59, $86, $7E, $A2, $6C, $8D, $60, $8C, $AA, $51, $A8, $17, $46, $A3, $35, $A4
	dc.b	$FC, $62, $C5, $47, $EC, $5D, $A5, $3A, $8B, $0B, $0B, $36, $3D, $69, $D3, $63, $BA, $C5, $0A, $35, $35, $29, $1D, $D7, $BE, $BA, $4C, $CD, $19, $66, $B1, $19
	dc.b	$68, $6D, $B4, $76, $54, $01, $2E, $C7, $DF, $74, $DA, $CD, $84, $6E, $B3, $2A, $6E, $CD, $CD, $45, $B6, $F0, $50, $03, $32, $74, $27, $5A, $2E, $A7, $F5, $9A
	dc.b	$42, $C8, $53, $58, $D4, $24, $37, $C9, $20, $91, $4D, $4F, $EB, $7A, $8A, $01, $24, $00, $63, $58, $74, $6C, $11, $98, $D7, $08, $00, $1A, $F4, $27, $47, $30
	dc.b	$6A, $2D, $41, $48, $A0, $A9, $48, $D7, $43, $33, $77, $FF, $77, $50, $05, $71, $51, $A8, $96, $CD, $63, $30, $00, $00, $3A, $FA, $0F, $46, $92, $43, $A4, $90
	dc.b	$A4, $50, $A0, $8E, $92, $48, $21, $4B, $74, $19, $B5, $98, $6F, $C5, $65, $51, $84, $A8, $94, $DA, $C3, $A2, $5A, $49, $24, $9A, $CC, $BC, $E9, $1E, $7F, $D8
	dc.b	$81, $D1, $AC, $C7, $A3, $62, $5A, $3B, $EC, $90, $4B, $97, $53, $A9, $D4, $F5, $E5, $9E, $5A, $9E, $3F, $AE, $D0, $0D, $76, $4B, $7E, $B1, $A9, $48, $F4, $6A
	dc.b	$83, $9D, $7F, $63, $CE, $00, $10, $FD, $8B, $52, $08, $52, $D4, $E9, $54, $3A, $2C, $ED, $4F, $D9, $D5, $A8, $C7, $23, $8A, $56, $D4, $9E, $D4, $40, $06, $2F
	dc.b	$8D, $EF, $48, $5E, $92, $48, $7E, $97, $AF, $3B, $CB, $8B, $BF, $62, $6C, $C4, $2E, $B2, $BF, $47, $1D, $86, $F5, $D1, $6F, $29, $92, $E4, $C3, $A3, $8A, $38
	dc.b	$E9, $B4, $A3, $16, $FB, $AF, $E6, $EC, $78, $03, $70, $7C, $90, $BE, $08, $52, $3F, $A9, $3B, $AF, $7A, $DE, $A8, $C6, $A1, $48, $CC, $9B, $4A, $19, $CE, $50
	dc.b	$9D, $50, $DC, $76, $94, $75, $CD, $45, $46, $B3, $29, $B5, $99, $F7, $B9, $17, $42, $ED, $AB, $C7, $91, $8A, $8B, $FB, $13, $A2, $A3, $0F, $12, $9B, $4A, $37
	dc.b	$F6, $7F, $B1, $DA, $76, $A1, $7D, $FC, $AD, $47, $C7, $43, $7A, $ED, $E3, $7B, $58, $73, $CA, $39, $A3, $21, $73, $67, $8A, $6D, $59, $AC, $ED, $B6, $E5, $AA
	dc.b	$31, $35, $BF, $90, $D5, $35, $28, $5C, $B5, $63, $5C, $DB, $99, $A3, $A1, $76, $D1, $2B, $8B, $3F, $73, $B9, $C5, $9A, $1E, $27, $93, $45, $DA, $ED, $A8, $7F
	dc.b	$66, $8E, $28, $E2, $C2, $85, $0A, $6D, $2C, $4E, $42, $E3, $FC, $3D, $18, $6F, $BB, $F5, $D7, $DC, $D4, $73, $22, $C4, $09, $14, $12, $BF, $F5, $90, $67, $15
	dc.b	$B8, $DD, $FA, $9B, $AF, $12, $60, $4C, $26, $13, $08, $2F, $FE, $53, $0A, $32, $0E, $E2, $C5, $72, $14, $6B, $1C, $8A, $8C, $3B, $4A, $2B, $23, $A4, $3F, $62
	dc.b	$C6, $F1, $BC, $ED, $2F, $BC, $DC, $C5, $BD, $AC, $29, $06, $1D, $19, $06, $49, $97, $23, $2E, $6B, $2E, $65, $D1, $E5, $8D, $D1, $BD, $E0, $01, $26, $20, $93
	dc.b	$0B, $EF, $B8, $DD, $79, $42, $C6, $B1, $51, $8D, $62, $A4, $18, $52, $2C, $D1, $58, $AC, $42, $90, $DA, $85, $86, $E3, $B4, $DF, $75, $FF, $AA, $29, $26, $20
	dc.b	$12, $B9, $82, $57, $32, $5B, $6F, $FD, $D5, $EA, $8C, $83, $0A, $41, $36, $E8, $DD, $0A, $16, $2B, $34, $62, $41, $88, $51, $8A, $C5, $E4, $62, $B1, $5D, $75
	dc.b	$FF, $BA, $BC, $06, $00, $30, $CC, $5D, $1B, $DF, $26, $26, $19, $14, $EA, $3F, $AE, $48, $7E, $BB, $F6, $20, $5E, $FB, $EE, $BE, $EB, $DF, $A3, $15, $C5, $1C
	dc.b	$C5, $63, $90, $FE, $AE, $E5, $BD, $ED, $CE, $9B, $17, $8F, $3F, $10, $2F, $C2, $3E, $4E, $49, $6C, $78, $4E, $76, $F1, $E7, $00, $00, $02, $A4, $90, $0A, $49
	dc.b	$27, $00, $7E, $C4, $24, $7A, $4A, $2F, $4C, $BF, $69, $A5, $90, $62, $92, $B3, $30, $92, $BE, $57, $94, $6F, $61, $46, $71, $DD, $AB, $E7, $33, $AC, $ED, $A9
	dc.b	$A4, $E6, $75, $63, $90, $A3, $76, $E8, $C6, $A7, $E8, $D1, $EB, $FB, $15, $DC, $7F, $62, $DF, $E3, $7E, $A0, $00, $00, $DD, $2D, $D7, $FE, $E2, $CB, $A2, $A6
	dc.b	$66, $F4, $54, $28, $50, $FF, $06, $F5, $D2, $08, $BA, $2D, $ED, $D0, $D8, $E5, $99, $43, $63, $3B, $1D, $92, $1A, $D9, $B9, $23, $66, $3A, $9A, $A5, $56, $6D
	dc.b	$E6, $BC, $C7, $99, $BC, $C7, $F4, $C7, $F4, $D8, $B2, $D8, $3F, $3F, $D4, $35, $F0, $45, $48, $A1, $47, $B5, $0A, $61, $15, $EA, $85, $0E, $AF, $8E, $A6, $8B
	dc.b	$97, $3C, $DD, $7C, $F1, $B2, $B1, $16, $D0, $62, $1F, $D3, $16, $16, $14, $E6, $36, $61, $4A, $C1, $18, $9B, $F9, $8D, $57, $45, $DD, $9A, $58, $2A, $61, $05
	dc.b	$87, $E9, $8F, $FD, $BB, $A3, $C4, $A6, $73, $75, $EE, $46, $A1, $A3, $6C, $C4, $93, $8E, $8D, $9D, $B3, $94, $28, $51, $8A, $8A, $8C, $B2, $A1, $46, $59, $AF
	dc.b	$BD, $D9, $7E, $E1, $6A, $52, $54, $29, $2E, $1D, $31, $4E, $68, $25, $40, $5D, $D3, $4F, $4F, $D1, $99, $CA, $49, $28, $BA, $4E, $8B, $A2, $E8, $BF, $B5, $5D
	dc.b	$37, $9D, $E8, $6A, $B5, $05, $93, $FF, $6C, $24, $F6, $8C, $E3, $15, $15, $12, $EA, $33, $6B, $FA, $B6, $CD, $B3, $F5, $B0, $73, $39, $20, $C0, $31, $60, $C4
	dc.b	$3B, $35, $9B, $AA, $6C, $F2, $9B, $65, $DF, $CD, $62, $2B, $3F, $44, $8C, $A8, $16, $10, $49, $DA, $8B, $9E, $C5, $E9, $E1, $36, $C9, $33, $08, $00, $18, $A4
	dc.b	$2D, $3D, $22, $C2, $91, $61, $40, $04, $6C, $0A, $4E, $DB, $4E, $52, $0C, $43, $A4, $F0, $40, $90, $66, $2C, $8A, $8C, $C5, $83, $67, $E0, $10, $01, $84, $18
	dc.b	$9E, $36, $9E, $4C, $48, $CE, $51, $B3, $A2, $B3, $F3, $E9, $43, $C2, $BF, $9F, $FE, $88, $13, $C7, $80, $64, $3A, $4B, $20, $9D, $34, $FD, $FF, $49, $4F, $DF
	dc.b	$F1, $02, $71, $8A, $4F, $29, $F1, $3D, $13, $F3, $ED, $E3, $F9, $F0, $00, $0B, $B2, $3D, $50, $EA, $5B, $2E, $C6, $D9, $76, $36, $D0, $FD, $2F, $71, $D9, $FA
	dc.b	$EF, $D5, $2C, $DD, $53, $6C, $9B, $A8, $FE, $98, $FE, $99, $6C, $25, $68, $ED, $E9, $E3, $5C, $5D, $FB, $EF, $D5, $75, $4D, $1E, $63, $FA, $B9, $8D, $97, $98
	dc.b	$DB, $64, $6C, $DB, $42, $C5, $27, $DB, $51, $BD, $2E, $FD, $77, $EE, $80, $E8, $95, $8C, $D2, $E6, $E8, $95, $8C, $C2, $65, $E9, $4E, $EB, $A7, $C6, $66, $90
	dc.b	$A1, $CE, $E1, $FA, $AA, $63, $9C, $0F, $DF, $7E, $E8, $09, $30, $1C, $C7, $EB, $B9, $4D, $C2, $EF, $DF, $5C, $CB, $8D, $03, $68, $06, $33, $BB, $67, $2F, $EB
	dc.b	$8A, $03, $77, $EF, $AE, $D8, $91, $A1, $B8, $D2, $14, $6D, $1B, $9D, $CD, $FD, $72, $FE, $AC, $24, $3B, $26, $28, $DD, $DA, $E8, $6F, $18, $C8, $00, $06, $2B
	dc.b	$AC, $50, $1A, $0C, $53, $13, $45, $24, $FB, $52, $FF, $D4, $6B, $7D, $A7, $7D, $26, $A4, $6F, $3D, $91, $98, $CD, $1A, $5F, $19, $AF, $A5, $F1, $BE, $91, $9A
	dc.b	$97, $D7, $82, $CE, $F9, $ED, $3D, $2C, $31, $94, $A7, $D6, $70, $23, $4E, $88, $DF, $19, $ED, $FA, $D0, $D9, $B1, $9C, $27, $87, $E8, $E6, $E9, $FE, $19, $E8
	dc.b	$C3, $FF, $7A, $B3, $5A, $6F, $D6, $4F, $33, $0A, $1D, $1A, $C2, $86, $63, $B5, $16, $67, $96, $1D, $0E, $72, $65, $A1, $33, $32, $84, $D9, $E5, $7B, $67, $7D
	dc.b	$AF, $29, $BA, $29, $B8, $00, $00, $E9, $DD, $7F, $E9, $A6, $33, $45, $F3, $CC, $72, $8B, $F3, $18, $CC, $65, $84, $5C, $F9, $AF, $DD, $CC, $F5, $CE, $48, $0D
	dc.b	$60, $9B, $62, $E4, $2C, $AB, $66, $28, $5D, $14, $28, $D7, $CF, $4E, $BB, $EC, $F8, $CF, $94, $28, $69, $3C, $C0, $37, $5A, $00, $DF, $DA, $EE, $D6, $76, $CC
	dc.b	$92, $E8, $94, $C0, $3C, $06, $FE, $95, $FF, $AC, $9E, $1A, $80, $35, $33, $0C, $50, $74, $EE, $5E, $B0, $D7, $88, $F4, $46, $6A, $24, $78, $25, $21, $4C, $6E
	dc.b	$9E, $8D, $D4, $63, $50, $00, $1F, $A8, $A4, $66, $13, $24, $28, $31, $AC, $C0, $2D, $20, $FE, $9A, $00, $25, $FC, $F6, $FF, $3C, $00, $02, $FF, $FE, $5F, $FF
	dc.b	$00, $0C, $4F, $FD, $F9, $E5, $9F, $0F, $E7, $F1, $00, $EE, $9E, $8D, $79, $BD, $68, $B3, $5F, $2A, $2D, $10, $A1, $E7, $39, $D2, $75, $FC, $FA, $65, $C4, $02
Game_over_palette_stream:
	dc.b	$60, $0E, $00, $00, $00, $00, $0E, $EE, $00, $00, $08, $CC, $04, $48, $0C, $CC, $04, $44, $00, $22, $02, $44, $04, $66, $06, $88, $06, $AA, $08, $AA, $0A, $CC
	dc.b	$0C, $EE
Game_over_tilemap:
	dc.b	$09, $00, $00, $00, $00, $12, $16, $98, $08, $F3, $C7, $80, $1D, $3E, $00, $74, $14, $20, $0C, $40, $40, $44, $78, $90, $02, $40, $40, $0E, $87, $C8, $76, $12
	dc.b	$18, $83, $00, $62, $05, $12, $4A, $10, $08, $00, $40, $0E, $88, $88, $7D, $47, $61, $21, $88, $EC, $9C, $1D, $3F, $A8, $74, $B0, $50, $09, $0C, $48, $08, $F0
	dc.b	$20, $23, $D0, $80, $12, $1D, $84, $86, $20, $40, $0E, $81, $48, $90, $42, $1C, $C6, $26, $80, $E9, $A4, $04, $48, $47, $91, $38, $3A, $58, $37, $91, $9C, $3A
	dc.b	$69, $2D, $08, $04, $00, $38, $87, $4B, $07, $71, $0E, $9A, $4E, $E2, $1D, $2C, $1B, $C9, $4C, $1D, $34, $9D, $C4, $3A, $58, $3B, $88, $74, $D2, $2F, $02, $02
	dc.b	$5C, $C7, $61, $21, $88, $EC, $08, $01, $D0, $51, $F4, $40, $26, $92, $49, $43, $B0, $90, $C4, $76, $31, $09, $0C, $40, $80, $1D, $3E, $00, $74, $F1, $50, $2A
	dc.b	$00, $30, $09, $B1, $D0, $3F, $80, $00
Game_over_tiles:
	dc.b	$01, $1F, $80, $37, $73, $78, $F3, $84, $03, $00, $14, $07, $26, $36, $37, $74, $85, $17, $78, $86, $03, $02, $15, $19, $27, $7A, $88, $05, $1A, $17, $72, $28
	dc.b	$F7, $89, $04, $09, $16, $38, $28, $F6, $8A, $04, $06, $15, $16, $27, $76, $37, $75, $8B, $04, $0A, $8C, $05, $17, $8D, $05, $18, $18, $F2, $8E, $03, $01, $14
	dc.b	$08, $26, $37, $37, $77, $FF, $F3, $F3, $F3, $F3, $E7, $98, $E6, $9F, $1C, $C8, $F2, $E6, $7F, $5B, $E7, $E7, $E7, $E7, $00, $88, $18, $FE, $A1, $E8, $41, $43
	dc.b	$FD, $DE, $7E, $7E, $7E, $79, $1F, $C6, $3F, $F4, $D8, $82, $BF, $FD, $E7, $E7, $E7, $E7, $FF, $6F, $FE, $EE, $0E, $D0, $20, $47, $9F, $9F, $9F, $9E, $4E, $D9
	dc.b	$FF, $EF, $FD, $3F, $FD, $E7, $E7, $E7, $E7, $92, $FF, $CD, $78, $07, $A1, $05, $7F, $FB, $CF, $CF, $CF, $CF, $CB, $FB, $87, $FC, $9B, $82, $82, $81, $02, $3C
	dc.b	$FC, $FC, $FC, $FF, $D9, $8F, $FA, $74, $20, $AF, $FF, $79, $F9, $F9, $F9, $FE, $B4, $17, $50, $08, $FF, $F2, $0B, $F9, $C2, $3C, $FC, $FC, $FC, $F2, $76, $CC
	dc.b	$3C, $03, $D0, $82, $BF, $FD, $E7, $E7, $E7, $E6, $E4, $17, $50, $08, $FE, $F0, $28, $2D, $A0, $47, $9F, $9F, $9F, $9B, $90, $5D, $40, $23, $FB, $C0, $AF, $E2
	dc.b	$40, $38, $F3, $F3, $F3, $F3, $F3, $F3, $F3, $F3, $E6, $7C, $87, $33, $E4, $39, $8F, $21, $CC, $79, $0E, $63, $01, $73, $BE, $01, $E7, $7C, $3F, $3B, $E0, $6F
	dc.b	$FD, $42, $3D, $05, $71, $97, $BB, $48, $F5, $79, $E5, $B5, $E7, $53, $7D, $A7, $53, $70, $55, $71, $7C, $C4, $E9, $81, $7B, $FE, $EE, $E5, $A7, $F9, $13, $AF
	dc.b	$EC, $EA, $6F, $9D, $AE, $86, $46, $76, $BD, $37, $0C, $9B, $FB, $0D, $A6, $FC, $DD, $F7, $D8, $86, $96, $F4, $DC, $9B, $94, $B7, $26, $0D, $3F, $B8, $85, $76
	dc.b	$9E, $4C, $18, $4F, $2E, $1B, $94, $EA, $43, $49, $A6, $D4, $B1, $BF, $BD, $DC, $A0, $5A, $6F, $BE, $4B, $48, $5B, $19, $61, $08, $D8, $BA, $8C, $9C, $43, $39
	dc.b	$C6, $D2, $D0, $FB, $82, $9F, $77, $20, $82, $F0, $86, $63, $63, $B4, $20, $9E, $3A, $43, $A7, $44, $6E, $08, $20, $A8, $72, $A0, $7F, $39, $CE, $42, $1D, $DE
	dc.b	$11, $72, $EA, $32, $53, $43, $91, $52, $DD, $C3, $4E, $BB, $86, $94, $08, $36, $32, $B1, $2A, $7D, $F1, $ED, $A9, $BB, $63, $8F, $CE, $79, $2C, $6B, $D9, $B0
	dc.b	$75, $76, $96, $12, $DE, $D4, $3F, $72, $C6, $D7, $B4, $DC, $37, $17, $6D, $4B, $1A, $E3, $52, $C2, $AD, $79, $10, $87, $0D, $1D, $2E, $5D, $9F, $B4, $48, $3E
	dc.b	$C5, $43, $95, $37, $1F, $CE, $D4, $DF, $21, $0E, $52, $65, $A2, $F8, $E2, $A5, $95, $ED, $FB, $92, $DE, $CD, $A9, $06, $DF, $9C, $6D, $5E, $3F, $A8, $47, $A1
	dc.b	$91, $9D, $93, $FA, $7C, $ED, $91, $9D, $B2, $10, $BF, $A7, $CD, $81, $73, $FE, $48, $4F, $E8, $17, $C8, $C8, $43, $3D, $10, $C8, $CE, $D9, $19, $C2, $7F, $42
	dc.b	$36, $23, $7B, $FB, $CB, $1B, $CB, $20, $DC, $A5, $86, $43, $69, $A4, $64, $1D, $2B, $64, $36, $93, $E5, $B8, $C0, $29, $A5, $BB, $B4, $DC, $B7, $77, $BD, $31
	dc.b	$05, $A7, $DD, $A7, $DF, $8F, $79, $6B, $C6, $A5, $AE, $5D, $72, $95, $6F, $6D, $4F, $F2, $27, $4D, $4E, $6F, $FA, $BB, $BC, $7B, $CB, $5C, $1F, $DC, $EA, $5A
	dc.b	$F0, $2F, $3C, $A4, $42, $17, $9D, $35, $5F, $6B, $CF, $BB, $04, $6F, $F9, $B6, $D3, $02, $0A, $87, $38, $81, $DF, $0E, $72, $16, $2F, $BB, $9C, $4D, $DC, $BE
	dc.b	$35, $39, $28, $E3, $8A, $3B, $61, $B5, $25, $CE, $3F, $6F, $CF, $F6, $FC, $FF, $6F, $CF, $F6, $FC, $FF, $6F, $CF, $F6, $FC, $FF, $6F, $CF, $F6, $FE, $77, $C0
	dc.b	$5C, $EF, $80, $79, $F9, $67, $9F, $93, $F3, $F2, $0B, $9F, $94, $73, $F2, $0B, $9F, $94, $0A, $D4, $90, $68, $B6, $9B, $6D, $19, $D5, $42, $95, $CA, $E0, $86
	dc.b	$13, $A6, $2F, $45, $B5, $23, $F9, $D3, $A6, $41, $6D, $3A, $68, $D3, $5D, $3C, $6A, $E0, $82, $0C, $83, $76, $19, $9B, $BD, $D9, $E5, $8A, $13, $81, $F9, $C7
	dc.b	$C4, $E0, $BA, $0D, $38, $1B, $B4, $B1, $04, $4F, $BC, $C0, $6D, $49, $69, $7C, $4E, $AF, $98, $15, $2D, $87, $8C, $54, $B6, $21, $F1, $52, $CE, $9F, $15, $3B
	dc.b	$82, $0E, $2F, $2D, $00, $A3, $79, $6B, $B9, $93, $79, $6B, $FA, $A3, $79, $6B, $ED, $81, $7E, $3F, $38, $41, $07, $D9, $AE, $0A, $17, $6F, $6A, $C6, $E0, $A7
	dc.b	$DF, $8A, $04, $1E, $2A, $68, $64, $DF, $16, $3B, $45, $93, $B5, $DA, $68, $43, $71, $41, $11, $B8, $20, $82, $0A, $79, $D1, $73, $A3, $C3, $C6, $A7, $94, $0A
	dc.b	$E5, $38, $11, $A9, $D4, $EA, $05, $7B, $E1, $D0, $AD, $62, $A2, $98, $EA, $75, $7A, $34, $58, $AD, $4D, $17, $F6, $AC, $C4, $F2, $05, $CC, $86, $A2, $08, $95
	dc.b	$03, $DF, $8A, $FE, $40, $9A, $FD, $C7, $EA, $C8, $64, $18, $B7, $FA, $4F, $F6, $25, $1E, $1C, $C8, $9F, $CD, $C8, $52, $27, $F1, $F5, $2E, $75, $50, $E8, $EA
	dc.b	$8F, $E7, $FF, $36, $DA, $20, $B7, $15, $A2, $F7, $6E, $34, $F0, $86, $35, $1B, $71, $81, $08, $37, $1E, $FB, $34, $FE, $E0, $23, $7F, $DC, $62, $F2, $2D, $50
	dc.b	$0A, $E2, $8E, $C7, $4D, $98, $CE, $AE, $6E, $0B, $E8, $70, $5D, $6B, $D8, $6F, $AE, $2E, $50, $5A, $9B, $C0, $DC, $14, $FB, $D7, $00, $83, $53, $5C, $05, $7B
	dc.b	$62, $E0, $DF, $B1, $42, $FC, $54, $B5, $DB, $82, $2B, $86, $B9, $1B, $82, $0E, $08, $69, $B8, $9D, $5D, $A6, $E2, $58, $B4, $DC, $C8, $57, $9B, $8A, $07, $0D
	dc.b	$73, $84, $30, $D3, $0F, $76, $9A, $7B, $B7, $15, $8A, $F6, $6C, $11, $CA, $60, $15, $3A, $63, $B1, $D4, $E1, $46, $66, $8B, $90, $D5, $82, $08, $C4, $E0, $82
	dc.b	$0E, $27, $70, $56, $27, $68, $05, $88, $BB, $6A, $B7, $7B, $F2, $05, $AF, $1C, $66, $E4, $5E, $5B, $68, $69, $A7, $C1, $1F, $9C, $10, $C1, $3A, $22, $58, $82
	dc.b	$0B, $19, $D5, $39, $C1, $6D, $30, $3E, $42, $B5, $28, $62, $E6, $FC, $81, $C5, $C3, $6A, $42, $C5, $CC, $E9, $9F, $17, $6D, $4B, $AC, $5F, $52, $41, $18, $BF
	dc.b	$3C, $08, $E7, $84, $0F, $3C, $64, $73, $C6, $DC, $F1, $91, $CF, $19, $1C, $F0, $81, $E7, $81, $FC, $EB, $CF, $26, $04, $43, $4E, $B2, $72, $16, $D0, $F0, $8B
	dc.b	$97, $51, $92, $B7, $73, $D3, $BB, $C6, $1B, $93, $08, $D4, $B1, $04, $17, $84, $33, $1B, $1D, $A1, $04, $F1, $D2, $1D, $3A, $23, $70, $41, $05, $43, $95, $03
	dc.b	$F9, $CE, $72, $10, $EE, $F0, $8B, $97, $51, $92, $B7, $73, $D3, $BB, $F7, $C5, $7B, $30, $23, $F9, $D9, $39, $0B, $68, $78, $45, $CB, $A8, $C9, $5B, $B9, $E9
	dc.b	$DD, $E2, $AF, $8F, $E2, $11, $E8, $64, $67, $64, $FE, $9F, $3B, $64, $67, $6C, $84, $0F, $A7, $CC, $02, $E7, $6A, $D3, $72, $94, $FE, $F4, $5F, $3C, $96, $90
	dc.b	$54, $39, $32, $09, $BD, $F6, $CB, $69, $82, $7F, $CE, $56, $98, $EC, $DC, $68, $FB, $CF, $26, $5E, $F3, $EE, $B9, $71, $69, $C8, $C8, $35, $9A, $96, $0D, $4D
	dc.b	$71, $96, $A6, $96, $29, $AB, $55, $A6, $2C, $1B, $4D, $47, $F1, $F5, $3A, $6D, $51, $BC, $F2, $AD, $35, $4E, $BB, $6A, $36, $A7, $68, $54, $D4, $3F, $36, $29
	dc.b	$A9, $AB, $95, $72, $6F, $DC, $37, $2A, $FE, $C0, $F6, $FD, $C1, $BF, $1F, $B8, $42, $F3, $DC, $5D, $B1, $53, $40, $B4, $E2, $32, $5A, $74, $5C, $B5, $F9, $6F
	dc.b	$86, $1C, $68, $F0, $E5, $6B, $8B, $F7, $F6, $C8, $43, $53, $72, $F1, $A2, $E5, $D3, $70, $8A, $8E, $18, $F4, $96, $87, $DC, $62, $F4, $DC, $17, $20, $82, $F0
	dc.b	$86, $63, $63, $B4, $20, $9E, $3A, $43, $A7, $44, $6E, $08, $22, $6B, $05, $CA, $81, $FC, $E7, $39, $08, $77, $78, $45, $CB, $A8, $C9, $5B, $B9, $E9, $DD, $FF
	dc.b	$BC, $E5, $02, $3F, $9D, $93, $90, $B6, $87, $84, $5C, $BA, $8C, $95, $BB, $9E, $9D, $DE, $1B, $93, $61, $B9, $10, $D3, $CA, $59, $E1, $0C, $C6, $C7, $68, $41
	dc.b	$3C, $74, $87, $4E, $88, $DC, $10, $44, $DF, $A6, $2E, $47, $A1, $8B, $8C, $ED, $8B, $8F, $4F, $E5, $B6, $47, $96, $D9, $0B, $07, $D3, $AC, $40, $2E, $71, $CF
	dc.b	$03, $0D, $CE, $1A, $FC, $D0, $61, $CD, $DB, $1C, $C8, $BD, $73, $28, $B7, $3D, $AF, $CD, $E1, $B7, $72, $AF, $43, $F9, $CC, $8E, $42, $7C, $43, $C6, $0B, $97
	dc.b	$55, $8C, $95, $0D, $40, $F4, $BB, $43, $C0, $EE, $0A, $2E, $76, $DF, $31, $E8, $17, $3D, $08, $2E, $A0, $11, $FD, $E0, $50, $5B, $40, $DC, $14, $1B, $82, $E4
	dc.b	$11, $77, $84, $2A, $63, $63, $B4, $20, $9E, $3A, $43, $A7, $44, $6E, $08, $23, $4C, $65, $86, $AB, $52, $DC, $0D, $19, $E4, $DC, $53, $5E, $A7, $94, $D6, $AA
	dc.b	$79, $5B, $53, $1F, $9C, $6F, $7D, $E9, $B8, $AD, $A0, $43, $68, $F2, $6F, $DC, $0E, $47, $95, $C4, $2A, $9B, $B5, $DE, $A7, $57, $D3, $5D, $36, $B8, $E5, $2D
	dc.b	$FB, $8A, $9E, $52, $D5, $C6, $98, $36, $98, $1B, $96, $E1, $A1, $AE, $DC, $5E, $A7, $57, $E1, $B8, $D7, $0C, $0F, $E6, $F9, $4E, $A6, $EF, $2C, $3F, $36, $22
	dc.b	$75, $4E, $88, $FC, $E1, $04, $17, $EE, $0A, $67, $3B, $1A, $39, $8F, $40, $B9, $E8, $41, $75, $00, $8F, $EF, $02, $82, $DA, $04, $03, $8B, $03, $82, $1B, $F3
	dc.b	$94, $31, $0C, $98, $AC, $20, $D8, $18, $18, $7B, $D6, $1F, $10, $1A, $B0, $71, $BD, $DA, $86, $36, $37, $63, $8E, $64, $61, $B9, $BB, $5F, $9C, $32, $E6, $0B
	dc.b	$63, $99, $17, $AE, $62, $1B, $99, $42, $FC, $C8, $DD, $BF, $A9, $8A, $F4, $32, $D8, $5B, $27, $F4, $F9, $C3, $E4, $66, $B0, $32, $10, $6A, $CB, $E6, $EC, $0B
	dc.b	$9F, $F2, $42, $7F, $40, $BE, $46, $42, $19, $E8, $86, $46, $76, $C8, $C8, $4F, $E8, $46, $C4, $6F, $B1, $11, $FB, $60, $41, $C8, $C8, $23, $23, $22, $3F, $8C
	dc.b	$08, $4F, $97, $28, $1C, $8F, $EF, $3F, $F7, $9C, $C8, $23, $F9, $D9, $39, $0B, $68, $78, $45, $CB, $A8, $C9, $5B, $B9, $E9, $DD, $E3, $4C, $50, $6D, $31, $72
	dc.b	$08, $2F, $08, $66, $36, $3B, $42, $09, $E3, $A4, $3A, $74, $46, $E0, $82, $23, $FA, $84, $7A, $19, $19, $D9, $3F, $A7, $CE, $D9, $19, $DB, $21, $03, $E9, $F3
	dc.b	$00, $B9, $73, $86, $2C, $70, $43, $5F, $14, $31, $0C, $9B, $0B, $08, $36, $01, $18, $7B, $D6, $1F, $10, $1A, $B0, $71, $BD, $DA, $86, $36, $37, $63, $8E, $6F
	dc.b	$86, $E7, $96, $BF, $30, $98, $73, $76, $C7, $30, $AF, $5C, $C6, $5B, $9E, $45, $F9, $91, $BB, $43, $95, $8A, $1F, $CE, $6C, $1C, $85, $B4, $3C, $60, $B9, $75
	dc.b	$58, $C9, $50, $D4, $0F, $4B, $B4, $3E, $E0, $A7, $DD, $C8, $20, $BC, $21, $98, $D8, $ED, $08, $27, $8E, $8D, $2E, $9F, $86, $DE, $A5, $88, $2A, $1C, $A8, $1D
	dc.b	$F4, $E7, $22, $75, $DD, $F5, $28, $B9, $9D, $29, $39, $33, $AB, $48, $23, $5C, $77, $E4, $C6, $75, $30, $0A, $D0, $BC, $EC, $68, $B4, $C7, $A6, $9A, $05, $EF
	dc.b	$34, $0B, $A9, $A0, $47, $F7, $81, $41, $6D, $02, $07, $70, $51, $73, $B6, $F9, $8F, $40, $B9, $E8, $41, $7A, $80, $44, $4E, $E0, $A1, $3B, $40, $34, $41, $4F
	dc.b	$BB, $90, $41, $78, $43, $38, $6F, $6B, $BF, $05, $34, $DC, $31, $79, $68, $90, $9A, $E8, $8D, $31, $06, $B8, $20, $B7, $BC, $09, $D4, $9D, $33, $EA, $53, $69
	dc.b	$8C, $E9, $87, $27, $D3, $2E, $4C, $0E, $87, $26, $8E, $39, $32, $23, $93, $02, $0B, $F7, $05, $17, $3B, $6F, $98, $F4, $0B, $97, $6E, $40, $BA, $E4, $08, $FE
	dc.b	$F0, $28, $2D, $A0, $47, $35, $E4, $DC, $D6, $1A, $FC, $D0, $61, $CC, $86, $C7, $32, $2F, $5C, $D3, $B7, $32, $F7, $E6, $5C, $86, $DC, $15, $8A, $05, $E7, $4D
	dc.b	$8C, $9F, $CE, $64, $17, $A7, $C0, $20, $CD, $2A, $C0, $20, $CE, $9A, $88, $28, $2B, $B0, $81, $B8, $A9, $61, $B8, $96, $04, $4B, $CD, $DA, $75, $31, $C6, $A5
	dc.b	$DB, $D8, $27, $D4, $B6, $98, $43, $DE, $75, $69, $DE, $A7, $DC, $B4, $FB, $C7, $BD, $6A, $41, $60, $67, $52, $AA, $2B, $52, $76, $A9, $D4, $A1, $46, $75, $37
	dc.b	$06, $79, $4D, $C2, $3E, $D7, $04, $16, $33, $A6, $7E, $53, $CA, $8C, $F2, $5C, $67, $90, $6D, $51, $9D, $31, $D4, $BF, $20, $B5, $4B, $93, $16, $D0, $69, $D0
	dc.b	$91, $CA, $4C, $E8, $CC, $0E, $54, $EC, $29, $4E, $B2, $13, $3E, $94, $89, $A5, $3A, $5A, $69, $0B, $55, $3C, $A8, $6A, $46, $A7, $DD, $9F, $56, $20, $B9, $D5
	dc.b	$4E, $A9, $EB, $DC, $4A, $BC, $EA, $46, $98, $37, $25, $A9, $55, $8D, $7B, $2A, $1C, $6C, $C8, $6A, $42, $D0, $53, $AB, $9D, $53, $F2, $DC, $70, $44, $57, $2E
	dc.b	$08, $32, $84, $A0, $46, $6B, $22, $3F, $8C, $0B, $27, $C8, $AD, $20, $72, $2B, $5D, $DC, $B5, $71, $FC, $82, $3F, $56, $6B, $4F, $08, $36, $A3, $6A, $D3, $72
	dc.b	$96, $BC, $EA, $9B, $14, $D3, $CB, $86, $53, $A6, $9D, $4E, $A5, $88, $23, $4D, $0F, $5A, $92, $37, $9D, $30, $39, $1C, $BB, $89, $D4, $A2, $E7, $92, $A3, $96
	dc.b	$D4, $99, $6C, $34, $E9, $EB, $DA, $FC, $9B, $54, $6A, $79, $54, $9A, $E4, $79, $3F, $24, $26, $8B, $69, $9E, $17, $20, $5E, $8F, $24, $54, $D7, $BB, $4E, $AF
	dc.b	$4C, $79, $4D, $E0, $1A, $E5, $72, $8D, $6A, $6B, $42, $35, $4B, $52, $B8, $D1, $D4, $96, $1E, $EC, $70, $16, $88, $2D, $1C, $A4, $C9, $55, $A6, $E4, $C4, $56
	dc.b	$8B, $4A, $1A, $8F, $73, $EE, $44, $EA, $6B, $92, $AD, $3F, $27, $E4, $57, $27, $D1, $13, $A0, $67, $41, $72, $52, $37, $AD, $49, $04, $15, $CB, $77, $F7, $06
	dc.b	$81, $E4, $15, $8F, $20, $6B, $DD, $B4, $CB, $DC, $8E, $43, $DD, $97, $25, $3A, $3E, $EC, $0C, $8F, $72, $0A, $6D, $09, $A7, $3A, $35, $A8, $CE, $A7, $4E, $5F
	dc.b	$91, $05, $D4, $06, $1D, $DA, $41, $41, $6A, $44, $0E, $F8, $60, $C3, $04, $35, $F1, $4B, $01, $30, $6C, $2C, $04, $D8, $75, $87, $BD, $60, $2C, $6C, $D5, $85
	dc.b	$83, $9B, $B5, $2C, $40, $37, $63, $82, $B0, $C1, $8E, $21, $AF, $8A, $38, $76, $4D, $85, $88, $6C, $39, $C2, $37, $AC, $3E, $21, $35, $60, $E0, $BD, $DA, $86
	dc.b	$3B, $DD, $8E, $39, $91, $86, $E6, $43, $5F, $9A, $0C, $B9, $A0, $D8, $E6, $85, $EB, $9A, $76, $E6, $9E, $FC, $C1, $7E, $EE, $50, $22, $2A, $5B, $25, $4B, $2D
	dc.b	$8C, $B0, $84, $6A, $4B, $A8, $9B, $95, $B8, $93, $D2, $24, $BC, $53, $70, $D7, $8F, $D6, $37, $EE, $5E, $15, $71, $1B, $1B, $C8, $84, $15, $34, $74, $6C, $3A
	dc.b	$74, $D8, $DC, $10, $D7, $22, $F5, $6B, $9A, $6F, $28, $6F, $66, $A4, $17, $F2, $5A, $A6, $83, $7E, $E5, $AA, $03, $7B, $33, $A1, $4D, $C6, $E2, $B1, $53, $0D
	dc.b	$FF, $99, $6B, $9B, $B7, $B5, $C2, $14, $DE, $CD, $08, $DF, $F7, $34, $C7, $37, $FD, $CB, $7E, $71, $A9, $BF, $72, $D7, $05, $A5, $A9, $3D, $5B, $DA, $9B, $81
	dc.b	$5F, $C9, $46, $9B, $F7, $3D, $AE, $9B, $F7, $35, $B5, $7E, $E5, $9D, $57, $F2, $69, $A6, $9B, $86, $20, $AF, $CD, $FB, $30, $A8, $CF, $EE, $50, $23, $DA, $C2
	dc.b	$B8, $6B, $FE, $E6, $81, $BB, $7B, $51, $42, $F5, $EC, $C0, $DE, $3F, $A9, $FB, $96, $BE, $67, $37, $A6, $A7, $F5, $8A, $6B, $B3, $E7, $C9, $A5, $F2, $30, $D3
	dc.b	$E9, $F1, $4C, $41, $7C, $50, $C5, $EA, $D7, $C2, $7C, $DE, $CF, $91, $9C, $21, $9E, $88, $64, $67, $6C, $8C, $84, $FE, $84, $6C, $46, $FB, $11, $18, $F4, $08
	dc.b	$2D, $81, $90, $46, $1B, $19, $10, $A9, $B2, $08, $58, $9C, $B9, $58, $9C, $8D, $EE, $C5, $E0, $36, $E0, $AC, $50, $3B, $16, $C6, $63, $D0, $2E, $5F, $00, $82
	dc.b	$EA, $B0, $08, $DD, $A8, $82, $82, $BB, $08, $10, $0B, $5C, $82, $88, $BB, $6D, $BA, $A6, $3E, $81, $15, $2D, $B1, $06, $F5, $30, $08, $FE, $F0, $28, $2D, $A0
	dc.b	$6E, $0A, $7B, $B1, $72, $08, $BB, $C2, $19, $81, $80, $5D, $BF, $38, $82, $78, $E9, $0E, $9D, $11, $B8, $20, $8B, $82, $AA, $F0, $D5, $83, $8F, $CD, $CD, $EB
	dc.b	$FB, $51, $B1, $BB, $08, $41, $3C, $74, $87, $4E, $88, $DC, $10, $47, $EE, $58, $15, $2D, $EC, $DF, $AC, $29, $BD, $AD, $72, $1B, $DA, $ED, $2D, $7B, $4C, $02
	dc.b	$0E, $2B, $70, $50, $5B, $40, $8B, $B7, $B5, $45, $7F, $26, $8C, $DC, $DD, $BD, $A8, $ED, $5C, $35, $15, $F9, $CF, $F5, $4B, $56, $3F, $99, $E5, $B8, $20, $83
	dc.b	$5F, $B9, $69, $2F, $5E, $CD, $42, $2B, $F9, $34, $D2, $C2, $BF, $F3, $5E, $57, $FD, $5D, $DD, $3A, $23, $70, $41, $15, $B8, $C5, $5F, $04, $79, $7E, $6C, $CB
	dc.b	$53, $50, $43, $F7, $2D, $78, $6A, $C5, $BD, $B0, $72, $56, $EE, $7A, $77, $7D, $C1, $4F, $BB, $90, $41, $78, $43, $17, $8F, $CE, $34, $B5, $7E, $E5, $AE, $F1
	dc.b	$D2, $1D, $3A, $23, $70, $41, $07, $F3, $85, $CA, $BB, $0F, $E7, $30, $39, $08, $77, $78, $45, $CB, $A8, $C9, $5B, $B9, $E9, $DD, $F7, $62, $9E, $31, $40, $82
	dc.b	$0B, $62, $10, $CC, $6C, $5F, $10, $82, $7A, $C7, $48, $6A, $4E, $88, $BB, $10, $41, $7C, $1A, $B1, $45, $EA, $D8, $DF, $36, $C3, $20, $71, $60, $CE, $6B, $AC
	dc.b	$0C, $75, $DC, $62, $CB, $68, $11, $56, $4F, $BD, $88, $20, $8B, $15, $64, $6C, $2C, $3A, $AF, $F5, $0B, $45, $93, $F6, $DC, $10, $41, $05, $0B, $43, $91, $62
	dc.b	$F0, $BB, $46, $D6, $78, $42, $C2, $36, $B1, $74, $F6, $1B, $82, $08, $8F, $EA, $11, $E8, $65, $A9, $55, $A8, $59, $58, $32, $B0, $EA, $AC, $2C, $10, $B2, $AE
	dc.b	$CA, $01, $73, $FE, $48, $4F, $E8, $1B, $26, $AB, $57, $6B, $D8, $76, $CF, $F6, $B3, $64, $2C, $33, $D8, $EC, $46, $F6, $04, $42, $B2, $04, $15, $D6, $F6, $56
	dc.b	$56, $2C, $AC, $AC, $59, $59, $58, $32, $EB, $73, $5D, $DF, $75, $0E, $54, $0F, $E7, $30, $B2, $08, $31, $B3, $C3, $1B, $17, $4C, $6C, $54, $75, $E9, $16, $7D
	dc.b	$C1, $4F, $BB, $90, $41, $16, $2D, $56, $3D, $AF, $67, $B5, $C7, $63, $67, $B1, $16, $7C, $5B, $70, $41, $7E, $E0, $A2, $E7, $63, $46, $BB, $2A, $61, $6A, $22
	dc.b	$C2, $C5, $DA, $2D, $51, $63, $5D, $85, $6D, $03, $70, $53, $EE, $E4, $10, $7B, $52, $1D, $8D, $85, $83, $1B, $0B, $06, $36, $16, $3D, $A8, $2B, $6E, $08, $20
	dc.b	$82, $9F, $77, $20, $83, $63, $D6, $AC, $2C, $7A, $9B, $2E, $A2, $C3, $AA, $B2, $EA, $41, $04, $1B, $27, $DD, $C8, $20, $8B, $1E, $A6, $CE, $6C, $2C, $85, $81
	dc.b	$B0, $B4, $0B, $5F, $AE, $E0, $82, $0A, $87, $2A, $07, $F3, $85, $5A, $82, $06, $C5, $84, $2E, $AE, $8D, $91, $5B, $D7, $6D, $BB, $BE, $ED, $FB, $68, $C5, $10
	dc.b	$72, $5B, $0F, $19, $7D, $C5, $B0, $8E, $C9, $AB, $0F, $02, $D4, $E4, $1A, $BB, $7F, $FA, $1C, $A0, $47, $F3, $B2, $72, $10, $61, $61, $5D, $8D, $8D, $93, $1B
	dc.b	$1B, $1E, $A2, $C2, $2C, $2A, $C4, $14, $FB, $B9, $04, $17, $84, $32, $D4, $2C, $7A, $9B, $2E, $A2, $C3, $AA, $B2, $ED, $46, $BA, $95, $0E, $54, $0F, $E7, $39
	dc.b	$C8, $40, $D8, $B0, $85, $DA, $EE, $8D, $91, $5B, $D8, $F4, $36, $2F, $BF, $F1, $BF, $9C, $0E, $4F, $48, $CB, $EF, $56, $C9, $7B, $28, $73, $63, $D0, $D9, $7F
	dc.b	$3A, $AC, $3B, $82, $8B, $9D, $B7, $CC, $65, $A8, $D8, $F5, $36, $1D, $45, $8F, $53, $65, $DA, $81, $EA, $41, $4E, $58, $8B, $02, $0B, $D9, $0C, $9E, $A6, $98
	dc.b	$1B, $05, $68, $B3, $96, $7B, $04, $44, $76, $1F, $CA, $4F, $BB, $9B, $02, $F1, $6C, $D8, $75, $78, $56, $7B, $3D, $A3, $B0, $B1, $16, $A1, $D8, $77, $72, $81
	dc.b	$1F, $CE, $C9, $C8, $4F, $DA, $85, $91, $16, $16, $AE, $AB, $A8, $B0, $FF, $D5, $88, $29, $F7, $72, $08, $67, $84, $17, $6A, $18, $EC, $2C, $AC, $18, $D8, $58
	dc.b	$B0, $B0, $B1, $63, $61, $8E, $C5, $40, $EA, $6D, $DD, $81, $C8, $41, $8D, $87, $53, $63, $64, $C6, $C6, $C5, $85, $85, $83, $1B, $0B, $16, $DD, $CA, $04, $7F
	dc.b	$3B, $27, $21, $06, $A8, $FE, $D0, $B0, $EA, $AC, $BA, $8B, $0E, $B1, $D4, $1C, $31, $63, $82, $1A, $F8, $A1, $88, $64, $D8, $58, $41, $B0, $08, $C3, $DE, $B0
	dc.b	$3C, $A0, $35, $61, $63, $7B, $B5, $79, $6C, $6E, $C7, $05, $BF, $88, $D8, $AF, $43, $2D, $85, $B2, $7F, $4F, $9C, $3E, $45, $DA, $B0, $32, $3B, $56, $5E, $D7
	dc.b	$60, $5F, $F9, $5B, $42, $7F, $40, $8B, $21, $90, $AC, $BA, $76, $56, $4C, $2C, $BB, $5D, $59, $58, $45, $85, $B7, $D8, $88, $FD, $B0, $20, $AB, $64, $11, $91
	dc.b	$91, $0A, $CA, $C5, $95, $95, $83, $2B, $2B, $5D, $8D, $8D, $FB, $77, $72, $81, $1F, $CE, $CD, $90, $5B, $43, $C3, $1B, $1E, $A6, $C6, $C5, $85, $85, $85, $CD
	dc.b	$85, $A0, $14, $FB, $B9, $04, $17, $84, $33, $1B, $17, $68, $5F, $DA, $16, $1D, $55, $97, $53, $61, $62, $0A, $7D, $DC, $82, $0B, $C5, $B3, $0F, $6D, $A3, $A8
	dc.b	$87, $B4, $3A, $16, $23, $71, $62, $3B, $B9, $40, $8F, $E7, $64, $E4, $2D, $A1, $E2, $AD, $44, $75, $4C, $6C, $7A, $8B, $0B, $40, $B4, $02, $9F, $77, $20, $82
	dc.b	$F0, $86, $63, $62, $F6, $36, $5D, $45, $87, $55, $65, $D4, $D8, $58, $77, $05, $17, $3B, $6F, $98, $4C, $81, $73, $B7, $5A, $0C, $6C, $6C, $58, $D8, $58, $30
	dc.b	$B1, $B1, $68, $FE, $A1, $1E, $86, $5B, $3B, $27, $F4, $F9, $67, $EA, $98, $59, $58, $32, $B0, $B2, $63, $61, $6F, $F2, $42, $7F, $40, $BE, $46, $42, $19, $E9
	dc.b	$65, $65, $5D, $95, $97, $51, $65, $D4, $58, $58, $EC, $45, $BD, $75, $39, $19, $04, $64, $64, $43, $57, $A1, $64, $C3, $2E, $6C, $73, $56, $EE, $2D, $00, $A7
	dc.b	$DD, $C8, $20, $BC, $21, $98, $D8, $BB, $51, $EB, $56, $16, $1D, $55, $97, $53, $61, $62, $A1, $CA, $81, $FC, $E7, $39, $08, $77, $78, $5D, $68, $23, $65, $6D
	dc.b	$EC, $6C, $E6, $C6, $DB, $AC, $30, $6F, $28, $6B, $E2, $BC, $9D, $93, $7E, $B6, $1B, $0F, $E4, $8D, $EB, $03, $CA, $13, $57, $EB, $4B, $DD, $AB, $CB, $BD, $DB
	dc.b	$C8, $36, $E2, $ED, $8A, $07, $62, $D8, $CC, $7A, $05, $CB, $E0, $10, $5D, $56, $01, $07, $B5, $10, $55, $AE, $C2, $07, $F2, $95, $B7, $72, $08, $2F, $08, $66
	dc.b	$36, $3B, $42, $09, $CD, $87, $51, $61, $62, $C6, $C2, $C5, $8D, $90, $EC, $5C, $82, $0B, $C2, $19, $8D, $88, $61, $08, $27, $A3, $60, $C6, $C3, $B5, $CD, $8D
	dc.b	$AE, $0B, $03, $63, $64, $5C, $ED, $BE, $63, $2C, $0B, $9E, $84, $17, $4C, $6C, $2C, $58, $D8, $D9, $30, $B5, $EC, $6C, $57, $52, $E4, $1B, $39, $EA, $A3, $63
	dc.b	$B4, $21, $61, $DA, $E2, $C5, $EC, $2C, $3A, $9B, $02, $0A, $ED, $0E, $41, $05, $E1, $0C, $C6, $C7, $68, $41, $3D, $ED, $71, $7E, $A9, $85, $87, $53, $61, $5D
	dc.b	$88, $B1, $73, $B6, $F9, $8C, $D8, $B9, $7B, $10, $5D, $58, $10, $7A, $90, $50, $56, $10, $0F, $62, $BF, $B4, $08, $20, $DA, $10, $CC, $6C, $76, $84, $13, $D8
	dc.b	$55, $A8, $D9, $59, $30, $68, $EA, $0D, $95, $8B, $17, $20, $82, $F0, $86, $63, $63, $61, $08, $2B, $57, $61, $FC, $A4, $EA, $C7, $B1, $1D, $A3, $AA, $04, $45
	dc.b	$8E, $4E, $6D, $B4, $39, $A4, $5C, $BD, $8E, $4A, $B1, $73, $B3, $77, $72, $D5, $D4, $53, $17, $20, $82, $F0, $86, $6D, $B1, $76, $84, $13, $D8, $57, $6A, $60
	dc.b	$AC, $BB, $45, $87, $58, $1D, $A0, $7F, $39, $CE, $42, $1D, $DE, $11, $72, $E8, $D9, $32, $DF, $B5, $F6, $36, $2F, $16, $36, $16, $04, $7F, $3B, $27, $21, $3D
	dc.b	$88, $B1, $56, $06, $CB, $A9, $EC, $6C, $45, $81, $B1, $16, $8E, $B5, $BB, $90, $41, $78, $43, $31, $B1, $DA, $10, $4F, $61, $56, $A3, $65, $64, $C2, $C7, $AB
	dc.b	$9C, $31, $6F, $22, $1A, $F8, $AF, $28, $64, $DF, $AD, $41, $B0, $0F, $93, $DE, $B0, $3C, $A0, $35, $7E, $B7, $7B, $B5, $79, $6C, $6E, $DE, $45, $8A, $7B, $62
	dc.b	$81, $06, $AD, $88, $43, $31, $B1, $7C, $42, $09, $EB, $1D, $21, $A9, $3A, $B5, $D8, $82, $2C, $2C, $6C, $7A, $9B, $06, $8C, $C7, $A0, $5C, $F4, $20, $BA, $80
	dc.b	$47, $76, $3D, $A9, $35, $C4, $58, $B0, $B3, $9B, $0B, $02, $19, $E1, $0C, $C6, $C7, $68, $41, $3C, $74, $8A, $EC, $2B, $AD, $03, $60, $C2, $FD, $AF, $67, $EC
	dc.b	$19, $E1, $0C, $C6, $C7, $68, $41, $06, $8E, $85, $A8, $27, $5D, $A0, $10, $6C, $6C, $2C, $3A, $AB, $21, $9D, $93, $FA, $7C, $B3, $E4, $65, $9F, $21, $0B, $2A
	dc.b	$ED, $4C, $45, $87, $5D, $AC, $6F, $D9, $5E, $CF, $91, $90, $86, $7A, $21, $91, $9D, $B2, $32, $13, $E7, $B1, $D8, $D8, $D9, $C8, $EB, $91, $56, $C8, $C8, $23
	dc.b	$23, $22, $3F, $8C, $08, $4F, $97, $2C, $0D, $83, $55, $8F, $6B, $B1, $46, $C0, $AB, $0A, $EC, $5C, $E4, $21, $DD, $E1, $17, $2E, $A3, $25, $45, $A8, $D7, $52
	dc.b	$C6, $DB, $8E, $C3, $FB, $54, $6C, $F0, $86, $63, $63, $B4, $20, $9E, $3A, $43, $D5, $A8, $B4, $58, $B1, $61, $DC, $1B, $39, $D9, $A3, $31, $E8, $17, $3D, $08
	dc.b	$22, $D0, $08, $3F, $CA, $A3, $D4, $58, $8E, $C0, $D8, $76, $7A, $ED, $4F, $08, $66, $36, $3B, $42, $08, $34, $74, $36, $09, $D5, $B7, $04, $16, $36, $4F, $BD
	dc.b	$88, $20, $BC, $21, $98, $D8, $BB, $45, $93, $B1, $16, $11, $65, $D4, $34, $58, $58, $5A, $2C, $8F, $61, $6D, $F3, $1E, $81, $73, $D0, $82, $EA, $01, $1D, $EA
	dc.b	$D4, $82, $16, $2C, $22, $C6, $C2, $2C, $2B, $B1, $78, $43, $31, $B1, $DA, $10, $4F, $1D, $21, $D3, $A2, $37, $04, $10, $58, $A7, $B6, $28, $10, $7B, $62, $10
	dc.b	$B4, $6C, $5F, $10, $82, $7A, $C7, $48, $6A, $4E, $88, $BB, $10, $45, $34, $57, $54, $0D, $8D, $8E, $7F, $95, $B4, $3C, $22, $E5, $D4, $66, $AD, $0E, $6C, $F6
	dc.b	$AE, $A6, $C5, $0F, $E5, $51, $16, $35, $D9, $55, $A3, $63, $B4, $20, $9C, $D5, $85, $88, $B3, $A2, $3A, $9B, $06, $50, $E5, $A0, $77, $B0, $39, $09, $BB, $BC
	dc.b	$22, $E5, $D4, $64, $DA, $1C, $F4, $AE, $C2, $C5, $A2, $C3, $B1, $16, $3D, $4D, $76, $A7, $87, $84, $5C, $BA, $8C, $95, $62, $E5, $EC, $7B, $50, $B1, $05, $0B
	dc.b	$43, $91, $62, $F0, $BB, $46, $D6, $78, $42, $C2, $3A, $43, $A7, $44, $6E, $08, $22, $C6, $C0, $F6, $16, $7B, $15, $62, $A9, $02, $E7, $A1, $05, $D1, $EB, $1D
	dc.b	$6E, $50, $EB, $00, $F5, $43, $AB, $90, $7F, $94, $7A, $C6, $C7, $68, $41, $3F, $61, $7E, $B7, $42, $C4, $34, $0B, $10, $47, $53, $61, $60, $43, $50, $AE, $C9
	dc.b	$A3, $63, $B4, $20, $9D, $8B, $DA, $1D, $75, $1B, $B7, $E6, $D8, $31, $B3, $F6, $36, $8E, $CA, $C8, $59, $E1, $E1, $17, $2E, $A3, $27, $F4, $A5, $CF, $E9, $47
	dc.b	$7F, $D2, $C0, $29, $CB, $17, $20, $86, $78, $41, $34, $6C, $76, $84, $13, $FE, $14, $8F, $03, $C3, $AF, $0B, $C6, $FE, $07, $86, $46, $C3, $B1, $16, $3D, $4D
	dc.b	$85, $BB, $BC, $22, $E5, $D1, $FD, $AA, $3F, $85, $3E, $0F, $81, $F8, $53, $E0, $F8, $3F, $85, $3D, $41, $42, $DF, $CE, $55, $D8, $2D, $A1, $E1, $17, $2E, $BF
	dc.b	$4A, $BF, $8A, $E7, $C0, $F1, $BF, $83, $F8, $51, $DC, $14, $5C, $ED, $BE, $63, $D0, $2E, $7A, $10, $5D, $40, $23, $7F, $C2, $C0, $28, $2F, $C2, $BC, $08, $07
	dc.b	$0C, $5B, $C8, $86, $BE, $2B, $CA, $19, $37, $EB, $50, $6C, $03, $E4, $F7, $AC, $0F, $28, $0D, $5F, $AD, $DE, $ED, $5E, $5B, $8B, $B7, $91, $6E, $96, $C5, $7A
	dc.b	$1D, $B0, $B6, $B0, $F4, $F4, $D8, $7C, $8C, $D6, $06, $42, $0D, $59, $7F, $17, $60, $5F, $C0, $B0, $B4, $2B, $2B, $02, $2C, $AC, $85, $A9, $59, $D0, $C8, $CE
	dc.b	$D9, $19, $09, $FC, $2F, $05, $FC, $0F, $06, $C0, $D8, $AB, $21, $62, $AD, $9B, $05, $6C, $D8, $FF, $18, $10, $9F, $2E, $7C, $1F, $DA, $F7, $F0, $22, $D5, $16
	dc.b	$56, $04, $58, $DA, $91, $B2, $AE, $C2, $DB, $10, $5D, $40, $23, $7F, $04, $78, $0B, $F4, $A7, $C1, $FC, $29, $06, $C2, $C7, $A9, $EA, $6C, $3F, $D4, $6C, $21
	dc.b	$04, $F1, $D2, $3F, $6A, $17, $ED, $48, $23, $C1, $05, $3E, $EE, $41, $05, $E1, $0C, $C6, $C7, $68, $41, $3C, $74, $8F, $09, $D1, $1B, $82, $08, $3D, $41, $60
	dc.b	$47, $62, $D9, $BF, $65, $FD, $A0, $59, $17, $2E, $A3, $25, $6E, $E7, $A7, $77, $8E, $CA, $C6, $CE, $6C, $2D, $78, $B2, $EA, $2F, $D8, $42, $09, $E3, $A4, $3A
	dc.b	$74, $46, $E0, $82, $19, $59, $FB, $1F, $F5, $0B, $21, $D8, $D9, $EC, $8B, $97, $51, $92, $B7, $73, $D3, $BB, $F7, $DB, $F4, $A4, $7A, $0B, $F0, $A3, $3B, $2F
	dc.b	$C2, $8F, $5F, $B5, $DB, $23, $3B, $64, $20, $7D, $3E, $60, $17, $23, $F0, $AF, $E0, $7E, $D4, $78, $5F, $B5, $5E, $17, $E9, $46, $7F, $4A, $10, $C8, $CE, $D9
	dc.b	$19, $09, $FD, $08, $D8, $8D, $FC, $0F, $07, $F0, $AB, $F6, $A4, $7E, $15, $78, $C8, $3F, $85, $5E, $32, $0F, $E1, $7F, $8C, $08, $4F, $97, $28, $1C, $8F, $EF
	dc.b	$3C, $7E, $94, $F8, $3E, $1C, $FF, $14, $E7, $C2, $FD, $A8, $F1, $D0, $82, $EA, $01, $1F, $DE, $05, $05, $B4, $08, $FC, $28, $29, $F7, $72, $08, $3F, $85, $10
	dc.b	$86, $7C, $6C, $76, $84, $13, $C7, $48, $74, $E8, $8D, $C1, $04, $15, $86, $0D, $E5, $0D, $7C, $57, $93, $B2, $6F, $D6, $C3, $61, $FC, $91, $BD, $60, $60, $42
	dc.b	$6A, $FD, $69, $7B, $B5, $60, $77, $BB, $60, $16, $87, $F1, $8A, $1B, $F8, $6C, $1C, $8F, $0F, $0F, $E3, $05, $C8, $F1, $58, $C9, $50, $D4, $0F, $4B, $B4, $3E
	dc.b	$E0, $F8, $1E, $0B, $F8, $3E, $1C, $F8, $1E, $20, $78, $3F, $B5, $3E, $17, $88, $E9, $0E, $9D, $11, $B8, $20, $82, $8F, $80, $54, $0F, $DA, $97, $3E, $02, $1B
	dc.b	$F8, $11, $E0, $7E, $D5, $46, $4A, $DD, $CF, $4E, $EF, $1F, $D5, $3F, $A5, $1F, $A5, $8F, $05, $78, $43, $C4, $78, $8F, $0F, $E0, $7E, $16, $32, $56, $EE, $7A
	dc.b	$77, $78, $F0, $53, $FF, $54, $1F, $0F, $FA, $51, $E2, $3F, $4A, $7F, $AA, $17, $88, $E9, $0E, $9D, $11, $B8, $20, $8E, $EE, $57, $81, $FC, $EC, $9C, $85, $B4
	dc.b	$5F, $11, $E1, $DA, $E1, $46, $4A, $DD, $CF, $4E, $EF, $00, $E1, $8B, $79, $10, $D7, $C5, $60, $43, $26, $F2, $08, $36, $01, $C6, $D7, $AC, $0C, $08, $0D, $5E
	dc.b	$43, $7B, $B5, $63, $A1, $BB, $60, $F3, $47, $0D, $CD, $16, $BF, $34, $18, $F3, $86, $C7, $32, $AF, $5C, $D4, $37, $38, $17, $E7, $02, $18, $40, $2B, $15, $1B
	dc.b	$16, $C0, $51, $92, $E4, $17, $C1, $72, $EA, $B0, $88, $DD, $A9, $CA, $0A, $EC, $20, $77, $C3, $16, $1B, $B5, $F1, $50, $EC, $5B, $01, $02, $D8, $2E, $42, $BD
	dc.b	$60, $ED, $0D, $58, $5B, $8B, $B6, $D0, $0B, $5C, $1E, $64, $47, $38, $17, $E6, $86, $17, $35, $B7, $35, $B7, $34, $E7, $9A, $DB, $9C, $3F, $E7, $01, $0D, $3A
	dc.b	$BB, $DE, $79, $33, $99, $D3, $66, $27, $4C, $76, $6D, $48, $4E, $67, $4C, $E6, $87, $2B, $84, $58, $CE, $A8, $83, $3A, $96, $2E, $56, $1B, $93, $6F, $92, $D2
	dc.b	$CB, $68, $69, $C1, $FC, $E3, $E2, $70, $A5, $B2, $67, $06, $6E, $0D, $D9, $E6, $2E, $C3, $70, $53, $EE, $E4, $10, $5E, $10, $58, $8D, $B1, $52, $21, $62, $A5
	dc.b	$A0, $62, $A5, $B0, $EA, $A5, $B0, $23, $13, $AB, $90, $54, $39, $51, $8A, $F6, $B7, $B5, $61, $09, $6B, $97, $3F, $9C, $2E, $47, $11, $85, $7E, $2E, $68, $5E
	dc.b	$5A, $E2, $4D, $E5, $AF, $FD, $E7, $2A, $AF, $8F, $E7, $64, $E4, $20, $DC, $53, $C3, $5D, $A6, $9D, $42, $B2, $DE, $F8, $B6, $DC, $54, $D0, $DD, $37, $0C, $54
	dc.b	$4F, $76, $7E, $1A, $ED, $31, $24, $34, $B2, $32, $08, $E2, $32, $56, $E1, $8F, $48, $92, $E6, $7B, $B9, $60, $41, $9D, $D9, $37, $17, $E0, $54, $99, $A9, $A6
	dc.b	$2D, $C5, $DA, $63, $25, $44, $B9, $E9, $C1, $6E, $0B, $10, $53, $96, $2E, $41, $69, $0D, $35, $65, $26, $5F, $81, $EC, $5A, $58, $34, $74, $87, $4E, $88, $92
	dc.b	$D3, $58, $90, $5A, $1C, $A6, $23, $F9, $C2, $4B, $4B, $26, $33, $53, $53, $52, $A6, $9A, $58, $49, $F2, $45, $46, $27, $07, $66, $F6, $2F, $89, $EE, $E5, $02
	dc.b	$3F, $9D, $2C, $72, $10, $A9, $87, $85, $2E, $5D, $46, $4A, $DD, $CF, $4E, $EF, $B8, $29, $F7, $18, $BD, $37, $0F, $08, $2C, $1A, $E1, $AE, $F5, $2D, $76, $E0
	dc.b	$5B, $6B, $F1, $6C, $5C, $2B, $B5, $4D, $70, $0D, $CA, $87, $2A, $6B, $1F, $CE, $AF, $66, $C2, $11, $76, $E2, $B0, $8B, $DD, $A6, $AE, $70, $8E, $1B, $8B, $8A
	dc.b	$7C, $5A, $6E, $64, $1B, $F7, $72, $81, $1F, $CE, $C9, $C8, $4C, $F0, $F8, $9C, $17, $23, $13, $58, $C9, $58, $E2, $81, $D9, $B5, $38, $2F, $B8, $69, $E5, $36
	dc.b	$E4, $D8, $6E, $52, $D0, $82, $B1, $D8, $BE, $23, $F3, $89, $E0, $34, $D4, $5C, $2B, $CB, $10, $D7, $23, $82, $08, $8F, $CE, $0B, $CD, $C7, $E7, $1E, $B5, $27
	dc.b	$38, $5F, $87, $6D, $31, $18, $5F, $87, $5C, $50, $C2, $FC, $39, $6D, $50, $BA, $FC, $39, $6D, $30, $BA, $FC, $39, $69, $6C, $7E, $73, $F0, $FC, $CE, $0A, $E6
	dc.b	$71, $1C, $CE, $10, $E6, $71, $1C, $CE, $02, $E6, $B1, $1C, $D6, $1F, $9A, $C6, $ED, $A6, $DB, $46, $B5, $28, $2A, $0A, $74, $C1, $3A, $AE, $2F, $9D, $A7, $53
	dc.b	$75, $B5, $E7, $53, $73, $EA, $F3, $CA, $01, $17, $69, $D5, $FA, $46, $9A, $FE, $81, $6D, $37, $E6, $EE, $82, $6F, $EC, $21, $7A, $6E, $19, $F2, $32, $26, $E3
	dc.b	$D0, $BE, $BF, $B3, $A2, $1B, $52, $1A, $73, $3E, $F2, $55, $36, $A5, $8D, $F9, $4E, $A4, $34, $B2, $9E, $5C, $32, $BB, $4F, $26, $2D, $3F, $B8, $8E, $52, $DC
	dc.b	$9A, $2F, $2D, $71, $17, $96, $20, $83, $2D, $08, $65, $8B, $E0, $ED, $08, $61, $E2, $CF, $0E, $A5, $91, $1B, $B4, $82, $0F, $14, $E5, $40, $FE, $73, $9C, $84
	dc.b	$3B, $BC, $22, $E5, $D4, $64, $AD, $DC, $F4, $EE, $FD, $E6, $FE, $D7, $06, $5A, $5A, $71, $99, $BC, $89, $DA, $1E, $11, $0C, $5D, $43, $4B, $2D, $C4, $99, $A9
	dc.b	$11, $ED, $53, $89, $35, $26, $4F, $14, $DC, $37, $0D, $29, $B8, $52, $81, $73, $D1, $81, $74, $5A, $58, $6F, $38, $9C, $34, $B5, $4D, $4D, $48, $9A, $9A, $9A
	dc.b	$9C, $34, $9A, $93, $C5, $48, $C3, $19, $BF, $11, $B1, $DA, $10, $4F, $26, $76, $89, $69, $C3, $4B, $63, $DA, $F2, $1B, $F3, $73, $8E, $1A, $A6, $A7, $15, $C5
	dc.b	$4D, $4E, $3D, $B0, $D1, $B1, $79, $8B, $CA, $91, $24, $7E, $6C, $49, $E1, $84, $A9, $A9, $32, $D3, $52, $D1, $FD, $42, $3D, $0C, $8C, $EC, $9F, $D3, $E7, $6C
	dc.b	$8C, $F0, $32, $10, $95, $29, $F3, $C0, $2E, $5E, $B8, $78, $4F, $E8, $17, $C8, $C8, $43, $3D, $10, $C8, $CE, $1F, $23, $21, $3F, $A1, $1B, $11, $17, $69, $B9
	dc.b	$96, $39, $69, $B9, $9D, $64, $34, $DC, $B6, $10, $4D, $2C, $7F, $8C, $DC, $2B, $64, $36, $9A, $4E, $41, $D4, $B4, $3B, $6A, $74, $C5, $CA, $E5, $3F, $CE, $9D
	dc.b	$35, $20, $AF, $3A, $9F, $F4, $48, $B7, $1A, $96, $B9, $51, $EF, $2D, $77, $D3, $4F, $BF, $04, $1B, $F2, $DC, $5D, $B5, $40, $FE, $6D, $B4, $C3, $3E, $EC, $08
	dc.b	$BB, $55, $D0, $57, $98, $DA, $F3, $A7, $57, $9E, $4D, $FB, $9D, $4B, $5C, $B4, $B6, $15, $7E, $1C, $CB, $56, $17, $E5, $DB, $4D, $E4, $BF, $2F, $C5, $62, $EB
	dc.b	$F2, $FA, $6F, $2B, $AF, $CB, $B5, $FC, $AE, $BF, $2F, $7F, $D6, $DD, $7E, $5C, $7E, $B4, $2F, $EB, $F3, $FD, $3F, $F0, $3F, $4F, $FC, $0F, $D3, $FF, $03, $F4
	dc.b	$FF, $C0, $FD, $3F, $F0, $3F, $4F, $FC, $0F, $D3, $F9, $FE, $01, $79, $2E, $6B, $C8, $F3, $5F, $AD, $E6, $BF, $5B, $CD, $7E, $B7, $9A, $FD, $6F, $35, $7F, $2E
	dc.b	$7F, $AC, $C0, $EE, $0D, $CB, $9D, $B7, $CC, $7A, $05, $CB, $E0, $10, $5D, $40, $23, $7C, $40, $28, $2D, $8F, $EF, $5A, $7F, $91, $26, $FF, $BB, $B9, $78, $43
	dc.b	$31, $B1, $DA, $10, $4F, $1D, $21, $D3, $A2, $3F, $F8, $DB, $B7, $26, $2E, $5D, $A6, $33, $1E, $81, $73, $D0, $82, $EA, $01, $1F, $DE, $05, $05, $FA, $CC, $5F
	dc.b	$F5, $A4, $34, $DC, $47, $BD, $C1, $05, $E1, $0C, $C6, $C7, $68, $41, $3C, $74, $87, $4E, $88, $F2, $20, $82, $E6, $4C, $86, $92, $E7, $6D, $F3, $1E, $81, $73
	dc.b	$D0, $82, $EA, $01, $1F, $DE, $07, $F8, $9F, $DD, $61, $29, $A5, $A1, $C8, $20, $BC, $21, $98, $D8, $ED, $08, $27, $8E, $90, $E9, $D1, $1F, $FC, $9B, $CD, $DA
	dc.b	$5A, $1C, $82, $0B, $C2, $19, $8D, $8E, $D0, $82, $78, $E9, $0E, $9D, $11, $FF, $CE, $19, $48, $9A, $2E, $41, $05, $E1, $0C, $C6, $C7, $68, $41, $3C, $74, $87
	dc.b	$4E, $88, $FF, $E7, $B4, $02, $8B, $9D, $B7, $CC, $7A, $05, $CF, $42, $0B, $A8, $04, $7F, $78, $14, $17, $EB, $31, $7F, $D6, $90, $53, $EE, $E4, $10, $5E, $10
	dc.b	$CC, $6C, $76, $84, $13, $C7, $48, $74, $E8, $8F, $22, $08, $22, $F2, $C8, $37, $23, $7F, $79, $62, $F0, $86, $63, $63, $B4, $20, $9E, $3A, $43, $A7, $44, $6E
	dc.b	$08, $21, $B7, $69, $E4, $5C, $BD, $EA, $33, $1E, $81, $73, $D0, $82, $EA, $01, $1F, $DE, $05, $05, $B4, $08, $F7, $96, $BC, $7E, $AE, $E0, $F4, $85, $B4, $7F
	dc.b	$13, $02, $1F, $C8, $43, $FE, $F5, $FF, $FB, $8B, $D7, $E9, $DF, $17, $35, $F9, $71, $E5, $75, $FA, $7F, $D6, $DD, $7E, $9F, $CB, $F3, $8B, $F4, $FE, $5F, $9C
	dc.b	$5F, $A7, $C7, $E7, $05, $7E, $9F, $1F, $9C, $3F, $F7, $FF, $3F, $F0, $3F, $4F, $FC, $0F, $D3, $FF, $03, $F4, $FF, $C0, $FC, $BF, $F4, $3F, $2F, $FD, $0F, $CB
	dc.b	$FF, $43, $F2, $FF, $D0, $FF, $BF, $FD, $FF, $EF, $FF, $7F, $3F, $3F, $3F, $3F, $CB, $FF, $43, $F0, $FF, $E0, $FC, $3F, $9F, $9F, $9F, $9F, $9F, $F8, $00, $00
Race_finish_object_init_data:
	dc.b	$00, $D5, $01, $1E, $00, $02, $58, $9E, $00, $CC, $00, $F9, $00, $02, $58, $68, $00, $EA, $00, $F9, $00, $02, $58, $70, $00, $DA, $00, $F2, $00, $02, $58, $78
Race_finish_palette_stream:
	dc.b	$02, $3E, $00, $00, $0E, $EE, $06, $62, $06, $64, $0C, $CC, $0A, $AA, $02, $22, $02, $46, $04, $68, $06, $8A, $08, $AC, $0A, $CE, $00, $AA, $00, $EE, $0C, $86
	dc.b	$00, $00, $00, $00, $02, $2E, $06, $62, $06, $64, $0C, $CC, $0A, $AA, $02, $22, $02, $46, $04, $68, $06, $8A, $08, $AC, $0A, $CE, $00, $AA, $00, $EE, $0C, $86
	dc.b	$00, $00, $00, $00, $00, $CE, $02, $22, $08, $88, $04, $44, $02, $24, $0E, $EE, $00, $06, $00, $08, $00, $2A, $02, $4C, $04, $6E, $06, $8E, $0A, $AA, $00, $00
	dc.b	$00, $00, $00, $00, $08, $AC, $02, $24, $02, $44, $04, $44, $04, $66, $06, $66, $06, $88, $08, $88, $08, $AA, $0A, $AA, $0A, $CC, $0C, $EE, $0E, $EE, $00, $00
	dc.b	$00, $00, $E8, $06, $21, $6F, $FF, $F8, $00, $00, $E8, $06, $21, $75, $FF, $F8, $00, $05, $A8, $0F, $61, $7B, $FF, $EC, $A8, $02, $61, $8B, $00, $0C, $C8, $0F
	dc.b	$61, $8E, $FF, $EC, $C8, $02, $61, $9E, $00, $0C, $E8, $0E, $61, $A1, $FF, $EC, $E8, $02, $61, $AD, $00, $0C, $00, $01, $D8, $0F, $21, $B0, $FF, $F0, $F8, $08
	dc.b	$21, $C0, $FF, $F8
Race_finish_layout_tilemap:
	dc.b	$07, $00, $00, $01, $00, $01, $01, $F7, $DF, $7D, $F7, $DF, $54, $1A, $20, $80, $A2, $0A, $08, $28, $00, $C0, $C4, $13, $90, $40, $40, $CB, $82, $18, $F8, $05
	dc.b	$43, $80, $18, $98, $29, $43, $80, $54, $3E, $A0, $9A, $35, $68, $D4, $10, $14, $5A, $51, $69, $44, $84, $10, $D4, $89, $05, $58, $35, $13, $F0, $4A, $D2, $44
	dc.b	$15, $62, $B4, $57, $41, $4B, $49, $80, $5C, $52, $86, $A8, $9B, $8B, $32, $B4, $DA, $7A, $04, $D1, $AB, $46, $A0, $9C, $34, $6A, $D1, $AD, $B0, $DC, $03, $52
	dc.b	$25, $C1, $CD, $B2, $BC, $0A, $D2, $45, $C9, $E2, $50, $D6, $53, $70, $4B, $49, $87, $27, $EC, $CA, $D3, $69, $F4, $13, $46, $AD, $1A, $82, $70, $D1, $AB, $46
	dc.b	$A4, $08, $86, $A4, $4A, $93, $98, $21, $AA, $87, $A2, $7F, $81, $5A, $48, $A9, $3C, $82, $56, $A9, $6A, $2B, $B8, $25, $A4, $C2, $93, $F8, $29, $78, $06, $A8
	dc.b	$9B, $8B, $32, $B4, $DA, $7A, $04, $D1, $AB, $46, $A0, $9C, $34, $6A, $D1, $AF, $F0, $00
Race_finish_buf_tilemap_1:
	dc.b	$08, $00, $00, $42, $00, $00, $78, $24, $83, $44, $34, $83, $40, $35, $07, $50, $74, $C4, $40, $A4, $4A, $44, $94, $C7, $50, $75, $07, $54, $64, $BF, $80, $00
Race_finish_buf_tilemap_2:
	dc.b	$09, $00, $00, $48, $00, $00, $46, $92, $A5, $2A, $4A, $C4, $E9, $2B, $D2, $A6, $B2, $46, $9A, $D9, $3A, $4B, $A4, $29, $AF, $54, $AE, $C1, $52, $9B, $25, $0A
	dc.b	$4C, $D4, $80, $E0, $65, $A4, $D0, $46, $9B, $4E, $89, $BA, $A3, $5D, $1A, $8D, $CE, $07, $AA, $6E, $14, $AC, $B9, $53, $EE, $EF, $45, $BC, $11, $AF, $17, $92
	dc.b	$41, $E6, $A5, $47, $A7, $24, $BB, $E5, $F4, $A5, $47, $DD, $24, $FA, $B4, $A0, $1C, $D4, $B0, $38, $22, $A1, $2F, $E0
Race_finish_buf_tilemap_3:
	dc.b	$09, $00, $00, $8B, $00, $00, $46, $94, $15, $2A, $50, $84, $A9, $C2, $D2, $A7, $0F, $46, $9C, $4D, $2A, $71, $74, $69, $46, $D4, $A5, $1E, $46, $94, $85, $4A
	dc.b	$52, $44, $69, $C9, $D1, $A9, $2B, $46, $D4, $C1, $1B, $33, $B4, $AC, $D1, $53, $81, $4F, $02, $AD, $41, $4A, $F5, $65, $2B, $D7, $95, $AD, $66, $4B, $F8, $00
Race_finish_tiles:
	dc.b	$81, $6D, $80, $03, $00, $14, $05, $25, $13, $36, $2F, $46, $36, $56, $37, $67, $74, $75, $12, $81, $04, $02, $16, $35, $28, $F1, $82, $04, $08, $18, $F4, $83
	dc.b	$04, $03, $17, $76, $84, $06, $32, $18, $F3, $85, $04, $06, $17, $75, $86, $04, $07, $17, $77, $87, $04, $04, $16, $39, $88, $05, $16, $89, $06, $2E, $8A, $05
	dc.b	$14, $18, $F0, $8B, $06, $33, $18, $F5, $8C, $06, $34, $18, $F6, $8D, $05, $15, $8E, $05, $18, $18, $F2, $8F, $06, $38, $FF, $94, $A5, $29, $4A, $52, $FF, $B4
	dc.b	$A5, $29, $4A, $52, $FF, $94, $A5, $29, $4A, $52, $92, $6D, $FA, $7B, $D0, $24, $D3, $A2, $0F, $D3, $CB, $A2, $4A, $4A, $81, $36, $40, $92, $95, $E9, $D1, $25
	dc.b	$29, $2A, $74, $45, $4D, $D0, $26, $DF, $A7, $94, $A6, $9B, $72, $3F, $6E, $39, $1C, $8E, $47, $E9, $E6, $81, $07, $E9, $D7, $99, $A2, $F2, $3F, $4E, $A8, $BC
	dc.b	$CD, $02, $4A, $F4, $1F, $C7, $9F, $F1, $EF, $45, $45, $E4, $72, $BF, $C7, $08, $10, $20, $45, $E6, $7F, $A7, $1F, $A7, $1F, $D7, $57, $D5, $14, $9C, $78, $24
	dc.b	$FC, $2F, $29, $F8, $04, $14, $14, $14, $E6, $FA, $04, $E8, $81, $F4, $CC, $BD, $5C, $BB, $FE, $C7, $FF, $52, $FF, $D7, $FE, $A5, $FF, $A7, $D5, $C9, $F5, $7D
	dc.b	$5C, $22, $FE, $AA, $7A, $F4, $FD, $D2, $92, $FE, $AA, $74, $90, $FD, $56, $DF, $B1, $42, $F5, $FD, $8B, $F8, $8F, $FD, $4B, $FF, $43, $FB, $42, $92, $1F, $CA
	dc.b	$2F, $52, $FD, $37, $F0, $7F, $4C, $9F, $DA, $09, $2F, $ED, $04, $FE, $D0, $49, $7F, $69, $7F, $C3, $7F, $F0, $53, $51, $FB, $A4, $1E, $17, $94, $FF, $74, $28
	dc.b	$28, $3F, $55, $7D, $24, $3C, $0B, $D4, $BD, $7F, $E3, $AF, $FE, $A5, $FF, $AF, $FD, $4B, $FF, $5F, $F1, $D7, $7A, $4B, $72, $A7, $4A, $6C, $52, $F0, $E8, $43
	dc.b	$F6, $22, $84, $3F, $B4, $29, $21, $FB, $A1, $41, $41, $E0, $29, $3A, $2D, $16, $92, $A0, $F0, $1E, $05, $EB, $AE, $7A, $02, $D9, $29, $20, $5B, $D2, $40, $AF
	dc.b	$A0, $A4, $B6, $2F, $52, $DF, $F6, $3B, $EA, $0A, $FD, $77, $D6, $40, $97, $59, $A7, $8C, $C9, $FC, $67, $FC, $10, $9E, $20, $81, $22, $95, $E8, $A5, $7A, $29
	dc.b	$02, $05, $7F, $E9, $B9, $27, $0E, $81, $1C, $9C, $10, $41, $E2, $09, $7C, $41, $02, $BC, $94, $BA, $16, $C5, $B6, $A3, $51, $A8, $4B, $FC, $5E, $FF, $D3, $12
	dc.b	$2F, $2A, $8A, $81, $26, $81, $2F, $4B, $D0, $73, $34, $1F, $A7, $DF, $F4, $F3, $4B, $D0, $72, $A8, $3F, $6E, $39, $5F, $D3, $DE, $8B, $FB, $71, $C8, $FD, $3A
	dc.b	$A0, $45, $E4, $20, $E4, $73, $BF, $2A, $8F, $A6, $65, $EC, $13, $A2, $74, $4B, $E8, $11, $68, $28, $28, $AF, $3F, $01, $C8, $F0, $54, $57, $21, $E0, $4A, $81
	dc.b	$F5, $1F, $B1, $7D, $7F, $F5, $2F, $FD, $7F, $AA, $5F, $EA, $57, $FD, $8C, $DE, $5A, $ED, $E1, $20, $49, $3A, $0A, $4A, $52, $08, $5E, $B7, $FE, $C6, $7F, $CA
	dc.b	$90, $FF, $50, $FF, $54, $A7, $FC, $A7, $F6, $27, $F1, $FD, $31, $39, $2F, $F2, $A5, $3F, $E5, $4F, $F9, $52, $9F, $F2, $AF, $F0, $1E, $05, $22, $94, $A5, $29
	dc.b	$48, $BD, $4B, $D7, $FE, $3A, $FF, $EA, $5F, $EA, $1F, $DA, $92, $FE, $EA, $FF, $D8, $E7, $45, $D6, $FA, $0A, $4A, $65, $2A, $0A, $4A, $65, $2A, $0A, $4F, $3F
	dc.b	$ED, $4A, $82, $8B, $4D, $B5, $92, $D0, $52, $FA, $4C, $94, $A4, $28, $29, $AA, $B8, $A0, $A4, $D2, $9B, $A6, $C5, $7D, $05, $2F, $A4, $AF, $2B, $E8, $28, $13
	dc.b	$D4, $9F, $D8, $91, $79, $54, $1C, $84, $9F, $E9, $EF, $4B, $D0, $72, $10, $20, $FD, $38, $4B, $FF, $6E, $A9, $7B, $EA, $8B, $DE, $65, $7B, $DE, $52, $DC, $AF
	dc.b	$79, $6C, $52, $70, $E5, $D0, $B6, $7B, $CB, $A2, $4D, $E6, $9B, $94, $A4, $AF, $7F, $8A, $74, $29, $EB, $B1, $20, $2D, $92, $5B, $92, $90, $29, $EB, $3F, $E0
	dc.b	$B9, $04, $BD, $15, $24, $A8, $A9, $34, $9A, $4F, $9B, $D2, $69, $3E, $55, $26, $81, $36, $4E, $FF, $B1, $08, $3F, $94, $9D, $39, $1F, $CA, $9F, $F2, $82, $6F
	dc.b	$C8, $FE, $50, $4E, $E4, $3C, $3F, $6C, $53, $FE, $D4, $87, $FE, $87, $FE, $A5, $FF, $A1, $E0, $08, $78, $4A, $52, $A0, $A4, $E9, $79, $02, $5F, $0D, $A8, $35
	dc.b	$9E, $A3, $D4, $BF, $4F, $B7, $E9, $8A, $7F, $CA, $14, $DE, $83, $FB, $43, $FF, $52, $FF, $57, $FC, $7F, $C2, $3F, $B5, $25, $FE, $D2, $FF, $6A, $4B, $FD, $A9
	dc.b	$F8, $0F, $09, $02, $DF, $C2, $FA, $5F, $41, $41, $FA, $A2, $9F, $EE, $97, $C3, $6D, $47, $EE, $AF, $F0, $14, $F1, $DB, $F7, $52, $BF, $FB, $4B, $FE, $A9, $0F
	dc.b	$FD, $50, $10, $F0, $14, $52, $95, $05, $25, $49, $4A, $42, $8B, $E0, $3F, $54, $BF, $B1, $BF, $F6, $33, $FF, $54, $87, $F6, $97, $FB, $52, $5F, $ED, $0F, $01
	dc.b	$E0, $0B, $A1, $52, $74, $14, $BE, $97, $FE, $EA, $FF, $E5, $4A, $7F, $EA, $1F, $A6, $9E, $B2, $45, $F1, $BD, $F5, $1A, $87, $1A, $CB, $A2, $5E, $40, $9E, $F2
	dc.b	$52, $1A, $C8, $13, $92, $5E, $4A, $FE, $2A, $F3, $20, $5D, $0B, $62, $E8, $57, $92, $92, $EB, $79, $4F, $F6, $33, $F1, $1E, $37, $94, $B7, $20, $5B, $92, $92
	dc.b	$6B, $32, $09, $7A, $74, $E5, $53, $A2, $4F, $95, $40, $9B, $20, $40, $92, $1C, $AA, $2A, $0E, $47, $23, $91, $C8, $49, $FE, $DC, $22, $F2, $39, $DF, $99, $26
	dc.b	$E9, $B2, $04, $09, $34, $9A, $5E, $8A, $9B, $A0, $4D, $BF, $4F, $29, $4D, $25, $B2, $74, $40, $92, $95, $E9, $D1, $25, $29, $4A, $52, $E8, $9D, $11, $52, $69
	dc.b	$34, $9A, $0E, $42, $0E, $47, $23, $90, $97, $A0, $49, $A7, $44, $1F, $A7, $97, $44, $94, $B5, $1A, $8D, $65, $29, $4C, $81, $0F, $15, $F1, $09, $3F, $10, $93
	dc.b	$F1, $5D, $6F, $29, $6E, $52, $BF, $5B, $FF, $62, $35, $DB, $C6, $F4, $FE, $0F, $2F, $A8, $25, $4D, $DC, $14, $CB, $74, $2D, $D0, $6A, $A4, $E3, $F6, $33, $40
	dc.b	$FF, $B1, $74, $09, $D0, $A5, $29, $4B, $A1, $6D, $AC, $CA, $52, $94, $A5, $29, $FE, $C6, $44, $3F, $83, $34, $BC, $95, $D2, $5D, $11, $53, $A2, $48, $94, $81
	dc.b	$29, $2F, $8C, $A7, $FC, $11, $FB, $1D, $C8, $14, $B6, $20, $5B, $6B, $32, $9F, $8C, $B5, $72, $1F, $C1, $41, $E3, $79, $02, $05, $29, $4C, $81, $02, $5D, $54
	dc.b	$B7, $25, $FE, $0A, $A0, $D5, $75, $49, $94, $89, $52, $65, $22, $54, $CB, $AF, $9F, $5C, $A5, $2E, $9A, $6F, $62, $BE, $D5, $C9, $A7, $66, $7C, $A7, $66, $75
	dc.b	$CD, $6D, $54, $28, $39, $E6, $5D, $E8, $33, $D1, $C8, $20, $CD, $01, $4C, $D3, $CE, $F3, $C8, $69, $C5, $C8, $B5, $D0, $D1, $EA, $50, $20, $8F, $AE, $95, $6E
	dc.b	$E8, $E6, $ED, $2B, $A5, $2B, $B7, $D6, $E9, $49, $AF, $FC, $C5, $CD, $29, $4A, $74, $97, $48, $DE, $D2, $3D, $ED, $9A, $FB, $6D, $A2, $FB, $2E, $6F, $32, $AD
	dc.b	$A0, $20, $21, $6C, $07, $45, $63, $10, $8B, $96, $62, $02, $04, $D0, $41, $E7, $ED, $9B, $1E, $49, $29, $3F, $E6, $36, $6C, $F0, $F6, $9B, $20, $C0, $B2, $D8
	dc.b	$47, $96, $5A, $5B, $6B, $BC, $F1, $E7, $DD, $AD, $A4, $A5, $29, $4A, $56, $E9, $69, $6F, $6D, $ED, $D3, $AD, $F6, $CC, $3D, $EC, $F2, $73, $5B, $68, $1E, $B8
	dc.b	$D2, $CC, $4E, $6C, $79, $37, $73, $9B, $29, $8C, $DF, $30, $EB, $9B, $98, $7E, $D9, $B9, $90, $31, $9B, $6A, $76, $19, $8E, $D7, $23, $66, $19, $F2, $A7, $57
	dc.b	$4E, $B5, $0C, $65, $4E, $BE, $08, $E2, $E2, $11, $45, $A1, $84, $60, $82, $DF, $A3, $48, $5F, $D9, $C3, $0E, $E0, $D1, $83, $D5, $21, $07, $7D, $23, $4C, $33
	dc.b	$F5, $BA, $9E, $47, $B9, $86, $BD, $AB, $BB, $D6, $4D, $B6, $8D, $B9, $74, $B5, $FF, $99, $CE, $FB, $81, $ED, $F9, $93, $2D, $EE, $39, $74, $BA, $52, $F6, $CF
	dc.b	$AE, $49, $84, $08, $1C, $5D, $4D, $92, $88, $11, $5C, $20, $D5, $2E, $0E, $18, $E7, $74, $CD, $5D, $30, $ED, $43, $D5, $15, $F2, $A6, $55, $A5, $4D, $F9, $A0
	dc.b	$20, $6E, $28, $70, $43, $B2, $5C, $70, $B0, $DD, $A0, $41, $51, $0A, $01, $02, $B8, $FA, $91, $D0, $AE, $30, $8B, $71, $D8, $5B, $24, $C9, $32, $7C, $93, $3D
	dc.b	$F8, $4F, $CC, $5E, $DC, $11, $DF, $D7, $88, $AC, $EB, $61, $A1, $4E, $E5, $3C, $AA, $B7, $66, $B5, $6A, $8C, $37, $76, $B5, $65, $29, $69, $D1, $37, $A3, $ED
	dc.b	$57, $DF, $55, $7D, $3F, $3B, $96, $78, $6E, $08, $65, $56, $17, $64, $32, $D1, $C5, $48, $31, $18, $6C, $C6, $55, $C3, $3C, $38, $27, $60, $54, $AB, $E1, $5C
	dc.b	$AD, $71, $CC, $A0, $8F, $32, $FC, $E9, $CD, $E2, $EA, $76, $58, $04, $74, $82, $43, $83, $CA, $D0, $A8, $70, $C1, $15, $D0, $ED, $01, $86, $6D, $14, $81, $DC
	dc.b	$58, $43, $2E, $94, $AB, $1B, $D3, $42, $89, $E8, $62, $CA, $FA, $76, $20, $CE, $A6, $56, $9E, $86, $56, $57, $E0, $1D, $A7, $A0, $2B, $B6, $3D, $EE, $05, $9F
	dc.b	$B6, $6C, $2E, $04, $81, $27, $71, $92, $0C, $4E, $E3, $1C, $EC, $41, $2F, $B8, $CB, $7B, $A0, $B7, $B4, $31, $E4, $79, $1B, $38, $7F, $D3, $B1, $59, $5D, $04
	dc.b	$52, $D7, $60, $38, $4F, $05, $C0, $71, $FA, $75, $E0, $3A, $90, $42, $E2, $70, $4E, $42, $AB, $8F, $DE, $56, $EC, $C5, $A1, $4F, $43, $B5, $43, $5A, $05, $68
	dc.b	$28, $96, $0D, $3B, $02, $A7, $50, $96, $31, $48, $04, $B7, $6B, $01, $C5, $85, $B3, $B0, $3C, $9F, $F7, $C7, $26, $93, $6F, $5E, $95, $36, $D8, $F1, $BB, $60
	dc.b	$35, $E6, $FD, $46, $7A, $35, $FA, $16, $47, $7E, $87, $83, $D8, $F4, $AE, $E6, $5B, $19, $4B, $7B, $88, $76, $CB, $C9, $F1, $C2, $D0, $5D, $07, $3F, $CE, $97
	dc.b	$6B, $3C, $D8, $AE, $15, $79, $B7, $AC, $69, $D5, $7B, $98, $D2, $A1, $94, $D4, $A8, $18, $69, $5F, $CC, $D0, $71, $41, $13, $35, $8E, $AF, $9E, $83, $48, $0C
	dc.b	$60, $C7, $0C, $1B, $05, $05, $49, $97, $00, $95, $EA, $D4, $CA, $03, $03, $FD, $3C, $0C, $56, $DF, $AB, $B9, $6D, $BD, $A5, $29, $4A, $52, $94, $A5, $29, $4B
	dc.b	$6A, $67, $BC, $06, $BA, $9F, $99, $B5, $6C, $C0, $C1, $5F, $70, $25, $35, $B8, $97, $2C, $32, $9F, $98, $83, $B4, $73, $DF, $B6, $41, $09, $60, $7E, $9F, $BE
	dc.b	$BC, $5B, $88, $FC, $FD, $AE, $E3, $77, $35, $A0, $E7, $59, $A0, $84, $89, $92, $30, $65, $87, $9B, $AB, $06, $19, $D7, $AE, $74, $E3, $35, $63, $C6, $97, $7E
	dc.b	$A1, $70, $1A, $F3, $2A, $EC, $CB, $5B, $DF, $8D, $9E, $B8, $DA, $B3, $AF, $43, $9F, $EE, $1C, $52, $ED, $CE, $47, $D0, $F7, $BA, $52, $90, $A5, $DF, $AA, $BA
	dc.b	$D4, $06, $4B, $E9, $4E, $C4, $A5, $23, $07, $79, $1C, $FF, $46, $42, $0D, $7F, $67, $00, $C1, $8F, $D1, $F1, $1A, $FE, $8E, $9C, $17, $A1, $88, $CF, $B0, $20
	dc.b	$61, $3B, $29, $3A, $08, $67, $E5, $50, $7E, $DF, $B8, $F4, $F1, $EC, $43, $F6, $62, $1E, $EA, $7E, $E7, $3D, $25, $2D, $3A, $77, $DC, $83, $EC, $94, $0F, $7A
	dc.b	$0A, $87, $9E, $7A, $67, $DE, $52, $94, $A5, $25, $6D, $9D, $AB, $B6, $2B, $95, $F6, $04, $D3, $61, $93, $42, $D8, $F2, $BD, $EB, $7A, $37, $06, $12, $75, $E0
	dc.b	$C1, $84, $DB, $03, $93, $AE, $34, $AA, $D6, $0A, $17, $9A, $FE, $8F, $62, $52, $05, $38, $1A, $CD, $07, $8D, $FF, $B7, $70, $5C, $CD, $08, $54, $FF, $4A, $7E
	dc.b	$9A, $41, $ED, $AC, $B7, $28, $1D, $AF, $31, $E9, $B1, $EE, $7B, $62, $35, $AF, $EA, $1E, $67, $BE, $1F, $77, $DF, $1B, $E1, $F7, $79, $74, $FF, $C8, $29, $16
	dc.b	$D7, $60, $16, $F8, $05, $7B, $8C, $02, $DF, $03, $5B, $CF, $C8, $52, $EF, $CF, $FB, $53, $B2, $F6, $20, $53, $35, $4B, $CC, $81, $1A, $98, $D4, $F7, $31, $04
	dc.b	$3B, $40, $35, $FD, $88, $D7, $CC, $63, $4B, $B3, $A7, $38, $06, $F6, $1A, $CF, $07, $6B, $CE, $A3, $23, $25, $EC, $AD, $56, $9A, $07, $BC, $D7, $46, $DD, $FB
	dc.b	$77, $6F, $6D, $FF, $51, $DD, $6D, $1D, $AA, $3B, $91, $92, $D7, $41, $AC, $72, $42, $B1, $E6, $10, $C2, $77, $1C, $82, $57, $19, $E9, $76, $7F, $BC, $97, $E6
	dc.b	$37, $EC, $CF, $67, $FC, $C4, $10, $C6, $7C, $16, $7D, $AB, $86, $FC, $FF, $78, $1C, $57, $4A, $DC, $13, $F4, $5C, $56, $9E, $D4, $CE, $E6, $EF, $D2, $DB, $BD
	dc.b	$6E, $7F, $CC, $BD, $81, $F1, $8D, $58, $60, $C7, $EB, $9B, $C8, $E9, $A5, $74, $E3, $02, $99, $14, $03, $2A, $20, $CE, $EF, $0B, $B4, $CC, $3F, $43, $B6, $D8
	dc.b	$15, $19, $F7, $A6, $05, $68, $5C, $08, $1E, $5A, $41, $0C, $64, $6B, $FA, $EE, $01, $D4, $76, $C4, $69, $EA, $E3, $F3, $A7, $3B, $BB, $15, $7F, $53, $1C, $26
	dc.b	$87, $E8, $C0, $D3, $B0, $40, $85, $0A, $97, $98, $34, $08, $11, $4C, $38, $40, $46, $0F, $4C, $56, $89, $4B, $94, $D5, $17, $C8, $C1, $8E, $70, $0C, $18, $42
	dc.b	$F2, $31, $D9, $26, $60, $C1, $4C, $D8, $60, $C8, $31, $86, $3E, $0E, $B7, $69, $75, $B1, $58, $04, $A5, $E8, $7C, $EA, $3B, $4D, $14, $A7, $C8, $D7, $B3, $A9
	dc.b	$7A, $14, $78, $99, $5E, $40, $AF, $23, $8B, $ED, $1B, $61, $4A, $78, $7D, $B0, $F3, $25, $7D, $BC, $BA, $3C, $AF, $FC, $C1, $F7, $EA, $EB, $D4, $76, $BD, $CF
	dc.b	$A9, $DF, $5E, $FD, $0D, $E6, $D8, $AC, $8D, $B6, $20, $7D, $FF, $31, $83, $E0, $FA, $FA, $E3, $F3, $2D, $7B, $4A, $52, $6D, $FA, $86, $BD, $97, $AC, $FA, $FE
	dc.b	$7F, $6C, $04, $65, $60, $49, $3E, $A7, $1C, $DE, $69, $B3, $61, $36, $30, $5B, $1E, $AB, $6E, $34, $AF, $6C, $90, $A6, $63, $08, $40, $87, $15, $C6, $4A, $83
	dc.b	$1C, $76, $52, $06, $E3, $90, $48, $18, $24, $D0, $47, $E7, $6F, $4A, $8B, $6A, $B9, $78, $3E, $BC, $84, $06, $F9, $18, $F4, $08, $5E, $69, $06, $8A, $81, $30
	dc.b	$49, $34, $14, $E4, $62, $BB, $64, $41, $27, $1F, $AD, $08, $AD, $58, $4D, $8D, $15, $26, $9D, $13, $A1, $2B, $6D, $E1, $B1, $1E, $86, $09, $D0, $AE, $30, $D9
	dc.b	$E9, $A8, $35, $E3, $1A, $10, $28, $28, $3C, $10, $30, $46, $58, $81, $5C, $69, $94, $0D, $07, $1F, $9D, $A6, $06, $04, $7E, $74, $F4, $EC, $D5, $D2, $A7, $1C
	dc.b	$06, $C3, $9D, $32, $8A, $A0, $4B, $CF, $15, $BC, $81, $E0, $F9, $07, $C1, $E0, $72, $A6, $A5, $3D, $78, $10, $4A, $85, $C6, $9B, $76, $BA, $B7, $71, $E1, $C3
	dc.b	$74, $60, $CA, $C1, $A7, $FA, $5D, $BA, $98, $6C, $2B, $03, $92, $C3, $EC, $D1, $5B, $B4, $CF, $CB, $D7, $1E, $D7, $B0, $EB, $FB, $EE, $AB, $D5, $5A, $7D, $55
	dc.b	$A7, $D7, $7E, $A1, $D7, $AA, $B8, $CD, $BF, $6C, $B8, $93, $CA, $5B, $BC, $A5, $2B, $DE, $C7, $BC, $3E, $CE, $75, $DF, $88, $DD, $CF, $A7, $1D, $1E, $4D, $FE
	dc.b	$37, $0D, $B3, $F4, $AF, $5D, $A3, $8E, $B7, $F6, $C0, $69, $91, $C6, $98, $65, $B1, $4F, $4C, $EE, $3C, $69, $1A, $E4, $E1, $84, $1F, $47, $FD, $3D, $FE, $7D
	dc.b	$83, $62, $05, $7D, $41, $C0, $C3, $AB, $69, $18, $69, $E8, $58, $6B, $DF, $2A, $7E, $61, $82, $29, $0A, $F5, $08, $08, $30, $83, $09, $91, $86, $17, $56, $D8
	dc.b	$9C, $59, $83, $67, $E1, $5D, $26, $D4, $08, $F3, $86, $A7, $9F, $5E, $2D, $E1, $91, $86, $BF, $90, $D7, $F3, $2E, $89, $EC, $81, $15, $3B, $A0, $45, $4C, $9B
	dc.b	$26, $CA, $99, $50, $41, $B6, $5A, $1D, $4C, $13, $B2, $C7, $21, $E0, $97, $95, $42, $DB, $9B, $C8, $78, $83, $45, $31, $1A, $B1, $3B, $3C, $16, $04, $71, $73
	dc.b	$F3, $81, $1C, $5C, $E0, $92, $FD, $55, $92, $7A, $84, $9B, $FE, $DC, $26, $5F, $B3, $4B, $8F, $F9, $75, $3C, $4D, $07, $B5, $6E, $B7, $16, $BB, $B9, $5E, $EB
	dc.b	$DD, $15, $15, $26, $85, $CD, $E8, $46, $0D, $3F, $48, $33, $B6, $76, $F5, $A9, $AB, $B2, $BD, $6E, $EE, $CA, $DD, $AA, $C1, $87, $5D, $4C, $34, $FD, $2B, $B1
	dc.b	$2B, $6D, $A8, $FD, $B1, $40, $F6, $FD, $6F, $00, $BD, $35, $83, $FD, $75, $78, $BA, $80, $E6, $F3, $35, $79, $6E, $FB, $BE, $EF, $BB, $CB, $F3, $14, $BB, $F5
	dc.b	$42, $C0, $E0, $6B, $32, $EC, $50, $B6, $10, $62, $97, $C6, $F6, $1E, $9B, $66, $33, $D8, $F3, $5B, $7E, $CE, $78, $E8, $D2, $94, $A5, $29, $2A, $55, $BA, $59
	dc.b	$1E, $71, $70, $D7, $6B, $8D, $37, $6B, $E0, $5D, $D5, $50, $C5, $D7, $C7, $6B, $B5, $56, $E6, $B9, $16, $CC, $1A, $AE, $DC, $C2, $38, $81, $1D, $86, $6A, $6B
	dc.b	$72, $59, $4A, $D7, $59, $DA, $E5, $FC, $CE, $AB, $76, $E5, $9F, $E8, $BF, $3A, $19, $D8, $C4, $15, $EC, $FE, $59, $27, $5B, $CC, $45, $B9, $11, $4E, $6D, $E1
	dc.b	$E9, $29, $9A, $D2, $28, $AF, $E1, $74, $FF, $3A, $13, $21, $44, $B5, $C6, $D3, $45, $B9, $96, $EE, $BB, $90, $8A, $2D, $0A, $E6, $3E, $91, $B5, $58, $53, $27
	dc.b	$AF, $E9, $7C, $08, $F7, $36, $52, $3B, $81, $DE, $42, $36, $3D, $CD, $5A, $F8, $3D, $D8, $B8, $CF, $4F, $D5, $87, $C0, $8D, $66, $C2, $01, $5A, $78, $32, $D9
	dc.b	$88, $5B, $6C, $E5, $69, $2F, $FC, $F6, $39, $4A, $59, $BF, $47, $DE, $D2, $CF, $FC, $79, $C8, $35, $FD, $43, $3E, $6E, $C7, $4B, $F1, $4B, $97, $3A, $E4, $93
	dc.b	$71, $96, $D5, $CB, $62, $CF, $8F, $D5, $7E, $60, $D7, $F4, $BC, $D9, $D9, $F6, $B6, $77, $79, $7A, $B0, $20, $43, $AE, $77, $EA, $1A, $64, $A5, $32, $BC, $8E
	dc.b	$EF, $08, $E2, $DC, $59, $6E, $A0, $85, $2B, $81, $75, $0C, $9E, $19, $92, $65, $EB, $A1, $58, $A0, $BA, $E5, $C6, $0F, $8C, $D4, $93, $2B, $64, $08, $12, $92
	dc.b	$F1, $8B, $5D, $48, $F0, $0C, $AD, $4B, $CC, $34, $11, $E5, $06, $20, $C4, $6A, $BA, $1F, $96, $7F, $A9, $6A, $36, $57, $EB, $32, $9E, $A0, $F3, $B1, $D2, $DE
	dc.b	$8A, $F5, $64, $FC, $ED, $BA, $CD, $9C, $31, $FA, $B7, $97, $87, $1E, $74, $67, $20, $5B, $17, $2B, $E2, $A9, $B5, $D5, $FC, $FD, $B3, $FC, $FB, $B2, $0F, $45
	dc.b	$EA, $AC, $8B, $83, $EE, $D3, $CB, $F3, $3A, $71, $EA, $F3, $EB, $E7, $5E, $99, $4B, $F9, $FF, $AC, $95, $ED, $29, $BC, $DE, $75, $FD, $2D, $F9, $57, $83, $DC
	dc.b	$EB, $7E, $99, $D2, $D3, $CE, $5D, $0A, $5D, $29, $29, $4B, $DB, $3F, $D6, $7E, $74, $72, $A4, $0B, $99, $95, $FA, $A9, $02, $04, $08, $10, $29, $90, $20, $93
	dc.b	$21, $AF, $4F, $D8, $CC, $86, $B2, $5B, $7E, $66, $CB, $F9, $88, $D4, $6A, $0A, $EF, $D5, $02, $BF, $C0, $9C, $E3, $D6, $08, $3F, $95, $4F, $F3, $EB, $E6, $D4
	dc.b	$6E, $6F, $20, $4D, $14, $CE, $96, $5B, $BF, $31, $F9, $91, $94, $EE, $A5, $C2, $01, $C1, $82, $04, $0B, $F4, $47, $54, $15, $C7, $1E, $D9, $2F, $E9, $53, $2B
	dc.b	$F5, $52, $5D, $57, $59, $F8, $EE, $5D, $0A, $5D, $0B, $74, $25, $F3, $69, $B8, $C8, $C7, $22, $26, $73, $C6, $BD, $E7, $C1, $2F, $2B, $E7, $99, $29, $02, $CA
	dc.b	$89, $50, $53, $24, $C6, $54, $6E, $48, $65, $1A, $31, $DF, $E9, $90, $87, $47, $38, $28, $07, $04, $23, $87, $D4, $C2, $46, $32, $3C, $9C, $65, $03, $15, $C9
	dc.b	$0B, $1F, $9D, $C2, $D6, $29, $E4, $4F, $67, $B4, $90, $11, $DF, $1D, $38, $52, $BF, $1D, $30, $43, $39, $5F, $5E, $FF, $CC, $09, $29, $4F, $F6, $3C, $AE, $BB
	dc.b	$EA, $28, $11, $7C, $6F, $21, $AD, $7C, $57, $BE, $B3, $2E, $E0, $A7, $FB, $15, $D5, $52, $7E, $21, $37, $F1, $DF, $C7, $24, $9F, $8E, $49, $3D, $77, $FD, $8B
	dc.b	$FE, $C5, $3B, $97, $9B, $84, $EE, $3C, $DD, $75, $4F, $D8, $A7, $F8, $5F, $55, $25, $F1, $5E, $46, $AA, $9E, $8D, $A8, $40, $7E, $97, $C7, $E8, $E6, $40, $FD
	dc.b	$27, $1F, $B1, $1C, $E4, $65, $04, $39, $1C, $B3, $F4, $E7, $74, $9F, $57, $58, $53, $83, $70, $6A, $E8, $63, $21, $CA, $B9, $64, $70, $69, $E6, $BD, $72, $4F
	dc.b	$34, $69, $F3, $DC, $AF, $4E, $E6, $10, $24, $D0, $73, $B7, $54, $9A, $0E, $B2, $BD, $06, $4C, $9B, $64, $71, $FC, $C5, $3D, $CE, $5B, $A4, $A0, $B6, $42, $CF
	dc.b	$72, $DF, $4C, $E5, $29, $4A, $5B, $67, $BD, $9E, $FB, $66, $C5, $7D, $B3, $AE, $92, $BF, $F5, $BA, $4E, $D7, $E7, $F9, $D6, $52, $08, $09, $F5, $99, $64, $77
	dc.b	$96, $55, $C5, $27, $5B, $37, $7F, $D6, $4A, $54, $E8, $F9, $CB, $74, $2B, $B7, $3D, $F3, $FC, $CC, $A5, $29, $4A, $FD, $25, $B5, $33, $7D, $A9, $9D, $25, $29
	dc.b	$7F, $32, $5A, $5D, $B9, $75, $9E, $AD, $47, $FD, $67, $E7, $6C, $E7, $29, $4A, $52, $FD, $2E, $DD, $CE, $EB, $FB, $39, $69, $F9, $DD, $26, $64, $A8, $2E, $CD
	dc.b	$26, $62, $10, $81, $36, $02, $10, $2C, $AA, $D9, $92, $E5, $83, $08, $A5, $36, $20, $59, $63, $A9, $36, $74, $CC, $3F, $19, $E1, $83, $C3, $DC, $81, $8C, $8D
	dc.b	$1E, $AC, $79, $C1, $1F, $59, $C3, $15, $B9, $2A, $1F, $5A, $17, $82, $C0, $87, $B5, $DF, $A3, $46, $1F, $9D, $C5, $53, $2E, $CA, $5C, $5E, $51, $53, $BF, $4A
	dc.b	$86, $BD, $81, $EF, $53, $E8, $D2, $D8, $ED, $3A, $5D, $4D, $A0, $3D, $F6, $10, $97, $FE, $62, $A9, $BB, $CA, $52, $4C, $F4, $FC, $EB, $39, $D9, $15, $8C, $32
	dc.b	$2E, $59, $88, $B5, $02, $68, $18, $A9, $9F, $38, $60, $F0, $E8, $12, $6C, $93, $C3, $6E, $78, $58, $A5, $A9, $88, $EC, $F6, $10, $71, $3F, $D5, $79, $59, $63
	dc.b	$F3, $35, $18, $71, $63, $2C, $EC, $C1, $81, $95, $B3, $75, $B8, $C8, $19, $37, $68, $10, $54, $EB, $97, $7C, $93, $0E, $72, $94, $A5, $26, $E8, $6D, $BB, $B5
	dc.b	$F6, $AE, $ED, $2D, $AD, $A0, $79, $BE, $44, $0D, $5B, $82, $19, $55, $6E, $C8, $65, $A3, $8D, $08, $31, $18, $AE, $4D, $E5, $A1, $73, $E4, $1B, $B2, $45, $F0
	dc.b	$2B, $80, $C1, $9D, $28, $18, $65, $6A, $E4, $6C, $1E, $2E, $A7, $61, $58, $04, $74, $86, $CC, $E0, $F2, $B4, $36, $71, $71, $2C, $0B, $1D, $11, $70, $19, $E6
	dc.b	$71, $D5, $20, $3E, $8E, $50, $19, $61, $16, $03, $E8, $87, $92, $33, $98, $BA, $D7, $E0, $98, $5B, $33, $6F, $CC, $2A, $5B, $74, $E9, $9C, $A5, $29, $74, $CF
	dc.b	$F5, $95, $B3, $9C, $4C, $B2, $C3, $5C, $E9, $38, $9A, $02, $0E, $B4, $C9, $C9, $69, $32, $FD, $3C, $EC, $4A, $F7, $99, $26, $AF, $CF, $1A, $5B, $33, $1D, $81
	dc.b	$76, $58, $16, $BB, $B2, $B4, $52, $C2, $EC, $F1, $D5, $0E, $96, $30, $61, $88, $7E, $63, $23, $76, $4A, $5A, $A9, $C1, $CE, $05, $46, $7D, $BC, $CC, $68, $5B
	dc.b	$9E, $55, $DE, $AD, $59, $DA, $0E, $A9, $65, $B2, $9E, $86, $AC, $96, $81, $56, $15, $4B, $06, $56, $C6, $4F, $91, $BF, $59, $74, $AF, $42, $E8, $9B, $E8, $5B
	dc.b	$E8, $7D, $0C, $67, $5B, $99, $CF, $8A, $38, $27, $60, $4E, $1F, $0A, $FA, $83, $99, $41, $5B, $36, $4A, $D0, $B2, $35, $A0, $BA, $30, $6B, $F9, $D2, $3D, $2A
	dc.b	$F3, $62, $C6, $6E, $99, $7E, $96, $95, $74, $3B, $40, $B5, $D9, $B4, $52, $01, $18, $B0, $86, $58, $B5, $3A, $86, $35, $89, $F6, $B4, $75, $7C, $F4, $B8, $40
	dc.b	$63, $07, $5C, $C7, $E6, $5E, $D4, $5A, $BD, $EF, $A7, $31, $7C, $24, $5A, $78, $83, $BA, $F2, $E8, $7A, $5B, $7E, $37, $BA, $8B, $EB, $ED, $79, $74, $82, $4D
	dc.b	$AC, $09, $F6, $A7, $05, $BB, $17, $4A, $74, $BB, $DA, $8C, $E7, $95, $14, $8D, $95, $15, $0D, $48, $20, $4A, $AB, $82, $68, $0E, $A8, $A5, $B1, $92, $9C, $CA
	dc.b	$78, $65, $C6, $9C, $3E, $1B, $37, $B1, $8A, $40, $A9, $8B, $B5, $80, $78, $B0, $B6, $76, $0D, $8B, $7E, $F5, $81, $DE, $E6, $B4, $1C, $EA, $0C, $20, $84, $80
	dc.b	$DF, $A4, $73, $7E, $CD, $29, $36, $E7, $D3, $1D, $0A, $5D, $2E, $6D, $A9, $D0, $E5, $D2, $E9, $4A, $52, $FC, $CD, $9B, $F6, $64, $23, $4E, $B7, $98, $D2, $A1
	dc.b	$88, $1A, $95, $01, $EF, $C1, $A9, $5F, $71, $82, $52, $5D, $66, $41, $B1, $6A, $69, $00, $BB, $CC, $B8, $BD, $F0, $75, $C9, $83, $29, $C3, $E1, $6A, $08, $19
	dc.b	$30, $C2, $92, $FE, $BA, $BE, $44, $08, $15, $7F, $5C, $57, $5A, $EF, $D4, $39, $74, $6E, $89, $D2, $29, $2D, $C8, $FA, $46, $76, $BE, $DE, $B6, $1E, $17, $6F
	dc.b	$05, $B1, $79, $EC, $5C, $DF, $9C, $76, $BC, $8E, $36, $20, $51, $3B, $0E, $4A, $D7, $58, $15, $DC, $58, $10, $8E, $CB, $FA, $47, $89, $A2, $A1, $1A, $97, $72
	dc.b	$80, $D9, $FE, $8B, $4C, $1D, $72, $D4, $79, $70, $4D, $0C, $7F, $A2, $5E, $2E, $B7, $E6, $6D, $76, $90, $F3, $EF, $56, $0C, $33, $FC, $E8, $76, $C5, $0A, $7F
	dc.b	$9F, $2D, $9F, $7C, $3E, $E7, $BE, $1B, $DB, $F5, $36, $71, $8A, $F4, $B6, $F5, $E8, $7D, $1E, $52, $96, $7F, $AA, $CF, $F3, $20, $CA, $66, $B6, $20, $65, $2D
	dc.b	$88, $15, $E6, $A4, $09, $48, $18, $32, $5A, $92, $F6, $FC, $CE, $9F, $C3, $1F, $B3, $DC, $87, $68, $06, $35, $EE, $8A, $77, $A6, $DC, $CC, $C7, $EC, $47, $EC
	dc.b	$C6, $A6, $0F, $4B, $A9, $EA, $7A, $9B, $CD, $91, $4E, $F4, $53, $9B, $84, $06, $EA, $48, $0C, $1A, $A2, $FE, $8D, $82, $04, $53, $5C, $F4, $CF, $14, $F2, $CE
	dc.b	$78, $42, $10, $AC, $60, $92, $03, $D4, $F9, $08, $B5, $D9, $B8, $30, $93, $AF, $07, $20, $73, $3D, $38, $D0, $F9, $68, $52, $52, $ED, $AA, $92, $BC, $CA, $F4
	dc.b	$04, $35, $1C, $8D, $67, $FA, $79, $95, $E9, $33, $7F, $D2, $C1, $D2, $E9, $1D, $F5, $53, $29, $B2, $99, $29, $6C, $43, $17, $EA, $1F, $7E, $2F, $BA, $C4, $3D
	dc.b	$7C, $17, $03, $5B, $DC, $69, $1B, $60, $EB, $28, $DA, $A7, $58, $9E, $0B, $02, $B7, $E8, $3B, $53, $F3, $3F, $9F, $3A, $54, $D4, $C9, $49, $4B, $B0, $45, $25
	dc.b	$82, $83, $29, $FE, $8C, $6B, $1C, $03, $11, $C0, $3C, $76, $04, $38, $D2, $BA, $17, $A7, $85, $7B, $7E, $B7, $9C, $0F, $D1, $D7, $5D, $A2, $FE, $C0, $8C, $97
	dc.b	$B6, $11, $AA, $D3, $30, $F7, $9A, $E8, $D7, $A0, $7E, $DD, $EB, $ED, $6D, $BF, $30, $6F, $7C, $1A, $57, $F4, $C4, $64, $BE, $C3, $58, $04, $B5, $8F, $35, $30
	dc.b	$9D, $C2, $10, $25, $71, $DA, $EC, $FF, $78, $31, $D0, $ED, $B6, $05, $46, $7D, $E9, $81, $5A, $17, $02, $07, $96, $90, $43, $19, $1A, $FE, $BB, $80, $75, $1D
	dc.b	$B1, $1A, $7A, $B8, $FC, $E9, $DF, $D8, $AB, $3D, $38, $4D, $0F, $D7, $44, $34, $06, $10, $21, $41, $84, $BC, $C1, $A0, $40, $83, $B0, $70, $80, $94, $F4, $C5
	dc.b	$72, $4A, $5C, $A6, $31, $3F, $23, $06, $39, $C0, $30, $7C, $97, $91, $83, $24, $99, $83, $1A, $A9, $B0, $83, $23, $63, $0D, $5D, $23, $16, $AF, $16, $FC, $F9
	dc.b	$20, $E7, $6E, $67, $1B, $14, $6B, $C8, $2D, $C8, $19, $71, $8D, $41, $96, $8A, $71, $ED, $53, $52, $18, $0D, $FA, $65, $C3, $6C, $52, $7D, $EE, $DF, $1D, $1E
	dc.b	$52, $5F, $D3, $59, $F6, $3D, $9F, $07, $83, $BF, $1C, $1E, $CE, $0F, $72, $07, $B6, $34, $DD, $C7, $F0, $FB, $E8, $7B, $7E, $96, $F6, $94, $DA, $57, $B2, $9C
	dc.b	$FA, $86, $BD, $95, $8E, $7D, $7F, $3F, $B6, $39, $65, $61, $E2, $BD, $7B, $02, $BC, $C1, $24, $DB, $04, $97, $98, $2D, $8F, $55, $BB, $8D, $2B, $DA, $E4, $BC
	dc.b	$C1, $A1, $02, $1C, $57, $19, $2A, $0C, $71, $D9, $48, $1B, $8E, $41, $20, $6A, $D2, $68, $38, $16, $9A, $4E, $9A, $84, $3F, $0D, $35, $E4, $20, $37, $C8, $C7
	dc.b	$A0, $42, $F3, $48, $34, $54, $09, $82, $41, $8A, $A0, $A7, $20, $B7, $CA, $02, $4E, $2B, $4E, $1D, $BC, $0F, $00, $D7, $8C, $19, $02, $82, $83, $E0, $87, $91
	dc.b	$19, $62, $05, $71, $A6, $44, $34, $10, $75, $A5, $7C, $86, $9F, $9D, $3D, $3B, $31, $E9, $53, $8B, $B2, $6C, $39, $D3, $CE, $88, $13, $6C, $56, $F2, $07, $83
	dc.b	$E4, $1F, $07, $81, $CA, $9A, $94, $F5, $F2, $82, $54, $2F, $2E, $8D, $5B, $B8, $F0, $D2, $47, $7B, $5E, $CA, $C1, $B6, $30, $D8, $56, $07, $25, $87, $D9, $B4
	dc.b	$36, $0C, $A6, $BD, $77, $69, $B8, $EA, $18, $3A, $F5, $DD, $A6, $DD, $0E, $6C, $A7, $7F, $E9, $99, $68, $FB, $FE, $7F, $76, $2E, $98, $97, $47, $94, $9B, $FC
	dc.b	$75, $0D, $B1, $37, $4E, $03, $5E, $43, $1B, $60, $C6, $3A, $CC, $FD, $30, $3B, $82, $9E, $95, $E1, $B1, $A4, $6A, $64, $18, $41, $F4, $74, $ED, $7D, $32, $F2
	dc.b	$0D, $88, $15, $EA, $0E, $33, $67, $56, $F6, $DB, $4E, $1B, $62, $A7, $EB, $D8, $72, $08, $53, $A9, $D3, $26, $C9, $84, $5C, $D9, $E2, $B7, $34, $59, $95, $C5
	dc.b	$3F, $3E, $C1, $81, $BC, $1C, $DA, $97, $15, $ED, $56, $F4, $EB, $F9, $F8, $A6, $46, $1A, $FE, $43, $5F, $CC, $BF, $3F, $B2, $76, $40, $8A, $9D, $D0, $22, $A6
	dc.b	$4D, $93, $65, $4C, $A8, $20, $DB, $2D, $0E, $A6, $09, $D9, $63, $90, $F0, $4B, $CA, $A1, $6D, $CD, $E4, $3C, $41, $A2, $98, $8D, $5B, $BB, $14, $1E, $03, $71
	dc.b	$71, $23, $54, $47, $17, $38, $2C, $AF, $D5, $59, $27, $A8, $49, $B7, $9D, $C8, $13, $2F, $D7, $1A, $5C, $79, $FE, $D6, $A7, $8E, $72, $46, $3D, $2B, $8E, $33
	dc.b	$B6, $97, $39, $5E, $EB, $DD, $15, $15, $26, $85, $E7, $7A, $17, $E7, $4F, $2F, $0B, $AB, $DF, $D7, $AB, $B2, $BB, $5F, $76, $6F, $D4, $75, $56, $9F, $51, $18
	dc.b	$1D, $66, $53, $65, $21, $0D, $3C, $FD, $0F, $4F, $D5, $16, $84, $BD, $81, $3E, $7C, $19, $18, $8E, $A2, $EC, $FF, $33, $40, $6F, $BB, $EF, $83, $DC, $BA, $5D
	dc.b	$29, $4B, $F3, $14, $BB, $F5, $53, $38, $1A, $CC, $BB, $14, $0B, $10, $83, $14, $52, $E9, $6C, $7E, $A6, $57, $BD, $FF, $B3, $AA, $74, $A2, $3C, $DB, $F3, $3A
	dc.b	$EE, $69, $BB, $5F, $0B, $56, $54, $FD, $18, $25, $82, $F4, $B1, $33, $83, $F2, $3E, $AE, $C7, $F9, $DD, $99, $FB, $64, $9D, $6F, $31, $16, $E4, $45, $39, $B7
	dc.b	$87, $A4, $A6, $6B, $48, $A2, $E7, $4A, $DA, $75, $B9, $58, $51, $2C, $0D, $A6, $8B, $73, $2D, $DD, $77, $21, $14, $5A, $15, $CC, $7D, $23, $6A, $B2, $56, $EC
	dc.b	$FB, $CF, $43, $D6, $F7, $31, $75, $EC, $77, $6C, $C5, $D3, $39, $4A, $7F, $B3, $1F, $A3, $BC, $E5, $23, $96, $6F, $D2, $BB, $DA, $43, $FC, $79, $C8, $35, $FD
	dc.b	$43, $3E, $6E, $C7, $47, $CF, $19, $62, $97, $0C, $1A, $A5, $FC, $EC, $9D, $3F, $BF, $E1, $7E, $6C, $30, $ED, $DF, $2F, $5C, $AD, $9F, $E6, $41, $02, $05, $79
	dc.b	$48, $A6, $5B, $96, $C7, $77, $84, $71, $6E, $2C, $B7, $50, $40, $C1, $5C, $0B, $A8, $CB, $4F, $0C, $C9, $32, $2C, $B4, $2B, $14, $10, $2C, $B8, $C1, $F1, $9A
	dc.b	$92, $65, $6C, $A6, $4B, $A8, $F2, $B5, $D4, $8C, $E8, $19, $5A, $97, $98, $68, $23, $CA, $0C, $41, $88, $D5, $74, $3F, $2C, $FF, $52, $D4, $6C, $AF, $D7, $A6
	dc.b	$A2, $D4, $BB, $16, $A7, $E7, $DD, $90, $7A, $2E, $74, $60, $C8, $B9, $36, $1D, $B6, $CA, $EE, $3F, $57, $7B, $7E, $92, $52, $FE, $7F, $EB, $25, $7B, $4A, $6F
	dc.b	$37, $9D, $CD, $9B, $6D, $52, $3D, $CE, $B7, $E9, $9D, $2D, $3B, $74, $8E, $94, $94, $A5, $29, $7B, $67, $FA, $CF, $CE, $8E, $6F, $2E, $65, $AA, $90, $20, $40
	dc.b	$81, $02, $99, $02, $09, $32, $1A, $F4, $FD, $8C, $C8, $6B, $2C, $ED, $48, $FC, $C2, $98, $3A, $2E, $AB, $FB, $A0, $40, $97, $C0, $9C, $E3, $D6, $08, $3F, $95
	dc.b	$4F, $F3, $EB, $E6, $D4, $CB, $9B, $F5, $0D, $14, $CE, $96, $A1, $5D, $F9, $8F, $CC, $8C, $4E, $EA, $5C, $20, $1C, $18, $20, $40, $BF, $45, $D9, $05, $71, $C7
	dc.b	$B6, $15, $BC, $D1, $B2, $D8, $AF, $25, $2D, $CB, $A1, $74, $29, $16, $E5, $B2, $02, $DD, $25, $34, $90, $D7, $95, $4E, $9A, $8A, $04, $5F, $1B, $C8, $6B, $5F
	dc.b	$15, $EF, $AC, $CB, $B8, $2D, $C9, $7F, $83, $3F, $19, $78, $EF, $E3, $92, $4F, $C7, $24, $9E, $BB, $FE, $C5, $FF, $62, $AE, $59, $52, $6E, $43, $2A, $12, $A3
	dc.b	$A6, $A0, $93, $FC, $2F, $AA, $92, $F8, $A9, $0E, $77, $49, $FE, $95, $61, $4E, $26, $6A, $E8, $7E, $7B, $39, $E4, $6D, $92, $79, $AF, $5C, $93, $CD, $1A, $7C
	dc.b	$F7, $2B, $D3, $B9, $84, $09, $34, $1C, $EC, $C1, $26, $81, $A5, $B2, $0C, $99, $36, $B5, $D9, $FF, $32, $52, $97, $4B, $6D, $6C, $F2, $BE, $D9, $26, $D9, $02
	dc.b	$CA, $FD, $43, $2F, $E7, $76, $CF, $62, $CD, $01, $3E, $A1, $32, $6C, $8F, $6C, $57, $14, $5C, $B0, $CE, $C2, $E1, $85, $4C, $A1, $EE, $A3, $9E, $49, $91, $B0
	dc.b	$A7, $47, $CE, $5B, $A1, $5D, $B9, $F4, $31, $74, $D1, $4B, $89, $FA, $D2, $CF, $29, $49, $74, $DF, $49, $6D, $4C, $DF, $78, $09, $7D, $2E, $A6, $72, $97, $EF
	dc.b	$25, $A7, $EA, $6F, $26, $F6, $5D, $5A, $9D, $C1, $0B, $61, $83, $69, $F9, $D6, $7E, $CF, $29, $4A, $5D, $77, $73, $BB, $64, $1A, $52, $FC, $9D, $A9, $29, $4A
	dc.b	$52, $94, $ED, $D1, $96, $EF, $DE, $32, $B0, $21, $96, $17, $C7, $2C, $18, $CF, $67, $08, $0B, $2A, $86, $04, $32, $06, $D1, $50, $C3, $30, $86, $13, $C8, $37
	dc.b	$6B, $5C, $D0, $99, $1A, $18, $4A, $41, $51, $19, $08, $43, $50, $92, $91, $43, $68, $7D, $A1, $81, $D8, $7E, $8D, $01, $B5, $C5, $43, $46, $41, $63, $A2, $2B
	dc.b	$5D, $80, $5D, $9D, $B4, $A8, $69, $A3, $03, $BC, $85, $4E, $F7, $56, $95, $ED, $6D, $F0, $96, $DA, $DA, $2D, $AE, $F6, $9D, $84, $25, $FF, $98, $AA, $6E, $E1
	dc.b	$3A, $24, $B7, $4E, $99, $A6, $95, $B7, $E9, $B2, $61, $95, $44, $5B, $C1, $01, $B1, $53, $38, $48, $57, $87, $B0, $4E, $15, $92, $67, $49, $DC, $A4, $74, $10
	dc.b	$6B, $C9, $F5, $8F, $CC, $51, $8D, $CD, $FC, $3C, $8A, $7F, $99, $A8, $C3, $A9, $96, $76, $60, $C0, $CA, $D9, $BC, $CC, $81, $93, $1B, $40, $82, $A7, $53, $D6
	dc.b	$0A, $85, $51, $CF, $7C, $93, $0F, $29, $4A, $52, $6E, $9A, $57, $7B, $AB, $B5, $76, $B6, $9B, $3E, $45, $B7, $04, $32, $BF, $21, $96, $93, $A8, $62, $35, $A0
	dc.b	$CA, $B8, $65, $20, $4E, $C2, $B6, $AF, $A8, $74, $7C, $06, $0C, $E8, $61, $86, $56, $AE, $55, $60, $F1, $F9, $93, $71, $58, $05, $D8, $36, $67, $04, $84, $F0
	dc.b	$E9, $DB, $20, $54, $CA, $A9, $07, $14, $AE, $55, $46, $42, $A7, $54, $80, $FA, $19, $40, $65, $83, $58, $0F, $A2, $46, $48, $CE, $62, $E8, $BF, $05, $54, $0E
	dc.b	$DC, $46, $B3, $AB, $A9, $5D, $66, $CF, $4A, $5D, $67, $3D, $F2, $95, $A5, $2D, $ED, $29, $6F, $77, $4B, $A5, $29, $4A, $52, $FE, $65, $BF, $4C, $93, $89, $A0
	dc.b	$20, $E1, $A3, $92, $D8, $BF, $6F, $7F, $E9, $DD, $6D, $13, $2A, $4C, $92, $FC, $BF, $59, $9D, $A1, $A0, $5A, $EE, $CA, $D1, $4B, $0B, $B3, $56, $43, $A5, $8E
	dc.b	$CA, $C4, $3F, $50, $AC, $94, $B5, $5B, $68, $15, $E0, $3B, $22, $DA, $EE, $19, $CF, $23, $73, $CB, $A5, $6D, $B4, $1C, $B1, $B2, $5A, $1E, $F4, $B7, $42, $A0
	dc.b	$B4, $F2, $A9, $D7, $1D, $98, $16, $C4, $10, $23, $04, $A0, $72, $E2, $7F, $99, $09, $DC, $21, $1C, $0C, $55, $83, $02, $80, $7A, $30, $32, $04, $0F, $86, $D3
	dc.b	$CB, $2D, $12, $82, $0A, $E0, $63, $A9, $0A, $58, $55, $81, $03, $F4, $99, $7E, $64, $75, $7C, $C7, $E6, $20, $31, $86, $EC, $C1, $B0, $43, $BC, $CB, $80, $F4
	dc.b	$E2, $DC, $13, $AC, $24, $15, $83, $63, $D2, $F3, $21, $AC, $F4, $3D, $16, $CA, $63, $8D, $A0, $A3, $72, $ED, $69, $DA, $E2, $1F, $BC, $58, $2D, $EC, $10, $25
	dc.b	$FE, $97, $73, $3B, $1E, $8E, $5B, $7E, $8E, $FD, $4C, $A7, $60, $46, $3F, $47, $9D, $B1, $57, $E2, $F2, $E8, $E2, $CD, $B2, $5A, $45, $9E, $D4, $91, $1D, $B6
	dc.b	$C6, $9C, $20, $ED, $95, $DA, $C3, $5A, $76, $CE, $CD, $3F, $DE, $B0, $6B, $DC, $EF, $E7, $5C, $EA, $10, $42, $44, $C9, $18, $36, $6B, $A6, $7F, $AA, $32, $FC
	dc.b	$C9, $03, $53, $94, $CC, $19, $6D, $DA, $F3, $23, $E8, $47, $20, $62, $DA, $7E, $63, $88, $38, $2C, $66, $CA, $70, $35, $3A, $FA, $36, $C7, $0F, $3D, $09, $4E
	dc.b	$F2, $04, $BA, $82, $F4, $20, $4A, $40, $8F, $A9, $C5, $BF, $56, $E8, $0A, $F7, $58, $BD, $01, $45, $A7, $05, $25, $89, $F8, $EC, $7C, $C0, $75, $CF, $4C, $8C
	dc.b	$62, $DA, $4F, $5F, $39, $C0, $2F, $D3, $8A, $02, $06, $46, $22, $70, $E6, $2D, $04, $1D, $15, $D4, $90, $10, $C4, $2A, $02, $D0, $CA, $EA, $F1, $6A, $A1, $1E
	dc.b	$73, $62, $85, $35, $7F, $D1, $2B, $67, $74, $2E, $14, $DC, $BD, $05, $70, $0C, $18, $C0, $D4, $10, $3F, $D1, $2D, $DF, $98, $BB, $83, $8B, $83, $0C, $EA, $30
	dc.b	$1B, $14, $25, $71, $C1, $4A, $5B, $98, $D4, $63, $6D, $5D, $69, $74, $76, $CF, $F3, $2A, $4A, $47, $3D, $65, $22, $53, $5A, $48, $12, $9C, $CA, $FF, $D4, $F6
	dc.b	$56, $1F, $B3, $57, $9F, $88, $20, $60, $82, $10, $30, $73, $E4, $EF, $FD, $3A, $98, $FD, $88, $FD, $98, $D5, $9F, $F4, $7A, $7A, $A0, $71, $A5, $FC, $91, $87
	dc.b	$BC, $8E, $7F, $A7, $73, $DF, $20, $61, $D0, $26, $3F, $46, $12, $F3, $18, $F6, $CF, $BF, $5B, $4A, $52, $94, $A4, $FD, $1E, $52, $94, $A5, $2E, $9F, $98, $DF
	dc.b	$F3, $12, $D9, $FA, $1E, $EF, $BB, $F1, $5D, $CF, $67, $E3, $67, $1C, $18, $7A, $67, $4F, $CE, $FA, $68, $48, $BE, $30, $39, $1D, $D0, $10, $E7, $77, $5E, $70
	dc.b	$A4, $8A, $82, $0A, $68, $B8, $54, $9F, $E7, $48, $7E, $9D, $87, $2B, $A9, $FE, $9C, $6A, $A9, $79, $5F, $AF, $4D, $66, $81, $F6, $E4, $24, $CC, $BF, $4B, $1E
	dc.b	$17, $5F, $C4, $CE, $6F, $33, $2D, $CC, $87, $1B, $93, $ED, $AC, $B6, $BA, $D7, $53, $D7, $C2, $7A, $6B, $B3, $E9, $1B, $9D, $65, $1B, $54, $EB, $75, $F5, $C6
	dc.b	$ED, $83, $6F, $DC, $D2, $BE, $1F, $A3, $67, $E5, $C1, $8F, $D3, $10, $30, $73, $FD, $1A, $FE, $CC, $45, $FC, $7B, $62, $9F, $9F, $A2, $BB, $0E, $A3, $A8, $FC
	dc.b	$C6, $6D, $DD, $AE, $5C, $0E, $CA, $58, $DC, $C3, $0E, $CB, $C3, $AF, $6C, $17, $5B, $E1, $03, $4C, $CA, $42, $E6, $3E, $F5, $3D, $1F, $8D, $AC, $0E, $82, $C2
	dc.b	$0C, $13, $D3, $53, $20, $4E, $3C, $62, $6E, $71, $E6, $E6, $41, $3B, $EF, $97, $02, $97, $67, $ED, $66, $D2, $D2, $FD, $45, $FD, $AB, $8B, $3F, $E6, $23, $03
	dc.b	$19, $F0, $59, $9E, $95, $C3, $7E, $7F, $BC, $0E, $2B, $A5, $6E, $09, $FA, $2E, $2B, $4F, $6A, $67, $73, $3E, $37, $B5, $FF, $A8, $C5, $6E, $7B, $8B, $0A, $7C
	dc.b	$63, $56, $A9, $AF, $EB, $98, $EB, $8A, $69, $5D, $38, $C0, $F3, $28, $06, $5E, $60, $EE, $F0, $BB, $4B, $0C, $5B, $73, $16, $16, $7B, $60, $54, $B3, $C0, $8C
	dc.b	$0A, $99, $70, $20, $79, $7B, $70, $31, $91, $F1, $3C, $70, $0C, $71, $DB, $11, $A6, $77, $0E, $03, $54, $5A, $E3, $D2, $79, $E4, $C3, $83, $76, $34, $0E, $73
	dc.b	$32, $9F, $0A, $84, $E1, $CC, $37, $24, $A4, $E6, $1F, $90, $8C, $2B, $A3, $A2, $D2, $EC, $08, $7B, $F0, $2A, $1F, $F4, $FE, $47, $A2, $A0, $F2, $ED, $0A, $4B
	dc.b	$DB, $15, $42, $0C, $19, $7F, $3B, $7B, $76, $14, $E2, $96, $BB, $8D, $38, $92, $A1, $03, $9A, $6E, $80, $81, $A9, $6F, $C6, $35, $3D, $38, $D0, $3F, $1A, $71
	dc.b	$FA, $35, $AE, $1F, $AF, $75, $C7, $47, $96, $F6, $94, $A5, $2B, $DE, $CF, $B7, $1D, $0F, $07, $B1, $F1, $BD, $D2, $ED, $D3, $8D, $FF, $E7, $4B, $A5, $29, $34
	dc.b	$AF, $65, $39, $F5, $0D, $7B, $2B, $3C, $FA, $FE, $7F, $6C, $73, $36, $1E, $2B, $D4, $C1, $95, $FD, $A1, $26, $D8, $24, $99, $E2, $37, $82, $45, $A5, $DC, $39
	dc.b	$65, $44, $37, $53, $AE, $0C, $83, $A7, $15, $BC, $86, $07, $64, $99, $E4, $11, $49, $03, $56, $9C, $CF, $81, $6E, $94, $EE, $10, $FC, $34, $D7, $90, $80, $DF
	dc.b	$25, $F4, $08, $59, $1A, $41, $A2, $A6, $49, $82, $41, $8A, $A0, $A7, $E9, $CB, $68, $C4, $04, $9B, $0E, $2A, $12, $78, $84, $DD, $15, $26, $9D, $13, $A1, $2B
	dc.b	$6C, $D3, $25, $2D, $1C, $D0, $9D, $0A, $E3, $10, $C7, $A8, $39, $91, $90, $28, $28, $3E, $08, $79, $11, $96, $20, $57, $1A, $64, $43, $44, $83, $AD, $2B, $E4
	dc.b	$34, $FC, $E9, $E9, $DA, $0F, $4A, $9C, $5D, $93, $61, $CE, $9E, $7F, $99, $AA, $04, $57, $18, $54, $04, $C7, $83, $E4, $1F, $06, $BC, $A9, $8E, $0A, $7A, $E3
	dc.b	$88, $25, $42, $C6, $9B, $76, $BA, $DA, $71, $E1, $C3, $74, $6B, $DB, $7E, $A1, $AF, $63, $0D, $8B, $CF, $6E, $B3, $87, $D9, $B4, $3E, $AA, $E6, $BD, $77, $65
	dc.b	$75, $EA, $1A, $FE, $AA, $F3, $69, $2B, $DE, $DD, $3F, $4D, $7D, $3A, $1F, $4B, $A5, $29, $4A, $57, $7F, $CE, $8D, $B7, $69, $06, $BC, $8F, $CB, $A8, $6B, $1A
	dc.b	$E0, $32, $FE, $88, $7E, $B8, $58, $10, $81, $06, $FA, $16, $4F, $91, $06, $D0, $82, $64, $61, $AF, $F2, $1A, $12, $50, $C7, $58, $19, $0A, $B0, $C4, $16, $6C
	dc.b	$F3, $3D, $36, $8E, $1B, $62, $AF, $E7, $EC, $C1, $2A, $68, $2B, $D4, $C6, $2B, $93, $08, $BB, $A8, $AD, $CD, $16, $9B, $DD, $4F, $CF, $AB, $2B, $7A, $4D, $86
	dc.b	$80, $E6, $C0, $B1, $9F, $5F, $D7, $DB, $16, $0D, $D1, $AF, $49, $27, $E7, $F7, $EC, $81, $15, $3D, $0F, $23, $F3, $1E, $BF, $AE, $5A, $E7, $6F, $D6, $C1, $D4
	dc.b	$C6, $B0, $B0, $10, $3C, $14, $D1, $50, $A6, $43, $95, $39, $F8, $82, $4F, $11, $04, $19, $3C, $84, $16, $03, $3A, $F3, $51, $1C, $5C, $E0, $B2, $69, $EA, $BC
	dc.b	$CF, $50, $93, $6F, $3B, $95, $32, $FD, $71, $A5, $C7, $9F, $ED, $6A, $78, $E7, $24, $63, $D2, $BF, $9F, $CF, $8A, $DC, $F3, $4B, $FF, $4F, $B2, $29, $AF, $99
	dc.b	$F9, $E3, $F7, $A3, $C8, $18, $EF, $9F, $E9, $5D, $95, $EB, $94, $EE, $EF, $5C, $87, $53, $AB, $06, $1D, $75, $31, $D5, $7D, $2A, $AC, $A4, $B9, $B3, $AD, $60
	dc.b	$86, $17, $B7, $E7, $F5, $AE, $61, $D9, $4C, $AC, $3A, $BD, $D4, $BA, $6F, $2D, $DE, $52, $94, $A4, $3F, $31, $77, $EA, $96, $DA, $8D, $66, $50, $65, $5D, $8F
	dc.b	$46, $9D, $BD, $9B, $6E, $B2, $92, $FE, $CC, $73, $BD, $03, $ED, $76, $B7, $B0, $34, $DD, $BA, $55, $A7, $58, $30, $53, $B7, $A5, $8A, $7F, $C5, $9F, $2C, $B5
	dc.b	$76, $83, $84, $71, $13, $31, $9A, $9A, $92, $59, $4A, $C0, $9D, $AE, $5B, $97, $34, $17, $4F, $2A, $26, $55, $8C, $A2, $EA, $CD, $96, $0B, $25, $60, $FE, $41
	dc.b	$1A, $C8, $B1, $70, $8B, $6D, $C8, $A5, $44, $6F, $17, $C0, $F0, $8B, $97, $C1, $2C, $0D, $2B, $72, $B0, $A0, $B0, $36, $9A, $2D, $CC, $B7, $64, $DB, $DC, $22
	dc.b	$8B, $42, $0C, $7D, $22, $FB, $55, $85, $3B, $FE, $77, $AF, $87, $6D, $CD, $94, $8E, $E0, $77, $90, $8D, $8F, $73, $06, $D7, $C1, $A0, $89, $B2, $0A, $63, $3E
	dc.b	$D3, $D0, $CB, $67, $3B, $B6, $63, $DD, $8B, $A6, $72, $94, $FF, $E7, $B3, $CB, $A7, $5C, $F7, $D3, $A5, $25, $21, $FB, $3E, $AF, $7B, $9D, $71, $97, $E9, $8F
	dc.b	$1E, $65, $FA, $DC, $65, $B1, $E4, $93, $EC, $A8, $A4, $39, $D9, $3A, $65, $FA, $9F, $CF, $F8, $0F, $CC, $D7, $36, $18, $C9, $7C, $FD, $5B, $59, $94, $CA, $F2
	dc.b	$91, $4C, $B7, $2D, $8E, $EF, $08, $E2, $9C, $58, $BF, $33, $49, $D3, $47, $F0, $CA, $17, $D3, $40, $43, $22, $75, $B0, $A9, $02, $78, $C1, $8C, $D4, $93, $2B
	dc.b	$65, $32, $5D, $47, $95, $AE, $A5, $B3, $A0, $63, $A3, $46, $EC, $A7, $94, $1D, $20, $CA, $01, $7E, $B0, $FC, $A9, $77, $E9, $68, $D9, $5F, $AF, $4D, $41, $D2
	dc.b	$C7, $4B, $7E, $7E, $C1, $EA, $C9, $3E, $B3, $67, $0C, $7E, $AD, $E5, $E1, $C7, $9D, $19, $C8, $15, $FA, $F2, $BA, $CD, $15, $BC, $EE, $AD, $B8, $A6, $9E, $AE
	dc.b	$CA, $D3, $CE, $8C, $A8, $1F, $26, $C7, $EE, $78, $5C, $9C, $B9, $2B, $D0, $12, $6C, $4B, $97, $4C, $FF, $7F, $FA, $C9, $07, $56, $9E, $75, $96, $61, $E7, $96
	dc.b	$03, $6D, $52, $3D, $CE, $B7, $E9, $9D, $2D, $3A, $74, $A4, $A5, $29, $4A, $5E, $D9, $FE, $B3, $F3, $A3, $9B, $CB, $9D, $77, $29, $90, $29, $90, $20, $5B, $10
	dc.b	$45, $25, $D7, $A7, $F0, $54, $86, $BE, $B4, $8F, $CC, $4C, $F7, $31, $70, $F0, $D5, $7F, $54, $A4, $BA, $8A, $13, $FE, $F6, $08, $3C, $F1, $F9, $F5, $F3, $6A
	dc.b	$65, $CD, $FA, $8D, $22, $99, $D9, $48, $67, $6B, $B3, $B5, $04, $15, $D4, $B8, $68, $08, $18, $20, $40, $BF, $45, $D9, $05, $71, $C7, $B6, $15, $BC, $D1, $B2
	dc.b	$D8, $AF, $25, $2D, $CB, $A1, $74, $29, $16, $E4, $AE, $8A, $84, $E0, $83, $4E, $09, $04, $72, $30, $A8, $53, $E3, $C5, $E7, $E7, $98, $E5, $4B, $2A, $95, $41
	dc.b	$4F, $9C, $02, $99, $21, $BD, $1B, $92, $08, $34, $63, $BF, $D3, $21, $0E, $8E, $70, $50, $0E, $08, $47, $0F, $A9, $84, $8C, $64, $79, $38, $A6, $83, $15, $C9
	dc.b	$0B, $F5, $B8, $5A, $C2, $E0, $9E, $CF, $69, $40, $23, $BF, $8E, $98, $52, $BF, $12, $21, $9D, $FA, $74, $2E, $FF, $CC, $09, $29, $A5, $E9, $7E, $A9, $34, $5A
	dc.b	$5F, $AC, $D1, $7C, $6F, $21, $AD, $7C, $57, $BE, $B3, $2E, $E0, $B7, $2D, $CB, $72, $E9, $E3, $BF, $8E, $49, $3F, $1C, $92, $7A, $EF, $FB, $17, $FD, $8A, $B9
	dc.b	$65, $49, $B9, $0C, $A8, $4A, $8E, $9E, $21, $3F, $82, $AF, $AA, $92, $F8, $AB, $20, $D5, $50, $E1, $B5, $09, $DB, $D2, $F2, $FD, $1C, $CA, $07, $A7, $22, $0F
	dc.b	$C7, $91, $91, $94, $15, $FC, $B3, $F4, $E7, $74, $54, $EB, $38, $08, $70, $CA, $6A, $E0, $F2, $7B, $D1, $CD, $CD, $B2, $4F, $35, $EB, $92, $79, $C3, $4F, $97
	dc.b	$ED, $7A, $77, $20, $81, $26, $83, $99, $A0, $7E, $76, $74, $95, $E8, $32, $E7, $63, $11, $FC, $C5, $3E, $85, $29, $6C, $85, $D0, $B3, $DD, $37, $00
Race_finish_tiles_2:
	dc.b	$80, $54, $80, $03, $00, $15, $0E, $25, $12, $35, $17, $46, $36, $55, $11, $65, $16, $74, $06, $81, $04, $02, $16, $3A, $82, $04, $05, $18, $F6, $83, $04, $03
	dc.b	$16, $3B, $27, $7A, $84, $06, $38, $85, $05, $18, $86, $05, $15, $87, $05, $10, $18, $F7, $88, $05, $14, $89, $05, $1A, $8A, $06, $39, $8B, $05, $19, $8C, $06
	dc.b	$37, $8D, $05, $13, $8E, $05, $0F, $17, $78, $8F, $04, $04, $17, $79, $FF, $8E, $F9, $DB, $31, $D7, $B9, $4B, $4B, $02, $37, $65, $60, $0C, $86, $7F, $4E, $65
	dc.b	$41, $08, $E7, $F6, $E4, $90, $94, $02, $A0, $85, $E0, $A9, $BD, $E1, $53, $97, $B8, $83, $95, $D0, $68, $6D, $01, $09, $2C, $23, $9F, $CE, $42, $D9, $6C, $B0
	dc.b	$28, $E5, $8A, $D9, $6C, $D9, $75, $12, $D4, $68, $CC, $CC, $CD, $6A, $35, $22, $A9, $48, $F9, $86, $C4, $F4, $84, $89, $C5, $B1, $B9, $24, $4C, $7D, $52, $46
	dc.b	$3A, $B6, $B6, $2B, $16, $B6, $2D, $46, $8E, $FC, $DC, $54, $6B, $6E, $97, $9B, $D0, $C1, $6A, $FA, $50, $BB, $12, $95, $8D, $A3, $D6, $C8, $0A, $F0, $42, $39
	dc.b	$41, $1C, $42, $14, $4E, $8C, $A1, $2F, $4E, $47, $18, $39, $74, $EE, $A1, $72, $95, $24, $57, $FC, $CB, $8B, $6D, $72, $6B, $1D, $36, $99, $99, $99, $B5, $65
	dc.b	$DE, $D0, $D4, $60, $BC, $B5, $89, $9B, $68, $44, $AC, $4E, $86, $63, $EF, $98, $FB, $E6, $D0, $8C, $37, $8E, $5C, $56, $32, $1F, $9B, $96, $8E, $DA, $6C, $BB
	dc.b	$3C, $CB, $4F, $9D, $61, $31, $3E, $31, $C7, $E6, $20, $F3, $25, $D3, $D0, $86, $2B, $A9, $28, $5E, $5C, $F4, $7E, $D8, $05, $13, $15, $3B, $BC, $90, $F5, $2A
	dc.b	$04, $8A, $50, $8E, $F4, $04, $35, $B6, $94, $A2, $4B, $65, $A4, $52, $3A, $42, $DD, $B6, $A3, $EC, $95, $DE, $2B, $1A, $15, $67, $B6, $96, $CA, $51, $E6, $16
	dc.b	$2B, $72, $CC, $CC, $CD, $36, $B1, $4B, $3C, $FB, $F1, $EF, $43, $9A, $1F, $48, $41, $5E, $A3, $A0, $F1, $DE, $27, $E0, $94, $C2, $9A, $2A, $10, $23, $47, $19
	dc.b	$18, $82, $0D, $D5, $0C, $8F, $08, $F9, $B9, $49, $64, $40, $9D, $37, $CC, $3C, $52, $15, $7A, $75, $25, $06, $86, $ED, $3B, $F4, $2F, $91, $1E, $6A, $92, $DF
	dc.b	$46, $16, $50, $91, $D9, $E3, $9D, $8E, $7B, $1D, $47, $00, $D9, $AF, $5B, $2C, $4D, $B8, $B1, $C8, $E5, $FB, $E9, $FE, $B9, $99, $AB, $9F, $CA, $E7, $9F, $CD
	dc.b	$8D, $E6, $BB, $D7, $7E, $C9, $46, $FC, $13, $C8, $6E, $84, $8A, $3D, $89, $3F, $43, $D9, $7B, $48, $EE, $64, $61, $66, $14, $13, $BF, $3A, $09, $1C, $48, $47
	dc.b	$74, $35, $04, $3A, $4B, $20, $42, $45, $0F, $24, $30, $F3, $EB, $C2, $B9, $E7, $3F, $69, $8C, $E0, $DD, $37, $EB, $BC, $F8, $3A, $C6, $B7, $32, $AC, $4A, $D5
	dc.b	$1D, $B3, $38, $EC, $6D, $63, $07, $B1, $BA, $BF, $EE, $CD, $9F, $B3, $F9, $D6, $D0, $49, $C2, $AE, $99, $D3, $95, $3D, $73, $91, $00, $A1, $41, $BA, $00, $E1
	dc.b	$E9, $66, $4F, $A9, $BF, $8A, $72, $14, $D5, $27, $72, $5D, $EE, $4F, $23, $BD, $53, $7A, $5F, $83, $4B, $BF, $AA, $5F, $AA, $C7, $15, $D8, $CB, $3B, $56, $C5
	dc.b	$62, $8C, $C8, $F6, $A8, $C6, $65, $30, $65, $5B, $D4, $74, $E9, $C2, $62, $03, $7D, $BF, $2C, $26, $5C, $B9, $4E, $03, $79, $2B, $CC, $AE, $48, $21, $7C, $02
	dc.b	$AD, $8A, $5E, $29, $AD, $E5, $E2, $3A, $E2, $7B, $22, $E1, $F7, $A1, $A6, $33, $7C, $85, $84, $B9, $13, $10, $94, $C7, $27, $78, $3A, $15, $89, $B6, $36, $9C
	dc.b	$12, $27, $0D, $8E, $1B, $4F, $89, $C6, $B1, $EB, $69, $89, $C6, $11, $3A, $C7, $13, $8C, $2D, $BB, $34, $66, $D2, $A3, $A9, $59, $62, $74, $E3, $12, $9E, $01
	dc.b	$6D, $F9, $8B, $6E, $71, $56, $3E, $2F, $CE, $0B, $8B, $9E, $14, $EF, $87, $1E, $D8, $8C, $2C, $63, $BB, $BC, $E9, $9B, $BC, $C1, $47, $7D, $93, $77, $95, $CB
	dc.b	$F5, $D7, $AF, $49, $B2, $2B, $E2, $A5, $B4, $10, $A3, $07, $D9, $6D, $86, $66, $66, $FF, $F6, $1C, $77, $C3, $1B, $8E, $DD, $E3, $B0, $6E, $3C, $7A, $72, $C9
	dc.b	$6A, $0D, $41, $8E, $14, $A4, $62, $BC, $13, $AB, $83, $71, $BA, $A3, $8B, $9F, $E5, $56, $F5, $86, $96, $47, $32, $D4, $30, $B5, $CA, $63, $DD, $72, $1E, $8A
	dc.b	$E3, $49, $4D, $49, $0B, $C8, $49, $84, $FD, $08, $47, $19, $3C, $DD, $E1, $37, $98, $20, $8F, $3D, $E6, $6E, $24, $32, $7F, $B3, $90, $A6, $F0, $A8, $48, $F2
	dc.b	$0A, $85, $E4, $DE, $A8, $38, $50, $93, $DC, $87, $2A, $98, $1E, $04, $D5, $04, $26, $46, $15, $1D, $85, $21, $E6, $58, $0A, $8B, $72, $FC, $B7, $0F, $9E, $EF
	dc.b	$C3, $BB, $68, $F6, $40, $DA, $EA, $3A, $D9, $48, $76, $38, $0B, $B7, $0E, $51, $C9, $6A, $18, $0B, $57, $D5, $17, $15, $E0, $DD, $ED, $93, $E9, $CA, $10, $9E
	dc.b	$1E, $A0, $95, $02, $39, $04, $D2, $48, $3C, $A8, $2B, $D6, $7B, $DD, $34, $F9, $8F, $CD, $79, $27, $90, $FC, $DA, $6D, $FC, $15, $1F, $AF, $24, $7C, $D0, $9C
	dc.b	$9D, $0E, $A4, $40, $BC, $39, $3A, $09, $3E, $90, $17, $8D, $D1, $F2, $F0, $52, $47, $12, $10, $49, $10, $7C, $DE, $8F, $49, $BD, $37, $F6, $9F, $34, $FC, $D6
	dc.b	$6A, $58, $53, $52, $32, $06, $2B, $F9, $43, $DF, $2E, $E1, $C5, $75, $06, $35, $59, $40, $F0, $60, $C7, $6A, $2B, $3B, $C0, $C4, $0C, $7E, $5B, $15, $80, $31
	dc.b	$8A, $AF, $5B, $40, $8E, $02, $1D, $8F, $D0, $FE, $53, $9C, $03, $E0, $D4, $BC, $C1, $4B, $03, $81, $35, $A8, $80, $E0, $1E, $0E, $5C, $03, $A9, $53, $F4, $44
	dc.b	$73, $49, $FE, $72, $7D, $21, $22, $BE, $61, $03, $FC, $89, $87, $84, $77, $9E, $93, $A4, $1E, $1C, $5E, $11, $E8, $3C, $26, $82, $02, $79, $20, $78, $42, $40
	dc.b	$81, $E8, $10, $3E, $8E, $20, $85, $22, $3D, $D4, $AA, $E2, $0A, $12, $4B, $34, $E6, $17, $2A, $ED, $BD, $BF, $39, $1F, $CD, $34, $69, $67, $CE, $29, $38, $9D
	dc.b	$A1, $62, $B4, $1B, $51, $26, $B5, $5A, $D0, $58, $A6, $F1, $F6, $8B, $F1, $12, $B6, $99, $99, $99, $99, $9B, $6F, $CC, $ED, $4E, $B6, $F1, $1F, $CB, $6F, $1E
	dc.b	$19, $8A, $C7, $63, $B1, $B3, $58, $DA, $C5, $1E, $1B, $86, $66, $96, $FF, $BE, $74, $E1, $88, $08, $09, $D4, $C9, $60, $BB, $D7, $7A, $F1, $DF, $E5, $97, $2E
	dc.b	$AF, $1E, $AB, $F9, $4F, $D3, $BF, $F3, $9F, $9D, $F2, $FE, $FF, $45, $DA, $8D, $53, $50, $D7, $BE, $FF, $AE, $04, $F0, $B7, $47, $83, $CF, $E6, $B3, $CF, $E6
	dc.b	$DC, $A4, $6A, $79, $19, $07, $47, $51, $D4, $14, $75, $0E, $83, $F7, $02, $87, $FA, $B1, $4C, $F2, $F2, $F1, $89, $96, $78, $CF, $A5, $9C, $1D, $01, $FA, $1E
	dc.b	$3D, $71, $8F, $CA, $33, $36, $77, $D7, $E6, $37, $F1, $BF, $04, $0B, $F2, $98, $E7, $F4, $DF, $95, $5E, $E4, $B5, $32, $DB, $F2, $BE, $FC, $7F, $1F, $87, $EE
	dc.b	$9E, $11, $FB, $FF, $08, $C8, $E1, $F9, $6F, $74, $E1, $3C, $07, $8A, $0A, $78, $73, $E8, $EC, $F2, $1F, $C5, $39, $A1, $F2, $F0, $97, $A3, $C2, $5E, $9B, $2D
	dc.b	$24, $A3, $F3, $59, $76, $4F, $34, $C8, $E7, $2E, $30, $7B, $CF, $F5, $9F, $AF, $B1, $7F, $97, $86, $66, $A6, $77, $DB, $F4, $B3, $BE, $06, $39, $DE, $44, $6B
	dc.b	$32, $97, $06, $38, $2F, $CE, $53, $F4, $90, $FD, $29, $3F, $F3, $AF, $1F, $AE, $FD, $96, $E4, $63, $F7, $FB, $BF, $71, $4F, $D3, $63, $F2, $98, $15, $78, $FD
	dc.b	$75, $F1, $9C, $7E, $6C, $4C, $77, $3E, $F3, $73, $71, $CE, $81, $4B, $DB, $F7, $1F, $9A, $5E, $73, $4C, $D3, $F3, $67, $93, $19, $1F, $BB, $F1, $57, $FE, $58
	dc.b	$AA, $3D, $DD, $01, $0E, $3B, $FC, $A7, $A6, $66, $66, $66, $AD, $93, $51, $EA, $2F, $58, $AC, $E3, $5C, $47, $F3, $0D, $15, $B1, $58, $AC, $B6, $3B, $1D, $9E
	dc.b	$91, $86, $22, $6C, $CC, $CC, $CD, $1A, $46, $91, $A7, $E5, $6F, $4C, $77, $B1, $83, $95, $30, $60, $E3, $DD, $B8, $BF, $1F, $95, $7D, $C8, $24, $A8, $E4, $8A
	dc.b	$33, $36, $D4, $64, $92, $34, $91, $C8, $52, $A3, $48, $EE, $F0, $85, $75, $F3, $B6, $7F, $43, $15, $36, $DB, $59, $6D, $34, $BF, $8E, $29, $0D, $A8, $92, $7F
	dc.b	$3A, $1E, $5F, $CC, $3B, $15, $C4, $0E, $58, $A8, $37, $76, $2B, $EA, $18, $D0, $F5, $82, $40, $63, $8C, $79, $74, $38, $7A, $5C, $9F, $14, $68, $A6, $C9, $14
	dc.b	$08, $12, $FF, $A1, $1F, $AF, $21, $DF, $EF, $FC, $29, $CB, $F7, $E5, $E4, $7E, $BD, $C4, $97, $42, $1F, $CE, $20, $77, $F4, $4A, $7E, $C0, $E4, $40, $8C, $1F
	dc.b	$EC, $4E, $27, $73, $07, $13, $BB, $CA, $46, $E4, $27, $76, $0D, $4F, $43, $BB, $C1, $E4, $63, $F5, $4E, $4F, $14, $D0, $D7, $E6, $90, $23, $E9, $EA, $BC, $A0
	dc.b	$4C, $1D, $7B, $AF, $E6, $70, $2A, $60, $EB, $AF, $CD, $7E, $A7, $F2, $BA, $D9, $39, $85, $9E, $CC, $DF, $BF, $77, $91, $D0, $F2, $40, $9D, $FA, $10, $4E, $ED
	dc.b	$DD, $3B, $B2, $7F, $97, $13, $D0, $25, $91, $C6, $5E, $63, $D7, $EB, $8E, $5F, $B3, $05, $DF, $EC, $41, $03, $2F, $62, $9F, $64, $AE, $37, $F4, $0A, $24, $E2
	dc.b	$71, $2C, $BA, $71, $CB, $A3, $5F, $40, $8C, $2F, $F0, $DC, $6E, $39, $7E, $6B, $F3, $3F, $BA, $66, $FC, $CC, $4E, $DC, $3E, $96, $4A, $5C, $ED, $CB, $39, $19
	dc.b	$A9, $64, $B3, $E4, $92, $26, $97, $98, $A1, $39, $29, $74, $B1, $6C, $4E, $4B, $FB, $02, $89, $B8, $A4, $46, $10, $DC, $B2, $23, $91, $B3, $8E, $C5, $A7, $1C
	dc.b	$B3, $1D, $5C, $DA, $DA, $77, $EE, $79, $B1, $B3, $8E, $E5, $62, $71, $1E, $DA, $CF, $71, $D7, $20, $C7, $39, $FD, $50, $30, $6A, $0E, $26, $0D, $C5, $2F, $D8
	dc.b	$BB, $AF, $D7, $8E, $9D, $E5, $DF, $D1, $78, $EB, $6F, $D0, $BB, $F7, $34, $69, $52, $E5, $62, $EE, $91, $3D, $BB, $D6, $C7, $A8, $80, $00
Credits_palette_stream:
	dc.b	$22, $2E, $08, $AE, $08, $8E, $08, $6E, $06, $4E, $04, $2E, $02, $0E, $00, $0E, $00, $0C, $00, $0A, $00, $08, $00, $06, $00, $06, $00, $04, $00, $00, $00, $00
	dc.b	$00, $00, $06, $88, $08, $AA, $0A, $AA, $0C, $CC, $04, $44, $06, $64, $0C, $CC, $06, $66, $00, $00, $02, $42, $04, $64, $06, $86, $08, $A8, $0A, $CA, $08, $86
	dc.b	$04, $44, $0E, $EE, $0C, $CC, $04, $46, $04, $48, $04, $6A, $00, $08, $00, $2A, $02, $4C, $06, $6E, $0A, $AE, $08, $88, $0A, $AA, $02, $22, $04, $44, $06, $66
Credits_car_sprite_table:
	dc.l	$0EEE0CCC, $0AAA0000, $08880444, $02220000, $0000044C, $022A0228, $02260224, $08CE02AE, $028C0268, $00680444, $02220000, $0000048C, $028A0068, $02460024, $088E066C, $044C000A, $00080444, $02220000, $0000046C, $024A0008, $00060004, $0EEE0CCC, $0AAA0AAA, $08880444, $02220000, $00000A84, $0A620862, $06420422
Credits_tilemap_1:
	dc.b	$08, $03, $00, $00, $00, $00, $01, $F7, $DF, $7D, $F7, $DF, $7D, $F6, $41, $44, $06, $43, $68, $58, $00, $38, $E9, $84, $90, $69, $80, $81, $D1, $02, $44, $81
	dc.b	$80, $12
	dc.b	$1E
	dc.b	$14, $A0, $90, $08, $41, $20, $90, $C2, $41, $B8, $44, $F0, $82, $40, $21, $84, $87, $40, $09, $07, $80, $12
	dc.b	$0F
	dc.b	$04, $24, $12, $10, $48, $07, $05, $26, $58, $49, $C1, $49, $8C, $12
	dc.b	$70
	dc.b	$90, $A7, $84, $80, $4B, $09, $0F, $02, $01, $06, $5C, $02, $48, $18, $04, $90, $71, $42, $40, $20, $84, $80, $40, $09, $00, $E3, $13
	dc.b	$84
	dc.b	$80, $76, $50, $A2, $70, $90, $9C, $50, $84, $28, $9E, $78, $49, $0C, $24, $3A, $01, $50, $2C, $62, $74, $28, $05, $A0, $72, $0B, $88, $0D, $B8, $10, $4B, $6A
	dc.b	$25, $BC, $F2, $E2, $59, $71, $FC
Credits_tilemap_2:
	dc.b	$08, $00, $00, $B8, $00, $B8, $01, $F5, $29, $DD, $2B, $46, $F9, $9A, $B8, $09, $54, $C6, $4A, $96, $5A, $31, $30, $2C, $E7, $23, $53, $63, $F8, $00
Credits_tilemap_3:
	dc.b	$0A, $00, $00, $01, $00, $00, $19, $83, $CF, $3C, $58, $00, $F0, $B0, $44, $22, $E0, $89, $E7, $81, $44, $42, $07, $08, $79, $84, $3C, $80, $1D
	dc.b	$97
	dc.b	$00, $4F, $2A, $08, $9E, $46, $11, $7F, $08, $BF, $00, $5E, $3C, $C8, $02, $78, $30, $04, $F0, $7A, $89, $E5, $01, $42, $27
	dc.b	$94
	dc.b	$22, $79, $E7, $85, $4C, $BF, $80, $3C
	dc.b	$9E
	dc.b	$78, $54, $4E, $6A, $27, $21, $E1, $C0, $3F, $4E, $A2, $84
	dc.b	$D1
	dc.b	$41, $CF, $0A, $01, $FA, $7D, $32, $FE, $00, $F2, $78, $F0, $0F, $62, $78, $25, $74, $8E, $38, $07, $51, $E2, $C0, $3F, $8B, $E0, $95
	dc.b	$D2
	dc.b	$41, $A0, $21, $A7, $9E, $17, $34, $2D, $4D, $53, $14, $C3, $CF, $0F, $9A, $16, $B7
	dc.b	$AD
	dc.b	$CB, $71, $E7, $87, $49, $8F, $80, $95
	dc.b	$80
	dc.b	$80, $08, $9E, $75, $36, $CF, $83, $BE, $A8, $69, $86, $89, $F4, $9D, $80, $3F, $80
Credits_car_frame_a:
	dc.b	$00, $11, $A8, $0E, $03, $19, $FF, $CC, $A8, $0E, $03, $25, $FF, $EC, $A8
	dc.b	$0D, $03, $31, $00, $0C, $B8, $00, $03, $39, $00, $24, $C8, $0B, $03, $3A, $FF, $9C, $E8, $0A, $03, $46, $FF, $9C, $C0, $0F, $03, $4F, $FF, $B4, $E0, $0F, $03
	dc.b	$5F, $FF, $B4, $C8, $0B, $03, $6F, $FF, $D4, $E8, $0A, $03, $7B, $FF, $D4, $C0, $0F, $03, $84, $FF, $EC, $E0, $0F, $03, $94, $FF, $EC, $C0, $0F, $03, $A4, $00
	dc.b	$0C, $E0, $0F, $03, $B4, $00, $0C, $C0, $0F, $03, $C4, $00, $2C, $E0, $0F, $03, $D4, $00, $2C, $C0, $0B, $03, $E4, $00, $4C, $E0, $0B, $03, $F0, $00, $4C
Credits_car_frame_b:
	dc.b	$00, $01, $E4, $0C, $23, $FC, $FF, $FB, $E4, $00, $24, $00, $00, $1B
Credits_car_frame_c:
	dc.b	$00, $01, $E4, $0C, $24, $01, $FF, $FB, $E4, $08, $24, $05, $00, $1B
Credits_car_frame_d:
	dc.b	$00, $01, $E4, $0C, $24, $08, $FF, $FB, $E4, $04, $24, $0C, $00, $1B
Credits_car_frame_e:
	dc.b	$00, $01, $E4, $0C, $24, $0E, $FF, $FB, $E4, $04, $24, $12, $00, $1B
Credits_car_frame_f:
	dc.b	$00, $00, $E4, $04, $24, $14, $FF, $FB
Credits_tiles:
	dc.b	$02, $19, $80, $76, $27, $81, $05, $0D, $17, $62, $27, $6A, $38, $E6, $48, $EB, $68, $EC, $76, $2A, $82, $05, $0B, $16, $24, $26, $2C, $37, $57, $47, $5E, $58
	dc.b	$DA, $68, $E8, $76, $1F, $83, $06, $25, $18, $E3, $84, $07, $63, $85, $07, $5A, $18, $F2, $86, $07, $5B, $18, $EA, $87, $06, $2E, $18, $DE, $28, $E4, $48, $F1
	dc.b	$76, $26, $88, $07, $69, $18, $F4, $89, $06, $30, $18, $ED, $8A, $07, $67, $18, $DF, $28, $E9, $8B, $04, $02, $16, $22, $27, $6C, $38, $E2, $48, $EE, $8C, $06
	dc.b	$23, $17, $56, $28, $E5, $8D, $05, $0E, $17, $5F, $27, $6E, $38, $D6, $48, $E7, $77, $65, $8E, $04, $00, $14, $04, $26, $1E, $36, $29, $47, $68, $58, $DB, $67
	dc.b	$70, $74, $03, $8F, $04, $01, $15, $0A, $25, $10, $36, $28, $47, $66, $57, $64, $68, $D7, $75, $0C, $FF, $9E, $79, $E7, $9E, $79, $E7, $9E, $79, $E7, $E3, $D1
	dc.b	$2A, $7F, $8C, $3F, $47, $F9, $4B, $47, $3C, $FF, $C0, $34, $C6, $92, $86, $3B, $52, $84, $A1, $8C, $25, $7A, $2E, $5B, $02, $5F, $D2, $79, $4B, $3F, $E8, $25
	dc.b	$DB, $FE, $9D, $A8, $A5, $49, $6D, $07, $1A, $5A, $94, $C1, $71, $DE, $8F, $1D, $A2, $8D, $75, $8A, $7D, $B9, $71, $E8, $97, $F2, $96, $8A, $D5, $38, $C2, $5C
	dc.b	$7F, $A5, $FC, $A4, $BA, $38, $CA, $D4, $BA, $31, $CB, $1D, $A9, $52, $59, $FF, $28, $12, $FE, $C3, $F6, $BF, $94, $FC, $81, $46, $51, $DA, $C7, $28, $63, $7A
	dc.b	$5C, $76, $B1, $DA, $E5, $FD, $2C, $A9, $8E, $D7, $E5, $2D, $47, $4F, $1E, $39, $67, $9E, $79, $7F, $C1, $2E, $3F, $E8, $71, $FE, $52, $D7, $E8, $0A, $D1, $79
	dc.b	$63, $0F, $C0, $3D, $C7, $F9, $49, $67, $9E, $79, $E7, $9E, $70, $9E, $79, $E7, $9E, $79, $E7, $FC, $86, $89, $E7, $9E, $79, $E7, $FF, $03, $DF, $DD, $9E, $79
	dc.b	$E7, $9E, $77, $B2, $F3, $CF, $3C, $F3, $CF, $F9, $00, $CB, $97, $9E, $79, $E7, $9E, $7C, $B9, $72, $CF, $3C, $F3, $FE, $43, $2E, $5C, $BF, $DD, $9E, $79, $E7
	dc.b	$CB, $B8, $32, $E5, $D6, $9E, $79, $E7, $D6, $0B, $E1, $97, $9C, $32, $DF, $9E, $79, $E7, $47, $53, $97, $2D, $F0, $D6, $07, $4F, $3C, $F3, $EE, $0C, $BF, $ED
	dc.b	$0D, $6A, $5C, $8E, $9E, $79, $E7, $CB, $95, $C1, $7C, $39, $D3, $5A, $79, $E7, $9F, $2F, $38, $5F, $0D, $67, $B2, $CF, $3C, $F3, $E5, $A5, $C0, $E4, $DC, $1F
	dc.b	$ED, $0D, $D3, $CF, $3F, $E0, $32, $DF, $07, $05, $F0, $75, $39, $7F, $BA, $1B, $A7, $9E, $7F, $F6, $86, $5C, $A0, $E4, $72, $6E, $07, $06, $E9, $E7, $CB, $AC
	dc.b	$0E, $7B, $70, $39, $37, $03, $9E, $FF, $68, $6E, $0D, $69, $E7, $CA, $0E, $0E, $7A, $5C, $17, $DE, $BE, $17, $D1, $CF, $39, $ED, $60, $74, $FF, $90, $0F, $F6
	dc.b	$85, $F4, $70, $6B, $3D, $CE, $0E, $4C, $B9, $7F, $BA, $13, $E5, $E7, $0F, $F6, $85, $F0, $70, $65, $FF, $6A, $38, $35, $93, $5B, $FA, $17, $C3, $28, $5F, $0E
	dc.b	$70, $70, $7F, $74, $3F, $BA, $19, $43, $9D, $1C, $99, $75, $83, $9C, $1C, $97, $C3, $2E, $5C, $BF, $DD, $0C, $B9, $6F, $85, $F0, $D6, $47, $27, $38, $38, $3F
	dc.b	$BA, $1F, $DD, $0C, $A1, $CE, $8E, $4E, $70, $D6, $0B, $E1, $AC, $8E, $4E, $70, $70, $7F, $74, $3F, $BA, $19, $43, $9D, $1C, $99, $77, $3D, $AC, $0E, $4B, $E9
	dc.b	$97, $2E, $5E, $70, $CB, $7F, $8A, $35, $D6, $7D, $7F, $FC, $B5, $C7, $A3, $8C, $3F, $A7, $8F, $8F, $1D, $A2, $96, $D4, $6B, $8C, $AD, $63, $7A, $5A, $6D, $17
	dc.b	$ED, $65, $C7, $5E, $3B, $5F, $94, $8E, $42, $FD, $2E, $34, $95, $EB, $5C, $74, $CA, $95, $A4, $C5, $20, $63, $B5, $B7, $7E, $9C, $72, $E3, $95, $25, $F2, $8C
	dc.b	$BC, $B1, $F9, $47, $8E, $D6, $3B, $58, $FC, $8B, $8D, $25, $09, $71, $F0, $95, $B2, $14, $A6, $0B, $6B, $D6, $A2, $94, $2D, $47, $DD, $1D, $AC, $7A, $23, $25
	dc.b	$C6, $58, $DE, $C7, $2D, $62, $F2, $2C, $72, $E3, $09, $53, $18, $7E, $91, $25, $06, $90, $7E, $52, $5C, $6F, $5A, $C4, $B8, $ED, $45, $A3, $FF, $91, $A4, $51
	dc.b	$97, $29, $4A, $F1, $63, $28, $ED, $4B, $68, $A9, $97, $1C, $BF, $A5, $D1, $7C, $3F, $29, $C6, $97, $ED, $4B, $FA, $5E, $3C, $76, $92, $5B, $51, $95, $A8, $D7
	dc.b	$1D, $36, $B8, $CB, $CB, $44, $A9, $8D, $31, $C7, $E4, $98, $C3, $C8, $AB, $14, $76, $AF, $A7, $94, $65, $28, $7F, $42, $5B, $45, $6A, $57, $B9, $6D, $71, $DA
	dc.b	$27, $AD, $72, $E3, $E1, $28, $71, $E8, $B5, $2A, $4B, $E5, $2F, $91, $2D, $B6, $A5, $B5, $3E, $30, $FE, $EC, $BA, $1C, $98, $F6, $E3, $93, $84, $BA, $31, $DA
	dc.b	$97, $45, $A2, $8D, $64, $F4, $FB, $82, $F8, $09, $ED, $BB, $6E, $FF, $07, $1B, $B4, $5F, $09, $F5, $8D, $C0, $E4, $72, $38, $CF, $83, $B4, $3B, $47, $F4, $2F
	dc.b	$A7, $39, $99, $9A, $38, $C1, $D4, $E5, $0E, $74, $71, $99, $99, $E8, $70, $65, $7B, $5B, $46, $B1, $9D, $F3, $3D, $BC, $BB, $93, $73, $DC, $F4, $B8, $1D, $C1
	dc.b	$C7, $4E, $EE, $17, $C1, $C1, $B8, $35, $91, $C1, $7D, $1C, $0E, $07, $1B, $A9, $70, $38, $F8, $5F, $A5, $C0, $E0, $CB, $B8, $1C, $8E, $34, $76, $DE, $E7, $9C
	dc.b	$8E, $07, $1E, $87, $03, $A9, $D6, $33, $79, $C6, $0E, $07, $19, $9B, $DB, $83, $71, $F0, $71, $99, $99, $86, $5A, $5C, $9B, $91, $CF, $5F, $79, $CF, $5F, $D1
	dc.b	$7C, $1C, $F6, $B0, $3A, $97, $6D, $EE, $0E, $70, $72, $38, $1C, $F3, $A9, $72, $6E, $07, $53, $7C, $C1, $D4, $B9, $1C, $F3, $9E, $D6, $0D, $64, $72, $39, $1C
	dc.b	$0E, $D0, $EE, $0E, $07, $06, $ED, $B7, $06, $E7, $9C, $17, $C1, $C9, $7C, $35, $82, $FA, $6E, $07, $03, $92, $F8, $39, $1C, $9B, $B6, $F7, $05, $F0, $E7, $0E
	dc.b	$70, $70, $65, $70, $38, $2F, $9A, $39, $EB, $E8, $EA, $6F, $83, $82, $F8, $38, $2F, $83, $83, $9D, $2F, $86, $E7, $AF, $87, $38, $5F, $07, $53, $AC, $1C, $E0
	dc.b	$E0, $73, $DF, $DD, $7B, $FB, $A1, $CE, $1B, $92, $F8, $6E, $7B, $9C, $2F, $87, $F7, $43, $59, $2F, $86, $B0, $38, $35, $81, $C9, $7C, $1C, $1A, $C0, $E7, $9C
	dc.b	$17, $C3, $58, $1C, $1F, $DD, $07, $07, $38, $73, $83, $82, $F8, $65, $BE, $0E, $47, $26, $EA, $5C, $1B, $82, $F8, $5F, $0B, $E9, $97, $2E, $E0, $70, $65, $DC
	dc.b	$17, $DE, $BE, $F3, $83, $70, $39, $EB, $E1, $B8, $2F, $85, $F0, $DC, $0E, $0C, $B9, $72, $F3, $87, $38, $39, $ED, $6A, $72, $E5, $70, $6B, $06, $5F, $F6, $D3
	dc.b	$AC, $97, $C3, $FD, $A1, $B8, $35, $83, $70, $7F, $75, $39, $C1, $C1, $97, $58, $35, $83, $2F, $F7, $4F, $2B, $9E, $D6, $07, $25, $F0, $CB, $97, $2F, $F7, $43
	dc.b	$2E, $E4, $FE, $EA, $7F, $74, $3F, $BA, $0E, $07, $06, $5D, $C1, $97, $2F, $FB, $43, $FB, $A1, $FD, $D0, $FE, $E8, $65, $CB, $97, $2E, $5D, $60, $CB, $97, $2E
	dc.b	$5D, $60, $CB, $AC, $19, $77, $03, $9E, $BE, $17, $C3, $2F, $3B, $DF, $DD, $0D, $60, $73, $CE, $0D, $D4, $DF, $07, $03, $A9, $70, $6E, $0F, $F6, $87, $38, $65
	dc.b	$BE, $1B, $82, $F8, $5F, $7B, $58, $37, $03, $91, $C1, $AC, $17, $C3, $58, $3F, $DA, $1C, $E1, $96, $F8, $6E, $0B, $E1, $7D, $ED, $60, $DC, $0E, $47, $26, $E0
	dc.b	$BE, $77, $F8, $4A, $BE, $CA, $D6, $36, $4B, $52, $9E, $DC, $A9, $8F, $8D, $3F, $89, $FA, $57, $26, $33, $A7, $55, $91, $92, $E3, $8B, $C8, $2D, $68, $FC, $A4
	dc.b	$AF, $7E, $8C, $25, $A6, $5F, $CA, $06, $CE, $52, $5E, $88, $9A, $1C, $74, $95, $6F, $28, $E5, $48, $AB, $5A, $96, $D6, $39, $69, $FD, $29, $BD, $8E, $99, $23
	dc.b	$28, $ED, $4A, $0D, $88, $25, $C7, $69, $71, $63, $8B, $1C, $B8, $D3, $1D, $A2, $B4, $4D, $7B, $8E, $D4, $52, $ED, $DA, $C7, $E4, $67, $A1, $AB, $B5, $FB, $44
	dc.b	$96, $D4, $6D, $B5, $F9, $45, $C7, $6B, $1D, $A2, $B5, $8E, $35, $F3, $2E, $D1, $72, $AD, $B1, $4B, $8F, $CB, $63, $D8, $C3, $CA, $B6, $8C, $76, $A3, $0D, $CF
	dc.b	$5A, $C7, $2E, $DF, $E5, $3F, $46, $12, $DA, $96, $D6, $39, $71, $CA, $98, $97, $6A, $5A, $49, $A8, $BA, $CF, $44, $91, $01, $62, $59, $04, $76, $8A, $38, $A3
	dc.b	$95, $25, $25, $95, $62, $AD, $2E, $DC, $B5, $BC, $A5, $09, $69, $94, $AD, $7E, $8C, $25, $4F, $DE, $5A, $95, $1B, $1D, $9A, $A5, $C7, $68, $B1, $BC, $B8, $ED
	dc.b	$4B, $4C, $B8, $E5, $2B, $2D, $27, $1A, $4A, $18, $FF, $4A, $9F, $A3, $0C, $7E, $51, $E2, $09, $5E, $B4, $4D, $8E, $D3, $D2, $99, $B8, $CC, $25, $E0, $5C, $31
	dc.b	$09, $99, $99, $99, $E8, $10, $1E, $02, $66, $66, $66, $67, $A1, $D4, $EE, $E0, $E3, $33, $33, $37, $03, $81, $D4, $B8, $DC, $0E, $0B, $EA, $A5, $C0, $3C, $4F
	dc.b	$0F, $FA, $C0, $4A, $38, $A3, $24, $8A, $3D, $88, $E3, $07, $23, $91, $D4, $B8, $CF, $B9, $41, $10, $F7, $47, $DC, $A7, $03, $8F, $43, $8C, $CF, $84, $43, $10
	dc.b	$A4, $3B, $8C, $CC, $CC, $CE, $21, $33, $33, $33, $D1, $7F, $6D, $C6, $F3, $8C, $CD, $1C, $66, $74, $B8, $C1, $C8, $E3, $79, $DC, $1C, $66, $66, $7C, $1C, $6E
	dc.b	$33, $33, $3D, $B7, $03, $8C, $CC, $CC, $CD, $C1, $B8, $2F, $86, $B1, $D2, $E7, $9C, $66, $67, $C1, $C0, $E7, $9C, $0E, $47, $1E, $87, $19, $99, $F0, $70, $38
	dc.b	$1C, $1B, $8C, $1C, $0E, $E0, $ED, $0E, $33, $E0, $EA, $6F, $A3, $81, $C0, $ED, $B7, $03, $91, $C0, $E0, $D6, $47, $23, $8C, $DE, $76, $87, $07, $F7, $43, $59
	dc.b	$1C, $17, $C1, $C8, $E0, $BE, $0E, $07, $25, $F0, $70, $6E, $07, $03, $8C, $D2, $FA, $73, $E8, $DC, $97, $C3, $71, $EE, $0D, $C0, $E3, $70, $3B, $83, $A9, $FE
	dc.b	$E8, $65, $E7, $07, $03, $83, $75, $39, $5C, $F6, $E3, $73, $CE, $7A, $F8, $7F, $B4, $37, $06, $5E, $70, $E7, $07, $07, $FB, $43, $FD, $A1, $7C, $1D, $4B, $93
	dc.b	$58, $3F, $BA, $1C, $E0, $E4, $70, $73, $86, $E4, $70, $5F, $07, $07, $38, $5F, $A7, $72, $38, $2F, $A6, $5C, $B7, $C3, $59, $32, $FF, $76, $9D, $64, $BE, $1F
	dc.b	$ED, $0D, $C9, $CB, $66, $2E, $12, $9F, $EC, $F1, $FE, $95, $7C, $CB, $EB, $BC, $5F, $B5, $95, $25, $E0, $D5, $B5, $6D, $5C, $6D, $09, $4D, $25, $C7, $6A, $5F
	dc.b	$D2, $94, $72, $47, $63, $64, $6C, $6B, $E5, $92, $32, $D1, $29, $A2, $F9, $97, $89, $E9, $4A, $46, $99, $5A, $2C, $74, $D6, $5F, $2D, $A0, $97, $6E, $D1, $F0
	dc.b	$96, $3B, $5F, $94, $95, $E9, $1A, $BA, $D1, $68, $C7, $68, $B8, $4A, $76, $BF, $28, $9E, $58, $E5, $FD, $25, $62, $B5, $28, $7F, $50, $F6, $5A, $7A, $59, $23
	dc.b	$5D, $68, $B8, $F1, $DA, $AD, $68, $9E, $FD, $9E, $3A, $65, $FD, $27, $94, $AF, $71, $E3, $B5, $28, $7E, $8F, $46, $30, $8B, $86, $3F, $DE, $5A, $95, $2D, $14
	dc.b	$72, $56, $F2, $2F, $EE, $4B, $FC, $4F, $2C, $7C, $7F, $C4, $09, $71, $CB, $FB, $46, $AF, $FA, $3C, $51, $AF, $16, $89, $7F, $29, $2F, $05, $C6, $B8, $ED, $63
	dc.b	$94, $39, $6F, $7E, $D3, $C8, $A3, $FE, $A7, $1C, $95, $97, $1A, $62, $91, $B2, $47, $F9, $49, $6D, $58, $D9, $71, $CB, $F9, $4E, $3B, $41, $2D, $3C, $7F, $B5
	dc.b	$C7, $C7, $8E, $BD, $62, $B5, $FA, $4B, $45, $CA, $F0, $BC, $31, $C4, $34, $C8, $50, $42, $8D, $65, $00, $96, $95, $07, $E5, $25, $78, $43, $F4, $B1, $28, $17
	dc.b	$CA, $B8, $C4, $CE, $98, $22, $8C, $CC, $F8, $09, $19, $99, $99, $99, $99, $BC, $A3, $33, $33, $30, $51, $99, $99, $9F, $01, $8A, $B1, $53, $B2, $31, $01, $7A
	dc.b	$2E, $02, $02, $14, $16, $DA, $8C, $FF, $F7, $FF, $CF, $FE, $6C, $AD, $B2, $3B, $D5, $8A, $35, $C7, $25, $61, $28, $EF, $00, $97, $F3, $3F, $F7, $FF, $C2, $8E
	dc.b	$28, $F6, $0A, $28, $15, $59, $71, $97, $EF, $24, $FE, $65, $9F, $FC, $8D, $7C, $BB, $06, $9A, $DD, $C3, $FF, $BA, $38, $B9, $7B, $BF, $F9, $59, $7F, $CC, $5F
	dc.b	$FB, $01, $C7, $B7, $16, $DE, $CD, $0A, $8A, $98, $CB, $96, $1F, $CC, $88, $7F, $D8, $47, $C1, $C6, $66, $83, $B6, $3B, $6A, $A4, $4D, $E7, $19, $99, $99, $9F
	dc.b	$07, $3D, $7C, $CC, $CD, $07, $80, $D2, $26, $66, $66, $67, $A0, $4C, $CC, $1C, $67, $B6, $E3, $33, $33, $33, $37, $87, $40, $80, $80, $BC, $E3, $33, $79, $C8
	dc.b	$E3, $33, $33, $37, $AF, $D2, $E7, $9C, $0E, $47, $3C, $E3, $33, $7A, $F9, $9D, $2E, $30, $70, $38, $CC, $CC, $37, $1D, $2E, $33, $07, $19, $9B, $81, $C0, $E3
	dc.b	$7A, $F9, $BC, $EE, $0E, $A5, $C6, $66, $0E, $34, $71, $99, $83, $8C, $CD, $2F, $83, $A9, $71, $83, $8C, $D1, $C8, $E0, $BE, $66, $E4, $E7, $D1, $B9, $2F, $86
	dc.b	$E3, $DC, $1C, $E6, $E0, $77, $07, $53, $28, $4A, $12, $84, $A1, $17, $F3, $1F, $5B, $56, $DA, $F5, $35, $FF, $EB, $DB, $BB, $FE, $D2, $FE, $93, $CB, $18, $56
	dc.b	$BD, $1B, $EF, $AF, $12, $F1, $2D, $B6, $6F, $D9, $6E, $EF, $DB, $5D, $87, $F5, $B7, $92, $5C, $76, $A5, $C7, $2C, $5C, $A5, $1D, $8D, $5F, $EF, $24, $E6, $AF
	dc.b	$52, $DB, $26, $2F, $DD, $2F, $3A, $DB, $6F, $93, $B7, $7E, $54, $97, $F6, $8B, $8E, $D6, $30, $E3, $C7, $FD, $CB, $23, $FE, $DF, $35, $7A, $AA, $CF, $26, $7A
	dc.b	$FF, $B4, $E3, $F2, $FE, $A7, $1C, $95, $8A, $D7, $E5, $22, $8E, $CA, $CB, $D9, $CA, $BE, $69, $2B, $7F, $46, $BF, $32, $DB, $E4, $1C, $76, $8A, $D2, $71, $A7
	dc.b	$1F, $E9, $3F, $46, $12, $DA, $FE, $27, $1A, $EB, $45, $6B, $F2, $91, $D8, $D9, $33, $AF, $3D, $9A, $97, $FB, $A9, $1B, $FB, $5F, $E2, $79, $7F, $33, $1F, $97
	dc.b	$E8, $F1, $DA, $E3, $C7, $FA, $3C, $7F, $F3, $97, $0D, $EE, $3B, $B8, $DA, $BD, $FC, $37, $A5, $EB, $93, $3F, $F1, $3F, $47, $6B, $1C, $BF, $C4, $8A, $35, $C7
	dc.b	$66, $39, $6D, $6C, $AD, $FD, $4F, $2F, $D1, $F8, $FF, $0F, $93, $0F, $EB, $F1, $DA, $2F, $DE, $0F, $E5, $3F, $47, $F9, $40, $8C, $BC, $BF, $68, $B8, $E4, $8F
	dc.b	$F6, $B5, $AF, $6F, $69, $DF, $B3, $C7, $4E, $19, $E5, $FD, $BF, $1D, $C3, $C2, $01, $40, $50, $0A, $C7, $6B, $21, $26, $65, $92, $51, $21, $05, $18, $69, $B9
	dc.b	$14, $60, $A0, $53, $D4, $24, $22, $82, $32, $01, $00, $80, $40, $CF, $80, $A0, $F0, $14, $10, $80, $08, $28, $14, $02, $0A, $05, $05, $06, $66, $82, $02, $03
	dc.b	$A0, $74, $41, $20, $02, $9A, $E9, $03, $33, $55, $2A, $06, $64, $01, $06, $20, $82, $8C, $CE, $14, $E6, $7B, $22, $31, $94, $88, $40, $14, $5F, $BC, $7B, $B9
	dc.b	$21, $B0, $04, $14, $55, $B3, $45, $1E, $42, $8C, $32, $10, $A0, $84, $3F, $F8, $51, $97, $F3, $3F, $F7, $FF, $C7, $DF, $8F, $A0, $AB, $5E, $FF, $E7, $FF, $3F
	dc.b	$F7, $FD, $C8, $AC, $FE, $66, $D5, $6B, $D1, $AE, $35, $C7, $5F, $FD, $92, $47, $B2, $B4, $51, $8F, $FA, $FF, $F9, $FF, $CE, $5B, $DC, $B7, $B9, $6F, $14, $10
	dc.b	$42, $21, $D1, $C5, $4F, $EF, $09, $41, $59, $75, $A2, $1B, $D5, $8B, $A2, $37, $CC, $CC, $C5, $E1, $7B, $5C, $0A, $80, $54, $65, $91, $04, $CC, $CF, $80, $80
	dc.b	$80, $80, $82, $81, $40, $20, $29, $0E, $02, $66, $66, $F0, $F0, $10, $80, $0A, $0B, $C2, $66, $66, $66, $28, $34, $A9, $E5, $19, $99, $99, $A0, $80, $E8, $52
	dc.b	$28, $CC, $CC, $CD, $E1, $31, $3D, $02, $60, $26, $66, $62, $F2, $8C, $CC, $C0, $4C, $CF, $6C, $40, $4C, $CF, $40, $99, $99, $99, $ED, $89, $99, $99, $99, $99
	dc.b	$9B, $C2, $66, $67, $4B, $8C, $CC, $CC, $E9, $FF, $B5, $D6, $F7, $AD, $FE, $DF, $F4, $DC, $9A, $7F, $B5, $67, $62, $F9, $97, $D8, $BE, $C5, $B5, $7D, $57, $5B
	dc.b	$BB, $F6, $DE, $3D, $5A, $7B, $7F, $75, $75, $76, $AD, $AB, $C5, $23, $64, $C4, $BA, $9B, $67, $32, $DB, $5F, $FC, $FA, $66, $99, $7F, $DA, $C1, $B2, $35, $78
	dc.b	$96, $D9, $3B, $24, $E6, $B3, $AF, $D3, $0B, $B4, $F4, $CD, $34, $D6, $67, $ED, $D3, $77, $35, $7A, $AA, $CF, $D1, $76, $FC, $9A, $A6, $E4, $B7, $BD, $6F, $FC
	dc.b	$F6, $EE, $5E, $FE, $9F, $DB, $B6, $4E, $9D, $37, $75, $D8, $D5, $FF, $6B, $9A, $4D, $FF, $1E, $DC, $F7, $5B, $FE, $BF, $57, $F9, $ED, $FF, $9E, $DE, $F7, $56
	dc.b	$F7, $4E, $1A, $79, $24, $EB, $5F, $EE, $AC, $6E, $FD, $EC, $FF, $B7, $D3, $86, $FC, $D3, $4D, $34, $99, $F4, $F2, $4B, $89, $6D, $93, $3E, $9F, $DD, $58, $DE
	dc.b	$DD, $F9, $37, $F9, $34, $EF, $C9, $C9, $D5, $BD, $A6, $69, $BF, $47, $E3, $A6, $EF, $D9, $EF, $2F, $55, $99, $E4, $C5, $23, $57, $9E, $F6, $2C, $33, $DE, $CF
	dc.b	$76, $9C, $3F, $75, $87, $ED, $BF, $6F, $FA, $37, $84, $3F, $66, $F0, $E1, $77, $1D, $2B, $CF, $A6, $E5, $24, $99, $D6, $4A, $0A, $F1, $26, $7A, $E4, $21, $86
	dc.b	$7B, $22, $01, $41, $A6, $80, $13, $30, $80, $66, $7A, $00, $21, $00, $83, $C2, $0A, $31, $41, $37, $84, $E0, $83, $A0, $53, $32, $50, $F0, $A0, $99, $BD, $07
	dc.b	$85, $15, $48, $ED, $88, $41, $14, $10, $01, $45, $02, $8E, $91, $DB, $10, $80, $08, $0A, $08, $43, $86, $60, $14, $10, $10, $C8, $14, $70, $17, $85, $E8, $06
	dc.b	$64, $80, $2A, $91, $41, $7A, $0F, $64, $0D, $73, $30, $50, $30, $42, $80, $50, $40, $15, $A1, $40, $CA, $00, $7F, $B7, $1A, $8B, $F9, $83, $14, $75, $E0, $55
	dc.b	$E0, $51, $D9, $08, $B9, $68, $28, $E4, $A0, $A3, $92, $32, $FF, $E7, $14, $65, $B5, $59, $FE, $8F, $FE, $6D, $46, $FA, $FF, $F8, $BE, $EF, $FE, $56, $7E, $C8
	dc.b	$EF, $7F, $31, $71, $AF, $96, $4A, $DB, $5C, $B5, $E3, $B3, $FF, $92, $56, $5F, $2B, $EF, $BF, $7A, $37, $EC, $2C, $95, $89, $E5, $72, $90, $BD, $64, $71, $2A
	dc.b	$BC, $64, $AA, $F5, $88, $63, $93, $94, $87, $FB, $91, $0B, $C2, $82, $66, $3C, $14, $82, $19, $80, $41, $48, $34, $A9, $04, $14, $F0, $BC, $A4, $1D, $02, $02
	dc.b	$F0, $80, $F0, $A1, $04, $05, $14, $F6, $60, $10, $17, $84, $04, $05, $EA, $1E, $CC, $60, $3A, $28, $01, $01, $48, $04, $29, $A1, $04, $14, $82, $8A, $78, $42
	dc.b	$00, $28, $27, $48, $F0, $10, $83, $C2, $0A, $01, $A4, $50, $5E, $17, $85, $E1, $41, $01, $05, $19, $82, $B4, $29, $04, $C5, $E1, $79, $4F, $0F, $08, $00, $99
	dc.b	$F0, $13, $48, $20, $A0, $80, $A0, $A0, $9A, $09, $99, $99, $E8, $51, $A0, $99, $99, $80, $98, $0D, $23, $C0, $4C, $40, $50, $5E, $17, $95, $48, $99, $89, $D2
	dc.b	$34, $8D, $23, $48, $F0, $10, $13, $78, $4C, $CC, $04, $CC, $F6, $C4, $CC, $CF, $40, $99, $A0, $84, $00, $40, $4C, $CC, $CC, $F8, $0D, $22, $62, $66, $7A, $04
	dc.b	$E9, $71, $99, $99, $9E, $DB, $F7, $BA, $7F, $ED, $BD, $D5, $75, $BB, $AD, $F2, $5B, $BB, $AA, $EF, $FB, $7F, $DB, $93, $F9, $0B, $CF, $5F, $7F, $B7, $F7, $58
	dc.b	$72, $5B, $DE, $B7, $BD, $6F, $7A, $DD, $D6, $F9, $3A, $B7, $AD, $DD, $6F, $7A, $DC, $D6, $EE, $D3, $86, $7E, $DE, $9B, $3A, $64, $D5, $6F, $7B, $4E, $19, $E4
	dc.b	$9A, $69, $A6, $FE, $56, $1A, $6E, $93, $15, $7A, $A4, $6D, $76, $CD, $E3, $6E, $69, $A6, $DE, $CF, $86, $9F, $1F, $E8, $C9, $D8, $BB, $B4, $E1, $9E, $BF, $8E
	dc.b	$9D, $F9, $A6, $9A, $6D, $56, $6F, $AD, $AB, $EC, $91, $AB, $C5, $9F, $69, $BA, $70, $FD, $D4, $9F, $D7, $D3, $84, $D3, $67, $BB, $AB, $F6, $ED, $93, $7F, $0D
	dc.b	$37, $6A, $5D, $5C, $CB, $EC, $E9, $BD, $FB, $7D, $38, $6F, $CD, $34, $D6, $36, $4D, $FA, $AA, $FE, $8A, $DB, $7B, $57, $26, $19, $EC, $F1, $B7, $36, $F6, $FE
	dc.b	$1A, $7F, $6E, $B6, $C9, $FB, $AF, $E8, $C9, $55, $4B, $EC, $DE, $F4, $C3, $8C, $3F, $AF, $28, $78, $F5, $4B, $9F, $93, $F4, $D2, $AF, $3E, $1C, $9D, $58, $97
	dc.b	$BF, $DB, $76, $AB, $DC, $D5, $F6, $C4, $E9, $CC, $F0, $A0, $84, $A1, $92, $58, $A8, $05, $F1, $42, $48, $94, $42, $8A, $45, $1C, $01, $40, $34, $88, $32, $00
	dc.b	$A0, $63, $28, $A5, $4F, $0D, $2A, $A7, $30, $08, $40, $14, $F2, $81, $41, $98, $14, $14, $02, $82, $00, $AD, $02, $F2, $91, $49, $00, $63, $19, $AE, $0C, $48
	dc.b	$3C, $3A, $14, $F3, $18, $C8, $03, $19, $AE, $8A, $0A, $00, $50, $53, $22, $08, $32, $80, $D7, $06, $40, $20, $55, $96, $A0, $51, $56, $01, $08, $14, $79, $0A
	dc.b	$3C, $D1, $47, $9A, $28, $C9, $44, $A2, $8F, $34, $51, $BF, $65, $69, $3F, $F9, $1C, $9F, $DC, $7D, $F7, $DF, $B2, $37, $E3, $B3, $FF, $9F, $FC, $B2, $35, $F2
	dc.b	$BE, $FB, $EF, $BF, $5E, $3B, $2B, $2F, $F9, $97, $AB, $3E, $FB, $F7, $B9, $4B, $A2, $3A, $F5, $AB, $FF, $72, $CF, $E6, $3E, $FB, $E2, $82, $10, $21, $01, $01
	dc.b	$01, $8E, $28, $24, $64, $A4, $54, $7B, $14, $95, $A2, $A1, $71, $EC, $84, $95, $8A, $0F, $29, $20, $0A, $45, $22, $80, $5E, $83, $C2, $02, $02, $8A, $4A, $1E
	dc.b	$53, $D0, $05, $02, $90, $50, $53, $5C, $05, $21, $4A, $A9, $10, $80, $08, $50, $02, $90, $05, $25, $01, $00, $A0, $06, $95, $00, $84, $02, $00, $A4, $10, $CC
	dc.b	$02, $8A, $01, $01, $4C, $88, $A0, $80, $42, $91, $01, $45, $22, $81, $48, $21, $00, $83, $DA, $E0, $3B, $63, $48, $A2, $80, $40, $50, $40, $74, $0E, $81, $41
	dc.b	$08, $6D, $A9, $14, $8A, $01, $79, $40, $20, $20, $20, $3C, $04, $15, $48, $98, $80, $A0, $82, $9E, $51, $8A, $09, $D2, $34, $D0, $03, $A1, $40, $26, $34, $90
	dc.b	$E8, $A3, $45, $06, $27, $B6, $A3, $01, $45, $18, $0D, $23, $48, $80, $A2, $80, $4C, $14, $02, $83, $A0, $41, $5B, $74, $02, $A9, $14, $50, $29, $14, $02, $F4
	dc.b	$00, $40, $40, $74, $0A, $0F, $01, $30, $14, $53, $C2, $83, $B6, $28, $34, $8A, $0F, $01, $41, $3E, $02, $F0, $9A, $0B, $C2, $66, $60, $34, $89, $99, $9A, $09
	dc.b	$9B, $C2, $66, $66, $66, $66, $60, $28, $34, $88, $28, $C0, $51, $4F, $0A, $0E, $D8, $A2, $9E, $14, $56, $DA, $80, $4F, $6D, $FA, $AA, $6F, $47, $FE, $B9, $2D
	dc.b	$DD, $FB, $6B, $BF, $ED, $6F, $93, $AA, $F3, $64, $A9, $AB, $E6, $5B, $5F, $CF, $DB, $FC, $AF, $E3, $5D, $A7, $0F, $E3, $72, $7F, $1B, $91, $AB, $EC, $5F, $F4
	dc.b	$64, $FE, $8C, $9F, $D1, $CE, $BF, $E8, $EF, $D7, $C5, $BD, $87, $F2, $BF, $CF, $A5, $B2, $74, $E1, $9F, $AE, $CA, $AA, $FE, $8A, $F5, $2F, $52, $DB, $FB, $A5
	dc.b	$EF, $AF, $D2, $ED, $38, $7E, $A3, $3E, $1A, $7C, $6C, $FD, $D6, $15, $55, $55, $5D, $0D, $D3, $FA, $9F, $DD, $4D, $A7, $FC, $EB, $6D, $9B, $F8, $7F, $46, $4A
	dc.b	$AA, $AA, $CE, $B9, $A6, $D3, $FE, $75, $FF, $2B, $0D, $3A, $AF, $55, $55, $5F, $E7, $C2, $69, $BD, $3F, $AF, $27, $EE, $B0, $D2, $DE, $8A, $AA, $C3, $A6, $C6
	dc.b	$FE, $DF, $D3, $0C, $F3, $4D, $A7, $FC, $EB, $CF, $26, $7F, $4B, $BA, $E4, $CF, $56, $AB, $D9, $EF, $67, $C2, $69, $A6, $9B, $B7, $4F, $8D, $7D, $FC, $34, $C9
	dc.b	$B2, $19, $D7, $9C, $A8, $F4, $B7, $2D, $17, $75, $4B, $46, $F7, $54, $A2, $43, $BD, $FA, $65, $17, $27, $54, $AA, $F1, $B6, $C6, $31, $8C, $63, $18, $CD, $70
	dc.b	$C8, $0C, $63, $18, $90, $06, $23, $18, $C6, $6B, $84, $01, $8C, $63, $18, $C6, $31, $94, $03, $18, $A2, $66, $B9, $31, $99, $09, $90, $21, $8A, $38, $12, $A2
	dc.b	$C9, $16, $48, $95, $B0, $62, $A3, $8B, $36, $CC, $91, $3F, $1F, $44, $7D, $15, $B6, $AB, $6D, $56, $DA, $28, $F6, $8A, $37, $DF, $7D, $F7, $DF, $7D, $F7, $DF
	dc.b	$7F, $69, $AF, $BE, $FB, $EF, $C9, $1C, $4A, $AF, $19, $2A, $BD, $62, $1B, $D1, $C5, $7A, $38, $AF, $56, $2D, $A8, $CB, $A2, $3C, $80, $C6, $31, $82, $50, $28
	dc.b	$10, $96, $68, $84, $84, $98, $C6, $30, $98, $C6, $28, $98, $C6, $31, $8C, $51, $09, $6B, $C5, $44, $42, $4A, $06, $31, $8C, $A0, $99, $44, $4C, $C8, $19, $01
	dc.b	$81, $AE, $0C, $63, $35, $CA, $80, $CC, $0A, $01, $08, $03, $04, $04, $18, $0C, $63, $21, $A0, $76, $D4, $8A, $01, $05, $02, $80, $43, $5C, $32, $04, $22, $CC
	dc.b	$99, $10, $5E, $10, $83, $C2, $82, $82, $94, $00, $D3, $90, $33, $52, $28, $2F, $29, $04, $15, $48, $99, $C0, $05, $20, $82, $F0, $BC, $26, $02, $67, $A0, $76
	dc.b	$C5, $14, $02, $0A, $0C, $8F, $66, $A5, $4F, $0B, $CA, $41, $05, $00, $99, $BC, $2F, $08, $28, $15, $4A, $80, $69, $50, $40, $14, $60, $20, $26, $02, $63, $48
	dc.b	$9A, $08, $2A, $91, $3A, $54, $03, $48, $99, $99, $D2, $26, $83, $C0, $50, $69, $13, $41, $30, $50, $0A, $08, $64, $7B, $35, $2A, $78, $5E, $80, $08, $28, $15
	dc.b	$77, $55, $DD, $57, $5B, $BA, $DF, $8D, $BB, $AD, $F8, $E9, $ED, $FE, $56, $D3, $57, $57, $F4, $56, $D5, $FF, $46, $4B, $AD, $FF, $5F, $AB, $FA, $FF, $A8, $FD
	dc.b	$D2, $F7, $EF, $36, $4F, $E8, $C9, $FD, $19, $3F, $A2, $BF, $E8, $AE, $69, $97, $9E, $4E, $9D, $2D, $5B, $6F, $54, $BE, $C5, $F6, $49, $FD, $19, $A6, $9B, $F7
	dc.b	$58, $6F, $E1, $8B, $6A, $AA, $AA, $FF, $3E, $13, $4D, $86, $7E, $DD, $3C, $95, $FA, $70, $E6, $AF, $D8, $BA, $BA, $6C, $C5, $C9, $E9, $DB, $9E, $69, $BF, $53
	dc.b	$A7, $F6, $EB, $CE, $BE, $9E, $D6, $DE, $DF, $EC, $93, $B3, $A6, $F4, $D3, $4D, $A7, $FC, $F9, $FB, $74, $FE, $DE, $BF, $4E, $15, $2F, $B3, $7B, $B7, $F7, $5F
	dc.b	$E7, $D3, $34, $D3, $69, $FF, $3D, $55, $59, $D7, $A7, $0E, $9B, $3C, $74, $F6, $CD, $34, $DC, $D6, $67, $AA, $A5, $F6, $7E, $EA, $BF, $27, $A6, $1B, $F3, $4D
	dc.b	$9F, $0F, $E4, $0D, $ED, $F2, $D5, $7B, $57, $46, $AB, $37, $E4, $CF, $66, $9E, $DF, $E5, $4C, $C8, $A0, $4A, $E2, $A3, $88, $62, $15, $C4, $31, $29, $71, $0C
	dc.b	$42, $59, $F0, $94, $A0, $57, $5B, $94, $84, $A8, $0C, $C5, $00, $C8, $59, $89, $9C, $50, $26, $50, $59, $89, $8C, $CC, $59, $89, $94, $44, $C6, $31, $9A, $E4
	dc.b	$CC, $84, $25, $AE, $5A, $E4, $C8, $02, $8A, $82, $63, $28, $2A, $22, $A0, $A0, $42, $4C, $C8, $4C, $51, $0E, $CC, $91, $64, $2C, $84, $24, $24, $C8, $95, $B1
	dc.b	$45, $98, $94, $50, $8A, $3B, $D1, $47, $7A, $28, $EF, $45, $5A, $BC, $55, $AB, $EC, $8E, $B8, $C5, $1D, $7D, $95, $BA, $1A, $FB, $EF, $E2, $BC, $DE, $86, $ED
	dc.b	$35, $6D, $AF, $A9, $F7, $DF, $E8, $6B, $F2, $36, $46, $C8, $D5, $B5, $FC, $4B, $6B, $F6, $46, $FB, $EF, $BE, $FB, $EF, $C7, $10, $94, $36, $50, $4B, $AC, $50
	dc.b	$29, $23, $D8, $AB, $23, $28, $59, $1C, $4A, $B2, $38, $95, $5E, $32, $63, $28, $26, $31, $8C, $63, $33, $13, $20, $0C, $50, $31, $9B, $18, $C6, $08, $08, $66
	dc.b	$48, $02, $82, $01, $42, $33, $30, $31, $99, $83, $20, $30, $42, $84, $80, $08, $08, $31, $94, $03, $03, $33, $D9, $9E, $CC, $8C, $08, $02, $83, $20, $64, $46
	dc.b	$06, $B8, $28, $19, $98, $04, $04, $19, $91, $E5, $00, $80, $85, $0F, $08, $08, $43, $6C, $42, $08, $20, $21, $07, $99, $00, $10, $C8, $82, $0A, $01, $41, $D0
	dc.b	$26, $82, $02, $03, $C0, $5E, $10, $10, $17, $A8, $01, $01, $01, $45, $24, $00, $4C, $07, $6C, $4C, $CC, $D0, $50, $50, $50, $50, $50, $4C, $50, $5E, $55, $30
	dc.b	$3A, $44, $07, $42, $B4, $08, $2A, $91, $01, $3A, $47, $80, $80, $E8, $1A, $54, $67, $C0, $40, $5E, $13, $3D, $B1, $DB, $17, $84, $D0, $78, $0B, $C3, $C0, $57
	dc.b	$D7, $67, $5B, $EB, $E9, $5F, $4E, $17, $61, $9F, $0C, $F8, $69, $9A, $EB, $7B, $D6, $E6, $E4, $B7, $72, $FA, $EB, $E2, $AF, $D3, $66, $FD, $DA, $70, $CF, $86
	dc.b	$7E, $DE, $4C, $33, $E9, $DE, $EA, $FD, $BF, $ED, $B7, $BF, $ED, $FB, $6B, $3A, $EC, $EB, $FF, $56, $1E, $97, $69, $FD, $BD, $BF, $F3, $DB, $BA, $DF, $8D, $BF
	dc.b	$F3, $F5, $7F, $5E, $AE, $B5, $E2, $DF, $AF, $8A, $EC, $3A, $6C, $DE, $F4, $C3, $A6, $69, $A6, $AA, $AA, $AF, $6A, $E9, $AE, $DD, $EF, $4E, $95, $FF, $5F, $4E
	dc.b	$13, $55, $56, $29, $2A, $AB, $9A, $F6, $AD, $F5, $EF, $D9, $BD, $FA, $8C, $37, $F9, $AB, $D5, $55, $55, $55, $67, $5E, $7B, $D8, $BF, $95, $E9, $75, $EC, $EB
	dc.b	$CF, $55, $55, $55, $55, $53, $6F, $FA, $7E, $DF, $12, $DB, $5F, $B1, $75, $55, $55, $53, $4C, $BE, $9C, $3F, $50, $DA, $FD, $3A, $AF, $55, $55, $53, $4D, $36
	dc.b	$FE, $1E, $9C, $8B, $FD, $D6, $1A, $6E, $6D, $ED, $FE, $C5, $D5, $77, $54, $B4, $6F, $5B, $94, $21, $BD, $D5, $2A, $8B, $93, $AA, $55, $7E, $DE, $DC, $AA, $DF
	dc.b	$C3, $D2, $E5, $59, $9E, $48, $B5, $57, $26, $30, $98, $C8, $13, $20, $42, $43, $10, $F1, $40, $B5, $C1, $8C, $62, $89, $8C, $63, $18, $1A, $E4, $C6, $31, $8C
	dc.b	$81, $32, $82, $63, $18, $C1, $2C, $C5, $98, $98, $0C, $A0, $B2, $10, $92, $A2, $51, $64, $8B, $5C, $A1, $16, $42, $1D, $8A, $8A, $3B, $38, $A3, $B3, $BA, $39
	dc.b	$04, $86, $2A, $CB, $25, $45, $CA, $4A, $D9, $5B, $FB, $75, $8A, $88, $A3, $7D, $F7, $DF, $7D, $F8, $FA, $23, $7D, $6D, $5B, $6F, $36, $C6, $DE, $6B, $EF, $BE
	dc.b	$FB, $EF, $D7, $6B, $FB, $4D, $AE, $D9, $1B, $D1, $AA, $F3, $56, $DA, $ED, $AF, $89, $F7, $DF, $7D, $FA, $ED, $7D, $F7, $D7, $1E, $CB, $D1, $C5, $D1, $1B, $EF
	dc.b	$BE, $FB, $EC, $66, $CC, $D1, $C4, $24, $24, $2B, $8E, $21, $25, $2E, $B1, $51, $24, $71, $42, $C8, $F6, $08, $31, $99, $01, $94, $06, $40, $63, $18, $C6, $30
	dc.b	$20, $19, $91, $82, $14, $06, $40, $60, $64, $01, $0D, $70, $C8, $0C, $C8, $02, $19, $91, $8A, $0D, $70, $10, $50, $64, $06, $30, $33, $52, $21, $00, $A0, $05
	dc.b	$19, $40, $08, $41, $14, $02, $14, $22, $82, $84, $10, $10, $CC, $10, $01, $08, $3C, $20, $A4, $A0, $18, $02, $14, $04, $11, $5C, $04, $04, $14, $0A, $79, $40
	dc.b	$2F, $50, $82, $0A, $35, $20, $BC, $A4, $14, $10, $13, $1A, $46, $95, $00, $A0, $F0, $13, $DB, $13, $05, $20, $80, $80, $E8, $52, $0E, $81, $E1, $07, $85, $05
	dc.b	$E1, $79, $5B, $62, $03, $B6, $26, $02, $0A, $31, $05, $1E, $81, $01, $78, $74, $08, $2A, $91, $DB, $1D, $B1, $33, $A4, $4D, $2E, $B7, $75, $BD, $EF, $D3, $5D
	dc.b	$D5, $77, $ED, $AE, $B7, $FD, $7F, $D4, $76, $E7, $C3, $F7, $4B, $CE, $BC, $EF, $D9, $89, $78, $AB, $B5, $78, $B9, $2D, $F2, $7F, $1A, $EB, $77, $5B, $FD, $BF
	dc.b	$EE, $33, $E1, $FF, $AE, $97, $EC, $6D, $E6, $BE, $BF, $1D, $3B, $D6, $FF, $CF, $FA, $8C, $3F, $51, $77, $F2, $97, $BF, $79, $B5, $FF, $A2, $BE, $C5, $F6, $4D
	dc.b	$34, $D9, $FB, $7C, $6C, $FE, $56, $2D, $AA, $AA, $9A, $69, $A6, $FD, $CF, $A6, $F2, $FA, $57, $D2, $FD, $53, $4D, $34, $D3, $6F, $FE, $E7, $D2, $F7, $4E, $A5
	dc.b	$B6, $CF, $4E, $DF, $DD, $7F, $9F, $4C, $D3, $4D, $FA, $8F, $1F, $F5, $60, $FD, $7E, $6C, $3F, $75, $64, $D3, $4D, $36, $1E, $9E, $32, $7E, $EB, $B6, $A9, $3F
	dc.b	$A3, $76, $9E, $DF, $DD, $4D, $34, $D3, $7A, $7F, $5E, $AA, $B3, $D9, $CD, $76, $9C, $37, $D7, $9D, $7F, $B7, $FD, $46, $13, $4D, $35, $55, $54, $FF, $6F, $F6
	dc.b	$BC, $74, $F6, $CD, $37, $32, $DB, $26, $25, $F3, $2D, $AB, $6A, $DA, $BC, $4B, $6C, $8D, $5B, $5F, $5F, $EA, $77, $F0, $DF, $9B, $F6, $F6, $F9, $08, $76, $2B
	dc.b	$88, $48, $48, $57, $FE, $B5, $FF, $AE, $4E, $E1, $E9, $0E, $2D, $37, $69, $B8, $36, $7E, $DE, $50, $89, $8C, $60, $C5, $44, $4A, $2A, $22, $12, $A0, $84, $98
	dc.b	$4C, $63, $35, $C9, $8C, $51, $40, $99, $41, $32, $04, $C6, $33, $31, $31, $84, $C6, $50, $5A, $E5, $AE, $42, $42, $4A, $89, $8C, $C8, $54, $10, $F1, $28, $87
	dc.b	$88, $62, $1D, $90, $FE, $DA, $88, $76, $66, $D9, $9B, $66, $68, $86, $B6, $D5, $6D, $A8, $A3, $BD, $15, $6A, $FB, $2B, $58, $3B, $2B, $49, $08, $B9, $55, $C5
	dc.b	$59, $F7, $DF, $7D, $F7, $EF, $62, $5C, $6F, $D9, $8A, $C6, $AD, $AB, $6A, $DB, $66, $2D, $A6, $D8, $DE, $8D, $4B, $C5, $63, $56, $D5, $E2, $93, $52, $DB, $23
	dc.b	$5F, $5B, $5F, $6D, $E6, $AD, $B6, $35, $6D, $91, $AB, $6B, $EF, $B6, $46, $BF, $24, $71, $0D, $E8, $E2, $E8, $8D, $F7, $DF, $7D, $F2, $D7, $21, $2C, $D1, $EC
	dc.b	$A2, $B6, $C8, $49, $1C, $50, $B2, $B4, $43, $7A, $B1, $74, $46, $C6, $31, $8C, $21, $2C, $D1, $28, $A1, $B1, $99, $00, $41, $41, $40, $31, $8C, $63, $35, $D0
	dc.b	$43, $30, $28, $14, $02, $0C, $52, $32, $00, $A0, $64, $01, $49, $98, $19, $00, $C8, $F6, $60, $CD, $4A, $80, $41, $41, $AE, $82, $02, $1A, $F4, $88, $0A, $40
	dc.b	$14, $94, $02, $90, $42, $08, $28, $20, $A4, $10, $10, $10, $CC, $8A, $DB, $14, $A1, $04, $04, $04, $32, $02, $80, $41, $40, $A4, $82, $08, $08, $08, $40, $C0
	dc.b	$41, $40, $28, $20, $34, $8B, $C2, $F0, $A0, $A0, $D2, $3B, $6A, $D0, $28, $20, $28, $3A, $14, $82, $83, $48, $A0, $80, $BD, $07, $85, $E1, $35, $52, $3B, $62
	dc.b	$F2, $90, $41, $40, $20, $20, $3A, $04, $C0, $5E, $1D, $B5, $3C, $28, $20, $2F, $0D, $30, $D0, $34, $89, $9F, $01, $A4, $69, $1D, $02, $F0, $BC, $34, $A8, $DE
	dc.b	$1D, $AC, $5B, $4D, $DA, $6F, $43, $5F, $93, $F9, $56, $7F, $EB, $4E, $F7, $F2, $1B, $7B, $56, $D3, $6F, $35, $78, $A4, $6C, $98, $BA, $1A, $FF, $FE, $BF, $D1
	dc.b	$84, $9F, $D1, $5D, $5D, $72, $76, $2F, $99, $FA, $FB, $EB, $FE, $57, $F2, $7F, $51, $55, $52, $76, $49, $D6, $FF, $47, $FE, $B3, $FF, $A3, $0A, $AA, $C4, $BA
	dc.b	$BA, $D7, $D9, $B5, $8B, $F7, $55, $FF, $93, $D3, $55, $55, $55, $55, $5B, $58, $BF, $95, $67, $5D, $95, $55, $55, $55, $54, $FE, $D6, $FF, $F4, $57, $55, $55
	dc.b	$54, $D9, $3F, $A3, $7B, $56, $FE, $1F, $A8, $DE, $AF, $D3, $87, $62, $EA, $D4, $BA, $AA, $AB, $9A, $6C, $3D, $3C, $6F, $74, $EA, $BD, $55, $55, $55, $34, $D9
	dc.b	$F0, $D3, $E3, $27, $F2, $B0, $6E, $D6, $7E, $BB, $2A, $AB, $F6, $FD, $5F, $D7, $EA, $9B, $7B, $F5, $1C, $9D, $5F, $BA, $C3, $D2, $EA, $F9, $D7, $BF, $8B, $6B
	dc.b	$52, $DB, $67, $ED, $ED, $CA, $AB, $BA, $AE, $EA, $94, $77, $BF, $ED, $FD, $6F, $EB, $F5, $76, $FA, $5D, $FA, $8F, $DD, $7E, $E5, $F8, $84, $A8, $88, $4A, $88
	dc.b	$94, $50, $94, $86, $28, $5B, $94, $4A, $8E, $A9, $62, $12, $1B, $AD, $CA, $54, $67, $BA, $DC, $AC, $51, $40, $A0, $50, $8B, $21, $09, $64, $88, $49, $8C, $63
	dc.b	$04, $98, $A2, $D7, $25, $13, $28, $26, $66, $26, $30, $4A, $04, $24, $C1, $26, $31, $84, $C6, $09, $30, $4A, $88, $B2, $16, $62, $D7, $2A, $09, $44, $24, $A2
	dc.b	$62, $BB, $A8, $E2, $87, $75, $1C, $59, $B6, $66, $D9, $92, $2A, $38, $AB, $5E, $69, $56, $AE, $DE, $2A, $D2, $77, $72, $FF, $AE, $3F, $FD, $8C, $43, $FF, $BE
	dc.b	$29, $1A, $B6, $C9, $AA, $C6, $AD, $AB, $6D, $9A, $96, $DA, $F8, $A3, $BD, $88, $AB, $5E, $8A, $B5, $7D, $9C, $B2, $35, $78, $A4, $6D, $76, $AD, $B2, $75, $C9
	dc.b	$A9, $75, $62, $93, $9A, $4D, $52, $36, $BB, $6F, $35, $6D, $7D, $F7, $F1, $2D, $B5, $F1, $2F, $15, $9A, $96, $DB, $1A, $B6, $C9, $A9, $6D, $AF, $89, $F7, $DF
	dc.b	$7D, $F6, $AD, $AB, $6D, $9F, $D1, $93, $AE, $46, $BE, $FC, $8D, $7D, $F7, $DF, $DA, $6E, $D5, $6E, $25, $2E, $B7, $10, $DE, $AC, $5D, $11, $BE, $FB, $EF, $D0
	dc.b	$4C, $84, $59, $23, $E2, $51, $2F, $97, $8A, $CE, $58, $AF, $72, $F4, $47, $90, $33, $12, $82, $82, $63, $20, $50, $28, $6C, $84, $51, $F7, $33, $31, $32, $80
	dc.b	$65, $01, $98, $A0, $0C, $60, $80, $82, $9E, $10, $63, $20, $0C, $D7, $0A, $03, $20, $66, $A7, $5D, $E1, $45, $05, $00, $21, $40, $30, $04, $04, $20, $0C, $D7
	dc.b	$01, $30, $50, $41, $28, $0D, $7A, $44, $14, $90, $01, $08, $02, $80, $42, $80, $55, $22, $02, $82, $02, $F2, $91, $40, $A0, $17, $94, $02, $19, $9E, $86, $85
	dc.b	$68, $82, $2B, $82, $82, $09, $00, $82, $08, $64, $05, $00, $A5, $0F, $0A, $08, $66, $01, $0C, $87, $B6, $20, $34, $8E, $D8, $E8, $14, $1A, $47, $40, $A0, $9E
	dc.b	$DD, $08, $C1, $0A, $11, $48, $AE, $02, $F2, $81, $4F, $28, $05, $EA, $11, $57, $7F, $DB, $FE, $DF, $E6, $BA, $DD, $DF, $F6, $FF, $35, $DF, $F6, $FF, $B7, $F9
	dc.b	$AE, $B7, $FB, $7F, $E3, $72, $7E, $9A, $EF, $FB, $7F, $DB, $FE, $DD, $57, $7F, $1A, $EF, $FB, $7E, $9A, $6E, $4B, $7B, $DF, $A6, $DE, $B7, $75, $BB, $BF, $4D
	dc.b	$C9, $FA, $6E, $4B, $7B, $D6, $EE, $FD, $35, $DF, $A6, $BA, $DF, $F9, $FA, $B9, $2D, $CD, $FB, $7B, $7C, $96, $FF, $CF, $6E, $6E, $AF, $1B, $77, $5B, $9B, $FA
	dc.b	$FD, $5E, $36, $E6, $BA, $DC, $D7, $5B, $9A, $6F, $F3, $DB, $BA, $DC, $D3, $5B, $DE, $FD, $47, $EA, $77, $E6, $9A, $6F, $EB, $DB, $F1, $FD, $37, $8D, $BB, $AD
	dc.b	$F8, $DB, $BA, $DD, $DF, $DA, $5E, $7B, $BF, $71, $FA, $99, $A6, $9A, $69, $A6, $E9, $BD, $FB, $9F, $DD, $4D, $34, $DC, $96, $E6, $9B, $F6, $ED, $5F, $F4, $7A
	dc.b	$1B, $BD, $FB, $8C, $33, $CD, $34, $D3, $4D, $52, $FB, $30, $FE, $54, $9B, $DF, $B8, $ED, $9A, $69, $A6, $AA, $AD, $A6, $AF, $0F, $E5, $49, $FA, $8E, $DE, $9F
	dc.b	$EB, $FA, $4D, $35, $55, $55, $7B, $56, $FE, $D7, $EA, $7F, $74, $BE, $4F, $D4, $76, $CC, $DE, $86, $F4, $6A, $5E, $A5, $E2, $5F, $5B, $EB, $DF, $B3, $3A, $F0
	dc.b	$FF, $57, $ED, $F4, $E1, $A7, $0B, $0A, $8A, $E4, $0A, $BC, $40, $37, $A2, $1D, $A8, $B6, $A2, $E8, $2C, $34, $E1, $FB, $AC, $04, $19, $90, $99, $AE, $43, $12
	dc.b	$80, $4B, $30, $0C, $59, $38, $C9, $8C, $81, $31, $9A, $E5, $AE, $4A, $28, $44, $C6, $31, $8A, $26, $33, $31, $40, $98, $C6, $32, $82, $51, $32, $82, $C9, $16
	dc.b	$B9, $33, $34, $59, $09, $85, $98, $99, $AF, $B2, $8E, $28, $44, $A2, $57, $10, $90, $EC, $18, $95, $C4, $AE, $28, $45, $41, $50, $4A, $2A, $38, $A8, $28, $12
	dc.b	$BB, $AB, $2C, $7F, $D6, $24, $AF, $ED, $8C, $43, $12, $88, $48, $78, $94, $42, $50, $2A, $0A, $05, $02, $7E, $B6, $D7, $17, $2A, $FF, $B7, $5B, $FF, $7F, $FB
	dc.b	$FF, $DC, $43, $10, $C4, $DB, $D8, $AC, $6B, $F5, $E3, $E8, $E5, $BC, $5F, $CC, $93, $8B, $F7, $9F, $EB, $8F, $FA, $32, $7F, $46, $BE, $25, $E2, $BC, $D7, $D7
	dc.b	$89, $FD, $A6, $AE, $B6, $D3, $5F, $AE, $D9, $39, $AB, $E2, $5E, $AB, $3B, $2C, $C5, $27, $5A, $F5, $2D, $AB, $6A, $F5, $3E, $FB, $7A, $31, $6D, $73, $2D, $B2
	dc.b	$6A, $5B, $56, $D5, $D4, $D5, $E2, $B1, $AF, $BE, $FB, $EF, $B5, $78, $AB, $D5, $A9, $7C, $CB, $E5, $E2, $AF, $CA, $4F, $BE, $FB, $EF, $BF, $10, $95, $1C, $54
	dc.b	$7F, $33, $65, $9F, $CC, $7D, $F7, $DF, $63, $22, $C9, $FD, $B5, $7E, $F3, $8A, $4F, $DE, $45, $B5, $59, $F8, $02, $81, $40, $21, $90, $14, $02, $10, $48, $16
	dc.b	$40, $D9, $9A, $3E, $E5, $2F, $97, $89, $40, $A0, $60, $85, $01, $00, $10, $1A, $68, $A5, $8A, $01, $08, $13, $06, $91, $A5, $40, $A0, $85, $22, $94, $04, $00
	dc.b	$69, $63, $32, $00, $A6, $40, $C8, $82, $0A, $41, $05, $6D, $B0, $41, $40, $C0, $D7, $01, $78, $69, $51, $99, $9E, $81, $34, $51, $8A, $50, $90, $01, $0C, $80
	dc.b	$A0, $A0, $14, $F2, $90, $42, $01, $03, $05, $7F, $DB, $FE, $D6, $FF, $01, $D5, $FA, $0B, $7F, $90, $B7, $3C, $F3, $CF, $FC, $0F, $FB, $7F, $DB, $FE, $DF, $90
	dc.b	$FE, $B7, $E4, $25, $FE, $37, $E4, $38, $FF, $01, $FA, $6F, $E0, $7E, $9B, $FC, $1F, $A6, $DE, $B7, $BD, $FA, $6E, $4F, $F3, $5D, $FE, $6B, $BF, $ED, $77, $F9
	dc.b	$AE, $FE, $37, $8D, $BE, $4D, $38, $69, $FC, $05, $BB, $AD, $DD, $6F, $92, $DD, $DF, $E6, $E4, $B7, $77, $FD, $BF, $ED, $FE, $6F, $1B, $7E, $33, $CD, $6E, $EB
	dc.b	$73, $7E, $DF, $AA, $69, $AE, $FD, $47, $EA, $74, $FE, $E7, $A7, $0F, $ED, $2F, $92, $DD, $DF, $A6, $BA, $DE, $F5, $BF, $DB, $DB, $BB, $F8, $DF, $D7, $B7, $77
	dc.b	$EE, $2E, $D3, $76, $9F, $ED, $61, $D2, $BF, $E5, $3F, $34, $D3, $4D, $FD, $9F, $FD, $49, $9D, $F9, $31, $2D, $AB, $9A, $69, $BF, $51, $77, $A7, $6F, $4E, $1F
	dc.b	$BA, $5F, $4B, $F2, $6A, $B3, $9A, $69, $A6, $FF, $CF, $FE, $BA, $33, $F3, $57, $AA, $69, $A6, $C3, $D3, $F9, $3F, $FA, $FE, $D2, $F3, $BE, $DB, $D8, $A6, $9A
	dc.b	$6F, $EC, $6F, $7F, $6B, $0D, $3B, $F5, $FF, $20, $FE, $AB, $D3, $4D, $34, $DF, $A8, $C3, $F7, $16, $67, $FD, $CD, $EF, $C0, $3F, $24, $DC, $9F, $D6, $DE, $FE
	dc.b	$36, $F7, $F5, $B9, $2D, $FE, $DF, $B7, $93, $D3, $07, $F6, $B1, $6F, $7F, $62, $DF, $F9, $ED, $FF, $9F, $F4, $D7, $75, $4D, $BD, $A7, $0D, $3D, $BF, $A8, $93
	dc.b	$FB, $5A, $AF, $69, $EA, $96, $8D, $EE, $AE, $30, $1F, $DB, $F5, $71, $F2, $7F, $1B, $F6, $FF, $B6, $FD, $47, $8E, $1D, $38, $67, $ED, $FF, $D4, $09, $8A, $21
	dc.b	$97, $5E, $DF, $E8, $E8, $FD, $37, $E8, $D5, $BD, $FD, $6F, $D4, $61, $E9, $BD, $FE, $AC, $18, $C6, $09, $50, $4A, $26, $66, $2B, $B8, $E0, $43, $86, $9D, $EF
	dc.b	$D9, $B0, $4A, $04, $31, $51, $13, $19, $41, $6B, $95, $12, $93, $28, $89, $44, $C8, $13, $09, $45, $02, $61, $64, $2C, $9B, $04, $A8, $25, $45, $02, $51, $2B
	dc.b	$62, $B6, $0C, $4A, $21, $8A, $82, $A0, $B5, $C8, $4A, $82, $81, $66, $26, $31, $83, $10, $93, $05, $04, $84, $A8, $21, $D9, $0D, $83, $12, $BF, $B6, $25, $02
	dc.b	$51, $40, $84, $A8, $25, $13, $18, $C8, $6C, $1E, $25, $10, $F1, $28, $87, $8A, $04, $A8, $A0, $4A, $89, $90, $25, $44, $AE, $25, $17, $F3, $24, $E2, $FD, $E7
	dc.b	$FA, $E3, $FF, $DF, $FA, $D4, $43, $FE, $B5, $77, $09, $0C, $42, $57, $B5, $3F, $FB, $CA, $FD, $DC, $BF, $FB, $FF, $DC, $4A, $EE, $1D, $82, $42, $D5, $F3, $2D
	dc.b	$B2, $73, $2D, $B2, $7F, $46, $3E, $8F, $DE, $57, $8B, $F7, $92, $7F, $6E, $B0, $FF, $AE, $AA, $AA, $D4, $BE, $6A, $FC, $CF, $D6, $DA, $2F, $F6, $6A, $BD, $AA
	dc.b	$BF, $5D, $7E, $65, $B5, $78, $97, $D9, $23, $57, $AA, $F3, $56, $D7, $DB, $D1, $8B, $A3, $52, $DB, $26, $A5, $D5, $55, $5C, $D5, $F9, $9F, $7E, $46, $DE, $6A
	dc.b	$DB, $7B, $14, $8D, $5F, $65, $9A, $97, $AA, $46, $AF, $AE, $CE, $52, $8F, $6A, $B3, $EB, $6A, $DB, $79, $AB, $6D, $7E, $6A, $ED, $93, $14, $9C, $CB, $C4, $B6
	dc.b	$F7, $43, $97, $BA, $4F, $E6, $13, $EF, $C8, $D7, $EB, $B6, $46, $DE, $63, $3F, $F7, $FF, $C7, $DF, $6A, $DB, $D0, $DB, $1A, $B1, $08, $06, $40, $62, $83, $FF
	dc.b	$7F, $CC, $D9, $5E, $35, $D6, $7D, $B2, $36, $B8, $0E, $D8, $BC, $A4, $14, $80, $64, $7B, $B9, $41, $CB, $DC, $BF, $E6, $45, $B5, $59, $40, $A0, $66, $40, $80
	dc.b	$08, $0D, $34, $52, $C5, $00, $84, $0B, $5F, $FC, $16, $E7, $9E, $79, $E7, $9E, $7F, $C8, $2F, $F0, $15, $FF, $21, $5F, $3A, $FF, $21, $B5, $3C, $F3, $CF, $3A
	dc.b	$DA, $B6, $AD, $B5, $DA, $FD, $EF, $D8, $58, $DF, $E0, $59, $FC, $0B, $3F, $60, $BF, $C0, $49, $FE, $0D, $A6, $AD, $AB, $C4, $BC, $5B, $4D, $B3, $14, $8D, $93
	dc.b	$FA, $2B, $6D, $76, $AF, $15, $EC, $4F, $ED, $67, $93, $55, $7C, $4B, $D5, $67, $34, $8D, $5E, $AB, $D8, $B6, $9B, $D0, $DE, $8A, $AA, $A9, $7D, $8B, $EC, $5F
	dc.b	$34, $9D, $6B, $D4, $BA, $B6, $B1, $6D, $62, $7D, $FB, $3F, $81, $67, $F0, $2C, $FE, $05, $9F, $C0, $6A, $F1, $57, $6A, $DB, $5F, $F0, $0D, $DA, $FC, $05, $9F
	dc.b	$90, $5F, $E4, $17, $F8, $05, $CF, $3C, $FF, $C0, $AF, $F8, $05, $FE, $C1, $7F, $B0, $5C, $F3, $CF, $3C, $F3, $AF, $F8, $12, $4F, $3C, $F3, $CF, $3C, $F6, $35
	dc.b	$F6, $D9, $F9, $0D, $AF, $D8, $57, $9E, $79, $E7, $CE, $FA, $DB, $D1, $AA, $46, $D9, $89, $78, $AC, $C5, $23, $6C, $EB, $BD, $AA, $CE, $BE, $8C, $EF, $EA, $93
	dc.b	$12, $EA, $D4, $BA, $AA, $AB, $9B, $7F, $B7, $D3, $7A, $F7, $4B, $57, $AA, $4C, $F5, $76, $2E, $AE, $C5, $D5, $77, $1F, $E0, $0A, $18, $69, $BB, $F4, $6A, $E9
	dc.b	$C3, $4D, $DC, $75, $F7, $F0, $BB, $6B, $F2, $1B, $5F, $90, $DA, $FC, $86, $D7, $E4, $18, $CE, $3C, $9C, $9F, $A3, $57, $F4, $38, $E7, $9E, $78, $99, $41, $50
	dc.b	$4C, $A2, $5D, $7F, $C0, $45, $9B, $F4, $0A, $01, $0F, $E8, $08, $2A, $2A, $38, $A8, $21, $E2, $66, $B9, $03, $11, $40, $21, $46, $86, $28, $32, $00, $96, $B8
	dc.b	$08, $64, $0A, $00, $52, $05, $00, $A1, $28, $2A, $3B, $94, $50, $8A, $04, $A8, $A8, $2C, $C4, $24, $24, $A2, $CD, $10, $92, $8B, $5C, $A8, $EE, $CD, $B0, $48
	dc.b	$48, $62, $54, $4A, $2C, $C4, $A2, $CC, $50, $26, $51, $10, $90, $C4, $24, $31, $09, $09, $51, $B0, $7B, $94, $4A, $28, $71, $43, $B9, $45, $92, $26, $10, $EC
	dc.b	$12, $81, $28, $A1, $15, $11, $09, $09, $42, $21, $21, $2C, $85, $41, $50, $42, $42, $4A, $21, $FF, $D9, $0F, $F6, $E0, $43, $B1, $44, $31, $32, $04, $C6, $64
	dc.b	$FE, $E4, $9C, $5F, $BC, $FF, $DE, $4D, $8C, $28, $10, $94, $0B, $21, $28, $94, $FC, $7D, $1F, $CC, $B1, $5F, $DB, $C9, $C5, $98, $98, $C5, $F5, $AD, $B7, $9A
	dc.b	$FC, $91, $7F, $73, $FD, $71, $92, $BB, $94, $43, $C5, $44, $42, $5D, $8B, $6A, $FA, $D6, $D5, $EA, $7E, $CF, $E6, $59, $B3, $F9, $9F, $FB, $FF, $DA, $DB, $7B
	dc.b	$99, $7A, $A4, $FE, $8B, $ED, $7D, $71, $ED, $7E, $F2, $BC, $5F, $CC, $B3, $15, $76, $D7, $6C, $8D, $B1, $AB, $6E, $D3, $56, $D7, $DF, $7E, $37, $DF, $E8, $D5
	dc.b	$79, $AB, $6D, $E6, $AF, $AE, $4E, $6D, $AC, $4B, $6B, $EF, $BE, $FB, $EF, $C8, $DB, $CD, $5E, $27, $DF, $BD, $FA, $09, $3F, $00, $B9, $E7, $9E, $79, $E7, $FC
	dc.b	$03, $EF, $FE, $81, $7F, $80, $B2, $79, $E7, $9E, $7A, $97, $A9, $F7, $EB, $FE, $41, $7F, $80, $AF, $3C, $F3, $D9, $FC, $0B, $3F, $81, $67, $F0, $24, $FE, $82
	dc.b	$E7, $9E, $79, $E4, $EB, $FC, $85, $8D, $5B, $7F, $21, $5F, $17, $E8, $2C, $6A, $FF, $41, $7B, $F6, $15, $FF, $61, $5F, $F6, $17, $AA, $EC, $5D, $4D, $5F, $5C
	dc.b	$8D, $5F, $34, $8D, $B3, $14, $98, $B6, $9B, $25, $55, $35, $7D, $8B, $AB, $AD, $7A, $97, $8A, $C6, $AD, $AB, $6D, $EE, $BB, $DF, $D0, $93, $FA, $12, $7F, $42
	dc.b	$4F, $E8, $49, $FD, $09, $3F, $A1, $27, $F4, $17, $FE, $03, $FC, $86, $DF, $EC, $1E, $1F, $E8, $24, $F3, $CF, $3A, $80, $40, $48, $40, $42, $11, $64, $21, $4C
	dc.b	$C5, $4D, $1F, $80, $7A, $8F, $C8, $22, $80, $7F, $40, $21, $02, $51, $50, $4C, $60, $93, $04, $B3, $13, $20, $4C, $81, $30, $48, $4B, $5C, $87, $FD, $63, $16
	dc.b	$6F, $FD, $F7, $2B, $65, $04, $C2, $A0, $B5, $CA, $11, $0C, $4C, $81, $40, $A8, $21, $21, $28, $10, $C5, $AE, $4A, $2C, $84, $A2, $66, $C6, $09, $2A, $2C, $85
	dc.b	$44, $4A, $D8, $31, $64, $25, $16, $B9, $31, $8C, $C8, $0C, $60, $90, $95, $05, $02, $12, $A0, $B5, $C9, $8C, $26, $32, $2C, $C4, $31, $31, $8C, $A2, $26, $30
	dc.b	$B3, $03, $32, $12, $89, $44, $24, $24, $A2, $D7, $21, $2C, $84, $C6, $32, $1B, $14, $4C, $63, $18, $C6, $66, $FF, $5C, $6A, $FE, $DE, $48, $99, $98, $28, $0D
	dc.b	$70, $D7, $0C, $DF, $CC, $B3, $67, $F3, $3F, $B7, $5B, $24, $4C, $63, $18, $FC, $7D, $1F, $CC, $B3, $FB, $75, $87, $FD, $79, $88, $49, $8A, $0C, $CF, $BE, $FF
	dc.b	$F3, $2C, $E2, $E5, $5F, $F6, $EB, $43, $B8, $43, $31, $55, $55, $5A, $97, $CD, $5F, $9A, $B6, $D7, $2D, $EE, $EE, $5E, $E8, $72, $F7, $49, $FD, $C7, $DF, $91
	dc.b	$AF, $F4, $36, $F0
Credits_tiles_2:
	dc.b	$00, $DD, $80, $07, $6F, $17, $70, $28, $EC, $38, $F4, $58, $E5, $74, $05, $81, $08, $E3, $82, $07, $62, $18, $F1, $83, $07, $67, $18, $E4, $85, $04, $04, $15
	dc.b	$10, $25, $11, $36, $29, $46, $2E, $57, $56, $67, $57, $73, $00, $86, $03, $01, $14, $06, $25, $12, $36, $27, $47, $5F, $57, $64, $67, $73, $76, $26, $88, $06
	dc.b	$2C, $18, $EB, $8A, $07, $6C, $18, $EA, $28, $F2, $76, $2A, $8B, $06, $2D, $17, $69, $28, $EE, $8C, $07, $65, $17, $68, $28, $EF, $38, $F0, $8D, $07, $66, $17
	dc.b	$6E, $38, $ED, $8E, $07, $5E, $17, $6A, $8F, $06, $28, $17, $6B, $27, $63, $37, $6D, $46, $30, $58, $E2, $67, $74, $74, $07, $FF, $77, $77, $77, $77, $77, $77
	dc.b	$77, $A0, $F1, $35, $17, $DD, $DD, $DD, $DC, $D1, $91, $DD, $DD, $DD, $F0, $2E, $EE, $EF, $41, $E2, $6E, $89, $D1, $1D, $DD, $DE, $7D, $B2, $4D, $B3, $BB, $BB
	dc.b	$CB, $03, $0C, $0C, $0E, $D6, $43, $81, $42, $EE, $EE, $EE, $7A, $33, $BB, $BE, $36, $E2, $6D, $B7, $F5, $CF, $0D, $66, $E7, $77, $E2, $6C, $73, $48, $08, $39
	dc.b	$E8, $7A, $37, $14, $B0, $9F, $6C, $FB, $6F, $EB, $2E, $EE, $EF, $D0, $ED, $9A, $7C, $66, $83, $8F, $9D, $0D, $09, $50, $61, $3D, $06, $B5, $06, $92, $8D, $58
	dc.b	$D7, $77, $6E, $2B, $F8, $D9, $25, $AD, $0A, $4F, $44, $4A, $4A, $25, $24, $F8, $4B, $09, $6D, $68, $6D, $64, $38, $46, $8B, $F0, $A1, $A8, $68, $39, $E8, $DC
	dc.b	$53, $ED, $BF, $8E, $2D, $8E, $93, $41, $A2, $96, $7E, $8C, $9B, $5A, $18, $DA, $38, $CD, $38, $CD, $3A, $CD, $D4, $35, $C5, $27, $AC, $C0, $00, $04, $26, $A6
	dc.b	$57, $10, $00, $11, $9F, $1C, $C5, $0C, $08, $81, $00, $0E, $29, $50, $68, $BE, $97, $C0, $00, $24, $D0, $31, $68, $30, $00, $0A, $5D, $DD, $FA, $1E, $87, $89
	dc.b	$B1, $DF, $77, $77, $A2, $FE, $B6, $A6, $48, $69, $6A, $EE, $EE, $F4, $4B, $6D, $FC, $77, $F1, $C5, $9F, $59, $E8, $78, $9B, $06, $B3, $03, $D7, $81, $B0, $E1
	dc.b	$2C, $25, $FA, $83, $46, $2D, $67, $8F, $AF, $17, $26, $2F, $D0, $D9, $8B, $3F, $8F, $E8, $71, $72, $62, $A2, $CE, $3B, $31, $72, $6B, $3D, $78, $B9, $35, $B5
	dc.b	$98, $B9, $35, $CA, $CF, $1E, $86, $18, $18, $61, $1C, $23, $84, $76, $98, $E0, $61, $81, $8B, $61, $02, $87, $1A, $4F, $8D, $27, $C7, $09, $63, $81, $C2, $07
	dc.b	$08, $17, $77, $77, $77, $E2, $2E, $EE, $EE, $EE, $F8, $D9, $DD, $DD, $DD, $F6, $B3, $BB, $9C, $27, $C7, $92, $8E, $74, $64, $4A, $25, $12, $EE, $ED, $C4, $68
	dc.b	$6D, $B7, $F1, $DF, $C6, $97, $DD, $CB, $F4, $6E, $26, $E2, $6C, $19, $36, $B4, $28, $6B, $A8, $35, $9A, $B1, $00, $00, $00, $00, $01, $7D, $0A, $73, $8C, $F4
	dc.b	$CF, $74, $80, $09, $35, $C6, $04, $00, $05, $72, $00, $00, $00, $86, $12, $89, $00, $00, $29, $96, $06, $17, $E9, $60, $00, $10, $9E, $92, $00, $00, $0A, $65
	dc.b	$5C, $80, $00, $12, $00, $00, $05, $CF, $D0, $F1, $37, $43, $C4, $D8, $4B, $06, $4D, $B3, $D1, $24, $30, $22, $B9, $00, $01, $13, $8E, $E6, $A2, $E9, $56, $6A
	dc.b	$CD, $58, $80, $8E, $EF, $B4, $E3, $3A, $E5, $AE, $69, $D3, $24, $4A, $3B, $EB, $BF, $AF, $26, $B3, $09, $50, $6E, $60, $1D, $F1, $CB, $6B, $23, $6B, $94, $2F
	dc.b	$81, $76, $06, $1A, $E7, $85, $06, $26, $0D, $58, $D2, $60, $69, $35, $CD, $73, $02, $8D, $B6, $B1, $A2, $B1, $A2, $BD, $15, $E8, $AE, $6B, $30, $C0, $C3, $03
	dc.b	$0C, $0C, $30, $8E, $06, $18, $18, $60, $60, $76, $9A, $4E, $08, $D8, $40, $E3, $34, $40, $D1, $3C, $0D, $13, $C2, $50, $20, $3B, $BF, $43, $C5, $2E, $26, $A0
	dc.b	$E3, $30, $C8, $8E, $EE, $D8, $CD, $1C, $E8, $29, $CE, $25, $0A, $10, $FB, $4E, $D9, $A6, $95, $2D, $59, $85, $67, $D7, $34, $CC, $00, $14, $9E, $93, $1A, $C4
	dc.b	$00, $03, $CB, $0C, $94, $14, $E7, $4C, $AB, $91, $5C, $A6, $17, $E8, $9A, $25, $08, $20, $0A, $D7, $D0, $D0, $9C, $EB, $9A, $E4, $00, $28, $94, $64, $86, $93
	dc.b	$5D, $AB, $48, $01, $71, $4B, $F4, $18, $CF, $4C, $E0, $00, $35, $9A, $0C, $5A, $86, $8C, $E0, $00, $00, $00, $00, $11, $91, $B1, $9D, $73, $D1, $24, $E7, $58
	dc.b	$80, $02, $39, $E9, $3E, $D4, $64, $9E, $B9, $00, $3B, $B9, $E9, $2C, $20, $DB, $51, $B0, $93, $9A, $19, $30, $96, $B3, $AD, $93, $19, $A2, $58, $EF, $EB, $C9
	dc.b	$AC, $C4, $A6, $B6, $81, $00, $04, $35, $C8, $00, $00, $22, $D5, $8D, $76, $15, $C8, $00, $00, $00, $01, $0D, $66, $B9, $AC, $B8, $F5, $D6, $9F, $19, $86, $48
	dc.b	$64, $84, $F4, $B4, $0C, $7F, $90, $C9, $FA, $1C, $5C, $78, $BF, $23, $67, $F8, $C0, $00, $21, $B0, $D3, $67, $E8, $8A, $1E, $3C, $FF, $94, $E4, $FD, $14, $27
	dc.b	$43, $12, $00, $14, $E2, $FC, $8C, $E9, $FF, $20, $00, $00, $62, $E6, $29, $6A, $CC, $00, $00, $01, $5C, $80, $00, $15, $CA, $10, $00, $00, $10, $0D, $72, $2B
	dc.b	$90, $02, $10, $86, $B9, $00, $0B, $88, $00, $00, $2B, $98, $34, $48, $00, $01, $4C, $C8, $52, $FC, $6F, $D6, $20, $00, $93, $4C, $9C, $E1, $90, $00, $26, $9B
	dc.b	$24, $08, $00, $57, $9A, $40, $00, $02, $4D, $38, $00, $00, $86, $06, $3C, $C1, $00, $00, $32, $24, $C6, $B3, $00, $00, $31, $9A, $69, $D3, $98, $00, $5F, $49
	dc.b	$92, $78, $32, $30, $00, $5D, $8A, $B9, $AE, $40, $00, $7E, $CB, $3F, $EC, $BF, $87, $F8, $4C, $F6, $62, $E4, $FC, $26, $7F, $CA, $59, $8B, $3F, $F1, $0F, $1F
	dc.b	$EC, $FF, $28, $6C, $C5, $FC, $34, $3F, $A1, $C5, $9F, $8E, $13, $A1, $FF, $97, $F0, $FC, $73, $FE, $93, $93, $C7, $3F, $E9, $33, $FE, $47, $AF, $F2, $9C, $9C
	dc.b	$65, $0F, $E8, $F1, $58, $61, $FA, $2B, $1A, $0D, $61, $A7, $13, $5D, $C9, $8B, $3F, $EC, $B3, $F8, $FE, $8F, $16, $7B, $31, $59, $FA, $1F, $19, $7E, $E2, $68
	dc.b	$98, $10, $21, $E3, $C7, $D6, $C9, $FA, $3F, $1F, $C8, $9F, $F1, $35, $9C, $7F, $B8, $31, $31, $20, $00, $24, $86, $33, $A3, $24, $E8, $C9, $3D, $32, $00, $24
	dc.b	$E9, $2B, $3F, $23, $64, $1B, $C7, $90, $C4, $F1, $E7, $C5, $19, $7E, $44, $00, $D5, $8D, $93, $C3, $C7, $8F, $AD, $93, $17, $1E, $2E, $36, $87, $5B, $58, $40
	dc.b	$00, $03, $74, $F4, $9B, $1A, $E9, $01, $03, $5C, $D6, $60, $05, $C6, $CE, $4F, $C2, $7E, $1F, $F2, $88, $D9, $FF, $09, $F8, $7F, $C2, $7E, $1E, $07, $17, $E5
	dc.b	$3F, $2F, $1B, $31, $7E, $8E, $27, $AC, $D8, $00, $FE, $26, $7F, $C2, $62, $FD, $3F, $E1, $33, $FE, $46, $CF, $DB, $E7, $B0, $A7, $EC, $F1, $59, $0B, $3F, $63
	dc.b	$7E, $13, $DD, $2A, $CD, $FA, $3C, $5F, $B3, $E3, $FE, $17, $1E, $76, $B1, $BF, $51, $4C, $90, $C5, $80, $10, $E4, $FD, $97, $E4, $73, $F8, $F2, $7E, $8B, $F5
	dc.b	$1F, $C1, $9A, $19, $29, $28, $C0, $64, $87, $E4, $6C, $BF, $FD, $19, $8A, $30, $00, $56, $95, $CC, $00, $00, $00, $8D, $5A, $42, $E6, $00, $01, $16, $14, $90
	dc.b	$00, $00, $23, $00, $00, $00, $0A, $5A, $B6, $2E, $3A, $E4, $00, $06, $2C, $F6, $5D, $C7, $D7, $77, $59, $00, $00, $00, $42, $00, $8E, $70, $00, $00, $57, $22
	dc.b	$99, $27, $30, $00, $08, $60, $50, $A1, $42, $85, $0A, $4A, $12, $81, $00, $0A, $C6, $9C, $89, $3A, $64, $00, $00, $60, $52, $69, $A4, $00, $00, $A3, $46, $69
	dc.b	$88, $00, $21, $49, $E1, $91, $26, $64, $92, $10, $00, $E6, $85, $26, $C9, $0B, $E0, $01, $03, $1C, $89, $34, $E0, $00, $61, $7D, $0C, $59, $32, $24, $E9, $24
	dc.b	$28, $50, $80, $23, $2A, $66, $49, $8A, $11, $49, $00, $64, $49, $A6, $64, $C8, $00, $05, $32, $24, $DC, $E1, $90, $00, $24, $93, $32, $4D, $31, $00, $09, $A6
	dc.b	$99, $1A, $24, $00, $13, $22, $4D, $34, $C4, $00, $0A, $64, $49, $B9, $C2, $70, $00, $84, $92, $66, $49, $9A, $17, $C0, $02, $7A, $66, $49, $21, $42, $00, $02
	dc.b	$13, $64, $BA, $40, $00, $2F, $C4, $A1, $42, $92, $84, $E0, $00, $02, $4D, $74, $80, $00, $09, $9A, $12, $BA, $70, $00, $8C, $DC, $E0, $D0, $9C, $00, $29, $9A
	dc.b	$60, $00, $02, $64, $E6, $00, $00, $49, $27, $8D, $F0, $00, $10, $68, $14, $9A, $51, $60, $00, $02, $6C, $80, $00, $04, $26, $00, $00, $2E, $E6, $00, $00, $53
	dc.b	$3A, $48, $10, $00, $02, $32, $49, $A5, $02, $00, $02, $93, $13, $74, $C0, $00, $2B, $4E, $8C, $00, $00, $57, $28, $C0, $00, $00, $00, $00, $29, $30, $30, $30
	dc.b	$29, $3D, $3D, $77, $7E, $A2, $EF, $D4, $00, $05, $72, $00, $00, $45, $80, $00, $00, $2E, $28, $40, $02, $B2, $AA, $A8, $17, $2A, $AA, $AF, $60, $8A, $AA, $AA
	dc.b	$AF, $F0, $22, $60, $51, $55, $55, $55, $72, $21, $F4, $9F, $95, $95, $55, $54, $D7, $29, $62, $7E, $E0, $C2, $CE, $4B, $33, $EF, $87, $EE, $33, $F0, $AD, $FC
	dc.b	$08, $FF, $81, $14, $D7, $FE, $C7, $25, $99, $FF, $71, $FB, $3E, $BF, $D9, $FE, $A3, $3D, $9F, $A3, $8F, $EA, $39, $2B, $D9, $BC, $34, $19, $3F, $87, $66, $7B
	dc.b	$3F, $E7, $FF, $3F, $F9, $FF, $4E, $C4, $E4, $FD, $40, $46, $43, $06, $43, $D7, $7D, $33, $FE, $A2, $7B, $33, $C2, $C9, $7E, $E1, $25, $1B, $F0, $BE, $97, $E2
	dc.b	$6E, $30, $92, $18, $4A, $33, $A4, $F0, $99, $AE, $37, $4A, $BB, $21, $8B, $21, $89, $43, $06, $4B, $F0, $29, $24, $30, $28, $D1, $30, $30, $90, $14, $94, $30
	dc.b	$60, $62, $C8, $45, $26, $0C, $86, $24, $21, $02, $25, $0A, $18, $14, $C8, $86, $26, $04, $0A, $4D, $26, $26, $B1, $89, $89, $04, $01, $73, $21, $8B, $21, $89
	dc.b	$A5, $91, $A0, $60, $50, $D6, $35, $8D, $D2, $11, $20, $44, $A1, $43, $02, $99, $10, $C4, $C0, $8A, $DF, $C0, $43, $49, $89, $AC, $62, $62, $41, $02, $95, $DF
	dc.b	$58, $C4, $C0, $D7, $37, $10, $29, $55, $05, $0D, $62, $00, $55, $E5, $00, $00, $AA, $A0, $01, $05, $55, $E5, $00, $22, $AA, $AF, $F8, $00, $0A, $AA, $AA, $02
	dc.b	$AA, $AA, $A8, $82, $AA, $AA, $AF, $28, $55, $55, $55, $5A, $CA, $AA, $AA, $AA, $AA, $AA, $AA, $AB, $C2, $E3, $05, $55, $55, $55, $55, $DF, $B3, $87, $96, $FE
	dc.b	$AD, $F5, $55, $55, $5F, $CA, $55, $5E, $AE, $5E, $AE, $5E, $AE, $1B, $3B, $3F, $95, $D9, $FE, $A5, $55, $55, $55, $5C, $CA, $AA, $AA, $AB, $BB, $47, $6A, $AA
	dc.b	$AA, $F2, $EA, $55, $55, $55, $55, $FE, $05, $E5, $E1, $55, $55, $55, $55, $55, $55, $FE, $AD, $FF, $EA, $B7, $FB, $5A, $6A, $AA, $AA, $AA, $B7, $46, $EB, $DB
	dc.b	$BB, $FF, $9B, $E1, $DB, $D5, $FD, $BF, $DD, $69, $D9, $6D, $55, $55, $BB, $47, $F7, $72, $FF, $77, $F9, $9B, $B4, $EC, $B7, $C3, $F7, $5D, $D9, $7F, $95, $6E
	dc.b	$CB, $7F, $D5, $6D, $5A, $B7, $DE, $F4, $D5, $CB, $AB, $97, $F5, $BF, $AE, $CD, $7B, $2F, $FB, $7F, $F9, $A7, $C2, $DC, $BD, $5F, $DB, $55, $5F, $DF, $7A, $7E
	dc.b	$B7, $57, $66, $5D, $DA, $BB, $34, $66, $BD, $BE, $F7, $0B, $74, $66, $FD, $72, $AA, $AF, $A7, $F3, $BB, $3F, $9D, $D9, $FC, $EE, $CB, $DD, $AB, $FE, $0B, $DF
	dc.b	$E0, $BD, $D9, $AB, $7E, $ED, $F7, $B7, $DE, $CD, $7B, $77, $EB, $BB, $72, $FE, $BB, $77, $7F, $F3, $74, $5B, $E9, $7B, $7F, $EF, $B7, $FE, $FB, $7F, $F3, $B7
	dc.b	$5E, $FF, $EE, $8D, $DF, $DC, $CD, $FC, $CB, $7F, $B9, $DD, $96, $DC, $B6, $E5, $B7, $7F, $6D, $EE, $1A, $B3, $65, $DD, $AB, $F5, $B9, $7F, $9B, $FD, $CC, $DF
	dc.b	$FC, $D1, $DD, $E1, $A7, $66, $9D, $1D, $DB, $3F, $76, $AB, $AB, $97, $76, $AF, $4C, $BB, $BF, $9D, $A3, $76, $AC, $D7, $B4, $76, $EA, $EF, $ED, $BD, $D9, $95
	dc.b	$55, $57, $86, $AE, $5D, $5C, $BA, $B9, $75, $2A, $AA, $E6, $D1, $6E, $CC, $BC, $3B, $7C, $2F, $66, $D5, $FA, $DC, $BF, $BE, $ED, $55, $55, $5C, $BF, $E0, $EF
	dc.b	$FE, $07, $7D, $BD, $5C, $36, $68, $FE, $6E, $CD, $3E, $19, $BC, $BB, $B4, $55, $55, $55, $54, $B9, $B5, $70, $BD, $BE, $F7, $6F, $EF, $BB, $BF, $99, $E5, $A7
	dc.b	$2D, $B9, $7F, $95, $DD, $55, $4A, $BF, $AE, $DF, $7B, $B3, $2F, $F7, $6F, $78, $7E, $B6, $F6, $9F, $E6, $66, $D9, $FB, $BE, $FE, $AB, $7A, $BB, $95, $55, $75
	dc.b	$6F, $BD, $E9, $BB, $FB, $DA, $3F, $9B, $7B, $FB, $9B, $BB, $2F, $6E, $CB, $9B, $B2, $F6, $ED, $1D, $97, $B3, $65, $D3, $C2, $F6, $6D, $16, $EC, $DF, $AB, $36
	dc.b	$5B, $7A, $B5, $66, $CB, $A7, $AB, $76, $8D, $3D, $5E, $1A, $7A, $BB, $F3, $68, $D3, $FC, $CD, $3B, $2D, $F0, $D3, $B3, $FB, $75, $55, $55, $5E, $5F, $BB, $D9
	dc.b	$A7, $CA, $DA, $AA, $AA, $AA, $AA, $AB, $AB, $4F, $FA, $AD, $AA, $AA, $AA, $AA, $AB, $7B, $FB, $74, $E8, $ED, $D9, $A7, $47, $EB, $7C, $B4, $F7, $F9, $5B, $E1
	dc.b	$E5, $FB, $BC, $BE, $56, $EC, $D3, $97, $FB, $5A, $6F, $7F, $83, $57, $2E, $6B, $DC, $B9, $B5, $7F, $03, $75, $EF, $E0, $65, $DD, $7B, $D3, $46, $6B, $DE, $96
	dc.b	$E5, $CD, $7B, $97, $F9, $D9, $B8, $6A, $ED, $E1, $AB, $B7, $85, $EC, $DE, $1C, $2F, $66, $D1, $6E, $5E, $17, $B3, $68, $D3, $C2, $F6, $6C, $BD, $DB, $EF, $6E
	dc.b	$CB, $6E, $CB, $77, $5E, $FF, $EF, $FF, $7F, $9B, $6F, $FB, $2D, $FF, $65, $BD, $F6, $FF, $33, $FF, $76, $F9, $69, $CD, $A3, $F9, $7D, $FF, $CB, $EF, $FE, $5E
	dc.b	$8E, $EF, $E6, $77, $78, $7E, $EF, $47, $76, $CF, $E5, $EC, $B7, $F7, $56, $EC, $5B, $76, $72, $E9, $EA, $F4, $B7, $F9, $5C, $2A, $B6, $AA, $BF, $D4, $AA, $AA
	dc.b	$BB, $3F, $C1, $B2, $DE, $5B, $76, $5B, $FC, $00
Credits_tiles_3:
	dc.b	$80, $FD, $80, $04, $06, $14, $07, $25, $11, $36, $30, $46, $2F, $56, $2A, $65, $14, $72, $00, $81, $03, $02, $16, $2E, $27, $70, $78, $EB, $82, $06, $2B, $17
	dc.b	$74, $83, $05, $10, $17, $71, $84, $07, $6A, $18, $E6, $85, $06, $31, $18, $EF, $86, $05, $16, $17, $6C, $28, $F2, $87, $05, $12, $17, $6E, $28, $EA, $48, $F0
	dc.b	$76, $33, $88, $07, $6F, $18, $F1, $89, $06, $32, $17, $76, $8A, $06, $27, $17, $6D, $8B, $06, $26, $17, $72, $28, $F4, $8C, $07, $6B, $8D, $06, $34, $8E, $08
	dc.b	$E7, $8F, $08, $EE, $FF, $00, $1F, $F3, $9F, $B2, $C1, $32, $95, $56, $AE, $A8, $15, $28, $2A, $AD, $8C, $65, $8B, $EA, $79, $52, $4F, $66, $AD, $E4, $FD, $D9
	dc.b	$77, $61, $BF, $F4, $8F, $30, $D0, $7E, $7B, $FF, $3C, $01, $84, $DA, $01, $1F, $F9, $1C, $DD, $EF, $CC, $9B, $83, $AA, $F5, $63, $0B, $34, $1A, $18, $EA, $AD
	dc.b	$94, $6B, $BA, $B8, $E2, $D0, $4F, $66, $C6, $15, $B2, $8A, $65, $5C, $1F, $A7, $17, $D8, $DF, $DE, $FC, $FF, $F5, $79, $AA, $F1, $FE, $F6, $C0, $00, $02, $BE
	dc.b	$BF, $D2, $7E, $CF, $55, $7C, $5E, $5A, $BB, $F9, $9E, $0B, $76, $AC, $59, $3F, $16, $AD, $61, $DF, $6C, $15, $B1, $D5, $8E, $10, $65, $06, $C5, $57, $FA, $56
	dc.b	$D9, $06, $D9, $97, $FB, $FF, $63, $6F, $D2, $7E, $D6, $BF, $E4, $7E, $BB, $F8, $C0, $00, $04, $78, $57, $75, $6A, $BE, $65, $C5, $A1, $AB, $A5, $A3, $8F, $46
	dc.b	$83, $C9, $B6, $6A, $C5, $34, $16, $3C, $D8, $B4, $93, $63, $A9, $94, $56, $C4, $F0, $6F, $D1, $35, $6D, $73, $74, $83, $5A, $B8, $37, $FF, $FF, $8D, $FA, $4F
	dc.b	$D9, $4D, $FA, $9F, $DF, $7E, $DC, $00, $00, $17, $F8, $A1, $4C, $65, $52, $85, $50, $52, $FE, $0D, $94, $2D, $86, $AB, $AF, $D5, $5B, $42, $A4, $FB, $1A, $CD
	dc.b	$C6, $CD, $DD, $97, $E7, $FF, $7C, $AD, $CD, $DF, $FA, $C9, $BF, $53, $CF, $FE, $70, $00, $00, $8F, $FC, $80, $7E, $B0, $3F, $ED, $FA, $FF, $E7, $79, $7F, $17
	dc.b	$D3, $F9, $3D, $55, $F3, $77, $8F, $8D, $A9, $61, $D3, $E3, $1B, $55, $67, $58, $D3, $FA, $BC, $43, $FE, $51, $E3, $57, $17, $D4, $53, $57, $58, $55, $FF, $6F
	dc.b	$CF, $7E, $FF, $9E, $6E, $FD, $5F, $AD, $D7, $FB, $98, $EC, $FD, $AE, $C0, $68, $18, $41, $E0, $17, $C1, $A0, $FF, $B2, $5F, $A2, $0F, $F9, $7E, $93, $BD, $F5
	dc.b	$5C, $DC, $23, $5E, $AC, $61, $66, $83, $43, $1D, $55, $B2, $6A, $E1, $AA, $B5, $5B, $F9, $32, $7B, $6A, $C6, $15, $B2, $74, $D0, $E9, $0D, $9F, $9D, $E7, $FE
	dc.b	$7F, $E9, $7F, $89, $DB, $FB, $15, $CB, $FA, $D2, $C6, $A5, $6C, $6A, $56, $A9, $36, $38, $27, $B1, $08, $AC, $31, $1F, $F8, $78, $83, $D7, $0F, $D2, $FE, $8B
	dc.b	$9A, $BE, $2F, $25, $DF, $CC, $F0, $6D, $DA, $B1, $64, $FC, $5A, $B5, $87, $7D, $B0, $56, $C7, $56, $38, $41, $94, $1B, $1E, $9F, $A3, $6D, $9F, $CF, $FD, $77
	dc.b	$F1, $3F, $4B, $FF, $8F, $FB, $04, $7A, $70, $AE, $18, $C9, $7E, $8F, $9B, $A5, $A2, $BA, $34, $1E, $4D, $B3, $56, $29, $A0, $D8, $F3, $62, $D2, $4D, $8E, $A6
	dc.b	$58, $6C, $4F, $06, $5D, $1A, $B6, $BA, $15, $E9, $AF, $BB, $2D, $35, $F3, $E5, $B2, $5F, $A4, $C7, $F4, $50, $FD, $4F, $8F, $EB, $BA, $B6, $05, $5C, $3F, $85
	dc.b	$FA, $3B, $FB, $F5, $55, $74, $9B, $F6, $30, $68, $2C, $2D, $75, $A2, $B5, $2C, $2D, $5E, $AA, $DA, $BA, $93, $6C, $6E, $EC, $BB, $B5, $E9, $FA, $FF, $FA, $7E
	dc.b	$A3, $F9, $3E, $5E, $00, $57, $60, $D2, $F4, $3E, $98, $5A, $96, $65, $7E, $25, $3F, $39, $57, $35, $5D, $AA, $EA, $04, $55, $22, $88, $29, $A1, $AC, $08, $C8
	dc.b	$AA, $48, $BE, $4C, $80, $00, $00, $00, $00, $0B, $E4, $15, $6E, $8F, $53, $26, $52, $FD, $8B, $21, $95, $15, $10, $EA, $29, $FF, $82, $C9, $D5, $E8, $00, $00
	dc.b	$00, $00, $00, $29, $D6, $00, $E9, $D3, $27, $BB, $0B, $A2, $B0, $4D, $C0, $00, $00, $00, $00, $00, $3F, $AE, $00, $00, $12, $00, $02, $40, $61, $6E, $A7, $B4
	dc.b	$95, $F6, $CF, $C0, $00, $00, $00, $00, $05, $44, $53, $3C, $C0, $00, $00, $00, $00, $03, $30, $00, $1B, $37, $EB, $00, $A9, $45, $46, $E7, $FE, $0B, $A8, $A7
	dc.b	$4C, $9D, $00, $00, $00, $14, $CC, $00, $33, $64, $D7, $32, $64, $C9, $D3, $20, $14, $53, $DC, $DC, $1E, $E8, $F0, $75, $7A, $00, $00, $00, $03, $30, $00, $91
	dc.b	$BA, $FB, $9A, $55, $5D, $60, $B5, $15, $13, $A6, $BA, $F4, $3A, $1A, $D4, $55, $20, $05, $45, $6A, $2A, $B2, $BD, $36, $FC, $AF, $55, $5C, $DB, $EA, $4D, $D5
	dc.b	$AE, $7D, $D6, $00, $23, $2A, $22, $90, $06, $D3, $65, $F3, $05, $38, $01, $1E, $74, $3C, $80, $B3, $74, $8D, $6D, $6D, $4F, $93, $F0, $C6, $3D, $D7, $C1, $A4
	dc.b	$B2, $9D, $93, $EB, $68, $32, $8A, $8C, $D1, $9E, $68, $C2, $3F, $BA, $CA, $76, $9C, $00, $00, $00, $00, $00, $00, $00, $33, $CC, $00, $00, $00, $00, $00, $00
	dc.b	$00, $33, $FD, $BD, $A5, $B2, $AB, $B0, $B9, $A7, $BE, $E9, $AA, $53, $52, $01, $4C, $8B, $F8, $5F, $C0, $2A, $DB, $54, $D0, $A4, $2A, $54, $44, $0A, $95, $15
	dc.b	$16, $41, $45, $7A, $95, $4A, $48, $33, $F2, $97, $3E, $9B, $B8, $36, $51, $DB, $C2, $33, $37, $25, $87, $28, $34, $1F, $C5, $B7, $A8, $61, $E2, $D0, $78, $45
	dc.b	$61, $0F, $1C, $39, $32, $BE, $E7, $C9, $D3, $6D, $57, $CF, $32, $ED, $82, $6E, $CD, $3D, $21, $3F, $66, $B9, $B8, $C6, $E0, $68, $03, $E5, $56, $FB, $FB, $20
	dc.b	$BF, $A9, $61, $D4, $82, $97, $7F, $5F, $60, $0F, $FF, $60, $1B, $AC, $06, $CC, $0A, $7F, $C8, $FF, $CF, $5E, $BD, $2E, $FD, $B5, $DF, $9D, $99, $AE, $9F, $F6
	dc.b	$33, $F2, $6F, $D5, $72, $BB, $6C, $67, $C3, $F5, $41, $1E, $C5, $32, $AB, $2A, $66, $7F, $D8, $06, $EB, $01, $F3, $00, $FF, $95, $5E, $3F, $B9, $E7, $CA, $EB
	dc.b	$FF, $82, $F2, $FE, $36, $EB, $7F, $85, $A6, $8E, $D7, $53, $6D, $7D, $AC, $AF, $9E, $F9, $E9, $38, $D3, $D3, $2A, $64, $19, $9F, $F6, $03, $AC, $0F, $0A, $D5
	dc.b	$78, $62, $F0, $BE, $0D, $08, $E2, $DC, $77, $B7, $7F, $94, $CD, $5E, $E5, $F9, $D6, $87, $8F, $E7, $A0, $D0, $65, $67, $50, $68, $4B, $0E, $03, $49, $BC, $15
	dc.b	$97, $F1, $AA, $FE, $53, $CF, $7E, $D8, $CE, $6D, $BE, $76, $85, $F9, $42, $AF, $D4, $85, $FF, $B9, $A6, $55, $65, $7F, $60, $00, $00, $00, $00, $AB, $33, $30
	dc.b	$00, $00, $00, $00, $0A, $2F, $F3, $D8, $CC, $00, $00, $00, $00, $02, $EF, $EB, $EC, $00, $BF, $1A, $B1, $B1, $7E, $2D, $6C, $31, $2A, $C6, $FD, $9F, $C3, $B0
	dc.b	$0F, $D6, $04, $76, $AA, $FF, $74, $F0, $DF, $56, $F6, $83, $C2, $30, $78, $46, $0F, $08, $C2, $A8, $46, $17, $FE, $8D, $A1, $BD, $B7, $BF, $16, $9A, $13, $75
	dc.b	$FF, $5F, $97, $94, $B5, $D9, $FF, $55, $33, $4E, $3F, $F0, $B5, $57, $AA, $AB, $35, $B0, $D8, $F6, $2D, $87, $91, $60, $8D, $9B, $FA, $78, $C0, $0E, $B0, $8A
	dc.b	$8A, $FD, $54, $D3, $A6, $DE, $61, $03, $7B, $6F, $A6, $F6, $85, $FB, $E0, $37, $16, $DE, $C9, $FF, $51, $1E, $3E, $89, $D3, $CF, $82, $DB, $94, $23, $3B, $F6
	dc.b	$A6, $54, $CA, $3A, $BF, $4B, $6F, $D2, $E1, $00, $74, $CA, $F5, $6A, $95, $4A, $97, $35, $99, $7E, $D3, $8E, $AC, $40, $6E, $B0, $6E, $0E, $99, $4D, $3E, $FD
	dc.b	$B7, $4C, $8A, $94, $61, $82, $A9, $61, $08, $CD, $1C, $99, $4C, $D3, $76, $08, $A9, $8A, $4E, $03, $7F, $52, $B9, $15, $4B, $1C, $2E, $69, $55, $76, $17, $03
	dc.b	$FF, $D4, $0E, $B0, $54, $DB, $37, $F2, $99, $32, $3F, $63, $52, $A9, $32, $74, $CA, $F4, $CA, $3C, $B8, $5F, $3D, $E9, $97, $EE, $D4, $D3, $FF, $06, $6D, $A0
	dc.b	$0C, $A8, $80, $00, $00, $00, $00, $00, $29, $77, $54, $6E, $EA, $23, $FB, $1F, $DB, $FE, $D8, $1B, $30, $28, $A8, $A8, $A8, $80, $00, $00, $00, $0C, $F3, $33
	dc.b	$03, $FA, $FB, $30, $BA, $18, $B5, $CD, $75, $7A, $9D, $5E, $A9, $70, $01, $4B, $AA, $42, $00, $00, $0A, $97, $F9, $EC, $F9, $98, $66, $06, $C9, $63, $FB, $78
	dc.b	$3D, $B0, $AD, $35, $A9, $5D, $15, $10, $00, $00, $00, $00, $61, $9E, $63, $DD, $FD, $7D, $80, $00, $61, $02, $06, $34, $B6, $2D, $E5, $FA, $58, $58, $0E, $B0
	dc.b	$23, $36, $DE, $5F, $A4, $E0, $FF, $9F, $64, $CB, $0E, $E7, $55, $5D, $7A, $74, $5C, $5D, $57, $5B, $F2, $FE, $B3, $E8, $FB, $B4, $8F, $E7, $76, $80, $D9, $80
	dc.b	$07, $FD, $80, $EB, $01, $FF, $AF, $CC, $62, $77, $C7, $26, $96, $CC, $5E, $59, $32, $7C, $59, $6A, $EE, $65, $BA, $B6, $83, $77, $73, $F7, $3A, $6E, $0D, $DA
	dc.b	$E7, $BB, $73, $75, $7F, $1B, $83, $79, $69, $2F, $D6, $FA, $34, $F4, $9A, $7A, $A6, $27, $BF, $30, $00, $FF, $B0, $5F, $D6, $04, $73, $00, $3F, $E4, $7F, $E6
	dc.b	$5F, $E1, $6F, $F3, $70, $BF, $F5, $5F, $B1, $9E, $33, $B6, $D5, $84, $EF, $3D, $27, $3A, $A6, $FD, $B9, $86, $80, $5F, $A5, $FB, $27, $9A, $F4, $F6, $8A, $08
	dc.b	$C8, $A2, $A2, $8F, $50, $C8, $02, $3F, $A2, $4D, $FA, $23, $F5, $29, $BB, $6A, $E0, $FF, $9C, $5E, $51, $FC, $EB, $4F, $33, $E9, $B2, $65, $1D, $26, $7D, $B8
	dc.b	$29, $F0, $C9, $FF, $54, $D0, $20, $D3, $E1, $94, $E3, $64, $53, $20, $75, $48, $2A, $A0, $AA, $40, $00, $00, $00, $BF, $AE, $9B, $FA, $F7, $18, $66, $01, $9E
	dc.b	$54, $C8, $00, $00, $00, $00, $02, $99, $E6, $19, $80, $66, $53, $22, $99, $00, $00, $00, $00, $06, $79, $86, $60, $1E, $1A, $6E, $3B, $53, $2A, $B2, $30, $81
	dc.b	$4C, $9F, $B5, $59, $19, $00, $00, $00, $55, $FB, $75, $1F, $DB, $A0, $8E, $60, $00, $14, $91, $54, $80, $00, $00, $0B, $ED, $1F, $D1, $59, $57, $1D, $58, $A6
	dc.b	$C5, $F1, $4D, $3D, $FF, $9D, $92, $8E, $91, $D2, $3B, $2E, $C3, $96, $B6, $D7, $15, $44, $CA, $F4, $FA, $F0, $4C, $A7, $79, $9B, $AB, $4D, $DA, $E5, $1F, $06
	dc.b	$DD, $FC, $19, $32, $A9, $14, $40, $99, $3A, $8A, $75, $52, $00, $00, $00, $00, $00, $1F, $C2, $3E, $0D, $D6, $00, $27, $4C, $9A, $E6, $4C, $99, $35, $C0, $00
	dc.b	$00, $00, $00, $00, $75, $80, $18, $28, $DC, $C9, $96, $0A, $37, $00, $00, $00, $00, $00, $04, $EF, $33, $CC, $D3, $BF, $EC, $68, $B0, $9D, $35, $D3, $60, $A7
	dc.b	$69, $3E, $D6, $B9, $94, $6E, $6D, $77, $6D, $4E, $99, $45, $4D, $3B, $AD, $73, $BC, $95, $F2, $79, $DD, $46, $64, $D7, $3C, $9E, $65, $85, $D3, $60, $A4, $A6
	dc.b	$56, $64, $CA, $D2, $65, $AD, $A7, $92, $AA, $7D, $7C, $D2, $D7, $AA, $3D, $A7, $59, $03, $5D, $E0, $D7, $78, $04, $57, $F9, $EC, $01, $86, $60, $0A, $88, $A2
	dc.b	$00, $A2, $A2, $A4, $D3, $D5, $BB, $42, $FD, $DA, $AF, $DB, $90, $5F, $E1, $1F, $00, $8E, $60, $06, $60, $00, $00, $00, $00, $00, $06, $60, $06, $60, $00, $00
	dc.b	$00, $00, $00, $06, $60, $06, $7D, $60, $03, $A6, $4C, $9A, $E6, $4C, $99, $00, $00, $00, $00, $00, $01, $7F, $57, $F0, $77, $5F, $73, $4B, $04, $D7, $17, $AC
	dc.b	$13, $A8, $DC, $CA, $3F, $B1, $6B, $9D, $05, $E8, $00, $00, $00, $00, $03, $30, $24, $51, $48, $02, $8A, $88, $95, $F7, $51, $00, $03, $48, $00, $24, $00, $75
	dc.b	$00, $00, $00, $00, $00, $00, $19, $80, $19, $80, $00, $00, $00, $00, $00, $46, $EF, $EB, $EC, $00, $23, $E0, $01, $20, $00, $00, $00, $29, $22, $A9, $55, $2B
	dc.b	$F7, $5F, $20, $00, $30, $FD, $24, $79, $B7, $62, $FA, $B7, $5D, $07, $D5, $26, $BA, $D1, $D5, $D5, $7F, $ED, $03, $F5, $1F, $AA, $E5, $94, $F3, $7E, $A7, $C6
	dc.b	$0C, $AF, $E1, $BA, $12, $9B, $AB, $F3, $DA, $9B, $5F, $EB, $9F, $9F, $9B, $FB, $43, $F2, $FD, $D7, $2F, $1C, $BF, $5D, $F9, $FD, $D3, $36, $B7, $D5, $1D, $75
	dc.b	$F3, $EA, $6D, $70, $FC, $FF, $4D, $BB, $FA, $BC, $76, $84, $D4, $EE, $DF, $96, $DF, $46, $D7, $A7, $E7, $BF, $3E, $B9, $BF, $5D, $F9, $F5, $CB, $F5, $5F, $CB
	dc.b	$00, $AA, $7E, $57, $AE, $57, $CC, $01, $84, $FD, $A3, $3C, $BF, $5A, $F3, $D7, $C6, $B9, $60, $A5, $DE, $F3, $D7, $A4, $D2, $AE, $33, $F4, $D3, $5E, $1B, $72
	dc.b	$DE, $7E, $EB, $F7, $79, $7E, $7B, $4D, $7F, $A3, $DC, $DC, $D3, $6B, $9A, $4F, $29, $A0, $D3, $4A, $6D, $7C, $F5, $EF, $FC, $E6, $9D, $1E, $BD, $FA, $B2, $FE
	dc.b	$50, $FC, $BF, $75, $CB, $8F, $E8, $B4, $FF, $64, $1B, $47, $FC, $E7, $E7, $A5, $3E, $B8, $7E, $7F, $A7, $6D, $FD, $5E, $3D, $82, $6F, $CE, $5F, $AF, $97, $ED
	dc.b	$25, $FA, $36, $E3, $AF, $BB, $57, $EB, $B4, $D7, $C7, $28, $3A, $F4, $ED, $B6, $60, $23, $D5, $FC, $8F, $D7, $2E, $9C, $7F, $65, $76, $CF, $ED, $FE, $74, $03
	dc.b	$7F, $EE, $7F, $55, $0F, $D9, $2D, $DF, $D6, $6F, $FE, $80, $36, $DF, $48, $EE, $D9, $34, $7F, $7A, $00, $13, $F6, $93, $F2, $87, $E7, $A3, $33, $2A, $57, $DD
	dc.b	$F9, $E8, $CC, $AB, $CA, $18, $4D, $3B, $4E, $61, $B5, $F7, $6D, $E3, $B5, $AB, $D2, $BF, $CE, $77, $56, $DD, $34, $8E, $8D, $CF, $FA, $CD, $3B, $B9, $F4, $E9
	dc.b	$DB, $7C, $F3, $4F, $C8, $2F, $DA, $F3, $6D, $CA, $BD, $37, $CB, $8D, $6A, $BE, $E6, $EE, $AD, $57, $05, $0F, $19, $E0, $BD, $23, $C8, $1A, $69, $E6, $BF, $A4
	dc.b	$3F, $71, $93, $5C, $CB, $A4, $2B, $ED, $0A, $D4, $EA, $67, $F4, $69, $80, $3F, $95, $E8, $FC, $1E, $69, $E5, $FC, $67, $FE, $E8, $03, $7E, $76, $AF, $CE, $80
	dc.b	$00, $DF, $9D, $F4, $8E, $C6, $B9, $F4, $B5, $5A, $36, $C9, $28, $FE, $F6, $D4, $D0, $6F, $E6, $BC, $DB, $AD, $BA, $79, $AB, $68, $28, $3A, $6E, $2D, $08, $F1
	dc.b	$7F, $D8, $FE, $DF, $F6, $DF, $FD, $0E, $5F, $DA, $E9, $0B, $FF, $46, $DF, $D1, $92, $6B, $34, $D6, $9B, $4E, $5A, $4C, $DA, $03, $FE, $B2, $6D, $7F, $AA, $F2
	dc.b	$56, $7F, $D8, $B7, $09, $A3, $2B, $72, $6F, $4F, $CE, $81, $FA, $CB, $FC, $BD, $1F, $83, $59, $A6, $D3, $F6, $CD, $B1, $BF, $FA, $00, $7F, $76, $FF, $D6, $BF
	dc.b	$EB, $40, $3F, $39, $3F, $E7, $1F, $5E, $CA, $F9, $9E, $DD, $3F, $38, $9E, $BE, $79, $99, $4E, $F5, $F3, $E3, $AD, $A6, $79, $57, $CE, $DA, $E3, $A4, $FC, $DD
	dc.b	$F8, $7E, $B3, $43, $6D, $55, $C3, $29, $F5, $C7, $9D, $55, $CF, $5E, $36, $D7, $14, $CB, $5E, $19, $4B, $4A, $B4, $A8
Championship_driver_tiles:
	dc.b	$80, $94, $80, $04, $02, $14, $05, $25, $0E, $35, $11, $46, $31, $56, $2F, $66, $2A, $73, $00, $81, $05, $0F, $17, $6E, $28, $EC, $77, $6A, $82, $06, $30, $18
	dc.b	$F2, $83, $04, $04, $16, $2E, $27, $72, $84, $04, $03, $16, $32, $27, $71, $38, $F1, $85, $05, $10, $17, $6C, $86, $05, $0D, $17, $6F, $28, $EF, $87, $05, $0C
	dc.b	$16, $33, $28, $F0, $88, $05, $13, $18, $EB, $89, $05, $14, $18, $ED, $8A, $07, $6D, $18, $EA, $8B, $07, $6B, $18, $F4, $8C, $06, $34, $18, $EE, $8D, $06, $2B
	dc.b	$17, $73, $8E, $05, $12, $17, $70, $8F, $05, $16, $17, $74, $FF, $00, $00, $5F, $E9, $2E, $4E, $82, $A1, $24, $A1, $8B, $F4, $66, $D5, $7E, $1F, $AA, $62, $C9
	dc.b	$F3, $D7, $D4, $EE, $98, $5C, $B7, $33, $F5, $2B, $90, $BF, $FA, $25, $B4, $00, $2F, $FF, $CB, $B6, $16, $C7, $6F, $81, $96, $CC, $37, $96, $5C, $F6, $FE, $F6
	dc.b	$9F, $FA, $FF, $9F, $FE, $40, $D4, $00, $03, $FF, $2E, $FD, $2C, $B6, $5C, $D5, $B6, $B2, $EC, $F4, $5A, $FF, $55, $BE, $8D, $FF, $D7, $FC, $FF, $D3, $5D, $46
	dc.b	$3F, $62, $AF, $D2, $3B, $8A, $B0, $00, $FD, $CF, $EA, $E7, $05, $BA, $BC, $11, $7C, $A4, $C7, $E1, $AC, $9E, $4C, $29, $13, $50, $A4, $AC, $7B, $5F, $84, $65
	dc.b	$5D, $56, $AE, $44, $DF, $D6, $4F, $A6, $85, $B1, $E8, $EA, $F0, $45, $7D, $B4, $F2, $4C, $25, $3D, $FF, $A8, $A0, $00, $76, $FF, $63, $71, $BF, $8F, $E8, $B5
	dc.b	$C0, $B5, $93, $57, $59, $36, $B5, $C3, $5F, $3F, $4E, $65, $4F, $ED, $2F, $F4, $F2, $2E, $7F, $A9, $62, $4A, $E8, $9D, $F7, $3D, $7B, $3A, $D9, $BC, $00, $1D
	dc.b	$FD, $85, $FD, $97, $40, $17, $F7, $71, $FD, $D6, $E5, $FD, $9C, $7F, $72, $04, $7B, $19, $57, $78, $BF, $F6, $CB, $BC, $62, $CE, $4A, $C2, $7D, $C2, $FB, $AA
	dc.b	$32, $CC, $2A, $03, $00, $11, $80, $00, $02, $28, $01, $DE, $D3, $A8, $C6, $55, $1B, $B7, $64, $23, $A8, $77, $FE, $97, $7F, $F4, $C4, $6E, $89, $92, $12, $2A
	dc.b	$5E, $97, $A0, $71, $80, $01, $B8, $F1, $35, $37, $19, $18, $00, $00, $00, $00, $00, $17, $50, $EF, $86, $78, $A6, $E8, $34, $0B, $EE, $24, $24, $8A, $12, $17
	dc.b	$20, $62, $A3, $A8, $C2, $E4, $46, $B9, $29, $91, $80, $00, $00, $03, $15, $25, $4C, $15, $1D, $46, $1F, $AF, $FA, $20, $34, $0A, $EF, $40, $1F, $79, $A6, $C6
	dc.b	$C1, $B0, $5B, $89, $09, $17, $FA, $64, $8B, $CA, $B7, $25, $F8, $3C, $B8, $22, $F9, $27, $6D, $75, $30, $B5, $85, $31, $51, $85, $3C, $73, $45, $E4, $59, $9B
	dc.b	$9F, $5F, $A5, $FB, $91, $D6, $E4, $C9, $DD, $4F, $D6, $8F, $17, $65, $1C, $81, $6A, $02, $A9, $54, $95, $56, $05, $FD, $3F, $6B, $BF, $3F, $D9, $C7, $FA, $7C
	dc.b	$3A, $7E, $FB, $98, $F2, $97, $34, $DD, $C1, $16, $5D, $CC, $1F, $E7, $11, $3B, $CD, $7F, $88, $BC, $52, $29, $E1, $E3, $E1, $FF, $BD, $5F, $F3, $FF, $E8, $BF
	dc.b	$FE, $81, $7F, $62, $BD, $C3, $1D, $12, $1F, $AE, $6E, $84, $90, $E5, $8F, $EB, $62, $8A, $C9, $2A, $15, $99, $1B, $8B, $AC, $98, $78, $E0, $B8, $41, $58, $49
	dc.b	$22, $65, $27, $6A, $E5, $35, $D3, $9C, $A7, $57, $53, $BA, $68, $49, $42, $D6, $ED, $B4, $45, $35, $A4, $F0, $A1, $32, $E7, $97, $40, $2A, $7B, $1D, $BA, $42
	dc.b	$5F, $F7, $FF, $DE, $AF, $F9, $FF, $F4, $71, $1F, $C4, $0C, $A6, $65, $9C, $84, $AC, $EE, $0C, $86, $DE, $BB, $77, $DC, $B9, $EC, $56, $D0, $99, $05, $6C, $9A
	dc.b	$C2, $B4, $09, $B3, $A5, $9B, $69, $DC, $4D, $B1, $59, $8A, $8A, $DE, $98, $6C, $E4, $EC, $F0, $D7, $0D, $F1, $A6, $78, $55, $85, $4C, $A8, $E9, $1C, $8A, $D4
	dc.b	$2C, $95, $E5, $68, $6E, $23, $84, $60, $71, $B8, $A8, $BB, $AD, $26, $51, $78, $13, $EC, $D5, $FD, $BB, $E5, $38, $7E, $EF, $4E, $09, $FC, $17, $7E, $CE, $BE
	dc.b	$92, $FD, $EF, $2C, $01, $1A, $F1, $23, $2C, $9C, $63, $A9, $99, $76, $0E, $65, $74, $D7, $F9, $10, $5D, $99, $92, $56, $E6, $5A, $6E, $82, $FE, $A1, $2B, $37
	dc.b	$CC, $9A, $E4, $2A, $EC, $D9, $AB, $1E, $56, $74, $31, $63, $4A, $8B, $06, $3F, $3A, $F0, $2C, $11, $8E, $47, $A4, $6E, $87, $93, $BC, $A1, $74, $27, $7B, $EB
	dc.b	$9E, $50, $E2, $55, $AB, $76, $33, $61, $41, $31, $6A, $17, $34, $EB, $77, $37, $F5, $B4, $B0, $5C, $1D, $64, $EE, $62, $B2, $87, $DB, $16, $52, $2C, $E1, $1A
	dc.b	$4B, $97, $54, $AE, $19, $47, $25, $E2, $1D, $D9, $E1, $B8, $05, $97, $EA, $23, $FB, $38, $FE, $ED, $DB, $F1, $DF, $8B, $2D, $7B, $1B, $9D, $F3, $8F, $4A, $14
	dc.b	$DD, $D5, $45, $49, $7E, $BF, $17, $A6, $3F, $AE, $79, $76, $F2, $7C, $96, $98, $B1, $59, $93, $0C, $BB, $59, $1B, $55, $35, $4C, $9D, $45, $E3, $7B, $10, $E8
	dc.b	$A8, $79, $9C, $AD, $DD, $6F, $D5, $96, $1F, $D1, $B2, $61, $FC, $1C, $2B, $D3, $F5, $FA, $EC, $0D, $78, $91, $96, $43, $1D, $40, $55, $01, $8E, $C0, $2F, $BB
	dc.b	$18, $5C, $5F, $AF, $7C, $7F, $54, $65, $CB, $A7, $EB, $B9, $E8, $1F, $6C, $5F, $23, $EA, $FD, $E8, $37, $7E, $DC, $0A, $8E, $26, $A7, $FB, $74, $FF, $BF, $87
	dc.b	$FE, $F5, $6A, $B7, $EA, $FF, $7E, $0E, $3C, $62, $61, $DA, $80, $FF, $AD, $F7, $0B, $EE, $03, $13, $06, $0B, $A5, $77, $29, $8D, $8C, $B9, $DD, $A5, $70, $76
	dc.b	$72, $CF, $19, $66, $2F, $E1, $8D, $31, $CE, $FC, $E4, $B3, $CF, $D3, $F4, $49, $DD, $AB, $57, $FF, $C6, $45, $FC, $45, $31, $8E, $A0, $3F, $6B, $BF, $67, $EC
	dc.b	$D6, $E0, $98, $DC, $0A, $E1, $C8, $00, $08, $D4, $D7, $25, $32, $C8, $38, $C0, $00, $54, $CA, $B4, $F0, $8B, $EA, $7F, $EB, $23, $FB, $FC, $82, $FF, $50, $05
	dc.b	$D4, $07, $ED, $5A, $EB, $87, $2D, $82, $08, $57, $62, $8E, $E3, $13, $17, $99, $65, $13, $2C, $88, $C8, $EF, $32, $30, $00, $00, $00, $00, $00, $39, $F5, $3C
	dc.b	$6A, $00, $01, $1D, $F0, $7B, $9B, $57, $7C, $1E, $00, $03, $70, $BF, $70, $C6, $95, $20, $00, $0A, $B6, $FF, $E5, $31, $D8, $9F, $A2, $D8, $AF, $FD, $57, $EF
	dc.b	$64, $CF, $EC, $A3, $3F, $B2, $75, $6A, $FF, $C9, $41, $76, $4B, $61, $C3, $06, $6B, $B6, $BA, $E9, $5F, $53, $68, $DF, $FC, $FF, $A6, $BA, $8F, $F8, $24, $FD
	dc.b	$2F, $AE, $A4, $81, $7E, $B9, $BA, $24, $0B, $96, $3F, $AD, $91, $5C, $B6, $62, $DC, $56, $29, $93, $15, $AC, $5C, $13, $C9, $25, $49, $D7, $25, $95, $7A, $57
	dc.b	$2C, $15, $1E, $56, $D0, $A8, $52, $D3, $5A, $ED, $42, $CC, $AE, $9D, $6D, $04, $77, $E4, $C5, $7C, $9E, $8C, $C6, $5F, $FC, $D5, $FF, $E0, $5C, $62, $6E, $F1
	dc.b	$D5, $FA, $9F, $49, $D2, $70, $24, $AF, $04, $79, $EB, $4C, $19, $6F, $22, $69, $48, $98, $FD, $75, $EB, $C1, $D2, $ED, $B4, $8B, $F5, $86, $53, $B6, $9B, $1E
	dc.b	$92, $4B, $68, $B8, $31, $F3, $5E, $0D, $47, $C9, $78, $32, $B2, $87, $5F, $7F, $5A, $2B, $3F, $4A, $C2, $9D, $99, $B6, $04, $C2, $9D, $1B, $69, $BE, $68, $4D
	dc.b	$2B, $30, $AB, $C1, $A9, $0E, $8F, $56, $61, $0D, $F8, $E6, $5B, $B1, $62, $43, $13, $C2, $14, $2E, $2F, $38, $5A, $0F, $23, $81, $34, $AE, $AD, $5A, $8F, $B4
	dc.b	$A9, $19, $13, $DA, $EC, $3F, $58, $5D, $EC, $EC, $73, $29, $FA, $EF, $D6, $56, $81, $D9, $11, $97, $15, $32, $3D, $5F, $F8, $E3, $FA, $2E, $9B, $EF, $F4, $AF
	dc.b	$F5, $6B, $FD, $9D, $D5, $FF, $25, $50, $7F, $05, $52, $A4, $9D, $F3, $83, $A5, $D6, $49, $5A, $F2, $29, $A1, $36, $BF, $46, $AE, $F7, $36, $65, $6C, $59, $BE
	dc.b	$CC, $56, $3D, $94, $29, $AA, $30, $A8, $BC, $30, $C7, $82, $42, $65, $DB, $71, $C2, $B6, $15, $32, $83, $20, $5D, $AB, $5A, $4D, $8B, $95, $6F, $99, $50, $B2
	dc.b	$2C, $31, $64, $18, $4C, $B6, $9A, $F4, $8E, $1D, $9B, $65, $B6, $BF, $DF, $05, $C9, $78, $BB, $25, $D4, $05, $4D, $17, $B4, $04, $A8, $EF, $40, $00, $00, $0A
	dc.b	$90, $54, $D0, $61, $77, $C3, $71, $AE, $F8, $76, $0F, $E3, $6C, $6B, $BF, $66, $09, $09, $86, $57, $04, $04, $C0, $02, $9A, $E5, $89, $DE, $60, $00, $00, $53
	dc.b	$A8, $C5, $5F, $E1, $D6, $3B, $E0, $CB, $D1, $F0, $68, $24, $8D, $D5, $B9, $31, $B8, $AE, $27, $DE, $69, $79, $D4, $68, $BC, $5D, $93, $8C, $16, $B0, $00, $BC
	dc.b	$C5, $47, $31, $7E, $57, $99, $7F, $DF, $FE, $65, $CB, $A7, $0C, $0B, $87, $97, $3C, $13, $B7, $85, $FF, $B7, $23, $A8, $E3, $94, $72, $8E, $68, $E4, $C2, $BE
	dc.b	$EF, $D7, $BB, $F8, $28, $DF, $EF, $03, $05, $FD, $4D, $40, $5F, $B0, $63, $05, $65, $4C, $8A, $2F, $EB, $DF, $04, $5F, $D5, $19, $5C, $5F, $AF, $E1, $5E, $96
	dc.b	$DD, $67, $3E, $1C, $0F, $6F, $EB, $69, $92, $FE, $DC, $5E, $78, $99, $19, $1F, $82, $78, $5B, $FD, $9A, $B8, $75, $7E, $F8, $64, $EE, $31, $37, $6A, $03, $FE
	dc.b	$AE, $FE, $1B, $AE, $02, $E7, $64, $E4, $15, $A2, $9B, $98, $91, $35, $47, $19, $1C, $99, $7C, $99, $54, $AF, $A0, $AB, $4C, $3F, $57, $E1, $FC, $17, $7F, $3B
	dc.b	$90, $2F, $FA, $55, $A8, $06, $FE, $D5, $AE, $E5, $8A, $2D, $DB, $15, $09, $2F, $45, $C9, $22, $60, $DC, $64, $64, $65, $91, $18, $00, $00, $04, $4C, $54, $77
	dc.b	$BE, $AD, $4F, $00, $00, $37, $5F, $B8, $5F, $D5, $FA, $9F, $D6, $12, $79, $41, $4C, $9F, $D5, $FA, $DA, $15, $75, $1D, $5F, $E1, $15, $4A, $BB, $E4, $30, $FE
	dc.b	$B4, $CB, $FA, $72, $42, $BA, $DC, $2B, $5C, $F4, $FD, $6E, $B7, $7E, $DC, $47, $8B, $B3, $73, $09, $39, $FE, $BA, $B9, $A7, $F7, $87, $FD, $35, $0A, $77, $33
	dc.b	$4A, $36, $90, $66, $BB, $6B, $46, $5A, $BD, $AD, $A3, $55, $91, $3F, $D6, $46, $76, $D9, $B8, $B4, $D7, $6E, $0E, $49, $17, $EB, $9B, $A2, $42, $7B, $F8, $15
	dc.b	$D3, $2E, $8A, $85, $36, $D8, $B0, $3C, $1E, $D8, $15, $2B, $92, $B2, $0D, $D2, $58, $3B, $3D, $7A, $75, $62, $93, $AE, $85, $94, $6D, $02, $36, $13, $E4, $FD
	dc.b	$0F, $19, $13, $4B, $FB, $A4, $DF, $EF, $77, $0F, $FA, $6A, $1A, $FF, $59, $D5, $9E, $05, $BE, $2F, $AF, $F7, $6B, $85, $0D, $DD, $92, $4C, $4C, $93, $B1, $58
	dc.b	$49, $38, $B7, $AE, $0B, $D6, $ED, $64, $DF, $DC, $34, $B7, $AC, $EB, $6D, $A9, $65, $69, $31, $F4, $8B, $D1, $94, $2E, $08, $4F, $81, $53, $9B, $E0, $70, $61
	dc.b	$65, $06, $C1, $85, $47, $21, $60, $CA, $3B, $02, $C1, $CC, $6C, $A1, $9D, $7B, $6B, $D1, $36, $CA, $BF, $D7, $0E, $25, $E3, $FC, $1F, $0A, $92, $2D, $42, $31
	dc.b	$7B, $31, $40, $0C, $00, $2F, $4A, $9A, $0D, $CD, $86, $E3, $56, $DD, $99, $B5, $F7, $39, $1E, $D2, $42, $47, $22, $A2, $A5, $E8, $48, $75, $1D, $59, $17, $F1
	dc.b	$14, $C0, $03, $13, $A8, $C0, $D5, $1F, $DA, $BA, $11, $65, $53, $B3, $E2, $7D, $47, $73, $BA, $4A, $BD, $2C, $85, $6D, $7B, $6B, $EE, $53, $5F, $DB, $D4, $CA
	dc.b	$A4, $47, $FC, $75, $97, $F3, $53, $6C, $BA, $BF, $9C, $0D, $7F, $89, $AB, $F4, $AD, $FD, $2B, $4A, $E5, $E5, $8D, $CB, $C9, $C6, $0E, $39, $2F, $88, $00, $3B
	dc.b	$6E, $78, $CA, $E3, $11, $F1, $8E, $A1, $01, $51, $80, $00, $00, $00, $37, $63, $D8, $00, $0B, $DF, $52, $45, $A8, $19, $8A, $03, $23, $00, $45, $2A, $69, $C5
	dc.b	$B0, $79, $C5, $B0, $7E, $BE, $BB, $FA, $C0, $86, $F8, $2E, $E4, $54, $6B, $AE, $2B, $AB, $8A, $11, $E1, $BE, $26, $57, $17, $8A, $71, $8E, $B0, $33, $89, $97
	dc.b	$38, $9C, $F8, $63, $C6, $7C, $E7, $5B, $66, $C9, $F3, $9D, $6D, $46, $5F, $DD, $7D, $A1, $FB, $12, $E8, $EE, $1A, $24, $DA, $B2, $7B, $BB, $E6, $47, $83, $61
	dc.b	$74, $A9, $22, $64, $2E, $26, $4F, $69, $7E, $DC, $A7, $59, $71, $26, $3E, $54, $35, $64, $5B, $C3, $F9, $A5, $FE, $ED, $3F, $E9, $3E, $7E, $8D, $DD, $3E, $7E
	dc.b	$8E, $D2, $86, $AF, $58, $49, $06, $E7, $37, $AD, $66, $E9, $EF, $29, $B1, $6B, $6D, $2C, $53, $B3, $49, $94, $5E, $A6, $3F, $0E, $D4, $2C, $A0, $6C, $2C, $88
	dc.b	$F6, $33, $1C, $22, $6C, $6C, $A0, $CA, $F6, $CA, $BD, $13, $6D, $7F, $AE, $DB, $FE, $42, $D4, $00, $05, $FC, $56, $EC, $8A, $62, $65, $71, $5C, $10, $BC, $7C
	dc.b	$06, $3E, $18, $FE, $B7, $A9, $8B, $FC, $E4, $32, $FF, $21, $6A, $00, $08, $36, $A4, $85, $F9, $0C, $4C, $00, $00, $57, $C7, $F6, $20, $00, $05, $5B, $E0, $D8
	dc.b	$46, $E2, $45, $6B, $0B, $92, $A0, $2F, $10, $16, $17, $C1, $F7, $C3, $FA, $20, $0D, $BD, $BF, $AC, $65, $0B, $AF, $F5, $AD, $4A, $90, $BF, $62, $5D, $23, $2D
	dc.b	$12, $76, $FD, $B1, $E0, $D2, $E5, $C0, $99, $3E, $2C, $26, $44, $C9, $F2, $A1, $66, $4C, $74, $EE, $2F, $D9, $FF, $D3, $50, $02, $9D, $DB, $58, $E9, $F3, $D7
	dc.b	$1A, $66, $4F, $BD, $F1, $6F, $59, $4D, $60, $50, $2B, $4E, $D0, $26, $93, $17, $6F, $23, $6D, $18, $79, $9E, $CB, $F0, $77, $86, $DA, $EC, $86, $CB, $BF, $88
	dc.b	$5E, $2C, $CB, $B0, $C9, $15, $E1, $DE, $20, $3B, $8E, $3C, $5C, $F2, $FE, $89, $3C, $2F, $ED, $B7, $13, $59, $CB, $79, $24, $6E, $77, $F1, $2F, $CC, $8E, $39
	dc.b	$BF, $16, $BD, $D4, $61, $3C, $AD, $DC, $D9, $BE, $64, $D3, $C0, $A1, $69, $DB, $81, $35, $DB, $58, $FA, $31, $F4, $61, $B1, $D8, $2F, $ED, $E5, $46, $13, $35
	dc.b	$0F, $E2, $C4, $EF, $4A, $98, $5C, $5C, $CA, $99, $17, $AF, $F4, $40, $BF, $F6, $25, $DF, $BB, $B8, $99, $76, $CD, $B8, $2F, $8B, $E9, $1C, $DD, $D9, $FB, $60
	dc.b	$1A, $F6, $E3, $37, $CF, $F6, $A5, $0B, $4D, $0D, $CF, $A6, $65, $91, $60, $AC, $8C, $DA, $F6, $F6, $00, $04, $77, $97, $37, $5D, $0D, $B8, $3B, $24, $7D, $1D
	dc.b	$BB, $BC, $00, $0A, $5F, $A5, $75, $A6, $78, $D1, $85, $93, $9B, $FB, $10, $00, $0E, $D9, $D1, $BB, $08, $D3, $B5, $99, $13, $FB, $FB, $00, $00, $05, $85, $9B
	dc.b	$B1, $40
Championship_driver_tiles_2:
	dc.b	$02, $55, $81, $03, $00, $15, $0F, $26, $2C, $37, $6A, $48, $E8, $78, $EC, $82, $04, $02, $15, $12, $26, $32, $38, $E6, $78, $F1, $83, $04, $03, $16, $29, $27
	dc.b	$6C, $78, $F2, $84, $04, $04, $16, $2D, $28, $DE, $38, $F0, $85, $04, $06, $16, $28, $27, $68, $38, $EA, $86, $05, $10, $16, $30, $27, $69, $37, $72, $48, $E3
	dc.b	$58, $E2, $67, $66, $75, $11, $87, $08, $DF, $88, $06, $2A, $17, $67, $28, $EE, $89, $05, $0A, $16, $2F, $27, $6E, $8A, $06, $27, $17, $6B, $8B, $06, $2E, $18
	dc.b	$ED, $8C, $08, $E7, $8D, $05, $0E, $16, $2B, $27, $70, $8E, $05, $0B, $16, $26, $27, $63, $37, $6D, $48, $E9, $58, $EB, $77, $62, $FF, $FC, $BC, $37, $F0, $64
	dc.b	$FC, $BD, $18, $36, $1B, $F0, $B5, $91, $A1, $BE, $D6, $C1, $B4, $B4, $19, $28, $86, $8B, $59, $19, $1B, $F8, $9B, $10, $ED, $3D, $3B, $F8, $6F, $E1, $F9, $7E
	dc.b	$5B, $EC, $9A, $77, $F0, $A3, $7E, $88, $6F, $C1, $3F, $2E, $DA, $77, $D1, $91, $B9, $6F, $71, $A7, $EC, $E8, $8C, $79, $6F, $C6, $31, $86, $FC, $63, $18, $C6
	dc.b	$31, $8C, $63, $CB, $7E, $31, $C3, $7E, $31, $8E, $9D, $F8, $6F, $C7, $97, $FD, $3C, $20, $9F, $C5, $DE, $F2, $F2, $A7, $FE, $8C, $9F, $D5, $8F, $87, $F1, $61
	dc.b	$FD, $5F, $F1, $A7, $97, $97, $FD, $3F, $AB, $73, $47, $AB, $92, $7F, $97, $FE, $9E, $5E, $56, $D3, $9F, $5F, $EA, $ED, $BA, $DF, $FA, $C7, $FE, $BF, $F4, $F2
	dc.b	$A6, $DB, $B4, $78, $A1, $A5, $3A, $CB, $FE, $B1, $FF, $2F, $FD, $13, $65, $B7, $34, $3F, $EB, $FC, $2D, $9E, $3A, $2E, $D1, $74, $7F, $E9, $E1, $CD, $0D, $F6
	dc.b	$C1, $A0, $D7, $25, $2D, $6B, $6C, $9C, $A7, $CB, $5E, $CD, $77, $7F, $50, $E3, $FF, $49, $52, $49, $4F, $57, $83, $69, $DF, $86, $FC, $32, $D7, $29, $CA, $7C
	dc.b	$BF, $55, $E5, $0F, $F2, $F8, $1C, $87, $97, $FD, $21, $BF, $CB, $F2, $FA, $F2, $D6, $53, $CA, $72, $9C, $E7, $F2, $FF, $AA, $C1, $1F, $87, $F8, $ED, $3B, $4E
	dc.b	$DB, $A0, $D0, $DF, $85, $10, $9E, $5F, $C3, $D7, $FB, $39, $FF, $A6, $87, $77, $E5, $E1, $FC, $7E, $5B, $FA, $7F, $88, $76, $FE, $CE, $AF, $D9, $D4, $54, $F3
	dc.b	$53, $2A, $73, $CF, $57, $EA, $B9, $FB, $A7, $2C, $E6, $5F, $A7, $C3, $F4, $FC, $B7, $F4, $FF, $10, $ED, $AB, $CA, $47, $91, $E7, $E7, $23, $E7, $2A, $B2, $3A
	dc.b	$8C, $AA, $E7, $A8, $CA, $7A, $A9, $DF, $86, $FE, $9F, $FB, $FE, $5F, $FE, $86, $46, $47, $CC, $75, $48, $E5, $3E, $79, $CE, $AA, $6A, $9E, $A3, $AA, $73, $29
	dc.b	$CA, $7A, $A7, $AA, $98, $7F, $DF, $FC, $FF, $F4, $A7, $C4, $A7, $FE, $14, $F5, $4A, $79, $55, $3D, $53, $E7, $C8, $EA, $32, $CE, $74, $5B, $4C, $BF, $CE, $DF
	dc.b	$F4, $CB, $F6, $69, $FC, $2A, $79, $B3, $F3, $77, $11, $CB, $F9, $1F, $E2, $B0, $BF, $EE, $9F, $E5, $34, $FF, $19, $1F, $EA, $8E, $7F, $13, $FE, $15, $59, $7F
	dc.b	$60, $93, $FA, $5F, $A7, $A3, $F4, $FF, $F5, $FD, $9E, $F1, $CE, $5A, $CA, $72, $9C, $AA, $FE, $16, $79, $67, $CA, $A2, $AA, $47, $E3, $2F, $F3, $FF, $D5, $BC
	dc.b	$8B, $59, $7E, $A8, $FC, $6A, $2A, $8A, $A2, $A8, $B3, $CA, $7F, $1C, $BF, $2E, $DF, $C7, $FF, $AF, $91, $FF, $A0, $CB, $FA, $7E, $39, $4E, $5F, $CA, $AA, $7E
	dc.b	$7A, $B5, $D5, $2E, $79, $73, $E7, $9E, $53, $F3, $CF, $9C, $AA, $2C, $FA, $FF, $39, $3D, $5A, $EA, $3A, $A7, $AA, $7E, $7A, $B5, $E7, $E7, $CF, $F9, $CA, $BA
	dc.b	$33, $F3, $CF, $CE, $75, $4F, $9C, $AA, $3C, $E7, $57, $3F, $EE, $0E, $7A, $67, $3D, $75, $4E, $7D, $DC, $F3, $9D, $47, $51, $E7, $D7, $54, $F5, $4F, $54, $F5
	dc.b	$4F, $CF, $DD, $CF, $9F, $9F, $3B, $FF, $55, $54, $F9, $F5, $F7, $4F, $54, $E7, $3D, $53, $E7, $9F, $B8, $EA, $9F, $3C, $E7, $9E, $7A, $8E, $73, $9F, $3C, $F9
	dc.b	$CF, $3C, $F4, $D5, $3D, $53, $E7, $3E, $EF, $DD, $67, $9E, $A3, $EE, $3A, $A7, $CE, $7A, $F3, $CE, $7A, $E9, $A8, $FF, $90, $75, $4F, $55, $35, $1D, $53, $9D
	dc.b	$53, $F7, $4F, $54, $E7, $51, $CE, $7D, $C7, $FA, $AC, $FA, $EA, $9C, $E7, $EE, $A7, $FF, $15, $4F, $54, $F5, $4F, $55, $35, $6B, $3A, $8E, $7E, $EA, $6A, $D6
	dc.b	$7A, $F3, $CE, $7A, $FB, $A7, $EE, $3D, $7F, $E8, $9E, $A9, $FB, $8F, $FB, $1A, $EA, $9F, $B8, $F3, $CE, $75, $1F, $F6, $35, $D5, $4C, $FF, $D8, $9C, $E7, $A8
	dc.b	$EA, $39, $F3, $CF, $9C, $AA, $32, $32, $A6, $79, $54, $53, $CB, $3C, $FF, $D8, $9C, $E7, $3F, $DC, $53, $DD, $3D, $47, $3F, $71, $CF, $DC, $73, $D3, $3D, $5F
	dc.b	$BA, $A8, $F5, $E5, $3D, $53, $E7, $2C, $E7, $DD, $3E, $73, $A8, $F5, $9D, $53, $E7, $9E, $A3, $EE, $3F, $E4, $4E, $75, $4F, $54, $FF, $B8, $A6, $A3, $9C, $FF
	dc.b	$54, $7F, $BA, $AB, $5F, $74, $FD, $D3, $D4, $79, $CF, $39, $D5, $3D, $47, $54, $FF, $B8, $9E, $A3, $EE, $9F, $F7, $13, $9C, $F5, $4F, $54, $F9, $CE, $A3, $AA
	dc.b	$7A, $8E, $7A, $A7, $CF, $AC, $E3, $18, $C7, $33, $71, $35, $DC, $6C, $85, $C6, $C6, $23, $18, $C5, $3F, $57, $BC, $D6, $D2, $46, $47, $20, $56, $17, $64, $63
	dc.b	$18, $F5, $69, $63, $4F, $E9, $BF, $F8, $5F, $D1, $20, $51, $8C, $63, $86, $8C, $1A, $9F, $E9, $76, $7F, $45, $42, $31, $8C, $70, $D1, $83, $53, $FD, $2E, $C7
	dc.b	$A9, $EA, $7C, $63, $18, $E1, $A3, $06, $A7, $FA, $5D, $9D, $91, $8C, $60, $DC, $5A, $21, $42, $35, $92, $05, $FD, $15, $BE, $FF, $E8, $C6, $31, $8F, $56, $F3
	dc.b	$74, $17, $65, $8A, $D4, $A1, $18, $C6, $36, $D1, $6B, $20, $27, $93, $CB, $B1, $5F, $E1, $8C, $63, $1F, $FA, $02, $B2, $5D, $81, $5D, $0A, $11, $8C, $63, $E1
	dc.b	$FB, $3F, $E9, $6A, $2E, $CE, $88, $C6, $31, $F2, $EC, $FF, $09, $76, $46, $31, $8F, $F0, $F2, $05, $D8, $0A, $C5, $76, $46, $31, $8E, $54, $91, $97, $67, $F4
	dc.b	$56, $14, $37, $59, $18, $C6, $3F, $C3, $C8, $17, $60, $2F, $F0, $AA, $C5, $46, $31, $8F, $F0, $86, $4F, $2E, $CF, $E8, $AA, $C5, $08, $C6, $31, $90, $90, $CB
	dc.b	$B1, $EB, $EC, $7D, $F1, $8C, $62, $24, $39, $B5, $2F, $FA, $2B, $0B, $E8, $5B, $EF, $8C, $63, $C6, $D7, $43, $FC, $47, $D8, $A0, $A0, $56, $29, $EA, $0A, $7F
	dc.b	$1B, $19, $71, $20, $E3, $63, $2E, $36, $B8, $A1, $BF, $CA, $E2, $CD, $76, $6B, $B3, $37, $67, $F4, $57, $FD, $15, $DF, $FE, $15, $1A, $5C, $85, $63, $71, $D1
	dc.b	$C6, $C6, $9C, $98, $D8, $C4, $AC, $57, $F4, $49, $43, $FF, $2A, $FE, $6A, $DD, $88, $D0, $E5, $49, $36, $14, $21, $CA, $83, $6D, $21, $61, $40, $94, $17, $FD
	dc.b	$90, $A7, $2F, $F9, $3F, $DD, $BF, $A7, $80, $FF, $71, $6A, $C7, $06, $42, $32, $0B, $50, $50, $53, $EF, $1F, $D9, $1F, $C9, $1B, $B8, $5F, $C2, $6F, $DE, $AD
	dc.b	$D3, $0E, $91, $D6, $26, $18, $D4, $3F, $B2, $2F, $5A, $B8, $29, $D7, $AE, $FE, $18, $EF, $76, $2C, $58, $B1, $05, $AB, $A1, $63, $F9, $22, $F9, $94, $EB, $EB
	dc.b	$BE, $BB, $E6, $FE, $EE, $25, $6D, $BD, $6A, $FF, $75, $E1, $4B, $B3, $70, $FF, $CA, $BF, $9B, $7F, $05, $56, $AA, $D7, $FD, $DC, $6A, $C5, $88, $5E, $B0, $A0
	dc.b	$A5, $FE, $E4, $5E, $EF, $F4, $8D, $CE, $54, $CE, $BE, $B5, $4D, $FB, $D5, $DF, $B5, $4B, $DD, $35, $FB, $77, $3E, $F1, $78, $DC, $3F, $F3, $B9, $7F, $C9, $99
	dc.b	$58, $95, $D7, $7E, $2C, $6A, $0A, $0A, $D5, $FC, $90, $A0, $AA, $FF, $D3, $5A, $9D, $7A, $F8, $63, $56, $37, $6D, $BF, $AD, $43, $86, $32, $0A, $0A, $7A, $C6
	dc.b	$E7, $AC, $7F, $E4, $7F, $A5, $77, $AF, $F7, $B3, $2B, $17, $FB, $87, $4E, $AD, $CF, $FD, $C8, $BC, $28, $7F, $E6, $F7, $2B, $82, $9D, $7B, $95, $B5, $4E, $C5
	dc.b	$8A, $6F, $DC, $85, $0B, $DD, $FB, $9A, $D4, $EF, $DC, $B8, $2B, $F7, $AA, $76, $E5, $85, $D6, $B5, $4C, $31, $62, $DA, $A1, $7B, $AF, $1B, $AB, $FD, $CF, $F3
	dc.b	$6F, $5A, $B1, $F0, $C5, $D6, $AC, $58, $A6, $17, $AD, $EA, $5D, $F8, $FF, $72, $ED, $CB, $BF, $FF, $AA, $AF, $16, $2C, $5B, $7F, $72, $B1, $FD, $95, $FE, $E6
	dc.b	$BF, $E4, $B9, $5F, $FD, $AF, $14, $CA, $C5, $89, $6A, $98, $2F, $F9, $22, $6B, $DD, $FC, $97, $29, $CA, $FE, $6A, $9D, $D7, $5E, $2C, $4B, $1D, $7F, $C9, $AC
	dc.b	$B7, $38, $56, $14, $EB, $DD, $BA, $B5, $D7, $78, $EB, $76, $2C, $58, $97, $C7, $42, $71, $32, $71, $31, $71, $31, $E6, $4C, $C9, $99, $33, $26, $82, $32, $7D
	dc.b	$A6, $5A, $8D, $92, $88, $21, $91, $FF, $15, $1B, $8D, $A3, $18, $37, $16, $F9, $23, $71, $96, $62, $4E, $23, $DE, $64, $64, $8C, $63, $1D, $29, $45, $BA, $7C
	dc.b	$1B, $06, $2B, $4E, $D6, $49, $1A, $1E, $94, $6E, $24, $CC, $D9, $AE, $E5, $6B, $F6, $A1, $A4, $28, $B8, $F0, $A2, $0D, $85, $A7, $FC, $5C, $1B, $4B, $46, $31
	dc.b	$86, $23, $21, $D3, $0A, $10, $B1, $D0, $87, $72, $53, $85, $1A, $5B, $89, $A2, $D9, $AE, $C5, $88, $7F, $B9, $E4, $16, $F5, $9E, $8B, $90, $82, $69, $68, $50
	dc.b	$9C, $4D, $76, $0D, $83, $43, $16, $2E, $B5, $6D, $56, $35, $0F, $F7, $42, $E4, $32, $34, $B9, $A1, $A2, $0D, $A5, $B4, $D1, $FE, $E1, $D2, $AC, $4A, $C5, $33
	dc.b	$D6, $2F, $5F, $6D, $3C, $DA, $20, $D7, $75, $42, $8B, $A8, $EB, $72, $BA, $6B, $56, $D7, $7F, $E6, $CE, $9B, $0A, $94, $64, $7F, $F5, $49, $21, $FC, $53, $67
	dc.b	$90, $76, $3D, $5C, $17, $FD, $1A, $FF, $C2, $EA, $79, $82, $ED, $D1, $71, $95, $D4, $41, $A1, $41, $E8, $86, $8C, $5F, $EE, $FF, $EB, $BF, $C3, $8C, $6D, $05
	dc.b	$49, $1A, $1A, $51, $06, $E4, $D8, $37, $2C, $7F, $CD, $1C, $03, $87, $00, $E0, $E0, $EE, $82, $0E, $FF, $0B, $9A, $DA, $2E, $B6, $8B, $9A, $0D, $0D, $17, $60
	dc.b	$D8, $62, $98, $75, $FF, $75, $75, $85, $8F, $FE, $B9, $F4, $93, $E4, $70, $A0, $8D, $A1, $44, $12, $49, $86, $2C, $5F, $EE, $FF, $EF, $45, $6F, $D8, $97, $50
	dc.b	$94, $41, $A0, $D0, $D1, $C9, $93, $68, $C5, $8F, $FF, $B5, $87, $07, $07, $7F, $85, $C6, $D0, $6B, $AD, $08, $DA, $68, $09, $C6, $C5, $D6, $31, $63, $FD, $E8
	dc.b	$FD, $E8, $AC, $39, $EE, $E8, $34, $97, $EC, $D3, $32, $66, $58, $C5, $30, $C6, $E5, $FF, $F6, $B0, $B0, $B1, $B6, $CF, $0A, $11, $B8, $93, $32, $36, $25, $8E
	dc.b	$BF, $FE, $D8, $4E, $D5, $27, $AC, $2F, $4D, $08, $65, $C4, $6D, $C4, $8D, $9A, $EC, $CD, $0D, $FE, $36, $CC, $DB, $FC, $4D, $C4, $C9, $98, $F3, $24, $37, $E3
	dc.b	$18, $EF, $F1, $DA, $DC, $9B, $99, $B4, $9B, $21, $F2, $24, $68, $A6, $66, $CC, $D9, $AE, $CD, $76, $64, $CC, $99, $92, $3A, $53, $35, $D9, $AE, $CD, $76, $6B
	dc.b	$B3, $5D, $A5, $B4, $B6, $6A, $20, $DC, $6D, $1C, $CD, $A5, $B4, $D1, $A6, $88, $36, $66, $E3, $68, $37, $13, $66, $6C, $34, $43, $44, $1A, $0D, $C7, $44, $28
	dc.b	$D2, $D8, $34, $1B, $4B, $60, $D0, $A3, $4E, $88, $68, $83, $61, $44, $28, $B9, $B0, $A2, $0D, $75, $10, $6C, $19, $3A, $A1, $42, $60, $D0, $68, $75, $43, $FE
	dc.b	$BD, $44, $85, $85, $09, $63, $61, $44, $13, $FC, $A9, $FE, $53, $A2, $1D, $48, $DA, $58, $52, $90, $68, $31, $83, $09, $42, $13, $D4, $49, $4D, $8A, $26, $83
	dc.b	$41, $B0, $4E, $A8, $34, $19, $1A, $0D, $0D, $07, $0D, $09, $41, $5A, $08, $D9, $E6, $CF, $42, $B0, $9E, $82, $FD, $46, $50, $6E, $4D, $C9, $B4, $B7, $1B, $41
	dc.b	$B8, $DB, $4D, $10, $6C, $18, $A8, $82, $1A, $10, $4A, $0D, $E4, $B3, $2B, $2F, $A1, $20, $DA, $68, $4C, $1B, $4D, $18, $34, $1A, $14, $61, $A0, $D0, $F4, $5B
	dc.b	$FE, $12, $51, $6A, $50, $5A, $82, $82, $9C, $30, $34, $A7, $4D, $08, $C5, $A1, $19, $21, $6C, $12, $84, $A0, $D8, $D1, $8D, $18, $AD, $06, $56, $18, $53, $D4
	dc.b	$F3, $55, $6A, $75, $E1, $A0, $DC, $9B, $8A, $88, $34, $1A, $0D, $06, $E3, $68, $68, $38, $68, $46, $95, $B6, $25, $2F, $51, $58, $AA, $D4, $E5, $27, $13, $26
	dc.b	$0D, $A5, $0F, $06, $D3, $6F, $12, $1C, $1B, $4B, $18, $68, $34, $28, $31, $A3, $49, $28, $B7, $8C, $81, $B7, $12, $36, $64, $E2, $63, $6E, $3A, $13, $0A, $21
	dc.b	$42, $41, $88, $10, $DE, $3A, $C3, $A5, $5A, $EB, $E2, $4C, $D7, $66, $6C, $CD, $06, $E4, $87, $A3, $06, $04, $C7, $A0, $9E, $80, $D9, $02, $EB, $E2, $BB, $33
	dc.b	$66, $6C, $CD, $87, $54, $1A, $06, $46, $C9, $44, $83, $9F, $68, $FE, $6B, $D7, $BF, $C4, $79, $8F, $89, $93, $32, $66, $4C, $C7, $99, $33, $31, $53, $C7, $24
	dc.b	$6E, $44, $13, $8C, $A9, $E3, $23, $4E, $32, $A7, $8C, $A9, $E3, $23, $A3, $32, $66, $4C, $C9, $99, $30, $6D, $2D, $76, $66, $CD, $73, $41, $B9, $24, $74, $B6
	dc.b	$66, $CC, $D1, $E3, $68, $34, $1B, $8D, $B9, $34, $19, $1B, $06, $83, $19, $36, $96, $D2, $D9, $9A, $0D, $C6, $DC, $9A, $14, $72, $23, $D1, $04, $27, $92, $19
	dc.b	$26, $A4, $79, $6A, $85, $1A, $50, $9A, $0D, $06, $43, $10, $62, $A0, $DE, $C8, $09, $2C, $64, $C9, $EA, $06, $4F, $55, $6B, $30, $A9, $95, $A8, $B1, $88, $35
	dc.b	$A4, $1C, $2D, $D5, $5D, $8A, $0E, $0E, $0A, $72, $9E, $E5, $DE, $BD, $C3, $6B, $94, $E9, $86, $37, $63, $0B, $1D, $2F, $B4, $6E, $73, $C8, $6E, $73, $F7, $4C
	dc.b	$A7, $A9, $77, $AF, $F7, $2B, $53, $D6, $ED, $CB, $04, $E5, $3E, $F0, $4E, $DD, $C0, $7F, $25, $61, $77, $E3, $D4, $A5, $A9, $62, $67, $A8, $3B, $1A, $9F, $7B
	dc.b	$A6, $7D, $F5, $CC, $FF, $DC, $B9, $63, $75, $73, $58, $A0, $A7, $63, $0E, $53, $B6, $85, $BB, $A5, $5D, $2A, $FF, $72, $BF, $DC, $E5, $8C, $58, $96, $A5, $B9
	dc.b	$5D, $21, $6E, $C5, $33, $DD, $D2, $E7, $BB, $A5, $C2, $BD, $AE, $7D, $78, $DC, $2B, $0E, $9A, $B5, $B9, $5F, $EE, $76, $2C, $58, $BF, $DD, $C3, $A5, $C2, $BD
	dc.b	$AE, $0A, $76, $D7, $2A, $BF, $F7, $28, $87, $48, $92, $A6, $72, $AC, $76, $30, $46, $1C, $B1, $7C, $B8, $05, $09, $3E, $B5, $03, $C8, $56, $A0, $AE, $0B, $AD
	dc.b	$4E, $EB, $76, $2C, $58, $B1, $8C, $55, $90, $76, $3F, $DE, $89, $86, $2C, $58, $C3, $BA, $C2, $9D, $D2, $A7, $6D, $77, $FB, $9C, $25, $B5, $DB, $5D, $B7, $80
	dc.b	$72, $EB, $E8, $AD, $41, $CA, $0A, $5D, $6A, $70, $50, $52, $F8, $2D, $D8, $96, $E5, $BA, $6E, $03, $1B, $B6, $87, $7F, $B9, $DD, $62, $67, $07, $2D, $5B, $5D
	dc.b	$32, $BF, $DD, $FB, $DE, $9C, $C9, $C5, $46, $66, $CC, $99, $AE, $CC, $99, $8F, $31, $95, $AD, $C8, $91, $93, $91, $A4, $12, $0D, $81, $24, $13, $91, $24, $13
	dc.b	$06, $81, $24, $0F, $06, $80, $48, $26, $96, $09, $06, $8B, $46, $31, $68, $C1, $B3, $51, $C7, $44, $1A, $0D, $A5, $B4, $A4, $1B, $4B, $40, $DA, $14, $60, $C6
	dc.b	$D8, $34, $1A, $08, $D8, $36, $0C, $6D, $0D, $18, $25, $16, $C2, $83, $2A, $44, $28, $37, $A1, $F1, $36, $96, $85, $10, $A3, $4F, $56, $14, $78, $50, $46, $40
	dc.b	$D2, $91, $6B, $D0, $20, $2E, $84, $A4, $2D, $FA, $21, $41, $2D, $BC, $09, $E8, $40, $D3, $19, $90, $34, $13, $1B, $DC, $4F, $58, $53, $97, $A9, $4E, $99, $CB
	dc.b	$70, $50, $52, $D4, $B7, $09, $02, $C6, $F2, $58, $20, $E5, $89, $AB, $0E, $5E, $A7, $3D, $CB, $43, $21, $C3, $27, $B8, $39, $61, $75, $BC, $C2, $DE, $41, $62
	dc.b	$60, $42, $65, $2D, $EA, $5B, $96, $A5, $BD, $4E, $0A, $72, $C5, $EE, $52, $C3, $82, $9C, $A9, $83, $89, $4E, $BC, $2E, $5F, $BD, $0B, $20, $E0, $A7, $58, $E5
	dc.b	$BD, $7C, $04, $C1, $61, $55, $AF, $F7, $A4, $E0, $E7, $B9, $7D, $0E, $99, $D6, $2D, $E4, $F5, $D8, $84, $F9, $2C, $13, $DD, $32, $9D, $FB, $97, $63, $72, $96
	dc.b	$15, $B5, $CA, $0A, $76, $35, $2E, $B7, $AC, $4C, $F7, $05, $89, $B6, $07, $10, $5B, $C8, $38, $13, $B7, $70, $5F, $EE, $66, $0B, $BD, $6A, $72, $D4, $17, $FB
	dc.b	$97, $05, $85, $0B, $DC, $F7, $2D, $5A, $94, $E2, $0A, $14, $85, $10, $50, $90, $BD, $CA, $5B, $B1, $EE, $72, $9D, $35, $7B, $9C, $B7, $2E, $F5, $A9, $6F, $5A
	dc.b	$9D, $37, $F3, $57, $58, $98, $70, $7B, $97, $5F, $43, $A6, $70, $93, $DC, $B7, $58, $E7, $B9, $75, $8A, $C7, $EF, $5E, $B7, $05, $BD, $D3, $70, $21, $30, $98
	dc.b	$2D, $F5, $CD, $20, $64, $B0, $E5, $0C, $75, $AE, $F5, $8A, $C6, $3B, $DC, $A7, $AA, $6D, $C2, $F5, $A9, $F7, $ED, $56, $30, $B1, $B5, $E4, $1D, $30, $50, $23
	dc.b	$B1, $CA, $04, $64, $A0, $E7, $AC, $83, $A6, $04, $14, $E5, $AB, $53, $96, $A7, $AC, $3A, $6A, $46, $D1, $4A, $DE, $BE, $8F, $EE, $AD, $F5, $BD, $4B, $0B, $50
	dc.b	$27, $A9, $DC, $CF, $53, $A4, $37, $3A, $67, $B9, $6E, $C6, $14, $B0, $BA, $D7, $64, $D7, $D7, $D6, $14, $EE, $95, $57, $D6, $EC, $58, $B1, $B9, $4E, $E9, $70
	dc.b	$53, $A6, $0E, $BD, $DD, $2E, $7A, $C2, $A6, $72, $82, $EF, $74, $CE, $52, $F8, $4C, $EE, $9A, $D6, $EC, $6F, $72, $C3, $B1, $9F, $09, $83, $9F, $C0, $29, $CB
	dc.b	$0B, $50, $55, $73, $39, $42, $BD, $AE, $5B, $96, $31, $4C, $E9, $82, $C1, $38, $38, $84, $C4, $ED, $4B, $04, $F7, $66, $4C, $C9, $9A, $EC, $C9, $98, $F4, $B6
	dc.b	$0C, $7A, $5A, $0C, $87, $87, $52, $4C, $90, $4E, $40, $E0, $9C, $82, $41, $30, $64, $0D, $06, $DE, $31, $74, $19, $0E, $4B, $3B, $A9, $94, $EB, $E7, $A6, $53
	dc.b	$89, $8E, $53, $85, $F2, $68, $32, $34, $28, $B4, $8D, $19, $0E, $DC, $B6, $21, $3C, $8C, $8C, $82, $C4, $F9, $1A, $E5, $38, $23, $B6, $42, $79, $23, $21, $19
	dc.b	$50, $40, $D0, $82, $18, $27, $9D, $85, $61, $02, $BC, $11, $BD, $4B, $51, $C9, $EA, $98, $C8, $10, $30, $B2, $0A, $27, $93, $D4, $BB, $16, $16, $F9, $4C, $16
	dc.b	$47, $FD, $12, $17, $99, $09, $2D, $4B, $23, $7A, $C2, $96, $10, $BA, $48, $C8, $63, $04, $64, $26, $92, $EF, $70, $23, $7A, $EF, $7C, $A6, $57, $41, $2B, $52
	dc.b	$C1, $D9, $8C, $10, $98, $2E, $4F, $98, $10, $27, $AD, $E4, $F9, $05, $87, $19, $19, $05, $87, $10, $42, $79, $B8, $65, $AA, $63, $2B, $14, $B0, $42, $FB, $29
	dc.b	$0A, $5A, $9E, $46, $14, $B0, $5D, $72, $72, $FF, $7A, $F3, $C8, $70, $79, $58, $E0, $AF, $E8, $F3, $AC, $2C, $2C, $73, $9A, $C4, $C3, $9C, $8D, $58, $E7, $32
	dc.b	$D9, $D0, $4B, $E8, $59, $58, $BB, $0C, $B9, $C2, $C2, $D4, $B9, $73, $BD, $4B, $07, $9F, $9C, $4C, $10, $CA, $7F, $DC, $A1, $97, $3B, $D4, $32, $79, $07, $02
	dc.b	$06, $08, $C2, $C1, $5A, $11, $E4, $68, $41, $24, $60, $9E, $96, $73, $1D, $88, $75, $49, $E5, $4D, $59, $02, $0A, $05, $7F, $F4, $6B, $14, $C9, $E4, $11, $88
	dc.b	$10, $30, $C8, $F4, $79, $DB, $23, $12, $A4, $52, $B2, $12, $04, $60, $84, $CE, $B1, $D3, $56, $24, $09, $C2, $54, $AE, $C2, $B4, $2C, $9F, $23, $7A, $02, $0B
	dc.b	$04, $09, $EB, $E8, $5B, $CD, $08, $4C, $E0, $B3, $25, $F0, $79, $05, $BD, $D9, $4C, $08, $1A, $1C, $D6, $4B, $18, $99, $F3, $0D, $AF, $58, $DA, $31, $BC, $83
	dc.b	$96, $E2, $5B, $DC, $B7, $02, $D4, $E7, $AC, $16, $A9, $9F, $58, $99, $FC, $01, $2C, $B6, $EA, $5B, $CD, $0C, $48, $6D, $05, $64, $CF, $25, $BE, $60, $A1, $8D
	dc.b	$FB, $AC, $21, $30, $A4, $49, $77, $C8, $2C, $4D, $AA, $61, $33, $C9, $EE, $B3, $F7, $35, $92, $97, $C2, $60, $B1, $B5, $EB, $20, $A5, $8B, $D6, $56, $2A, $B5
	dc.b	$8B, $C9, $D8, $EC, $20, $41, $4E, $EB, $0A, $76, $37, $2C, $5F, $C1, $4E, $7A, $83, $94, $1D, $62, $9C, $A7, $E4, $14, $E2, $30, $B1, $7B, $81, $B9, $6F, $25
	dc.b	$04, $FF, $6B, $C8, $3A, $C5, $BC, $A9, $25, $02, $04, $0C, $A6, $32, $0B, $7A, $82, $18, $20, $A0, $A3, $43, $23, $B1, $89, $E4, $0D, $1F, $24, $6E, $83, $42
	dc.b	$0B, $BC, $15, $85, $78, $5B, $CA, $C3, $20, $B1, $2A, $5E, $B2, $49, $1E, $A9, $05, $85, $C8, $75, $5B, $32, $1F, $E7, $3F, $73, $6E, $1A, $20, $97, $5B, $75
	dc.b	$B7, $7E, $DE, $8F, $CB, $F9, $4F, $4C, $A7, $95, $C6, $9B, $2D, $5F, $E7, $0B, $52, $F5, $6F, $72, $6C, $1A, $DB, $AD, $BA, $DF, $D3, $B7, $ED, $FC, $B5, $CA
	dc.b	$72, $9C, $93, $F5, $7B, $D7, $0A, $50, $AC, $FF, $23, $43, $42, $1F, $81, $DB, $B3, $7F, $AA, $0D, $0D, $85, $49, $19, $4F, $23, $91, $A5, $C9, $A3, $B4, $AC
	dc.b	$98, $2E, $DF, $E9, $A5, $28, $C8, $47, $6F, $F0, $CA, $1D, $A7, $A5, $88, $CA, $94, $34, $3E, $63, $23, $B9, $3F, $57, $A1, $6F, $3D, $5F, $B3, $F1, $20, $40
	dc.b	$BF, $67, $97, $FD, $7C, $29, $B4, $8F, $FA, $5F, $F5, $04, $F9, $9F, $2D, $4B, $04, $24, $3F, $84, $64, $65, $4C, $1B, $4B, $41, $91, $B7, $A8, $4C, $87, $37
	dc.b	$F9, $0C, $52, $26, $D4, $42, $F7, $D3, $69, $B2, $32, $1A, $52, $94, $B4, $3F, $8B, $04, $6B, $4F, $7B, $C5, $0D, $08, $F2, $58, $C7, $AF, $B0, $36, $F5, $1E
	dc.b	$06, $87, $E1, $FE, $5D, $89, $4D, $B2, $D8, $94, $E4, $79, $1A, $17, $E7, $35, $17, $42, $C3, $1C, $B5, $7F, $D3, $A9, $0D, $0D, $3F, $87, $BC, $7F, $D4, $F1
	dc.b	$1C, $E7, $50, $2A, $5F, $CE, $40, $8C, $97, $62, $C2, $C5, $33, $9C, $FF, $AC, $39, $6C, $93, $25, $1E, $1B, $25, $67, $8B, $CC, $64, $0A, $D2, $39, $59, $FA
	dc.b	$C2, $0A, $D4, $AB, $29, $90, $20, $56, $E8, $4A, $07, $36, $C9, $1E, $54, $82, $12, $43, $5A, $9E, $62, $53, $28, $1E, $5A, $88, $C9, $E5, $FE, $16, $FE, $A1
	dc.b	$95, $32, $39, $7F, $0D, $29, $9A, $CE, $B1, $8E, $C5, $89, $81, $70, $7A, $F5, $39, $FC, $29, $FC, $E3, $85, $7F, $C2, $06, $5E, $41, $66, $90, $40, $61, $61
	dc.b	$A0, $7C, $E6, $16, $11, $8F, $9C, $E6, $06, $92, $30, $BA, $5B, $27, $CC, $31, $90, $90, $90, $F2, $21, $21, $FB, $3C, $81, $6F, $1C, $81, $6C, $42, $79, $1F
	dc.b	$32, $C2, $FA, $17, $FD, $19, $02, $7D, $3C, $D3, $11, $8C, $8F, $99, $EB, $95, $85, $D8, $56, $49, $FC, $CB, $7C, $C2, $60, $6F, $C8, $73, $02, $7D, $6F, $35
	dc.b	$12, $02, $39, $28, $8D, $79, $05, $83, $59, $3C, $9E, $4F, $C9, $64, $73, $0C, $6F, $E6, $0B, $04, $F5, $82, $98, $21, $29, $EA, $36, $92, $C2, $96, $0C, $9F
	dc.b	$35, $84, $26, $D4, $4F, $C7, $D8, $F9, $74, $2C, $9E, $4F, $58, $20, $B0, $40, $BF, $A2, $B0, $A5, $BD, $76, $2F, $A1, $67, $FE, $19, $7F, $85, $97, $D0, $B2
	dc.b	$04, $08, $10, $39, $CA, $79, $4F, $2F, $FB, $FF, $D7, $CA, $A3, $B6, $E4, $ED, $D8, $54, $94, $F9, $6B, $29, $F9, $E5, $3C, $A7, $2F, $D5, $16, $BC, $BF, $EF
	dc.b	$FF, $5F, $2B, $92, $EB, $7F, $57, $AF, $9C, $16, $BF, $CE, $0E, $7B, $39, $FF, $55, $2E, $7F, $D5, $64, $72, $32, $FF, $BF, $57, $2F, $D9, $91, $CB, $B5, $3B
	dc.b	$77, $BC, $65, $CE, $5F, $AC, $1A, $CB, $5F, $3C, $E4, $7F, $C2, $32, $FC, $BF, $F1, $74, $E8, $D3, $FE, $32, $4A, $6E, $6E, $D6, $F1, $1F, $AC, $07, $E2, $24
	dc.b	$94, $E4, $6D, $1C, $D4, $FF, $52, $1F, $AB, $B6, $9F, $E9, $6B, $90, $CA, $7F, $12, $3B, $4D, $3F, $56, $DD, $BF, $C4, $BB, $0F, $E2, $DB, $FB, $BB, $65, $B2
	dc.b	$47, $FB, $A1, $AC, $BB, $3C, $68, $83, $69, $6F, $E2, $1E, $7F, $D5, $A6, $CF, $F2, $76, $99, $7F, $0C, $A7, $FF, $17, $67, $F0, $BF, $54, $D0, $6C, $19, $1B
	dc.b	$FA, $46, $5B, $13, $65, $B7, $25, $DD, $5C, $DF, $B3, $F1, $D5, $38, $FD, $D7, $F4, $A0, $D0, $64, $ED, $84, $8C, $8C, $8C, $A8, $B7, $9B, $45, $BA, $3C, $BC
	dc.b	$67, $94, $F9, $55, $FE, $2A, $9A, $E4, $3A, $8E, $A3, $F1, $46, $4D, $92, $6F, $E5, $E1, $4E, $7E, $6F, $2F, $1C, $F2, $AB, $2A, $8D, $3F, $76, $C7, $2D, $99
	dc.b	$7F, $8F, $0D, $1A, $6A, $A6, $AF, $0F, $E1, $91, $F8, $95, $45, $56, $46, $97, $25, $DF, $C5, $FE, $10, $95, $3F, $D2, $85, $16, $E8, $FE, $23, $5B, $92, $1A
	dc.b	$32, $65, $B2, $5B, $DF, $B3, $DE, $85, $10, $A3, $C6, $5F, $DA, $6F, $06, $46, $B5, $A0, $DB, $CD, $BD, $A1, $39, $8F, $24, $D8, $94, $93, $6F, $35, $CD, $77
	dc.b	$F4, $84, $A9, $FE, $17, $87, $51, $A7, $F0, $D1, $AD, $64, $3B, $7C, $76, $48, $CA, $7F, $DD, $B7, $EA, $FF, $A4, $3F, $A4, $65, $53, $23, $27, $56, $F1, $B5
	dc.b	$A6, $DE, $07, $69, $CB, $65, $BA, $CB, $5D, $89, $72, $7F, $2F, $23, $E6, $3E, $EA, $65, $46, $F6, $8A, $7F, $E9, $DA, $D7, $21, $FF, $D5, $F3, $8D, $72, $FF
	dc.b	$A6, $40, $86, $5F, $E3, $D0, $9D, $5F, $F4, $FE, $1C, $93, $FE, $B2, $04, $F2, $DE, $FD, $9F, $8C, $BC, $BF, $EA, $86, $5F, $C3, $FF, $2A, $51, $69, $95, $3B
	dc.b	$DB, $08, $E4, $F2, $B3, $F8, $64, $64, $69, $FC, $32, $D1, $BD, $23, $2D, $85, $4D, $BF, $D5, $43, $23, $48, $32, $64, $39, $9E, $BB, $08, $7F, $08, $F9, $8C
	dc.b	$A9, $95, $25, $FB, $34, $39, $1F, $36, $F3, $78, $1E, $46, $94, $78, $F6, $19, $52, $5B, $3F, $A4, $65, $BC, $C9, $B3, $C5, $29, $43, $DE, $6D, $34, $5D, $BF
	dc.b	$96, $B7, $AB, $18, $58, $98, $F2, $39, $1F, $89, $A1, $02, $04, $9F, $C2, $D8, $86, $5F, $C3, $DF, $EA, $B9, $B7, $EF, $9B, $70, $C4, $54, $F3, $09, $6C, $CB
	dc.b	$62, $31, $6C, $CA, $99, $79, $6F, $B5, $DF, $97, $6B, $B7, $EC, $9F, $56, $22, $A7, $98, $4B, $66, $5B, $11, $8B, $66, $54, $CB, $CB, $F2, $F4, $7E, $DE, $C2
	dc.b	$7D, $F3, $0E, $9C, $9F, $CC, $64, $7E, $02, $D6, $B6, $0D, $CC, $65, $E5, $4E, $FF, $F9, $66, $52, $D5, $33, $FA, $54, $BD, $5B, $81, $EF, $68, $E2, $46, $49
	dc.b	$79, $1A, $1C, $8E, $8F, $EA, $2C, $28, $7E, $72, $AE, $7C, $6A, $9A, $FD, $57, $BC, $F7, $B4, $71, $23, $24, $BC, $8D, $0E, $47, $47, $F5, $16, $FD, $67, $CE
	dc.b	$73, $D5, $FB, $AE, $7D, $79, $FF, $55, $DD, $3F, $EE, $27, $3F, $DC, $4F, $FB, $89, $CE, $73, $EE, $3C, $E7, $39, $EB, $AA, $7A, $8F, $BB, $F6, $7F, $AA, $3A
	dc.b	$B5, $D5, $CF, $57, $3D, $53, $D5, $AF, $9E, $7E, $79, $F3, $9D, $53, $F7, $4F, $57, $3F, $74, $E7, $51, $EB, $39, $F3, $9E, $7D, $67, $54, $F5, $4F, $51, $D4
	dc.b	$79, $CF, $5D, $5A, $EA, $FD, $D5, $53, $D5, $FA, $AF, $DC, $4F, $DD, $3D, $5A, $F3, $CF, $FC, $89, $FF, $91, $3D, $53, $E7, $3F, $F4, $1E, $B3, $EE, $9F, $B8
	dc.b	$EA, $3A, $8F, $FF, $1D, $C7, $FF, $83, $CE, $7F, $B8, $3A, $8F, $F7, $07, $51, $F7, $4E, $79, $CF, $3D, $33, $F7, $1E, $7A, $75, $D4, $73, $9F, $FE, $33, $9F
	dc.b	$FE, $2A, $9E, $A3, $A8, $FF, $70, $73, $D4, $73, $9D, $54, $FF, $22, $7A, $A7, $A8, $EA, $9F, $FB, $14, $F7, $6C, $FF, $C7, $F2, $27, $FD, $C4, $F5, $1F, $EE
	dc.b	$0F, $3C, $E7, $56, $BC, $E7, $9E, $7C, $E7, $FC, $A3, $CF, $3D, $53, $9D, $53, $F7, $1F, $EA, $8F, $FF, $1F, $F8, $CE, $7F, $D8, $3C, $F3, $E7, $D7, $FD, $89
	dc.b	$F3, $EB, $CF, $3D, $5A, $FF, $F1, $57, $F2, $AA, $3C, $E7, $FC, $83, $FD, $C1, $FF, $60, $EA, $3A, $8E, $AA, $6A, $3F, $DC, $1E, $73, $CE, $7F, $C8, $FD, $D6
	dc.b	$79, $EA, $FD, $57, $EE, $27, $FD, $C1, $55, $2C, $F9, $7E, $E2, $9E, $E3, $CE, $79, $CE, $AA, $7B, $A7, $CF, $3D, $47, $51, $D4, $75, $1D, $53, $FF, $A0, $F5
	dc.b	$D3, $AC, $E5, $FB, $3E, $E3, $FF, $C6, $79, $E9, $CF, $3D, $53, $E7, $A7, $3C, $F9, $CF, $39, $D5, $3D, $47, $FE, $8D, $67, $39, $FF, $AA, $A3, $A8, $FF, $F1
	dc.b	$FE, $83, $FE, $41, $D5, $4D, $47, $FD, $83, $CE, $75, $53, $54, $FF, $C8, $39, $EA, $9E, $AD, $67, $3D, $53, $D5, $3D, $3F, $C8, $3C, $E7, $FF, $8E, $EA, $6A
	dc.b	$3F, $FC, $7E, $E2, $9C, $F3, $E7, $9F, $F7, $13, $E7, $D7, $57, $EE, $AA, $FD, $57, $EC, $FF, $F1, $FC, $89, $FF, $67, $3D, $47, $9E, $7F, $DC, $4F, $4D, $53
	dc.b	$E7, $9E, $A9, $FF, $71, $AF, $BA, $7A, $A7, $CF, $FF, $AF, $DC, $1F, $FE, $33, $9E, $BC, $E7, $DD, $4C, $E7, $55, $39, $E7, $CF, $3E, $79, $EA, $D7, $54, $E7
	dc.b	$51, $CF, $57, $EE, $B3, $CF, $56, $BC, $F3, $FF, $20, $FF, $71, $4F, $F6, $0F, $3C, $E7, $FA, $A3, $9F, $39, $E7, $39, $EA, $9F, $3C, $F5, $1D, $53, $E7, $9F
	dc.b	$3E, $BA, $A7, $FD, $C4, $FD, $DA, $EA, $9F, $F7, $07, $FB, $8A, $7F, $F1, $56, $B3, $EE, $9C, $EA, $39, $CF, $3C, $F5, $4F, $57, $EA, $B3, $CF, $51, $CF, $9F
	dc.b	$5D, $47, $3F, $EE, $27, $EE, $D7, $4F, $F6, $0F, $3F, $F4, $D0, $FC, $0F, $3C, $F5, $53, $DD, $FA, $AE, $E9, $F3, $CF, $9E, $7A, $8E, $A9, $EA, $9C, $E7, $AA
	dc.b	$73, $D7, $FF, $8B, $69, $A8, $FF, $70, $F3, $AA, $9F, $E4, $1C, $FF, $D3, $9F, $3C, $FF, $B8, $39, $FF, $91, $3D, $5F, $BA, $AB, $FD, $5F, $B8, $FD, $56, $A4
	dc.b	$3F, $FC, $53, $FB, $8F, $2A, $8F, $3D, $35, $1E, $79, $FF, $B1, $AE, $AD, $75, $4F, $FC, $89, $EA, $9F, $A3, $5F, $3F, $FE, $3F, $D1, $FD, $3E, $E3, $FF, $C4
	dc.b	$F5, $6B, $AA, $7C, $F3, $E7, $FD, $55, $53, $D5, $3D, $5A, $FF, $F1, $4D, $47, $9F, $62, $53, $51, $D5, $4A, $1F, $FE, $3F, $55, $51, $D5, $3D, $5F, $AA, $FD
	dc.b	$C7, $EA, $AA, $D7, $9E, $7F, $F4, $7F, $8F, $FE, $8D, $FB, $3F, $0E, $EA, $6A, $3A, $A7, $A7, $3C, $FF, $C8, $9F, $F7, $13, $E7, $9F, $3C, $FF, $F8, $AA, $DA
	dc.b	$2D, $A7, $F8, $BF, $C4, $3D, $EA, $2A, $A6, $AF, $D9, $CF, $FF, $8F, $FC, $55, $AF, $3E, $BC, $FF, $AA, $AB, $59, $A5, $5F, $9C, $AB, $9C, $FF, $A9, $9F, $7B
	dc.b	$CA, $9B, $5A, $AF, $D5, $7F, $62, $7F, $E4, $7E, $EB, $BB, $FB, $55, $6B, $FF, $E7, $71, $E7, $FD, $9A, $36, $F1, $DA, $69, $FB, $3F, $FC, $7F, $63, $F5, $5D
	dc.b	$DA, $F3, $FF, $6B, $3F, $F7, $3F, $F1, $FD, $8D, $95, $7E, $CE, $AD, $93, $E7, $9F, $F7, $13, $E7, $D7, $54, $F5, $4F, $57, $EA, $AA, $9E, $AF, $ED, $7E, $E3
	dc.b	$FB, $9F, $B8, $FD, $67, $F2, $36, $55, $FB, $3A, $B6, $55, $3E, $79, $FF, $71, $AE, $A9, $FF, $91, $AF, $3C, $F9, $E7, $CF, $3D, $53, $D5, $F9, $78, $6F, $E0
	dc.b	$C9, $FA, $78, $6F, $C1, $92, $1F, $97, $EA, $C3, $F2, $F0, $46, $4D, $2D, $0B, $60, $D0, $A2, $D8, $32, $32, $35, $AD, $6E, $CF, $E2, $61, $F9, $7E, $5F, $97
	dc.b	$E3, $DF, $4D, $2D, $86, $FB, $7E, $5D, $B0, $DF, $82, $7E, $5D, $B4, $EF, $A3, $23, $72, $6D, $EE, $49, $FC, $3A, $23, $18, $C6, $3C, $7B, $F1, $8F, $2D, $F8
	dc.b	$C6, $1B, $F1, $8C, $63, $18, $C7, $8B, $7E, $31, $8E, $1B, $F1, $8C, $10, $D0, $FF, $E9, $BD, $D5, $0B, $68, $FD, $9A, $6C, $F0, $FD, $9D, $B4, $78, $36, $9E
	dc.b	$A8, $FF, $13, $42, $61, $FC, $58, $79, $79, $7F, $8F, $FE, $9F, $D5, $B9, $A3, $D5, $CA, $DF, $DD, $B5, $DB, $DD, $BB, $DF, $B3, $4A, $53, $CA, $DD, $95, $6B
	dc.b	$6B, $90, $EA, $B4, $E8, $ED, $4B, $A8, $86, $8E, $5A, $11, $AE, $6B, $69, $43, $DE, $F2, $B6, $E4, $BB, $47, $8A, $7E, $CF, $F5, $5F, $F5, $8A, $76, $D1, $DB
	dc.b	$FF, $44, $D9, $E1, $0D, $09, $44, $1A, $5F, $D4, $F1, $D1, $76, $8B, $A3, $FC, $4F, $D5, $F8, $12, $4A, $1B, $ED, $83, $41, $2E, $43, $6C, $19, $36, $4E, $68
	dc.b	$53, $94, $F4, $CE, $5A, $EE, $FE, $A1, $C5, $2E, $F0, $ED, $95, $36, $D2, $84, $76, $D3, $6E, $1B, $FA, $77, $E7, $2D, $79, $4F, $24, $3D, $67, $3F, $97, $FD
	dc.b	$5A, $ED, $E3, $92, $1A, $5C, $90, $A5, $21, $74, $0F, $7A, $1B, $E9, $BF, $87, $E5, $E7, $2D, $85, $39, $6B, $29, $CA, $73, $9F, $CB, $FE, $A1, $65, $FC, $43
	dc.b	$43, $4A, $7F, $89, $0B, $7B, $61, $A2, $0D, $0D, $F9, $CE, $7B, $7C, $8F, $5F, $F0, $D0, $EE, $DF, $86, $FE, $8F, $FB, $FE, $5F, $FE, $86, $46, $47, $CC, $75
	dc.b	$48, $E5, $3E, $79, $CE, $AA, $6A, $9E, $A3, $AA, $73, $29, $CA, $7A, $A7, $AA, $92, $D9, $69, $97, $FD, $D3, $FC, $A6, $9F, $E3, $23, $FD, $51, $CF, $E2, $7F
	dc.b	$C2, $AB, $2F, $EC, $5B, $FD, $2F, $D3, $D1, $FA, $7F, $FA, $FE, $CF, $78, $E7, $2D, $65, $39, $4E, $55, $7F, $0B, $3C, $B3, $E5, $51, $55, $23, $FE, $92, $65
	dc.b	$FE, $7F, $FA, $B7, $91, $6B, $2F, $D5, $1F, $8D, $45, $51, $54, $55, $16, $79, $4F, $FE, $24, $24, $2F, $CB, $B7, $F1, $FF, $EB, $E4, $7F, $E8, $32, $FE, $9F
	dc.b	$8E, $53, $97, $EA, $A3, $18, $C7, $33, $71, $35, $DC, $6C, $85, $C6, $CF, $8C, $63, $18, $7E, $AE, $DA, $13, $64, $A9, $2E, $8C, $BF, $C3, $18, $C6, $3D, $5C
	dc.b	$8D, $3F, $A6, $43, $9B, $FC, $24, $0A, $31, $8C, $70, $D1, $A6, $9F, $E9, $7F, $84, $BF, $A2, $A1, $18, $C6, $3A, $68, $83, $43, $BB, $98, $C8, $FB, $3F, $A3
	dc.b	$18, $C6, $30, $FE, $2E, $07, $FE, $2E, $CE, $C8, $C6, $30, $6D, $2D, $0F, $FA, $B1, $3C, $86, $56, $28, $2E, $CB, $FA, $23, $18, $C6, $8E, $36, $7E, $74, $AB
	dc.b	$FA, $25, $A9, $5A, $AF, $8C, $63, $1B, $9A, $EB, $68, $B8, $AC, $2E, $CE, $CB, $23, $18, $C7, $FE, $85, $A8, $81, $76, $7F, $45, $42, $31, $8C, $7F, $89, $B3
	dc.b	$FA, $56, $65, $D9, $AA, $31, $8C, $7F, $C6, $5D, $9D, $80, $BF, $A3, $18, $C6, $24, $72, $05, $61, $6A, $50, $2F, $E8, $AB, $B2, $31, $8C, $44, $B6, $11, $F6
	dc.b	$7F, $46, $65, $0F, $DC, $BE, $31, $8C, $4B, $61, $6C, $12, $06, $40, $BB, $3F, $C2, $A8, $C6, $31, $A7, $C4, $16, $A2, $EC, $0A, $7A, $DF, $18, $C6, $20, $86
	dc.b	$42, $5D, $8F, $9B, $B1, $EA, $8C, $63, $11, $21, $CD, $A9, $62, $56, $2F, $52, $9E, $BB, $15, $18, $C7, $89, $AE, $F1, $EC, $50, $53, $CB, $A3, $F7, $23, $8D
	dc.b	$8C, $B8, $88, $72, $6B, $8C, $B8, $FB, $4B, $8A, $E2, $CD, $77, $15, $D9, $9A, $1F, $E1, $5F, $F4, $56, $AE, $85, $AB, $FA, $24, $14, $69, $72, $42, $C6, $E3
	dc.b	$A3, $89, $8F, $4D, $04, $64, $F2, $B1, $41, $4F, $25, $12, $87, $FE, $4D, $D3, $3A, $67, $34, $8D, $65, $31, $D0, $99, $06, $83, $41, $A1, $24, $A3, $8E, $60
	dc.b	$A0, $4A, $18, $C2, $AC, $53, $97, $FB, $91, $FB, $DF, $DC, $D7, $8F, $72, $EB, $9B, $80, $99, $FC, $20, $FD, $AE, $55, $8A, $7D, $E2, $F1, $B9, $F7, $85, $0D
	dc.b	$DC, $1E, $AA, $E6, $17, $B9, $6E, $99, $5B, $5C, $1D, $8B, $6A, $87, $F6, $46, $EF, $DE, $8B, $E6, $FD, $CB, $96, $A5, $DF, $5F, $5B, $B1, $62, $FF, $72, $82
	dc.b	$F7, $6A, $FE, $C8, $56, $D5, $39, $55, $EE, $FD, $EA, $F7, $70, $5B, $BA, $D5, $D3, $BB, $FD, $D7, $BD, $61, $42, $F7, $DE, $3F, $93, $C3, $77, $EF, $42, $AB
	dc.b	$55, $6B, $72, $A6, $AF, $1D, $F8, $BF, $DD, $7A, $C5, $E2, $F5, $8F, $FC, $B9, $55, $EE, $FD, $EA, $EF, $AD, $6E, $99, $5C, $31, $AB, $6A, $97, $BA, $6B, $F6
	dc.b	$DF, $65, $E3, $73, $D4, $FB, $D7, $FD, $99, $BF, $D3, $B5, $4E, $DA, $A5, $DE, $B0, $AD, $AE, $1D, $6A, $B2, $FB, $3F, $92, $3F, $72, $EF, $E4, $FF, $36, $65
	dc.b	$7E, $F7, $1A, $97, $FC, $D9, $9C, $A5, $F0, $99, $42, $B0, $E9, $85, $E2, $F0, $BD, $D6, $2C, $29, $7F, $C9, $7C, $DF, $C9, $DB, $FB, $DC, $58, $B1, $3D, $4F
	dc.b	$FF, $C8, $FD, $C8, $DC, $EF, $EC, $BA, $65, $3B, $72, $DC, $AD, $AA, $77, $5B, $A6, $72, $FF, $9B, $33, $B7, $0B, $C3, $BF, $93, $5A, $9D, $FB, $9A, $D5, $33
	dc.b	$AF, $70, $DA, $E5, $39, $5B, $6B, $C5, $33, $BF, $DD, $78, $53, $AF, $1B, $B8, $7E, $E6, $B5, $BA, $F5, $AB, $6D, $78, $BA, $D5, $8B, $14, $C2, $F5, $D9, $BB
	dc.b	$6D, $F5, $FE, $E5, $6E, $57, $F7, $66, $76, $2C, $58, $BA, $7F, $B2, $3F, $92, $BF, $E4, $BB, $F9, $35, $AB, $FF, $AE, $C5, $32, $B1, $62, $5A, $A6, $13, $6E
	dc.b	$13, $7F, $E5, $4E, $53, $95, $C3, $16, $2C, $58, $B6, $FE, $E7, $F7, $B7, $D6, $2B, $53, $A6, $AD, $4E, $52, $DD, $35, $EE, $56, $3B, $DD, $7E, $D7, $4C, $AC
	dc.b	$58, $B8, $A8, $E3, $A1, $38, $99, $38, $98, $A3, $18, $E6, $4D, $32, $32, $1A, $0C, $AC, $36, $4D, $10, $6A, $7F, $CB, $C6, $D1, $C2, $8E, $3B, $B8, $B7, $CA
	dc.b	$0D, $C6, $49, $C4, $76, $B2, $69, $63, $B5, $91, $92, $31, $8C, $74, $BE, $64, $D2, $C8, $F5, $E0, $D0, $B4, $ED, $68, $31, $1A, $36, $0C, $92, $34, $C1, $92
	dc.b	$46, $9A, $53, $33, $72, $5A, $75, $A1, $AE, $0B, $A2, $EC, $3A, $B4, $B1, $FF, $14, $E0, $D1, $8C, $78, $F1, $1C, $86, $D8, $50, $85, $8F, $4D, $10, $59, $E9
	dc.b	$6D, $2B, $8E, $66, $CD, $76, $2C, $58, $B1, $2C, $4C, $61, $61, $21, $A1, $0D, $AD, $D3, $44, $2E, $4E, $54, $62, $C5, $D6, $AC, $4B, $0B, $56, $23, $23, $45
	dc.b	$DC, $87, $73, $43, $B6, $1A, $20, $D0, $6E, $B5, $62, $57, $FB, $95, $8B, $AD, $4B, $7A, $C7, $35, $D4, $DC, $D7, $75, $42, $8E, $D6, $EB, $BF, $A6, $B5, $63
	dc.b	$53, $AF, $0B, $BD, $6A, $B3, $19, $AE, $C9, $1A, $76, $92, $7F, $54, $D1, $A0, $D0, $68, $1B, $0A, $DF, $33, $BA, $2B, $5F, $F4, $6B, $14, $96, $AD, $EB, $B2
	dc.b	$17, $75, $25, $C7, $77, $F9, $4E, $8C, $34, $62, $EB, $FF, $EF, $0B, $3F, $7B, $30, $5D, $8B, $91, $8D, $89, $44, $0F, $04, $A3, $06, $E5, $37, $01, $58, $FD
	dc.b	$EB, $FF, $9A, $F2, $AE, $C9, $57, $FD, $1A, $D9, $28, $ED, $43, $64, $BA, $14, $61, $45, $D0, $A2, $0C, $EF, $F7, $3B, $FD, $DF, $ED, $5F, $05, $8F, $FE, $D9
	dc.b	$B0, $84, $8E, $1A, $0D, $A1, $46, $12, $4C, $31, $7F, $B9, $D8, $DD, $8C, $70, $1C, $3A, $2B, $7D, $29, $DB, $42, $34, $1B, $06, $86, $8E, $4D, $0C, $6F, $C6
	dc.b	$EF, $F7, $7F, $F5, $DF, $D1, $70, $3B, $B5, $3A, $88, $33, $DC, $11, $B0, $B4, $1A, $69, $A0, $17, $58, $C5, $37, $F3, $42, $EB, $7F, $EF, $6C, $70, $75, $8E
	dc.b	$12, $0E, $34, $92, $42, $98, $26, $65, $8C, $53, $09, $9D, $B7, $80, $AD, $6E, $0E, $B1, $6E, $5B, $83, $27, $04, $A3, $F8, $94, $42, $DE, $24, $65, $8E, $BE
	dc.b	$1D, $63, $84, $CE, $B0, $A6, $7B, $16, $15, $85, $F2, $60, $B1, $C9, $0C, $27, $19, $A3, $66, $BA, $30, $DF, $E3, $6C, $CD, $BF, $C6, $C9, $99, $B3, $1E, $64
	dc.b	$8B, $46, $DE, $3D, $E6, $E5, $26, $E4, $C6, $D2, $A3, $03, $46, $E3, $24, $38, $C6, $31, $E2, $68, $C6, $31, $85, $D9, $93, $33, $66, $BA, $31, $CD, $72, $71
	dc.b	$24, $63, $1D, $37, $66, $BB, $35, $D9, $9B, $4B, $61, $47, $15, $17, $41, $A1, $46, $08, $D0, $6E, $36, $E2, $6D, $2D, $A5, $B8, $E8, $8F, $15, $19, $9A, $0D
	dc.b	$A7, $47, $15, $10, $D1, $06, $E5, $44, $28, $E2, $68, $36, $96, $C3, $AB, $93, $69, $A2, $0D, $83, $42, $8F, $D5, $B6, $14, $76, $D1, $06, $C1, $91, $93, $44
	dc.b	$1A, $DA, $30, $68, $75, $61, $D4, $50, $EA, $90, $EA, $B5, $F0, $68, $68, $4F, $F2, $A3, $61, $FF, $5C, $18, $23, $41, $B0, $63, $16, $92, $32, $31, $D8, $C8
	dc.b	$68, $41, $C0, $D0, $1B, $D3, $FA, $B0, $4F, $FA, $A3, $41, $A1, $A0, $E0, $09, $92, $82, $B4, $64, $F3, $6F, $F0, $90, $32, $5A, $AC, $58, $58, $83, $47, $4B
	dc.b	$46, $8E, $36, $C3, $44, $1B, $0B, $68, $83, $1A, $03, $20, $D6, $29, $EA, $0A, $0A, $75, $10, $A3, $93, $26, $6A, $30, $D0, $68, $D8, $50, $4F, $38, $68, $25
	dc.b	$15, $96, $A8, $95, $D1, $8D, $42, $F1, $A6, $D3, $D3, $42, $31, $34, $19, $28, $46, $3A, $12, $83, $46, $24, $D0, $56, $1A, $31, $F4, $28, $C2, $85, $E1, $42
	dc.b	$B5, $2D, $CD, $C4, $DC, $74, $60, $D0, $EA, $85, $B4, $41, $A0, $D4, $B1, $51, $06, $A5, $0E, $D6, $47, $9F, $45, $E1, $55, $92, $99, $34, $B1, $23, $60, $D8
	dc.b	$31, $B2, $41, $B0, $DE, $83, $61, $BC, $70, $6C, $37, $A0, $DA, $6D, $EA, $86, $82, $D1, $81, $90, $36, $E2, $6C, $CD, $14, $C1, $B4, $E8, $48, $36, $07, $42
	dc.b	$41, $A0, $C4, $2D, $60, $4C, $1D, $23, $70, $3C, $D7, $66, $6E, $26, $8B, $71, $21, $C1, $B0, $A0, $68, $83, $48, $26, $82, $7A, $DD, $C6, $97, $37, $15, $19
	dc.b	$9B, $4D, $18, $51, $06, $23, $EA, $32, $0E, $0C, $84, $FA, $F7, $BF, $7A, $B7, $AF, $7F, $88, $F3, $1F, $13, $26, $64, $CC, $99, $8E, $31, $91, $F1, $90, $46
	dc.b	$E4, $42, $EE, $32, $3B, $B8, $C8, $FB, $79, $21, $A5, $DC, $B6, $5D, $C9, $08, $E2, $99, $93, $35, $C9, $83, $69, $4C, $1B, $4A, $60, $DA, $5A, $EC, $CD, $A5
	dc.b	$B4, $DC, $D0, $68, $D1, $99, $A3, $C9, $A0, $D9, $A8, $83, $41, $A0, $D6, $F2, $63, $24, $D3, $41, $2C, $B9, $34, $78, $DA, $3A, $74, $71, $95, $05, $04, $93
	dc.b	$D0, $12, $6A, $47, $96, $A8, $68, $83, $24, $1A, $14, $41, $0C, $B4, $D0, $86, $28, $4E, $8A, $32, $7A, $C9, $EA, $0A, $AC, $2C, $14, $DD, $05, $8C, $69, $49
	dc.b	$3E, $14, $6A, $72, $74, $56, $A5, $B9, $4F, $76, $DD, $C3, $6D, $E1, $6A, $58, $5A, $9D, $8D, $CB, $1B, $6B, $08, $0B, $73, $AC, $51, $5E, $E7, $EE, $99, $4F
	dc.b	$BF, $1F, $F6, $5F, $FB, $91, $79, $3A, $F0, $AE, $17, $85, $56, $A1, $FB, $9B, $17, $BA, $61, $35, $EB, $56, $D7, $A8, $3B, $19, $0D, $D8, $CB, $75, $73, $0D
	dc.b	$CE, $53, $96, $37, $39, $77, $BD, $CA, $72, $9D, $30, $5B, $94, $EC, $6A, $99, $DD, $2A, $C5, $D2, $AC, $4B, $7E, $D7, $62, $C6, $14, $E1, $B5, $53, $2B, $A4
	dc.b	$6D, $7B, $BA, $5C, $2B, $DA, $E7, $F0, $99, $C1, $C2, $BC, $64, $F7, $05, $56, $B7, $2D, $CA, $76, $2C, $58, $BF, $DC, $EE, $BE, $1D, $62, $BD, $AA, $AD, $4E
	dc.b	$9A, $BC, $58, $D4, $FD, $A2, $41, $CB, $72, $B5, $39, $6A, $04, $62, $B1, $7C, $AB, $0E, $50, $93, $EB, $2D, $E9, $07, $03, $97, $05, $A8, $29, $DD, $6E, $C5
	dc.b	$D2, $3F, $DC, $EE, $90, $BA, $F1, $89, $9C, $41, $D3, $7F, $34, $4C, $EC, $58, $B1, $85, $3B, $A4, $3B, $A4, $2B, $A5, $CA, $EB, $70, $41, $B5, $D2, $C4, $BE
	dc.b	$0B, $72, $83, $AC, $E0, $A7, $28, $2A, $67, $29, $C1, $41, $53, $56, $14, $15, $D2, $EC, $75, $CD, $5E, $27, $0A, $FA, $EB, $0E, $C6, $26, $72, $DD, $30, $C5
	dc.b	$8A, $B5, $85, $B9, $71, $E2, $A2, $39, $AE, $CD, $74, $63, $98, $D8, $A8, $E4, $84, $8D, $C8, $C9, $93, $91, $24, $12, $0D, $81, $24, $13, $0A, $09, $39, $50
	dc.b	$61, $39, $33, $D2, $30, $68, $C6, $2D, $18, $36, $6A, $38, $DB, $06, $83, $60, $DA, $53, $32, $41, $A1, $A2, $14, $C1, $A0, $DA, $51, $B0, $68, $50, $6D, $06
	dc.b	$4C, $2D, $62, $A7, $41, $93, $D2, $8A, $6C, $3C, $CD, $C7, $D5, $87, $FD, $48, $FC, $29, $07, $BC, $F4, $08, $0D, $0C, $21, $95, $89, $61, $D9, $0A, $20, $56
	dc.b	$50, $69, $8C, $32, $03, $4C, $66, $40, $9F, $31, $95, $64, $F2, $30, $B7, $58, $B0, $A5, $A9, $CB, $7A, $9C, $BB, $D6, $40, $96, $0B, $FD, $C0, $9E, $B1, $35
	dc.b	$6F, $5A, $1B, $C8, $57, $23, $27, $B9, $EB, $27, $B9, $EB, $0B, $75, $8B, $04, $F2, $0B, $13, $05, $39, $77, $CC, $14, $B7, $2D, $53, $5E, $E0, $AE, $03, $72
	dc.b	$C5, $64, $E5, $4C, $0C, $94, $EB, $E6, $05, $C2, $F0, $4B, $72, $D5, $5B, $FA, $78, $05, $85, $D6, $A0, $E5, $D6, $40, $9C, $2B, $58, $5A, $B5, $38, $97, $A9
	dc.b	$6F, $20, $BB, $0A, $C5, $85, $EA, $27, $29, $6A, $99, $CA, $5B, $BA, $C7, $5A, $82, $86, $35, $2E, $B7, $AD, $53, $18, $72, $C6, $33, $20, $B0, $B0, $B9, $07
	dc.b	$10, $5B, $94, $B5, $56, $BF, $E4, $AD, $41, $6E, $99, $4E, $0A, $0B, $FD, $CB, $82, $C2, $86, $E7, $59, $BA, $C5, $15, $9B, $01, $05, $0C, $82, $9D, $7A, $DD
	dc.b	$33, $AF, $72, $AB, $5A, $9D, $FB, $97, $4D, $7A, $D4, $B7, $B9, $4E, $9B, $FD, $A3, $1A, $AB, $B2, $65, $3B, $A1, $6E, $5B, $E5, $67, $01, $5B, $EB, $0E, $15
	dc.b	$F4, $38, $2D, $DA, $A6, $1C, $08, $4C, $E9, $81, $03, $76, $32, $79, $92, $C5, $7B, $54, $E9, $82, $C2, $D4, $36, $87, $29, $EA, $5E, $E0, $A9, $AF, $B1, $63
	dc.b	$1A, $81, $3E, $65, $63, $B3, $A5, $E5, $4B, $DC, $F2, $32, $0E, $5B, $CC, $94, $E5, $A8, $10, $53, $96, $AB, $14, $E5, $A8, $DE, $A7, $4D, $48, $5B, $A6, $14
	dc.b	$8C, $6F, $98, $70, $5D, $6B, $0B, $AD, $EA, $B1, $40, $82, $DF, $CC, $14, $E5, $48, $3A, $FD, $AA, $5D, $73, $05, $D8, $B7, $2C, $81, $09, $94, $EC, $4E, $5B
	dc.b	$BA, $55, $5F, $5B, $B1, $62, $DA, $E5, $75, $B8, $3A, $67, $EE, $E9, $70, $72, $C2, $A6, $73, $D6, $E5, $4C, $E5, $05, $F0, $99, $CA, $C7, $FB, $DD, $AF, $AD
	dc.b	$6E, $C6, $6E, $58, $74, $D6, $7F, $36, $67, $2E, $B5, $6D, $72, $C2, $9D, $D6, $EC, $6E, $7E, $32, $70, $58, $58, $58, $AC, $4C, $26, $B1, $64, $16, $18, $2C
	dc.b	$66, $48, $C6, $39, $93, $89, $97, $C6, $C8, $BC, $3A, $93, $1A, $71, $BC, $F8, $EE, $09, $85, $A6, $81, $A0, $99, $06, $85, $B2, $9C, $FB, $69, $94, $FC, $F4
	dc.b	$E5, $38, $59, $E5, $3B, $F8, $D9, $0E, $1A, $10, $8E, $5B, $32, $A4, $A9, $04, $FC, $8D, $62, $61, $92, $2E, $53, $82, $3B, $65, $4A, $10, $6B, $4B, $41, $02
	dc.b	$B2, $90, $5F, $D1, $2B, $08, $15, $E0, $8E, $C5, $2D, $47, $27, $A9, $66, $42, $40, $D6, $41, $52, $D4, $A5, $89, $63, $7C, $B6, $FF, $85, $64, $77, $99, $3C
	dc.b	$82, $96, $46, $FD, $B6, $74, $91, $AC, $63, $23, $27, $CC, $A2, $DC, $FA, $49, $6A, $D4, $41, $7D, $12, $99, $F3, $05, $83, $7E, $D9, $05, $BD, $64, $F9, $88
	dc.b	$2E, $C9, $84, $8F, $20, $B0, $68, $72, $79, $90, $42, $D4, $B3, $2F, $E8, $90, $55, $8A, $A4, $B7, $05, $95, $21, $6A, $7E, $C0, $B1, $2A, $D6, $E5, $A9, $C4
	dc.b	$E3, $93, $A6, $D4, $42, $BB, $0A, $CA, $D5, $FD, $17, $2C, $4C, $FE, $73, $13, $0F, $CE, $11, $AA, $69, $E9, $2A, $44, $9F, $25, $D3, $61, $90, $5F, $41, $95
	dc.b	$93, $29, $66, $59, $F9, $D4, $B0, $75, $19, $09, $85, $A6, $5F, $B9, $08, $5F, $9C, $B0, $81, $B8, $15, $60, $90, $10, $70, $58, $20, $47, $61, $1A, $12, $09
	dc.b	$18, $27, $A3, $F9, $8E, $CB, $4E, $A2, $79, $53, $9F, $20, $A1, $78, $BC, $85, $F6, $3B, $54, $81, $53, $90, $23, $16, $82, $30, $54, $A1, $52, $B9, $19, $02
	dc.b	$30, $4F, $30, $46, $09, $53, $39, $EE, $5B, $96, $E1, $20, $E2, $74, $B6, $2C, $DE, $56, $85, $A3, $E4, $6F, $40, $41, $60, $AC, $9A, $C5, $85, $BD, $08, $63
	dc.b	$73, $C8, $2F, $80, $94, $CF, $76, $53, $02, $06, $87, $35, $92, $C6, $26, $7C, $C3, $6B, $D6, $36, $8D, $AF, $74, $C0, $AC, $72, $DD, $27, $B8, $3B, $51, $6A
	dc.b	$99, $F5, $BC, $96, $38, $6A, $DA, $11, $F3, $03, $48, $59, $D3, $D1, $8C, $29, $6F, $98, $29, $F3, $3F, $71, $18, $21, $33, $E4, $09, $77, $96, $A9, $B5, $10
	dc.b	$C6, $FB, $C3, $AC, $57, $EF, $48, $2B, $A5, $EB, $18, $DE, $A5, $90, $52, $C5, $EB, $2B, $15, $58, $DC, $4E, $59, $6A, $20, $46, $A7, $75, $85, $3B, $1D, $7B
	dc.b	$BF, $7B, $78, $50, $72, $BA, $14, $14, $F5, $85, $8B, $CD, $03, $96, $F7, $52, $E5, $D8, $68, $CB, $E0, $FA, $D6, $09, $F5, $87, $3C, $81, $05, $B8, $9E, $64
	dc.b	$B0, $64, $16, $61, $4B, $A5, $EA, $7A, $90, $C8, $F5, $13, $E4, $0D, $1E, $B9, $36, $A2, $34, $FE, $89, $3C, $B7, $05, $BE, $57, $D2, $26, $91, $93, $D6, $F9
	dc.b	$05, $BF, $27, $AC, $10, $2E, $AB, $66, $43, $FC, $E6, $E5, $DB, $86, $88, $5C, $97, $25, $DB, $DB, $F7, $6F, $37, $E5, $FC, $A7, $39, $D0, $F5, $95, $C9, $49
	dc.b	$1D, $AB, $E7, $2B, $2D, $E8, $46, $E5, $46, $0D, $6D, $D6, $DD, $6F, $E9, $D9, $3F, $4F, $FD, $3B, $75, $CA, $7D, $9F, $BB, $49, $CA, $7B, $4E, $DB, $28, $B4
	dc.b	$F7, $A1, $A1, $0F, $C0, $ED, $D9, $BF, $D5, $06, $82, $52, $54, $CA, $79, $53, $95, $C9, $D5, $DA, $5F, $D1, $5B, $5B, $B2, $6B, $69, $4F, $D9, $A6, $C4, $32
	dc.b	$87, $69, $C0, $E0, $C4, $65, $4A, $1A, $53, $23, $91, $DC, $9D, $BD, $40, $81, $F4, $6C, $E6, $D9, $20, $43, $98, $F2, $4D, $08, $68, $DE, $14, $DA, $47, $FD
	dc.b	$2F, $E2, $F6, $A0, $93, $D6, $FC, $AC, $23, $27, $C8, $1F, $31, $91, $91, $C1, $B4, $A5, $1F, $F4, $C8, $7E, $CF, $C0, $D3, $B4, $11, $85, $58, $76, $9B, $59
	dc.b	$4A, $1D, $B4, $21, $A7, $EC, $D1, $A1, $D5, $0F, $03, $F0, $F1, $43, $23, $E6, $7C, $DF, $AA, $EC, $1B, $DA, $37, $8D, $0F, $C3, $FE, $BB, $12, $9B, $65, $B1
	dc.b	$0D, $39, $8F, $24, $2F, $E8, $90, $32, $D5, $FE, $41, $A1, $19, $0D, $3A, $AD, $F2, $34, $3F, $F2, $78, $F3, $D3, $51, $6C, $1C, $F9, $1C, $AC, $58, $98, $15
	dc.b	$3A, $FF, $58, $6C, $5B, $24, $C9, $42, $1D, $BF, $C3, $DE, $FE, $96, $B1, $69, $1C, $81, $0F, $D6, $10, $55, $9F, $9C, $2B, $0C, $82, $AC, $A6, $40, $81, $26
	dc.b	$8B, $68, $39, $E5, $FC, $32, $3C, $A9, $56, $48, $78, $DE, $72, $98, $28, $65, $AA, $46, $F7, $13, $27, $43, $17, $85, $25, $49, $7F, $4D, $0D, $92, $9C, $63
	dc.b	$AD, $F8, $EC, $58, $99, $FC, $1E, $BF, $F0, $D6, $BA, $7F, $39, $C0, $19, $73, $B9, $E7, $2F, $E9, $B3, $CD, $20, $80, $D6, $61, $A0, $7C, $E6, $B7, $A3, $1F
	dc.b	$39, $2D, $E6, $99, $3E, $96, $C9, $62, $61, $8C, $D7, $21, $97, $91, $09, $6C, $23, $E6, $B4, $90, $F2, $A4, $7F, $08, $C8, $65, $33, $CA, $C5, $FF, $84, $81
	dc.b	$3F, $66, $4B, $23, $1C, $C7, $95, $8B, $93, $CB, $B2, $56, $49, $FC, $CB, $18, $C4, $D4, $BF, $21, $CC, $09, $F5, $BC, $D5, $68, $5E, $40, $C8, $2C, $9E, $46
	dc.b	$4B, $27, $93, $C9, $F9, $2E, $53, $4A, $6B, $25, $33, $C9, $E4, $31, $89, $28, $5E, $6D, $25, $A9, $6F, $32, $7A, $F5, $14, $DF, $E1, $DB, $D8, $FC, $B5, $2C
	dc.b	$BA, $17, $2E, $85, $FF, $45, $60, $97, $FD, $13, $E8, $59, $97, $F4, $65, $D1, $CC, $0A, $CA, $49, $E4, $26, $13, $94, $F9, $6B, $FF, $BF, $FD, $7C, $AA, $3B
	dc.b	$6E, $4E, $DD, $85, $49, $4F, $96, $B2, $9F, $9E, $53, $CA, $72, $9C, $A7, $2A, $50, $93, $FE, $FF, $D5, $B9, $BC, $AE, $4B, $AD, $FD, $5E, $BE, $70, $5A, $FF
	dc.b	$38, $39, $EC, $E7, $FD, $54, $B9, $FF, $55, $49, $1C, $A9, $FC, $BC, $3F, $2F, $0F, $CB, $FF, $56, $17, $7E, $CC, $8E, $5D, $A9, $DB, $BD, $E3, $2E, $72, $FD
	dc.b	$60, $D6, $5A, $F9, $E7, $23, $FE, $11, $97, $E5, $FF, $8B, $87, $6D, $1A, $7F, $C6, $49, $4D, $CD, $DA, $DE, $23, $F5, $80, $FC, $44, $92, $9C, $8D, $B8, $9A
	dc.b	$34, $FF, $52, $1F, $AB, $B6, $9F, $E9, $6B, $90, $CA, $7F, $12, $DE, $34, $FE, $DF, $F1, $2E, $C3, $F8, $B6, $FE, $EE, $D9, $6C, $91, $FE, $E8, $6B, $2E, $CF
	dc.b	$1D, $1C, $9B, $F8, $87, $9F, $F5, $69, $B3, $FC, $9D, $A6, $5F, $C3, $29, $FF, $C5, $D9, $FC, $2F, $D5, $35, $C8, $75, $15, $47, $E2, $8C, $9B, $24, $DF, $CB
	dc.b	$C2, $9C, $FC, $DE, $5E, $39, $E5, $56, $55, $27, $F2, $D8, $E5, $B3, $2F, $F1, $E1, $A3, $4D, $54, $D5, $E1, $FC, $32, $3F, $12, $A8, $AA, $C8, $D2, $E4, $BA
	dc.b	$8A, $5B, $F8, $47, $2A, $7F, $A5, $0A, $2D, $D1, $FC, $46, $B7, $24, $34, $64, $CB, $64, $B7, $BF, $66, $86, $90, $A2, $14, $27, $89, $7F, $69, $BC, $19, $1A
	dc.b	$D6, $83, $6F, $36, $F6, $84, $E6, $3C, $93, $62, $52, $4D, $BC, $D7, $51, $FD, $27, $95, $3F, $C2, $F0, $EA, $34, $FE, $1A, $35, $AC, $87, $6F, $8E, $C9, $19
	dc.b	$4F, $FB, $B6, $ED, $4F, $E9, $0F, $E9, $19, $54, $C8, $C9, $D5, $BC, $6D, $69, $B7, $81, $DA, $72, $D9, $6E, $B2, $D7, $67, $6A, $7F, $2F, $23, $E6, $3E, $EA
	dc.b	$65, $46, $F6, $8A, $7F, $E9, $DA, $D7, $21, $FF, $D5, $F3, $8D, $72, $FF, $A7, $89, $7F, $8F, $42, $75, $7F, $D3, $F8, $72, $4F, $FA, $C8, $13, $CB, $C3, $67
	dc.b	$8C, $BC, $BF, $EA, $86, $5F, $C3, $FF, $2A, $51, $69, $95, $3B, $DB, $08, $DE, $B0, $B0, $43, $9A, $CC, $8C, $A9, $95, $25, $FB, $34, $39, $1F, $36, $F3, $78
	dc.b	$1E, $46, $94, $78, $F4, $89, $8F, $23, $91, $F8, $9A, $10, $20, $49, $FC, $2D, $88, $65, $FC, $3D, $FE, $AB, $9B, $7E, $F9, $B7, $09, $88, $10, $98, $A9, $92
	dc.b	$C8, $4B, $66, $5B, $11, $8B, $66, $54, $CB, $CB, $F2, $F4, $7E, $DE, $C2, $7D, $E3, $1A, $B1, $EA, $55, $87, $BD, $A3, $89, $19, $25, $E4, $68, $72, $3A, $3F
	dc.b	$A8, $B0, $A1, $F9, $CA, $B9, $F1, $AB, $1A, $B5, $5E, $F3, $DE, $D1, $C4, $8C, $92, $F2, $34, $39, $1D, $1F, $D4, $5B, $F5, $9F, $39, $FE, $5E, $1B, $F8, $51
	dc.b	$FA, $78, $6F, $E0, $D0, $FC, $BE, $84, $68, $7E, $5E, $16, $B2, $60, $D0, $B6, $0D, $85, $10, $6B, $5A, $0C, $8D, $6B, $1B, $1A, $1F, $86, $1B, $F8, $6F, $C3
	dc.b	$F2, $FC, $49, $CB, $7F, $06, $FC, $BB, $43, $F2, $F0, $4F, $CB, $F1, $E8, $E3, $B7, $89, $3F, $67, $44, $78, $F7, $E3, $18, $C6, $3C, $BA, $A3, $18, $C6, $31
	dc.b	$8C, $70, $DF, $C3, $7F, $8F, $7F, $96, $FC, $63, $18, $F1, $EF, $C6, $31, $8C, $63, $18, $EF, $C6, $31, $8C, $63, $18, $F1, $75, $42, $D3, $43, $43, $FE, $26
	dc.b	$09, $D5, $E1, $E5, $E4, $7F, $F4, $BA, $DB, $BA, $A3, $E1, $FD, $58, $51, $FA, $BD, $9F, $C4, $FF, $1D, $DE, $5F, $E4, $3D, $1F, $AB, $B7, $89, $AE, $EA, $E5
	dc.b	$75, $1F, $AB, $A3, $7B, $B7, $7A, $E4, $A7, $B5, $27, $FE, $9C, $F4, $FE, $EA, $A3, $9F, $FE, $9F, $BB, $4F, $D5, $C5, $BF, $56, $D7, $37, $6A, $5C, $94, $CE
	dc.b	$93, $91, $F3, $4F, $4E, $F5, $CC, $9F, $B3, $23, $FF, $A4, $E7, $FE, $5B, $A3, $83, $61, $DA, $9D, $A9, $DB, $FC, $43, $B6, $EC, $13, $62, $68, $85, $AD, $6D
	dc.b	$32, $A7, $9A, $EA, $29, $6E, $D8, $FF, $92, $EF, $0E, $68, $36, $1A, $12, $E4, $36, $F0, $A6, $72, $FD, $51, $7E, $AB, $F6, $73, $DD, $FE, $48, $A7, $6F, $F1
	dc.b	$29, $23, $24, $A5, $AD, $6D, $EB, $9B, $4F, $E9, $E1, $2E, $E2, $FE, $54, $BF, $54, $68, $69, $FB, $3A, $30, $A2, $0D, $BD, $B2, $54, $DA, $69, $4A, $5C, $9F
	dc.b	$AB, $B6, $1B, $FC, $7B, $F5, $4F, $9C, $B5, $94, $F2, $9C, $A7, $39, $FC, $B0, $FE, $A8, $59, $1D, $D4, $27, $F0, $D0, $FC, $3F, $67, $76, $FC, $0F, $4D, $D0
	dc.b	$9C, $D2, $E3, $B9, $2E, $D7, $2A, $67, $FE, $1D, $B7, $42, $84, $6C, $3F, $EF, $BE, $DF, $F4, $CB, $F6, $69, $FC, $2A, $79, $B3, $F3, $77, $11, $CB, $F9, $19
	dc.b	$1E, $FB, $19, $3C, $BF, $EE, $9F, $E5, $34, $FF, $19, $1F, $EA, $8E, $7F, $13, $FE, $15, $59, $7F, $60, $92, $92, $32, $3F, $D3, $D1, $FA, $7F, $FA, $FE, $CF
	dc.b	$78, $E7, $2D, $65, $39, $4E, $55, $7F, $0B, $3C, $B3, $E5, $51, $55, $23, $C9, $09, $39, $BF, $CF, $FF, $56, $F2, $2D, $65, $FA, $A3, $F1, $A8, $AA, $2A, $8A
	dc.b	$A2, $CF, $29, $F2, $8C, $63, $18, $F1, $35, $DC, $6C, $8D, $C6, $C6, $23, $18, $C6, $1F, $AB, $E5, $BC, $64, $76, $B6, $56, $10, $2F, $E8, $C6, $31, $8E, $14
	dc.b	$69, $6B, $7F, $A6, $F3, $E6, $79, $BE, $40, $A3, $18, $C7, $4D, $18, $36, $CE, $63, $EC, $B1, $63, $74, $63, $18, $E1, $A3, $06, $43, $23, $91, $91, $F4, $13
	dc.b	$D5, $62, $9F, $18, $C7, $35, $18, $7F, $14, $A9, $CB, $B3, $B1, $42, $31, $6C, $D4, $43, $46, $1F, $F5, $B0, $96, $08, $2B, $FC, $2B, $57, $F4, $63, $18, $C7
	dc.b	$F8, $BB, $DF, $D1, $2E, $C2, $7A, $BA, $23, $18, $C6, $DF, $EA, $D8, $56, $16, $A2, $FE, $89, $6A, $8C, $63, $C5, $A3, $95, $08, $0C, $18, $43, $EC, $EC, $11
	dc.b	$8C, $7F, $8B, $A4, $93, $2D, $83, $2E, $CD, $5B, $BA, $23, $18, $C7, $F8, $76, $9F, $45, $3D, $85, $D9, $18, $C7, $8F, $41, $DB, $4C, $81, $91, $82, $7A, $BF
	dc.b	$C2, $A7, $97, $44, $63, $1F, $FA, $BC, $AC, $A7, $B1, $FB, $84, $DF, $D9, $7C, $63, $1E, $AE, $45, $4A, $1D, $A6, $24, $FA, $4B, $51, $76, $10, $54, $63, $18
	dc.b	$9A, $65, $64, $81, $74, $17, $60, $56, $A8, $C6, $31, $90, $C9, $E5, $D8, $F9, $BF, $C2, $AB, $23, $18, $C7, $2B, $0B, $FA, $2B, $FE, $8C, $CF, $BD, $EB, $0B
	dc.b	$54, $63, $1E, $36, $B9, $86, $40, $8D, $F7, $D8, $43, $70, $25, $3F, $F7, $21, $4F, $E2, $32, $E2, $41, $C4, $63, $8D, $AE, $28, $6F, $E9, $6B, $8B, $8B, $B7
	dc.b	$35, $D9, $AE, $EC, $EC, $E8, $5D, $FF, $E1, $51, $A5, $C8, $56, $37, $1D, $1C, $9A, $94, $E4, $64, $C6, $39, $82, $B5, $10, $BF, $A0, $BF, $92, $EB, $DC, $B7
	dc.b	$2D, $CB, $76, $D3, $43, $9A, $92, $64, $91, $A4, $92, $46, $DA, $42, $C7, $EE, $42, $FF, $73, $58, $53, $97, $7A, $DC, $A9, $B8, $2D, $4B, $21, $8C, $4C, $4B
	dc.b	$B3, $1C, $03, $21, $2C, $2F, $0B, $64, $16, $A0, $A0, $A7, $A8, $6E, $7D, $E3, $FB, $21, $5F, $BD, $17, $AD, $CB, $75, $F5, $CC, $16, $3A, $47, $58, $98, $63
	dc.b	$FF, $CF, $FE, $54, $E5, $2D, $5F, $CD, $5A, $97, $7B, $A6, $56, $2C, $5B, $55, $FE, $E5, $09, $BF, $72, $26, $13, $29, $D7, $85, $2D, $55, $EE, $FF, $EB, $97
	dc.b	$5E, $2D, $DD, $2A, $5A, $BF, $DD, $62, $B5, $7E, $E6, $CF, $EC, $87, $2E, $F7, $5F, $5A, $AB, $FE, $4B, $A6, $72, $96, $AA, $F1, $62, $17, $F4, $2C, $28, $28
	dc.b	$29, $EB, $52, $C6, $E0, $EB, $DD, $B9, $C1, $55, $A9, $6A, $AF, $F9, $38, $D4, $EB, $F6, $AB, $6E, $AF, $E4, $BF, $F7, $23, $FF, $3B, $96, $A5, $DE, $B5, $2E
	dc.b	$FF, $F7, $2B, $AE, $FC, $58, $D4, $14, $14, $14, $FB, $EB, $DC, $26, $FD, $CB, $82, $97, $5A, $9D, $7A, $D5, $C2, $60, $B5, $2E, $BC, $77, $8E, $13, $28, $28
	dc.b	$3B, $18, $21, $7D, $84, $2F, $7A, $C6, $E7, $FF, $E7, $FF, $2A, $AE, $65, $62, $FF, $70, $E9, $D5, $BA, $CD, $C2, $F1, $FD, $9F, $DE, $DE, $EB, $E6, $53, $94
	dc.b	$B7, $62, $E9, $AF, $AD, $CB, $72, $EF, $72, $82, $83, $94, $EF, $DC, $B8, $29, $DB, $9C, $2F, $72, $DC, $A7, $6E, $C7, $C3, $16, $2C, $4B, $DD, $5A, $9C, $2F
	dc.b	$FD, $EE, $E7, $63, $75, $FD, $35, $AB, $17, $5A, $B1, $62, $99, $EA, $7D, $E3, $F7, $33, $28, $29, $DB, $9D, $7F, $F3, $57, $FC, $DD, $AE, $53, $B1, $62, $E9
	dc.b	$FD, $CA, $EC, $55, $6A, $5E, $E7, $2A, $BF, $DC, $FF, $B5, $53, $3B, $6B, $B1, $62, $C5, $7C, $C1, $7F, $B9, $13, $5E, $EB, $C2, $FF, $F3, $FC, $D5, $BA, $6A
	dc.b	$F1, $62, $98, $75, $FF, $27, $86, $E7, $07, $2A, $B5, $2E, $BB, $EB, $E9, $76, $2C, $58, $B1, $2F, $32, $66, $4E, $2A, $38, $A8, $CC, $91, $8C, $6E, $81, $96
	dc.b	$A6, $43, $26, $83, $D0, $D3, $A8, $11, $E8, $83, $1B, $46, $39, $9B, $8B, $7D, $92, $8E, $48, $D1, $8C, $12, $08, $C8, $D6, $B2, $46, $31, $CC, $8C, $17, $C9
	dc.b	$19, $1B, $0A, $09, $0D, $A0, $D0, $42, $43, $4E, $48, $68, $7C, $93, $89, $33, $5D, $C9, $68, $FD, $A8, $69, $0D, $17, $61, $44, $1B, $97, $F5, $60, $94, $E1
	dc.b	$46, $14, $46, $3C, $B1, $19, $75, $C1, $8B, $68, $68, $5A, $53, $1C, $28, $3B, $90, $DB, $4B, $69, $4E, $2A, $33, $5D, $8B, $10, $21, $30, $9B, $40, $42, $0B
	dc.b	$3C, $1A, $14, $41, $34, $B4, $28, $4E, $26, $4C, $1B, $06, $86, $2C, $53, $2B, $1A, $B6, $AB, $6D, $C8, $65, $B6, $1A, $08, $D0, $DA, $1A, $21, $DB, $83, $60
	dc.b	$D0, $6E, $95, $62, $56, $2E, $91, $D6, $FB, $D6, $FA, $5A, $4D, $FA, $BA, $2E, $EA, $85, $17, $51, $D6, $E5, $74, $D6, $A5, $AB, $1A, $9C, $A9, $94, $BF, $DC
	dc.b	$91, $AD, $4B, $B1, $A9, $45, $A0, $48, $7F, $14, $AE, $87, $F1, $49, $02, $85, $78, $EC, $2E, $0B, $FE, $8D, $7F, $E1, $73, $C8, $48, $2D, $0F, $45, $C6, $34
	dc.b	$41, $A0, $D4, $C3, $FA, $B8, $B1, $BB, $68, $AC, $56, $B7, $2D, $EB, $1C, $29, $13, $3E, $6A, $48, $E6, $42, $68, $34, $10, $E0, $D9, $B1, $F0, $E9, $70, $FE
	dc.b	$6D, $95, $AC, $39, $F2, $AF, $FA, $35, $B2, $3F, $B5, $0D, $AD, $D1, $0A, $12, $0D, $CB, $12, $C2, $EB, $5D, $6B, $AE, $61, $FB, $D5, $FE, $F4, $70, $D4, $46
	dc.b	$41, $84, $8E, $14, $11, $B4, $28, $82, $49, $30, $C5, $89, $DD, $35, $BF, $F7, $A1, $D4, $BE, $B7, $D0, $9D, $B4, $1B, $41, $B0, $FE, $2F, $26, $4C, $5B, $47
	dc.b	$5B, $96, $26, $AC, $38, $38, $2F, $86, $A7, $6A, $BA, $D7, $52, $D8, $50, $13, $37, $58, $C5, $8D, $D3, $38, $39, $7F, $FD, $0E, $0E, $EC, $A5, $01, $C0, $8F
	dc.b	$4A, $66, $C5, $B5, $D3, $39, $7F, $BD, $58, $5F, $EF, $57, $AA, $64, $A1, $1B, $7B, $0A, $2E, $E3, $B9, $1B, $89, $18, $7F, $BB, $87, $48, $74, $CE, $99, $D6
	dc.b	$17, $00, $70, $37, $6A, $C2, $96, $0B, $18, $50, $86, $13, $8C, $D1, $B3, $5D, $9A, $E8, $6F, $F1, $B6, $66, $DF, $E2, $6D, $FE, $36, $4E, $26, $4C, $D7, $43
	dc.b	$7F, $8A, $EC, $D7, $47, $33, $23, $72, $62, $B6, $88, $34, $0E, $47, $06, $C0, $ED, $6C, $C9, $99, $B8, $A8, $E2, $6B, $B8, $9B, $35, $D9, $BB, $73, $5D, $C9
	dc.b	$A0, $DC, $6D, $1C, $CD, $A5, $B4, $D1, $A6, $88, $36, $66, $E3, $D1, $C4, $DC, $7A, $21, $A2, $1A, $30, $D1, $C7, $44, $1B, $36, $8C, $1B, $8E, $8C, $3F, $8B
	dc.b	$83, $42, $50, $6C, $28, $BA, $88, $51, $06, $BA, $88, $51, $06, $B6, $14, $41, $A0, $8D, $06, $87, $F5, $61, $FC, $52, $4A, $21, $42, $3F, $0A, $10, $38, $36
	dc.b	$1F, $F5, $D0, $8D, $0A, $21, $44, $28, $87, $52, $68, $87, $52, $13, $60, $C0, $DE, $49, $06, $30, $61, $29, $51, $3F, $AA, $0D, $82, $34, $1A, $14, $40, $E1
	dc.b	$A1, $34, $5A, $09, $92, $83, $67, $C9, $9E, $6C, $F4, $2B, $09, $E8
Options_shift_display_tiles:
	dc.b	$2F, $E8, $5C, $1B, $95, $1A, $68, $8C, $28, $E2, $6C, $28, $C1, $B0, $95, $08, $76, $BD, $28, $FE, $8A, $9F, $7B, $26, $0D, $A6, $8E, $5D, $58, $68, $B4, $DB
	dc.b	$0B, $4C, $21, $B3, $ED, $2D, $4A, $7A, $89, $EA, $7A, $96, $A1, $7A, $DC, $AD, $36, $9E, $9E, $A2, $68, $35, $AC, $90, $46, $4D, $09, $42, $1D, $AC, $68, $C6
	dc.b	$82, $92, $79, $8B, $FA, $1D, $37, $F2, $70, $6C, $34, $60, $D0, $68, $51, $C9, $A1, $A3, $4D, $09, $41, $1A, $3D, $AD, $27, $A8, $9E, $8A, $AC, $38, $AC, $54
	dc.b	$CA, $72, $9B, $8A, $8C, $28, $D2, $C9, $06, $E4, $87, $C6, $C6, $1A, $0D, $0A, $1F, $A3, $03, $0A, $2D, $E8, $10, $32, $B4, $C8, $52, $DC, $48, $D9, $93, $8D
	dc.b	$8E, $8D, $3D, $49, $83, $0D, $09, $41, $39, $FB, $C6, $E7, $BA, $4E, $5D, $7C, $57, $66, $6C, $CD, $06, $E4, $87, $0A, $30, $60, $6C, $7A, $08, $13, $1D, $08
	dc.b	$16, $E4, $07, $29, $AB, $E2, $BA, $31, $83, $42, $88, $34, $28, $32, $36, $4A, $0C, $83, $85, $08, $E1, $58, $B7, $F7, $AB, $70, $72, $F3, $5D, $99, $B8, $99
	dc.b	$33, $26, $63, $CC, $99, $9B, $33, $48, $DB, $91, $04, $6E, $44, $6D, $C6, $47, $77, $19, $53, $C6, $54, $F1, $91, $D1, $C8, $8D, $1B, $32, $66, $4C, $C9, $74
	dc.b	$1B, $4B, $5D, $99, $B8, $AE, $A2, $0D, $A6, $E6, $E2, $B9, $A3, $A5, $B3, $36, $66, $CC, $DC, $BA, $B8, $99, $34, $B4, $19, $0B, $93, $19, $2D, $B3, $36, $66
	dc.b	$E4, $D0, $A3, $91, $43, $44, $10, $AC, $46, $24, $B1, $68, $60, $B5, $13, $CB, $18, $86, $84, $30, $4C, $4D, $03, $B1, $01, $36, $A4, $C9, $02, $83, $21, $02
	dc.b	$7A, $9E, $A5, $85, $56, $F2, $C7, $D0, $42, $61, $83, $21, $07, $0B, $6C, $E1, $FD, $1A, $DF, $B9, $EB, $DC, $B5, $3B, $AD, $D8, $C6, $37, $63, $0B, $7A, $EB
	dc.b	$5B, $C9, $3F, $72, $F5, $10, $DC, $F5, $2D, $58, $F7, $2E, $F5, $87, $6E, $5B, $EF, $70, $BD, $64, $1C, $A1, $5A, $88, $39, $4B, $55, $6A, $1F, $B9, $99, $F7
	dc.b	$CD, $62, $FF, $72, $B1, $33, $D4, $ED, $B6, $5E, $E9, $9F, $7D, $73, $0F, $E4, $B9, $7F, $B9, $AE, $6B, $1C, $AA, $F1, $85, $D7, $B5, $58, $BA, $55, $FE, $E5
	dc.b	$2C, $62, $C5, $8A, $60, $E5, $63, $52, $C2, $DD, $8B, $1B, $DD, $8C, $39, $F5, $CC, $ED, $4E, $DA, $E1, $C2, $67, $3E, $B0, $E9, $AB, $5B, $95, $FE, $E7, $62
	dc.b	$C5, $89, $DD, $7F, $BD, $E9, $15, $F4, $85, $3B, $6B, $94, $15, $B6, $B5, $38, $87, $5C, $BA, $DE, $EC, $6E, $51, $87, $3D, $4B, $97, $00, $A7, $5E, $38, $28
	dc.b	$2A, $4E, $15, $A9, $CA, $E0, $BA, $D4, $EE, $B7, $62, $C5, $B4, $75, $85, $FE, $F7, $18, $FD, $EE, $3A, $E6, $74, $C3, $16, $2C, $58, $C2, $C2, $BA, $5C, $A7
	dc.b	$4C, $16, $EE, $97, $02, $E9, $74, $DC, $36, $B8, $38, $3A, $6E, $16, $70, $53, $82, $82, $97, $C1, $6E, $DB, $5A, $DC, $B7, $4C, $ED, $AE, $5B, $A6, $72, $EB
	dc.b	$C6, $EC, $6E, $0E, $C4, $EE, $97, $B9, $61, $D3, $2B, $1B, $B1, $3A, $6E, $1D, $31, $E2, $A2, $31, $8C, $63, $98, $D0, $91, $B9, $49, $92, $0D, $81, $A4, $13
	dc.b	$92, $14, $13, $06, $85, $C5, $03, $C1, $A0, $5B, $D8, $34, $0C, $23, $72, $7A, $34, $63, $18, $C1, $A3, $06, $CD, $47, $1B, $24, $1B, $06, $83, $24, $19, $2E
	dc.b	$83, $71, $A3, $42, $8D, $26, $DA, $5A, $0C, $8C, $94, $69, $46, $34, $38, $50, $84, $8F, $3A, $0C, $52, $0C, $A8, $06, $83, $93, $42, $8E, $54, $41, $A0, $D0
	dc.b	$4D, $08, $C4, $65, $BD, $48, $43, $06, $86, $80, $93, $52, $2C, $13, $D5, $62, $CE, $C2, $A2, $14, $14, $DF, $C4, $90, $21, $4A, $63, $27, $EF, $05, $BD, $D9
	dc.b	$3D, $4E, $9B, $52, $A6, $FD, $E8, $50, $5E, $E7, $09, $3C, $B1, $82, $58, $C6, $16, $F2, $EB, $0B, $73, $DD, $36, $AA, $F2, $40, $E0, $E5, $89, $7E, $F4, $4C
	dc.b	$16, $F3, $0B, $7A, $DC, $B5, $2C, $12, $EB, $5A, $96, $15, $58, $53, $9E, $A7, $2A, $67, $FF, $24, $2C, $29, $CA, $AC, $2E, $55, $A9, $C1, $64, $1D, $7B, $9F
	dc.b	$5A, $C2, $C5, $6F, $5F, $02, $7B, $9E, $E5, $82, $7B, $9E, $BA, $D6, $16, $1C, $4B, $12, $D4, $42, $4B, $05, $AA, $4B, $05, $62, $DC, $A9, $9D, $78, $EB, $75
	dc.b	$F8, $EF, $15, $85, $89, $9D, $62, $C4, $CF, $30, $E2, $0B, $79, $93, $81, $2D, $E4, $08, $57, $BB, $82, $F7, $3A, $65, $6D, $55, $6F, $5E, $E7, $3E, $6F, $E8
	dc.b	$D6, $B5, $03, $0A, $AC, $AF, $23, $17, $90, $50, $21, $B9, $CA, $5B, $B1, $BB, $75, $78, $DD, $7A, $DC, $2B, $BD, $6E, $B2, $F5, $B8, $56, $15, $58, $70, $5F
	dc.b	$00, $E1, $8E, $BD, $5B, $5C, $24, $F5, $B8, $13, $EB, $5B, $9E, $E7, $D6, $BE, $01, $CB, $FD, $E8, $74, $C1, $CF, $74, $C1, $CB, $7A, $C1, $B9, $62, $40, $C9
	dc.b	$61, $CB, $18, $EB, $5D, $F3, $07, $63, $BD, $77, $BD, $58, $EF, $0A, $DA, $F7, $2C, $4C, $15, $33, $E4, $26, $B0, $84, $C1, $CA, $06, $FA, $D4, $08, $C9, $41
	dc.b	$CF, $58, $76, $30, $41, $CB, $57, $43, $95, $62, $C3, $97, $B0, $6D, $A6, $60, $BE, $85, $F0, $15, $AD, $F5, $BD, $6F, $5E, $41, $4E, $12, $17, $8B, $C9, $EE
	dc.b	$5B, $B1, $85, $2C, $3B, $1D, $93, $56, $BB, $26, $52, $EB, $EB, $72, $DD, $D2, $AA, $FA, $DD, $8B, $14, $CE, $BD, $D8, $EB, $7A, $B1, $D6, $A7, $7F, $B9, $CA
	dc.b	$58, $E9, $72, $D5, $5C, $DF, $DD, $99, $DD, $35, $ED, $B1, $CB, $76, $D3, $7B, $96, $F7, $3E, $B7, $D6, $A9, $9D, $7D, $6A, $5B, $A6, $E1, $30, $5B, $A6, $1B
	dc.b	$42, $C6, $37, $2D, $C4, $16, $16, $E0, $E7, $CC, $E0, $BB, $16, $1C, $17, $99, $33, $2F, $30, $E2, $B8, $71, $20, $E2, $31, $85, $10, $64, $5E, $0D, $0A, $11
	dc.b	$60, $E0, $90, $64, $60, $90, $48, $21, $A0, $68, $5B, $90, $BA, $0C, $84, $84, $B3, $B9, $90, $CA, $75, $F3, $D3, $94, $F3, $1E, $53, $89, $8F, $9C, $9E, $B8
	dc.b	$51, $6C, $10, $9A, $07, $E0, $5F, $B3, $24, $20, $65, $48, $20, $BC, $8D, $61, $64, $32, $45, $A1, $4E, $08, $ED, $24, $06, $84, $19, $08, $C8, $31, $83, $42
	dc.b	$3B, $0B, $FA, $24, $F2, $B2, $FB, $09, $EB, $51, $1A, $A4, $26, $32, $12, $7A, $C8, $28, $BA, $14, $B1, $30, $59, $18, $29, $9E, $42, $40, $84, $96, $F2, $37
	dc.b	$AC, $2D, $4B, $23, $EB, $32, $13, $14, $C4, $64, $31, $95, $24, $26, $05, $FB, $91, $27, $EE, $B0, $84, $DD, $05, $35, $8B, $79, $28, $63, $79, $85, $85, $C8
	dc.b	$10, $58, $20, $4F, $5B, $E4, $64, $F5, $87, $1A, $15, $86, $E2, $08, $5A, $96, $65, $A9, $40, $82, $B5, $52, $4A, $5D, $E0, $A9, $13, $02, $D8, $26, $04, $E5
	dc.b	$BB, $19, $53, $2A, $DE, $BD, $5C, $3F, $A2, $E0, $4B, $E8, $FC, $E2, $C4, $C3, $9E, $95, $85, $8E, $72, $A5, $53, $4E, $72, $43, $FE, $89, $7F, $84, $AC, $5D
	dc.b	$85, $CE, $F5, $85, $83, $27, $AC, $5E, $BA, $BF, $38, $F9, $81, $E7, $E7, $FD, $C9, $CB, $9D, $EA, $12, $06, $46, $FC, $AD, $24, $0B, $06, $84, $11, $E4, $24
	dc.b	$11, $E7, $27, $98, $20, $9C, $D6, $53, $56, $40, $A9, $AB, $23, $D4, $E5, $A9, $0C, $9E, $E5, $BA, $82, $04, $0C, $AD, $7A, $3D, $0E, $D2, $30, $40, $ED, $A5
	dc.b	$6F, $90, $23, $0B, $20, $62, $46, $0B, $1B, $84, $A6, $AC, $16, $C2, $79, $5A, $F2, $7C, $8D, $E8, $24, $B1, $24, $05, $36, $A5, $85, $84, $90, $58, $92, $52
	dc.b	$B9, $3C, $A6, $15, $89, $2E, $C7, $12, $12, $F5, $19, $1C, $DD, $13, $59, $30, $C6, $31, $8C, $62, $67, $CD, $67, $05, $82, $B1, $CB, $7C, $BA, $26, $1C, $04
	dc.b	$CF, $E0, $09, $64, $31, $FF, $46, $94, $79, $2C, $ED, $81, $82, $7E, $D0, $4B, $7A, $EC, $25, $89, $85, $EF, $98, $7E, $E4, $DE, $41, $6F, $90, $25, $EE, $B1
	dc.b	$62, $6B, $09, $63, $1B, $C8, $5F, $5F, $EE, $6B, $C7, $C3, $18, $DA, $A5, $85, $2C, $AF, $58, $BD, $65, $62, $AB, $1B, $89, $CB, $2D, $52, $30, $43, $AC, $5F
	dc.b	$33, $97, $62, $AB, $53, $82, $82, $9C, $A0, $E2, $B1, $4E, $50, $39, $8A, $F2, $34, $0B, $17, $8A, $5C, $B0, $6A, $08, $DF, $DD, $0B, $CB, $B0, $8C, $94, $BF
	dc.b	$E8, $A8, $65, $32, $9F, $B0, $AC, $56, $F1, $95, $99, $02, $0A, $47, $F3, $05, $A9, $E6, $84, $16, $A0, $B2, $B0, $81, $F4, $7E, $CC, $A6, $24, $2A, $75, $18
	dc.b	$5B, $FF, $84, $16, $17, $97, $55, $B3, $5C, $D7, $73, $FE, $E5, $29, $B6, $EA, $3F, $E9, $A7, $F2, $F4, $6F, $DD, $6F, $96, $53, $95, $C7, $6E, $C4, $5F, $EB
	dc.b	$0A, $CB, $D6, $08, $D0, $F8, $DA, $09, $DB, $FC, $46, $FD, $3D, $1B, $F8, $53, $6D, $1F, $97, $FD, $51, $FF, $13, $F9, $69, $71, $52, $84, $11, $88, $D0, $87
	dc.b	$F1, $1B, $7A, $9A, $0D, $0D, $1A, $1B, $F8, $35, $25, $82, $1D, $D0, $6E, $DA, $49, $0D, $2E, $B6, $9C, $8F, $78, $DF, $31, $25, $36, $CC, $69, $FB, $32, $A6
	dc.b	$DA, $61, $49, $43, $B4, $F4, $B1, $E5, $4F, $F9, $0A, $94, $FD, $5F, $52, $DE, $7A, $A9, $F1, $C8, $10, $FE, $1E, $5F, $F5, $F0, $A6, $D2, $3F, $E9, $7F, $D4
	dc.b	$13, $E6, $1C, $D6, $2C, $13, $C8, $48, $F2, $A4, $A9, $85, $18, $34, $19, $1B, $7A, $84, $F1, $6F, $EA, $7E, $CC, $2F, $54, $82, $AC, $3B, $4D, $92, $84, $34
	dc.b	$34, $D9, $0F, $E2, $E1, $BC, $7E, $1E, $36, $91, $F3, $2D, $F8, $F5, $F6, $51, $BD, $47, $81, $A1, $F8, $7F, $57, $62, $53, $6E, $54, $A5, $3C, $C7, $92, $17
	dc.b	$F4, $48, $19, $04, $58, $6F, $03, $7A, $50, $8C, $76, $B2, $1B, $6F, $1A, $52, $94, $91, $91, $C9, $0A, $E9, $54, $68, $D8, $30, $E7, $2A, $A5, $4D, $8B, $04
	dc.b	$6B, $39, $CE, $75, $85, $89, $6C, $FD, $61, $B1, $5A, $65, $BD, $47, $81, $F3, $59, $72, $1D, $5F, $D2, $4F, $CE, $10, $51, $3C, $8C, $94, $BB, $3F, $38, $56
	dc.b	$52, $CA, $47, $D3, $BC, $74, $4E, $85, $BC, $64, $3F, $85, $B0, $8F, $F5, $74, $82, $12, $4A, $54, $F3, $19, $3C, $8F, $9A, $C2, $32, $7D, $BF, $D1, $6F, $F2
	dc.b	$15, $32, $39, $21, $B6, $C4, $39, $AC, $98, $63, $13, $6A, $58, $9A, $CA, $DE, $BD, $4E, $1F, $BD, $A7, $F3, $8F, $AF, $99, $E6, $5E, $4B, $A5, $20, $80, $D6
	dc.b	$29, $48, $73, $85, $D8, $C7, $CE, $6B, $B1, $24, $73, $3D, $B2, $18, $C4, $C4, $0B, $18, $9A, $9C, $86, $42, $43, $F6, $7F, $C2, $DE, $3E, $6D, $88, $4F, $23
	dc.b	$FE, $14, $CF, $C8, $2E, $C9, $86, $5D, $19, $4C, $42, $53, $73, $6A, $2B, $0B, $B3, $98, $49, $F9, $2D, $F8, $C2, $C5, $2F, $C8, $73, $02, $7D, $6F, $BE, $D5
	dc.b	$91, $A8, $AD, $25, $E4, $A2, $32, $D4, $B0, $64, $BC, $9E, $47, $30, $25, $90, $E6, $9B, $52, $DF, $8F, $25, $05, $2C, $34, $96, $16, $F3, $21, $36, $A2, $7A
	dc.b	$F5, $17, $61, $74, $2F, $FC, $2B, $27, $93, $D6, $08, $2C, $13, $CA, $C5, $82, $04, $BE, $85, $9F, $42, $CC, $BF, $A3, $2F, $F0, $92, $FB, $08, $10, $27, $EF
	dc.b	$41, $A1, $47, $8C, $BF, $B4, $DE, $0C, $8D, $6B, $41, $B7, $9B, $7B, $42, $73, $1E, $49, $B1, $29, $26, $ED, $B6, $E4, $BB, $FA, $42, $54, $FF, $0B, $C3, $A8
	dc.b	$D3, $F8, $68, $D6, $B2, $1D, $BE, $3B, $24, $65, $39, $FE, $AD, $BB, $53, $FA, $43, $FA, $46, $55, $32, $32, $75, $6F, $1B, $5A, $6D, $E0, $76, $9C, $B6, $5B
	dc.b	$AC, $B5, $D9, $75, $BF, $CB, $C8, $F9, $8F, $BA, $99, $51, $BD, $A2, $9F, $FA, $76, $B5, $C8, $7F, $F5, $7C, $E3, $5C, $82, $7E, $CF, $C6, $5E, $5F, $F5, $43
	dc.b	$2F, $E1, $FF, $95, $28, $B4, $CA, $9D, $ED, $84, $7D, $2A, $96, $AF, $DC, $9E, $F6, $8E, $24, $64, $97, $91, $A1, $C8, $E8, $FE, $A2, $C2, $87, $E7, $2A, $E7
	dc.b	$92, $D5, $2B, $F6, $A9, $6F, $3D, $ED, $1C, $48, $C9, $2F, $23, $43, $91, $D1, $FD, $45, $BF, $59, $F3, $98
Car_select_tilemap:
	dc.b	$0A, $00, $00, $00, $00, $03, $0D, $10, $28, $80, $47, $9E, $6D, $70, $AE, $98, $5E, $78, $55, $C3, $EA, $62, $11, $E1, $57, $14, $69, $8A, $A0, $A0, $02, $06
	dc.b	$D7, $18, $A9, $8C, $C0, $A0, $02, $06, $D7, $1C, $E9, $8E, $E7, $85, $5C, $86, $A6, $45
	dc.b	$1E
	dc.b	$15, $72, $66, $99, $3A, $78, $55, $CA, $CA, $65, $81, $E5, $53, $32, $CF, $2A, $99, $CC, $12, $40, $A0, $45, $10, $38, $0A, $20, $88, $76, $01, $73, $C2, $AE
	dc.b	$84
	dc.b	$53
	dc.b	$43, $0F, $0A, $BA, $37, $4D, $1F, $3C, $2A, $E9, $75, $34, $C8, $34, $0D, $AE, $A0
	dc.b	$53
	dc.b	$51, $01, $40, $04, $0D, $AE, $A8
	dc.b	$D3
	dc.b	$55, $4F, $0A, $BA, $C9, $4D, $68, $3C, $2A, $EB, $BD, $35, $EC, $F0, $AB, $B1, $54, $D8, $E1, $A8, $97, $64, $40, $31, $80, $80, $64
	dc.b	$01
	dc.b	$00, $CA, $02, $01, $98, $0F, $36, $90, $CC, $69, $5A, $6B, $E6, $7D, $A3, $7E, $99, $CC, $12, $26, $53, $03, $83, $B2, $0B
	dc.b	$1E
	dc.b	$15, $77, $1A, $9B, $94, $78, $55, $DD, $9A, $6E, $E9, $E1, $57, $7B, $29, $BE, $00, $A0, $02, $10, $05, $C3, $2B, $BF, $94, $E0, $00, $50, $01, $03, $6B, $C1
	dc.b	$B4, $E1, $13, $C2, $AF, $10
	dc.b	$53
	dc.b	$89, $0F, $0A, $BC, $67, $4E, $37, $3C, $2A, $F2, $35, $39, $2A, $D9, $68, $1C, $03, $10, $0A, $C6, $30, $34, $4C, $BA, $32, $9D, $F3, $3E, $D1, $BF, $4C, $E6
	dc.b	$FE, $00
Car_intro_sprite_frame_table:
	dc.l	Car_intro_frame_data_2F12C
	dc.l	Car_intro_frame_data_2F124
	dc.l	Car_intro_frame_data_2F11C
	dc.l	Car_intro_frame_data_2F114
	dc.l	Car_intro_frame_data_2F106
	dc.l	Car_intro_frame_data_2F0F8
	dc.l	Car_intro_frame_data_2F0E4
	dc.l	Car_intro_frame_data_2F0BE
	dc.l	Car_intro_frame_data_2F08C
Car_intro_frame_data_2F08C:
	dc.b	$00, $07, $D0, $09, $00, $00, $FF, $E4, $D0, $09, $00, $06, $FF, $FC
	dc.b	$E0, $0B, $00, $0C, $FF, $CC, $E0, $0B, $00, $18, $FF, $E4, $E0, $0B
	dc.b	$00, $24, $FF, $FC, $E0, $0F, $00, $30, $00, $14, $F8, $00, $00, $40
	dc.b	$FF, $C4, $F8, $00, $00, $41, $00, $34
Car_intro_frame_data_2F0BE:
	dc.b	$00, $05, $E0, $04, $00, $42, $FF, $E4, $E0, $0B, $00, $44, $FF, $F4
	dc.b	$E8, $0A, $00, $50, $FF, $D4, $F0, $01, $00, $59, $FF, $EC, $E8, $0A
	dc.b	$00, $5B, $00, $0C, $F8, $00, $00, $64, $00, $24
Car_intro_frame_data_2F0E4:
	dc.b	$00, $02, $E8, $0A, $00, $65, $FF, $F0, $F0, $05, $00, $6E, $FF, $E0
	dc.b	$F0, $09, $00, $72, $00, $08
Car_intro_frame_data_2F0F8:
	dc.b	$00, $01, $F0, $09, $00, $78, $FF, $E8, $F0, $09, $00, $7E, $00, $00
Car_intro_frame_data_2F106:
	dc.b	$00, $01, $F0, $09, $00, $84, $FF, $F0, $F8, $00, $00, $8A, $00, $08
Car_intro_frame_data_2F114:
	dc.b	$00, $00, $F8, $08, $00, $8B, $FF, $F4
Car_intro_frame_data_2F11C:
	dc.b	$00, $00, $F8, $04, $00, $8E, $FF, $F8
Car_intro_frame_data_2F124:
	dc.b	$00, $00, $F8, $04, $00, $90, $FF, $F8
Car_intro_frame_data_2F12C:
	dc.b	$00, $00, $F8, $00, $00, $92, $FF, $FC
Arcade_car_spec_palette_stream:
	dc.b	$02, $3E, $00, $00, $0E, $EE, $02, $22, $02, $24, $02, $26, $0A, $AA, $0C, $CC, $06, $44, $04, $48, $04, $4A, $08, $66, $06, $68, $06, $6A, $06, $8A, $08, $8A
	dc.b	$00, $00, $00, $00, $02, $2E, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $06, $6A, $0A, $AA, $0A, $AC, $0C, $CE, $06, $66, $06, $68
	dc.b	$00, $00, $00, $00, $00, $CE, $02, $22, $04, $44, $02, $44, $04, $66, $04, $46, $06, $88, $0A, $AA, $06, $66, $0A, $CC, $06, $6A, $02, $8A, $02, $AC, $02, $CE
	dc.b	$00, $00, $08, $8A, $0A, $AC, $0C, $CC, $06, $66, $0A, $AA, $04, $22, $06, $44, $06, $22, $0A, $44, $08, $22, $0C, $44, $0A, $22, $0E, $44, $0E, $66, $08, $88
Arcade_car_spec_car_frame_a:
	dc.b	$00, $01, $E0, $08, $00, $E5, $FF, $F8, $E8, $0E, $00, $E8, $FF, $F0
Arcade_car_spec_car_frame_b:
	dc.b	$00, $01, $E0, $0E, $00, $F4, $FF, $F0, $F8, $08, $01, $00, $FF, $F8
Arcade_car_spec_car_frame_c:
	dc.b	$00, $02, $D8, $04, $01, $03, $FF, $F4, $E0, $0F, $01, $05, $FF, $EC, $E0, $01, $01, $15, $00, $0C
Arcade_car_spec_car_frame_d:
	dc.b	$00, $00, $E8, $06, $01, $17, $FF, $F8
Arcade_car_spec_tilemap_1:
	dc.b	$08, $00, $00, $63, $00, $63, $01, $70, $1F, $4C, $27, $D1, $0D, $F4, $49, $50, $05, $49, $40, $55, $4F, $01, $43, $C0, $4C, $F0, $13, $1B, $F8, $00
Arcade_car_spec_tilemap_2:
	dc.b	$08, $00, $00, $63, $00, $63, $01, $0A, $58, $28, $71, $C4, $63, $AD, $8A, $85, $FC, $CA, $FB, $9F, $C0, $00
Arcade_car_spec_tilemap_3:
	dc.b	$07, $01, $00, $00, $00, $00, $01, $00, $15, $07, $08, $0A, $90, $00, $81, $57, $90, $10, $00, $0A, $B4, $40, $B8, $82, $80, $11, $60, $1A, $88, $30, $15, $42
	dc.b	$6C, $03, $53, $06, $06, $00, $40, $B4, $44, $38, $04, $55, $12, $A2, $20, $05, $51, $2A, $22, $1C, $02, $2A, $89, $51, $10, $E2, $10, $24, $45, $11, $90, $2A
	dc.b	$8E, $51, $19, $02, $A8, $E5, $81, $9A, $63, $24, $64, $A8, $A6, $53, $86, $A0, $0C, $34, $B4, $CA, $72, $54, $53, $29, $A6, $48, $46, $1B, $2E, $40, $35, $F5
	dc.b	$D4, $CC, $F2, $59, $53, $33, $C3, $65, $C8, $06, $BE, $BA, $99, $9D, $12, $EE, $20, $26, $21, $C0, $0A, $0E, $99, $BF, $00, $AA, $67, $74, $CD, $F8, $05, $53
	dc.b	$3B, $A6, $6F, $C0, $2A, $99, $DD, $33, $72, $2C, $1F, $D8, $3F, $B0, $7F, $4C, $FC, $8B, $09, $16, $12, $2C, $24, $53, $48, $23, $26, $AD, $35, $6B, $0A, $36
	dc.b	$14, $69, $A8, $91, $93, $7A, $9A, $FD, $85, $AB, $0B, $54, $D6, $BF, $80, $00
Arcade_car_spec_tiles:
	dc.b	$80, $E4, $80, $03, $00, $14, $05, $25, $12, $36, $2A, $46, $34, $56, $2F, $66, $37, $74, $06, $81, $04, $02, $16, $33, $28, $F2, $82, $04, $08, $17, $76, $83
	dc.b	$05, $13, $17, $78, $84, $06, $30, $85, $04, $03, $16, $31, $27, $77, $86, $04, $04, $16, $38, $28, $F4, $87, $04, $07, $17, $74, $27, $75, $88, $06, $36, $89
	dc.b	$06, $35, $8A, $05, $16, $18, $F5, $8B, $06, $2E, $8C, $06, $2B, $8D, $06, $32, $18, $F6, $8E, $05, $14, $18, $F3, $8F, $06, $39, $FF, $FF, $D3, $37, $FD, $FF
	dc.b	$EE, $CC, $CB, $FB, $76, $65, $E9, $57, $ED, $EA, $E8, $CC, $CB, $FB, $76, $65, $E9, $FD, $6E, $9F, $D6, $66, $66, $66, $FF, $BC, $3C, $7F, $1F, $1D, $0C, $18
	dc.b	$C4, $1C, $BB, $B0, $C5, $9B, $FE, $FF, $F7, $65, $3D, $CF, $7F, $DB, $B3, $2F, $4A, $BA, $C5, $5D, $0D, $8E, $F3, $61, $FB, $75, $FF, $BB, $32, $F9, $5F, $C1
	dc.b	$54, $4D, $A7, $55, $48, $74, $AB, $10, $49, $23, $91, $34, $8F, $73, $66, $5F, $E3, $A3, $33, $33, $33, $54, $FD, $92, $F3, $EB, $23, $72, $BF, $3B, $CA, $5F
	dc.b	$B5, $29, $62, $0C, $B4, $C4, $81, $03, $53, $47, $9B, $C7, $F1, $E1, $D9, $98, $7F, $9D, $89, $4D, $4C, $27, $75, $C4, $63, $C7, $48, $54, $04, $0A, $5E, $40
	dc.b	$B4, $26, $58, $35, $29, $77, $05, $56, $31, $FB, $71, $0F, $1D, $59, $AA, $4D, $1E, $30, $87, $85, $FE, $AA, $FF, $16, $AF, $E2, $CB, $D3, $C2, $3A, $5E, $43
	dc.b	$FE, $2D, $57, $46, $60, $F1, $D2, $01, $F4, $87, $06, $A9, $27, $07, $32, $AB, $12, $6D, $0D, $9A, $5D, $17, $F6, $EC, $CC, $CC, $6D, $BC, $38, $E8, $5D, $19
	dc.b	$9A, $5D, $09, $94, $B7, $26, $1F, $D7, $66, $66, $66, $6E, $8A, $9D, $71, $BF, $1B, $CD, $A4, $52, $39, $3C, $8C, $1A, $F5, $3B, $CD, $01, $A9, $83, $D0, $D4
	dc.b	$BF, $AE, $CE, $CD, $D7, $4C, $6F, $C5, $EA, $86, $07, $A4, $63, $7E, $37, $9B, $1E, $90, $77, $E2, $3F, $8E, $A7, $7F, $6F, $DB, $B4, $89, $4A, $A2, $19, $83
	dc.b	$1D, $67, $DA, $58, $8C, $55, $FF, $44, $E0, $D9, $9B, $77, $4D, $C9, $9B, $F8, $EC, $C0, $98, $BA, $25, $45, $27, $3D, $33, $60, $64, $3A, $02, $89, $F4, $66
	dc.b	$66, $60, $77, $E3, $7C, $38, $E8, $5D, $1A, $A3, $66, $66, $97, $50, $7F, $A2, $E9, $2E, $F2, $C6, $FC, $59, $9B, $73, $97, $43, $07, $A4, $74, $40, $6D, $79
	dc.b	$B6, $FD, $F4, $36, $60, $63, $B3, $A0, $39, $1A, $E2, $A7, $2C, $41, $A9, $3F, $60, $60, $D9, $92, $F3, $FD, $B8, $31, $FC, $75, $3D, $3B, $E9, $1D, $19, $9A
	dc.b	$A8, $78, $E9, $D9, $CC, $1F, $4E, $CE, $CC, $CE, $CA, $5B, $A6, $77, $F1, $D7, $73, $6D, $CF, $FA, $E0, $D4, $A4, $72, $29, $62, $A5, $23, $1D, $13, $AE, $3F
	dc.b	$C7, $58, $66, $D3, $A6, $E4, $08, $14, $88, $23, $3A, $3C, $7F, $1F, $85, $E8, $A5, $B9, $03, $BC, $AA, $20, $5A, $15, $47, $A3, $83, $5E, $BD, $DE, $15, $FB
	dc.b	$4C, $1E, $E7, $7E, $3B, $9D, $FD, $F4, $36, $60, $75, $11, $A9, $B3, $35, $E7, $BE, $37, $9E, $E6, $3F, $6E, $CC, $0D, $4E, $A3, $53, $69, $1D, $46, $A6, $0F
	dc.b	$73, $53, $91, $B6, $F8, $DE, $7A, $18, $C6, $A3, $AB, $1A, $B1, $07, $A1, $C7, $56, $91, $B3, $36, $86, $0D, $AF, $31, $FB, $70, $60, $F4, $31, $FB, $50, $6A
	dc.b	$60, $C1, $83, $5C, $6F, $30, $63, $FE, $A0, $D7, $F6, $AA, $63, $F6, $AB, $DE, $46, $B8, $83, $07, $B9, $83, $D0, $DB, $73, $DF, $1D, $CF, $73, $DC, $E5, $FC
	dc.b	$63, $97, $EC, $4E, $44, $1C, $A5, $C3, $84, $53, $5C, $64, $6A, $77, $98, $35, $C4, $1D, $47, $34, $1C, $07, $4C, $DF, $3E, $83, $35, $CC, $7A, $74, $E3, $43
	dc.b	$DF, $BD, $F8, $B2, $FA, $3A, $07, $41, $9A, $A3, $CB, $30, $87, $C3, $FA, $33, $63, $79, $E9, $88, $3A, $B1, $06, $CC, $CC, $3F, $6E, $C0, $F7, $36, $66, $66
	dc.b	$07, $D6, $31, $06, $31, $96, $20, $E4, $7D, $B8, $FD, $1A, $74, $F4, $F0, $92, $30, $60, $E5, $88, $C6, $A3, $91, $83, $D0, $EA, $C5, $4C, $7E, $D4, $3F, $EC
	dc.b	$BF, $EF, $D7, $BE, $9D, $EF, $C6, $F3, $8E, $A6, $C6, $DD, $2A, $ED, $D2, $AE, $97, $9E, $E7, $B9, $8C, $7F, $65, $2F, $EA, $E8, $72, $8E, $B1, $FE, $78, $EA
	dc.b	$75, $7E, $D7, $4C, $6A, $C5, $A4, $75, $62, $0E, $A3, $1F, $E7, $8E, $BF, $B2, $70, $63, $10, $6A, $6D, $2C, $41, $C8, $F7, $30, $6B, $FD, $51, $DB, $F4, $7D
	dc.b	$93, $A7, $A4, $3A, $29, $EE, $6A, $6C, $D5, $1D, $E6, $0E, $A7, $89, $C3, $F1, $D5, $3A, $70, $F2, $3D, $CE, $46, $DB, $9B, $6E, $7F, $E7, $FD, $17, $4E, $DD
	dc.b	$2A, $C5, $71, $66, $07, $23, $DF, $B8, $31, $DF, $B7, $5F, $D1, $7E, $DF, $B3, $C2, $9C, $8E, $46, $3B, $B1, $B7, $FD, $D9, $9A, $5D, $AF, $C5, $A5, $D4, $1F
	dc.b	$ED, $E4, $60, $D5, $EA, $36, $66, $66, $1F, $D7, $66, $BC, $B7, $26, $BC, $9A, $F7, $9C, $3C, $8D, $4F, $AE, $20, $DC, $94, $E5, $9A, $9C, $8A, $AE, $E5, $2C
	dc.b	$41, $96, $98, $90, $25, $EE, $8E, $90, $31, $4E, $B0, $A8, $4D, $79, $6E, $95, $39, $84, $D3, $14, $D3, $1C, $3F, $6E, $21, $E3, $A8, $3B, $CD, $8D, $51, $48
	dc.b	$1F, $42, $E8, $86, $A6, $A6, $A6, $0D, $A4, $72, $EB, $DB, $A2, $29, $54, $4A, $4C, $0A, $F2, $9C, $68, $F8, $B0, $78, $E9, $82, $F4, $84, $06, $A8, $A4, $8A
	dc.b	$84, $0A, $A2, $52, $53, $BC, $8E, $F2, $91, $34, $90, $38, $26, $66, $25, $CD, $14, $97, $D3, $42, $62, $D1, $F8, $EA, $CC, $CD, $23, $DF, $16, $97, $54, $84
	dc.b	$BC, $B7, $2B, $C9, $4C, $1E, $F8, $EE, $6A, $4D, $A7, $40, $50, $F8, $DF, $8D, $E6, $D2, $29, $1C, $9E, $5D, $D7, $AB, $4F, $15, $3D, $CD, $4B, $F8, $E9, $B9
	dc.b	$26, $EE, $DD, $5A, $45, $27, $96, $6C, $0F, $47, $C6, $FC, $74, $23, $D0, $94, $E5, $9C, $CE, $A2, $AB, $B7, $53, $5C, $6A, $FE, $3A, $48, $AA, $35, $2B, $C9
	dc.b	$4A, $A4, $78, $47, $4A, $8D, $4D, $4B, $A9, $62, $CC, $D7, $9A, $3A, $49, $D8, $16, $85, $2F, $E3, $98, $2A, $8D, $4A, $A3, $69, $75, $67, $36, $63, $CE, $4E
	dc.b	$71, $9A, $96, $E4, $0D, $99, $AF, $3A, $BA, $AF, $E8, $BA, $0F, $E2, $E8, $77, $9B, $03, $91, $B1, $C8, $EF, $31, $DA, $AC, $56, $27, $13, $06, $D7, $9A, $99
	dc.b	$4B, $05, $35, $F2, $63, $05, $2C, $F0, $D3, $35, $2F, $08, $E7, $81, $6E, $4D, $22, $EB, $A1, $02, $52, $52, $04, $33, $0F, $98, $29, $7E, $8E, $3F, $28, $7F
	dc.b	$A2, $9E, $12, $29, $25, $44, $08, $27, $4C, $C1, $21, $02, $52, $09, $A7, $92, $94, $8A, $7F, $E2, $F2, $FD, $94, $FC, $86, $6A, $64, $3C, $A4, $40, $AA, $72
	dc.b	$60, $5B, $CC, $AA, $23, $09, $FA, $27, $30, $75, $1D, $58, $D5, $88, $30, $7D, $3B, $3C, $03, $66, $6F, $EB, $AA, $7E, $DC, $1C, $31, $35, $4E, $97, $E6, $09
	dc.b	$4A, $44, $84, $08, $10, $23, $47, $ED, $D6, $3A, $42, $F4, $6A, $8D, $98, $DB, $47, $C5, $7A, $9A, $BC, $03, $06, $31, $5E, $EB, $88, $C5, $7B, $C8, $C6, $23
	dc.b	$15, $FD, $AA, $9E, $86, $0E, $46, $DF, $F5, $18, $8E, $EB, $DF, $73, $06, $3B, $83, $18, $D5, $8A, $E2, $BD, $C1, $AF, $7A, $8F, $0F, $D1, $C1, $96, $99, $A9
	dc.b	$6E, $7B, $9B, $29, $02, $05, $B9, $48, $81, $4B, $F6, $78, $67, $A6, $25, $56, $20, $A5, $DC, $10, $30, $6A, $60, $8D, $7B, $82, $52, $C3, $10, $4B, $98, $21
	dc.b	$86, $23, $1C, $0C, $77, $97, $F1, $47, $70, $6A, $63, $BB, $62, $0C, $62, $3B, $AF, $70, $60, $C1, $8F, $E2, $AE, $20, $D4, $D4, $C6, $2A, $72, $FE, $35, $5F
	dc.b	$B1, $A8, $84, $12, $9F, $0E, $68, $0E, $FF, $DA, $D5, $88, $35, $35, $35, $30, $6A, $7C, $0E, $03, $CF, $38, $CD, $E0, $66, $B9, $84, $9A, $74, $E1, $4C, $1C
	dc.b	$B1, $5C, $54, $C6, $20, $F4, $EE, $B8, $CD, $27, $08, $1D, $06, $6A, $8F, $2C, $C2, $1F, $0F, $FA, $30, $6A, $63, $11, $8A, $9C, $BF, $6B, $B9, $DE, $63, $BD
	dc.b	$58, $B0, $C4, $1A, $98, $C4, $1A, $F7, $D3, $1B, $F1, $06, $CF, $FD, $69, $BA, $78, $F4, $9A, $98, $31, $FC, $5C, $F0, $18, $10, $FD, $88, $CC, $11, $EE, $75
	dc.b	$7F, $15, $4F, $A7, $A7, $84, $78, $E2, $7E, $9D, $F4, $30, $6B, $88, $3C, $31, $06, $0D, $7F, $46, $E4, $A5, $22, $96, $7A, $78, $29, $44, $D2, $2A, $89, $B1
	dc.b	$95, $F9, $DE, $43, $F6, $64, $33, $BC, $A4, $72, $9C, $78, $7F, $D9, $4E, $3C, $7E, $88, $A4, $40, $C1, $02, $06, $46, $A4, $A6, $B9, $E1, $2C, $01, $03, $91
	dc.b	$AF, $79, $63, $D7, $F4, $5F, $B7, $8F, $E3, $8C, $46, $2A, $60, $C7, $F1, $57, $BA, $9A, $98, $C6, $A3, $1F, $B5, $97, $70, $FF, $A2, $FE, $BC, $74, $8E, $86
	dc.b	$0D, $4F, $4C, $41, $AF, $ED, $47, $7B, $CC, $63, $79, $DE, $93, $F4, $EA, $9F, $B3, $8E, $98, $10, $CC, $1C, $89, $49, $70, $1F, $B1, $91, $29, $C8, $E4, $6B
	dc.b	$87, $70, $60, $F0, $EB, $09, $3E, $3F, $6F, $FB, $39, $1C, $8A, $F2, $91, $EF, $8A, $FE, $52, $47, $79, $C8, $C7, $1F, $C3, $7E, $3F, $66, $8F, $F9, $40, $4A
	dc.b	$6C, $30, $52, $91, $DA, $9F, $DF, $66, $66, $66, $66, $66, $66, $66, $BF, $9B, $E7, $5C, $EA, $9D, $F1, $9D, $58, $22, $96, $43, $95, $C8, $6B, $31, $70, $B8
	dc.b	$72, $10, $61, $70, $24, $09, $22, $7C, $DD, $79, $A6, $BF, $AA, $9C, $79, $D4, $55, $DF, $58, $98, $F3, $5F, $D9, $AD, $25, $31, $E0, $52, $F9, $84, $DE, $EF
	dc.b	$EE, $D1, $99, $9A, $9A, $EE, $FA, $E9, $E3, $0D, $3F, $5B, $86, $D6, $FC, $C4, $B0, $E7, $2B, $DD, $63, $47, $E6, $2F, $7E, $77, $76, $6B, $6B, $FA, $DF, $CD
	dc.b	$E4, $26, $5D, $33, $40, $49, $53, $CC, $B4, $72, $F1, $9F, $81, $C8, $9E, $7E, $03, $E8, $4B, $AC, $A6, $BE, $C5, $95, $B5, $FC, $D8, $71, $6C, $A8, $EB, $35
	dc.b	$98, $FC, $C8, $85, $9A, $BF, $0D, $23, $89, $BA, $A6, $68, $1E, $4E, $A9, $76, $5F, $AB, $F5, $B9, $9F, $7D, $68, $D7, $F8, $FC, $DD, $34, $43, $14, $A9, $3C
	dc.b	$0C, $7D, $AB, $37, $3D, $79, $57, $E6, $26, $91, $27, $D8, $A2, $FD, $76, $6A, $F7, $C1, $9A, $DE, $D5, $FA, $D7, $94, $2E, $12, $48, $37, $95, $A7, $14, $FD
	dc.b	$12, $D3, $9A, $42, $C5, $04, $D6, $28, $28, $30, $AE, $05, $2A, $C3, $65, $A2, $FB, $5D, $E2, $EE, $67, $22, $58, $AD, $D1, $D5, $06, $15, $BA, $E6, $1C, $71
	dc.b	$5C, $08, $4A, $A8, $26, $F2, $A0, $EC, $42, $2F, $9E, $D6, $D9, $3F, $31, $62, $E4, $E7, $56, $B1, $44, $F1, $8C, $A9, $9A, $F0, $BF, $9F, $FC, $C4, $C3, $D4
	dc.b	$83, $24, $23, $42, $11, $53, $87, $B2, $7A, $ED, $FA, $C6, $6F, $17, $F9, $DD, $4D, $4E, $99, $4A, $7B, $3C, $C7, $05, $F9, $4D, $42, $2A, $65, $24, $FC, $DD
	dc.b	$78, $1D, $DE, $CC, $C0, $F2, $8A, $17, $6C, $A8, $35, $7D, $AD, $70, $45, $ED, $3C, $10, $24, $C9, $03, $A2, $CD, $C3, $8F, $6F, $CD, $FB, $57, $66, $94, $55
	dc.b	$1C, $8E, $98, $2D, $B5, $E9, $17, $73, $85, $01, $82, $B8, $AD, $5D, $B1, $98, $F5, $19, $F2, $50, $B6, $C9, $36, $E3, $F2, $8D, $BE, $1A, $7E, $50, $7E, $93
	dc.b	$B0, $9C, $70, $41, $23, $3E, $23, $09, $E6, $22, $79, $D4, $8F, $1F, $C7, $FC, $A2, $61, $A5, $C1, $22, $AB, $90, $D0, $E0, $40, $48, $74, $73, $24, $5E, $03
	dc.b	$8E, $2E, $FD, $C5, $3F, $3F, $39, $3E, $BF, $9B, $FE, $6B, $33, $51, $BD, $B4, $2A, $6A, $65, $2C, $1C, $85, $0D, $6E, $C3, $1E, $4D, $99, $99, $9A, $FB, $37
	dc.b	$A5, $56, $4A, $F7, $B2, $33, $33, $37, $16, $D9, $3D, $76, $94, $51, $62, $BA, $08, $AA, $DB, $40, $80, $92, $D8, $66, $95, $6D, $E3, $B5, $5F, $98, $6D, $87
	dc.b	$AA, $57, $B2, $57, $00, $82, $45, $11, $5C, $56, $B0, $21, $2B, $58, $A5, $72, $A4, $4B, $B0, $8A, $45, $6B, $D9, $68, $29, $D8, $45, $17, $F4, $54, $D6, $D9
	dc.b	$74, $68, $59, $E5, $A5, $62, $E5, $28, $A9, $D1, $C7, $69, $E4, $B5, $C8, $C3, $89, $F6, $D4, $4C, $25, $C6, $5B, $16, $BC, $9B, $88, $47, $2E, $9C, $BA, $65
	dc.b	$59, $0B, $6D, $5D, $9E, $B4, $AC, $86, $51, $62, $4B, $2F, $39, $61, $B5, $A0, $58, $1F, $25, $3A, $F2, $AC, $AB, $BB, $9F, $34, $B6, $BB, $61, $95, $73, $4D
	dc.b	$9C, $14, $E0, $60, $2B, $83, $C0, $AB, $5C, $2D, $5E, $46, $E3, $D2, $BD, $66, $B3, $E2, $C8, $BC, $DD, $D2, $E9, $38, $B8, $4E, $59, $CE, $9D, $09, $FC, $C1
	dc.b	$75, $42, $72, $54, $04, $83, $6D, $76, $F3, $E6, $7C, $17, $A0, $BA, $9A, $17, $0C, $95, $3A, $0D, $79, $FD, $76, $BB, $53, $36, $6B, $F6, $FE, $1A, $04, $FE
	dc.b	$6A, $6B, $7C, $F9, $BE, $B4, $FD, $76, $DE, $99, $49, $20, $5D, $CD, $56, $8A, $E4, $8B, $6C, $2B, $1C, $4A, $B7, $09, $24, $2D, $AA, $42, $72, $42, $09, $9F
	dc.b	$AD, $D5, $E5, $75, $AE, $E8, $D3, $DD, $27, $79, $3D, $B4, $DB, $97, $BA, $A7, $CD, $EE, $97, $39, $6D, $71, $4B, $07, $C1, $EC, $CC, $CC, $C3, $CF, $4A, $69
	dc.b	$95, $07, $89, $65, $E7, $EC, $CD, $7E, $DB, $C2, $1C, $FB, $EA, $2B, $7C, $AE, $DA, $E9, $AD, $72, $9A, $C7, $EB, $BD, $BD, $76, $66, $D3, $F5, $49, $FB, $88
	dc.b	$5A, $E0, $AB, $28, $95, $D5, $F1, $39, $24, $CE, $E1, $C5, $9D, $1E, $98, $7E, $71, $7D, $4A, $F4, $0F, $58, $F5, $8C, $27, $0F, $90, $FD, $96, $07, $CA, $60
	dc.b	$11, $CA, $7C, $84, $72, $A9, $08, $25, $56, $BB, $2B, $BF, $7A, $CD, $FB, $EF, $D5, $8F, $D6, $03, $43, $BB, $F5, $FE, $04, $CF, $79, $EE, $9F, $ED, $B9, $99
	dc.b	$B5, $E3, $4B, $A7, $B7, $9C, $B9, $17, $09, $D1, $52, $E7, $CB, $91, $95, $26, $96, $BA, $C9, $76, $1F, $98, $E6, $A8, $57, $AD, $7C, $E5, $86, $D0, $29, $A5
	dc.b	$9B, $F3, $0C, $DF, $98, $2D, $6B, $BB, $2C, $20, $87, $53, $21, $94, $CD, $C4, $7B, $1C, $C2, $07, $F0, $6A, $92, $C0, $1D, $48, $30, $20, $FA, $1A, $BA, $9F
	dc.b	$2F, $B7, $38, $6D, $AA, $C2, $0B, $83, $C5, $C2, $D9, $D9, $2D, $AE, $C9, $CE, $57, $58, $20, $32, $3D, $60, $20, $24, $92, $0F, $E0, $C8, $94, $97, $0A, $0C
	dc.b	$E7, $75, $AB, $25, $9D, $C2, $65, $5A, $D6, $91, $76, $B3, $57, $AE, $C1, $24, $FE, $B5, $FE, $C6, $9F, $98, $A1, $54, $52, $FE, $0A, $EB, $B7, $EB, $A2, $D4
	dc.b	$11, $82, $61, $70, $75, $DA, $44, $0B, $6B, $08, $73, $71, $EA, $09, $EB, $4A, $6D, $85, $39, $19, $04, $F2, $7D, $69, $58, $72, $41, $99, $D3, $F3, $1F, $9F
	dc.b	$A2, $3E, $0F, $5A, $EA, $40, $A7, $AB, $88, $AC, $B5, $82, $BB, $23, $15, $D9, $22, $C6, $92, $7F, $29, $79, $64, $2B, $5F, $D7, $4D, $24, $41, $01, $FE, $89
	dc.b	$CA, $EC, $AE, $1A, $F3, $6A, $C8, $F6, $A1, $3D, $04, $F5, $AA, $83, $21, $5D, $44, $65, $44, $05, $04, $82, $89, $9D, $72, $AD, $4C, $5A, $77, $57, $3C, $B5
	dc.b	$C0, $A2, $D1, $45, $25, $4D, $B2, $91, $38, $E1, $4B, $74, $52, $09, $58, $4D, $DF, $17, $49, $5D, $F9, $9B, $AB, $B5, $6C, $CC, $CD, $1B, $BD, $F3, $79, $65
	dc.b	$FA, $EE, $57, $25, $9C, $A9, $C1, $B9, $CE, $8B, $ED, $47, $39, $99, $3E, $0F, $6A, $E6, $22, $61, $14, $DC, $A6, $6F, $84, $C2, $4C, $E6, $86, $0F, $A7, $EA
	dc.b	$6D, $CE, $88, $64, $FA, $DB, $F3, $39, $20, $A1, $60, $E9, $40, $9D, $9F, $04, $52, $49, $8D, $84, $22, $B9, $5A, $09, $05, $69, $7E, $14, $FC, $E6, $41, $08
	dc.b	$14, $F3, $54, $09, $5D, $20, $24, $D0, $B9, $AE, $61, $21, $03, $97, $04, $E8, $B3, $08, $AE, $97, $5B, $8F, $2E, $26, $12, $49, $B1, $FE, $A7, $65, $D5, $3C
	dc.b	$90, $A0, $16, $97, $5F, $83, $96, $99, $26, $88, $2B, $FC, $A0, $E0, $94, $A6, $F6, $9C, $0B, $4F, $3A, $F0, $E4, $7E, $D8, $3E, $5A, $20, $C9, $AA, $40, $ED
	dc.b	$15, $8E, $03, $A2, $A5, $95, $D6, $36, $C2, $ED, $A9, $CC, $92, $68, $08, $20, $FD, $B3, $AA, $68, $8F, $24, $93, $D4, $92, $CD, $D7, $82, $54, $70, $E3, $F7
	dc.b	$55, $DD, $5F, $E6, $F7, $3A, $5F, $E2, $93, $D3, $6B, $9F, $0A, $AE, $4B, $84, $E4, $74, $B2, $53, $21, $C0, $A7, $2B, $4B, $BD, $AE, $FD, $6D, $19, $99, $99
	dc.b	$B2, $DF, $25, $2F, $CD, $FB, $48, $81, $35, $E7, $09, $A5, $22, $77, $C6, $E5, $BC, $D7, $F5, $B5, $E4, $87, $51, $02, $DD, $37, $7A, $8A, $49, $7F, $49, $12
	dc.b	$A0, $BA, $F7, $CB, $42, $E9, $A7, $90, $20, $85, $D4, $87, $42, $4B, $DC, $3F, $01, $C3, $87, $93, $8C, $DC, $20, $40, $4B, $E4, $E1, $33, $A8, $9E, $59, $F4
	dc.b	$E0, $17, $03, $80, $96, $FD, $B0, $E2, $CA, $9B, $93, $E8, $E4, $3F, $62, $09, $3A, $7E, $AC, $91, $52, $44, $10, $25, $6A, $80, $93, $4B, $38, $41, $40, $9F
	dc.b	$9C, $E2, $B1, $58, $4B, $0A, $C5, $17, $88, $AA, $CB, $1C, $DD, $93, $D5, $80, $8C, $2B, $1D, $86, $DC, $2F, $64, $17, $6A, $81, $1E, $33, $9C, $B3, $EC, $48
	dc.b	$33, $73, $8B, $91, $F8, $B2, $0B, $8B, $04, $8E, $72, $D7, $01, $80, $79, $C2, $F9, $ED, $72, $A0, $AC, $15, $B0, $A9, $C6, $DC, $C2, $D9, $EE, $99, $88, $16
	dc.b	$7D, $86, $C2, $82, $CF, $02, $92, $39, $9E, $05, $76, $D7, $5F, $3B, $D2, $FC, $AE, $E2, $54, $13, $60, $52, $E6, $49, $28, $9A, $4C, $5B, $67, $17, $57, $6A
	dc.b	$2F, $24, $E5, $93, $AC, $1A, $53, $53, $58, $2E, $6D, $33, $81, $1E, $6E, $BE, $75, $D0, $A0, $AB, $5A, $08, $D8, $AB, $5A, $0C, $2E, $F3, $EC, $59, $73, $AF
	dc.b	$0A, $49, $24, $ED, $76, $98, $CF, $44, $AE, $F2, $B0, $9D, $4E, $9E, $2A, $F3, $BD, $35, $98, $45, $A2, $1E, $FE, $2A, $CB, $79, $89, $84, $D3, $99, $BD, $53
	dc.b	$13, $D2, $B9, $82, $49, $65, $AC, $6B, $1F, $99, $8A, $DE, $B7, $AF, $A5, $7F, $BD, $DB, $DA, $3F, $66, $9E, $2B, $66, $66, $FC, $CC, $7A, $FE, $67, $07, $2B
	dc.b	$78, $09, $32, $5F, $27, $1A, $D3, $F9, $F2, $24, $97, $A0, $74, $54, $54, $5F, $49, $27, $90, $4F, $EB, $A3, $92, $C4, $90, $BF, $44, $B0, $22, $50, $20, $42
	dc.b	$C0, $89, $47, $9A, $C4, $BF, $5C, $A4, $B0, $3F, $5C, $E8, $08, $E7, $95, $DC, $10, $40, $8A, $9D, $55, $02, $0E, $08, $CB, $74, $11, $80, $AE, $30, $4A, $BC
	dc.b	$DD, $21, $62, $82, $1F, $14, $DB, $8D, $6E, $59, $E5, $E7, $22, $5F, $19, $07, $4D, $32, $08, $C9, $51, $0E, $24, $5E, $85, $E8, $1F, $F5, $9F, $AB, $AF, $26
	dc.b	$6C, $9A, $EB, $DD, $2F, $71, $ED, $52, $2A, $65, $2B, $BD, $AE, $CA, $BB, $64, $DA, $3E, $FE, $9A, $64, $E5, $7B, $EF, $C5, $F9, $FE, $B6, $EA, $F2, $4A, $92
	dc.b	$F2, $52, $04, $EA, $41, $1D, $14, $94, $90, $23, $92, $97, $0E, $8F, $52, $10, $75, $E0, $91, $F3, $52, $72, $91, $38, $CF, $A1, $04, $54, $1C, $5C, $E0, $94
	dc.b	$93, $F3, $8E, $A8, $E1, $2C, $92, $41, $9A, $A0, $E3, $F3, $7E, $A4, $FC, $5D, $EB, $5E, $6B, $E4, $9F, $B1, $04, $83, $A9, $70, $5C, $2A, $68, $9F, $B7, $47
	dc.b	$52, $7C, $C1, $7E, $AA, $BF, $D5, $61, $FA, $CA, $4A, $3D, $22, $B1, $44, $04, $38, $AC, $12, $3F, $AE, $15, $D0, $96, $82, $8A, $4E, $87, $5D, $05, $01, $02
	dc.b	$4C, $2B, $C1, $30, $FD, $D5, $61, $CF, $2F, $CD, $CE, $27, $A8, $40, $85, $70, $29, $3D, $0F, $59, $AE, $7D, $2E, $B2, $95, $45, $57, $96, $9F, $D1, $AB, $39
	dc.b	$D3, $6D, $6C, $E9, $58, $C8, $AE, $9C, $6F, $0B, $E3, $63, $BF, $88, $E2, $48, $2D, $C2, $E6, $12, $4F, $E5, $D4, $5D, $5B, $A0, $43, $B5, $56, $CA, $91, $A1
	dc.b	$51, $6E, $5A, $E9, $DA, $55, $CC, $84, $4A, $B9, $88, $A6, $9C, $DF, $5A, $D3, $6F
	dc.b	$D6, $CE, $BC
	dc.b	$6A, $AD
	dc.b	$25
	dc.b	$5A, $C5
	dc.b	$51, $4B, $FF, $5D, $BD, $1E, $54, $69, $14, $BF, $76, $4C, $B3, $6A, $A6, $B5, $B5, $53, $65, $AD, $B9, $54, $94, $E4, $95, $4F, $7E, $5B, $79, $D4, $49, $57
	dc.b	$0E, $97, $A6, $9C, $36, $FC, $48, $97, $89, $13, $33, $34, $8B, $8D, $09, $1D, $53, $F6, $28, $A9, $FB, $17, $4A, $BC, $82, $7E, $C4, $17, $1E, $40, $9B, $C9
	dc.b	$3A, $1D, $D6, $57, $58, $F3, $F4, $94, $0E, $0B, $81, $1B, $39, $20, $4E, $C1, $2A, $8B, $2A, $3A, $55, $98, $E2, $CB, $65, $FC, $A2, $6D, $64, $F5, $FC, $C7
	dc.b	$9C, $69, $B0, $A5, $FC, $33, $33, $7F, $32, $DE, $D8, $7E, $D8, $67, $2E, $C1, $D6, $2B, $18, $70, $5F, $98, $A4, $F3, $A8, $87, $ED, $96, $01, $FA, $2F, $13
	dc.b	$1C, $65, $67, $21, $C5, $DE, $80, $82, $07, $FD, $B3, $8B, $89, $0B, $A1, $3A, $92, $54, $85, $24, $20, $84, $A8, $F7, $A0, $E1, $FF, $7B, $5D, $B3, $BD, $1D
	dc.b	$AF, $48, $D3, $24, $9E, $E8, $D5, $65, $2B, $57, $75, $69, $FA, $32, $0E, $43, $F5, $6E, $80, $97, $AA, $74, $D4, $7B, $20, $CD, $07, $E7, $15, $1F, $F3, $3C
	dc.b	$EA, $33, $5C, $DE, $F2, $13, $43, $7F, $CD, $E1, $71, $50, $CA, $BB, $61, $EB, $52, $67, $67, $27, $52, $16, $AC, $9F, $F6, $3C, $E1, $FC, $7F, $DB, $02, $7F
	dc.b	$E8, $84, $71, $FD, $BB, $65, $FC, $AF, $D6, $07, $57, $F4, $0E, $AF, $57, $40, $F5, $74, $08, $F2, $21, $9A, $10, $20, $40, $81, $03, $FD, $DB, $A1, $45, $16
	dc.b	$BE, $17, $CC, $57, $9A, $D7, $49, $13, $8A, $FC, $C1, $7A, $0F, $3A, $C2, $12, $49, $33, $09, $51, $20, $2F, $CD, $D8, $12, $10, $CC, $23, $8C, $FF, $8C, $BE
	dc.b	$8F, $98, $27, $CD, $73, $49, $66, $A9, $A7, $96, $85, $2C, $C3, $90, $C8, $79, $71, $95, $E4, $BF, $B1, $3B, $5F, $B4, $BF, $6D, $57, $1B, $97, $15, $57, $97
	dc.b	$E7, $19, $99, $99, $BF, $FF, $57, $FF, $D9, $96, $99, $3C, $DF, $29, $61, $AD, $05, $BF, $3E, $1C, $58, $72, $A4, $1E, $C3, $99, $12, $4E, $C3, $F9, $F4, $C9
	dc.b	$D9, $9B, $2D, $ED, $D3, $42, $04, $C9, $52, $3F, $0C, $CD, $7A, $6E, $8C, $CC, $CC, $CC, $CD, $56, $5B, $C6, $9F, $9F, $AB, $A6, $DD, $87, $8C, $16, $CB, $F9
	dc.b	$43, $1F, $9F, $39, $8B, $73, $B2, $73, $4C, $B5, $9B, $E7, $AD, $D2, $CD, $66, $4D, $9A, $F9, $29, $02, $1F, $9C, $52, $04, $A7, $AF, $EC, $54, $C6, $A0, $96
	dc.b	$80, $86, $C4, $B3, $78, $05, $A9, $2E, $B3, $96, $6B, $AF, $EA, $09, $6D, $FD, $CC, $87, $EA, $71, $74, $C3, $5C, $07, $8B, $73, $D3, $08, $04, $30, $AC, $B5
	dc.b	$A7, $31, $A8, $B8, $24, $E3, $6D, $55, $26, $87, $6D, $82, $61, $3C, $36, $82, $A1, $89, $C0, $3C, $0D, $30, $B9, $01, $A0, $35, $A6, $C6, $42, $82, $62, $C6
	dc.b	$E9, $B1, $ED, $1A, $DD, $87, $15, $99, $09, $94, $D2, $B1, $32, $1F, $9B, $9A, $4F, $2E, $69, $EC, $97, $E4, $13, $A4, $A6, $23, $0B, $64, $F9, $29, $25, $2E
	dc.b	$16, $1C, $A4, $CE, $78, $12, $A1, $88, $05, $A9, $0C, $27, $91, $C8, $DC, $EC, $9D, $28, $CC, $CD, $F9, $F6, $FC, $FD, $45, $2E, $65, $4F, $DF, $8D, $79, $BD
	dc.b	$F7, $D7, $6D, $13, $9B, $C8, $46, $91, $91, $55, $97, $AD, $D5, $4E, $54, $E6, $9C, $90, $CC, $44, $F3, $04, $10, $D3, $AD, $DB, $02, $5C, $D7, $2F, $CE, $53
	dc.b	$31, $B4, $F6, $CA, $79, $57, $03, $58, $3F, $D5, $EB, $B5, $E4, $3F, $31, $1B, $41, $0D, $A5, $EB, $22, $B4, $C5, $90, $10, $31, $30, $60, $81, $8D, $97, $CA
	dc.b	$75, $67, $6F, $05, $A1, $8E, $6A, $A4, $6D, $5E, $BB, $5B, $65, $E6, $29, $95, $3F, $38, $78, $5C, $E7, $F9, $40, $4F, $13, $8C, $C1, $3A, $3F, $E6, $5E, $45
	dc.b	$5D, $39, $A2, $96, $55, $AC, $EA, $8A, $2E, $B5, $FA, $E1, $B3, $ED, $5B, $82, $AB, $02, $82, $94, $CA, $DB, $29, $02, $4F, $CA, $48, $85, $6D, $E6, $92, $21
	dc.b	$45, $25, $2D, $B2, $9F, $33, $DB, $39, $DC, $B3, $D6, $63, $C6, $D7, $4A, $26, $B3, $59, $C7, $EC, $FA, $2F, $8C, $0F, $B4, $A6, $52, $49, $A9, $AC, $4A, $70
	dc.b	$F8, $23, $E5, $2C, $D7, $9D, $62, $68, $3C, $AC, $3F, $29, $31, $FA, $38, $48, $10, $B3, $94, $E2, $76, $F1, $A6, $BB, $4E, $44, $A9, $FB, $EE, $7C, $DA, $9B
	dc.b	$CF, $2B, $ED, $3A, $69, $6D, $E6, $C5, $7D, $39, $F3, $E7, $2F, $CC, $4A, $6E, $5F, $94, $91, $61, $A3, $EF, $61, $76, $96, $95, $D7, $DC, $2E, $19, $58, $97
	dc.b	$5B, $B6, $31, $1B, $6B, $32, $FC, $A5, $BA, $2C, $EE, $17, $61, $CC, $58, $5D, $7C, $E5, $70, $B8, $5B, $4B, $84, $0F, $CD, $DF, $61, $AD, $AE, $11, $70, $B4
	dc.b	$C5, $B5, $D8, $4C, $5D, $3B, $81, $59, $6E, $99, $4C, $78, $5B, $AC, $27, $AD, $D6, $B8, $AC, $B1, $3D, $6E, $C0, $A4, $9B, $5C, $2E, $9C, $B1, $14, $CA, $97
	dc.b	$7B, $20, $C6, $E9, $64, $7F, $9F, $96, $73, $FC, $E6, $4A, $42, $83, $CD, $67, $02, $BC, $A9, $31, $3C, $5F, $5B, $0C, $26, $33, $5A, $73, $B5, $DF, $AA, $BA
	dc.b	$D5, $F9, $DB, $F3, $76, $FC, $FD, $17, $39, $4E, $A2, $CB, $C0, $42, $82, $A5, $74, $97, $8B, $39, $A6, $19, $C0, $CF, $B1, $76, $FC, $DF, $7B, $7E, $AF, $2C
	dc.b	$1E, $7F, $AF, $87, $13, $28, $94, $C1, $73, $E5, $E0, $16, $A7, $CC, $A6, $0A, $60, $F4, $2D, $66, $B3, $52, $5D, $A7, $E4, $FA, $CE, $35, $38, $D4, $AD, $3F
	dc.b	$31, $6D, $61, $4F, $F2, $9A, $8A, $2C, $0C, $32, $F5, $99, $4E, $55, $90, $CC, $40, $89, $10, $E0, $45, $53, $C8, $5C, $43, $C0, $DA, $C9, $CD, $27, $84, $EF
	dc.b	$7B, $F3, $BF, $36, $BC, $85, $34, $89, $DF, $90, $FD, $6D, $39, $AE, $5E, $04, $55, $AF, $16, $B8, $58, $F6, $E9, $B6, $B5, $D9, $25, $02, $71, $E4, $B3, $21
	dc.b	$9A, $C6, $93, $25, $ED, $A9, $5B, $5F, $55, $DB, $5F, $58, $2B, $A6, $35, $9C, $AD, $AE, $DF, $99, $2B, $14, $6B, $2B, $AD, $DA, $7F, $9F, $F5, $EC, $0C, $1A
	dc.b	$96, $06, $0E, $50, $3F, $37, $FB, $E3, $66, $0F, $B9, $6E, $8C, $CD, $BF, $EE, $65, $93, $FE, $89, $C1, $A4, $8E, $B4, $A2, $C1, $ED, $1B, $0A, $CE, $0D, $39
	dc.b	$34, $7A, $B8, $53, $8A, $B0, $4A, $6B, $70, $4C, $01, $7B, $6B, $C7, $E6, $5D, $2C, $39, $FC, $CF, $E6, $C5, $7C, $AE, $B7, $25, $CB, $F9, $45, $49, $23, $04
	dc.b	$65, $7A, $4E, $9B, $73, $97, $4F, $DA, $EB, $95, $77, $2A, $74, $95, $C1, $04, $2C, $26, $42, $8A, $E2, $C9, $70, $AC, $E8, $1E, $B7, $C1, $61, $5F, $3A, $C5
	dc.b	$78, $65, $49, $95, $7A, $DA, $EB, $38, $99, $94, $D1, $FF, $32, $F0, $83, $F3, $21, $F5, $A7, $E6, $C5, $67, $AB, $A9, $7E, $72, $35, $81, $F9, $4A, $C3, $83
	dc.b	$BC, $D7, $01, $84, $4D, $3F, $67, $AF, $2D, $B9, $6E, $4F, $A7, $E9, $19, $B4, $00
;Arcade_car_spec_tiles_b
Arcade_car_spec_tiles_b:
	dc.b	$00, $38, $80, $06, $28, $16, $2D, $25, $0A, $35, $0F, $46, $26, $56, $27, $66, $33, $74, $00, $83, $05, $11, $15, $0D, $26, $29, $36, $30, $46, $32, $58, $F3
	dc.b	$68, $EF, $76, $2E, $84, $04, $02, $16, $2C, $27, $76, $85, $04, $03, $16, $31, $27, $78, $86, $05, $15, $17, $75, $87, $07, $6A, $16, $34, $28, $F7, $88, $05
	dc.b	$10, $17, $6E, $27, $6F, $38, $EE, $48, $F2, $89, $04, $01, $15, $0B, $27, $74, $37, $72, $8A, $04, $04, $16, $36, $27, $6B, $8B, $05, $0E, $27, $7A, $8D, $05
	dc.b	$0C, $16, $38, $8E, $05, $12, $18, $F6, $8F, $06, $2F, $17, $73, $FF, $00, $07, $FA, $85, $1F, $BB, $EE, $77, $F5, $EB, $EF, $5D, $55, $D1, $D5, $F7, $EA, $00
	dc.b	$1E, $4E, $B7, $FD, $0E, $D1, $DE, $4E, $AF, $BE, $F7, $6A, $76, $A7, $68, $E0, $00, $00, $DD, $3E, $F9, $A9, $80, $00, $2A, $13, $C1, $D3, $41, $AA, $74, $29
	dc.b	$9D, $D1, $9D, $73, $C0, $A7, $80, $CF, $CE, $7D, $55, $9E, $FD, $53, $FB, $4E, $C1, $9D, $83, $98, $E6, $CC, $D8, $00, $00, $1F, $F7, $D1, $D0, $6C, $3D, $7F
	dc.b	$E3, $D6, $FB, $AE, $BA, $25, $1E, $CD, $2A, $6C, $69, $52, $64, $DF, $C6, $2D, $9E, $0A, $F9, $5F, $2C, $45, $39, $B3, $63, $1E, $07, $12, $31, $43, $16, $62
	dc.b	$38, $8B, $24, $CE, $84, $C1, $2F, $E2, $F1, $26, $27, $46, $20, $E2, $3A, $FF, $5D, $C2, $0D, $1C, $0E, $C2, $74, $30, $8F, $F6, $94, $48, $7F, $89, $68, $B3
	dc.b	$F6, $9E, $F5, $FC, $DD, $75, $75, $F7, $F5, $B9, $B0, $D3, $FB, $11, $74, $7F, $F1, $84, $1B, $0B, $AE, $C2, $CC, $BB, $37, $B1, $89, $B7, $15, $A0, $B5, $3F
	dc.b	$5B, $AC, $FF, $5B, $AC, $50, $75, $8A, $0A, $18, $A7, $24, $3F, $EC, $9A, $72, $34, $3E, $58, $A1, $18, $F8, $DA, $83, $EC, $7B, $51, $D8, $C5, $56, $78, $05
	dc.b	$53, $07, $D3, $07, $E0, $FC, $1F, $B9, $AF, $85, $2F, $C1, $F8, $3F, $25, $64, $AC, $95, $1B, $1A, $A3, $42, $38, $AB, $6C, $62, $AD, $86, $2F, $43, $6B, $CD
	dc.b	$A4, $FA, $66, $28, $CF, $10, $00, $00, $00, $00, $00, $09, $EB, $9E, $AC, $EB, $9D, $73, $74, $F5, $74, $DF, $9B, $82, $B2, $B7, $CE, $76, $E7, $1C, $E2, $00
	dc.b	$00, $00, $01, $36, $F5, $3B, $BA, $8F, $DD, $FE, $D9, $DE, $FD, $74, $FD, $33, $A1, $D7, $57, $AD, $5F, $B6, $D3, $F9, $7A, $9D, $FF, $8F, $F5, $F5, $FE, $5C
	dc.b	$1B, $E5, $75, $CD, $2B, $8C, $BC, $C4, $C9, $B7, $8C, $98, $BC, $6B, $7C, $98, $28, $BE, $7B, $71, $63, $16, $65, $89, $30, $BF, $19, $D9, $60, $01, $07, $6E
	dc.b	$F5, $47, $FE, $3D, $79, $7F, $5D, $AE, $AF, $E6, $F4, $6D, $77, $57, $46, $BB, $AE, $8E, $6E, $F8, $C2, $97, $6E, $A7, $77, $F6, $DB, $FF, $8B, $AE, $69, $AF
	dc.b	$22, $E8, $51, $32, $5A, $30, $48, $C7, $F5, $DC, $12, $33, $DB, $84, $31, $46, $7E, $E8, $4B, $A6, $CB, $B3, $92, $08, $00, $04, $33, $DF, $37, $73, $E3, $DC
	dc.b	$AC, $20, $AA, $77, $2A, $9D, $F6, $C1, $BB, $A3, $6C, $61, $85, $BE, $76, $F7, $D1, $DF, $47, $7D, $1D, $F4, $77, $D1, $4D, $8D, $A0, $8E, $C4, $6D, $02, $64
	dc.b	$87, $1B, $44, $96, $DB, $4C, $B0, $50, $90, $92, $CA, $84, $21, $FD, $60, $DA, $C5, $98, $A5, $B7, $B0, $C5, $19, $6D, $6F, $93, $16, $A1, $21, $B1, $E2, $4D
	dc.b	$9E, $C8, $97, $F2, $4C, $4B, $96, $2B, $31, $32, $35, $97, $82, $34, $FE, $22, $D2, $C8, $96, $2B, $8F, $ED, $0C, $68, $FE, $20, $DA, $65, $4A, $84, $9A, $F4
	dc.b	$26, $BD, $0A, $33, $21, $CE, $82, $00, $00, $00, $00, $13, $39, $FD, $C0, $00, $00, $1E, $4E, $AD, $1F, $E8, $A8, $67, $09, $B7, $BF, $B9, $F8, $28, $B0, $56
	dc.b	$4A, $C9, $59, $2B, $25, $64, $AC, $95, $92, $B2, $55, $36, $2A, $93, $27, $B7, $67, $D2, $2F, $C1, $F8, $4D, $4C, $D4, $CC, $D2, $9E, $25, $98, $80, $00, $00
	dc.b	$07, $FA, $23, $BF, $28, $79, $BA, $EB, $BB, $E1, $87, $73, $7F, $B0, $DD, $D7, $5D, $75, $25, $E6, $BF, $35, $96, $04, $29, $89, $34, $C5, $07, $6E, $88, $C9
	dc.b	$33, $5B, $35, $CB, $61, $D6, $BD, $97, $B0, $EB, $3E, $5C, $20, $E2, $28, $C9, $20, $99, $1A, $33, $58, $E2, $C9, $70, $8B, $26, $4B, $5A, $CA, $D6, $27, $2B
	dc.b	$57, $AC, $55, $FC, $99, $BA, $66, $21, $1D, $CE, $AE, $95, $85, $7F, $EF, $0A, $BB, $57, $5D, $2B, $FC, $78, $69, $F9, $B6, $C2, $2E, $FF, $C6, $E8, $F9, $47
	dc.b	$CA, $EB, $AE, $1B, $32, $5D, $98, $31, $76, $53, $C2, $48, $4E, $C6, $7E, $FB, $81, $E2, $4C, $FD, $77, $E3, $3F, $7A, $8C, $5A, $7E, $B5, $16, $69, $C2, $2C
	dc.b	$87, $F7, $43, $4F, $24, $E0, $4F, $97, $03, $D8, $D6, $C9, $76, $6F, $F5, $30, $FE, $A2, $E8, $5D, $8B, $B7, $F9, $2A, $E4, $8A, $E5, $09, $97, $15, $3B, $3D
	dc.b	$27, $D4, $E9, $F4, $74, $D0, $FC, $DC, $DB, $DC, $FD, $F7, $5D, $75, $DD, $F6, $79, $96, $14, $11, $95, $36, $97, $88, $A8, $76, $63, $D6, $8C, $BD, $45, $12
	dc.b	$39, $28, $6C, $3B, $D5, $D3, $F3, $8A, $B1, $6F, $16, $2D, $E2, $5B, $3F, $D9, $93, $0F, $E3, $2F, $9A, $C0, $00, $00, $00, $00, $00, $00, $9D, $B0, $9B, $07
	dc.b	$E0, $FA, $66, $88, $00, $00, $00, $00, $4D, $CD, $F7, $F5, $93, $EB, $7E, $2A, $BE, $B7, $99, $5B, $CC, $71, $1B, $6F, $90, $99, $1D, $1C, $E4, $76, $4A, $8F
	dc.b	$61, $32, $39, $51, $E2, $C3, $1B, $4B, $F6, $A2, $A3, $5C, $85, $E4, $6B, $98, $B1, $CC, $80, $00, $00, $00, $00, $02, $B9, $D6, $F9, $FF, $5F, $34, $B9, $C9
	dc.b	$F2, $E7, $27, $FB, $5F, $27, $8F, $B5, $E6, $A5, $FE, $B9, $46, $27, $2B, $D4, $7D, $39, $DB, $8A, $E5, $5B, $E8, $13, $E9, $7D, $BE, $16, $AF, $12, $98, $C6
	dc.b	$73, $00, $09, $C0
Round_sign_tile_table: ; 16 pointers to compressed round-sign tile data, indexed by Track_data sign tileset offset / 2
	dc.l	Round_sign_tiles_1
	dc.l	Round_sign_tiles_2
	dc.l	Round_sign_tiles_3
	dc.l	Round_sign_tiles_4
	dc.l	Round_sign_tiles_5
	dc.l	Round_sign_tiles_6
	dc.l	Round_sign_tiles_7
	dc.l	Round_sign_tiles_8
	dc.l	Round_sign_tiles_9
	dc.l	Round_sign_tiles_10
	dc.l	Round_sign_tiles_11
	dc.l	Round_sign_tiles_12
	dc.l	Round_sign_tiles_13
	dc.l	Round_sign_tiles_14
	dc.l	Round_sign_tiles_15
	dc.l	Round_sign_tiles_16
Round_sign_mapping_table: ; 16 pointers to compressed round-sign tilemap mapping data
	dc.l	Round_sign_mapping_1
	dc.l	Round_sign_mapping_2
	dc.l	Round_sign_mapping_3
	dc.l	Round_sign_mapping_4
	dc.l	Round_sign_mapping_5
	dc.l	Round_sign_mapping_6
	dc.l	Round_sign_mapping_7
	dc.l	Round_sign_mapping_8
	dc.l	Round_sign_mapping_9
	dc.l	Round_sign_mapping_10
	dc.l	Round_sign_mapping_11
	dc.l	Round_sign_mapping_12
	dc.l	Round_sign_mapping_13
	dc.l	Round_sign_mapping_14
	dc.l	Round_sign_mapping_15
	dc.l	Round_sign_mapping_16
Round_sign_tiles_1:
	dc.b	$07, $01, $00, $00, $00, $0A, $02, $00, $00, $30, $40, $01, $82, $00, $07, $60, $40, $00, $00, $50, $40, $00, $00, $A5, $84, $02, $90, $A9, $00, $98, $9C, $04
	dc.b	$12, $E0, $22, $98, $9C, $04, $12, $E0, $22, $98, $9C, $07, $92, $E2, $22, $14, $14, $00, $D1, $F9, $08, $85, $10, $83, $00, $50, $5E, $B6, $22, $02, $21, $44
	dc.b	$34, $20, $40, $19, $0A, $01, $88, $7C, $44, $42, $80, $E7, $78, $3E, $3C, $3E, $2A, $10, $04, $7F, $80, $00
Round_sign_tiles_2:
	dc.b	$06, $01, $00, $00, $00, $0D, $0E, $00, $00, $78, $83, $00, $0F, $10, $60, $00, $E4, $00, $18, $00, $60, $03, $02, $58, $B0, $5B, $01, $CC, $23, $89, $47, $08
	dc.b	$E8, $03, $C8, $47, $08, $E8, $03, $C6, $A2, $81, $1C, $23, $83, $81, $AC, $0E, $25, $6A, $84, $86, $11, $CD, $E1, $1C, $DC, $01, $DF, $C0
Round_sign_tiles_3:
	dc.b	$06, $02, $00, $00, $00, $0A, $0E, $00, $00, $78, $83, $00, $0F, $80, $60, $22, $45, $06, $02, $0C, $20, $60, $4B, $10, $0B, $60, $39, $84, $59, $48, $61, $16
	dc.b	$52, $18, $45, $80, $80, $10, $09, $8C, $86, $11, $60, $21, $00, $68, $30, $15, $88, $86, $11, $6D, $E1, $16, $DC, $01, $7F, $C0
Round_sign_tiles_4:
	dc.b	$06, $01, $00, $00, $00, $0D, $0E, $00, $00, $78, $83, $00, $0F, $10, $60, $01, $E4, $0C, $00, $00, $20, $03, $02, $58, $B0, $5B, $01, $CC, $23, $81, $81, $3C
	dc.b	$8C, $23, $80, $E2, $42, $79, $18, $47, $40, $1E, $4A, $18, $47, $14, $86, $11, $CD, $E1, $1C, $DC, $01, $DF, $C0, $00
Round_sign_tiles_5:
	dc.b	$07, $01, $00, $00, $00, $0D, $0E, $00, $00, $1C, $80, $00, $C0, $01, $E2, $06, $00, $0F, $10, $30, $00, $60, $01, $81, $2C, $2C, $14, $08, $44, $04, $47, $4B
	dc.b	$80, $BA, $41, $20, $0F, $01, $F4, $B8, $0B, $A4, $14, $01, $20, $78, $12, $A5, $00, $5C, $BE, $36, $A2, $E1, $40, $1C, $1F, $8E, $00, $B8, $48, $0D, $C8, $DA
	dc.b	$D8, $5C, $28, $05, $A1, $72, $CF, $18, $CF, $07, $8E, $90, $BF, $F0
Round_sign_tiles_6:
	dc.b	$06, $03, $00, $00, $00, $0B, $0E, $00, $00, $3C, $40, $C0, $01, $E4, $06, $01, $08, $07, $40, $30, $08, $18, $20, $30, $25, $84, $82, $D8, $0E, $61, $0C, $02
	dc.b	$02, $68, $08, $04, $80, $28, $E1, $0C, $E8, $1A, $9A, $1C, $17, $1E, $0A, $00, $A3, $84, $30, $BC, $21, $90, $38, $C2, $80, $CA, $36, $10, $C6, $F0, $86, $37
	dc.b	$00, $33, $F8, $00
Round_sign_tiles_7:
	dc.b	$06, $00, $00, $00, $00, $0E, $0E, $00, $00, $F1, $0C, $00, $78, $86, $00, $3C, $43, $00, $18, $01, $81, $2C, $C0, $5B, $01, $CC, $27, $94, $86, $13, $C4, $80
	dc.b	$A8, $B8, $4F, $2B, $93, $C7, $9C, $57, $1D, $4F, $73, $09, $ED, $C0, $3F, $F8
Round_sign_tiles_8:
	dc.b	$07, $03, $00, $00, $00, $0A, $0E, $00, $00, $1E, $20, $30, $00, $3E, $00, $60, $08, $24, $14, $06, $00, $80, $C0, $80, $60, $4B, $04, $02, $80, $D0, $12, $00
	dc.b	$A0, $02, $24, $23, $C0, $28, $88, $50, $13, $A1, $F0, $0E, $A3, $C4, $28, $0A, $2F, $88, $50, $14, $5F, $10, $A0, $28, $3E, $29, $55, $E0, $50, $07, $80, $72
	dc.b	$1E, $05, $01, $42, $40, $5E, $09, $C8, $78, $14, $05, $07, $00, $6E, $24, $06, $98, $10, $02, $9F, $C0, $00
Round_sign_tiles_9:
	dc.b	$06, $03, $00, $00, $00, $0B, $0E, $00, $00, $3C, $40, $C0, $01, $E2, $06, $00, $07, $58, $50, $30, $08, $18, $20, $30, $25, $84, $82, $D8, $0E, $61, $0C, $15
	dc.b	$00, $10, $0B, $08, $60, $34, $45, $C2, $E2, $26, $16, $0A, $18, $43, $01, $A2, $2E, $32, $18, $43, $01, $80, $AC, $0A, $00, $C0, $2C, $03, $93, $38, $58, $63
	dc.b	$98, $43, $1B, $80, $19, $FC
Round_sign_tiles_10:
	dc.b	$06, $03, $00, $00, $00, $0E, $22, $00, $28, $14, $41, $F9, $02, $C3, $03, $83, $46, $08, $09, $61, $80, $B6, $03, $90, $03, $CC, $A2, $1E, $04, $05, $70, $79
	dc.b	$08, $0D, $8B, $87, $CC, $70, $3C, $40, $38, $28, $02, $00, $40, $64, $0F, $88, $E0, $78, $08, $05, $00, $B0, $08, $0D, $A2, $61, $0F, $6F, $08, $7B, $70, $03
	dc.b	$FF, $80
Round_sign_tiles_11:
	dc.b	$06, $02, $00, $00, $00, $10, $22, $00, $50, $28, $87, $E4, $14, $48, $71, $25, $8E, $05, $B0, $1C, $C2, $44, $BC, $24, $42, $A3, $54, $5E, $47, $48, $90, $0A
	dc.b	$02, $41, $B9, $1D, $22, $40, $48, $0D, $03, $80, $D8, $0C, $24, $5B, $C2, $45, $B8, $04, $7F, $80
Round_sign_tiles_12:
	dc.b	$06, $01, $00, $00, $00, $15, $2E, $00, $81, $E5, $93, $05, $B0, $1C, $C2, $58, $98, $17, $C0, $C2, $5A, $01, $70, $20, $19, $1B, $0E, $7C, $25, $B9, $97, $AE
	dc.b	$66, $B8, $B0, $37, $01, $84, $B0, $10, $38, $8F, $CB, $C1, $52, $CE, $61, $2C, $DC, $02, $DF, $C0
Round_sign_tiles_13:
	dc.b	$06, $03, $00, $00, $00, $10, $2F, $98, $44, $2C, $30, $38, $34, $60, $80, $96, $1C, $0B, $60, $39, $84, $45, $02, $78, $AD, $08, $A3, $00, $48, $2A, $32, $C0
	dc.b	$C0, $1A, $03, $8A, $D0, $89, $7C, $96, $84, $44, $02, $81, $26, $14, $03, $20, $B8, $BA, $08, $B9, $84, $45, $B8, $02, $3F, $C0
Round_sign_tiles_14:
	dc.b	$06, $03, $00, $00, $00, $12, $2A, $88, $38, $9C, $70, $60, $C0, $96, $20, $0B, $60, $39, $84, $4C, $AE, $43, $82, $62, $41, $40, $17, $0E, $88, $E0, $1C, $87
	dc.b	$04, $C4, $81, $E2, $C4, $2E, $14, $02, $50, $3A, $14, $31, $0E, $09, $89, $03, $00, $B4, $58, $05, $C0, $E1, $13, $6F, $08, $9B, $70, $04, $FF, $80
Round_sign_tiles_15:
	dc.b	$06, $01, $00, $00, $00, $15, $2E, $00, $81, $E5, $93, $05, $B0, $1C, $80, $58, $58, $07, $04, $E2, $78, $B0, $30, $0C, $8C, $87, $1B, $EA, $45, $82, $98, $24
	dc.b	$28, $B1, $16, $0B, $61, $20, $3B, $01, $CC, $25, $9B, $80, $5B, $F8
Round_sign_tiles_16:
	dc.b	$06, $03, $00, $00, $00, $11, $22, $00, $28, $3C, $42, $01, $43, $A3, $04, $04, $B0, $F0, $5B, $01, $CC, $22, $41, $40, $55, $16, $02, $D0, $18, $44, $82, $80
	dc.b	$3E, $04, $01, $71, $70, $89, $71, $1F, $57, $02, $03, $38, $F8, $44, $82, $C2, $E4, $27, $27, $61, $11, $27, $30, $89, $37, $00, $4B, $F8
Round_sign_mapping_1:
	dc.b	$80, $43, $80, $05, $1B, $14, $0A, $25, $18, $35, $19, $45, $1C, $55, $1D, $66, $3D, $71, $00, $88, $08, $F8, $8C, $03, $04, $14, $0B, $25, $1A, $36, $3C, $FF
	dc.b	$FF, $88, $00, $E7, $EA, $33, $F1, $CF, $CC, $3B, $FB, $8F, $CF, $0F, $81, $EF, $C6, $FF, $71, $F9, $E5, $7E, $60, $19, $F8, $C7, $E6, $3F, $3C, $03, $E3, $1F
	dc.b	$98, $FC, $F0, $0A, $FC, $C0, $EF, $F6, $07, $EA, $31, $F9, $61, $FA, $80, $C7, $E5, $87, $FD, $C7, $F5, $FF, $22, $3F, $6E, $1F, $97, $FC, $88, $0A, $FE, $E6
	dc.b	$E7, $63, $37, $C9, $50, $55, $F6, $20, $33, $AD, $DE, $66, $21, $53, $90, $6F, $C0, $06, $20, $84, $ED, $D6, $80, $4C, $7E, $5F, $F2, $20, $3C, $FC, $BF, $E4
	dc.b	$73, $31, $33, $12, $A7, $25, $44, $4C, $79, $BF, $F6, $0C, $5A, $23, $CE, $43, $B3, $70, $62, $EA, $0C, $40, $84, $21, $99, $D9, $BF, $13, $7E, $62, $06, $65
	dc.b	$4C, $5E, $E6, $60, $DC, $19, $BD, $DB, $1F, $CC, $2B, $FD, $86, $EE, $B4, $31, $07, $25, $4E, $41, $08, $CF, $98, $88, $FE, $E0, $79, $BD, $62, $76, $72, $F1
	dc.b	$A0, $87, $B0, $3D, $F3, $7A, $3C, $DE, $82, $67, $5C, $8A, $9C, $B0, $ED, $80, $BC, $DD, $4C, $C6, $25, $47, $2C, $EF, $80, $3C, $DE, $8E, $40, $AF, $FE, $76
	dc.b	$D5, $A4, $15, $78, $8A, $8C, $DD, $40, $D1, $DB, $0E, $47, $B0, $42, $76, $EA, $7B, $3B, $1D, $82, $A5, $7F, $73, $36, $95, $7C, $95, $06, $26, $74, $20, $4D
	dc.b	$F8, $CC, $A8, $E5, $8C, $D8, $62, $0D, $EA, $A0, $A8, $03, $13, $3A, $37, $75, $75, $79, $D1, $51, $D8, $7B, $A0, $0B, $21, $0C, $C4, $01, $D9, $B8, $3D, $83
	dc.b	$93, $70, $72, $0E, $DE, $E0, $0C, $4C, $58, $0A, $BD, $EB, $90, $42, $3B, $60, $76, $62, $EA, $01, $89, $53, $32, $BC, $02, $39, $67, $6C, $35, $5A, $72, $56
	dc.b	$B1, $61, $78, $D1, $78, $D0, $7F, $32, $A1, $FC, $CA, $81, $AC, $CF, $63, $41, $CD, $62, $FB, $1E, $07, $3F, $F9, $ED, $E6, $EB, $C0, $C0
Round_sign_mapping_2:
	dc.b	$80, $31, $80, $05, $18, $15, $17, $24, $0A, $35, $1A, $46, $3C, $55, $16, $66, $3A, $71, $00, $81, $18, $FA, $88, $05, $19, $17, $7A, $58, $F8, $8C, $03, $04
	dc.b	$15, $1B, $26, $3B, $35, $1C, $47, $7B, $78, $F9, $FF, $FF, $88, $00, $D7, $EE, $2F, $EB, $CC, $BA, $FF, $40, $F4, $F4, $CA, $BF, $91, $8F, $CB, $00, $F8, $FC
	dc.b	$B7, $99, $17, $FE, $41, $5F, $17, $C8, $0F, $E4, $18, $CD, $B3, $6C, $DB, $36, $CD, $B3, $6C, $EB, $F5, $0D, $65, $6C, $DB, $36, $CD, $B3, $6F, $FC, $75, $EB
	dc.b	$CC, $DB, $21, $D7, $EA, $07, $FE, $07, $C0, $BF, $C0, $0B, $FF, $DC, $7F, $5F, $E8, $7E, $DC, $3F, $2F, $F4, $03, $5F, $97, $FA, $01, $AF, $C3, $FE, $2F, $F3
	dc.b	$A0, $3E, $7C, $DA, $63, $B4, $15, $2F, $B1, $7D, $87, $F7, $35, $B4, $BE, $D2, $A0, $D7, $BB, $42, $D0, $5F, $75, $DD, $E0, $83, $5B, $BF, $0B, $FF, $70, $3F
	dc.b	$B8, $5F, $7D, $4A, $85, $E5, $4A, $95, $C3, $1B, $D4, $09, $79, $50, $81, $D4, $A8, $75, $35, $DA, $A7, $53, $1D, $F5, $2A, $11, $68, $75, $05, $E5, $4C, $6D
	dc.b	$52, $D2, $A5, $4D, $77, $8E, $C5, $4A, $83, $BB, $EF, $10, $4A, $83, $5C, $62, $16, $85, $A5, $F9, $8E, $EA, $16, $85, $A5, $A5, $F8, $03, $52, $A0, $09, $50
	dc.b	$0E, $A5, $A5, $40, $23, $12, $A0, $03, $AD, $B1, $15, $D9, $8D, $DF, $6C, $76, $6B, $D8, $8E, $A2, $D2, $A1, $79, $53, $13, $1C, $5E, $01, $AE, $CF, $3B, $0F
	dc.b	$9E, $A7, $9B, $C7, $B0, $B7, $0D, $70, $2B, $DA, $A3, $81, $E7, $0D, $70, $31, $FE, $C3, $1F, $EC, $09, $5C, $25, $70, $3E, $4F, $90, $00
Round_sign_mapping_3:
	dc.b	$80, $33, $80, $05, $19, $15, $17, $25, $18, $35, $16, $46, $3A, $55, $1C, $66, $3C, $71, $00, $81, $18, $FA, $88, $06, $3B, $47, $7B, $8C, $03, $04, $14, $0A
	dc.b	$25, $1A, $35, $1B, $47, $7A, $58, $F8, $78, $F9, $FF, $FF, $88, $00, $B7, $EE, $2F, $F9, $8E, $BB, $79, $FE, $81, $F9, $87, $E6, $1D, $B1, $EF, $3F, $96, $01
	dc.b	$FD, $8F, $CB, $75, $D8, $BF, $B3, $1F, $D8, $BF, $60, $3D, $F3, $F7, $02, $DF, $B8, $3D, $BC, $ED, $E7, $6C, $77, $6E, $D8, $F6, $2F, $FF, $71, $FD, $7F, $A1
	dc.b	$FB, $70, $FC, $BF, $D0, $0B, $7E, $5F, $E8, $05, $EB, $F3, $7F, $9D, $39, $41, $47, $3E, $02, $FF, $24, $B6, $83, $D5, $A9, $16, $98, $82, $DF, $EC, $B4, $39
	dc.b	$07, $9F, $02, $04, $20, $84, $E5, $06, $60, $D6, $77, $9A, $B5, $31, $5D, $4B, $C1, $9D, $5E, $B3, $10, $81, $45, $BF, $D8, $13, $3B, $14, $72, $97, $D9, $7F
	dc.b	$46, $3D, $2D, $B0, $D1, $D5, $21, $31, $1C, $9D, $57, $2B, $AA, $CF, $AE, $42, $F3, $13, $30, $4B, $D0, $E4, $0A, $21, $0B, $45, $00, $B4, $31, $01, $D6, $9A
	dc.b	$07, $52, $DA, $19, $F8, $2F, $F1, $99, $9D, $80, $C4, $C4, $01, $79, $88, $F3, $66, $3D, $12, $F4, $C4, $2D, $2F, $47, $2A, $F3, $35, $D4, $10, $8F, $20, $1E
	dc.b	$4C, $46, $20, $31, $2F, $33, $BC, $CB, $E8, $1E, $4E, $4C, $68, $04, $CE, $CB, $6C, $2F, $EA, $F1, $1B, $BC, $0D, $1D, $68, $3A, $D9, $6D, $85, $B7, $68, $68
	dc.b	$2D, $F3, $15, $69, $8D, $86, $6B, $1A, $CC, $E4, $5B, $41, $F2, $7C, $80, $00
Round_sign_mapping_4:
	dc.b	$80, $39, $80, $04, $0A, $15, $19, $24, $0B, $35, $1C, $46, $3C, $56, $3A, $66, $3D, $71, $00, $81, $18, $FA, $88, $06, $3B, $17, $7C, $8C, $03, $04, $15, $18
	dc.b	$25, $1A, $35, $1B, $FF, $FF, $88, $00, $F7, $B7, $5D, $BD, $F8, $3F, $B0, $33, $FD, $8F, $CB, $00, $EB, $F3, $DE, $76, $75, $D9, $D7, $7C, $FD, $45, $FC, $03
	dc.b	$B7, $CB, $F8, $CF, $7C, $EC, $AE, $F9, $D8, $01, $5D, $F3, $B3, $DF, $D4, $0F, $FC, $57, $F2, $0C, $F7, $E7, $C1, $DF, $9F, $02, $BF, $90, $03, $3F, $F7, $1F
	dc.b	$D7, $FA, $1F, $B7, $0F, $CB, $FD, $00, $E7, $E5, $FE, $80, $6F, $F2, $FF, $81, $FC, $68, $0B, $95, $80, $15, $8A, $FE, $63, $C8, $21, $99, $78, $08, $2B, $19
	dc.b	$95, $2B, $17, $A5, $CE, $A5, $41, $9D, $5E, $10, $8F, $21, $2A, $73, $19, $81, $0B, $C5, $E8, $EB, $01, $2B, $FB, $95, $84, $66, $54, $B8, $66, $25, $68, $F2
	dc.b	$72, $17, $33, $1E, $E0, $B8, $75, $1E, $E2, $E0, $E6, $8F, $35, $58, $CE, $FD, $80, $54, $BC, $15, $01, $9C, $54, $1E, $E1, $CD, $B3, $2B, $5E, $C2, $B0, $B9
	dc.b	$9C, $1F, $DC, $F2, $0B, $C5, $C2, $A5, $4B, $83, $DC, $1D, $4C, $CB, $95, $0E, $4B, $8C, $CE, $A7, $B1, $33, $AB, $C1, $70, $4E, $6A, $B7, $98, $75, $07, $BA
	dc.b	$CE, $80, $F2, $5E, $2B, $00, $5C, $A9, $7B, $BC, $3D, $80, $C5, $CA, $80, $8E, $B1, $99, $5A, $E6, $01, $E4, $A9, $CC, $20, $75, $2E, $2A, $75, $33, $2E, $36
	dc.b	$73, $F9, $8F, $35, $58, $08, $26, $70, $03, $3A, $AD, $00, $AD, $56, $CD, $DC, $0D, $5E, $3A, $8D, $87, $9F, $EC, $F6, $54, $BC, $5E, $83, $AD, $9C, $D8, $5E
	dc.b	$F9, $0D, $05, $FF, $F2, $31, $73, $9A, $A8, $18, $AD, $95, $8A, $D8, $75, $A3, $CD, $04, $AD, $99, $95, $B0, $CF, $F3, $17, $1B, $0E, $B6, $73, $61, $40, $00
Round_sign_mapping_5:
	dc.b	$80, $53, $80, $05, $19, $15, $16, $25, $17, $35, $18, $45, $1A, $55, $1C, $66, $3B, $71, $00, $88, $06, $3C, $17, $7B, $48, $F8, $8C, $03, $04, $14, $0A, $25
	dc.b	$1B, $36, $3A, $47, $7A, $58, $F9, $FF, $FF, $88, $00, $FF, $C0, $FF, $C0, $F8, $17, $F8, $CF, $E5, $80, $7C, $67, $F2, $C0, $39, $EF, $5E, $0E, $FF, $F0, $BF
	dc.b	$B7, $B7, $87, $8B, $78, $7C, $0B, $7C, $0F, $2D, $E0, $1D, $F9, $DF, $9A, $F6, $CF, $8F, $6F, $DC, $0F, $87, $7E, $6B, $DE, $3D, $80, $E7, $FD, $C7, $F5, $FF
	dc.b	$22, $3F, $6E, $1F, $97, $FC, $88, $0E, $50, $72, $19, $AC, $41, $78, $B4, $2F, $41, $99, $88, $77, $33, $05, $E2, $1D, $EE, $F0, $CF, $C8, $63, $E7, $33, $91
	dc.b	$8A, $D4, $B4, $16, $AC, $EE, $D1, $19, $D8, $63, $A2, $B1, $41, $59, $D9, $6D, $83, $3F, $97, $FC, $88, $0C, $7E, $5F, $F0, $3F, $8D, $3B, $81, $BB, $6E, $F0
	dc.b	$21, $69, $6A, $BC, $BC, $2F, $16, $86, $B6, $18, $87, $72, $FD, $0C, $FA, $2F, $EA, $FD, $25, $E6, $22, $5A, $6A, $5A, $22, $5F, $AC, $FF, $B0, $62, $22, $6A
	dc.b	$B3, $B0, $17, $98, $83, $B9, $68, $72, $87, $23, $10, $BD, $5A, $80, $63, $79, $9C, $99, $EA, $F0, $31, $2D, $2F, $56, $97, $80, $62, $AD, $46, $3A, $0B, $F4
	dc.b	$63, $A0, $E7, $A2, $FE, $83, $FF, $91, $1F, $21, $D7, $73, $93, $54, $03, $51, $C8, $2F, $FF, $CC, $52, $F5, $A9, $68, $2D, $56, $A5, $A1, $02, $AD, $0C, $FC
	dc.b	$E6, $07, $FF, $0C, $6D, $07, $59, $F4, $84, $1A, $DE, $6A, $D3, $11, $79, $68, $D5, $1C, $F4, $02, $B3, $58, $97, $85, $A6, $A0, $CF, $45, $E0, $01, $09, $C9
	dc.b	$9A, $CE, $CC, $CB, $C3, $12, $F1, $8D, $E6, $00, $A0, $C5, $31, $D0, $29, $CA, $3E, $4E, $E6, $36, $6A, $BB, $86, $A3, $93, $55, $CA, $EF, $AC, $C5, $E5, $A3
	dc.b	$54, $31, $41, $78, $31, $BD, $43, $93, $30, $5E, $AD, $05, $E0, $42, $10, $C4, $56, $25, $E5, $E1, $88, $20, $04, $CD, $5B, $7A, $A0, $62, $5A, $62, $66, $00
	dc.b	$D7, $A0, $18, $99, $A0, $16, $AB, $50, $0B, $55, $A8, $6A, $0C, $56, $69, $7F, $45, $BF, $D8, $66, $AD, $B1, $78, $35, $2D, $35, $04, $21, $B4, $03, $FF, $8A
	dc.b	$C4, $BF, $59, $81, $56, $E8, $AB, $74, $1E, $AD, $1D, $FC, $85, $FA, $CE, $CE, $B3, $B0, $9C, $84, $E4, $0C, $75, $88, $6C, $39, $47, $28, $00, $00
Round_sign_mapping_6:
	dc.b	$80, $2E, $80, $06, $3A, $14, $0A, $25, $18, $35, $16, $45, $1A, $56, $3C, $65, $1B, $71, $00, $81, $18, $FA, $88, $05, $1C, $18, $F8, $8C, $03, $04, $15, $19
	dc.b	$25, $17, $36, $3B, $46, $3D, $78, $F9, $FF, $FF, $88, $00, $B7, $EE, $2B, $E3, $5C, $6F, $FD, $03, $E1, $F0, $E3, $1F, $C8, $EB, $F2, $C0, $3F, $B1, $F9, $6D
	dc.b	$70, $0D, $F2, $B8, $1F, $C8, $2B, $F9, $1D, $7C, $6B, $81, $F1, $AE, $2D, $FA, $8D, $7C, $38, $71, $5C, $00, $DF, $37, $FD, $81, $5F, $F7, $1F, $D7, $FA, $1F
	dc.b	$B7, $0F, $CB, $FD, $00, $B7, $E5, $FE, $80, $5B, $F0, $FF, $8B, $FC, $E8, $0A, $B8, $0D, $5F, $CC, $EA, $3C, $86, $A2, $79, $03, $D4, $3B, $42, $0B, $77, $D5
	dc.b	$D6, $87, $90, $B6, $7A, $F5, $50, $42, $DD, $D6, $7C, $CB, $E4, $2D, $F2, $5B, $28, $4B, $5F, $AE, $EA, $16, $9D, $42, $D3, $A8, $C6, $7C, $82, $2A, $35, $2B
	dc.b	$BA, $80, $D4, $55, $F1, $91, $88, $8B, $B2, $37, $3C, $8F, $23, $FD, $80, $B5, $ED, $31, $31, $EA, $BF, $B8, $23, $A8, $BA, $0D, $CA, $F5, $BE, $C1, $B9, $89
	dc.b	$53, $AB, $E3, $2D, $C3, $C9, $D6, $51, $EE, $A6, $EE, $16, $F7, $17, $A9, $E6, $75, $02, $EF, $42, $2D, $7B, $4C, $4C, $76, $04, $7F, $B1, $97, $F7, $03, $FB
	dc.b	$9B, $9A, $CE, $2E, $1B, $F5, $89, $89, $6B, $85, $7C, $9F, $21, $7C, $66, $A6, $B3, $68, $81, $7A, $BA, $A6, $B3, $8B, $87, $7B, $8B, $5C, $1E, $E2, $1D, $86
	dc.b	$6B, $B5, $A6, $33, $8B, $84, $6E, $03, $60, $00
Round_sign_mapping_7:
	dc.b	$80, $3C, $80, $05, $19, $15, $16, $24, $0A, $35, $17, $46, $3B, $55, $1A, $66, $3A, $71, $00, $81, $18, $FA, $88, $05, $1B, $48, $F8, $8C, $03, $04, $15, $18
	dc.b	$26, $3C, $35, $1C, $47, $7A, $57, $7B, $68, $F9, $FF, $FF, $88, $00, $FF, $C0, $FF, $C0, $FF, $40, $CF, $F6, $3F, $1D, $F8, $60, $1F, $19, $FC, $B0, $7C, $1D
	dc.b	$FC, $05, $B7, $7D, $96, $F8, $33, $B6, $B6, $6B, $76, $FF, $C2, $FB, $6B, $66, $B7, $DF, $E6, $2B, $F5, $05, $F6, $15, $F9, $8B, $7E, $E0, $CE, $C3, $5B, $AF
	dc.b	$DC, $0B, $FE, $E0, $6C, $75, $B0, $1D, $7F, $DC, $7F, $5F, $E8, $7E, $DC, $3F, $2F, $F4, $02, $FF, $97, $FA, $01, $7F, $C3, $FE, $2F, $F3, $B5, $8E, $E2, $B1
	dc.b	$99, $50, $5B, $D5, $F0, $8B, $CA, $82, $FF, $37, $86, $A0, $EB, $D8, $81, $08, $21, $35, $80, $16, $F9, $BC, $A8, $5A, $0E, $BD, $0C, $C0, $F9, $EA, $2B, $C4
	dc.b	$19, $F2, $F8, $42, $0E, $FD, $DE, $54, $2D, $3B, $83, $BF, $00, $19, $E0, $3B, $F7, $A8, $5A, $54, $CC, $12, $D8, $1A, $81, $82, $10, $BC, $A9, $51, $0B, $4A
	dc.b	$99, $82, $B0, $35, $00, $02, $F0, $75, $05, $73, $B8, $6A, $66, $0A, $C5, $60, $66, $0D, $4C, $F8, $05, $E5, $4B, $F2, $B8, $2D, $09, $51, $68, $BF, $0A, $F4
	dc.b	$4B, $61, $50, $BC, $B6, $0D, $62, $D3, $38, $EE, $08, $47, $50, $6A, $0B, $CB, $61, $5E, $8B, $7B, $2D, $8A, $82, $F2, $A1, $D4, $B6, $00, $66, $06, $A1, $78
	dc.b	$B6, $15, $E8, $B7, $C9, $33, $EE, $D1, $87, $81, $CA, $95, $3B, $C7, $73, $50, $3C, $3B, $F0, $3A, $E1, $7E, $05, $B8, $5F, $81, $7E, $5B, $C3, $CB, $60, $30
	dc.b	$6B, $01, $D7, $2D, $0C, $F2, $D0, $3F, $F8, $EB, $FF, $81, $9C, $57, $99, $9A, $8B, $F8, $10, $EA, $07, $40
Round_sign_mapping_8:
	dc.b	$80, $59, $80, $05, $1C, $14, $0A, $25, $18, $35, $17, $45, $1A, $55, $1D, $66, $3C, $71, $00, $88, $06, $3D, $8C, $03, $04, $15, $16, $25, $19, $35, $1B, $48
	dc.b	$F8, $58, $F9, $FF, $FF, $88, $00, $BF, $EE, $2B, $F3, $1A, $F5, $E7, $FA, $07, $E6, $1F, $98, $7A, $C7, $F2, $39, $F9, $60, $1F, $D8, $FC, $B6, $BD, $03, $CF
	dc.b	$6B, $D0, $0D, $7E, $63, $9E, $BC, $F5, $7F, $D4, $5F, $D1, $DF, $5E, $7A, $C7, $B7, $F5, $8F, $E4, $0A, $FF, $B8, $FE, $BF, $E4, $47, $ED, $C3, $F2, $FF, $91
	dc.b	$00, $F2, $76, $3B, $06, $3F, $F9, $7B, $25, $5B, $52, $A0, $C4, $AB, $1D, $97, $81, $FE, $CB, $D9, $39, $94, $C4, $15, $61, $56, $0B, $55, $8A, $D8, $79, $9B
	dc.b	$CC, $42, $A6, $A0, $87, $92, $F9, $09, $CC, $98, $B0, $2B, $F2, $FF, $91, $01, $7F, $C3, $FE, $2F, $F3, $A0, $20, $5F, $2C, $7C, $31, $05, $E3, $C8, $F2, $0A
	dc.b	$98, $DB, $13, $56, $AB, $55, $81, $63, $B6, $AD, $8A, $CD, $E1, $9D, $7F, $B3, $50, $EC, $E4, $18, $B6, $2C, $39, $07, $67, $32, $02, $FF, $EC, $03, $52, $A5
	dc.b	$67, $56, $05, $E5, $4B, $C0, $1D, $9C, $B5, $58, $05, $7C, $8D, $41, $56, $C5, $98, $F8, $2B, $FD, $87, $2C, $10, $5F, $60, $5F, $FF, $9F, $28, $81, $DF, $FE
	dc.b	$2A, $5E, $63, $7C, $B0, $FF, $65, $5A, $F0, $95, $F0, $35, $BA, $B3, $B2, $F3, $1B, $1F, $15, $9C, $58, $C7, $C8, $FF, $E5, $E1, $8D, $F3, $23, $E2, $FB, $31
	dc.b	$02, $B3, $59, $E5, $8A, $D8, $55, $B9, $BE, $58, $E6, $C6, $3E, $6B, $E4, $0A, $CE, $B2, $06, $B6, $DA, $F9, $40, $AB, $55, $AA, $31, $2F, $01, $95, $F2, $81
	dc.b	$56, $AB, $54, $62, $D8, $80, $B3, $B6, $A8, $0C, $7C, $36, $0B, $EF, $99, $7C, $03, $5F, $05, $4D, $41, $3C, $F9, $2C, $11, $F0, $ED, $81, $A9, $E4, $10, $8E
	dc.b	$D8, $00, $E4, $BE, $4D, $65, $3C, $8C, $47, $67, $90, $9E, $42, $A5, $F2, $72, $62, $D5, $35, $11, $88, $EC, $EC, $F2, $27, $6D, $A8, $79, $07, $67, $37, $C8
	dc.b	$6A, $72, $0B, $CC, $4A, $9A, $87, $20, $46, $50, $85, $E1, $90, $79, $2F, $9D, $64, $17, $8A, $80, $2F, $3B, $6A, $80, $62, $55, $BB, $90, $31, $6C, $7C, $72
	dc.b	$C6, $A0, $55, $B1, $6C, $7C, $15, $FE, $C1, $CB, $08, $15, $6E, $D8, $0B, $DB, $BB, $3B, $08, $5F, $6F, $FE, $02, $D7, $DA, $F6, $06, $EA, $DD, $9C, $DE, $20
	dc.b	$33, $59, $66, $B2, $0B, $ED, $7D, $83, $59, $6B, $20, $8F, $20, $3C, $DD, $59, $BA, $B0, $3E, $55, $F2, $0C, $65, $AC, $82, $E0
Round_sign_mapping_9:
	dc.b	$80, $2E, $80, $04, $0A, $15, $16, $24, $09, $35, $18, $46, $3B, $55, $19, $67, $7B, $71, $00, $81, $18, $F9, $88, $05, $1A, $17, $7A, $48, $FA, $58, $FB, $8C
	dc.b	$04, $08, $15, $17, $25, $1B, $35, $1C, $46, $3A, $56, $3C, $78, $F8, $FF, $FF, $88, $00, $C7, $EE, $2D, $EB, $BD, $3D, $FF, $A0, $7A, $7A, $69, $3F, $55, $F9
	dc.b	$60, $1F, $7F, $96, $EF, $40, $7B, $D5, $B4, $07, $BD, $7B, $D7, $7E, $95, $A7, $A7, $EE, $0F, $B0, $B6, $87, $D1, $6F, $A0, $D5, $BE, $C5, $BF, $EE, $3F, $AF
	dc.b	$F2, $3F, $6E, $1F, $97, $F9, $01, $8F, $CB, $FC, $80, $C7, $E1, $FF, $17, $F9, $D1, $DD, $C5, $79, $50, $31, $71, $68, $9E, $0A, $F0, $57, $FB, $07, $7C, $16
	dc.b	$B8, $C5, $C3, $6C, $44, $C1, $68, $EE, $0C, $DC, $00, $A8, $C4, $13, $18, $84, $DE, $60, $98, $33, $18, $84, $57, $45, $40, $33, $00, $39, $30, $03, $93, $06
	dc.b	$60, $CC, $2D, $D1, $98, $33, $15, $09, $BC, $EC, $81, $0C, $DE, $BA, $26, $08, $31, $CA, $B9, $18, $86, $60, $9E, $4C, $01, $DD, $EB, $95, $B0, $31, $7B, $75
	dc.b	$57, $C4, $19, $83, $31, $8F, $2D, $15, $13, $13, $D0, $B7, $FB, $1B, $40, $81, $00, $1F, $1B, $03, $E3, $C0, $16, $DC, $DC, $06, $ED, $B3, $BD, $87, $85, $BC
	dc.b	$0B, $70, $C7, $03, $3D, $13, $D0, $57, $44, $F4, $13, $F0, $7C, $06, $6E, $66, $E0, $00
Round_sign_mapping_10:
	dc.b	$80, $36, $80, $04, $0A, $15, $19, $24, $0B, $35, $1B, $46, $3C, $55, $1A, $71, $00, $81, $18, $FA, $88, $06, $3A, $16, $3D, $8C, $03, $04, $15, $18, $25, $1C
	dc.b	$36, $3B, $48, $F8, $8E, $18, $F9, $FF, $FF, $88, $D7, $BE, $75, $E7, $AD, $7F, $20, $7A, $F3, $AD, $74, $AF, $77, $E8, $AF, $EC, $57, $5A, $E8, $FE, $C7, $C8
	dc.b	$74, $E9, $AF, $6B, $F5, $1F, $2B, $F4, $17, $E8, $07, $5F, $E0, $EB, $3D, $01, $BE, $AF, $E4, $07, $EA, $33, $D7, $C8, $0F, $6F, $A0, $19, $F6, $BF, $50, $3C
	dc.b	$FE, $40, $FD, $C6, $7D, $6B, $A7, $F2, $00, $6F, $FE, $E3, $FA, $FF, $43, $F6, $E1, $F9, $7F, $A0, $1B, $FC, $BF, $D0, $0D, $FE, $6F, $F3, $A0, $3B, $AE, $79
	dc.b	$12, $B0, $81, $35, $8B, $95, $17, $33, $2E, $54, $15, $FE, $CA, $88, $CC, $F2, $04, $AE, $6F, $09, $9C, $25, $C1, $5C, $37, $D8, $6F, $E0, $BE, $C3, $72, $E0
	dc.b	$0B, $97, $8D, $63, $C8, $B9, $99, $70, $54, $AE, $EF, $08, $DC, $B8, $37, $CA, $9E, $4C, $C1, $73, $70, $CF, $00, $5C, $DF, $00, $4C, $F6, $5C, $F3, $0D, $CD
	dc.b	$4C, $FC, $5F, $33, $C0, $15, $8A, $86, $A5, $CA, $C2, $E7, $98, $B9, $9C, $66, $01, $A8, $A9, $72, $A0, $AE, $D7, $F0, $BC, $5F, $2A, $0D, $4B, $C1, $9E, $EA
	dc.b	$66, $04, $18, $AC, $01, $52, $E5, $4A, $99, $E0, $1B, $9A, $95, $8C, $C0, $13, $38, $CC, $03, $C9, $BF, $84, $06, $65, $CA, $E6, $71, $53, $50, $35, $2A, $2E
	dc.b	$6A, $66, $37, $D9, $7F, $DC, $79, $CC, $C0, $86, $FE, $0F, $F0, $76, $15, $FE, $CA, $8C, $5C, $DF, $02, $B1, $9E, $EA, $6A, $2F, $B0, $C5, $7C, $2E, $6F, $19
	dc.b	$EC, $35, $8D, $44, $05, $FC, $5C, $61, $80, $F8, $AC, $2A, $6A, $57, $2B, $01, $83, $58, $0D, $77, $5C, $3B, $AE, $07, $FF, $0F, $FE, $00
Round_sign_mapping_11:
	dc.b	$80, $3B, $80, $05, $19, $15, $18, $24, $0A, $35, $16, $45, $1A, $55, $1C, $66, $37, $71, $00, $88, $06, $3B, $16, $3C, $28, $F8, $8C, $03, $04, $15, $17, $26
	dc.b	$36, $36, $3A, $46, $3D, $8E, $18, $FA, $FF, $FF, $88, $E7, $9A, $EF, $5E, $39, $FC, $81, $E0, $E7, $81, $5F, $16, $EF, $5E, $39, $FB, $8F, $A1, $D8, $DF, $BC
	dc.b	$7C, $7D, $2B, $C0, $57, $95, $F0, $03, $FF, $0C, $78, $0B, $77, $5E, $7D, $00, $EE, $DD, $FD, $00, $B7, $60, $39, $D8, $DF, $F9, $03, $F7, $02, $DF, $B8, $1C
	dc.b	$FE, $C0, $C7, $F6, $07, $C5, $7E, $58, $7C, $05, $7E, $58, $7F, $DC, $7F, $5F, $F2, $23, $F6, $E1, $F9, $7F, $C8, $80, $B7, $E5, $FF, $22, $02, $DF, $97, $FC
	dc.b	$0F, $E3, $75, $7D, $47, $20, $B6, $D6, $9B, $C3, $3D, $54, $B4, $62, $6F, $37, $88, $40, $D8, $6B, $D1, $89, $BD, $D0, $98, $83, $FD, $8D, $43, $90, $A9, $5D
	dc.b	$33, $04, $35, $B6, $7A, $16, $B8, $C7, $B9, $B8, $AB, $8A, $98, $D8, $42, $19, $D8, $0B, $45, $74, $02, $57, $4B, $44, $44, $2F, $6B, $E2, $55, $EA, $22, $26
	dc.b	$67, $26, $67, $2F, $9D, $B1, $B0, $35, $37, $98, $D8, $B4, $B4, $33, $2D, $19, $95, $73, $90, $A9, $68, $AF, $F6, $00, $DA, $AE, $02, $63, $D0, $72, $33, $D6
	dc.b	$26, $21, $08, $5B, $FF, $8A, $F4, $54, $6F, $37, $88, $86, $25, $A5, $75, $AE, $96, $81, $BC, $D5, $ED, $71, $BC, $39, $31, $FF, $CB, $4D, $F6, $16, $EA, $A5
	dc.b	$A6, $36, $A9, $69, $9B, $9A, $8D, $91, $70, $31, $2A, $F5, $7C, $F4, $05, $5E, $A5, $A0, $0C, $4D, $5D, $08, $42, $E8, $B8, $3F, $F8, $DF, $FF, $81, $9B, $DA
	dc.b	$F9, $9C, $8D, $5C, $36, $35, $B0, $2A, $E7, $2E, $16, $E8, $B7, $41, $2B, $A2, $57, $41, $E9, $5E, $85, $BD, $2B, $D0, $C4, $37, $81, $B8
Round_sign_mapping_12:
	dc.b	$80, $3A, $80, $05, $1B, $14, $0A, $25, $1A, $35, $16, $46, $3B, $55, $17, $67, $7B, $71, $00, $86, $18, $F9, $88, $05, $18, $16, $39, $26, $38, $8C, $03, $04
	dc.b	$15, $19, $26, $3A, $37, $79, $47, $7A, $78, $F8, $8E, $17, $78, $FF, $FF, $88, $BF, $3D, $E3, $BE, $57, $FE, $40, $E5, $DE, $2F, $86, $F9, $B7, $23, $7F, $D8
	dc.b	$DE, $2F, $83, $FB, $1E, $03, $0C, $2F, $CE, $F8, $F0, $D7, $20, $D7, $20, $D7, $05, $62, $B8, $AC, $56, $05, $72, $5F, $8D, $78, $01, $C5, $63, $C0, $0E, $75
	dc.b	$C0, $1E, $F8, $B6, $2F, $8B, $E2, $F8, $BE, $2F, $8B, $E2, $F8, $BE, $2D, $C7, $CA, $B0, $BE, $2F, $83, $DF, $36, $F0, $EF, $00, $B7, $F6, $2D, $8B, $E2, $F8
	dc.b	$0E, $F9, $B7, $C8, $0D, $71, $E0, $6B, $F9, $03, $F7, $1B, $E0, $7E, $E3, $7C, $0F, $FC, $0F, $FC, $0E, $35, $F2, $38, $0D, $7C, $8F, $FB, $8F, $EB, $FE, $44
	dc.b	$7E, $DC, $3F, $2F, $F9, $10, $16, $FC, $BF, $E4, $40, $5B, $F2, $FF, $9D, $01, $9B, $66, $A5, $A3, $52, $A3, $BC, $97, $C8, $0B, $E4, $B7, $F7, $03, $73, $7E
	dc.b	$89, $50, $84, $A9, $68, $54, $B4, $54, $B4, $6A, $54, $EE, $6E, $1D, $CA, $CA, $A2, $F3, $DF, $AA, $86, $B2, $A8, $3E, $37, $9B, $65, $AC, $F7, $2A, $0D, $F5
	dc.b	$6C, $DE, $6E, $5A, $35, $2A, $0A, $EA, $BA, $10, $26, $FC, $AD, $2A, $3B, $C8, $0B, $7F, $70, $AF, $8B, $66, $F0, $81, $9A, $F3, $59, $D4, $5E, $37, $2D, $2A
	dc.b	$5A, $2B, $FB, $9B, $80, $3A, $00, $16, $81, $DF, $47, $40, $AC, $BD, $C5, $E2, $F1, $AF, $3A, $8A, $CE, $A3, $72, $A3, $52, $D0, $83, $70, $84, $01, $69, $EE
	dc.b	$01, $A9, $52, $D3, $70, $0B, $4A, $9A, $96, $C8, $11, $DE, $4B, $E4, $3C, $D6, $4F, $35, $90, $F8, $3E, $02, $57, $A2, $57, $A0, $96, $E8, $96, $E8, $3A, $AE
	dc.b	$8E, $AB, $A0, $F4, $6B, $D0, $6B, $E2, $33, $69, $AF, $21, $BC, $DB, $3B, $96, $9B, $97, $80, $00
Round_sign_mapping_13:
	dc.b	$80, $37, $80, $05, $18, $14, $0A, $25, $16, $35, $17, $46, $3A, $55, $19, $66, $3B, $71, $00, $81, $18, $F9, $88, $05, $1A, $16, $38, $27, $7A, $38, $FA, $8C
	dc.b	$03, $04, $16, $36, $26, $39, $36, $37, $46, $3C, $58, $F8, $8E, $17, $7B, $FF, $FF, $88, $CF, $1D, $6B, $AE, $19, $FE, $40, $E1, $D6, $B3, $A6, $38, $BF, $03
	dc.b	$1F, $D8, $C6, $B3, $A3, $FB, $1E, $C3, $4D, $33, $C6, $3D, $7B, $5B, $80, $5B, $80, $5B, $D1, $5A, $AF, $55, $AA, $D0, $AE, $0C, $FA, $B7, $B0, $1E, $AB, $5E
	dc.b	$C0, $71, $6F, $40, $38, $B7, $AC, $7D, $0B, $FD, $34, $AE, $2F, $ED, $8D, $3B, $D1, $A7, $5F, $D8, $F6, $2D, $FC, $81, $F5, $5C, $33, $A7, $F2, $00, $5F, $FE
	dc.b	$E3, $FA, $FF, $23, $F6, $E1, $F9, $7F, $90, $17, $FC, $BF, $C8, $0A, $DB, $F3, $7F, $8D, $FC, $08, $0A, $F0, $10, $C7, $36, $89, $68, $21, $5F, $FC, $01, $F0
	dc.b	$3A, $F0, $54, $EF, $64, $25, $41, $FE, $C7, $50, $CC, $2D, $2D, $BB, $10, $43, $AE, $71, $B8, $09, $6E, $4A, $84, $25, $F7, $A8, $66, $19, $8B, $6F, $68, $54
	dc.b	$BC, $31, $31, $17, $96, $D8, $15, $1D, $CA, $E4, $BC, $BC, $31, $2F, $18, $96, $D8, $CC, $2D, $2F, $15, $2D, $B6, $25, $E1, $09, $51, $99, $8F, $8E, $E0, $3B
	dc.b	$8D, $C1, $1E, $75, $01, $89, $79, $89, $DE, $F5, $B5, $A1, $98, $5E, $62, $5E, $63, $7A, $E6, $D2, $DE, $0B, $7C, $26, $27, $52, $A0, $82, $77, $2B, $60, $1C
	dc.b	$85, $E1, $99, $5F, $FC, $BC, $EF, $91, $7D, $ED, $2F, $2B, $9B, $4B, $CC, $6C, $75, $1C, $A0, $0B, $C5, $47, $70, $84, $5B, $CA, $8D, $9E, $07, $C7, $73, $AD
	dc.b	$AD, $C8, $67, $C2, $DE, $05, $6F, $5B, $1B, $D6, $C1, $C9, $D7, $20, $B6, $C6, $76, $0B, $EE, $5F, $70, $96, $DC, $96, $DC, $26, $61, $33, $00, $00
Round_sign_mapping_14:
	dc.b	$80, $37, $80, $06, $3A, $14, $0A, $25, $18, $34, $0B, $46, $39, $55, $19, $66, $3B, $71, $00, $88, $05, $1A, $16, $36, $26, $3C, $38, $F8, $8C, $04, $08, $14
	dc.b	$09, $26, $37, $36, $38, $47, $7A, $58, $FA, $8E, $17, $7B, $FF, $FF, $88, $CE, $DC, $EB, $9D, $99, $FE, $40, $D8, $67, $60, $AF, $86, $34, $EF, $CF, $63, $C1
	dc.b	$CF, $F6, $3D, $B1, $B0, $31, $B6, $3C, $01, $B7, $5F, $C8, $AD, $19, $D1, $9D, $5E, $B9, $DB, $AF, $60, $3C, $AD, $7B, $01, $B6, $3C, $77, $A3, $3A, $31, $E3
	dc.b	$BD, $19, $D1, $9D, $56, $80, $EF, $CC, $EC, $57, $C0, $AF, $EC, $57, $98, $F6, $63, $61, $9D, $B1, $FD, $8F, $63, $1F, $C8, $1F, $02, $FE, $00, $5F, $FD, $C7
	dc.b	$F5, $FF, $22, $3F, $6E, $1F, $97, $FC, $88, $0B, $FC, $BF, $E4, $40, $71, $F9, $BF, $CE, $97, $BA, $07, $15, $C2, $08, $09, $2F, $E8, $3E, $80, $5F, $07, $50
	dc.b	$CC, $0C, $7F, $F2, $E5, $89, $E6, $2A, $05, $4E, $21, $50, $B9, $A8, $0D, $EA, $0C, $48, $66, $00, $2A, $40, $54, $D4, $D4, $5C, $31, $15, $0E, $64, $CF, $07
	dc.b	$71, $7B, $9C, $EF, $DC, $17, $0C, $C7, $70, $EE, $31, $22, $BD, $18, $F5, $D4, $DC, $80, $90, $B9, $5F, $0B, $DC, $75, $2C, $C9, $17, $00, $2B, $D2, $E2, $A1
	dc.b	$CC, $8B, $90, $18, $8C, $C0, $17, $17, $B8, $0C, $47, $53, $5B, $F3, $20, $B8, $A8, $B8, $A9, $01, $89, $C4, $01, $18, $8A, $9B, $93, $AF, $FE, $06, $F8, $9A
	dc.b	$8E, $65, $72, $15, $F4, $57, $D0, $7A, $A8, $EE, $1E, $83, $1F, $FC, $4D, $C6, $38, $EA, $02, $71, $B9, $38, $DC, $3D, $18, $F4, $17, $FE, $CE, $A1, $2E, $02
	dc.b	$4C, $C8, $67, $82, $F8, $0B, $00, $00
Round_sign_mapping_15:
	dc.b	$80, $40, $80, $05, $17, $15, $18, $24, $0A, $36, $39, $45, $19, $56, $36, $67, $78, $71, $00, $81, $17, $7B, $88, $05, $1A, $16, $37, $27, $79, $8C, $03, $04
	dc.b	$15, $16, $26, $38, $36, $3B, $46, $3A, $8E, $17, $7A, $FF, $FF, $88, $DB, $7C, $EB, $3B, $B6, $FE, $40, $DE, $BC, $8D, $EB, $C8, $FF, $C0, $FE, $C7, $A1, $B8
	dc.b	$DB, $7B, $F9, $F4, $AD, $C1, $5B, $80, $57, $90, $1B, $F3, $F9, $60, $19, $D7, $A0, $1B, $81, $5E, $55, $FB, $8A, $D7, $3A, $18, $F3, $5B, $D6, $8F, $5A, $68
	dc.b	$D0, $F1, $AA, $FC, $B0, $CF, $91, $BD, $68, $63, $71, $AC, $6B, $C6, $BD, $00, $FE, $C7, $A1, $5F, $C8, $1F, $B8, $C6, $ED, $B4, $FE, $40, $E7, $FF, $06, $B6
	dc.b	$D5, $FF, $B0, $2F, $BF, $3F, $96, $5F, $5B, $68, $19, $FC, $B0, $FF, $B8, $FE, $BF, $B1, $FB, $70, $FC, $BF, $B0, $1C, $FE, $5F, $D8, $0E, $7F, $2F, $F9, $D3
	dc.b	$30, $6D, $2A, $57, $06, $20, $45, $40, $15, $2A, $6D, $6C, $C6, $D2, $A0, $AE, $2F, $31, $64, $A9, $9B, $5E, $54, $18, $B7, $36, $2D, $CD, $83, $FB, $9C, $D8
	dc.b	$95, $02, $D8, $87, $32, $A0, $C4, $CC, $BF, $00, $1C, $08, $1D, $1E, $20, $57, $FF, $05, $45, $43, $FF, $82, $A0, $DA, $5F, $B2, $A5, $47, $31, $67, $03, $6B
	dc.b	$2C, $95, $12, $A0, $00, $58, $DA, $62, $54, $BC, $22, $A3, $36, $DA, $66, $63, $A1, $15, $0A, $E8, $54, $1E, $25, $7E, $6F, $F3, $A2, $0F, $13, $13, $F3, $7F
	dc.b	$8D, $FC, $0E, $25, $47, $8B, $17, $95, $C2, $54, $C5, $AA, $2A, $1E, $2D, $51, $7E, $2F, $D0, $15, $2F, $39, $B5, $F8, $57, $61, $89, $79, $56, $BD, $B1, $60
	dc.b	$2F, $2A, $62, $54, $62, $06, $D1, $B4, $CC, $BC, $67, $83, $9E, $98, $98, $E3, $10, $11, $B5, $AF, $F9, $BF, $CE, $DE, $02, $33, $31, $3F, $17, $F8, $7F, $65
	dc.b	$FB, $0C, $F6, $73, $D8, $63, $FF, $91, $6A, $B5, $70, $18, $95, $D5, $45, $90, $3A, $F1, $33, $6E, $6C, $1B, $75, $7B, $23, $BB, $D8, $2D, $98, $5B, $30, $38
	dc.b	$BF, $67, $17, $EC, $3F, $B9, $78, $7F, $72, $F0, $3A, $BD, $8E, $AF, $60, $E2, $FF, $97, $F6, $70, $19, $00
Round_sign_mapping_16:
	dc.b	$80, $38, $80, $05, $19, $14, $0A, $25, $17, $35, $1A, $46, $3B, $55, $1B, $66, $3D, $71, $00, $81, $18, $F9, $88, $05, $18, $15, $1C, $8C, $03, $04, $15, $16
	dc.b	$26, $3C, $36, $3A, $8E, $18, $F8, $FF, $FF, $88, $DF, $3B, $C7, $7C, $6F, $F9, $03, $8E, $F1, $BC, $33, $CD, $70, $67, $FB, $19, $C6, $F0, $7F, $63, $E0, $30
	dc.b	$C3, $7C, $CF, $EA, $3E, $17, $E0, $2F, $C0, $0C, $7B, $8A, $C0, $70, $AC, $5F, $F2, $C1, $FA, $81, $58, $F8, $01, $CC, $F2, $B1, $58, $D6, $05, $F9, $DE, $2B
	dc.b	$0A, $E6, $BE, $30, $C1, $81, $EE, $2F, $F0, $05, $62, $B1, $EE, $3E, $00, $7F, $63, $E0, $5F, $F9, $03, $F7, $15, $C6, $F0, $FE, $40, $0D, $7F, $DC, $7F, $5F
	dc.b	$E4, $7E, $DC, $3F, $2F, $F2, $03, $5F, $97, $F9, $01, $56, $FC, $DF, $CE, $E1, $02, $AD, $EC, $6E, $3B, $B1, $BF, $EE, $6E, $DD, $C5, $E5, $4B, $C1, $9B, $67
	dc.b	$C7, $70, $42, $6E, $C0, $2B, $FD, $9A, $97, $85, $41, $EF, $F7, $04, $DC, $12, $BF, $99, $9B, $6A, $CB, $DB, $B9, $50, $67, $CD, $5B, $73, $33, $51, $79, $50
	dc.b	$57, $95, $E0, $83, $D9, $9E, $B3, $1E, $C0, $5B, $32, $AC, $A8, $EE, $C1, $6A, $B0, $0B, $1A, $84, $35, $2F, $2F, $10, $A9, $79, $98, $2F, $61, $B8, $06, $A0
	dc.b	$3B, $F1, $E0, $3B, $80, $1A, $F0, $04, $CF, $40, $6A, $5E, $67, $CC, $CA, $9D, $C1, $08, $F6, $0D, $C1, $A9, $56, $5F, $F9, $85, $7F, $70, $AB, $5E, $0D, $4B
	dc.b	$C3, $76, $AB, $2A, $02, $F2, $A6, $7A, $CC, $AF, $01, $EC, $A9, $79, $78, $05, $E5, $4D, $4A, $E8, $08, $CF, $46, $BA, $0D, $F4, $6B, $A0, $BF, $F3, $2F, $16
	dc.b	$58, $3A, $AF, $0F, $2A, $C1, $63, $76, $0F, $7A, $35, $D0, $5F, $FF, $91, $6D, $4B, $F4, $19, $B6, $AD, $99, $A9, $99, $B8, $00
Title_sign_tilemap: ; Compressed tilemap for track preview sign at title screen
	dc.b	$06, $03, $00, $00, $00, $13, $0A, $00, $08, $34, $40, $C0, $80, $02, $16, $10, $70, $A8, $83, $03, $CC, $18, $24, $18, $24, $1F, $00, $C1, $20, $C0, $D1, $10
	dc.b	$F1, $10, $E0, $C0, $72, $06, $87, $80, $06, $8C, $0F, $08, $1A, $50, $70, $20, $40, $44, $18, $0A, $81, $28, $02, $00, $40, $19, $05, $48, $03, $20, $71, $59
	dc.b	$19, $05, $48, $12, $80, $40, $59, $05, $2F, $E0
Title_sign_tiles: ; Compressed tiles for track preview sign at title screen
	dc.b	$80, $23, $80, $05, $1B, $15, $17, $25, $19, $35, $16, $45, $1A, $56, $3B, $65, $18, $71, $00, $89, $03, $04, $15, $1C, $46, $3C, $68, $FB, $8C, $04, $0A, $18
	dc.b	$FA, $26, $3A, $36, $3D, $77, $7C, $FF, $FF, $88, $DF, $D8, $DF, $D8, $FD, $CB, $88, $DF, $D8, $C7, $2D, $CD, $46, $3C, $17, $F0, $67, $C1, $6F, $06, $7C, $17
	dc.b	$FE, $C8, $C4, $01, $89, $78, $06, $22, $D0, $0B, $CB, $40, $17, $80, $31, $06, $A0, $C4, $DC, $B4, $62, $0C, $45, $E5, $A5, $E6, $B9, $A8, $EE, $77, $2F, $2D
	dc.b	$33, $16, $E0, $62, $1F, $A9, $B4, $2F, $03, $50, $20, $6A, $5E, $5A, $33, $1F, $B9, $19, $F1, $99, $69, $9E, $5E, $6B, $83, $FE, $E0, $1D, $FD, $6A, $BB, $A7
	dc.b	$74, $5B, $A0, $C7, $B9, $AB, $53, $75, $BF, $E6, $06, $68, $D7, $41, $AF, $F6, $29, $4F, $A5, $14, $33, $D5, $FA, $01, $D5, $FA, $0F, $E6, $00, $5F, $E3, $BE
	dc.b	$80, $B5, $67, $E0, $5B, $D3, $E1, $F0, $3D, $C5, $6B, $EB, $54, $18, $AE, $E9, $BA, $B5, $67, $D0, $DF, $B6, $A1, $7A, $18, $FE, $E0, $A1, $80, $00
Track_preview_tilemap_data: ; Per-track tilemap for race preview background; stride = $3B bytes, indexed by Track_preview_index
	dc.b	$24, $00, $1A, $FA, $18, $00, $22, $10, $1A, $1C, $FA, $FA, $FA, $FE, $25, $01, $1B, $FA, $19, $01, $23, $11, $1B, $1D, $FA, $FA, $FA, $FD, $FB, $07, $C0, $34
	dc.b	$FA, $1B, $18, $1E, $17, $0D, $FA, $FA, $01, $FA, $35, $FD, $15, $0E, $17, $10, $1D, $11, $FA, $28, $FA, $03, $05, $02, $00, $16, $FF, $02, $22, $00, $32, $10
	dc.b	$16, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FE, $03, $23, $01, $33, $11, $17, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FD, $FB, $07, $C0, $34, $FA, $1B, $18, $1E, $17
	dc.b	$0D, $FA, $FA, $02, $FA, $35, $FD, $15, $0E, $17, $10, $1D, $11, $FA, $28, $FA, $03, $04, $08, $08, $16, $FF, $0A, $22, $00, $1A, $04, $08, $FA, $FA, $FA, $FA
	dc.b	$FA, $FA, $FA, $FE, $0B, $23, $01, $1B, $05, $09, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FD, $FB, $07, $C0, $34, $FA, $1B, $18, $1E, $17, $0D, $FA, $FA, $03, $FA
	dc.b	$35, $FD, $15, $0E, $17, $10, $1D, $11, $FA, $28, $FA, $03, $00, $07, $02, $16, $FF, $0E, $28, $1A, $0C, $00, $22, $30, $FA, $FA, $FA, $FA, $FA, $FA, $FE, $0F
	dc.b	$29, $1B, $0D, $01, $23, $31, $FA, $FA, $FA, $FA, $FA, $FA, $FD, $FB, $07, $C0, $34, $FA, $1B, $18, $1E, $17, $0D, $FA, $FA, $04, $FA, $35, $FD, $15, $0E, $17
	dc.b	$10, $1D, $11, $FA, $28, $FA, $03, $02, $03, $02, $16, $FF, $2C, $08, $24, $26, $FA, $0C, $08, $22, $18, $00, $1A, $30, $FA, $FE, $2D, $09, $25, $27, $FA, $0D
	dc.b	$09, $23, $19, $01, $1B, $31, $FA, $FD, $FB, $07, $C0, $34, $FA, $1B, $18, $1E, $17, $0D, $FA, $FA, $05, $FA, $35, $FD, $15, $0E, $17, $10, $1D, $11, $FA, $28
	dc.b	$FA, $03, $07, $04, $04, $16, $FF, $28, $38, $24, $38, $00, $38, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FE, $29, $39, $25, $39, $01, $39, $FA, $FA, $FA, $FA, $FA
	dc.b	$FA, $FA, $FD, $FB, $07, $C0, $34, $FA, $1B, $18, $1E, $17, $0D, $FA, $FA, $06, $FA, $35, $FD, $15, $0E, $17, $10, $1D, $11, $FA, $28, $FA, $03, $05, $08, $04
	dc.b	$16, $FF, $04, $00, $1A, $00, $06, $00, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FE, $05, $01, $1B, $01, $07, $01, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FD, $FB, $07
	dc.b	$C0, $34, $FA, $1B, $18, $1E, $17, $0D, $FA, $FA, $07, $FA, $35, $FD, $15, $0E, $17, $10, $1D, $11, $FA, $28, $FA, $03, $03, $06, $00, $16, $FF, $0C, $22, $08
	dc.b	$00, $26, $FA, $02, $22, $10, $26, $00, $10, $1A, $FE, $0D, $23, $09, $01, $27, $FA, $03, $23, $11, $27, $01, $11, $1B, $FD, $FB, $07, $C0, $34, $FA, $1B, $18
	dc.b	$1E, $17, $0D, $FA, $FA, $08, $FA, $35, $FD, $15, $0E, $17, $10, $1D, $11, $FA, $28, $FA, $03, $04, $05, $06, $16, $FF, $10, $26, $00, $16, $30, $FA, $FA, $FA
	dc.b	$FA, $FA, $FA, $FA, $FA, $FE, $11, $27, $01, $17, $31, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FD, $FB, $07, $C0, $34, $FA, $1B, $18, $1E, $17, $0D, $FA, $FA
	dc.b	$09, $FA, $35, $FD, $15, $0E, $17, $10, $1D, $11, $FA, $28, $FA, $03, $08, $00, $08, $16, $FF, $1E, $1C, $22, $26, $28, $0C, $00, $16, $FA, $FA, $FA, $FA, $FA
	dc.b	$FE, $1F, $1D, $23, $27, $29, $0D, $01, $17, $FA, $FA, $FA, $FA, $FA, $FD, $FB, $07, $C0, $34, $FA, $1B, $18, $1E, $17, $0D, $FA, $01, $00, $FA, $35, $FD, $15
	dc.b	$0E, $17, $10, $1D, $11, $FA, $28, $FA, $03, $02, $09, $06, $16, $FF, $24, $1E, $00, $10, $1A, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FE, $25, $1F, $01, $11
	dc.b	$1B, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FD, $FB, $07, $C0, $34, $FA, $1B, $18, $1E, $17, $0D, $FA, $01, $01, $FA, $35, $FD, $15, $0E, $17, $10, $1D, $11
	dc.b	$FA, $28, $FA, $03, $03, $09, $02, $16, $FF, $18, $08, $2E, $10, $04, $1C, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FE, $19, $09, $2F, $11, $05, $1D, $FA, $FA, $FA
	dc.b	$FA, $FA, $FA, $FA, $FD, $FB, $07, $C0, $34, $FA, $1B, $18, $1E, $17, $0D, $FA, $01, $02, $FA, $35, $FD, $15, $0E, $17, $10, $1D, $11, $FA, $28, $FA, $03, $04
	dc.b	$02, $04, $16, $FF, $12, $00, $1E, $00, $1A, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FE, $13, $01, $1F, $01, $1B, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FD
	dc.b	$FB, $07, $C0, $34, $FA, $1B, $18, $1E, $17, $0D, $FA, $01, $03, $FA, $35, $FD, $15, $0E, $17, $10, $1D, $11, $FA, $28, $FA, $03, $07, $07, $06, $16, $FF, $02
	dc.b	$08, $16, $0C, $10, $28, $18, $FA, $FA, $FA, $FA, $FA, $FA, $FE, $03, $09, $17, $0D, $11, $29, $19, $FA, $FA, $FA, $FA, $FA, $FA, $FD, $FB, $07, $C0, $34, $FA
	dc.b	$1B, $18, $1E, $17, $0D, $FA, $01, $04, $FA, $35, $FD, $15, $0E, $17, $10, $1D, $11, $FA, $28, $FA, $03, $08, $07, $02, $16, $FF, $00, $28, $24, $26, $22, $00
	dc.b	$16, $10, $00, $FA, $FA, $FA, $FA, $FE, $01, $29, $25, $27, $23, $01, $17, $11, $01, $FA, $FA, $FA, $FA, $FD, $FB, $07, $C0, $34, $FA, $1B, $18, $1E, $17, $0D
	dc.b	$FA, $01, $05, $FA, $35, $FD, $15, $0E, $17, $10, $1D, $11, $FA, $28, $FA, $03, $00, $04, $00, $16, $FF, $18, $1C, $1A, $00, $04, $1C, $FA, $FA, $FA, $FA, $FA
	dc.b	$FA, $FA, $FE, $19, $1D, $1B, $01, $05, $1D, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FD, $FB, $07, $C0, $34, $FA, $1B, $18, $1E, $17, $0D, $FA, $01, $06, $FA, $35
	dc.b	$FD, $15, $0E, $17, $10, $1D, $11, $FA, $28, $FA, $03, $00, $07, $02, $16, $FF
Championship_start_text_tilemap: ; Packed tilemap for "BEST LAP" text at championship start screen
	dc.b	$E3, $58, $FB, $87, $C0, $0B, $0E, $1C, $1D, $FA, $15, $0A, $19, $FF
Championship_start_palette_stream: ; Palette VDP command stream for championship start screen
	dc.b	$02, $11, $00, $00, $0E, $EE, $0A, $AA, $06, $88, $04, $46, $04, $44, $02, $22, $00, $00, $00, $0E, $00, $00, $04, $4E, $06, $68, $06, $66, $08, $88, $00, $00
	dc.b	$00, $00, $00, $00, $00, $CE
Championship_start_curve_data: ; Compressed curve data decompressed to Curve_data at championship start
	dc.b	$80, $10, $80, $04, $0B, $15, $12, $25, $14, $35, $10, $45, $19, $55, $1B, $65, $1D, $71, $00, $8F, $05, $11, $15, $13, $25, $15, $35, $18, $45, $1A, $55, $1C
	dc.b	$65, $1E, $FF, $00, $FF, $FD, $F8, $0B, $F2, $5C, $04, $B8, $53, $41, $4D, $08, $60, $43, $01, $9A, $99, $A8, $37, $36, $E6, $07, $63, $D8, $80, $8F, $62, $07
	dc.b	$66, $DC, $C1, $BA, $99, $A8, $67, $02, $18, $10, $D0, $53, $45, $38, $09, $71, $2F, $01, $7E, $B0
Championship_start_tilemap: ; Compressed tilemap for championship start background
	dc.b	$07, $00, $00, $00, $00, $44, $02, $78, $09, $E0, $22, $00, $3C, $39, $60, $09, $80, $58, $5C, $25, $C1, $94, $00, $98, $05, $89, $94, $00, $29, $EF, $40, $8C
	dc.b	$00, $28, $B0, $40, $9E, $FE, $1B, $F8, $20, $20, $3F, $05, $50, $27, $BF, $86, $FE, $08, $0E, $2F, $E1, $AD, $C2, $2C, $F7, $F0, $DF, $C1, $01, $C5, $FC, $35
	dc.b	$B8, $45, $9E, $FE, $1B, $F8, $20, $38, $BF, $86, $B7, $08, $B3, $DF, $C3, $7F, $04, $07, $17, $F0, $D6, $E1, $16, $7B, $F8, $6F, $E0, $80, $E2, $FE, $1A, $DC
	dc.b	$22, $CF, $7F, $0D, $FC, $10, $1C, $5F, $C3, $5B, $84, $59, $EF, $E1, $BF, $82, $03, $8B, $F8, $6B, $70, $8B, $3D, $FC, $37, $F0, $40, $71, $7F, $0D, $6E, $11
	dc.b	$67, $BF, $86, $FE, $08, $0E, $2F, $E1, $AD, $C2, $2C, $F7, $F0, $DF, $C1, $01, $C5, $FC, $35, $B8, $45, $9E, $FE, $1B, $F8, $20, $20, $3F, $06, $2C, $70, $27
	dc.b	$C1, $83, $07, $AC, $27, $E0, $00, $3F, $86, $FB, $3D, $62, $BF, $00, $01, $FC, $37, $D9, $EB, $15, $F8, $00, $0F, $E1, $BE, $CF, $58, $AF, $C0, $00, $7F, $0D
	dc.b	$F6, $7A, $C5, $7E, $00, $03, $F8, $6F, $B3, $D6, $2B, $F0, $00, $1F, $C3, $7D, $9E, $B1, $5F, $80, $00, $FE, $1B, $EC, $F5, $8A, $FC, $00, $07, $F0, $DF, $67
	dc.b	$AC, $57, $E0, $00, $3F, $86, $FB, $3D, $22, $BF, $00, $01, $F8, $33, $E5, $48, $94, $07, $07, $F3, $C0, $4F, $01, $00, $07, $F0
Championship_start_tiles: ; Compressed tiles for championship start background
	dc.b	$00, $4C, $84, $04, $05, $15, $12, $28, $F3, $85, $04, $04, $16, $36, $86, $05, $17, $17, $78, $28, $F7, $87, $05, $14, $88, $05, $16, $14, $08, $26, $39, $37
	dc.b	$75, $48, $F2, $57, $77, $89, $05, $18, $14, $07, $27, $76, $8B, $04, $06, $27, $7A, $8C, $06, $33, $8D, $03, $00, $13, $01, $25, $13, $36, $32, $46, $38, $56
	dc.b	$37, $68, $F6, $75, $1A, $8E, $05, $15, $77, $74, $FF, $D6, $B5, $AD, $6B, $5A, $D6, $FF, $9E, $CB, $F3, $CB, $95, $57, $8A, $AE, $F5, $0A, $50, $55, $66, $8A
	dc.b	$2B, $C2, $8E, $8B, $AD, $04, $29, $34, $90, $49, $15, $3F, $B4, $DE, $5B, $F4, $08, $A5, $0A, $2C, $E4, $14, $EC, $16, $69, $FC, $B2, $CF, $C8, $46, $74, $52
	dc.b	$AC, $FC, $F4, $08, $A5, $0A, $2C, $E4, $14, $EC, $14, $30, $45, $FD, $DD, $8B, $3C, $04, $0C, $EA, $39, $67, $8E, $81, $14, $A1, $45, $9C, $82, $9D, $82, $8F
	dc.b	$52, $1F, $9B, $B3, $39, $6C, $06, $70, $8D, $8B, $33, $D8, $36, $3A, $04, $52, $85, $16, $72, $0A, $76, $0A, $18, $22, $FA, $18, $2A, $CE, $30, $85, $9C, $62
	dc.b	$03, $3D, $BA, $04, $52, $85, $16, $72, $0A, $76, $0A, $7F, $D6, $19, $F9, $60, $CE, $11, $5A, $CC, $FC, $B7, $40, $8A, $50, $A2, $CE, $41, $4E, $C1, $46, $02
	dc.b	$4B, $D3, $85, $6F, $E4, $96, $7B, $3D, $83, $3D, $BA, $04, $52, $85, $16, $72, $0A, $76, $0A, $3F, $76, $A5, $AD, $FB, $92, $C2, $DD, $91, $5B, $B8, $6E, $81
	dc.b	$14, $A1, $45, $9C, $82, $9D, $82, $8F, $ED, $97, $EA, $5E, $68, $A1, $FB, $F4, $08, $A5, $0A, $2C, $E4, $14, $EC, $16, $69, $2D, $D7, $84, $9A, $29, $97, $1D
	dc.b	$02, $29, $42, $8B, $39, $05, $3B, $05, $3F, $FB, $ED, $6E, $CC, $F6, $16, $76, $7F, $2E, $81, $14, $A1, $45, $9C, $82, $9D, $82, $CD, $3F, $97, $82, $CF, $18
	dc.b	$40, $CE, $A2, $15, $9E, $3A, $04, $52, $85, $16, $72, $0A, $76, $0A, $3F, $36, $8B, $E8, $40, $56, $72, $85, $9C, $75, $67, $B7, $40, $8A, $50, $A2, $CE, $41
	dc.b	$4E, $C1, $66, $92, $F5, $35, $0C, $E1, $26, $CF, $69, $16, $7E, $81, $14, $A1, $45, $9C, $82, $9D, $82, $8F, $DD, $A9, $6E, $A5, $B0, $12, $68, $D8, $EE, $D8
	dc.b	$E8, $11, $4A, $14, $59, $C8, $29, $D8, $28, $FE, $59, $6C, $75, $36, $C2, $4D, $14, $63, $B8, $E8, $11, $4A, $14, $59, $C8, $29, $D8, $28, $FF, $DC, $33, $F2
	dc.b	$11, $9D, $14, $D9, $9F, $9F, $DF, $67, $AF, $D6, $1D, $B7, $4F, $3E, $24, $50, $26, $48, $A2, $53, $51, $01, $75, $AC, $BF, $39, $AC, $F5, $9E, $4B, $3C, $E7
	dc.b	$29, $E7, $ED, $99, $AA, $EF, $9C, $D0, $A6, $65, $24, $17, $33, $E6, $73, $F6, $CC, $26, $49, $98, $45, $CB, $33, $20, $9C, $6C, $B3, $42, $B3, $4F, $3E, $17
	dc.b	$45, $14, $6C, $52, $41, $24, $57, $59, $33, $C4, $D9, $E0, $A3, $3C, $4D, $9E, $26, $CF, $03, $66, $78, $08, $AC, $F1, $36, $78, $C9, $9E, $0A, $33, $C0, $45
	dc.b	$67, $82, $AC, $F1, $36, $78, $D8, $33, $C2, $49, $9E, $26, $CF, $01, $9E, $1B, $01, $9E, $1B, $01, $9E, $1B, $01, $9E, $1B, $01, $9E, $1B, $08, $CF, $0D, $84
	dc.b	$67, $86, $C0, $67, $86, $78, $0C, $F6, $C4, $06, $7B, $62, $15, $9E, $D8, $80, $CF, $6C, $40, $67, $B6, $20, $33, $DB, $10, $19, $ED, $88, $0C, $F0, $CF, $0A
	dc.b	$D6, $67, $80, $D6, $67, $F5, $8B, $33, $C3, $62, $CC, $FC, $B5, $99, $F9, $6B, $33, $C0, $6B, $33, $C0, $67, $86, $FD, $CF, $5E, $DD, $56, $1F, $93, $0F, $62
	dc.b	$8B, $67, $29, $20, $F6, $1E, $83, $C3, $76, $81, $D5, $B0, $10, $72, $DD, $A4, $5A, $DD, $A6, $D1, $D9, $15, $92, $CC, $F2, $64, $56, $7B, $06, $0D, $DA, $19
	dc.b	$E3, $65, $0F, $01, $4B, $FE, $EC, $BF, $52, $F0, $11, $43, $F7, $78, $0A, $5E, $32, $6E, $D0, $B1, $FB, $95, $9A, $5B, $F7, $33, $E7, $B4, $F9, $6C, $6C, $52
	dc.b	$CD, $8F, $45, $5B, $0D, $D8, $7E, $6F, $1C, $B3, $F9, $33, $C0, $45, $67, $FC, $D9, $56, $78, $C1, $67, $8C, $20, $67, $8C, $59, $59, $E3, $10, $CF, $19, $33
	dc.b	$D8, $A0, $67, $B7, $E6, $E4, $CF, $CA, $86, $7B, $64, $CF, $E4, $CF, $64, $90, $67, $B6, $4C, $F1, $34, $67, $B0, $42, $CF, $64, $F3, $67, $B0, $52, $CF, $6C
	dc.b	$99, $EC, $85, $19, $ED, $22, $CF, $6C, $99, $E0, $EC, $D8, $84, $2A, $D8, $FD, $DA, $86, $C7, $52, $D8, $89, $A3, $63, $BB, $62, $14, $AB, $62, $32, $67, $81
	dc.b	$B2, $8C, $41, $53, $88, $94, $F1, $1C, $62, $0A, $28, $C4, $04, $90, $C4, $15, $38, $8D, $6B, $61, $7C, $91, $47, $82, $92, $1E, $37, $F0, $52, $7E, $02, $79
	dc.b	$8A, $5C, $C8, $D2, $FA, $D6, $AF, $ED, $E3, $7F, $1B, $FB, $F1, $EF, $C6, $66, $42, $5E, $3D, $A9, $34, $90, $BD, $0A, $48, $D2, $E5, $72, $A5, $FD, $BF, $2F
	dc.b	$7D, $EF, $F9, $79, $A2, $F0, $92, $C9, $24, $76, $2B, $39, $64, $8B, $34, $51, $E7, $BA, $9A, $5D, $17, $7B, $3F, $A2, $9E, $41, $25, $CC, $D4, $F3, $C2, $28
	dc.b	$D8, $A4, $82, $48, $AE, $8B, $1B, $3F, $E6, $EC, $10, $75, $09, $E7, $DE, $71, $C2, $28, $D8, $A4, $82, $48, $AE, $8B, $3F, $5C, $77, $16, $08, $BC, $9F, $2D
	dc.b	$22, $8D, $8A, $48, $24, $8A, $E8, $E3, $D3, $FF, $E3, $CA, $42, $07, $FA, $38, $45, $1B, $14, $90, $49, $15, $D1, $B3, $3C, $2B, $77, $10, $8B, $CE, $4B, $CF
	dc.b	$B2, $28, $D8, $A4, $82, $48, $AE, $8B, $F3, $DB, $A8, $E4, $72, $A2, $07, $33, $B7, $08, $A3, $62, $92, $09, $22, $BA, $3F, $B9, $E5, $BF, $F1, $0B, $D4, $77
	dc.b	$F6, $45, $1B, $14, $90, $49, $15, $D1, $7F, $DD, $A8, $EF, $3E, $57, $2F, $F4, $70, $8A, $36, $29, $20, $92, $2B, $A3, $6E, $CD, $D8, $7F, $A0, $27, $51, $62
	dc.b	$BE, $5C, $22, $8D, $8A, $48, $24, $8A, $E8, $F2, $CF, $F9, $BF, $FC, $73, $2F, $25, $3C, $F0, $8A, $36, $29, $20, $92, $2B, $A3, $F9, $B2, $CE, $D0, $83, $A8
	dc.b	$4F, $31, $DC, $C7, $08, $A3, $62, $92, $09, $22, $BA, $3E, $82, $33, $F2, $7A, $A7, $99, $EE, $6D, $C2, $28, $D8, $A4, $82, $48, $AE, $8F, $EE, $F6, $B6, $3A
	dc.b	$85, $1C, $F9, $CF, $BF, $B2, $28, $D8, $A4, $82, $48, $AE, $8E, $3F, $76, $8A, $3C, $94, $F3, $2C, $BB, $EE, $8A, $36, $29, $20, $92, $2B, $AC, $99, $E2, $7E
	dc.b	$45, $25, $CC, $D4, $73, $BA, $28, $D8, $A4, $82, $48, $AE, $B2, $DB, $24, $28, $A3, $F4, $A6, $45, $42, $7B, $22, $94, $53, $20, $92, $D6, $EA, $97, $E3, $DC
	dc.b	$A2, $8F, $75, $0A, $69, $E2, $47, $F6, $D3, $BD, $3D, $CD, $E9, $FB, $61, $7A, $7F, $1B, $F2, $FF, $F6, $BF, $1E, $FC, $7B, $F1, $EF, $C7, $BF, $1E, $37, $F1
	dc.b	$BD, $F5, $C7, $8F, $6B, $EB, $5A, $D6, $B5, $7F, $F3, $FF, $D8, $7F, $98, $FF, $5B, $2F, $DB, $6B, $5A, $FF, $BF, $FD, $BF, $ED, $FF, $6F, $FB, $6B, $5A, $FF
	dc.b	$B7, $F9, $87, $F5, $8F, $ED, $B2, $BE, $B5, $AD, $1A, $E7, $C5, $4E, $73, $AE, $59, $8A, $EF, $9D, $F7, $A0, $BE, $54, $9D, $CD, $38, $BD, $37, $AE, $7C, $54
	dc.b	$E7, $3A, $E5, $98, $AE, $F9, $DF, $7A, $0B, $E5, $49, $DC, $D3, $F3, $D3, $BD, $05, $69, $3A, $E7, $C5, $4E, $73, $AE, $59, $8A, $EF, $9D, $F7, $A0, $BE, $54
	dc.b	$1D, $3F, $EF, $3A, $E7, $C5, $4E, $73, $AE, $59, $8A, $EF, $9D, $F7, $A0, $BE, $54, $15, $A5, $CD, $0D, $68, $2F, $4D, $EB, $98, $AD, $0D, $4E, $75, $A0, $AE
	dc.b	$55, $A5, $78, $AD, $2F, $C5, $68, $2F, $95, $68, $6E, $69, $5A, $4E, $F4, $15, $A7, $FC, $3F, $E1, $FF, $0F, $F8, $7F, $C3, $FE, $1F, $F0, $FF, $85, $68, $2B
	dc.b	$9C, $EB, $4A, $9C, $CD, $69, $96, $62, $B4, $E3, $3A, $D3, $8A, $56, $99, $50, $56, $97, $34, $35, $A0, $BD, $37, $AE, $63, $F3, $C6, $A7, $3F, $CB, $8A, $E5
	dc.b	$98, $AE, $F9, $DF, $7A, $0B, $E5, $49, $DC, $D3, $F3, $D3, $BD, $05, $69, $D3, $FE, $E2, $B9, $66, $2B, $BE, $77, $DE, $82, $F9, $50, $74, $FF, $BD, $68, $2B
	dc.b	$9C, $FF, $2F, $53, $9C, $EB, $96, $62, $BB, $E7, $7D, $E8, $2F, $95, $07, $4F, $FB, $CE, $B9, $8F, $CF, $1A, $9C, $FF, $2E, $2B, $96, $62, $BB, $E7, $7D, $E8
	dc.b	$2F, $95, $27, $73, $4E, $2F, $49, $F4, $FF, $B8, $AE, $59, $8A, $EF, $9D, $F7, $A0, $BE, $54, $9D, $CD, $38, $BD, $27, $5A, $0A, $E7, $3F, $CB, $D4, $E7, $3A
	dc.b	$E5, $98, $AE, $F9, $DF, $7A, $0B, $E5, $49, $DC, $D3, $8B, $D2, $60
Control_layout_table: ; 6 pointers to control scheme display data, one per control type
	dc.l	Control_layout_type_1
	dc.l	Control_layout_type_2
	dc.l	Control_layout_type_3
	dc.l	Control_layout_type_4
	dc.l	Control_layout_type_5
	dc.l	Control_layout_type_6
Control_layout_type_1: ; Control type A: SHIFT DOWN/UP on C/A
	dc.b	$00, $04
	dc.l	Control_layout_type_1_header
	dc.l	Control_layout_type_1_shift_dn
	dc.l	Control_layout_type_1_shift_up
	dc.l	Control_layout_type_1_brake
	dc.l	Control_layout_type_1_accel
Control_layout_type_1_header:
	dc.b	$E2, $B2, $FB, $07, $C0, $0A, $FF, $00
Control_layout_type_1_shift_dn:
	dc.b	$E8, $86
	txt "SHIFT", $FA
	txt "DOWN", $FA, $FF
Control_layout_type_1_shift_up:
	dc.b	$EB, $86
	txt "SHIFT", $FA
	txt "UP", $FA, $FA, $FA, $FF
Control_layout_type_1_brake:
	dc.b	$EB, $B2, $FA, $FA, $FA, $FA, $FA, $FA
	txt "BRAKE", $FF
Control_layout_type_1_accel:
	dc.b	$EA, $B2
	txt "ACCELERATOR", $FF
Control_layout_type_2: ; Control type B
	dc.b	$00, $04
	dc.l	Control_layout_type_2_header
	dc.l	Control_layout_type_2_shift_dn
	dc.l	Control_layout_type_2_shift_up
	dc.l	Control_layout_type_2_brake
	dc.l	Control_layout_type_2_accel
Control_layout_type_2_header:
	dc.b	$E2, $B2, $FB, $07, $C0, $0B, $FF, $00
Control_layout_type_2_shift_dn:
	dc.b	$E8, $86, $1C, $11, $12, $0F, $1D, $FA, $1E, $19, $FA, $FA, $FA, $FF
Control_layout_type_2_shift_up:
	dc.b	$EB, $86, $1C, $11, $12, $0F, $1D, $FA, $0D, $18, $20, $17, $FA, $FF
Control_layout_type_2_brake:
	dc.b	$EB, $B2, $FA, $FA, $FA, $FA, $FA, $FA, $0B, $1B, $0A, $14, $0E, $FF
Control_layout_type_2_accel:
	dc.b	$EA, $B2, $0A, $0C, $0C, $0E, $15, $0E, $1B, $0A, $1D, $18, $1B, $FF
Control_layout_type_3: ; Control type C
	dc.b	$00, $04
	dc.l	Control_layout_type_3_header
	dc.l	Control_layout_type_3_shift_dn
	dc.l	Control_layout_type_3_shift_up
	dc.l	Control_layout_type_3_brake
	dc.l	Control_layout_type_3_accel
Control_layout_type_3_header:
	dc.b	$E2, $B2, $FB, $07, $C0, $0C, $FF, $00
Control_layout_type_3_shift_dn:
	dc.b	$E8, $86, $1C, $11, $12, $0F, $1D, $FA, $0D, $18, $20, $17, $FA, $FF
Control_layout_type_3_shift_up:
	dc.b	$EB, $86, $1C, $11, $12, $0F, $1D, $FA, $1E, $19, $FA, $FA, $FA, $FF
Control_layout_type_3_brake:
	dc.b	$EB, $B2, $0A, $0C, $0C, $0E, $15, $0E, $1B, $0A, $1D, $18, $1B, $FF
Control_layout_type_3_accel:
	dc.b	$EA, $B2, $FA, $FA, $FA, $FA, $FA, $FA, $0B, $1B, $0A, $14, $0E, $FF
Control_layout_type_4: ; Control type D
	dc.b	$00, $04
	dc.l	Control_layout_type_4_header
	dc.l	Control_layout_type_4_shift_dn
	dc.l	Control_layout_type_4_shift_up
	dc.l	Control_layout_type_4_brake
	dc.l	Control_layout_type_4_accel
Control_layout_type_4_header:
	dc.b	$E2, $B2, $FB, $07, $C0, $0D, $FF, $00
Control_layout_type_4_shift_dn:
	dc.b	$E8, $86, $1C, $11, $12, $0F, $1D, $FA, $1E, $19, $FA, $FA, $FA, $FF
Control_layout_type_4_shift_up:
	dc.b	$EB, $86, $1C, $11, $12, $0F, $1D, $FA, $0D, $18, $20, $17, $FA, $FF
Control_layout_type_4_brake:
	dc.b	$EB, $B2, $0A, $0C, $0C, $0E, $15, $0E, $1B, $0A, $1D, $18, $1B, $FF
Control_layout_type_4_accel:
	dc.b	$EA, $B2, $FA, $FA, $FA, $FA, $FA, $FA, $0B, $1B, $0A, $14, $0E, $FF
Control_layout_type_5: ; Control type E
	dc.b	$00, $04
	dc.l	Control_layout_type_5_header
	dc.l	Control_layout_type_5_shift_dn
	dc.l	Control_layout_type_5_shift_up
	dc.l	Control_layout_type_5_brake
	dc.l	Control_layout_type_5_accel
Control_layout_type_5_header:
	dc.b	$E2, $B2, $FB, $07, $C0, $0E, $FF, $00
Control_layout_type_5_shift_dn:
	dc.b	$E8, $86, $0B, $1B, $0A, $14, $0E, $FA, $FA, $FA, $FA, $FA, $FA, $FF
Control_layout_type_5_shift_up:
	dc.b	$EB, $86, $0A, $0C, $0C, $0E, $15, $0E, $1B, $0A, $1D, $18, $1B, $FF
Control_layout_type_5_brake:
	dc.b	$EB, $B2, $FA, $1C, $11, $12, $0F, $1D, $FA, $0D, $18, $20, $17, $FF
Control_layout_type_5_accel:
	dc.b	$EA, $B2, $FA, $FA, $FA, $1C, $11, $12, $0F, $1D, $FA, $1E, $19, $FF
Control_layout_type_6: ; Control type F
	dc.b	$00, $04
	dc.l	Control_layout_type_6_header
	dc.l	Control_layout_type_6_shift_dn
	dc.l	Control_layout_type_6_shift_dn_b-2
	dc.l	Control_layout_type_6_brake
	dc.l	Control_layout_type_6_brake_b-2
Control_layout_type_6_header:
	dc.l	$E2B2FB07
	dc.l	$C00FFF00
Control_layout_type_6_shift_dn:
	dc.l	$E8860A0C
	dc.l	$0C0E150E
	dc.l	$1B0A1D18
	dc.l	$1BFFEB86
;Control_layout_type_6_shift_dn_b
Control_layout_type_6_shift_dn_b:
	dc.l	$0B1B0A14
	dc.l	$0EFAFAFA
	dc.l	$FAFAFAFF
Control_layout_type_6_brake:
	dc.l	$EBB41C11
	dc.l	$120F1DFA
	dc.l	$0D182017
	dc.l	$FF00EAB2
;Control_layout_type_6_brake_b
Control_layout_type_6_brake_b:
	dc.l	$FAFAFA1C
	dc.l	$11120F1D
	dc.l	$FA1E19FF
Options_jp_text_table: ; 2 pointers to Japanese text tilemap blocks for options screen
	dc.l	Options_jp_text_1
	dc.l	Options_jp_text_2
Options_jp_text_1:
	dc.l	$E328FB07
	dc.l	$C017181B
	dc.l	$160A15FF
Options_jp_text_2:
	dc.l	$E328FB07
	dc.l	$C00E0A1C
	dc.l	$22FAFAFF
Options_en_text_table: ; 2 pointers to English text tilemap blocks for options screen
	dc.l	Options_en_text_1
	dc.l	Options_en_text_2-2
Options_en_text_1:
	dc.l	$E3A8FB07
	dc.l	$C0130A19
	dc.l	$0A170E1C
	dc.l	$0EFFE3A8
;Options_en_text_2
Options_en_text_2:
	dc.l	$FB07C00E
	dc.l	$17101512
	dc.l	$1C11FAFF
Race_quotes_table: ; 15 pointers to race quote text strings displayed during race results
	dc.l	Race_quote_1
	dc.l	Race_quote_2
	dc.l	Race_quote_3
	dc.l	Race_quote_4
	dc.l	Race_quote_5
	dc.l	Race_quote_6
	dc.l	Race_quote_7
	dc.l	Race_quote_8
	dc.l	Race_quote_9
	dc.l	Race_quote_10
	dc.l	Race_quote_11
	dc.l	Race_quote_12
	dc.l	Race_quote_13
	dc.l	Race_quote_14
	dc.l	Race_quote_15
Race_quote_1:
	dc.b	$E4, $28, $FB, $07, $C0
	txt '"EXTREME', $FA
	txt 'TENSION"', $FA, $FF
Race_quote_2:
	dc.b	$E4, $28, $FB, $07, $C0, $27, $1D, $11, $0E, $FA, $0C, $11, $0E, $0C, $14, $0E, $1B, $FA, $0F, $15, $0A, $10, $27, $FF
Race_quote_3:
	dc.b	$E4, $28, $FB, $07, $C0, $27, $1D, $11, $0E, $FA, $11, $0E, $0A, $1D, $FA, $20, $0A, $1F, $0E, $1C, $27, $FA, $FA, $FF
Race_quote_4:
	dc.b	$E4, $28, $FB, $07, $C0, $27, $0A, $FA, $0B, $1B, $0E, $0A, $14, $27, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FF
Race_quote_5:
	dc.b	$E4, $28, $FB, $07, $C0, $27, $1A, $1E, $0A, $15, $12, $0F, $22, $27, $FA, $FA, $FA, $FA, $FA, $FA, $FF, $00
Race_quote_6:
	dc.b	$E4, $28, $FB, $07, $C0, $27, $0F, $01, $FA, $10, $1B, $0A, $17, $0D, $FA, $19, $1B, $12, $21, $27, $FF, $00
Race_quote_7:
	dc.b	$E4, $28, $FB, $07, $C0, $27, $0A, $1D, $FA, $0A, $FA, $15, $18, $1C, $1C, $27, $FA, $FA, $FA, $FA, $FF, $00
Race_quote_8:
	dc.b	$E4, $28, $FB, $07, $C0, $27, $1C, $1E, $19, $0E, $1B, $FA, $15, $12, $0C, $0E, $17, $1C, $0E, $27, $FF, $00
Race_quote_9:
	dc.b	$E4, $28, $FB, $07, $C0, $27, $0E, $21, $11, $0A, $1E, $1C, $1D, $FA, $0F, $1E, $16, $0E, $1C, $27, $FF, $00
Race_quote_10:
	dc.b	$E4, $28, $FB, $07, $C0, $27, $0C, $18, $17, $0C, $0E, $17, $1D, $1B, $0A, $1D, $12, $18, $17, $27, $FA, $FF
Race_quote_11:
	dc.b	$E4, $28, $FB, $07, $C0, $27, $1D, $11, $0E, $FA, $0B, $12, $1D, $1D, $0E, $1B, $17, $0E, $1C, $1C, $27, $FF
Race_quote_12:
	dc.b	$E4, $28, $FB, $07, $C0, $27, $12, $16, $19, $0A, $1D, $12, $0E, $17, $0C, $0E, $27, $FA, $FA, $FA, $FA, $FF
Race_quote_13:
	dc.b	$E4, $28, $FB, $07, $C0, $27, $0C, $18, $17, $1D, $0E, $17, $1D, $16, $0E, $17, $1D, $27, $FA, $FA, $FF, $00
Race_quote_14:
	dc.b	$E4, $28, $FB, $07, $C0, $27, $11, $18, $15, $0D, $FA, $12, $17, $FA, $0C, $11, $0E, $0C, $14, $27, $FA, $FA, $FF, $00
Race_quote_15:
	dc.b	$E4, $28, $FB, $07, $C0, $27, $1D, $11, $0E, $16, $0E, $FA, $18, $0F, $FA, $16, $18, $17, $0A, $0C, $18, $27, $FF, $00
Race_quote_index_table: ; Maps race-result index to quote index; $00 = no quote
	dc.b	$01, $02, $04, $05, $06, $07, $08, $09, $0A, $0E, $10, $11, $12, $16, $1B, $1C, $1E
	dc.b	$00
Championship_intro_text_table: ; 6 pointers to championship intro screen text records
	dc.l	Championship_intro_text_1
	dc.l	Championship_intro_text_2
	dc.l	Championship_intro_text_5
	dc.l	Championship_intro_text_4
	dc.l	Championship_intro_text_6
	dc.l	Championship_intro_text_3
Championship_intro_text_1:
	dc.b	$E5, $28, $FB, $07, $C0, $27, $14, $0E, $0E, $19, $FA, $12, $1D, $FA, $1E, $19, $2D, $27, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FF
Championship_intro_text_2:
	dc.b	$E5, $28, $FB, $07, $C0, $27, $0C, $26, $16, $18, $17, $2D, $27, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FF
Championship_intro_text_3:
	dc.b	$E5, $28, $FB, $07, $C0, $27, $17, $18, $20, $FA, $12, $1D, $26, $1C, $FA, $1E, $19, $FA, $1D, $18, $FA, $22, $18, $1E, $27, $FF
Championship_intro_text_4:
	dc.b	$E5, $28, $FB, $07, $C0, $27, $10, $18, $18, $0D, $FA, $15, $1E, $0C, $14, $2D, $27, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FF
Championship_intro_text_5:
	dc.b	$E5, $28, $FB, $07, $C0, $27, $0F, $12, $17, $0A, $15, $FA, $15, $0A, $19, $2D, $27, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FF
Championship_intro_text_6:
	dc.b	$E5, $28, $FB, $07, $C0, $27, $17, $12, $0C, $0E, $FA, $0D, $1B, $12, $1F, $12, $17, $26, $27, $FA, $FA, $FA, $FA, $FA, $FA, $FF
Championship_intro_sequence: ; Sequence of championship intro text indices
	dc.b	$01, $02, $03, $05, $06, $04
Championship_intro_text_block: ; Full text block for championship intro screen (options, controls, voice title)
	dc.b	$E1, $96, $FB, $07, $C0, $FA, $FA, $FA, $FA, $18, $19, $1D, $12, $18, $17, $1C, $FC, $FB, $27, $C0, $0C, $18, $17, $1D, $1B, $18, $15, $FB, $07, $C0, $FA, $FA
	dc.b	$1D, $22, $19, $0E, $FD, $FB, $27, $C0, $15, $0E, $1F, $0E, $15, $FD, $15, $0A, $17, $10, $1E, $0A, $10, $0E, $FD, $0B, $29, $10, $29, $16, $29, $FD, $1C, $29
	dc.b	$0E, $29, $FD, $1F, $18, $12, $0C, $0E, $FD, $0E, $21, $12, $1D, $FC, $FC, $FC, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FA, $FA
	dc.b	$FA, $FA, $FA, $FB, $07, $C0, $19, $12, $1D, $FA, $12, $17, $FF, $00
Options_screen_cram_data: ; VDP CRAM/scroll init stream for Options screen championship variant
	dc.b	$60, $0F, $00, $00, $00, $00, $0E, $8A, $0A, $68, $00, $EE, $00, $00, $02, $22, $04, $44, $06, $66, $08, $88, $0A, $AA, $0C, $CC, $0E, $EE, $04, $4E, $0C, $44
	dc.b	$0E, $88
Options_screen_champ_tilemap: ; Tilemap for Options/championship intro screen (used with Decompress_tilemap_to_vdp_64_cell_rows)
	dc.b	$07, $03, $00, $00, $00, $03, $06, $78, $06, $78, $06, $02, $00, $17, $DF, $E2, $82, $01, $3E, $FA, $1C, $50, $40, $20, $25, $01, $09, $94, $04, $E2, $82, $01
	dc.b	$34, $53, $5C, $50, $40, $26, $8A, $6B, $8A, $08, $04, $D1, $4D, $71, $41, $00, $9A, $2A, $50, $13, $8A, $08, $04, $D0, $69, $06, $D7, $14, $10, $0A, $50, $10
	dc.b	$06, $00, $94, $04, $E2, $82, $80, $4F, $80, $CF, $80, $F1, $80, $E0, $3F, $80
Options_screen_champ_tiles: ; Compressed tiles for Options/championship intro screen background
	dc.b	$00, $45, $82, $37, $75, $78, $F4, $83, $06, $36, $17, $71, $26, $34, $36, $33, $47, $72, $57, $6F, $68, $F6, $74, $07, $84, $05, $13, $85, $03, $02, $15, $15
	dc.b	$26, $35, $37, $76, $48, $F5, $78, $F7, $86, $03, $00, $14, $08, $26, $2E, $36, $2F, $48, $F3, $77, $6E, $87, $03, $01, $15, $14, $27, $70, $37, $78, $88, $04
	dc.b	$06, $15, $16, $27, $73, $89, $05, $12, $16, $32, $28, $F2, $77, $74, $8A, $06, $30, $17, $77, $8B, $06, $31, $FF, $F4, $F4, $F4, $F4, $EB, $9F, $5C, $FA, $E7
	dc.b	$D7, $3F, $4F, $4F, $4F, $47, $77, $7E, $B9, $F5, $CF, $AE, $7D, $73, $EB, $9F, $5C, $FA, $E7, $D5, $DD, $DD, $DD, $DD, $F3, $FF, $A3, $BB, $BB, $BB, $BC, $DE
	dc.b	$6F, $37, $9B, $CF, $88, $E5, $32, $CE, $EE, $FC, $85, $38, $8A, $5A, $46, $DF, $C9, $6F, $F4, $BB, $F2, $83, $B0, $E1, $CC, $F3, $E9, $D3, $A6, $4D, $27, $E3
	dc.b	$FD, $6E, $1F, $D8, $E9, $D3, $A6, $4D, $26, $95, $A4, $D2, $69, $34, $9F, $77, $F6, $29, $D3, $A7, $49, $34, $9A, $4D, $2B, $49, $A4, $D2, $69, $3C, $54, $69
	dc.b	$4B, $EB, $97, $3E, $1D, $3A, $49, $BF, $B2, $D2, $69, $34, $9A, $4E, $E8, $6F, $BA, $A3, $8F, $3A, $42, $FE, $4D, $8F, $42, $81, $FD, $CB, $BB, $BA, $1B, $E2
	dc.b	$A3, $4B, $18, $43, $6C, $AC, $61, $3B, $BB, $FB, $4F, $7C, $F7, $CF, $88, $D2, $6F, $CB, $FA, $9B, $4F, $7C, $DD, $DD, $DD, $DD, $F7, $8D, $E1, $B9, $0B, $66
	dc.b	$2D, $2D, $05, $B2, $D0, $16, $9C, $B6, $06, $D9, $4C, $5B, $C9, $A5, $6C, $9A, $5D, $DA, $4C, $7F, $55, $93, $1F, $CD, $C8, $86, $3F, $9B, $96, $AD, $86, $32
	dc.b	$D5, $BA, $7F, $63, $29, $CB, $F1, $98, $64, $C7, $09, $FF, $26, $C6, $74, $E7, $FE, $64, $1B, $26, $BB, $0C, $7B, $AC, $87, $93, $49, $A4, $D9, $34, $BF, $B1
	dc.b	$26, $2C, $6C, $58, $B1, $63, $60, $C5, $A9, $CC, $78, $46, $C0, $82, $11, $62, $08, $FF, $C3, $16, $2C, $5A, $8C, $58, $B1, $B7, $FD, $F8, $02, $28, $08, $20
	dc.b	$C1, $04, $11, $40, $44, $B1, $EF, $FF, $86, $2C, $58, $B5, $18, $B1, $62, $DF, $F7, $04, $10, $45, $01, $04, $18, $20, $82, $0E, $3F, $AA, $C4, $E2, $7F, $71
	dc.b	$26, $90, $63, $CC, $8F, $C7, $16, $2C, $57, $E7, $FC, $2F, $C7, $FE, $78, $70, $5F, $9E, $44, $18, $AC, $10, $41, $06, $40, $82, $0C, $7E, $7D, $37, $97, $E3
	dc.b	$FF, $3C, $9B, $26, $FC, $F2, $12, $63, $08, $D8, $1C, $15, $81, $C3, $26, $21, $BC, $8C, $4A, $C4, $23, $CC, $EB, $E5, $6A, $02, $29, $CC, $1C, $3F, $73, $6F
	dc.b	$2F, $0D, $22, $30, $C8, $CC, $2C, $3C, $EB, $21, $F9, $D8, $AB, $0F, $CE, $DC, $84, $F3, $06, $68, $68, $66, $45, $78, $CD, $81, $85, $B7, $31, $40, $8D, $BC
	dc.b	$0C, $A8, $1A, $98, $4A, $80, $B1, $77, $77, $75, $EC, $16, $F1, $57, $36, $93, $71, $16, $C9, $B8, $D1, $B2, $3B, $03, $69, $31, $D8, $53, $98, $D8, $16, $36
	dc.b	$1B, $0A, $73, $1B, $02, $C6, $C0, $E1, $2D, $7F, $19, $E4, $6B, $F8, $C9, $1C, $AA, $D2, $A3, $1A, $E1, $C1, $85, $71, $FD, $56, $30, $A5, $71, $B9, $AE, $37
	dc.b	$EA, $65, $0A, $92, $32, $85, $E2, $50, $85, $1A, $50, $A0, $FE, $6E, $17, $94, $2B, $CC, $1C, $2E, $2A, $FD, $61, $16, $82, $D1, $E0, $18, $54, $8A, $05, $48
	dc.b	$C8, $1B, $D9, $06, $18, $43, $20, $D7, $D4, $B0, $57, $10, $71, $8C, $4D, $D2, $EF, $8F, $F5, $A5, $8D, $F8, $E1, $2C, $37, $6E, $DD, $BA, $31, $89, $61, $2C
	dc.b	$70, $C6, $5D, $C6, $11, $88, $C3, $F7, $7D, $F1, $C3, $11, $8E, $ED, $DB, $B7, $02, $08, $20, $DE, $41, $6F, $32, $C7, $CD, $A9, $79, $62, $AF, $63, $5B, $D8
	dc.b	$2C, $2F, $31, $26, $A0, $58, $49, $A9, $5C, $0C, $1D, $64, $3F, $3B, $D9, $87, $E7, $75, $06, $EC, $24, $C5, $85, $4D, $C5, $AE, $FC, $EC, $73, $3F, $D6, $42
	dc.b	$83, $5B, $98, $C1, $60, $9A, $5D, $FF, $19, $20, $A5, $8F, $E3, $24, $42, $18, $62, $6F, $9C, $BC, $E4, $D3, $BA, $D9, $5C, $DE, $2E, $2C, $5A, $E2, $D4, $BF
	dc.b	$C5, $CC, $29, $05, $85, $01, $B0, $A0, $31, $C0, $11, $40, $8E, $60, $D7, $33, $08, $E8, $08, $AE, $86, $E5, $A5, $EB, $43, $72, $D2, $F5, $98, $A7, $31, $B4
	dc.b	$51, $A9, $C4, $16, $2C, $78, $8A, $35, $38, $C7, $8D, $2E, $23, $48, $20, $E8, $10, $20, $83, $1C, $22, $91, $4B, $AC, $81, $B8, $D9, $06, $50, $D9, $02, $CA
	dc.b	$1B, $21, $4A, $C3, $18, $3D, $82, $A2, $B8, $8B, $21, $C0, $59, $51, $11, $92, $3A, $8E, $C3, $09, $35, $DD, $F1, $EF, $FA, $CC, $31, $1E, $E1, $58, $28, $42
	dc.b	$4D, $58, $59, $1A, $C7, $79, $05, $76, $38, $0A, $DD, $88, $A8, $31, $A8, $20, $8A, $82, $08, $5B, $B7, $7F, $99, $5E, $82, $BD, $0D, $63, $DF, $D4, $56, $EE
	dc.b	$1B, $B7, $04, $10, $42, $A1, $04, $10, $F7, $F7, $FF, $32, $FF, $BD, $E4, $34, $BF, $AC, $7C, $CA, $0C, $82, $8A, $8E, $C0, $FB, $9F, $73, $77, $A8, $FC, $E8
	dc.b	$56, $95, $E9, $A4, $7B, $06, $29, $AA, $26, $75, $B9, $4F, $DE, $64, $76, $06, $63, $85, $E5, $09, $D2, $14, $19, $C1, $08, $C4, $E1, $1B, $E6, $7F, $CD, $3D
	dc.b	$DB, $A7, $FE, $62, $08, $20, $C1, $04, $18, $20, $83, $79, $06, $F2, $0F, $9C, $F7, $4F, $74, $EF, $37, $AD, $2E, $47, $48, $2B, $3B, $96, $60, $A3, $99, $0B
	dc.b	$90, $AF, $20, $8B, $EC, $A0, $E6, $14, $72, $A8, $DE, $86, $F0, $BD, $93, $BF, $F5, $AB, $08, $76, $08, $21, $AC, $21, $AC, $C2, $1A, $CE, $A1, $05, $3E, $C1
	dc.b	$4F, $5D, $AB, $3F, $EA, $CF, $FA, $B3, $ED, $13, $57, $90, $82, $82, $08, $50, $41, $08, $28, $20, $85, $04, $10, $82, $82, $0C, $10, $45, $41, $04, $21, $40
	dc.b	$42, $14, $04, $21, $E0, $21, $C2, $E5, $C0, $6C, $10, $A0, $E3, $5A, $0D, $3F, $EF, $FD, $78, $E1, $1A, $18, $E4, $1D, $DF, $DB, $FE, $FB, $9D, $DD, $DD, $FF
	dc.b	$8E, $2B, $FD, $70, $B6, $8F, $E3, $E9, $1C, $39, $41, $F6, $0E, $FF, $D5, $8F, $F2, $C7, $A8, $44, $7A, $8A, $0F, $5E, $03, $58, $E1, $DB, $61, $41, $58, $9E
	dc.b	$E9, $EE, $9E, $E9, $EE, $9C, $2F, $39, $FF, $98, $CD, $5E, $41, $BA, $70, $7C, $FF, $69, $79, $05, $5C, $41, $0A, $08, $22, $A0, $82, $2B, $B1, $04, $57, $8C
	dc.b	$C8, $AE, $95, $DF, $FF, $45, $EC, $5D, $DD, $DD, $DD, $F7, $CF, $7C, $F7, $CF, $7C, $F7, $CF, $7C, $FD, $76, $9E, $DE, $B3, $D3, $B7, $2D, $77, $84, $EE, $E1
	dc.b	$5E, $42, $0A, $F4, $15, $FA, $85, $15, $3F, $D5, $04, $6A, $0B, $BF, $15, $41, $98, $23, $95, $37, $97, $77, $77, $D8, $53, $5D, $01, $15, $CE, $95, $E5, $45
	dc.b	$BD, $8B, $BB, $DE, $41, $0A, $F2, $0D, $E4, $10, $BF, $AD, $A8, $42, $B1, $D8, $3B, $F1, $33, $AE, $61, $4F, $95, $76, $9E, $6B, $49, $BC, $DE, $6F, $37, $77
	dc.b	$77, $77, $79, $BE, $D3, $E5, $F9, $47, $77, $77, $7F, $69, $BF, $F5, $1D, $DD, $DD, $C0
	dc.b	$C5, $14, $FB, $C7, $C0, $22, $18, $1E, $FA, $11, $0A, $1F, $0E, $FA, $20, $18, $17, $FA, $1D, $11, $0E, $FA, $20, $18, $1B, $15, $0D, $FC, $0C, $11, $0A, $16
	dc.b	$19, $12, $18, $17, $1C, $11, $12, $19, $FA, $1D, $12, $1D, $15, $0E, $29, $FA, $FA, $FA, $FA, $FC, $0F, $1B, $18, $16, $FA, $17, $18, $20, $FA, $18, $17, $2A
	dc.b	$FA, $22, $18, $1E, $FA, $16, $1E, $1C, $1D, $FC, $0D, $0E, $0F, $0E, $17, $0D, $FA, $1D, $11, $0E, $FA, $1D, $12, $1D, $15, $0E, $29, $29, $29, $FF, $C5, $98
	dc.b	$FB, $C7, $C0, $FA, $1D, $11, $0A, $17, $14, $FA, $22, $18, $1E, $FA, $0F, $18, $1B, $FC, $19, $15, $0A, $22, $12, $17, $10, $FA, $18, $1E, $1B, $FA, $10, $0A
	dc.b	$16, $0E, $29, $FC, $FC, $FD, $FA, $19, $1B, $0E, $1C, $0E, $17, $1D, $0E, $0D, $FA, $0B, $22, $29, $29, $29, $FF, $00
Championship_driver_select_cram_data: ; VDP CRAM/scroll init stream for Championship driver/team select screen
	dc.b	$20, $2F, $00, $00, $00, $00, $02, $22, $02, $44, $04, $66, $06, $88, $06, $AA, $08, $CC, $0A, $EE, $02, $46, $04, $68, $06, $8A, $06, $AC, $00, $46, $02, $68
	dc.b	$04, $8A, $00, $00, $00, $00, $0E, $EE, $08, $00, $0E, $22, $0E, $64, $0E, $E6, $00, $20, $04, $E2, $00, $E2, $00, $C0, $00, $A2, $00, $82, $00, $42, $0A, $EC
	dc.b	$00, $00, $00, $00, $00, $00, $00, $02, $00, $22, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $02, $00, $00, $00, $00, $02, $22, $00, $00, $00, $22
	dc.b	$00, $00
Championship_team_select_logo_vdp_data: ; 48-entry VDP sprite attribute / nametable table for scrolling championship logo
	dc.l	$0466008A, $02AE0AEE, $0222048A, $00240242, $024404CE, $04680246, $0EEE02AC, $04EE0068, $02440068, $008C08CC, $00000268, $00020020, $002202AC, $02460024, $0CCC008A, $02CC0046, $00220046, $006A06AA, $00000046, $00000000, $0000008A, $00240002, $0AAA0068, $00AA0024, $00000024, $00480488, $00000024, $00000000, $00000068, $00020000, $08880046, $00880002
	dc.l	$00000002, $00260266, $00000002, $00000000, $00000046, $00000000, $06660024, $00660000, $00000000, $00040044, $00000000, $00000000, $00000024, $00000000, $04440002, $00440000
Team_select_car_sprite_frame_a: ; Sprite frame data: team-select car top-left quadrant (object at y=$120, x=$120)
	dc.b	$00, $11, $D8, $0F, $40, $01, $FF, $90, $D8, $0E, $40, $11, $FF, $B0, $F0, $05, $40, $1D, $FF, $C0, $D0, $04, $40, $21, $FF, $C0, $C8, $0E, $40, $23, $FF, $D0
	dc.b	$E0, $04, $40, $2F, $FF, $D0, $B8, $0D, $40, $31, $FF, $E8, $B0, $00, $40, $39, $FF, $F0, $C8, $09, $40, $3A, $FF, $F0, $A8, $0B, $40, $40, $00, $08, $C8, $08
	dc.b	$40, $4C, $00, $08, $A0, $0B, $40, $4F, $00, $20, $C0, $04, $40, $5B, $00, $20, $A8, $0D, $40, $5D, $00, $38, $B8, $04, $40, $65, $00, $38, $A0, $08, $40, $67
	dc.b	$00, $40, $98, $0A, $40, $6A, $00, $58
Team_select_car_sprite_frame_b: ; Sprite frame data: team-select car top-right quadrant (object at y=$120, x=$128)
	dc.b	$00, $0E, $90, $0D, $20, $73, $FF, $E0, $90, $0D, $20, $7B, $00, $00, $A0, $0F, $20, $83, $FF, $D8, $A0, $0E, $20, $93
	dc.b	$00, $08, $A0, $07, $20, $9F, $FF, $F8, $C0, $04, $20, $A7, $FF, $E0, $B8, $00, $20, $A9, $00, $08, $B8, $05, $20, $AA, $00, $10, $C0, $0F, $20, $AE, $FF, $F0
	dc.b	$E0, $0F, $20, $BE, $FF, $F0, $D8, $07, $20, $CE, $FF, $E0
	dc.b	$F8, $04, $20, $D6, $FF, $E0, $D8, $07, $20, $D8, $00, $10
	dc.b	$F8, $04, $20, $E0, $00, $10
Team_select_car_sprite_frame_c: ; Sprite frame data: team-select car bottom-left quadrant (object at y=$F4, x=$148)
	dc.b	$00, $12
	dc.b	$50, $01, $40, $E2, $00, $24, $50, $0E, $40, $E4, $00, $04, $68, $00, $40, $F0, $00, $04, $58, $07, $40, $F1, $FF, $F4, $78, $00, $40, $F9, $FF, $F4, $60, $00
	dc.b	$40, $FA, $FF, $EC, $68, $0B, $40, $FB, $FF, $DC, $80, $00, $41, $07, $FF, $D4, $88, $0B, $41, $08, $FF, $D4, $A8, $0B, $41, $14, $FF, $D4, $C0, $00, $41, $20
	dc.b	$FF, $EC, $C8, $09, $41, $21, $FF, $DC, $D0, $00, $41, $27, $FF, $F4, $D8, $00, $41, $28, $FF, $E4, $D8, $0E, $41, $29, $FF, $EC, $F0, $08, $41, $35, $FF, $F4
	dc.b	$E0, $04, $41, $38, $00, $0C, $E8, $0E, $41, $3A, $00, $0C
Team_select_car_sprite_frame_d: ; Sprite frame data: team-select car bottom-right quadrant (object at y=$14C, x=$148)
	dc.b	$00, $12, $50, $01, $48, $E2, $FF, $D4, $50, $0E, $48, $E4, $FF, $DC, $68, $00, $48, $F0, $FF, $F4
	dc.b	$58, $07, $48, $F1, $FF, $FC, $78, $00, $48, $F9, $00, $04, $60, $00, $48, $FA, $00, $0C, $68, $0B, $48, $FB, $00, $0C, $80, $00, $49, $07, $00, $24, $88, $0B
	dc.b	$49, $08, $00, $14, $A8, $0B, $49, $14, $00, $14, $C0, $00, $49, $20, $00, $0C, $C8, $09, $49, $21, $00, $0C, $D0, $00, $49, $27, $00, $04, $D8, $00, $49, $28
	dc.b	$00, $14, $D8, $0E, $49, $29, $FF, $F4, $F0, $08, $49, $35, $FF, $F4, $E0, $04, $49, $38, $FF, $E4, $E8, $0E, $49, $3A, $FF, $D4
Championship_driver_select_tilemap: ; Tilemap for Championship driver/team select background
	dc.b	$0A, $02, $00, $00, $00, $00, $01, $F7, $DF, $7D, $F7, $DF, $7D, $F7, $DF, $7D, $F7, $DF, $7D, $F7, $DF, $7D, $F4, $80, $7D, $80, $5A, $09, $F4, $41, $40, $0E
	dc.b	$30, $08, $00
	dc.b	$04
	dc.b	$90, $0A, $84, $C0, $4A, $9E, $3A, $E0, $AA, $79, $68, $0A, $A1, $E7, $84, $A1, $E7, $88, $91, $E7, $88, $90, $10, $04, $D9, $E7, $9E, $79, $E7, $9E, $79, $E7
	dc.b	$9E, $79, $E7, $9E, $79, $E7, $9E, $79, $E7, $9E, $79, $E7, $9E, $79, $E6, $FF
Championship_driver_select_tiles: ; Compressed tiles for Championship driver/team select screen
	dc.b	$82, $9C, $80, $03, $00, $14, $05, $25, $16, $36, $36, $46, $38, $57, $76, $67, $7A, $75, $14, $81, $06, $31, $82, $05, $0E, $17, $75, $83, $04, $04, $16, $34
	dc.b	$28, $EF, $84, $04, $02, $16, $33, $28, $F7, $85, $06, $32, $86, $06, $30, $18, $F6, $87, $05, $12, $17, $72, $88, $06, $2E, $18, $EE, $89, $06, $2F, $18, $F3
	dc.b	$8A, $05, $0F, $17, $73, $8B, $05, $15, $17, $78, $8C, $04, $06, $16, $37, $8D, $05, $13, $18, $F2, $8E, $04, $03, $16, $35, $8F, $04, $08, $17, $74, $FF, $A5
	dc.b	$29, $4A, $52, $94, $B5, $DC, $10, $8E, $0A, $E4, $2A, $5A, $E0, $C5, $B5, $C4, $AD, $DA, $57, $5A, $41, $93, $69, $15, $C5, $4A, $52, $94, $A5, $2C, $FF, $4F
	dc.b	$A5, $29, $4A, $52, $CF, $F4, $FA, $0E, $5D, $B4, $2B, $67, $4E, $C5, $44, $F4, $9B, $8B, $A5, $76, $7D, $C5, $72, $B0, $B9, $6E, $10, $0A, $33, $68, $40, $91
	dc.b	$A5, $2D, $D1, $B4, $B2, $43, $6D, $50, $83, $42, $BA, $33, $BB, $95, $28, $5D, $D4, $E1, $BB, $A9, $C4, $7A, $95, $3B, $3F, $D3, $FD, $73, $EC, $FA, $3E, $96
	dc.b	$7F, $A7, $D2, $9D, $9F, $E9, $F4, $A5, $29, $4A, $53, $D3, $FB, $73, $EC, $FA, $52, $94, $E1, $FE, $9F, $4A, $53, $8E, $7D, $B9, $D3, $B3, $D5, $FB, $3F, $67
	dc.b	$D3, $6E, $77, $59, $E3, $20, $EC, $79, $E4, $20, $3E, $BC, $E2, $94, $2E, $D2, $2D, $9F, $CA, $83, $98, $C4, $D1, $79, $CF, $27, $36, $D3, $2C, $2E, $A5, $38
	dc.b	$7F, $A7, $D2, $96, $7F, $A7, $ED, $5C, $E5, $B4, $7A, $45, $4D, $A7, $FA, $FB, $11, $E7, $3A, $5B, $A6, $73, $1E, $23, $BC, $60, $D3, $1B, $84, $76, $26, $34
	dc.b	$E8, $DA, $84, $FD, $0A, $4A, $61, $C3, $A8, $3B, $3B, $4A, $03, $10, $E8, $DC, $5C, $8C, $E9, $FE, $B2, $57, $4B, $DB, $92, $7A, $4A, $7A, $C7, $02, $A7, $13
	dc.b	$32, $E3, $A7, $76, $C5, $2E, $EA, $52, $94, $5C, $62, $9E, $8F, $B6, $34, $C6, $94, $A5, $29, $8D, $31, $ED, $F9, $1A, $52, $94, $17, $53, $B1, $76, $90, $8E
	dc.b	$24, $52, $A3, $FD, $3F, $B3, $EC, $FB, $73, $57, $EC, $F0, $FD, $9E, $BC, $E9, $67, $D9, $F4, $B3, $FD, $3D, $5F, $4F, $4F, $D9, $F4, $F4, $FA, $52, $DC, $EC
	dc.b	$F5, $E7, $67, $AB, $E8, $FE, $CF, $A3, $E8, $FE, $DC, $FB, $3F, $87, $FA, $7D, $1E, $1F, $B7, $3A, $73, $D9, $E1, $FE, $B9, $F1, $FA, $AE, $1F, $B7, $30, $F0
	dc.b	$F5, $E6, $1F, $D9, $FE, $BF, $75, $C7, $3A, $59, $FB, $73, $0F, $DB, $9F, $A7, $FA, $7D, $29, $4A, $07, $FA, $78, $E7, $DB, $98, $7D, $2C, $FA, $2B, $F2, $78
	dc.b	$7F, $E4, $64, $FC, $A5, $3C, $50, $4C, $3E, $72, $7C, $8F, $2E, $61, $F5, $70, $2E, $76, $63, $47, $87, $89, $6F, $7B, $C3, $C3, $53, $87, $96, $3E, $58, $F9
	dc.b	$39, $BD, $26, $DF, $95, $BF, $9A, $BF, $F5, $3C, $D5, $FE, $7A, $2B, $C6, $F3, $72, $F3, $A6, $78, $3E, $CF, $A5, $38, $7F, $A7, $FA, $7F, $A7, $D2, $94, $A5
	dc.b	$29, $E9, $FE, $9F, $4A, $51, $5F, $E9, $F4, $A5, $29, $4A, $53, $B3, $FD, $3F, $D7, $3E, $CF, $A5, $1F, $4A, $50, $3C, $3F, $87, $87, $D2, $DC, $EC, $FA, $2F
	dc.b	$3B, $3F, $87, $FA, $7D, $29, $4F, $4F, $A7, $A7, $D2, $94, $A0, $7E, $CF, $57, $EC, $FA, $52, $94, $A5, $29, $C3, $E9, $E9, $F4, $A5, $1F, $E9, $F4, $D8, $AA
	dc.b	$BE, $DD, $D5, $49, $17, $69, $17, $B7, $52, $B9, $6E, $8F, $C8, $A5, $56, $E2, $B3, $2D, $47, $43, $C6, $EA, $AF, $59, $D9, $07, $EB, $47, $EC, $FC, $84, $E8
	dc.b	$8E, $24, $BF, $C9, $5D, $24, $AE, $93, $83, $D2, $35, $9E, $2E, $B7, $55, $84, $9A, $6F, $02, $38, $6C, $59, $0E, $9B, $63, $78, $91, $C6, $AE, $BE, $2A, $69
	dc.b	$F9, $1C, $91, $CC, $71, $A3, $D9, $C3, $18, $B2, $2B, $6C, $83, $7D, $B4, $64, $A5, $A7, $BC, $0F, $77, $34, $69, $76, $61, $97, $A2, $29, $B2, $E8, $A7, $1B
	dc.b	$84, $1B, $A3, $2C, $23, $70, $C9, $4F, $FA, $53, $97, $6D, $33, $F4, $99, $F0, $81, $24, $5C, $69, $41, $FF, $4A, $52, $94, $A4, $8A, $EE, $10, $46, $76, $CA
	dc.b	$B7, $66, $24, $31, $3A, $8F, $C8, $A1, $0C, $60, $BC, $6C, $C9, $F9, $18, $57, $8B, $94, $98, $3E, $07, $B1, $2C, $D0, $D4, $A2, $85, $95, $70, $F2, $89, $25
	dc.b	$C2, $5B, $34, $57, $B4, $AB, $C4, $7A, $4B, $BB, $4A, $94, $A0, $7F, $0F, $0F, $A6, $DC, $C3, $C7, $30, $F5, $7A, $BF, $B3, $ED, $CD, $79, $8F, $D5, $59, $E1
	dc.b	$EA, $F0, $F1, $CD, $79, $AF, $3D, $9F, $C7, $F2, $AC, $F5, $78, $7F, $A7, $D9, $E1, $E1, $F6, $78, $7D, $39, $D0, $73, $57, $DB, $F5, $5C, $7E, $A8, $3C, $3C
	dc.b	$7E, $A9, $7F, $D4, $3F, $94, $1E, $BC, $F6, $7E, $DC, $C3, $D5, $F4, $1C, $C3, $C3, $F8, $78, $7D, $3F, $94, $BC, $EC, $F5, $7A, $F3, $B3, $FD, $3C, $7F, $29
	dc.b	$5E, $1E, $39, $AF, $31, $FA, $A0, $FB, $3E, $CF, $B7, $EA, $87, $EE, $87, $EA, $83, $C3, $C7, $EE, $A9, $C7, $35, $7A, $FE, $A8, $73, $1C, $EC, $F5, $FE, $57
	dc.b	$AE, $76, $E6, $39, $D9, $F8, $F2, $E3, $1D, $FB, $67, $C3, $FB, $B9, $AD, $65, $E4, $1E, $1F, $70, $F2, $7D, $16, $A8, $AD, $31, $91, $D4, $38, $C6, $2F, $06
	dc.b	$08, $C9, $B0, $72, $BC, $EE, $2C, $3A, $92, $D4, $8D, $70, $3E, $41, $83, $3C, $8C, $B7, $31, $9D, $E7, $87, $9F, $E4, $7A, $7E, $45, $A5, $73, $C6, $3C, $98
	dc.b	$A7, $8F, $35, $61, $CE, $58, $58, $8C, $39, $B5, $43, $15, $8A, $EC, $59, $3F, $F4, $F0, $FB, $86, $4D, $77, $5A, $CF, $A6, $37, $73, $57, $AD, $D4, $FD, $D5
	dc.b	$BF, $B4, $B2, $CC, $3F, $B7, $3B, $4B, $77, $6C, $FF, $D4, $59, $FE, $B9, $F0, $F0, $FD, $89, $FC, $10, $91, $76, $41, $CF, $B6, $B9, $EC, $47, $FD, $40, $FE
	dc.b	$CF, $F4, $FF, $52, $57, $AB, $C2, $10, $7D, $9F, $DB, $9D, $BF, $54, $1F, $98, $FD, $50, $E7, $DB, $9F, $67, $D2, $CF, $F4, $FB, $3F, $D3, $EC, $FB, $3E, $CF
	dc.b	$B3, $E9, $41, $CD, $5F, $6E, $6A, $FA, $7A, $7F, $A7, $D9, $FE, $9F, $E9, $FE, $9E, $1F, $E9, $F6, $78, $7F, $0F, $0F, $B7, $B8, $7C, $B3, $D9, $F2, $CC, $F3
	dc.b	$E1, $F4, $F5, $71, $5C, $B9, $E0, $70, $99, $EF, $33, $D1, $77, $B7, $EF, $02, $30, $4F, $D4, $15, $C4, $C9, $6C, $EB, $0D, $76, $7B, $E8, $13, $7B, $31, $A2
	dc.b	$B5, $9D, $FA, $C0, $CB, $A7, $F3, $2D, $BA, $2B, $68, $D0, $AC, $21, $8F, $41, $AA, $09, $EE, $93, $0C, $68, $AD, $18, $8C, $63, $86, $1D, $E3, $41, $A6, $CD
	dc.b	$08, $3F, $66, $BF, $91, $1F, $A2, $31, $E4, $DB, $62, $D0, $78, $FE, $C9, $03, $BB, $77, $EC, $C1, $06, $E1, $A1, $7F, $58, $9D, $02, $0D, $02, $1E, $E1, $BF
	dc.b	$22, $E0, $90, $D3, $EA, $6E, $65, $72, $C6, $CD, $DE, $19, $5B, $41, $BE, $83, $70, $C1, $17, $70, $C1, $B4, $DC, $23, $92, $1A, $06, $EE, $D1, $93, $74, $1B
	dc.b	$A0, $D1, $52, $DD, $FE, $A0, $27, $0D, $4F, $4E, $0D, $B4, $38, $36, $D0, $9D, $BF, $67, $B2, $2A, $53, $6D, $3B, $22, $A7, $1D, $E3, $4D, $90, $20, $FE, $9E
	dc.b	$DD, $EA, $81, $17, $41, $DF, $B2, $47, $6E, $81, $36, $6C, $59, $38, $C5, $A5, $C2, $02, $FE, $1D, $A3, $F8, $6A, $DD, $E1, $17, $F6, $76, $64, $E1, $23, $B2
	dc.b	$47, $F9, $2E, $CF, $B3, $26, $72, $B3, $22, $A6, $7E, $90, $BB, $40, $4E, $21, $07, $7A, $E9, $FB, $7F, $DA, $52, $94, $2A, $7B, $F0, $8B, $9A, $E9, $B6, $72
	dc.b	$FF, $25, $29, $4A, $52, $85, $E8, $A9, $4A, $51, $FE, $9F, $4A, $52, $94, $A5, $16, $E5, $BA, $C4, $D7, $13, $5B, $F7, $9B, $7E, $B3, $8C, $FB, $8A, $94, $A5
	dc.b	$25, $4C, $F8, $4C, $F8, $2A, $52, $D8, $D4, $3F, $6C, $73, $E1, $E1, $B2, $5E, $72, $34, $72, $F2, $99, $BD, $63, $DA, $79, $1C, $86, $58, $BD, $AA, $E9, $8C
	dc.b	$64, $35, $57, $87, $1F, $55, $72, $C2, $B4, $A3, $17, $17, $27, $C9, $9F, $27, $7E, $54, $92, $A3, $AF, $EA, $C5, $D5, $15, $EA, $B7, $25, $D1, $ED, $EF, $77
	dc.b	$64, $B8, $15, $D9, $84, $82, $DF, $3D, $AF, $4D, $90, $65, $72, $DD, $B1, $F2, $65, $74, $5F, $BD, $73, $C2, $B7, $78, $8A, $52, $94, $A1, $7A, $6F, $4E, $7A
	dc.b	$F3, $0F, $0F, $1F, $AA, $B7, $35, $7D, $BF, $55, $B3, $C7, $EA, $AC, $F1, $FB, $AB, $7E, $E8, $7E, $EA, $DC, $EC, $F0, $F1, $FB, $A1, $CE, $DF, $EA, $E3, $9F
	dc.b	$6F, $F5, $0E, $63, $F5, $41, $E3, $98, $FD, $D0, $E7, $B3, $C7, $30, $FB, $3E, $DF, $DA, $1C, $D7, $F5, $56, $E7, $6F, $D5, $2F, $FE, $AC, $F0, $F5, $7D, $9E
	dc.b	$3F, $54, $39, $87, $D9, $E1, $FC, $73, $57, $DB, $F9, $43, $98, $FF, $50, $FD, $50, $7A, $FE, $E9, $7F, $54, $BC, $F6, $FD, $52, $FE, $E9, $5F, $DB, $F7, $56
	dc.b	$FE, $50, $FD, $52, $BD, $7F, $55, $47, $87, $EC, $F1, $FB, $A5, $7D, $9F, $B7, $EA, $83, $ED, $FF, $A7, $AF, $F2, $95, $EB, $FA, $A0, $FB, $7E, $AA, $83, $F5
	dc.b	$41, $3F, $4F, $CD, $4B, $F4, $5C, $C3, $E5, $FA, $21, $FA, $A1, $25, $78, $FD, $50, $EA, $F1, $FA, $A1, $9A, $FE, $DF, $DB, $14, $FE, $A7, $F6, $3F, $4C, $6C
	dc.b	$6C, $8E, $37, $06, $5A, $93, $07, $31, $8B, $B0, $1F, $A2, $37, $18, $71, $02, $92, $E6, $F7, $61, $93, $8F, $9D, $DF, $B4, $E9, $77, $E8, $5C, $5F, $91, $BB
	dc.b	$96, $8E, $20, $7D, $48, $10, $95, $FD, $42, $13, $EF, $C3, $30, $40, $DF, $2D, $25, $9C, $B4, $F3, $91, $3F, $F5, $3D, $31, $C2, $3B, $B3, $F6, $C4, $FF, $53
	dc.b	$5E, $4E, $7D, $C4, $2F, $E4, $1F, $71, $3E, $3B, $9E, $BC, $E5, $CE, $CF, $05, $FA, $A0, $F5, $CB, $F2, $3C, $ED, $FA, $89, $BC, $3C, $7E, $B6, $F2, $D7, $3D
	dc.b	$92, $C7, $64, $0C, $1F, $C3, $02, $D3, $B6, $96, $CE, $9D, $89, $4B, $F5, $C4, $60, $97, $F5, $40, $87, $F2, $86, $7C, $D7, $9A, $5B, $F5, $41, $19, $79, $87
	dc.b	$87, $3E, $C5, $AF, $39, $F5, $67, $3D, $67, $FA, $86, $B7, $FA, $97, $F5, $4A, $F5, $7D, $9E, $BC, $F3, $AF, $39, $19, $2C, $DC, $68, $EB, $3A, $03, $B1, $4D
	dc.b	$E2, $45, $87, $2E, $EA, $EC, $FF, $70, $F0, $4E, $65, $23, $24, $31, $B8, $65, $76, $C8, $23, $7E, $8D, $3B, $22, $A1, $A6, $A9, $FA, $F6, $4E, $A3, $F5, $8E
	dc.b	$5E, $A1, $35, $EA, $31, $64, $71, $E2, $31, $10, $8E, $53, $11, $A1, $A9, $86, $08, $DF, $91, $1F, $AC, $40, $82, $F4, $34, $8D, $CE, $A1, $C9, $FA, $C3, $48
	dc.b	$46, $EF, $34, $08, $BF, $AF, $58, $61, $AE, $2E, $60, $D1, $D5, $66, $8E, $EF, $76, $33, $30, $7F, $AC, $C6, $66, $26, $D0, $D3, $36, $38, $4D, $D0, $24, $6D
	dc.b	$A8, $85, $DF, $AE, $2C, $ED, $99, $C3, $1B, $32, $39, $31, $FD, $7A, $15, $EC, $BA, $4F, $CD, $A6, $D0, $DF, $A2, $86, $D9, $1C, $C1, $1B, $A3, $62, $10, $4F
	dc.b	$49, $C2, $B8, $FA, $E2, $6B, $34, $EB, $8D, $ED, $02, $7A, $2A, $04, $C7, $45, $9D, $A0, $63, $76, $30, $20, $32, $C0, $FD, $7A, $6D, $88, $68, $56, $18, $84
	dc.b	$6F, $C8, $B4, $36, $2C, $EF, $23, $D0, $7E, $F4, $DA, $41, $C3, $C9, $1D, $27, $34, $36, $8E, $1B, $84, $E8, $21, $5C, $96, $C5, $4F, $BF, $68, $6B, $4D, $59
	dc.b	$3A, $8D, $ED, $AC, $2C, $34, $F5, $08, $21, $3F, $45, $14, $B6, $E9, $BE, $DD, $37, $08, $D0, $23, $78, $C5, $93, $F2, $3A, $4C, $33, $B1, $1E, $56, $9F, $F4
	dc.b	$7A, $3B, $BE, $11, $82, $5B, $A2, $32, $2A, $63, $33, $64, $DB, $13, $6C, $50, $22, $9C, $7E, $47, $A8, $43, $D3, $1B, $34, $30, $C4, $E6, $E6, $46, $B3, $59
	dc.b	$03, $82, $59, $02, $33, $B4, $B4, $34, $FA, $36, $81, $07, $EB, $B1, $DE, $7B, $63, $37, $1C, $7E, $B7, $15, $61, $FA, $FF, $D1, $06, $F4, $DF, $AF, $B2, $08
	dc.b	$56, $D1, $5D, $FA, $F4, $DB, $7C, $46, $82, $7D, $04, $33, $84, $68, $73, $30, $EE, $F8, $FD, $92, $0D, $29, $DB, $74, $6D, $BA, $03, $FD, $60, $D3, $10, $9A
	dc.b	$E3, $D4, $62, $8E, $3C, $7A, $CE, $16, $11, $63, $71, $08, $DC, $32, $06, $D3, $66, $B6, $96, $68, $54, $D9, $84, $04, $08, $A8, $10, $24, $25, $A3, $46, $4C
	dc.b	$FB, $B6, $CE, $99, $AA, $7A, $D3, $67, $2A, $70, $8B, $DE, $1D, $A0, $45, $6C, $E5, $9F, $2B, $A8, $54, $CE, $EF, $4D, $9D, $DC, $20, $62, $1A, $04, $E1, $38
	dc.b	$29, $7F, $52, $94, $A5, $0A, $EF, $4D, $9D, $DE, $9B, $31, $EE, $BB, $95, $89, $3D, $48, $6F, $B5, $CC, $1B, $3B, $89, $83, $0C, $DB, $34, $86, $E3, $46, $52
	dc.b	$56, $0C, $5B, $5C, $57, $0F, $E2, $2F, $EC, $C8, $10, $4F, $D3, $8C, $D7, $DE, $9C, $69, $DB, $BE, $56, $2A, $C3, $73, $87, $87, $73, $76, $52, $70, $97, $E5
	dc.b	$7C, $C5, $E1, $F9, $BA, $72, $7A, $F7, $10, $92, $2F, $71, $40, $8E, $37, $C4, $3F, $F2, $39, $3A, $2F, $BB, $1B, $CE, $4D, $15, $41, $7B, $BC, $46, $98, $5E
	dc.b	$DD, $42, $34, $AF, $35, $C7, $73, $C2, $BC, $9D, $FA, $C0, $DF, $AF, $DC, $40, $EF, $8E, $49, $2E, $95, $8F, $13, $24, $05, $25, $36, $1A, $59, $A0, $F9, $55
	dc.b	$5B, $5E, $44, $12, $31, $8D, $CB, $45, $4D, $C9, $52, $07, $41, $76, $E9, $5E, $97, $4B, $BA, $B1, $FA, $86, $F4, $54, $A5, $29, $EB, $C7, $6F, $C8, $F3, $5E
	dc.b	$74, $E6, $BF, $DA, $E1, $FB, $7E, $AB, $6F, $D5, $70, $FF, $4F, $F4, $FA, $50, $3F, $87, $87, $F0, $FA, $7A, $7F, $A7, $FA, $E6, $AF, $A7, $F2, $97, $F7, $54
	dc.b	$B3, $FB, $73, $EC, $FF, $4F, $F4, $FA, $6D, $FA, $AE, $3F, $55, $67, $FA, $7D, $1F, $E9, $FB, $3F, $D3, $E8, $AF, $F4, $F1, $5E, $4B, $59, $40, $DF, $2A, $82
	dc.b	$B9, $B5, $72, $57, $01, $1D, $4B, $A6, $05, $5C, $C1, $46, $9E, $7D, $F4, $5F, $D5, $71, $8D, $D5, $B7, $84, $99, $FE, $AD, $19, $01, $EE, $80, $8D, $D1, $98
	dc.b	$A8, $C0, $A4, $B5, $6A, $7A, $8C, $2E, $CE, $B6, $34, $CE, $BC, $B2, $49, $BB, $C6, $8E, $57, $CE, $33, $10, $EB, $9D, $1F, $C4, $05, $5C, $ED, $C8, $72, $A0
	dc.b	$CF, $91, $24, $AA, $B2, $04, $2B, $37, $34, $AA, $51, $37, $1A, $60, $21, $04, $24, $DC, $80, $E7, $E3, $02, $BA, $B8, $57, $F4, $EB, $CA, $83, $F5, $9E, $37
	dc.b	$AD, $BA, $24, $0F, $31, $0E, $67, $4F, $CD, $4E, $03, $BB, $E7, $A0, $77, $EA, $30, $AD, $DE, $D6, $2B, $F4, $9D, $0B, $BA, $F2, $52, $8F, $61, $93, $96, $37
	dc.b	$C8, $36, $35, $6F, $33, $19, $13, $C6, $93, $4B, $7E, $A3, $C5, $D8, $C6, $3F, $CD, $E7, $48, $EF, $6D, $2D, $ED, $21, $1B, $E0, $B7, $E2, $97, $E1, $6F, $32
	dc.b	$C1, $93, $F5, $CE, $18, $DD, $5F, $6B, $93, $18, $C7, $F5, $B8, $FB, $45, $03, $06, $D6, $D0, $23, $50, $61, $23, $0E, $5B, $9B, $97, $CF, $F2, $A6, $E9, $9F
	dc.b	$2D, $AF, $3E, $F6, $37, $5D, $7B, $FD, $AF, $A6, $26, $20, $75, $68, $18, $C3, $6A, $12, $F9, $04, $D5, $1E, $60, $DF, $E1, $E7, $37, $CA, $17, $58, $C1, $07
	dc.b	$49, $E1, $5C, $B3, $C3, $9D, $01, $C0, $9B, $B5, $83, $59, $D9, $F2, $C4, $79, $66, $9F, $A9, $27, $E8, $25, $37, $1B, $D5, $9C, $8E, $4B, $F4, $F3, $E4, $FC
	dc.b	$EF, $A3, $56, $F9, $20, $F2, $4B, $E5, $74, $F1, $9E, $24, $68, $D2, $7C, $9A, $F9, $61, $78, $C1, $E7, $7B, $A0, $36, $09, $29, $C5, $A1, $E3, $F6, $95, $E7
	dc.b	$7D, $15, $D3, $09, $09, $F9, $14, $9A, $E2, $9F, $AC, $F7, $BC, $7E, $AA, $1E, $E9, $E1, $A0, $6B, $D6, $17, $BE, $D8, $79, $E7, $96, $74, $1E, $4A, $6A, $DE
	dc.b	$47, $3B, $27, $B3, $C9, $2F, $4B, $D4, $8C, $8C, $92, $D7, $68, $13, $A6, $70, $B7, $FB, $FE, $54, $A5, $41, $FA, $DD, $EF, $9A, $4F, $46, $75, $F3, $7D, $EB
	dc.b	$29, $95, $52, $EF, $30, $F4, $A8, $C3, $49, $AC, $B4, $B2, $32, $60, $FF, $DA, $54, $A9, $08, $7F, $AD, $30, $8C, $93, $DC, $3A, $57, $11, $F7, $65, $03, $5B
	dc.b	$FA, $E0, $4E, $34, $6E, $A2, $6E, $9A, $47, $95, $E9, $79, $79, $FB, $CA, $8A, $D3, $1E, $40, $DC, $35, $D0, $E5, $8E, $4F, $BD, $5C, $6F, $49, $DF, $CA, $11
	dc.b	$C8, $2F, $EB, $21, $03, $04, $DE, $3F, $52, $E2, $E5, $5A, $24, $C2, $0C, $55, $8D, $4E, $35, $AF, $9A, $79, $F2, $36, $5F, $DF, $23, $81, $09, $AC, $04, $EA
	dc.b	$35, $A9, $5F, $FA, $59, $5F, $41, $E5, $AE, $26, $35, $EB, $FA, $E7, $5F, $2F, $CA, $DF, $2C, $AF, $32, $BF, $F5, $CE, $79, $93, $CE, $66, $31, $39, $A0, $98
	dc.b	$99, $49, $F7, $CB, $CF, $9D, $3F, $5D, $33, $9E, $9F, $A2, $86, $4E, $9F, $CB, $BE, $B8, $F0, $72, $FD, $77, $91, $89, $3D, $67, $07, $37, $1F, $9C, $B2, $AE
	dc.b	$17, $95, $3F, $5C, $3F, $58, $9F, $AE, $E2, $FE, $53, $BD, $39, $0D, $6E, $34, $04, $DA, $B1, $A1, $93, $75, $34, $7B, $3B, $07, $DF, $52, $BF, $2B, $E8, $BA
	dc.b	$3B, $71, $D2, $CC, $B2, $BF, $BA, $B2, $74, $2F, $89, $14, $C8, $D3, $79, $73, $B7, $E5, $46, $A3, $02, $F3, $F1, $2B, $A8, $8E, $64, $FD, $62, $2B, $26, $EB
	dc.b	$95, $7F, $7F, $E0, $5C, $83, $30, $63, $19, $3E, $C6, $D2, $5D, $56, $FC, $AB, $ED, $95, $65, $40, $CA, $9B, $32, $6C, $DD, $31, $6F, $D5, $C3, $4D, $4F, $CE
	dc.b	$71, $7C, $9E, $DE, $5E, $76, $76, $67, $95, $70, $CA, $EF, $19, $50, $68, $10, $69, $B2, $5A, $31, $74, $34, $7E, $47, $CA, $4F, $8F, $D6, $C8, $83, $3A, $7C
	dc.b	$D4, $D8, $3D, $72, $F1, $93, $BF, $4B, $45, $4E, $34, $1D, $EB, $BC, $69, $BC, $03, $93, $3A, $68, $4F, $27, $4A, $72, $7F, $EB, $9C, $F2, $7A, $F8, $8C, $BA
	dc.b	$79, $AF, $BD, $10, $37, $08, $C9, $BF, $EB, $DD, $18, $6A, $1E, $52, $2E, $C6, $4F, $F3, $23, $06, $F2, $FD, $DD, $DF, $91, $8A, $0E, $FD, $99, $74, $5C, $53
	dc.b	$F2, $2D, $17, $62, $65, $F9, $19, $14, $8E, $43, $A2, $90, $91, $F2, $57, $82, $7B, $BF, $5C, $0D, $F4, $C1, $DF, $DE, $CA, $FF, $D3, $F9, $D6, $57, $FE, $56
	dc.b	$5E, $79, $54, $75, $5B, $AF, $5D, $6A, $6D, $2A, $8D, $71, $79, $0F, $DF, $13, $F5, $A7, $EB, $BF, $94, $57, $96, $D3, $7D, $5F, $EE, $72, $7B, $6B, $E6, $E3
	dc.b	$78, $A9, $E8, $C3, $5A, $8E, $79, $EA, $35, $57, $D3, $99, $73, $E4, $FF, $E6, $EB, $3A, $F9, $CE, $5E, $24, $E5, $6C, $BD, $9E, $2F, $3B, $9D, $9A, $DE, $F1
	dc.b	$7E, $C6, $59, $7E, $BE, $B4, $27, $93, $B6, $9A, $45, $DB, $4E, $4C, $4B, $DC, $4A, $95, $8D, $2F, $0D, $8E, $7E, $57, $8A, $CC, $87, $97, $EB, $FF, $97, $4A
	dc.b	$52, $B7, $5B, $BB, $02, $82, $8A, $F2, $70, $8A, $AD, $E1, $09, $33, $13, $26, $FF, $DD, $29, $45, $BB, $8C, $C1, $6D, $E2, $38, $CD, $8B, $6F, $D0, $BC, $7E
	dc.b	$AB, $67, $FA, $7D, $3D, $3E, $94, $A5, $03, $FD, $3F, $D3, $E9, $67, $D9, $F6, $7D, $29, $4A, $52, $94, $D9, $FE, $9F, $4A, $52, $94, $A5, $29, $4A, $47, $F8
	dc.b	$E1, $2E, $AF, $42, $C2, $C8, $AC, $FA, $2D, $5B, $38, $6B, $17, $89, $3F, $D3, $F6, $FE, $BA, $0F, $DB, $C1, $07, $0F, $62, $AA, $E7, $AD, $07, $27, $B9, $3A
	dc.b	$97, $27, $90, $DE, $43, $90, $97, $5F, $D3, $CF, $92, $D6, $41, $FC, $B3, $AE, $78, $94, $0F, $04, $E0, $E1, $FA, $BA, $57, $0C, $B0, $4A, $AD, $65, $9D, $D5
	dc.b	$B4, $81, $25, $79, $7E, $ED, $AB, $A7, $F6, $FD, $F0, $B8, $F3, $BB, $07, $2E, $36, $2A, $61, $34, $BE, $09, $2F, $11, $31, $32, $AC, $49, $4C, $98, $83, $43
	dc.b	$8D, $E3, $AF, $82, $C3, $BB, $DB, $C6, $15, $C2, $EC, $2B, $A1, $83, $58, $A6, $97, $57, $47, $17, $41, $55, $81, $A5, $51, $5A, $5E, $D3, $1A, $6F, $F9, $1C
	dc.b	$3F, $51, $E1, $DF, $A8, $C2, $EE, $A5, $A8, $90, $47, $D3, $F4, $C9, $7B, $5F, $77, $EA, $C2, $04, $AB, $78, $58, $F0, $9E, $07, $81, $22, $FD, $5D, $90, $BF
	dc.b	$4D, $76, $38, $64, $43, $97, $EB, $A8, $08, $F9, $3B, $91, $C2, $7B, $15, $DF, $91, $F1, $6B, $A0, $7E, $DC, $34, $07, $E5, $8A, $49, $35, $70, $31, $A5, $C5
	dc.b	$8A, $1B, $BF, $2B, $45, $BA, $FD, $AE, $25, $EB, $F9, $5C, $D5, $BF, $9F, $68, $B4, $61, $DC, $5F, $AB, $FF, $A1, $0C, $9B, $26, $E8, $EA, $32, $30, $BB, $C1
	dc.b	$A5, $E5, $95, $AE, $15, $B7, $25, $EE, $70, $DC, $57, $BB, $01, $E0, $10, $F7, $19, $FB, $54, $15, $DD, $68, $47, $22, $91, $AC, $EE, $65, $C3, $A8, $AC, $55
	dc.b	$86, $9F, $AF, $15, $1C, $BD, $EB, $B4, $BD, $EC, $51, $58, $2A, $B7, $8A, $24, $BC, $5A, $42, $E9, $78, $B8, $5C, $C1, $2E, $04, $D5, $92, $DE, $EA, $CA, $14
	dc.b	$B1, $75, $47, $ED, $2D, $FC, $4E, $EC, $5A, $83, $91, $6E, $2E, $4E, $5E, $F9, $72, $F1, $62, $95, $07, $8E, $C5, $6F, $75, $F6, $2A, $8C, $E8, $35, $60, $52
	dc.b	$82, $FD, $41, $2D, $76, $A8, $95, $47, $86, $5A, $AF, $86, $5F, $1C, $12, $E0, $5D, $2E, $8A, $DD, $43, $1E, $77, $55, $05, $C5, $D6, $43, $BB, $C6, $69, $6A
	dc.b	$C7, $88, $AC, $94, $BF, $77, $2B, $67, $B6, $0E, $0D, $ED, $71, $D0, $9C, $8D, $6C, $70, $12, $1D, $52, $49, $25, $EB, $0D, $CA, $EC, $3C, $07, $2D, $CE, $F2
	dc.b	$2C, $29, $FA, $6D, $F5, $4A, $61, $89, $BC, $BF, $22, $92, $08, $E6, $E8, $19, $01, $47, $EA, $D6, $A3, $F5, $62, $A5, $C8, $72, $65, $E4, $3F, $4F, $FB, $88
	dc.b	$C3, $BA, $88, $35, $49, $AD, $6E, $9B, $9A, $34, $12, $A9, $02, $5A, $A6, $11, $E1, $59, $31, $BB, $F5, $6D, $FB, $7B, $4A, $BF, $C6, $8C, $28, $80, $8E, $63
	dc.b	$10, $D3, $26, $89, $E0, $70, $27, $D0, $23, $2F, $EB, $C5, $4B, $C7, $BB, $7A, $92, $EB, $0E, $BB, $02, $9D, $3F, $23, $2C, $05, $EE, $8C, $D0, $1D, $5D, $7A
	dc.b	$F4, $58, $1E, $0B, $CD, $D1, $31, $CB, $2A, $E0, $58, $0F, $D3, $95, $BF, $4D, $77, $B4, $61, $49, $FE, $BA, $F1, $E5, $69, $C8, $EF, $84, $54, $54, $6B, $32
	dc.b	$36, $9F, $A8, $28, $4A, $C7, $25, $2E, $45, $8C, $77, $63, $18, $E1, $41, $FA, $E8, $9B, $8F, $6C, $2F, $81, $FB, $D4, $10, $9F, $BD, $41, $09, $87, $E8, $9B
	dc.b	$A3, $0F, $7D, $33, $F6, $C6, $3F, $4D, $8D, $2F, $11, $2F, $CA, $88, $BC, $60, $DD, $45, $D3, $30, $CA, $E3, $86, $09, $ED, $0C, $B7, $46, $70, $33, $1F, $C4
	dc.b	$C3, $1E, $B7, $7E, $9A, $81, $8C, $8F, $9D, $C7, $95, $C6, $39, $35, $CC, $2E, $1D, $1F, $98, $C6, $FD, $EA, $2B, $18, $90, $69, $17, $89, $34, $67, $86, $37
	dc.b	$62, $85, $F9, $1A, $0B, $DE, $4E, $9E, $86, $4F, $5B, $B9, $82, $0F, $3C, $3B, $AC, $83, $0F, $DC, $20, $69, $DA, $5E, $0A, $BD, $D8, $C7, $72, $7B, $5D, $49
	dc.b	$1E, $1A, $90, $A9, $BF, $13, $C5, $E2, $AC, $F9, $66, $0C, $33, $EF, $99, $A9, $82, $F3, $C2, $E6, $C3, $F7, $01, $D8, $3B, $74, $B9, $C4, $0A, $9C, $F1, $E6
	dc.b	$64, $3F, $5C, $F2, $67, $58, $81, $6E, $7B, $10, $64, $FD, $65, $CC, $82, $32, $EA, $6E, $BD, $D9, $26, $68, $0B, $5A, $0C, $EA, $F0, $73, $7A, $EA, $A4, $3F
	dc.b	$5C, $A6, $3B, $FC, $B5, $2F, $DF, $D5, $A7, $7B, $9F, $F9, $5C, $5D, $E6, $68, $A8, $AD, $43, $77, $2C, $DE, $0B, $15, $79, $3D, $89, $95, $E3, $30, $5E, $65
	dc.b	$25, $F2, $82, $BD, $FE, $58, $5F, $87, $EF, $5E, $80, $A5, $9D, $F4, $0D, $9C, $B3, $3B, $C6, $76, $95, $E4, $BF, $B4, $52, $4F, $DE, $CA, $6E, $7E, $7E, $3C
	dc.b	$B0, $9D, $EF, $FC, $AB, $C2, $14, $CF, $74, $A1, $E9, $7C, $FC, $0B, $E7, $C8, $B9, $13, $63, $23, $FD, $39, $24, $18, $3F, $30, $FC, $BF, $56, $55, $C3, $F2
	dc.b	$BD, $72, $9F, $E5, $4D, $A5, $7B, $5F, $AD, $03, $20, $89, $F5, $09, $33, $99, $75, $31, $34, $99, $29, $C2, $14, $F0, $5A, $DF, $90, $93, $56, $59, $3B, $22
	dc.b	$7D, $F9, $3D, $83, $4C, $A5, $0F, $A2, $C7, $98, $C4, $38, $6B, $21, $2E, $DF, $AE, $98, $2B, $38, $DF, $AF, $E8, $67, $8F, $9D, $DC, $6F, $14, $F5, $77, $1B
	dc.b	$F6, $EE, $A7, $6F, $FD, $52, $94, $A5, $31, $F5, $8D, $29, $4A, $52, $94, $FC, $8F, $6F, $2D, $A6, $37, $DA, $74, $A6, $C7, $3E, $B4, $D9, $BF, $5E, $1D, $66
	dc.b	$D1, $D0, $AE, $67, $33, $A6, $10, $B0, $BB, $07, $2F, $F1, $ED, $2D, $9B, $AD, $B9, $50, $1F, $66, $73, $7B, $A3, $29, $FB, $BA, $75, $91, $09, $13, $A7, $CE
	dc.b	$4B, $A2, $C8, $72, $DD, $04, $82, $17, $4A, $09, $0B, $97, $AB, $45, $DB, $8F, $62, $B9, $58, $BB, $B1, $10, $48, $3A, $61, $20, $51, $77, $EB, $F7, $53, $EF
	dc.b	$58, $4C, $3F, $57, $4A, $8F, $02, $EF, $19, $E1, $88, $3D, $1D, $51, $22, $3D, $CD, $9C, $6C, $4C, $E0, $6E, $FE, $73, $38, $1C, $EF, $C1, $08, $39, $A2, $A2
	dc.b	$B4, $81, $71, $3A, $B0, $2A, $57, $13, $A2, $5E, $EC, $1C, $57, $0B, $98, $DC, $75, $05, $B8, $9B, $0A, $CB, $A0, $81, $01, $3C, $61, $04, $2A, $54, $EE, $15
	dc.b	$28, $5D, $CA, $E1, $7A, $E6, $24, $D8, $57, $05, $28, $B8, $AB, $84, $94, $87, $20, $9D, $C4, $39, $08, $EE, $18, $09, $51, $7C, $07, $24, $87, $EA, $C4, $5D
	dc.b	$5C, $2A, $B2, $AC, $54, $EB, $21, $C8, $1E, $02, $4B, $2D, $BF, $6E, $3A, $0F, $DB, $AC, $53, $69, $08, $0D, $FA, $BD, $D6, $EC, $16, $B7, $74, $C2, $39, $67
	dc.b	$2C, $86, $6F, $DD, $C4, $08, $DC, $B0, $09, $E6, $DA, $82, $A1, $3C, $1A, $C0, $3C, $13, $0F, $C8, $9E, $6D, $16, $98, $4D, $EE, $8D, $C4, $14, $5C, $9D, $2A
	dc.b	$82, $42, $AA, $D6, $A8, $EE, $8A, $2F, $82, $D0, $48, $56, $EC, $BC, $42, $CA, $31, $D0, $16, $1B, $89, $69, $1C, $67, $32, $59, $5D, $CB, $07, $CE, $A1, $D4
	dc.b	$5A, $EA, $AF, $E5, $5C, $2E, $B6, $7C, $96, $44, $B2, $4B, $8A, $E9, $33, $83, $02, $4F, $D3, $82, $05, $56, $BC, $60, $C7, $90, $B8, $A2, $86, $1E, $80, $B4
	dc.b	$5B, $88, $38, $D8, $3C, $4B, $02, $C6, $65, $84, $62, $EF, $69, $66, $85, $04, $2B, $BD, $DB, $E0, $C3, $72, $BB, $17, $15, $07, $9A, $BC, $3C, $BF, $22, $41
	dc.b	$89, $ED, $C7, $2B, $87, $8B, $89, $91, $7C, $5C, $48, $5C, $55, $BB, $54, $35, $D4, $B5, $43, $3F, $6A, $8A, $E1, $70, $CD, $4B, $95, $C2, $3C, $09, $20, $65
	dc.b	$AA, $90, $2F, $20, $80, $B7, $EA, $10, $15, $1C, $5D, $47, $21, $81, $7B, $0E, $4E, $93, $FF, $4E, $24, $F9, $1C, $93, $A6, $2F, $C1, $CC, $7B, $BD, $1C, $6F
	dc.b	$19, $BE, $0A, $E7, $12, $E0, $54, $57, $4F, $91, $1E, $01, $D8, $F2, $0F, $C8, $A5, $EE, $EC, $6A, $D7, $38, $31, $C9, $6A, $D9, $6F, $FA, $E2, $B8, $6E, $77
	dc.b	$9B, $B0, $CA, $9B, $7E, $B9, $AD, $AD, $DF, $B3, $6D, $07, $8D, $CE, $F4, $F6, $BB, $19, $3E, $B7, $60, $E4, $9F, $B1, $29, $43, $7B, $12, $D4, $63, $ED, $4B
	dc.b	$85, $54, $95, $07, $47, $3F, $AC, $06, $18, $DD, $9C, $5C, $1C, $25, $70, $40, $73, $97, $42, $60, $70, $2E, $99, $03, $68, $78, $7B, $51, $89, $D1, $35, $7B
	dc.b	$7B, $20, $B8, $9C, $49, $C8, $5C, $18, $B4, $C2, $E2, $62, $56, $75, $EE, $C2, $7B, $87, $2E, $03, $F5, $84, $6E, $36, $A2, $E6, $23, $24, $EE, $04, $D3, $34
	dc.b	$EE, $CD, $E6, $B7, $6E, $2E, $6C, $AB, $FC, $EC, $98, $DF, $EC, $D7, $09, $5D, $97, $73, $3A, $FE, $EA, $0D, $41, $89, $BE, $35, $4B, $81, $F9, $F7, $54, $AE
	dc.b	$80, $9F, $A8, $F6, $84, $64, $B4, $D8, $C9, $BB, $8E, $6A, $52, $5D, $43, $A9, $05, $ED, $34, $EA, $85, $D5, $27, $7E, $07, $77, $B6, $B0, $35, $2C, $1C, $C2
	dc.b	$E2, $B8, $EC, $4C, $FB, $9B, $89, $C9, $D1, $A6, $74, $89, $18, $E4, $33, $C2, $EA, $D8, $BB, $54, $66, $30, $71, $46, $01, $B0, $70, $E7, $20, $64, $EC, $2D
	dc.b	$27, $60, $65, $CE, $82, $AC, $1F, $69, $5E, $64, $85, $ED, $71, $BC, $23, $69, $17, $BE, $E4, $12, $F3, $F0, $F9, $3F, $2D, $44, $1B, $CB, $1D, $52, $27, $72
	dc.b	$F9, $D1, $4D, $D9, $FE, $46, $12, $F3, $7D, $9A, $DA, $F7, $56, $E2, $7E, $C6, $1E, $46, $F1, $26, $C2, $E7, $55, $C6, $85, $6C, $AE, $05, $46, $B8, $98, $EA
	dc.b	$47, $73, $42, $99, $3E, $1A, $77, $9E, $46, $48, $0A, $66, $57, $22, $CC, $AD, $5D, $66, $42, $E5, $F3, $78, $26, $A2, $EB, $50, $4B, $5F, $3A, $82, $61, $16
	dc.b	$F7, $5F, $E1, $95, $CD, $55, $E8, $0C, $5D, $E5, $FA, $20, $77, $70, $74, $5F, $DF, $5A, $EE, $2F, $2D, $AF, $1A, $0B, $F9, $C8, $1D, $E0, $F3, $31, $26, $17
	dc.b	$EC, $58, $31, $79, $C8, $A7, $41, $91, $7E, $B7, $42, $E5, $E4, $25, $78, $24, $E4, $0B, $2A, $9B, $F5, $56, $71, $18, $97, $96, $B2, $AC, $8F, $F5, $A1, $AA
	dc.b	$2F, $F2, $12, $A6, $44, $83, $93, $CE, $53, $42, $5B, $DB, $CC, $DF, $BD, $E2, $57, $BB, $F4, $CF, $C3, $57, $42, $79, $40, $67, $31, $AC, $4B, $F5, $77, $F9
	dc.b	$50, $7F, $3B, $99, $54, $1E, $17, $FE, $54, $62, $F9, $34, $94, $BC, $8E, $65, $94, $2E, $AE, $5F, $20, $63, $7C, $B5, $9D, $E0, $F1, $75, $14, $8E, $57, $EA
	dc.b	$B7, $B3, $82, $64, $B2, $7D, $E1, $07, $27, $E1, $94, $F2, $13, $32, $35, $E8, $18, $81, $FE, $CD, $A2, $B7, $5F, $FB, $EA, $30, $46, $BE, $4A, $70, $C1, $D1
	dc.b	$5E, $45, $1B, $A0, $6C, $62, $5D, $DE, $F4, $5B, $8A, $5C, $40, $42, $A2, $E6, $11, $64, $4B, $A0, $64, $EC, $C8, $DF, $D4, $95, $D4, $A5, $28, $54, $DB, $F5
	dc.b	$0D, $9E, $0B, $FA, $8C, $F0, $17, $52, $94, $A5, $28, $B9, $F1, $76, $7C, $5D, $4A, $52, $94, $A5, $AE, $5B, $87, $32, $6A, $DD, $7E, $2A, $70, $1D, $9F, $A2
	dc.b	$5C, $88, $64, $2B, $90, $37, $93, $C6, $54, $38, $DD, $CD, $71, $B6, $07, $96, $39, $1B, $4B, $CF, $F4, $D7, $CA, $9F, $AB, $D9, $DE, $7B, $64, $7A, $0F, $0B
	dc.b	$3A, $6A, $4B, $52, $19, $86, $23, $5A, $C9, $32, $8C, $B1, $4F, $D7, $6C, $90, $B2, $C9, $D8, $AE, $8B, $22, $5C, $EF, $A7, $19, $8F, $39, $21, $79, $29, $84
	dc.b	$BB, $F6, $30, $21, $31, $58, $65, $89, $EF, $20, $8D, $FC, $40, $52, $5F, $DA, $5E, $54, $05, $A4, $84, $C1, $0D, $53, $30, $90, $75, $E6, $6F, $46, $93, $6A
	dc.b	$97, $3E, $4B, $D6, $B8, $29, $26, $78, $6A, $1F, $55, $73, $50, $C1, $DD, $9A, $BF, $CE, $5D, $5E, $CE, $AC, $4C, $1E, $0C, $1C, $4F, $2D, $C1, $1E, $E5, $BA
	dc.b	$38, $5C, $E1, $D0, $38, $C9, $D8, $6F, $2A, $07, $06, $2D, $0B, $AE, $42, $AB, $50, $72, $48, $EE, $8C, $1A, $68, $BF, $B4, $DC, $86, $EB, $22, $42, $E0, $90
	dc.b	$77, $50, $7B, $88, $CD, $D5, $6C, $59, $FD, $0B, $A6, $09, $29, $C1, $6C, $64, $30, $09, $24, $B9, $C3, $DC, $5C, $57, $7E, $B2, $EF, $67, $31, $D3, $B9, $8E
	dc.b	$78, $16, $0E, $27, $24, $EB, $8D, $5C, $42, $78, $56, $F6, $E5, $81, $8C, $FF, $4E, $2E, $04, $D7, $67, $B7, $76, $63, $DE, $EA, $6C, $99, $AF, $B5, $D5, $C1
	dc.b	$C4, $E9, $61, $71, $7B, $0C, $32, $EE, $57, $7B, $EF, $70, $31, $21, $BB, $B3, $BA, $07, $73, $89, $AE, $6A, $76, $CF, $0D, $F0, $68, $6C, $1D, $73, $C3, $EB
	dc.b	$C9, $1B, $DB, $2B, $DC, $C2, $3D, $B1, $0E, $6E, $5F, $91, $B4, $67, $CB, $14, $37, $D0, $1E, $73, $17, $B7, $5F, $6C, $41, $BC, $EE, $EB, $75, $F8, $E4, $FC
	dc.b	$3B, $B9, $24, $A6, $4B, $DD, $04, $E8, $7F, $EB, $91, $91, $8B, $F5, $D4, $B1, $CD, $B3, $EE, $C6, $61, $3D, $C5, $CE, $A8, $74, $24, $81, $09, $3F, $F6, $E5
	dc.b	$C1, $7F, $A1, $CC, $37, $EF, $9D, $06, $E3, $BE, $01, $06, $B4, $24, $BF, $5E, $D5, $B8, $27, $E9, $CB, $49, $12, $95, $73, $FD, $C0, $C7, $34, $0D, $6C, $E8
	dc.b	$2E, $24, $DF, $A6, $CD, $35, $AB, $F0, $AB, $A1, $F5, $0F, $FD, $31, $62, $E2, $B8, $85, $56, $A4, $C0, $AA, $B1, $72, $E1, $67, $51, $3A, $0B, $AA, $4D, $55
	dc.b	$84, $10, $D2, $6C, $5B, $F4, $29, $C9, $F2, $FD, $54, $BA, $54, $49, $7F, $4F, $3B, $A3, $BA, $34, $9A, $35, $2D, $FB, $B6, $38, $B4, $AD, $20, $F9, $09, $46
	dc.b	$32, $73, $FF, $AE, $FB, $72, $B7, $EA, $23, $1C, $3B, $B8, $3A, $29, $7E, $B2, $6D, $74, $15, $91, $84, $A3, $BF, $A6, $17, $24, $B4, $E5, $85, $C4, $33, $DB
	dc.b	$BB, $DA, $E5, $96, $FA, $B2, $CA, $8C, $3F, $58, $57, $54, $7B, $82, $40, $C5, $F9, $11, $DC, $F4, $2B, $E5, $DD, $DF, $26, $1E, $25, $86, $8E, $7F, $89, $08
	dc.b	$07, $75, $36, $BB, $DF, $B8, $12, $B0, $DC, $54, $AD, $A4, $AA, $24, $BF, $A7, $0F, $C8, $B8, $C1, $ED, $87, $EE, $01, $83, $B1, $D0, $38, $41, $AE, $27, $09
	dc.b	$2B, $4B, $1F, $03, $0B, $A3, $90, $95, $BF, $4E, $25, $C5, $5B, $BB, $0F, $D4, $13, $E9, $DA, $EC, $10, $18, $EE, $AA, $B2, $1A, $B0, $AA, $55, $DD, $C0, $87
	dc.b	$24, $EE, $04, $BA, $15, $63, $0B, $B0, $76, $75, $D6, $9D, $9D, $DC, $E5, $BA, $AB, $24, $E3, $3B, $86, $38, $26, $72, $83, $C5, $F7, $E6, $0A, $B7, $35, $FB
	dc.b	$83, $77, $75, $7B, $89, $9E, $25, $95, $3B, $AA, $69, $73, $1E, $F0, $81, $2A, $7E, $F5, $BA, $A3, $0E, $24, $B8, $F5, $B8, $9B, $C5, $FC, $C3, $7E, $B7, $B1
	dc.b	$D0, $5D, $B9, $33, $9B, $02, $DD, $E8, $20, $17, $76, $12, $2A, $C8, $7E, $DD, $65, $56, $E4, $C5, $E2, $69, $ED, $37, $4D, $0C, $7E, $BA, $9B, $7E, $B2, $EF
	dc.b	$6B, $B6, $C0, $81, $47, $BE, $19, $BA, $4B, $2B, $61, $E0, $4B, $C3, $AE, $9A, $5D, $82, $E3, $71, $A9, $F8, $05, $46, $30, $DE, $D1, $63, $D9, $AE, $2C, $9E
	dc.b	$09, $F8, $33, $A4, $FF, $D3, $7E, $A0, $3B, $1D, $CD, $83, $88, $7E, $B0, $99, $C3, $25, $2A, $13, $43, $E1, $6E, $23, $43, $1B, $89, $E5, $76, $15, $FD, $45
	dc.b	$E4, $25, $B6, $4F, $E9, $FB, $84, $AD, $FF, $CE, $23, $06, $3F, $5D, $47, $1B, $9B, $0B, $97, $09, $D8, $B5, $73, $68, $0B, $D8, $7E, $9F, $6F, $D4, $67, $FA
	dc.b	$8F, $D7, $75, $79, $BC, $D7, $52, $0F, $A3, $18, $B8, $BA, $9B, $18, $27, $86, $2B, $B0, $C5, $30, $2B, $9D, $69, $0C, $F0, $CE, $3B, $9C, $BE, $DC, $C1, $64
	dc.b	$3D, $C1, $84, $95, $17, $DA, $4F, $12, $B6, $19, $10, $2C, $1C, $41, $D3, $5F, $D3, $10, $BF, $04, $2D, $08, $FC, $FA, $68, $F9, $40, $E9, $EC, $F0, $D5, $95
	dc.b	$07, $71, $48, $38, $C7, $33, $04, $C1, $F7, $CA, $FC, $2E, $E7, $91, $EE, $8C, $58, $21, $F8, $0F, $0F, $C0, $6B, $36, $73, $C4, $B7, $2C, $19, $D4, $DF, $37
	dc.b	$60, $83, $7E, $E3, $64, $D6, $F7, $E1, $CE, $FB, $8F, $2C, $2E, $F2, $57, $BB, $22, $57, $61, $8B, $A4, $37, $FD, $2B, $AA, $7C, $9D, $14, $71, $E5, $1F, $AC
	dc.b	$7B, $2D, $75, $1A, $BF, $2E, $EB, $E4, $78, $69, $82, $78, $3B, $A3, $12, $AF, $B1, $8C, $2A, $4E, $57, $1D, $F9, $16, $5A, $50, $1A, $48, $A5, $E6, $DB, $1A
	dc.b	$D7, $08, $BA, $FD, $64, $C1, $1A, $65, $2F, $20, $DE, $CD, $0B, $3B, $D6, $68, $BC, $B2, $AE, $47, $45, $71, $03, $19, $66, $62, $4E, $D6, $C6, $31, $C3, $95
	dc.b	$4C, $8C, $AE, $99, $8B, $C5, $F9, $1B, $D9, $0C, $A5, $95, $FE, $30, $CA, $43, $5C, $8D, $A8, $D7, $86, $BD, $5A, $AA, $E3, $B4, $F0, $F1, $87, $8C, $B4, $5D
	dc.b	$3B, $68, $BA, $2A, $5B, $BA, $9D, $B3, $ED, $A7, $A8, $D0, $31, $34, $69, $6E, $E4, $54, $B1, $70, $D0, $9D, $B4, $A5, $28, $BF, $C4, $77, $AC, $17, $3B, $95
	dc.b	$ED, $DF, $17, $2C, $0F, $D0, $DD, $56, $A0, $85, $9D, $4A, $F4, $8F, $C8, $82, $30, $DF, $AF, $49, $63, $07, $D0, $77, $2B, $62, $97, $7E, $EB, $19, $BB, $0D
	dc.b	$89, $F7, $CF, $F2, $B8, $BA, $86, $C6, $3A, $E3, $90, $84, $C1, $72, $74, $F5, $FD, $0E, $94, $A5, $23, $B4, $3F, $B3, $DA, $F1, $16, $6A, $6F, $93, $AF, $49
	dc.b	$1A, $B1, $7A, $62, $1C, $D7, $7A, $83, $7F, $76, $07, $88, $92, $2B, $CD, $24, $BA, $F4, $4A, $5B, $93, $9A, $7A, $8E, $FF, $DE, $87, $FE, $D3, $12, $95, $FC
	dc.b	$AB, $2C, $AF, $08, $AC, $2F, $3B, $C6, $81, $0E, $57, $CF, $43, $9C, $81, $52, $F3, $06, $3C, $E7, $E7, $A7, $9C, $FC, $C6, $77, $C8, $1D, $E3, $C4, $D0, $9E
	dc.b	$25, $B8, $9D, $E9, $7F, $E9, $CA, $FE, $5F, $D4, $3A, $09, $92, $3F, $40, $72, $08, $7C, $B5, $78, $2B, $3C, $E6, $08, $EC, $60, $A6, $6A, $F9, $C9, $F7, $8D
	dc.b	$5A, $35, $1F, $AE, $EB, $4D, $7B, $3C, $C3, $CD, $4D, $E0, $84, $B5, $B6, $77, $FE, $B9, $9D, $EC, $EF, $D3, $45, $93, $F4, $F3, $76, $17, $63, $BE, $34, $D5
	dc.b	$4D, $21, $CD, $76, $17, $6F, $9E, $02, $A3, $A2, $95, $C9, $77, $4F, $18, $23, $5C, $5B, $57, $6E, $97, $1D, $5D, $73, $BC, $50, $65, $5B, $C4, $E4, $57, $40
	dc.b	$68, $AD, $D5, $92, $47, $22, $91, $6E, $3C, $43, $40, $AC, $7E, $AF, $F5, $F5, $8F, $75, $AE, $75, $75, $6F, $75, $3D, $E5, $39, $60, $EF, $D5, $C3, $5D, $51
	dc.b	$98, $49, $54, $B2, $CE, $B1, $E0, $B2, $CE, $3C, $29, $74, $DB, $96, $6D, $74, $7E, $46, $29, $9E, $92, $C8, $D9, $3C, $25, $B7, $F0, $B8, $5C, $C4, $BD, $D8
	dc.b	$56, $06, $F2, $05, $E2, $D2, $5E, $57, $7E, $44, $AE, $AA, $45, $01, $DF, $59, $5F, $5C, $1B, $2D, $65, $88, $B9, $9D, $CA, $EA, $CC, $DA, $7E, $E7, $30, $9F
	dc.b	$AD, $60, $EB, $79, $AB, $91, $AB, $9A, $4A, $F8, $A4, $F2, $7E, $9E, $6C, $72, $0F, $D0, $90, $3B, $45, $84, $0E, $4B, $36, $8E, $EE, $E8, $9D, $2D, $9D, $49
	dc.b	$6E, $FE, $25, $3A, $86, $C3, $AB, $38, $F4, $BF, $50, $EE, $F8, $EF, $72, $04, $D8, $9A, $EA, $97, $88, $F4, $55, $82, $FD, $D9, $52, $69, $96, $9E, $4E, $31
	dc.b	$7A, $BB, $55, $D2, $AE, $DC, $20, $4A, $97, $EB, $22, $BB, $BB, $42, $8A, $E6, $3C, $17, $4A, $70, $D8, $34, $5D, $17, $62, $98, $25, $58, $86, $55, $BA, $65
	dc.b	$01, $8B, $07, $8C, $2A, $8C, $58, $3B, $07, $55, $AE, $2B, $14, $10, $90, $25, $25, $95, $3B, $A2, $E8, $B9, $C8, $B7, $89, $07, $D7, $49, $DD, $FB, $35, $4A
	dc.b	$F4, $15, $5B, $84, $2F, $EA, $EC, $5E, $3D, $E6, $9F, $A8, $A5, $77, $BF, $F7, $D2, $59, $6A, $0E, $EF, $DE, $5D, $3B, $89, $4A, $3C, $0F, $D7, $D5, $6A, $5F
	dc.b	$BB, $5E, $9F, $B8, $D1, $92, $97, $8D, $5F, $79, $CA, $F1, $A9, $4C, $EF, $41, $BC, $EE, $67, $04, $CC, $39, $82, $0F, $02, $69, $09, $FC, $B8, $09, $EE, $24
	dc.b	$95, $A0, $7B, $3E, $E8, $EE, $17, $0C, $16, $4B, $36, $45, $60, $9D, $3B, $40, $85, $81, $58, $A8, $D0, $25, $8B, $F5, $95, $A4, $3A, $1D, $8F, $EB, $EF, $12
	dc.b	$7D, $A4, $6E, $43, $1D, $C6, $8C, $9A, $F8, $3D, $2D, $A0, $41, $A3, $68, $C9, $D1, $07, $46, $A1, $61, $91, $E4, $CF, $C0, $9F, $7B, $A4, $3B, $A2, $E4, $B9
	dc.b	$C9, $E5, $51, $CB, $F7, $FF, $A8, $9C, $7E, $B2, $04, $4E, $3F, $66, $3B, $E3, $4A, $1D, $E7, $79, $BC, $F0, $39, $1D, $E7, $70, $B8, $DE, $37, $39, $EA, $42
	dc.b	$09, $95, $86, $95, $89, $88, $40, $DD, $27, $A4, $D2, $02, $55, $A8, $62, $F4, $CA, $3F, $23, $AC, $8E, $F1, $7F, $EF, $A7, $AA, $0D, $5A, $6E, $5E, $F6, $0E
	dc.b	$10, $8A, $CE, $F2, $84, $DC, $15, $77, $AD, $32, $C5, $D8, $F7, $63, $04, $B2, $3B, $CE, $47, $E4, $AE, $40, $CA, $E1, $D0, $36, $8C, $68, $34, $DF, $46, $1F
	dc.b	$BF, $1F, $AF, $6A, $4A, $7F, $95, $BA, $77, $9E, $47, $EC, $F0, $F0, $63, $75, $3B, $6F, $FF, $ED, $41, $AF, $EF, $81, $F9, $69, $FB, $CA, $4F, $24, $7E, $F9
	dc.b	$38, $F0, $17, $AC, $BF, $5C, $C3, $B9, $5C, $6C, $3B, $82, $31, $83, $DC, $D1, $8C, $39, $5A, $CD, $0A, $4D, $47, $8C, $A7, $57, $7E, $98, $64, $E9, $6A, $F3
	dc.b	$2D, $CE, $DC, $CE, $FF, $D7, $5E, $5A, $DE, $35, $BD, $74, $1D, $FD, $DE, $2E, $FD, $7D, $0E, $78, $3B, $DB, $9E, $19, $19, $19, $75, $FD, $70, $D7, $C8, $81
	dc.b	$A9, $F2, $78, $FD, $F2, $A7, $53, $DA, $08, $1B, $0D, $68, $C6, $EB, $FD, $8F, $21, $80, $93, $F0, $7E, $5A, $87, $FE, $B8, $4B, $37, $91, $BC, $EF, $79, $6A
	dc.b	$09, $DB, $10, $26, $30, $7B, $15, $01, $BE, $F7, $87, $E3, $F9, $57, $DE, $FC, $EB, $F9, $1F, $D7, $4B, $5C, $D4, $AE, $61, $FA, $EE, $75, $63, $D8, $97, $F5
	dc.b	$C1, $E4, $A7, $42, $95, $FC, $B2, $BE, $44, $B2, $BC, $E5, $79, $FE, $9C, $18, $BD, $B5, $42, $82, $0C, $BF, $B4, $71, $7F, $7A, $A5, $D4, $7E, $F2, $97, $FE
	dc.b	$56, $FA, $E1, $F9, $5F, $DB, $DE, $57, $C8, $A5, $CC, $5C, $4F, $D3, $98, $6E, $72, $2E, $66, $F5, $D7, $35, $D5, $87, $70, $6C, $5F, $4C, $AF, $9E, $32, $F1
	dc.b	$1C, $AB, $2F, $32, $A9, $6B, $C1, $6A, $3D, $F8, $FD, $A3, $CF, $82, $9B, $FF, $AF, $41, $3F, $E7, $24, $BF, $53, $FA, $DD, $8F, $DD, $01, $07, $FB, $A1, $7A
	dc.b	$CC, $7E, $D3, $12, $E4, $5F, $A7, $75, $26, $22, $70, $7D, $26, $8D, $3B, $8F, $A0, $29, $8B, $AC, $40, $D5, $B4, $CD, $0A, $E6, $5F, $75, $BF, $3E, $46, $1C
	dc.b	$DD, $68, $22, $44, $FF, $D4, $A4, $4E, $12, $DB, $CE, $34, $09, $09, $B6, $92, $69, $8B, $A0, $20, $F7, $12, $D1, $DA, $A9, $D6, $82, $FF, $CA, $F8, $CA, $B4
	dc.b	$E3, $BC, $7F, $0D, $7F, $87, $44, $EC, $81, $36, $41, $1C, $68, $C9, $C2, $2A, $0E, $F0, $81, $B1, $B2, $59, $DD, $E1, $03, $0F, $E1, $8D, $29, $40, $DF, $A1
	dc.b	$71, $57, $19, $AD, $E5, $01, $C7, $E5, $C1, $E9, $9A, $A0, $D4, $84, $0C, $5D, $A9, $3E, $F5, $76, $A9, $21, $14, $FD, $D6, $78, $1F, $A8, $F5, $5F, $57, $7A
	dc.b	$6E, $D8, $DC, $23, $66, $8A, $26, $17, $FE, $57, $5C, $9B, $01, $70, $4B, $61, $9B, $2C, $94, $A6, $6F, $95, $8A, $61, $02, $29, $2A, $49, $01, $42, $CE, $4A
	dc.b	$50, $3C, $96, $E3, $7E, $A3, $45, $91, $77, $C7, $7C, $81, $A3, $95, $04, $0F, $25, $30, $C6, $E4, $53, $57, $21, $AB, $81, $B6, $36, $70, $FD, $F5, $B4, $12
	dc.b	$4F, $D3, $AA, $4B, $35, $F7, $90, $4F, $70, $57, $8E, $F1, $2D, $B9, $5A, $72, $4F, $70, $9C, $48, $20, $41, $9C, $8F, $DC, $12, $CE, $59, $A0, $CC, $4B, $39
	dc.b	$A6, $69, $21, $2B, $D3, $39, $20, $92, $EB, $79, $0C, $D3, $AD, $F2, $52, $77, $E4, $4E, $5E, $F8, $89, $5F, $24, $96, $60, $F9, $1F, $2B, $6B, $32, $41, $3B
	dc.b	$67, $31, $3F, $D7, $03, $12, $BC, $7E, $BA, $B3, $91, $0F, $D7, $64, $08, $1A, $9B, $B3, $47, $C8, $1E, $00, $8D, $06, $A4, $11, $65, $A9, $09, $0B, $C7, $57
	dc.b	$EA, $0F, $F4, $5C, $47, $96, $C6, $96, $61, $33, $4E, $82, $EB, $D1, $E8, $E6, $0F, $06, $33, $52, $63, $CD, $FA, $4D, $D2, $76, $BF, $AD, $31, $06, $FD, $4A
	dc.b	$42, $A7, $69, $5E, $BA, $AC, $AC, $65, $AB, $88, $F0, $30, $EC, $44, $D8, $49, $51, $D2, $CB, $95, $D9, $32, $B0, $35, $BE, $E5, $BC, $5D, $02, $03, $5E, $77
	dc.b	$63, $17, $C3, $5E, $71, $8E, $03, $2A, $AC, $B2, $68, $69, $B5, $E4, $97, $72, $87, $62, $0D, $F6, $3B, $B0, $31, $98, $31, $0C, $79, $8D, $55, $33, $64, $1D
	dc.b	$2B, $D0, $49, $0A, $07, $92, $3D, $0A, $15, $F2, $32, $C1, $30, $1C, $EF, $82, $6D, $54, $DA, $6E, $36, $B4, $A1, $C7, $69, $AC, $02, $D6, $62, $2B, $70, $D6
	dc.b	$C5, $B1, $8A, $E7, $70, $BC, $DE, $78, $38, $E5, $D6, $01, $AC, $75, $CA, $1F, $71, $63, $C9, $2C, $FB, $40, $2C, $4C, $68, $5C, $69, $B1, $BB, $4D, $B2, $E8
	dc.b	$98, $48, $EF, $62, $63, $F6, $87, $45, $CF, $19, $C3, $B1, $B8, $86, $E7, $25, $31, $AC, $84, $DE, $63, $9B, $18, $79, $0D, $60, $C6, $75, $CD, $E8, $4F, $38
	dc.b	$30, $64, $18, $15, $DE, $CE, $BA, $B7, $95, $54, $9A, $F3, $99, $77, $09, $9C, $CE, $7C, $CA, $F4, $29, $7E, $D2, $F8, $1A, $F5, $F0, $D2, $31, $D6, $65, $06
	dc.b	$E2, $FD, $71, $4A, $6C, $43, $51, $50, $8D, $68, $47, $55, $8D, $52, $EA, $C9, $A7, $AF, $74, $04, $AF, $EA, $18, $B9, $0C, $C6, $17, $02, $B1, $E0, $C4, $37
	dc.b	$06, $1B, $26, $32, $77, $EA, $A4, $10, $EF, $45, $70, $92, $04, $C5, $F0, $1E, $A4, $69, $5B, $8A, $56, $40, $4C, $1C, $11, $4A, $EC, $9D, $24, $3A, $C1, $65
	dc.b	$7D, $A3, $1B, $BA, $F4, $BF, $72, $67, $77, $5E, $78, $3B, $09, $6B, $33, $07, $09, $B3, $0D, $16, $06, $A5, $0A, $E3, $25, $99, $83, $71, $AD, $4D, $5D, $27
	dc.b	$4D, $32, $F6, $AC, $C8, $42, $7B, $3A, $BD, $07, $EB, $07, $5E, $83, $7B, $C3, $A1, $77, $BE, $62, $10, $74, $A9, $49, $03, $A3, $27, $9A, $9E, $6A, $6F, $29
	dc.b	$38, $BF, $22, $79, $87, $0F, $30, $F3, $93, $39, $52, $E7, $04, $3F, $6E, $8C, $11, $BB, $A0, $22, $E5, $CF, $C4, $04, $91, $3F, $BB, $AC, $64, $1F, $AA, $B9
	dc.b	$8C, $6B, $27, $5E, $0E, $F5, $91, $38, $3A, $14, $99, $27, $03, $47, $8C, $57, $F5, $E7, $B4, $66, $F1, $88, $4C, $A1, $C7, $75, $92, $FC, $E7, $13, $BD, $3F
	dc.b	$5D, $38, $97, $98, $D6, $E5, $D6, $F5, $8C, $58, $C1, $E6, $82, $01, $DF, $EE, $20, $65, $FB, $49, $B0, $76, $6B, $7A, $9C, $F1, $F6, $F3, $CA, $55, $65, $8B
	dc.b	$DA, $A7, $66, $09, $5C, $6F, $E8, $80, $8E, $65, $A1, $31, $1E, $C4, $E0, $4F, $1A, $BF, $D8, $3D, $4D, $AE, $69, $96, $DA, $C8, $10, $7B, $8C, $33, $88, $4F
	dc.b	$59, $06, $71, $DE, $0E, $45, $73, $8C, $81, $BE, $A1, $C1, $01, $CE, $36, $DE, $4E, $6C, $06, $5D, $41, $BF, $37, $72, $BC, $81, $25, $DD, $26, $41, $E6, $3F
	dc.b	$23, $33, $71, $F0, $6E, $07, $B1, $CC, $1F, $10, $0D, $0D, $4D, $D7, $24, $58, $C6, $37, $90, $FC, $89, $4A, $F9, $9B, $77, $12, $1C, $B2, $4D, $54, $E1, $CD
	dc.b	$A1, $95, $D8, $89, $E8, $B8, $63, $37, $7E, $BA, $AF, $61, $03, $36, $41, $98, $CE, $FC, $BA, $FE, $DC, $41, $40, $96, $F7, $BF, $A2, $0F, $DE, $5F, $13, $B3
	dc.b	$3A, $26, $BF, $AE, $10, $77, $8D, $C4, $F9, $9C, $DD, $17, $E6, $F3, $40, $5F, $95, $79, $8A, $98, $FC, $A9, $6B, $59, $22, $92, $EA, $9F, $AE, $0C, $0C, $68
	dc.b	$61, $C3, $55, $71, $AC, $87, $85, $94, $CC, $5C, $EC, $35, $9D, $F9, $57, $41, $7C, $88, $64, $B7, $CA, $1A, $A3, $48, $4F, $C8, $DC, $79, $84, $C4, $EA, $DA
	dc.b	$A0, $4E, $84, $AE, $40, $91, $6C, $50, $39, $0E, $59, $22, $9B, $E0, $FF, $2B, $1B, $CE, $13, $98, $E9, $7E, $09, $D3, $62, $3D, $F4, $79, $BD, $DB, $86, $A8
	dc.b	$93, $BA, $06, $CA, $FD, $55, $01, $32, $A6, $37, $54, $A2, $59, $3E, $A5, $DD, $33, $64, $68, $EE, $74, $89, $58, $10, $8C, $43, $8C, $83, $99, $4E, $79, $DE
	dc.b	$40, $C9, $E3, $3A, $C0, $20, $6F, $C6, $A4, $3F, $5D, $5C, $4C, $B5, $CF, $24, $08, $4D, $FB, $A2, $92, $F2, $34, $B3, $79, $A0, $B9, $EB, $AC, $D4, $B7, $D7
	dc.b	$10, $C4, $18, $1E, $4F, $37, $7E, $44, $F9, $E2, $22, $55, $19, $E4, $B7, $C6, $C4, $31, $08, $A6, $96, $45, $69, $22, $A7, $54, $04, $81, $16, $4A, $E5, $C1
	dc.b	$D8, $5D, $93, $99, $E5, $C9, $2A, $8D, $03, $41, $92, $08, $B4, $68, $11, $FA, $46, $81, $8B, $93, $04, $84, $ED, $34, $B5, $C1, $26, $CF, $AD, $F5, $E8, $18
	dc.b	$23, $B3, $EF, $9E, $2C, $BD, $EE, $38, $F1, $02, $1C, $77, $74, $C9, $4E, $63, $F5, $42, $12, $3F, $5C, $0A, $B0, $D7, $EB, $81, $1B, $24, $B5, $72, $3C, $C8
	dc.b	$1E, $D3, $1A, $DB, $49, $3F, $6F, $D7, $30, $CC, $E7, $AB, $0C, $E6, $81, $81, $2C, $CD, $20, $A7, $CB, $58, $7C, $8E, $4B, $A1, $A9, $72, $4B, $A4, $0D, $3B
	dc.b	$97, $96, $AB, $16, $91, $AD, $CA, $62, $4A, $4B, $AD, $A0, $B5, $6C, $BF, $23, $91, $61, $7B, $CE, $58, $BE, $50, $61, $AF, $1D, $24, $63, $A0, $68, $ED, $AC
	dc.b	$8F, $6E, $B2, $64, $D9, $05, $6D, $03, $11, $56, $58, $47, $5C, $E1, $A0, $40, $90, $DA, $6C, $81, $07, $EC, $C2, $2F, $EC, $D7, $4E, $34, $ED, $FB, $30, $81
	dc.b	$2D, $A0, $D3, $64, $54, $D9, $15, $3D, $26, $C9, $45, $4D, $92, $9D, $B1, $18, $8E, $F6, $90, $C5, $51, $83, $F8, $69, $92, $E8, $1C, $2E, $5E, $FD, $91, $53
	dc.b	$13, $80, $96, $48, $56, $58, $D2, $1F, $81, $3E, $FC, $1A, $1B, $AB, $73, $5B, $CD, $9F, $A2, $B8, $83, $D5, $A2, $69, $59, $2E, $E3, $15, $D4, $55, $AD, $F9
	dc.b	$16, $B9, $86, $27, $D1, $01, $75, $99, $A4, $29, $2B, $A7, $2B, $3C, $3A, $72, $17, $96, $5C, $5E, $55, $F2, $0C, $A4, $A8, $19, $4A, $F9, $07, $A5, $9C, $AC
	dc.b	$25, $5B, $DD, $21, $92, $4B, $F6, $7B, $7F, $0F, $84, $09, $C2, $03, $F5, $3D, $2C, $92, $F7, $1C, $B3, $53, $E5, $9A, $48, $9E, $52, $5D, $2C, $7F, $91, $F7
	dc.b	$04, $3F, $2A, $41, $E0, $AA, $A4, $33, $41, $FA, $E1, $9A, $63, $B4, $2B, $FB, $8C, $64, $58, $9A, $45, $E6, $0B, $21, $97, $9B, $E4, $33, $96, $68, $60, $B4
	dc.b	$F2, $3B, $C8, $21, $79, $9F, $B8, $C9, $50, $82, $0A, $AB, $C1, $48, $8D, $4E, $DE, $F6, $37, $4C, $17, $EF, $95, $0B, $F5, $C1, $A6, $64, $35, $0C, $97, $AF
	dc.b	$EB, $9D, $20, $6E, $E0, $C3, $29, $B8, $18, $3B, $75, $37, $9C, $FA, $9A, $CC, $47, $EB, $2C, $6D, $D8, $8F, $D1, $D9, $88, $C8, $6E, $0C, $8D, $77, $0E, $17
	dc.b	$AE, $A1, $D2, $18, $1A, $B8, $4D, $67, $FA, $2C, $97, $0B, $FF, $44, $12, $41, $FC, $49, $CB, $ED, $92, $16, $15, $1E, $D9, $24, $C5, $4F, $89, $AE, $F5, $7D
	dc.b	$F2, $D7, $13, $BA, $30, $53, $82, $C1, $D8, $1A, $BB, $01, $5B, $F8, $C1, $AB, $37, $34, $FD, $A5, $82, $3B, $0B, $DC, $1C, $F6, $32, $1A, $63, $3C, $5C, $64
	dc.b	$34, $34, $73, $4F, $1F, $68, $99, $95, $47, $B3, $AF, $1D, $D2, $CC, $14, $8C, $4B, $D9, $C7, $29, $A4, $BF, $44, $62, $F4, $97, $ED, $2F, $98, $2D, $01, $07
	dc.b	$2E, $32, $2E, $53, $BB, $63, $6F, $4E, $97, $A9, $29, $2B, $8E, $56, $D6, $0E, $5D, $8C, $16, $D3, $D9, $B2, $42, $BB, $17, $54, $3B, $83, $13, $E0, $C4, $F8
	dc.b	$75, $03, $BA, $2C, $91, $77, $25, $C4, $9C, $BD, $10, $1C, $CF, $29, $DC, $F9, $82, $3A, $EA, $2F, $B1, $FE, $B1, $1E, $BF, $BC, $12, $30, $DF, $B3, $06, $C7
	dc.b	$A0, $41, $7B, $FF, $4E, $52, $C4, $31, $F5, $57, $C9, $2F, $CA, $BE, $61, $25, $80, $D4, $32, $19, $0D, $DC, $6A, $E1, $FA, $C7, $77, $60, $DD, $ED, $FA, $86
	dc.b	$EF, $FD, $BF, $EE, $A7, $69, $AA, $3E, $72, $8A, $BB, $0C, $83, $EE, $09, $66, $1E, $12, $CE, $09, $05, $67, $5C, $C8, $09, $60, $4A, $2A, $CA, $F8, $63, $0C
	dc.b	$B2, $30, $5C, $24, $9D, $5B, $A5, $55, $4B, $65, $69, $AD, $D9, $5A, $72, $B3, $B2, $84, $91, $0C, $85, $5C, $A4, $32, $05, $32, $04, $32, $42, $19, $8B, $B2
	dc.b	$C4, $3C, $DD, $83, $F2, $65, $71, $BF, $5B, $95, $97, $48, $EE, $B5, $51, $DD, $DB, $8A, $B4, $EC, $42, $19, $3C, $EA, $EB, $EB, $CD, $66, $22, $C8, $FB, $F0
	dc.b	$BA, $5C, $EF, $56, $99, $DB, $45, $76, $F3, $B2, $38, $33, $BB, $9A, $E7, $15, $CE, $EE, $6B, $9B, $0A, $97, $F2, $8A, $F4, $F2, $5F, $D6, $DE, $73, $0E, $8A
	dc.b	$DE, $13, $D9, $60, $9A, $FD, $EB, $28, $0D, $2D, $EB, $28, $0D, $76, $E4, $20, $BA, $29, $59, $F3, $E4, $E0, $41, $2F, $D6, $72, $5F, $27, $E5, $12, $6B, $B1
	dc.b	$11, $FB, $4F, $C8, $94, $58, $BF, $22, $62, $4A, $49, $0F, $AC, $B3, $08, $71, $D9, $D0, $B9, $D9, $17, $35, $76, $57, $4F, $AB, $D9, $CB, $5F, $77, $C6, $E7
	dc.b	$FA, $26, $23, $71, $37, $E8, $A4, $6E, $21, $E4, $E3, $48, $15, $E4, $CE, $9F, $9F, $EB, $A4, $2F, $41, $1B, $88, $BF, $47, $F7, $5E, $F7, $16, $00, $D7, $71
	dc.b	$0D, $77, $E8, $9E, $53, $6B, $B7, $77, $E9, $BF, $67, $FA, $CB, $BC, $B4, $FC, $AF, $3F, $3E, $4E, $1E, $5B, $4B, $23, $AC, $56, $F3, $54, $12, $23, $4D, $F0
	dc.b	$08, $4C, $3A, $B3, $A1, $4B, $07, $33, $A1, $4A, $B1, $DA, $F7, $BA, $F8, $52, $59, $20, $81, $13, $D6, $E8, $9E, $45, $B4, $2A, $2E, $B1, $6F, $C8, $C8, $F6
	dc.b	$FC, $8D, $E6, $0D, $7F, $42, $0A, $DF, $A1, $49, $18, $8B, $42, $04, $67, $79, $BA, $F2, $1D, $14, $93, $37, $97, $5C, $1F, $83, $98, $BF, $6D, $D5, $A7, $CF
	dc.b	$02, $79, $B5, $A0, $26, $E3, $9D, $E0, $AA, $F1, $FA, $D9, $2C, $FC, $F7, $39, $CA, $62, $7F, $91, $93, $CC, $8E, $39, $B5, $DD, $4F, $0E, $6E, $C3, $A9, $FE
	dc.b	$AB, $57, $EA, $DA, $6E, $4D, $7D, $73, $7E, $52, $AF, $E4, $75, $E9, $89, $F7, $09, $62, $6F, $93, $CE, $43, $35, $B9, $0D, $D9, $AE, $17, $BD, $DB, $3F, $02
	dc.b	$3D, $9A, $0D, $B9, $2E, $05, $7D, $79, $5A, $F6, $3E, $2A, $1E, $2E, $6B, $96, $2A, $33, $57, $4D, $73, $40, $77, $D4, $B5, $40, $D7, $D4, $AD, $50, $EF, $51
	dc.b	$D9, $D3, $E0, $9D, $7E, $31, $22, $64, $06, $27, $2C, $D2, $1A, $F2, $9F, $56, $4C, $1E, $2F, $EB, $17, $13, $C1, $2A, $11, $A9, $D9, $25, $95, $EF, $CF, $4C
	dc.b	$50, $4D, $70, $AE, $EE, $99, $3C, $19, $4F, $2C, $48, $D8, $1C, $AE, $96, $13, $C9, $E7, $7E, $1D, $5F, $22, $12, $B4, $9D, $FA, $E7, $7E, $BA, $BF, $AA, $C3
	dc.b	$9D, $F3, $09, $B2, $66, $DC, $CD, $CF, $D5, $CA, $5B, $49, $2E, $56, $D7, $CD, $C6, $1A, $D9, $98, $6D, $65, $AD, $B9, $96, $06, $AD, $A4, $21, $02, $17, $E5
	dc.b	$7C, $C8, $EB, $90, $DE, $D8, $86, $D8, $A0, $32, $C8, $3F, $89, $3E, $B6, $D0, $5D, $97, $6B, $8E, $DA, $0B, $AD, $90, $3C, $27, $93, $40, $65, $7A, $A3, $42
	dc.b	$E4, $1C, $9B, $64, $1C, $8D, $5D, $5C, $A6, $96, $73, $03, $E1, $21, $B1, $2B, $40, $8F, $DC, $D7, $2C, $04, $99, $25, $AB, $12, $48, $AC, $61, $39, $12, $C8
	dc.b	$49, $24, $7C, $85, $E0, $83, $F9, $0B, $FD, $C6, $B7, $A9, $3C, $66, $8E, $99, $3C, $24, $DF, $93, $81, $03, $E4, $2A, $4B, $2B, $7F, $1D, $52, $FF, $DB, $A9
	dc.b	$1D, $06, $77, $F2, $27, $0C, $CF, $BE, $F2, $D7, $2C, $66, $68, $46, $C2, $BD, $6E, $58, $04, $BC, $AC, $4B, $C8, $40, $2E, $AA, $F2, $04, $B2, $AB, $F8, $67
	dc.b	$58, $B8, $4C, $9D, $F9, $10, $E3, $AB, $59, $3F, $78, $10, $62, $81, $82, $2E, $28, $1A, $5D, $E1, $96, $43, $4B, $5C, $7F, $B3, $61, $72, $A0, $46, $7D, $F8
	dc.b	$FF, $8F, $6F, $D9, $ED, $FB, $3D, $BB, $E3, $6E, $F8, $D1, $7F, $86, $31, $1F, $C3, $07, $08, $3F, $67, $07, $6D, $02, $63, $B2, $43, $B1, $DA, $06, $B4, $B2
	dc.b	$40, $90, $FD, $7B, $44, $82, $58, $E4, $59, $3E, $12, $31, $93, $1E, $01, $AD, $A4, $69, $66, $80, $E4, $EC, $69, $D3, $8A, $F6, $3F, $D3, $ED, $7C, $96, $56
	dc.b	$FD, $47, $21, $01, $16, $16, $0D, $BF, $22, $3A, $48, $E0, $63, $62, $10, $31, $4E, $8C, $19, $5D, $BA, $6F, $E6, $7F, $BC, $0E, $12, $DA, $B7, $1B, $92, $B2
	dc.b	$75, $05, $C4, $64, $F2, $C8, $5C, $F1, $27, $90, $C0, $B8, $78, $25, $92, $95, $CF, $37, $AE, $42, $E1, $5C, $B9, $D4, $C3, $F2, $9D, $C1, $9F, $4E, $6E, $48
	dc.b	$A9, $36, $A2, $BA, $FE, $57, $78, $AF, $6F, $1B, $6F, $9F, $6C, $F6, $B9, $2B, $74, $E4, $92, $A0, $E8, $AF, $32, $CB, $F2, $37, $37, $A8, $F5, $50, $47, $C2
	dc.b	$17, $04, $82, $BF, $A7, $76, $4F, $96, $34, $D9, $1F, $78, $C6, $36, $32, $C5, $B3, $06, $40, $86, $60, $DE, $A9, $EF, $AA, $A2, $91, $AD, $E6, $0C, $BF, $5D
	dc.b	$49, $C8, $F8, $21, $9E, $C4, $6F, $2E, $3F, $5D, $63, $15, $07, $63, $25, $3F, $CA, $A9, $CA, $F2, $CA, $A6, $D4, $0C, $64, $37, $06, $2F, $21, $D5, $8F, $6D
	dc.b	$41, $ED, $AA, $B7, $63, $69, $0F, $D7, $0A, $BD, $6E, $6F, $2A, $55, $28, $96, $FC, $AA, $E7, $56, $F6, $3F, $46, $99, $A1, $E7, $5B, $5D, $6C, $3F, $4F, $91
	dc.b	$D3, $D2, $73, $E1, $35, $8B, $64, $40, $B1, $CA, $32, $62, $59, $DC, $EB, $8D, $EA, $4F, $37, $AD, $E3, $C8, $61, $E5, $2B, $E9, $E4, $61, $D3, $09, $66, $72
	dc.b	$F7, $86, $39, $AE, $A1, $8C, $10, $D6, $D3, $2A, $E8, $A6, $A5, $83, $C7, $9B, $9A, $9B, $26, $DE, $EB, $25, $F7, $98, $47, $35, $36, $3D, $B3, $3E, $26, $57
	dc.b	$CF, $29, $61, $46, $B5, $4E, $D2, $52, $3B, $4B, $8C, $78, $31, $88, $92, $B1, $84, $12, $56, $57, $60, $82, $57, $B5, $2D, $98, $EA, $72, $19, $9E, $D8, $86
	dc.b	$35, $31, $8F, $06, $98, $86, $BE, $C9, $89, $1C, $B6, $6F, $33, $B4, $A8, $75, $2F, $19, $D4, $74, $10, $B0, $B1, $41, $55, $AA, $E2, $4F, $F1, $CC, $62, $4F
	dc.b	$F0, $EC, $10, $B0, $AF, $46, $A0, $60, $42, $E5, $95, $AB, $72, $C8, $5E, $61, $DD, $89, $DB, $1A, $C5, $9C, $0E, $26, $A9, $52, $C2, $1F, $2A, $D3, $A1, $2D
	dc.b	$D9, $7A, $C9, $D1, $B5, $C2, $04, $C4, $85, $D9, $4F, $29, $9A, $0B, $B2, $9E, $53, $32, $17, $64, $0D, $C7, $87, $E5, $6F, $9D, $34, $EB, $D2, $FA, $FE, $44
	dc.b	$9B, $A1, $42, $D5, $84, $08, $5A, $B7, $44, $85, $AB, $08, $41, $D4, $32, $90, $70, $C3, $2C, $52, $E2, $A5, $7C, $D8, $B0, $7A, $0E, $9B, $5D, $16, $40, $EE
	dc.b	$12, $AE, $8A, $EA, $2B, $90, $A9, $7E, $44, $57, $22, $5C, $AF, $6B, $D7, $0A, $10, $D1, $48, $48, $7E, $46, $60, $84, $87, $95, $A4, $BF, $AD, $05, $C8, $7E
	dc.b	$B4, $10, $91, $ED, $9F, $97, $5A, $96, $F4, $72, $6C, $6A, $9B, $1A, $1F, $04, $82, $62, $4A, $F0, $CB, $25, $78, $71, $89, $29, $07, $21, $3F, $2B, $F2, $8A
	dc.b	$02, $64, $BF, $4B, $D5, $B6, $60, $6C, $11, $61, $8D, $84, $59, $89, $93, $64, $7B, $08, $5C, $45, $F9, $43, $E1, $25, $4C, $25, $E6, $FE, $F3, $54, $DA, $6E
	dc.b	$64, $13, $B3, $5A, $6B, $8B, $B5, $D9, $FA, $E2, $C3, $A3, $85, $70, $4C, $2F, $75, $09, $66, $40, $E8, $A9, $7C, $F8, $91, $4F, $82, $F2, $D8, $C8, $E7, $B6
	dc.b	$53, $38, $27, $49, $D4, $FD, $17, $1D, $78, $8F, $D1, $14, $12, $FE, $44, $14, $5B, $F2, $20, $AC, $D6, $8B, $4D, $DE, $68, $F4, $07, $46, $EA, $D7, $37, $31
	dc.b	$D0, $8C, $54, $1A, $C8, $3A, $A2, $FD, $36, $A9, $F7, $AE, $2B, $D1, $81, $BC, $7E, $97, $CD, $BC, $A9, $5F, $D5, $49, $2A, $0C, $74, $DB, $C7, $4B, $36, $5D
	dc.b	$A1, $CF, $DE, $C8, $E7, $F2, $B2, $3B, $09, $BB, $03, $75, $D4, $27, $26, $CF, $B2, $72, $0F, $B2, $72, $E2, $7D, $A3, $B3, $A2, $7B, $5F, $54, $71, $60, $EA
	dc.b	$D2, $BD, $90, $83, $B8, $CA, $81, $DB, $46, $4E, $8E, $32, $74, $6D, $A8, $AE, $39, $5D, $57, $51, $9C, $77, $E5, $FA, $63, $C4, $1C, $27, $47, $32, $D4, $67
	dc.b	$13, $07, $58, $F0, $F5, $3C, $4B, $F2, $27, $35, $C4, $79, $5E, $D8, $16, $53, $BC, $A9, $2F, $CA, $BF, $06, $8A, $88, $B3, $21, $0E, $95, $B1, $5A, $BB, $3A
	dc.b	$B1, $55, $80, $E2, $15, $25, $63, $71, $48, $F2, $BE, $83, $D8, $39, $49, $B3, $EA, $18, $26, $70, $EB, $47, $2D, $89, $BB, $DC, $99, $A5, $A7, $22, $15, $68
	dc.b	$7F, $56, $FC, $8D, $13, $B6, $9D, $03, $2C, $27, $40, $64, $3A, $59, $C4, $3A, $2C, $9A, $B6, $F1, $23, $85, $C0, $77, $65, $34, $75, $17, $7A, $AC, $D2, $BB
	dc.b	$D7, $6A, $EF, $B4, $55, $61, $AA, $86, $37, $86, $AA, $3A, $37, $8B, $64, $E0, $58, $57, $95, $01, $8C, $BA, $29, $0B, $BD, $5D, $1E, $9F, $B1, $07, $35, $A0
	dc.b	$AA, $BE, $73, $C7, $09, $38, $8C, $84, $52, $0E, $E3, $19, $B0, $7B, $1F, $BB, $0A, $91, $F1, $56, $12, $B6, $4C, $41, $33, $18, $6A, $12, $D5, $0F, $C3, $27
	dc.b	$E3, $7D, $1A, $89, $4D, $BA, $83, $DB, $F2, $22, $7B, $68, $21, $4A, $D1, $B9, $63, $5A, $76, $35, $72, $2B, $59, $D6, $63, $B2, $2B, $40, $D3, $10, $D6, $48
	dc.b	$72, $B2, $2B, $23, $61, $7A, $2B, $69, $D9, $BA, $0F, $D6, $1F, $2B, $EA, $7E, $66, $B7, $19, $2A, $59, $86, $E8, $B2, $5E, $92, $EB, $21, $BC, $16, $58, $75
	dc.b	$C2, $2E, $75, $2C, $77, $8B, $82, $5A, $B3, $C7, $2F, $D5, $16, $C4, $B2, $D9, $FA, $CC, $AC, $E5, $32, $DB, $07, $35, $64, $52, $A2, $E7, $57, $C8, $B1, $FD
	dc.b	$AA, $76, $E8, $0B, $67, $C1, $97, $63, $EC, $80, $A5, $94, $F1, $C0, $C2, $50, $D4, $AD, $7B, $C3, $0E, $46, $CF, $57, $F2, $17, $29, $46, $A2, $EE, $C7, $0C
	dc.b	$B1, $CC, $E4, $DE, $C6, $4E, $CE, $01, $1E, $1C, $D6, $47, $7B, $B0, $75, $68, $F1, $39, $15, $CE, $D8, $B0, $21, $8C, $04, $B9, $AA, $0A, $01, $88, $40, $58
	dc.b	$DF, $76, $93, $49, $2B, $21, $65, $D3, $F5, $C3, $73, $A0, $CC, $78, $7E, $0C, $A5, $F9, $19, $4F, $DF, $BC, $DC, $33, $54, $0E, $12, $CB, $07, $FE, $A4, $B2
	dc.b	$FC, $8E, $96, $BB, $F7, $C5, $4B, $6B, $9C, $F3, $35, $D2, $DE, $F2, $5E, $FC, $E5, $69, $25, $E5, $A7, $20, $8E, $CC, $3E, $4A, $EC, $D2, $60, $A8, $B9, $A0
	dc.b	$49, $AF, $98, $9A, $4E, $43, $59, $89, $25, $E3, $5B, $25, $FA, $79, $90, $79, $6A, $33, $59, $C2, $E6, $0E, $9B, $7B, $E4, $71, $9E, $83, $24, $20, $8A, $85
	dc.b	$6E, $F5, $79, $DE, $09, $F7, $BE, $C4, $35, $B1, $D2, $9C, $1A, $96, $D9, $1C, $8B, $68, $17, $90, $D4, $44, $8C, $38, $FC, $EA, $10, $98, $BF, $5C, $93, $26
	dc.b	$1E, $54, $09, $32, $E2, $4B, $52, $53, $78, $32, $3B, $73, $BA, $A3, $3B, $E4, $FE, $B2, $F3, $E4, $3C, $95, $D7, $84, $B4, $DD, $43, $07, $B4, $D0, $81, $CC
	dc.b	$C3, $C1, $5E, $A8, $56, $3B, $D4, $AE, $9D, $EB, $00, $AE, $52, $0E, $99, $8E, $AA, $73, $A2, $F4, $26, $09, $B1, $F1, $D4, $D9, $2D, $C8, $D5, $01, $F4, $39
	dc.b	$3F, $0D, $78, $20, $76, $31, $53, $A7, $07, $07, $B2, $02, $7A, $EA, $0E, $E2, $06, $B3, $17, $29, $C8, $E4, $D8, $E0, $5B, $12, $90, $92, $90, $8A, $5B, $55
	dc.b	$32, $12, $D5, $4C, $57, $89, $4F, $2B, $40, $90, $B9, $0F, $22, $D6, $4A, $6E, $B4, $B1, $06, $3A, $89, $50, $10, $BF, $A8, $91, $E4, $72, $59, $B1, $D4, $93
	dc.b	$C8, $56, $63, $3F, $25, $3D, $1D, $05, $7E, $85, $3C, $23, $39, $D6, $FF, $62, $F0, $EA, $56, $F8, $AE, $1F, $AB, $95, $64, $79, $78, $2D, $BF, $59, $01, $C6
	dc.b	$BA, $06, $31, $7C, $4D, $18, $6B, $D8, $D6, $B4, $D8, $D6, $A7, $B1, $DB, $52, $B4, $37, $BD, $B7, $CE, $57, $9C, $06, $C8, $B2, $59, $1B, $63, $3C, $9D, $9A
	dc.b	$94, $E9, $93, $8A, $C5, $35, $CC, $54, $4F, $27, $7B, $E4, $93, $C5, $73, $C8, $79, $39, $30, $BC, $D3, $0D, $B1, $5C, $16, $0C, $20, $75, $14, $86, $30, $91
	dc.b	$66, $0C, $23, $F2, $2B, $8A, $0A, $F1, $02, $0D, $E5, $91, $BF, $21, $1E, $C6, $EB, $FD, $A3, $AD, $70, $BB, $0B, $A9, $FA, $FF, $39, $56, $E9, $78, $75, $7C
	dc.b	$DC, $9D, $31, $7B, $10, $FD, $78, $26, $19, $E5, $83, $3C, $B0, $71, $1A, $90, $25, $BF, $62, $A2, $CB, $62, $5B, $B3, $52, $05, $76, $60, $94, $BD, $55, $3F
	dc.b	$44, $3B, $84, $C4, $94, $86, $33, $09, $4D, $B1, $98, $25, $35, $9E, $D9, $6D, $72, $E4, $96, $6B, $26, $2F, $2C, $83, $EE, $CA, $14, $DF, $D2, $F8, $5C, $5F
	dc.b	$D2, $EA, $59, $32, $E9, $92, $13, $0B, $FA, $54, $13, $2F, $E4, $60, $10, $75, $CB, $59, $DD, $D0, $4C, $F1, $8A, $DF, $D5, $97, $2B, $BF, $45, $75, $14, $AE
	dc.b	$E8, $77, $74, $C2, $F4, $27, $B7, $E4, $4C, $3F, $A5, $A6, $E9, $C5, $46, $B2, $27, $DF, $2C, $24, $E1, $71, $CE, $D9, $14, $2C, $81, $65, $42, $92, $C8, $16
	dc.b	$40, $96, $40, $B2, $B4, $D5, $36, $6B, $3B, $1B, $C1, $D7, $00, $7D, $68, $0A, $29, $DA, $01, $7A, $94, $0F, $D1, $56, $D8, $F5, $56, $58, $49, $64, $08, $1E
	dc.b	$0F, $52, $9A, $3B, $03, $D0, $4C, $65, $8D, $07, $40, $93, $7C, $EC, $C8, $72, $C0, $7E, $B0, $9B, $10, $79, $82, $70, $83, $DC, $9F, $8C, $DF, $7F, $E8, $6E
	dc.b	$17, $0F, $D8, $BC, $5D, $41, $D3, $F2, $39, $44, $A2, $72, $F3, $94, $49, $89, $B8, $63, $FD, $65, $A2, $E3, $7D, $70, $37, $5C, $B1, $D8, $E2, $C5, $4A, $29
	dc.b	$89, $A9, $29, $FA, $34, $2D, $AE, $A8, $C0, $9D, $85, $D5, $10, $B9, $E2, $1D, $3D, $B1, $A0, $FC, $8F, $6D, $08, $67, $F9, $15, $81, $A4, $C9, $60, $72, $61
	dc.b	$19, $38, $B0, $C6, $F3, $99, $1B, $93, $F2, $21, $C4, $77, $27, $B5, $0D, $CB, $93, $BA, $09, $90, $95, $FE, $0E, $36, $CC, $DB, $B1, $E3, $73, $81, $45, $CF
	dc.b	$77, $B5, $EE, $99, $7E, $8B, $0B, $E2, $74, $1F, $AF, $AE, $50, $E2, $BF, $39, $65, $4D, $C8, $EC, $5A, $13, $47, $33, $C1, $D7, $66, $A4, $3F, $68, $26, $B9
	dc.b	$D2, $D3, $25, $BA, $D0, $5C, $26, $C9, $68, $25, $40, $5D, $70, $93, $AF, $F7, $B2, $35, $6C, $EA, $5A, $33, $B2, $46, $C6, $34, $1E, $01, $84, $DF, $C5, $91
	dc.b	$A4, $33, $37, $30, $9D, $77, $20, $C2, $71, $AC, $06, $4A, $02, $D7, $20, $E0, $EA, $EA, $F0, $7A, $42, $BE, $D8, $B6, $A1, $06, $9F, $AA, $CB, $19, $BC, $82
	dc.b	$0E, $A6, $F0, $92, $4D, $E7, $40, $69, $21, $B9, $A3, $C6, $96, $B9, $F9, $9A, $A5, $CA, $F1, $D5, $16, $53, $37, $44, $F2, $92, $A1, $E7, $B2, $1D, $29, $D9
	dc.b	$36, $B8, $49, $73, $17, $0E, $49, $9A, $9D, $FE, $C7, $95, $FD, $B7, $96, $C5, $BD, $25, $3B, $16, $E0, $BB, $21, $32, $97, $41, $36, $52, $E8, $C6, $09, $F7
	dc.b	$41, $A6, $F7, $59, $C3, $7B, $97, $4A, $27, $0E, $FC, $88, $DD, $5C, $0D, $5A, $14, $E0, $31, $40, $74, $61, $7B, $07, $DF, $5B, $B8, $92, $F9, $D5, $D9, $63
	dc.b	$94, $A8, $A6, $56, $3E, $59, $17, $E9, $FF, $5C, $58, $1F, $92, $71, $00, $AE, $17, $38, $1E, $28, $5A, $83, $76, $39, $5F, $C8, $81, $CD, $A8, $EE, $48, $40
	dc.b	$9F, $3C, $C2, $12, $07, $79, $20, $41, $DD, $E6, $96, $C6, $68, $D5, $7F, $29, $C6, $5D, $66, $08, $3C, $B5, $29, $69, $4C, $19, $4B, $F5, $D2, $3F, $D3, $98
	dc.b	$3E, $56, $60, $97, $CB, $67, $46, $58, $65, $8C, $AB, $95, $F8, $2B, $D4, $DD, $82, $9F, $59, $15, $05, $D8, $3B, $F2, $A6, $8F, $6C, $1D, $A1, $82, $0D, $76
	dc.b	$6B, $0A, $5B, $3B, $27, $3C, $9F, $95, $AA, $93, $18, $09, $A6, $EE, $FD, $0E, $50, $8E, $0E, $99, $D0, $3B, $1E, $C7, $D4, $3A, $13, $B6, $EB, $BB, $B7, $DA
	dc.b	$40, $DA, $C7, $55, $70, $E9, $3E, $A3, $16, $A6, $90, $E0, $ED, $29, $B2, $5B, $F5, $95, $87, $34, $5A, $48, $0C, $49, $5A, $01, $B5, $FA, $75, $12, $AD, $0F
	dc.b	$4B, $CC, $72, $45, $90, $30, $7C, $20, $39, $B6, $A9, $40, $92, $09, $E4, $33, $BC, $D1, $67, $5B, $A9, $6F, $2B, $4F, $7D, $7A, $86, $74, $6A, $EC, $51, $8E
	dc.b	$EB, $F5, $86, $B1, $59, $01, $CB, $F6, $6A, $E4, $92, $2E, $74, $A9, $48, $FF, $22, $32, $DB, $C1, $D4, $A4, $0F, $9F, $99, $48, $D3, $39, $64, $35, $5C, $D9
	dc.b	$E7, $6C, $D1, $EA, $5F, $AE, $A0, $FC, $A8, $3D, $BC, $5E, $3F, $59, $0F, $37, $9B, $B7, $73, $CD, $EE, $3B, $8C, $77, $95, $C3, $58, $D7, $F4, $BD, $D1, $4F
	dc.b	$55, $CB, $6F, $00, $B2, $8F, $CA, $F8, $BA, $0B, $01, $FA, $83, $82, $EE, $0C, $86, $BA, $88, $AE, $C6, $D5, $CA, $E2, $5B, $8A, $8A, $D6, $B8, $95, $83, $3D
	dc.b	$88, $65, $73, $D9, $ED, $70, $A8, $71, $7E, $BB, $09, $F7, $14, $3B, $51, $FA, $53, $26, $07, $68, $05, $73, $52, $CF, $CD, $7A, $E4, $B0, $0B, $90, $AB, $27
	dc.b	$EA, $3D, $9E, $2E, $07, $C5, $C7, $D9, $8C, $36, $A8, $C1, $9D, $41, $BB, $EC, $D6, $68, $05, $FC, $C4, $62, $61, $7D, $AF, $C0, $FB, $12, $CB, $7B, $93, $B6
	dc.b	$74, $53, $2D, $E0, $9C, $1C, $5A, $8C, $C3, $7E, $B9, $0C, $B5, $06, $35, $62, $36, $9B, $66, $CF, $04, $C5, $DD, $13, $B8, $3B, $2E, $87, $5A, $10, $CB, $82
	dc.b	$95, $6D, $90, $AC, $A3, $F4, $AA, $84, $D8, $DD, $ED, $70, $DC, $7E, $BB, $30, $E4, $BF, $F5, $4D, $77, $B5, $7A, $E1, $4C, $2E, $2C, $9D, $DC, $40, $DA, $43
	dc.b	$DF, $09, $B7, $97, $2C, $E6, $EE, $F9, $BA, $01, $83, $B4, $6A, $C7, $B3, $67, $DD, $D6, $81, $DA, $67, $67, $0A, $88, $DA, $5C, $3A, $A7, $73, $A7, $96, $12
	dc.b	$D8, $84, $F8, $25, $BE, $64, $1C, $77, $D0, $1A, $31, $2E, $B3, $C8, $95, $1D, $94, $29, $08, $0D, $CF, $37, $FE, $54, $D4, $98, $30, $3F, $C8, $C0, $C5, $A3
	dc.b	$F4, $F0, $D5, $C9, $F5, $A5, $A5, $86, $4E, $96, $E5, $22, $41, $0A, $41, $D8, $1D, $CD, $D5, $FB, $DE, $BA, $A9, $86, $7F, $11, $76, $1B, $BD, $9C, $FA, $0C
	dc.b	$3A, $E1, $AF, $05, $7E, $F5, $7E, $AE, $A9, $B4, $5D, $7B, $F0, $36, $18, $12, $70, $5B, $38, $5C, $21, $FE, $D0, $4C, $EA, $21, $F8, $7E, $61, $87, $E4, $52
	dc.b	$36, $DF, $45, $AD, $EE, $C2, $46, $E7, $E2, $EA, $D8, $86, $31, $56, $5C, $43, $20, $BB, $DA, $51, $4C, $57, $DC, $26, $19, $56, $3D, $DC, $BD, $3C, $0A, $DE
	dc.b	$B7, $A6, $47, $B2, $1A, $A0, $61, $06, $A7, $0C, $32, $6E, $6E, $A4, $13, $65, $FB, $24, $0D, $2B, $1D, $C4, $3A, $F9, $36, $0C, $E0, $57, $95, $70, $7D, $EE
	dc.b	$B8, $7E, $44, $DA, $7A, $8E, $E6, $7E, $0C, $EC, $3A, $D1, $9D, $83, $60, $DD, $48, $C1, $91, $AD, $CD, $83, $BC, $BA, $DC, $30, $7D, $47, $E5, $48, $4D, $61
	dc.b	$05, $C0, $D9, $74, $21, $93, $C2, $65, $85, $08, $3E, $4E, $40, $C0, $B0, $9A, $2B, $0B, $99, $25, $68, $95, $72, $37, $5E, $F5, $70, $69, $68, $AE, $86, $08
	dc.b	$DD, $44, $5D, $F9, $56, $A6, $EB, $25, $6F, $CA, $D4, $90, $5D, $8D, $BF, $88, $DD, $C3, $03, $10, $79, $82, $0E, $4F, $D7, $42, $62, $AF, $EB, $18, $A6, $17
	dc.b	$52, $2C, $E3, $EE, $1E, $F8, $1B, $CD, $BD, $C5, $D8, $3A, $5F, $AC, $76, $0E, $BC, $86, $B2, $69, $36, $7F, $AE, $89, $6A, $DD, $D5, $BD, $D1, $43, $4F, $67
	dc.b	$73, $C4, $65, $98, $28, $18, $7E, $CB, $0F, $CA, $87, $1B, $89, $5C, $1D, $B4, $5B, $17, $AC, $02, $15, $B2, $3A, $84, $D8, $5F, $ED, $A0, $B9, $E3, $90, $4C
	dc.b	$DB, $62, $9F, $87, $E3, $27, $18, $70, $82, $D9, $DC, $27, $93, $B3, $D5, $A8, $0A, $04, $B7, $BD, $30, $21, $2C, $D9, $08, $FF, $68, $1D, $52, $75, $D0, $BA
	dc.b	$A9, $27, $E5, $6C, $77, $CB, $57, $86, $BB, $2F, $7A, $21, $82, $C1, $3A, $64, $E0, $58, $1F, $50, $D9, $87, $79, $33, $E3, $77, $5E, $86, $23, $37, $8B, $8A
	dc.b	$01, $0B, $9E, $0D, $51, $8A, $E2, $A1, $02, $AB, $FF, $2B, $89, $6E, $5B, $7E, $B0, $9E, $B0, $0B, $AE, $18, $E5, $8F, $25, $C9, $53, $73, $28, $19, $F8, $67
	dc.b	$B6, $72, $A5, $A3, $0B, $8A, $2D, $5C, $83, $16, $D8, $9A, $DD, $E2, $0B, $2B, $F1, $1E, $01, $E4, $B7, $2A, $36, $5C, $67, $2C, $A9, $C1, $06, $90, $F7, $56
	dc.b	$71, $7A, $AC, $72, $76, $0E, $95, $E3, $92, $BE, $B2, $45, $32, $BB, $4B, $B3, $BA, $62, $B4, $BC, $97, $C6, $39, $41, $2B, $7A, $95, $AE, $C1, $ED, $ED, $24
	dc.b	$E6, $EF, $DA, $36, $0C, $96, $C0, $54, $56, $EF, $6A, $29, $FE, $54, $75, $79, $AC, $57, $A8, $25, $7D, $73, $98, $CF, $1E, $A4, $85, $DE, $4F, $EB, $9F, $3C
	dc.b	$AE, $F6, $AE, $1D, $C8, $39, $B5, $3D, $DF, $97, $47, $7B, $D3, $8C, $1D, $73, $F1, $4C, $E8, $E2, $61, $9D, $9C, $4B, $87, $9D, $31, $2B, $B0, $46, $58, $90
	dc.b	$3A, $8D, $DF, $20, $CB, $BF, $E4, $5A, $EF, $6C, $B0, $65, $BA, $03, $23, $5C, $1A, $11, $96, $E0, $D7, $46, $94, $4B, $D4, $EA, $B8, $6D, $37, $86, $1B, $8D
	dc.b	$E1, $50, $18, $39, $6A, $86, $46, $BC, $B6, $E5, $62, $17, $EB, $4E, $8F, $13, $E2, $A3, $F5, $D3, $5A, $97, $EB, $DB, $0C, $67, $7E, $3D, $F4, $B1, $E3, $63
	dc.b	$B4, $7E, $B2, $85, $C7, $41, $E6, $7D, $18, $37, $23, $DA, $3F, $5D, $F9, $18, $0D, $6B, $DC, $13, $69, $34, $4F, $6D, $E1, $D4, $1F, $A2, $B4, $36, $CC, $B0
	dc.b	$DD, $2B, $08, $1F, $22, $0E, $7E, $2D, $94, $AE, $9F, $E5, $5C, $CB, $13, $D2, $2F, $60, $DF, $BF, $BE, $94, $36, $4B, $55, $0C, $20, $D2, $B0, $C8, $BA, $0E
	dc.b	$9D, $92, $E0, $96, $D0, $5C, $96, $41, $04, $96, $48, $A5, $78, $84, $0D, $D9, $82, $04, $11, $B2, $2C, $77, $B9, $51, $74, $74, $5C, $22, $DD, $2E, $A5, $B7
	dc.b	$4B, $98, $40, $F1, $71, $0E, $83, $F5, $76, $81, $FC, $35, $61, $D0, $74, $0E, $FD, $78, $40, $62, $2C, $D1, $AD, $29, $4E, $C9, $0D, $FB, $E5, $86, $B1, $84
	dc.b	$5C, $7A, $B1, $F4, $11, $FA, $C3, $A5, $8F, $A0, $6C, $60, $1A, $C7, $5B, $7E, $BC, $E1, $63, $55, $40, $76, $D5, $4F, $15, $D6, $40, $D4, $D6, $54, $1F, $91
	dc.b	$07, $69, $6D, $DF, $2D, $CE, $7E, $F2, $08, $A5, $C8, $AD, $31, $A0, $40, $93, $EC, $8B, $A5, $02, $03, $41, $A1, $09, $5F, $24, $5C, $C1, $8B, $FF, $54, $40
	dc.b	$CB, $5E, $64, $A9, $2C, $B3, $D8, $EA, $A5, $91, $1D, $EF, $E5, $42, $C8, $85, $F3, $D4, $16, $58, $EC, $78, $62, $7C, $AB, $27, $87, $93, $CD, $CF, $26, $7B
	dc.b	$12, $A6, $A8, $FC, $B5, $1E, $67, $37, $55, $E7, $43, $B1, $B4, $FD, $38, $79, $95, $67, $7D, $7F, $4E, $8E, $29, $11, $E8, $F2, $E4, $43, $35, $43, $07, $DC
	dc.b	$FF, $6D, $5A, $9B, $9B, $99, $C1, $BC, $9E, $19, $DB, $F2, $23, $63, $DF, $FF, $C7, $CC, $1E, $D9, $9A, $EB, $FC, $C3, $A5, $BF, $98, $AE, $D4, $20, $B9, $B5
	dc.b	$07, $7B, $38, $1B, $F3, $47, $87, $2F, $7D, $8C, $77, $82, $30, $4B, $22, $75, $2D, $98, $70, $B8, $EC, $60, $9F, $AB, $B5, $75, $4C, $1B, $55, $66, $E3, $07
	dc.b	$96, $6B, $AA, $E7, $33, $6B, $B0, $75, $9A, $84, $2B, $1E, $48, $CF, $1E, $3F, $22, $CE, $32, $A9, $38, $C6, $3D, $66, $E3, $F6, $9C, $BD, $EC, $57, $F3, $C0
	dc.b	$F9, $90, $35, $4D, $CE, $97, $38, $9D, $3E, $88, $0A, $53, $3D, $27, $DD, $3E, $6C, $35, $7C, $96, $5A, $90, $45, $CB, $52, $41, $7B, $DD, $B9, $BE, $FD, $3D
	dc.b	$E8, $8B, $E2, $5F, $95, $09, $19, $C9, $50, $7E, $B3, $04, $9F, $F3, $94, $C7, $EB, $9E, $5A, $92, $06, $27, $AD, $D5, $67, $0D, $1A, $91, $91, $1D, $A0, $64
	dc.b	$48, $7D, $F8, $93, $91, $F6, $EA, $2F, $99, $DE, $6B, $78, $32, $39, $6B, $30, $65, $CB, $4C, $39, $B9, $28, $3A, $34, $23, $AF, $2D, $C6, $12, $BF, $4B, $63
	dc.b	$FA, $7B, $DF, $AE, $57, $9C, $9E, $5E, $72, $69, $68, $FF, $39, $65, $27, $C9, $3C, $4B, $50, $74, $1B, $99, $3C, $30, $D5, $D3, $41, $77, $E9, $F2, $70, $37
	dc.b	$9B, $FC, $C1, $C8, $5F, $FA, $F1, $89, $DB, $F2, $31, $75, $E7, $7E, $5E, $1E, $ED, $68, $7F, $AC, $0C, $64, $24, $A6, $A8, $32, $35, $31, $79, $8C, $8E, $C6
	dc.b	$43, $11, $9A, $90, $23, $E6, $BC, $BC, $D4, $E8, $24, $7F, $B7, $D7, $0B, $C8, $6A, $4F, $C0, $C8, $FC, $DF, $9D, $7F, $5D, $CE, $4F, $75, $F5, $BB, $CA, $0E
	dc.b	$41, $31, $D6, $E7, $1D, $F8, $57, $CC, $E8, $D6, $76, $B2, $35, $3A, $F2, $31, $FA, $EF, $3E, $43, $2A, $9B, $8D, $6F, $9E, $3F, $C8, $BF, $07, $FF, $20, $3F
	dc.b	$0B, $81, $F5, $A6, $6D, $89, $5A, $77, $2C, $DF, $D6, $58, $1D, $F8, $A2, $9D, $62, $41, $A4, $2F, $67, $1E, $28, $72, $BE, $6D, $AD, $D2, $BC, $CB, $F5, $2E
	dc.b	$07, $46, $31, $FA, $C9, $1B, $8D, $CC, $E1, $3B, $EC, $62, $F2, $BF, $F4, $A3, $2B, $F5, $FD, $29, $E5, $AE, $DF, $CE, $FD, $BB, $C3, $50, $72, $4C, $89, $EE
	dc.b	$1A, $F3, $25, $FD, $F5, $CF, $20, $7F, $B5, $12, $07, $97, $E4, $5C, $71, $DC, $7D, $F5, $C5, $37, $F3, $2A, $CB, $07, $D3, $F5, $9A, $89, $C8, $F7, $3F, $39
	dc.b	$03, $06, $39, $64, $D5, $3D, $9D, $93, $7E, $A7, $B8, $5F, $CB, $CF, $07, $BA, $47, $2E, $EB, $F2, $09, $42, $9E, $E6, $8E, $8F, $2D, $C2, $10, $F3, $F6, $73
	dc.b	$23, $B2, $2A, $ED, $2C, $51, $D2, $EA, $C8, $42, $0F, $CA, $1E, $E9, $7E, $57, $DA, $FA, $06, $31, $FB, $F3, $21, $3E, $FB, $8C, $8C, $78, $04, $2A, $6E, $F1
	dc.b	$FA, $C7, $3D, $C4, $7B, $BA, $F7, $99, $1E, $87, $72, $B0, $E8, $94, $70, $62, $BB, $38, $7B, $17, $E5, $79, $41, $3A, $ED, $3A, $21, $65, $5C, $97, $71, $58
	dc.b	$71, $5F, $D5, $5E, $20, $7E, $57, $43, $96, $39, $77, $51, $03, $4C, $9B, $41, $0C, $95, $DB, $7D, $3B, $93, $71, $16, $8C, $1D, $84, $99, $D8, $33, $CD, $FD
	dc.b	$D8, $3C, $31, $92, $5C, $E1, $75, $1C, $F2, $04, $65, $57, $5D, $B9, $77, $42, $B5, $C5, $8F, $55, $6B, $97, $5E, $BE, $CF, $06, $FB, $21, $20, $3E, $BC, $CE
	dc.b	$F7, $15, $15, $02, $02, $1F, $AF, $F0, $20, $5D, $3E, $B8, $79, $1D, $79, $20, $C8, $64, $7C, $84, $B1, $20, $6B, $39, $16, $39, $0C, $DE, $B9, $51, $73, $53
	dc.b	$E3, $23, $93, $C5, $75, $AA, $43, $25, $6D, $52, $19, $3C, $D7, $06, $52, $B1, $8E, $E5, $FD, $72, $BE, $9C, $10, $CC, $6A, $FC, $F2, $93, $77, $60, $EC, $3A
	dc.b	$3C, $57, $A8, $6C, $05, $C9, $B9, $E0, $FB, $83, $67, $06, $0C, $3B, $DA, $AF, $A2, $98, $D7, $14, $2B, $CA, $5E, $7B, $DD, $0E, $7E, $35, $94, $CC, $56, $38
	dc.b	$B9, $2E, $2F, $6A, $97, $76, $FC, $D0, $3B, $DA, $FF, $7A, $33, $CC, $27, $BA, $7E, $A6, $3C, $3E, $31, $CA, $FF, $D5, $E7, $73, $86, $7C, $9C, $62, $5A, $6A
	dc.b	$39, $5B, $C8, $5F, $FB, $7C, $E8, $0B, $6E, $41, $F6, $97, $04, $7E, $7C, $6A, $FB, $A5, $7C, $9A, $F9, $67, $2B, $E5, $06, $24, $3D, $D6, $41, $28, $96, $90
	dc.b	$92, $BD, $32, $06, $4B, $7C, $5F, $5C, $1A, $D0, $82, $E1, $77, $46, $5B, $85, $D6, $D0, $24, $68, $DD, $E2, $3D, $77, $B6, $81, $06, $83, $F8, $7F, $BC, $86
	dc.b	$AF, $2E, $84, $A5, $5B, $96, $EE, $9B, $8D, $06, $8B, $DF, $C2, $51, $06, $96, $D1, $74, $81, $17, $34, $5C, $91, $88, $F7, $B3, $91, $BF, $50, $A8, $12, $C8
	dc.b	$B0, $96, $40, $94, $8D, $AE, $4D, $E1, $6E, $09, $20, $DA, $78, $4A, $F6, $4E, $3B, $E9, $5D, $B4, $A7, $6F, $D5, $FA, $73, $68, $BE, $2F, $26, $F4, $C1, $2C
	dc.b	$94, $A5, $29, $4D, $BB, $C4, $2E, $8B, $1C, $20, $6B, $22, $A0, $8B, $7E, $CE, $17, $BF, $D6, $82, $29, $D3, $78, $6E, $9C, $40, $8F, $49, $DA, $17, $F9, $EB
	dc.b	$0B, $FB, $F4, $FD, $FA, $F4, $A7, $EB, $C4, $2C, $2A, $6C, $8A, $83, $F5, $EC, $A8, $21, $BA, $2A, $2B, $42, $46, $D0, $C2, $3F, $86, $12, $90, $E4, $77, $EB
	dc.b	$2E, $18, $AE, $E0, $B6, $EA, $69, $03, $F2, $3A, $88, $5F, $C8, $FE, $BB, $67, $5A, $34, $C5, $3A, $88, $A5, $62, $F6, $86, $11, $24, $92, $7A, $D1, $50, $C4
	dc.b	$92, $C9, $88, $97, $0C, $81, $06, $81, $07, $7F, $46, $A2, $04, $72, $37, $85, $47, $09, $79, $E8, $10, $17, $91, $A5, $BF, $5A, $7D, $E0, $D5, $90, $23, $27
	dc.b	$97, $41, $0E, $A5, $A6, $E3, $89, $8C, $ED, $35, $21, $31, $88, $7D, $E4, $73, $C5, $B1, $35, $43, $40, $82, $0C, $18, $9B, $81, $1C, $07, $62, $0C, $81, $53
	dc.b	$CE, $E9, $29, $DC, $A6, $0D, $CB, $A8, $20, $60, $F7, $04, $6F, $07, $B9, $6A, $46, $37, $2B, $11, $F6, $C4, $E9, $B8, $37, $1E, $5A, $F9, $9B, $8C, $6B, $E6
	dc.b	$61, $C6, $BB, $DC, $71, $6E, $84, $C1, $8C, $78, $3C, $4C, $1D, $9F, $62, $A2, $7E, $99, $31, $3B, $FB, $3C, $20, $E6, $77, $0C, $90, $73, $0F, $20, $85, $CA
	dc.b	$A1, $B0, $3E, $F5, $35, $92, $D4, $67, $4D, $1D, $73, $99, $D7, $0C, $AA, $EE, $E2, $7E, $55, $8F, $D1, $02, $7E, $2C, $EE, $E9, $0C, $1C, $1E, $B5, $68, $17
	dc.b	$C7, $99, $87, $5E, $71, $A9, $5F, $4C, $E1, $D5, $2B, $DF, $B4, $77, $E3, $95, $57, $43, $04, $0A, $7D, $0F, $AC, $DC, $37, $30, $76, $E6, $2B, $78, $2A, $6D
	dc.b	$85, $EE, $23, $7D, $F3, $1B, $9B, $DB, $C4, $E0, $C3, $E3, $33, $07, $6E, $8B, $B8, $85, $30, $46, $E4, $F0, $70, $3A, $3A, $8A, $E0, $D8, $E8, $EB, $9A, $24
	dc.b	$C4, $73, $32, $49, $BC, $C5, $F2, $20, $79, $83, $47, $A5, $CF, $6B, $61, $57, $E0, $4D, $B7, $41, $00, $A8, $D8, $21, $63, $39, $5F, $9C, $90, $5F, $3B, $F4
	dc.b	$34, $39, $96, $0B, $79, $82, $15, $D4, $84, $CC, $7E, $B6, $26, $F0, $46, $AC, $35, $2A, $0F, $23, $9D, $E3, $5B, $F9, $54, $C9, $E7, $3C, $D4, $B1, $78, $E7
	dc.b	$74, $86, $42, $7F, $AE, $23, $5F, $D7, $60, $46, $08, $6A, $84, $74, $B1, $88, $2B, $F3, $5D, $44, $12, $FE, $F9, $8D, $07, $EF, $88, $C7, $F7, $82, $13, $6B
	dc.b	$62, $9B, $7E, $FA, $8B, $3D, $5F, $9F, $22, $79, $96, $FA, $14, $EF, $2F, $C8, $82, $99, $C7, $EB, $48, $79, $BA, $5C, $CE, $4E, $93, $CD, $4C, $3A, $F0, $74
	dc.b	$E1, $F7, $C8, $DE, $52, $24, $D6, $C5, $3D, $53, $DF, $AE, $26, $2F, $5C, $1D, $8A, $3D, $14, $9D, $30, $F3, $B3, $AC, $79, $D0, $5F, $EE, $F1, $EF, $A8, $CD
	dc.b	$4B, $77, $61, $62, $FD, $59, $1E, $63, $C8, $39, $F9, $87, $14, $C7, $B8, $71, $4D, $F4, $B1, $3C, $A4, $75, $13, $36, $D4, $38, $5E, $6C, $A5, $31, $20, $6A
	dc.b	$61, $FA, $D8, $C8, $48, $15, $8C, $6A, $A6, $3F, $5D, $43, $79, $E1, $EF, $2D, $46, $0F, $8E, $1F, $84, $24, $FC, $EE, $40, $49, $3E, $57, $4A, $E1, $88, $E7
	dc.b	$C8, $8F, $21, $9F, $99, $03, $A5, $8E, $F9, $5E, $FB, $E5, $E6, $18, $E7, $79, $A9, $BA, $F9, $0F, $D0, $89, $DB, $F4, $33, $2B, $1F, $90, $D5, $5B, $31, $A8
	dc.b	$9D, $23, $CE, $7E, $66, $F2, $BD, $66, $08, $E7, $87, $4F, $30, $49, $72, $D4, $4C, $55, $BD, $98, $AF, $10, $CA, $F2, $0F, $A9, $A9, $91, $D0, $43, $86, $A4
	dc.b	$F3, $0D, $AF, $20, $F0, $C0, $FC, $DE, $4F, $DF, $D3, $5D, $C3, $C5, $DA, $B2, $58, $E9, $B1, $60, $DA, $4E, $24, $64, $3F, $2B, $E4, $43, $74, $C1, $48, $3E
	dc.b	$B8, $97, $32, $07, $22, $4B, $35, $D0, $72, $CC, $1E, $55, $B8, $6A, $FA, $5D, $7D, $D8, $07, $E0, $EC, $DE, $0E, $56, $BC, $13, $55, $48, $21, $35, $6C, $60
	dc.b	$C2, $77, $24, $D3, $F5, $CA, $C8, $A4, $3C, $52, $78, $DD, $83, $9B, $4F, $CA, $C5, $9F, $D9, $EB, $1E, $9F, $D0, $54, $83, $5C, $CF, $AA, $11, $8D, $6E, $4A
	dc.b	$E2, $D4, $18, $77, $44, $B1, $B8, $BF, $4A, $E2, $AF, $AA, $AF, $41, $02, $AB, $CE, $1E, $51, $51, $9B, $AA, $1C, $83, $90, $46, $A5, $AB, $91, $B5, $4A, $AB
	dc.b	$D4, $48, $B2, $7D, $9D, $91, $87, $EC, $87, $24, $B1, $03, $95, $4B, $77, $E1, $59, $2E, $EB, $90, $BA, $87, $83, $07, $3C, $49, $E9, $E7, $D1, $0C, $9C, $B7
	dc.b	$7E, $44, $15, $A4, $32, $5C, $7F, $2A, $1E, $73, $05, $BA, $4D, $9F, $70, $DE, $9B, $38, $AB, $7F, $3F, $13, $89, $BB, $C9, $4E, $1F, $25, $72, $BC, $1F, $90
	dc.b	$69, $20, $3E, $4E, $D6, $BA, $6B, $B7, $8E, $74, $59, $74, $C7, $41, $33, $98, $6C, $55, $ED, $E4, $E6, $F2, $BD, $82, $4D, $3C, $A4, $77, $9C, $C7, $96, $58
	dc.b	$91, $CC, $79, $63, $1A, $16, $4B, $3A, $49, $15, $C5, $E3, $62, $7E, $E0, $91, $53, $52, $52, $5F, $CA, $A0, $92, $3C, $BF, $2B, $25, $91, $3D, $73, $5C, $FA
	dc.b	$D3, $17, $9B, $F5, $7D, $F2, $BD, $9D, $17, $2B, $A4, $E8, $97, $0E, $8D, $2C, $6E, $54, $5C, $84, $0D, $02, $48, $4B, $A7, $7D, $2F, $C8, $34, $68, $3F, $E6
	dc.b	$3F, $E6, $3F, $C6, $3F, $A6, $3F, $C6, $10, $20, $40, $81, $3D, $7F, $0C, $7E, $CF, $8F, $D9, $ED, $FB, $35, $41, $FB, $3D, $BF, $66, $A8, $BD, $EA, $8B, $DF
	dc.b	$B2, $04, $B7, $78, $D1, $52, $BF, $E3, $AA, $E8, $34, $5E, $F5, $D0, $7F, $4E, $E4, $1D, $F5, $BA, $82, $3B, $EA, $1D, $DF, $C4, $30, $6B, $38, $D5, $87, $70
	dc.b	$76, $DA, $54, $25, $B4, $AF, $1A, $78, $A0, $D2, $DA, $50, $B9, $DB, $43, $18, $6C, $93, $CA, $02, $0D, $30, $84, $08, $10, $63, $A0, $4B, $5D, $A0, $48, $09
	dc.b	$72, $E9, $0C, $9D, $98, $7E, $CD, $52, $DD, $E3, $45, $D2, $C9, $6A, $D9, $15, $2E, $4B, $68, $20, $77, $FF, $BD, $BF, $5E, $B0, $A9, $68, $48, $08, $A8, $10
	dc.b	$40, $EF, $E3, $4A, $69, $68, $54, $E3, $BC, $77, $C5, $29, $4B, $25, $34, $E3, $BE, $DA, $6D, $A6, $DA, $6D, $A5, $23, $64, $5E, $81, $17, $BF, $6F, $D9, $D9
	dc.b	$07, $E4, $51, $50, $27, $9B, $96, $11, $8A, $46, $C8, $18, $CB, $93, $2A, $63, $25, $68, $12, $C4, $66, $E5, $2C, $47, $91, $DA, $13, $CB, $69, $7B, $A4, $94
	dc.b	$BF, $5E, $2F, $1D, $3C, $3F, $13, $0D, $6F, $C8, $9B, $18, $F2, $5B, $D8, $E3, $F7, $B2, $5D, $06, $AB, $76, $49, $5D, $25, $75, $5C, $51, $98, $82, $5C, $BD
	dc.b	$8B, $CE, $E3, $4C, $09, $31, $08, $F8, $19, $27, $E4, $61, $1D, $78, $9B, $91, $8D, $D7, $8F, $D1, $09, $9C, $83, $39, $51, $64, $CE, $08, $C8, $24, $C2, $70
	dc.b	$C2, $49, $7C, $B0, $24, $04, $FD, $72, $25, $78, $E4, $3D, $D7, $51, $EE, $6D, $A8, $42, $56, $E4, $A4, $A7, $E0, $20, $42, $1D, $06, $80, $8C, $9D, $8B, $F1
	dc.b	$C9, $C1, $F9, $C6, $61, $B0, $D4, $B1, $79, $63, $1C, $F2, $10, $A6, $BF, $A5, $2C, $A4, $B9, $D5, $AE, $7F, $B4, $B0, $4A, $BF, $F5, $D9, $15, $71, $40, $6F
	dc.b	$CF, $15, $61, $9A, $A0, $2B, $20, $41, $91, $D8, $90, $4C, $66, $25, $A0, $7E, $8B, $A1, $8E, $4A, $60, $87, $2D, $A6, $8C, $35, $98, $98, $C4, $D4, $A4, $8D
	dc.b	$16, $CC, $46, $5D, $B3, $B4, $C2, $53, $D2, $07, $F1, $20, $F9, $DF, $E4, $A4, $BF, $C4, $A2, $90, $CF, $62, $B4, $F8, $CE, $7C, $73, $3F, $46, $58, $5F, $DD
	dc.b	$BE, $0E, $61, $8E, $16, $C0, $42, $10, $EE, $21, $FA, $C7, $73, $1B, $AD, $FC, $E7, $01, $82, $6B, $A3, $06, $3F, $CA, $EE, $8A, $EF, $19, $E2, $EB, $81, $BC
	dc.b	$16, $A4, $CA, $4C, $EE, $E0, $43, $27, $C8, $C8, $D0, $21, $A9, $2E, $84, $33, $31, $A1, $89, $02, $13, $87, $5E, $1A, $E9, $1D, $5D, $24, $DC, $3F, $31, $30
	dc.b	$52, $25, $EA, $53, $3B, $75, $36, $77, $10, $1D, $C3, $A1, $7C, $B6, $F2, $57, $0F, $25, $E5, $95, $E2, $FC, $FF, $4F, $7C, $EF, $53, $5E, $A3, $36, $F2, $EA
	dc.b	$3C, $9C, $BE, $46, $E0, $EF, $D6, $E8, $D3, $85, $9C, $96, $76, $9D, $FB, $7E, $9E, $F7, $DF, $2D, $8C, $1F, $1A, $BC, $4F, $63, $E7, $32, $D8, $C8, $3F, $52
	dc.b	$57, $D7, $6D, $FD, $F5, $2F, $D6, $5E, $FF, $37, $90, $CA, $4F, $84, $FD, $F4, $B1, $E2, $6E, $C5, $27, $B1, $A3, $1E, $D5, $DD, $2D, $18, $B4, $26, $62, $30
	dc.b	$CB, $04, $B4, $DF, $96, $0F, $35, $BF, $45, $3C, $EF, $70, $78, $BF, $C8, $18, $7C, $B6, $3E, $9E, $5D, $66, $37, $F2, $EA, $61, $8F, $63, $9B, $B8, $98, $FD
	dc.b	$6B, $EF, $E5, $FA, $D1, $7F, $69, $8B, $FB, $3C, $72, $F2, $13, $BC, $79, $3C, $84, $D7, $C8, $CA, $77, $CF, $69, $83, $4E, $1E, $13, $CE, $5B, $10, $3B, $1A
	dc.b	$9D, $45, $EA, $60, $F2, $3E, $C6, $26, $65, $63, $13, $41, $9E, $B6, $9A, $98, $75, $70, $A9, $40, $3A, $F5, $C0, $81, $2F, $EA, $B1, $13, $96, $3D, $CD, $93
	dc.b	$4D, $31, $FD, $62, $A4, $3B, $57, $86, $4E, $B9, $E3, $26, $43, $1E, $D2, $CB, $67, $FE, $9B, $95, $F3, $C6, $DA, $BE, $6E, $F2, $1C, $A6, $1C, $B3, $3B, $7E
	dc.b	$88, $21, $CD, $7A, $09, $9A, $07, $79, $0B, $CD, $26, $3C, $9D, $78, $42, $93, $CA, $B2, $4B, $CF, $96, $66, $35, $98, $F2, $BE, $7B, $7E, $B4, $EF, $24, $9D
	dc.b	$92, $F0, $83, $BE, $88, $A8, $3F, $2B, $A1, $83, $9D, $D8, $66, $D8, $2B, $CB, $63, $C4, $1E, $7B, $A6, $2F, $DA, $E1, $79, $6D, $70, $2E, $C4, $FF, $4F, $EC
	dc.b	$92, $75, $CF, $0F, $19, $41, $87, $AD, $E5, $87, $08, $D7, $7A, $DF, $8B, $94, $AD, $81, $6D, $ED, $6C, $98, $7E, $55, $B0, $C9, $8C, $72, $34, $80, $64, $35
	dc.b	$08, $1E, $57, $F3, $B7, $EB, $57, $45, $99, $5B, $49, $F1, $A7, $1D, $F6, $D7, $F6, $78, $94, $C9, $F3, $08, $ED, $32, $7B, $24, $C3, $41, $8C, $6D, $F9, $5C
	dc.b	$76, $3B, $DF, $B1, $F0, $7D, $A6, $60, $F6, $3D, $25, $7C, $B9, $FE, $B3, $63, $F3, $31, $95, $BC, $62, $FA, $82, $CB, $C9, $4C, $14, $7A, $2A, $50, $F9, $E0
	dc.b	$E9, $64, $64, $B8, $29, $C8, $77, $61, $2C, $AA, $DE, $ED, $8B, $83, $12, $99, $55, $F2, $B6, $41, $C8, $56, $A8, $95, $EF, $B3, $7E, $F8, $A5, $BD, $D3, $FD
	dc.b	$76, $3E, $E8, $42, $67, $DC, $5B, $DD, $3C, $3F, $22, $0B, $F2, $A5, $87, $E5, $48, $74, $93, $F7, $70, $E7, $79, $E6, $7F, $A6, $FE, $74, $8A, $4E, $C1, $30
	dc.b	$3B, $DE, $97, $16, $37, $6B, $29, $B0, $61, $AF, $5C, $90, $F9, $C9, $72, $91, $2C, $D6, $B7, $5A, $6E, $13, $7D, $A6, $E1, $7C, $ED, $35, $9D, $E4, $90, $3A
	dc.b	$CC, $E5, $59, $6A, $E5, $95, $D5, $DD, $6F, $AB, $7E, $BC, $3B, $74, $6F, $27, $29, $B9, $36, $6E, $B1, $AA, $B2, $C6, $F8, $D5, $BC, $5F, $5C, $B0, $09, $67
	dc.b	$78, $2B, $13, $72, $20, $42, $0F, $C0, $CC, $54, $B5, $2F, $44, $A6, $1F, $C8, $87, $EB, $AB, $9A, $BF, $BA, $7D, $01, $37, $46, $AA, $04, $56, $C6, $10, $1E
	dc.b	$F0, $2A, $08, $F0, $AA, $56, $16, $43, $AE, $A9, $17, $E4, $CE, $96, $22, $B3, $91, $ED, $D3, $C6, $F1, $DF, $4B, $6F, $DB, $7F, $5B, $F6, $DF, $4E, $19, $53
	dc.b	$66, $45, $41, $FC, $31, $A6, $DA, $32, $76, $64, $F4, $81, $36, $D0, $27, $6E, $FB, $24, $7E, $CE, $CC, $B7, $7F, $4E, $C8, $A8, $10, $B4, $5E, $F2, $09, $C5
	dc.b	$DC, $22, $A5, $90, $77, $D9, $06, $8B, $DF, $4B, $27, $66, $4E, $C4, $9C, $41, $76, $65, $D3, $B6, $8D, $62, $AE, $8C, $20, $5D, $28, $B4, $59, $B1, $EF, $18
	dc.b	$B3, $97, $41, $88, $EA, $8E, $1A, $1D, $9C, $A8, $76, $61, $A0, $45, $6B, $20, $46, $EF, $1D, $25, $B2, $2C, $96, $17, $A2, $FE, $BF, $6E, $8B, $FC, $FD, $17
	dc.b	$73, $1B, $AE, $87, $A7, $27, $40, $86, $8E, $E9, $C5, $3B, $DC, $DF, $91, $1A, $40, $9A, $FE, $B1, $0F, $CA, $FE, $F0, $9C, $CC, $72, $BD, $FF, $AC, $97, $E5
	dc.b	$55, $96, $E3, $9E, $1F, $95, $F3, $A6, $23, $4E, $13, $B1, $E2, $BD, $56, $FF, $D6, $4C, $DD, $BE, $5C, $92, $53, $90, $35, $49, $2D, $F8, $78, $29, $4E, $56
	dc.b	$4E, $46, $81, $93, $62, $13, $FC, $8D, $88, $1B, $8D, $50, $32, $42, $72, $21, $20, $9E, $E1, $E1, $06, $59, $9D, $93, $1E, $98, $BC, $39, $6B, $D0, $16, $5F
	dc.b	$C4, $E0, $BB, $C8, $10, $2E, $F1, $91, $2F, $BA, $FE, $BA, $C6, $3F, $DD, $95, $AB, $DC, $0B, $F2, $A7, $5E, $E0, $5F, $95, $07, $E6, $33, $15, $BE, $C4, $09
	dc.b	$C6, $B9, $02, $4D, $B2, $31, $D7, $F4, $E6, $B5, $CA, $D7, $C8, $9F, $22, $04, $6E, $98, $46, $05, $C3, $0C, $8E, $C8, $0B, $13, $59, $8E, $F5, $70, $40, $94
	dc.b	$E3, $F6, $73, $86, $30, $92, $FD, $56, $9B, $6A, $3B, $CA, $BC, $84, $BD, $EA, $A8, $0C, $3C, $68, $64, $F0, $FA, $AF, $90, $21, $92, $A0, $4B, $73, $F3, $96
	dc.b	$25, $2F, $DF, $14, $84, $AD, $7A, $3B, $86, $49, $09, $59, $D0, $65, $B1, $B1, $AE, $5A, $FE, $56, $F2, $4D, $9D, $8E, $78, $BE, $FC, $A5, $75, $F2, $24, $54
	dc.b	$06, $DB, $20, $47, $15, $90, $3E, $64, $34, $12, $59, $0D, $04, $97, $45, $3C, $A4, $DA, $2B, $C9, $B0, $12, $BC, $EF, $86, $7A, $03, $F5, $2F, $4E, $F5, $95
	dc.b	$A7, $EA, $79, $82, $B4, $C6, $0E, $C2, $D3, $27, $7B, $79, $68, $5E, $8E, $C5, $E8, $87, $91, $92, $90, $F3, $31, $98, $3E, $6D, $67, $9A, $C7, $B9, $8E, $B1
	dc.b	$ED, $7F, $32, $B9, $83, $42, $B6, $AA, $D6, $D5, $81, $5B, $5D, $EE, $FD, $66, $BD, $B7, $5B, $AD, $EC, $22, $E0, $C4, $B7, $C3, $64, $D9, $A2, $B0, $73, $1E
	dc.b	$D2, $1A, $A0, $B8, $72, $78, $40, $43, $2B, $CB, $58, $DB, $79, $AB, $39, $83, $4C, $3C, $39, $5B, $F5, $B9, $57, $0A, $E0, $3A, $A6, $3E, $42, $6A, $98, $CC
	dc.b	$14, $D5, $C3, $CA, $F9, $A9, $83, $98, $9A, $98, $35, $4E, $B4, $B4, $C1, $CF, $69, $9A, $F9, $3A, $69, $2D, $9D, $31, $21, $FB, $D3, $0C, $27, $63, $93, $1D
	dc.b	$91, $50, $C9, $64, $24, $47, $7A, $DE, $24, $AE, $9F, $2B, $F5, $C8, $16, $A2, $F3, $BB, $63, $93, $EE, $8F, $E7, $10, $43, $5D, $55, $38, $30, $83, $F7, $C4
	dc.b	$EE, $2A, $F3, $CB, $A9, $0C, $8E, $5B, $AE, $60, $DA, $17, $39, $20, $45, $E5, $A0, $DD, $F6, $92, $DC, $34, $57, $1A, $1E, $68, $35, $87, $E7, $78, $7C, $B4
	dc.b	$F2, $95, $F3, $B4, $F8, $73, $0F, $2B, $CE, $6E, $C4, $79, $03, $98, $41, $E4, $56, $42, $FD, $6D, $A2, $FF, $2B, $48, $DB, $9C, $AF, $0F, $AB, $BF, $4E, $53
	dc.b	$23, $DB, $30, $5D, $AF, $9A, $58, $81, $84, $B3, $C9, $0D, $0D, $6F, $45, $46, $EB, $7B, $8B, $AF, $EB, $A5, $8D, $FF, $91, $CA, $B2, $13, $70, $78, $3D, $89
	dc.b	$BA, $93, $96, $5F, $AC, $28, $11, $7D, $99, $26, $8F, $FD, $F3, $24, $62, $09, $4D, $D3, $1C, $CC, $7E, $DE, $7F, $A9, $DC, $30, $34, $3D, $D4, $E6, $25, $63
	dc.b	$F2, $05, $D7, $2B, $E6, $79, $F2, $06, $E4, $90, $E4, $11, $84, $87, $E5, $5D, $8C, $B1, $06, $DF, $91, $3B, $DD, $23, $1D, $1D, $34, $32, $1D, $7C, $84, $DE
	dc.b	$35, $9A, $A3, $EF, $57, $4C, $93, $1B, $38, $5E, $31, $92, $98, $9A, $0B, $FF, $44, $6F, $76, $37, $E3, $F9, $53, $7D, $71, $3F, $52, $19, $8C, $5E, $1E, $3C
	dc.b	$86, $28, $0B, $F5, $A3, $41, $7B, $96, $66, $1E, $7C, $67, $79, $F3, $DC, $C1, $E2, $BF, $91, $04, $76, $E6, $AF, $B7, $3A, $76, $E7, $BA, $BF, $D3, $E8, $37
	dc.b	$0D, $83, $F2, $18, $7E, $54, $31, $F0, $C0, $C3, $C7, $2C, $01, $C2, $F2, $C1, $8C, $97, $F2, $AA, $CE, $A2, $F5, $04, $30, $5E, $A3, $1C, $AC, $EE, $E5, $4B
	dc.b	$6A, $13, $D2, $2A, $1E, $96, $D1, $FA, $5E, $34, $04, $AD, $4C, $AC, $5E, $D5, $C0, $79, $27, $B4, $FB, $27, $62, $4E, $D2, $D8, $D5, $09, $50, $D4, $95, $0D
	dc.b	$4C, $A5, $81, $ED, $33, $C3, $F5, $BE, $7C, $B6, $3E, $C4, $74, $E0, $81, $B9, $AC, $40, $C3, $7A, $21, $EC, $56, $BB, $71, $D4, $FF, $45, $DB, $51, $BA, $9F
	dc.b	$1F, $AC, $76, $F6, $60, $7B, $ED, $BA, $FB, $9A, $9B, $7E, $A1, $D5, $19, $7F, $49, $EE, $5D, $6F, $49, $B6, $BB, $CE, $31, $0C, $37, $81, $01, $C3, $98, $64
	dc.b	$63, $6E, $6C, $B2, $2B, $7E, $B4, $3D, $BF, $5D, $33, $CA, $F9, $66, $0D, $B5, $BF, $B3, $59, $0D, $58, $82, $03, $B2, $6D, $D6, $48, $4A, $7D, $64, $8B, $A8
	dc.b	$74, $90, $93, $6A, $FE, $BC, $DC, $31, $1B, $86, $58, $F4, $81, $95, $B6, $71, $B5, $DA, $07, $29, $CB, $B3, $A3, $74, $57, $34, $B3, $49, $DF, $94, $86, $44
	dc.b	$08, $10, $2A, $F3, $04, $F3, $21, $A8, $20, $60, $F3, $0F, $3B, $73, $32, $B1, $E7, $78, $6D, $5B, $39, $34, $30, $FD, $61, $61, $37, $79, $E1, $FA, $A0, $7E
	dc.b	$78, $0A, $87, $59, $C3, $2A, $BB, $5B, $1E, $5B, $1E, $1A, $E4, $0C, $36, $A2, $A6, $AE, $1F, $CC, $B7, $9B, $FC, $F2, $F1, $DF, $C7, $7F, $1D, $53, $8D, $7B
	dc.b	$72, $4E, $35, $9B, $2E, $EB, $59, $35, $60, $7E, $96, $A2, $E1, $1B, $47, $64, $B2, $0D, $29, $B4, $5B, $B8, $43, $0E, $99, $B2, $6F, $64, $08, $21, $A1, $BF
	dc.b	$5E, $D2, $4E, $EB, $21, $27, $84, $08, $BF, $B3, $B4, $5D, $FA, $CB, $7E, $D3, $70, $E2, $AF, $4F, $D6, $38, $57, $66, $1D, $0A, $E8, $5A, $AB, $42, $A7, $1D
	dc.b	$F7, $2B, $77, $8F, $D9, $D9, $07, $EB, $EC, $83, $F5, $94, $E0, $00
;Championship_driver_select_tiles_b
Championship_driver_select_tiles_b:
	dc.b	$81, $45, $80, $03, $00, $14, $07, $25, $12, $35, $18, $46, $2E, $56, $33, $66, $37, $74, $03, $81, $04, $02, $16, $39, $28, $F3, $82, $06, $2F, $83, $04, $06
	dc.b	$16, $38, $28, $F4, $84, $04, $04, $17, $77, $28, $F5, $85, $05, $15, $18, $F6, $86, $04, $08, $17, $75, $87, $04, $05, $17, $76, $88, $07, $74, $89, $06, $36
	dc.b	$8A, $05, $13, $18, $F2, $8B, $05, $16, $8C, $06, $34, $8D, $05, $14, $17, $78, $8E, $06, $32, $8F, $06, $35, $FF, $33, $3D, $D3, $34, $2B, $90, $9B, $08, $4D
	dc.b	$84, $32, $60, $CE, $84, $CE, $59, $B6, $E4, $81, $09, $83, $1A, $66, $4E, $92, $6C, $13, $18, $24, $33, $33, $CC, $90, $E4, $4C, $18, $90, $21, $E1, $89, $02
	dc.b	$13, $3B, $5F, $22, $6B, $90, $17, $18, $41, $CB, $63, $B8, $2C, $FB, $98, $FE, $23, $A7, $F0, $50, $17, $F0, $C9, $1A, $E6, $21, $FB, $37, $E3, $CF, $05, $EA
	dc.b	$4C, $E9, $24, $2E, $2E, $4E, $73, $EE, $66, $66, $66, $66, $7B, $A6, $68, $47, $72, $13, $61, $09, $87, $ED, $09, $83, $79, $DE, $C1, $8B, $D1, $D8, $92, $5C
	dc.b	$12, $0F, $4E, $51, $FC, $C2, $4B, $F6, $86, $66, $78, $4D, $C9, $0C, $CF, $1D, $C9, $24, $85, $7A, $49, $09, $B0, $85, $E9, $B9, $3A, $13, $06, $2B, $98, $30
	dc.b	$42, $67, $E3, $32, $AC, $9B, $08, $4C, $77, $17, $17, $35, $C4, $81, $B9, $0C, $09, $89, $03, $0E, $09, $02, $13, $66, $85, $7B, $26, $10, $16, $7D, $CC, $CC
	dc.b	$CC, $CC, $F7, $4C, $D0, $CB, $F6, $81, $09, $BF, $62, $92, $FD, $9F, $3F, $C3, $1E, $9F, $B1, $6C, $20, $2E, $25, $52, $E3, $1E, $85, $8E, $0A, $EF, $64, $33
	dc.b	$DD, $0B, $82, $31, $DC, $9A, $49, $CB, $06, $24, $1C, $06, $24, $97, $04, $92, $6E, $53, $04, $12, $EE, $E6, $66, $67, $72, $5D, $DC, $B0, $80, $9B, $D5, $C9
	dc.b	$9F, $94, $26, $0C, $5C, $13, $B1, $33, $F0, $E9, $E8, $EC, $4E, $59, $96, $E8, $61, $A4, $81, $09, $D8, $8C, $CC, $DC, $98, $CF, $76, $0D, $82, $0C, $09, $1D
	dc.b	$3C, $D3, $1E, $B8, $F5, $BB, $CD, $31, $C0, $24, $B9, $81, $23, $F0, $1B, $04, $67, $9A, $19, $9E, $68, $59, $93, $5C, $4D, $26, $1C, $06, $42, $1F, $B3, $20
	dc.b	$9F, $C1, $47, $FE, $21, $99, $99, $C9, $2B, $1E, $C8, $10, $99, $C9, $30, $C4, $81, $09, $8D, $89, $0C, $E4, $D9, $91, $E6, $87, $C3, $97, $7C, $30, $F3, $62
	dc.b	$61, $FB, $39, $34, $98, $90, $87, $A0, $40, $9F, $C1, $97, $F1, $0C, $F7, $4C, $D0, $8E, $E4, $26, $EF, $5E, $BC, $C2, $1E, $68, $7B, $96, $18, $C8, $32, $13
	dc.b	$48, $B7, $E2, $E2, $1C, $B4, $B8, $93, $48, $91, $A5, $C4, $9A, $44, $81, $A4, $D2, $E5, $81, $25, $CD, $71, $1E, $64, $C7, $9F, $07, $9B, $6F, $ED, $15, $EF
	dc.b	$58, $C2, $17, $07, $24, $2E, $08, $CC, $F3, $62, $DD, $AE, $6B, $90, $87, $18, $4F, $3B, $BD, $4C, $CF, $DA, $2A, $92, $23, $33, $DC, $98, $D8, $92, $4C, $66
	dc.b	$C4, $98, $62, $4B, $89, $33, $43, $33, $33, $33, $CD, $2E, $EE, $58, $4E, $5A, $48, $5C, $49, $09, $9D, $9D, $2B, $FA, $6A, $99, $FF, $12, $5F, $C1, $47, $E0
	dc.b	$70, $48, $63, $8C, $FF, $4B, $D6, $A8, $66, $66, $6F, $FB, $49, $27, $EC, $53, $1C, $02, $47, $27, $67, $EE, $1A, $5C, $DD, $E9, $8F, $49, $33, $F2, $C8, $41
	dc.b	$89, $0F, $34, $91, $70, $47, $99, $26, $38, $DC, $92, $E6, $DC, $93, $08, $49, $9A, $19, $9E, $E8, $79, $A1, $19, $A6, $10, $98, $93, $72, $4B, $98, $CC, $CC
	dc.b	$E4, $83, $8B, $89, $8A, $48, $4D, $8E, $78, $24, $0C, $38, $24, $0C, $38, $2C, $70, $41, $1F, $F4, $A8, $3D, $5F, $BF, $EC, $42, $15, $FC, $06, $42, $6B, $89
	dc.b	$87, $A6, $18, $72, $FC, $02, $4B, $89, $0F, $34, $B9, $88, $CC, $CD, $D2, $4C, $5D, $C1, $70, $FE, $6D, $2F, $D9, $86, $2E, $1F, $82, $04, $38, $04, $3B, $FE
	dc.b	$C7, $BB, $FE, $D0, $CE, $5D, $F0, $95, $20, $97, $31, $19, $99, $C9, $09, $8C, $CF, $3E, $25, $DF, $0C, $4E, $4E, $C1, $B9, $E0, $83, $0F, $42, $1C, $FA, $10
	dc.b	$40, $9E, $61, $25, $FB, $47, $43, $33, $33, $DD, $37, $43, $33, $33, $3D, $FD, $6E, $F5, $33, $33, $33, $3C, $21, $99, $E6, $98, $F5, $E5, $D3, $CF, $80, $85
	dc.b	$E9, $BF, $A4, $B8, $F3, $09, $E7, $DE, $5E, $A6, $66, $61, $0A, $B1, $EC, $81, $2A, $EC, $72, $EF, $72, $15, $F8, $FC, $97, $12, $61, $C1, $33, $F1, $CA, $34
	dc.b	$8B, $B9, $99, $C9, $89, $0C, $CC, $E5, $58, $AA, $5D, $FC, $47, $4F, $30, $8F, $7B, $02, $49, $35, $E4, $98, $2E, $F7, $21, $8F, $5C, $27, $21, $2E, $62, $33
	dc.b	$92, $13, $19, $9D, $C9, $5E, $B5, $43, $33, $3C, $7E, $D2, $48, $39, $09, $22, $72, $BB, $83, $33, $33, $DD, $8C, $91, $D2, $B1, $54, $33, $33, $39, $77, $B9
	dc.b	$39, $4C, $5E, $C7, $BB, $12, $19, $DC, $C4, $98, $63, $3E, $09, $1D, $2E, $EF, $E7, $C1, $02, $67, $2E, $2F, $E0, $20, $2F, $42, $74, $1E, $7D, $DF, $F6, $86
	dc.b	$12, $BD, $6A, $87, $73, $12, $19, $DC, $C5, $EA, $38, $7F, $3C, $7E, $CC, $98, $9A, $5C, $10, $2F, $42, $61, $DF, $CD, $0A, $5E, $AE, $99, $A1, $99, $A5, $62
	dc.b	$A8, $6E, $84, $C1, $89, $30, $D2, $4B, $9B, $CF, $82, $61, $E8, $E8, $5E, $81, $88, $27, $9B, $12, $3F, $A9, $26, $68, $66, $66, $66, $66, $67, $77, $7B, $93
	dc.b	$9C, $21, $70, $67, $24, $26, $33, $63, $DC, $8C, $F7, $23, $3D, $F8, $33, $33, $DC, $B3, $63, $B9, $AE, $42, $33, $B9, $09, $A4, $41, $2B, $FA, $6F, $63, $33
	dc.b	$4D, $C9, $37, $24, $B9, $8C, $CC, $CC, $F7, $62, $43, $C2, $66, $85, $72, $11, $B1, $23, $A1, $70, $67, $24, $26, $36, $24, $33, $33, $93, $06, $27, $42, $0D
	dc.b	$77, $05, $C7, $72, $91, $37, $7A, $C5, $7B, $D4, $CC, $CF, $74, $33, $DD, $0C, $CC, $CF, $FC, $83, $F6, $23, $94, $1E, $85, $C1, $36, $FE, $97, $DD, $CD, $C5
	dc.b	$DC, $CE, $E4, $3B, $B8, $DD, $B7, $27, $42, $E0, $87, $72, $69, $27, $2C, $18, $9F, $80, $C4, $10, $7A, $10, $47, $A9, $0B, $CB, $AD, $50, $B8, $26, $0D, $71
	dc.b	$70, $5C, $17, $7E, $5A, $EE, $E1, $89, $30, $C4, $97, $12, $66, $55, $8A, $A3, $A7, $A1, $49, $38, $20, $92, $E4, $26, $3D, $4C, $CE, $EF, $5B, $BD, $4C, $CC
	dc.b	$CC, $CC, $CC, $CF, $09, $9A, $15, $C8, $4C, $66, $66, $FE, $B2, $EF, $FB, $16, $05, $7F, $EC, $F3, $F4, $05, $E9, $CB, $A7, $9A, $63, $D5, $DA, $E4, $32, $0C
	dc.b	$66, $66, $87, $86, $B9, $08, $DD, $B3, $69, $20, $E2, $48, $09, $C9, $88, $17, $01, $0A, $A9, $58, $F6, $08, $66, $69, $B9, $26, $E4, $97, $36, $69, $2F, $DA
	dc.b	$63, $F8, $2F, $7F, $00, $9D, $83, $5E, $48, $41, $AF, $2E, $EE, $C5, $DE, $48, $7B, $A1, $E6, $9C, $A1, $99, $99, $C9, $09, $8C, $F0, $84, $C0, $90, $C2, $17
	dc.b	$EC, $C9, $30, $41, $B9, $E0, $83, $0F, $42, $EF, $5F, $D3, $55, $0C, $CC, $CD, $FF, $69, $77, $21, $24, $5C, $10, $47, $67, $62, $39, $33, $B1, $48, $B8, $20
	dc.b	$92, $E4, $23, $A0, $20, $98, $26, $2B, $99, $D1, $D0, $C8, $CC, $31, $21, $9E, $18, $93, $0D, $72, $16, $FC, $3A, $04, $27, $62, $08, $5C, $10, $6E, $5A, $4C
	dc.b	$38, $0C, $48, $5E, $97, $92, $3F, $98, $47, $E7, $F2, $44, $8F, $C0, $62, $47, $F4, $24, $97, $9A, $63, $D4, $CC, $EE, $4F, $D2, $A4, $93, $CD, $31, $EA, $66
	dc.b	$66, $67, $BF, $F1, $07, $71, $FB, $14, $1C, $FE, $CC, $10, $FD, $9C, $B8, $F3, $62, $69, $26, $18, $82, $13, $3B, $79, $FE, $CC, $7E, $CC, $9F, $F6, $65, $2F
	dc.b	$D8, $A6, $3D, $4D, $0A, $E4, $93, $17, $7E, $5B, $AD, $41, $30, $BD, $D0, $B8, $2F, $52, $E0, $90, $73, $C1, $23, $FA, $12, $3A, $06, $24, $B9, $89, $30, $C6
	dc.b	$67, $72, $11, $9B, $1B, $12, $3A, $16, $E9, $78, $BE, $2A, $97, $31, $21, $9B, $93, $19, $BA, $5C, $C4, $67, $86, $33, $3D, $F8, $24, $C7, $29, $99, $75, $AA
	dc.b	$19, $84, $33, $CD, $0B, $0D, $CB, $3B, $3F, $A2, $10, $FD, $99, $04, $FE, $0A, $3F, $F1, $0C, $CC, $CC, $57, $AF, $B7, $E9, $89, $87, $03, $80, $5F, $B3, $04
	dc.b	$83, $F8, $28, $3F, $A8, $66, $62, $A9, $99, $26, $68, $66, $66, $66, $66, $67, $9A, $66, $85, $72, $13, $61, $0B, $8C, $25, $62, $A7, $9F, $7B, $93, $9F, $50
	dc.b	$85, $C7, $21, $2F, $FE, $1F, $21, $B9, $61, $E8, $5D, $EB, $FA, $6A, $A1, $BF, $AD, $DC, $84, $C7, $04, $12, $4C, $18, $B0, $4C, $18, $26, $65, $24, $AF, $5A
	dc.b	$A5, $DE, $B8, $41, $CA, $60, $B8, $24, $3C, $D8, $B3, $E3, $76, $B9, $B9, $DD, $0E, $5C, $12, $3A, $11, $9E, $EC, $09, $1D, $08, $36, $EC, $5E, $A4, $CE, $D7
	dc.b	$F2, $ED, $2F, $47, $FE, $18, $6F, $E8, $B1, $7F, $50, $93, $34, $33, $3D, $D3, $72, $4C, $D8, $92, $EE, $09, $30, $5C, $12, $1C, $90, $B8, $24, $08, $67, $9A
	dc.b	$16, $EC, $84, $D2, $2C, $CB, $82, $60, $C3, $80, $C3, $F6, $60, $9F, $D3, $94, $F4, $E7, $B8, $F3, $EF, $2F, $53, $33, $33, $CD, $0F, $34, $09, $99, $1E, $ED
	dc.b	$99, $1E, $FC, $6E, $49, $73, $1E, $E4, $87, $9A, $19, $99, $99, $99, $99, $BC, $76, $8B, $3C, $65, $A9, $69, $93, $C7, $4B, $5F, $A5, $F8, $65, $6C, $DA, $2F
	dc.b	$CD, $8B, $75, $DD, $8C, $CC, $CC, $CC, $FF, $EC, $0A, $9A, $5F, $6D, $29, $96, $AD, $F9, $29, $D0, $B5, $19, $0C, $88, $6C, $35, $AE, $39, $15, $D4, $72, $18
	dc.b	$64, $8F, $34, $E4, $4C, $6B, $6A, $AB, $EB, $67, $DB, $8D, $4A, $5A, $39, $02, $A0, $20, $4E, $51, $24, $85, $E3, $B1, $99, $F5, $5E, $9F, $A7, $8A, $69, $3A
	dc.b	$FA, $D6, $9A, $4F, $A2, $CD, $61, $B9, $05, $40, $4A, $09, $5B, $08, $35, $AF, $E9, $C1, $0D, $45, $79, $7A, $92, $DF, $E6, $F3, $EB, $37, $21, $A8, $B6, $A0
	dc.b	$84, $32, $58, $28, $27, $2B, $3F, $E4, $92, $AB, $B4, $21, $99, $FF, $9E, $3B, $FF, $3B, $5E, $BF, $E1, $14, $FC, $FE, $5A, $59, $7A, $F7, $AA, $E2, $77, $72
	dc.b	$73, $37, $9C, $8A, $53, $30, $A5, $9A, $7F, $8C, $CC, $E1, $7A, $4F, $D7, $6D, $69, $7E, $CB, $4D, $A6, $5F, $92, $FC, $D9, $57, $FB, $75, $A6, $AF, $37, $CA
	dc.b	$11, $E6, $67, $9F, $90, $9E, $6A, $49, $75, $E1, $1E, $61, $2B, $69, $7E, $66, $9F, $C3, $33, $3D, $93, $FB, $33, $5F, $2E, $E1, $3F, $77, $59, $95, $6E, $D5
	dc.b	$CA, $B9, $CC, $69, $74, $DF, $29, $6A, $8F, $7B, $EA, $13, $60, $D8, $A0, $BC, $7E, $7D, $F6, $E6, $ED, $AF, $CD, $3F, $CE, $66, $7F, $99, $EF, $FB, $39, $65
	dc.b	$FA, $6A, $DF, $35, $D0, $17, $4E, $34, $D9, $B5, $BF, $67, $E9, $F9, $CD, $66, $CB, $AD, $F9, $4E, $06, $AF, $7E, $5A, $46, $D6, $72, $BE, $7B, $53, $91, $A6
	dc.b	$5A, $4E, $82, $A3, $2D, $35, $0A, $22, $F1, $B1, $64, $13, $1A, $D0, $AF, $15, $4D, $7A, $55, $90, $CC, $C7, $E8, $AE, $45, $4E, $89, $B3, $D5, $52, $C2, $8F
	dc.b	$CC, $0E, $F2, $AA, $36, $3A, $E6, $86, $66, $66, $66, $66, $79, $D7, $3A, $E6, $9C, $08, $E9, $DD, $81, $46, $5A, $5E, $09, $A6, $D4, $BD, $83, $0D, $97, $D8
	dc.b	$94, $16, $D7, $8E, $57, $50, $8F, $7A, $FE, $49, $B5, $95, $F5, $D4, $5F, $82, $62, $BF, $17, $AB, $66, $D0, $D9, $F3, $9D, $F1, $BD, $E6, $7B, $EC, $7B, $EC
	dc.b	$7B, $A1, $9E, $E8, $66, $66, $75, $FC, $C6, $9E, $4F, $47, $B5, $34, $49, $6A, $09, $89, $1E, $85, $A6, $BC, $EA, $F1, $32, $A0, $D7, $2B, $F4, $5D, $2A, $DA
	dc.b	$FE, $7B, $A1, $32, $71, $AD, $F9, $68, $C0, $B6, $9E, $D9, $7E, $72, $F4, $1E, $05, $FA, $CC, $74, $A8, $F5, $72, $15, $BA, $F2, $09, $71, $46, $49, $2E, $17
	dc.b	$6B, $E1, $CB, $6C, $B6, $B0, $41, $1A, $0D, $36, $AD, $E9, $7E, $CB, $55, $CA, $B7, $A6, $B6, $E9, $37, $62, $09, $D2, $9B, $2E, $83, $4B, $CB, $F2, $4B, $A5
	dc.b	$76, $EE, $34, $50, $8B, $7E, $5A, $7E, $48, $36, $B7, $D3, $5D, $32, $D8, $65, $6A, $06, $A6, $C5, $F9, $C1, $C0, $BF, $4D, $9A, $CC, $5C, $4D, $83, $13, $68
	dc.b	$58, $5B, $FF, $38, $F5, $ED, $15, $CA, $44, $DD, $09, $9C, $9F, $42, $87, $40, $57, $AE, $18, $64, $58, $27, $20, $97, $64, $36, $C6, $4A, $59, $3A, $35, $36
	dc.b	$5D, $B1, $A6, $56, $9E, $1B, $28, $CD, $6D, $8E, $54, $B0, $83, $25, $DD, $6E, $D7, $2D, $EF, $DC, $8F, $3C, $84, $4F, $0C, $22, $9A, $C9, $86, $D7, $DA, $54
	dc.b	$BF, $56, $2A, $BE, $A1, $6F, $8D, $6E, $6A, $E4, $F4, $24, $62, $BE, $59, $06, $D6, $77, $10, $67, $6A, $CF, $F3, $DD, $34, $9C, $30, $AB, $04, $86, $AD, $97
	dc.b	$8D, $35, $A5, $8B, $A2, $41, $7B, $25, $64, $4C, $10, $24, $AF, $27, $2A, $D9, $CA, $01, $0C, $A5, $00, $9E, $F3, $BF, $78, $27, $2C, $34, $89, $C9, $5D, $88
	dc.b	$14, $8A, $E2, $05, $82, $4C, $D6, $45, $22, $C1, $3B, $60, $B3, $52, $72, $C1, $1B, $93, $90, $27, $AC, $B9, $75, $72, $04, $E5, $BB, $5C, $48, $4E, $42, $A8
	dc.b	$52, $24, $27, $29, $73, $82, $75, $76, $25, $16, $2D, $BA, $6B, $A1, $6D, $66, $E9, $F9, $C8, $E4, $16, $D5, $69, $B6, $5D, $E8, $97, $90, $BE, $63, $22, $BA
	dc.b	$63, $52, $94, $E5, $A9, $1C, $A9, $69, $86, $05, $92, $82, $72, $19, $02, $16, $56, $91, $48, $9B, $99, $11, $86, $2C, $DA, $E5, $0C, $58, $50, $C5, $BF, $32
	dc.b	$9E, $F4, $BE, $77, $10, $D8, $14, $98, $4F, $05, $51, $3C, $72, $D5, $B8, $98, $D7, $72, $85, $49, $F3, $15, $1B, $39, $44, $A0, $B3, $8D, $69, $09, $26, $11
	dc.b	$69, $14, $C2, $E9, $2D, $86, $B9, $44, $B8, $B6, $DA, $4A, $D7, $EC, $BB, $5D, $AA, $E7, $96, $98, $BC, $85, $6E, $FC, $96, $D8, $9D, $A6, $D8, $98, $9D, $DB
	dc.b	$4F, $3D, $9B, $2B, $AF, $2D, $6E, $B5, $E5, $75, $5B, $3E, $31, $3D, $27, $94, $98, $22, $89, $BA, $D5, $32, $10, $1B, $B6, $D3, $E9, $31, $C7, $4A, $99, $9C
	dc.b	$B6, $FC, $C7, $61, $D7, $57, $D4, $AB, $7E, $43, $2D, $52, $62, $FA, $0D, $18, $A6, $41, $B4, $9A, $30, $CA, $F6, $D1, $27, $D1, $B2, $A0, $CB, $4B, $D8, $2D
	dc.b	$FA, $E9, $4C, $8A, $1B, $F3, $37, $8A, $2E, $C2, $F2, $45, $D8, $64, $FF, $A2, $0A, $58, $BE, $A4, $D2, $6A, $93, $13, $D1, $0B, $11, $D0, $10, $24, $5A, $39
	dc.b	$04, $E3, $2B, $E8, $C3, $60, $4D, $7E, $BB, $3A, $B0, $6A, $6C, $23, $F2, $44, $E5, $13, $08, $B1, $D1, $04, $54, $CC, $EA, $75, $CF, $84, $B8, $83, $77, $E8
	dc.b	$F3, $62, $17, $E9, $D1, $36, $0C, $1A, $FA, $69, $B1, $05, $2F, $6E, $88, $35, $52, $67, $D5, $BF, $24, $B2, $98, $D6, $B7, $CA, $65, $C6, $26, $CB, $74, $C9
	dc.b	$AE, $BD, $33, $43, $33, $DF, $6D, $F4, $DE, $3F, $87, $B3, $67, $33, $9E, $F3, $CF, $9B, $88, $C4, $02, $1B, $43, $C0, $21, $B1, $63, $60, $52, $25, $D8, $12
	dc.b	$90, $25, $72, $05, $22, $04, $AE, $40, $81, $6D, $85, $74, $DE, $98, $80, $57, $10, $29, $13, $CE, $30, $A2, $6B, $22, $59, $29, $02, $CB, $7C, $8F, $75, $94
	dc.b	$C8, $14, $96, $8E, $4A, $43, $F3, $C4, $F3, $21, $C3, $94, $F1, $3B, $4F, $6E, $D4, $E2, $FF, $CF, $90, $2C, $9B, $51, $B0, $BD, $B2, $A6, $4D, $AD, $3F, $3E
	dc.b	$D4, $DB, $49, $D4, $E9, $29, $8B, $6C, $BE, $42, $8F, $D8, $15, $96, $61, $47, $38, $67, $51, $B3, $93, $C0, $C9, $DB, $90, $4A, $43, $91, $60, $43, $90, $B4
	dc.b	$C3, $28, $A7, $2E, $DD, $AC, $59, $FE, $C4, $12, $E5, $82, $51, $91, $61, $5F, $99, $2B, $F3, $25, $27, $27, $F3, $52, $04, $F7, $FE, $9F, $04, $EA, $26, $E5
	dc.b	$89, $BE, $B0, $59, $F2, $A3, $91, $A7, $31, $8C, $B1, $C8, $D8, $13, $90, $F2, $B4, $ED, $3B, $4E, $A5, $7E, $9C, $51, $2D, $96, $97, $E5, $A3, $74, $0D, $C8
	dc.b	$E6, $8B, $5E, $BD, $C5, $F7, $15, $FA, $DD, $7C, $16, $77, $C6, $F7, $99, $9F, $4A, $25, $FD, $2A, $A9, $A7, $47, $B0, $D7, $4F, $C9, $7E, $60, $A3, $4A, $5F
	dc.b	$45, $D5, $49, $44, $6D, $E9, $DA, $2F, $2B, $5F, $C1, $4C, $5E, $DD, $6B, $AE, $92, $BF, $89, $97, $EC, $B8, $AD, $E0, $9F, $6A, $B6, $5C, $8B, $68, $43, $55
	dc.b	$FC, $D8, $BC, $A6, $54, $1E, $05, $FD, $2F, $75, $DB, $C7, $E7, $BC, $2F, $4D, $1B, $50, $40, $9F, $22, $D4, $98, $AB, $19, $5F, $B1, $0B, $02, $17, $C6, $A2
	dc.b	$D2, $BF, $4C, $AF, $B3, $AE, $8C, $B3, $B3, $59, $74, $A6, $D5, $A6, $DD, $7F, $39, $AB, $E5, $51, $92, $DF, $F9, $CE, $67, $7D, $69, $C7, $4C, $B8, $2D, $38
	dc.b	$E9, $7E, $A3, $CD, $81, $45, $18, $98, $5E, $C9, $42, $E0, $A9, $7E, $41, $18, $9C, $BD, $81, $36, $B9, $43, $3A, $2F, $44, $C6, $B1, $A2, $3E, $91, $3E, $96
	dc.b	$47, $D2, $36, $4D, $6B, $39, $2D, $34, $E9, $B7, $71, $FA, $CB, $29, $04, $5F, $CF, $37, $46, $1B, $54, $AF, $6C, $AF, $E9, $61, $F9, $24, $BE, $27, $02, $FA
	dc.b	$DE, $2F, $87, $AB, $5D, $56, $CD, $8C, $CC, $F7, $E2, $F6, $84, $AE, $C5, $55, $AC, $F9, $9A, $5E, $BA, $79, $69, $5D, $7A, $56, $FC, $97, $F5, $F3, $2C, $81
	dc.b	$30, $DA, $DA, $5A, $FA, $64, $D1, $96, $D9, $6D, $6C, $9B, $4C, $B9, $10, $F5, $A5, $E0, $AD, $18, $FD, $10, $B6, $7F, $92, $33, $DF, $4B, $99, $76, $B9, $AB
	dc.b	$19, $DE, $C6, $66, $67, $9D, $23, $1A, $AD, $85, $AB, $15, $99, $5E, $D9, $35, $03, $0C, $98, $AB, $A0, $61, $13, $A4, $D2, $3A, $6B, $EC, $34, $8A, $A3, $7E
	dc.b	$7D, $4A, $DD, $02, $7E, $7F, $A6, $5F, $9B, $D2, $B7, $E9, $B5, $7F, $55, $DE, $76, $DA, $D5, $8D, $2D, $7D, $1B, $4A, $36, $BA, $73, $B0, $A6, $8A, $12, $F8
	dc.b	$BC, $36, $9A, $D3, $81, $5D, $1A, $82, $F6, $D6, $7A, $16, $9B, $16, $BC, $06, $D2, $79, $6B, $A6, $A5, $A6, $AD, $4E, $3C, $65, $6D, $6D, $30, $A1, $69, $B5
	dc.b	$E4, $99, $5D, $7D, $B6, $D2, $A9, $60, $D5, $05, $7B, $51, $26, $BE, $16, $9A, $64, $D9, $51, $B6, $F6, $FD, $73, $D2, $76, $58, $5A, $6C, $96, $BD, $AF, $DA
	dc.b	$8B, $35, $96, $9F, $9E, $A0, $60, $8D, $AE, $85, $4C, $83, $7E, $48, $A9, $AA, $74, $D4, $9A, $FC, $9F, $5C, $BF, $25, $A8, $40, $57, $E5, $78, $D6, $36, $BF
	dc.b	$F7, $D4, $CB, $5B, $E0, $B2, $05, $F9, $21, $B1, $02, $0C, $9A, $F4, $FC, $C9, $6B, $90, $BF, $A6, $DD, $0B, $45, $B5, $FA, $E5, $B5, $32, $4B, $7E, $70, $2F
	dc.b	$8B, $F6, $9E, $D5, $49, $D9, $3F, $95, $5E, $F3, $DA, $9B, $6B, $FA, $DD, $AD, $AE, $D7, $96, $A2, $7F, $9F, $6D, $49, $C9, $16, $FE, $34, $E3, $65, $D4, $5E
	dc.b	$43, $2D, $BC, $5F, $42, $D4, $6C, $DF, $92, $CB, $91, $A6, $BE, $34, $D7, $F3, $C3, $F5, $4D, $90, $29, $8E, $76, $E6, $A9, $55, $41, $EC, $29, $A1, $56, $77
	dc.b	$BB, $6D, $45, $A5, $BF, $24, $DB, $0C, $83, $7E, $62, $FD, $18, $64, $32, $D2, $FD, $5B, $2F, $CE, $24, $0A, $36, $5D, $65, $90, $CB, $17, $D3, $22, $AC, $B2
	dc.b	$6B, $C1, $48, $AF, $DB, $50, $CF, $4B, $ED, $95, $B6, $9B, $FE, $BA, $06, $48, $FF, $9E, $A7, $E7, $A9, $7D, $2F, $27, $CA, $82, $D9, $EA, $1B, $59, $6D, $AD
	dc.b	$B6, $D3, $CD, $5A, $9D, $35, $EB, $A6, $C5, $91, $69, $D5, $A2, $BF, $9B, $F2, $B5, $67, $6D, $96, $3F, $37, $3A, $DF, $32, $C9, $BF, $5B, $94, $F2, $FD, $7E
	dc.b	$57, $FE, $73, $21, $AA, $68, $C1, $9F, $58, $D6, $F2, $6D, $50, $31, $5E, $32, $69, $D0, $5F, $90, $2B, $C3, $64, $D6, $27, $BE, $B3, $AB, $5F, $1D, $DA, $F7
	dc.b	$86, $BC, $CC, $EE, $4D, $D0, $CC, $CC, $CC, $F7, $D7, $7A, $FE, $6D, $1A, $59, $7E, $7D, $43, $75, $19, $17, $68, $15, $56, $D1, $69, $D2, $A1, $7C, $45, $17
	dc.b	$A6, $BF, $AD, $D0, $7E, $7A, $7A, $53, $46, $2C, $B5, $BE, $76, $9D, $67, $DE, $C3, $CD, $F9, $B7, $EA, $AD, $3B, $4F, $FE, $C4, $39, $8E, $61, $E6, $41, $4A
	dc.b	$8F, $31, $D8, $4C, $A4, $4E, $4E, $4E, $46, $0B, $79, $EF, $63, $33, $33, $05, $8F, $CD, $F2, $08, $45, $A6, $4E, $A1, $73, $8B, $8A, $04, $13, $F2, $3B, $48
	dc.b	$9C, $87, $3F, $FF, $3F, $FC, $FF, $DF, $FB, $D3, $CB, $34, $1F, $FD, $33, $CB, $5C, $B5, $B7, $E7, $F2, $9D, $A7, $6D, $7F, $37, $3F, $FB, $41, $48, $81, $29
	dc.b	$5C, $A0, $B0, $43, $91, $CB, $AC, $BF, $C3, $02, $0A, $1D, $5F, $B6, $C3, $F4, $F0, $43, $52, $8E, $60, $40, $29, $47, $31, $8C, $82, $D2, $45, $93, $D2, $45
	dc.b	$05, $D4, $58, $10, $80, $42, $C0, $82, $88, $C1, $39, $48, $95, $D7, $04, $B0, $40, $9E, $28, $A3, $91, $CD, $88, $17, $FF, $CF, $FF, $3F, $F7, $FF, $F1, $FF
	dc.b	$F4, $CF, $F3, $DF, $DF, $F2, $FE, $DF, $FD, $82, $D8, $84, $4A, $2C, $A1, $79, $0B, $0A, $39, $51, $D7, $97, $8C, $15, $DC, $C7, $23, $9D, $82, $94, $97, $69
	dc.b	$88, $1C, $C1, $58, $A3, $CC, $41, $74, $87, $57, $98, $57, $57, $9E, $B2, $21, $04, $A4, $F0, $4E, $56, $8B, $8A, $70, $17, $13, $16, $20, $4F, $39, $2D, $D3
	dc.b	$0B, $CC, $88, $10, $20, $4F, $FF, $F3, $FF, $CF, $FD, $FF, $FC, $7F, $FD, $33, $FE, $7E, $5F, $9F, $FE, $5C, $FF, $37, $FF, $62, $87, $FD, $8A, $BD, $A7, $CA
	dc.b	$EC, $F6, $9B, $AA, $44, $BC, $ED, $2F, $31, $19, $96, $64, $22, $EE, $4C, $CC, $CD, $CA, $39, $04, $39, $50, $43, $97, $20, $40, $BB, $5C, $57, $E0, $81, $56
	dc.b	$08, $10, $B7, $20, $A5, $61, $FF, $F3, $FF, $CF, $FD, $FF, $9D, $3F, $CF, $5C, $8F, $FF, $D3, $33, $33, $33, $DE, $FC, $EF, $8C, $5F, $96, $96, $B9, $81, $66
	dc.b	$D3, $33, $33, $33, $33, $33, $33, $33, $33, $33, $33, $3D, $F6, $C5, $FF, $AD, $CF, $CB, $17, $A7, $E7, $A5, $78, $85, $A5, $C4, $B4, $FD, $52, $42, $D2, $7F
	dc.b	$AE, $6E, $74, $B7, $95, $BF, $95, $E6, $39, $05, $F9, $B9, $DB, $CA, $D3, $FF, $B1, $99, $99, $99, $99, $99, $99, $98, $D7, $7C, $B9, $8C, $CB, $72, $BA, $6E
	dc.b	$B8, $B7, $9C, $BF, $7F, $6F, $D7, $FE, $F6, $C9, $9D, $F6, $CB, $6C, $5E, $EA, $F7, $D3, $F3, $FF, $9E, $37, $BF, $F9, $A6, $7F, $FD, $FF, $CF, $FD, $FF, $FC
	dc.b	$7F, $FD, $33, $33, $6B, $F3, $DA, $71, $75, $7F, $3D, $75, $AB, $A7, $EF, $E3, $2D, $85, $7F, $37, $5B, $FD, $AD, $59, $DA, $B6, $09, $22, $05, $6D, $7F, $37
	dc.b	$E5, $69, $FF, $D8, $CC, $CC, $CC, $B7, $23, $33, $33, $DE, $3C, $C1, $3A, $C7, $20, $A4, $40, $AE, $8E, $44, $4A, $24, $B2, $8E, $47, $20, $9C, $9C, $87, $FF
	dc.b	$FF, $FA, $66, $66, $69, $BC, $FF, $3D, $BB, $5D, $36, $5C, $FB, $66, $A6, $66, $66, $66, $66, $66, $66, $66, $66, $67, $9E, $C6, $FF, $CD, $FF, $CF, $FD, $FF
	dc.b	$FC, $7F, $FD, $33, $FD, $6D, $DB, $78, $B9, $78, $BB, $F5, $DE, $0E, $5F, $CD, $33, $33, $92, $EF, $4F, $2B, $6E, $5E, $47, $A0, $FE, $B5, $A5, $17, $D6, $CA
	dc.b	$13, $F2, $5F, $99, $57, $E9, $97, $45, $3C, $2E, $F4, $5C, $E2, $8B, $9C, $5A, $EB, $7E, $72, $E5, $33, $33, $33, $75, $A2, $85, $75, $9A, $85, $9A, $F8, $28
	dc.b	$75, $A2, $E2, $7B, $AC, $A3, $38, $37, $69, $8E, $B2, $E8, $22, $55, $67, $2B, $7B, $47, $41, $DA, $9F, $9E, $E9, $E3, $1E, $2E, $A6, $70, $FF, $C6, $0B, $19
	dc.b	$95, $D1, $5F, $E5, $E9, $3D, $BF, $8E, $67, $BA, $F9, $69, $29, $D0, $43, $AC, $DE, $1F, $C3, $C3, $D9, $5E, $1E, $B2, $89, $65, $9D, $45, $84, $3D, $72, $B7
	dc.b	$59, $65, $66, $A4, $98, $37, $4A, $0F, $CD, $F4, $A5, $68, $2D, $FA, $DC, $4F, $F6, $FF, $A6, $F2, $1C, $CB, $C0, $B1, $05, $92, $F8, $B2, $8F, $DB, $6C, $BF
	dc.b	$9C, $78, $AE, $D8, $BD, $B6, $C5, $B2, $DA, $E5, $3C, $2D, $27, $25, $F0, $B2, $F0, $B8, $ED, $88, $59, $CB, $AB, $AB, $C3, $C4, $DE, $1E, $B0, $A2, $1E, $B9
	dc.b	$58, $40, $F6, $CB, $A4, $E0, $5B, $F3, $D3, $AA, $F1, $D2, $74, $57, $FC, $C5, $E3, $B7, $5F, $1F, $AA, $20, $AF, $FA, $DF, $CD, $E9, $77, $81, $D4, $B1, $47
	dc.b	$5F, $E3, $6F, $6F, $6B, $C5, $BF, $38, $BF, $99, $CB, $45, $33, $33, $97, $96, $99, $C6, $70, $2D, $99, $74, $1D, $BC, $09, $85, $9D, $3B, $5B, $A5, $F4, $59
	dc.b	$4E, $AB, $88, $1D, $BF, $6C, $3C, $81, $3A, $C7, $85, $9F, $EA, $E7, $2F, $D6, $F6, $8B, $BC, $0F, $DB, $4B, $F4, $AF, $FA, $6F, $CF, $27, $E9, $6F, $50, $B4
	dc.b	$FD, $76, $DA, $59, $FF, $8F, $A1, $99, $99, $9E, $F3, $DE, $3F, $39, $BE, $97, $57, $4C, $F6, $33, $33, $33, $33, $3C, $E9, $9F, $6C, $E7, $BA, $BA, $FE, $70
	dc.b	$2B, $CE, $92, $D2, $50, $2D, $BD, $95, $D4, $E5, $03, $47, $87, $61, $D1, $79, $BA, $76, $7A, $E5, $D1, $E8, $52, $E9, $5A, $3D, $63, $A5, $25, $5C, $BA, $56
	dc.b	$51, $97, $4A, $0F, $D3, $0E, $97, $F6, $F3, $5E, $9F, $DA, $D1, $FC, $BF, $BB, $D8, $C7, $E9, $9F, $F4, $CE, $9D, $65, $5B, $F5, $97, $B6, $5B, $2F, $EA, $FF
	dc.b	$3C, $15, $FF, $8E, $EA, $79, $D1, $ED, $2A, $28, $B7, $61, $D8, $58, $9D, $66, $E4, $F6, $0A, $62, $04, $05, $DE, $F7, $83, $EB, $88, $B5, $08, $57, $2B, $30
	dc.b	$99, $63, $A4, $D4, $2E, $5D, $2D, $3E, $C3, $4F, $CC, $3A, $93, $53, $A3, $F9, $5B, $A5, $07, $FF, $4D, $FF, $4C, $FF, $A6, $75, $EB, $2A, $DF, $A3, $AF, $B6
	dc.b	$5B, $2F, $E6, $F4, $FC, $F7, $67, $FD, $BC, $A9, $35, $CE, $2D, $74, $0D, $2E, $AD, $B3, $C9, $73, $53, $3D, $FC, $BB, $67, $4B, $7E, $71, $FF, $4C, $FA, $4A
	dc.b	$F4, $AE, $92, $AE, $DA, $ED, $8C, $BB, $5C, $A6, $66, $67, $72, $CF, $3A, $1E, $6B, $77, $6A, $5D, $DB, $F5, $46, $66, $66, $66, $66, $67, $BA, $99, $99, $CB
	dc.b	$49, $BA, $DD, $3C, $52, $4B, $22, $95, $2E, $87, $57, $AE, $28, $66, $F5, $78, $79, $8B, $67, $30, $59, $D2, $72, $58, $91, $67, $49, $96, $F3, $59, $E9, $FA
	dc.b	$AE, $D4, $53, $DD, $77, $A6, $6B, $BD, $0E, $5A, $2D, $DA, $0A, $2E, $F4, $14, $0B, $85, $0B, $6C, $51, $D7, $7B, $EE, $A4, $E5, $17, $2E, $79, $67, $D0, $5F
	dc.b	$77, $41, $5C, $50, $2D, $97, $13, $BA, $93, $57, $D3, $1D, $A5, $49, $A9, $05, $16, $13, $A5, $9F, $A7, $61, $E0, $7E, $7D, $67, $49, $74, $5A, $67, $49, $75
	dc.b	$14, $7E, $B8, $EB, $25, $9C, $3A, $D6, $DA, $4F, $F5, $7A, $65, $FA, $79, $D2, $C2, $DE, $54, $59, $13, $A8, $8C, $2E, $2D, $33, $82, $11, $82, $BA, $01, $5A
	dc.b	$51, $41, $6C, $FA, $52, $50, $FD, $29, $37, $8A, $0F, $0A, $F1, $BD, $05, $1E, $16, $C2, $83, $AE, $3A, $CA, $6F, $FC, $BE, $92, $FD, $ED, $FF, $AD, $C2, $DD
	dc.b	$D5, $FB, $75, $7E, $DC, $C9, $79, $75, $AD, $B4, $1F, $AB, $D3, $2E, $D6, $FE, $6B, $D2, $5D, $71, $D4, $59, $FA, $C9, $6E, $AD, $B0, $B7, $E4, $B2, $AE, $9B
	dc.b	$2E, $32, $ED, $72, $99, $9D, $DA, $4F, $78, $33, $BB, $B6, $F7, $99, $9D, $DD, $B2, $C7, $85, $15, $75, $28, $A4, $F2, $79, $C9, $66, $F1, $85, $7B, $DE, $0F
	dc.b	$09, $BC, $D5, $E3, $15, $CF, $B6, $E8, $AF, $12, $9D, $F2, $A7, $60, $8B, $2F, $02, $70, $E5, $03, $C4, $EC, $2B, $9D, $9E, $1E, $8E, $BB, $AB, $C3, $D0, $65
	dc.b	$5C, $D6, $51, $8C, $AB, $8A, $05, $CA, $A2, $30, $A9, $BC, $C8, $43, $E9, $3A, $4E, $5A, $88, $14, $FC, $DD, $35, $C7, $81, $A7, $57, $A2, $F4, $11, $89, $EF
	dc.b	$F9, $8C, $28, $D6, $99, $CE, $E9, $CA, $CE, $A2, $92, $2B, $A3, $14, $10, $3C, $96, $62, $1D, $44, $C5, $3F, $56, $26, $EA, $3C, $82, $8E, $8B, $3E, $D2, $E9
	dc.b	$35, $31, $18, $5C, $E8, $F1, $9C, $3C, $50, $DE, $25, $A6, $0B, $F3, $6B, $D0, $41, $4F, $2F, $0E, $53, $C9, $84, $FA, $09, $E4, $CE, $BD, $05, $19, $E3, $38
	dc.b	$7E, $87, $47, $8C, $E1, $E3, $38, $F0, $F0, $22, $82, $78, $A3, $EA, $B3, $FC, $DF, $8B, $6A, $B3, $F0, $22, $B3, $A4, $A0, $65, $88, $15, $59, $40, $AE, $52
	dc.b	$81, $5C, $95, $E1, $CA, $50, $12, $FD, $56, $55, $D7, $65, $95, $B2, $9D, $DE, $4B, $65, $97, $68, $CE, $04, $2C, $A1, $DB, $38, $CB, $36, $5C, $F2, $CE, $B9
	dc.b	$D7, $25, $BB, $2A, $4F, $4C, $50, $46, $71, $9C, $3D, $8F, $3B, $29, $DD, $65, $BA, $37, $A2, $9E, $EB, $9D, $82, $DD, $A7, $E6, $F4, $FD, $D0, $B3, $C6, $14
	dc.b	$EC, $F1, $75, $F9, $F4, $57, $89, $6B, $95, $5E, $25, $D3, $2A, $DD, $AF, $4C, $AE, $D2, $BD, $3F, $37, $75, $7A, $61, $60, $56, $92, $21, $07, $18, $A2, $BC
	dc.b	$62, $B9, $AA, $6F, $45, $CD, $4B, $7A, $2E, $6B, $A2, $E6, $BA, $6E, $B9, $AC, $F3, $B1, $C1, $E7, $63, $AE, $6B, $91, $9F, $69, $FE, $9E, $74, $98, $A3, $D1
	dc.b	$D6, $54, $3C, $4C, $4E, $51, $25, $B9, $71, $06, $21, $CB, $75, $10, $F6, $80, $57, $58, $4E, $56, $A7, $E6, $25, $67, $AF, $4F, $16, $19, $3F, $4A, $49, $9E
	dc.b	$A1, $46, $A2, $1E, $8E, $57, $28, $67, $8B, $A1, $E0, $50, $E4, $4F, $18, $9D, $B9, $78, $97, $92, $8B, $0F, $0F, $7F, $4C, $78, $FD, $41, $44, $A8, $3A, $4C
	dc.b	$44, $A9, $88, $95, $05, $EF, $12, $9A, $CA, $1D, $72, $AE, $76, $AD, $BF, $39, $FA, $A3, $33, $33, $31, $63, $53, $BA, $C3, $CA, $EC, $A0, $52, $59, $36, $6D
	dc.b	$0F, $DB, $11, $74, $62, $79, $B1, $CE, $50, $63, $85, $CE, $99, $E5, $74, $28, $B5, $24, $53, $A0, $5A, $02, $9F, $48, $75, $13, $E8, $D8, $A2, $E6, $A7, $AF
	dc.b	$43, $CE, $F1, $53, $BA, $8B, $B7, $E7, $3F, $54, $66, $BB, $CC, $CF, $79, $9F, $4F, $DE, $79, $2E, $BE, $CF, $0E, $BF, $9E, $AB, $C3, $A8, $CB, $3E, $DF, $AB
	dc.b	$BA, $DE, $33, $EA, $67, $75, $AB, $9A, $9E, $57, $E6, $A5, $BE, $A6, $74, $5D, $BF, $59, $E4, $B3, $CA, $A7, $2A, $40, $E9, $96, $2D, $3C, $50, $50, $7E, $62
	dc.b	$C1, $5F, $C7, $E6, $2D, $A8, $87, $A5, $71, $12, $A7, $49, $44, $A9, $88, $95, $31, $D5, $FD, $B1, $03, $F3, $D5, $C4, $2F, $4C, $BD, $B1, $AA, $FE, $7A, $D2
	dc.b	$9D, $07, $6F, $CE, $2C, $2C, $D6, $53, $75, $9E, $FD, $9E, $31, $3C, $43, $AB, $95, $CB, $BC, $C1, $5D, $31, $19, $AC, $D4, $45, $D1, $75, $A9, $3B, $95, $C9
	dc.b	$E8, $08, $52, $77, $44, $A9, $2B, $4D, $74, $FD, $3C, $E9, $3C, $E0, $4E, $9B, $AD, $D0, $F4, $DD, $68, $78, $87, $EC, $3F, $59, $3F, $6E, $8B, $29, $FE, $96
	dc.b	$92, $A7, $53, $EB, $25, $8D, $E9, $5C, $D7, $2B, $E2, $E5, $DA, $8A, $3F, $4F, $2A, $2C, $BB, $3F, $EF, $42, $E7, $E0, $75, $BA, $6F, $18, $59, $75, $97, $B4
	dc.b	$BF, $4D, $F9, $EF, $6E, $AE, $A3, $F3, $DE, $15, $FB, $4B, $4B, $63, $F7, $B2, $5E, $B9, $D9, $7A, $E1, $4B, $79, $C2, $E7, $4D, $33, $EC, $66, $66, $67, $D3
	dc.b	$F3, $9F, $AA, $A1, $8D, $5E, $1F, $B0, $8C, $E7, $43, $B0, $89, $2C, $F7, $59, $D9, $E8, $20, $28, $8A, $4B, $AD, $2A, $3B, $7E, $AE, $9D, $07, $97, $F3, $47
	dc.b	$8B, $BF, $5B, $07, $FB, $63, $FD, $35, $EB, $9E, $DA, $5B, $AA, $BF, $6E, $9E, $34, $85, $7D, $7B, $74, $A2, $5D, $AA, $EA, $7B, $AE, $6B, $61, $3A, $49, $74
	dc.b	$58, $5A, $62, $CE, $B4, $94, $08, $0B, $4D, $D6, $E8, $7A, $0B, $F3, $9E, $B5, $C4, $D4, $2B, $C6, $36, $49, $79, $28, $BE, $4A, $16, $74, $78, $1E, $1E, $D7
	dc.b	$2D, $27, $6C, $E1, $E2, $90, $E5, $3B, $4B, $F6, $D3, $B0, $FD, $38, $D2, $7F, $98, $1F, $9C, $B0, $57, $4F, $D4, $05, $F6, $D7, $F3, $15, $F0, $EB, $E2, $EA
	dc.b	$6F, $FF, $6F, $FE, $19, $99, $9C, $CF, $CA, $98, $EA, $16, $74, $C4, $3A, $D0, $59, $E1, $D6, $9B, $AE, $23, $16, $94, $3A, $88, $C2, $BD, $15, $E0, $76, $15
	dc.b	$91, $05, $1B, $44, $BF, $30, $F4, $97, $E6, $25, $67, $FD, $EF, $91, $5B, $1D, $84, $F3, $ED, $FF, $6F, $EE, $7E, $6F, $3E, $C6, $66, $66, $6B, $E5, $94, $FF
	dc.b	$58, $BE, $5B, $53, $F4, $D2, $ED, $FA, $DB, $BF, $4E, $66, $67, $FF, $CE, $AF, $FB, $BF, $1F, $9B, $FD, $38, $FD, $BB, $F8, $BA, $6B, $74, $CC, $75, $C7, $97
	dc.b	$5C, $FC, $8C, $D4, $FC, $BC, $2D, $DD, $A9, $3A, $0E, $B8, $59, $75, $92, $FE, $F3, $F5, $46, $66, $67, $3A, $6E, $B4, $B9, $68, $5F, $9C, $FD, $52, $CE, $CF
	dc.b	$D4, $43, $A4, $A2, $5A, $DF, $9A, $EC, $8F, $69, $F4, $0B, $AD, $57, $CB, $A2, $EA, $B9, $5E, $52, $E9, $A8, $CA, $D3, $EC, $3A, $3A, $85, $FE, $6A, $CE, $8B
	dc.b	$8A, $29, $E3, $A8, $FE, $33, $C1, $DD, $D7, $48, $BF, $F4, $DE, $42, $79, $7E, $A8, $CC, $CC, $CD, $FF, $55, $4D, $D7, $C7, $94, $A9, $D9, $E0, $28, $FD, $33
	dc.b	$C2, $CE, $D5, $10, $F0, $A3, $2B, $22, $BC, $79, $0D, $74, $91, $3F, $41, $FB, $B9, $BF, $EB, $67, $2E, $92, $5F, $1E, $52, $FD, $3B, $F5, $51, $C8, $9B, $F3
	dc.b	$03, $C9, $FA, $CE, $D4, $58, $D2, $74, $9D, $1E, $61, $69, $9D, $07, $ED, $86, $9D, $6E, $FC, $E0, $8B, $FA, $CB, $49, $E5, $E4, $66, $67, $FA, $AA, $6E, $BE
	dc.b	$54, $DD, $67, $07, $FA, $6C, $5F, $2E, $AF, $B7, $79, $75, $E8, $BA, $D6, $25, $D0, $74, $CA, $95, $97, $41, $DB, $2A, $CB, $A7, $61, $95, $9E, $7F, $ED, $53
	dc.b	$C4, $4B, $F6, $C3, $F4, $C6, $FE, $D6, $FD, $AD, $B2, $D9, $7F, $73, $D8, $CC, $CC, $CC, $DF, $4A, $67, $0B, $4D, $D6, $9B, $AD, $0E, $50, $AE, $B4, $91, $2D
	dc.b	$D5, $04, $A2, $7A, $84, $F6, $48, $9D, $FA, $88, $CA, $08, $2D, $56, $B4, $BC, $5F, $03, $F4, $E5, $36, $8A, $12, $4D, $AD, $14, $E9, $5C, $BA, $34, $53, $A6
	dc.b	$B9, $2B, $42, $F4, $D4, $2E, $9D, $6F, $D5, $E8, $15, $B5, $94, $CA, $7A, $E1, $68, $A6, $77, $00
;Championship_standings_tilemap_list
Championship_standings_tilemap_list:
	dc.b	$00, $01
	dc.l	Championship_standings_team_names_a
	dc.l	Championship_standings_team_names_b
;Championship_standings_team_names_a
Championship_standings_team_names_a:
	dc.b	$E3, $88, $FB, $67, $C0
	txt "MADONNA\n"
	txt "FIRENZE\n"
	txt "MILLIONS\n"
	txt "BESTOWAL\n", $FD
	txt "BLANCHE\n"
	txt "TYRANT\n"
	txt "LOSEL\n"
	txt "MAY", $FF, $00
;Championship_standings_team_names_b
Championship_standings_team_names_b:
	dc.b	$E3, $AC
	txt "BULLETS\n"
	txt "DARDAN\n"
	txt "LINDEN\n"
	txt "MINARAE\n", $FD
	txt "RIGEL\n"
	txt "COMET\n"
	txt "ORCHIS\n"
	txt "ZEROFORCE\n", $FD
	txt "EXIT", $FF
;Championship_standings_tiles
Championship_standings_tiles:
	dc.b	$08, $00, $00, $00, $00, $00, $01, $F7, $DE, $3C, $67, $D0, $3C, $77, $CF, $1D, $F0, $A7, $A5, $42, $4A, $01, $90, $27, $A6, $4F, $4C, $88, $98, $8C, $14, $C0
	dc.b	$66, $27, $01, $05, $30, $19, $8A, $20, $41, $4C, $46, $0A, $60, $0C, $0B, $05, $30, $06, $2A, $2A, $01, $05, $31, $18, $29, $9C, $14, $D8, $13, $9A, $CA, $62
	dc.b	$62, $D3, $15, $17, $39, $2D, $A6, $26, $23, $05, $33, $82, $9B, $21, $21, $CD, $65, $31, $31, $69, $80, $60, $31, $03, $C9, $6D, $31, $31, $18, $29, $9C, $14
	dc.b	$D9, $09, $0E, $6B, $29, $89, $8B, $4C, $09, $C9, $6D, $31, $31, $18, $29, $9C, $14, $D9, $09, $0E, $6B, $29, $89, $8B, $40, $2E, $0A, $00, $F2, $5B, $4C, $4C
	dc.b	$46, $0A, $67, $05, $36, $04, $E6, $B2, $98, $98, $B4, $C0, $28, $03, $C9, $6D, $31, $31, $18, $29, $9C, $14, $D8, $13, $9A, $CA, $62, $62, $D3, $02, $72, $5B
	dc.b	$4C, $4C, $46, $0A, $60, $33, $23, $00, $82, $98, $0C, $C8, $F0, $20, $A6, $23, $05, $30, $19, $92, $5C, $94, $93, $13, $01, $99, $28, $04, $14, $C4, $60, $A6
	dc.b	$40, $5A, $01, $40, $11, $A8, $A9, $C9, $6D, $31, $30, $06, $2A, $2A, $01, $05, $31, $18, $29, $9C, $16, $98, $A8, $B9, $CD, $6D, $31, $32, $61, $8A, $8B, $9C
	dc.b	$A6, $53, $13, $11, $82, $99, $C5, $6A, $59, $4E, $12, $E8, $81, $05, $88, $1E, $6B, $69, $89, $93, $0C, $77, $9A, $62, $62, $66, $67, $99, $4C, $4C, $46, $0A
	dc.b	$67, $05, $A6, $01, $80, $DA, $0F, $35, $B4, $C4, $C9, $86, $28, $CE, $C0, $6D, $03, $9B, $7C, $CA, $62, $62, $30, $53, $20, $2D, $00, $BC, $09, $D0, $F9, $AD
	dc.b	$A6, $26, $4C, $31, $02, $74, $04, $28, $BA, $72, $99, $4C, $4C, $46, $0A, $67, $05, $A6, $20, $4E, $81, $02, $0C, $1E, $6B, $69, $89, $93, $0C, $72, $9D, $A7
	dc.b	$00, $03, $9B, $AC, $CA, $62, $62, $30, $53, $20, $2D, $00, $B8, $30, $22, $01, $E6, $B6, $98, $99, $30, $C5, $1A, $D8, $11, $00, $F2, $99, $4C, $4C, $46, $0A
	dc.b	$65, $18, $E9, $91, $FC, $A4, $13, $13, $01, $99, $68, $04, $14, $C4, $67, $A6, $4F, $4C, $8A, $98, $8C, $F4, $C8, $69, $8A, $CB, $4C, $46, $7A, $64, $F4, $C8
	dc.b	$A9, $8F, $BE, $C7, $F0, $00
;Championship_standings_vdp_word_run
Championship_standings_vdp_word_run:
	dc.b	$60, $0E, $06, $66, $00, $00, $0E, $EE, $00, $00, $06, $88, $04, $46, $04, $44, $02, $22, $00, $00, $00, $0E, $00, $00, $04, $4E, $06, $68, $06, $66, $08, $88
;Championship_standings_tiles_b
Championship_standings_tiles_b:
	dc.b	$00, $B6, $80, $08, $F3, $84, $04, $04, $15, $17, $28, $F5, $85, $04, $05, $16, $38, $86, $05, $0E, $18, $F4, $87, $04, $08, $17, $74, $27, $78, $88, $06, $36
	dc.b	$15, $1A, $27, $72, $37, $76, $48, $F6, $89, $06, $33, $15, $13, $28, $F2, $8B, $04, $0A, $8C, $06, $37, $8D, $03, $00, $14, $03, $25, $0F, $36, $32, $45, $16
	dc.b	$55, $18, $65, $12, $74, $02, $8E, $04, $06, $17, $73, $27, $77, $77, $75, $FF, $22, $22, $22, $22, $2C, $73, $CB, $9A, $64, $C9, $66, $4C, $30, $43, $50, $C8
	dc.b	$F5, $40, $D6, $41, $D5, $08, $82, $9A, $BD, $7F, $96, $82, $BC, $B6, $CE, $F5, $3D, $86, $D7, $A9, $F2, $EA, $15, $0D, $4D, $51, $F7, $08, $7C, $04, $1F, $9B
	dc.b	$5B, $FE, $AF, $C9, $05, $7F, $24, $EA, $7D, $85, $4F, $A8, $54, $35, $35, $47, $DC, $21, $F0, $10, $7E, $ED, $07, $E6, $FB, $1D, $66, $15, $EB, $59, $FF, $62
	dc.b	$B3, $EA, $15, $0D, $4D, $51, $F7, $08, $7C, $04, $14, $16, $E7, $59, $9A, $3E, $B3, $57, $AA, $56, $7A, $CA, $BA, $85, $43, $53, $54, $7D, $C2, $1F, $01, $07
	dc.b	$F6, $CE, $7D, $8E, $6F, $54, $13, $FE, $C7, $50, $A8, $6A, $6A, $8F, $B8, $43, $E0, $21, $FF, $6C, $54, $FB, $0A, $99, $AA, $0A, $9F, $B7, $50, $A8, $6A, $6A
	dc.b	$8F, $B8, $43, $E0, $21, $FF, $AC, $72, $A9, $EC, $14, $EA, $63, $6B, $ED, $53, $DB, $A8, $54, $35, $35, $47, $DC, $21, $F0, $10, $7E, $6D, $6E, $FD, $04, $B2
	dc.b	$BD, $50, $76, $CB, $A8, $54, $35, $35, $47, $DC, $21, $F0, $10, $7E, $AE, $EF, $DA, $69, $6F, $20, $A9, $43, $69, $EC, $75, $D4, $2A, $1A, $9A, $A3, $EE, $10
	dc.b	$F8, $08, $3F, $57, $71, $FA, $B9, $A0, $AF, $DC, $EC, $75, $FB, $9E, $55, $3E, $A1, $50, $D4, $D5, $1F, $70, $87, $C0, $41, $FC, $B7, $F2, $A9, $BD, $45, $4D
	dc.b	$07, $2A, $9E, $C3, $A8, $54, $35, $35, $47, $DC, $21, $F0, $10, $7E, $AE, $E3, $F5, $73, $43, $AC, $EA, $66, $B5, $9D, $4F, $42, $B3, $EA, $15, $0D, $4D, $51
	dc.b	$F7, $08, $7C, $04, $14, $17, $F9, $79, $9D, $4F, $59, $A8, $A9, $A0, $CF, $55, $3D, $75, $0A, $86, $A6, $A8, $FB, $84, $3E, $02, $0F, $CD, $E7, $77, $ED, $53
	dc.b	$B5, $4C, $2A, $0D, $AA, $7B, $3F, $A8, $54, $35, $35, $47, $DC, $21, $F0, $11, $EB, $7F, $D5, $BD, $05, $4C, $2B, $EA, $62, $E7, $53, $EA, $15, $0D, $4D, $51
	dc.b	$F7, $08, $7C, $04, $1F, $BB, $CD, $FC, $AA, $6F, $51, $53, $41, $CA, $A7, $B0, $EA, $15, $0D, $4D, $51, $F7, $08, $7C, $04, $1F, $AB, $BF, $EE, $E6, $83, $69
	dc.b	$D4, $CD, $67, $53, $D0, $9F, $50, $A8, $6A, $6A, $8F, $B8, $43, $E0, $23, $D6, $FF, $AB, $7A, $0A, $98, $57, $D6, $7C, $90, $54, $F6, $EA, $15, $0D, $4D, $51
	dc.b	$F7, $08, $7C, $04, $7A, $DE, $A6, $F4, $AF, $20, $A7, $5E, $5A, $41, $5E, $5D, $42, $A1, $A9, $AA, $3E, $E1, $0F, $80, $8F, $5B, $8F, $CD, $BD, $0E, $A6, $AF
	dc.b	$5A, $9E, $C8, $FA, $CF, $F7, $DB, $97, $EB, $0F, $8C, $2F, $A9, $D1, $DC, $D7, $35, $C9, $53, $3B, $BD, $06, $7A, $42, $2C, $BF, $38, $5B, $96, $F9, $23, $F7
	dc.b	$7D, $DF, $BC, $B7, $36, $4C, $6E, $F5, $35, $DC, $D6, $E1, $37, $3F, $53, $DE, $5B, $85, $C9, $77, $0A, $99, $6E, $77, $0A, $FA, $F2, $D1, $ED, $FB, $93, $5B
	dc.b	$ED, $E4, $68, $39, $67, $6E, $5C, $1A, $DF, $65, $4F, $D5, $A6, $55, $E4, $28, $76, $A9, $9F, $2A, $F2, $5F, $5A, $FD, $CA, $1D, $4E, $A6, $75, $3A, $98, $5A
	dc.b	$9D, $4F, $61, $53, $A9, $EA, $A7, $A3, $E2, $B3, $D2, $9A, $56, $7F, $BB, $41, $59, $F6, $3A, $CF, $4F, $5A, $CF, $FB, $15, $9E, $90, $D2, $B3, $D6, $55, $3D
	dc.b	$0E, $12, $B3, $D1, $A0, $AC, $F5, $73, $AC, $F5, $95, $67, $A3, $54, $AC, $F4, $16, $F5, $9E, $8D, $05, $67, $AC, $AA, $7A, $E1, $04, $F4, $10, $E7, $FB, $B3
	dc.b	$9F, $63, $9E, $82, $A0, $9F, $F6, $27, $A0, $87, $3D, $65, $53, $D2, $A0, $A9, $E9, $0E, $A7, $A7, $D4, $F4, $FA, $9E, $95, $05, $4F, $57, $15, $3D, $21, $D4
	dc.b	$F5, $2A, $9E, $C6, $A2, $A7, $B0, $5B, $D4, $F6, $34, $15, $3D, $B2, $A9, $ED, $C1, $D4, $F6, $5B, $8A, $9E, $D9, $54, $F4, $FE, $10, $6C, $14, $D0, $F6, $5F
	dc.b	$57, $EC, $12, $DB, $64, $A8, $36, $53, $5B, $8D, $AE, $68, $7B, $10, $F2, $5A, $CC, $F6, $9E, $D5, $98, $54, $9D, $4C, $D3, $6A, $F2, $CA, $A7, $B7, $07, $53
	dc.b	$D9, $6E, $2A, $7B, $65, $53, $DB, $3E, $D5, $E5, $C8, $54, $FB, $25, $4F, $91, $D4, $F9, $1D, $4F, $46, $B5, $3D, $21, $D4, $F6, $CA, $A7, $A1, $53, $EC, $B5
	dc.b	$3E, $C9, $53, $EC, $95, $3E, $C2, $A7, $D8, $54, $FB, $25, $4F, $B0, $A9, $EA, $A7, $A5, $AC, $EA, $7A, $4A, $CE, $A7, $A1, $59, $D4, $F4, $2B, $3A, $9E, $96
	dc.b	$B3, $A9, $E9, $2B, $3A, $9E, $92, $B3, $A9, $E8, $54, $F5, $53, $D6, $7A, $A9, $EB, $3D, $54, $FF, $37, $9E, $AA, $7A, $CF, $55, $3D, $67, $AA, $9E, $B3, $D5
	dc.b	$4F, $59, $EA, $A7, $A1, $53, $D2, $1D, $67, $C8, $EB, $3E, $C7, $53, $E4, $7B, $54, $F6, $54, $1B, $54, $D6, $E1, $6A, $7B, $23, $EA, $7A, $C2, $D4, $CD, $4E
	dc.b	$A6, $17, $D6, $A6, $68, $75, $3B, $54, $F8, $35, $A9, $AD, $CE, $A7, $6A, $9E, $85, $4F, $B2, $D6, $7C, $BF, $57, $9F, $F6, $2A, $7F, $D8, $A9, $EC, $39, $54
	dc.b	$D0, $69, $2A, $7B, $0D, $0A, $9E, $AA, $7A, $5D, $B3, $A9, $E9, $06, $75, $3D, $1E, $75, $3D, $1E, $D5, $3D, $2A, $0A, $9E, $AE, $2A, $7A, $43, $A9, $E9, $F9
	dc.b	$EC, $75, $3D, $B3, $D9, $45, $67, $AC, $F6, $4A, $9E, $A7, $B5, $4F, $53, $DA, $B3, $E5, $3A, $9F, $6C, $EA, $7C, $87, $97, $21, $A1, $59, $EB, $3D, $82, $D6
	dc.b	$69, $B6, $7B, $2A, $56, $63, $90, $AC, $F9, $3E, $B3, $1A, $1C, $56, $7F, $BB, $5A, $9F, $61, $59, $F2, $39, $9F, $15, $E5, $B1, $A5, $79, $6D, $71, $5F, $B9
	dc.b	$D8, $EB, $F7, $3B, $05, $AF, $DC, $EC, $A9, $59, $ED, $E5, $B2, $56, $63, $CB, $61, $53, $D0, $E1, $06, $7A, $34, $3C, $F5, $77, $E7, $AB, $67, $A3, $54, $19
	dc.b	$E8, $2D, $C6, $7A, $34, $3C, $F4, $45, $C0, $76, $4A, $83, $D0, $D6, $E3, $D3, $1E, $86, $AF, $F4, $0B, $EA, $21, $C7, $73, $87, $11, $13, $A5, $E9, $8F, $4C
	dc.b	$7E, $9A, $DF, $A6, $B6, $E7, $71, $7F, $49, $43, $D6, $E1, $D0, $6B, $73, $87, $1A, $65, $0E, $97, $47, $61, $DD, $0F, $6F, $2A, $CC, $D7, $D8, $2D, $FB, $1A
	dc.b	$1F, $2C, $95, $1E, $A8, $3D, $70, $87, $0E, $54, $CA, $7C, $AA, $7F, $F8, $1D, $8F, $D9, $FB, $59, $50, $70, $6B, $70, $B7, $34, $23, $FD, $DF, $15, $9F, $60
	dc.b	$9D, $BD, $5F, $FD, $89, $2A, $0E, $0D, $6E, $16, $E6, $84, $79, $FE, $ED, $52, $BD, $90, $76, $BB, $FF, $D1, $85, $41, $C1, $AD, $C2, $DC, $D0, $8E, $7F, $BB
	dc.b	$41, $FD, $87, $F2, $4C, $BF, $D1, $65, $41, $C1, $AD, $C2, $DC, $D0, $8F, $69, $FE, $EC, $FF, $B0, $6B, $CA, $C9, $ED, $65, $41, $C1, $AD, $C2, $DC, $D0, $B1
	dc.b	$53, $D8, $D4, $76, $0B, $EA, $39, $04, $7E, $AC, $A8, $38, $35, $B8, $5B, $9A, $11, $EC, $FE, $10, $6C, $14, $D0, $F6, $5F, $57, $EC, $10, $8D, $50, $70, $6B
	dc.b	$70, $B7, $34, $2C, $54, $F6, $35, $1D, $82, $FA, $8D, $1A, $3F, $56, $54, $1C, $1A, $DC, $2D, $CD, $08, $F6, $7A, $ED, $3D, $82, $9A, $72, $5F, $53, $D0, $42
	dc.b	$35, $41, $C1, $AD, $C2, $DC, $D0, $8F, $F5, $73, $FF, $C7, $B7, $AF, $FE, $35, $85, $41, $C1, $AD, $C2, $DC, $D0, $8F, $69, $FE, $AE, $63, $FD, $01, $79, $59
	dc.b	$3D, $AC, $A8, $38, $35, $B8, $5B, $9A, $11, $F2, $A9, $FF, $E3, $DA, $FE, $C8, $7C, $AC, $A8, $38, $35, $B8, $5B, $9A, $13, $EA, $7A, $43, $F6, $7A, $A7, $2C
	dc.b	$93, $94, $95, $07, $06, $B7, $0B, $73, $42, $C2, $D4, $CD, $4F, $90, $5F, $53, $D8, $D3, $2D, $AC, $A8, $38, $35, $B8, $5B, $9A, $11, $E8, $54, $FB, $2F, $FA
	dc.b	$3D, $7D, $90, $F9, $59, $50, $70, $6B, $70, $B7, $34, $23, $A9, $E9, $50, $7B, $23, $D7, $95, $B9, $12, $A0, $E0, $D6, $E1, $6E, $68, $4F, $F2, $E4, $7F, $D8
	dc.b	$35, $4E, $59, $27, $29, $2A, $0E, $0D, $6E, $16, $E6, $84, $FA, $CC, $76, $1E, $CF, $54, $D5, $93, $44, $A8, $38, $35, $B8, $5B, $9A, $11, $ED, $E5, $B2, $D6
	dc.b	$63, $FD, $01, $53, $96, $49, $CA, $4A, $83, $83, $5B, $85, $B9, $A1, $1E, $7F, $BB, $7F, $B0, $E3, $95, $CD, $3F, $D0, $6A, $86, $A8, $77, $0B, $72, $C2, $2B
	dc.b	$AD, $FA, $63, $54, $1F, $A6, $40, $87, $1E, $97, $3F, $DB, $3D, $D1, $FA, $63, $74, $7E, $D8, $3A, $3F, $8D, $D3, $FE, $CE, $B7, $E9, $AD, $FA, $6B, $7E, $9A
	dc.b	$DF, $A6, $B7, $A6, $3D, $30, $E2, $B7, $A4, $9C, $44, $44, $44, $EF, $F3, $FF, $D8, $7F, $98, $FF, $AD, $97, $ED, $88, $8B, $FE, $FF, $F6, $FF, $B7, $FD, $BF
	dc.b	$EC, $44, $5F, $F6, $FF, $30, $FE, $B1, $FE, $DB, $27, $11, $11, $1B, $6F, $66, $3D, $DE, $D9, $6E, $1B, $1B, $BB, $10, $1D, $94, $3D, $C7, $16, $74, $61, $B7
	dc.b	$B3, $1E, $EF, $EA, $3F, $BC, $E1, $FD, $E0, $EE, $F6, $EF, $6E, $F8, $6D, $EC, $C7, $B9, $F5, $EB, $D4, $88, $9E, $DB, $D9, $8F, $73, $FE, $73, $B7, $1F, $BE
	dc.b	$74, $0D, $FB, $BB, $A0, $87, $FE, $DF, $2F, $16, $F1, $66, $DE, $CC, $7B, $BD, $B0, $C7, $FC, $E7, $1F, $F3, $83, $87, $3B, $3B, $9E, $39, $E1, $B7, $B3, $1E
	dc.b	$E4, $7D, $7A, $91, $13, $DB, $7B, $31, $EE, $5B, $8F, $DF, $38, $F7, $EE, $E8, $38, $7F, $41, $19, $78, $B7, $4B, $77, $B7, $7C, $BF, $7C, $F6, $1D, $DE, $E1
	dc.b	$DF, $27, $77, $B7, $7B, $77, $2B, $73, $75, $98, $45, $98, $45, $98, $45, $98, $45, $98, $45, $98, $41, $65, $FD, $E7, $06, $B4, $06, $1F, $C7, $0C, $22, $CC
	dc.b	$22, $CC, $1D, $DD, $C1, $AD, $05, $CD, $CF, $EE, $21, $EC, $18, $43, $D8, $30, $87, $B0, $61, $0F, $60, $C2, $1E, $C1, $84, $3D, $88, $3B, $FB, $CE, $86, $B7
	dc.b	$46, $1F, $D7, $61, $19, $43, $08, $CA, $18, $3B, $BB, $A1, $AD, $04, $39, $BA, $CC, $22, $CC, $22, $CC, $22, $CC, $22, $CC, $22, $CC, $22, $5E, $2D, $E2, $DE
	dc.b	$37, $CB, $C0, $DD, $FE, $04, $3F, $F6, $F9, $78, $B7, $8B, $73, $B7, $7C, $98, $73, $7B, $1F, $37, $B8, $F9, $E4, $E1, $CE, $CE, $E7, $8E, $78, $E9, $8E, $9B
	dc.b	$DB, $A0, $DF, $2E, $87, $BB, $FA, $1C, $3F, $A0, $8C, $BC, $5B, $A5, $98, $45, $98, $45, $98, $45, $98, $45, $98, $3B, $B9, $B4, $9D, $FC, $72, $0C, $3F, $8E
	dc.b	$18, $45, $98, $45, $98, $46, $4E, $60, $EE, $EE, $86, $B7, $47, $7F, $5C, $9E, $E0, $CF, $70, $70, $61, $01, $C6, $C7, $06, $E7, $C3, $DC, $F8, $C9, $C2, $2C
	dc.b	$EE, $84, $70, $C3, $F8, $E1, $84, $59, $84, $59, $84, $59, $83, $BB, $B8, $35, $A0, $3B, $FA, $E4, $18, $45, $98, $45, $98, $45, $98, $45, $98, $3B, $BB, $83
	dc.b	$5A, $03, $BF, $AE, $44, $45, $8E, $78, $6C, $34, $9A, $4C, $44, $47, $D4, $88, $88, $88, $99, $D2, $71, $3A, $4E, $93, $88, $88, $88, $88, $B2, $62, $22, $B7
	dc.b	$77, $F3, $CB, $9D, $98, $88, $8A, $5D, $CB, $99, $73, $27, $11, $11, $11, $11, $38, $B2, $6C, $34, $9A, $4D, $86, $93, $49, $A4, $C4, $44, $52, $8C, $40, $75
	dc.b	$A0, $3A, $D0, $1D, $67, $13, $A4, $E9, $38, $9D, $27, $49, $D2, $71, $06, $93, $61, $A4, $D8, $69, $34, $9A, $4C, $44, $44, $3A, $5A, $31, $12, $8C, $41, $16
	dc.b	$5F, $F7, $22, $22, $22, $22, $F4, $27, $13, $49, $89, $B2, $74, $9C, $4E, $93, $8A, $25, $12, $89, $46, $1A, $4D, $26, $93, $61, $A4, $D2, $6C, $36, $20, $43
	dc.b	$DC, $F8, $7B, $9F, $0F, $73, $E1, $EE, $38, $B3, $84, $59, $C2, $2C, $E2, $75, $9D, $27, $49, $D2, $71, $3A, $4E, $93, $89, $DF, $90, $B7, $E8, $31, $E7, $2F
	dc.b	$37, $F9, $91, $1F, $9C, $BC, $ED, $FA, $0C, $9A, $4D, $26, $93, $49, $A4, $D2, $69, $36, $22, $51, $28, $94, $4A, $25, $12, $89, $41, $34, $9A, $5F, $B7, $22
	dc.b	$22, $27, $C4, $A3, $2F, $DB, $91, $11, $11, $11, $13, $DA, $4D, $26, $C3, $49, $83, $62, $1B, $0E, $62, $22, $22, $2C, $3B, $FD, $C4, $44, $44, $44, $E9, $3A
	dc.b	$4E, $22, $22, $22, $22, $74, $9D, $27, $13, $A4, $E2, $36, $93, $49, $A4, $D2, $69, $34, $98, $9D, $68, $94, $4A, $25, $04, $E9, $38, $9C, $5E, $99, $7E, $FB
	dc.b	$26, $93, $49, $B0, $D2, $6C, $35, $B9, $E3, $BC, $4A, $25, $12, $89, $44, $A2, $51, $88, $27, $B4, $9B, $0D, $26, $93, $49, $B0, $D2, $77, $8B, $78, $B4, $62
	dc.b	$25, $12, $89, $46, $23, $2F, $DB, $E5, $FF, $72, $22, $22, $22, $87, $49, $C4, $E9, $3A, $4E, $93, $89, $D2, $77, $ED, $C3, $A4, $E2, $74, $9D, $27, $13, $A4
	dc.b	$EC, $BF, $6E, $41, $C4, $E9, $38, $9C, $44, $44, $44, $44, $E2, $F4, $2E, $85, $E3, $A9, $11, $11, $17, $FD, $C8, $88, $A5, $16, $E9, $97, $47, $F8, $94, $62
	dc.b	$25, $18, $82, $22, $22, $1D, $ED, $DF, $2F, $DF, $3D, $87, $37, $78, $70, $67, $7E, $DC, $7A, $7F, $1C, $DC, $71, $67, $41, $11, $3F, $FE, $FF, $F7, $FF, $B9
	dc.b	$B8, $E2, $CE, $8C, $78, $B7, $8B, $78, $DC, $7F, $5C, $6F, $FD, $71, $FF, $77, $B8, $E2, $CE, $8C, $73, $B7, $7C, $98, $73, $7B, $1B, $3B, $C3, $8D, $DF, $B7
	dc.b	$0E, $CA, $1E, $E3, $8B, $3A, $08, $89, $FF, $F7, $FF, $B8, $76, $50, $F7, $1C, $59, $D1, $8E, $98, $E9, $BD, $BA, $0D, $C7, $F1, $CF, $7F, $E3, $9C, $07, $65
	dc.b	$0F, $71, $C5, $9D, $18, $6D, $EC, $C7, $BB, $DB, $2D, $C3, $1F, $F3, $9C, $7F, $CE, $0E, $1C, $EC, $EE, $78, $E7, $86, $DE, $CC, $7B, $BD, $B2, $DC, $75, $EA
	dc.b	$44, $4F, $6D, $EC, $C7, $BB, $DB, $2D, $C3, $63, $77, $3F, $F7, $C1, $C6, $D6, $70, $6C, $39, $B0, $DB, $D9, $8F, $77, $B6, $5B, $86, $C6, $FD, $48, $89, $ED
	dc.b	$BD, $98, $F7, $7B, $65, $B8, $6C, $6F, $DD, $CF, $87, $C1, $C6, $50, $22, $DD, $1F, $F9, $0B, $7E, $83, $1E, $72, $F3, $22, $7F, $99, $11, $FE, $83, $1F, $90
	dc.b	$C7, $9E, $5F, $B0, $C7, $E4, $31, $E7, $97, $EC, $25, $E7, $2F, $37, $F3, $B3, $06, $C9, $8D, $9E, $CF, $67, $B9, $ED, $93, $8D, $AC, $E0, $D8, $73, $62, $37
	dc.b	$C4, $0D, $ED, $07, $BE, $50, $FD, $DF, $0F, $87, $C1, $C6, $50, $22, $DD, $08, $88, $8D, $A4, $D2, $69, $34, $98, $88, $BF, $9C, $5C, $C9, $88, $88, $88, $88
	dc.b	$9C, $4E, $2B, $34, $9A, $4D, $26, $93, $49, $A4, $D2, $62, $2C, $74, $C4, $4A, $25, $12, $89, $41, $10, $E8, $4E, $27, $13, $49, $B0, $D8, $74, $9C, $51, $28
	dc.b	$94, $4A, $25, $12, $82, $22, $CB, $D0, $9C, $4E, $93, $89, $9F, $E7, $2F, $39, $7E, $81, $FF, $B0, $CB, $F6, $0F, $FD, $86, $5F, $B0, $7F, $F0, $1F, $FB, $0C
	dc.b	$44, $9C, $C4, $44, $44, $45, $D4, $88, $88, $88, $DA, $DC, $C8, $88, $88, $88, $46, $22, $51, $88, $C4, $49, $C4, $E2, $71, $3E, $25, $12, $89, $44, $A2, $51
	dc.b	$28, $94, $4B, $A6, $22, $51, $28, $94, $4A, $25, $12, $81, $D0, $9C, $4E, $26, $93, $49, $B0, $D8, $69, $38, $A2, $51, $28, $94, $4A, $25, $12, $82, $69, $34
	dc.b	$9A, $4D, $86, $93, $61, $AD, $CF, $1F, $90, $7F, $F0, $1F, $FB, $0C, $BF, $60, $FF, $E0, $3F, $F6, $19, $79, $91, $1F, $9C, $9A, $4D, $26, $93, $49, $A4, $D2
	dc.b	$69, $3B, $0E, $62, $22, $22, $2F, $FB, $F3, $22, $22, $2B, $45, $BA, $0F, $E3, $E2, $31, $12, $8C, $46, $20, $88, $88, $88, $88, $AD, $D3, $2E, $87, $FB, $7C
	dc.b	$44, $A3, $11, $28, $C4, $11, $11, $1F, $3B, $30, $6C, $98, $D9, $EC, $F7, $78, $76, $20, $3B, $28, $7B, $8E, $2C, $E8, $22, $27, $FF, $DD, $D8, $80, $EC, $A1
	dc.b	$EE, $38, $B3, $A3, $11, $BE, $20, $6F, $68, $3D, $C7, $ED, $DF, $BB, $B1, $01, $D9, $43, $DC, $71, $67, $43, $C0, $00
Endgame_tilemap_b: ; Packed tilemap: endgame/race-result overlay (used with Draw_packed_tilemap_to_vdp in Endgame_sequence_init)
	dc.b	$C8, $0A, $FB, $07, $C0, $19, $0A, $1C, $1C, $20, $18, $1B, $0D, $FA, $12, $17, $0C, $18, $1B, $1B, $0E, $0C, $1D, $2D, $2D, $FF
Endgame_tilemap_a: ; Packed tilemap: endgame/race-result frame (used with Draw_packed_tilemap_to_vdp in Endgame_sequence_init)
	dc.b	$C1, $8C, $FB, $27, $C0, $0E, $17, $1D, $0E, $1B, $FA, $1D, $11, $0E, $FA, $19, $0A, $1C, $1C, $20, $18, $1B, $0D, $FF
Name_entry_tilemap_a: ; Packed tilemap: save name-entry screen primary layout (used with Draw_packed_tilemap_to_vdp in Save_name_entry_init)
	dc.b	$C7, $8A, $FB, $27, $C0, $2C, $2C, $2C, $2C, $2C, $FA, $19, $0A, $1C, $1C, $20, $18, $1B, $0D, $FA, $2C, $2C, $2C, $2C, $2C, $FC, $FC, $FC, $FC, $FC, $FC, $2C
	dc.b	$2C, $2C, $2C, $2C, $2C, $2C, $2C, $2C, $2C, $2C, $2C, $2C, $2C, $2C, $2C, $2C, $2C, $2C, $2C, $FF
Name_entry_tilemap_b: ; Packed tilemap: save name-entry screen secondary layout (border/cursor tiles)
	dc.b	$CF, $26, $FB, $20, $64, $37, $38, $38, $38, $38, $38, $38, $38, $39, $FD, $3A, $32, $32, $10, $0A, $16, $0E, $32, $3B, $FD, $3A, $32, $32, $32, $32, $32, $32
	dc.b	$32, $3B, $FD, $3A, $32, $32, $0E, $17, $0D, $32, $32, $3B, $FD, $3C, $3D, $3D, $3D, $3D, $3D, $3D, $3D, $3E, $FF, $00, $00, $00, $E8, $0A, $20, $01, $FF, $F4
Endgame_tiles_a: ; Compressed tiles for endgame/name-entry screen (decompressed to VDP VRAM $40200000)
	dc.b	$80, $09, $80, $15, $1D, $24, $0C, $35, $1B, $47, $7D, $63, $02, $72, $00, $81, $04, $06, $27, $7C, $75, $1C, $83, $04, $07, $88, $05, $1A, $14, $0A, $89, $14
	dc.b	$08, $8A, $04, $09, $15, $1E, $8B, $14, $0B, $FF, $03, $2A, $27, $1F, $51, $3F, $7E, $63, $77, $F2, $26, $38, $98, $4E, $26, $13, $89, $8F, $C5, $FE, $AB, $35
	dc.b	$F8, $BF, $D5, $7F, $43, $F2, $3F, $7E, $00, $4D, $D4, $7A, $EA, $27, $9C, $00, $00, $00, $8A, $BF, $45, $5F, $B9, $C0, $09, $BD, $6E, $6F, $EF, $F4, $7B, $F3
	dc.b	$F0, $0D, $FD, $07, $13, $09, $C4, $C2, $71, $31, $B8, $D3, $EE, $2B, $7F, $C1, $CF, $E8, $9D, $00
Endgame_tiles_b:
	dc.b	$00, $47, $80, $03, $01, $14, $0A, $23, $03, $35, $19, $45, $1A, $54, $0B, $67, $72, $73, $04, $81, $15, $18, $37, $78, $82, $13, $00, $26, $36, $38, $F6, $46
	dc.b	$3A, $57, $7A, $67, $76, $83, $08, $F3, $13, $02, $27, $73, $47, $77, $56, $37, $84, $16, $38, $86, $08, $F7, $18, $F2, $FF, $AF, $D0, $E7, $F0, $35, $8A, $C3
	dc.b	$C1, $C3, $C1, $C3, $C5, $62, $BF, $03, $9F, $D0, $CB, $C6, $BF, $43, $78, $BC, $5E, $2F, $19, $FE, $8C, $AF, $E0, $D6, $1E, $35, $FA, $17, $E1, $F8, $7F, $A1
	dc.b	$D7, $F8, $65, $7F, $47, $58, $D6, $35, $E3, $96, $0E, $1E, $2B, $F8, $33, $5F, $A1, $CF, $87, $83, $8A, $C5, $62, $BF, $C3, $AC, $5E, $25, $7F, $46, $B1, $7F
	dc.b	$D1, $E5, $8B, $C1, $C3, $C5, $7F, $06, $67, $C3, $C6, $B1, $7F, $D1, $AC, $3C, $1C, $3C, $57, $F0, $65, $7F, $84, $E1, $E3, $58, $D6, $35, $8B, $C5, $E2, $6B
	dc.b	$C3, $C3, $FC, $0D, $7E, $86, $BF, $02, $FC, $3F, $C0, $D7, $83, $F8, $1C, $E2, $BF, $83, $1F, $F0, $6B, $0F, $07, $0F, $15, $FD, $1B, $C6, $B0, $FC, $4D, $6D
	dc.b	$90, $45, $06, $08, $60, $F6, $21, $82, $18, $87, $D5, $06, $08, $60, $FA, $A0, $C1, $0C, $1F, $53, $3E, $CC, $50, $22, $C5, $8E, $42, $83, $F6, $95, $D3, $14
	dc.b	$28, $30, $43, $04, $30, $45, $0A, $EA, $3E, $C4, $58, $BE, $98, $B1, $7D, $A1, $EC, $45, $8B, $E9, $8B, $16, $24, $EA, $86, $85, $8A, $D8, $86, $28, $50, $7D
	dc.b	$42, $18, $21, $82, $18, $3D, $88, $60, $86, $08, $62, $57, $AC, $8B, $16, $2C, $58, $CF, $A9, $62, $C5, $8B, $16, $08, $62, $BA, $94, $18, $22, $85, $02, $1F
	dc.b	$B6, $7A, $60, $ED, $42, $B6, $84, $58, $B1, $62, $C5, $8B, $ED, $08, $60, $EC, $76, $3D, $8F, $62, $0F, $E0, $88, $21, $82, $18, $84, $30, $76, $A0, $7D, $88
	dc.b	$3D, $88, $3E, $C4, $56, $C4, $31, $2B, $AA, $0C, $10, $C1, $0C, $10, $C1, $0C, $57, $52, $BD, $50, $60, $86, $08, $60, $FA, $A1, $62, $72, $EA, $83, $04, $30
	dc.b	$43, $04, $1F, $62, $28, $3D, $88, $87, $D5, $06, $08, $60, $8A, $D8, $F4, $C1, $DA, $85, $6D, $2B, $D9, $8A, $14, $39, $75, $C8, $10, $C5, $75, $1F, $AC, $8B
	dc.b	$16, $2C, $58, $B1, $18, $60, $86, $08, $60, $86, $08, $60, $86, $2B, $A9, $41, $82, $18, $21, $83, $B1, $DA, $BA, $CE, $D7, $F8, $29, $90, $C1, $0C, $10, $7F
	dc.b	$04, $41, $EC, $7B, $50, $21, $FE, $09, $FE, $0A, $50, $60, $EC, $76, $AE, $B3, $B6, $7A, $AD, $8E, $C4, $31, $28, $50, $A1, $42, $85, $07, $ED, $A1, $62, $C4
	dc.b	$7D, $B5, $B6, $76, $CE, $D9, $DB, $3B, $6B, $B4, $92, $BB, $F2, $55, $B9, $4D, $56, $F0, $AB, $57, $BD, $26, $8A, $68, $A6, $8E, $F2, $47, $DE, $93, $45, $5A
	dc.b	$6A, $BB, $CE, $4A, $D5, $6E, $53, $45, $34, $53, $55, $BC, $92, $BB, $D2, $68, $FF, $8C, $AE, $5D, $E6, $B9, $E5, $5A, $CE, $F9, $56, $AD, $49, $35, $B9, $4D
	dc.b	$14, $D5, $6F, $6A, $BB, $D2, $B5, $7B, $D2, $68, $A6, $8A, $68, $A6, $A6, $54, $D7, $3B, $56, $AD, $67, $79, $6A, $6B, $9D, $AB, $56, $8A, $6A, $BB, $D2, $B5
	dc.b	$69, $A2, $A9, $57, $76, $8F, $3A, $55, $CE, $3E, $76, $AD, $5A, $B5, $6B, $3B, $C9, $0E, $F5, $E6, $51, $47, $CC, $A2, $8F, $99, $45, $1F, $32, $8A, $92, $1D
	dc.b	$E9, $34, $53, $45, $34, $53, $52, $4A, $EF, $49, $A2, $9A, $29, $AA, $EF, $24, $AD, $E9, $34, $53, $47, $7A, $56, $A4, $E5, $B9, $4D, $14, $D5, $6F, $6A, $D4
	dc.b	$87, $7A, $4D, $15, $6A, $D4, $93, $97, $7A, $E7, $7D, $EF, $99, $DE, $65, $5A, $CE, $F9, $56, $AD, $72, $E7, $24, $A4, $D1, $4D, $14, $D1, $4D, $56, $F2, $42
	dc.b	$9A, $29, $AA, $45, $67, $9D, $F9, $C9, $32, $9A, $28, $F9, $94, $7F, $C6, $79, $9E, $75, $E6, $FC, $E4, $94, $9A, $A4, $56, $79, $E5, $15, $49, $A9, $21, $4D
	dc.b	$14, $D5, $22, $B3, $CF, $4B, $4A, $4D, $7F, $8F, $3C, $F3, $CF, $3C, $F3, $FE, $39, $33, $C5, $F1, $9F, $EA, $67, $8B, $E2, $49, $26, $7F, $89, $24, $93, $97
	dc.b	$1A, $E3, $5C, $6B, $8D, $71, $AE, $24, $AE, $35, $FA, $4D, $7E, $93, $5C, $4D, $71, $7C, $4D, $7F, $12, $B8, $7C, $5F, $19, $FD, $26, $78, $97, $C4, $9C, $BD
	dc.b	$EF, $CB, $5F, $D6, $AF, $EB, $3F, $2E, $5E, $F2, $4F, $7E, $5E, $4F, $FA, $D5, $FD, $6D, $79, $5F, $BC, $7F, $B6, $CF, $95, $FE, $DB, $3E, $55, $FA, $63, $FD
	dc.b	$63, $EF, $9F, $23, $EF, $9F, $23, $EF, $9F, $D3, $1F, $F2, $9F, $F2, $C9, $24, $84, $00
	include	"src/team_messages_data.asm"
	include	"src/crash_gauge_data.asm"
;Startup_tileset_data
	include	"src/car_sprite_blobs.asm"
	include	"src/hud_and_minimap_data.asm"
	include	"src/screen_art_data.asm"
	include	"src/track_bg_data.asm"
	include	"src/road_and_track_data.asm"
	include	"src/audio_engine.asm"
EndOfRom:
	END
