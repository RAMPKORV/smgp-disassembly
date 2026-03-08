Race_hud_tiles_g:
	dc.b	$00, $0D, $80, $06, $34, $17, $77, $26, $36, $36, $37, $48, $FA, $56, $33, $66, $3A, $75, $12, $81, $04, $06, $15, $0F, $25, $13, $37, $7C, $48, $FB, $66, $3C
	dc.b	$76, $38, $82, $05, $18, $83, $04, $08, $17, $76, $84, $03, $00, $15, $15, $27, $7B, $85, $03, $02, $17, $7A, $86, $05, $14, $26, $32, $87, $05, $0E, $15, $16
	dc.b	$88, $16, $39, $89, $06, $35, $8D, $03, $01, $15, $17, $FF, $6E, $9B, $A7, $E6, $32, $B7, $7F, $E3, $5B, $4F, $E2, $D2, $DF, $B3, $54, $B7, $EC, $D5, $2D, $FC
	dc.b	$3A, $39, $7F, $5B, $B6, $81, $F4, $73, $04, $27, $47, $68, $A3, $D3, $F5, $FC, $43, $0F, $D2, $EB, $CE, $93, $D7, $F5, $0A, $AD, $FA, $8D, $65, $29, $75, $8C
	dc.b	$E3, $38, $EB, $0E, $A6, $F8, $CB, $D0, $C7, $ED, $BF, $47, $95, $87, $ED, $BF, $4F, $CD, $1C, $9C, $FE, $6D, $F3, $F1, $1A, $BB, $EF, $F3, $2E, $FB, $FC, $CF
	dc.b	$F4, $65, $29, $4A, $59, $C6, $3E, $B1, $F5, $DB, $EA, $33, $8D, $FF, $2D, $1B, $64, $ED, $B2, $71, $D3, $2B, $3F, $27, $19, $FE, $5A, $D3, $1F, $A7, $9D, $4B
	dc.b	$9E, $18, $29, $94, $6B, $33, $0C, $44, $C3, $02, $BE, $54, $89, $FB, $22, $63, $F5, $A1, $E3, $F9, $B2, $CE, $31, $B4, $7E, $4A, $3B, $C6, $23, $7F, $C9, $4B
	dc.b	$66, $07, $76, $17, $D9, $E4, $2C, $AA, $5F, $47, $30, $3F, $62, $FF, $2B, $79, $D6, $E1, $E4, $7E, $F5, $FF, $ED, $44, $7F, $B4, $7A, $FE, $68, $78, $3F, $B4
	dc.b	$FD, $EB, $20, $47, $26, $B7, $F6, $45, $C7, $E9, $43, $2B, $D6, $E1, $87, $EB, $7D, $DF, $BC, $7F, $8B, $B4, $A5, $2D, $C1, $04, $10, $51, $45, $14, $7F, $EB
	dc.b	$C7, $1C, $71, $C1, $79, $79, $64, $51, $45, $7F, $F7, $FF, $A4, $78, $BC, $5E, $2F, $11, $45, $14, $7F, $E8, $47, $F7, $40, $00, $00
