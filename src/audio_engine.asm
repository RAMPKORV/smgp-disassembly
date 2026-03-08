Halt_audio_sequence:
; Stop the current audio sequence immediately.
; Writes the halt sentinel ($8000) to Audio_seq_timer (Audio_engine_state+$22).
; The per-frame Update_audio_engine routine treats a negative sequence timer as
; the halted state and performs a full channel reset at loc_76176.
; OR.w D0,D0 sets Z so callers can test for silence/ready state.
	MOVE.w	#$8000, Audio_seq_timer
	OR.w	D0, D0
	RTS
;Trigger_music_mode_1
Trigger_music_mode_1:
; Trigger audio playback in mode 1.
; Writes byte $01 to Audio_ctrl_mode (Audio_engine_state+$24 / $FF5AE4).
; The Update_audio_engine routine reads this byte each frame; when non-zero it
; dispatches the pending per-channel command (loc_761C4) and clears the latch.
; OR.w D0,D0 preserves D0 for the caller.
	MOVE.b	#1, Audio_ctrl_mode
	OR.w	D0, D0
	RTS
;Trigger_music_playback
Trigger_music_playback:
; Trigger standard music playback.
; Writes byte $80 to Audio_ctrl_mode (Audio_engine_state+$24 / $FF5AE4).
; Mode $80 causes Update_audio_engine to latch the music command from
; Audio_music_cmd (+$00) and send it to the Z80 as a song-start byte
; ($80 + song_id) via Z80_audio_music_cmd ($A01C09).
; OR.w D0,D0 preserves D0 for the caller.
	MOVE.b	#$80, Audio_ctrl_mode
	OR.w	D0, D0
	RTS
Update_audio_engine:
; Per-frame audio engine update routine called from Race_loop (step 24).
; Updates the 68K-side audio engine state struct at Audio_engine_state ($FF5AC0)
; and sends encoded note/command data to the Z80 sound driver via Z80 RAM writes.
;
; Inputs (from Audio_engine_state struct, A6 = $FF5AC0 on entry):
;   +$00 .w  music command latch    – non-zero = pending song change
;   +$02 .w  music mode             – bits 0-3 control active audio mode
;   +$04 .w  engine speed           – scaled player speed for pitch calculation
;   +$06 .w  channel flags          – bit 0 = engine channel active
;   +$1E .b  engine flags           – bit 0 = rev-up screech; bit 1 = fade-in
;
; A4 = $FF5AF0 (Audio_engine_scratch, 12-byte note data scratch buffer)
;
; Per-frame update sequence:
;   1. Increment frame counter (+$1C).
;   2. Count down fade-in/out counter (+$12); suppress pitch writes while non-zero.
;   3. Count down sequence timer (+$22):
;        - positive → decrement and return (wait for next step)
;        - zero     → process next sequence step (Audio_engine_step)
;        - negative ($8000) → halted; reset all channels (Audio_engine_halt_reset)
;   4. If Audio_ctrl_mode (+$24) is non-zero → dispatch pending command (Audio_engine_send_ctrl).
;   5. Process music mode bits from +$02 (silence, send music cmd, etc.).
;   6. Write channel-enable byte to Z80 via Write_byte_to_z80_ram → Z80_audio_pitch_sfm.
;   7. If engine channel active: compute YM pitch from speed/shift/RPM, encode
;      note bytes via Encode_z80_note, write 12-byte block to Z80_audio_engine_ch1.
;   8. Compute PSG ch1 and ch2 note blocks via Audio_engine_psg_ch1 / Audio_engine_psg_ch2 and write them
;      to Z80_audio_engine_ch1 ($A01FA0) and Z80_audio_engine_ch2 ($A01FC0).
	LEA	Audio_engine_state, A6
	LEA	Audio_engine_scratch, A4
	ADDQ.w	#1, $1C(A6)
	MOVE.w	$12(A6), D0
	BEQ.b	Audio_engine_seq_timer_check
	SUBQ.w	#1, D0
	MOVE.w	D0, $12(A6)
Audio_engine_seq_timer_check:
	MOVE.w	$22(A6), D0
	BEQ.b	Audio_engine_step
	BMI.w	Audio_engine_halt_reset
	SUBQ.w	#1, D0
	MOVE.w	D0, $22(A6)
	RTS
Audio_engine_step:
	MOVE.b	$24(A6), D0
	BNE.w	Audio_engine_send_ctrl
	MOVE.w	$2(A6), D0
	ANDI.w	#$000F, D0
	BEQ.b	Audio_engine_seq_done
	CMPI.w	#$000F, D0
	BNE.b	Audio_engine_mode_check
	LEA	Audio_engine_silence_block(PC), A5
	LEA	$00A01FA2, A3
	MOVEQ	#$0000000F, D7
	JSR	Z80_bus_arbitrate_and_copy(PC)
	LEA	Audio_engine_silence_block(PC), A5
	LEA	$00A01FC2, A3
	MOVEQ	#3, D7
	JSR	Z80_bus_arbitrate_and_copy(PC)
	BSET.b	#1, $1E(A6)
Audio_engine_mode_check:
	CMPI.w	#4, D0
	BCC.b	Audio_engine_mode_write
	MOVE.w	#$0080, $12(A6)
Audio_engine_mode_write:
	MOVE.w	#0, $2(A6)
	MOVE.b	D0, (A4)
	LEA	$00A01FB7, A3
	JSR	Write_byte_to_z80_ram(PC)
Audio_engine_seq_done:
	JSR	$7620E(PC)
	MOVE.w	$20(A6), D0
	ANDI.w	#$001F, D0
	BNE.w	$76224
	MOVE.w	$0(A6), D0
	MOVE.w	#0, $0(A6)
	TST.w	D0
	BEQ.b	Audio_engine_music_cmd_done
	CMPI.w	#$0011, D0
	BEQ.w	Audio_engine_music_reset
	BCC.b	Audio_engine_music_cmd_done
	ADDI.w	#$0080, D0
	MOVE.b	D0, (A4)
	LEA	$00A01C09, A3
	JSR	Write_byte_to_z80_ram(PC)
Audio_engine_music_cmd_done:
	MOVE.w	$6(A6), D0
	ANDI.w	#1, D0
	MOVE.b	D0, (A4)
	LEA	$00A01FB3, A3
	JSR	Write_byte_to_z80_ram(PC)
	LSR.w	#1, D0
	BCS.b	Audio_engine_channel_active
Audio_engine_channel_off:
	RTS
Audio_engine_channel_active:
	BTST.b	#1, $1E(A6)
	BNE.b	Audio_engine_channel_off
	JSR	Audio_engine_update_pitch(PC)
	JSR	Audio_engine_psg_ch1(PC)
	JSR	Audio_engine_psg_ch2(PC)
	RTS
Audio_engine_update_pitch:
	MOVE.w	$26(A6), D0
	BNE.b	Audio_engine_screech_tick
	BCLR.b	#0, $1E(A6)
	BRA.b	Audio_engine_rpm_compare
Audio_engine_screech_tick:
	SUBQ.w	#1, D0
	MOVE.w	D0, $26(A6)
Audio_engine_rpm_compare:
	MOVE.w	$00FF9100, D0
	CMP.w	$14(A6), D0
	BEQ.b	Audio_engine_rpm_equal
	BCC.b	Audio_engine_rpm_higher
	MOVE.w	D0, $14(A6)
	MOVE.w	#$0050, D0
	MOVE.w	D0, $16(A6)
	CMPI.w	#$0380, $4(A6)
	BCS.b	Audio_engine_pitch_resume
	MOVE.w	#$0050, $26(A6)
	BSET.b	#0, $1E(A6)
	MOVE.b	#7, (A4)
	LEA	$00A01FB7, A3
	JSR	Write_byte_to_z80_ram(PC)
	BRA.b	Audio_engine_pitch_resume
Audio_engine_rpm_higher:
	MOVE.w	#$0100, $16(A6)
	MOVE.w	D0, $14(A6)
	BRA.b	Audio_engine_pitch_resume
Audio_engine_rpm_equal:
	MOVE.w	$16(A6), D0
	BEQ.b	Audio_engine_pitch_resume
	SUBQ.w	#1, D0
	MOVE.w	D0, $16(A6)
Audio_engine_pitch_resume:
	MOVEQ	#0, D0
	MOVE.w	$4(A6), D0
	ANDI.w	#$07F8, D0
	LSL.w	#1, D0
	MOVE.w	D0, D1
	LSL.w	#1, D0
	ADD.w	D1, D0
	ADDI.w	#$2800, D0
	MOVE.w	D0, $1A(A6)
	MOVE.w	$00FF9100, D0
	BEQ.b	Audio_engine_vol_clamp
	MOVE.w	#$0018, D1
	MOVE.w	$16(A6), D0
	BEQ.b	Audio_engine_vol_speed_check
	CMPI.w	#$0100, D0
	BCC.b	Audio_engine_vol_clamp
	LSR.w	#5, D0
	SUB.w	D0, D1
	BRA.b	Audio_engine_vol_speed_check
Audio_engine_vol_clamp:
	MOVEQ	#$00000010, D1
	BRA.b	Audio_engine_write_volume
Audio_engine_vol_speed_check:
	MOVE.w	$4(A6), D0
	SUBI.w	#$0420, D0
	BCS.b	Audio_engine_write_volume
	CMPI.w	#$0100, D0
	BCS.b	Audio_engine_vol_reduce
	MOVEQ	#$00000010, D1
	BRA.b	Audio_engine_write_volume
Audio_engine_vol_reduce:
	ANDI.w	#$00F0, D0
	LSR.w	#5, D0
	SUB.w	D0, D1
	CMPI.w	#$0010, D1
	BCC.b	Audio_engine_write_volume
	MOVEQ	#$00000010, D1
Audio_engine_write_volume:
	MOVE.w	D1, $18(A6)
	MOVEA.l	A4, A5
	MOVE.w	$1A(A6), D0
	MOVE.w	D0, D1
	BSR.w	Encode_z80_note
	MOVE.w	D0, D1
	BSR.w	Encode_z80_note
	MOVE.w	D0, D1
	ADDI.w	#$0600, D1
	BSR.w	Encode_z80_note
	MOVE.w	D0, D1
	BSR.w	Encode_z80_note
	MOVE.w	$18(A6), D1
	BTST.b	#0, $1E(A6)
	BEQ.b	Audio_engine_ym_vol_write
	MOVE.w	$12(A6), D0
	BEQ.b	Audio_engine_ym_vol_max
	MOVE.w	$16(A6), D0
	LSR.w	#6, D0
	SUB.w	D0, D1
	BRA.b	Audio_engine_ym_vol_write
Audio_engine_ym_vol_max:
	MOVEQ	#$0000007F, D1
Audio_engine_ym_vol_write:
	MOVE.b	D1, (A5)+
	MOVE.w	$1A(A6), D1
	BTST.b	#1, $7(A6)
	BNE.b	Audio_engine_ym_vibrato
	ADDI.w	#$0020, D1
	SUBI.w	#$2800, D1
	LSR.w	#1, D1
	ADDI.w	#$2800, D1
	BRA.b	Audio_engine_ym_ch2_note
Audio_engine_ym_vibrato:
	MOVE.w	$1C(A6), D0
	ANDI.w	#$000F, D0
	CMPI.w	#8, D0
	BCS.b	Audio_engine_ym_vibrato_lo
	NOT.w	D0
	ANDI.w	#7, D0
Audio_engine_ym_vibrato_lo:
	LSL.w	#5, D0
	ADDI.w	#$0040, D0
	ADD.w	D0, D1
Audio_engine_ym_ch2_note:
	BSR.w	Encode_z80_note
	MOVE.b	D1, D4
	MOVE.b	D2, D5
	MOVE.w	$18(A6), D1
	BTST.b	#1, $7(A6)
	BNE.b	Audio_engine_ym_ch2_vol
	BTST.b	#0, $1E(A6)
	BEQ.b	Audio_engine_ym_vol_boost
	MOVE.w	$16(A6), D0
	LSR.w	#5, D0
	NOT.w	D0
	ANDI.w	#$000F, D0
	ADD.w	D0, D1
	BRA.b	Audio_engine_ym_ch2_vol
Audio_engine_ym_vol_boost:
	ADDI.w	#$0010, D1
Audio_engine_ym_ch2_vol:
	BTST.b	#0, $1E(A6)
	BEQ.b	Audio_engine_ym_ch2_write
	MOVEQ	#$0000007F, D1
Audio_engine_ym_ch2_write:
	MOVE.b	D1, (A5)
	MOVEQ	#$0000000B, D7
	LEA	$00A01FA6, A3
	BSR.w	Copy_scratch_to_z80_ram
	MOVEA.l	A4, A5
	SUBQ.b	#8, D5
	MOVE.b	D5, (A5)+
	MOVE.b	D4, (A5)+
	MOVE.b	D1, (A5)+
	MOVEQ	#2, D7
	LEA	$00A01FC6, A3
	BRA.w	Copy_scratch_to_z80_ram
Audio_engine_psg_ch1:
	MOVEA.l	A4, A5
	MOVE.w	$8(A6), D0
	CMPI.w	#$00FF, D0
	BEQ.w	Audio_engine_psg_ch1_mute
	BSR.w	Audio_engine_note_freq
	MOVE.w	D0, D4
	BSR.w	Audio_engine_lfo_delta
	ADD.w	D4, D0
	MOVE.w	D0, D5
	MOVE.w	$8(A6), D0
	MOVE.w	$A(A6), D1
	BSR.w	Audio_engine_note_split
	MOVE.w	D4, D1
	BSR.w	Encode_z80_note
	MOVE.b	D6, (A5)+
	MOVE.w	D5, D1
	BSR.w	Encode_z80_note
	MOVE.b	D7, (A5)+
	BRA.b	Audio_engine_psg_ch1_send
Audio_engine_psg_ch1_mute:
	MOVE.b	#$7F, $2(A5)
	MOVE.b	#$7F, $5(A5)
Audio_engine_psg_ch1_send:
	LEA	$00A01FA0, A3
	MOVEQ	#5, D7
	BRA.w	Copy_scratch_to_z80_ram
Audio_engine_psg_ch2:
	MOVEA.l	A4, A5
	MOVE.w	$C(A6), D0
	CMPI.w	#$00FF, D0
	BEQ.w	Audio_engine_psg_ch2_mute
	BSR.w	Audio_engine_note_freq
	MOVE.w	D0, D4
	BSR.w	Audio_engine_lfo_delta
	ADD.w	D4, D0
	MOVE.w	D0, D5
	MOVE.w	$C(A6), D0
	MOVE.w	$E(A6), D1
	BSR.w	Audio_engine_note_split
	MOVE.w	D4, D1
	BSR.w	Encode_z80_note
	MOVE.b	D6, (A5)+
	MOVE.w	D5, D1
	BSR.w	Encode_z80_note
	MOVE.b	D7, (A5)+
	BRA.b	Audio_engine_psg_ch2_send
Audio_engine_psg_ch2_mute:
	MOVE.b	#$7F, $2(A5)
	MOVE.b	#$7F, $5(A5)
Audio_engine_psg_ch2_send:
	LEA	$00A01FC0, A3
	MOVEQ	#5, D7
	BRA.w	Copy_scratch_to_z80_ram
Audio_engine_lfo_delta:
; Compute frame-based LFO oscillation offset from the frame counter (+$1C).
; Uses lower 4 bits of frame counter; maps [0..7] → positive, [8..15] → inverted negative.
; Returns an offset in [0..56] increments of 8 in D0.
	MOVE.w	$1C(A6), D0
	ANDI.w	#$000F, D0
	CMPI.w	#8, D0
	BCC.b	Audio_engine_lfo_hi
	NEG.w	D0
	ANDI.w	#7, D0
Audio_engine_lfo_hi:
	LSL.w	#3, D0
	ADDI.w	#$0010, D0
	RTS
Audio_engine_note_split:
; Split a 7-bit note value (D0) and a 4-bit volume/channel byte (D1) into two
; PSG channel bytes stored in D6 (ch1 detune) and D7 (ch2 detune).
; Uses Audio_engine_psg_detune_table for per-step detune offsets.
	ANDI.w	#$007F, D0
	LSR.w	#1, D0
	ADDI.w	#0, D0
	MOVE.b	D0, D6
	MOVE.b	D0, D7
	LEA	Audio_engine_psg_detune_table(PC), A1
	ANDI.w	#$000F, D1
	LSL.w	#1, D1
	ADD.b	(A1,D1.w), D6
	ADDQ.w	#1, D1
	ADD.b	(A1,D1.w), D7
	RTS
Audio_engine_note_freq:
; Compute YM/PSG frequency word from a 7-bit note value in D0.
; Maps note [0..$7F] to a 16-bit frequency suitable for the note lookup tables.
; Result is masked to even steps ($FFE0) so it aligns with the frequency table stride.
	ANDI.w	#$007F, D0
	LSL.w	#4, D0
	SUBI.w	#$4000, D0
	NEG.w	D0
	ANDI.w	#$FFE0, D0
	RTS
Audio_engine_psg_detune_table:
	dc.b	$00, $00, $00, $04, $00, $08, $00, $0C, $00, $10, $00, $14, $00, $18, $00, $1C, $00, $00, $04, $00, $08, $00, $0C, $00, $10, $00, $14, $00, $18, $00, $1C, $00
Encode_z80_note:
	MOVE.w	D1, D3
	LSR.w	#8, D1
	LEA	Audio_engine_ym_semitone_table(PC), A1
	MOVE.b	(A1,D1.w), D1
	MOVE.b	D1, D2
	ANDI.b	#$F0, D1
	ANDI.b	#$E0, D3
	LSR.b	#4, D3
	OR.b	D3, D1
	ANDI.w	#$00FE, D1
	LEA	Audio_engine_ym_octave_table(PC), A1
	MOVE.w	(A1,D1.w), D1
	ANDI.w	#7, D2
	LSL.w	#8, D2
	LSL.w	#3, D2
	OR.w	D2, D1
	MOVE.w	D1, D2
	LSR.w	#8, D2
	MOVE.b	D2, (A5)+
	MOVE.b	D1, (A5)+
	RTS
Audio_engine_ym_semitone_table:
	dc.b	$00, $10, $20, $30, $40, $50, $60, $70, $80, $90, $A0, $B0, $01, $11, $21, $31, $41, $51, $61, $71, $81, $91, $A1, $B1, $02, $12, $22, $32, $42, $52, $62, $72
	dc.b	$82, $92, $A2, $B2, $03, $13, $23, $33
	dc.b	$43, $53, $63, $73, $83, $93, $A3, $B3, $04, $14, $24, $34, $44, $54, $64, $74, $84, $94, $A4, $B4, $05, $15, $25, $35, $45, $55, $65, $75, $85, $95, $A5, $B5
	dc.b	$06, $16, $26, $36, $46, $56, $66, $76, $86, $96, $A6
	dc.b	$B6, $07, $17, $27, $37, $47, $57, $67, $77, $87, $97, $A7, $B7
Audio_engine_ym_octave_table:
	dc.w	$0284, $0288, $028C, $0290, $0294, $0298, $029C, $02A0, $02AB, $02B0, $02B5, $02BA, $02BF, $02C4, $02C9, $02CE, $02D3, $02D8, $02DD, $02E2, $02E7, $02EC, $02F1, $02F6, $02FE, $0303, $0308, $030D, $0312, $0317, $031C, $0321
	dc.w	$032D, $0332, $0337, $033C, $0341, $0346, $034B, $0350, $035C, $0362, $0368, $036E, $0374, $037A, $0380, $0386, $038F, $0395, $039B, $03A1, $03A7, $03AD, $03B3, $03B9, $03C5, $03CC, $03D3, $03DA, $03E1, $03E8, $03EF, $03F6
	dc.w	$03FF, $0406, $040D, $0414, $041B, $0422, $0429, $0430, $043C, $0444, $044C, $0454, $045C, $0464, $046C, $0474, $047C, $0484, $048C, $0494, $049C, $04A4, $04AC, $04B4, $04C0, $04C9, $04D2, $04DB, $04E4, $04ED, $04F6, $04FF
Audio_engine_halt_reset:
; Halted state: reset all engine state channels and send silence/clear commands to Z80.
; Called when sequence timer goes negative ($8000 = halted).
; Clears all pitch/volume/mode fields, then sends halt ($80) to Z80_audio_pitch_sfm
; and clear ($C0) to Z80_audio_music_cmd.
	MOVEQ	#0, D0
	MOVE.w	#3, $22(A6)
	MOVE.w	D0, $14(A6)
	MOVE.w	D0, $16(A6)
	MOVE.w	D0, $18(A6)
	MOVE.w	D0, $1A(A6)
	MOVE.w	D0, $1C(A6)
	MOVE.w	D0, $2(A6)
	MOVE.b	D0, $1E(A6)
	MOVE.w	D0, $26(A6)
	MOVE.w	D0, $12(A6)
	MOVE.b	D0, $24(A6)
	MOVE.l	D0, $28(A6)
	MOVE.b	#$80, (A4)
	LEA	$00A01FB7, A3
	JSR	Write_byte_to_z80_ram(PC)
	MOVE.b	#$C0, (A4)
	LEA	$00A01C09, A3
	BRA.b	Write_byte_to_z80_ram
Audio_engine_send_ctrl:
; Dispatch a pending audio control command to the Z80.
; Called when Audio_ctrl_mode (+$24) is non-zero.
; Writes the command byte to Z80_audio_ctrl ($A01C10) and clears the latch.
	MOVE.b	D0, (A4)
	MOVEQ	#0, D0
	MOVE.b	D0, $24(A6)
	LEA	$00A01C10, A3
	BRA.b	Write_byte_to_z80_ram
	dc.b	$7E, $01, $60, $02
;Write_byte_to_z80_ram
Write_byte_to_z80_ram:
; Write one byte from the Audio_engine_scratch buffer (A4) to Z80 RAM (A3).
; This is the single-byte entry point: D7 is set to 0 so the DBF loop copies
; exactly 1 byte.  Falls through to Copy_scratch_to_z80_ram.
;
; Inputs:  A3 = destination address in Z80 RAM window ($A00000-$A0FFFF)
;          A4 = source pointer (byte to write; Audio_engine_scratch buffer)
;
; Three entry points share the bus-arbitration block at loc_761DC:
;
;   Write_byte_to_z80_ram (here, $761D4):
;     D7 ← 0; falls to Copy_scratch_to_z80_ram (copies A4 into A5)
;     → Copies 1 byte from Audio_engine_scratch[0] to Z80 RAM[A3].
;
;   Copy_scratch_to_z80_ram ($761DA):
;     A5 ← A4 (source = scratch buffer start); then arbitrates and copies D7+1 bytes.
;     → Copies D7+1 bytes from A4 to Z80 RAM[A3].
;     Used when the caller wants to send a variable-length block from the scratch
;     buffer (e.g. Encode_z80_note callers writing 12-byte note blocks).
;
;   Z80_bus_arbitrate_and_copy ($761DC):
;     Arbitrates and copies D7+1 bytes from A5 to Z80 RAM[A3].
;     → Copies D7+1 bytes starting from caller-supplied A5 to Z80 RAM[A3].
;     Used when A5 already points to a ROM data table (e.g. the silence-all block
;     at Audio_engine_silence_block).
;
; Bus arbitration protocol used by all three entry points:
;   1. Write $0100 to Z80_bus_request to request 68K ownership.
;   2. Spin on bit 0 of Z80_bus_request until the Z80 acknowledges (bit clears).
;   3. Copy D7+1 bytes from A5 to A3 (Z80 RAM window).
;   4. Write $0000 to Z80_bus_request to release the bus back to the Z80.
	MOVEQ	#0, D7
Copy_scratch_to_z80_ram:
; Mid-entry: set A5 = A4 (Audio_engine_scratch start), then fall through
; to the bus-arbitration block to copy D7+1 bytes from A4 to Z80 RAM at A3.
	MOVEA.l	A4, A5
Z80_bus_arbitrate_and_copy:
	MOVE.w	#$0100, Z80_bus_request
Z80_bus_wait_loop:
	BTST.b	#0, Z80_bus_request
	BNE.b	Z80_bus_wait_loop
Z80_bus_copy_loop:
	MOVE.b	(A5)+, (A3)+
	DBF	D7, Z80_bus_copy_loop
	MOVE.w	#0, Z80_bus_request
	RTS
Audio_engine_silence_block:
	dc.b	$7F, $00, $00, $7F, $00, $00, $00, $00, $00, $00, $00, $00, $7F, $00, $00, $7F
Audio_engine_seq_interval:
	MOVEQ	#0, D2
	MOVE.b	$29(A6), D0
	BEQ.b	Audio_engine_seq_interval_clear
	SUBQ.b	#1, D0
	MOVE.b	D0, $29(A6)
	BNE.b	Audio_engine_seq_interval_rts
Audio_engine_seq_interval_clear:
	MOVE.b	D2, $28(A6)
Audio_engine_seq_interval_rts:
	RTS
Audio_engine_seq_step:
	SUBQ.w	#1, D0
	BEQ.w	Audio_engine_seq_pitch_write
	LEA	Audio_engine_seq_step_table(PC), A1
	MOVE.w	D0, D1
	ADD.w	D0, D0
	ADD.w	D1, D0
	MOVE.b	(A1,D0.w), D1
	BMI.b	Audio_engine_seq_vibrato
	BEQ.b	Audio_engine_seq_screech
	CMPI.b	#$40, D1
	BNE.w	Audio_engine_seq_clear
	MOVE.b	$28(A6), D2
	MOVE.b	$1(A1,D0.w), D1
	CMP.b	D1, D2
	BHI.b	Audio_engine_seq_clear
	MOVE.b	D1, $28(A6)
	MOVE.b	$2(A1,D0.w), D0
	MOVE.b	D0, $29(A6)
	BRA.b	Audio_engine_seq_pitch_write
Audio_engine_seq_vibrato:
	MOVE.b	$28(A6), D0
	BNE.b	Audio_engine_seq_pitch_write
	MOVE.w	$20(A6), D0
	CMPI.w	#$000B, D0
	BNE.b	Audio_engine_seq_advance
	MOVEQ	#$0000000A, D0
	MOVE.w	D0, $20(A6)
	BRA.b	Audio_engine_seq_step
Audio_engine_seq_advance:
	ADDQ.w	#3, D0
	MOVE.w	D0, $20(A6)
	BRA.b	Audio_engine_seq_step
Audio_engine_seq_screech:
	MOVE.b	#7, $28(A6)
	MOVE.b	#1, $29(A6)
Audio_engine_seq_pitch_write:
	MOVE.w	$20(A6), D0
	ANDI.w	#$001F, D0
	ADDI.w	#$009F, D0
	MOVE.b	D0, (A4)
	LEA	$00A01C09, A3
	JSR	Write_byte_to_z80_ram(PC)
Audio_engine_seq_clear:
	MOVE.w	#0, $20(A6)
	RTS
Audio_engine_seq_step_table:
	dc.b	$C0, $00, $01
	dc.b	$00
	dc.b	$00, $01, $20, $00, $01
	dc.b	$00
	dc.b	$00, $01
	dc.b	$00
	dc.b	$00, $01
	dc.b	$40, $06, $1C, $40, $07, $10, $40, $07, $10, $40, $07, $10, $40, $00, $00, $80
	dc.b	$00, $01, $40, $00, $01, $40, $00, $01
	dc.b	$40
	dc.b	$00
	dc.b	$01
	dc.b	$40, $00, $01
	dc.b	$80
	dc.b	$00, $01
	dc.b	$80
	dc.b	$00, $01
	dc.b	$80
	dc.b	$00, $01
	dc.b	$40, $00, $01, $40, $00, $01, $40, $00, $01, $40, $07, $20
	dc.b	$20, $00, $01, $20, $00, $01, $20, $00, $01, $20, $00, $01
	dc.b	$00
	dc.b	$00, $01
	dc.b	$40
	dc.b	$03
	dc.b	$10
	dc.b	$20, $00, $01
	dc.b	$40
	dc.b	$03
	dc.b	$10
	dc.b	$20, $00, $01, $00
Audio_engine_music_reset:
	MOVEA.l	A4, A5
	MOVE.b	#$A8, (A5)+
	MOVE.b	#3, (A5)+
	MOVE.b	#3, (A5)
	LEA	$00A01C0D, A3
	MOVEQ	#2, D7
	BRA.w	Copy_scratch_to_z80_ram
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
Z80_data:
	dc.b	$F3, $F3, $ED, $56, $18, $40, $00, $00, $3A, $00, $40, $CB, $7F, $20, $F9, $C9, $DD, $CB, $01, $7E, $C0, $C3, $00, $06, $C3, $0E, $06, $00, $00, $00, $00, $00
	dc.b	$2A, $02, $1C, $06, $00, $C3, $22, $01, $4F, $06, $00, $09, $09, $00, $00, $00, $7E, $23, $66, $6F, $C9, $00, $00, $00, $F5, $3A, $FF, $1F, $B7, $28, $04, $3D
	dc.b	$32, $FF, $1F, $F1, $FB, $C9, $31, $7D, $1F, $3E, $03, $32, $FF, $1F, $FB, $3A, $FF, $1F, $B7, $20, $F9, $F3, $CD, $AC, $08, $CD, $D0, $07, $CD, $D1, $00, $CD
	dc.b	$10, $01, $21, $B7, $1F, $7E, $B7, $C4, $A7, $10, $23, $7E, $17, $DC, $31, $10, $11, $B3, $1F, $1A, $1F, $13, $1A, $17, $12, $E6, $03, $28, $2A, $3D, $FE, $02
	dc.b	$28, $09, $B7, $28, $03, $C3, $6F, $12, $CD, $60, $11, $3A, $00, $40, $1F, $1F, $30, $D0, $3A, $10, $1C, $B7, $C4, $BA, $12, $CD, $B3, $13, $CD, $10, $01, $CD
	dc.b	$6C, $06, $CD, $63, $02, $18, $BB, $3A, $00, $40, $E6, $03, $28, $B4, $CB, $4F, $28, $10, $CD, $10, $01, $21, $C2, $00, $E5, $CD, $E3, $07, $CD, $6C, $06, $C3
	dc.b	$63, $02, $3A, $00, $40, $CB, $47, $28, $99, $CD, $D1, $00, $CD, $2A, $02, $18, $91, $2A, $04, $1C, $7D, $E6, $03, $4F, $3E, $25, $DF, $CB, $3C, $CB, $1D, $CB
	dc.b	$3C, $CB, $1D, $4D, $3E, $24, $DF, $3E, $1F, $18, $2E, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	dc.b	$00, $01, $02, $04, $08, $10, $20, $40, $80, $FF, $FE, $FC, $F8, $F0, $E0, $C0, $3A, $06, $1C, $4F, $3E, $26, $DF, $3E, $2F, $21, $12, $1C, $B6, $4F, $3E, $27
	dc.b	$DF, $C9, $09, $08, $F7, $08, $C9, $F7, $01, $40, $15, $08, $02, $00, $15, $35, $01, $A4, $01, $A0, $00, $49, $01, $4E, $01, $4E, $01, $4E, $01, $90, $01, $90
	dc.b	$01, $90, $01, $90, $01, $90, $01, $90, $01, $00, $01, $02, $01, $80, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	dc.b	$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $02, $04, $06, $08, $0A, $0C, $0A, $08, $06, $04
	dc.b	$02, $00, $FE, $FC, $FA, $F8, $F6, $F4, $F6, $F8, $FA, $FC, $FE, $00, $82, $29, $00, $00, $00, $00, $01, $01, $01, $01, $02, $02, $01, $01, $01, $00, $00, $00
	dc.b	$84, $01, $82, $04, $B2, $01, $B2, $01, $B9, $01, $B9, $01, $C5, $01, $D0, $01, $DF, $01, $00, $02, $04, $06, $08, $10, $83, $00, $00, $02, $03, $04, $04, $05
	dc.b	$05, $05, $06, $06, $81, $03, $00, $01, $01, $01, $02, $03, $04, $04, $05, $81, $00, $00, $01, $01, $02, $03, $04, $05, $05, $06, $08, $07, $07, $06, $81, $00
	dc.b	$00, $00, $00, $00, $01, $01, $01, $02, $02, $03, $03, $04, $04, $05, $05, $06, $07, $08, $09, $0A, $0B, $0C, $81, $00, $80, $00, $00, $00, $80, $00, $00, $00
	dc.b	$80, $80, $80, $00, $00, $80, $00, $00, $00, $C0, $C4, $18, $52, $C1, $3A, $C4, $15, $C5, $CE, $19, $8F, $C6, $D4, $C7, $3D, $C9, $00, $C0, $DB, $C6, $40, $CA
	dc.b	$7E, $D0, $85, $D6, $C4, $CE, $CE, $DA, $AC, $DB, $CD, $E3, $07, $CD, $33, $09, $CD, $49, $08, $CD, $6C, $06, $3A, $07, $1C, $B7, $F4, $63, $02, $AF, $32, $19
	dc.b	$1C, $DD, $21, $40, $1C, $DD, $CB, $00, $7E, $C4, $0C, $0A, $06, $09, $DD, $21, $70, $1C, $C5, $DD, $CB, $00, $7E, $C4, $A0, $02, $11, $30, $00, $DD, $19, $C1
	dc.b	$10, $F0, $C9, $3E, $01, $32, $19, $1C, $DD, $21, $20, $1E, $DD, $CB, $00, $7E, $C4, $A7, $02, $DD, $21, $50, $1E, $DD, $CB, $00, $7E, $C4, $A7, $02, $DD, $21
	dc.b	$80, $1E, $DD, $CB, $00, $7E, $C4, $A7, $02, $DD, $21, $B0, $1E, $DD, $CB, $00, $7E, $C4, $A7, $02, $DD, $21, $E0, $1E, $DD, $CB, $00, $7E, $C2, $A7, $02, $C9
	dc.b	$DD, $CB, $01, $7E, $C2, $6D, $0F, $CD, $6B, $04, $20, $17, $CD, $3D, $03, $DD, $CB, $00, $66, $C0, $CD, $A2, $04, $CD, $99, $05, $CD, $CD, $04, $CD, $E5, $02
	dc.b	$C3, $72, $05, $CD, $55, $04, $DD, $CB, $00, $66, $C0, $CD, $73, $04, $DD, $7E, $1E, $B7, $28, $06, $DD, $35, $1E, $CA, $89, $05, $CD, $99, $05, $DD, $CB, $00
	dc.b	$76, $C0, $CD, $CD, $04, $DD, $CB, $00, $56, $C0, $DD, $CB, $00, $46, $C2, $FA, $02, $3E, $A4, $4C, $D7, $3E, $A0, $4D, $D7, $C9, $DD, $7E, $01, $FE, $02, $20
	dc.b	$F0, $CD, $2D, $03, $D9, $21, $29, $03, $06, $04, $7E, $F5, $23, $D9, $EB, $4E, $23, $46, $23, $EB, $DD, $6E, $0D, $DD, $66, $0E, $09, $F1, $F5, $4C, $DF, $F1
	dc.b	$D6, $04, $4D, $DF, $D9, $10, $E3, $D9, $C9, $AD, $AE, $AC, $A6, $11, $2A, $1C, $3A, $19, $1C, $B7, $C8, $11, $1A, $1C, $F0, $11, $22, $1C, $C9, $DD, $5E, $03
	dc.b	$DD, $56, $04, $DD, $CB, $00, $8E, $DD, $CB, $00, $A6, $1A, $13, $FE, $E0, $D2, $46, $0C, $08, $CD, $89, $05, $CD, $0F, $04, $08, $DD, $CB, $00, $5E, $C2, $B7
	dc.b	$03, $B7, $F2, $DD, $03, $D6, $81, $F2, $6F, $03, $CD, $14, $10, $18, $2E, $DD, $86, $05, $21, $6A, $09, $F5, $EF, $F1, $DD, $CB, $01, $7E, $20, $19, $D5, $16
	dc.b	$08, $1E, $0C, $08, $AF, $08, $93, $38, $05, $08, $82, $18, $F8, $08, $83, $21, $F4, $09, $EF, $08, $B4, $67, $D1, $DD, $75, $0D, $DD, $74, $0E, $DD, $CB, $00
	dc.b	$6E, $20, $0D, $1A, $B7, $F2, $DC, $03, $DD, $7E, $0C, $DD, $77, $0B, $18, $33, $1A, $13, $DD, $77, $10, $18, $24, $67, $1A, $13, $6F, $B4, $28, $0C, $DD, $7E
	dc.b	$05, $06, $00, $B7, $F2, $C8, $03, $05, $4F, $09, $DD, $75, $0D, $DD, $74, $0E, $DD, $CB, $00, $6E, $28, $05, $1A, $13, $DD, $77, $10, $1A, $13, $CD, $05, $04
	dc.b	$DD, $77, $0C, $DD, $73, $03, $DD, $72, $04, $DD, $7E, $0C, $DD, $77, $0B, $DD, $CB, $00, $4E, $C0, $AF, $DD, $77, $25, $DD, $77, $22, $DD, $77, $17, $DD, $7E
	dc.b	$1F
	dc.b	$DD
	dc.b	$77, $1E, $C9, $DD, $46, $02, $05, $C8, $4F, $81, $10, $FD, $C9, $DD, $7E, $11, $3D, $F8, $20, $3B, $DD, $CB, $00, $4E, $C0, $DD, $35, $16, $C0, $D9, $DD, $7E
	dc.b	$15, $DD, $77, $16, $DD, $7E, $12, $21, $5D, $04, $EF, $DD, $5E, $13, $DD, $34, $13, $DD, $7E, $14, $3D, $BB, $20, $0E, $DD, $35, $13, $DD, $7E, $11, $FE, $02
	dc.b	$28, $04, $DD, $36, $13, $00, $16, $00, $19, $EB, $CD, $27, $0E, $D9, $C9, $AF, $DD, $77, $13, $DD, $7E, $11, $D6, $02, $F8, $18, $BE, $65, $04, $66, $04, $67
	dc.b	$04, $68, $04, $C0, $80, $C0, $40, $80, $C0, $DD, $7E, $0B, $3D, $DD, $77, $0B, $C9, $DD, $7E, $18, $B7, $C8, $F8, $3D, $0E, $0A, $E7, $EF, $CD, $E3, $0F, $DD
	dc.b	$66, $1D, $DD, $6E, $1C, $11, $3F, $06, $06, $04, $DD, $4E, $19, $F5, $CB, $29, $C5, $30, $06, $86, $E6, $7F, $4F, $1A, $D7, $C1, $13, $23, $F1, $10, $EE, $C9
	dc.b	$DD, $CB, $07, $7E, $C8, $DD, $CB, $00, $4E, $C0, $DD, $5E, $20, $DD, $56, $21, $DD, $E5, $E1, $06, $00, $0E, $24, $09, $EB, $ED, $A0, $ED, $A0, $ED, $A0, $7E
	dc.b	$CB, $3F, $12, $AF, $DD, $77, $22, $DD, $77, $23, $C9, $DD, $7E, $07, $B7, $C8, $FE, $80, $20, $48, $DD, $35, $24, $C0, $DD, $34, $24, $E5, $DD, $6E, $22, $DD
	dc.b	$66, $23, $DD, $35, $25, $20, $20, $DD, $5E, $20, $DD, $56, $21, $D5, $FD, $E1, $FD, $7E, $01, $DD, $77, $25, $DD, $7E, $26, $4F, $E6, $80, $07, $ED, $44, $47
	dc.b	$09, $DD, $75, $22, $DD, $74, $23, $C1, $09, $DD, $35, $27, $C0, $FD, $7E, $03, $DD, $77, $27, $DD, $7E, $26, $ED, $44, $DD, $77, $26, $C9, $3D, $EB, $0E, $08
	dc.b	$E7, $EF, $18, $03, $DD, $77, $25, $E5, $DD, $4E, $25, $CD, $DF, $05, $E1, $CB, $7F, $CA, $63, $05, $FE, $82, $28, $12, $FE, $80, $28, $12, $FE, $84, $28, $11
	dc.b	$26, $FF, $30, $1F, $DD, $CB, $00, $F6, $E1, $C9, $03, $0A, $18, $D6, $AF, $18, $D3, $03, $0A, $DD, $86, $22, $DD, $77, $22, $DD, $34, $25, $DD, $34, $25, $18
	dc.b	$C6, $26, $00, $6F, $DD, $46, $22, $04, $EB, $19, $10, $FD, $DD, $34, $25, $C9, $DD, $7E, $0D, $DD, $B6, $0E, $C8, $DD, $7E, $00, $E6, $06, $C0, $DD, $7E, $01
	dc.b	$F6, $F0, $4F, $3E, $28, $DF, $C9, $DD, $7E, $00, $E6, $06, $C0, $DD, $4E, $01, $CB, $79, $C0, $3E, $28, $DF, $C9, $06, $00, $DD, $7E, $10, $B7, $F2, $A3, $05
	dc.b	$05, $DD, $66, $0E, $DD, $6E, $0D, $4F, $09, $DD, $CB, $01, $7E, $20, $22, $EB, $3E, $07, $A2, $47, $4B, $B7, $21, $83, $02, $ED, $42, $38, $06, $21, $85, $FA
	dc.b	$19, $18, $0E, $B7, $21, $08, $05, $ED, $42, $30, $05, $21, $7C, $05, $19, $EB, $EB, $DD, $CB, $00, $6E, $C8, $DD, $74, $0E, $DD, $75, $0D, $C9, $06, $00, $09
	dc.b	$4D, $44, $0A, $C9, $2A, $37, $1C, $3A, $19, $1C, $B7, $28, $06, $DD, $6E, $2A, $DD, $66, $2B, $AF, $B0, $28, $06, $11, $19, $00, $19, $10, $FD, $C9, $DD, $CB
	dc.b	$01, $56, $20, $11, $DD, $CB, $00, $56, $C0, $DD, $86, $01, $32, $00, $40, $CF, $79, $32, $01, $40, $C9, $DD, $CB, $00, $56, $C0, $DD, $86, $01, $D6, $04, $32
	dc.b	$02, $40, $CF, $79, $32, $03, $40, $C9, $B0, $30, $38, $34, $3C, $50, $58, $54, $5C, $60, $68, $64, $6C, $70, $78, $74, $7C, $80, $88, $84, $8C, $40, $48, $44
	dc.b	$4C, $90, $98, $94, $9C, $11, $2A, $06, $DD, $4E, $0A, $3E, $B4, $D7, $CD, $66, $06, $DD, $77, $1B, $06, $14, $CD, $66, $06, $10, $FB, $DD, $75, $1C, $DD, $74
	dc.b	$1D, $C3, $41, $0E, $1A, $13, $4E, $23, $D7, $C9, $21, $09, $1C, $7E, $36, $80, $CB, $7F, $CA, $AC, $08, $FE, $A0, $DA, $84, $06, $FE, $C0, $DA, $3E, $07, $C3
	dc.b	$AC, $08, $D6, $81, $F8, $F5, $06, $00, $4F, $21, $F7, $01, $09, $7E, $32, $01, $1C, $CD, $D0, $07, $CD, $AC, $08, $F1, $0E, $04, $E7, $EF, $E5, $E5, $F7, $22
	dc.b	$37, $1C, $E1, $FD, $E1, $FD, $7E, $05, $32, $13, $1C, $32, $14, $1C, $11, $06, $00, $19, $22, $33, $1C, $21, $1F, $07, $22, $35, $1C, $11, $40, $1C, $FD, $46
	dc.b	$02, $FD, $7E, $04, $C5, $2A, $35, $1C, $ED, $A0, $ED, $A0, $12, $13, $22, $35, $1C, $2A, $33, $1C, $ED, $A0, $ED, $A0, $ED, $A0, $ED, $A0, $22, $33, $1C, $CD
	dc.b	$8D, $07, $C1, $10, $DF, $FD, $7E, $03, $B7, $CA, $19, $07, $47, $21, $2D, $07, $22, $35, $1C, $11, $90, $1D, $FD, $7E, $04, $C5, $2A, $35, $1C, $ED, $A0, $ED
	dc.b	$A0, $12, $13, $22, $35, $1C, $2A, $33, $1C, $01, $06, $00, $ED, $B0, $22, $33, $1C, $CD, $94, $07, $C1, $10, $E2, $3E, $80, $32, $09, $1C, $C9, $80, $02, $80
	dc.b	$00, $80, $01, $80, $04, $80, $05, $80, $06, $80, $02, $80, $80, $80, $A0, $80, $C0, $4F, $CB, $21, $06, $00, $09, $46, $23, $66, $68, $C9, $E6, $1F, $21, $BC
	dc.b	$14, $CD, $33, $07, $AF, $32, $19, $1C, $46, $23, $C5, $5E, $23, $56, $23, $E5, $23, $4E, $3E, $28, $CD, $0E, $06, $21, $50, $FE, $19, $CB, $D6, $E1, $ED, $A0
	dc.b	$ED, $A0, $ED, $A0, $ED, $A0, $ED, $A0, $ED, $A0, $ED, $A0, $E5, $21, $A7, $07, $01, $23, $00, $ED, $B0, $21, $34, $17, $EB, $73, $23, $72, $23, $EB, $21, $CA
	dc.b	$07, $01, $04, $00, $ED, $B0, $E1, $C1, $10, $C0, $C9, $08, $AF, $12, $13, $12, $13, $08, $EB, $36, $30, $23, $36, $C0, $23, $36, $01, $06, $24, $23, $36, $00
	dc.b	$10, $FB, $23, $EB, $C9, $00, $00, $30, $C0, $01, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	dc.b	$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $3A, $01, $1C, $07, $32, $00, $60, $06, $08, $3A, $00, $1C, $32, $00, $60, $0F, $10, $FA
	dc.b	$C9, $21, $10, $1C, $7E, $B7, $C8, $FA, $F4, $07, $D1, $3D, $C0, $36, $02, $C3, $F8, $08, $AF, $77, $3A, $0D, $1C, $B7, $C2, $AC, $08, $DD, $21, $70, $1C, $06
	dc.b	$06, $3A, $11, $1C, $B7, $20, $06, $DD, $CB, $00, $7E, $28, $06, $DD, $4E, $0A, $3E, $B4, $D7, $11, $30, $00, $DD, $19, $10, $E7, $DD, $21, $20, $1E, $06, $05
	dc.b	$DD, $CB, $00, $7E, $28, $06, $DD, $4E, $0A, $3E, $B4, $D7, $11, $30, $00, $DD, $19, $10, $ED, $C9, $AF, $32, $40, $1C, $32, $60, $1D, $32, $90, $1D, $32, $C0
	dc.b	$1D, $CD, $23, $09, $C3, $19, $07, $21, $0D, $1C, $7E, $B7, $C8, $FC, $36, $08, $CB, $BE, $3A, $0F, $1C, $3D, $28, $04, $32, $0F, $1C, $C9, $3A, $0E, $1C, $32
	dc.b	$0F, $1C, $3A, $0D, $1C, $3D, $32, $0D, $1C, $28, $3F, $DD, $21, $40, $1C, $06, $06, $DD, $34, $06, $F2, $7E, $08, $DD, $35, $06, $18, $0F, $DD, $CB, $00, $7E
	dc.b	$28, $09, $DD, $CB, $00, $56, $20, $03, $CD, $41, $0E, $11, $30, $00, $DD, $19, $10, $DF, $C9, $00, $00, $7F, $00, $00, $7F, $00, $00, $00, $00, $00, $00, $00
	dc.b	$00, $7F, $00, $00, $7F, $00, $00, $00, $00, $00, $21, $95, $08, $11, $A0, $1F, $01, $17, $00, $ED, $B0, $AF, $32, $B9, $1F, $21, $09, $1C, $11, $0A, $1C, $01
	dc.b	$06, $03, $36, $00, $ED, $B0, $DD, $21, $1F, $07, $06, $06, $C5, $CD, $4C, $09, $CD, $F1, $08, $DD, $23, $DD, $23, $C1, $10, $F2, $06, $07, $AF, $32, $0D, $1C
	dc.b	$CD, $23, $09, $3E, $0F, $32, $12, $1C, $4F, $3E, $27, $DF, $C3, $19, $07, $3E, $90, $0E, $00, $C3, $60, $09, $CD, $23, $09, $C5, $F5, $06, $03, $3E, $B4, $0E
	dc.b	$00, $F5, $DF, $F1, $3C, $10, $FA, $06, $03, $3E, $B4, $F5, $CD, $21, $06, $F1, $3C, $10, $F8, $0E, $00, $06, $07, $3E, $28, $F5, $DF, $0C, $F1, $10, $FA, $F1
	dc.b	$C1, $E5, $21, $11, $7F, $36, $9F, $36, $BF, $36, $DF, $36, $FF, $E1, $C3, $19, $07, $21, $13, $1C, $7E, $B7, $C8, $35, $C0, $3A, $14, $1C, $77, $21, $4B, $1C
	dc.b	$11, $30, $00, $06, $0A, $34, $19, $10, $FC, $C9, $CD, $5C, $09, $3E, $40, $0E, $7F, $CD, $60, $09, $DD, $4E, $01, $C3, $95, $05, $3E, $80, $0E, $FF, $06, $04
	dc.b	$F5, $D7, $F1, $C6, $04, $10, $F9, $C9, $56, $03, $26, $03, $F9, $02, $CE, $02, $A5, $02, $80, $02, $5C, $02, $3A, $02, $1A, $02, $FB, $01, $DF, $01, $C4, $01
	dc.b	$AB, $01, $93, $01, $7D, $01, $67, $01, $53, $01, $40, $01, $2E, $01, $1D, $01, $0D, $01, $FE, $00, $EF, $00, $E2, $00, $D6, $00, $C9, $00, $BE, $00, $B4, $00
	dc.b	$A9, $00, $A0, $00, $97, $00, $8F, $00, $87, $00, $7F, $00, $78, $00, $71, $00, $6B, $00, $65, $00, $5F, $00, $5A, $00, $55, $00, $50, $00, $4B, $00, $47, $00
	dc.b	$43, $00, $40, $00, $3C, $00, $39, $00, $36, $00, $33, $00, $30, $00, $2D, $00, $2B, $00, $28, $00, $26, $00, $24, $00, $22, $00, $20, $00, $1F, $00, $1D, $00
	dc.b	$1B, $00, $1A, $00, $18, $00, $17, $00, $16, $00, $15, $00, $13, $00, $12, $00, $11, $00, $84, $02, $AB, $02, $D3, $02, $FE, $02, $2D, $03, $5C, $03, $8F, $03
	dc.b	$C5, $03, $FF, $03, $3C, $04, $7C, $04, $C0, $04, $DD, $35, $0B, $CC, $13, $0A, $C9, $DD, $5E, $03, $DD, $56, $04, $1A, $13, $FE, $E0, $D2, $93, $0A, $B7, $FA
	dc.b	$28, $0A, $1B, $DD, $7E, $0D, $DD, $77, $0D, $FE, $80, $CA, $7D, $0A, $D5, $21, $60, $1D, $CB, $56, $20, $44, $E6, $0F, $28, $40, $08, $CD, $89, $05, $08, $11
	dc.b	$8D, $0A, $EB, $ED, $A0, $ED, $A0, $ED, $A0, $3D, $21, $B7, $0A, $EF, $01, $06, $00, $ED, $B0, $CD, $94, $07, $21, $65, $1D, $DD, $7E, $05, $86, $77, $3A, $68
	dc.b	$1D, $21, $D5, $0A, $EF, $3A, $66, $1D, $DD, $5E, $06, $D5, $83, $DD, $77, $06, $CD, $47, $06, $D1, $DD, $73, $06, $CD, $E5, $08, $D1, $1A, $13, $B7, $F2, $DD
	dc.b	$03, $1B, $DD, $7E, $0C, $DD, $77, $0B, $C3, $E3, $03, $80, $02, $01, $80, $C0, $01, $21, $99, $0A, $C3, $49, $0C, $13, $C3, $19, $0A, $A1, $0A, $AC, $0A, $A7
	dc.b	$0A, $00, $04, $00, $01, $F3, $E7, $C2, $08, $F2, $B2, $0A, $00, $06, $00, $02, $F3, $E7, $C5, $08, $F2, $E3, $0A, $E9, $0A, $EF, $0A, $1B, $0B, $24, $0B, $32
	dc.b	$0B, $42, $0B, $53, $0B, $61, $0B, $6F, $0B, $75, $0B, $7B, $0B, $61, $0B, $81, $0B, $87, $0B, $97, $0B, $B0, $0B, $C9, $0B, $E2, $0B, $FB, $0B, $14, $0C, $2D
	dc.b	$0C, $FA, $0A, $08, $06, $00, $00, $FC, $0A, $03, $06, $00, $00, $F5, $0A, $FE, $06, $00, $00, $E0, $40, $F6, $FC, $0A, $E0, $80, $FE, $00, $02, $00, $00, $FC
	dc.b	$01, $B8, $ED, $11, $E7, $B1, $ED, $21, $E7, $A8, $F1, $08, $E7, $A5, $ED, $21, $E7, $99, $ED, $21, $E7, $8D, $F1, $08, $F2, $21, $0B, $FF, $09, $01, $01, $B4
	dc.b	$10, $F2, $2A, $0B, $D0, $04, $01, $02, $FC, $01, $95, $92, $0C, $F2, $FC, $00, $38, $0B, $00, $00, $00, $03, $FE, $03, $02, $00, $01, $B4, $64, $E7, $64, $F2
	dc.b	$48, $0B, $00, $00, $00, $04, $FE, $03, $02, $00, $00, $FC, $01, $B0, $FA, $46, $F2, $59, $0B, $00, $00, $00, $05, $FE, $00, $00, $01, $00, $34, $46, $F2, $67
	dc.b	$0B, $00, $08, $00, $06, $FE, $03, $01, $02, $00, $32, $50, $F2, $94, $0B, $00, $00, $00, $06, $94, $0B, $00, $04, $00, $06, $94, $0B, $00, $10, $00, $06, $8D
	dc.b	$0B, $00, $00, $00, $06, $92, $0B, $00, $00, $00, $06, $E0, $80, $F6, $94, $0B, $E0, $40, $B0, $16, $F2, $3B, $08, $30, $31, $60, $1F, $1F, $15, $13, $1F, $1F
	dc.b	$1F, $16, $00, $00, $18, $0D, $00, $00, $00, $37, $00, $30, $05, $80, $3C, $0F, $00, $00, $00, $1F, $1A, $18, $1C, $17, $11, $1A, $0E, $00, $0F, $14, $10, $1F
	dc.b	$EC, $FF, $FF, $07, $80, $16, $80, $FC, $01, $00, $00, $00, $1F, $9F, $9F, $1F, $15, $13, $1F, $11, $00, $00, $0E, $0D, $F5, $FF, $09, $F6, $0A, $84, $20, $80
	dc.b	$34, $05, $01, $0F, $0E, $1F, $1F, $1F, $1F, $08, $1F, $0B, $1F, $08, $10, $05, $0E, $14, $17, $F9, $F7, $0A, $90, $08, $88, $3C, $03, $00, $00, $00, $9F, $9F
	dc.b	$9F, $9F, $14, $10, $0C, $10, $04, $08, $08, $08, $F5, $FF, $29, $FC, $18, $93, $0C, $94, $3A, $05, $07, $00, $00, $1F, $1F, $18, $9F, $10, $10, $14, $1F, $04
	dc.b	$06, $08, $0D, $F8, $F8, $18, $1C, $1E, $2C, $18, $8C, $72, $7F, $75, $75, $75, $9F, $9F, $9F, $9F, $15, $18, $19, $16, $06, $0A, $0A, $12, $0F, $4F, $4F, $AF
	dc.b	$00, $12, $12, $90, $21, $52, $0C, $E5, $D6, $E0, $21, $5D, $0C, $EF, $1A, $E9, $13, $C3, $4B, $03, $21, $9D, $0C, $EF, $13, $1A, $E9, $23, $0E, $4B, $0D, $60
	dc.b	$0D, $99, $0D, $A9, $0D, $60, $0E, $68, $0E, $BC, $0D, $9F, $0D, $38, $0E, $D9, $0C, $E6, $0C, $64, $0D, $77, $0D, $7C, $0D, $FF, $0D, $87, $0D, $A8, $0E, $DE
	dc.b	$0E, $80, $0E, $B0, $0E, $9F, $0E, $B4, $0E, $56, $0F, $29, $0F, $43, $0F, $7C, $0E, $75, $0E, $BA, $0E, $D0, $0E, $C2, $0D, $56, $0C, $D5, $0C, $58, $0D, $FA
	dc.b	$0C, $02, $0D, $3D, $0D, $C6, $0C, $AD, $0C, $4F, $0D, $DD, $36, $18, $80, $DD, $73, $19, $DD, $72, $1A, $21, $43, $06, $06, $04, $1A, $13, $4F, $7E, $23, $D7
	dc.b	$10, $F8, $1B, $C9, $D9, $06, $0A, $11, $30, $00, $21, $42, $1C, $77, $19, $10, $FC, $D9, $C9, $32, $07, $1C, $C9, $21, $04, $1C, $EB, $ED, $A0, $ED, $A0, $ED
	dc.b	$A0, $EB, $1B, $C9, $EB, $4E, $23, $46, $23, $EB, $2A, $04, $1C, $09, $22, $04, $1C, $1A, $21, $06, $1C, $86, $77, $C9, $DD, $E5, $CD, $72, $06, $DD, $E1, $C9
	dc.b	$32, $11, $1C, $B7, $28, $1D, $DD, $E5, $D5, $DD, $21, $40, $1C, $06, $0A, $11, $30, $00, $DD, $CB, $00, $BE, $CD, $8F, $05, $DD, $19, $10, $F5, $D1, $DD, $E1
	dc.b	$C3, $23, $09, $DD, $E5, $D5, $DD, $21, $40, $1C, $06, $0A, $11, $30, $00, $DD, $CB, $00, $FE, $DD, $19, $10, $F8, $D1, $DD, $E1, $C9, $EB, $5E, $23, $56, $23
	dc.b	$4E, $06, $00, $23, $EB, $ED, $B0, $1B, $C9, $DD, $77, $10, $C9, $DD, $77, $18, $13, $1A, $DD, $77, $19, $C9, $21, $14, $1C, $86, $77, $2B, $77, $C9, $32, $16
	dc.b	$1C, $C9, $DD, $CB, $01, $7E, $C8, $DD, $CB, $00, $A6, $DD, $35, $17, $DD, $86, $06, $DD, $77, $06, $C9, $CD, $81, $0D, $D7, $C9, $CD, $81, $0D, $DF, $C9, $EB
	dc.b	$7E, $23, $4E, $EB, $C9, $DD, $73, $20, $DD, $72, $21, $DD, $36, $07, $80, $13, $13, $13, $DD, $CB, $00, $8E, $C9, $CD, $4C, $09, $C3, $DE, $0E, $CD, $05, $04
	dc.b	$DD, $77, $1E, $DD, $77, $1F, $C9, $DD, $E5, $E1, $01, $11, $00, $09, $EB, $01, $05, $00, $ED, $B0, $3E, $01, $12, $EB, $1B, $C9, $DD, $CB, $00, $CE, $1B, $C9
	dc.b	$DD, $7E, $01, $FE, $02, $20, $2A, $DD, $CB, $00, $C6, $D9, $CD, $2D, $03, $06, $04, $C5, $D9, $1A, $13, $D9, $21, $F7, $0D, $87, $4F, $06, $00, $09, $ED, $A0
	dc.b	$ED, $A0, $C1, $10, $EC, $D9, $1B, $3E, $4F, $32, $12, $1C, $4F, $3E, $27, $DF, $C9, $13, $13, $13, $C9, $00, $00, $32, $01, $8E, $01, $E4, $01, $DD, $CB, $01
	dc.b	$7E, $20, $19, $CD, $5C, $09, $1A, $DD, $77, $08, $F5, $13, $1A, $DD, $77, $0F, $F1, $1B, $D5, $47, $CD, $E6, $05, $CD, $47, $06, $D1, $C9, $1A, $B7, $F0, $13
	dc.b	$C9, $AF, $DD, $77, $11, $0E, $3F, $DD, $7E, $0A, $A1, $EB, $B6, $DD, $77, $0A, $4F, $3E, $B4, $D7, $EB, $C9, $4F, $3E, $22, $DF, $13, $0E, $C0, $18, $E8, $D9
	dc.b	$11, $3F, $06, $DD, $6E, $1C, $DD, $66, $1D, $06, $04, $7E, $B7, $F2, $55, $0E, $DD, $86, $06, $E6, $7F, $4F, $1A, $D7, $13, $23, $10, $EF, $D9, $C9, $13, $DD
	dc.b	$86, $06, $DD, $77, $06, $1A, $DD, $CB, $01, $7E, $C0, $DD, $86, $06, $DD, $77, $06, $18, $CC, $DD, $86, $05, $DD, $77, $05, $C9, $DD, $77, $02, $C9, $DD, $CB
	dc.b	$01, $56, $C0, $3E, $DF, $32, $11, $7F, $1A, $DD, $77, $1A, $DD, $CB, $00, $C6, $B7, $20, $06, $DD, $CB, $00, $86, $3E, $FF, $32, $11, $7F, $C9, $DD, $CB, $01
	dc.b	$7E, $C8, $DD, $77, $08, $C9, $13, $DD, $CB, $01, $7E, $20, $01, $1A, $DD, $77, $07, $C9, $EB, $5E, $23, $56, $1B, $C9, $FE, $01, $20, $05, $DD, $CB, $00, $EE
	dc.b	$C9, $DD, $CB, $00, $8E, $DD, $CB, $00, $AE, $AF, $DD, $77, $10, $C9, $FE, $01, $20, $05, $DD, $CB, $00, $DE, $C9, $DD, $CB, $00, $9E, $C9, $DD, $CB, $00, $BE
	dc.b	$CD, $89, $05, $3A, $19, $1C, $B7, $28, $2D, $DD, $7E, $01, $E6, $07, $DD, $E5, $07, $4F, $06, $00, $21, $1B, $0F, $09, $4E, $23, $46, $C5, $DD, $E1, $DD, $CB
	dc.b	$00, $7E, $28, $10, $DD, $CB, $00, $96, $2A, $37, $1C, $DD, $46, $08, $CD, $F5, $05, $CD, $47, $06, $DD, $E1, $E1, $E1, $C9, $70, $1C, $A0, $1C, $70, $1C, $70
	dc.b	$1C, $D0, $1C, $00, $1D, $30, $1D, $4F, $13, $1A, $47, $C5, $DD, $E5, $E1, $DD, $35, $09, $DD, $4E, $09, $DD, $35, $09, $06, $00, $09, $72, $2B, $73, $D1, $1B
	dc.b	$C9, $DD, $E5, $E1, $DD, $4E, $09, $06, $00, $09, $5E, $23, $56, $DD, $34, $09, $DD, $34, $09, $C9, $13, $C6, $28, $4F, $06, $00, $DD, $E5, $E1, $09, $7E, $B7
	dc.b	$20, $02, $1A, $77, $13, $35, $C2, $B4, $0E, $13, $C9, $CD, $6B, $04, $20, $0D, $CD, $3D, $03, $DD, $CB, $00, $66, $C0, $CD, $A2, $04, $18, $0C, $DD, $7E, $1E
	dc.b	$B7, $28, $06, $DD, $35, $1E, $CA, $14, $10, $CD, $99, $05, $CD, $CD, $04, $DD, $CB, $00, $56, $C0, $DD, $4E, $01, $7D, $E6, $0F, $B1, $32, $11, $7F, $7D, $E6
	dc.b	$F0, $B4, $0F, $0F, $0F, $0F, $32, $11, $7F, $DD, $7E, $08, $B7, $0E, $00, $28, $09, $3D, $0E, $0A, $E7, $EF, $CD, $E3, $0F, $4F, $DD, $CB, $00, $66, $C0, $DD
	dc.b	$7E, $06, $81, $CB, $67, $28, $02, $3E, $0F, $DD, $B6, $01, $C6, $10, $DD, $CB, $00, $46, $20, $04, $32, $11, $7F, $C9, $C6, $20, $32, $11, $7F, $C9, $DD, $77
	dc.b	$17, $E5, $DD, $4E, $17, $CD, $DF, $05, $E1, $CB, $7F, $28, $21, $FE, $83, $28, $0C, $FE, $81, $28, $13, $FE, $80, $28, $0C, $03, $0A, $18, $E1, $DD, $CB, $00
	dc.b	$E6, $E1, $C3, $14, $10, $AF, $18, $D6, $E1, $DD, $CB, $00, $E6, $C9, $DD, $34, $17, $C9, $DD, $CB, $00, $E6, $DD, $CB, $00, $56, $C0, $3E, $1F, $DD, $86, $01
	dc.b	$F0, $32, $11, $7F, $DD, $CB, $00, $46, $C8, $3E, $FF, $32, $11, $7F, $C9, $3A, $BF, $1F, $47, $10, $FE, $21, $B8, $1F, $7E, $1F, $3F, $D2, $4F, $10, $17, $77
	dc.b	$2A, $BA, $1F, $7E, $E6, $F0, $0F, $0F, $0F, $0F, $C3, $97, $10, $17, $77, $2A, $BC, $1F, $2B, $22, $BC, $1F, $7D, $B4, $20, $31, $3A, $B8, $1F, $E6, $08, $CA
	dc.b	$7D, $10, $AF, $32, $B0, $1E, $4F, $3E, $2B, $CD, $0E, $06, $0E, $7F, $3E, $42, $06, $04, $08, $CD, $21, $06, $08, $C6, $04, $10, $F7, $AF, $32, $B8, $1F, $32
	dc.b	$B9, $1F, $4F, $3E, $2B, $CD, $0E, $06, $C3, $E4, $10, $2A, $BA, $1F, $7E, $23, $22, $BA, $1F, $E6, $0F, $26, $01, $6F, $3A, $BE, $1F, $86, $32, $BE, $1F, $4F
	dc.b	$3E, $2A, $C3, $0E, $06, $FA, $5C, $10, $08, $3E, $80, $32, $01, $1C, $CD, $D0, $07, $08, $E6, $0F, $3D, $87, $87, $87, $4F, $AF, $32, $B7, $1F, $47, $21, $E8
	dc.b	$10, $09, $23, $3A, $B9, $1F, $BE, $28, $02, $30, $17, $2B, $11, $B8, $1F, $01, $08, $00, $ED, $B0, $3E, $2B, $0E, $80, $CD, $0E, $06, $3E, $B6, $0E, $C0, $CD
	dc.b	$21, $06, $21, $B7, $1F, $C9, $80, $08, $6C, $E8, $E8, $05, $80, $07, $80, $08, $00, $80, $80, $08, $80, $07, $80, $08, $00, $B8, $00, $08, $80, $07, $80, $08
	dc.b	$80, $88, $80, $0F, $80, $0A, $80, $08, $54, $EE, $00, $06, $80, $0A, $80, $08, $00, $98, $00, $0F, $80, $0A, $80, $00, $30, $D9, $3C, $0F, $80, $04, $80, $00
	dc.b	$00, $A7, $00, $11, $80, $04, $80, $00, $00, $A7, $00, $11, $80, $06, $80, $00, $00, $A7, $00, $11, $80, $08, $80, $00, $00, $A7, $00, $11, $80, $0A, $80, $00
	dc.b	$00, $A7, $00, $11, $80, $0C, $80, $00, $00, $A7, $00, $11, $80, $0E, $80, $00, $00, $A7, $00, $11, $80, $10, $88, $80, $54, $F4, $AB, $0B, $80, $09, $3E, $80
	dc.b	$32, $01, $1C, $CD, $D0, $07, $21, $0A, $1C, $11, $0B, $1C, $01, $35, $00, $AF, $77, $ED, $B0, $21, $40, $1C, $11, $30, $00, $06, $0D, $77, $19, $10, $FC, $32
	dc.b	$B6, $1F, $CD, $E9, $0D, $21, $11, $7F, $36, $9F, $36, $BF, $36, $DF, $36, $FF, $21, $96, $12, $06, $05, $7E, $23, $4E, $23, $CD, $0E, $06, $10, $F7, $0E, $00
	dc.b	$11, $CF, $11, $CD, $47, $12, $0E, $01, $11, $ED, $11, $CD, $47, $12, $0E, $02, $11, $0B, $12, $CD, $47, $12, $0E, $00, $11, $0B, $12, $CD, $5B, $12, $21, $8E
	dc.b	$12, $06, $04, $7E, $23, $4E, $23, $CD, $0E, $06, $10, $F7, $C9, $3A, $B7, $00, $01, $00, $01, $14, $26, $00, $7F, $1F, $1F, $1F, $15, $1F, $1F, $1F, $1F, $00
	dc.b	$00, $00, $00, $0F, $0F, $0F, $0F, $00, $00, $00, $00, $3A, $77, $00, $01, $00, $01, $14, $26, $00, $7F, $1F, $1F, $1F, $15, $1F, $1F, $1F, $1F, $00, $00, $00
	dc.b	$00, $0F, $0F, $0F, $0F, $00, $00, $00, $00, $3A, $F7, $00, $01, $00, $01, $14, $26, $00, $7F, $1F, $1F, $1F, $15, $1F, $1F, $1F, $1F, $00, $00, $00, $00, $0F
	dc.b	$0F, $0F, $0F, $00, $00, $00, $00, $B0, $B4, $30, $34, $38, $3C, $40, $44, $48, $4C, $50, $54, $58, $5C, $60, $64, $68, $6C, $70, $74, $78, $7C, $80, $84, $88
	dc.b	$8C, $90, $94, $98, $9C, $06, $1E, $21, $29, $12, $C5, $41, $1A, $13, $4F, $7E, $23, $80, $CD, $0E, $06, $C1, $10, $F2, $C9, $06, $1E, $21, $29, $12, $C5, $41
	dc.b	$1A, $13, $4F, $7E, $23, $80, $CD, $21, $06, $C1, $10, $F2, $C9, $21, $98, $12, $06, $11, $7E, $23, $4E, $23, $CD, $0E, $06, $10, $F7, $21, $A2, $12, $06, $04
	dc.b	$7E, $23, $4E, $23, $CD, $21, $06, $10, $F7, $C3, $8B, $00, $28, $F0, $28, $F1, $28, $F2, $28, $F4, $22, $0E, $28, $00, $28, $01, $28, $02, $28, $04, $22, $00
	dc.b	$40, $7F, $44, $7F, $48, $7F, $4C, $7F, $41, $7F, $45, $7F, $49, $7F, $4D, $7F, $42, $7F, $46, $7F, $4A, $7F, $4E, $7F, $F8, $3E, $02, $32, $10, $1C, $0E, $7F
	dc.b	$DD, $21, $20, $1E, $DD, $CB, $00, $7E, $20, $07, $3E, $4C, $CD, $0E, $06, $18, $03, $CD, $78, $13, $DD, $21, $50, $1E, $DD, $CB, $00, $7E, $20, $07, $3E, $4D
	dc.b	$CD, $0E, $06, $18, $03, $CD, $78, $13, $3E, $4E, $CD, $0E, $06, $3E, $4C, $CD, $21, $06, $DD, $21, $B0, $1E, $DD, $CB, $00, $7E, $20, $07, $3E, $4D, $CD, $21
	dc.b	$06, $18, $03, $CD, $78, $13, $DD, $21, $E0, $1E, $DD, $CB, $00, $7E, $20, $09, $0E, $7F, $3E, $4E, $CD, $21, $06, $18, $03, $CD, $78, $13, $3A, $10, $1C, $B7
	dc.b	$F2, $1E, $13, $AF, $32, $10, $1C, $DD, $21, $20, $1E, $DD, $CB, $00, $7E, $28, $03, $CD, $59, $13, $DD, $21, $50, $1E, $DD, $CB, $00, $7E, $28, $03, $CD, $59
	dc.b	$13, $DD, $21, $B0, $1E, $DD, $CB, $00, $7E, $28, $03, $CD, $59, $13, $DD, $21, $E0, $1E, $DD, $CB, $00, $7E, $C8, $11, $3F, $06, $DD, $6E, $1C, $DD, $66, $1D
	dc.b	$06, $04, $7E, $B7, $F2, $73, $13, $DD, $86, $06, $E6, $7F, $4F, $1A, $CD, $00, $06, $13, $23, $10, $ED, $C9, $11, $3F, $06, $DD, $6E, $1C, $DD, $66, $1D, $06
	dc.b	$04, $7E, $B7, $F2, $8E, $13, $1A, $0E, $7F, $CD, $00, $06, $13, $23, $10, $F1, $C9, $1A, $32, $00, $40, $13, $7E, $23, $32, $01, $40, $CD, $B3, $14, $10, $F1
	dc.b	$C9, $1A, $32, $02, $40, $13, $7E, $23, $32, $03, $40, $CD, $B3, $14, $10, $F1, $C9, $21, $B6, $1F, $3A, $20, $1E, $B7, $FA, $E4, $13, $CB, $6E, $28, $16, $CB
	dc.b	$AE, $3E, $28, $0E, $00, $CD, $0E, $06, $11, $CF, $11, $CD, $47, $12, $3E, $28, $0E, $F0, $C3, $0E, $06, $21, $A0, $1F, $11, $A1, $14, $06, $03, $CD, $93, $13
	dc.b	$18, $02, $CB, $EE, $21, $B6, $1F, $3A, $50, $1E, $B7, $FA, $17, $14, $CB, $5E, $28, $16, $CB, $9E, $3E, $28, $0E, $01, $CD, $0E, $06, $11, $ED, $11, $CD, $47
	dc.b	$12, $3E, $28, $0E, $F1, $C3, $0E, $06, $21, $A3, $1F, $11, $A4, $14, $06, $03, $CD, $93, $13, $18, $02, $CB, $DE, $21, $A6, $1F, $11, $A7, $14, $06, $09, $CD
	dc.b	$93, $13, $21, $AF, $1F, $11, $A1, $14, $06, $03, $CD, $A3, $13, $21, $B6, $1F, $3A, $B0, $1E, $B7, $F2, $3D, $14, $CB, $BE, $18, $2D, $CB, $7E, $20, $1C, $CB
	dc.b	$FE, $D9, $3E, $28, $0E, $05, $CD, $0E, $06, $0E, $01, $11, $CF, $11, $CD, $5B, $12, $3E, $28, $0E, $F5, $CD, $0E, $06, $D9, $18, $0D, $D9, $21, $C0, $1F, $11
	dc.b	$A4, $14, $06, $03, $CD, $A3, $13, $D9, $3A, $E0, $1E, $B7, $F2, $74, $14, $CB, $B6, $C9, $CB, $76, $20, $18, $CB, $F6, $3E, $28, $0E, $06, $CD, $0E, $06, $0E
	dc.b	$02, $11, $ED, $11, $CD, $5B, $12, $3E, $28, $0E, $F6, $C3, $0E, $06, $3A, $B8, $1F, $B7, $F8, $21, $C3, $1F, $11, $B0, $14, $06, $03, $CD, $A3, $13, $C9, $A4
	dc.b	$A0, $4C, $A5, $A1, $4D, $AD, $A9, $AC, $A8, $AE, $AA, $A6, $A2, $4E, $A6, $A2, $4E, $DD, $E3, $DD, $E3, $DD, $E3, $DD, $E3, $C9, $23, $15, $41, $15, $23, $15
	dc.b	$6C, $15, $99, $15, $C8, $15, $DF, $15, $E9, $15, $F3, $15, $1E, $16, $28, $16, $D5, $16, $EE, $16, $01, $17, $1A, $17, $37, $16, $4B, $16, $5F, $16, $41, $16
	dc.b	$55, $16, $69, $16, $88, $16, $23, $15, $23, $15, $23, $15, $23, $15, $A2, $16, $FC, $14, $23, $15, $06, $15, $23, $15, $23, $15, $01, $B0, $1E, $80, $05, $01
	dc.b	$10, $15, $F0, $00, $01, $B0, $1E, $80, $05, $01, $15, $15, $F0, $00, $E0, $40, $F6, $17, $15, $E0, $80, $EF, $08, $FC, $01, $9D, $ED, $0C, $FC, $00, $80, $02
	dc.b	$F2, $01, $50, $1E, $80, $01, $01, $2D, $15, $00, $10, $EF, $00, $F4, $0A, $C8, $0A, $80, $10, $C8, $0A, $80, $03, $F7, $00, $04, $31, $15, $80, $0A, $F2, $02
	dc.b	$B0, $1E, $80, $05, $01, $54, $15, $FB, $10, $E0, $1E, $80, $06, $01, $5F, $15, $FB, $10, $EF, $01, $F4, $0A, $B6, $12, $BE, $13, $80, $10, $F2, $EF, $01, $F4
	dc.b	$0A, $80, $09, $BD, $12, $C5, $0A, $80, $10, $F2, $02, $B0, $1E, $80, $05, $01, $7F, $15, $FB, $0C, $E0, $1E, $80, $06, $01, $84, $15, $FB, $0C, $EF, $03, $F6
	dc.b	$8C, $15, $EF, $03, $80, $02, $F4, $0A, $E6, $0E, $BD, $68, $E6, $02, $E7, $BD, $04, $F7, $00, $18, $8E, $15, $F2, $02, $B0, $1E, $80, $05, $01, $AC, $15, $FB
	dc.b	$0C, $E0, $1E, $80, $06, $01, $B1, $15, $FB, $0C, $EF, $04, $F6, $B9, $15, $EF, $04, $80, $02, $F4, $0A, $E6, $0E, $C9, $7F, $E7, $40, $E6, $02, $E7, $C9, $04
	dc.b	$F7, $00, $18, $BD, $15, $F2, $01, $B0, $1E, $80, $05, $01, $D2, $15, $FB, $0B, $EF, $05, $F4, $04, $94, $04, $80, $02, $94, $04, $80, $08, $F2, $01, $B0, $1E
	dc.b	$80, $05, $01, $FD, $15, $F8, $00, $01, $B0, $1E, $80, $05, $01, $02, $16, $F8, $0C, $01, $B0, $1E, $80, $05, $01, $07, $16, $F8, $00, $E0, $40, $F6, $09, $16
	dc.b	$E0, $C0, $F6, $09, $16, $E0, $80, $EF, $06, $FC, $01, $9D, $ED, $09, $FC, $00, $80, $02, $FC, $01, $A1, $F3, $10, $FC, $00, $80, $20, $F2, $01, $B0, $1E, $80
	dc.b	$05, $01, $32, $16, $04, $10, $01, $20, $1E, $80, $00, $01, $32, $16, $04, $10, $EF, $07, $93, $30, $F2, $01, $20, $1E, $80, $00, $01, $73, $16, $18, $08, $01
	dc.b	$B0, $1E, $80, $05, $01, $73, $16, $18, $08, $01, $20, $1E, $80, $00, $01, $78, $16, $18, $14, $01, $B0, $1E, $80, $05, $01, $78, $16, $18, $14, $01, $20, $1E
	dc.b	$80, $00, $01, $7D, $16, $18, $08, $01, $B0, $1E, $80, $05, $01, $7D, $16, $18, $08, $E0, $40, $F6, $7F, $16, $E0, $C0, $F6, $7F, $16, $E0, $80, $EF, $09, $81
	dc.b	$06, $86, $06, $86, $06, $F2, $01, $B0, $1E, $80, $05, $01, $92, $16, $00, $04, $EF, $0B, $A4, $10, $80, $0A, $F7, $00, $08, $94, $16, $EF, $02, $81, $02, $F2
	dc.b	$02, $B0, $1E, $80, $05, $01, $B5, $16, $08, $0C, $E0, $1E, $80, $06, $01, $B7, $16, $02, $08, $80, $02, $EF, $0A, $FF, $06, $00, $0C, $0C, $0C, $B0, $60, $E7
	dc.b	$10, $E6, $05, $F7, $00, $08, $C1, $16, $FF, $06, $00, $00, $00, $00, $EF, $02, $81, $02, $F2, $01, $B0, $1E, $80, $05, $01, $DF, $16, $F8, $00, $EF, $0C, $FC
	dc.b	$01, $C0, $01, $08, $C0, $01, $08, $FC, $00, $80, $02, $F2, $01, $B0, $1E, $80, $05, $01, $F8, $16, $14, $00, $EF, $0D, $A8, $08, $A8, $08, $80, $02, $F2, $01
	dc.b	$B0, $1E, $80, $05, $01, $0B, $17, $0C, $00, $EF, $0E, $FC, $01, $B0, $04, $08, $B0, $04, $08, $FC, $00, $80, $02, $F2, $01, $B0, $1E, $80, $05, $01, $24, $17
	dc.b	$10, $00, $EF, $0F, $89, $08, $E6, $06, $E7, $01, $F7, $00, $08, $28, $17, $80, $02, $F2, $15, $42, $71, $31, $15, $1F, $14, $13, $1D, $06, $00, $00, $06, $05
	dc.b	$00, $00, $00, $CD, $FA, $FA, $FA, $2A, $80, $98, $8D, $04, $31, $62, $75, $31, $1E, $1C, $1E, $1E, $98, $07, $18, $07, $09, $0C, $09, $0C, $53, $47, $54, $47
	dc.b	$0C, $80, $0C, $80, $07, $00, $00, $00, $00, $DF, $DF, $DF, $DF, $1F, $1F, $1F, $1F, $0F, $0F, $0F, $0F, $FF, $FF, $FF, $FF, $7F, $7F, $7F, $7F, $15, $21, $31
	dc.b	$21, $13, $10, $10, $10, $10, $03, $03, $03, $03, $05, $00, $00, $00, $CF, $FF, $FF, $FF, $18, $80, $80, $8C, $15, $21, $31, $21, $13, $10, $10, $10, $10, $02
	dc.b	$02, $02, $02, $05, $00, $00, $00, $CF, $FF, $FF, $FF, $18, $80, $80, $8C, $05, $3F, $1F, $2F, $2F, $DF, $DF, $DF, $DF, $09, $07, $08, $09, $CF, $CC, $C8, $C9
	dc.b	$4F, $8F, $8F, $8F, $04, $7F, $80, $80, $E0, $12, $10, $7C, $70, $1F, $1F, $1F, $1F, $1F, $1F, $1A, $0E, $00, $03, $00, $C4, $03, $16, $04, $18, $08, $17, $12
	dc.b	$80, $FA, $10, $20, $4F, $71, $09, $DF, $DF, $DF, $0F, $0F, $0F, $0F, $00, $00, $00, $00, $07, $07, $07, $0E, $15, $14, $12, $80, $E0, $12, $10, $7C, $70, $1F
	dc.b	$1F, $1F, $1F, $1F, $1F, $1A, $0E, $00, $03, $00, $C4, $03, $16, $04, $18, $00, $17, $12, $80, $35, $07, $50, $44, $12, $DF, $DF, $DF, $DF, $04, $04, $08, $09
	dc.b	$00, $C0, $00, $00, $4C, $6C, $FC, $2C, $09, $80, $80, $80, $65, $79, $31, $43, $B7, $1F, $1F, $1F, $1F, $09, $1F, $1F, $1F, $07, $0B, $0B, $0B, $0F, $7F, $7F
	dc.b	$7F, $1C, $80, $80, $80, $07, $00, $00, $06, $16, $00, $00, $1F, $1F, $1F, $1F, $0B, $0B, $0F, $0F, $0F, $0F, $FF, $FF, $37, $37, $7F, $7F, $80, $80, $04, $23
	dc.b	$48, $14, $28, $D1, $DF, $D1, $D0, $00, $88, $00, $85, $40, $5F, $40, $5F, $0F, $1F, $0F, $1F, $16, $88, $12, $80, $04, $09, $04, $04, $04, $1F, $DF, $DF, $DF
	dc.b	$00, $00, $09, $09, $80, $D2, $DF, $DF, $0F, $FF, $2F, $2F, $16, $80, $80, $80, $05, $14, $0A, $01, $23, $DF, $DF, $DF, $DF, $06, $05, $00, $00, $C0, $DF, $CC
	dc.b	$CC, $6F, $1F, $0F, $0F, $10, $80, $80, $80, $05, $1F, $2F, $2F, $2F, $DF, $DF, $DF, $DF, $09, $07, $08, $09, $3F, $3C, $38, $39, $8F, $8F, $8F, $8F, $06, $80
	dc.b	$86, $80, $9C, $19, $06, $00, $01, $10, $66, $19, $00, $06, $E2, $18, $FD, $0F, $08, $19, $FD, $0F, $24, $19, $FD, $0F, $3D, $19, $09, $0F, $4F, $19, $FD, $0A
	dc.b	$EF, $00, $EA, $09, $00, $E8, $80, $2A, $B0, $06, $80, $12, $B0, $AF, $06, $80, $AE, $30, $E4, $01, $00, $00, $04, $01, $80, $02, $B0, $06, $AB, $AE, $B3, $AE
	dc.b	$B0, $AE, $80, $B0, $30, $E3, $EF, $00, $80, $2A, $B5, $06, $E0, $80, $80, $12, $B5, $B4, $06, $80, $A7, $30, $B0, $06, $AB, $AE, $B3, $AE, $B0, $B3, $80, $B5
	dc.b	$30, $E3, $EF, $00, $80, $2A, $BA, $06, $E0, $40, $80, $12, $BA, $B9, $06, $80, $AC, $30, $AB, $12, $AE, $AE, $06, $80, $B0, $30, $E3, $EF, $00, $80, $30, $80
	dc.b	$80, $B0, $06, $AB, $AE, $B3, $AE, $B0, $B7, $80, $B9, $30, $E3, $EF, $01, $80, $2A, $AE, $06, $80, $12, $A2, $A1, $06, $80, $A0, $30, $A4, $12, $A7, $AB, $06
	dc.b	$80, $AD, $30, $E3, $85, $06, $84, $84, $81, $82, $83, $8A, $89, $8A, $8A, $84, $85, $0C, $8A, $06, $85, $8A, $85, $E6, $18, $84, $03, $84, $03, $84, $03, $84
	dc.b	$03, $84, $06, $E6, $E8, $84, $81, $82, $03, $83, $03, $83, $03, $83, $03, $85, $06, $8A, $8A, $85, $8A, $8A, $85, $8A, $85, $E3, $3A, $01, $23, $01, $11, $90
	dc.b	$46, $16, $56, $09, $07, $0C, $05, $02, $00, $00, $00, $28, $38, $08, $18, $1B, $2B, $22, $80, $20, $36, $35, $30, $31, $DF, $DF, $9F, $9F, $05, $04, $07, $04
	dc.b	$03, $02, $02, $04, $29, $19, $19, $E9, $1E, $3A, $16, $80, $A6, $1B, $06, $00, $01, $10, $E4, $1A, $00, $06, $EC, $19, $FD, $0E, $40, $1A, $FD, $12, $6A, $1A
	dc.b	$FD, $12, $92, $1A, $FD, $12, $BA, $1A, $FD, $12, $EA, $38, $00, $E8, $EF, $01, $80, $12, $99, $9A, $06, $80, $9B, $80, $9C, $80, $9D, $9E, $80, $6C, $A4, $12
	dc.b	$06, $0C, $A9, $18, $80, $06, $A2, $06, $0C, $A7, $18, $80, $06, $A0, $06, $0C, $A5, $18, $80, $06, $9E, $06, $0C, $A0, $18, $80, $06, $A4, $06, $0C, $A9, $18
	dc.b	$80, $06, $A2, $06, $0C, $A7, $18, $80, $06, $A8, $06, $0C, $AD, $18, $80, $06, $A2, $06, $0C, $A7, $A0, $12, $06, $80, $A0, $12, $A0, $A0, $06, $E3, $F0, $30
	dc.b	$01, $01, $08, $EF, $00, $E0, $80, $80, $12, $B1, $B2, $06, $80, $B3, $80, $B4, $80, $B5, $B6, $80, $6C, $B5, $54, $B3, $60, $B5, $6C, $B4, $30, $B3, $B5, $12
	dc.b	$06, $80, $B6, $12, $B5, $C1, $06, $E3, $F0, $30, $01, $01, $08, $EF, $00, $80, $12, $B5, $B6, $06, $80, $B7, $80, $B8, $80, $B9, $BA, $80, $6C, $B8, $54, $B6
	dc.b	$60, $B8, $6C, $B8, $30, $B6, $B8, $12, $06, $80, $BA, $12, $B8, $B8, $06, $E3, $F0, $30, $01, $01, $08, $EF, $00, $80, $12, $BB, $BC, $06, $80, $BD, $80, $BE
	dc.b	$80, $BF, $C0, $80, $6C, $BF, $54, $BD, $60, $BF, $6C, $BE, $30, $BD, $BF, $12, $06, $80, $C0, $12, $BF, $BF, $06, $E3, $F0, $30, $01, $01, $08, $EF, $00, $E0
	dc.b	$40, $80, $12, $BF, $C0, $06, $80, $C1, $80, $C2, $80, $C3, $C4, $80, $6C, $C3, $54, $C1, $60, $C3, $6C, $C2, $30, $C1, $C3, $12, $06, $80, $C4, $12, $C3, $C3
	dc.b	$06, $E3, $80, $0C, $85, $06, $85, $80, $0C, $85, $85, $85, $84, $06, $84, $8A, $81, $03, $81, $03, $81, $06, $81, $82, $03, $82, $03, $82, $06, $82, $83, $03
	dc.b	$83, $03, $83, $06, $83, $85, $85, $85, $85, $84, $85, $12, $85, $0C, $85, $06, $84, $89, $E6, $18, $84, $03, $84, $03, $84, $03, $84, $03, $E6, $EC, $84, $06
	dc.b	$E6, $FC, $85, $0C, $85, $06, $8A, $84, $0C, $85, $06, $8A, $89, $0C, $85, $06, $8A, $84, $E6, $18, $84, $03, $84, $03, $84, $03, $84, $03, $E6, $EC, $84, $06
	dc.b	$E6, $FC, $85, $06, $84, $85, $8A, $84, $0C, $85, $06, $8A, $89, $0C, $85, $06, $8A, $84, $E6, $18, $84, $03, $84, $03, $84, $03, $84, $03, $E6, $EC, $84, $06
	dc.b	$E6, $FC, $85, $06, $85, $85, $06, $8A, $84, $0C, $8A, $06, $85, $85, $0C, $8A, $06, $85, $84, $85, $03, $E6, $18, $84, $03, $84, $03, $84, $03, $E6, $EC, $84
	dc.b	$06, $E6, $FC, $85, $0C, $E6, $18, $84, $03, $84, $03, $84, $03, $84, $03, $E6, $E8, $84, $06, $84, $84, $84, $85, $0C, $8A, $06, $84, $85, $85, $8A, $8A, $85
	dc.b	$80, $8A, $85, $E3, $3D, $64, $A4, $32, $31, $1F, $1F, $1E, $1D, $13, $14, $11, $09, $06, $07, $05, $07, $57, $2A, $2A, $2C, $16, $84, $89, $80, $20, $36, $35
	dc.b	$30, $31, $DF, $DF, $9F, $9F, $05, $04, $07, $04, $03, $02, $02, $04, $29, $19, $19, $E9, $1E, $3A, $16, $80, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $07, $80
	dc.b	$27, $01, $00, $01, $E8, $80, $00, $00, $00, $00, $00, $00, $00, $00, $4B, $D5, $BB, $43, $AE, $60, $D1, $5C, $E6, $CD, $62, $D2, $6E, $35, $DD, $A6, $E5, $B6
	dc.b	$EE, $75, $F5, $6F, $7F, $65, $E6, $6F, $55, $5E, $C7, $F5, $6F, $66, $CF, $66, $DE, $66, $FB, $7E, $D5, $C1, $5C, $E6, $5E, $6E, $D6, $5D, $E6, $3D, $44, $5E
	dc.b	$36, $EA, $50, $E6, $5F, $65, $E6, $CE, $6E, $54, $52, $E6, $DB, $C5, $5E, $55, $E6, $E6, $DD, $6E, $44, $D5, $AD, $34, $3B, $B6, $E2, $D6, $6F, $6D, $5D, $C6
	dc.b	$E6, $3F, $7E, $5B, $D6, $E4, $3C, $6E, $E7, $5E, $E6, $D5, $3D, $5E, $6D, $5E, $60, $E5, $4D, $5B, $5E, $C6, $D5, $BC, $52, $3E, $54, $9E, $6D, $3D, $6E, $52
	dc.b	$5E, $46, $3E, $E6, $64, $EE, $36, $5E, $D5, $64, $E1, $B3, $E6, $03, $5E, $65, $DE, $D5, $6C, $ED, $65, $4E, $3C, $47, $EF, $56, $7F, $E6, $6C, $FA, $6B, $3C
	dc.b	$25, $E6, $6E, $F6, $63, $9E, $56, $ED, $65, $EE, $56, $D4, $46, $FE, $67, $DF, $06, $7F, $D6, $43, $F3, $73, $DF, $67, $EC, $F7, $6F, $E4, $76, $FE, $67, $68
	dc.b	$55, $7C, $87, $76, $FF, $77, $FF, $77, $86, $E7, $5F, $C7, $7F, $F5, $79, $FE, $8F, $4F, $77, $FE, $67, $EF, $D7, $5F, $C7, $F6, $E7, $6F, $46, $5F, $5E, $74
	dc.b	$F5, $5E, $36, $D6, $F5, $65, $EC, $E6, $6E, $C6, $E4, $C6, $5F, $64, $6F, $5D, $46, $E5, $6F, $65, $24, $F6, $64, $F5, $D6, $5E, $C6, $F6, $55, $2E, $56, $4F
	dc.b	$5E, $66, $CF, $7D, $D5, $D6, $DB, $D6, $E6, $E1, $66, $F4, $5E, $6E, $7E, $9C, $6E, $5E, $45, $6E, $E6, $6E, $AE, $66, $ED, $46, $5F, $D6, $6D, $E6, $F7, $E6
	dc.b	$D1, $B6, $BC, $DD, $56, $DE, $C7, $F6, $E6, $6E, $4D, $56, $EE, $56, $9E, $D6, $E6, $E6, $5D, $1B, $D6, $DE, $63, $4D, $E7, $EB, $4E, $7C, $E5, $E6, $3F, $62
	dc.b	$6D, $E1, $7F, $6E, $56, $4E, $4E, $7E, $D3, $46, $DE, $55, $E6, $E6, $93, $E3, $06, $EC, $C6, $6E, $EC, $74, $F5, $E7, $5E, $EA, $66, $EC, $D6, $5E, $DC, $7E
	dc.b	$E6, $E7, $DE, $2C, $6B, $D3, $A6, $1E, $1D, $7C, $F6, $E6, $5E, $05, $45, $F6, $C6, $3E, $DC, $67, $FD, $4B, $7E, $F6, $C6, $D0, $D6, $C5, $E5, $E6, $6E, $E6
	dc.b	$E6, $AD, $45, $14, $E3, $55, $E9, $D5, $C7, $EF, $7F, $7C, $E4, $D7, $CE, $5E, $62, $E5, $E6, $7E, $F7, $F7, $CE, $A6, $5A, $F6, $19, $5E, $33, $05, $6F, $36
	dc.b	$E6, $D3, $C4, $6D, $E6, $E6, $CD, $CB, $56, $3F, $6E, $66, $F6, $D6, $5E, $2B, $D6, $E5, $E6, $36, $EE, $6C, $46, $EB, $44, $3C, $D4, $B5, $C2, $E5, $56, $CF
	dc.b	$6D, $65, $ED, $6D, $6E, $D5, $D6, $DE, $53, $6E, $D6, $D6, $1E, $25, $59, $EC, $55, $D5, $E5, $B6, $DE, $6D, $55, $E5, $E6, $5E, $4B, $C6, $E5, $DA, $46, $DE
	dc.b	$6E, $65, $DE, $54, $54, $EC, $35, $DA, $32, $6E, $D6, $E7, $EE, $6D, $53, $E6, $D4, $C3, $E6, $D6, $EB, $6E, $65, $E5, $D4, $5E, $45, $D5, $ED, $6D, $56, $F6
	dc.b	$D5, $6F, $60, $B6, $E1, $5D, $6E, $4D, $44, $5F, $7E, $63, $DC, $5E, $6E, $45, $C5, $DD, $44, $B6, $F7, $E2, $6E, $D6, $E6, $E4, $6D, $5E, $4D, $5C, $7F, $36
	dc.b	$F7, $EC, $6D, $45, $F7, $E5, $4E, $35, $D6, $DF, $7E, $65, $F6, $5D, $7F, $36, $E6, $ED, $6C, $36, $FC, $7F, $7D, $E6, $C5, $5F, $55, $D6, $E4, $C5, $B6, $F2
	dc.b	$7F, $7E, $D6, $AD, $6F, $55, $D6, $E3, $A5, $D6, $EE, $7F, $7D, $D5, $4D, $6F, $6B, $5A, $4E, $6E, $56, $5F, $6E, $36, $F7, $E5, $5D, $D5, $D6, $CD, $C5, $C5
	dc.b	$6F, $46, $F7, $ED, $7F, $7D, $E3, $4B, $5B, $D5, $D1, $7D, $F7, $F6, $6F, $7E, $C6, $EE, $6E, $7E, $2E, $6D, $73, $88, $F5, $78, $7C, $C7, $FE, $6D, $7E, $0E
	dc.b	$6D, $75, $FE, $6E, $7E, $F7, $E7, $DF, $56, $56, $FD, $B7, $45, $C8, $76, $E7, $FE, $7E, $7F, $E7, $49, $5F, $56, $5D, $E6, $EE, $7F, $66, $F7, $0F, $7F, $C7
	dc.b	$E6, $DF, $76, $E5, $6F, $C7, $F7, $EF, $7D, $46, $F6, $6E, $6F, $37, $BE, $36, $DF, $7F, $7B, $F7, $E5, $6F, $62, $56, $FD, $6A, $6E, $F7, $6F, $7E, $E7, $EF
	dc.b	$8F, $46, $F5, $6E, $6E, $E7, $CD, $4E, $7A, $F6, $4E, $7F, $E7, $CD, $6F, $66, $E5, $BE, $7D, $EA, $79, $F6, $E5, $78, $66, $D7, $FB, $66, $3A, $F5, $55, $EC
	dc.b	$46, $F7, $F6, $6F, $56, $D6, $FD, $66, $4D, $E6, $6C, $FD, $76, $87, $4D, $7F, $E8, $F6, $CF, $66, $E6, $FA, $7C, $D3, $F7, $6D, $2F, $07, $DE, $CE, $77, $FD
	dc.b	$6E, $7E, $F7, $D2, $6F, $A7, $6E, $F7, $F7, $DF, $7D, $6C, $FE, $75, $6F, $BC, $7E, $5F, $77, $87, $E1, $7F, $44, $66, $DF, $55, $6E, $EE, $76, $CF, $D7, $ED
	dc.b	$6F, $8F, $E6, $D6, $CE, $E7, $69, $FE, $67, $EE, $E6, $75, $FE, $7C, $5C, $F6, $6D, $5F, $B7, $A4, $FD, $76, $EF, $C7, $6F, $69, $E7, $FE, $7E, $65, $F6, $6E
	dc.b	$6F, $47, $DD, $CE, $76, $87, $5E, $7E, $F7, $D6, $58, $77, $E6, $FE, $76, $E2, $F7, $7E, $87, $66, $68, $D8, $EC, $3F, $66, $E5, $F4, $7B, $EE, $47, $78, $97
	dc.b	$E7, $C8, $76, $D7, $FE, $7D, $3D, $F7, $7F, $1E, $57, $18, $76, $B7, $FF, $8F, $54, $87, $7E, $6F, $C7, $DD, $2F, $77, $85, $7E, $7D, $88, $5F, $7F, $D7, $E3
	dc.b	$4F, $76, $F6, $E3, $79, $87, $7C, $6F, $F7, $6F, $7F, $C7, $E2, $AF, $76, $F5, $D6, $7E, $88, $AD, $78, $C8, $F5, $48, $85, $F7, $FD, $7E, $30, $E7, $78, $B7
	dc.b	$E7, $D8, $76, $E7, $FE, $8F, $5D, $F7, $5E, $6F, $57, $B8, $76, $A7, $FF, $8E, $D5, $87, $7E, $6F, $E7, $5E, $5F, $77, $FF, $7A, $66, $85, $7E, $6C, $F7, $5E
	dc.b	$6F, $47, $E9, $DE, $76, $87, $5C, $7F, $F8, $F6, $58, $77, $E6, $FE, $7C, $34, $F7, $78, $66, $F8, $FF, $7D, $17, $86, $7E, $6D, $F7, $4E, $6F, $67, $FE, $7F
	dc.b	$76, $87, $7F, $7F, $F8, $ED, $6F, $37, $F5, $DA, $7E, $F7, $D5, $78, $67, $F7, $EF, $75, $E6, $F6, $7F, $C5, $C7, $FE, $7E, $7D, $88, $DD, $6F, $B7, $E6, $EF
	dc.b	$76, $EA, $F7, $7F, $E7, $F7, $CF, $7D, $46, $86, $7D, $6E, $F7, $6E, $4F, $76, $F6, $BE, $7E, $F7, $D5, $6F, $66, $F7, $EE, $7E, $D6, $F7, $68, $67, $E7, $EF
	dc.b	$76, $F6, $EE, $7D, $C4, $F7, $6F, $5D, $67, $FF, $7D, $66, $87, $7F, $7F, $E7, $D3, $0F, $76, $F6, $E4, $7F, $E7, $E7, $08, $76, $D7, $84, $8F, $5E, $F7, $6E
	dc.b	$5F, $68, $F8, $8F, $76, $85, $7E, $7F, $F7, $6D, $3F, $67, $EE, $E5, $8E, $87, $65, $6F, $F7, $6E, $AF, $67, $EE, $E5, $74, $FD, $57, $58, $75, $07, $FE, $7E
	dc.b	$6E, $F7, $6E, $5F, $57, $EE, $3D, $76, $87, $35, $78, $47, $E7, $FF, $77, $E2, $F5, $7D, $EE, $67, $F4, $4E, $7E, $F7, $E7, $2F, $56, $D6, $FE, $74, $E5, $E7
	dc.b	$68, $76, $E7, $FF, $8E, $E6, $F5, $7F, $5C, $E7, $BE, $4E, $76, $85, $7C, $7E, $88, $5F, $6F, $A8, $FD, $CE, $75, $F5, $E7, $78, $27, $E7, $FF, $8E, $5D, $F5
	dc.b	$7E, $4F, $07, $6F, $DD, $77, $86, $50, $7F, $F7, $C7, $E8, $77, $32, $FB, $73, $FD, $57, $F4, $6E, $7D, $F7, $DB, $6F, $47, $F6, $CF, $75, $E5, $E6, $78, $57
	dc.b	$E7, $D8, $84, $F7, $FD, $7E, $A4, $F7, $6F, $6E, $67, $FF, $72, $64, $87, $7F, $6E, $E8, $EF, $5F, $77, $FC, $D6, $7F, $E7, $F7, $DF, $7C, $45, $86, $8F, $5F
	dc.b	$D7, $6F, $D3, $8F, $F7, $F7, $48, $8E, $56, $FC, $7E, $6F, $E7, $5E, $DD, $76, $87, $30, $7F, $E7, $E7, $FF, $76, $E5, $F6, $7E, $E3, $B7, $D8, $76, $57, $80
	dc.b	$8F, $5E, $F7, $7F, $5F, $67, $EF, $66, $78, $47, $E7, $EF, $7A, $D6, $F5, $7F, $5E, $D7, $BE, $5D, $7D, $88, $E6, $58, $76, $B6, $FE, $75, $DE, $E7, $7F, $EC
	dc.b	$7A, $F6, $D6, $68, $76, $B6, $FD, $73, $5F, $E7, $6E, $FB, $76, $87, $45, $78, $57, $E7, $FE, $74, $DD, $F7, $7F, $DD, $57, $B8, $76, $36, $FE, $8F, $BD, $F7
	dc.b	$7F, $9E, $67, $FE, $65, $7E, $87, $69, $78, $48, $F3, $EF, $8A, $F4, $E7, $6F, $D6, $57, $8E, $8F, $7E, $88, $4C, $CF, $67, $ED, $E9, $7B, $F5, $C7, $38, $76
	dc.b	$46, $86, $8F, $6F, $E7, $4E, $4E, $67, $FD, $42, $7F, $F7, $55, $58, $77, $F5, $DE, $8E, $F5, $D6, $6F, $C7, $D6, $58, $57, $E6, $DF, $76, $F7, $F5, $7F, $A6
	dc.b	$E6, $4F, $7D, $56, $85, $8F, $6E, $F7, $5F, $7F, $67, $FB, $5E, $7E, $E6, $23, $7F, $F8, $F6, $EF, $72, $C3, $F7, $6E, $3E, $46, $BE, $5E, $75, $87, $6D, $78
	dc.b	$18, $F5, $EE, $74, $F6, $E6, $7F, $C6, $E6, $7F, $F7, $E6, $38, $85, $F7, $F5, $7F, $35, $E7, $EE, $6D, $A7, $2F, $E7, $5F, $6F, $67, $F4, $5E, $7E, $E7, $DB
	dc.b	$5F, $66, $D6, $C8, $8C, $E7, $86, $7F, $7E, $E7, $DE, $6E, $64, $F6, $53, $56, $FE, $7F, $7E, $F8, $EC, $EE, $76, $F5, $D6, $4E, $E6, $C6, $6F, $F8, $E5, $C8
	dc.b	$86, $F6, $F6, $7F, $D6, $E7, $EE, $6B, $D5, $55, $F5, $7F, $6E, $E7, $CE, $6E, $65, $F6, $6E, $6E, $D6, $D1, $7E, $88, $DC, $68, $77, $F7, $F5, $7F, $C6, $E7
	dc.b	$EE, $6B, $C4, $6C, $88, $E6, $EF, $76, $3E, $E6, $6E, $DD, $55, $D3, $1D, $66, $48, $75, $46, $87, $7F, $6F, $67, $FD, $7D, $6F, $D7, $BE, $4C, $7F, $F8, $DE
	dc.b	$5F, $67, $FC, $5D, $7E, $F7, $4D, $4F, $75, $F5, $66, $FE, $7D, $5E, $F8, $DF, $7F, $75, $F4, $6E, $6E, $D7, $ED, $66, $FE, $7E, $7F, $F8, $ED, $DE, $7B, $F6
	dc.b	$53, $5F, $66, $E4, $56, $EF, $7D, $6E, $F8, $EE, $4F, $75, $F5, $64, $5F, $56, $C4, $CE, $7E, $F7, $3D, $6F, $67, $F4, $CC, $7F, $D7, $EB, $4E, $7D, $F7, $D5
	dc.b	$68, $58, $FD, $4F, $77, $87, $5D, $7F, $D7, $F2, $5E, $7E, $E6, $66, $86, $7E, $68, $77, $F5, $E7, $6F, $E7, $B5, $F5, $7D, $F6, $36, $48, $77, $E5, $F6, $7F
	dc.b	$9D, $66, $FD, $73, $ED, $56, $ED, $56, $D6, $FD, $8F, $DD, $F8, $EF, $7E, $69, $F7, $5F, $6D, $56, $F4, $7E, $E4, $7F, $E7, $BF, $6E, $76, $FB, $7F, $6E, $D7
	dc.b	$EE, $6C, $6D, $E6, $BD, $7F, $F8, $FB, $6F, $76, $87, $5A, $6F, $57, $F3, $5D, $7F, $C7, $ED, $7F, $F8, $F6, $EF, $8E, $F7, $F7, $DF, $76, $F3, $56, $DF, $75
	dc.b	$EE, $7F, $D8, $87, $EE, $8F, $F7, $F7, $EE, $73, $F6, $45, $3F, $7A, $DE, $76, $86, $7F, $6D, $D8, $FF, $7E, $13, $E7, $DF, $7B, $E6, $D6, $DE, $57, $38, $67
	dc.b	$F6, $E4, $7F, $E8, $FD, $3D, $7F, $D7, $EE, $6C, $7E, $F7, $56, $8C, $8F, $0E, $98, $8D, $8F, $2E, $47, $FE, $7B, $EE, $67, $FB, $6D, $7E, $87, $7F, $7F, $67
	dc.b	$86, $7F, $6B, $56, $F4, $7F, $E6, $7E, $F5, $7E, $E7, $D8, $85, $F6, $9C, $7F, $D7, $F2, $7F, $6E, $56, $F5, $7D, $F6, $6C, $F7, $68, $68, $86, $CA, $7F, $E8
	dc.b	$FE, $6D, $6F, $57, $EF, $73, $DD, $55, $E6, $60, $87, $6F, $7F, $75, $88, $4F, $7F, $7E, $F7, $5F, $B7, $5E, $E7, $ED, $44, $78, $58, $87, $E3, $78, $67, $F7
	dc.b	$F6, $7F, $56, $2F, $56, $4F, $63, $D4, $D6, $6C, $88, $BF, $7F, $66, $F6, $6F, $6E, $7C, $F7, $1F, $62, $6E, $D7, $ED, $5D, $5D, $6E, $E7, $F6, $5E, $6C, $E7
	dc.b	$ED, $6E, $6D, $D6, $E5, $4E, $6D, $52, $E6, $D2, $4C, $6F, $65, $E6, $E5, $6F, $64, $E7, $F6, $4E, $6D, $5C, $D6, $DD, $6E, $50, $D6, $E5, $5F, $66, $F7, $E1
	dc.b	$6F, $65, $E6, $E5, $5E, $6D, $5C, $C6, $E5, $4B, $4E, $36, $E5, $C4, $2C, $94, $3E, $63, $DD, $6D, $5D, $D6, $DC, $5D, $5D, $95, $E5, $5E, $6A, $E6, $CC, $59
	dc.b	$D5, $CE, $7F, $56, $E6, $CE, $6D, $A6, $E6, $E2, $6E, $5B, $04, $D6, $DD, $5D, $5C, $C5, $D2, $5D, $44, $E6, $9E, $6C, $D5, $2B, $5E, $54, $E6, $C3, $AB, $5D
	dc.b	$5D, $4A, $D5, $C4, $0A, $0B, $A5, $D3, $B5, $DD, $6E, $36, $E6, $DD, $6E, $53, $E6, $E6, $C9, $5D, $5D, $5A, $D5, $2D, $5D, $5D, $C6, $E4, $43, $C9, $45, $E3
	dc.b	$5E, $6D, $A5, $E6, $D4, $3D, $6E, $53, $C4, $4E, $6E, $53, $C5, $C2, $B4, $C3, $C5, $D4, $C3, $B3, $20, $3E, $6E, $54, $D6, $E6, $E5, $C4, $3C, $43, $CB, $5D
	dc.b	$5E, $6D, $24, $3D, $5C, $A3, $D5, $D5, $B4, $C3, $B4, $D5, $BC, $43, $C4, $CC, $5D, $5D, $5C, $93, $B3, $2B, $10, $A4, $D5, $D5, $C3, $B3, $C4, $AB, $2C, $5D
	dc.b	$5D, $4B, $21, $2C, $40, $C4, $C4, $A0, $32, $C4, $C3, $2C, $4C, $49, $B2, $A1, $2A, $2B, $3B, $3A, $93, $B3, $B0, $29, $92, $B3, $B9, $30, $A1, $A2, $3C, $4B
	dc.b	$10, $93, $B0, $3B, $A4, $C3, $A1, $2A, $02, $A2, $1A, $3B, $92, $A2, $0A, $02, $A2, $A0, $2B, $3A, $92, $B3, $9A, $3A, $92, $A0, $19, $10, $00, $2B, $3A, $20
	dc.b	$A0, $2A, $02, $00, $A2, $A2, $A2, $0A, $20, $0A, $21, $A1, $1A, $10, $0A, $02, $A2, $0A, $20, $A0, $2A, $2A, $20, $A2, $A0, $2A, $2A, $02, $A2, $0A, $20, $A2
	dc.b	$A2, $A2, $0A, $02, $A0, $2A, $02, $0A, $20, $0A, $20, $A2, $0A, $20, $90, $00, $00, $10, $00, $10, $00, $00, $00, $09, $00, $90, $00, $A0, $02, $00, $10, $10
	dc.b	$02, $00, $A0, $90, $90, $A0, $90, $00, $00, $10, $00, $21, $01, $20, $10, $20, $0A, $09, $A0, $99, $00, $00, $00, $10, $01, $00, $02, $00, $0A, $00, $90, $09
	dc.b	$00, $A2, $00, $01, $10, $02, $0A, $09, $09, $0A, $90, $00, $A2, $00, $01, $02, $11, $21, $02, $00, $0A, $09, $A9, $90, $A0, $00, $02, $01, $01, $00, $20, $00
	dc.b	$0A, $00, $99, $00, $00, $00, $10, $00, $90, $0A, $00, $90, $00, $00, $00, $01, $21, $21, $12, $10, $90, $A9, $A0, $99, $A0, $00, $00, $20, $11, $02, $00, $10
	dc.b	$09, $0A, $09, $00, $00, $09, $00, $00, $A0, $09, $00, $00, $00, $01, $20, $12, $12, $11, $00, $9A, $9A, $09, $9A, $00, $00, $00, $21, $01, $20, $10, $00, $09
	dc.b	$0A, $00, $90, $90, $0A, $09, $0A, $00, $00, $00, $20, $12, $12, $12, $11, $00, $09, $A9, $A9, $9A, $09, $00, $10, $20, $11, $02, $10, $02, $A0, $09, $00, $A9
	dc.b	$09, $A9, $0A, $90, $00, $00, $01, $22, $13, $02, $22, $19, $0A, $9A, $9A, $AA, $90, $00, $00, $12, $01, $12, $01, $02, $00, $0A, $09, $A9, $0A, $9A, $99, $A0
	dc.b	$09, $01, $02, $23, $30, $30, $22, $90, $9A, $AB, $99, $A9, $A0, $00, $02, $12, $11, $21, $20, $10, $09, $0A, $9A, $9A, $AA, $AA, $A0, $00, $02, $22, $32, $33
	dc.b	$22, $01, $A9, $AB, $AA, $B0, $A0, $90, $10, $21, $21, $21, $22, $20, $19, $A9, $AA, $AA, $BA, $B9, $A0, $02, $21, $33, $33, $33, $10, $A0, $BA, $BA, $B9, $A9
	dc.b	$0A, $20, $12, $21, $22, $32, $10, $2A, $AA, $AB, $BA, $BB, $B0, $93, $03, $33, $42, $40, $29, $0B, $0B, $BB, $9A, $AA, $A0, $02, $12, $13, $23, $02, $10, $9A
	dc.b	$AB, $BB, $BB, $A1, $A2, $33, $41, $42, $30, $19, $AA, $B9, $BA, $AA, $A9, $A2, $02, $22, $22, $30, $20, $AA, $AB, $BB, $BA, $9A, $33, $33, $34, $21, $20, $A9
	dc.b	$AA, $BA, $A9, $AA, $90, $00, $21, $22, $21, $20, $AA, $AB, $BB, $90, $A3, $14, $94, $23, $92, $0A, $0A, $9B, $0B, $2B, $9A, $2A, $22, $12, $03, $B2, $B0, $C9
	dc.b	$C4, $5C, $4B, $4D, $3B, $3B, $44, $A3, $C4, $D3, $C4, $C5, $B2, $C3, $BA, $23, $9B, $2C, $0C, $2C, $65, $D4, $D4, $E5, $15, $D6, $DC, $C4, $AB, $43, $BC, $4C
	dc.b	$2A, $5D, $4B, $0C, $3A, $BB, $9B, $64, $D4, $D4, $E6, $B5, $E6, $E4, $A5, $B2, $2B, $C3, $4C, $3A, $2C, $4A, $CA, $3C, $A0, $B6, $5E, $4D, $5E, $61, $5E, $5C
	dc.b	$A4, $4C, $C4, $C3, $05, $D1, $B3, $C4, $C2, $B2, $C9, $B5, $7F, $3D, $5D, $56, $EA, $C6, $E5, $14, $E5, $A3, $95, $DB, $22, $91, $AC, $A2, $3C, $C6, $7F, $2E
	dc.b	$6E, $64, $DD, $45, $D5, $C2, $E6, $A2, $C4, $D3, $41, $C1, $3B, $BB, $CC, $67, $FC, $D6, $D5, $5E, $C2, $6E, $5C, $4D, $53, $BC, $4C, $B4, $1C, $94, $CC, $2C
	dc.b	$D7, $5F, $4C, $6E, $6B, $DD, $65, $E5, $C3, $D6, $CC, $D5, $CA, $32, $C3, $4D, $BA, $C5, $7F, $CB, $63, $C5, $E3, $C7, $EC, $D4, $C5, $2D, $B4, $3C, $1A, $12
	dc.b	$4D, $CC, $27, $5F, $4D, $7F, $6C, $E4, $56, $E4, $D5, $D6, $DC, $C5, $CA, $C3, $32, $9D, $CC, $75, $F4, $C7, $F6, $DD, $A6, $5E, $4C, $4C, $6E, $BA, $5C, $0C
	dc.b	$B4, $4C, $DD, $76, $F3, $D7, $F7, $EE, $B6, $5E, $4C, $4D, $6D, $CC, $6D, $CB, $93, $4C, $E3, $8F, $EC, $55, $E7, $F4, $D7, $EC, $D6, $E5, $BC, $C5, $4D, $BC
	dc.b	$52, $9E, $57, $F3, $D7, $E4, $2C, $E6, $6E, $BC, $6E, $6E, $4D, $6D, $DC, $53, $BE, $67, $FB, $C7, $EB, $B2, $E6, $5E, $31, $6E, $5E, $5B, $5C, $DC, $53, $CE
	dc.b	$74, $F4, $66, $F7, $E4, $E7, $ED, $C6, $D3, $D4, $C5, $9D, $CB, $5D, $C7, $DE, $D7, $BE, $4C, $3D, $6C, $DD, $6B, $4E, $5B, $5C, $DC, $23, $D7, $5F, $D6, $6E
	dc.b	$AC, $5D, $6A, $DD, $55, $CE, $5B, $5B, $DD, $C5, $B7, $EE, $E7, $5C, $DC, $32, $6D, $DD, $63, $DD, $35, $9C, $DD, $10, $8F, $EF, $76, $DC, $D4, $C6, $BD, $E6
	dc.b	$5C, $DC, $53, $CD, $E3, $67, $EE, $E7, $5E, $4D, $D6, $54, $F5, $55, $DC, $AB, $5D, $CE, $47, $5E, $F7, $5C, $4E, $5E, $66, $ED, $16, $CC, $DA, $4A, $CE, $B7
	dc.b	$6E, $F6, $6C, $5E, $5E, $57, $ED, $D5, $4D, $BC, $4C, $BE, $48, $EE, $F5, $7E, $49, $D2, $D7, $ED, $C5, $4D, $AC, $4D, $DD, $76, $CF, $55, $5C, $E7, $F5, $45
	dc.b	$4E, $25, $CD, $C5, $DD, $E6, $73, $FB, $47, $ED, $6E, $6E, $69, $CD, $35, $DD, $B5, $DE, $47, $5E, $E9, $7E, $C5, $D5, $E6, $42, $DC, $5C, $DD, $5D, $D3, $76
	dc.b	$FE, $A7, $BD, $3C, $5E, $55, $5D, $E5, $4C, $DB, $CD, $57, $5F, $DC, $66, $E5, $D6, $E0, $55, $CE, $33, $3D, $CD, $C7, $55, $FD, $55, $6E, $4A, $3C, $C5, $40
	dc.b	$DC, $3B, $CD, $D4, $75, $DE, $E6, $53, $CB, $5D, $BC, $64, $DD, $D4, $2C, $DD, $66, $6E, $ED, $66, $E3, $95, $DD, $25, $5B, $EB, $34, $CE, $C7, $65, $FE, $46
	dc.b	$6D, $D4, $40, $E3, $56, $CE, $DB, $5C, $EA, $76, $3E, $F4, $66, $CE, $55, $3E, $C5, $62, $EE, $B5, $2E, $56, $7C, $EF, $B6, $63, $DA, $52, $DD, $B5, $5B, $ED
	dc.b	$B4, $05, $65, $3E, $EC, $56, $22, $C4, $BC, $CC, $44, $BD, $DC, $B6, $56, $BD, $EB, $34, $12, $45, $3C, $DC, $13, $3C, $DD, $B5, $56, $4B, $DD, $C3, $30, $14
	dc.b	$54, $CC, $DB, $10, $AC, $DC, $55, $65, $CE, $CB, $42, $1B, $44, $5A, $CD, $CB, $11, $BC, $D4, $56, $59, $DE, $C4, $44, $B2, $34, $43, $CD, $DA, $23, $BC, $A4
	dc.b	$65, $4D, $DD, $C3, $52, $2A, $23, $42, $BD, $DC, $23, $2B, $25, $55, $1C, $DD, $C2, $44, $42, $A2, $31, $BD, $CC, $B2, $12, $45, $44, $3B, $DC, $CB, $44, $42
	dc.b	$12, $29, $CC, $CC, $B9, $A3, $45, $45, $9B, $DC, $D2, $34, $34, $23, $29, $BC, $DC, $B0, $A3, $35, $55, $1B, $DC, $DA, $24, $34, $33, $39, $BC, $DC, $BB, $A1
	dc.b	$45, $55, $3B, $DD, $CB, $94, $43, $42, $32, $AC, $DC, $CB, $AB, $44, $65, $4B, $DD, $DC, $33, $43, $43, $43, $AD, $CD, $BB, $AB, $34, $65, $5C, $DD, $DC, $34
	dc.b	$33, $34, $52, $CD, $DC, $B0, $BC, $14, $66, $4C, $DE, $C1, $33, $93, $45, $59, $DD, $DB, $21, $CD, $95, $66, $4D, $EC, $20, $BC, $A5, $65, $BD, $DD, $B3, $BC
	dc.b	$DC, $55, $65, $BD, $CB, $BD, $D3, $56, $5B, $DB, $AB, $DC, $B3, $2D, $C5, $66, $BD, $D0, $0C, $DC, $56, $5C, $DA, $3C, $DC, $24, $1D, $D4, $66, $BD, $94, $AE
	dc.b	$D2, $65, $BC, $45, $CE, $D4, $50, $CD, $9C, $35, $64, $B3, $CC, $DD, $34, $53, $44, $AD, $D2, $B3, $A3, $AD, $DC, $65, $50, $45, $ED, $D4, $01, $55, $5D, $CA
	dc.b	$CD, $A5, $3C, $CC, $DC, $65, $53, $44, $ED, $D4, $A3, $55, $4C, $1C, $DB, $24, $B2, $AD, $DB, $36, $25, $52, $BD, $CD, $C2, $45, $25, $2C, $CC, $BC, $02, $2B
	dc.b	$CB, $CC, $55, $45, $53, $DD, $CD, $C4, $44, $55, $BC, $AD, $CB, $2A, $23, $BC, $CB, $35, $45, $54, $DC, $CD, $D4, $33, $55, $20, $BC, $DB, $C9, $33, $AB, $BA
	dc.b	$C4, $53, $55, $1D, $9B, $DC, $02, $C5, $5A, $43, $CC, $BC, $C9, $1A, $92, $BA, $B5, $34, $44, $3B, $BB, $CC, $C3, $B3, $43, $33, $0B, $BC, $B0, $A9, $10, $02
	dc.b	$0A, $23, $09, $22, $22, $33, $A2, $AA, $BB, $9A, $90, $22, $12, $00, $A0, $99, $0A, $0A, $90, $91, $00, $02, $02, $21, $21, $00, $09, $12, $10, $00, $9A, $AA
	dc.b	$AB, $00, $00, $00, $02, $01, $21, $10, $90, $90, $A0, $21, $01, $00, $02, $01, $02, $00, $A0, $90, $A9, $09, $19, $00, $0A, $00, $00, $02, $00, $00, $10, $09
	dc.b	$00, $00, $00, $01, $00, $01, $00, $21, $91, $09, $0A, $09, $00, $00, $00, $00, $00, $00, $00, $90, $10, $00, $00, $90, $00, $00, $00, $00, $00, $10, $00, $00
	dc.b	$10, $90, $00, $00, $00, $00, $00, $00, $00, $00, $01, $91, $90, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	dc.b	$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $09
	dc.b	$10, $2A, $00, $00, $00, $09, $10, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	dc.b	$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $19, $00, $00, $00, $19, $00, $90, $10, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	dc.b	$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $09, $20, $09, $00, $00, $00, $00, $00, $00, $19, $09, $01, $91, $90, $19, $10, $00, $29
	dc.b	$00, $2A, $0B, $2A, $20, $00, $01, $91, $00, $01, $A2, $2A, $91, $99, $01, $00, $10, $90, $21, $A0, $99, $10, $09, $10, $90, $A0, $0A, $90, $02, $32, $31, $22
	dc.b	$10, $0A, $AB, $AA, $AA, $BB, $AB, $BB, $B0, $54, $54, $44, $AD, $BC, $DC, $34, $54, $42, $CD, $CB, $CD, $DB, $45, $66, $53, $CD, $DE, $CC, $35, $55, $6A, $DD
	dc.b	$DD, $CB, $01, $CA, $36, $55, $C3, $3D, $EC, $53, $23, $55, $CD, $BC, $CC, $44, $9D, $CC, $B6, $56, $C3, $CC, $EC, $B5, $45, $43, $BD, $CC, $92, $4B, $BD, $DC
	dc.b	$65, $6C, $4B, $DD, $E5, $55, $33, $3B, $DD, $B4, $43, $BB, $DD, $D5, $66, $32, $DC, $ED, $46, $55, $CB, $DD, $C1, $55, $BC, $DD, $DD, $57, $69, $DE, $DC, $D5
	dc.b	$66, $3E, $DC, $C9, $46, $3C, $DD, $DD, $C4, $76, $3E, $EB, $AD, $56, $6A, $FD, $35, $44, $54, $DD, $DA, $CD, $A7, $65, $FE, $54, $1B, $66, $CE, $EB, $64, $C9
	dc.b	$5D, $DC, $0C, $DD, $77, $3F, $E3, $45, $E6, $64, $EF, $56, $5B, $B3, $9D, $CA, $BD, $D6, $76, $FE, $B4, $6E, $56, $5E, $F3, $66, $AC, $C4, $CD, $BA, $DD, $67
	dc.b	$6E, $FC, $56, $E5, $64, $DF, $C6, $63, $CD, $3B, $CB, $CD, $D6, $76, $EF, $D5, $6D, $46, $4D, $FC, $66, $4C, $DB, $AC, $9C, $DD, $67, $5E, $ED, $36, $E5, $64
	dc.b	$DE, $E6, $60, $CD, $B1, $CB, $CD, $D6, $76, $FE, $13, $6D, $26, $5D, $EE, $56, $2B, $D9, $2C, $CC, $DC, $76, $5E, $F5, $95, $C3, $65, $CE, $E4, $60, $0C, $A2
	dc.b	$DC, $DC, $46, $65, $DE, $B1, $3B, $B5, $53, $DD, $34, $1B, $B0, $30, $00, $93, $3A, $BC, $C2, $33, $31, $33, $BA, $A2, $30, $21, $AA, $BA, $A9, $12, $A9, $BB
	dc.b	$23, $09, $03, $30, $90, $32, $21, $0A, $AB, $AA, $90, $21, $0B, $A3, $39, $A9, $32, $AA, $01, $19, $01, $2A, $A0, $11, $02, $0A, $AA, $23, $A9, $92, $2A, $A0
	dc.b	$11, $90, $01, $99, $A2, $19, $20, $09, $00, $29, $99, $11, $09, $00, $09, $01, $19, $00, $00, $00, $00, $09, $02, $90, $00, $10, $90, $00, $00, $01, $90, $00
	dc.b	$00, $91, $00, $01, $09, $00, $00, $00, $10, $90, $00, $00, $00, $00, $90, $00, $10, $10, $09, $00, $00, $01, $09, $09, $01, $00, $00, $00, $90, $01, $00, $10
	dc.b	$90, $90, $01, $01, $90, $00, $00, $00, $00, $09, $10, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	dc.b	$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	dc.b	$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	dc.b	$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	dc.b	$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	dc.b	$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $01, $B2, $10, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	dc.b	$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	dc.b	$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	dc.b	$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	dc.b	$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	dc.b	$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	dc.b	$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $19, $39, $B3, $AA, $19, $00, $0A, $02, $00, $00, $10, $00, $00, $00, $00, $00, $00
	dc.b	$00, $00, $01, $09, $19, $10, $09, $01, $09, $00, $00, $00, $01, $00, $90, $01, $91, $00, $09, $90, $0A, $20, $00, $10, $19, $10, $00, $00, $90, $00, $90, $00
	dc.b	$0A, $20, $00, $01, $00, $01, $00, $02, $A0, $00, $00, $91, $99, $10, $90, $19, $19, $0A, $90, $0A, $21, $02, $01, $29, $21, $90, $00, $A0, $90, $91, $91, $00
	dc.b	$01, $00, $09, $10, $90, $9A, $9A, $90, $2A, $30, $21, $22, $02, $A2, $A0, $A9, $99, $19, $01, $01, $02, $01, $90, $0A, $99, $AA, $AA, $A2, $2A, $4A, $33, $12
	dc.b	$3A, $9A, $9B, $A9, $B2, $B2, $22, $12, $30, $29, $90, $AB, $AB, $BA, $B0, $3B, $42, $43, $33, $93, $C3, $CB, $9C, $99, $19, $32, $24, $12, $3A, $99, $BB, $BB
	dc.b	$BB, $BA, $33, $05, $B4, $4A, $4A, $BA, $BC, $BB, $B9, $2A, $40, $34, $13, $2A, $A9, $BB, $AC, $BA, $B9, $03, $33, $42, $44, $B3, $BB, $1C, $BC, $B2, $A3, $94
	dc.b	$23, $4B, $39, $A9, $BB, $BA, $B9, $AA, $9A, $14, $C5, $A4, $4B, $4C, $3C, $1C, $B1, $C3, $1A, $41, $33, $92, $1A, $AA, $AA, $9A, $9A, $A9, $BA, $93, $04, $31
	dc.b	$43, $93, $0C, $3C, $BA, $C3, $B2, $32, $23, $20, $39, $B2, $BA, $0B, $2A, $A9, $AB, $9B, $14, $C5, $B4, $4A, $4A, $9A, $CB, $BA, $B9, $2A, $4A, $42, $A4, $B1
	dc.b	$AA, $99, $A0, $A0, $AA, $BA, $AB, $94, $C5, $B4, $42, $4A, $1B, $AC, $BB, $C3, $B9, $4B, $42, $14, $B2, $1B, $1A, $B2, $AA, $AA, $B9, $AB, $AA, $4B, $5B, $44
	dc.b	$04, $A0, $BB, $BB, $CB, $1A, $13, $93, $32, $39, $30, $A2, $BA, $0B, $1A, $B9, $BA, $AB, $92, $3A, $5B, $44, $94, $B2, $0C, $9C, $BA, $B9, $00, $32, $23, $22
	dc.b	$39, $02, $B2, $AB, $0B, $AB, $B9, $BA, $09, $4B, $42, $43, $33, $39, $AA, $BB, $BB, $BB, $00, $03, $03, $21, $32, $22, $A2, $AA, $9B, $AA, $BA, $BA, $AA, $02
	dc.b	$30, $40, $43, $24, $B3, $AB, $0C, $AA, $BA, $AA, $29, $23, $02, $31, $22, $22, $A0, $AB, $9B, $AB, $AA, $B0, $00, $23, $94, $93, $4A, $4B, $3A, $B2, $BB, $0B
	dc.b	$AA, $B2, $A2, $21, $22, $12, $22, $20, $0A, $9A, $AA, $BA, $9A, $9A, $02, $A3, $94, $B4, $01, $39, $39, $2A, $AA, $AB, $9A, $9A, $00, $20, $12, $02, $20, $21
	dc.b	$01, $90, $A9, $AA, $AA, $AA, $00, $91, $02, $12, $22, $39, $30, $21, $A2, $B0, $AB, $09, $A9, $00, $00, $10, $21, $12, $01, $20, $0A, $09, $A9, $AA, $0A, $90
	dc.b	$A0, $02, $03, $93, $10, $39, $31, $A2, $A0, $AA, $A9, $9A, $90, $00, $01, $02, $11, $02, $01, $00, $09, $A0, $99, $A9, $A0, $90, $00, $10, $21, $23, $A3, $92
	dc.b	$2A, $2A, $0A, $9A, $99, $0A, $00, $91, $00, $21, $01, $02, $01, $09, $0A, $09, $9A, $09, $A0, $09, $01, $02, $02, $12, $21, $20, $19, $00, $A0, $A9, $99, $0A
	dc.b	$00, $00, $02, $01, $01, $00, $20, $00, $0A, $09, $90, $A0, $90, $A0, $00, $20, $10, $22, $02, $02, $10, $1A, $1A, $90, $A9, $09, $00, $A2, $00, $00, $10, $10
	dc.b	$02, $00, $0A, $09, $09, $A0, $90, $0A, $00, $20, $10, $21, $12, $02, $92, $00, $0A, $9A, $09, $09, $00, $A2, $00, $00, $10, $10, $20, $00, $A0, $90, $9A, $09
	dc.b	$A0, $09, $10, $02, $12, $29, $30, $21, $91, $A1, $A9, $A9, $09, $0A, $00, $02, $01, $01, $02, $00, $00, $A0, $99, $A9, $0A, $09, $01, $92, $12, $12, $21, $20
	dc.b	$29, $00, $A9, $9A, $99, $0A, $00, $02, $01, $01, $20, $00, $00, $A0, $9A, $99, $A9, $00, $00, $29, $23, $93, $12, $29, $2A, $09, $A9, $A9, $9A, $00, $00, $02
	dc.b	$10, $12, $00, $00, $A9, $0A, $A0, $A9, $0A, $2A, $39, $32, $23, $03, $A2, $9A, $0A, $AA, $99, $A0, $91, $00, $21, $01, $02, $00, $A9, $9A, $9A, $91, $B3, $A3
	dc.b	$10, $30, $32, $21, $90, $0A, $A9, $AA, $9A, $09, $10, $02, $10, $10, $00, $90, $AA, $A9, $1B, $3A, $32, $A4, $B3, $21, $20, $00, $AA, $9A, $A9, $A2, $A0, $00
	dc.b	$20, $00, $00, $A9, $0A, $09, $01, $2A, $31, $31, $03, $A2, $99, $0A, $9A, $A1, $A1, $00, $19, $10, $90, $A9, $A9, $A2, $A2, $03, $A4, $A3, $22, $2A, $19, $A9
	dc.b	$AA, $A9, $0A, $2A, $21, $92, $99, $0A, $9A, $A1, $B3, $A4, $A3, $23, $21, $2A, $0A, $AA, $A9, $AA, $2A, $2A, $02, $A9, $0A, $AA, $19, $39, $32, $33, $23, $20
	dc.b	$AA, $AB, $AB, $A9, $A2, $A2, $10, $2A, $9A, $AA, $19, $12, $23, $31, $40, $22, $A9, $BB, $AB, $AA, $92, $A2, $10, $2A, $9A, $BA, $2B, $4A, $33, $34, $39, $3B
	dc.b	$0A, $CA, $AB, $AA, $A3, $92, $29, $0A, $BA, $90, $03, $23, $41, $42, $12, $B9, $BC, $AB, $B0, $A2, $12, $21, $A9, $BB, $0A, $A4, $A4, $42, $43, $93, $CA, $AC
	dc.b	$BB, $C3, $91, $4A, $21, $BA, $CA, $3C, $42, $34, $34, $40, $20, $CB, $CC, $AB, $B3, $A4, $29, $3B, $BB, $C4, $D5, $B4, $50, $44, $92, $AC, $BC, $CA, $C9, $31
	dc.b	$42, $02, $BC, $C3, $B9, $4A, $53, $44, $3A, $2C, $CA, $CC, $AC, $33, $94, $2A, $9C, $C5, $D4, $29, $52, $44, $3B, $3C, $D2, $D0, $0B, $33, $04, $2C, $1C, $C5
	dc.b	$E5, $33, $53, $44, $3C, $4D, $BC, $D3, $B2, $14, $31, $3C, $AC, $B3, $C5, $C4, $53, $43, $1C, $3D, $BC, $C2, $B2, $33, $31, $2B, $CC, $4D, $50, $B6, $C4, $40
	dc.b	$C3, $CC, $BC, $C2, $92, $42, $93, $CC, $A3, $D5, $20, $52, $44, $0B, $0C, $D2, $CB, $39, $24, $3B, $3C, $D4, $2D, $51, $A5, $43, $42, $C0, $BD, $AB, $C2, $32
	dc.b	$34, $B9, $BD, $24, $D5, $39, $54, $33, $3C, $BB, $DB, $B9, $B4, $31, $4A, $BB, $D2, $3D, $54, $15, $43, $33, $CB, $CC, $CB, $A9, $34, $04, $AB, $BD, $A4, $D5
	dc.b	$32, $54, $42, $2B, $CB, $DB, $BB, $03, $43, $33, $BC, $CC, $3D, $44, $45, $35, $90, $3D, $BC, $D0, $C4, $A4, $43, $4B, $BC, $DB, $3D, $54, $35, $44, $3A, $2D
	dc.b	$CC, $CC, $B4, $14, $43, $32, $CC, $DC, $4D, $45, $35, $45, $3C, $3D, $CC, $DB, $C4, $34, $52, $4A, $BC, $DC, $D4, $B3, $54, $54, $53, $C0, $DD, $CD, $1C, $44
	dc.b	$45, $34, $AC, $BD, $DC, $C4, $B5, $55, $54, $4B, $D0, $DD, $DB, $2B, $54, $45, $33, $BC, $CD, $DD, $B5, $A5, $55, $53, $4A, $DC, $DC, $DC, $20, $45, $54, $34
	dc.b	$CC, $CD, $DC, $CB, $53, $55, $55, $00, $AD, $DC, $DC, $C3, $44, $45, $44, $3B, $CC, $DC, $DB, $BA, $45, $54, $54, $3B, $BC, $DC, $CC, $B9, $44, $44, $44, $1A
	dc.b	$BC, $CC, $CC, $BB, $93, $53, $44, $45, $C9, $BC, $CD, $0B, $B3, $34, $33, $44, $1A, $BB, $CB, $CA, $BC, $AA, $25, $24, $44, $4A, $99, $CC, $CC, $BB, $12, $44
	dc.b	$34, $32, $0B, $BB, $CB, $9A, $AB, $0A, $9B, $44, $33, $44, $3B, $AA, $BC, $CB, $AB, $23, $44, $13, $32, $BB, $AB, $BC, $22, $1A, $92, $BA, $BA, $42, $32, $34
	dc.b	$30, $A0, $BC, $BA, $AA, $02, $42, $12, $13, $BB, $A9, $1B, $02, $31, $A1, $AB, $BC, $AB, $B3, $44, $34, $44, $2B, $BB, $BC, $CC, $02, $13, $44, $30, $1A, $AB
	dc.b	$BB, $A1, $01, $33, $30, $AB, $BB, $CC, $AA, $03, $44, $44, $44, $AB, $CB, $CC, $BB, $93, $33, $33, $41, $9B, $AA, $BB, $A0, $22, $23, $32, $0A, $BB, $BB, $BB
	dc.b	$A9, $12, $24, $44, $22, $31, $AB, $CB, $BA, $BA, $22, $33, $22, $31, $9B, $AA, $AA, $A9, $22, $22, $32, $3A, $9B, $BA, $AB, $BA, $0A, $00, $22, $43, $42, $22
	dc.b	$10, $BB, $CA, $BA, $A0, $23, $32, $31, $20, $AB, $AB, $09, $A0, $22, $23, $02, $21, $AA, $BA, $AA, $B9, $00, $00, $10, $02, $33, $33, $02, $10, $AB, $BA, $BA
	dc.b	$90, $12, $32, $22, $00, $A9, $AB, $00, $00, $21, $12, $10, $09, $00, $0A, $AA, $00, $90, $A0, $00, $90, $A0, $23, $32, $32, $21, $0A, $BB, $AA, $B0, $91, $22
	dc.b	$22, $20, $00, $0A, $A9, $A2, $00, $01, $12, $00, $0A, $00, $00, $99, $00, $0A, $09, $A0, $00, $90, $01, $23, $32, $12, $00, $0A, $BB, $A9, $00, $00, $12, $30
	dc.b	$19, $00, $A0, $90, $90, $01, $00, $00, $01, $90, $09, $11, $00, $90, $00, $90, $A9, $A0, $00, $00, $02, $32, $31, $00, $2A, $0A, $BA, $A9, $00, $10, $21, $12
	dc.b	$10, $90, $00, $A9, $09, $00, $01, $00, $00, $10, $90, $00, $10, $00, $99, $00, $A0, $9A, $00, $00, $20, $02, $23, $21, $00, $09, $0A, $B9, $A9, $01, $02, $01
	dc.b	$12, $10, $90, $A0, $09, $90, $00, $01, $00, $00, $00, $00, $00, $00, $00, $00, $90, $0A, $09, $00, $00, $00, $10, $02, $22, $21, $00, $0A, $09, $AA, $A0, $00
	dc.b	$21, $01, $20, $10, $09, $A9, $00, $90, $00, $00, $10, $00, $00, $00, $00, $00, $00, $01, $90, $09, $0A, $00, $90, $00, $10, $02, $01, $12, $10, $20, $A0, $9A
	dc.b	$09, $9A, $00, $21, $01, $00, $20, $00, $A9, $09, $00, $00, $00, $01, $00, $00, $09, $00, $10, $00, $10, $00, $90, $09, $0A, $00, $00, $00, $02, $00, $00, $10
	dc.b	$10, $21, $00, $90, $0A, $09, $09, $00, $10, $01, $00, $00, $00, $00, $90, $00, $00, $09, $10, $00, $00, $00, $00, $00, $00, $10, $09, $00, $00, $90, $00, $00
	dc.b	$00, $00, $00, $00, $19, $00, $10, $01, $02, $00, $00, $0A, $09, $00, $90, $01, $00, $01, $00, $00, $09, $00, $00, $90, $00, $00, $01, $00, $00, $00, $00, $00
	dc.b	$00, $00, $09, $00, $00, $00, $00, $00, $00, $00, $00, $00, $01, $00, $10, $20, $00, $00, $A0, $90, $09, $01, $00, $01, $00, $00, $00, $09, $00, $00, $90, $01
	dc.b	$00, $00, $00, $00, $00, $00, $01, $09, $00, $09, $00, $00, $00, $00, $00, $00, $00, $01, $00, $00, $00, $00, $10, $02, $00, $0A, $00, $90, $00, $00, $00, $00
	dc.b	$10, $00, $00, $90, $00, $00, $09, $01, $00, $00, $00, $00, $00, $01, $00, $90, $00, $90, $00, $00, $00, $00, $01, $00, $00, $00, $00, $00, $00, $01, $00, $02
	dc.b	$00, $00, $A0, $09, $00, $00, $00, $00, $00, $10, $09, $00, $00, $00, $90, $00, $00, $10, $00, $00, $00, $00, $00, $00, $00, $90, $00, $00, $00, $00, $00, $00
	dc.b	$19, $01, $00, $00, $00, $00, $01, $00, $90, $00, $01, $00, $00, $00, $B2, $2B, $22, $01, $C5, $D4, $2C, $4C, $4B, $1A, $02, $0A, $3C, $33, $B0, $92, $A3, $A1
	dc.b	$B3, $A2, $B1, $3C, $4A, $93, $C3, $4D, $5D, $5C, $94, $C3, $B2, $3B, $3A, $C4, $B3, $B1, $2A, $20, $B3, $A2, $A9, $2B, $31, $3C, $14, $D5, $D5, $D4, $4C, $4C
	dc.b	$4A, $B4, $BC, $4B, $2B, $3B, $04, $C1, $03, $B0, $00, $94, $BD, $5D, $5C, $23, $C5, $D5, $C4, $BA, $21, $C4, $B1, $B3, $2C, $4B, $2B, $3A, $1C, $52, $E6, $E5
	dc.b	$AC, $5D, $6D, $3C, $4A, $4D, $5D, $33, $A3, $C4, $A9, $93, $C4, $C4, $C5, $CE, $6E, $6D, $4A, $C6, $E5, $D6, $E6, $E6, $E5, $B4, $D5, $B3, $C3, $3D, $5D, $5B
	dc.b	$5E, $6E, $44, $E6, $E6, $D5, $D5, $C5, $D5, $D2, $4B, $3C, $5D, $5D, $5E, $6D, $5E, $6D, $C6, $E6, $E6, $D4, $D5, $D5, $D3, $3D, $59, $2B, $2B, $4D, $5D, $52
	dc.b	$E6, $E6, $D4, $AB, $54, $DA, $4D, $5E, $6D, $5D, $5D, $5D, $5D, $5C, $4B, $E6, $E6, $E6, $D4, $C6, $E5, $C4, $3D, $5C, $3D, $5D, $5E, $6E, $65, $DD, $6E, $6E
	dc.b	$6E, $44, $5E, $5D, $59, $D5, $D5, $D5, $D5, $D5, $D6, $E5, $BD, $5D, $5D, $5C, $5E, $6E, $6E, $6D, $6E, $5E, $6D, $5C, $5E, $6E, $6E, $54, $CC, $52, $D4, $D6
	dc.b	$E6, $E6, $E5, $D6, $E6, $DE, $7F, $7F, $7F, $6E, $7F, $7F, $6D, $5D, $5D, $5D, $43, $35, $F7, $F7, $F7, $E6, $F7, $E6, $F7, $E5, $D6, $E4, $C5, $54, $F7, $E6
	dc.b	$F7, $AD, $E6, $4D, $E6, $5E, $D6, $4E, $46, $7F, $F7, $DC, $D7, $DF, $47, $FE, $58, $85, $67, $87, $57, $FF, $70, $EB, $64, $F6, $7F, $F7, $7F, $46, $58, $77
	dc.b	$58, $7B, $78, $8E, $CF, $73, $F4, $7D, $F7, $7F, $F7, $78, $56, $6F, $64, $68, $77, $FE, $76, $FD, $7C, $F7, $78, $7D, $78, $7C, $6F, $75, $FF, $8B, $FE, $7C
	dc.b	$E7, $58, $8E, $6F, $64, $3F, $7D, $DE, $7E, $CE, $7D, $C7, $87, $D7, $F7, $F7, $F7, $E4, $F7, $CC, $E7, $DE, $78, $74, $7F, $6F, $88, $7D, $4F, $75, $EE, $66
	dc.b	$F7, $88, $E7, $87, $E7, $F7, $E5, $E7, $ED, $E7, $E6, $EE, $7B, $DE, $69, $4F, $7E, $5D, $7F, $5E, $7A, $B8, $8D, $6F, $7E, $6F, $7F, $6E, $7F, $5E, $74, $A8
	dc.b	$8E, $6F, $7E, $6F, $7F, $6E, $7F, $5E, $76, $EF, $7C, $5F, $7E, $6F, $7F, $6D, $7F, $5E, $77, $8B, $7E, $5F, $71, $2E, $7F, $6E, $7F, $5D, $7E, $F7, $53, $F6
	dc.b	$65, $F7, $F5, $D6, $DC, $D7, $68, $67, $ED, $E7, $6F, $D6, $E6, $D6, $F6, $37, $FE, $7D, $4F, $76, $DF, $7F, $7F, $7F, $6E, $7F, $E8, $EB, $F7, $5C, $F7, $F7
	dc.b	$F6, $E5, $27, $FE, $7E, $6F, $74, $4F, $7F, $7F, $6E, $6E, $7F, $E8, $F6, $F6, $6D, $F6, $A6, $E5, $DB, $57, $FE, $7F, $7F, $75, $EF, $7E, $6F, $7E, $25, $78
	dc.b	$67, $F6, $F7, $6E, $E7, $F7, $F7, $F6, $7E, $88, $F7, $F5, $64, $F7, $E5, $CD, $5D, $47, $FD, $7F, $7F, $7C, $EE, $7F, $7F, $7F, $57, $48, $7C, $6E, $A6, $5F
	dc.b	$6B, $4B, $C5, $DA, $7F, $E7, $F7, $F7, $4C, $F7, $F7, $F7, $F6, $57, $87, $D6, $EC, $66, $F6, $D4, $BC, $4D, $47, $FD, $7F, $6F, $74, $CE, $7F, $7F, $6E, $65
	dc.b	$4F, $7F, $7F, $7E, $6F, $7F, $7F, $6E, $63, $78, $7D, $6E, $5D, $6F, $7E, $5C, $5D, $BC, $7F, $D7, $E5, $E6, $CB, $E6, $E7, $F6, $E6, $6C, $F7, $F7, $F7, $E6
	dc.b	$F7, $F7, $E6, $F6, $C7, $87, $54, $E5, $C6, $F7, $EB, $53, $9E, $57, $EF, $7E, $6F, $7E, $6E, $7F, $6E, $6F, $64, $78, $75, $BE, $6D, $6F, $7E, $D6, $2B, $E5
	dc.b	$65, $88, $F6, $F7, $E7, $F7, $F6, $C6, $F5, $47, $EF, $7F, $7F, $7F, $7E, $78, $72, $6F, $7E, $7F, $D7, $F4, $53, $C9, $54, $F7, $1D, $E6, $D7, $FA, $6E, $B6
	dc.b	$D0, $C6, $CE, $65, $ED, $6E, $7F, $E7, $E4, $45, $E5, $45, $F7, $AE, $D6, $E7, $CF, $7F, $6D, $7F, $6C, $6F, $65, $DD, $6E, $47, $87, $5E, $A7, $F5, $54, $E4
	dc.b	$6E, $3A, $5F, $76, $88, $F5, $C7, $F6, $D4, $E6, $D2, $43, $DD, $7C, $88, $F6, $46, $F7, $EE, $6D, $D6, $AD, $3D, $74, $88, $F6, $D6, $F7, $EE, $6C, $E6, $6F
	dc.b	$7F, $37, $F6, $4E, $66, $F6, $AE, $66, $F6, $6F, $6C, $E6, $6F, $7F, $66, $4F, $7F, $D7, $ED, $7E, $E7, $FD, $7C, $F7, $F7, $6F, $C7, $F5, $78, $77, $F4, $6F
	dc.b	$67, $FF, $88, $75, $EB, $78, $77, $F6, $6F, $65, $F7, $4A, $88, $F6, $5F, $37, $F7, $6F, $66, $F5, $6F, $7E, $A5, $F7, $F7, $E3, $53, $E7, $EE, $7E, $E7, $F5
	dc.b	$5E, $7D, $F7, $F7, $EE, $7C, $F7, $DE, $7E, $E7, $F5, $6F, $76, $88, $F6, $5F, $37, $F7, $3F, $7E, $E7, $F4, $6F, $67, $EE, $78, $8F, $E7, $DE, $7F, $57, $F6
	dc.b	$5F, $7E, $E7, $E4, $E7, $F7, $FE, $7E, $B7, $F6, $6F, $7C, $F7, $ED, $6E, $7F, $54, $E7, $FE, $7E, $66, $F7, $CF, $7D, $E7, $F6, $CE, $7E, $E7, $F7, $FE, $7E
	dc.b	$57, $F6, $4F, $7E, $E7, $F6, $5E, $66, $F5, $5F, $7F, $67, $F6, $CF, $7E, $17, $F6, $5F, $7E, $53, $E7, $F6, $E4, $6E, $B7, $F7, $FA, $7F, $26, $E6, $BE, $7F
	dc.b	$65, $F7, $DE, $7F, $7F, $17, $F5, $5F, $7E, $37, $F6, $4F, $7E, $05, $E6, $4A, $F7, $F7, $F6, $7F, $55, $F7, $E5, $6F, $66, $F7, $F4, $6E, $61, $D6, $F7, $F7
	dc.b	$E4, $6C, $F7, $F7, $CD, $5C, $D6, $E5, $DD, $6E, $6A, $E7, $EE, $7F, $7F, $56, $F6, $5E, $7F, $66, $F7, $DF, $7F, $65, $E7, $EC, $5E, $65, $F7, $F7, $ED, $7F
	dc.b	$D7, $F7, $DE, $7F, $6B, $E6, $D3, $6E, $6E, $C5, $D6, $F7, $F7, $DE, $7F, $56, $E6, $BE, $6D, $B5, $E6, $D3, $6F, $7D, $E6, $E5, $5E, $65, $EC, $6F, $7F, $65
	dc.b	$E7, $F4, $6E, $54, $E6, $E5, $6E, $5C, $D6, $E6, $CD, $55, $CE, $7F, $7F, $C7, $F6, $9E, $7E, $C6, $F6, $3E, $6A, $D6, $E5, $CC, $6E, $55, $E6, $DD, $6C, $E7
	dc.b	$F5, $5F, $7E, $46, $F7, $DD, $6D, $D6, $E5, $3E, $6E, $64, $E6, $BD, $6C, $E5, $2E, $7F, $66, $F6, $0E, $6E, $55, $D4, $3C, $5C, $D6, $E5, $5E, $6B, $D5, $CC
	dc.b	$5D, $35, $1E, $6E, $45, $E6, $BE, $6D, $B6, $E5, $5E, $45, $E6, $DC, $6D, $C5, $D4, $4A, $C5, $D0, $4D, $6E, $53, $BD, $6E, $5C, $4D, $5E, $6B, $C4, $4D, $5D
	dc.b	$A5, $D5, $BC, $4B, $C5, $D4, $A2, $B4, $2D, $52, $D4, $3D, $52, $D5, $BC, $49, $C5, $D3, $10, $D5, $0B, $14, $D5, $D4, $3C, $C4, $39, $4C, $A4, $A4, $C9, $4D
	dc.b	$5D, $5C, $B3, $01, $BA, $34, $C1, $2C, $34, $C4, $BB, $A1, $02, $92, $C4, $2B, $4C, $A5, $CC, $5C, $B4, $9C, $5C, $C5, $BC, $30, $C3, $AA, $22, $C0, $23, $23
	dc.b	$C3, $1A, $BB, $33, $99, $2B, $21, $4C, $4A, $C4, $2C, $4B, $22, $C4, $4D, $32, $CA, $30, $4C, $B2, $3A, $2B, $4A, $AA, $22, $3B, $2B, $1A, $4C, $C4, $A2, $90
	dc.b	$C4, $20, $0A, $41, $B4, $C3, $AB, $3B, $B3, $B0, $B3, $23, $B1, $B4, $9A, $2B, $B3, $4B, $3C, $29, $42, $C9, $3C, $19, $39, $4C, $3B, $12, $C4, $AA, $AA, $34
	dc.b	$C2, $B3, $4C, $C4, $BA, $4B, $B2, $B3, $1B, $10, $94, $BB, $00, $A2, $A2, $4C, $23, $C2, $03, $B1, $4C, $22, $A0, $12, $B3, $1A, $31, $AB, $A4, $B3, $A4, $CB
	dc.b	$C4, $2C, $20, $33, $B0, $A9, $2A, $4A, $B0, $13, $AA, $4C, $03, $9C, $30, $A0, $21, $3C, $A3, $4C, $2C, $94, $0A, $20, $C2, $41, $AA, $30, $12, $A9, $AA, $34
	dc.b	$B9, $AA, $23, $C3, $2B, $13, $9A, $23, $BB, $B0, $93, $2A, $BA, $23, $4B, $D4, $49, $A9, $90, $A3, $13, $B4, $AA, $C1, $3B, $13, $BA, $29, $13, $BB, $23, $A3
	dc.b	$99, $4B, $AB, $9A, $24, $B9, $C3, $B4, $30, $09, $12, $AA, $13, $C4, $C4, $C9, $02, $B3, $B3, $4C, $AB, $22, $B3, $09, $39, $BA, $4D, $43, $BA, $5C, $B9, $4C
	dc.b	$B3, $B3, $21, $B3, $C4, $4B, $3C, $09, $41, $B1, $4C, $3C, $2C, $42, $1B, $1A, $A2, $A2, $B2, $A3, $B4, $C3, $B0, $20, $C3, $42, $0B, $10, $B3, $3A, $3C, $32
	dc.b	$AD, $41, $4C, $94, $C1, $20, $B3, $2B, $3B, $B1, $40, $1A, $9B, $23, $29, $9B, $94, $A0, $2A, $B4, $B9, $A4, $CB, $32, $03, $AC, $B4, $93, $93, $B1, $3C, $32
	dc.b	$B3, $A9, $01, $AA, $30, $90, $3B, $A2, $B3, $19, $0A, $3B, $93, $AB, $40, $C4, $B9, $20, $B3, $A0, $00, $02, $B2, $2A, $A3, $B3, $A0, $B3, $A2, $91, $91, $09
	dc.b	$A2, $19, $01, $91, $90, $10, $91, $90, $2A, $19, $01, $09, $02, $99, $10, $91, $09, $10, $91, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $02, $A0, $00
	dc.b	$00, $00, $00, $00, $00, $2A, $02, $00, $0A, $02, $0A, $2A, $02, $A0, $00, $2A, $00, $00, $2A, $2A, $02, $A2, $A2, $00, $A2, $00, $00, $00, $00, $00, $01, $90
	dc.b	$00, $00, $00, $00, $0A, $02, $0A, $00, $00, $00, $00, $20, $A2, $00, $01, $90, $00, $19, $00, $19, $01, $90, $00, $00, $00, $00, $00, $0A, $2A, $02, $A0, $00
	dc.b	$00, $00, $00, $20, $A2, $00, $00, $01, $90, $19, $00, $19, $00, $00, $00, $0A, $20, $0A, $20, $A0, $00, $00, $00, $00, $2A, $02, $00, $A2, $19, $00, $19, $01
	dc.b	$90, $01, $9A, $20, $00, $00, $0A, $2A, $00, $00, $00, $00, $00, $00, $00, $00, $02, $0A, $20, $00, $01, $90, $19, $00, $01, $90, $00, $0A, $20, $A0, $00, $00
	dc.b	$00, $00, $00, $00, $00, $02, $A0, $02, $00, $01, $9A, $20, $00, $01, $A1, $00, $00, $0A, $2A, $00, $00, $00, $00, $00, $00, $09, $19, $10, $00, $00, $2A, $20
	dc.b	$00, $00, $00, $00, $00, $19, $00, $00, $0A, $02, $A0, $00, $00, $09, $10, $00, $00, $00, $00, $2A, $C2, $C5, $BB, $4C, $33, $3C, $4B, $3C, $40, $2D, $5D, $D6
	dc.b	$DC, $50, $C5, $BB, $4C, $4D, $5B, $BC, $5D, $5C, $4C, $5D, $03, $99, $4D, $44, $D4, $B1, $12, $0B, $40, $00, $9C, $4A, $94, $C3, $2C, $33, $D3, $4A, $A3, $BB
	dc.b	$A4, $0B, $3A, $BB, $33, $B3, $91, $2A, $95, $CA, $10, $B3, $AB, $B4, $3B, $B5, $D0, $93, $9B, $4C, $3B, $4C, $A4, $C4, $1B, $C5, $BC, $5D, $C5, $C0, $23, $2C
	dc.b	$4A, $2A, $21, $BB, $4C, $12, $3C, $33, $C0, $32, $C4, $D4, $5D, $3A, $C5, $C9, $4C, $A5, $BD, $43, $C4, $3A, $99, $3A, $4C, $3C, $B3, $B4, $C4, $3D, $43, $C4
	dc.b	$BC, $42, $B3, $29, $0C, $15, $C3, $C2, $0B, $32, $1C, $23, $03, $C2, $3B, $4D, $5A, $B0, $3C, $05, $D3, $BA, $2B, $4D, $5B, $05, $DA, $B3, $04, $3C, $3C, $4C
	dc.b	$5D, $34, $D5, $D5, $CA, $25, $DB, $4C, $4B, $B0, $5D, $4C, $4C, $3C, $A5, $C4, $D4, $3A, $C5, $CA, $A2, $B4, $C5, $3D, $4C, $5D, $4B, $C4, $C4, $C2, $BC, $44
	dc.b	$C3, $35, $E6, $D3, $C4, $0B, $CB, $44, $BB, $4C, $5E, $6D, $4C, $C5, $D5, $3D, $5D, $5D, $45, $E6, $E6, $E9, $5D, $5B, $A5, $D3, $92, $5D, $22, $4C, $2A, $5E
	dc.b	$53, $A3, $CC, $59, $D6, $E4, $5E, $6E, $34, $4C, $3D, $5A, $1C, $5D, $43, $D5, $4E, $6D, $35, $D4, $D4, $34, $C4, $D4, $4C, $A4, $C2, $2E, $6C, $C5, $CA, $4B
	dc.b	$39, $C4, $B4, $B0, $A4, $D5, $D5, $C3, $3D, $51, $D5, $BC, $44, $E4, $6E, $35, $CB, $4D, $5C, $94, $D5, $CA, $5D, $44, $D2, $4A, $B5, $D4, $3D, $45, $0D, $A5
	dc.b	$D4, $3E, $55, $D3, $4D, $4B, $4D, $95, $D6, $E5, $C3, $3D, $54, $C9, $34, $D4, $4E, $55, $E9, $6D, $C6, $DD, $6C, $E6, $BD, $5D, $52, $CC, $5D, $40, $D5, $D4
	dc.b	$5D, $35, $DB, $5D, $35, $BD, $51, $DA, $6E, $D6, $3E, $6B, $D4, $AD, $5C, $35, $DB, $5C, $4D, $C6, $E4, $5B, $3D, $45, $DD, $61, $E5, $5D, $C5, $2D, $4A, $12
	dc.b	$3D, $5D, $34, $BB, $32, $4E, $6B, $E6, $4E, $45, $4B, $D9, $59, $D4, $4C, $B3, $5D, $D6, $BD, $A4, $4D, $B5, $E5, $39, $4B, $24, $B5, $DD, $55, $CE, $55, $2E
	dc.b	$46, $DD, $54, $DB, $5D, $04, $5C, $E6, $BE, $6C, $D6, $D4, $32, $D2, $53, $DD, $55, $DE, $65, $DD, $45, $0D, $34, $3D, $5B, $D5, $AE, $64, $E5, $53, $4E, $E6
	dc.b	$6E, $E6, $6A, $EB, $63, $DC, $42, $33, $DD, $55, $DE, $65, $DC, $4A, $55, $EE, $66, $DF, $57, $AE, $D6, $59, $DE, $56, $DE, $55, $4D, $3D, $55, $EC, $65, $FC
	dc.b	$75, $FE, $67, $DE, $D6, $52, $EE, $66, $CE, $06, $4D, $E4, $64, $DD, $6D, $E5, $6E, $E5, $7E, $E6, $5E, $36, $ED, $65, $F4, $65, $E4, $5C, $CB, $65, $FE, $76
	dc.b	$FE, $76, $EE, $6C, $65, $EF, $67, $EF, $66, $D9, $02, $D6, $6E, $F6, $7E, $F6, $7E, $EC, $6D, $6A, $F9, $75, $F1, $7B, $E2, $E5, $66, $FF, $67, $DF, $57, $6A
	dc.b	$FE, $76, $FE, $67, $DE, $CE, $75, $EE, $67, $FF, $57, $DD, $EA, $76, $FE, $66, $ED, $35, $6D, $ED, $7C, $DE, $73, $FC, $7E, $60, $F6, $7F, $E6, $D6, $5F, $37
	dc.b	$EB, $CE, $75, $F6, $6F, $57, $F6, $EE, $76, $FB, $5C, $7E, $F6, $45, $5F, $C7, $E2, $7F, $E6, $65, $48, $67, $DD, $DC, $75, $FE, $C7, $7F, $E2, $66, $6F, $F6
	dc.b	$66, $08, $67, $6F, $F5, $8B, $FF, $48, $3F, $F5, $76, $68, $54, $75, $EF, $76, $EF, $F8, $6D, $FF, $77, $DF, $E7, $75, $FF, $67, $6E, $87, $57, $FF, $75, $6F
	dc.b	$D6, $7E, $EF, $77, $6F, $F5, $75, $FF, $7C, $78, $66, $66, $F5, $C7, $FE, $C7, $56, $87, $D7, $EF, $56, $7F, $E5, $7D, $CF, $7E, $6F, $47, $D6, $87, $E8, $FF
	dc.b	$47, $5E, $E5, $55, $1F, $7F, $7F, $7E, $7B, $87, $D7, $FE, $75, $78, $6D, $7E, $4E, $6D, $5E, $6D, $78, $7D, $7E, $F4, $76, $EE, $4C, $6D, $D5, $E7, $F6, $B7
	dc.b	$87, $E7, $FD, $37, $5E, $DC, $56, $DC, $E7, $3F, $66, $87, $A7, $FE, $C8, $E1, $F6, $E7, $F6, $E7, $4E, $6F, $D7, $D6, $FD, $72, $68, $7D, $6D, $13, $4D, $37
	dc.b	$FE, $7D, $68, $77, $D6, $87, $E7, $F5, $6E, $D7, $EF, $8F, $7F, $F8, $E6, $FC, $6D, $4F, $7E, $D7, $FD, $74, $6F, $F8, $F7, $FE, $7E, $6E, $6F, $67, $87, $6E
	dc.b	$78, $76, $B4, $F7, $E6, $DE, $6D, $78, $77, $F7, $87, $6D, $5F, $7F, $7D, $E7, $48, $68, $F3, $F1, $7E, $6E, $E7, $E7, $FD, $7D, $F7, $4E, $5F, $7C, $D6, $F7
	dc.b	$E6, $CE, $70, $87, $7F, $6F, $67, $F7, $EE, $5B, $6F, $67, $86, $8F, $9E, $E7, $F7, $CF, $7E, $7F, $66, $FE, $8F, $D9, $F8, $FB, $6F, $6E, $7E, $B7, $FF, $8E
	dc.b	$F7, $F7, $EE, $7E, $5E, $65, $E6, $48, $86, $F6, $F6, $6F, $7C, $E3, $D7, $E3, $6F, $D8, $86, $AE, $7F, $57, $F6, $F7, $AD, $6D, $F7, $6F, $7F, $66, $88, $DE
	dc.b	$D4, $65, $E6, $FE, $8F, $D6, $F8, $FF, $7E, $5E, $66, $E6, $48, $77, $F7, $F5, $78, $76, $ED, $C7, $AE, $7F, $F8, $FE, $7F, $7D, $F7, $2E, $D6, $5D, $64, $87
	dc.b	$7F, $6E, $47, $87, $7F, $E6, $61, $E7, $FF, $8E, $F7, $F7, $58, $77, $F4, $62, $4E, $78, $48, $F3, $CE, $8F, $F7, $AF, $7E, $6E, $57, $85, $88, $61, $C7, $FE
	dc.b	$8F, $E6, $E6, $E6, $68, $77, $87, $45, $78, $57, $EA, $5D, $6F, $75, $87, $7F, $6D, $66, $87, $7F, $55, $E5, $E7, $58, $68, $85, $6B, $6F, $7D, $E5, $6F, $3C
	dc.b	$76, $8C, $8F, $E7, $F7, $E5, $3E, $66, $EF, $76, $6F, $88, $68, $8E, $E7, $F7, $F6, $7E, $87, $55, $78, $C8, $86, $7F, $7E, $6E, $E7, $4F, $06, $E7, $28, $77
	dc.b	$88, $F1, $6E, $78, $77, $FE, $7E, $C7, $EF, $8F, $F8, $87, $4A, $5F, $75, $FB, $7F, $57, $FF, $8F, $C7, $F7, $F7, $EF, $73, $F6, $6F, $77, $8D, $88, $67, $F7
	dc.b	$F7, $EF, $8F, $F7, $4F, $77, $8C, $88, $67, $F6, $D7, $FD, $7E, $F8, $FF, $77, $80, $88, $76, $F6, $27, $86, $7F, $D8, $8C, $77, $8E, $8F, $47, $87, $67, $87
	dc.b	$6F, $27, $FD, $76, $FF, $88, $57, $F7, $B7, $87, $3F, $67, $FD, $7E, $68, $75, $F8, $87, $57, $87, $5F, $76, $FD, $7F, $7F, $D7, $88, $ED, $66, $EE, $78, $77
	dc.b	$EE, $7F, $47, $87, $3E, $7F, $7D, $78, $7E, $37, $EF, $7C, $F8, $E8, $8F, $56, $F7, $35, $F7, $F7, $0D, $F7, $F6, $7E, $F7, $F6, $6F, $67, $EF, $7F, $77, $FF
	dc.b	$7F, $76, $38, $7E, $07, $F6, $6B, $F7, $F6, $7E, $F7, $F6, $7C, $FB, $6F, $7F, $7D, $78, $8F, $C7, $58, $8F, $E7, $E6, $F7, $EE, $7F, $7D, $1F, $7F, $76, $EE
	dc.b	$78, $8D, $F7, $EE, $7F, $7F, $7F, $7F, $65, $F7, $3F, $7E, $D7, $F6, $6F, $7F, $6D, $4C, $7F, $B7, $87, $7F, $56, $F7, $CF, $7F, $65, $E7, $E4, $E7, $F7, $F5
	dc.b	$55, $F7, $F6, $7F, $E7, $F6, $5F, $7E, $5D, $78, $8F, $65, $68, $8F, $C7, $FE, $7C, $F7, $EE, $88, $38, $FF, $8F, $F8, $8B, $88, $57, $F4, $88, $E8, $87, $4F
	dc.b	$67, $F3, $78, $86, $85, $78, $8D, $F7, $78, $57, $88, $F4, $C7, $F7, $DF, $76, $87, $6F, $8E, $88, $DD, $F7, $F1, $7F, $76, $EF, $7F, $76, $FE, $7F, $66, $F6
	dc.b	$7F, $07, $87, $68, $84, $F7, $DF, $76, $87, $6F, $75, $F6, $6F, $67, $C8, $8F, $C7, $F6, $63, $88, $FC, $7E, $F7, $DE, $7F, $D7, $D5, $BD, $6F, $7D, $E6, $6E
	dc.b	$E7, $F7, $2E, $E7, $F0, $7F, $46, $D6, $F6, $2E, $7B, $F7, $DD, $E7, $F7, $DB, $F7, $F6, $7E, $D6, $ED, $56, $F6, $7F, $A7, $F4, $6E, $E7, $DE, $56, $F6, $43
	dc.b	$E6, $CE, $6A, $6F, $A7, $F7, $3F, $7E, $6F, $47, $F7, $F6, $E6, $4F, $74, $F7, $E5, $5E, $D7, $EF, $7E, $6E, $7F, $56, $E5, $E6, $5E, $5E, $6B, $D6, $EC, $6D
	dc.b	$D6, $ED, $7F, $7E, $B6, $EA, $5E, $6C, $5E, $6D, $D6, $AE, $6D, $9D, $7F, $96, $E4, $6E, $6E, $B6, $CD, $5E, $65, $DC, $5E, $5D, $6E, $6E, $36, $5E, $E7, $F5
	dc.b	$5E, $63, $E6, $D3, $5D, $43, $E6, $4E, $55, $DD, $6E, $50, $C5, $BE, $6D, $D6, $E6, $CD, $62, $E6, $E6, $E5, $25, $E6, $D0, $32, $D5, $D4, $B6, $F6, $5E, $53
	dc.b	$D6, $E5, $5D, $3C, $05, $CD, $6E, $44, $C5, $CA, $29, $3D, $55, $EC, $6E, $36, $E6, $EC, $6E, $6D, $23, $5C, $C4, $0C, $4C, $14, $BC, $5D, $C6, $ED, $6D, $A5
	dc.b	$E6, $BE, $6B, $5E, $69, $D5, $D4, $4C, $B5, $D3, $2B, $B5, $D4, $3E, $65, $E4, $B4, $5E, $44, $A3, $C4, $C5, $D4, $AB, $4C, $A3, $2C, $33, $D5, $5F, $65, $CA
	dc.b	$D5, $5E, $35, $A2, $C6, $E5, $C3, $BC, $5C, $A5, $D3, $1A, $B6, $BF, $72, $E4, $E7, $FC, $7E, $5D, $54, $E5, $4D, $20, $32, $33, $CC, $4A, $65, $F6, $D2, $DB
	dc.b	$7F, $56, $BC, $E6, $DE, $6C, $5E, $65, $E5, $C4, $DB, $55, $3F, $7E, $5E, $65, $F6, $6D, $CD, $7F, $B5, $44, $E6, $D2, $C6, $3F, $6D, $66, $87, $5D, $5D, $7F
	dc.b	$46, $E6, $F7, $EE, $7D, $4E, $7E, $E6, $5E, $E7, $CE, $57, $EF, $7F, $6E, $65, $F7, $C4, $F6, $7F, $56, $4F, $46, $F6, $56, $F5, $6E, $D4, $66, $FD, $7F, $64
	dc.b	$5C, $F7, $DD, $65, $9F, $7D, $DC, $55, $F7, $CD, $D6, $4E, $6D, $56, $87, $6F, $7E, $7F, $69, $EB, $B7, $F5, $6E, $4D, $6E, $55, $4E, $B6, $E4, $B6, $E3, $60
	dc.b	$F7, $DF, $7D, $5F, $73, $E3, $64, $F6, $5E, $C6, $4E, $60, $DD, $63, $E6, $CC, $C6, $DD, $52, $05, $F6, $6F, $56, $E5, $16, $EE, $7E, $2E, $7E, $C6, $DC, $D6
	dc.b	$E5, $5D, $C3, $6E, $C7, $FE, $7E, $3C, $7F, $45, $CD, $36, $E4, $60, $E4, $6F, $65, $4E, $A5, $DD, $65, $E4, $5E, $56, $F4, $6E, $34, $6F, $7D, $4E, $55, $E6
	dc.b	$50, $F6, $5E, $56, $DD, $6D, $3E, $55, $D3, $4C, $C5, $E5, $2A, $D6, $EA, $7F, $6E, $6E, $54, $D5, $E7, $F6, $C4, $C4, $BC, $6E, $59, $5E, $5A, $2C, $5C, $B6
	dc.b	$ED, $6E, $C5, $6F, $6B, $5E, $65, $E6, $4D, $E6, $DC, $55, $DD, $6E, $B6, $CE, $64, $CE, $63, $5F, $61, $DB, $6D, $E7, $EC, $D7, $ED, $6C, $DB, $6E, $46, $BE
	dc.b	$52, $E5, $5C, $D6, $DC, $26, $ED, $6D, $D5, $55, $ED, $7F, $6E, $6E, $6C, $E6, $D6, $F7, $E2, $55, $EB, $6E, $44, $5E, $6C, $DD, $6D, $D6, $4C, $5F, $7F, $6D
	dc.b	$6E, $B6, $DB, $46, $F6, $52, $E6, $3E, $64, $DE, $6D, $D6, $5E, $45, $EC, $6A, $E5, $65, $F6, $BD, $B6, $DE, $7E, $CD, $6D, $C6, $AD, $B6, $E3, $6D, $E6, $AE
	dc.b	$65, $EC, $6D, $D5, $5E, $46, $E2, $6E, $D6, $E5, $C6, $F7, $CD, $D6, $BE, $6C, $2D, $6E, $25, $5E, $54, $E5, $5C, $E6, $CB, $C6, $E4, $55, $AF, $7E, $4D, $6E
	dc.b	$46, $EC, $46, $F6, $6D, $E6, $2E, $65, $EC, $6E, $45, $4E, $54, $DD, $6C, $D6, $CD, $36, $ED, $6E, $5D, $6E, $6C, $9E, $63, $E6, $AB, $D6, $DC, $54, $E4, $5D
	dc.b	$25, $CD, $50, $BC, $5D, $44, $CC, $45, $CE, $6E, $5D, $6E, $55, $E3, $55, $E6, $C2, $E6, $BD, $63, $E1, $6E, $A5, $3D, $53, $DC, $6D, $D5, $4D, $C5, $14, $F7
	dc.b	$E4, $C6, $E1, $6E, $5D, $6E, $45, $0D, $54, $E6, $4D, $E6, $BD, $45, $E5, $5C, $D5, $4E, $55, $CD, $52, $C5, $E5, $C0, $95, $BE, $6D, $5D, $6E, $45, $1D, $35
	dc.b	$D4, $A5, $E5, $A2, $B4, $BC, $4C, $4C, $5D, $24, $BB, $14, $C4, $DB, $5D, $5D, $6E, $5C, $4C, $15, $D4, $C5, $D2, $4B, $A3, $2C, $30, $0A, $11, $B1, $2A, $2A
	dc.b	$2C, $4C, $33, $AA, $24, $D5, $CC, $5C, $4C, $23, $C3, $A3, $C4, $C4, $C3, $A3, $0B, $3A, $09, $3B, $2A, $19, $A3, $C4, $B3, $B3, $B2, $1B, $39, $4D, $5C, $A4
	dc.b	$C4, $D5, $AB, $03, $9B, $3B, $3C, $4A, $2A, $20, $A3, $AA, $93, $B3, $C4, $B0, $A3, $B9, $3B, $41, $C4, $AB, $4C, $3B, $23, $B9, $20, $A2, $0A, $92, $11, $90
	dc.b	$1A, $20, $9A, $3B, $91, $09, $A2, $2B, $20, $2B, $42, $D5, $BB, $4C, $4C, $32, $BA, $29, $02, $00, $B3, $A3, $B2, $A3, $90, $0B, $3A, $9A, $3A, $A1, $00, $00
	dc.b	$10, $04, $C3, $3C, $4B, $90, $B4, $BB, $3B, $21, $A2, $A2, $02, $B2, $03, $B1, $2B, $1A, $2A, $91, $9A, $21, $A1, $12, $B4, $9C, $4A, $A3, $B3, $C4, $0B, $90
	dc.b	$20, $A2, $0B, $31, $A9, $20, $1A, $2A, $92, $A2, $B2, $0A, $93, $B0, $21, $92, $30, $C4, $0B, $3B, $3C, $32, $9B, $31, $AA, $39, $B4, $BA, $02, $10, $B3, $9A
	dc.b	$02, $AB, $30, $9A, $20, $00, $10, $00, $22, $AA, $4C, $04, $C2, $A2, $0A, $92, $10, $A2, $1B, $30, $A9, $3B, $2A, $2A, $09, $19, $A2, $1A, $93, $B2, $03, $B2
	dc.b	$99, $39, $02, $9B, $30, $0A, $10, $A2, $0A, $20, $A2, $B3, $1A, $1A, $2A, $02, $A0, $09, $1A, $11, $90, $01, $90, $10, $92, $92, $A2, $00, $00, $00, $02, $A0
	dc.b	$19, $00, $00, $A0, $2A, $02, $00, $A0, $2A, $00, $00, $91, $09, $19, $10, $91, $09, $10, $00, $02, $A2, $00, $00, $00, $00, $00, $00, $19, $00, $00, $00, $0A
	dc.b	$02, $A0, $2A, $20, $A0, $91, $00, $09, $10, $00, $09, $10, $00, $91, $00, $2A, $2A, $20, $0A, $20, $00, $A2, $A2, $00, $A2, $00, $00, $00, $00, $00, $00, $0A
	dc.b	$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $2A, $00, $00, $00, $00, $02, $A2, $0A, $2A, $20, $00, $00, $0A, $20, $0A, $20, $0A, $02, $0A, $2A, $2A
	dc.b	$2A, $00, $2A, $02, $A0, $00, $00, $00, $2A, $00, $00, $02, $A0, $2A, $A0, $01, $21, $09, $09, $A0, $99, $11, $22, $00, $A9, $90, $19, $90, $92, $22, $29, $A0
	dc.b	$A0, $0A, $09, $01, $22, $01, $99, $10, $9A, $A1, $12, $19, $29, $A0, $99, $01, $20, $02, $90, $1A, $09, $99, $20, $02, $A2, $01, $91, $AA, $9A, $11, $10, $02
	dc.b	$20, $29, $9A, $A9, $91, $2B, $21, $03, $19, $AA, $3A, $1A, $B1, $02, $A3, $02, $90, $90, $2B, $9A, $93, $12, $09, $00, $29, $A9, $99, $22, $12, $1B, $2A, $1B
	dc.b	$1B, $12, $3A, $A3, $39, $3B, $B0, $BB, $A0, $33, $22, $13, $92, $BC, $A1, $0B, $03, $04, $32, $2B, $BB, $BB, $A2, $01, $34, $42, $BB, $BA, $0A, $C9, $23, $42
	dc.b	$4C, $0B, $2C, $00, $A9, $24, $20, $3A, $BA, $09, $C3, $02, $03, $3A, $A4, $BB, $B2, $BA, $A3, $22, $23, $2A, $9A, $C1, $B3, $3B, $22, $2B, $93, $2B, $93, $9A
	dc.b	$22, $BA, $2B, $90, $39, $99, $40, $29, $AB, $2B, $3B, $21, $93, $93, $2B, $A9, $19, $3B, $02, $3B, $04, $9B, $1C, $A2, $B1, $49, $4B, $31, $BB, $CB, $92, $3B
	dc.b	$24, $A4, $1A, $1C, $C0, $CB, $43, $5C, $42, $2B, $B0, $CC, $B1, $94, $43, $53, $CC, $BD, $2C, $A2, $45, $94, $04, $9D, $3C, $CB, $AA, $43, $5B, $49, $BB, $CB
	dc.b	$C2, $A4, $39, $44, $21, $CB, $BD, $4B, $C5, $05, $41, $0C, $1D, $BC, $C1, $51, $24, $51, $BC, $CC, $CB, $B4, $33, $25, $03, $CC, $BC, $BB, $44, $94, $44, $AB
	dc.b	$BD, $C2, $BA, $95, $35, $03, $B1, $DC, $CB, $B4, $23, $45, $32, $AC, $DB, $D2, $44, $22, $52, $B1, $9C, $CD, $A3, $35, $22, $44, $BB, $CD, $CB, $39, $45, $24
	dc.b	$24, $CC, $DC, $CC, $33, $54, $54, $B2, $C0, $DD, $BB, $35, $43, $44, $BB, $CA, $DC, $C3, $45, $5C, $44, $2D, $CD, $CB, $C5, $44, $52, $44, $BD, $CD, $DB, $14
	dc.b	$45, $51, $50, $0D, $CD, $EB, $44, $55, $44, $13, $CD, $BE, $C4, $35, $45, $49, $4C, $DD, $CD, $10, $35, $55, $44, $2A, $ED, $AD, $C4, $35, $55, $54, $3D, $DD
	dc.b	$DD, $BB, $45, $56, $5A, $2C, $DE, $CD, $C4, $05, $64, $53, $BD, $DD, $DB, $C2, $45, $64, $14, $3D, $DE, $CD, $44, $35, $55, $44, $2C, $ED, $DB, $A4, $35, $55
	dc.b	$44, $CC, $DD, $DC, $B5, $A5, $55, $59, $DD, $DC, $C0, $B5, $35, $54, $3B, $DC, $CD, $DB, $15, $35, $55, $5C, $CD, $DD, $DC, $34, $55, $54, $43, $DC, $CD, $DD
	dc.b	$52, $53, $53, $5A, $CD, $CC, $DB, $34, $53, $41, $52, $DD, $C9, $DB, $44, $45, $44, $42, $CD, $CD, $DC, $05, $54, $50, $24, $AD, $CD, $CD, $C5, $55, $14, $24
	dc.b	$3D, $CB, $DC, $B5, $45, $A4, $B3, $2C, $DB, $B9, $D5, $55, $CB, $14, $2B, $E3, $4D, $93, $55, $5C, $A4, $BC, $D2, $BC, $DB, $55, $50, $A2, $4C, $DB, $A1, $E1
	dc.b	$26, $44, $B1, $5A, $D4, $D4, $DB, $E5, $55, $A3, $59, $2C, $BC, $2C, $DA, $5C, $4A, $4B, $42, $BA, $4C, $CD, $44, $D5, $25, $B0, $3A, $C3, $AC, $C5, $D4, $4B
	dc.b	$5C, $53, $CD, $A0, $DD, $4A, $B5, $54, $44, $2C, $BC, $DC, $D3, $C3, $53, $55, $5A, $CC, $CD, $DD, $B3, $D5, $96, $56, $AB, $D1, $DD, $DB, $CC, $44, $66, $6B
	dc.b	$CD, $AD, $DE, $DA, $D4, $97, $56, $33, $CC, $ED, $ED, $2D, $25, $66, $65, $3C, $CD, $EE, $E5, $E3, $56, $66, $55, $DA, $ED, $FA, $CC, $D6, $37, $56, $4A, $4E
	dc.b	$EE, $ED, $DD, $65, $67, $64, $5D, $DE, $EF, $3D, $C5, $56, $66, $63, $BD, $EE, $ED, $BC, $D6, $17, $46, $36, $DE, $EF, $DD, $43, $55, $66, $65, $5D, $CE, $EE
	dc.b	$EE, $5D, $66, $56, $75, $CD, $DE, $EF, $D4, $5B, $6A, $76, $55, $DD, $DE, $FF, $65, $5A, $7D, $79, $64, $E3, $FD, $FD, $B6, $55, $56, $66, $B5, $EC, $FC, $FD
	dc.b	$55, $46, $37, $65, $B4, $EE, $EF, $E3, $46, $5A, $65, $75, $4E, $DD, $EE, $FC, $64, $69, $74, $64, $3B, $EE, $FB, $ED, $56, $55, $64, $66, $D4, $F5, $FC, $F6
	dc.b	$D7, $C6, $66, $45, $D5, $FB, $F3, $E4, $C7, $C6, $64, $54, $DD, $ED, $EC, $DC, $46, $46, $6C, $6C, $5E, $EF, $0B, $5B, $D5, $66, $53, $6D, $BE, $DE, $DA, $4D
	dc.b	$35, $57, $3A, $5D, $5E, $1F, $BC, $5E, $54, $75, $5C, $D3, $AE, $4F, $42, $5C, $C5, $56, $6D, $4E, $6E, $2F, $31, $5B, $C5, $26, $5C, $4D, $6D, $CD, $DC, $5C
	dc.b	$AC, $D6, $55, $D5, $CC, $AC, $CD, $6D, $33, $E5, $6D, $6D, $5E, $4A, $BE, $55, $4C, $DB, $44, $44, $2B, $C2, $E5, $D6, $B5, $DD, $D6, $96, $D3, $D5, $E9, $B5
	dc.b	$5B, $CE, $5E, $63, $54, $4E, $5E, $56, $32, $EA, $DD, $55, $36, $D3, $ED, $64, $22, $1D, $D4, $D4, $43, $5D, $4D, $C5, $53, $3B, $D0, $DD, $55, $52, $DE, $6C
	dc.b	$3B, $5C, $4E, $6D, $41, $A6, $D3, $ED, $B3, $65, $DA, $DB, $3D, $6B, $54, $CE, $4E, $63, $6D, $EB, $6D, $5C, $54, $3D, $EE, $56, $5B, $DA, $6B, $1D, $A5, $5C
	dc.b	$ED, $D2, $6B, $45, $D5, $5D, $4D, $3D, $4D, $F5, $64, $6B, $6E, $6D, $5F, $55, $CD, $EC, $B5, $66, $36, $F7, $E5, $F5, $C5, $E5, $EE, $75, $6C, $39, $5D, $4E
	dc.b	$DD, $12, $BD, $C6, $66, $C6, $E3, $E3, $DD, $E4, $B4, $D6, $56, $53, $5E, $D5, $ED, $3E, $5B, $5D, $54, $65, $15, $DD, $E5, $DD, $E6, $35, $D5, $C7, $BC, $5E
	dc.b	$AE, $5D, $CD, $45, $5A, $C4, $6A, $2C, $E6, $E2, $4B, $D9, $A6, $EC, $6D, $6D, $3D, $6D, $20, $CC, $E5, $44, $4D, $D6, $4D, $6D, $5C, $35, $EC, $C5, $DA, $D4
	dc.b	$B6, $E6, $55, $CA, $C4, $ED, $BC, $DC, $64, $55, $3D, $64, $20, $DD, $EE, $5D, $55, $33, $6C, $D7, $B4, $EB, $BE, $EC, $C4, $15, $54, $64, $C5, $D4, $3E, $DE
	dc.b	$BA, $D5, $55, $64, $4D, $54, $9D, $CD, $ED, $C5, $C4, $56, $55, $A0, $5D, $CD, $BD, $F6, $E4, $37, $46, $C4, $E3, $24, $DC, $DD, $DC, $45, $17, $E5, $49, $E5
	dc.b	$93, $D5, $DE, $C3, $16, $46, $4D, $E5, $CA, $45, $EB, $CC, $44, $D6, $05, $BC, $9E, $54, $5D, $5C, $3E, $CD, $5B, $63, $5F, $7E, $6C, $6D, $4C, $EC, $BE, $55
	dc.b	$5E, $6C, $43, $53, $6E, $CC, $CE, $3D, $44, $64, $3E, $55, $5C, $5D, $CE, $BC, $DD, $46, $5B, $43, $50, $5A, $3D, $DC, $DE, $C3, $6A, $64, $3D, $5A, $54, $CD
	dc.b	$DD, $EB, $CB, $66, $63, $DD, $35, $32, $1E, $DA, $DE, $26, $55, $6C, $9B, $4B, $4C, $DD, $D3, $E4, $4A, $65, $63, $DE, $6D, $4C, $AC, $E4, $D9, $D6, $56, $5D
	dc.b	$DD, $24, $5C, $CD, $42, $E0, $A5, $64, $5E, $D2, $53, $B0, $33, $CC, $EC, $54, $36, $CD, $93, $5C, $55, $DE, $5C, $EA, $24, $C6, $6E, $D2, $56, $23, $DC, $DA
	dc.b	$EC, $B5, $55, $6D, $E6, $42, $5C, $DD, $CD, $E4, $96, $52, $40, $23, $A4, $14, $CE, $CD, $B3, $C5, $44, $63, $CB, $24, $5D, $ED, $A0, $9C, $AB, $65, $6E, $14
	dc.b	$A4, $CC, $CC, $3D, $CD, $26, $53, $4C, $A4, $CC, $44, $AD, $BD, $D5, $95, $34, $51, $DB, $C5, $C4, $AB, $E4, $3D, $15, $55, $49, $EB, $54, $31, $CD, $3B, $BD
	dc.b	$1B, $6C, $55, $E4, $43, $B4, $2C, $2E, $2D, $5C, $55, $35, $E3, $4C, $54, $AC, $DD, $CC, $5D, $55, $54, $E0, $35, $42, $3D, $CC, $DD, $B4, $64, $45, $EB, $53
	dc.b	$01, $3C, $3D, $EB, $43, $54, $35, $0C, $C4, $33, $4C, $DC, $CD, $B9, $55, $45, $CC, $BA, $55, $BD, $CB, $CD, $90, $35, $55, $2E, $A4, $30, $14, $CC, $CD, $CC
	dc.b	$65, $34, $BC, $C1, $04, $34, $CC, $CD, $D4, $35, $35, $40, $E4, $B5, $34, $BC, $DC, $0C, $24, $44, $6E, $D2, $45, $44, $3E, $B9, $DC, $B5, $54, $5C, $D1, $3C
	dc.b	$5A, $33, $CD, $DC, $B5, $54, $50, $D9, $AA, $41, $B4, $DC, $CB, $C4, $45, $54, $CD, $4C, $34, $B2, $AD, $BD, $D6, $95, $32, $BC, $00, $5C, $43, $1D, $DC, $24
	dc.b	$14, $53, $DD, $B3, $5B, $5B, $2C, $CC, $D3, $53, $5C, $CC, $93, $35, $4D, $42, $CD, $CC, $53, $A5, $C0, $B5, $C4, $4C, $4A, $DD, $AC, $44, $94, $1C, $32, $25
	dc.b	$42, $9D, $CD, $3D, $25, $B5, $4D, $01, $35, $33, $BD, $CC, $CD, $54, $44, $4C, $D4, $36, $CC, $C4, $DD, $D4, $95, $34, $43, $DB, $5D, $5A, $5D, $CD, $99, $A2
	dc.b	$52, $51, $E4, $D5, $45, $C5, $DC, $D0, $B3, $45, $45, $EA, $E5, $53, $54, $CC, $DC, $AC, $55, $4C, $AE, $5D, $53, $53, $4D, $CC, $CB, $44, $C5, $B4, $DD, $26
	dc.b	$35, $0D, $DC, $AB, $3C, $53, $5E, $23, $34, $52, $CC, $BC, $BA, $90, $45, $5E, $0B, $91, $52, $34, $9D, $DC, $B5, $5C, $44, $C2, $D4, $4B, $53, $AE, $3D, $1C
	dc.b	$41, $55, $4D, $CC, $35, $43, $C9, $DC, $CC, $55, $A5, $CC, $CC, $15, $4B, $49, $AE, $B0, $44, $35, $4D, $C3, $C4, $14, $5A, $CE, $9C, $35, $44, $19, $AB, $AB
	dc.b	$A5, $43, $DD, $CC, $04, $5C, $55, $BB, $DC, $B5, $4C, $B1, $CC, $C4, $26, $5C, $CD, $C4, $90, $B3, $B3, $BC, $2C, $6A, $49, $DC, $B3, $B2, $33, $33, $CC, $D5
	dc.b	$45, $BB, $D4, $A9, $B3, $C4, $5B, $DD, $52, $43, $D4, $94, $CB, $92, $41, $0B, $D4, $40, $2A, $A4, $3D, $CA, $42, $4C, $2C, $54, $C4, $D2, $A4, $BC, $C2, $B5
	dc.b	$2B, $D6, $90, $BC, $21, $AC, $4D, $93, $13, $AC, $63, $2B, $CC, $C3, $CC, $34, $A4, $B9, $A4, $54, $C1, $DC, $BB, $3C, $23, $43, $C9, $55, $94, $DC, $9C, $BC
	dc.b	$B2, $45, $3D, $0B, $54, $9C, $A2, $1D, $CC, $35, $44, $D2, $42, $20, $CC, $53, $BD, $D1, $5A, $4A, $BB, $54, $D0, $25, $BB, $BC, $C4, $A4, $D4, $49, $3A, $B1
	dc.b	$33, $13, $CD, $3C, $4B, $B4, $4B, $B4, $22, $2B, $2B, $B0, $BC, $C2, $55, $AA, $CA, $54, $AC, $DC, $3B, $AC, $B5, $54, $D4, $04, $C3, $D2, $A2, $2B, $C9, $55
	dc.b	$2C, $BB, $3B, $C9, $A2, $49, $1A, $C4, $54, $D0, $9B, $B2, $D2, $B4, $44, $BB, $52, $BB, $B0, $C2, $A9, $CC, $35, $44, $C9, $94, $D4, $C2, $C9, $C3, $A0, $51
	dc.b	$4B, $33, $A1, $CC, $1B, $4B, $AC, $43, $A4, $C4, $14, $CB, $20, $C2, $9B, $0B, $5B, $C2, $30, $5C, $B4, $C0, $C3, $C0, $24, $1B, $D4, $33, $5C, $3A, $0B, $0B
	dc.b	$CC, $41, $2C, $33, $34, $B4, $B4, $0A, $CD, $C4, $44, $D4, $33, $C0, $15, $01, $AB, $CD, $C5, $3D, $44, $44, $C2, $C4, $19, $BB, $C3, $BB, $C4, $54, $4C, $0D
	dc.b	$3C, $43, $3D, $A3, $4D, $34, $44, $CB, $B5, $E4, $14, $93, $4B, $99, $AB, $44, $C9, $92, $DC, $33, $15, $BB, $34, $BB, $92, $A0, $B1, $2C, $B9, $34, $3C, $4A
	dc.b	$41, $C9, $13, $B9, $0C, $D3, $53, $4D, $44, $4C, $CB, $B9, $4B, $1B, $C4, $4A, $3B, $34, $42, $CC, $CB, $39, $B1, $C2, $B2, $54, $15, $CB, $CA, $DA, $43, $C1
	dc.b	$4B, $B2, $40, $43, $4B, $CB, $DA, $22, $B3, $5C, $C4, $34, $4B, $CB, $BB, $1C, $C1, $34, $30, $34, $B4, $2C, $A1, $3C, $2D, $29, $42, $C4, $2B, $43, $9C, $2A
	dc.b	$3C, $3C, $C4, $4B, $B3, $4C, $41, $93, $2C, $A3, $C2, $D3, $4A, $04, $21, $3A, $A4, $BC, $92, $BC, $B3, $39, $23, $94, $3A, $3A, $2B, $AB, $BC, $2A, $24, $12
	dc.b	$41, $BC, $33, $1B, $BB, $C3, $4A, $93, $2A, $43, $C2, $1C, $A9, $B0, $B3, $33, $00, $33, $0B, $93, $CC, $32, $AC, $33, $32, $4C, $B4, $0C, $4A, $BC, $31, $90
	dc.b	$34, $A3, $C3, $92, $BC, $30, $AA, $BB, $44, $3B, $20, $AA, $21, $B9, $3B, $C0, $B3, $24, $02, $91, $23, $AB, $01, $9C, $2B, $1B, $42, $20, $A4, $C4, $9A, $2B
	dc.b	$D3, $23, $B1, $41, $B4, $21, $12, $BC, $9A, $C1, $31, $B2, $33, $A3, $4B, $3B, $AB, $BB, $A9, $93, $93, $2A, $34, $39, $C2, $2C, $C2, $C3, $32, $22, $B4, $24
	dc.b	$C4, $BB, $1B, $CA, $A9, $A3, $4B, $23, $4A, $4C, $3D, $33, $CB, $1B, $B4, $4A, $B3, $33, $2B, $2B, $B3, $BB, $BA, $33, $A3, $40, $2A, $1B, $A3, $BA, $AB, $BA
	dc.b	$42, $33, $3B, $A2, $2C, $39, $BA, $22, $CB, $24, $A3, $4B, $A3, $B2, $A3, $2C, $A1, $BA, $32, $92, $0B, $09, $24, $21, $BA, $B9, $AB, $22, $33, $A1, $2A, $3C
	dc.b	$4A, $BB, $AB, $13, $3B, $12, $33, $3C, $19, $3A, $2C, $C2, $23, $B2, $02, $33, $99, $14, $CA, $AC, $91, $21, $03, $92, $13, $20, $BC, $C3, $01, $0A, $11, $41
	dc.b	$29, $03, $02, $C9, $AB, $A0, $A3, $93, $33, $2A, $0B, $23, $9C, $CB, $34, $9B, $A4, $42, $1C, $B3, $4C, $1C, $B2, $1C, $49, $04, $49, $9B, $A4, $0C, $1A, $BC
	dc.b	$9A, $32, $44, $21, $2C, $C4, $AC, $12, $0B, $B9, $23, $44, $B3, $BA, $A2, $BB, $23, $BB, $BC, $34, $43, $4B, $BA, $4C, $C9, $2B, $2A, $BB, $B4, $45, $9A, $B2
	dc.b	$3B, $C0, $BB, $90, $AB, $33, $44, $3B, $C3, $31, $CC, $AB, $30, $A3, $22, $42, $B2, $1A, $3A, $CC, $29, $1B, $13, $41, $B4, $B4, $B3, $AC, $9C, $B1, $A9, $34
	dc.b	$42, $9A, $93, $30, $CA, $AB, $BA, $1B, $44, $3B, $2C, $24, $3B, $BA, $BB, $09, $C1, $44, $49, $AC, $15, $CB, $AB, $B3, $2C, $B9, $52, $3A, $AC, $24, $3B, $B2
	dc.b	$BA, $9A, $BA, $42, $2A, $BA, $53, $AB, $BB, $B3, $AB, $A2, $41, $1A, $B3, $21, $B2, $9A, $B1, $2A, $A3, $22, $90, $B3, $49, $C2, $B9, $2B, $B1, $14, $91, $BB
	dc.b	$24, $4A, $C2, $3B, $C2, $3C, $23, $0B, $BB, $15, $4A, $C0, $BA, $32, $BB, $32, $3B, $BC, $35, $3B, $BB, $AB, $3A, $C2, $44, $B0, $CA, $44, $4B, $CC, $B2, $2B
	dc.b	$B0, $44, $3B, $BB, $15, $1C, $A9, $C2, $2C, $B4, $24, $10, $DA, $53, $BA, $2B, $C2, $3B, $B4, $33, $4C, $CA, $42, $B0, $BC, $A2, $4C, $33, $43, $2C, $CA, $43
	dc.b	$BB, $00, $1B, $AA, $04, $23, $0B, $B2, $23, $B1, $1A, $0A, $CA, $33, $40, $AB, $A3, $3A, $BB, $4B, $90, $CB, $44, $32, $9B, $93, $29, $CB, $A2, $A1, $BB, $43
	dc.b	$43, $BB, $A4, $AC, $B2, $A3, $3B, $CC, $44, $32, $AA, $24, $AC, $9A, $B4, $9B, $C2, $44, $3A, $CA, $34, $AC, $BB, $29, $30, $A9, $34, $4C, $B2, $21, $2B, $CB
	dc.b	$A3, $00, $A3, $03, $4C, $B3, $33, $2C, $CB, $02, $AA, $24, $93, $0A, $93, $32, $BA, $BC, $0A, $21, $34, $22, $C0, $34, $BB, $0B, $BA, $AB, $A3, $43, $32, $CB
	dc.b	$43, $9B, $00, $C9, $BA, $B4, $44, $90, $BB, $34, $0C, $AA, $B9, $B9, $13, $42, $3B, $BA, $33, $3C, $AB, $00, $AB, $02, $43, $39, $C3, $32, $BB, $BC, $13, $BB
	dc.b	$34, $33, $2A, $B3, $2B, $BA, $B0, $A1, $AA, $42, $34, $B9, $22, $BB, $BB, $A9, $00, $B3, $43, $13, $BC, $44, $CB, $AB, $A1, $2C, $34, $43, $A0, $CB, $42, $AC
	dc.b	$B1, $90, $C3, $33, $44, $1C, $CA, $33, $1C, $BB, $22, $3B, $34, $23, $2B, $CB, $32, $AB, $CB, $34, $AB, $34, $23, $2B, $CB, $32, $0B, $B0, $A3, $0A, $14, $33
	dc.b	$3C, $C3, $0B, $3B, $AB, $10, $2B, $34, $49, $3C, $C2, $1A, $A3, $BB, $2A, $B1, $44, $32, $0C, $C2, $3A, $B3, $BA, $1B, $90, $44, $32, $9C, $C2, $19, $A3, $A0
	dc.b	$1B, $A1, $24, $33, $BB, $C3, $1A, $9A, $20, $1B, $B3, $33, $34, $BC, $B3, $3B, $AB, $B2, $39, $BB, $23, $44, $9C, $A3, $3B, $BA, $AA, $30, $CA, $34, $33, $2C
	dc.b	$A4, $2B, $CA, $B1, $22, $C0, $43, $33, $AB, $02, $1B, $BB, $AB, $21, $3B, $43, $33, $BB, $22, $9B, $AC, $A9, $22, $A3, $22, $42, $B1, $A3, $AB, $0C, $12, $B0
	dc.b	$02, $23, $33, $BA, $11, $B0, $1C, $A1, $A9, $32, $41, $A3, $B2, $A1, $9B, $9B, $A2, $BB, $44, $29, $22, $B3, $BA, $0B, $2A, $B1, $1B, $14, $A3, $31, $C2, $A0
	dc.b	$3B, $3B, $A3, $BA, $A3, $39, $39, $C0, $3A, $31, $3B, $12, $CA, $B2, $23, $3A, $BA, $42, $2B, $3B, $B0, $BB, $A1, $49, $32, $B2, $33, $B2, $B0, $C9, $0B, $B2
	dc.b	$33, $49, $AA, $34, $AB, $B2, $BA, $BB, $A3, $24, $21, $2C, $24, $1B, $BB, $AB, $0A, $A4, $23, $3A, $09, $92, $23, $CB, $AA, $01, $0A, $42, $39, $B3, $91, $13
	dc.b	$CC, $A3, $B9, $93, $23, $02, $A3, $21, $A1, $BC, $90, $2B, $39, $33, $2B, $32, $10, $BA, $AB, $AB, $2A, $40, $33, $91, $12, $1B, $AB, $A2, $BC, $24, $23, $03
	dc.b	$9B, $12, $19, $BB, $20, $AC, $03, $42, $22, $AB, $01, $12, $A9, $C0, $29, $C4, $42, $2A, $AB, $B3, $31, $9B, $B1, $9B, $A3, $34, $2B, $AA, $29, $3A, $2B, $A9
	dc.b	$B2, $A1, $34, $2B, $9B, $20, $29, $2A, $B9, $B3, $0A, $32, $30, $BB, $03, $B1, $02, $A0, $AA, $39, $29, $32, $0C, $93, $03, $11, $AB, $AC, $33, $02, $13, $BA
	dc.b	$22, $1B, $32, $9B, $BA, $93, $20, $93, $2B, $03, $2B, $22, $BA, $BA, $C3, $40, $32, $99, $29, $11, $B9, $2B, $9B, $B3, $33, $03, $3C, $30, $A1, $9B, $3B, $CB
	dc.b	$02, $34, $20, $A1, $31, $AB, $20, $AC, $0A, $90, $43, $13, $0B, $22, $BB, $92, $AB, $1A, $B0, $43, $39, $1A, $A1, $3B, $C2, $0A, $A1, $11, $24, $2A, $3B, $A2
	dc.b	$0B, $AA, $0A, $B2, $A3, $23, $39, $B3, $9A, $19, $B2, $A0, $B1, $23, $1A, $32, $AA, $01, $AA, $2A, $1B, $00, $10, $30, $13, $B9, $20, $1B, $2A, $B2, $AB, $13
	dc.b	$23, $A3, $A1, $91, $1B, $3A, $BA, $1B, $92, $33, $10, $B3, $A3, $0B, $1B, $1A, $AB, $A4, $23, $10, $B1, $22, $9A, $99, $BA, $90, $B3, $43, $10, $CA, $32, $2B
	dc.b	$A1, $AB, $A0, $21, $34, $09, $BC, $24, $3A, $B0, $AB, $1B, $23, $33, $2A, $C9, $A4, $0A, $1A, $91, $BB, $33, $23, $90, $CB, $33, $2A, $00, $AA, $9B, $22, $4A
	dc.b	$02, $BB, $03, $30, $A1, $AB, $AA, $A3, $32, $92, $0B, $C4, $33, $90, $9B, $B9, $1A, $42, $B1, $BA, $93, $3A, $22, $AB, $09, $A1, $30, $A1, $A9, $23, $20, $22
	dc.b	$BB, $BB, $02, $93, $29, $01, $29, $4B, $00, $0B, $B0, $09, $A2, $3A, $2A, $04, $12, $B9, $1B, $AB, $19, $02, $23, $A2, $A3, $1A, $9B, $39, $9B, $B3, $A1, $23
	dc.b	$0A, $34, $9B, $BB, $3A, $BB, $B2, $30, $23, $A2, $33, $0B, $9B, $92, $BB, $B3, $32, $12, $91, $94, $1B, $2C, $0B, $9A, $B3, $34, $19, $0B, $33, $0A, $BA, $BB
	dc.b	$09, $A2, $34, $3B, $2B, $22, $20, $BB, $BB, $01, $19, $33, $31, $0B, $93, $01, $B9, $BB, $2A, $3A, $14, $20, $1A, $C3, $20, $90, $B9, $B2, $10, $A4, $33, $1B
	dc.b	$CA, $32, $B4, $CB, $9A, $12, $23, $4A, $3C, $9B, $33, $B2, $BA, $BB, $33, $A3, $33, $1C, $B0, $32, $0A, $2B, $BA, $30, $32, $13, $0A, $CA, $33, $A2, $AA, $C2
	dc.b	$A2, $33, $33, $0B, $C1, $39, $13, $BB, $BA, $22, $03, $23, $3B, $CB, $42, $A9, $BA, $1A, $21, $B3, $42, $1B, $BB, $33, $9A, $AA, $1A, $A9, $13, $42, $AA, $BB
	dc.b	$23, $AA, $9A, $10, $B3, $04, $30, $BA, $A3, $A0, $AA, $2A, $A9, $90, $13, $32, $A2, $B1, $0B, $92, $A0, $92, $B2, $02, $32, $1A, $B0, $3B, $B2, $B3, $A1, $00
	dc.b	$23, $21, $91, $B9, $A3, $BA, $A1, $20, $90, $23, $00, $39, $B2, $1B, $B9, $31, $1B, $A2, $23, $A9, $23, $BA, $92, $AB, $22, $90, $A3, $A0, $22, $21, $B9, $1A
	dc.b	$2A, $B1, $12, $91, $1B, $33, $92, $AB, $2B, $20, $B0, $22, $0A, $0A, $33, $1A, $B4, $9B, $9C, $22, $21, $0B, $03, $30, $9A, $A3, $11, $BC, $23, $92, $1B, $10
	dc.b	$33, $A9, $A2, $19, $AA, $A2, $A3, $AA, $93, $23, $9A, $92, $2A, $A1, $BB, $03, $2B, $92, $42, $AC, $39, $20, $AA, $A1, $22, $0B, $90, $32, $2C, $23, $29, $BA
	dc.b	$A9, $22, $2A, $A2, $23, $0B, $21, $B3, $BB, $2A, $09, $31, $99, $33, $9C, $33, $A2, $AB, $AA, $93, $12, $92, $02, $C3, $22, $A2, $BB, $29, $21, $10, $0A, $20
	dc.b	$21, $B3, $91, $BB, $02, $93, $0A, $2A, $22, $93, $A0, $99, $9B, $00, $19, $A3, $29, $19, $23, $90, $A9, $1B, $0A, $90, $A3, $21, $0B, $33, $19, $B9, $21, $AB
	dc.b	$A0, $22, $21, $1C, $42, $99, $A0, $19, $AA, $92, $A2, $12, $2B, $22, $23, $CA, $20, $AB, $01, $20, $12, $1B, $22, $32, $0A, $B0, $AA, $09, $92, $10, $2B, $30
	dc.b	$32, $9B, $A9, $19, $A0, $93, $A3, $9B, $39, $32, $AA, $3C, $A2, $0A, $B4, $A2, $2B, $30, $31, $9B, $0B, $B3, $A3, $B3, $A2, $2B, $3A, $33, $A0, $B2, $CA, $12
	dc.b	$00, $21, $1B, $40, $91, $1A, $B2, $BB, $12, $0A, $23, $00, $23, $A2, $1B, $BA, $9B, $10, $31, $02, $3B, $12, $13, $B9, $B0, $9B, $A0, $23, $2A, $39, $03, $99
	dc.b	$9B, $2A, $19, $0A, $B3, $31, $93, $B3, $A2, $BA, $10, $0A, $1B, $A2, $40, $12, $B3, $9A, $9A, $1A, $1B, $0A, $B3, $33, $22, $A2, $A0, $99, $1B, $1B, $A2, $A1
	dc.b	$33, $22, $BA, $3A, $2B, $1B, $2A, $B2, $1A, $23, $33, $AC, $3A, $29, $B0, $A0, $09, $21, $13, $30, $0B, $12, $AA, $B0, $0A, $A2, $3B, $93, $31, $3B, $A3, $B9
	dc.b	$A2, $B2, $90, $20, $10, $39, $1A, $B2, $A2, $19, $AB, $20, $30, $1A, $22, $1A, $C3, $2A, $3A, $A9, $99, $03, $02, $11, $10, $C3, $2A, $22, $B9, $B0, $23, $A9
	dc.b	$A3, $20, $C3, $30, $2A, $0B, $AB, $32, $93, $2A, $10, $BA, $32, $1A, $9A, $B9, $22, $20, $20, $29, $BA, $31, $90, $A1, $9B, $02, $11, $31, $09, $B3, $90, $22
	dc.b	$AB, $AA, $B1, $32, $32, $A1, $B2, $99, $20, $1B, $1A, $B0, $32, $32, $99, $A2, $BA, $21, $A9, $0A, $B2, $13, $33, $00, $B1, $9B, $92, $A1, $A9, $A3, $B3, $33
	dc.b	$20, $B0, $2C, $01, $1B, $2A, $02, $A2, $33, $10, $BB, $29, $90, $A0, $12, $A0, $91, $34, $A2, $BC, $30, $B0, $B2, $20, $A2, $01, $24, $9A, $BA, $00, $A9, $00
	dc.b	$11, $A1, $22, $93, $20, $B9, $1A, $9A, $A2, $92, $A0, $4B, $01, $12, $9C, $3A, $02, $A9, $11, $11, $22, $9A, $93, $0C, $11, $91, $1A, $A1, $39, $20, $2A, $A2
	dc.b	$2B, $92, $A0, $10, $A9, $22, $01, $91, $90, $21, $B9, $91, $20, $A0, $93, $2A, $90, $1A, $21, $AB, $91, $31, $0B, $22, $09, $02, $9A, $92, $AA, $90, $32, $A1
	dc.b	$91, $29, $A0, $00, $02, $BA, $3A, $23, $B2, $90, $11, $AA, $13, $A0, $B2, $19, $03, $A1, $0A, $A0, $2A, $93, $09, $9A, $2A, $2A, $30, $2A, $0A, $29, $2A, $0A
	dc.b	$1B, $29, $20, $23, $90, $BB, $20, $01, $01, $9A, $23, $A0, $22, $90, $9B, $92, $09, $19, $90, $11, $02, $11, $92, $BA, $A2, $19, $20, $90, $A2, $19, $12, $00
	dc.b	$9A, $B0, $31, $3A, $B9, $92, $20, $00, $22, $9B, $B9, $23, $1A, $A0, $21, $22, $B0, $31, $0B, $BA, $22, $01, $AA, $22, $3B, $A2, $30, $0B, $B0, $02, $2A, $1A
	dc.b	$03, $2A, $A1, $10, $0A, $B2, $92, $19, $20, $90, $21, $09, $91, $90, $BA, $02, $21, $2A, $01, $20, $90, $1A, $29, $AA, $93, $91, $19, $91, $90, $22, $A9, $91
	dc.b	$9A, $00, $11, $00, $92, $00, $3A, $9A, $02, $AA, $10, $A3, $A1, $91, $00, $39, $0A, $91, $A0, $19, $A2, $92, $91, $20, $29, $09, $A9, $29, $19, $A0, $10, $91
	dc.b	$12, $12, $A9, $AA, $29, $19, $92, $01, $A0, $21, $12, $AA, $9A, $01, $10, $1A, $01, $01, $00, $10, $1A, $AA, $03, $1A, $10, $99, $21, $A0, $21, $0A, $90, $93
	dc.b	$0A, $09, $09, $92, $99, $20, $1A, $19, $22, $99, $2A, $99, $92, $90, $11, $1A, $10, $92, $90, $29, $A9, $00, $91, $10, $12, $9A, $92, $91, $00, $A0, $10, $90
	dc.b	$11, $29, $11, $B1, $01, $90, $9A, $10, $19, $A1, $22, $10, $99, $01, $A1, $A9, $12, $1B, $A3, $22, $01, $AA, $01, $A0, $AA, $22, $9A, $10, $32, $01, $BA, $29
	dc.b	$19, $9B, $31, $00, $A1, $22, $20, $9A, $00, $1B, $9A, $21, $0A, $92, $22, $21, $AA, $1A, $1A, $A9, $23, $A9, $09, $23, $A2, $A1, $90, $AA, $90, $93, $A1, $02
	dc.b	$02, $09, $00, $0A, $99, $19, $00, $02, $00, $12, $01, $92, $9A, $AA, $99, $11, $92, $20, $19, $02, $19, $A9, $99, $A1, $12, $00, $20, $1A, $03, $9A, $09, $9B
	dc.b	$92, $20, $00, $31, $A0, $91, $1A, $90, $9A, $A2, $21, $09, $31, $A1, $A1, $10, $90, $A9, $00, $20, $09, $22, $A9, $A0, $20, $A9, $02, $A9, $12, $20, $11, $A0
	dc.b	$A0, $00, $1A, $92, $A0, $A3, $29, $91, $10, $99, $19, $1A, $00, $91, $A2, $3A, $92, $01, $A0, $A1, $11, $91, $0A, $01, $00, $A1, $12, $9A, $9A, $22, $0A, $02
	dc.b	$A0, $20, $21, $91, $1A, $AA, $92, $91, $A1, $A2, $11, $19, $02, $0A, $9B, $12, $20, $90, $90, $02, $02, $00, $0A, $A9, $92, $22, $A9, $90, $12, $09, $91, $1A
	dc.b	$A0, $90, $22, $09, $19, $10, $12, $A2, $0A, $0A, $90, $11, $99, $A1, $20, $2A, $19, $20, $0B, $00, $21, $91, $90, $11, $99, $00, $3A, $99, $A2, $01, $90, $00
	dc.b	$11, $91, $91, $90, $99, $1A, $01, $09, $22, $A1, $19, $29, $92, $99, $1B, $92, $00, $92, $A2, $10, $00, $91, $02, $AB, $20, $10, $91, $92, $1A, $29, $11, $0A
	dc.b	$99, $91, $02, $A0, $12, $1A, $01, $11, $B0, $01, $A9, $01, $90, $21, $20, $09, $11, $AA, $00, $9A, $00, $11, $92, $21, $99, $91, $1A, $00, $10, $A9, $00, $12
	dc.b	$22, $AA, $92, $1B, $01, $19, $A9, $02, $10, $31, $9A, $01, $AA, $00, $2A, $A9, $12, $12, $21, $1A, $A1, $9A, $09, $2A, $9A, $10, $22, $20, $00, $A0, $90, $A0
	dc.b	$11, $A0, $02, $20, $00, $20, $99, $A9, $90, $19, $19, $10, $29, $12, $29, $9A, $A9, $11, $A1, $00, $92, $19, $21, $21, $9B, $A0, $01, $A1, $29, $00, $10, $02
	dc.b	$00, $9A, $A0, $10, $91, $10, $10, $92, $01, $01, $AA, $99, $10, $91, $00, $29, $92, $19, $11, $A9, $90, $1A, $29, $19, $10, $00, $10, $02, $A1, $09, $90, $00
	dc.b	$00, $02, $AA, $20, $10, $90, $10, $A1, $01, $91, $10, $A0, $20, $19, $99, $2A, $A0, $90, $12, $00, $10, $01, $1A, $2A, $20, $B9, $92, $11, $91, $2A, $00, $09
	dc.b	$01, $2A, $9A, $10, $29, $02, $2A, $A9, $01, $92, $99, $1A, $92, $11, $01, $2A, $9A, $12, $90, $90, $1A, $91, $11, $91, $29, $AA, $12, $09, $2A, $19, $99, $21
	dc.b	$11, $A0, $99, $A3, $19, $01, $92, $B0, $02, $00, $20, $AA, $A0, $21, $00, $02, $9A, $93, $19, $00, $0A, $90, $20, $99, $11, $1B, $02, $20, $99, $19, $A1, $21
	dc.b	$A1, $A2, $2A, $B2, $20, $09, $10, $A9, $02, $00, $02, $09, $A1, $29, $A2, $1A, $99, $4B, $9B, $31, $A9, $A3, $A2, $1B, $32, $B2, $B3, $B2, $2B, $3B, $4C, $B4
	dc.b	$9A, $9A, $B5, $B3, $CC, $34, $3C, $C2, $24, $4D, $B3, $52, $DD, $44, $5D, $0D, $45, $C4, $E5, $54, $CE, $46, $CD, $E5, $66, $CF, $53, $6C, $ED, $56, $3D, $E6
	dc.b	$6E, $4F, $7B, $6E, $E5, $B6, $D4, $E6, $34, $EA, $7F, $6F, $7C, $6E, $E4, $46, $D4, $E6, $E6, $E4, $64, $E4, $E6, $25, $ED, $55, $6E, $CD, $6A, $4E, $1D, $72
	dc.b	$F6, $F7, $D6, $E3, $D6, $5C, $ED, $6C, $6E, $2E, $7D, $DA, $E7, $E6, $E4, $E6, $D6, $E6, $E6, $E4, $C6, $CE, $6F, $7E, $6F, $7E, $7F, $5E, $60, $5E, $B5, $63
	dc.b	$F6, $E7, $E6, $F6, $B6, $EC, $D6, $5D, $BE, $65, $6F, $6F, $7D, $4E, $46, $4D, $E5, $16, $E5, $E6, $C6, $F6, $D6, $5F, $6E, $7E, $5E, $6E, $6E, $5C, $06, $5F
	dc.b	$6E, $65, $F6, $E7, $E5, $E6, $D6, $E4, $BD, $7F, $B6, $E7, $F4, $41, $6E, $D5, $54, $BE, $6E, $7F, $C6, $D7, $FC, $54, $6F, $D7, $D5, $ED, $64, $6F, $C6, $C7
	dc.b	$FD, $54, $6F, $D7, $5C, $EE, $65, $6F, $C6, $D7, $FC, $63, $4F, $C7, $2C, $ED, $62, $78, $67, $E7, $86, $65, $3F, $47, $DD, $C3, $6D, $6F, $47, $F7, $F3, $6C
	dc.b	$AF, $57, $DE, $5C, $6E, $7F, $C7, $F7, $FB, $7D, $CF, $47, $ED, $52, $6E, $7F, $D7, $F7, $F9, $7E, $4F, $57, $ED, $6B, $5F, $7F, $07, $F7, $F4, $7E, $3E, $37
	dc.b	$EE, $6C, $4E, $7F, $97, $F7, $F6, $6E, $DB, $07, $F5, $BC, $5C, $78, $76, $F7, $F7, $DD, $C5, $D6, $E6, $E3, $26, $CF, $7E, $5E, $17, $F6, $5B, $F7, $E6, $F7
	dc.b	$E7, $86, $7F, $7F, $7E, $46, $68, $75, $4F, $66, $4B, $88, $E3, $42, $5F, $7C, $CE, $7F, $6F, $7F, $88, $57, $F7, $F7, $F7, $E6, $F7, $F7, $F7, $EB, $78, $72
	dc.b	$45, $2A, $D6, $E5, $D6, $F7, $E6, $F7, $EE, $7F, $7F, $7F, $7F, $7F, $7F, $7E, $6F, $76, $87, $2D, $56, $E2, $43, $E6, $AE, $7D, $EC, $7E, $F7, $F7, $E7, $88
	dc.b	$F6, $E7, $F7, $CE, $F7, $78, $56, $E6, $5E, $5A, $5F, $7E, $57, $FE, $65, $6F, $6D, $C4, $6F, $7E, $6F, $7F, $7D, $5F, $7E, $78, $7C, $14, $6F, $7E, $43, $6F
	dc.b	$6A, $CD, $6E, $7F, $46, $E5, $6F, $6C, $5E, $7F, $6B, $6F, $7F, $7D, $F7, $F7, $D4, $E6, $DC, $5A, $CB, $7F, $6E, $66, $F4, $4E, $65, $E5, $C5, $F7, $F7, $E7
	dc.b	$F7, $F5, $6E, $C5, $E6, $4E, $53, $5E, $6D, $CA, $6E, $5E, $75, $87, $5E, $63, $DC, $54, $E5, $4D, $D7, $F6, $E7, $DF, $66, $E6, $CB, $D5, $5E, $44, $BD, $6D
	dc.b	$4E, $66, $EE, $7F, $6E, $6E, $5B, $6E, $44, $D5, $D5, $E6, $D6, $F7, $E5, $C4, $B5, $E6, $E6, $E5, $C5, $E6, $E6, $E6, $E6, $E6, $D1, $6E, $49, $4C, $3D, $6E
	dc.b	$5E, $6D, $6F, $66, $E6, $F7, $F6, $C6, $E6, $E6, $E6, $E5, $C6, $EE, $7F, $7F, $62, $5E, $6E, $6E, $5A, $5B, $E5, $46, $F5, $6E, $6E, $62, $D5, $E5, $6F, $55
	dc.b	$6E, $D5, $55, $EE, $7E, $5E, $16, $D5, $E5, $6F, $6E, $63, $E5, $37, $FE, $7F, $7F, $56, $D6, $F5, $6E, $6E, $6A, $E6, $D7, $FC, $6E, $7F, $53, $36, $F6, $5E
	dc.b	$6F, $7D, $CB, $D7, $FC, $7F, $7F, $56, $E7, $FA, $6D, $6F, $62, $C5, $E7, $EE, $7F, $7F, $B7, $E6, $F5, $6C, $4E, $95, $D5, $E7, $DF, $7F, $7A, $F7, $E6, $ED
	dc.b	$63, $3B, $E6, $C3, $E6, $6F, $6D, $56, $F6, $A5, $BE, $C6, $C6, $F7, $E5, $E0, $7F, $B6, $D7, $FE, $7D, $6F, $D6, $56, $F5, $55, $DE, $65, $F6, $D6, $6F, $6D
	dc.b	$6C, $ED, $65, $9E, $05, $6B, $E6, $EB, $5E, $7E, $E6, $D6, $DE, $5C, $7F, $0D, $65, $C2, $4F, $7E, $65, $F6, $D6, $DD, $C4, $6D, $DD, $65, $4E, $6F, $64, $D6
	dc.b	$E4, $B5, $34, $E4, $C6, $DD, $A4, $6E, $6E, $D6, $C6, $DE, $41, $63, $EC, $D6, $B5, $EC, $53, $B6, $F6, $5C, $6F, $5C, $65, $BE, $D5, $63, $EC, $D6, $D6, $0E
	dc.b	$5D, $6B, $ED, $64, $6E, $AE, $65, $BC, $E5, $24, $6E, $E5, $C7, $EC, $E4, $61, $5E, $D5, $64, $DE, $4C, $6B, $DD, $B5, $55, $ED, $55, $5E, $D3, $36, $4E, $3E
	dc.b	$65, $BE, $5D, $63, $4E, $45, $4D, $9D, $14, $C5, $1D, $C6, $E5, $CD, $63, $BD, $51, $4D, $3D, $5C, $3C, $5D, $35, $D4, $CC, $55, $DC, $B5, $39, $CD, $5C, $3B
	dc.b	$3C, $33, $23, $D5, $D5, $C5, $E5, $44, $D4, $CC, $5D, $5C, $3D, $6D, $A2, $C5, $C4, $D5, $B5, $D3, $D5, $D4, $C4, $C0, $5D, $5D, $5C, $5D, $2C, $34, $4D, $22
	dc.b	$C4, $1C, $20, $A4, $3D, $4B, $5C, $3D, $24, $4C, $3C, $3B, $1B, $43, $D5, $C4, $D5, $D5, $C4, $CB, $44, $D3, $2D, $5C, $31, $2D, $6D, $4C, $AA, $4B, $C4, $A1
	dc.b	$3A, $C5, $D4, $B4, $B1, $C5, $C4, $D4, $B3, $3B, $0B, $3B, $3B, $4C, $4D, $5C, $3C, $5C, $2C, $2B, $5D, $4B, $A9, $A4, $C5, $C2, $B3, $C4, $D5, $C4, $C0, $34
	dc.b	$C4, $D4, $A3, $2A, $3B, $A2, $AA, $2A, $4B, $C3, $B4, $32, $C0, $2A, $A4, $B1, $0B, $03, $BA, $43, $B1, $C3, $C5, $D4, $C2, $3B, $4A, $1B, $3C, $4C, $4C, $33
	dc.b	$D5, $C4, $3A, $C4, $C4, $D5, $C2, $2A, $30, $C3, $1B, $4D, $5C, $5C, $4D, $4B, $4D, $5C, $03, $A1, $9B, $24, $D5, $CB, $41, $B4, $C3, $C4, $C3, $3C, $4A, $B2
	dc.b	$1A, $5D, $4D, $40, $5D, $4C, $3B, $B4, $C4, $B2, $1A, $C4, $42, $AB, $D5, $C5, $D4, $C4, $C4, $C4, $C3, $B3, $C4, $40, $0C, $C4, $3A, $0C, $4B, $03, $00, $AA
	dc.b	$2B, $B4, $40, $9C, $2C, $4A, $B3, $D5, $B4, $B2, $C4, $C4, $C5, $C3, $CB, $42, $3B, $AB, $2B, $4C, $4C, $4C, $3D, $53, $5D, $BB, $4A, $4D, $4C, $4C, $4C, $4C
	dc.b	$4C, $02, $50, $CB, $C4, $24, $C1, $B4, $B4, $D4, $C4, $CA, $B6, $D2, $D3, $D5, $A4, $C4, $B5, $CC, $B3, $2A, $9B, $6D, $3E, $5C, $53, $0D, $5C, $5C, $1D, $42
	dc.b	$0D, $35, $4B, $D3, $D5, $05, $E6, $D5, $D5, $E6, $D5, $E5, $6C, $DE, $5D, $6A, $3E, $6D, $6E, $2B, $6D, $5E, $C6, $5E, $DC, $56, $DC, $E6, $55, $ED, $D7, $9E
	dc.b	$E5, $73, $EF, $57, $6F, $EE, $77, $DF, $D6, $7E, $FE, $76, $6F, $F6, $75, $FE, $67, $5F, $F5, $75, $EF, $76, $5C, $EE, $55, $4E, $D5, $63, $ED, $56, $DE, $D7
	dc.b	$CD, $E7, $DE, $A5, $7F, $EC, $71, $DF, $76, $9F, $65, $5F, $66, $F5, $56, $CF, $56, $6F, $D5, $7F, $D0, $7E, $D2, $7F, $C6, $7B, $85, $76, $FE, $76, $FE, $76
	dc.b	$EF, $77, $8D, $76, $58, $67, $CF, $57, $4F, $B7, $4F, $E7, $78, $E8, $CD, $F6, $7F, $D7, $5F, $E7, $6E, $F4, $77, $F8, $85, $FE, $57, $EE, $7B, $F4, $75, $FD
	dc.b	$64, $7D, $87, $7F, $3E, $7A, $F7, $4F, $97, $2E, $E6, $C6, $78, $C8, $FC, $E6, $6F, $66, $FE, $76, $EE, $6D, $36, $78, $C8, $FE, $54, $6F, $7B, $FE, $75, $F6
	dc.b	$6E, $46, $68, $58, $FF, $74, $5F, $74, $FE, $8F, $F7, $9F, $67, $08, $77, $87, $66, $FD, $7E, $F6, $7E, $C6, $BF, $76, $48, $67, $F5, $7F, $5D, $7E, $F6, $7E
	dc.b	$E6, $DE, $7D, $6F, $F8, $C8, $8D, $F7, $69, $FE, $76, $F5, $AE, $65, $6C, $87, $78, $76, $E6, $47, $86, $C7, $DF, $C7, $C5, $E7, $8D, $8E, $F8, $FA, $57, $E8
	dc.b	$76, $6F, $EC, $75, $5F, $7F, $F8, $48, $76, $F7, $6E, $F6, $75, $FE, $35, $66, $FC, $7E, $F7, $68, $77, $F6, $5F, $C6, $7D, $FD, $7C, $44, $F6, $78, $68, $8B
	dc.b	$7F, $67, $EF, $07, $D5, $EE, $47, $DE, $E8, $F8, $86, $87, $6F, $74, $2F, $66, $F7, $3F, $67, $FD, $6C, $7F, $F7, $58, $81, $F7, $CE, $E7, $4F, $7D, $F6, $7F
	dc.b	$46, $E5, $78, $B8, $FF, $8F, $E7, $E9, $E7, $CE, $7E, $F7, $5F, $46, $CA, $78, $C8, $FE, $7F, $57, $E5, $F7, $4F, $7B, $F7, $6F, $BC, $6E, $74, $86, $7F, $66
	dc.b	$F7, $C7, $FF, $8F, $F7, $BF, $76, $FD, $7E, $D6, $7F, $88, $58, $8E, $D7, $0C, $87, $7F, $E7, $9E, $7D, $F6, $7F, $5E, $37, $FE, $8F, $F7, $E7, $F6, $5F, $75
	dc.b	$FE, $75, $E6, $EE, $71, $EB, $C4, $67, $8B, $88, $57, $E6, $F7, $EF, $76, $DF, $7C, $E7, $FE, $76, $FB, $6E, $67, $D8, $77, $86, $64, $6F, $7F, $E7, $7F, $E6
	dc.b	$6D, $5E, $E6, $6E, $DD, $56, $24, $C8, $86, $87, $C6, $6F, $7F, $D7, $6E, $F6, $6E, $6F, $B7, $5F, $C4, $64, $5F, $73, $87, $7F, $34, $7C, $F7, $FC, $76, $FF
	dc.b	$76, $5E, $F6, $66, $DF, $D7, $6E, $F4, $7E, $F8, $D8, $74, $7E, $E6, $E5, $47, $FE, $66, $ED, $D6, $D6, $4F, $C7, $5E, $ED, $77, $8C, $8F, $FD, $77, $F0, $05
	dc.b	$E7, $BF, $D6, $7D, $FD, $66, $5E, $EC, $66, $ED, $D5, $7F, $E8, $FE, $F7, $7F, $5E, $7E, $D7, $BF, $56, $5F, $D6, $6D, $5E, $43, $5E, $06, $E4, $78, $58, $FE
	dc.b	$E5, $7E, $D5, $6C, $E6, $EC, $C6, $6E, $E6, $6D, $DD, $D6, $5C, $E4, $A4, $47, $82, $8F, $CF, $57, $EC, $D7, $CE, $64, $CF, $66, $0C, $E6, $54, $EB, $0B, $6D
	dc.b	$BD, $53, $4D, $6E, $F7, $5E, $DE, $7C, $4D, $B6, $D5, $E6, $EB, $64, $3E, $33, $6D, $E6, $E6, $AC, $4D, $D6, $CD, $5B, $6F, $47, $DE, $E6, $61, $ED, $6D, $5B
	dc.b	$5D, $E6, $55, $ED, $54, $2C, $D5, $2D, $5D, $5D, $45, $E5, $43, $E5, $6A, $F5, $65, $EE, $65, $5E, $9A, $5B, $C5, $D4, $CC, $6D, $32, $D4, $3B, $34, $CD, $45
	dc.b	$CC, $92, $4B, $C2, $30, $4B, $C4, $C5, $DB, $4A, $4D, $5B, $C4, $C5, $9D, $4B, $4C, $C5, $2C, $C4, $4D, $34, $2C, $C4, $4C, $B1, $43, $CA, $A5, $D4, $4E, $54
	dc.b	$4C, $D5, $A4, $CC, $5B, $BC, $44, $D3, $34, $D3, $32, $4D, $24, $B2, $C4, $3C, $13, $BB, $4A, $B4, $A9, $B2, $4B, $BB, $43, $C0, $2B, $4C, $20, $03, $B9, $32
	dc.b	$C3, $20, $AB, $4A, $A1, $A2, $1A, $92, $C4, $0C, $4A, $3B, $92, $93, $B9, $3B, $03, $A9, $A3, $3C, $13, $9A, $21, $A1, $0A, $00, $2A, $2A, $21, $90, $B4, $9C
	dc.b	$22, $29, $A0, $21, $B3, $A2, $A1, $1A, $2A, $2A, $A3, $91, $A9, $3B, $20, $A2, $A0, $3B, $02, $A2, $00, $0A, $2A, $21, $A1, $0A, $20, $B3, $0A, $02, $1B, $13
	dc.b	$AA, $20, $1A, $A3, $A9, $2A, $2A, $93, $9A, $2A, $2A, $93, $9A, $20, $A2, $00, $00, $A2, $A0, $2A, $20, $A2, $A2, $A2, $0A, $2A, $2A, $20, $A2, $00, $A0, $2A
	dc.b	$20, $0A, $20, $A2, $1A, $10, $A2, $0A, $2A, $20, $A0, $00, $20, $A2, $00, $A2, $0A, $2A, $00, $02, $A2, $A2, $A0, $2A, $2A, $02, $A2, $0A, $2A, $02, $A2, $0A
	dc.b	$2A, $20, $A2, $0A, $00, $2A, $02, $A0, $2A, $02, $A0, $02, $A0, $2A, $00, $2A, $2A, $20, $A2, $A2, $A0, $2A, $02, $A0, $02, $A0, $02, $A2, $A0, $2A, $2A, $02
	dc.b	$A0, $02, $A2, $A0, $2A, $00, $2A, $00, $02, $A2, $A0, $00, $00, $00, $00, $00, $02, $A2, $0A, $2A, $02, $A2, $A0, $02, $A2, $A0, $2A, $02, $A2, $A0, $00, $00
	dc.b	$02, $A0, $2A, $20, $0B, $32, $B0, $20, $B2, $4D, $42, $A9, $3A, $B3, $2B, $03, $B3, $B1, $2A, $2B, $3A, $2A, $02, $A2, $A2, $A2, $1B, $12, $0A, $2A, $20, $00
	dc.b	$A2, $A2, $00, $A0, $2A, $00, $2A, $02, $0A, $00, $02, $A0, $2A, $02, $A2, $A2, $0A, $00, $20, $A9, $21, $A9, $12, $00, $A0, $20, $A9, $13, $BA, $22, $0A, $A2
	dc.b	$2A, $90, $30, $B0, $12, $A9, $12, $0A, $93, $A1, $A0, $20, $A9, $30, $A9, $02, $1B, $12, $1A, $A3, $A1, $A2, $0A, $03, $B0, $20, $00, $A2, $0A, $92, $2B, $29
	dc.b	$21, $A9, $20, $0A, $02, $0A, $02, $0A, $00, $20, $A0, $02, $A0, $2A, $2A, $02, $A0, $02, $A0, $2A, $2A, $00, $02, $0A, $00, $2A, $02, $A2, $A0, $2A, $00, $2A
	dc.b	$2A, $20, $A0, $20, $0A, $02, $0A, $02, $00, $A0, $2A, $2A, $02, $A0, $02, $A0, $00, $00, $00, $20, $A0, $20, $A0, $20, $A0, $20, $A0, $2A, $02, $A2, $A0, $00
	dc.b	$00, $02, $A2, $A2, $A2, $A0, $2A, $02, $A0, $2A, $02, $A0, $02, $A0, $02, $0A, $2A, $02, $A2, $A0, $2A, $02, $0A, $00, $00, $2A, $02, $A2, $A0, $20, $A0, $2A
	dc.b	$2A, $2A, $02, $A0, $02, $A2, $A0, $2A, $2A, $2A, $02, $A2, $A0, $00, $20, $A0, $2A, $02, $A0, $00, $02, $A2, $A0, $2A, $2A, $02, $A2, $A0, $02, $A2, $0A, $2A
	dc.b	$02, $A0, $2A, $02, $A0, $2A, $20, $A0, $2A, $02, $A0, $2A, $2A, $20, $5E, $C6, $06, $02, $01, $00, $85, $C5, $00, $02, $2A, $C0, $F4, $14, $06, $C2, $F4, $14
	dc.b	$34, $C3, $F4, $18, $B1, $C3, $F4, $18, $8B, $C4, $F4, $18, $6D, $C5, $E8, $03, $00, $00, $6F, $C5, $E8, $05, $00, $00, $EA, $40, $01, $E6, $F8, $43, $C0, $EF
	dc.b	$00, $F0, $18, $01, $04, $08, $F8, $4B, $C0, $EF, $04, $F8, $C8, $C1, $F6, $31, $C0, $80, $60, $F7, $00, $12, $43, $C0, $F9, $80, $0C, $AE, $0C, $B1, $0A, $B5
	dc.b	$1A, $BA, $18, $BC, $0C, $BB, $03, $E7, $BC, $E7, $BD, $12, $BC, $0A, $BA, $1A, $0C, $C1, $BF, $BB, $03, $E7, $BC, $E7, $BD, $12, $BF, $0C, $BD, $18, $BC, $0C
	dc.b	$BD, $BF, $BF, $02, $E7, $C0, $C1, $14, $BD, $0C, $B8, $24, $BA, $0C, $BC, $BA, $02, $E7, $BB, $BC, $14, $BD, $0C, $BF, $18, $BD, $BC, $0C, $B6, $02, $E7, $B7
	dc.b	$B8, $14, $B3, $0C, $B8, $18, $BF, $0C, $BA, $BC, $B5, $B8, $BA, $BC, $BA, $BC, $BD, $BF, $C0, $03, $E7, $C1, $E7, $C3, $5A, $B8, $02, $E7, $B9, $E7, $BA, $08
	dc.b	$BD, $0C, $BF, $03, $E7, $C0, $E7, $C1, $12, $BF, $0C, $BC, $18, $BD, $0C, $B8, $02, $E7, $B9, $E7, $BA, $08, $BD, $0C, $C0, $02, $E7, $C1, $E7, $C2, $14, $C1
	dc.b	$0C, $BB, $03, $E7, $BC, $E7, $BD, $1E, $0C, $C1, $C6, $18, $C4, $0C, $C1, $BD, $C1, $C4, $18, $C1, $0C, $BD, $18, $BC, $0C, $BD, $BA, $E7, $0C, $B5, $B3, $AE
	dc.b	$B3, $B5, $B8, $BA, $B4, $03, $E7, $B5, $E7, $B7, $12, $B3, $0C, $B8, $18, $B7, $0C, $B8, $BA, $BB, $03, $E7, $BC, $E7, $BD, $5A, $E7, $0C, $BC, $BF, $BD, $C1
	dc.b	$BF, $BD, $BC, $AE, $B5, $B1, $B8, $B5, $BA, $B8, $BB, $03, $E7, $BC, $E7, $BD, $42, $BC, $0C, $BA, $BC, $BF, $03, $E7, $C0, $E7, $C1, $12, $BF, $0C, $BD, $BF
	dc.b	$BC, $BD, $BF, $BF, $03, $E7, $C0, $E7, $C1, $12, $BD, $0C, $B8, $18, $0C, $BA, $BC, $BC, $BD, $BF, $B8, $B8, $BC, $BF, $BC, $BD, $BF, $C1, $BF, $BD, $BF, $BC
	dc.b	$BD, $BD, $03, $E7, $BE, $E7, $BF, $12, $BC, $0C, $BD, $18, $BA, $0C, $B8, $BA, $C0, $03, $E7, $C1, $E7, $B7, $1E, $B8, $0C, $BA, $BC, $BA, $BD, $BF, $03, $E7
	dc.b	$C0, $E7, $C1, $12, $BD, $0C, $BA, $18, $B5, $0C, $B8, $BC, $BB, $03, $E7, $BC, $E7, $BD, $12, $BC, $0C, $BA, $18, $B6, $0C, $BA, $BC, $BF, $03, $E7, $C0, $E7
	dc.b	$C1, $12, $BD, $0C, $BA, $18, $BC, $0C, $BD, $C1, $C2, $03, $E7, $C3, $E7, $C4, $42, $BC, $0C, $BD, $B6, $B3, $B6, $BA, $B8, $B5, $B3, $B0, $B7, $B5, $B3, $B0
	dc.b	$B0, $AC, $B0, $B3, $B8, $BC, $BD, $C1, $C4, $C1, $BD, $BC, $B6, $02, $E7, $B7, $E7, $B8, $44, $80, $18, $F9, $80, $60, $80, $3C, $BD, $0C, $BC, $BA, $80, $60
	dc.b	$80, $3C, $BC, $0C, $BA, $B8, $80, $60, $80, $80, $60, $80, $0C, $B6, $B1, $B6, $B8, $BA, $BC, $BD, $80, $60, $80, $80, $80, $3C, $0C, $BC, $BA, $80, $60, $80
	dc.b	$B1, $0C, $AE, $AA, $AE, $B1, $B3, $B5, $B3, $B3, $B1, $B3, $B5, $B8, $B5, $B8, $BA, $80, $60, $F9, $EF, $01, $F8, $38, $C2, $96, $96, $18, $0C, $18, $0C, $0C
	dc.b	$80, $60, $EF, $01, $F8, $BA, $C2, $99, $80, $54, $F8, $BA, $C2, $99, $80, $18, $9D, $0C, $A0, $A2, $9B, $98, $EF, $01, $F8, $38, $C2, $A0, $A0, $A0, $A0, $A0
	dc.b	$A0, $A0, $A0, $F6, $14, $C2, $96, $0C, $0C, $99, $96, $96, $96, $99, $96, $96, $96, $99, $96, $9B, $96, $99, $96, $96, $96, $99, $96, $96, $96, $99, $96, $96
	dc.b	$96, $99, $9B, $9D, $96, $99, $9B, $94, $94, $98, $94, $94, $94, $98, $94, $94, $94, $98, $94, $9B, $94, $99, $98, $92, $92, $96, $92, $92, $92, $96, $98, $94
	dc.b	$94, $98, $99, $9B, $99, $98, $94, $96, $96, $99, $96, $96, $96, $99, $96, $96, $96, $99, $96, $96, $96, $99, $9B, $96, $96, $99, $96, $96, $96, $99, $96, $96
	dc.b	$96, $99, $9B, $9D, $9B, $99, $96, $94, $94, $98, $94, $94, $94, $98, $94, $94, $94, $98, $94, $99, $94, $98, $94, $92, $92, $92, $92, $92, $92, $92, $92, $94
	dc.b	$94, $94, $94, $94, $94, $94, $94, $F9, $96, $0C, $0C, $0C, $0C, $0C, $0C, $94, $94, $92, $92, $92, $92, $92, $92, $92, $92, $96, $96, $96, $96, $96, $96, $96
	dc.b	$96, $99, $99, $99, $99, $99, $99, $99, $99, $9D, $9D, $9D, $9D, $9D, $9D, $9D, $9D, $94, $94, $94, $94, $94, $94, $94, $94, $99, $99, $99, $99, $99, $99, $99
	dc.b	$99, $98, $98, $98, $98, $98, $98, $98, $98, $96, $96, $96, $96, $96, $96, $94, $94, $92, $92, $92, $92, $92, $92, $92, $92, $96, $96, $96, $96, $96, $96, $96
	dc.b	$96, $99, $99, $99, $99, $99, $99, $99, $99, $9B, $9B, $9B, $9B, $94, $94, $94, $94, $98, $98, $98, $98, $94, $94, $94, $94, $99, $99, $99, $99, $99, $99, $99
	dc.b	$99, $F9, $EF, $02, $F0, $10, $01, $04, $06, $F8, $78, $C3, $E6, $FC, $B5, $0C, $18, $0C, $18, $0C, $18, $80, $54, $E6, $0C, $FB, $F4, $EF, $02, $F4, $00, $F8
	dc.b	$93, $C3, $B8, $0C, $80, $48, $B8, $0C, $F8, $93, $C3, $BD, $48, $BC, $18, $FB, $0C, $EF, $02, $F8, $78, $C3, $E6, $FC, $BC, $0C, $0C, $0C, $0C, $0C, $0C, $0C
	dc.b	$0C, $E6, $0C, $F6, $4B, $C3, $E6, $F8, $B5, $60, $B6, $B8, $B5, $B3, $48, $B1, $18, $B3, $30, $B5, $18, $B3, $B1, $48, $18, $B3, $60, $F7, $00, $02, $7A, $C3
	dc.b	$F9, $B5, $48, $B3, $18, $B1, $60, $B5, $B5, $B5, $B3, $B5, $B7, $B5, $48, $B3, $18, $AE, $60, $B5, $B5, $B6, $30, $B3, $B7, $B3, $B5, $48, $80, $18, $F9, $EF
	dc.b	$02, $F0, $10, $01, $04, $06, $F8, $EF, $C3, $E6, $FC, $AE, $0C, $18, $0C, $18, $0C, $18, $80, $54, $E6, $0C, $EF, $02, $F4, $00, $F8, $09, $C4, $B1, $80, $48
	dc.b	$AC, $0C, $F8, $09, $C4, $B5, $48, $18, $EF, $02, $F8, $EF, $C3, $E6, $FC, $B3, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $E6, $0C, $F6, $C8, $C3, $E6, $F8, $AE
	dc.b	$60, $60, $60, $60, $AC, $48, $AA, $18, $AC, $30, $18, $18, $AA, $48, $18, $AC, $60, $F7, $00, $02, $F1, $C3, $F9, $AE, $18, $A2, $0C, $0C, $0C, $0C, $18, $AA
	dc.b	$A5, $0C, $0C, $0C, $0C, $0C, $0C, $AE, $18, $A9, $0C, $0C, $0C, $0C, $0C, $0C, $AC, $18, $0C, $0C, $0C, $0C, $0C, $0C, $18, $A4, $0C, $0C, $0C, $0C, $0C, $0C
	dc.b	$AC, $18, $A7, $0C, $0C, $0C, $0C, $0C, $0C, $AC, $18, $0C, $0C, $0C, $0C, $0C, $0C, $AE, $18, $AB, $0C, $0C, $0C, $0C, $0C, $0C, $AE, $18, $A9, $0C, $0C, $0C
	dc.b	$0C, $A9, $18, $AA, $A5, $0C, $0C, $0C, $0C, $0C, $0C, $AE, $18, $A9, $0C, $0C, $0C, $0C, $0C, $0C, $AC, $18, $0C, $0C, $0C, $0C, $0C, $0C, $AE, $18, $A0, $0C
	dc.b	$0C, $AC, $18, $A7, $0C, $0C, $B0, $18, $AB, $0C, $0C, $AC, $18, $A7, $0C, $0C, $AC, $18, $0C, $0C, $0C, $0C, $0C, $0C, $F9, $EF, $02, $F0, $10, $01, $04, $06
	dc.b	$F8, $CD, $C4, $E6, $FC, $B1, $0C, $18, $0C, $18, $0C, $18, $80, $54, $E6, $0C, $FB, $0C, $EF, $02, $F4, $00, $F8, $E7, $C4, $B5, $80, $48, $A5, $0C, $F8, $E7
	dc.b	$C4, $B8, $48, $18, $FB, $F4, $EF, $02, $F8, $CD, $C4, $E6, $FC, $B8, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $E6, $0C, $F6, $A2, $C4, $E6, $F8, $B1, $60, $60
	dc.b	$B3, $B1, $B0, $48, $AE, $18, $B0, $30, $18, $18, $AE, $48, $18, $B0, $60, $F7, $00, $02, $CF, $C4, $F9, $B1, $18, $A9, $0C, $0C, $0C, $0C, $18, $AE, $9E, $0C
	dc.b	$0C, $0C, $0C, $0C, $0C, $B1, $18, $A2, $0C, $0C, $0C, $0C, $0C, $0C, $B1, $18, $A5, $0C, $0C, $0C, $0C, $0C, $0C, $B0, $18, $9D, $0C, $0C, $0C, $0C, $0C, $0C
	dc.b	$B0, $18, $A0, $0C, $0C, $0C, $0C, $0C, $0C, $B1, $18, $A5, $0C, $0C, $0C, $0C, $0C, $0C, $B3, $18, $A4, $0C, $0C, $0C, $0C, $0C, $0C, $B1, $18, $A2, $0C, $0C
	dc.b	$0C, $0C, $18, $B1, $9E, $0C, $0C, $0C, $0C, $0C, $0C, $B1, $18, $A2, $0C, $0C, $0C, $0C, $0C, $0C, $B1, $18, $A5, $0C, $0C, $0C, $0C, $0C, $0C, $B3, $18, $9B
	dc.b	$0C, $0C, $B0, $18, $A0, $0C, $0C, $B3, $18, $A4, $0C, $0C, $B0, $18, $A0, $0C, $0C, $B1, $18, $A5, $0C, $0C, $0C, $0C, $0C, $0C, $F9, $80, $06, $F8, $43, $C0
	dc.b	$F0, $18, $02, $01, $08, $F8, $4B, $C0, $F0, $08, $01, $01, $04, $F8, $C8, $C1, $F6, $72, $C5, $85, $0C, $85, $84, $89, $F7, $00, $20, $85, $C5, $84, $85, $85
	dc.b	$84, $85, $85, $84, $85, $84, $8E, $8A, $8F, $81, $06, $81, $82, $83, $84, $0C, $85, $85, $0C, $8E, $06, $8F, $84, $0C, $85, $8F, $06, $8E, $85, $0C, $84, $8E
	dc.b	$06, $8F, $F7, $00, $07, $A3, $C5, $85, $0C, $85, $84, $8A, $85, $84, $84, $84, $85, $0C, $8E, $06, $8F, $84, $0C, $85, $8F, $06, $8E, $85, $0C, $84, $8E, $06
	dc.b	$8F, $F7, $00, $04, $C2, $C5, $85, $0C, $8E, $84, $84, $8F, $85, $84, $89, $85, $0C, $8E, $84, $84, $8F, $85, $84, $89, $85, $0C, $8E, $84, $8A, $8F, $85, $84
	dc.b	$84, $84, $85, $84, $85, $81, $06, $81, $82, $0C, $84, $85, $85, $0C, $8F, $84, $85, $8E, $85, $84, $8F, $F7, $00, $0C, $FE, $C5, $85, $0C, $8E, $84, $84, $8F
	dc.b	$85, $84, $89, $85, $0C, $8E, $84, $84, $8F, $85, $84, $89, $85, $0C, $8E, $84, $8A, $8F, $85, $84, $84, $85, $85, $84, $84, $85, $84, $84, $84, $85, $0C, $85
	dc.b	$84, $8A, $F7, $00, $0E, $2F, $C6, $84, $84, $84, $84, $81, $06, $82, $83, $85, $84, $0C, $85, $85, $0C, $85, $84, $8A, $F7, $00, $10, $45, $C6, $84, $84, $84
	dc.b	$84, $81, $06, $82, $83, $85, $84, $0C, $85, $F6, $A3, $C5, $2C, $74, $74, $34, $34, $1F, $12, $1F, $1F, $00, $00, $00, $00, $00, $01, $00, $01, $0F, $3F, $0F
	dc.b	$3F, $16, $80, $17, $80, $42, $CA, $88, $6E, $44, $1D, $1A, $1D, $1C, $0F, $0C, $0A, $0A, $08, $04, $06, $06, $9F, $6F, $6F, $4F, $20, $18, $22, $80, $53, $BC
	dc.b	$E8, $66, $64, $9F, $9F, $1F, $1F, $15, $12, $11, $08, $07, $03, $05, $05, $6F, $4F, $4F, $4F, $16, $0C, $10, $80, $10, $04, $02, $08, $04, $1F, $1F, $1F, $1F
	dc.b	$10, $0F, $09, $08, $07, $00, $00, $00, $3F, $0F, $0F, $4F, $20, $20, $20, $80, $35, $55, $43, $47, $02, $19, $1F, $15, $1F, $0C, $07, $0C, $07, $1F, $00, $00
	dc.b	$00, $1F, $34, $37, $34, $10, $80, $80, $80, $C3, $C9, $06, $03, $01, $00, $7E, $C9, $00, $00, $0B, $C7, $0C, $14, $B7, $C7, $00, $14, $6B, $C8, $E8, $14, $CA
	dc.b	$C8, $F4, $14, $21, $C9, $00, $14, $69, $C8, $E8, $06, $00, $02, $C8, $C8, $E8, $06, $00, $02, $1F, $C9, $E8, $06, $00, $02, $EA, $00, $01, $E6, $EF, $00, $F0
	dc.b	$12, $01, $08, $06, $A2, $0C, $A4, $A7, $A9, $A2, $A4, $A7, $A9, $A0, $A2, $A7, $A9, $A0, $A2, $A7, $A9, $A0, $A2, $A5, $A7, $A0, $A2, $A5, $A7, $A0, $A2, $A6
	dc.b	$A7, $A0, $A2, $A6, $A7, $A0, $06, $9B, $A0, $A4, $A7, $18, $A0, $06, $9B, $A0, $A4, $A7, $18, $A0, $06, $9D, $A0, $A5, $A9, $18, $A0, $06, $9D, $A0, $A5, $A9
	dc.b	$18, $9D, $24, $A0, $A4, $18, $A9, $24, $A7, $3C, $EF, $04, $F0, $08, $01, $04, $04, $A7, $0C, $A9, $AC, $AE, $A7, $A9, $AC, $AE, $A6, $A9, $AC, $AE, $A6, $A9
	dc.b	$AC, $AE, $A2, $A5, $A9, $AA, $A2, $A5, $A9, $AA, $A0, $A4, $A7, $A9, $A0, $A4, $A7, $A9, $F0, $0C, $01, $04, $0C, $A3, $06, $A0, $A3, $A7, $AA, $18, $A3, $06
	dc.b	$A0, $A3, $A7, $AA, $18, $A4, $06, $A0, $A4, $A7, $A9, $18, $A4, $06, $A0, $A4, $A7, $A9, $18, $F0, $18, $01, $04, $08, $AE, $24, $18, $B0, $0C, $AE, $18, $A9
	dc.b	$30, $AE, $F6, $0F, $C7, $EF, $01, $9D, $0C, $0C, $80, $24, $98, $06, $06, $9D, $9D, $98, $0C, $9D, $9D, $80, $24, $9D, $06, $06, $98, $98, $9D, $0C, $99, $99
	dc.b	$80, $24, $94, $06, $06, $99, $99, $94, $0C, $9A, $9A, $80, $24, $94, $06, $06, $9D, $0C, $9A, $94, $94, $80, $24, $A0, $06, $06, $9B, $9B, $A0, $0C, $99, $99
	dc.b	$80, $30, $99, $06, $06, $94, $0C, $9D, $9D, $80, $24, $94, $06, $06, $98, $9B, $9D, $0C, $94, $94, $18, $96, $94, $06, $06, $98, $98, $9B, $0C, $EF, $01, $96
	dc.b	$0C, $96, $80, $24, $91, $06, $06, $9D, $9D, $96, $0C, $0C, $0C, $80, $24, $96, $06, $06, $9D, $9A, $96, $0C, $0C, $0C, $80, $24, $9E, $06, $A0, $9E, $99, $96
	dc.b	$0C, $9D, $9D, $80, $24, $9B, $06, $06, $98, $0C, $94, $97, $97, $80, $24, $97, $06, $06, $9B, $9B, $9C, $0C, $9D, $9D, $80, $24, $9D, $06, $06, $98, $98, $94
	dc.b	$0C, $96, $96, $80, $24, $96, $06, $06, $9D, $0C, $9A, $96, $96, $18, $06, $06, $0C, $18, $06, $06, $F6, $B7, $C7, $E1, $02, $EF, $02, $E0, $80, $BA, $0C, $0C
	dc.b	$80, $48, $B8, $0C, $0C, $80, $48, $B8, $0C, $0C, $80, $48, $B8, $0C, $0C, $80, $48, $BC, $0C, $0C, $80, $48, $B8, $0C, $0C, $80, $48, $B9, $0C, $0C, $80, $48
	dc.b	$BC, $0C, $18, $B8, $3C, $EF, $02, $E4, $01, $01, $00, $02, $01, $BF, $0C, $0C, $80, $48, $BE, $0C, $0C, $80, $48, $BA, $0C, $0C, $80, $48, $BF, $0C, $0C, $80
	dc.b	$48, $BB, $0C, $0C, $80, $48, $BC, $0C, $0C, $80, $48, $BE, $0C, $0C, $80, $48, $BF, $30, $BE, $F6, $6B, $C8, $E1, $02, $EF, $02, $B5, $0C, $0C, $80, $48, $B5
	dc.b	$0C, $0C, $80, $48, $B5, $0C, $0C, $80, $48, $B5, $0C, $0C, $80, $48, $B8, $0C, $0C, $80, $48, $B5, $0C, $0C, $80, $48, $B5, $0C, $0C, $80, $48, $B8, $0C, $18
	dc.b	$B3, $3C, $EF, $02, $BA, $0C, $0C, $80, $48, $BA, $0C, $0C, $80, $48, $B6, $0C, $0C, $80, $48, $B8, $0C, $0C, $80, $48, $B6, $0C, $0C, $80, $48, $B9, $0C, $0C
	dc.b	$80, $48, $BA, $0C, $0C, $80, $48, $BA, $30, $30, $F6, $CA, $C8, $E1, $02, $EF, $02, $E0, $40, $B0, $0C, $0C, $80, $48, $B0, $0C, $0C, $80, $48, $B1, $0C, $0C
	dc.b	$80, $48, $B2, $0C, $0C, $80, $48, $B3, $0C, $0C, $80, $48, $B1, $0C, $0C, $80, $48, $B0, $0C, $0C, $80, $48, $B3, $0C, $18, $AE, $3C, $EF, $02, $E4, $02, $01
	dc.b	$00, $02, $01, $B5, $0C, $0C, $80, $48, $B5, $0C, $0C, $80, $48, $B1, $0C, $0C, $80, $48, $B5, $0C, $0C, $80, $48, $B3, $0C, $0C, $80, $48, $B5, $0C, $0C, $80
	dc.b	$48, $B5, $0C, $0C, $80, $48, $B5, $30, $30, $F6, $21, $C9, $85, $0C, $85, $8F, $8E, $8F, $85, $84, $8E, $F7, $00, $06, $7E, $C9, $85, $85, $84, $85, $8A, $85
	dc.b	$84, $8A, $84, $85, $84, $85, $8A, $85, $84, $84, $85, $0C, $85, $8F, $8F, $8F, $85, $84, $8E, $F7, $00, $06, $9C, $C9, $85, $85, $84, $85, $8A, $85, $84, $8A
	dc.b	$81, $06, $82, $84, $0C, $82, $06, $83, $84, $0C, $85, $84, $84, $84, $F6, $7E, $C9, $34, $32, $34, $42, $84, $1F, $1E, $19, $18, $02, $02, $02, $06, $04, $04
	dc.b	$04, $04, $4F, $5F, $4F, $2F, $20, $8C, $24, $80, $12, $61, $69, $62, $64, $DE, $DC, $5E, $5C, $0B, $0C, $08, $06, $09, $0C, $08, $07, $1F, $5F, $1F, $0F, $1C
	dc.b	$22, $1D, $80, $64, $18, $54, $74, $34, $1D, $1C, $1E, $9F, $0A, $05, $06, $08, $00, $00, $00, $00, $3B, $5B, $09, $49, $0E, $84, $10, $80, $B2, $5A, $5F, $74
	dc.b	$34, $D6, $DC, $DE, $9F, $1A, $10, $09, $08, $00, $00, $00, $00, $38, $58, $08, $48, $18, $14, $27, $80, $35, $42, $82, $44, $51, $19, $1F, $15, $0F, $0C, $09
	dc.b	$10, $06, $10, $04, $05, $00, $1F, $3F, $3F, $3F, $26, $80, $80, $80, $47, $CE, $06, $02, $01, $00, $D3, $CD, $00, $00, $6A, $CA, $00, $14, $11, $CB, $F4, $14
	dc.b	$9F, $CB, $E8, $18, $EF, $CB, $F4, $18, $3A, $CC, $00, $18, $89, $CC, $E8, $05, $00, $05, $2D, $CD, $E8, $05, $00, $05, $EA, $84, $00, $E6, $80, $60, $EF, $00
	dc.b	$F0, $14, $01, $04, $06, $E4, $02, $00, $00, $03, $01, $AE, $08, $B3, $B5, $B8, $48, $E7, $30, $B7, $18, $B5, $10, $B3, $08, $B5, $60, $E7, $60, $AE, $08, $B3
	dc.b	$B5, $B8, $48, $E7, $30, $B7, $10, $BA, $08, $B8, $10, $B5, $08, $BC, $60, $80, $60, $BA, $08, $BC, $BA, $B5, $48, $80, $40, $B7, $08, $B8, $10, $BA, $08, $B7
	dc.b	$28, $B3, $38, $E7, $60, $BA, $08, $BC, $BA, $B5, $48, $80, $30, $B7, $18, $B8, $10, $BA, $08, $BD, $28, $BC, $38, $E7, $60, $EF, $04, $F0, $04, $01, $01, $06
	dc.b	$FB, $F4, $C2, $08, $C1, $BD, $C1, $BF, $BD, $BF, $BD, $BC, $BD, $BC, $BA, $B5, $BC, $BA, $B8, $BA, $BC, $BD, $BC, $BA, $BF, $BD, $BC, $C2, $C1, $BD, $C1, $BF
	dc.b	$BD, $BF, $BD, $BC, $BA, $BC, $BD, $BF, $BF, $BF, $BF, $BF, $BF, $BF, $0C, $80, $24, $FB, $0C, $F8, $0B, $CB, $F6, $70, $CA, $80, $60, $80, $80, $80, $F9, $80
	dc.b	$60, $EF, $01, $F8, $7A, $CB, $96, $10, $08, $08, $99, $9B, $9D, $9B, $9D, $A2, $A0, $9D, $F8, $7A, $CB, $96, $10, $08, $08, $99, $9B, $9D, $9B, $9D, $A2, $A0
	dc.b	$9D, $F7, $00, $02, $13, $CB, $EF, $01, $9E, $10, $08, $08, $9D, $99, $9B, $10, $08, $08, $99, $98, $96, $10, $08, $08, $98, $99, $9D, $10, $08, $08, $9B, $99
	dc.b	$9E, $10, $08, $08, $9D, $99, $9B, $10, $08, $08, $99, $96, $9D, $9D, $9D, $9D, $9D, $9D, $9D, $0C, $80, $24, $F8, $7A, $CB, $96, $10, $08, $08, $99, $9B, $9D
	dc.b	$9B, $9D, $A2, $A0, $9D, $F6, $13, $CB, $96, $10, $08, $08, $99, $9B, $96, $99, $96, $98, $94, $98, $96, $10, $08, $08, $99, $9B, $96, $99, $9B, $94, $94, $94
	dc.b	$96, $10, $08, $08, $99, $9B, $96, $99, $96, $98, $94, $98, $F9, $80, $60, $EF, $02, $BA, $60, $B8, $BA, $E7, $60, $60, $B8, $BC, $E7, $60, $BA, $B8, $BA, $E7
	dc.b	$60, $60, $B8, $B8, $24, $BC, $3C, $E7, $60, $EF, $03, $E0, $40, $BA, $10, $08, $80, $18, $BA, $10, $08, $80, $18, $BA, $10, $08, $80, $18, $B8, $10, $08, $80
	dc.b	$18, $BA, $10, $08, $80, $18, $BA, $10, $08, $80, $18, $BC, $06, $0A, $08, $08, $08, $08, $0C, $80, $24, $E0, $C0, $F8, $0B, $CB, $F6, $A1, $CB, $80, $60, $EF
	dc.b	$02, $B5, $60, $60, $60, $E7, $60, $60, $60, $B8, $E7, $60, $B5, $B5, $B5, $E7, $60, $60, $60, $24, $B8, $3C, $E7, $60, $EF, $03, $B6, $10, $08, $80, $18, $B6
	dc.b	$10, $08, $80, $18, $B5, $10, $08, $80, $18, $B3, $10, $08, $80, $18, $B6, $10, $08, $80, $18, $B6, $10, $08, $80, $18, $B8, $08, $08, $08, $08, $08, $08, $0C
	dc.b	$80, $24, $F8, $0B, $CB, $F6, $F1, $CB, $80, $60, $EF, $02, $B1, $60, $60, $60, $E7, $60, $60, $60, $B5, $E7, $60, $B1, $B1, $B1, $E7, $60, $60, $60, $24, $B5
	dc.b	$3C, $E7, $60, $EF, $03, $E0, $80, $B1, $10, $08, $80, $18, $B3, $10, $08, $80, $18, $B1, $10, $08, $80, $18, $B0, $10, $08, $80, $18, $B1, $10, $08, $80, $18
	dc.b	$B3, $10, $08, $80, $18, $B5, $08, $08, $08, $08, $08, $08, $0C, $80, $24, $E0, $C0, $F8, $0B, $CB, $F6, $70, $CA, $80, $60, $F5, $05, $80, $48, $BD, $12, $BA
	dc.b	$06, $80, $48, $BD, $12, $B8, $06, $80, $48, $BD, $12, $BA, $06, $80, $48, $08, $BD, $C1, $80, $48, $BD, $12, $BA, $06, $80, $48, $BD, $12, $B8, $06, $80, $48
	dc.b	$C1, $12, $BC, $06, $80, $18, $C1, $08, $BF, $BC, $B8, $BC, $B8, $B5, $B8, $B8, $80, $48, $BD, $12, $BA, $06, $80, $48, $BD, $12, $B8, $06, $80, $48, $BD, $12
	dc.b	$BA, $06, $80, $48, $08, $BD, $C1, $80, $48, $BD, $12, $BA, $06, $80, $48, $BD, $12, $B8, $06, $80, $48, $C1, $12, $BC, $06, $80, $18, $C1, $08, $BF, $BC, $B8
	dc.b	$BC, $B8, $B5, $B8, $B8, $F5, $05, $BD, $08, $BA, $B6, $AE, $AA, $AE, $B3, $B6, $BF, $C2, $BF, $BA, $AE, $A9, $AE, $AE, $B1, $B5, $B8, $B3, $B0, $AC, $B0, $B3
	dc.b	$BD, $BA, $B6, $B1, $AE, $B1, $B3, $B6, $BA, $BF, $BA, $B6, $A9, $AC, $B0, $A9, $AC, $B0, $B5, $18, $80, $F8, $0B, $CB, $F6, $8B, $CC, $80, $60, $F5, $05, $80
	dc.b	$48, $BA, $12, $B5, $06, $80, $48, $B8, $12, $B5, $06, $80, $48, $BA, $12, $B5, $06, $80, $48, $BA, $08, $BD, $C1, $80, $48, $BA, $12, $B5, $06, $80, $48, $B8
	dc.b	$12, $B5, $06, $80, $48, $BC, $12, $B8, $06, $80, $18, $C1, $08, $BF, $BC, $B8, $BC, $B8, $B5, $B8, $B8, $80, $48, $BA, $12, $B5, $06, $80, $48, $B8, $12, $B5
	dc.b	$06, $80, $48, $BA, $12, $B5, $06, $80, $48, $BA, $08, $BD, $C1, $80, $48, $BA, $12, $B5, $06, $80, $48, $B8, $12, $B5, $06, $80, $48, $BC, $12, $B8, $06, $80
	dc.b	$18, $C1, $08, $BF, $BC, $B8, $BC, $B8, $B5, $B8, $B8, $F5, $05, $BD, $08, $BA, $B6, $AE, $AA, $AE, $B3, $B6, $BF, $C2, $BF, $BA, $AE, $A9, $AE, $AE, $B1, $B5
	dc.b	$B8, $B3, $B0, $AC, $B0, $B3, $BD, $BA, $B6, $B1, $AE, $B1, $B3, $B6, $BA, $BF, $BA, $B6, $A9, $AC, $B0, $A9, $AC, $B0, $B5, $18, $80, $F8, $0B, $CB, $F6, $2F
	dc.b	$CD, $81, $04, $81, $82, $08, $82, $04, $82, $83, $08, $84, $85, $85, $84, $83, $82, $04, $83, $84, $08, $84, $95, $08, $8F, $95, $84, $8F, $95, $F7, $00, $1F
	dc.b	$E8, $CD, $82, $04, $82, $83, $08, $84, $95, $84, $84, $95, $08, $8A, $95, $84, $8A, $95, $95, $8A, $95, $81, $82, $83, $95, $8A, $95, $84, $8A, $95, $95, $84
	dc.b	$84, $85, $81, $82, $95, $08, $8A, $95, $84, $8A, $95, $95, $8A, $95, $81, $82, $83, $84, $84, $84, $84, $84, $84, $84, $8F, $8F, $8F, $8F, $8F, $95, $08, $8F
	dc.b	$95, $84, $8F, $95, $F7, $00, $07, $2F, $CE, $82, $04, $82, $83, $08, $84, $95, $84, $84, $F6, $E8, $CD, $3B, $75, $36, $63, $32, $D9, $5E, $DF, $9F, $0C, $0A
	dc.b	$11, $04, $04, $02, $02, $00, $4F, $2F, $2F, $1F, $24, $1C, $1D, $80, $12, $32, $46, $08, $04, $1F, $1F, $1F, $1F, $06, $16, $18, $09, $07, $08, $06, $05, $3F
	dc.b	$4F, $3F, $4F, $1C, $0F, $17, $80, $15, $E4, $32, $28, $04, $1F, $1F, $1F, $1F, $08, $0F, $09, $08, $07, $02, $00, $00, $3F, $5F, $4F, $4F, $1C, $80, $80, $80
	dc.b	$21, $6D, $74, $58, $28, $DF, $DF, $1F, $1F, $10, $0C, $09, $08, $07, $00, $02, $02, $3F, $4F, $4F, $4F, $24, $10, $20, $80, $21, $74, $B2, $34, $32, $16, $18
	dc.b	$18, $1F, $06, $0A, $0F, $0B, $08, $08, $04, $04, $4F, $4F, $3F, $1F, $24, $20, $12, $80, $7E, $D8, $06, $03, $01, $00, $EF, $D7, $00, $02, $F4, $CE, $F4, $14
	dc.b	$0F, $D1, $F4, $14, $33, $D2, $F4, $18, $7E, $D3, $F4, $18, $B6, $D4, $F4, $18, $B7, $D5, $E8, $05, $00, $00, $F8, $D6, $E8, $05, $00, $00, $72, $D7, $E8, $05
	dc.b	$00, $00, $EA, $44, $01, $E6, $80, $60, $80, $80, $80, $F7, $00, $06, $F8, $CE, $EF, $00, $F0, $14, $01, $04, $08, $BB, $03, $E7, $BC, $E7, $BD, $2A, $BF, $0C
	dc.b	$BC, $18, $BB, $02, $E7, $BC, $E7, $BD, $38, $0C, $BF, $18, $BD, $0C, $BA, $02, $E7, $BB, $E7, $BC, $14, $BD, $0C, $BC, $18, $BA, $0C, $B6, $02, $E7, $B7, $E7
	dc.b	$B8, $74, $AE, $03, $E7, $AF, $E7, $B0, $12, $B3, $0C, $AC, $18, $0C, $B0, $B3, $BC, $18, $BD, $0C, $BC, $18, $BA, $0C, $B8, $0C, $B8, $03, $E7, $B9, $E7, $BA
	dc.b	$66, $E7, $60, $BB, $02, $E7, $BC, $E7, $BD, $14, $BF, $0C, $BC, $18, $0C, $BD, $BF, $BD, $10, $BF, $C1, $C1, $0E, $BF, $12, $BB, $02, $E7, $BC, $E7, $BD, $24
	dc.b	$BF, $0C, $BD, $18, $BC, $B8, $03, $E7, $B9, $E7, $BA, $66, $B8, $02, $E7, $B9, $E7, $BC, $14, $BA, $0C, $BC, $18, $BA, $0C, $B8, $BA, $BA, $03, $E7, $BB, $E7
	dc.b	$BC, $2A, $80, $18, $B3, $0C, $B1, $B0, $24, $B1, $AC, $18, $AE, $54, $B5, $0C, $BA, $06, $B8, $B6, $B8, $BA, $24, $06, $BC, $BD, $0C, $BC, $06, $BD, $BF, $0C
	dc.b	$BD, $06, $BF, $C1, $0A, $BF, $08, $C1, $06, $C4, $C2, $04, $C1, $08, $C2, $06, $C1, $BF, $C1, $BF, $BD, $BF, $BD, $BC, $BD, $BC, $BA, $BC, $BA, $B8, $BA, $B8
	dc.b	$B6, $B8, $B6, $B5, $B6, $03, $E7, $B7, $E7, $B8, $5A, $AE, $03, $E7, $AF, $E7, $B0, $36, $0C, $B3, $B8, $BC, $BA, $06, $B8, $B0, $0A, $B3, $08, $B8, $06, $BC
	dc.b	$16, $B8, $0E, $B6, $06, $B3, $B8, $03, $E7, $B9, $E7, $BA, $5A, $E7, $60, $BD, $0C, $BF, $C1, $18, $BF, $0C, $BD, $18, $0C, $E7, $0C, $BF, $C1, $BF, $BD, $18
	dc.b	$BC, $06, $BA, $04, $BC, $08, $BD, $06, $B6, $03, $E7, $B7, $E7, $C4, $36, $0C, $C2, $C1, $C2, $18, $C1, $0C, $BF, $3C, $B0, $06, $AE, $B0, $AE, $B1, $B0, $B3
	dc.b	$B0, $B5, $B1, $B6, $B3, $B8, $B5, $BA, $B8, $BA, $03, $E7, $BB, $E7, $BC, $34, $08, $BD, $04, $BC, $08, $BA, $06, $B8, $BA, $B8, $03, $E7, $B9, $E7, $BA, $5A
	dc.b	$E7, $60, $EF, $02, $F0, $14, $01, $04, $08, $BB, $03, $E7, $BC, $E7, $BD, $2A, $BF, $0C, $BC, $18, $BD, $0C, $E7, $0C, $B8, $B3, $B0, $B3, $18, $B8, $0C, $B3
	dc.b	$B3, $03, $E7, $B4, $E7, $C1, $12, $BD, $0C, $BF, $18, $BC, $0C, $BD, $B8, $B3, $03, $E7, $B4, $E7, $B5, $4E, $E7, $F0, $01, $01, $F0, $00, $0C, $F0, $14, $01
	dc.b	$04, $08, $80, $0C, $B6, $B3, $B1, $B3, $AE, $18, $AF, $02, $E7, $B0, $E7, $B1, $08, $E7, $0C, $AC, $B0, $AC, $AE, $B0, $B1, $0A, $B3, $0E, $B1, $18, $B8, $BA
	dc.b	$0C, $B6, $24, $BB, $03, $E7, $BC, $E7, $BD, $2A, $BC, $0C, $BD, $BF, $C1, $E7, $0C, $BF, $BD, $C1, $18, $BF, $0C, $BD, $C1, $E7, $0C, $BF, $BD, $C2, $18, $C1
	dc.b	$0C, $BF, $C1, $E7, $0C, $BF, $BD, $BF, $BD, $BC, $BD, $BA, $BC, $B8, $BA, $BC, $BD, $BC, $BA, $B8, $E7, $0C, $BC, $B5, $BC, $B5, $BA, $B5, $B8, $E7, $0C, $B3
	dc.b	$B6, $B3, $B5, $B6, $B8, $BA, $E7, $30, $BC, $0C, $BD, $BF, $B3, $03, $E7, $B4, $E7, $C1, $5A, $E7, $F0, $01, $01, $F0, $00, $0C, $F6, $02, $CF, $EF, $01, $80
	dc.b	$60, $80, $80, $80, $80, $80, $80, $80, $9B, $0C, $0C, $0C, $0C, $18, $0C, $0C, $E7, $0C, $0C, $18, $18, $18, $0C, $0C, $0C, $0C, $18, $0C, $0C, $E7, $0C, $0C
	dc.b	$18, $18, $18, $0C, $0C, $0C, $0C, $18, $0C, $0C, $E7, $0C, $0C, $18, $18, $0C, $0C, $E7, $0C, $0C, $18, $18, $0C, $0C, $E7, $0C, $0C, $18, $18, $18, $F7, $00
	dc.b	$02, $1A, $D1, $EF, $01, $F8, $DE, $D1, $96, $96, $99, $96, $9B, $96, $99, $96, $F8, $DE, $D1, $92, $92, $92, $92, $94, $94, $94, $94, $F8, $DE, $D1, $96, $96
	dc.b	$99, $96, $9B, $96, $99, $96, $F8, $DE, $D1, $92, $92, $92, $92, $94, $94, $94, $94, $EF, $01, $F8, $19, $D2, $A0, $A0, $A0, $A0, $99, $99, $99, $99, $F8, $19
	dc.b	$D2, $A0, $A0, $A0, $A2, $A4, $A2, $A0, $9E, $9E, $9E, $9E, $9E, $9E, $9E, $9E, $9E, $A0, $A0, $A0, $A0, $A0, $A0, $A0, $A0, $99, $99, $99, $99, $99, $99, $99
	dc.b	$99, $9E, $9E, $9E, $9E, $9E, $9E, $9E, $9E, $9B, $9B, $9B, $9B, $9B, $9B, $9B, $9B, $9B, $9B, $9B, $9B, $A0, $A0, $A0, $A0, $99, $99, $99, $99, $99, $99, $99
	dc.b	$99, $99, $99, $A0, $A2, $9D, $A5, $A4, $A2, $F6, $55, $D1, $96, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0A, $0E, $94, $0C, $0C
	dc.b	$0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $96, $96
	dc.b	$96, $96, $96, $96, $96, $96, $F9, $9E, $0C, $9E, $9E, $9E, $9E, $9E, $9E, $9E, $A0, $A0, $A0, $A0, $A0, $A0, $A0, $A0, $99, $99, $99, $99, $99, $99, $99, $99
	dc.b	$F9, $EF, $03, $F0, $28, $01, $04, $08, $E6, $FC, $E0, $80, $F8, $01, $D3, $E6, $04, $EF, $04, $F0, $14, $01, $04, $08, $E0, $C0, $F8, $45, $D3, $80, $18, $BC
	dc.b	$BA, $0C, $BC, $80, $18, $BD, $0C, $0C, $B5, $18, $B3, $0C, $B5, $80, $18, $B5, $B3, $0C, $B5, $80, $30, $F8, $45, $D3, $80, $18, $BC, $0C, $0C, $BD, $BC, $80
	dc.b	$18, $BD, $0C, $0C, $B5, $18, $B3, $0C, $B5, $80, $18, $80, $0C, $BA, $80, $18, $BC, $0C, $80, $24, $F8, $45, $D3, $80, $18, $BC, $BA, $0C, $BC, $80, $18, $BD
	dc.b	$0C, $BD, $B5, $18, $B3, $0C, $B5, $80, $18, $B5, $B3, $0C, $B5, $80, $30, $F8, $45, $D3, $80, $18, $BC, $0C, $0C, $BD, $BC, $80, $18, $BD, $0C, $0C, $B5, $18
	dc.b	$B3, $0C, $B5, $80, $18, $80, $0C, $BA, $80, $18, $BC, $0C, $80, $24, $EF, $05, $E0, $80, $BA, $48, $18, $BC, $30, $30, $B5, $48, $B3, $0C, $B5, $E7, $60, $B6
	dc.b	$48, $18, $B5, $3C, $24, $B1, $3C, $AA, $24, $B3, $48, $80, $18, $BA, $48, $18, $BC, $3C, $0C, $BD, $BC, $B8, $48, $0C, $BA, $E7, $60, $B6, $0C, $B5, $B6, $80
	dc.b	$18, $B6, $0C, $B5, $B6, $80, $30, $B3, $B5, $60, $E7, $60, $F6, $43, $D2, $F8, $1B, $D3, $BC, $0C, $BA, $E7, $60, $E7, $60, $F8, $1B, $D3, $BF, $0C, $BC, $E7
	dc.b	$60, $E7, $60, $F7, $00, $02, $0B, $D3, $F9, $BD, $0C, $0C, $0C, $0C, $18, $0C, $0C, $E7, $0C, $0C, $18, $18, $18, $BC, $0C, $0C, $0C, $0C, $18, $0C, $0C, $E7
	dc.b	$0C, $0C, $18, $18, $18, $BD, $0C, $0C, $0C, $0C, $18, $0C, $0C, $E7, $0C, $0C, $18, $18, $F9, $E0, $80, $BD, $0C, $0C, $E0, $C0, $B5, $18, $B3, $0C, $B5, $80
	dc.b	$18, $80, $18, $BD, $BC, $0C, $BD, $80, $18, $E0, $80, $BC, $0C, $BC, $E0, $C0, $B3, $18, $B1, $0C, $B3, $80, $18, $B3, $B1, $0C, $B3, $80, $30, $E0, $80, $BC
	dc.b	$0C, $0C, $E0, $C0, $B3, $18, $B1, $0C, $B3, $80, $18, $F9, $EF, $03, $F0, $28, $01, $04, $08, $E6, $FC, $F8, $49, $D4, $E6, $04, $EF, $04, $F0, $14, $01, $04
	dc.b	$08, $F8, $8A, $D4, $80, $18, $B8, $B6, $0C, $B8, $80, $18, $BA, $0C, $0C, $AE, $18, $AC, $0C, $AE, $80, $18, $AE, $AC, $0C, $AE, $80, $30, $F8, $8A, $D4, $80
	dc.b	$18, $B8, $0C, $0C, $BA, $B8, $80, $18, $BA, $0C, $0C, $AE, $18, $AC, $0C, $AE, $80, $18, $80, $0C, $B6, $80, $18, $B8, $0C, $80, $24, $F8, $8A, $D4, $80, $18
	dc.b	$B8, $B6, $0C, $B8, $80, $18, $BA, $0C, $0C, $AE, $18, $AC, $0C, $0C, $80, $18, $AE, $AC, $0C, $AE, $80, $30, $F8, $8A, $D4, $80, $18, $B8, $0C, $0C, $BA, $B8
	dc.b	$80, $18, $BA, $0C, $0C, $AE, $18, $AC, $0C, $AE, $80, $18, $80, $0C, $B6, $80, $18, $B8, $0C, $80, $24, $EF, $05, $F0, $14, $01, $04, $08, $B6, $48, $18, $B8
	dc.b	$30, $30, $B1, $48, $B0, $0C, $B1, $E7, $60, $48, $18, $B0, $3C, $24, $AE, $3C, $24, $B0, $48, $80, $18, $B6, $48, $18, $B8, $3C, $0C, $BA, $B8, $B5, $48, $0C
	dc.b	$B6, $E7, $60, $B3, $0C, $B1, $B3, $80, $18, $B3, $0C, $B1, $B3, $80, $30, $B0, $B1, $60, $E7, $60, $F6, $8C, $D3, $F8, $62, $D4, $0C, $B7, $E7, $60, $E7, $60
	dc.b	$F8, $62, $D4, $BA, $0C, $B8, $E7, $60, $E7, $60, $F7, $00, $02, $52, $D4, $F9, $B8, $0C, $0C, $0C, $0C, $18, $0C, $0C, $E7, $0C, $0C, $18, $18, $18, $0C, $0C
	dc.b	$0C, $0C, $18, $0C, $0C, $E7, $0C, $0C, $18, $18, $18, $0C, $0C, $0C, $0C, $18, $0C, $0C, $E7, $0C, $0C, $18, $18, $F9, $C6, $0C, $0C, $AE, $18, $AC, $0C, $AE
	dc.b	$80, $18, $80, $18, $BA, $B8, $0C, $BA, $24, $C4, $0C, $0C, $AC, $18, $AA, $0C, $AC, $80, $18, $AC, $AA, $0C, $AC, $80, $30, $C4, $0C, $0C, $AC, $18, $AA, $0C
	dc.b	$AC, $80, $18, $F9, $EF, $03, $F0, $28, $01, $04, $08, $E6, $FC, $E0, $40, $F8, $6B, $D5, $E6, $04, $EF, $04, $F0, $14, $01, $04, $08, $E0, $40, $F8, $9E, $D5
	dc.b	$80, $18, $B3, $B1, $0C, $B3, $80, $18, $B5, $0C, $0C, $80, $48, $80, $60, $F8, $9E, $D5, $80, $18, $B3, $0C, $0C, $0C, $0C, $80, $18, $B5, $0C, $0C, $80, $48
	dc.b	$80, $0C, $B1, $80, $18, $B3, $0C, $80, $24, $F8, $9E, $D5, $80, $18, $B3, $B1, $0C, $B3, $80, $18, $B5, $0C, $0C, $80, $48, $80, $60, $F8, $9E, $D5, $80, $18
	dc.b	$B3, $0C, $0C, $0C, $0C, $80, $18, $B5, $0C, $0C, $80, $48, $80, $0C, $B1, $80, $18, $B3, $0C, $80, $24, $EF, $05, $F0, $14, $01, $04, $08, $E0, $40, $B1, $48
	dc.b	$18, $B3, $30, $30, $AC, $48, $0C, $0C, $E7, $60, $AE, $48, $18, $AC, $3C, $24, $AA, $3C, $24, $AC, $48, $80, $18, $B1, $48, $18, $B3, $3C, $0C, $0C, $0C, $B1
	dc.b	$48, $0C, $0C, $E7, $60, $AE, $0C, $0C, $0C, $80, $18, $AE, $0C, $0C, $0C, $80, $30, $AC, $AC, $60, $E7, $60, $F6, $C6, $D4, $B3, $0C, $0C, $0C, $0C, $18, $0C
	dc.b	$0C, $E7, $0C, $0C, $18, $18, $18, $0C, $0C, $0C, $0C, $18, $0C, $0C, $E7, $0C, $0C, $18, $18, $18, $0C, $0C, $0C, $0C, $18, $0C, $0C, $E7, $0C, $0C, $18, $18
	dc.b	$0C, $0C, $E7, $60, $E7, $60, $F7, $00, $03, $6B, $D5, $F9, $B5, $0C, $0C, $80, $48, $80, $18, $B5, $B3, $0C, $B5, $24, $B3, $0C, $0C, $80, $48, $80, $60, $B3
	dc.b	$0C, $0C, $80, $48, $F9, $F5, $00, $FB, $F4, $F8, $01, $D3, $FB, $0C, $F5, $05, $F8, $00, $D6, $18, $0C, $0C, $0C, $0C, $0C, $0C, $F8, $00, $D6, $E7, $0C, $BA
	dc.b	$BA, $BA, $18, $BC, $0C, $0C, $0C, $F8, $00, $D6, $18, $0C, $0C, $0C, $0C, $0C, $0C, $F8, $00, $D6, $E7, $0C, $BA, $BA, $BA, $18, $BC, $0C, $0C, $0C, $F5, $00
	dc.b	$F0, $14, $01, $01, $06, $F8, $35, $D6, $C1, $F4, $00, $F6, $C0, $D5, $B5, $18, $0C, $0C, $0C, $0C, $0C, $0C, $18, $0C, $0C, $0C, $0C, $0C, $0C, $B3, $18, $0C
	dc.b	$0C, $0C, $0C, $0C, $0C, $18, $0C, $0C, $0C, $0C, $0C, $0C, $18, $0C, $0C, $0C, $0C, $0C, $0C, $18, $0C, $0C, $0C, $0C, $0C, $0C, $B5, $18, $0C, $0C, $0C, $0C
	dc.b	$0C, $0C, $F9, $BA, $30, $BC, $0C, $B8, $18, $BA, $0C, $B6, $B1, $AE, $BA, $B6, $B1, $AE, $B1, $BD, $18, $BA, $0C, $BC, $18, $B8, $0C, $BA, $B5, $B5, $B1, $AC
	dc.b	$B0, $B1, $B5, $B8, $B5, $E7, $0C, $BD, $BA, $B6, $BD, $BA, $18, $B6, $0C, $E7, $0C, $BC, $B8, $B5, $BC, $B8, $B5, $B8, $80, $18, $BD, $BD, $0C, $BA, $BC, $BD
	dc.b	$B3, $06, $B8, $BC, $B8, $B3, $B8, $BC, $B8, $B3, $B8, $BC, $BF, $B8, $BC, $BD, $BF, $BD, $0C, $BC, $BA, $BD, $18, $BC, $0C, $BA, $BD, $E7, $0C, $BC, $BA, $BF
	dc.b	$18, $BD, $0C, $BC, $18, $BD, $06, $B8, $B5, $B8, $BD, $B8, $B5, $B8, $BD, $B8, $B5, $B8, $BD, $B8, $B5, $B8, $BD, $BA, $B6, $BA, $BD, $BA, $B6, $BA, $BD, $BA
	dc.b	$B6, $BA, $BD, $BA, $B6, $BA, $BF, $BA, $B6, $BA, $BF, $BA, $B6, $BA, $BF, $BA, $B6, $BA, $BF, $BA, $B6, $BA, $BF, $BA, $B6, $BA, $BF, $BA, $B6, $BA, $BF, $BA
	dc.b	$B6, $BA, $BF, $BA, $B6, $BA, $BD, $B8, $B5, $B8, $BD, $B8, $B5, $B8, $BD, $B8, $B5, $B8, $BD, $B8, $B5, $B8, $B5, $B1, $B5, $B8, $BC, $B8, $BC, $BD, $BC, $BD
	dc.b	$BF, $BD, $C1, $BF, $C2, $F9, $F5, $00, $FB, $F4, $F8, $49, $D4, $FB, $0C, $F5, $05, $F8, $3D, $D7, $18, $0C, $0C, $0C, $0C, $0C, $0C, $F8, $3D, $D7, $E7, $0C
	dc.b	$B6, $B6, $B6, $18, $B8, $0C, $0C, $0C, $F8, $3D, $D7, $18, $0C, $0C, $0C, $0C, $0C, $0C, $F8, $3D, $D7, $E7, $0C, $B6, $B6, $B6, $18, $B8, $0C, $0C, $0C, $F5
	dc.b	$00, $80, $03, $F8, $35, $D6, $C1, $03, $F6, $01, $D7, $BD, $18, $0C, $0C, $0C, $0C, $0C, $0C, $18, $0C, $0C, $0C, $0C, $0C, $0C, $BC, $18, $0C, $0C, $0C, $0C
	dc.b	$0C, $0C, $18, $0C, $0C, $0C, $0C, $0C, $0C, $18, $0C, $0C, $0C, $0C, $0C, $0C, $18, $0C, $0C, $0C, $0C, $0C, $0C, $BD, $18, $0C, $0C, $0C, $0C, $0C, $0C, $F9
	dc.b	$F5, $00, $FB, $F4, $F8, $6B, $D5, $FB, $0C, $F5, $05, $F8, $BA, $D7, $18, $0C, $0C, $0C, $0C, $0C, $0C, $F8, $BA, $D7, $E7, $0C, $B1, $B1, $B1, $18, $B3, $0C
	dc.b	$0C, $0C, $F8, $BA, $D7, $18, $0C, $0C, $0C, $0C, $0C, $0C, $F8, $BA, $D7, $E7, $0C, $B1, $B1, $B1, $18, $B3, $0C, $0C, $0C, $F5, $00, $80, $60, $80, $80, $80
	dc.b	$F7, $00, $04, $AB, $D7, $F6, $7B, $D7, $C6, $18, $0C, $0C, $0C, $0C, $0C, $0C, $18, $0C, $0C, $0C, $0C, $0C, $0C, $C4, $18, $0C, $0C, $0C, $0C, $0C, $0C, $18
	dc.b	$0C, $0C, $0C, $0C, $0C, $0C, $18, $0C, $0C, $0C, $0C, $0C, $0C, $18, $0C, $0C, $0C, $0C, $0C, $0C, $C6, $18, $0C, $0C, $0C, $0C, $0C, $0C, $F9, $80, $18, $8A
	dc.b	$F7, $00, $0F, $EF, $D7, $80, $20, $85, $04, $85, $83, $08, $F8, $4F, $D8, $84, $0C, $85, $85, $8A, $85, $84, $84, $84, $F8, $4F, $D8, $85, $0C, $81, $06, $82
	dc.b	$84, $0C, $85, $85, $84, $84, $84, $F8, $4F, $D8, $84, $0C, $85, $85, $84, $81, $06, $82, $84, $0C, $84, $84, $F8, $66, $D8, $81, $06, $81, $85, $0C, $82, $83
	dc.b	$82, $06, $82, $85, $0C, $82, $83, $F8, $66, $D8, $81, $06, $81, $82, $0C, $85, $83, $06, $83, $81, $06, $81, $82, $0C, $84, $84, $F6, $0A, $D8, $85, $06, $8A
	dc.b	$85, $8A, $84, $8A, $8A, $8A, $8A, $8A, $85, $8A, $84, $8A, $8A, $8A, $F7, $00, $0F, $4F, $D8, $F9, $85, $06, $8A, $85, $8A, $84, $8A, $8A, $8A, $85, $06, $8A
	dc.b	$85, $8A, $84, $8A, $8A, $85, $F7, $00, $07, $66, $D8, $F9, $3D, $54, $48, $74, $32, $9F, $1F, $1E, $1F, $11, $03, $08, $0A, $03, $00, $00, $00, $3F, $3F, $3F
	dc.b	$3F, $1A, $80, $80, $80, $12, $6A, $4A, $68, $44, $18, $1D, $1F, $1F, $10, $0F, $15, $08, $07, $00, $07, $0A, $6F, $6F, $6F, $4F, $1A, $16, $18, $80, $2C, $C4
	dc.b	$74, $34, $34, $1F, $12, $1F, $1F, $0E, $00, $0F, $00, $00, $01, $00, $01, $2F, $3F, $3F, $3F, $14, $80, $0E, $80, $11, $8E, $42, $4C, $54, $1F, $1F, $1F, $1F
	dc.b	$18, $10, $08, $08, $02, $01, $04, $03, $4F, $3F, $3F, $2F, $27, $1A, $24, $80, $3D, $5A, $48, $74, $32, $99, $9F, $98, $9F, $08, $05, $0F, $08, $0F, $05, $05
	dc.b	$03, $35, $35, $35, $35, $20, $80, $80, $80, $2C, $86, $24, $54, $34, $1F, $1F, $1F, $1F, $05, $0E, $04, $05, $01, $01, $01, $02, $5B, $5A, $5A, $8A, $18, $80
	dc.b	$15, $80, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $00, $00
	dc.b	$00, $00, $00, $00, $5B, $33, $3D, $DD, $DC, $44, $61, $DB, $C5, $EC, $55, $56, $36, $CD, $9D, $2C, $C0, $EC, $3D, $53, $55, $53, $5D, $1E, $CE, $D0, $46, $5D
	dc.b	$59, $42, $54, $CA, $DD, $C5, $9A, $5C, $34, $CD, $E9, $D4, $46, $66, $2B, $DE, $35, $DB, $1D, $DD, $45, $56, $4C, $AE, $4E, $D2, $34, $66, $2D, $BA, $22, $A3
	dc.b	$DC, $EB, $D6, $65, $4C, $5B, $DD, $5E, $C2, $C6, $DC, $55, $6D, $AC, $DE, $E0, $35, $35, $55, $51, $C9, $4D, $AC, $6D, $34, $DD, $46, $ED, $CC, $34, $4C, $54
	dc.b	$4B, $EE, $45, $D4, $65, $5B, $6D, $43, $CD, $EE, $E5, $52, $55, $65, $ED, $4C, $EC, $56, $BD, $44, $5C, $05, $4C, $EE, $DC, $56, $D5, $43, $55, $3B, $14, $4B
	dc.b	$ED, $CD, $C5, $D0, $52, $C4, $24, $4D, $E0, $75, $BD, $2E, $66, $5B, $EE, $55, $6E, $ED, $C9, $02, $3C, $D3, $46, $64, $DD, $C5, $60, $EE, $35, $65, $EE, $C5
	dc.b	$3E, $C6, $5C, $E5, $76, $2D, $EE, $6E, $ED, $AA, $65, $DE, $47, $4E, $F6, $74, $5C, $B3, $BD, $1D, $2D, $3C, $C4, $3D, $C5, $59, $AD, $DD, $36, $65, $44, $DE
	dc.b	$E5, $5C, $42, $CC, $36, $DE, $66, $1E, $EE, $66, $65, $5D, $EE, $EC, $23, $A2, $4E, $56, $5B, $35, $6C, $2C, $35, $65, $FE, $EE, $C4, $66, $5E, $E9, $55, $4D
	dc.b	$D3, $65, $EB, $67, $DE, $DB, $CC, $46, $DA, $9E, $B5, $7D, $EC, $E6, $5E, $46, $5E, $EC, $D4, $A3, $54, $DE, $46, $69, $51, $45, $44, $D2, $3A, $EE, $ED, $56
	dc.b	$B4, $CB, $D3, $45, $0E, $D4, $66, $34, $4D, $33, $EC, $34, $25, $5E, $EC, $74, $DD, $B4, $D4, $66, $4F, $EC, $CA, $DD, $56, $7D, $FD, $66, $13, $43, $D6, $66
	dc.b	$5E, $FE, $D1, $4D, $E4, $65, $5D, $E3, $34, $DB, $34, $66, $5B, $EE, $46, $3A, $5A, $CB, $43, $EE, $C5, $6E, $31, $61, $EC, $BB, $42, $D3, $54, $2B, $35, $DA
	dc.b	$55, $62, $D6, $55, $EF, $ED, $D4, $D6, $CC, $64, $DB, $5D, $D9, $6C, $34, $65, $CE, $D5, $55, $54, $DD, $49, $E1, $DA, $3B, $45, $44, $BD, $ED, $AA, $C5, $50
	dc.b	$13, $50, $44, $42, $53, $54, $CB, $AE, $DE, $DD, $B6, $B9, $5D, $94, $65, $DC, $14, $43, $5D, $DC, $C5, $34, $56, $DD, $5E, $C5, $5C, $EE, $B6, $49, $DD, $E3
	dc.b	$3D, $65, $5B, $5C, $45, $63, $D2, $2B, $40, $9C, $CE, $D3, $22, $BD, $B4, $9C, $B5, $5C, $D4, $25, $56, $BE, $D9, $4C, $06, $4D, $B5, $6A, $D2, $5E, $D3, $DD
	dc.b	$5D, $EC, $DD, $54, $65, $34, $34, $43, $51, $B4, $B2, $44, $2C, $DE, $DB, $4C, $09, $CD, $3B, $54, $5B, $D0, $26, $51, $DC, $D5, $55, $E4, $65, $CE, $A5, $5C
	dc.b	$DE, $DD, $66, $5E, $EC, $DB, $A2, $CB, $56, $2D, $54, $65, $43, $9C, $03, $4C, $DD, $DC, $C3, $12, $CD, $49, $A1, $CC, $A3, $55, $54, $6C, $DE, $55, $BC, $2D
	dc.b	$49, $C3, $63, $BC, $EB, $63, $C5, $0E, $DD, $C1, $BA, $35, $AD, $C6, $45, $C9, $65, $6C, $CD, $A5, $ED, $BD, $CC, $DA, $5C, $4A, $53, $22, $CB, $C4, $64, $1C
	dc.b	$52, $0C, $CD, $D5, $05, $3D, $D3, $2B, $44, $BB, $52, $C3, $4C, $BC, $BD, $DC, $D4, $55, $5D, $35, $54, $3C, $54, $9D, $3D, $D3, $4B, $CB, $BA, $0C, $C4, $23
	dc.b	$3C, $CB, $C5, $42, $2B, $65, $CC, $35, $CC, $1D, $1B, $DC, $9C, $4B, $C4, $14, $65, $CC, $C5, $5D, $C9, $D3, $BC, $DC, $C4, $BB, $55, $5E, $53, $D5, $45, $D4
	dc.b	$45, $6B, $CC, $DD, $DE, $D3, $4C, $35, $5C, $D4, $45, $4B, $44, $55, $DD, $B3, $CD, $B0, $3D, $DD, $3C, $25, $50, $46, $54, $41, $C3, $BD, $D4, $9D, $AD, $C4
	dc.b	$CC, $2B, $39, $B5, $45, $34, $B5, $4D, $CC, $BA, $A5, $AC, $BC, $33, $05, $CA, $0B, $B5, $4C, $DD, $A4, $43, $DC, $54, $5A, $D2, $55, $CD, $9D, $DC, $3A, $B1
	dc.b	$B5, $44, $66, $5D, $DE, $D6, $3D, $AC, $A3, $AC, $B2, $CD, $DD, $45, $35, $54, $6A, $DD, $53, $DD, $C2, $44, $65, $DD, $DC, $D9, $2D, $D4, $54, $55, $32, $4C
	dc.b	$9A, $CE, $36, $5C, $CB, $45, $BD, $4C, $DC, $3C, $1B, $C4, $54, $44, $34, $DA, $CD, $54, $09, $33, $DD, $C9, $9D, $C3, $36, $5B, $43, $35, $0D, $DD, $CE, $C5
	dc.b	$55, $B5, $65, $AD, $DC, $D3, $CA, $B4, $5C, $55, $1D, $CD, $D4, $DC, $66, $1D, $95, $52, $DD, $DD, $EA, $55, $5A, $33, $54, $DB, $5C, $C6, $E1, $66, $B5, $3C
	dc.b	$ED, $EE, $CC, $DD, $56, $BC, $54, $55, $CD, $24, $9B, $45, $5B, $05, $3D, $E4, $BD, $6D, $C3, $5B, $25, $BD, $1C, $C0, $BD, $A5, $55, $43, $54, $CE, $0D, $DC
	dc.b	$CB, $24, $44, $4B, $45, $3B, $4B, $A3, $BC, $55, $CD, $3E, $C1, $CD, $2A, $00, $54, $55, $C5, $4D, $C3, $4B, $9B, $24, $23, $3C, $EC, $3C, $9A, $14, $52, $C5
	dc.b	$9C, $BC, $B4, $5B, $45, $A0, $44, $BC, $CE, $DC, $BD, $44, $55, $31, $43, $A4, $53, $CA, $40, $E3, $0D, $2A, $AC, $BB, $C3, $41, $54, $45, $DD, $53, $CC, $42
	dc.b	$34, $35, $DB, $C9, $DC, $9C, $44, $CC, $AC, $33, $55, $5A, $44, $DD, $59, $BC, $DD, $14, $AB, $BD, $34, $52, $34, $55, $44, $44, $5E, $EC, $CD, $CC, $03, $CC
	dc.b	$A4, $C2, $50, $54, $C1, $64, $B4, $5B, $D2, $3C, $CC, $CD, $D1, $44, $6C, $EB, $44, $C0, $BA, $45, $54, $CB, $33, $CE, $A3, $BC, $44, $BB, $53, $AC, $3B, $65
	dc.b	$B9, $46, $5E, $ED, $DD, $DC, $B0, $BC, $35, $26, $3A, $54, $D5, $5B, $C6, $BD, $B3, $AD, $CC, $1E, $C4, $C5, $6C, $DB, $C1, $2A, $35, $35, $62, $CC, $B1, $DE
	dc.b	$45, $CD, $AC, $B5, $AB, $55, $B5, $55, $CB, $C5, $1E, $DC, $DC, $BB, $B3, $A4, $49, $C6, $2C, $54, $C5, $6B, $DB, $CA, $04, $1C, $DD, $CC, $D4, $4D, $35, $D4
	dc.b	$5C, $5C, $45, $65, $4C, $DD, $CA, $CE, $24, $DD, $25, $CC, $A5, $34, $44, $46, $34, $4A, $3C, $ED, $2D, $DD, $42, $B0, $3A, $C1, $55, $35, $5B, $44, $AC, $DC
	dc.b	$D2, $40, $B3, $BD, $4B, $35, $0D, $A5, $CB, $0B, $43, $3C, $35, $34, $3B, $C3, $1C, $DB, $DD, $B4, $CD, $36, $B0, $55, $56, $5D, $D4, $DB, $BC, $DA, $DC, $9B
	dc.b	$C2, $CC, $C4, $65, $51, $35, $45, $3D, $DD, $CD, $45, $2A, $CD, $D4, $5D, $D2, $24, $65, $CC, $2D, $54, $CB, $42, $B3, $1B, $2C, $DB, $90, $AC, $D4, $AC, $56
	dc.b	$CC, $56, $C5, $4D, $CC, $CB, $6C, $DD, $DD, $94, $CC, $CC, $B6, $55, $54, $94, $9B, $BC, $CD, $CD, $56, $41, $DD, $D2, $50, $DB, $24, $54, $01, $39, $C9, $DC
	dc.b	$54, $A3, $D2, $43, $44, $AD, $ED, $D5, $4D, $56, $3B, $46, $6C, $3E, $E4, $3D, $53, $3C, $DC, $33, $CD, $DC, $AB, $45, $56, $45, $5C, $DD, $DD, $33, $A6, $55
	dc.b	$CD, $ED, $4B, $DC, $53, $56, $4C, $D0, $B3, $0E, $35, $C9, $A3, $04, $34, $5D, $EE, $D9, $45, $35, $6D, $36, $53, $4B, $E0, $43, $C5, $3D, $BD, $E0, $1D, $DC
	dc.b	$BD, $66, $56, $A4, $5D, $DC, $AD, $04, $D5, $42, $5B, $CE, $34, $24, $4D, $B5, $2C, $BB, $B2, $DD, $46, $D5, $3D, $45, $44, $9D, $DD, $DA, $5C, $46, $4D, $55
	dc.b	$44, $5E, $E0, $3D, $33, $C5, $4E, $43, $DD, $C1, $CC, $64, $55, $56, $3D, $CE, $EA, $4B, $35, $96, $5B, $DD, $1C, $CB, $DB, $52, $EC, $35, $65, $C0, $52, $65
	dc.b	$DD, $CE, $9B, $2C, $DC, $D3, $A4, $6C, $D6, $63, $6C, $EC, $0B, $B4, $DB, $5E, $15, $1D, $EC, $BC, $56, $4C, $46, $4A, $24, $DE, $2B, $46, $5C, $C9, $DD, $9D
	dc.b	$DC, $C2, $66, $2C, $C9, $B6, $C3, $0D, $B4, $C9, $49, $5D, $33, $CC, $DE, $D3, $65, $C4, $64, $55, $44, $CD, $EB, $BC, $9D, $E3, $2B, $B0, $BE, $B6, $66, $33
	dc.b	$52, $A2, $3B, $CD, $EB, $55, $41, $CE, $36, $A4, $4D, $B4, $CC, $3A, $C1, $CD, $45, $53, $C9, $35, $93, $CC, $CC, $CB, $CD, $C6, $9D, $66, $94, $5D, $C4, $DC
	dc.b	$BA, $A5, $CD, $43, $EE, $C1, $45, $44, $54, $56, $CC, $CE, $E5, $45, $64, $DC, $3C, $E4, $9E, $05, $34, $53, $94, $32, $6D, $EB, $5D, $03, $D4, $4D, $56, $CE
	dc.b	$DD, $24, $D3, $62, $E6, $6A, $56, $EC, $9C, $B6, $3D, $CC, $EC, $CD, $DD, $D9, $66, $56, $4C, $5B, $A4, $CE, $DB, $D5, $64, $0A, $BE, $B5, $4D, $44, $34, $53
	dc.b	$43, $DD, $DD, $D3, $BD, $54, $46, $5C, $5C, $DC, $CC, $93, $DB, $62, $D5, $54, $A5, $EC, $3C, $D4, $5C, $B3, $D3, $A9, $DC, $3B, $C5, $56, $53, $2D, $DC, $CC
	dc.b	$B3, $CC, $66, $3B, $CD, $E5, $4E, $36, $93, $4B, $56, $BD, $DD, $EA, $59, $B1, $C3, $53, $44, $DE, $D2, $05, $5D, $56, $3C, $65, $DA, $4E, $D2, $DD, $64, $04
	dc.b	$BE, $A3, $DD, $9A, $C4, $55, $66, $DD, $49, $BD, $ED, $54, $46, $52, $DC, $ED, $64, $EC, $65, $35, $4A, $CD, $DC, $CE, $D5, $45, $5C, $36, $49, $5C, $DD, $CD
	dc.b	$D3, $C4, $64, $D5, $6A, $B5, $EE, $45, $A6, $2D, $B1, $EE, $21, $DC, $CB, $56, $56, $64, $E4, $BD, $DC, $DC, $4E, $66, $6C, $9D, $E0, $6C, $E4, $62, $B5, $5D
	dc.b	$CD, $EC, $4C, $C6, $BA, $5A, $56, $1E, $9C, $FA, $4C, $05, $35, $64, $C6, $6D, $DB, $E9, $6A, $D5, $4D, $DC, $EC, $0E, $D4, $46, $53, $36, $65, $CD, $ED, $DB
	dc.b	$05, $AD, $75, $4C, $DD, $E4, $4E, $C6, $4D, $B4, $5C, $3D, $CC, $1C, $46, $6C, $CC, $56, $DD, $DF, $ED, $56, $6C, $26, $6D, $36, $6D, $CE, $EB, $50, $D6, $BD
	dc.b	$CD, $E4, $6E, $B4, $25, $5B, $12, $3C, $B4, $92, $B4, $AB, $C5, $66, $DE, $DC, $D5, $DE, $46, $53, $C5, $9B, $CE, $C5, $B3, $64, $25, $CD, $5B, $ED, $BE, $E6
	dc.b	$53, $5C, $36, $6E, $26, $3D, $6E, $D6, $5D, $54, $EE, $0E, $EB, $2E, $B5, $64, $65, $56, $2E, $DD, $35, $4C, $B3, $C5, $54, $DD, $EE, $D6, $49, $56, $4B, $54
	dc.b	$9E, $ED, $B4, $C4, $65, $3B, $D2, $52, $DC, $CE, $C4, $34, $69, $35, $0E, $46, $DB, $4E, $B6, $54, $5A, $EE, $4E, $B5, $DD, $44, $55, $55, $50, $DD, $CC, $3C
	dc.b	$DB, $65, $B5, $5D, $ED, $ED, $67, $DD, $55, $4A, $DC, $CB, $EC, $56, $33, $34, $5B, $CB, $DE, $D4, $CD, $54, $D5, $54, $55, $DD, $55, $E5, $6E, $46, $44, $5D
	dc.b	$ED, $EE, $E5, $4C, $A4, $A5, $65, $46, $DE, $A3, $B2, $50, $94, $A4, $5C, $EB, $DD, $45, $DC, $65, $99, $4B, $2B, $DE, $94, $13, $64, $A0, $A4, $44, $DD, $DD
	dc.b	$23, $AB, $4C, $55, $DC, $53, $C4, $CE, $56, $54, $62, $EC, $EE, $C4, $3D, $95, $44, $55, $45, $BE, $CA, $DA, $14, $46, $CB, $62, $EE, $CD, $06, $CD, $46, $54
	dc.b	$4B, $23, $EE, $D5, $D9, $66, $B3, $CC, $53, $DC, $CD, $9D, $D2, $63, $25, $2D, $D6, $B5, $6E, $D6, $6C, $55, $EF, $DE, $C4, $5C, $E3, $65, $65, $41, $3D, $E5
	dc.b	$3C, $CC, $35, $52, $55, $DE, $DB, $D5, $6E, $D6, $6D, $44, $CC, $DD, $D5, $2D, $25, $55, $BB, $24, $DD, $0C, $D4, $4C, $35, $44, $5C, $DD, $44, $3B, $D4, $65
	dc.b	$B6, $BE, $ED, $DC, $49, $DD, $45, $45, $54, $64, $DE, $C4, $3B, $B4, $5C, $C5, $BD, $E1, $AD, $55, $23, $66, $DB, $3D, $DC, $DD, $4A, $D5, $65, $32, $DA, $5D
	dc.b	$DB, $DD, $36, $A5, $5C, $C3, $1E, $55, $5C, $DC, $C6, $5A, $4C, $EE, $CC, $56, $0E, $E5, $66, $55, $DD, $4D, $E3, $6B, $EC, $66, $5E, $44, $CE, $E2, $C3, $5D
	dc.b	$B6, $64, $B5, $CD, $CD, $33, $4E, $D5, $6C, $3C, $54, $CD, $54, $DD, $5D, $B5, $C1, $43, $EC, $66, $A4, $2D, $24, $92, $AD, $DE, $CC, $63, $BD, $C3, $55, $55
	dc.b	$43, $BE, $D4, $6A, $CB, $C3, $93, $6C, $EE, $D1, $B6, $4D, $15, $44, $64, $CC, $DE, $26, $DE, $55, $BC, $CD, $56, $DC, $AC, $C5, $5C, $4D, $D4, $53, $B4, $5C
	dc.b	$A5, $D5, $62, $CC, $BB, $DD, $E9, $AD, $E3, $56, $A5, $31, $55, $DD, $C5, $3D, $C6, $6B, $E3, $54, $F0, $BC, $B6, $DA, $57, $41, $BD, $D1, $DC, $2A, $EC, $56
	dc.b	$51, $ED, $94, $C5, $CD, $DA, $54, $55, $51, $9D, $C4, $6D, $94, $E5, $7A, $D3, $9E, $FB, $C5, $AD, $EC, $56, $46, $53, $4C, $DD, $45, $3C, $15, $4B, $C3, $9D
	dc.b	$EC, $A1, $45, $CC, $46, $45, $5C, $DE, $D3, $43, $E4, $54, $10, $44, $4D, $E3, $4D, $25, $D4, $0B, $54, $5A, $1B, $42, $A9, $93, $5B, $D4, $DD, $DC, $D3, $4B
	dc.b	$B5, $94, $46, $3C, $5B, $ED, $D5, $41, $56, $3D, $D5, $AC, $EE, $CB, $36, $5A, $56, $4C, $BC, $DA, $DD, $A3, $C0, $56, $4D, $D4, $54, $DD, $4D, $D3, $B5, $53
	dc.b	$CD, $B3, $94, $5C, $B3, $56, $54, $EC, $DD, $DC, $34, $CD, $DB, $56, $36, $5C, $D3, $DD, $95, $3D, $B5, $6B, $CD, $5D, $ED, $B4, $C5, $AC, $56, $64, $3B, $ED
	dc.b	$CE, $54, $DC, $36, $6D, $D2, $12, $C3, $42, $E2, $CB, $36, $2D, $D4, $2A, $55, $C5, $5C, $36, $1B, $CD, $ED, $DB, $9C, $CC, $C3, $36, $64, $31, $AD, $E5, $53
	dc.b	$A4, $4D, $D4, $6A, $DE, $9D, $45, $6C, $DD, $64, $54, $DD, $DC, $E4, $59, $24, $5B, $C5, $A3, $4B, $BC, $DE, $55, $5D, $BC, $16, $41, $13, $DD, $65, $54, $4D
	dc.b	$DD, $CD, $CC, $DC, $DD, $C3, $6C, $65, $D5, $54, $CD, $55, $D4, $64, $CE, $CB, $BE, $E6, $5D, $36, $5D, $57, $DC, $DE, $EC, $DD, $35, $DB, $75, $5B, $AA, $93
	dc.b	$9C, $DF, $C5, $15, $44, $4C, $40, $34, $35, $D4, $6C, $D6, $9D, $EC, $E4, $6A, $CE, $CE, $16, $C6, $5B, $25, $D5, $45, $5B, $D4, $DD, $CC, $6E, $EF, $66, $53
	dc.b	$64, $D4, $74, $9D, $EE, $EE, $D5, $49, $35, $54, $56, $55, $BD, $E4, $ED, $4C, $EE, $54, $56, $53, $BC, $B5, $65, $4D, $0C, $AC, $CB, $CD, $ED, $C4, $33, $4C
	dc.b	$35, $55, $55, $CD, $C4, $64, $CC, $DD, $A5, $CD, $E4, $C2, $D6, $52, $47, $4C, $DD, $EA, $CE, $DD, $25, $36, $5D, $A5, $54, $34, $3D, $ED, $2C, $96, $DE, $35
	dc.b	$64, $43, $D1, $62, $C6, $2C, $DE, $DC, $4C, $DD, $DD, $02, $46, $6D, $D1, $64, $C5, $35, $A2, $4D, $D9, $5E, $ED, $D5, $6C, $65, $DC, $75, $BD, $DE, $EC, $C4
	dc.b	$34, $DC, $56, $43, $51, $BC, $D5, $CD, $BB, $DE, $55, $B3, $44, $C6, $5C, $DC, $CC, $D5, $55, $32, $DC, $DE, $5B, $53, $5A, $36, $5D, $54, $CE, $E5, $66, $CD
	dc.b	$DD, $D2, $5C, $9E, $C4, $DD, $66, $D1, $64, $B9, $CC, $3D, $E3, $45, $2C, $45, $C3, $4C, $A4, $CC, $DE, $66, $BC, $4B, $D5, $55, $3A, $DD, $57, $3D, $C3, $DE
	dc.b	$C4, $DC, $ED, $DD, $A5, $45, $56, $4D, $46, $4C, $DC, $6D, $4A, $CC, $D4, $CC, $4F, $55, $E3, $75, $D5, $75, $DD, $ED, $DE, $CD, $CA, $D6, $66, $B6, $DE, $56
	dc.b	$BC, $EE, $4D, $C4, $52, $95, $5C, $54, $AB, $66, $2E, $C5, $DD, $DD, $DC, $CC, $BC, $DD, $65, $55, $50, $45, $0A, $D2, $55, $CC, $DC, $D4, $DC, $4E, $35, $4D
	dc.b	$75, $EC, $75, $9D, $EE, $CD, $EC, $C5, $CB, $55, $66, $B9, $53, $CD, $EE, $35, $3D, $CC, $55, $64, $BA, $40, $36, $5D, $D3, $DD, $E9, $D2, $BC, $CC, $4D, $55
	dc.b	$25, $6C, $54, $53, $ED, $56, $BD, $CD, $D3, $AC, $6E, $DB, $3D, $67, $DD, $66, $DD, $E4, $BD, $EE, $DB, $24, $66, $6D, $1B, $A6, $A4, $EE, $CC, $1A, $C4, $4B
	dc.b	$46, $6B, $C5, $C4, $5C, $E2, $6C, $ED, $DC, $CC, $2D, $C3, $A5, $64, $65, $DA, $55, $DC, $D2, $3D, $D0, $3B, $4C, $C0, $D0, $44, $B6, $0D, $B7, $5D, $DC, $DD
	dc.b	$CA, $BB, $1D, $D4, $65, $43, $3D, $5B, $AD, $CB, $9D, $AC, $53, $96, $45, $BA, $43, $65, $EE, $45, $CE, $DE, $DB, $9B, $C4, $A3, $55, $56, $22, $44, $CD, $BB
	dc.b	$54, $DE, $AB, $45, $31, $4E, $C4, $52, $53, $CD, $66, $DD, $9B, $CD, $DD, $44, $DC, $45, $25, $C4, $55, $0D, $CD, $DC, $03, $A4, $54, $46, $5D, $D3, $A5, $4D
	dc.b	$E3, $52, $DD, $0B, $DD, $CC, $44, $C3, $46, $54, $35, $4C, $CC, $91, $4E, $CA, $AD, $4C, $36, $EE, $56, $C5, $54, $C7, $6E, $EC, $BC, $ED, $CC, $AD, $3B, $66
	dc.b	$2D, $25, $56, $DE, $DA, $CE, $31, $26, $BB, $56, $5D, $DC, $66, $DF, $D6, $6C, $E5, $4E, $D0, $CB, $2E, $D5, $65, $64, $B1, $4B, $A9, $C5, $5E, $E4, $0B, $4A
	dc.b	$44, $ED, $66, $DA, $5A, $E6, $6C, $E2, $5E, $EA, $DC, $44, $24, $73, $DA, $55, $5C, $DE, $BD, $DB, $3C, $44, $42, $55, $DD, $D3, $56, $5D, $C5, $AC, $C5, $4D
	dc.b	$ED, $CC, $CD, $56, $59, $55, $D4, $3D, $43, $C5, $AE, $D3, $DE, $A3, $65, $B9, $55, $D5, $65, $C6, $6E, $ED, $0D, $ED, $EE, $55, $64, $7C, $EE, $54, $53, $DD
	dc.b	$DD, $CC, $54, $66, $DD, $66, $9D, $E2, $43, $CE, $C7, $5E, $E5, $6C, $EE, $DD, $BB, $66, $5B, $55, $D0, $66, $DD, $4B, $CE, $ED, $4D, $DD, $35, $2D, $66, $5A
	dc.b	$54, $96, $6D, $ED, $D2, $EE, $0C, $14, $4A, $65, $3C, $5A, $54, $DE, $CB, $DD, $55, $2C, $59, $56, $4C, $EA, $54, $BD, $D5, $6C, $EB, $5D, $DE, $DC, $4A, $45
	dc.b	$6A, $55, $C1, $65, $DD, $D9, $65, $F4, $CE, $CD, $36, $6E, $D7, $3D, $56, $D3, $6C, $EE, $D0, $DD, $ED, $B6, $64, $57, $D9, $C3, $54, $BE, $F3, $DD, $56, $3C
	dc.b	$5C, $D6, $65, $AD, $C4, $4C, $ED, $66, $EE, $65, $CD, $EE, $DC, $D5, $75, $25, $3C, $45, $3D, $CC, $B3, $ED, $6D, $DB, $A6, $61, $E6, $6C, $D5, $5B, $5A, $DE
	dc.b	$F0, $5E, $B4, $D9, $65, $36, $6C, $C2, $AA, $1D, $DD, $BC, $35, $42, $25, $AC, $03, $CE, $26, $51, $CD, $55, $4C, $A4, $DE, $DB, $D0, $0C, $56, $41, $45, $2C
	dc.b	$2B, $4C, $D5, $3E, $D5, $DD, $43, $56, $ED, $66, $B3, $52, $D5, $5D, $EE, $6D, $FD, $B4, $63, $51, $64, $AC, $5B, $50, $EE, $CB, $D5, $64, $CA, $2C, $63, $5C
	dc.b	$EC, $66, $2C, $D1, $5B, $ED, $6E, $ED, $DE, $53, $56, $6A, $35, $9A, $45, $A0, $DD, $4C, $DA, $4E, $C1, $44, $6D, $A6, $9D, $46, $44, $6C, $EE, $D4, $CD, $CD
	dc.b	$C2, $54, $A6, $4E, $D6, $52, $3D, $DC, $0D, $44, $CC, $54, $C5, $64, $2E, $36, $6E, $DD, $46, $5E, $EB, $EE, $CC, $E6, $54, $66, $A1, $5C, $D2, $44, $5C, $D5
	dc.b	$CE, $C5, $DB, $43, $34, $CC, $66, $E2, $6C, $C4, $BD, $DC, $4D, $DA, $BC, $45, $4D, $64, $49, $5C, $DC, $BC, $D9, $B4, $42, $D3, $54, $24, $BB, $E4, $66, $BD
	dc.b	$BC, $46, $EA, $5D, $EE, $DD, $56, $B5, $55, $44, $BD, $43, $9C, $DD, $55, $EC, $5D, $2A, $35, $3B, $D5, $53, $35, $6D, $46, $DE, $EA, $4F, $C3, $D4, $45, $D6
	dc.b	$6C, $05, $C2, $1C, $DE, $0B, $55, $44, $43, $32, $45, $AD, $D5, $53, $DE, $45, $6D, $E2, $CD, $DC, $CC, $5D, $A5, $65, $A4, $4C, $52, $3B, $E1, $5D, $E9, $50
	dc.b	$3C, $32, $5D, $36, $5B, $D6, $3D, $55, $EE, $EC, $BC, $BC, $46, $DC, $47, $33, $BC, $DC, $BB, $CD, $53, $C0, $54, $46, $CD, $C5, $BD, $B5, $5B, $EA, $55, $5D
	dc.b	$DD, $DD, $D2, $C3, $5C, $14, $54, $54, $C3, $44, $44, $E3, $4E, $D3, $B1, $3B, $44, $5E, $46, $6C, $15, $BB, $9D, $EE, $D6, $DB, $34, $24, $9D, $37, $CE, $D3
	dc.b	$55, $CE, $3D, $53, $35, $5C, $CC, $45, $54, $DE, $D6, $7E, $E2, $57, $1E, $EC, $DE, $E5, $DC, $4E, $46, $6D, $46, $45, $5A, $4C, $EC, $DE, $DB, $65, $40, $63
	dc.b	$5A, $64, $DE, $C3, $DC, $5D, $DD, $C6, $E4, $43, $2B, $DC, $C7, $5D, $EA, $25, $5B, $CD, $CD, $34, $44, $C3, $B9, $45, $5C, $57, $3F, $EC, $96, $6B, $CB, $DE
	dc.b	$C3, $DD, $DD, $C6, $5B, $54, $EB, $66, $62, $E4, $3E, $E4, $60, $B4, $5C, $DE, $A6, $6D, $D6, $AD, $54, $CC, $D5, $DE, $4D, $B4, $E4, $56, $64, $CC, $45, $2D
	dc.b	$D1, $22, $C4, $DD, $D4, $55, $0D, $4D, $D6, $6D, $D2, $1D, $55, $C1, $ED, $D3, $24, $5A, $C5, $4B, $26, $6C, $CC, $6B, $ED, $3C, $EE, $6C, $E4, $53, $55, $96
	dc.b	$64, $D5, $4D, $DC, $BB, $CD, $5E, $23, $0D, $BC, $B5, $64, $DD, $AA, $5B, $BA, $9C, $14, $53, $CC, $55, $B4, $50, $CB, $43, $EC, $44, $35, $DE, $D3, $ED, $59
	dc.b	$30, $C6, $64, $C3, $44, $53, $43, $BE, $E1, $DE, $95, $34, $56, $D5, $34, $65, $ED, $5A, $DC, $1C, $AD, $5C, $DD, $DE, $CC, $46, $66, $A0, $54, $5B, $1E, $DD
	dc.b	$CD, $B2, $41, $64, $64, $45, $DC, $35, $BE, $DC, $C6, $5E, $E3, $DE, $43, $A3, $B2, $66, $B0, $56, $41, $DC, $3C, $ED, $CE, $D5, $4C, $66, $3C, $6E, $56, $CD
	dc.b	$45, $CD, $EA, $4D, $D6, $D0, $9E, $EC, $D6, $56, $6D, $05, $65, $EA, $2E, $CD, $1D, $1C, $36, $66, $44, $2E, $A5, $CE, $D0, $B4, $4C, $E2, $59, $D3, $CD, $CC
	dc.b	$56, $6D, $40, $56, $4C, $55, $EE, $DC, $EB, $5A, $B4, $41, $26, $C6, $5D, $E5, $6D, $CB, $B4, $CE, $2E, $C0, $DD, $DC, $66, $66, $B9, $31, $CC, $BD, $D2, $CC
	dc.b	$35, $1D, $65, $B5, $60, $E1, $5B, $DE, $A3, $55, $AD, $DC, $DD, $6B, $DD, $D6, $24, $45, $56, $1C, $D5, $3E, $DC, $DE, $23, $44, $56, $D2, $6C, $45, $DD, $45
	dc.b	$CD, $B6, $D2, $DB, $DC, $0E, $DE, $C7, $56, $52, $B5, $42, $EC, $0C, $DD, $B4, $5B, $D6, $65, $4C, $BE, $C9, $6E, $E3, $54, $54, $4A, $DC, $E3, $AE, $CE, $56
	dc.b	$54, $55, $65, $1C, $23, $EE, $CD, $CD, $45, $45, $66, $E5, $3B, $4B, $EC, $5B, $EC, $56, $BE, $5B, $24, $DE, $EE, $66, $44, $34, $56, $39, $5B, $AE, $EC, $5A
	dc.b	$DC, $16, $5C, $56, $3E, $C3, $3E, $35, $30, $53, $EB, $DA, $D4, $EE, $A2, $56, $52, $55, $6C, $54, $5D, $EF, $1D, $D3, $66, $36, $59, $C5, $CB, $BD, $EB, $2D
	dc.b	$A4, $65, $CD, $3C, $DD, $EE, $CC, $66, $56, $55, $5B, $CB, $13, $ED, $AC, $CD, $A4, $66, $BD, $53, $DD, $35, $0C, $2C, $23, $6B, $EC, $9D, $C4, $DA, $35, $53
	dc.b	$32, $46, $DD, $CB, $3D, $DD, $44, $9C, $55, $46, $5E, $E6, $DD, $5B, $14, $54, $2C, $45, $DD, $CD, $ED, $ED, $C6, $65, $65, $40, $4C, $DD, $5A, $DD, $42, $4C
	dc.b	$3D, $56, $5B, $34, $DD, $DA, $5C, $CC, $CB, $64, $E3, $05, $DC, $EC, $B4, $69, $45, $54, $40, $5C, $9C, $DD, $DC, $BC, $44, $34, $6D, $C4, $9B, $52, $E5, $55
	dc.b	$BD, $41, $BD, $2C, $DE, $DE, $05, $65, $55, $55, $3C, $DD, $96, $DE, $4C, $C5, $61, $26, $BD, $C9, $BD, $DD, $51, $C4, $51, $65, $EE, $BC, $CD, $CD, $52, $45
	dc.b	$56, $54, $5C, $C3, $DB, $DD, $EB, $AB, $B5, $55, $54, $DD, $5D, $55, $DD, $05, $4D, $D6, $54, $CB, $BD, $DE, $ED, $56, $54, $56, $1A, $C3, $B3, $4E, $DB, $D4
	dc.b	$44, $34, $64, $DC, $AC, $ED, $C6, $54, $45, $25, $9E, $DD, $CC, $ED, $B5, $45, $65, $50, $52, $2D, $B0, $9D, $ED, $54, $41, $53, $B5, $5E, $35, $D5, $4E, $D4
	dc.b	$43, $BD, $66, $CE, $CB, $EE, $DE, $66, $55, $56, $2C, $03, $31, $C4, $CD, $DD, $C4, $43, $B5, $5A, $B1, $1D, $CB, $54, $92, $3B, $44, $DD, $C0, $3D, $EC, $45
	dc.b	$53, $06, $45, $3B, $93, $2A, $DD, $BA, $AB, $D5, $5C, $34, $CC, $4C, $C5, $BB, $CC, $55, $44, $4C, $CD, $EC, $DD, $03, $A6, $34, $65, $9C, $5C, $0B, $5A, $CD
	dc.b	$CC, $C9, $50, $45, $4D, $CC, $DD, $35, $55, $CB, $24, $3B, $ED, $D4, $CB, $2C, $34, $44, $55, $55, $5B, $3B, $1D, $EC, $CB, $EC, $45, $C4, $65, $4C, $B3, $54
	dc.b	$DD, $E4, $63, $C5, $30, $CD, $BE, $EE, $B4, $66, $35, $62, $C2, $B4, $4C, $3C, $ED, $42, $45, $53, $5A, $CD, $CD, $EC, $C5, $5C, $00, $A0, $00, $02, $A0, $02
	dc.b	$A0, $2A, $20, $A3, $D5, $D5, $CA, $4C, $33, $A3, $B3, $C4, $D4, $3B, $4B, $3B, $4B, $B4, $D4, $D5, $C5, $C4, $C2, $3B, $3A, $B3, $3D, $5C, $03, $3C, $3A, $C5
	dc.b	$D2, $4A, $C4, $D5, $CB, $5B, $4D, $4E, $6D, $5C, $44, $2B, $C3, $C3, $93, $B3, $04, $AB, $1C, $C4, $A3, $5D, $9B, $5C, $AB, $24, $C3, $4D, $5C, $23, $C3, $C5
	dc.b	$D5, $D4, $C5, $D2, $2C, $5D, $5D, $4C, $5D, $43, $C5, $1D, $4C, $11, $C5, $C4, $A9, $D5, $C4, $A4, $D4, $D5, $D4, $3A, $B2, $4C, $B5, $CB, $5D, $A4, $3D, $6E
	dc.b	$5A, $4D, $5D, $5A, $D6, $DB, $2C, $04, $C4, $2B, $3D, $14, $0A, $0C, $45, $E5, $B0, $A0, $3B, $5C, $4D, $23, $2A, $B5, $E6, $E6, $D4, $B4, $AA, $D5, $D4, $C4
	dc.b	$34, $D4, $4D, $51, $B3, $D5, $C5, $E6, $D1, $A4, $AC, $4D, $6E, $6E, $5D, $5C, $B4, $C4, $C4, $D6, $E5, $C3, $B5, $D6, $E6, $E4, $3B, $5B, $D5, $D5, $E5, $1A
	dc.b	$22, $C6, $E6, $E5, $D4, $B4, $D4, $3D, $6D, $45, $E6, $E1, $6F, $6C, $B6, $E5, $9B, $5E, $54, $D6, $EB, $6E, $6E, $C7, $EC, $5E, $6E, $6C, $E6, $D6, $2F, $7F
	dc.b	$70, $F7, $F7, $CE, $7F, $6C, $E7, $F7, $CF, $7F, $7C, $F7, $F6, $6F, $7F, $7C, $E6, $F7, $F7, $E5, $4D, $6D, $D6, $F7, $E6, $DE, $6E, $7F, $66, $F7, $F6, $6F
	dc.b	$7F, $65, $F7, $F6, $4A, $33, $3B, $6E, $C6, $E6, $E3, $5E, $6E, $45, $9D, $35, $E7, $F5, $6E, $6E, $C6, $E6, $E4, $B6, $E6, $DE, $7F, $63, $E7, $F6, $DD, $6E
	dc.b	$64, $4F, $7E, $D7, $F7, $EE, $6F, $7E, $56, $F6, $53, $F7, $F7, $DE, $7F, $6C, $E7, $F7, $BE, $6D, $D5, $5F, $7F, $73, $F7, $F6, $3C, $6E, $6E, $6E, $6E, $C7
	dc.b	$F7, $EE, $6F, $7E, $56, $F7, $D2, $E7, $F7, $F3, $6F, $7E, $D7, $F7, $DD, $2C, $B5, $5F, $7F, $7C, $E6, $F7, $DB, $6F, $7E, $5F, $7F, $72, $E7, $F6, $DE, $7F
	dc.b	$7C, $E6, $E5, $D6, $F7, $F7, $3F, $7F, $65, $E6, $E6, $3C, $E6, $DD, $7F, $7E, $D6, $F7, $E4, $6F, $7D, $2F, $7F, $66, $F8, $FB, $4F, $7E, $C6, $E5, $61, $F7
	dc.b	$F5, $7F, $7E, $E7, $F4, $52, $E6, $E5, $7F, $65, $F6, $40, $E6, $DC, $6E, $53, $3D, $5D, $5C, $B2, $C5, $3E, $6E, $54, $B0, $A2, $C5, $E6, $D3, $2B, $32, $C5
	dc.b	$E6, $D4, $01, $4D, $5A, $D5, $D1, $4C, $B3, $0C, $5D, $5B, $3A, $2B, $92, $3D, $5C, $A4, $BC, $5D, $B5, $E6, $D3, $5D, $5B, $D5, $3D, $51, $D5, $DA, $5D, $5D
	dc.b	$42, $D5, $D5, $B4, $D5, $CB, $5D, $33, $C5, $D5, $C1, $0C, $5D, $5D, $42, $C5, $D4, $C5, $D3, $4D, $5C, $04, $D5, $D5, $CB, $4C, $4C, $4B, $4B, $A3, $C4, $BB
	dc.b	$5D, $33, $D5, $BC, $4B, $B4, $B1, $3B, $14, $BB, $3B, $2A, $4C, $22, $C4, $BA, $3C, $32, $A3, $A0, $93, $B4, $C4, $BC, $5C, $A3, $C2, $3A, $92, $C4, $B2, $2B
	dc.b	$12, $A3, $91, $A2, $B3, $B3, $0B, $29, $2A, $92, $B2, $10, $94, $D4, $4C, $4C, $A4, $1B, $01, $B3, $2C, $3B, $2B, $4C, $B5, $D3, $33, $4C, $B4, $1D, $5B, $CA
	dc.b	$35, $DC, $53, $2E, $53, $43, $D5, $D3, $4C, $4D, $5B, $C3, $C5, $DA, $5D, $5C, $B5, $B4, $D4, $BA, $4D, $5D, $25, $4E, $35, $24, $E4, $5A, $0D, $5C, $B5, $CC
	dc.b	$B5, $5E, $5D, $45, $E5, $5B, $CC, $5D, $4A, $2C, $C6, $DE, $6C, $5C, $E6, $49, $D4, $4D, $5D, $4D, $55, $E5, $3A, $5E, $6B, $CC, $C6, $E4, $4C, $C3, $6F, $65
	dc.b	$B4, $E6, $9B, $DC, $6E, $44, $0C, $55, $F6, $44, $CE, $7D, $3E, $55, $E4, $C6, $E5, $5F, $7E, $6D, $E6, $C6, $E9, $5E, $6E, $6E, $65, $F7, $F7, $ED, $6E, $7F
	dc.b	$55, $E6, $E6, $E6, $6F, $64, $6F, $C6, $24, $F7, $EE, $7C, $4F, $76, $87, $6C, $DE, $7E, $AD, $69, $F7, $C6, $F6, $7F, $E7, $D3, $F7, $DE, $6D, $6F, $56, $3E
	dc.b	$57, $B8, $77, $EF, $76, $F4, $C7, $FE, $7D, $E3, $67, $FF, $8E, $FE, $8F, $F7, $4C, $F6, $6E, $B6, $57, $8C, $8F, $EA, $7F, $D7, $3F, $E7, $D9, $43, $57, $85
	dc.b	$7E, $D0, $7F, $16, $6F, $D7, $ED, $44, $37, $86, $7E, $E6, $6F, $56, $6F, $D7, $ED, $6D, $C7, $87, $6E, $E7, $4F, $66, $3F, $65, $F6, $6D, $C6, $88, $4E, $F7
	dc.b	$2E, $66, $DF, $7C, $EC, $6E, $66, $87, $6D, $E7, $DE, $57, $EF, $67, $FD, $6E, $66, $87, $7E, $F7, $5F, $66, $2F, $57, $F5, $6E, $D7, $FD, $7E, $2E, $7F, $6C
	dc.b	$7E, $E6, $D4, $E6, $E6, $68, $75, $5F, $66, $E6, $E7, $F5, $D6, $D5, $CD, $65, $F5, $6D, $5F, $7D, $3E, $6B, $D6, $E6, $D4, $E6, $D1, $B5, $0C, $3D, $6E, $6E
	dc.b	$6D, $CD, $54, $E6, $E6, $B3, $D5, $2D, $5D, $5D, $6E, $40, $4C, $C5, $E6, $D5, $E6, $D5, $E6, $D5, $D2, $5D, $5E, $6E, $6E, $6D, $A6, $2E, $46, $DE, $5C, $6E
	dc.b	$A5, $4D, $D6, $E5, $E7, $E0, $D6, $E4, $6D, $F7, $D6, $F6, $4A, $D5, $6E, $C6, $BE, $64, $F4, $7E, $F7, $A3, $F7, $D5, $E7, $DE, $55, $CE, $6B, $C6, $58, $74
	dc.b	$6F, $7D, $DD, $66, $F3, $7D, $F6, $5D, $C7, $FE, $74, $EE, $7B, $E3, $65, $F6, $6E, $E5, $5E, $66, $87, $56, $F6, $7F, $E6, $6D, $E7, $DF, $56, $5F, $74, $87
	dc.b	$66, $F5, $7F, $D6, $6E, $E7, $DE, $C6, $5F, $75, $87, $66, $F3, $7E, $E3, $6B, $E7, $DE, $E6, $6F, $57, $FE, $76, $EF, $75, $F4, $57, $F4, $6C, $F4, $7E, $E6
	dc.b	$78, $67, $5F, $D7, $DF, $B7, $5F, $66, $EE, $66, $FD, $76, $87, $75, $FE, $7E, $ED, $74, $E5, $5D, $E6, $6E, $F7, $68, $77, $6F, $E7, $AF, $E7, $6E, $E7, $DE
	dc.b	$56, $DF, $67, $FE, $67, $98, $76, $5F, $57, $EE, $17, $FD, $66, $EE, $77, $8C, $67, $D8, $77, $EF, $67, $FE, $67, $FE, $76, $EF, $77, $81, $67, $28, $77, $DF
	dc.b	$47, $EF, $47, $BE, $56, $CF, $77, $FF, $57, $58, $74, $7F, $F8, $CF, $F7, $6D, $E6, $6F, $37, $68, $56, $7E, $F6, $7E, $F6, $7D, $FC, $75, $F5, $6A, $F3, $75
	dc.b	$86, $76, $FD, $57, $FF, $77, $DF, $57, $4F, $46, $DF, $57, $78, $25, $7D, $F6, $6D, $F5, $76, $FE, $76, $FE, $7D, $EE, $79, $68, $76, $5D, $F6, $7F, $E7, $63
	dc.b	$FC, $66, $F5, $6E, $EA, $7E, $6E, $D3, $70, $F6, $E6, $ED, $73, $EE, $55, $6E, $D3, $5C, $4D, $6B, $5F, $65, $5E, $CE, $7E, $D6, $25, $F5, $46, $CC, $DC, $55
	dc.b	$C5, $E2, $7F, $4E, $75, $FA, $55, $CE, $66, $F2, $C7, $DD, $E6, $6D, $4E, $5D, $C7, $FD, $27, $5F, $BD, $7E, $D6, $5C, $ED, $7C, $EE, $66, $D5, $E5, $C9, $D6
	dc.b	$68, $7C, $7F, $E5, $7C, $EC, $64, $EA, $C7, $E5, $E5, $53, $1E, $23, $B1, $D7, $CF, $6E, $7F, $5E, $7E, $D5, $6B, $EE, $67, $EC, $E6, $D6, $E5, $E5, $52, $DD
	dc.b	$7A, $87, $97, $F5, $E7, $EC, $D7, $1E, $D2, $7E, $CE, $6D, $6E, $5E, $96, $5D, $E2, $56, $1F, $6C, $7F, $3E, $7E, $C0, $55, $E4, $A6, $EC, $D7, $E4, $E6, $BE
	dc.b	$64, $5E, $DB, $6C, $16, $EE, $62, $6F, $6E, $7F, $6D, $6D, $D3, $54, $E5, $D6, $E6, $C3, $DA, $50, $CE, $6D, $5E, $64, $6F, $D6, $56, $F5, $D7, $F4, $C6, $CE
	dc.b	$64, $4E, $5A, $6E, $BC, $6D, $14, $D5, $E6, $C0, $D4, $45, $4F, $6C, $7F, $D9, $65, $E4, $D6, $E5, $D6, $D4, $D5, $5D, $BD, $60, $BC, $39, $4C, $CA, $5B, $CD
	dc.b	$6C, $F7, $D6, $F5, $D7, $DD, $D5, $5D, $2D, $6D, $5E, $6B, $5E, $4D, $6D, $4D, $42, $42, $C4, $D4, $C5, $3D, $C4, $55, $CF, $56, $0A, $E4, $62, $DD, $63, $CE
	dc.b	$56, $CE, $D6, $51, $E3, $55, $EC, $55, $CE, $55, $4C, $E5, $44, $D3, $43, $DA, $A5, $35, $EE, $65, $5E, $E6, $55, $EA, $54, $DE, $65, $9E, $C6, $5D, $E4, $6A
	dc.b	$DC, $55, $DD, $95, $5D, $D1, $54, $CC, $44, $CC, $14, $4D, $C4, $6D, $E5, $55, $EE, $65, $5E, $C1, $6D, $DC, $55, $DD, $B6, $4D, $D5, $5B, $DC, $55, $DD, $25
	dc.b	$3B, $D4, $44, $DC, $44, $AC, $A5, $CB, $2A, $4C, $3B, $5D, $D5, $A5, $E5, $D6, $D1, $C2, $5C, $2D, $6C, $3E, $45, $4C, $D5, $24, $E4, $45, $CD, $14, $5D, $C2
	dc.b	$50, $CC, $44, $BC, $C5, $C2, $C4, $4C, $AB, $49, $2C, $39, $22, $4D, $B3, $44, $DA, $B5, $BA, $C4, $4B, $BD, $54, $3C, $C3, $33, $CB, $15, $CC, $B3, $4B, $9C
	dc.b	$5B, $2D, $43, $3B, $C3, $33, $BC, $24, $2B, $B2, $39, $B1, $03, $B9, $39, $00, $01, $B2, $1A, $2A, $A3, $A2, $AA, $3A, $2B, $3A, $3B, $00, $02, $0A, $91, $2A
	dc.b	$2B, $3A, $2A, $2A, $2A, $02, $A2, $A2, $A2, $A2, $A2, $A2, $A2, $A0, $2A, $00, $2A, $2A, $2A, $00, $02, $0A, $00, $2A, $09, $29, $2A, $2A, $2A, $02, $A2, $A0
	dc.b	$2A, $00, $20, $0A, $02, $A2, $A0, $2A, $00, $20, $0A, $2A, $2A, $00, $20, $A0, $20, $A0, $02, $0A, $00, $2A, $00, $02, $A0, $20, $0A, $02, $00, $A0, $20, $A2
	dc.b	$A2, $A2, $A2, $A2, $A2, $0A, $2A, $20, $A0, $02, $0A, $2A, $2A, $2A, $2A, $02, $A2, $A0, $2A, $00, $2A, $00, $20, $A0, $02, $A0, $02, $0A, $00, $20, $A0, $20
	dc.b	$A0, $02, $B4, $3C, $D3, $35, $BE, $45, $5C, $DC, $64, $DD, $B5, $5C, $E3, $64, $DD, $4A, $B6, $DE, $56, $DE, $54, $4B, $D4, $45, $EA, $55, $DC, $4C, $59, $E5
	dc.b	$54, $AE, $45, $32, $DA, $44, $AE, $46, $3D, $E6, $5D, $E5, $53, $DC, $54, $CC, $33, $53, $EA, $54, $CB, $C2, $52, $CC, $35, $CD, $23, $45, $9E, $44, $B4, $D4
	dc.b	$44, $3E, $93, $55, $E5, $94, $4E, $44, $24, $E4, $44, $5E, $30, $46, $E3, $C4, $5E, $4C, $46, $E4, $E5, $6E, $5E, $56, $E5, $14, $DD, $6D, $6E, $C4, $B5, $E5
	dc.b	$B4, $5E, $42, $46, $EC, $D5, $5D, $6D, $D6, $E6, $BE, $5E, $6B, $D5, $E6, $33, $AE, $60, $0D, $D4, $45, $5E, $3D, $66, $F4, $D6, $5E, $4E, $7C, $CB, $E5, $54
	dc.b	$ED, $16, $55, $F6, $E7, $5F, $1E, $66, $D9, $E6, $52, $CE, $46, $BD, $EC, $67, $ED, $E6, $6D, $DF, $65, $6B, $F7, $D6, $9F, $5A, $6C, $ED, $57, $E5, $F7, $6E
	dc.b	$CF, $65, $53, $F6, $56, $DE, $D6, $3C, $EC, $72, $4F, $57, $DD, $F6, $A7, $CF, $6D, $7E, $F6, $D7, $FE, $67, $D4, $EE, $74, $EE, $26, $6D, $F7, $E7, $EF, $6A
	dc.b	$6F, $D7, $C5, $5F, $67, $FB, $F7, $6D, $CF, $74, $DE, $D7, $5E, $F6, $7D, $CC, $F8, $CF, $DD, $75, $F5, $56, $EE, $C7, $CE, $E6, $7F, $78, $76, $2F, $34, $7E
	dc.b	$E5, $57, $FD, $65, $68, $79, $6F, $7F, $6C, $6D, $F7, $B6, $F5, $64, $DF, $7D, $6F, $55, $44, $E7, $F6, $15, $EA, $D7, $CF, $7E, $6F, $55, $5E, $E7, $E6, $E7
	dc.b	$F6, $E7, $EF, $66, $4F, $66, $DD, $E7, $EC, $E6, $4E, $7E, $78, $7E, $7F, $57, $5E, $F7, $E6, $F6, $5C, $E5, $6E, $C6, $35, $F7, $F7, $87, $07, $F3, $71, $4F
	dc.b	$54, $CC, $A5, $D5, $D6, $3E, $B5, $A4, $E6, $E6, $E5, $25, $9E, $6D, $5D, $5B, $B3, $B4, $C9, $C5, $D4, $04, $CA, $43, $AD, $B5, $CB, $03, $5E, $44, $4C, $D5
	dc.b	$4D, $4D, $6D, $1B, $42, $CA, $24, $C3, $B3, $C3, $4C, $2D, $5B, $B0, $42, $BA, $24, $C2, $C5, $BB, $A3, $B2, $B4, $C9, $24, $C3, $C5, $D3, $A4, $1D, $5B, $3B
	dc.b	$B4, $2C, $93, $93, $D5, $C4, $BA, $4C, $4C, $3B, $02, $2A, $B3, $32, $C2, $14, $CB, $23, $2A, $C4, $B4, $D5, $D5, $C4, $C4, $C3, $A0, $02, $A2, $A0, $31, $C4
	dc.b	$B4, $C2, $A3, $AB, $39, $3B, $0A, $3B, $39, $B3, $93, $C2, $02, $3C, $4B, $3B, $03, $B1, $2B, $3C, $33, $0C, $32, $3C, $30, $90, $B4, $AB, $A3, $21, $C4, $A2
	dc.b	$C3, $31, $CC, $6E, $5D, $5C, $3B, $40, $0C, $4D, $C5, $D6, $E6, $E6, $E6, $E6, $AB, $4D, $5D, $5D, $3C, $4B, $31, $D6, $E5, $D5, $1A, $4D, $5D, $5D, $5D, $45
	dc.b	$D5, $E6, $D5, $D1, $2C, $5C, $2D, $5D, $5D, $5D, $59, $D3, $C5, $C5, $E6, $D5, $DC, $43, $3B, $0C, $5A, $4E, $52, $5D, $3C, $5E, $6E, $6D, $4D, $4C, $5B, $D5
	dc.b	$B5, $D5, $E6, $D6, $E5, $E6, $D5, $4E, $6E, $6D, $4D, $A3, $24, $D5, $E6, $D6, $E5, $E6, $D5, $E6, $D6, $AD, $BD, $53, $4D, $3C, $44, $CB, $D6, $D5, $E6, $E6
	dc.b	$E6, $E6, $E6, $5E, $5E, $6A, $5E, $4D, $52, $5D, $D4, $3A, $5D, $C4, $B4, $CB, $25, $5E, $5E, $63, $4E, $5E, $6C, $5C, $BC, $5D, $5C, $AC, $4D, $5C, $34, $4D
	dc.b	$C4, $C6, $BE, $5D, $44, $D5, $C4, $4C, $94, $CB, $3A, $C5, $D6, $D3, $E6, $E6, $CB, $D4, $C6, $E6, $E6, $C4, $D5, $E6, $E6, $E6, $D6, $E5, $E6, $D5, $C4, $E6
	dc.b	$E6, $D4, $C5, $D5, $D5, $D4, $D5, $D5, $B6, $E3, $CC, $6D, $5D, $D4, $B2, $5D, $5D, $4A, $4D, $5E, $6D, $5D, $6E, $6F, $7E, $6C, $3E, $5E, $6D, $6E, $6E, $6E
	dc.b	$6E, $5D, $5D, $50, $5D, $D5, $E6, $43, $E9, $35, $D6, $E6, $E5, $C6, $E5, $E6, $E6, $C6, $E4, $E4, $5B, $6E, $E6, $D6, $2E, $5E, $65, $4E, $5E, $6E, $6C, $6F
	dc.b	$6E, $56, $D5, $ED, $6B, $5C, $E6, $D6, $1D, $D5, $D6, $E5, $E7, $E5, $F7, $F7, $E6, $F7, $E6, $E6, $F6, $56, $E4, $E5, $3B, $C3, $46, $E4, $E2, $6D, $6E, $94
	dc.b	$4B, $AE, $6D, $7F, $4E, $6D, $6E, $5E, $76, $FB, $DC, $7E, $6F, $46, $6E, $CF, $73, $6E, $EE, $75, $5F, $CC, $76, $DF, $E6, $97, $FE, $C7, $66, $FC, $D7, $6E
	dc.b	$F4, $67, $FF, $D7, $66, $DD, $F5, $54, $6F, $B6, $6B, $EE, $55, $7F, $EE, $67, $6F, $EC, $72, $5E, $5E, $5E, $6E, $7F, $6E, $7E, $5F, $7D, $6F, $4E, $74, $5F
	dc.b	$5E, $64, $5C, $6D, $EE, $7E, $7F, $C5, $5C, $4F, $7C, $6D, $FB, $66, $6F, $DB, $64, $5E, $D7, $ED, $E6, $D7, $FD, $37, $E6, $F7, $56, $FE, $E7, $6A, $FE, $67
	dc.b	$E0, $F6, $67, $FD, $E7, $44, $FE, $57, $E5, $F7, $7D, $FC, $D7, $3F, $E6, $66, $F2, $56, $1B, $6F, $CE, $79, $3F, $37, $6F, $CD, $75, $FE, $67, $6F, $FB, $76
	dc.b	$0F, $B6, $93, $D5, $6C, $F1, $65, $5F, $E7, $5B, $EB, $76, $FE, $C7, $6E, $F5, $56, $DD, $D5, $D5, $B6, $DE, $57, $87, $E7, $3E, $F7, $56, $FD, $67, $FE, $D7
	dc.b	$6E, $F6, $66, $EE, $55, $CE, $56, $5F, $D5, $65, $5D, $F6, $36, $EE, $47, $4D, $F6, $55, $FB, $67, $EE, $E7, $4D, $E6, $6C, $F3, $66, $EE, $D6, $6C, $DD, $56
	dc.b	$CF, $6D, $7F, $4E, $7D, $4F, $75, $5F, $54, $6E, $EB, $65, $DD, $64, $ED, $56, $4E, $E6, $62, $EC, $45, $DC, $46, $EE, $46, $5E, $CD, $7E, $4E, $63, $5F, $65
	dc.b	$6F, $C5, $63, $E3, $45, $DE, $46, $5E, $E6, $6C, $DD, $5C, $20, $52, $DD, $55, $6F, $D6, $35, $F6, $E7, $F6, $E7, $E4, $E6, $6D, $DE, $70, $3F, $65, $4E, $C6
	dc.b	$5C, $F6, $45, $D4, $31, $DC, $55, $CD, $D5, $5A, $CB, $20, $0A, $4A, $BC, $54, $F6, $45, $DE, $6D, $6E, $6E, $6D, $C5, $C6, $E3, $D6, $C0, $C4, $4D, $3D, $6D
	dc.b	$4E, $63, $2D, $A5, $D3, $04, $BC, $3B, $4C, $4C, $42, $0C, $02, $4B, $AD, $5B, $4B, $3D, $5C, $CB, $54, $2E, $44, $5C, $C2, $24, $D4, $A5, $D2, $D5, $24, $E5
	dc.b	$44, $EB, $64, $CD, $B5, $92, $E6, $34, $E9, $53, $3D, $5B, $AC, $44, $DA, $34, $9C, $33, $C4, $B2, $12, $C3, $03, $C4, $2C, $3C, $43, $BB, $13, $3C, $B4, $09
	dc.b	$C2, $4B, $2A, $B3, $33, $D2, $43, $2D, $14, $4C, $C3, $43, $D3, $04, $BA, $33, $D3, $34, $BC, $23, $4B, $CB, $44, $CB, $04, $2C, $2B, $40, $C3, $A3, $92, $C3
	dc.b	$23, $C3, $A2, $19, $A9, $23, $BA, $A4, $2C, $03, $2A, $C4, $09, $A9, $22, $91, $BA, $42, $CA, $33, $AC, $33, $2C, $23, $0A, $A3, $0B, $12, $2B, $93, $9A, $92
	dc.b	$29, $A2, $A2, $29, $B0, $32, $BB, $32, $9A, $02, $A2, $A9, $3A, $2A, $90, $21, $9B, $31, $9A, $02, $2B, $02, $01, $AA, $22, $9A, $93, $9B, $22, $1A, $A3, $9A
	dc.b	$2A, $02, $1B, $12, $2B, $93, $A9, $A3, $1B, $12, $1B, $12, $0A, $02, $A2, $A2, $0A, $02, $0A, $02, $0A, $92, $10, $A0, $2A, $00, $2A, $00, $2A, $2A, $20, $A0
	dc.b	$02, $A2, $A0, $20, $A0, $20, $A0, $20, $A0, $2A, $20, $A2, $A2, $A2, $A2, $0A, $2A, $02, $A2, $A2, $A0, $02, $A0, $02, $A0, $2A, $02, $0A, $02, $A0, $02, $0A
	dc.b	$02, $A0, $00, $02, $A0, $00, $2A, $02, $00, $A0, $2A, $00, $00, $00, $20, $A2, $A0, $02, $A2, $0A, $2A, $02, $A2, $A0, $2A, $2A, $2A, $00, $02, $A0, $00, $2A
	dc.b	$00, $00, $02, $A2, $A0, $00, $02, $A0, $2A, $00, $00, $2A, $02, $A2, $A0, $02, $A0, $00, $2A, $00, $2A, $00, $00, $2A, $02, $A0, $02, $A0, $00, $00, $00, $00
	dc.b	$2A, $2A, $02, $A0, $00, $2A, $2A, $2A, $00, $02, $A0, $00, $00, $02, $A2, $A0, $00, $02, $A2, $A2, $A2, $A0, $00, $2A, $02, $A0, $02, $A0, $02, $A2, $A0, $2A
	dc.b	$20, $A0, $2A, $02, $A0, $2A, $2A, $2A, $02, $A0, $00, $2A, $20, $A0, $2A, $00, $00, $00, $02, $A0, $20, $A0, $2A, $02, $A2, $A0, $2A, $00, $02, $A0, $02, $A2
	dc.b	$A0, $20, $A2, $A3, $C4, $4D, $A5, $CC, $43, $C9, $4A, $B2, $2B, $12, $0A, $21, $B1, $2A, $23, $D4, $5D, $C5, $9C, $41, $C1, $32, $0D, $53, $D4, $4C, $C5, $BC
	dc.b	$34, $CC, $43, $BB, $33, $C2, $4C, $03, $9A, $22, $C1, $5D, $B4, $3C, $24, $CA, $33, $BB, $4C, $94, $B9, $13, $BA, $24, $C9, $39, $A9, $3A, $B3, $3C, $31, $A0
	dc.b	$02, $0A, $21, $B3, $9B, $30, $B3, $A0, $2A, $20, $B4, $BB, $30, $A2, $A2, $A0, $3B, $A3, $A9, $21, $A0, $20, $A0, $20, $A0, $20, $B3, $1B, $03, $9A, $2A, $2A
	dc.b	$02, $A9, $29, $2A, $2A, $02, $0A, $00, $2A, $02, $A9, $39, $A2, $00, $A2, $1B, $21, $A2, $0A, $02, $A2, $0A, $20, $A0, $20, $A2, $00, $A2, $A2, $A2, $A2, $0A
	dc.b	$02, $0A, $02, $00, $A0, $2A, $20, $A9, $21, $A0, $2A, $00, $2A, $02, $A0, $2A, $00, $02, $0A, $2A, $00, $2A, $02, $0A, $02, $0A, $02, $00, $A2, $0A, $02, $A2
	dc.b	$A2, $0A, $02, $A0, $2A, $00, $20, $A0, $20, $A0, $2A, $00, $2A, $02, $0A, $20, $0A, $02, $A2, $A0, $2A, $02, $A0, $00, $02, $A2, $A2, $0A, $00, $20, $A0, $02
	dc.b	$A0, $20, $A0, $20, $A0, $20, $A0, $20, $A0, $2A, $00, $2A, $2A, $02, $A0, $02, $A0, $02, $A0, $20, $A0, $20, $A0, $2A, $02, $A2, $A2, $0A, $20, $0A, $02, $A2
	dc.b	$A2, $0A, $00, $00, $CD, $C0, $15, $7D, $F4, $66, $EE, $B5, $66, $3E, $EE, $57, $5F, $E2, $D7, $62, $FF, $77, $ED, $E4, $C6, $6E, $5E, $45, $D4, $76, $FB, $4D
	dc.b	$D9, $4B, $33, $5E, $36, $EE, $64, $DE, $75, $EE, $6C, $AE, $44, $57, $EF, $56, $5A, $F5, $C3, $43, $65, $3B, $EC, $66, $BF, $D6, $E6, $36, $EE, $B7, $1F, $A5
	dc.b	$EF, $66, $D6, $6E, $E4, $77, $DD, $4C, $4A, $BE, $F4, $77, $FF, $65, $C3, $3E, $44, $4F, $6D, $62, $C4, $D6, $2D, $D9, $57, $4E, $DD, $6E, $5F, $74, $5F, $5E
	dc.b	$6E, $56, $9D, $96, $54, $E7, $CF, $F6, $7E, $E6, $2A, $3C, $5E, $3E, $66, $F5, $E8, $DE, $F7, $6F, $E6, $6C, $D4, $69, $FD, $66, $55, $E4, $B3, $E6, $F7, $D2
	dc.b	$F7, $6F, $E6, $7B, $F2, $54, $70, $DF, $E5, $7C, $F4, $6C, $5F, $7E, $B6, $F6, $C6, $E7, $E4, $7E, $F7, $E4, $6E, $DB, $6D, $F7, $C5, $E7, $E2, $BD, $45, $5E
	dc.b	$EC, $5E, $5D, $7E, $55, $5F, $7E, $46, $F4, $C7, $D2, $EE, $46, $CE, $AD, $55, $5C, $64, $6D, $C4, $B4, $DE, $5D, $69, $E5, $BE, $5E, $43, $37, $DD, $B5, $BD
	dc.b	$0E, $6D, $6F, $63, $D3, $67, $EE, $E4, $63, $F4, $6D, $AA, $C7, $C6, $4F, $CD, $5D, $16, $57, $DE, $9B, $3E, $C6, $EF, $45, $7F, $6D, $D5, $6D, $E4, $7B, $EE
	dc.b	$C7, $26, $5F, $15, $51, $4C, $4B, $DD, $44, $ED, $C6, $C5, $F7, $E4, $D4, $D6, $5D, $6F, $44, $D5, $C6, $D3, $63, $62, $F5, $E6, $6D, $DC, $C2, $6E, $CD, $6D
	dc.b	$AE, $4B, $56, $E5, $64, $3B, $EB, $7E, $5F, $CD, $7C, $BF, $46, $E6, $4D, $57, $DD, $E6, $F7, $9C, $2D, $E6, $4E, $6D, $C5, $F7, $34, $BD, $DD, $76, $EE, $6C
	dc.b	$5E, $3E, $55, $4B, $D4, $5C, $5F, $56, $ED, $50, $A6, $D4, $4A, $35, $AD, $CB, $54, $DB, $E5, $BE, $50, $A7, $96, $D5, $4E, $D3, $DC, $DD, $D6, $64, $5D, $ED
	dc.b	$41, $D5, $56, $CE, $7D, $D1, $E6, $CD, $5F, $66, $4A, $ED, $4D, $54, $E6, $25, $33, $B0, $0B, $E6, $DE, $46, $C6, $D3, $C6, $ED, $B3, $6C, $E0, $61, $55, $CD
	dc.b	$B5, $CD, $E5, $4E, $DE, $7D, $6D, $2E, $46, $CD, $5B, $55, $4E, $46, $E6, $CD, $C6, $4B, $9C, $D9, $B5, $E4, $4D, $64, $DC, $ED, $45, $54, $C4, $E6, $CE, $5A
	dc.b	$56, $E6, $D4, $E7, $EB, $E3, $7F, $6E, $D6, $D5, $ED, $64, $C6, $D5, $55, $5D, $F6, $0D, $54, $4E, $D6, $AB, $F6, $DE, $55, $0C, $E9, $57, $D5, $62, $D4, $14
	dc.b	$9E, $BC, $7C, $5E, $D5, $1F, $74, $ED, $2E, $6B, $6E, $EC, $6E, $54, $C7, $EC, $B5, $6C, $D5, $E5, $D5, $D5, $5D, $DF, $73, $C2, $5C, $C6, $CE, $54, $EB, $15
	dc.b	$43, $6E, $EB, $66, $6E, $E6, $E6, $6E, $DB, $5E, $55, $CA, $DC, $E6, $3A, $AF, $66, $F5, $6E, $6D, $6B, $EC, $64, $5E, $56, $C6, $2E, $5B, $56, $E6, $DE, $64
	dc.b	$FC, $E5, $35, $6E, $5E, $E6, $5F, $6E, $56, $36, $DE, $C6, $BC, $B6, $55, $CD, $E3, $56, $E3, $95, $D9, $49, $54, $DD, $35, $DD, $4C, $04, $BD, $6E, $6E, $42
	dc.b	$5F, $26, $C6, $6D, $EE, $6E, $36, $3B, $25, $35, $5E, $C6, $44, $EE, $57, $F5, $DE, $6E, $39, $E7, $5E, $1D, $56, $E6, $EF, $74, $6E, $E5, $AD, $42, $C6, $D6
	dc.b	$E5, $6E, $C4, $4B, $6B, $E5, $A4, $3D, $4A, $93, $EE, $C5, $7D, $C3, $E5, $45, $EB, $D5, $7E, $BE, $56, $E4, $A4, $45, $DE, $96, $E6, $3E, $55, $5F, $25, $06
	dc.b	$5D, $F5, $D3, $55, $36, $E5, $BC, $6D, $45, $4C, $BE, $5D, $45, $23, $DE, $6F, $5B, $07, $DE, $E2, $52, $D6, $B9, $5E, $44, $53, $43, $45, $22, $CD, $6D, $E4
	dc.b	$35, $2D, $2D, $4A, $EC, $3C, $6A, $4C, $44, $99, $BD, $54, $C3, $B3, $B6, $2E, $EB, $35, $4D, $D1, $55, $44, $ED, $56, $25, $D0, $4A, $DD, $59, $6D, $4D, $D2
	dc.b	$C5, $4C, $C2, $CE, $55, $B4, $3B, $5D, $64, $1D, $1D, $F4, $56, $C6, $D3, $AE, $3D, $52, $BC, $56, $D3, $C4, $2D, $46, $D4, $DD, $54, $50, $D2, $9D, $CB, $56
	dc.b	$BB, $EB, $6B, $DD, $DD, $34, $AA, $A5, $45, $35, $D4, $12, $D5, $5B, $DD, $C5, $C5, $E5, $A9, $5E, $3B, $54, $CD, $44, $25, $3D, $6D, $6E, $C5, $2C, $DE, $54
	dc.b	$1E, $46, $DC, $5E, $7E, $53, $C5, $0C, $EC, $D6, $4E, $6C, $E5, $DD, $55, $65, $C5, $B3, $C1, $25, $D6, $DC, $CC, $DE, $42, $44, $C1, $D6, $DD, $55, $C3, $C5
	dc.b	$B4, $5C, $0E, $CD, $5D, $6E, $45, $4C, $5C, $E3, $45, $46, $ED, $53, $64, $31, $CE, $CB, $ED, $44, $55, $C4, $CD, $2D, $54, $6D, $54, $5C, $D4, $E5, $C6, $B5
	dc.b	$AD, $AC, $D6, $DD, $F6, $4D, $DD, $65, $5A, $5D, $E4, $6A, $D7, $B5, $E3, $E9, $CB, $CB, $56, $21, $43, $CD, $A9, $D5, $3A, $E5, $C6, $E6, $E4, $5D, $B4, $D3
	dc.b	$5D, $CD, $6B, $4E, $7D, $BC, $4D, $5E, $5E, $7E, $35, $CD, $D5, $B6, $D5, $45, $EC, $DD, $46, $E6, $4D, $4D, $6E, $D4, $B6, $6B, $ED, $5C, $44, $ED, $3D, $BB
	dc.b	$64, $55, $EB, $6A, $C6, $E5, $AC, $C5, $DD, $C6, $C3, $AC, $D4, $95, $D5, $4D, $5D, $34, $E5, $4D, $5D, $CB, $C6, $C4, $A4, $5C, $44, $E2, $91, $53, $5D, $2D
	dc.b	$33, $CB, $BB, $C3, $BC, $5B, $BB, $B5, $CD, $55, $45, $E5, $A5, $5D, $E5, $5E, $63, $CE, $6D, $4C, $D5, $E6, $4E, $6E, $D3, $04, $C5, $C3, $55, $C5, $5D, $D5
	dc.b	$CC, $36, $CD, $53, $D4, $4D, $DC, $B3, $B3, $DD, $45, $DA, $1C, $5B, $33, $4D, $6D, $53, $D3, $AD, $35, $35, $B5, $33, $53, $E9, $D5, $DC, $4D, $31, $A5, $9B
	dc.b	$CD, $E5, $00, $DB, $D5, $55, $32, $64, $5B, $CC, $5C, $1C, $34, $DD, $D4, $55, $CC, $DD, $C4, $3B, $4B, $4D, $3C, $31, $3D, $45, $55, $44, $D5, $D5, $44, $DE
	dc.b	$DD, $55, $33, $EC, $52, $D1, $64, $5E, $6E, $E4, $46, $A9, $6A, $AF, $65, $BB, $D5, $D5, $E2, $54, $CE, $4E, $45, $66, $DA, $59, $CD, $D6, $E7, $0B, $EE, $C3
	dc.b	$DC, $54, $55, $05, $BC, $4B, $EE, $7B, $EC, $CD, $3C, $DC, $7E, $06, $47, $E1, $E7, $DD, $AF, $7C, $E7, $E3, $D6, $CE, $CC, $DC, $55, $6C, $C6, $CE, $3F, $6D
	dc.b	$6C, $7F, $56, $5E, $A4, $E6, $6E, $E3, $55, $EE, $64, $4E, $E6, $5E, $B7, $D6, $A4, $F5, $D2, $5B, $E7, $BC, $D4, $DE, $74, $4D, $3E, $5B, $45, $9D, $3E, $C5
	dc.b	$5D, $D6, $E5, $DC, $D6, $CE, $65, $4D, $6E, $34, $64, $AE, $D6, $C5, $CE, $69, $5A, $F6, $5D, $E5, $4C, $65, $DE, $6D, $BB, $6E, $6C, $EE, $7E, $7F, $6E, $34
	dc.b	$C5, $E4, $6F, $6B, $46, $3E, $BE, $75, $E4, $DC, $C6, $36, $C3, $D4, $E3, $E6, $BE, $5D, $56, $DE, $45, $E6, $6A, $D5, $CD, $C5, $5C, $5E, $6D, $3D, $EC, $41
	dc.b	$6E, $7D, $6F, $64, $D4, $4C, $E5, $D4, $E6, $B4, $CC, $BB, $55, $5D, $CC, $D2, $55, $6B, $D1, $CB, $C4, $35, $DB, $C3, $C5, $CC, $EA, $5B, $55, $4E, $6C, $BB
	dc.b	$CC, $45, $D5, $D0, $54, $6E, $3C, $5B, $4E, $D4, $05, $EC, $6C, $15, $5D, $C4, $5E, $DD, $63, $43, $E5, $CA, $6C, $C5, $5E, $D2, $53, $04, $5C, $D6, $BE, $2E
	dc.b	$53, $5C, $CB, $3D, $C9, $6D, $45, $BD, $5E, $6E, $56, $C1, $CC, $35, $13, $4D, $33, $C0, $9D, $5C, $4B, $E4, $3D, $B5, $5D, $C6, $5C, $A2, $DC, $4C, $C9, $5C
	dc.b	$3D, $5D, $5A, $43, $5D, $4C, $55, $AD, $D9, $4B, $3B, $43, $DC, $BB, $A9, $4E, $45, $96, $4D, $C4, $3D, $4A, $04, $42, $CD, $B5, $B9, $5B, $6E, $5C, $D9, $5E
	dc.b	$5A, $5C, $3D, $BA, $C5, $B2, $3B, $4C, $BD, $44, $3D, $43, $25, $D5, $C5, $94, $D2, $D4, $D0, $4B, $50, $AB, $2B, $6D, $AD, $C3, $DC, $53, $34, $CD, $55, $3B
	dc.b	$44, $43, $E4, $D4, $DB, $BB, $45, $D5, $D2, $C5, $3C, $6E, $4B, $43, $CC, $36, $2B, $D5, $D9, $CA, $3D, $CD, $45, $AB, $45, $D5, $49, $B4, $CC, $6D, $15, $4C
	dc.b	$DD, $24, $1C, $E5, $BC, $53, $D3, $5B, $B4, $C4, $4D, $D5, $BB, $49, $5D, $4C, $26, $D3, $5B, $3A, $D5, $D6, $CE, $4C, $D3, $C5, $E6, $DC, $50, $4D, $6A, $D3
	dc.b	$34, $CB, $3D, $90, $BB, $63, $BC, $5C, $0E, $50, $5D, $D5, $34, $B1, $2C, $B4, $B4, $D5, $45, $E4, $22, $C4, $D4, $94, $D3, $3C, $02, $CD, $24, $35, $4C, $C4
	dc.b	$3C, $B3, $4B, $6D, $3C, $CD, $CD, $5B, $54, $4C, $42, $A6, $D4, $D3, $0D, $3D, $4C, $CD, $45, $DC, $35, $B5, $CA, $53, $16, $BB, $CD, $DA, $4C, $12, $C3, $3C
	dc.b	$33, $CC, $A5, $43, $44, $D4, $AC, $45, $CC, $2C, $CB, $3D, $4A, $BA, $43, $20, $BA, $54, $4D, $9D, $01, $5A, $49, $DD, $B5, $5C, $24, $DC, $44, $C5, $BC, $4B
	dc.b	$BD, $44, $32, $C0, $30, $BB, $44, $94, $C0, $BA, $33, $49, $BC, $C1, $BD, $54, $CC, $3A, $6E, $4B, $5D, $6B, $3E, $54, $EB, $59, $52, $3E, $02, $39, $44, $A5
	dc.b	$C3, $DD, $53, $D3, $5D, $56, $ED, $6D, $5D, $34, $E0, $B4, $23, $C4, $40, $C4, $DC, $5C, $B5, $5D, $C6, $CB, $E5, $2D, $54, $DC, $55, $2E, $5C, $A2, $15, $E6
	dc.b	$DD, $5C, $C6, $AD, $36, $E5, $C2, $53, $DD, $AB, $54, $D5, $24, $E5, $BD, $5B, $AC, $4E, $53, $C6, $D6, $D5, $BE, $49, $5E, $6D, $4C, $6D, $C5, $C5, $BD, $CA
	dc.b	$44, $4C, $EC, $4A, $53, $C0, $34, $D3, $C5, $A5, $AB, $A5, $CC, $B4, $5D, $9D, $D6, $4D, $D0, $D4, $54, $B2, $4D, $53, $3D, $5A, $BD, $C4, $5B, $D6, $C1, $CC
	dc.b	$C3, $3D, $5B, $34, $C3, $5D, $C2, $3B, $54, $CC, $CC, $5D, $25, $AB, $5D, $5E, $52, $AA, $A5, $43, $CD, $E5, $5C, $A4, $AD, $34, $44, $3D, $5B, $5D, $4D, $44
	dc.b	$9D, $C5, $D4, $B6, $DA, $BC, $BC, $4D, $45, $C5, $B0, $B4, $D5, $4A, $D0, $D4, $5C, $B3, $43, $CB, $4C, $4D, $42, $B3, $5B, $3D, $D1, $4C, $41, $D5, $05, $C4
	dc.b	$C4, $99, $3B, $CB, $31, $2D, $35, $B0, $C1, $C4, $04, $DC, $13, $5A, $B3, $CB, $5C, $5D, $5C, $DC, $43, $23, $C4, $A5, $BC, $2A, $51, $CD, $34, $B6, $BB, $BE
	dc.b	$C3, $4C, $C3, $5D, $45, $C5, $CD, $44, $9A, $B4, $34, $9D, $4B, $BC, $B5, $4C, $5D, $B4, $94, $CB, $3D, $B3, $CA, $16, $CD, $44, $C9, $5B, $DC, $C1, $52, $C5
	dc.b	$AA, $B4, $D5, $44, $C9, $D5, $CB, $41, $C1, $4C, $4C, $3B, $D2, $C6, $D5, $B3, $2D, $D6, $D3, $B5, $C9, $BC, $25, $CA, $5D, $5D, $D4, $6C, $D2, $A4, $5B, $CC
	dc.b	$09, $BB, $44, $CC, $CC, $A4, $D4, $45, $53, $C3, $3B, $BA, $0B, $CC, $C5, $D2, $C4, $24, $D4, $4A, $54, $D3, $25, $3C, $AA, $DC, $BC, $B4, $A3, $33, $33, $04
	dc.b	$3C, $BC, $3B, $94, $43, $4B, $4C, $BA, $90, $C4, $D1, $AC, $2D, $4A, $B4, $4B, $54, $23, $51, $AC, $4D, $3D, $3C, $AD, $4A, $32, $B4, $13, $41, $33, $BC, $4C
	dc.b	$DA, $D5, $3B, $3C, $4B, $44, $C5, $4A, $9B, $B1, $2A, $4D, $BC, $D5, $C3, $2C, $4B, $44, $10, $A4, $B4, $4B, $33, $2C, $BC, $DB, $C4, $02, $34, $41, $C4, $DA
	dc.b	$5D, $3C, $24, $5D, $33, $04, $4A, $D3, $4B, $D3, $5D, $B2, $13, $B1, $4A, $C4, $1D, $D4, $44, $B0, $50, $B5, $CA, $4B, $BA, $03, $2D, $D5, $DC, $42, $B2, $55
	dc.b	$DD, $55, $4C, $D4, $3C, $B4, $9C, $D5, $CC, $45, $DC, $36, $E5, $9C, $54, $CC, $A5, $2C, $BC, $54, $AD, $3D, $4A, $D5, $3A, $3C, $14, $94, $DC, $5C, $5C, $34
	dc.b	$BB, $DC, $5C, $6D, $42, $3E, $59, $D4, $9B, $45, $CB, $5D, $4D, $4A, $C4, $D0, $45, $D5, $C4, $DB, $5C, $4C, $34, $BC, $44, $C3, $4C, $3C, $C3, $D4, $C5, $4D
	dc.b	$33, $43, $B3, $4D, $29, $CC, $BC, $59, $21, $44, $D4, $D4, $3B, $22, $D4, $4B, $53, $1D, $4A, $41, $E5, $3C, $DB, $6C, $C4, $B5, $C4, $A4, $D4, $11, $DC, $93
	dc.b	$45, $C4, $4D, $D4, $4C, $D4, $45, $E5, $3D, $55, $D5, $CB, $D5, $4C, $DB, $44, $BC, $25, $4B, $CA, $5E, $44, $5D, $C4, $5D, $5B, $D0, $03, $BD, $C4, $A4, $44
	dc.b	$D5, $41, $D4, $D0, $5D, $43, $10, $95, $B3, $D3, $BD, $44, $CB, $32, $39, $4A, $05, $CB, $BB, $D9, $23, $B5, $5C, $CC, $5D, $51, $C0, $BD, $5C, $5B, $C3, $A4
	dc.b	$59, $3D, $B3, $D4, $3B, $D3, $34, $93, $92, $13, $D3, $3A, $B1, $2A, $5C, $3C, $5D, $0A, $AC, $12, $44, $CB, $43, $B5, $1B, $AD, $5D, $3C, $C5, $3C, $4C, $D4
	dc.b	$B6, $D5, $DC, $94, $5C, $C4, $D3, $4B, $1C, $34, $B4, $0D, $39, $A9, $53, $D4, $92, $9D, $12, $C3, $5C, $5C, $C5, $D4, $9D, $53, $D4, $24, $BD, $25, $D5, $C3
	dc.b	$2B, $1D, $6C, $CA, $4C, $3C, $C4, $C4, $5A, $DA, $C3, $54, $2B, $C3, $90, $C3, $4C, $CC, $25, $4D, $5D, $C9, $53, $CA, $5C, $BD, $40, $B5, $BB, $B0, $35, $D1
	dc.b	$23, $D1, $B3, $55, $DD, $5C, $30, $A3, $24, $DB, $01, $A6, $DD, $5D, $4A, $32, $D5, $3C, $BC, $A5, $44, $CD, $5D, $C4, $A5, $3C, $CA, $95, $D5, $D5, $D4, $D5
	dc.b	$C4, $4C, $B4, $4D, $5C, $CC, $33, $02, $44, $CB, $CB, $35, $D4, $D4, $53, $CD, $4B, $24, $5B, $CC, $A4, $D4, $D5, $5D, $44, $D3, $3C, $C5, $CB, $31, $12, $A4
	dc.b	$D5, $CC, $93, $45, $9C, $C5, $AD, $C9, $C5, $5C, $CC, $4B, $B5, $D5, $C4, $CD, $32, $44, $4C, $A3, $B5, $CE, $16, $3B, $DC, $5B, $43, $9A, $D2, $13, $DB, $33
	dc.b	$44, $34, $49, $BD, $C2, $23, $CC, $53, $DA, $41, $9D, $44, $4A, $D5, $4D, $B1, $35, $4A, $BD, $4D, $C5, $4A, $DC, $36, $BD, $5C, $CB, $2C, $44, $A5, $CB, $5B
	dc.b	$C0, $AD, $A3, $3C, $A3, $B3, $33, $5B, $34, $D4, $3A, $CC, $C2, $3D, $4B, $3C, $4B, $24, $94, $5C, $3B, $A4, $AC, $3B, $CD, $34, $B2, $CA, $50, $C0, $44, $5C
	dc.b	$BD, $44, $D4, $4D, $B1, $24, $4C, $1B, $BB, $C2, $34, $22, $4B, $14, $9C, $B3, $2A, $AC, $C5, $C5, $1C, $BB, $1B, $C4, $0B, $23, $24, $3D, $5B, $30, $0B, $C9
	dc.b	$34, $3C, $24, $1C, $AC, $2B, $A9, $CB, $93, $49, $5C, $5C, $3B, $0C, $34, $CB, $4A, $1C, $5C, $C0, $94, $4D, $2B, $5B, $3C, $C5, $C3, $CA, $4C, $4D, $03, $B5
	dc.b	$10, $1A, $C9, $BC, $14, $24, $02, $33, $40, $BC, $CB, $AB, $29, $22, $2B, $94, $43, $CC, $40, $3A, $2C, $BB, $34, $93, $00, $2B, $BC, $CB, $34, $A4, $B4, $00
	dc.b	$99, $39, $1C, $13, $AA, $A2, $2A, $34, $91, $BC, $3B, $A4, $2B, $5C, $C4, $2D, $30, $2B, $B3, $BB, $A4, $4B, $42, $BB, $BC, $3C, $33, $C3, $4B, $40, $C4, $33
	dc.b	$CC, $43, $3C, $2B, $3B, $3B, $33, $D5, $B1, $3B, $A4, $0C, $C4, $90, $09, $BB, $3B, $30, $32, $20, $1A, $91, $1B, $A9, $4B, $BB, $92, $9A, $A4, $3B, $A3, $1B
	dc.b	$A5, $CA, $1B, $40, $B2, $0B, $43, $BB, $CC, $A2, $03, $B4, $4B, $21, $3A, $0A, $C1, $0B, $A3, $31, $B2, $22, $3A, $B4, $10, $B3, $30, $BB, $B9, $BC, $49, $42
	dc.b	$19, $22, $3B, $CA, $CB, $92, $32, $43, $BB, $00, $B3, $B3, $23, $0A, $03, $C1, $B4, $BA, $41, $A1, $9A, $3B, $BA, $B3, $A0, $23, $3C, $32, $4C, $43, $BA, $C3
	dc.b	$AB, $2C, $4A, $42, $C4, $C3, $B2, $4C, $3B, $BB, $3A, $3B, $4A, $3B, $4A, $B9, $A3, $B1, $0C, $42, $AB, $3B, $4B, $0A, $B9, $00, $2B, $20, $4A, $B3, $3A, $90
	dc.b	$C9, $B3, $94, $03, $3A, $A3, $9C, $3C, $AB, $4A, $B4, $2B, $4B, $29, $4B, $09, $1B, $19, $B3, $12, $A1, $2A, $B3, $B1, $AA, $23, $03, $39, $3B, $A3, $C2, $0C
	dc.b	$3A, $2C, $40, $BB, $22, $B5, $AC, $1C, $30, $AA, $4A, $23, $2C, $2A, $29, $3B, $0A, $C0, $22, $B3, $33, $B3, $30, $BB, $4C, $9A, $B2, $13, $B2, $43, $A3, $C4
	dc.b	$CB, $A2, $22, $A4, $2A, $1B, $0C, $22, $A3, $02, $93, $A9, $B0, $3B, $4C, $4B, $3B, $B3, $BB, $B4, $29, $32, $C3, $AB, $40, $BA, $9B, $3A, $4A, $99, $A9, $A3
	dc.b	$B4, $AB, $92, $92, $C3, $A3, $A2, $11, $31, $B4, $A0, $BB, $2A, $B1, $22, $1A, $00, $30, $0B, $03, $B2, $A1, $B1, $01, $33, $9B, $02, $0B, $3C, $3A, $22, $03
	dc.b	$94, $B1, $BB, $9B, $43, $C4, $AB, $B2, $01, $22, $B4, $B1, $0B, $A3, $32, $BB, $3B, $90, $22, $BA, $1B, $39, $94, $B3, $B0, $AA, $3A, $09, $B3, $B3, $A2, $33
	dc.b	$B3, $C3, $BB, $21, $32, $BB, $4C, $31, $C1, $03, $B4, $AB, $13, $1A, $A3, $3C, $2A, $33, $AA, $0A, $94, $AB, $B1, $13, $1B, $02, $AA, $3B, $40, $A2, $1B, $29
	dc.b	$AB, $90, $02, $02, $B3, $2B, $21, $20, $B3, $0B, $39, $3B, $2B, $2A, $B1, $29, $4A, $B0, $3A, $3C, $1B, $A4, $C0, $24, $B3, $AB, $00, $4B, $2B, $AB, $24, $BB
	dc.b	$3A, $2B, $A0, $33, $B3, $AA, $B3, $21, $20, $3B, $02, $0B, $AB, $03, $00, $03, $B3, $3B, $20, $C2, $93, $B0, $32, $B9, $3B, $32, $9B, $93, $A2, $93, $2B, $C2
	dc.b	$22, $B0, $23, $B3, $A2, $2A, $A4, $C4, $C3, $B1, $B0, $29, $B4, $BB, $33, $AB, $A2, $39, $2A, $9B, $3B, $3B, $31, $29, $02, $2C, $4B, $2B, $A3, $09, $31, $BA
	dc.b	$1A, $29, $03, $C2, $03, $2B, $32, $AA, $1C, $10, $29, $01, $32, $B2, $93, $1A, $B1, $A1, $3A, $12, $1B, $0B, $03, $02, $1B, $19, $2B, $3B, $32, $29, $1B, $A1
	dc.b	$3A, $B2, $0B, $3B, $2A, $B3, $03, $1A, $21, $00, $21, $AB, $3B, $90, $A1, $01, $0B, $3A, $13, $B3, $A1, $22, $B1, $9A, $00, $99, $21, $02, $22, $AA, $1B, $B2
	dc.b	$01, $90, $39, $10, $0B, $3B, $22, $A1, $20, $B9, $29, $01, $92, $2A, $3A, $A9, $99, $3A, $02, $91, $B2, $22, $B9, $01, $20, $91, $A1, $3A, $99, $10, $9B, $92
	dc.b	$22, $10, $19, $0A, $A1, $13, $A9, $01, $A3, $A9, $00, $A1, $10, $00, $1A, $09, $A2, $29, $00, $2A, $9A, $21, $91, $91, $99, $11, $01, $91, $00, $1A, $1A, $01
	dc.b	$1A, $20, $00, $A2, $0A, $19, $92, $19, $10, $A1, $00, $01, $09, $19, $19, $90, $10, $01, $09, $10, $90, $00, $19, $00, $00, $00, $19, $00, $00, $00, $00, $00
	dc.b	$09, $10, $00, $19, $19, $19, $00, $91, $00, $00, $01, $90, $19, $00
