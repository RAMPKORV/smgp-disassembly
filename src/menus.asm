Race_preview_screen_init:
	JSR	Fade_palette_to_black
	JSR	Initialize_h40_vdp_state
	JSR	Clear_main_object_pool
	MOVE.l	#$40000000, VDP_control_port
	LEA	Attract_screen_logo_tiles, A0
	JSR	Decompress_to_vdp
	LEA	Attract_screen_bg_tilemap, A0
	MOVE.w	#$4000, D0
	MOVE.l	#$40000003, D7
	MOVEQ	#$00000027, D6
	MOVEQ	#$0000001B, D5
	JSR	Decompress_tilemap_to_vdp_64_cell_rows
	LEA	Attract_screen_overlay_tilemap, A0
	MOVE.w	#$2384, D0
	JSR	Decompress_tilemap_to_buffer
	LEA	Attract_screen_palette_data, A6
	JSR	Copy_word_run_from_stream
	MOVE.w	#$0095, Screen_timer.w
	MOVEQ	#0, D0
	JSR	Load_streamed_decompression_descriptor
	MOVE.l	#$00001032, Main_object_pool.w
	MOVE.l	#Attract_screen_logo_frame, Frame_callback.w
	MOVE.l	#$00002440, Vblank_callback.w
	ANDI	#$F8FF, SR
	JSR	Wait_for_vblank
	MOVE.w	#1, Vblank_enable.w
	MOVE.w	#$8174, VDP_control_port
	RTS
;$00002440
Attract_screen_logo_vblank_handler:
	JSR	Upload_h40_tilemap_buffer_to_vram
	JSR	Update_input_bitset
	JSR	Upload_palette_buffer_to_cram
	JMP	Continue_streamed_decompression
;$00002458
Attract_screen_frame:
	JSR	Wait_for_vblank
	BTST.b	#KEY_START, Input_click_bitset.w
	BEQ.b	Attract_screen_frame_No_start
	MOVE.w	#9, Selection_count.w
	MOVE.l	#Title_menu, Frame_callback.w
	RTS
Attract_screen_frame_No_start:
	TST.w	Attract_anim_cell_count.w
	BEQ.b	Attract_screen_frame_Tilemap
	MOVEQ	#$0000001F, D7
	LEA	Decomp_code_table.w, A6
Attract_screen_frame_Code_loop:
	TST.w	(A6)
	BMI.b	Attract_screen_frame_Code_next
	MOVE.w	$2(A6), D0
	BPL.b	Attract_screen_frame_Code_pos
	EXT.w	D0
	MOVE.w	D0, $2(A6)
	BRA.b	Attract_screen_frame_Code_next
Attract_screen_frame_Code_pos:
	BSR.w	Attract_anim_cell_update
Attract_screen_frame_Code_next:
	LEA	$8(A6), A6
	DBF	D7, Attract_screen_frame_Code_loop
	LEA	Attract_anim_tile_buf.w, A0
	BRA.w	Upload_words_to_vram
Attract_screen_frame_Tilemap:
	LEA	Tilemap_work_buf.w, A0
	BSR.w	Upload_words_to_vram
	TST.w	Anim_delay.w
	BEQ.b	Attract_screen_frame_No_delay
	SUBQ.w	#1, Anim_delay.w
	BNE.b	Attract_screen_frame_Rts
	MOVE.l	#$00002944, Frame_callback.w
Attract_screen_frame_Rts:
	RTS
Attract_screen_frame_No_delay:
	TST.w	Screen_timer.w
	BNE.b	Attract_screen_frame_Timer
	MOVE.w	Screen_scroll.w, D7
	MOVE.w	Screen_data_ptr.w, D5
	ADDI.w	#$0111, D5
	LEA	(Palette_buffer+$4).w, A1
	MOVEQ	#$0000000D, D2
Attract_screen_frame_Pos_loop:
	MOVE.w	D5, $20(A1)
	MOVE.w	D5, (A1)+
	DBF	D2, Attract_screen_frame_Pos_loop
	MOVE.w	D5, Screen_data_ptr.w
	SUBQ.w	#1, D7
	MOVE.w	D7, Screen_scroll.w
	BPL.b	Attract_screen_frame_Return
	ADDQ.w	#1, Screen_timer.w
	LEA	Attract_anim_slot_buf.w, A1
	MOVE.w	#7, (A1)+
	MOVE.w	#$000A, (A1)+
	MOVE.w	#$000D, Screen_scroll.w
Attract_screen_frame_Return:
	RTS
Attract_screen_frame_Timer:
	BTST.b	#0, Frame_counter.w
	BEQ.b	Attract_screen_frame_Return
	LEA	Attract_anim_slot_buf.w, A1
	LEA	(Palette_buffer+$4).w, A5
	MOVE.w	Screen_scroll.w, D7
	CMPI.w	#6, D7
	BCS.b	Attract_screen_frame_No_adj
	SUBI.w	#$0111, (A5)
	SUBI.w	#$0111, $20(A5)
Attract_screen_frame_No_adj:
	LEA	Attract_car_segment_data(PC), A2
	LEA	Attract_anim_slot_buf.w, A3
	LEA	(Palette_buffer+$8).w, A4
	MOVEQ	#1, D6
Attract_screen_frame_Car_loop:
	MOVE.w	(A3), D5
	SUBQ.w	#1, D5
	MOVE.w	D5, (A3)+
	MOVEA.l	A4, A1
	MOVEQ	#3, D2
Attract_screen_frame_Seg_loop:
	ADDQ.w	#1, D5
	BMI.b	Attract_screen_frame_Seg_skip
	CMPI.w	#8, D5
	BCC.b	Attract_screen_frame_Seg_skip
	MOVE.w	D5, D0
	ADD.w	D0, D0
	MOVE.w	D0, D1
	ADD.w	D0, D0
	ADD.w	D0, D1
	MOVEA.l	A2, A0
	ADDA.w	D1, A0
	MOVE.l	(A0)+, (A1)+
	MOVE.w	(A0)+, (A1)+
	DBF	D2, Attract_screen_frame_Seg_loop
	BRA.b	Attract_screen_frame_Seg_done
Attract_screen_frame_Seg_skip:
	ADDQ.w	#6, A1
	DBF	D2, Attract_screen_frame_Seg_loop
Attract_screen_frame_Seg_done:
	LEA	$20(A4), A4
	DBF	D6, Attract_screen_frame_Car_loop
	SUBQ.w	#1, D7
	MOVE.w	D7, Screen_scroll.w
	BPL.b	Attract_screen_frame_Done
	MOVE.w	#$003C, Anim_delay.w
Attract_screen_frame_Done:
	RTS
	dc.b	$D0, $C0, $32, $D8, $51, $C9, $FF, $FC, $4E, $75
;Startup_screen_init
Startup_screen_init:
	JSR	Halt_audio_sequence
	JSR	Fade_palette_to_black
	JSR	Initialize_h40_vdp_state
	MOVE.w	#$8238, VDP_control_port
	MOVE.w	#$8B03, VDP_control_port
	MOVE.w	#$9011, VDP_control_port
	MOVE.w	#$9280, VDP_control_port
	LEA	Startup_screen_tiles, A0
	LEA	Tilemap_work_buf.w, A4
	JSR	Decompress_to_ram
	MOVE.w	#$0187, D2
	LEA	Attract_anim_tile_buf.w, A0
Startup_screen_init_Clear_loop:
	CLR.l	(A0)+
	DBF	D2, Startup_screen_init_Clear_loop
	LEA	Attract_anim_tile_buf.w, A0
	BSR.w	Upload_words_to_vram
	MOVEQ	#1, D4
	MOVE.l	#$00800000, D0
	MOVE.l	#$661C0003, D1
	MOVEQ	#1, D5
Startup_screen_init_Row_loop:
	MOVEQ	#1, D3
Startup_screen_init_Half_loop:
	MOVE.l	D1, VDP_control_port
	MOVEQ	#$0000000B, D2
