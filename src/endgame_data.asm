Arcade_car_spec_asset_list:
	dc.b	$00, $01
	dc.b	$00, $20
	dc.l	Arcade_car_spec_tiles
	dc.b	$1C, $A0
	dc.l	Arcade_car_spec_tiles_b
; 4 object records: y.w, x.w, sprite-frame ptr.l.
; The frame pointers target embedded sprite records inside Arcade_car_spec_palette_stream.
Arcade_car_spec_car_positions:
	dc.w	$00BD, $00CC
	dc.l	Arcade_car_spec_car_frame_a
	dc.w	$0126, $00BF
	dc.l	Arcade_car_spec_car_frame_b
	dc.w	$018A, $00CB
	dc.l	Arcade_car_spec_car_frame_c
	dc.w	$00E7, $00B0
	dc.l	Arcade_car_spec_car_frame_d
Arcade_car_spec_tilemap_list:
	dc.b	$00, $01
	dc.l	Arcade_car_spec_tilemap_a
	dc.l	Arcade_car_spec_tilemap_b
Arcade_car_spec_tilemap_a:
	dc.l	$E786FBC7
	dc.l	$C0FA150A
	dc.l	$19FAFAFA
	dc.l	$1D12160E
	dc.l	$FCFDFA01
	dc.l	$1C1DFCFA
	dc.l	$02170DFC
	dc.l	$FA031B0D
	dc.l	$FCFD1D18
	dc.l	$1D0A15FF
Arcade_car_spec_tilemap_b:
	dc.l	$EB260D1B
	dc.l	$121F0E1B
	dc.l	$261CFA19
	dc.l	$1812171D
	dc.l	$1CFF87D9
Endgame_car_anim_tile_table:
	; 9 longs = 18 tile words copied directly to the VDP tilemap buffer by
	; Draw_tilemap_buffer_to_vdp_64_cell_rows. Values in the $87xx range are tile IDs,
	; not executable pointers, even when they coincide with code addresses in smgp.lst.
	dc.l	$87DB87CE
	dc.l	$87D987CA
	dc.l	$87DB87CE
	dc.l	$000087DD
	dc.l	$87D80000
	dc.l	$87C287D7
	dc.l	$87CD0000
	dc.l	$87DB87CA
	dc.l	$87CC87CE
Arcade_car_spec_stat_ptrs:
	dc.l	Lap_time_table_ptr
	dc.l	Lap_time_table_ptr+4
	dc.l	Lap_time_table_ptr+8
	dc.l	Rival_race_time_bcd
Arcade_car_spec_vdp_addrs:
	dc.w	$E890, $E990, $EA90, $EC10