;Crash_rpm_gauge_palette_table
Crash_rpm_gauge_palette_table:
	; 8-byte records consumed by Crash_obj_gauge_write:
	;   bytes 0-2 = 24-bit gauge threshold/state value
	;   bytes 3-6 = pointer to a palette write stream consumed by Write_3_palette_vdp_bytes
	; The pointed-to streams start with a sprite-count byte and then 7-byte sprite/tile tuples.
	dc.b	$7F, $80
	dc.b	$80
	dc.l	Crash_rpm_gauge_palette_0
	dc.b	$00, $7F, $81
	dc.b	$00
	dc.l	Crash_rpm_gauge_palette_0
	dc.b	$00, $7F, $81
	dc.b	$80
	dc.l	Crash_rpm_gauge_palette_1
	dc.b	$00, $7F, $82
	dc.b	$20
	dc.l	Crash_rpm_gauge_palette_2
	dc.b	$00, $7F, $82
	dc.b	$D0
	dc.l	Crash_rpm_gauge_palette_3
	dc.b	$00, $7F, $83
	dc.b	$80
	dc.l	Crash_rpm_gauge_palette_4
	dc.b	$00, $7F, $84
	dc.b	$40
	dc.l	Crash_rpm_gauge_palette_5
	dc.b	$00, $7F, $85
	dc.b	$00
	dc.l	Crash_rpm_gauge_palette_6
	dc.b	$00, $7F, $85
	dc.b	$B0
	dc.l	Crash_rpm_gauge_palette_7
	dc.b	$00, $7F, $86
	dc.b	$80
	dc.l	Crash_rpm_gauge_palette_8
	dc.b	$00, $7F, $87
	dc.b	$40
	dc.l	Crash_rpm_gauge_palette_9
	dc.b	$00, $7F, $88
	dc.b	$10
	dc.l	Crash_rpm_gauge_palette_10
	dc.b	$00, $7F, $89
	dc.b	$00
	dc.l	Crash_rpm_gauge_palette_11
	dc.b	$00, $7F, $89
	dc.b	$D0
	dc.l	Crash_rpm_gauge_palette_12
	dc.b	$00, $7F, $8A
	dc.b	$90
	dc.l	Crash_rpm_gauge_palette_13
	dc.b	$00, $7F, $8B
	dc.b	$60
	dc.l	Crash_rpm_gauge_palette_14
	dc.b	$00, $7F, $8C
	dc.b	$30
	dc.l	Crash_rpm_gauge_palette_15
	dc.b	$00, $7F, $8D
	dc.b	$10
	dc.l	Crash_rpm_gauge_palette_16
	dc.b	$00, $7F, $8D
	dc.b	$E0
	dc.l	Crash_rpm_gauge_palette_17
	dc.b	$00, $7F, $8E
	dc.b	$B0
	dc.l	Crash_rpm_gauge_palette_18
	dc.b	$00, $7F, $8F
	dc.b	$70
	dc.l	Crash_rpm_gauge_palette_19
	dc.b	$00, $7F, $90
	dc.b	$40
	dc.l	Crash_rpm_gauge_palette_20
	dc.b	$00, $7F, $91
	dc.b	$00
	dc.l	Crash_rpm_gauge_palette_21
	dc.b	$00, $7F
	dc.b	$91
	dc.b	$A0
	dc.l	Crash_rpm_gauge_palette_21
;Crash_rpm_gauge_palette_0
Crash_rpm_gauge_palette_0:
	dc.b	$00, $01, $B0, $0C, $84, $52, $00, $00, $B0, $0C, $84, $56, $00, $20
;Crash_rpm_gauge_palette_1
Crash_rpm_gauge_palette_1:
	dc.b	$00, $02, $B0, $0C, $84, $52, $00, $00, $B0, $04, $84, $56, $00, $20
	dc.b	$B8, $0C, $84, $58, $00, $20
;Crash_rpm_gauge_palette_2
Crash_rpm_gauge_palette_2:
	dc.b	$00, $02, $B0, $04, $84, $52, $00, $00, $B0, $09, $84, $54, $00, $10
	dc.b	$B8, $08, $84, $5A, $00, $28
;Crash_rpm_gauge_palette_3
Crash_rpm_gauge_palette_3:
	dc.b	$00, $03, $B0, $0C, $84, $52, $00, $00, $B8, $0C, $84, $56, $00, $10
	dc.b	$B8, $00, $84, $5A, $00, $30, $C0, $04, $84, $5B, $00, $30
;Crash_rpm_gauge_palette_4
Crash_rpm_gauge_palette_4:
	dc.b	$00, $03, $B0, $08, $84, $52, $00, $00, $B8, $0C, $84, $55, $00, $08
	dc.b	$B8, $00, $84, $59, $00, $28, $C0, $0C, $84, $5A, $00, $20
;Crash_rpm_gauge_palette_5
Crash_rpm_gauge_palette_5:
	dc.b	$00, $03, $B0, $08, $84, $52, $00, $00, $B8, $0C, $84, $55, $00, $08
	dc.b	$C0, $08, $84, $59, $00, $20, $C8, $04, $84, $5C, $00, $30
