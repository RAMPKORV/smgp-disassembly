Race_preview_vblank_handler_2:
	JSR	Upload_h32_tilemap_buffer_to_vram
	JSR	Update_input_bitset
	JSR	Upload_palette_buffer_to_cram
	MOVE.w	#$977F, D7
	MOVE.l	#$96CE95A0, D6
	MOVE.l	#$940193C0, D5
	MOVE.l	#$68000083, Vdp_dma_setup.w
	JSR	Send_D567_to_VDP
	JMP	Flush_pending_dma_transfers
;Initialize_results_screen
Initialize_results_screen:
	JSR	Fade_palette_to_black
	JSR	Initialize_h32_vdp_state
	MOVE.w	#$8200, VDP_control_port
	MOVE.w	#$9003, VDP_control_port
	MOVE.w	#$9200, VDP_control_port
	MOVE.l	#$941F93FF, D6
	MOVE.l	#$40000080, D7
	JSR	Start_vdp_dma_fill
	LEA	Screen_scroll_table_buf.w, A1
	MOVE.w	#$00E0, D0
Initialize_results_screen_Clear_loop:
	CLR.l	(A1)+
	DBF	D0, Initialize_results_screen_Clear_loop
	MOVE.l	#$5C000000, VDP_control_port
	LEA	Result_screen_tiles_a, A0
	JSR	Decompress_to_vdp
	MOVE.l	#$45800001, VDP_control_port
	LEA	Result_screen_tiles_b, A0
	JSR	Decompress_to_vdp
	MOVE.l	#$63A00001, VDP_control_port
	LEA	Race_common_tiles, A0
	JSR	Decompress_to_vdp
	MOVE.w	#5, D0
	LEA	Result_decomp_list, A1
Initialize_results_screen_Decomp_loop:
	MOVEM.w	D0, -(A7)
	MOVE.l	(A1)+, D7
	MOVEA.l	(A1)+, A0
	MOVE.w	(A1)+, D0
	MOVE.w	(A1)+, D6
	MOVE.w	(A1)+, D5
	MOVEM.l	A1, -(A7)
	JSR	Decompress_tilemap_to_vdp_128_cell_rows
	MOVEM.l	(A7)+, A1
	MOVEM.w	(A7)+, D0
	DBF	D0, Initialize_results_screen_Decomp_loop
	MOVE.w	#7, D0
	LEA	Result_tilemap_list, A1
Initialize_results_screen_Tilemap_loop:
	MOVEM.w	D0, -(A7)
	MOVE.l	(A1)+, D7
	MOVEA.l	(A1)+, A6
	MOVE.w	#1, D6
	MOVE.w	#5, D5
	MOVEM.l	A1, -(A7)
	JSR	Draw_tilemap_buffer_to_vdp_128_cell_rows
	MOVEM.l	(A7)+, A1
	MOVEM.w	(A7)+, D0
	DBF	D0, Initialize_results_screen_Tilemap_loop
	MOVE.w	#$0080, D0
	MOVE.l	#$5A000003, VDP_control_port
Initialize_results_screen_Fill_loop:
	MOVE.l	#$622A622B, VDP_data_port
	DBF	D0, Initialize_results_screen_Fill_loop
	MOVE.w	#$0014, D0
	MOVE.l	#$59000003, D7
Initialize_results_screen_Row_loop:
	MOVEM.l	D7/D0, -(A7)
Initialize_results_screen_Row_inner:
	ADDI.l	#$000C0000, D7
	DBF	D0, Initialize_results_screen_Row_inner
	SUBI.l	#$000C0000, D7
	MOVE.l	D7, VDP_control_port
	MOVE.w	#$6229, VDP_data_port
	MOVEM.l	(A7)+, D0/D7
	DBF	D0, Initialize_results_screen_Row_loop
	MOVE.w	#$004B, Screen_state_byte_1.w
	MOVE.l	#$00050000, Screen_timer.w
	LEA	Result_sprite_anim_data, A6
	JSR	Copy_word_run_from_stream
	CLR.l	D0
	MOVE.b	Player_team.w, D0
	ANDI.b	#$0F, D0 ; isolate the player's team number
	MULS.w	#$0038, D0
	ADDI.w	#$000A, D0
	LEA	Team_palette_data, A1
	ADDA.l	D0, A1
	LEA	(Palette_buffer+$C).w, A2
	MOVE.w	#3, D0
