Update_road_graphics:
; Main per-frame road and background rendering update.
; Called once per frame from Race_loop (step 15).  Skipped when Race_finish_flag is set.
;
; Steps:
;  1. Background vertical scroll: read Background_vertical_displacement at
;     Player_distance/4, sign-extend, store in $FFFF9236 (VDP V-scroll register cache).
;  2. Background horizontal parallax: read Background_horizontal_displacement at
;     Player_distance/2 (even index), shift left 6, convert to 32-bit fixed-point,
;     then integrate toward target using Player_distance_fixed accumulator
;     (smooth parallax scrolling).  Store integer part in Player_distance_steps.
;  3. Road scanline descriptors: select one of 16 sub-step offset blocks from
;     the pre-computed road scan-line descriptor table at Road_scanline_descriptor_table based on
;     (Player_distance & $F).  Copy 4 × 48-byte blocks to $FFFFAC40 (road
;     scan-line work area used by the road tile painter).
;  4. HUD scroll blanking: if HUD_scroll_base != 0, fill that row in the
;     scan-line work area with $FF40 (blank/transparent tile) and clear the flag.
;  5. Retire flash: if bit 0 is set in $FFFF9239, blank a row range (from
;     $FFFFAFEC) with $FF40.
;  6. Road-edge/turn sign placement: compute upcoming sign distance, look up
;     edge Y position from the Ai_screen_y_table Y-position table, fill the sign
;     row region with $FF40, and update sign position flag ($FFFFFC86).
;  7. Background zone colouring: if Background_zone_index != 0, AND the
;     appropriate scan-line words with $FF40 for the sky/ground colour split.
;  8. Road tile row builder: build the per-scanline road tile index sequence
;     at $FFFF9D40 from the current Tileset_base_offset, scale table, and
;     per-row Y table; handles retire flash (alternating pattern at bit 0 of
;     Frame_counter).
	TST.w	Race_finish_flag.w
	BNE.b	Copy_displacement_rows_Rts
	MOVE.w	Player_distance.w, D0
	LSR.w	#2, D0
	LEA	Background_vertical_displacement, A0
	MOVE.b	(A0,D0.w), D0
	EXT.w	D0
	MOVE.w	D0, Background_vertical_offset.w
	MOVEQ	#0, D0
	MOVE.w	Player_distance.w, D0
	LSR.w	#1, D0
	ANDI.w	#$FFFE, D0
	LEA	Background_horizontal_displacement, A0
	MOVE.w	(A0,D0.w), D0
	LSL.w	#6, D0
	SWAP	D0
	MOVE.l	Player_distance_fixed.w, D1
	LSL.l	#6, D1
	SUB.l	D1, D0
	ASR.l	#8, D0
	ADD.l	D0, Player_distance_fixed.w
	MOVE.w	Player_distance_fixed.w, Player_distance_steps.w
	MOVE.w	Player_distance.w, D0
	ANDI.w	#$000F, D0
	LSL.w	#6, D0
	MOVE.w	D0, D1
	ADD.w	D0, D0
	ADD.w	D1, D0
	LEA	Road_scanline_descriptor_table, A6
	ADDA.w	D0, A6
	LEA	(Main_object_pool-$140).w, A5
	MOVEM.l	(A6)+, D0-D7/A0-A3
	MOVEM.l	D0-D7/A0-A3, (A5)
	LEA	$30(A5), A5
	MOVEM.l	(A6)+, D0-D7/A0-A3
	MOVEM.l	D0-D7/A0-A3, (A5)
	LEA	$30(A5), A5
	MOVEM.l	(A6)+, D0-D7/A0-A3
	MOVEM.l	D0-D7/A0-A3, (A5)
	LEA	$30(A5), A5
	MOVEM.l	(A6)+, D0-D7/A0-A3
	MOVEM.l	D0-D7/A0-A3, (A5)
	LEA	(Main_object_pool-$140).w, A6
	LEA	(A6), A5
	MOVE.w	HUD_scroll_base.w, D0
	BEQ.b	Update_road_graphics_Hud_blank_done
	ADD.w	D0, D0
	ADDA.w	D0, A5
	MOVE.w	#$FF40, D1
	MOVE.w	HUD_blank_row_count.w, D0
Update_road_graphics_Hud_blank_loop:
	MOVE.w	D1, (A5)+
	DBF	D0, Update_road_graphics_Hud_blank_loop
	LEA	(A6), A5
	CLR.w	HUD_scroll_base.w
Update_road_graphics_Hud_blank_done:
	BTST.b	#0, Special_road_scene_b.w
	BEQ.b	Update_road_graphics_Retire_flash_done
	MOVE.w	Road_blank_row_count.w, D0
	MOVE.w	#$FF40, D1
Update_road_graphics_Retire_flash_loop:
	MOVE.w	D1, (A5)+
	DBF	D0, Update_road_graphics_Retire_flash_loop
	LEA	(A6), A5
Update_road_graphics_Retire_flash_done:
	TST.w	Special_road_blank_bg_flag.w
	BEQ.b	Update_road_graphics_Sign_row_done
	MOVE.w	Road_blank_row_count.w, D0
	MOVE.w	#$FF40, D1
	LEA	$C0(A5), A5
Update_road_graphics_Sign_row_loop:
	MOVE.w	D1, -(A5)
	DBF	D0, Update_road_graphics_Sign_row_loop
	LEA	(A6), A5
Update_road_graphics_Sign_row_done:
	LEA	Road_sign_rotation_index.w, A0
	MOVE.w	(A0)+, D2
	MOVE.w	(A0,D2.w), D2
	MOVE.w	D2, D0
	ADDQ.w	#7, D0
	MOVE.w	D0, D1
	SUB.w	Player_distance.w, D0
	CMPI.w	#$00A0, D0
	BCS.b	Update_road_graphics_Sign_in_range
	MOVE.w	Player_distance.w, D0
	ADD.w	D2, D0
	SUB.w	D0, D1
	BCS.b	Update_road_graphics_Sign_skip
	BEQ.b	Update_road_graphics_Sign_skip
	MOVE.w	D1, D0
Update_road_graphics_Sign_in_range:
	MOVE.w	#$009F, D1
	SUB.w	D0, D1
	LEA	Ai_screen_y_table, A4
	MOVEQ	#0, D2
	MOVEQ	#$0000005F, D0
	MOVE.b	(A4,D1.w), D2
	CMPI.w	#$0098, D1
	BCC.b	Update_road_graphics_Sign_height_lookup
	MOVE.b	$8(A4,D1.w), D0
Update_road_graphics_Sign_height_lookup:
	SUB.b	D2, D0
	ADD.w	D2, D2
	LEA	(A5,D2.w), A5
Update_road_graphics_Sign_fill_loop:
	MOVE.w	#$FF40, (A5)+
	DBF	D0, Update_road_graphics_Sign_fill_loop
	MOVE.w	#1, Road_sign_fill_flag.w
	LEA	Player_obj_field_14.w, A0
	TST.w	Special_road_scene.w
	BEQ.b	Update_road_graphics_Bg_load
	LEA	Default_bg_scroll_row_data(PC), A0
	BRA.b	Update_road_graphics_Bg_load
Update_road_graphics_Sign_skip:
	TST.w	Use_world_championship_tracks.w
	BNE.b	Render_road_bg_entry
	TST.w	Track_index_arcade_mode.w
	BEQ.b	Render_road_bg_entry
	TST.w	Road_sign_fill_flag.w
	BEQ.b	Render_road_bg_entry
	CLR.w	Road_sign_fill_flag.w
	MOVE.w	Road_sign_rotation_index.w, D0
	ADDQ.w	#2, D0
	CMPI.w	#6, D0
	BCS.b	Update_road_graphics_Rot_wrap_done
	MOVEQ	#0, D0