Startup_screen_init_Tile_loop:
	MOVE.w	D4, VDP_data_port
	ADDQ.w	#1, D4
	DBF	D2, Startup_screen_init_Tile_loop
	ADD.l	D0, D1
	DBF	D3, Startup_screen_init_Half_loop
	ORI.w	#$2000, D4
	DBF	D5, Startup_screen_init_Row_loop
	LEA	Palette_buffer.w, A1
	MOVE.l	#$00000EEE, D1
	MOVEQ	#3, D3
Startup_screen_init_Pal_loop:
	MOVE.l	D1, (A1)+
	MOVEQ	#6, D2
Startup_screen_init_Zero_loop:
	CLR.l	(A1)+
	DBF	D2, Startup_screen_init_Zero_loop
	DBF	D3, Startup_screen_init_Pal_loop
	MOVE.w	#1, Attract_anim_cell_count.w
	LEA	Decomp_code_table_init(PC), A0
	LEA	Decomp_code_table.w, A1
	MOVE.l	(A0)+, (A1)+
	MOVE.l	(A0)+, (A1)+
	MOVEQ	#-1, D1
	MOVEQ	#$0000001E, D2
Startup_screen_init_Code_loop:
	MOVE.w	D1, (A1)
	LEA	$8(A1), A1
	DBF	D2, Startup_screen_init_Code_loop
	MOVE.w	#$000D, Screen_scroll.w
	CLR.w	Track_index.w
	CLR.b	Title_menu_flags.w
	CLR.w	Title_menu_state.w
	MOVE.l	#Attract_screen_frame, Frame_callback.w
	MOVE.l	#$000003D8, Vblank_callback.w
	ANDI	#$F8FF, SR
	JSR	Wait_for_vblank
	JSR	Wait_for_vblank
	MOVE.w	#1, Vblank_enable.w
	MOVE.w	#$8174, VDP_control_port
	RTS

;Upload_words_to_vram
Upload_words_to_vram:
	MOVEA.l	#VDP_data_port, A1
	MOVE.w	#$030F, D1
	MOVE.l	#$40000000, $4(A1)
Upload_words_to_vram_Loop:
	MOVE.w	(A0)+, (A1)
	DBF	D1, Upload_words_to_vram_Loop
	RTS
Attract_anim_cell_update:
	CLR.b	Attract_anim_restore_flag.w
	MOVE.w	$6(A6), D5
	ADDQ.w	#4, D5
	ANDI.w	#$000E, D5
	MOVEQ	#4, D6
	BRA.b	Attract_anim_cell_update_Scan
Attract_anim_cell_update_Loop:
	DBF	D6, Attract_anim_cell_update_Step
	BCLR.b	#7, Attract_anim_restore_flag.w
	BEQ.b	Attract_anim_cell_update_Clear
	LEA	Attract_anim_restore_buf.w, A0
	MOVEA.l	A6, A1
	MOVE.l	(A0)+, (A1)+
	MOVE.w	(A0)+, (A1)+
	RTS
Attract_anim_cell_update_Clear:
	SUBQ.w	#1, Attract_anim_cell_count.w
	MOVE.w	#$FFFF, (A6)
	RTS
Attract_anim_cell_update_Step:
	SUBQ.w	#2, D5
	BCC.b	Attract_anim_cell_update_Scan
	MOVE.w	#$000E, D5
Attract_anim_cell_update_Scan:
	BSR.w	Attract_anim_cell_read
	SWAP	D5
	SWAP	D6
	SWAP	D7
	MOVEQ	#1, D0
	MOVEQ	#$0000000F, D1
	MOVE.w	D2, D6
	LSR.w	#1, D6
	BCS.b	Attract_anim_cell_update_Right
	MOVEQ	#$00000010, D0
	MOVEQ	#-$00000010, D1
Attract_anim_cell_update_Right:
	MOVE.w	D0, D5
	MOVE.w	D1, D7
	MOVE.w	D3, D0
	LSL.w	#2, D0
	ADD.w	D0, D6
	ADD.w	D4, D6
	LEA	Tilemap_work_buf.w, A0
	MOVE.b	(A0,D6.w), D0
	AND.w	D7, D0
	CMP.b	D5, D0
	BNE.b	Attract_anim_cell_update_No_match
	LEA	Attract_anim_tile_buf.w, A1
	ADDA.w	D6, A1
	MOVE.b	(A1), D0
	AND.w	D7, D0
	CMP.w	D5, D0
	BEQ.b	Attract_anim_cell_update_No_match
	OR.b	D5, (A1)
	BSET.b	#7, Attract_anim_restore_flag.w
	BNE.b	Attract_anim_cell_update_Queue
	SWAP	D5
	MOVE.w	D5, $6(A6)
	LEA	Attract_anim_restore_buf.w, A1
	MOVE.w	D2, (A1)+
	MOVE.w	D3, (A1)+
	MOVE.w	D4, (A1)+
	BRA.b	Attract_anim_cell_update_Store
Attract_anim_cell_update_Queue:
	LEA	Attract_anim_queue_buf.w, A1
	ADDQ.w	#1, Attract_anim_cell_count.w
Attract_anim_cell_update_Queue_loop:
	LEA	$8(A1), A1
	TST.w	(A1)
	BPL.b	Attract_anim_cell_update_Queue_loop
	MOVE.w	D2, (A1)+
	ORI.w	#$FF00, D3
	MOVE.w	D3, (A1)+
	MOVE.w	D4, (A1)+
	SWAP	D5
	MOVE.w	D5, (A1)+
	SWAP	D5
Attract_anim_cell_update_No_match:
	SWAP	D5
Attract_anim_cell_update_Store:
	SWAP	D6
	SWAP	D7
	BRA.w	Attract_anim_cell_update_Loop
Attract_anim_cell_read:
	MOVE.w	$0(A6), D2
	MOVE.w	$2(A6), D3
	MOVE.w	$4(A6), D4
	JMP	Attract_anim_cell_dispatch(PC,D5.w)
Attract_anim_cell_dispatch:
	BRA.b	Attract_anim_cell_col_next
	BRA.b	Attract_anim_cell_col_row_next
	BRA.b	Attract_anim_cell_row_next
	BRA.b	Attract_anim_cell_col_prev_row_next
	BRA.b	Attract_anim_cell_col_prev_only
	BRA.b	Attract_anim_cell_col_prev
	BRA.b	Attract_anim_cell_row_prev
	BSR.b	Menu_cursor_col_next
	BRA.b	Attract_anim_cell_row_prev
Attract_anim_cell_col_next:
	BRA.b	Menu_cursor_col_next
Attract_anim_cell_col_row_next:
	BSR.b	Menu_cursor_col_next
	BRA.b	Menu_cursor_row_next
Attract_anim_cell_row_next:
	BRA.b	Menu_cursor_row_next
Attract_anim_cell_col_prev_row_next:
	BSR.b	Menu_cursor_col_prev
	BRA.b	Menu_cursor_row_next
Attract_anim_cell_col_prev_only:
	BRA.b	Menu_cursor_col_prev
Attract_anim_cell_col_prev:
	BSR.b	Menu_cursor_col_prev
Attract_anim_cell_row_prev:
	SUBQ.w	#1, D3
	BCC.b	Attract_anim_cell_row_prev_rts
	MOVEQ	#7, D3
	SUBI.w	#$0180, D4
Attract_anim_cell_row_prev_rts:
	RTS
;Menu_cursor_col_next
Menu_cursor_col_next:
	ADDQ.w	#1, D2
	CMPI.w	#8, D2
	BCS.b	Menu_cursor_col_next_Rts
	MOVEQ	#0, D2
	ADDI.w	#$0020, D4
Menu_cursor_col_next_Rts:
	RTS
Menu_cursor_row_next:
	ADDQ.w	#1, D3
	CMPI.w	#8, D3
	BCS.b	Menu_cursor_row_next_Rts
	MOVEQ	#0, D3
	ADDI.w	#$0180, D4
Menu_cursor_row_next_Rts:
	RTS