;Crash_rpm_gauge_palette_6
Crash_rpm_gauge_palette_6:
	dc.b	$00, $03, $B0, $04, $84, $52, $00, $00, $B8, $08, $84, $54, $00, $08
	dc.b	$C0, $08, $84, $57, $00, $18, $C8, $08, $84, $5A, $00, $28
;Crash_rpm_gauge_palette_7
Crash_rpm_gauge_palette_7:
	dc.b	$00, $04, $B0, $04, $84, $52, $00, $00, $B8, $08, $84, $54, $00, $08
	dc.b	$C0, $08, $84, $57, $00, $10, $C8, $08, $84, $5A, $00, $20, $D0, $04
	dc.b	$84, $5D, $00, $30
;Crash_rpm_gauge_palette_8
Crash_rpm_gauge_palette_8:
	dc.b	$00, $04, $B0, $04, $84, $52, $00, $00, $B8, $08, $84, $54, $00, $00
	dc.b	$C0, $04, $84, $57, $00, $10, $C8, $08, $84, $59, $00, $18, $D0, $04
	dc.b	$84, $5C, $00, $28
;Crash_rpm_gauge_palette_9
Crash_rpm_gauge_palette_9:
	dc.b	$00, $05, $B0, $04, $84, $52, $00, $00, $B8, $08, $84, $54, $00, $00
	dc.b	$C0, $04, $84, $57, $00, $10, $C8, $04, $84, $59, $00, $18, $D0, $04
	dc.b	$84, $5B, $00, $20, $D8, $04, $84, $5D, $00, $28
;Crash_rpm_gauge_palette_10
Crash_rpm_gauge_palette_10:
	dc.b	$00, $05, $B0, $04, $84, $52, $00, $00, $B8, $08, $84, $54, $00, $00
	dc.b	$C0, $08, $84, $57, $00, $08, $C8, $08, $84, $5A, $00, $10, $D0, $04
	dc.b	$84, $5D, $00, $18, $D8, $04, $84, $5F, $00, $20
;Crash_rpm_gauge_palette_11
Crash_rpm_gauge_palette_11:
	dc.b	$00, $05, $B0, $05, $84, $52, $00, $00, $C0, $04, $84, $56, $00, $08
	dc.b	$C8, $04, $84, $58, $00, $10, $D0, $04, $84, $5A, $00, $18, $D8, $04
	dc.b	$84, $5C, $00, $20, $E0, $00, $84, $5E, $00, $28
;Crash_rpm_gauge_palette_12
Crash_rpm_gauge_palette_12:
	dc.b	$00, $05, $B0, $01, $84, $52, $00, $00, $B8, $01, $84, $54, $00, $08
	dc.b	$C0, $01, $84, $56, $00, $10, $C8, $01, $84, $58, $00, $18, $D8, $04
	dc.b	$84, $5A, $00, $18, $E0, $04, $84, $5C, $00, $20
;Crash_rpm_gauge_palette_13
Crash_rpm_gauge_palette_13:
	dc.b	$00, $05, $B0, $01, $84, $52, $00, $00, $B8, $02, $84, $54, $00, $08
	dc.b	$C0, $02, $84, $57, $00, $10, $D0, $01, $84, $5A, $00, $18, $E0, $04
	dc.b	$84, $5C, $00, $18, $E8, $00, $84, $5E, $00, $20
;Crash_rpm_gauge_palette_14
Crash_rpm_gauge_palette_14:
	dc.b	$00, $04, $B0, $02, $84, $52, $00, $00, $B8, $02, $84, $55, $00, $08
	dc.b	$C8, $02, $84, $58, $00, $10, $D8, $01, $84, $5B, $00, $18, $E8, $04
	dc.b	$84, $5D, $00, $18
;Crash_rpm_gauge_palette_15
Crash_rpm_gauge_palette_15:
	dc.b	$00, $05, $B0, $00, $84, $52, $00, $00, $B8, $05, $84, $53, $00, $00
	dc.b	$C8, $05, $84, $57, $00, $08, $D8, $00, $84, $5B, $00, $10, $E0, $04
	dc.b	$84, $5C, $00, $10, $E8, $01, $84, $5E, $00, $18