Update_road_graphics_Rot_wrap_done:
	MOVE.w	D0, Road_sign_rotation_index.w
Render_road_bg_entry:
	TST.w	Track_horizon_override_flag.w
	BEQ.b	Update_road_graphics_Bg_done
	LEA	Arcade_bg_scroll_row_data(PC), A0
Update_road_graphics_Bg_load:
	LEA	(Palette_buffer+$76).w, A1
	MOVE.l	(A0)+, (A1)+
	MOVE.l	(A0)+, (A1)+
	MOVE.w	(A0), (A1)
Update_road_graphics_Bg_done:
	TST.w	Background_zone_index.w
	BEQ.b	Update_road_graphics_Road_tiles
	MOVE.w	#$FF40, D7
	MOVE.w	#$00A0, D1
	SUB.w	Background_zone_index.w, D1
	LEA	Ai_screen_y_table, A4
	MOVE.b	(A4,D1.w), D1
	MOVE.w	D1, D2
	ADD.w	D1, D1
	ADDA.w	D1, A5
	BTST.b	#0, Background_zone_0_flag_b.w
	BNE.b	Update_road_graphics_Gnd_fill
	MOVE.w	#$005F, D0
	SUB.w	D2, D0
Update_road_graphics_Sky_fill_loop:
	ADD.w	D7, (A5)+
	DBF	D0, Update_road_graphics_Sky_fill_loop
	BRA.b	Update_road_graphics_Road_tiles
Update_road_graphics_Gnd_fill:
	MOVE.w	D2, D0
Update_road_graphics_Gnd_fill_loop:
	ADD.w	D7, -(A5)
	DBF	D0, Update_road_graphics_Gnd_fill_loop
Update_road_graphics_Road_tiles:
	LEA	Road_tile_id_buf.w, A5
	LEA	Road_scanline_x_buf.w, A4
	LEA	(Sprite_attr_buf+$600).w, A1
	LEA	Screen_scroll_table_buf.w, A0
	MOVE.w	Tileset_base_offset.w, D7
	EORI.w	#$01C0, D7
	ADDA.w	D7, A0
	TST.w	Retire_flash_flag.w
	BEQ.b	Update_road_graphics_Normal_tiles
	BTST.b	#0, Frame_counter.w
	BEQ.b	Update_road_graphics_Normal_tiles
	LEA	Road_tile_offset_table(PC), A1
	MOVEQ	#$00000019, D1
Update_road_graphics_Retire_tile_loop:
	MOVE.w	(A1)+, (A0)+
	DBF	D1, Update_road_graphics_Retire_tile_loop
	MOVE.w	#$FFE2, D1
	MOVE.w	#$00C5, D0
Update_road_graphics_Retire_seq_loop:
	MOVE.w	D1, (A0)+
	SUBQ.w	#1, D1
	DBF	D0, Update_road_graphics_Retire_seq_loop
	BRA.w	Update_road_graphics_Dirty
Update_road_graphics_Normal_tiles:
	MOVEQ	#0, D5
	MOVEQ	#0, D4
	MOVEQ	#0, D1
	MOVE.w	#$00DF, D3
Update_road_graphics_Tile_loop:
	MOVE.w	(A5)+, D0
	BNE.b	Update_road_graphics_Tile_nonzero
	ADDQ.w	#2, A1
	ADDQ.w	#2, A0
	ADDQ.w	#1, D5
	ADDQ.w	#1, D4
	DBF	D3, Update_road_graphics_Tile_loop
	BRA.b	Update_road_graphics_Minimap
Update_road_graphics_Tile_nonzero:
	SUBQ.w	#1, D0
	MOVE.w	#$0190, D1
	SUB.w	D5, D1
	ADD.w	D0, D1
	ADD.w	D0, D0
	ADD.w	(A6,D0.w), D1
	MOVE.w	D1, (A0)+
	MOVE.w	(A4,D0.w), (A1)+
	ADDQ.w	#1, D5
	DBF	D3, Update_road_graphics_Tile_loop
Update_road_graphics_Minimap:
	MOVE.w	D4, Minimap_scroll_pos.w
	LEA	(Screen_scroll_table_buf+$80).w, A1
	ADDA.w	D7, A1
	CMPI.w	#2, Special_road_scene.w
	BNE.b	Update_road_graphics_Bg_scroll
	SUBI.w	#$0041, D4
	MOVE.w	#$FFC2, D3
Update_road_graphics_Tunnel_loop:
	MOVE.w	D3, (A1)+
	SUBQ.w	#1, D3
	DBF	D4, Update_road_graphics_Tunnel_loop
	BRA.b	Update_road_graphics_Road_header
Update_road_graphics_Bg_scroll:
	MOVE.w	Background_vertical_offset.w, D0
	MOVEQ	#$00000027, D1
	SUB.w	D0, D1
	MOVE.w	D1, D2
	MOVE.w	D1, Minimap_track_offset.w
	ADDI.w	#$0041, Minimap_track_offset.w
	MOVE.w	#$FFC0, D3
Update_road_graphics_Bg_col_loop:
	MOVE.w	D3, (A1)+
	SUBQ.w	#1, D3
	DBF	D1, Update_road_graphics_Bg_col_loop
	SUB.w	D2, D4
	SUBI.w	#$0042, D4
	ADDI.w	#$FFC0, D0
	LEA	$380(A1), A0
	SUBA.w	D7, A0
	MOVE.w	Player_distance_steps.w, D6
	MOVE.w	#$0048, D1
Update_road_graphics_Horizon_loop:
	MOVE.w	D6, (A0)+
	MOVE.w	D0, (A1)+
	SUBQ.w	#1, D1
	BNE.b	Update_road_graphics_Horizon_mid
	MOVE.w	#$0080, D6
Update_road_graphics_Horizon_mid:
	DBF	D4, Update_road_graphics_Horizon_loop
Update_road_graphics_Road_header:
	LEA	Screen_scroll_table_buf.w, A0
	ADDA.w	D7, A0
	LEA	Road_tile_offset_table(PC), A1
	MOVEQ	#$00000019, D0
Update_road_graphics_Road_hdr_loop:
	MOVE.w	(A1)+, (A0)+
	DBF	D0, Update_road_graphics_Road_hdr_loop
	LEA	$380(A0), A1
	SUBA.w	D7, A1
	MOVEQ	#$00000019, D6
	CMPI.w	#2, Special_road_scene.w
	BCS.b	Update_road_graphics_Normal_upper
	MOVE.w	#$FFE8, D0
Update_road_graphics_Tunnel_upper_loop:
	MOVE.w	D0, (A0)+
	ADDQ.w	#2, A1
	SUBQ.w	#1, D0
	DBF	D6, Update_road_graphics_Tunnel_upper_loop
	BRA.b	Update_road_graphics_Bg_check
Update_road_graphics_Normal_upper:
	MOVEQ	#0, D0
	SUB.w	Player_distance_steps.w, D0
	MOVE.w	#$FFF4, D1
Update_road_graphics_Normal_upper_loop:
	MOVE.w	D0, (A1)+
	MOVE.w	D1, (A0)+
	DBF	D6, Update_road_graphics_Normal_upper_loop
Update_road_graphics_Bg_check:
	TST.w	Special_road_blank_bg_flag.w
	BEQ.b	Update_road_graphics_Substep
	LEA	Blank_bg_scroll_row_data(PC), A6
	BRA.b	Update_road_graphics_Edge_write