Initialize_results_screen_Palette_loop:
	MOVE.w	(A1)+, (A2)+
	DBF	D0, Initialize_results_screen_Palette_loop
	LEA	Team_palette_copy_buf.w, A1
	LEA	(Palette_buffer+$2C).w, A2
	MOVE.w	#3, D0
Initialize_results_screen_Palette2_loop:
	MOVE.w	(A1)+, (A2)+
	DBF	D0, Initialize_results_screen_Palette2_loop
	MOVE.w	(Palette_buffer+$C).w, (Palette_buffer+$78).w
	MOVE.w	(Palette_buffer+$E).w, (Palette_buffer+$7C).w
	MOVE.w	(Palette_buffer+$78).w, (Palette_buffer+$18).w
	MOVE.w	(Palette_buffer+$7C).w, (Palette_buffer+$1C).w
	MOVE.l	#Race_preview_vblank_handler_2, Vblank_callback.w
	CLR.l	Saved_frame_callback.w
	BCLR.b	#4, Player_state_flags.w
	RTS
Init_race_result_scores:
	LEA	Tire_stat_max_base.w, A1
	LEA	Init_result_score_data, A2
	BSR.b	Format_result_score_row
	MOVE.b	#$FF, Race_event_flags.w
	RTS
Update_race_result_scores:
	LEA	Tire_steering_durability_acc.w, A1
	LEA	Init_result_score_data_2, A2
	ORI	#$0700, SR
	BSR.b	Format_result_score_row
	ANDI	#$F8FF, SR
	RTS
Format_result_score_row:
	MOVE.w	#4, D0
Format_result_score_row_Loop:
	MOVEM.w	D0, -(A7)
	MOVE.w	(A1)+, D0
	MOVE.w	(A2)+, D7
	MOVEM.l	A2/A1, -(A7)
	JSR	Binary_to_decimal
	MOVE.w	#$431D, D4
	BSR.b	Write_bcd_digits_to_vdp
	MOVEM.l	(A7)+, A1/A2
	MOVEM.w	(A7)+, D0
	DBF	D0, Format_result_score_row_Loop
	RTS
Write_bcd_digits_to_vdp:
	JSR	Tile_index_to_vdp_command
	MOVE.l	D7, VDP_control_port
	LEA	Digit_scratch_buf.w, A1
	MOVE.w	D1, (A1)
	MOVEQ	#$0000000F, D2
	MOVEQ	#0, D3
	MOVE.b	(A1)+, D0
	BSR.b	Write_bcd_digits_to_vdp_Digit
	MOVE.b	(A1)+, D0
	BSR.b	Write_bcd_digits_to_vdp_Hi
	MOVEQ	#1, D3
Write_bcd_digits_to_vdp_Hi:
	ROR.b	#4, D0
Write_bcd_digits_to_vdp_Digit:
	MOVE.w	D0, D5
	AND.w	D2, D5
	BNE.b	Write_bcd_digits_to_vdp_Nonzero
	TST.w	D3
	BNE.b	Write_bcd_digits_to_vdp_Emit
	MOVE.w	#$434F, D5
	BRA.b	Write_bcd_digits_to_vdp_Write
Write_bcd_digits_to_vdp_Nonzero:
	MOVEQ	#1, D3
Write_bcd_digits_to_vdp_Emit:
	ADD.w	D4, D5
Write_bcd_digits_to_vdp_Write:
	MOVE.w	D5, VDP_data_port
	RTS
	dc.b	$3A, $9E, $51, $C8, $FF, $FC, $4E, $75