;Menu_cursor_col_prev
Menu_cursor_col_prev:
	SUBQ.w	#1, D2
	BCC.b	Menu_cursor_col_prev_Rts
	MOVEQ	#7, D2
	SUBI.w	#$0020, D4
Menu_cursor_col_prev_Rts:
	RTS
Decomp_code_table_init:
	dc.b	$00, $01, $00, $01, $00, $20, $00, $02
Attract_car_segment_data: ; Suspected main menu loop
	dc.b	$0E, $60, $0C, $40, $06, $20, $0E, $80, $0A, $40, $08, $00, $0E, $A0, $0C, $60, $08, $40, $0E, $C8, $0C, $80, $0A, $40, $0E, $EE, $0E, $A4, $0C, $62, $0E, $C8
	dc.b	$0C, $80, $0A, $40, $0E, $A0, $0C, $60, $08, $00, $0E, $80, $0A, $40, $08, $20
;$00002818
; Title_anim_frame — per-frame handler for the animated title screen.
; Updates sprite objects and processes player input.
; If bit 0 of Title_menu_flags is set (attract-cycle state) and the animation sequence
;   ends, transitions back to Race_preview_screen_init to loop the attract sequence.
; A secondary attract-cycle timer also fires back to Race_preview_screen_init.
; On START press: plays team-select music (Music_team_select), begins cursor processing,
;   and arms the appropriate title sub-menu handler based on Title_menu_state.
Title_anim_frame:
	JSR	Wait_for_vblank
	JSR	Update_objects_and_build_sprite_buffer
	BTST.b	#0, Title_menu_flags.w
	BNE.b	Title_anim_frame_Active
	BTST.b	#KEY_START, Input_click_bitset.w
	BNE.w	Title_anim_frame_Start_pressed
	BTST.b	#3, Title_menu_flags.w
	BNE.w	Title_anim_frame_Menu_entry
Title_anim_frame_Active:
	BSR.w	Title_anim_draw_cursor
	MOVE.w	Screen_scroll.w, D0
	JSR	Title_anim_scroll_dispatch(PC,D0.w)
	RTS
Title_anim_scroll_dispatch:
	BRA.w	Title_anim_car_seq_tick
	BRA.w	Title_anim_attract_loop
Title_anim_car_seq_tick:
	SUBQ.w	#1, Screen_timer.w
	BNE.b	Title_anim_car_seq_tick_Rts
	LEA	Title_anim_car_seq(PC), A1
	CLR.l	D0
	MOVE.l	Screen_data_ptr.w, D0
	ADDA.l	D0, A1
	CMPI.w	#$FFFF, (A1)
	BEQ.b	Title_anim_car_seq_Done
	BSR.b	Title_anim_alloc_car_obj
	MOVE.w	(A1)+, D0
	MOVE.w	D0, $26(A0)
	LEA	(Palette_buffer+$E).w, A3
	CMPI.w	#0, (A1)
	BEQ.b	Title_anim_car_seq_Load_pal
	LEA	$20(A3), A3
Title_anim_car_seq_Load_pal:
	MOVE.w	(A1)+, $C(A0)
	CMPI.w	#$0140, (A1)
	BEQ.b	Title_anim_car_seq_No_extra
	ADDQ.w	#4, $E(A0)
Title_anim_car_seq_No_extra:
	MOVE.w	(A1)+, $16(A0)
	MOVE.w	(A1)+, Screen_timer.w
	MOVEA.l	(A1), A2
	MOVE.w	#8, D0
Title_anim_car_seq_Pal_loop:
	MOVE.w	(A2)+, (A3)+
	DBF	D0, Title_anim_car_seq_Pal_loop
	ADDI.l	#$0000000C, Screen_data_ptr.w
Title_anim_car_seq_tick_Rts:
	RTS
Title_anim_car_seq_Done:
	BTST.b	#0, Title_menu_flags.w
	BEQ.b	Title_anim_car_seq_Next_state
	MOVE.w	#$001E, Screen_timer.w
	JSR	Clear_main_object_pool
	CLR.l	Screen_scroll.w
	CLR.l	Screen_data_ptr.w
	RTS
Title_anim_car_seq_Next_state:
	ADDQ.w	#4, Screen_scroll.w
	RTS
Title_anim_alloc_car_obj:
	LEA	Ai_car_array.w, A0
Title_anim_alloc_car_obj_Search:
	TST.l	(A0)
	BEQ.b	Title_anim_alloc_car_obj_Found
	LEA	$40(A0), A0
	BRA.b	Title_anim_alloc_car_obj_Search
Title_anim_alloc_car_obj_Found:
	MOVE.l	#Title_anim_car_obj_frame, $0(A0)
	MOVE.w	#$0210, $18(A0)
	MOVE.l	#Title_anim_car_obj_data, $4(A0)
	MOVE.w	#$001E, Screen_timer.w
	RTS
Title_anim_car_obj_frame:
	MOVE.w	$26(A0), D0
	ADD.w	D0, $18(A0)
	JMP	Queue_object_for_sprite_buffer
Title_anim_attract_loop:
	MOVE.l	#Race_preview_screen_init, Frame_callback.w
	RTS
Title_anim_frame_Start_pressed:
	MOVE.w	#Music_team_select, Audio_music_cmd ; team / driver select music
Title_anim_frame_Menu_entry:
	CLR.l	(Aux_object_pool+$4C0).w
	CLR.l	(Aux_object_pool+$500).w
	CLR.b	Menu_cursor.w
	BSET.b	#0, Title_menu_flags.w
	MOVE.b	#$FF, D0
	BSR.w	Update_title_menu_state
	RTS
; Title_menu — entry point when player presses START on the title screen.
; Sets "player-pressed START" bit (bit 3 of Title_menu_flags) then falls through to
; Title_menu_Init_screen which fades to black, inits H40 VDP, decompresses the full title screen
Title_menu:
	BSET.b	#3, Title_menu_flags.w
	BRA.b	Title_menu_Init_screen
;$00002944
Title_menu_attract_cycle:
	MOVE.w	#6, Selection_count.w
	CLR.b	Title_menu_flags.w
	CLR.w	Title_menu_state.w
Title_menu_Init_screen:
	JSR	Fade_palette_to_black
	JSR	Initialize_h40_vdp_state
	JSR	Clear_main_object_pool
	MOVE.w	#$8238, VDP_control_port
	MOVE.w	#$9011, VDP_control_port
	MOVE.w	#$9280, VDP_control_port
	MOVE.w	#$001E, Screen_timer.w
	MOVE.l	#$63A00001, VDP_control_port
	LEA	Race_common_tiles, A0
	JSR	Decompress_to_vdp
	MOVE.l	#$40000000, VDP_control_port
	LEA	Title_screen_tiles_a, A0
	JSR	Decompress_to_vdp
	MOVE.l	#$41A00001, VDP_control_port
	LEA	Title_screen_tiles_c, A0
	JSR	Decompress_to_vdp
	LEA	Title_screen_main_tilemap, A0
	MOVE.w	#$6000, D0
	MOVE.l	#$40000003, D7
	MOVE.w	#$0027, D6
	MOVE.w	#$001B, D5
	JSR	Decompress_tilemap_to_vdp_64_cell_rows
	LEA	Title_screen_overlay_tilemap, A0
	MOVE.w	#$E000, D0
	MOVE.l	#$428E0003, D7
	MOVE.w	#$000F, D6
	MOVE.w	#$0014, D5
	JSR	Decompress_tilemap_to_vdp_64_cell_rows
	LEA	Title_screen_palette_data, A6
	JSR	Copy_word_run_from_stream
	CMPI.w	#2, Title_menu_state.w
	BNE.w	Title_menu_Track_preview_done
	MOVE.l	#$59800001, VDP_control_port
	LEA	Title_sign_tiles, A0
	JSR	Decompress_to_vdp
	LEA	Title_sign_tilemap, A0
	MOVE.w	#$E2CC, D0
	MOVE.l	#$43100003, D7
	MOVE.w	#9, D6
	MOVE.w	#4, D5
	JSR	Decompress_tilemap_to_vdp_64_cell_rows
	LEA	(Tilemap_work_buf+$64).w, A6
	MOVE.l	#$4A920003, D7
	MOVE.w	#$000A, D6
	MOVE.w	#3, D5
	JSR	Draw_tilemap_buffer_to_vdp_64_cell_rows
	LEA	Round_sign_mapping_table, A1
	MOVE.w	Track_index.w, D0
	LSL.w	#2, D0
	MOVEA.l	(A1,D0.w), A0
	MOVE.l	#$4E600001, VDP_control_port
	JSR	Decompress_to_vdp
	LEA	Round_sign_tile_table, A1
	MOVE.w	Track_index.w, D0
	LSL.w	#2, D0
	MOVEA.l	(A1,D0.w), A0
	MOVE.w	#$E273, D0
	MOVE.l	#$43240003, D7
	MOVE.w	#3, D6
	MOVE.w	#4, D5
	JSR	Decompress_tilemap_to_vdp_64_cell_rows
	LEA	(Tilemap_work_buf+$28).w, A6
	MOVE.l	#$46100003, D7
	MOVE.w	#$000D, D6
	MOVE.w	#8, D5
	JSR	Draw_tilemap_buffer_to_vdp_64_cell_rows
	LEA	Title_screen_preview_palette_data, A6
	JSR	Copy_word_run_from_stream