Update_road_graphics_Substep:
	MOVEQ	#$0000000F, D0
	SUB.w	Player_distance.w, D0
	ANDI.w	#$000F, D0
	LSL.w	#6, D0
	MOVE.w	D0, D1
	ADD.w	D0, D0
	ADD.w	D1, D0
	LEA	Road_scanline_descriptor_table, A6
	ADDA.w	D0, A6
Update_road_graphics_Edge_write:
	LEA	Road_row_x_buf.w, A4
	MOVE.w	#$000B, D3
	MOVE.w	#$015C, D2
Update_road_graphics_Edge_loop:
	MOVE.w	(A6), D1
	ADDQ.w	#4, A6
	ADD.w	D2, D1
	MOVE.w	D1, (A0)+
	ADDQ.w	#1, D2
	MOVE.w	(A4)+, (A1)+
	DBF	D3, Update_road_graphics_Edge_loop
	LEA	Screen_scroll_table_buf.w, A0
	ADDA.w	D7, A0
	MOVEQ	#0, D3
	MOVE.w	Special_road_scene.w, D0
	SUBQ.w	#1, D0
	BEQ.b	Update_road_graphics_Horizon2
	SUBQ.w	#2, D0
	BNE.b	Update_road_graphics_Signs
	MOVE.w	Crash_scene_compare_depth.w, D0
	BEQ.b	Update_road_graphics_Signs
	SUBI.w	#$0080, D0
	MOVE.w	Minimap_track_offset.w, D2
	SUB.w	D0, D2
	BLS.b	Update_road_graphics_Signs
	SUBQ.w	#1, D2
	MOVE.w	#$01F2, D1
	SUB.w	D0, D1
	ADD.w	D0, D0
	LEA	$2(A0,D0.w), A2
	LEA	$380(A2), A3
	SUBA.w	D7, A3
Update_road_graphics_Horizon_center_loop:
	MOVE.w	D1, (A2)+
	MOVE.w	D3, (A3)+
	SUBQ.w	#1, D1
	DBF	D2, Update_road_graphics_Horizon_center_loop
	BRA.b	Update_road_graphics_Signs
Update_road_graphics_Horizon2:
	MOVE.w	Crash_scene_hud_span.w, D0
	BEQ.b	Update_road_graphics_Signs
	SUBI.w	#$0080, D0
	MOVE.w	Minimap_scroll_pos.w, D2
	SUB.w	D0, D2
	SUBQ.w	#2, D2
	MOVE.w	#$01F2, D1
	SUB.w	D0, D1
	ADD.w	D0, D0
	LEA	$2(A0,D0.w), A2
	LEA	$380(A2), A3
	SUBA.w	D7, A3
Update_road_graphics_Horizon2_loop:
	MOVE.w	D1, (A2)+
	MOVE.w	D3, (A3)+
	SUBQ.w	#1, D1
	DBF	D2, Update_road_graphics_Horizon2_loop
;Update_road_graphics_Signs
Update_road_graphics_Signs:
	LEA	Crash_scene_hud_span.w, A1
	MOVEQ	#1, D6
Update_road_graphics_Signs_loop:
	MOVE.w	(A1), D0
	BEQ.b	Update_road_graphics_Signs_next
	CLR.w	(A1)
	SUBI.w	#$0080, D0
	MOVE.w	D0, D1
	SUBQ.w	#6, D1
	NEG.w	D1
	ADD.w	D0, D0
	LEA	$2(A0,D0.w), A2
	MOVE.w	$2(A1), D0
Update_road_graphics_Signs_col_loop:
	MOVE.w	D1, -(A2)
	ADDQ.w	#1, D1
	DBF	D0, Update_road_graphics_Signs_col_loop
Update_road_graphics_Signs_next:
	ADDQ.w	#4, A1
	DBF	D6, Update_road_graphics_Signs_loop
	MOVEQ	#1, D6
Update_road_graphics_Signs2_loop:
	MOVE.w	(A1), D0
	BEQ.b	Update_road_graphics_Signs2_next
	CLR.w	(A1)
	SUBI.w	#$0080, D0
	MOVE.w	D0, D1
	SUBQ.w	#4, D1
	NEG.w	D1
	SUB.w	(Road_scroll_origin_x+$A).w, D1
	ADD.w	D0, D0
	LEA	$2(A0,D0.w), A2
	MOVE.w	$2(A1), D0
Update_road_graphics_Signs2_col_loop:
	MOVE.w	D1, -(A2)
	ADDQ.w	#1, D1
	DBF	D0, Update_road_graphics_Signs2_col_loop
Update_road_graphics_Signs2_next:
	ADDQ.w	#4, A1
	DBF	D6, Update_road_graphics_Signs2_loop
Update_road_graphics_Dirty:
	MOVE.w	#$FFFF, Tileset_dirty_flag.w
	RTS
Advance_player_distance:
	LEA	Player_obj.w, A0
	JSR	Compute_curve_speed_factor
	MULU.w	Player_speed.w, D0
	ADD.l	D0, $1E(A0)
	ADD.l	$1A(A0), D0
	SWAP	D0
	CMP.w	Track_length.w, D0
	BCS.b	Advance_player_distance_Swap_back
	SUB.w	Track_length.w, D0
	ADDQ.w	#1, Laps_completed.w
	MOVE.w	Track_length.w, D1
	ADD.w	D1, Total_distance.w
Advance_player_distance_Swap_back:
	SWAP	D0
	MOVE.l	D0, $1A(A0)
	TST.w	Use_world_championship_tracks.w
	BEQ.b	Update_road_graphics_Render
	TST.w	Track_index_arcade_mode.w
	BEQ.b	Update_road_graphics_Render
	MOVE.w	Player_distance.w, D4
	MOVE.w	#$00A0, D1
	MOVEQ	#1, D2
	MOVE.w	#$00AF, D3
	SUB.w	D4, D3
	CMP.w	D1, D3
	BCS.b	Update_road_graphics_Zone
	ADDQ.w	#1, D2
	MOVE.w	#$014F, D3
	SUB.w	D4, D3
	CMP.w	D1, D3
	BCS.b	Update_road_graphics_Zone
	ADDQ.w	#1, D2
	MOVE.w	Background_zone_2_distance.w, D3
	SUB.w	D4, D3
	CMP.w	D1, D3
	BCS.b	Update_road_graphics_Zone
	ADDQ.w	#1, D2
	MOVE.w	Background_zone_1_distance.w, D3
	SUB.w	D4, D3
	CMP.w	D1, D3
	BCS.b	Update_road_graphics_Zone
	MOVEQ	#0, D2
;Update_road_graphics_Zone
Update_road_graphics_Zone:
	MOVE.w	Background_zone_prev.w, D4
	MOVE.w	D2, Background_zone_prev.w
	BNE.b	Update_road_graphics_Zone_nonzero
	TST.w	D4
	BEQ.b	Update_road_graphics_Render
	CLR.w	Background_zone_index.w
	BRA.b	Update_road_graphics_Zone_signal
Update_road_graphics_Zone_nonzero:
	ADDQ.w	#1, D3
	MOVE.w	D3, Background_zone_index.w
	TST.w	D4
	BNE.b	Update_road_graphics_Render
Update_road_graphics_Zone_signal:
	MOVE.w	#2, Road_scroll_update_mode.w
;Update_road_graphics_Render
Update_road_graphics_Render:
	LEA	(Road_scale_table+$150).w, A6
	SWAP	D0
	LSR.w	#2, D0 ; D0 = steps travelled from lap marker (starts at end of track since in front of marker)
	LEA	Curve_data+1, A5
	MOVEQ	#$00000027, D7 ; =39, so max 40 loop iterations, road displacement data has at most 40 values
	MOVEQ	#0, D6
	MOVEQ	#0, D4
	MOVEQ	#-1, D1
