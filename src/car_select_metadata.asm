TeamMachineScreenStats:
; 7 bytes per team (16 teams + 1 sentinel), loaded by Load_team_machine_stats.
; Bytes 0-4: ENG, T.M, SUS., TIRE, BRA. bar heights (0x00-0x64) for the machine screen display
;            Written to Tire_stat_max_0..4 ($FFFF9010-$FFFF9018) via two-copy method
;            (each bar written twice to separate even/odd VDP tile columns)
; Byte 5   : Unused by Load_team_machine_stats (padding / unknown purpose)
;            Values 0-3; possibly a visual curve type index for the car stats screen
; Byte 6   : Per-tick tire wear delta applied to all 5 Tire_stat_delta entries ($FFFF9025,9027,9029,902B,902D)
;            Lower value = slower tire wear = better durability in race
; Row 17 ($FF sentinel): terminates the table; $04 in byte 6 is the fallback tire wear delta
	dc.b	$64, $64, $50, $64, $64 ; Madonna ENG/TM/SUS/TIRE/BRA bars
	dc.b	$00, $05               ; pad=$00  tire_wear_delta=$05
	dc.b	$50, $64, $64, $5A, $64 ; Firenze
	dc.b	$02, $04               ; pad=$02  tire_wear_delta=$04
	dc.b	$64, $50, $5A, $50, $64 ; Millions
	dc.b	$01, $05               ; pad=$01  tire_wear_delta=$05
	dc.b	$64, $3C, $64, $64, $64 ; Bestowal
	dc.b	$03, $05               ; pad=$03  tire_wear_delta=$05
	dc.b	$50, $50, $50, $50, $50 ; Blanche
	dc.b	$01, $05               ; pad=$01  tire_wear_delta=$05
	dc.b	$3C, $64, $3C, $50, $64 ; Tyrant
	dc.b	$02, $03               ; pad=$02  tire_wear_delta=$03
	dc.b	$64, $3C, $50, $50, $50 ; Losel
	dc.b	$03, $04               ; pad=$03  tire_wear_delta=$04
	dc.b	$3C, $50, $3C, $3C, $50 ; May
	dc.b	$02, $03               ; pad=$02  tire_wear_delta=$03
	dc.b	$3C, $3C, $46, $3C, $3C ; Bullets
	dc.b	$03, $03               ; pad=$03  tire_wear_delta=$03
	dc.b	$50, $32, $32, $3C, $28 ; Dardan
	dc.b	$01, $05               ; pad=$01  tire_wear_delta=$05
	dc.b	$50, $28, $50, $50, $50 ; Linden
	dc.b	$03, $01               ; pad=$03  tire_wear_delta=$01
	dc.b	$50, $3C, $28, $32, $28 ; Minarae
	dc.b	$03, $04               ; pad=$03  tire_wear_delta=$04
	dc.b	$5A, $1E, $3C, $3C, $28 ; Rigel
	dc.b	$03, $01               ; pad=$03  tire_wear_delta=$01
	dc.b	$50, $1E, $3C, $28, $28 ; Comet
	dc.b	$01, $02               ; pad=$01  tire_wear_delta=$02
	dc.b	$3C, $28, $28, $3C, $28 ; Orchis
	dc.b	$03, $02               ; pad=$03  tire_wear_delta=$02
	dc.b	$50, $1E, $3C, $3C, $14 ; Zeroforce
	dc.b	$01, $03               ; pad=$01  tire_wear_delta=$03
	dc.b	$FF, $FF, $FF, $FF, $FF, $04, $FF, $00 ; sentinel: $FF bars, fallback tire_wear_delta=$04
Car_select_bg_vdp_stream:
	dc.b	$42, $1E, $00, $00, $0E, $EE, $08, $00, $00, $22, $0C, $66, $00, $00, $00, $00, $00, $00, $00, $00, $00, $CC, $0C, $C0, $0A, $CC, $02, $43, $02, $44, $00, $00
	dc.b	$02, $66, $00, $00, $00, $EE, $0E, $EE, $02, $22, $06, $66, $04, $4E, $00, $0A, $00, $EE, $00, $88, $04, $44, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