Title_menu_Track_preview_done:
	BTST.b	#0, Title_menu_flags.w
	BNE.b	Title_menu_Cursor_skip
	MOVE.l	#$00002C92, (Aux_object_pool+$4C0).w
	MOVE.l	#$00001032, (Aux_object_pool+$500).w
Title_menu_Cursor_skip:
	LEA	Title_screen_bg_tilemap, A0
	MOVE.w	#$C000, D0
	MOVE.l	#$60AE0003, D7
	MOVE.w	#$000C, D6
	MOVE.w	#$0019, D5
	JSR	Decompress_tilemap_to_vdp_64_cell_rows
	MOVE.l	#Title_anim_frame, Frame_callback.w
	MOVE.l	#$000003D8, Vblank_callback.w
	TST.w	Selection_count.w
	BEQ.b	Title_menu_attract_Halt_skip
	JSR	Halt_audio_sequence
Title_menu_attract_Halt_skip:
	ANDI	#$F8FF, SR
	JSR	Wait_for_vblank
	JSR	Wait_for_vblank
	MOVE.w	Selection_count.w, Audio_music_cmd ; song = Music_title_screen (6)
	CLR.w	Selection_count.w
	JSR	Trigger_music_playback
	MOVE.w	#1, Vblank_enable.w
	MOVE.w	#$8174, VDP_control_port
	RTS

Clear_driver_points:
	LEA	Driver_points_by_team.w, A1
	MOVE.w	#$000F, D0
Clear_driver_points_Loop:
	CLR.b	(A1)+
	DBF	D0, Clear_driver_points_Loop
	RTS
Title_anim_car_seq:
	dc.w	$FFF6
	dc.w	$0000
	dc.w	$0150
	dc.b	$00, $14
	dc.l	Title_anim_car_pal_a
	dc.w	$FFF2
	dc.w	$2000
	dc.w	$0140
	dc.b	$00, $28
	dc.l	Title_anim_car_pal_b
	dc.w	$FFF4
	dc.w	$0000
	dc.w	$0150
	dc.b	$00, $32
	dc.l	Title_anim_car_pal_c
	dc.w	$FFF4
	dc.w	$2000
	dc.w	$0150
	dc.b	$00, $28
	dc.l	Title_anim_car_pal_d
	dc.w	$FFF6
	dc.w	$0000
	dc.w	$0140
	dc.b	$00, $2C
	dc.l	Title_anim_car_pal_e
	dc.w	$FFF6
	dc.w	$2000
	dc.w	$0150
	dc.b	$00, $18
	dc.l	Title_anim_car_pal_f
	dc.w	$FFF2
	dc.w	$0000
	dc.w	$0140
	dc.b	$00, $24
	dc.l	Title_anim_car_pal_a
	dc.w	$FFF4
	dc.w	$2000
	dc.w	$0150
	dc.b	$00, $28
	dc.l	Title_anim_car_pal_d
	dc.w	$FFF6
	dc.w	$0000
	dc.w	$0140
	dc.b	$00, $2C
	dc.l	Title_anim_car_pal_e
	dc.w	$FFF7
	dc.w	$2000
	dc.w	$0140
	dc.b	$00, $32
	dc.l	Title_anim_car_pal_b
	dc.w	$FFF2
	dc.w	$0000
	dc.w	$0150
	dc.b	$00, $1E
	dc.l	Title_anim_car_pal_f
	dc.w	$FFF6
	dc.w	$2000
	dc.w	$0150
	dc.b	$00, $3C
	dc.l	Title_anim_car_pal_c
	dc.w	$FFFF
Title_anim_car_pal_a:
	dc.w	$06CE, $00AE, $028C, $0048, $06CE, $00AE, $028C, $04CE, $00AE
Title_anim_car_pal_b:
	dc.w	$046E, $002A, $0006, $0004, $06C6, $0484, $0260, $0AEE, $00CE
Title_anim_car_pal_c:
	dc.w	$0EEA, $0CC4, $0882, $0440, $0EEA, $0CC4, $0882, $0EEA, $0CC4
Title_anim_car_pal_d:
	dc.w	$088E, $020A, $0006, $0002, $088E, $020A, $0006, $088E, $020A
Title_anim_car_pal_e:
	dc.w	$0A88, $0CCC, $0AAA, $0666, $0A88, $0620, $0AAA, $0AEE, $00CE
Title_anim_car_pal_f:
	dc.w	$0EEE, $0AAA, $0622, $0400, $0EEE, $0AAA, $0622, $0A66, $0622
Title_anim_car_obj_data:
	dc.b	$00, $07, $E0, $0F, $02, $0D, $FF, $B0, $E0, $0F, $02, $1D, $FF, $D0, $E0, $0F, $02, $2D, $FF, $F0, $E0, $0F, $02, $3D, $00, $10, $E0, $0F, $02, $4D, $00, $30
	dc.b	$D0, $0D, $02, $5D, $FF, $E8, $D0, $0D, $02, $65, $00, $08, $D0, $09, $02, $6D, $00, $38
	MOVE.l	#Sprite_frame_data_127D0, $4(A0)
	MOVE.w	#$0148, $16(A0)
	MOVE.w	#$0130, $18(A0)
	MOVE.w	#$00A1, $E(A0)
	JMP	Queue_object_for_sprite_buffer
Title_anim_draw_cursor:
	BTST.b	#0, Title_menu_flags.w
	BEQ.w	Title_anim_draw_cursor_Rts
	BTST.b	#1, Title_menu_flags.w
	BEQ.w	Title_anim_draw_cursor_Active
	MOVE.l	Title_menu_vdp_command.w, D0
	ORI	#$0700, SR
	MOVE.l	D0, VDP_control_port
	MOVE.w	#$8354, VDP_data_port
	CLR.w	D1
	MOVE.b	Title_menu_row_count.w, D1
Title_anim_draw_cursor_Fill_before:
	MOVE.w	#$8355, VDP_data_port
	DBF	D1, Title_anim_draw_cursor_Fill_before
	MOVE.w	#$8356, VDP_data_port
	ANDI	#$F8FF, SR
	CLR.w	D2
	MOVE.b	Title_menu_cursor_row.w, D2
Title_anim_draw_cursor_Row_loop:
	ADDI.l	#$00800000, D0
	ORI	#$0700, SR
	MOVE.l	D0, VDP_control_port
	MOVE.w	#$8357, VDP_data_port
	CLR.w	D1
	MOVE.b	Title_menu_row_count.w, D1