Update_road_graphics_Read_loop: ; loop reading curve data from memory
	MOVE.b	(A5,D0.w), D2
	BPL.b	Update_road_graphics_Read_body
	MOVEQ	#0, D0
	BRA.b	Update_road_graphics_Read_loop
Update_road_graphics_Read_body:
	ADDQ.w	#1, D0
	JSR	Integrate_curveslope(PC) ; parse curve data
	BCS.b	Update_road_graphics_Read_sentinel ; road displacement was negative, stop rendering
	DBF	D7, Update_road_graphics_Read_loop
	BRA.b	Update_road_graphics_Scale_setup
Update_road_graphics_Read_sentinel:
	MOVE.w	#$8000, -(A6)
	DBF	D7, Update_road_graphics_Read_sentinel
Update_road_graphics_Scale_setup:
	LEA	Slope_scale_factors(PC), A6
	LEA	(Road_scale_table+$100).w, A5
	MOVEQ	#$00000027, D0
Update_road_graphics_Scale_loop:
	JSR	Scale_curveslope_entry(PC)
	DBF	D0, Update_road_graphics_Scale_loop
	MOVEQ	#$00000027, D1
	MOVEQ	#0, D2
	MOVEQ	#$0000005F, D3
	LEA	(Road_row_y_buf+$140).w, A6
	LEA	(Road_scale_table+$14E).w, A5 ; array output of Integrate_curveslope
	LEA	Curve_interp_segment_counts(PC), A4
Update_road_graphics_Interp_loop:
	JSR	Interpolate_curveslope_segment(PC)
	BCS.b	Update_road_graphics_Interp_sentinel
	SUBQ.w	#2, A5
	DBF	D1, Update_road_graphics_Interp_loop
	BRA.b	Update_road_graphics_X_offset
Update_road_graphics_Interp_sentinel:
	MOVE.w	#$0100, -(A6)
	DBF	D3, Update_road_graphics_Interp_sentinel
Update_road_graphics_X_offset:
	MOVEQ	#0, D5
	MOVE.w	Player_x_negated.w, D5
	SMI	D1
	BPL.b	Update_road_graphics_X_negate
	NEG.w	D5
Update_road_graphics_X_negate:
	SWAP	D5
	MOVE.w	#$0064, D6
	JSR	Divide_fractional
	TST.b	D1
	BEQ.b	Update_road_graphics_X_accum
	NEG.l	D7
Update_road_graphics_X_accum:
	MOVE.l	D7, D0
	ADD.l	D0, D0
	ADD.l	D0, D0
	ADD.l	D7, D0
	ADD.l	D7, D0
	ADDI.l	#$FF800000, D0
	LEA	Road_scanline_x_buf.w, A0
	MOVEQ	#$00000077, D6
Update_road_graphics_X_fill:
	MOVE.l	D0, (A0)
	ADDQ.w	#2, A0
	ADD.l	D7, D0
	DBF	D6, Update_road_graphics_X_fill
	LEA	Road_scanline_x_buf.w, A0
	LEA	Road_row_x_buf.w, A1
	MOVEQ	#$00000012, D0
Update_road_graphics_X_copy:
	MOVE.w	(A0), (A1)+
	ADDQ.w	#4, A0
	DBF	D0, Update_road_graphics_X_copy
	LEA	(Road_row_y_buf+$80).w, A0
	LEA	Road_scanline_x_buf.w, A1
	MOVEQ	#$0000005F, D0
Update_road_graphics_X_slope_add:
	MOVE.w	(A0)+, D1
	ADD.w	D1, (A1)+
	DBF	D0, Update_road_graphics_X_slope_add
	LEA	(Road_scale_table+$144).w, A6
	MOVE.w	Player_distance.w, D0
	LSR.w	#2, D0
	LEA	Curve_data+1, A5
	MOVEQ	#$00000021, D7
	MOVEQ	#0, D6
	MOVEQ	#0, D4
	MOVEQ	#-1, D1
Update_road_graphics_Bg_read_loop:
	MOVE.b	(A5,D0.w), D2
	BPL.b	Update_road_graphics_Bg_read_body
	MOVE.w	Track_length.w, D0
	LSR.w	#2, D0
	SUBQ.w	#1, D0
	BRA.b	Update_road_graphics_Bg_read_loop
Update_road_graphics_Bg_read_body:
	SUBQ.w	#1, D0
	JSR	Integrate_curveslope(PC) ; parse curve data (why done here also?)
	BCS.b	Update_road_graphics_Bg_read_sentinel
	DBF	D7, Update_road_graphics_Bg_read_loop
	BRA.b	Update_road_graphics_Bg_scale_setup
Update_road_graphics_Bg_read_sentinel:
	MOVE.w	#$8000, -(A6)
	DBF	D7, Update_road_graphics_Bg_read_sentinel
Update_road_graphics_Bg_scale_setup:
	LEA	Slope_scale_factors(PC), A6
	LEA	(Road_scale_table+$100).w, A5
	MOVEQ	#$00000021, D0
Update_road_graphics_Bg_scale_loop:
	JSR	Scale_curveslope_entry(PC)
	DBF	D0, Update_road_graphics_Bg_scale_loop
	MOVEQ	#$00000021, D1
	MOVEQ	#0, D2
	MOVEQ	#$00000018, D3
	LEA	(Road_bg_curve_interp_buf+$32).w, A6
	LEA	(Road_scale_table+$142).w, A5 ; array output of Integrate_curveslope
	LEA	Bg_interp_segment_counts(PC), A4
Update_road_graphics_Bg_interp_loop:
	JSR	Interpolate_curveslope_segment(PC)
	BCS.b	Update_road_graphics_Bg_interp_sentinel
	SUBQ.w	#2, A5
	DBF	D1, Update_road_graphics_Bg_interp_loop
	BRA.b	Update_road_graphics_Bg_combine_setup
Update_road_graphics_Bg_interp_sentinel:
	MOVE.w	#$0100, -(A6)
	DBF	D3, Update_road_graphics_Bg_interp_sentinel
Update_road_graphics_Bg_combine_setup:
	LEA	Road_bg_curve_interp_buf.w, A0
	LEA	Road_row_x_buf.w, A1
	MOVEQ	#$00000018, D0
Update_road_graphics_Bg_combine_loop:
	MOVE.w	(A0), D1
	ADD.w	D1, (A1)+
	ADDQ.w	#4, A0
	DBF	D0, Update_road_graphics_Bg_combine_loop
	RTS
Update_slope_data:
; Rebuild the 40-entry slope displacement table for the current track position.
; Called from Race_loop step 13 whenever the player advances.
;
; Steps:
;  1. Look up physical slope byte at Physical_slope_data[Player_distance/4] and
;     store at Track_phys_slope_value (used by Update_rpm to apply hill RPM drag).
;  2. Call Integrate_curveslope 40 times for the slope data stream at
;     Visual_slope_data+1, storing 40 signed displacement words descending from
;     $FFFF984E (A6 -= 2 each call).  Sentinel (carry set) fills remainder
;     with $8000.
;  3. Scale the integrated entries using Scale_curveslope_entry and a
;     look-up table at loc_6EBE (40 reciprocal scale factors).
;  4. Interpolate the scaled slope entries into the 96-entry display buffer
;     at $FFFF97C0 using Interpolate_curveslope_segment and a segment-count
;     table at Curve_interp_segment_counts.
;  5. Add a ramp offset (0..47) to each of the 96 display entries to produce
;     the final per-scanline slope contribution.
;  6. Push a snapshot of the current register set into $FFFF9AC0 (8×14 regs)
;     using MOVEM to allow the road renderer to replay the slope state.
;  7. Build the road-centre vertical position lookup at $FFFF9900 from the
;     slope data at $FFFF9700 using a gap-fill scan for the rival-car sprite.
	MOVE.w	Player_distance.w, D0
	LSR.w	#2, D0
	LEA	Physical_slope_data, A5
	MOVE.b	(A5,D0.w), D1 ; physical slope at current track step (index = Player_distance/4)
	EXT.w	D1
	MOVE.w	D1, Track_phys_slope_value.w
	LEA	(Road_scale_table+$150).w, A6
	LEA	Visual_slope_data+1, A5 ; visual slope data stream (+1 to skip sentinel byte)
	MOVEQ	#$00000027, D7
	MOVEQ	#0, D6
	MOVEQ	#0, D4
	MOVEQ	#-1, D1