;Crash_rpm_gauge_palette_16
Crash_rpm_gauge_palette_16:
	dc.b	$00, $05, $B0, $00, $84, $52, $00, $00, $B8, $05, $84, $53, $00, $00
	dc.b	$C8, $01, $84, $57, $00, $08, $D0, $02, $84, $59, $00, $10, $E8, $04
	dc.b	$84, $5C, $00, $10, $F0, $00, $84, $5E, $00, $18
;Crash_rpm_gauge_palette_17
Crash_rpm_gauge_palette_17:
	dc.b	$00, $04, $B0, $01, $84, $52, $00, $00, $C0, $05, $84, $54, $00, $00
	dc.b	$D0, $00, $84, $58, $00, $08, $D8, $05, $84, $59, $00, $08, $E8, $01
	dc.b	$84, $5D
	dc.b	$00, $10
;Crash_rpm_gauge_palette_18
Crash_rpm_gauge_palette_18:
	dc.b	$00, $04, $B0, $01, $84, $52, $00, $00, $C0, $05, $84, $54, $00, $00
	dc.b	$D0, $02, $84, $58, $00, $08, $E8, $04, $84, $5B, $00, $08, $F0, $00
	dc.b	$84, $5D, $00, $10
;Crash_rpm_gauge_palette_19
Crash_rpm_gauge_palette_19:
	dc.b	$00, $02, $B0, $02, $84, $52, $00, $00, $C8, $06, $84, $55, $00, $00
	dc.b	$E0, $03, $84, $5B, $00, $08
;Crash_rpm_gauge_palette_20
Crash_rpm_gauge_palette_20:
	dc.b	$00, $03, $B0, $03, $84, $52, $00, $00, $D0, $01, $84, $56, $00, $00
	dc.b	$E0, $05, $84, $58, $00, $00, $F0, $01, $84, $5C, $00, $08
;Crash_rpm_gauge_palette_21
Crash_rpm_gauge_palette_21:
	dc.b	$00, $02, $B0, $03, $84, $52, $00, $00, $D0, $03, $84, $56, $00, $00
	dc.b	$F0, $01, $84, $5A, $00, $00, $00
;Crash_sync_gauge_palette_table
Crash_sync_gauge_palette_table:
	; Same 8-byte record format as Crash_rpm_gauge_palette_table, but indexed by the
	; synced crash-gauge state copied from Player_obj+$28.
	dc.b	$7F, $94
	dc.b	$30
	dc.l	Crash_sync_gauge_palette_6
	dc.b	$00, $7F, $93
	dc.b	$80
	dc.l	Crash_sync_gauge_palette_5
	dc.b	$00, $7F, $92
	dc.b	$C0
	dc.l	Crash_sync_gauge_palette_4
	dc.b	$00, $7F, $92
	dc.b	$40
	dc.l	Crash_sync_gauge_palette_3
	dc.b	$00, $7F, $92
	dc.b	$C0
	dc.l	Crash_sync_gauge_palette_2
	dc.b	$00, $7F, $93
	dc.b	$80
	dc.l	Crash_sync_gauge_palette_1
	dc.b	$00, $7F, $94
	dc.b	$30
	dc.l	Crash_sync_gauge_palette_0
;Crash_sync_gauge_palette_0
Crash_sync_gauge_palette_0:
	dc.b	$00, $02, $E8, $04, $84, $61, $FF, $FA, $F0, $0D, $84, $63, $FF, $F2
	dc.b	$F8, $00, $84, $6B, $FF, $EA
;Crash_sync_gauge_palette_1
Crash_sync_gauge_palette_1:
	dc.b	$00, $02, $E8, $04, $84, $61, $FF, $F8, $F0, $0D, $84, $63, $FF, $F0
	dc.b	$F8, $00, $84, $6B, $FF, $E8
;Crash_sync_gauge_palette_2
Crash_sync_gauge_palette_2:
	dc.b	$00, $02, $E8, $04, $84, $61, $FF, $E9, $F0, $0D, $84, $63, $FF, $E9
	dc.b	$F0, $01, $84, $6B, $00, $09
