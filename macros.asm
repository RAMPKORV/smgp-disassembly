txt macro
escape = 0
i = 0
	while i<strlen(\1)
c substr 1+i,1+i,\1
	if escape=0
		if "\c"="\"
escape = 1
		elseif ("\c"="'")
				dc.b    $26
		elseif ("\c"='"')
				dc.b    $27
		elseif ("\c"="?")
				dc.b    $2E
		elseif ("\c"=".")
				dc.b    $29
		elseif ("\c"=",")
				dc.b    $2A
		elseif ("\c"="/")
				dc.b    $2B
		elseif ("\c"="-")
				dc.b    $2C
		elseif ("\c"="!")
				dc.b    $2D
		elseif ("\c"=" ")
			dc.b	$32
		elseif ("\c"="(")
			dc.b	$34
		elseif ("\c"=")")
			dc.b	$35
		elseif ("\c">="0")&("\c"<="9")
			dc.b	("\c"-"0")
		elseif ("\c">="A")&("\c"<="Z")
			dc.b	("\c"-"A")+$0A
		endif
	else
		; newline
		if "\c"="n"
			dc.b	$FC
		else
			inform 2,"Invalid escape character '%s'", "\c"
		endif
escape = 0
	endif
i = i+1
	endw
	rept narg-1
		shift
		dc.b \1
	endr
	endm

VRAM = %100001
CRAM = %101011
VSRAM = %100101

READ = %001100
WRITE = %000111
DMA = %100111

vdpComm macro addr,type,rwd,dest
	MOVE.l	#((((\2&\3)&3)<<30)|((\1&$3FFF)<<16)|(((\2&\3)&$FC)<<2)|((\1&$C000)>>14)), \4
	endm

VdpRowAdvance macro reg
	ADDI.l	#$00800000, \1
	endm

stopZ80 macro
	MOVE.w	#$0100, Z80_bus_request
.loop\@:
	BTST.b	#0, Z80_bus_request
	BNE.b	.loop\@
	endm

startZ80 macro
	MOVE.w	#0, Z80_bus_request
	endm

InterruptDisable macro
	ORI	#$0700, SR
	endm

InterruptEnable macro
	ANDI	#$F8FF, SR
	endm

InitH40ClearObjects macro
	JSR	Fade_palette_to_black
	JSR	Initialize_h40_vdp_state
	JSR	Clear_main_object_pool
	endm

WaitTwoVblanks macro
	JSR	Wait_for_vblank
	JSR	Wait_for_vblank
	endm

EnableDisplay macro
	MOVE.w	#1, Vblank_enable.w
	MOVE.w	#$8174, VDP_control_port
	endm

EnableDisplay_Rts macro
	EnableDisplay
	RTS
	endm

SetH40MenuRegs macro
	MOVE.w	#$8238, VDP_control_port
	MOVE.w	#$9011, VDP_control_port
	MOVE.w	#$9280, VDP_control_port
	endm

VdpWriteD7D0 macro
	InterruptDisable
	MOVE.l	D7, VDP_control_port
	MOVE.w	D0, VDP_data_port
	InterruptEnable
	endm

EnableDisplayAfterWait macro
	InterruptEnable
	WaitTwoVblanks
	EnableDisplay_Rts
	endm

HaltAudioAndEnableAfterWait macro
	MOVE.l	#$000003D8, Vblank_callback.w
	JSR	Halt_audio_sequence
	EnableDisplayAfterWait
	endm

InterruptWaitEnable_Rts macro
	InterruptEnable
	JSR	Wait_for_vblank
	EnableDisplay_Rts
	endm

DrawPackedTilemapInterrupt_Rts macro
	InterruptDisable
	JSR	Draw_packed_tilemap_to_vdp
	InterruptEnable
	RTS
	endm

GetPlayerAndRivalTeamsD0D1 macro
	MOVE.b	Player_team.w, D0
	MOVE.b	Rival_team.w, D1
	ANDI.b	#$0F, D0 ; isolate the player's team number
	ANDI.b	#$0F, D1 ; isolate the rival's team number
	endm

ReturnToTitleMenu macro
	MOVE.w	#9, Selection_count.w
	MOVE.l	#Title_menu, Frame_callback.w
	RTS
	endm

SetPlayerTeamChampionship_Rts macro
	BCLR.b	#4, Player_team.w
	BSET.b	#5, Player_team.w
	RTS
	endm

DecompressTilemap64_27x1B macro
	MOVE.l	#$40000003, D7
	MOVEQ	#$00000027, D6
	MOVEQ	#$0000001B, D5
	JSR	Decompress_tilemap_to_vdp_64_cell_rows
	endm