Update_slope_data_Read_loop:
	MOVE.b	(A5,D0.w), D2
	BPL.b	Update_slope_data_Read_body
	MOVEQ	#0, D0
	BRA.b	Update_slope_data_Read_loop
Update_slope_data_Read_body:
	ADDQ.w	#1, D0
	JSR	Integrate_curveslope(PC) ; parse slope data
	BCS.b	Update_slope_data_Read_sentinel
	DBF	D7, Update_slope_data_Read_loop
	BRA.b	Update_slope_data_Scale_setup
Update_slope_data_Read_sentinel:
	MOVE.w	#$8000, -(A6)
	DBF	D7, Update_slope_data_Read_sentinel
Update_slope_data_Scale_setup:
	LEA	Slope_scale_factors(PC), A6
	LEA	(Road_scale_table+$100).w, A5
	MOVEQ	#$00000027, D0
Update_slope_data_Scale_loop:
	JSR	Scale_curveslope_entry(PC)
	DBF	D0, Update_slope_data_Scale_loop
	MOVEQ	#$00000027, D1
	MOVEQ	#0, D2
	MOVEQ	#$0000005F, D3
	LEA	(Road_scale_table+$C0).w, A6
	LEA	(Road_scale_table+$14E).w, A5 ; array output of Integrate_curveslope
	LEA	Curve_interp_segment_counts(PC), A4
Update_slope_data_Interp_loop:
	JSR	Interpolate_curveslope_segment(PC)
	BCS.b	Update_slope_data_Interp_sentinel
	SUBQ.w	#2, A5
	DBF	D1, Update_slope_data_Interp_loop
	BRA.b	Update_slope_data_Ramp_setup
Update_slope_data_Interp_sentinel:
	MOVE.w	#$0100, -(A6)
	DBF	D3, Update_slope_data_Interp_sentinel
Update_slope_data_Ramp_setup:
	LEA	(Road_scale_table+$C0).w, A1
	MOVEQ	#0, D6
	MOVEQ	#$0000002F, D7
Update_slope_data_Ramp_loop:
	MOVE.w	-(A1), D0
	ADD.w	D6, D0
	MOVE.w	D0, (A1)
	MOVE.w	-(A1), D0
	ADD.w	D6, D0
	MOVE.w	D0, (A1)
	ADDQ.w	#1, D6
	DBF	D7, Update_slope_data_Ramp_loop
	MOVEM.l	$00FF5980, D0-D7/A0-A3/A4/A5
	LEA	Sprite_attr_buf.w, A6
	MOVEM.l	A5/A4/A3/A2/A1/A0/D7/D6/D5/D4/D3/D2/D1/D0, -(A6)
	MOVEM.l	A5/A4/A3/A2/A1/A0/D7/D6/D5/D4/D3/D2/D1/D0, -(A6)
	MOVEM.l	A5/A4/A3/A2/A1/A0/D7/D6/D5/D4/D3/D2/D1/D0, -(A6)
	MOVEM.l	A5/A4/A3/A2/A1/A0/D7/D6/D5/D4/D3/D2/D1/D0, -(A6)
	MOVEM.l	A5/A4/A3/A2/A1/A0/D7/D6/D5/D4/D3/D2/D1/D0, -(A6)
	MOVEM.l	A5/A4/A3/A2/A1/A0/D7/D6/D5/D4/D3/D2/D1/D0, -(A6)
	MOVEM.l	A5/A4/A3/A2/A1/A0/D7/D6/D5/D4/D3/D2/D1/D0, -(A6)
	MOVEM.l	A5/A4/A3/A2/A1/A0/D7/D6/D5/D4/D3/D2/D1/D0, -(A6)
	LEA	(Player_obj+$DA).w, A2
	CLR.w	(A2)
	LEA	Road_scale_table.w, A1
	LEA	Road_tile_id_buf.w, A0
	MOVE.w	(A1)+, D0
	BMI.w	Update_slope_data_Rts
	MOVE.w	D0, D6
	MOVE.w	D0, D3
	MOVE.w	#$00DF, D2
	SUB.w	D0, D2
	BMI.w	Update_slope_data_Rts
	ADD.w	D2, D2
	ADDA.w	D2, A0
	MOVEQ	#1, D1
	MOVEQ	#1, D2
	MOVE.w	#$005E, D7
Update_slope_data_Ycenter_loop:
	CMP.w	(A1), D3
	BPL.b	Update_slope_data_Ycenter_no_peak
	MOVE.w	(A1), D3
	MOVE.w	D1, (A2)
Update_slope_data_Ycenter_no_peak:
	MOVE.w	(A1)+, D0
	SUB.w	D0, D6
	BEQ.b	Update_slope_data_Ycenter_equal
	BPL.b	Update_slope_data_Ycenter_above
Update_slope_data_Ycenter_below:
	MOVE.w	D1, -(A0)
	ADDQ.w	#1, D6
	BNE.b	Update_slope_data_Ycenter_below
	BRA.b	Update_slope_data_Ycenter_next
Update_slope_data_Ycenter_above:
	ADDQ.w	#2, A0
	MOVE.w	D1, (A0)
	SUBQ.w	#1, D6
	BNE.b	Update_slope_data_Ycenter_above
	BRA.b	Update_slope_data_Ycenter_next
Update_slope_data_Ycenter_equal:
	MOVE.w	D1, (A0)
Update_slope_data_Ycenter_next:
	ADD.w	D2, D1
	MOVE.w	D0, D6
	DBF	D7, Update_slope_data_Ycenter_loop
Update_slope_data_Rts:
	RTS
Road_tile_offset_table:
	dc.w	$0004
	dc.w	$0003
	dc.w	$0002
	dc.w	$0001
	dc.w	$0000
	dc.w	$FFFF
	dc.w	$FFFE
	dc.w	$FFFD
	dc.w	$FFFC
	dc.w	$FFFB
	dc.w	$FFFA
	dc.w	$FFF9
	dc.w	$FFF8
	dc.w	$FFF7
	dc.w	$FFF6
	dc.w	$FFF5
	dc.w	$FFF4
	dc.w	$FFF3
	dc.w	$FFF2
	dc.w	$FFF1
	dc.w	$FFF0
	dc.w	$FFEF
	dc.w	$FFEE
	dc.w	$FFED
	dc.w	$FFE9
	dc.w	$FFE8
Slope_scale_factors:
	dc.w	$1000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$11BE
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$1447
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$16D0
	dc.w	$0000
	dc.w	$0000
	dc.w	$1959
	dc.w	$0000
	dc.w	$1BE2
	dc.w	$0000
	dc.w	$1E6A
	dc.w	$0000
	dc.w	$20F3
	dc.w	$237C
	dc.w	$2605
	dc.w	$0000
	dc.w	$288E
	dc.w	$2B17
	dc.w	$3029
	dc.w	$32B1
	dc.w	$37C3
	dc.w	$3A4C
	dc.w	$41E7
	dc.w	$46F8
	dc.w	$4E93
	dc.w	$58B6
	dc.w	$67EC
	dc.w	$79AA
	dc.w	$9303
	dc.w	$BB90