;Crash_sync_gauge_palette_3
Crash_sync_gauge_palette_3:
	dc.b	$00, $02, $F8, $04, $84, $61, $FF, $EC, $F0, $0C, $84, $63, $FF, $F4
	dc.b	$F8, $04, $84, $67, $00, $04
;Crash_sync_gauge_palette_4
Crash_sync_gauge_palette_4:
	dc.b	$00, $02, $E8, $04, $8C, $61, $00, $07, $F0, $0D, $8C, $63, $FF, $F7
	dc.b	$F0, $01, $8C, $6B, $FF, $EF
;Crash_sync_gauge_palette_5
Crash_sync_gauge_palette_5:
	dc.b	$00, $02, $E8, $04, $8C, $61, $FF, $F8, $F0, $0D, $8C, $63, $FF, $F0
	dc.b	$F8, $00, $8C, $6B, $00, $10
;Crash_sync_gauge_palette_6
Crash_sync_gauge_palette_6:
	dc.b	$00, $02, $E8, $04, $8C, $61, $FF, $F6, $F0, $0D, $8C, $63, $FF, $EE
	dc.b	$F8, $00, $8C, $6B, $00, $0E, $00
;Crash_collision_palette_table
Crash_collision_palette_table:
	dc.b	$7F, $9D
	dc.b	$E0
	dc.b	$00, $7F, $A2
	dc.b	$60
	dc.b	$00, $7F, $9E
	dc.b	$A0
	dc.b	$00, $7F, $A3
	dc.b	$20
	dc.b	$00, $7F, $9F
	dc.b	$60
	dc.b	$00, $7F, $A3
	dc.b	$E0
	dc.b	$00, $7F, $9B
	dc.b	$A0
	dc.b	$00, $7F, $A0
	dc.b	$20
	dc.b	$00, $7F, $9C
	dc.b	$60
	dc.b	$00, $7F, $A0
	dc.b	$E0
	dc.b	$00, $7F, $9D
	dc.b	$20
	dc.b	$00, $7F, $A1
	dc.b	$A0
	dc.b	$00, $7F, $99
	dc.b	$60
	dc.b	$00, $7F, $97
	dc.b	$20
	dc.b	$00, $7F, $9A
	dc.b	$20
	dc.b	$00, $7F, $97
	dc.b	$E0
	dc.b	$00, $7F, $9A
	dc.b	$E0
	dc.b	$00, $7F, $98
	dc.b	$A0
	dc.b	$00, $7F, $94
	dc.b	$E0
	dc.b	$00, $7F, $94
	dc.b	$E0
	dc.b	$00, $7F, $95
	dc.b	$A0
	dc.b	$00, $7F, $95
	dc.b	$A0
	dc.b	$00, $7F, $96
	dc.b	$60
	dc.b	$00, $7F, $96
	dc.b	$60
	dc.b	$00, $7F, $97
	dc.b	$20
	dc.b	$00, $7F, $99
	dc.b	$60
	dc.b	$00, $7F, $97
	dc.b	$E0
	dc.b	$00, $7F, $9A
	dc.b	$20
	dc.b	$00, $7F, $98
	dc.b	$A0
	dc.b	$00, $7F, $9A
	dc.b	$E0
	dc.b	$00, $7F, $A0
	dc.b	$20
	dc.b	$00, $7F, $9B
	dc.b	$A0
	dc.b	$00, $7F, $A0
	dc.b	$E0
	dc.b	$00, $7F, $9C
	dc.b	$60
	dc.b	$00, $7F, $A1
	dc.b	$A0
	dc.b	$00, $7F, $9D
	dc.b	$20
	dc.b	$00, $7F, $A2
	dc.b	$60
	dc.b	$00, $7F, $9D
	dc.b	$E0
	dc.b	$00, $7F, $A3
	dc.b	$20
	dc.b	$00, $7F, $9E
	dc.b	$A0
	dc.b	$00, $7F, $A3
	dc.b	$E0
	dc.b	$00, $7F, $9F
	dc.b	$60
