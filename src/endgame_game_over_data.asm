Game_over_screen_asset_list:
	dc.b	$00, $01
	dc.l	Game_over_screen_text_score
	dc.l	Game_over_screen_text_drivers
Game_over_screen_text_score:
	dc.b	$E5, $06, $FB, $67, $C0, $22, $18, $1E, $26, $1F, $0E, $FA, $0D, $18, $17, $0E, $FA, $12, $1D, $2D, $FF, $00
Game_over_screen_text_drivers:
	dc.b	$E8, $8A, $22, $18, $1E, $1B, $FA, $15, $12, $0C, $0E, $17, $1C, $0E, $FC, $17, $18, $29, $FA, $04, $06, $00, $00, $2C, $1D, $11, $06, $09, $FF, $00