Curve_interp_segment_counts:
	dc.w	$001C
	dc.w	$0010
	dc.w	$000A
	dc.w	$0007
	dc.w	$0006
	dc.w	$0004
Bg_interp_segment_counts:
	dc.w	$0003
	dc.w	$0002
	dc.w	$0003
	dc.w	$0001
	dc.w	$0002
	dc.w	$0001
	dc.w	$0002
	dc.w	$0001
	dc.w	$0000
	dc.w	$0001
	dc.w	$0001
	dc.w	$0001
	dc.w	$0000
	dc.w	$0001
	dc.w	$0000
	dc.w	$0001
	dc.w	$0000
	dc.w	$0001
	dc.w	$0000
	dc.w	$0000
	dc.w	$0001
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0001
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0001
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0001
Integrate_curveslope:
; Stepwise integrator for curve or slope data.  Appends one displacement word
; to the output array at A6 (A6 decrements by 2 each call).  Looks up the
; road displacement value for the current streak from Road_displacement_table
; via A4.  A new A4 pointer is loaded only when D2 changes from the previous
; call (start of a new turn / gradient streak).  Returns with carry clear on
; success, carry set when the displacement table sentinel is reached (end of
; streak data).
; Used for curve data (called from loc_6BDA / loc_6C4C) and slope data
; (called from Update_slope_data) to produce per-step road graphical offsets.
; Left turn / down slope → negative displacement; right turn / up slope → positive.
; Inputs:
;  D0 = track step index (distance travelled)
;  D1 = curve/slope byte from previous step, initially -1 (forces table reload)
;  D2 = curve/slope byte for current step
;  D4 = accumulated integral (initially 0); written as word to (A6), A6 -= 2
;  D6 = streak integral accumulator (initially 0); bit 31 = direction flag
;  A4 = Road_displacement_table pointer for current streak (updated when D2 changes)
;  A6 = output array pointer (word, predecrement)
	CMP.b	D2, D1
	BEQ.b	Integrate_curveslope_Accum ; jump if same curve/slope data as last step (continues with precious A4 value)
	MOVE.w	D2, D1
	ANDI.w	#$003F, D2
	BEQ.b	Integrate_curveslope_Flat ; jump if straight/flat
	ADD.w	D2, D2                  ; ...
	ADD.w	D2, D2                  ; ...
	LEA	Road_displacement_table, A4 ; ...
	MOVEA.l	(A4,D2.w), A4           ; new road displacement table lookup when curve/slope data changed from previous step (begin new "streak")
Integrate_curveslope_Flat:
	MOVE.w	D1, D2 ; = curve/slope data for step
	MOVE.w	D6, D3 ; previous curve/slope "streak" integral used as starting point
	TST.l	D6
	BMI.b	Integrate_curveslope_Accum ; jump if previous turn was right turn/up slope
	NEG.w	D3
Integrate_curveslope_Accum:
	TST.b	D2
	BNE.b	Integrate_curveslope_Curved ; jump if not 0 (not straight/flat road)
	ADD.w	D3, D4 ; accumulate integral
	MOVE.w	D4, -(A6) ; output
	BRA.b	Integrate_curveslope_Rts
Integrate_curveslope_Curved:
	BCLR.l	#6, D2
	BNE.b	Integrate_curveslope_Right ; jump if right turn/up slope
	BCLR.l	#$1F, D6
	MOVE.w	(A4)+, D6 ; = this steps road displacement
	BMI.b	Integrate_curveslope_Sentinel ; jump if end of displacement data
	SUB.w	D3, D6 ; add integral from previous curve/slope "streak"
	SUB.w	D6, D4 ; accumulate integral
	MOVE.w	D4, -(A6) ; output
	BRA.b	Integrate_curveslope_Rts
Integrate_curveslope_Right:
	BSET.l	#$1F, D6
	MOVE.w	(A4)+, D6 ; = this steps road displacement
	BMI.b	Integrate_curveslope_Sentinel ; jump if end of displacement data
	ADD.w	D3, D6 ; add integral from previous curve/slope "streak"
	ADD.w	D6, D4 ; accumulate integral
	MOVE.w	D4, -(A6) ; output
Integrate_curveslope_Rts:
	OR.w	D0, D0 ; clear carry flag
	RTS
Integrate_curveslope_Sentinel:
	ORI	#1, CCR ; set carry flag
	RTS
;Interpolate_curveslope_segment
Interpolate_curveslope_segment:
	MOVE.w	(A4)+, D6
	BEQ.b	Interpolate_curveslope_Rts
	CMPI.w	#1, D6
	BEQ.b	Interpolate_curveslope_One
	MOVE.w	(A5), D0
	CMPI.w	#$8000, D0
	BEQ.b	Interpolate_curveslope_Sentinel
	MOVEQ	#0, D5
	MOVE.w	D2, D5
	SUB.w	D0, D5
	SMI	D4
	BPL.b	Interpolate_curveslope_Pos
	NEG.w	D5
Interpolate_curveslope_Pos:
	SWAP	D5
	JSR	Divide_fractional
	TST.b	D4
	BEQ.b	Interpolate_curveslope_Interp
	NEG.l	D7
Interpolate_curveslope_Interp:
	MOVEQ	#0, D0
	MOVE.w	D2, D0
	SUBQ.w	#1, D6
Interpolate_curveslope_Loop:
	MOVE.w	D0, -(A6)
	SUBQ.w	#1, D3
	SWAP	D0
	SUB.l	D7, D0
	SWAP	D0
	DBF	D6, Interpolate_curveslope_Loop
	MOVE.w	(A5), D2
	BRA.b	Interpolate_curveslope_Rts
Interpolate_curveslope_One:
	MOVE.w	(A5), D2
	CMPI.w	#$8000, D2
	BEQ.b	Interpolate_curveslope_Sentinel
	MOVE.w	D2, -(A6)
	SUBQ.w	#1, D3
Interpolate_curveslope_Rts:
	OR.w	D0, D0
	RTS
Interpolate_curveslope_Sentinel:
	ORI	#1, CCR
	RTS
;Scale_curveslope_entry
Scale_curveslope_entry:
	MOVE.w	(A5), D1
	BEQ.b	Scale_curveslope_Skip_advance
	CMPI.w	#$8000, D1
	BEQ.b	Scale_curveslope_Skip_advance
	TST.w	D1
	SMI	D2
	BPL.b	Scale_curveslope_Positive
	NEG.w	D1
Scale_curveslope_Positive:
	MOVE.w	(A6)+, D3
	BEQ.b	Scale_curveslope_Advance
	MULU.w	D3, D1
	CMPI.l	#$01000000, D1
	BCS.b	Scale_curveslope_In_range
	MOVE.w	#$8000, D1
	BRA.b	Scale_curveslope_Store
Scale_curveslope_In_range:
	SWAP	D1
	TST.b	D2
	BEQ.b	Scale_curveslope_Store
	NEG.w	D1
Scale_curveslope_Store:
	MOVE.w	D1, (A5)+
	RTS
Scale_curveslope_Skip_advance:
	ADDQ.w	#2, A6
Scale_curveslope_Advance:
	ADDQ.w	#2, A5
	RTS