Driver_portrait_palette_streams:
	dc.b	$02, $0E
	dc.w	$0000, $0000, $068C, $0004, $0248, $0000, $0466, $0000, $000C, $0008, $08AC, $046A, $0024, $0000, $0244
	dc.b	$02, $0E
	dc.w	$0000, $0000, $068C, $0006, $0248, $0ECC, $0A88, $0246, $022C, $000A, $08AC, $046A, $0024, $0004, $0866
	dc.b	$02, $0E
	dc.w	$0000, $0000, $08AC, $068C, $046A, $0248, $0024, $0246, $00AE, $0888, $0CCC, $020A, $0006, $044E, $0888
	dc.b	$02, $0E
	dc.w	$0000, $0688, $068C, $0EEE, $0248, $0ACE, $0246, $0468, $0ACC, $08AA, $08AC, $046A, $0024, $068A, $0964
	dc.b	$02, $0E
	dc.w	$0000, $0000, $068C, $0ACE, $0248, $0ACE, $08AC, $0468, $0068, $028A, $08AC, $046A, $0024, $0000, $0046
	dc.b	$02, $0E
	dc.w	$0000, $0000, $068C, $0ACE, $0248, $0A22, $0888, $0800, $0A44, $0CCC, $08AC, $046A, $0024, $0666, $0244
	dc.b	$02, $0E
	dc.w	$0000, $0000, $068C, $0222, $0248, $0ACE, $0220, $0662, $0882, $0440, $08AC, $046A, $0024, $0888, $0466
	dc.b	$02, $0E
	dc.w	$0000, $0000, $068C, $0000, $0248, $0000, $0000, $0000, $0242, $0A84, $08AC, $046A, $0024, $0022, $0244
	dc.b	$02, $0E
	dc.w	$0000, $0000, $068C, $08AC, $0248, $0468, $0246, $0222, $0444, $0888, $08AE, $046A, $0024, $0666, $0244
	dc.b	$02, $0E
	dc.w	$0000, $0000, $068C, $0444, $0248, $0ACE, $0CCC, $0888, $0E44, $0A00, $08AC, $046A, $0024, $0C22, $0466
	dc.b	$02, $0E
	dc.w	$0000, $0000, $068C, $0CCC, $0248, $0AAA, $0004, $0008, $000A, $0000, $08AC, $046A, $0024, $0000, $0866
	dc.b	$02, $0E
	dc.w	$0000, $0000, $068C, $0EEE, $0248, $0ACE, $0C22, $0444, $0222, $0888, $08AE, $046A, $0024, $0600, $0864
	dc.b	$02, $0E
	dc.w	$0000, $0000, $068C, $0000, $0248, $0006, $000C, $0CCE, $0008, $0004, $08AC, $046A, $0024, $000A, $0244
	dc.b	$02, $0E
	dc.w	$0000, $0664, $068C, $0ACE, $0248, $0000, $0000, $00CE, $008A, $0046, $08AC, $046A, $0024, $0000, $0000
	dc.b	$02, $0E
	dc.w	$0000, $0664, $068C, $0ACE, $0248, $00AC, $0EEE, $00CE, $008A, $0046, $08AC, $046A, $0024, $0AAA, $0888
	dc.b	$02, $0E
	dc.w	$0000, $0240, $068C, $0ACE, $0248, $0888, $0EEE, $04CE, $008C, $0444, $08AC, $046A, $0024, $0664, $0480
	dc.b	$02, $0E, $00, $00, $00, $00, $06, $8C, $08, $88, $02, $48, $04, $44, $0C, $CC, $0A, $22, $00, $AC, $0E, $66, $08, $AC, $04, $6A, $00, $24, $08, $02, $02, $44
	dc.b	$02, $0E, $00, $00, $00, $00, $06, $8C, $08, $88, $02, $48, $04, $44, $0C, $CC, $0A, $22, $00, $AC, $0E, $66, $08, $AC, $04, $6A, $00, $24, $08, $02, $02, $44
DriverPortraitTileMappings:
	dc.l	Driver_portrait_tilemap_Ceara ; G. Ceara
	dc.l	Driver_portrait_tilemap_Asselin ; A. Asslin
	dc.l	Driver_portrait_tilemap_Elssler ; F. Elssler
	dc.l	Driver_portrait_tilemap_Alberti ; G. Alberti
	dc.l	Driver_portrait_tilemap_Picos ; A. Picos
	dc.l	Driver_portrait_tilemap_Herbin ; J. Herbin
	dc.l	Driver_portrait_tilemap_Hamano ; M. Hamano
	dc.l	Driver_portrait_tilemap_Pacheco ; E. Pacheco
	dc.l	Driver_portrait_tilemap_Turner ; G. Turner
	dc.l	Driver_portrait_tilemap_Miller ; B. Miller
	dc.l	Driver_portrait_tilemap_Bellini ; E. Bellini
	dc.l	Driver_portrait_tilemap_Moreau ; M. Moreau
	dc.l	Driver_portrait_tilemap_Cotman ; R. Cotman
	dc.l	Driver_portrait_tilemap_Tornio ; E. Tornio
	dc.l	Driver_portrait_tilemap_Tegner ; C. Tegner
	dc.l	Driver_portrait_tilemap_Klinger ; P. Klinger
	dc.l	Driver_portrait_tilemap_Player ; You
	dc.l	Driver_portrait_tilemap_Player	; You
