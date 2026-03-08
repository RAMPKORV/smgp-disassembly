; 3-entry pointer table into sprite records embedded just before Credits_tiles.
; Verified with smgp.lst: $000281E6, $000281AE, and $00028140.
Credits_car_frame_table:
	dc.l	Credits_car_frame_f
	dc.l	Credits_car_frame_b
	dc.l	Credits_car_frame_a
Credits_asset_list:
	dc.b	$00, $02
	dc.b	$00, $20
	dc.l	Credits_tiles
	dc.b	$43, $60
	dc.l	Credits_tiles_2
	dc.b	$63, $20
	dc.l	Credits_tiles_3
