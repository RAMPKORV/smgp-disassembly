Result_decomp_list:
	dc.b	$4E, $80, $00, $03
	dc.l	Result_tiles_a
	dc.b	$60, $E0, $00, $1F, $00, $0B, $4E, $C0, $00, $03
	dc.l	Result_tiles_b
	dc.b	$60, $E0, $00, $1F, $00, $0B, $4E, $00, $00, $03
	dc.l	Result_tiles_c
	dc.b	$60, $E0, $00, $1F, $00, $0B, $4E, $40, $00, $03
	dc.l	Result_tiles_d
	dc.b	$60, $E0, $00, $1F, $00, $0B, $55, $44, $00, $00
	dc.l	Result_tiles_e
	dc.b	$00, $E0, $00, $0B, $00, $03, $59, $40, $00, $00
	dc.l	Result_tiles_f
	dc.b	$A0, $E0, $00, $14, $00, $02
Result_tilemap_list:
	dc.l	$53840003
	dc.l	Result_screen_tile_col_b
	dc.b	$53, $98, $00, $03
	dc.l	Result_screen_tile_col_a
	dc.b	$53, $A0, $00, $03
	dc.l	Result_screen_tile_col_c
	dc.b	$53, $A4, $00, $03
	dc.l	Result_screen_tile_col_a
	dc.b	$53, $E8, $00, $03
	dc.l	Result_screen_tile_col_c
	dc.b	$53, $F8, $00, $03
	dc.l	Result_screen_tile_col_a
	dc.b	$53, $FC, $00, $03
	dc.l	Result_screen_tile_col_b
	dc.b	$53, $08, $00, $03
	dc.l	Result_screen_tile_col_a