Update_road_tile_scroll:
; Update the per-scanline HScroll table in the $FFFFF600 work buffer and
; optionally update the road edge guard-rail tile positions.
; Called once per frame from Race_loop (step 16).
;
; Steps:
;  1. If $FFFF9280 == 0, skip scroll rebuild and jump directly to the curve
;     interpolation section.
;  2. Select source road scroll table based on Background_zone_index:
;     zone 0 → $FFFFD400/$FFFFD900, other → $FFFFD680/$FFFFE000.
;  3. Call Copy_displacement_rows_to_work_buffer to populate $FFFFF600.
;  4. If $FFFF9280 == 2, skip guard-rail update (jump to Update_road_tile_scroll_clear).
;  5. Determine road edge tile column positions from $FFFFAFD6/$FFFFAFD8
;     (player horizontal position / road width), clamp to 12 road rows.
;  6. Call Fill_table_stride_loop twice to write left/right guard-rail tile
;     indices at the computed column positions across the scroll table.
;  7. At Update_road_tile_scroll_curve: Regardless of $FFFF9280, process 7 curve interpolation
;     rows at $FFFF9658 using $FFFF91BA (previous values); compare old vs new
;     displacement and interpolate intermediate scroll values in $FFFFEA00
;     buffers for smooth curve entry/exit transitions.
;  8. Clear $FFFF9280, set $FFFF9282 = 1 (scroll updated flag).
	TST.w	Road_scroll_update_mode.w
	BEQ.w	Update_road_tile_scroll_curve
	TST.w	Background_zone_index.w
	BNE.b	Update_road_tile_scroll_zone_b
	LEA	Ui_tilemap_panel_a.w, A0
	LEA	Ui_tilemap_scratch_a.w, A1
	BRA.b	Update_road_tile_scroll_copy
Update_road_tile_scroll_zone_b:
	LEA	Ui_tilemap_panel_a_copy.w, A0
	LEA	Ui_tilemap_scratch_b.w, A1
Update_road_tile_scroll_copy:
	JSR	Copy_displacement_rows_to_work_buffer(PC)
	CMPI.w	#2, Road_scroll_update_mode.w
	BEQ.w	Update_road_tile_scroll_clear
	MOVE.l	#$04420442, D3
	CMPI.w	#1, Special_road_scene.w
	BNE.b	Update_road_tile_scroll_rail
	MOVE.l	#$04320432, D3
Update_road_tile_scroll_rail:
	LEA	Road_hscroll_buf.w, A0
	LEA	(Road_scanline_x_buf+$8).w, A1
	MOVEQ	#$0000007C, D4
	MOVE.w	(Road_scroll_origin_x-2).w, D7
	SUBI.w	#$012E, D7
	LSR.w	#2, D7
	CMPI.w	#$000B, D7
	BLS.b	Update_road_tile_scroll_rail_row
	MOVEQ	#$0000000B, D7
Update_road_tile_scroll_rail_row:
	MOVE.w	(A1), D1
	NEG.w	D1
	ANDI.w	#$01FF, D1
	MOVE.w	Road_scroll_origin_x.w, D0
	SUBI.w	#$00A0, D0
	BMI.b	Update_road_tile_scroll_rail_right
	MOVE.w	D0, D5
	LSR.w	#3, D5
	ADD.w	D1, D0
	LSR.w	#3, D0
	MOVE.w	D0, D2
	ADD.w	D2, D2
	SUBQ.w	#2, D2
	MOVE.w	D5, D0
	LSR.w	#1, D0
	ADDQ.w	#1, D0
	MOVEQ	#-4, D5
	JSR	Fill_table_stride_loop(PC)
Update_road_tile_scroll_rail_right:
	MOVE.w	(Main_object_pool+$298).w, D0
	SUBI.w	#$0060, D0
	BPL.b	Update_road_tile_scroll_rail_right_ok
	MOVEQ	#0, D0
Update_road_tile_scroll_rail_right_ok:
	MOVE.w	#$0118, D5
	CMP.w	D5, D0
	BCC.b	Update_road_tile_scroll_rail_next
	SUB.w	D0, D5
	ADD.w	D1, D0
	LSR.w	#3, D0
	MOVE.w	D0, D2
	ADD.w	D2, D2
	LSR.w	#4, D5
	MOVE.w	D5, D0
	MOVEQ	#4, D5
	JSR	Fill_table_stride_loop(PC)
Update_road_tile_scroll_rail_next:
	LEA	$10(A1), A1
	LEA	$80(A0), A0
	DBF	D7, Update_road_tile_scroll_rail_row
Update_road_tile_scroll_clear:
	CLR.w	Road_scroll_update_mode.w
	MOVE.w	#1, Road_scroll_updated_flag.w
Update_road_tile_scroll_curve:
	LEA	Road_curve_interp_buf.w, A0
	LEA	Road_curve_prev_buf.w, A1
	LEA	Tilemap_work_buf.w, A2
	MOVE.w	#$FFF8, D7
	MOVEQ	#0, D0
	MOVEQ	#6, D2
Update_road_tile_scroll_curve_row:
	LEA	(A2), A3
	LEA	$C0(A2), A4
	MOVE.w	(A1), D6
	MOVE.w	(A0), D5
	MOVE.w	D5, (A1)
	CMP.w	D5, D6
	BEQ.w	Update_road_tile_scroll_next_row
	BLT.w	Update_road_tile_scroll_left
	NEG.w	D5
	NEG.w	D6
	AND.w	D7, D5
	AND.w	D7, D6
	SUB.w	D6, D5
	BPL.b	Update_road_tile_scroll_right_abs
	NEG.w	D5
Update_road_tile_scroll_right_abs:
	CMPI.w	#$0080, D5
	BCS.b	Update_road_tile_scroll_right_clamp
	MOVE.w	#$0080, D5
Update_road_tile_scroll_right_clamp:
	LSR.w	#3, D5
	MOVE.w	D5, D3
	MOVE.w	D6, D4
	ADDI.w	#$0120, D6
	LSR.w	#2, D6
	ANDI.w	#$007E, D6
	ADDI.w	#$0220, D4
	LSR.w	#2, D4
	ANDI.w	#$00FE, D4
	LEA	Ui_tilemap_scratch_b.w, A5
	LEA	Ui_tilemap_scratch_a.w, A6
	ADDA.w	D0, A5
	ADDA.w	D0, A6
Update_road_tile_scroll_right_fill:
	MOVE.w	(A5,D4.w), (A3)+
	MOVE.w	(A6,D4.w), (A4)+
	ADDQ.w	#2, D4
	ANDI.w	#$00FE, D4
	DBF	D5, Update_road_tile_scroll_right_fill
	MOVE.w	D3, D5
	MOVE.w	D6, $8(A1)
	MOVE.w	#$007E, D4
	SUB.w	D6, D4
	LSR.w	#1, D4
	CMP.w	D3, D4
	BCC.b	Update_road_tile_scroll_right_write1
	MOVE.w	#2, $2(A1)
	SUB.w	D4, D5
	SUBQ.w	#1, D5
	MOVE.w	D4, $4(A1)
	MOVE.w	D5, $6(A1)
	BRA.w	Update_road_tile_scroll_zone_copy
Update_road_tile_scroll_right_write1:
	MOVE.w	#1, $2(A1)
	MOVE.w	D3, $4(A1)
	BRA.w	Update_road_tile_scroll_zone_copy
Update_road_tile_scroll_left:
	NEG.w	D5
	NEG.w	D6
	AND.w	D7, D5
	AND.w	D7, D6
	SUB.w	D5, D6
	BPL.b	Update_road_tile_scroll_left_abs
	NEG.w	D6
Update_road_tile_scroll_left_abs:
	CMPI.w	#$0080, D6
	BCS.b	Update_road_tile_scroll_left_clamp
	MOVE.w	#$0080, D6