Title_anim_draw_cursor_Row_fill:
	MOVE.w	#$834F, VDP_data_port
	DBF	D1, Title_anim_draw_cursor_Row_fill
	MOVE.w	#$8358, VDP_data_port
	DBF	D2, Title_anim_draw_cursor_Row_loop
	ANDI	#$F8FF, SR
	ADDI.l	#$00800000, D0
	ORI	#$0700, SR
	MOVE.l	D0, VDP_control_port
	MOVE.w	#$8359, VDP_data_port
	CLR.w	D1
	MOVE.b	Title_menu_row_count.w, D1
Title_anim_draw_cursor_Fill_after:
	MOVE.w	#$835A, VDP_data_port
	DBF	D1, Title_anim_draw_cursor_Fill_after
	MOVE.w	#$835B, VDP_data_port
	ANDI	#$F8FF, SR
	MOVE.b	Title_menu_cursor_row.w, D0
	CMP.b	Title_menu_item_count.w, D0
	BEQ.b	Title_anim_draw_cursor_Complete
	ADDQ.b	#1, Title_menu_cursor_row.w
	RTS
Title_anim_draw_cursor_Complete:
	BCLR.b	#1, Title_menu_flags.w
	CLR.w	D1
	MOVE.b	Title_menu_item_count.w, D1
	LSR.w	#1, D1
	MOVE.b	D1, Temp_x_pos.w
	CLR.w	D2
	MOVE.b	Title_menu_row_count.w, D2
	SUBQ.w	#3, D2
	MOVE.l	Title_menu_vdp_command.w, D7
	ADDI.l	#$00860000, D7
	MOVEA.l	Title_menu_item_table_ptr.w, A1
	ORI	#$0700, SR
	BSR.w	Title_menu_write_items
	ANDI	#$F8FF, SR
	CLR.b	Menu_cursor.w
Title_anim_draw_cursor_Rts:
	RTS
Title_anim_draw_cursor_Active:
	BSR.b	Title_menu_handle_input
	CMPI.w	#3, Title_menu_state.w
	BEQ.b	Title_anim_draw_track_cursor
;Render_title_car_indicator_tile
Render_title_car_indicator_tile:
	MOVE.l	Title_menu_vdp_command.w, D7
	CLR.w	D0
	MOVE.b	Menu_cursor.w, D0
	MOVE.l	#$01000000, D1
	MOVE.l	#$FF800000, D2
Render_title_car_indicator_tile_Pos_loop:
	ADD.l	D1, D2
	DBF	D0, Render_title_car_indicator_tile_Pos_loop
	ADD.l	D2, D7
	ADDI.l	#$00040000, D7
	ADDQ.b	#1, Screen_subcounter.w
	MOVE.w	#$834F, D0
	BTST.b	#2, Screen_subcounter.w
	BEQ.b	Render_title_car_indicator_tile_Blank
	MOVE.w	#$834D, D0
Render_title_car_indicator_tile_Blank:
	ORI	#$0700, SR
	MOVE.l	D7, VDP_control_port
	MOVE.w	D0, VDP_data_port
	ANDI	#$F8FF, SR
	RTS
Title_anim_draw_track_cursor:
	MOVE.w	Title_menu_cursor.w, D0
	ADDI.w	#$831E, D0
	ORI	#$0700, SR
	MOVE.l	#$6A400003, VDP_control_port
	MOVE.w	D0, VDP_data_port
	ANDI	#$F8FF, SR
	RTS
Title_menu_handle_input:
	MOVE.b	Input_click_bitset.w, D0
	BEQ.b	Title_menu_handle_input_Rts
	ANDI.b	#$E0, D0
	BNE.w	Title_menu_handle_input_Confirm
	BTST.b	#KEY_B, Input_click_bitset.w
	BNE.b	Title_menu_handle_input_Cancel
	BTST.b	#KEY_UP, Input_click_bitset.w
	BNE.w	Title_menu_handle_input_Up
	BTST.b	#KEY_DOWN, Input_click_bitset.w
	BNE.w	Title_menu_handle_input_Down
	CMPI.w	#3, Title_menu_state.w
	BEQ.b	Title_menu_handle_input_Lr
Title_menu_handle_input_Rts:
	RTS
Title_menu_handle_input_Lr:
	BTST.b	#KEY_LEFT, Input_click_bitset.w
	BNE.b	Title_menu_handle_input_Left
	CMPI.w	#3, Title_menu_state.w
	BNE.b	Title_menu_handle_input_Right
	MOVE.w	#$000E, Audio_sfx_cmd       ; Sfx_menu_confirm
Title_menu_handle_input_Right:
	CMPI.w	#8, Title_menu_cursor.w
	BEQ.b	Title_menu_handle_input_Right_wrap
	ADDQ.w	#1, Title_menu_cursor.w
	RTS
Title_menu_handle_input_Right_wrap:
	CLR.w	Title_menu_cursor.w
	RTS
Title_menu_handle_input_Left:
	CMPI.w	#3, Title_menu_state.w
	BNE.b	Title_menu_handle_input_Left_dec
	MOVE.w	#$000E, Audio_sfx_cmd       ; Sfx_menu_confirm
Title_menu_handle_input_Left_dec:
	MOVE.w	Title_menu_cursor.w, D0
	BEQ.b	Title_menu_handle_input_Left_wrap
	SUBQ.w	#1, Title_menu_cursor.w
	RTS
Title_menu_handle_input_Left_wrap:
	MOVE.w	#8, Title_menu_cursor.w
	RTS
Title_menu_handle_input_Cancel:
	CLR.b	Screen_subcounter.w
	BSR.w	Render_title_car_indicator_tile
	CMPI.w	#2, Title_menu_state.w
	BCC.b	Title_menu_handle_input_Cancel_hi
	CLR.w	Title_menu_state.w
	MOVE.b	#$FF, D0
	BRA.w	Update_title_menu_state
Title_menu_handle_input_Cancel_hi:
	MOVE.w	#2, Title_menu_state.w
	MOVE.b	#$FF, D0
	BRA.w	Update_title_menu_state
Title_menu_handle_input_Confirm:
	MOVE.w	#$000E, Audio_sfx_cmd       ; Sfx_menu_confirm
	CLR.b	Screen_subcounter.w
	BSR.w	Render_title_car_indicator_tile
	CMPI.w	#3, Title_menu_state.w
	BEQ.b	Title_menu_handle_input_Warm_up
	CLR.b	D0
	BRA.w	Update_title_menu_state
Title_menu_handle_input_Up:
	CMPI.w	#3, Title_menu_state.w
	BEQ.b	Title_menu_handle_input_Up_quiet
	MOVE.w	#$000E, Audio_sfx_cmd       ; Sfx_menu_confirm
Title_menu_handle_input_Up_quiet:
	CLR.b	Screen_subcounter.w
	BSR.w	Render_title_car_indicator_tile
	MOVE.b	Menu_cursor.w, D0
	BEQ.b	Title_menu_handle_input_Up_wrap
	SUBQ.b	#1, Menu_cursor.w
	RTS
Title_menu_handle_input_Up_wrap:
	MOVE.b	Temp_x_pos.w, D0
	MOVE.b	D0, Menu_cursor.w
	RTS
Title_menu_handle_input_Down:
	CMPI.w	#3, Title_menu_state.w
	BEQ.b	Title_menu_handle_input_Down_quiet
	MOVE.w	#$000E, Audio_sfx_cmd       ; Sfx_menu_confirm
Title_menu_handle_input_Down_quiet:
	CLR.b	Screen_subcounter.w
	BSR.w	Render_title_car_indicator_tile
	MOVE.b	Temp_x_pos.w, D0
	CMP.b	Menu_cursor.w, D0
	BEQ.b	Title_menu_handle_input_Down_wrap
	ADDQ.b	#1, Menu_cursor.w
	RTS
Title_menu_handle_input_Down_wrap:
	CLR.b	Menu_cursor.w
	RTS
