Race_finish_asset_list:
	dc.b	$00, $01
	dc.b	$00, $20
	dc.l	Race_finish_tiles
	dc.b	$2D, $E0
	dc.l	Race_finish_tiles_2
Race_finish_tilemap_list:
	dc.b	$00, $01
	dc.l	Race_finish_text_mode_text
	dc.l	Race_finish_text_driver_text
Race_finish_text_mode_text:
	dc.b	$E4, $B0, $FB, $C7, $C0, $FA, $15, $0A, $19, $FA, $FA, $FA, $1D, $12, $16, $0E, $FC, $FD, $FA, $01, $1C, $1D, $FC, $FA, $02, $17, $0D, $FC, $FA, $03, $1B, $0D
	dc.b	$FC, $FD, $1D, $18, $1D, $0A, $15, $FF
Race_finish_text_driver_text:
	dc.b	$EB, $2E, $0D, $1B, $12, $1F, $0E, $1B, $26, $1C, $FA, $19, $18, $12, $17, $1D, $1C, $FF
Race_finish_lap_time_ptrs:
	dc.l	Lap_time_table_ptr
	dc.l	Lap_time_table_ptr+4
	dc.l	Lap_time_table_ptr+8
	dc.l	Rival_race_time_bcd
Race_finish_tile_attr_data:
	dc.l	$E5BAE6BA
	dc.l	$E7BAE93A
Race_finish_buffer_ptr_table:
	dc.l	Tilemap_work_buf
	dc.l	Tilemap_work_buf+$152
	dc.l	Tilemap_work_buf+$2A4
	dc.l	Tilemap_work_buf+$152