Update_road_tile_scroll_left_clamp:
	LSR.w	#3, D6
	MOVE.w	D6, D3
	MOVE.w	D5, D4
	SUBI.w	#$0028, D5
	LSR.w	#2, D5
	ANDI.w	#$007E, D5
	ADDI.w	#$00D8, D4
	LSR.w	#2, D4
	ANDI.w	#$00FE, D4
	LEA	Ui_tilemap_scratch_b.w, A5
	LEA	Ui_tilemap_scratch_a.w, A6
	ADDA.w	D0, A5
	ADDA.w	D0, A6
Update_road_tile_scroll_left_fill:
	MOVE.w	(A5,D4.w), (A3)+
	MOVE.w	(A6,D4.w), (A4)+
	ADDQ.w	#2, D4
	ANDI.w	#$00FE, D4
	DBF	D6, Update_road_tile_scroll_left_fill
	MOVE.w	D3, D6
	MOVE.w	D5, $8(A1)
	MOVE.w	#$007E, D4
	SUB.w	D5, D4
	LSR.w	#1, D4
	CMP.w	D3, D4
	BCC.b	Update_road_tile_scroll_left_write1
	MOVE.w	#2, $2(A1)
	SUB.w	D4, D6
	SUBQ.w	#1, D6
	MOVE.w	D4, $4(A1)
	MOVE.w	D6, $6(A1)
	BRA.b	Update_road_tile_scroll_zone_copy
Update_road_tile_scroll_left_write1:
	MOVE.w	#1, $2(A1)
	MOVE.w	D3, $4(A1)
Update_road_tile_scroll_zone_copy:
	LEA	(A2), A3
	LEA	$60(A2), A4
	LEA	$C0(A2), A5
	LEA	$120(A2), A6
	TST.w	Background_zone_index.w
	BEQ.b	Update_road_tile_scroll_zone_a_copy
Update_road_tile_scroll_zone_b_copy:
	MOVE.w	(A3), (A4)+
	MOVE.w	(A5), (A6)
	EORI.w	#$6000, (A3)+
	ANDI.w	#$DFFF, (A5)+
	ANDI.w	#$BFFF, (A6)+
	DBF	D3, Update_road_tile_scroll_zone_b_copy
	BRA.b	Update_road_tile_scroll_next_row
Update_road_tile_scroll_zone_a_copy:
	MOVE.w	(A5), (A4)+
	MOVE.w	(A5), (A6)
	EORI.w	#$6000, (A3)+
	ANDI.w	#$DFFF, (A5)+
	ANDI.w	#$BFFF, (A6)+
	DBF	D3, Update_road_tile_scroll_zone_a_copy
Update_road_tile_scroll_next_row:
	LEA	$10(A0), A0
	LEA	$A(A1), A1
	LEA	$180(A2), A2
	ADDI.w	#$0100, D0
	DBF	D2, Update_road_tile_scroll_curve_row
	RTS
Flush_vdp_mode_and_signs:
	CMPI.w	#2, Road_column_update_state.w
	BNE.b	Flush_vdp_mode_and_signs_Check
	JSR	Set_vdp_mode_h32_variant_b
Flush_vdp_mode_and_signs_Check:
	TST.w	Road_scroll_updated_flag.w
	BEQ.b	Flush_vdp_mode_and_signs_Skip
	MOVE.w	#$977F, D7
	MOVE.l	#$96FB9500, D6
	MOVE.l	#$94039300, D5
	MOVE.l	#$4D000083, Vdp_dma_setup.w
	JSR	Send_D567_to_VDP
	CLR.w	Road_scroll_updated_flag.w
	RTS
Flush_vdp_mode_and_signs_Skip:
	JMP	Send_sign_tileset_to_VDP
Upload_tilemap_rows_to_vdp:
	MOVE.l	#$49800003, D0
	LEA	Tilemap_row_upload_queue.w, A0
	LEA	VDP_data_port, A1
	LEA	Tilemap_work_buf.w, A2
	MOVEQ	#6, D1
Upload_tilemap_rows_to_vdp_Slot_loop:
	TST.w	(A0)
	BEQ.b	Upload_tilemap_rows_to_vdp_Next_slot
	LEA	(A2), A3
	MOVE.l	D0, D2
	MOVEQ	#3, D3
Upload_tilemap_rows_to_vdp_Strip_loop:
	LEA	(A3), A4
	MOVEQ	#0, D7
	MOVE.w	$6(A0), D7
	SWAP	D7
	ADD.l	D2, D7
	MOVE.l	D7, $4(A1)
	MOVE.w	$2(A0), D4
Upload_tilemap_rows_to_vdp_Row1_loop:
	MOVE.w	(A4)+, (A1)
	DBF	D4, Upload_tilemap_rows_to_vdp_Row1_loop
	CMPI.w	#1, (A0)
	BEQ.b	Upload_tilemap_rows_to_vdp_Strip_next
	MOVE.l	D2, $4(A1)
	MOVE.w	$4(A0), D4
Upload_tilemap_rows_to_vdp_Row2_loop:
	MOVE.w	(A4)+, (A1)
	DBF	D4, Upload_tilemap_rows_to_vdp_Row2_loop
Upload_tilemap_rows_to_vdp_Strip_next:
	LEA	$60(A3), A3
	ADDI.l	#$06000000, D2
	DBF	D3, Upload_tilemap_rows_to_vdp_Strip_loop
	CLR.w	(A0)
Upload_tilemap_rows_to_vdp_Next_slot:
	ADDI.l	#$00800000, D0
	LEA	$A(A0), A0
	LEA	$180(A2), A2
	DBF	D1, Upload_tilemap_rows_to_vdp_Slot_loop
	RTS
;Fill_table_stride_loop
Fill_table_stride_loop:
	AND.w	D4, D2
	MOVE.l	D3, (A0,D2.w)
	ADD.w	D5, D2
	DBF	D0, Fill_table_stride_loop
	RTS
Arcade_bg_scroll_row_data:
	dc.b	$02, $C6, $02, $A2, $00, $62, $02, $68, $02, $22
Default_bg_scroll_row_data:
	dc.b	$00, $00, $00, $00, $08, $88, $08, $88
	dc.w	$0888
Blank_bg_scroll_row_data:
	dc.w	$FF40
	dc.b	$00, $00
	dc.w	$FF40
	dc.b	$00, $00
	dc.w	$FF40
	dc.b	$00, $00
	dc.w	$FF40
	dc.b	$00, $00
	dc.w	$FF40
	dc.b	$00, $00
	dc.w	$FF40
	dc.b	$00, $00
	dc.w	$FF40
	dc.b	$00, $00
	dc.w	$FF40
	dc.b	$00, $00
	dc.w	$FF40
	dc.b	$00, $00
	dc.w	$FF40
	dc.b	$00, $00
	dc.w	$FF40
	dc.b	$00, $00
	dc.w	$FF40
	dc.b	$00, $00, $FF, $40, $00, $00, $FF, $40, $00, $00, $FF, $40, $00, $00, $FF, $40, $00, $00, $FF, $40, $00, $00, $FF, $40, $00, $00, $FF, $40, $00, $00, $FF, $40
	dc.b	$00, $00, $FF, $40, $00, $00, $FF, $40, $00, $00, $FF, $40, $00, $00, $FF, $40, $00, $00
Arcade_placement_seq_v1:
	dc.w	$000E
	dc.b	$00, $0C, $00, $0B, $00, $0A, $00, $09, $00, $08, $00, $07, $00, $06, $00, $05
Arcade_placement_seq_v2:
	dc.w	$000B
	dc.b	$00, $0A, $00, $09, $00, $08, $00, $07, $00, $06, $00, $05, $00, $03, $00, $02