Title_menu_handle_input_Warm_up:
	MOVE.w	#2, Title_menu_state.w
	CLR.b	Title_menu_flags.w
	CLR.w	Track_index_arcade_mode.w
	CLR.w	Practice_mode.w
	MOVE.w	#1, Warm_up.w
	MOVE.w	#1, Practice_flag.w
	MOVE.w	#$000A, Selection_count.w
	MOVE.l	#$00003800, Frame_callback.w
	RTS
Title_menu_write_items:
	MOVE.l	D7, VDP_control_port
	MOVE.w	D2, D3
Title_menu_write_items_Loop:
	CLR.w	D0
	MOVE.b	(A1)+, D0
	ADDI.w	#$831D, D0
	MOVE.w	D0, VDP_data_port
	DBF	D3, Title_menu_write_items_Loop
	ADDI.l	#$01000000, D7
	DBF	D1, Title_menu_write_items
	RTS
Update_title_menu_state:
	TST.b	D0
	BNE.b	Update_title_menu_state_Layout
	CLR.l	D1
	LEA	Title_menu_state_handlers, A1
	MOVE.w	Title_menu_state.w, D0
	LSL.l	#3, D0
	MOVE.b	Menu_cursor.w, D1
	ADD.l	D1, D1
	ADD.l	D1, D0
	MOVEA.w	(A1,D0.w), A2
	JSR	(A2)
Update_title_menu_state_Layout:
	CLR.w	D1
	CLR.w	D2
	LEA	Title_menu_selection_layouts, A1
	MOVE.w	Title_menu_state.w, D0
	MULS.w	#$000A, D0
	MOVE.b	(A1,D0.w), D1
	MOVE.b	$1(A1,D0.w), D2
	MOVE.l	$2(A1,D0.w), D3
	MOVE.l	$6(A1,D0.w), D4
	MOVE.b	D1, Title_menu_row_count.w
	MOVE.b	D2, Title_menu_item_count.w
	MOVE.l	D3, Title_menu_item_table_ptr.w
	MOVE.l	D4, Title_menu_vdp_command.w
	CLR.b	Title_menu_cursor_row.w
	BSET.b	#1, Title_menu_flags.w
	RTS
Title_menu_sel_Free_practice:
	CLR.w	Shift_type.w
	CLR.w	Use_world_championship_tracks.w
	CLR.w	Track_index_arcade_mode.w
	CLR.w	Track_index.w
	CLR.w	Practice_mode.w
	CLR.w	Warm_up.w
	MOVE.w	#1, Practice_flag.w
	MOVE.w	#Engine_data_offset_practice, Engine_data_offset.w
	CLR.w	Acceleration_modifier.w
	MOVE.l	#$00003800, Saved_frame_callback.w
	MOVE.l	#$000032FA, Frame_callback.w
	MOVE.w	#1, Selection_count.w
	BCLR.b	#0, Title_menu_flags.w
	RTS
Title_menu_sel_New_game:
	MOVE.w	#$000A, Selection_count.w
	MOVE.w	#1, Title_menu_state.w
	RTS
Title_menu_sel_Arcade:
	MOVE.w	#$000E, Selection_count.w
	MOVE.l	#$00005690, Frame_callback.w
	RTS
Title_menu_sel_Password:
	MOVE.l	#$0000ED90, Frame_callback.w
	RTS
Title_menu_sel_Championship:
	MOVE.w	Saved_shift_type.w, Shift_type.w
	MOVE.w	#1, Use_world_championship_tracks.w
	CLR.w	Track_index.w
	MOVE.w	#1, Practice_flag.w
	MOVE.w	#2, Title_menu_state.w
	CLR.b	Player_team.w
	JSR	Initialize_drivers_and_teams
	MOVE.l	#$0000D6E2, Frame_callback.w
	RTS
Title_menu_sel_Endgame:
	CLR.b	Menu_cursor.w
	MOVE.w	Saved_shift_type.w, Shift_type.w
	MOVE.w	#1, Use_world_championship_tracks.w
	CLR.w	Track_index.w
	MOVE.w	#1, Practice_flag.w
	MOVE.w	#2, Title_menu_state.w
	CLR.b	Player_team.w
	JSR	Initialize_drivers_and_teams
	MOVE.l	#Title_menu, Saved_frame_callback.w
	MOVE.l	#Endgame_sequence_init, Frame_callback.w
	RTS
Title_menu_sel_Track_preview:
	MOVE.w	#3, Title_menu_state.w
	RTS
Title_menu_sel_Race_no_rival:
	CLR.w	Track_index_arcade_mode.w
	CLR.w	Practice_mode.w
	CLR.w	Warm_up.w
	MOVE.l	#$00003800, Frame_callback.w
	RTS
Title_menu_sel_Team_select:
	BSET.b	#7, Player_team.w
	MOVE.l	#Title_menu, Saved_frame_callback.w
	MOVE.l	#Team_select_screen_init, Frame_callback.w
	RTS
Title_menu_sel_Options:
	MOVE.l	#Title_menu, Saved_frame_callback.w
	MOVE.l	#$000032E0, Frame_callback.w
	RTS
Title_menu_state_handlers:
	dc.w	Title_menu_sel_Free_practice
	dc.w	Title_menu_sel_New_game
	dc.w	Title_menu_sel_Arcade
	dc.w	Title_menu_sel_Password
	dc.w	Title_menu_sel_Championship
	dc.w	Title_menu_sel_Endgame
	dc.w	Title_menu_state_handlers
	dc.w	Title_menu_state_handlers
	dc.w	Title_menu_sel_Track_preview
	dc.w	Title_menu_sel_Race_no_rival
	dc.w	Title_menu_sel_Team_select
	dc.w	Title_menu_sel_Options
Title_menu_selection_layouts:
	dc.b	$14, $06
	dc.l	Title_menu_items_main
	dc.l	$681E0003
	dc.b	$0A, $02
	dc.l	Title_menu_items_newgame
	dc.l	$69280003
	dc.b	$0E, $06
	dc.l	Title_menu_items_options
	dc.l	$682A0003
	dc.b	$08, $00
	dc.l	Title_menu_items_laps
	dc.l	$69B00003
Title_menu_items_main:
	txt "SUPER MONACO GP   "
	txt "WORLD CHAMPIONSHIP"
	txt "FREE PRACTICE     "
	txt "OPTIONS           "
Title_menu_items_newgame:
	txt "NEW GAME"
	txt "PASSWORD"
Title_menu_items_options:
	txt "WARM UP     "
	txt "RACE        "
	txt "MACHINE     "
	txt "TRANSMISSION"
Title_menu_items_laps:
	txt "LAPS  "
;$000031FE
; Options_setup_frame — per-frame handler for the WARM UP / RACE / MACHINE / TRANSMISSION
; options screen.  Fires cursor-move SFX (Sfx_menu_cursor) from Options_cursor_update, then
; counts down the Screen_scroll transition timer.  When a valid selection is committed
; (scroll reaches 0) saves Shift_type to Saved_shift_type_2 and restores the frame
; callback that launched the options screen (via Saved_frame_callback), returning to
; either the arcade or championship path.
Options_setup_frame:
	JSR	Wait_for_vblank
	JSR	Update_objects_and_build_sprite_buffer
	MOVE.w	Options_cursor_update.w, D0
	BEQ.b	Options_setup_frame_No_sfx
	MOVE.w	D0, Audio_sfx_cmd           ; Options_cursor_update → SFX (Sfx_menu_cursor = 2)
	CLR.w	Options_cursor_update.w
Options_setup_frame_No_sfx:
	TST.w	Screen_scroll.w
	BEQ.b	Options_setup_frame_Idle
	SUBQ.w	#1, Screen_scroll.w
	BNE.w	Options_setup_frame_Rts
	BRA.w	Options_setup_frame_Commit
Options_setup_frame_Idle:
	MOVE.w	Use_world_championship_tracks.w, D0
	OR.w	Anim_delay.w, D0
	BNE.b	Options_setup_frame_Input
	MOVEQ	#1, D1
	SUB.w	D1, Screen_tick.w
	BNE.b	Options_setup_frame_Laps_display
	MOVE.w	#$003C, Screen_tick.w
	MOVE.b	Screen_digit.w, D2
	BEQ.w	Options_setup_frame_Commit
	ADDI.w	#0, D0
	SBCD	D1, D2
	MOVE.b	D2, Screen_digit.w
Options_setup_frame_Laps_display:
	LEA	Digit_tilemap_buf.w, A1
	MOVE.b	Screen_digit.w, D1
	MOVEQ	#1, D0
	MOVEQ	#0, D7
	JSR	Unpack_bcd_digits_to_buffer
	MOVEQ	#1, D0
	JSR	Copy_digits_to_tilemap
	MOVE.l	#$61460003, D7
	MOVEQ	#1, D6
	MOVEQ	#1, D5
	LEA	Digit_tilemap_buf.w, A6
	JSR	Draw_tilemap_buffer_to_vdp_64_cell_rows
Options_setup_frame_Input:
	MOVE.b	Input_click_bitset.w, D0
	ANDI.b	#$F0, D0
	BEQ.b	Options_setup_frame_Rts
	LEA	VDP_data_port, A5
	MOVE.w	#$E786, D6
	TST.w	Shift_type.w
	BEQ.b	Options_setup_frame_Draw_selected
	MOVE.w	#$E7A0, D6
	CMPI.w	#1, Shift_type.w
	BEQ.b	Options_setup_frame_Draw_selected
	MOVE.w	#$E7BA, D6
Options_setup_frame_Draw_selected:
	LEA	Options_selected_text_data(PC), A6
	JSR	Draw_packed_tilemap_to_vdp_preset_base
	MOVEQ	#2, D0
	MOVE.w	D0, Options_cursor_update.w
	MOVE.w	D0, Audio_sfx_cmd           ; Sfx_menu_cursor (2)
	MOVE.w	#$002D, Screen_scroll.w
Options_setup_frame_Rts:
	RTS
Options_setup_frame_Commit:
	MOVE.w	Shift_type.w, Saved_shift_type.w
	MOVE.w	Shift_type.w, Saved_shift_type_2.w
	MOVE.l	Saved_frame_callback.w, Frame_callback.w
	RTS
;$000032E0
; Options_screen_arcade_init — arcade-path entry for the options screen.
; Restores Saved_shift_type → Shift_type, sets Anim_delay=1, then falls through to
; Options_screen_init.
Options_screen_arcade_init:
	JSR	Fade_palette_to_black
	JSR	Initialize_h40_vdp_state
	MOVE.w	Saved_shift_type.w, Shift_type.w
	MOVE.w	#1, Anim_delay.w
	BRA.b	Options_screen_init_Body
;Options_screen_init
; Options_screen_init — initialise the options setup screen (shared between arcade and
; championship paths).  Fades to black, inits H40 VDP, decompresses the options tileset
; and four tilemaps (WARM UP / RACE / MACHINE / TRANSMISSION selector panels), draws
; lap-count and control-type graphics, arms the options cursor object, and installs
; Options_setup_frame as the per-frame callback.
Options_screen_init:
	JSR	Fade_palette_to_black
	JSR	Initialize_h40_vdp_state
Options_screen_init_Body:
	JSR	Clear_main_object_pool
	MOVE.w	#$9011, VDP_control_port
	LEA	Options_asset_list(PC), A1
	JSR	Decompress_asset_list_to_vdp
	LEA	Options_bg_tilemap, A0
	MOVE.w	#$6580, D0
	MOVE.l	#$40000003, D7
	MOVEQ	#$00000027, D6
	MOVEQ	#$0000001B, D5
	JSR	Decompress_tilemap_to_vdp_64_cell_rows
	MOVE.w	#$2000, D0
	LEA	Options_main_tilemap, A0
	JSR	Decompress_tilemap_to_buffer
	LEA	Options_tilemap_list(PC), A1
	JSR	Draw_tilemap_list_to_vdp_64_cell_rows
	LEA	Options_champ_lap_list(PC), A1
	TST.w	Anim_delay.w
	BEQ.b	Options_screen_init_Champ_layout
	LEA	Options_arcade_lap_list(PC), A1
Options_screen_init_Champ_layout:
	JSR	Draw_tilemap_list_to_vdp_64_cell_rows
	MOVE.w	#$2000, D0
	LEA	Options_shift_tilemap_a, A0
	JSR	Decompress_tilemap_to_buffer
	MOVE.w	Control_type.w, D0
	LSL.w	#2, D0
	LEA	Options_shift_display_table(PC), A1
	MOVEA.l	(A1,D0.w), A1
	JSR	Draw_tilemap_list_to_vdp_64_cell_rows
	MOVE.l	#$66860003, D7
	MOVEQ	#7, D6
	MOVEQ	#1, D5
	LEA	Shift_indicator_tilemap_manual, A6
	MOVE.w	#$FD89, D1
	MOVE.l	#$00800000, D3
	JSR	Write_tilemap_rows_to_vdp
	MOVE.l	#$66A20003, D7
	MOVEQ	#5, D6
	MOVEQ	#1, D5
	MOVE.l	A6, -(A7)
	JSR	Write_tilemap_rows_to_vdp
	MOVE.l	#$663C0003, D7
	MOVEQ	#2, D5
	MOVEA.l	(A7)+, A6
	JSR	Write_tilemap_rows_to_vdp
	MOVEQ	#0, D0
	LEA	Options_shift_tilemap_b, A0
	JSR	Decompress_tilemap_to_buffer
	LEA	Options_palette_data, A6
	JSR	Copy_word_run_from_stream
	MOVE.l	#$0030003C, Screen_timer.w
	MOVE.l	#$000035A8, Main_object_pool.w
	JSR	Update_objects_and_build_sprite_buffer
	MOVE.l	#Options_setup_frame, Frame_callback.w
	MOVE.l	#$000003D8, Vblank_callback.w
	ANDI	#$F8FF, SR
	JSR	Wait_for_vblank
	MOVE.w	Selection_count.w, Audio_music_cmd ; song selection (context-dependent)
	CLR.w	Selection_count.w
	MOVE.w	#1, Vblank_enable.w
	MOVE.w	#$8174, VDP_control_port
	RTS
Options_palette_data:
	dc.b	$02, $3B, $00, $00, $00, $00, $0A, $AA, $02, $22, $06, $66, $00, $00, $0C, $CC, $08, $88, $06, $68, $0E, $66, $02, $2E, $06, $68, $04, $44, $02, $2E, $00, $CE
	dc.b	$00, $00, $00, $00, $00, $CE, $00, $04, $02, $EE, $0E, $8E, $0C, $A8, $08, $E0, $0A, $E2, $06, $E0, $04, $44, $0E, $EE, $00, $0E, $06, $6E, $04, $4E, $0C, $CC
	dc.b	$00, $00, $00, $00, $00, $AE, $0A, $AA, $02, $22, $06, $66, $00, $00, $0C, $CC, $08, $88, $0A, $AC, $0E, $66, $02, $2E, $06, $68, $04, $44, $02, $2E, $00, $CE
	dc.b	$06, $66, $00, $00, $00, $00, $08, $88, $06, $88, $04, $46, $04, $44, $02, $22, $06, $EE, $04, $CE, $02, $AE, $02, $8E, $06, $68
Options_asset_list:
	dc.b	$00, $03
	dc.b	$B0, $00
	dc.l	Options_bg_tiles
	dc.b	$00, $00
	dc.l	Options_tiles
	dc.b	$95, $80
	dc.l	Race_hud_tiles_a
	dc.b	$9F, $20
	dc.l	Race_hud_tiles_b
Options_tilemap_list:
	dc.b	$00, $05
	dc.b	$E0, $8C, $1A, $02
	dc.l	Tilemap_work_buf
	dc.b	$EC, $32, $0D, $01
	dc.l	$FFFFEB8E
	dc.b	$E2, $86, $07, $02
	dc.l	$FFFFEBC6
	dc.b	$E2, $A0, $07, $02
	dc.l	$FFFFEBF6
	dc.b	$E2, $BA, $07, $02
	dc.l	$FFFFEC26
	dc.b	$EC, $04, $0A, $02
	dc.l	$FFFFEC56
Options_champ_lap_list:
	dc.b	$00, $02
	dc.l	$E5040A01
	dc.l	$FFFFEAA2
	dc.l	$E41C0B03
	dc.l	$FFFFEACE
	dc.l	$E4360B03
	dc.l	$FFFFEB2E
Options_arcade_lap_list:
	dc.b	$00, $01
	dc.l	$E49C0B01
	dc.l	$FFFFEACE
	dc.l	$E4B60B01
	dc.l	$FFFFEB2E
Options_shift_display_table:
	dc.l	Options_shift_display_4speed-2
	dc.l	Options_shift_display_man
	dc.l	Options_shift_display_4speed-2
	dc.l	Options_shift_display_man
	dc.l	Options_shift_display_7speed
	dc.l	Options_shift_display_7speed
Options_shift_display_man:
	dc.l	Options_shift_display_tiles
	dc.l	$0908FFFF
	dc.l	$EA00E79E
	dc.l	$0908FFFF
	dc.l	$EB68E7B8
	dc.l	$0908FFFF
	dc.l	$ECD00002
Options_shift_display_4speed:
	dc.l	$E7840908
	dc.l	$FFFFEE38
	dc.l	$E79E0908
	dc.l	$FFFFEFA0
	dc.l	$E7B80908
	dc.l	$FFFFEEEC
Options_shift_display_7speed:
	dc.l	Options_shift_display_tiles
	dc.l	$0908FFFF
	dc.l	$EAB4E79E
	dc.l	$0908FFFF
	dc.l	$EC1CE7B8
	dc.l	$0908FFFF
	dc.b	$ED, $84
Options_selected_text_data:
	dc.b	$FB, $C7, $C0
	txt "SELECTED"
Options_cursor_anim_table:
	dc.b	$FF, $01, $01, $01, $02, $03, $04, $05, $06, $07, $0C, $12, $2C
Options_cursor_x_positions:
	dc.w	$0080
	dc.w	$00E8
	dc.w	$0150
; Options_cursor_obj_init (inline, falls through after dc.w table)
Options_cursor_obj_init:
	MOVE.l	#Options_cursor_obj_frame, (A0)
	MOVE.l	#Sprite_frame_data_12912, $4(A0)
	MOVE.w	#$0140, $16(A0)
	MOVE.w	Shift_type.w, D0
	ADD.w	D0, D0
	MOVE.w	Options_cursor_x_positions(PC,D0.w), $18(A0)
Options_cursor_obj_frame:
	MOVE.w	$2A(A0), D0
	BEQ.b	Options_cursor_obj_Input
	MOVEQ	#0, D1
	MOVE.b	Options_cursor_anim_table(PC,D0.w), D1
	TST.w	$2C(A0)
	BEQ.b	Options_cursor_obj_Slide
	NEG.w	D1
Options_cursor_obj_Slide:
	ADD.w	D1, $18(A0)
	SUBQ.w	#1, $2A(A0)
	BRA.b	Options_shift_anim_Advance
Options_cursor_obj_Input:
	TST.w	Screen_scroll.w
	BNE.b	Options_shift_anim_Advance
	LEA	Shift_type.w, A3
	BTST.b	#KEY_RIGHT, Input_click_bitset.w
	BEQ.b	Options_cursor_obj_Left_check
	CMPI.w	#2, (A3)
	BEQ.b	Options_shift_anim_Advance
	ADDQ.w	#1, (A3)
	CLR.w	$2C(A0)
	BRA.b	Options_cursor_obj_Start_anim
Options_cursor_obj_Left_check:
	BTST.b	#KEY_LEFT, Input_click_bitset.w
	BEQ.b	Options_shift_anim_Advance
	TST.w	(A3)
	BEQ.b	Options_shift_anim_Advance
	SUBQ.w	#1, (A3)
	MOVE.w	#$FFFF, $2C(A0)
Options_cursor_obj_Start_anim:
	MOVE.w	#$000C, $2A(A0)
;Options_shift_anim_Advance
Options_shift_anim_Advance:
	MOVE.w	$2E(A0), D0
	MOVE.b	Frame_counter.w, D1
	ANDI.w	#1, D1
	BNE.b	Options_cursor_obj_Advance_frame
	ADDQ.w	#2, D0
	ANDI.w	#6, D0
	MOVE.w	D0, $2E(A0)
Options_cursor_obj_Advance_frame:
	LEA	Options_shift_anim_frames(PC,D0.w), A1
	LEA	(Palette_buffer+$70).w, A2
	MOVE.l	(A1)+, (A2)+
	MOVE.l	(A1), (A2)
	MOVEQ	#2, D0
	SUB.w	Shift_type.w, D0
	ADD.w	D0, D0
	LEA	Options_shift_tilemap_offsets, A1
	ADDA.w	D0, A1
	MOVE.l	#$47840003, D7
	MOVEQ	#9, D6
	MOVEQ	#8, D5
	LEA	Tilemap_work_buf.w, A6
	MOVE.w	(A1)+, D1
	MOVE.l	#$00800000, D3
	JSR	Write_tilemap_rows_to_vdp
	MOVE.l	#$479E0003, D7
	MOVEQ	#8, D5
	LEA	Tilemap_work_buf.w, A6
	MOVE.w	(A1)+, D1
	JSR	Write_tilemap_rows_to_vdp
	MOVE.l	#$47B80003, D7
	MOVEQ	#8, D5
	LEA	Tilemap_work_buf.w, A6
	MOVE.w	(A1)+, D1
	JSR	Write_tilemap_rows_to_vdp
	JMP	Queue_object_for_sprite_buffer
Options_shift_tilemap_offsets:
	dc.w	$0000, $0000, $4000, $0000, $0000
Options_shift_anim_frames:
	dc.b	$06, $EE, $04, $CE, $02, $AE
	dc.l	$028E06EE
	dc.l	$04CE02AE
;Race_loop
; ============================================================
; Race_loop - per-frame race update routine
; Called every frame by Championship_warmup_race_frame and by the
; championship/practice race Frame_callback at $36B6.
;
; Frame update order:
;   1. Sync with VBI cycle (Wait_for_practice_vblank_cycle)
;   2. Reset tilemap draw queue
;   3. Early-out if race is finished (Race_finish_flag set)
;   4. Handle_pause  — process pause input; return early while paused
;   5. Update_road_tile_scroll / Update_background_scroll_delta
;   6. If retired: zero shift/RPM/speed; else drive model update:
;        Update_shift → Update_rpm → Update_breaking →
;        Update_engine_sound_pitch → Update_speed
;   7. Render_speed  — speedometer gauge
;   8. Advance_lap_checkpoint  — checkpoint and lap detection
;   9. Render_placement_display  — "1ST" / "2ND" etc. ordinal HUD
;  10. Update_steering  — steering input → Steering_output
;  11. Update_horizontal_position  — lateral position integration
;  12. Advance_player_distance  — advance track position
;  13. Update_slope_data  — slope/gradient integrator
;  14. Update_race_timer  — tick BCD race clock
;  15. Update_race_position  — compute placement vs AI cars
;  16. Update_gap_to_rival_display  — gap-to-rival HUD value
;  17. Update_rival_sprite_tiles  — rival car sprite animation
;  18. Parse_tileset_for_signs  — tileset pass for roadside signs
;  19. Parse_sign_data  — sign/obstacle placement pass
;  20. Update_pit_prompt  — pit-in display
;  21. Update_braking_performance  — braking zone durability tracker + overtake flag
;  22. Apply_sorted_positions_to_cars  — sort AI car positions
;  -- wait for VBI step 4 --
;  23. Update_objects_and_build_sprite_buffer  — build sprite DMA list
;  24. Update_engine_and_tire_sounds  — engine/tire SFX
;  25. Update_road_graphics  — road scanline renderer
; ============================================================
