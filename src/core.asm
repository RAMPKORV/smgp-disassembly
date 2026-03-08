Divide_fractional:
; Input D5 always swapped before call such that D5.high is the input and D5.low is always 0
; Returns:
; * D7.h = D5 / D6 (integer)
; * D7.l = fraction (value/2^16)
	MOVEQ	#0, D0
	SWAP	D5
	MOVE.w	D5, D0 ; D0.l = D5
	DIVU.w	D6, D0 ; D0.l = D5 / D6 (D0.h = remainder)
	MOVE.w	D0, D7 ; D7.l = D5 / D6 (D7.h after swap)
	SWAP	D5
	MOVE.w	D5, D0 ; D0.l = D5.l (always 0). So D0 = remainder << 16
	DIVU.w	D6, D0 ; D0.l = remainder / D6
	SWAP	D7     ; D7.h = D5 / D6
	MOVE.w	D0, D7 ; D7.l = remainder / D6 (from $0000 to $FFFF)
	RTS
Decompress_asset_list_to_vdp:
; Decompress and upload a list of compressed graphics assets directly to VRAM.
; Each list entry specifies a VRAM tile address and a compressed data pointer.
; A1 points to the list: first word is item count minus 1, followed by entries
; each containing a tile-index word and a long pointer to compressed source data.
; Inputs:
;  A1 = pointer to asset list (consumed)
	MOVE.w	(A1)+, D0
Decompress_asset_list_loop:
	MOVE.w	(A1)+, D7
	JSR	Tile_index_to_vdp_command(PC)
	MOVE.l	D7, VDP_control_port
	MOVEA.l	(A1)+, A0
	JSR	Decompress_to_vdp(PC)
	DBF	D0, Decompress_asset_list_loop
	RTS
	dc.b	$30, $19, $49, $F9, $00, $00, $07, $70, $60, $12
Draw_tilemap_list_to_vdp_64_cell_rows:
; Draw a list of pre-decompressed tilemaps to VRAM using 64-cell (512-byte) row strides.
; Inputs:
;  A1 = pointer to list: first word is item count minus 1, then per-entry:
;       tile-index word, width byte (tiles-1), height byte (rows-1), source ptr
	MOVE.w	(A1)+, D0
	LEA	Draw_tilemap_buffer_to_vdp_64_cell_rows, A4
	BRA.b	Draw_tilemap_list_loop
Draw_tilemap_list_to_vdp_32_cell_rows:
; Same as Draw_tilemap_list_to_vdp_64_cell_rows but with 32-cell (256-byte) row stride.
; Used for the normal H40/H32 background plane width (32 or 40 tiles wide).
	MOVE.w	(A1)+, D0
	LEA	Draw_tilemap_buffer_to_vdp_32_cell_rows, A4
Draw_tilemap_list_loop:
	MOVE.w	(A1)+, D7
	JSR	Tile_index_to_vdp_command(PC)
	MOVEQ	#0, D6
	MOVE.b	(A1)+, D6
	MOVEQ	#0, D5
	MOVE.b	(A1)+, D5
	MOVEA.l	(A1)+, A6
	JSR	(A4)
	DBF	D0, Draw_tilemap_list_loop
	RTS
Prng:
; Pseudo-random number generator (LCG-style).
;
; Maintains a 32-bit state in Saved_vdp_state.  On each call, advances the
; state using a multiply-by-41 recurrence (x = x*5 then x*8+x):
;   step 1: D1 = x*4 + x = x*5   (ADD.l twice then ADD.l original)
;   step 2: D1 = D1*8 + x*5 = x*41  (ASL.l #3 then ADD.l)
;   (correction: ADD D1+D1 = 2x, ADD again = 4x, ADD D0 = 5x; ASL*8=40x; ADD D0=41x)
; The high and low 16-bit halves are XOR-folded to produce a 16-bit output in D0.
; Returns: D0.w = 16-bit pseudo-random value.
; Uses: Saved_vdp_state ($FFFFFF18) as the PRNG state.
;       D0 = output, D1 = scratch (destroyed).
;       Default seed $2A6D365B used if state is currently zero.
	MOVE.l	Saved_vdp_state.w, D1
	TST.w	D1
	BNE.b	Prng_nonzero_seed
	MOVE.l	#$2A6D365B, D1
Prng_nonzero_seed:
	MOVE.l	D1, D0
	ADD.l	D1, D1
	ADD.l	D1, D1
	ADD.l	D0, D1
	ASL.l	#3, D1
	ADD.l	D0, D1
	MOVE.w	D1, D0
	SWAP	D1
	ADD.w	D1, D0
	MOVE.w	D0, D1
	SWAP	D1
	MOVE.l	D1, Saved_vdp_state.w
	RTS
Update_input_bitset:
; Read both controllers and update Input_state_bitset / Input_click_bitset.
;
; The controller data port ($A10003, $A10005) is on the 68K address bus, but
; the bus arbitration sequence (request Z80 bus, wait for grant) is required
; before accessing $A1xxxx ports because the Z80 also asserts the bus during
; its interrupt service.  The 68K holds Z80_bus_request while reading the
; two controller ports, then releases it immediately afterward.
;
; Outputs: Input_state_bitset (byte) = active-high button bits after NOT/EOR
;          Input_click_bitset  (byte) = bits that changed to pressed this frame
	MOVE.w	#$0100, Z80_bus_request
	BTST.b	#0, Z80_bus_request
	BNE.b	Update_input_bitset
	LEA	Input_state_bitset.w, A0
	LEA	Io_ctrl_port_1_data, A1 ; Controller 1 data
	JSR	Read_controller_input(PC)
	ADDQ.w	#2, A1 ; Controller 2 data
	JSR	Read_controller_input(PC)
	MOVE.w	#0, Z80_bus_request
	RTS
Read_controller_input:
	MOVE.b	#$40, (A1)
	NOP
	NOP
	MOVE.b	(A1), D0
	MOVE.b	#0, (A1)
	NOP
	NOP
	MOVE.b	(A1), D1
	ASL.w	#2, D1
	ANDI.w	#$003F, D0
	ANDI.w	#$00C0, D1
	OR.w	D1, D0
	NOT.w	D0
	EOR.b	D0, (A0)
	MOVE.b	(A0), D1
	MOVE.b	D0, (A0)+
	AND.w	D1, D0
	MOVE.b	D0, (A0)+
	RTS
Initialize_vdp:
; Write the 19-entry VDP register initialisation table at Vdp_init_register_table to the
; VDP control port one word at a time, then clear 64 words of VRAM at address
; $C0000000 (VRAM write mode).  Called once at boot from EntryPoint.
	LEA	Vdp_init_register_table(PC), A0
	MOVEQ	#$00000012, D0
Initialize_vdp_reg_loop:
	MOVE.w	(A0)+, VDP_control_port
	DBF	D0, Initialize_vdp_reg_loop
	MOVE.l	#$C0000000, VDP_control_port
	MOVEQ	#$0000003F, D7
Initialize_vdp_vram_loop:
	MOVE.w	#0, VDP_data_port
	DBF	D7, Initialize_vdp_vram_loop
	RTS
Initialize_h40_vdp_state:
; Set the VDP to H40 (320-pixel wide) mode and DMA-clear VRAM.
; Writes mode register $85 ($8576+1) for H40, $8C81 for H40 cell width,
; $8D3C for hscroll table at $E000.  Stores H40 column count ($50 = 80 bytes/row)
; and tile count ($01C0 = 448) for the DMA transfer size.  Then DMA-fills VRAM.
	LEA	VDP_control_port, A0
	MOVE.w	#$857A, (A0)
	MOVE.w	#$8C81, (A0)
	MOVE.w	#$8D3C, (A0)
	BSR.b	Reset_vdp_update_state
	MOVE.w	#$0050, Vdp_plane_row_bytes.w
	MOVE.w	#$01C0, Vdp_plane_tile_count.w
	MOVE.l	#$943793FF, D6
	BRA.b	Initialize_vdp_dma_common
Initialize_h32_vdp_state:
; Set the VDP to H32 (256-pixel wide) mode and DMA-clear VRAM.
; Writes $8576 for H32 mode, $8C00 for H32 cell width, $8D3A for hscroll table.
; Stores H32 column count ($40 = 64 bytes/row) and tile count ($0180 = 384).
	LEA	VDP_control_port, A0
	MOVE.w	#$8576, (A0)
	MOVE.w	#$8C00, (A0)
	MOVE.w	#$8D3A, (A0)
	BSR.b	Reset_vdp_update_state
	MOVE.w	#$0040, Vdp_plane_row_bytes.w
	MOVE.w	#$0180, Vdp_plane_tile_count.w
	MOVE.l	#$942D93FF, D6
Initialize_vdp_dma_common:
	MOVE.l	#$40000083, D7
	JMP	Start_vdp_dma_fill(PC)
Reset_vdp_update_state:
; Reset VDP display state, zero screen state variables, and clear the sprite
; attribute table scratch buffer.
; Disables interrupts (ORI #$0700,SR), then:
;  - $8134: mode register 1 (H-int disabled, display on)
;  - $8004: mode register 2 (DMA disabled, PAL=0)
;  - $8AFF: H-interrupt every line (register $0A = $FF)
;  - $40000010: VRAM write at $0010 (clear 1 longword = sprite attr table base)
; Then clears $40×4 = $100 bytes from Screen_timer ($FFFFFF00 area),
; and $A0×4 = $280 bytes from $FFFF9AC0 (sprite attribute table buffer).
	ORI	#$0700, SR
	MOVE.w	#$8134, VDP_control_port
	MOVE.w	#$8004, VDP_control_port
	MOVE.w	#$8AFF, VDP_control_port
	MOVE.l	#$40000010, VDP_control_port
	MOVE.l	#0, VDP_data_port
	LEA	Screen_timer.w, A0
	MOVE.w	#$003F, D0
Reset_vdp_screen_clr_loop:
	CLR.l	(A0)+
	DBF	D0, Reset_vdp_screen_clr_loop
	LEA	Sprite_attr_buf.w, A0
	MOVE.w	#$009F, D0
Reset_vdp_sprite_clr_loop:
	CLR.l	(A0)+
	DBF	D0, Reset_vdp_sprite_clr_loop
	CLR.w	Audio_engine_flags
	RTS
Copy_word_run_from_stream:
	MOVEQ	#0, D0
	MOVEQ	#0, D1
	MOVE.b	(A6)+, D0
	MOVE.b	(A6)+, D1
Copy_word_run_to_buffer:
	LEA	Palette_buffer.w, A5
	ADDA.w	D0, A5
Copy_word_run_loop:
	MOVE.w	(A6)+, (A5)+
	DBF	D1, Copy_word_run_loop
	RTS
Upload_palette_buffer_to_cram:
; DMA the 64-entry (128-byte) palette buffer at $FFFFE980 to CRAM.
; Spins for ~$400 cycles first if Pal_flag is set (PAL timing compensation).
; Uses Send_D567_to_VDP with D5=$94009340, D6=$96F495C0, D7=$977F and
; Vdp_dma_setup=$C0000080 (CRAM DMA transfer mode).
	MOVE.w	#$0400, D0
	TST.b	Pal_flag.w
	BEQ.b	Upload_palette_dma
Upload_palette_pal_wait:
	DBF	D0, Upload_palette_pal_wait
Upload_palette_dma:
	MOVE.l	#$94009340, D5
	MOVE.w	#$977F, D7
	MOVE.l	#$96F495C0, D6
	MOVE.l	#$C0000080, Vdp_dma_setup.w
	JMP	Send_D567_to_VDP(PC)
Upload_palette_buffer_to_cram_delayed:
; Same as Upload_palette_buffer_to_cram but with a shorter ~$320 spin delay.
; Used in contexts where less PAL-mode wait time is needed.
	MOVE.w	#$0320, D0
	TST.b	Pal_flag.w
	BEQ.b	Upload_palette_delayed_dma
Upload_palette_delayed_wait:
	DBF	D0, Upload_palette_delayed_wait
Upload_palette_delayed_dma:
	MOVE.l	#$94009340, D5
	MOVE.w	#$977F, D7
	MOVE.l	#$96F495C0, D6
	MOVE.l	#$C0000080, Vdp_dma_setup.w
	JMP	Send_D567_to_VDP(PC)
Upload_h40_tilemap_buffer_to_vram:
; DMA the tilemap buffer to VRAM in H40 (40-cell wide) mode.
; Sets the DMA source register to H40 stride ($94019340) and VRAM DMA mode ($74000083).
; The tilemap buffer spans 40 cells wide × N rows at the plane B address.
	MOVE.l	#$94019340, D5
	MOVE.l	#$74000083, Vdp_dma_setup.w
	BRA.b	Upload_tilemap_dma
Upload_h32_tilemap_buffer_to_vram:
; DMA the tilemap buffer to VRAM in H32 (32-cell wide) mode.
; Sets stride to H32 ($94019300) and VRAM DMA mode ($6C000083).
	MOVE.l	#$94019300, D5
	MOVE.l	#$6C000083, Vdp_dma_setup.w
Upload_tilemap_dma:
	MOVE.w	#$977F, D7
	MOVE.l	#$96CD9560, D6
	JMP	Send_D567_to_VDP(PC)
Draw_tilemap_buffer_to_vdp_128_cell_rows:
; Write rows of tilemap data directly to the VDP data port.
; Uses a row stride of $01000000 (128 cells = 256 bytes) per row.
; Inputs:
;  D7 = VDP address command longword (first destination row)
;  D6 = tile count per row minus 1
;  D5 = row count minus 1
;  A6 = source tilemap word buffer (consumed)
	MOVE.l	#$01000000, D3
	BRA.b	Draw_tilemap_buffer_body
Draw_tilemap_buffer_to_vdp_64_cell_rows:
; Write rows of tilemap data to VDP with 64-cell (128-byte) row stride.
; Used for plane B when the VDP scroll size is set to 64 cells wide.
; Same inputs as Draw_tilemap_buffer_to_vdp_128_cell_rows.
	MOVE.l	#$00800000, D3
	BRA.b	Draw_tilemap_buffer_body
Draw_tilemap_buffer_to_vdp_32_cell_rows:
; Write rows of tilemap data to VDP with 32-cell (64-byte) row stride.
; Used for normal 32-cell wide plane layouts (H32 mode and some H40 tilemaps).
; Same inputs as Draw_tilemap_buffer_to_vdp_128_cell_rows.
	MOVE.l	#$00400000, D3
Draw_tilemap_buffer_body:
	LEA	VDP_data_port, A5
Draw_tilemap_buffer_row:
	MOVE.l	D7, $4(A5)
	MOVE.w	D6, D4
Draw_tilemap_buffer_tile:
	MOVE.w	(A6)+, (A5)
	DBF	D4, Draw_tilemap_buffer_tile
	ADD.l	D3, D7
	DBF	D5, Draw_tilemap_buffer_row
	RTS
Decompress_tilemap_to_vdp_128_cell_rows:
; Decompress a packed tilemap to the $FFFFEA00 work buffer then upload it
; to VDP using 128-cell row stride.
; Inputs:
;  A0 = pointer to compressed tilemap data
;  D7 = VDP address command (first destination row)
;  D6 = tile count per row minus 1
;  D5 = row count minus 1
;  D0 = tile index base offset for non-zero tiles
	JSR	Decompress_tilemap_to_buffer(PC)
	LEA	Tilemap_work_buf.w, A6
	BRA.b	Draw_tilemap_buffer_to_vdp_128_cell_rows
Decompress_tilemap_to_vdp_64_cell_rows:
; Decompress a packed tilemap to the $FFFFEA00 work buffer then upload it
; to VDP using 64-cell row stride.  Same inputs as the 128-cell variant.
	JSR	Decompress_tilemap_to_buffer(PC)
	LEA	Tilemap_work_buf.w, A6
	BRA.b	Draw_tilemap_buffer_to_vdp_64_cell_rows
	dc.b	$4E, $BA, $02, $FA, $4D, $F8, $EA, $00, $60, $C2
Decompress_tilemap_128cell_with_base:
	MOVE.l	#$01000000, D3
	BRA.b	Decompress_tilemap_with_base_body
	dc.b	$26, $3C, $00, $80, $00, $00, $60, $06
Decompress_tilemap_to_vdp_32_cell_rows_with_base:
; Decompress a packed tilemap to $FFFFEA00 then call Write_tilemap_rows_to_vdp
; with a caller-supplied tile base offset (D1).  Uses 32-cell row stride.
; Inputs:
;  A0 = pointer to compressed tilemap data
;  D7 = VDP address command (first destination row)
;  D6 = tile count per row minus 1
;  D5 = row count minus 1
;  D1 = tile base offset added to non-zero tile indices
;  D0 = decompression mode / base word passed to Decompress_tilemap_to_buffer
	MOVE.l	#$00400000, D3
Decompress_tilemap_with_base_body:
	JSR	Decompress_tilemap_to_buffer(PC)
	LEA	Tilemap_work_buf.w, A6
;Write_tilemap_rows_to_vdp
Write_tilemap_rows_to_vdp:
; Writes rows of tilemap data to VDP, offsetting tile indices by D1.
; Inputs:
;  D7 = VDP address command longword (first destination row)
;  D6 = words per row minus 1
;  D5 = row count minus 1
;  D3 = VDP address row increment (added to D7 each row)
;  D1 = tile base offset (added to non-zero tile indices)
;  A6 = source tilemap buffer (consumed)
	LEA	VDP_data_port, A5
Write_tilemap_rows_row:
	MOVE.l	D7, $4(A5)
	MOVE.w	D6, D4
Write_tilemap_rows_tile:
	MOVE.w	(A6)+, D2
	MOVE.w	D2, D0
	ANDI.w	#$07FF, D2
	BEQ.b	Write_tilemap_rows_zero
	MOVE.w	D0, D2
	ADD.w	D1, D2
Write_tilemap_rows_zero:
	MOVE.w	D2, (A5)
	DBF	D4, Write_tilemap_rows_tile
	ADD.l	D3, D7
	DBF	D5, Write_tilemap_rows_row
	RTS
	dc.b	$32, $1A		; MOVE.w (A2)+, D1
	dc.b	$3E, $1A, $4E, $BA	; MOVE.w (A2)+, D7
	dc.b	$00, $A4		; JSR *+$8AE
	dc.b	$7C, $00		; MOVEQ #0, D6
	dc.b	$1C, $1A		; MOVE.b (A2)+, D6
	dc.b	$7A, $00		; MOVEQ #0, D5
	dc.b	$1A, $1A		; MOVE.b (A2)+, D5
	dc.b	$30, $1A		; MOVE.w (A2)+, D0
	dc.b	$20, $5A		; MOVEA.l (A2)+, A0
	dc.b	$4E, $BA, $FF, $86	; JSR *+$7A0
	dc.b	$51, $C9, $FF, $E8	; DBF D1, *+$FFE8
	dc.b	$4E, $75		; RTS [ This is an unreached (possibly unused?) routine. ]
Copy_tilemap_block_with_base:
	MOVE.w	#$0180, D3
Copy_tilemap_block_row:
	LEA	(A5), A4
	MOVE.w	D6, D4
Copy_tilemap_block_tile:
	MOVE.w	(A6)+, D2
	MOVE.w	D2, D0
	ANDI.w	#$07FF, D2
	BEQ.b	Copy_tilemap_block_zero
	MOVE.w	D0, D2
	ADD.w	D1, D2
Copy_tilemap_block_zero:
	MOVE.w	D2, (A4)+
	DBF	D4, Copy_tilemap_block_tile
	ADDA.w	D3, A5
	DBF	D5, Copy_tilemap_block_row
	RTS
Draw_packed_tilemap_to_vdp:
; Draw a run-length-encoded packed tilemap stream to the VDP.
; Reads the first word from A6 as the tile base index (D6), then falls through.
; Inputs:
;  A6 = pointer to packed tilemap byte stream
; (tile base read from first word in stream; see Draw_packed_tilemap_to_vdp_preset_base for format)
	LEA	VDP_data_port, A5
	MOVE.w	(A6)+, D6
;Draw_packed_tilemap_to_vdp_preset_base
Draw_packed_tilemap_to_vdp_preset_base:
; Entry point for Draw_packed_tilemap_to_vdp with caller-supplied tile base in D6.
; Converts D6 tile index to a VDP VRAM write command, then decodes a byte stream:
;  - byte < $FA: emit tile at (D0 + byte) to current VDP column position
;  - byte $FA: read next word from stream to replace D0 base
;  - byte $FB: D6 += $80, restart with new base
;  - byte $FC: D6 += $C0, restart with new base
;  - byte $FD: D6 += $100, restart with new base
;  - byte $FE: RTS (end of packed tilemap)
; Inputs:
;  A6 = packed byte stream
;  D6 = initial tile base index
	MOVE.w	D6, D7
	JSR	Tile_index_to_vdp_command(PC)
	MOVE.l	D7, $4(A5)
Draw_packed_fetch:
	MOVEQ	#0, D1
	MOVE.b	(A6)+, D1
	CMPI.w	#$00FA, D1
	BCC.b	Draw_packed_ctrl
	ADD.w	D0, D1
Draw_packed_emit:
	MOVE.w	D1, (A5)
	BRA.b	Draw_packed_fetch
Draw_packed_ctrl:
	SUBI.w	#$00FA, D1
	ADD.w	D1, D1
	ADD.w	D1, D1
	JMP	Draw_packed_dispatch(PC,D1.w)
Draw_packed_dispatch:
	BRA.w	Draw_packed_emit
	BRA.w	Draw_packed_new_base
	BRA.w	Draw_packed_base_add80
	BRA.w	Draw_packed_base_add40a
	BRA.w	Draw_packed_base_add40b
	RTS
Draw_packed_new_base:
	MOVE.b	(A6)+, D0
	LSL.w	#8, D0
	MOVE.b	(A6)+, D0
	BRA.b	Draw_packed_fetch
Draw_packed_base_add80:
	ADDI.w	#$0080, D6
Draw_packed_base_add40a:
	ADDI.w	#$0040, D6
Draw_packed_base_add40b:
	ADDI.w	#$0040, D6
	BRA.b	Draw_packed_tilemap_to_vdp_preset_base
Draw_packed_tilemap_list:
	MOVE.w	(A1)+, D2
Draw_packed_list_loop:
	MOVEA.l	(A1)+, A6
	JSR	Draw_packed_tilemap_to_vdp(PC)
	DBF	D2, Draw_packed_list_loop
	RTS
Tile_index_to_vdp_command:
	ANDI.l	#$0000FFFF, D7
	LSL.l	#2, D7
	LSR.w	#2, D7
	ORI.w	#$4000, D7
	SWAP	D7
	RTS
Fade_palette_to_black:
; Fade all 64 palette entries ($FFFFE980..$FFFFE9FF) to black over 6 VBlanks.
; Each pass darkens all three colour components of all 64 entries by subtracting
; 2 from each 4-bit channel using Darken_palette_component, then waits for a
; VBlank (and an extra VBlank on PAL systems where Pal_flag != 0) before the
; next pass.  After 7 iterations the palette is fully black.
; Also clears Practice_vblank_step each pass.
	ANDI	#$F8FF, SR
	JSR	Wait_for_vblank
	MOVEQ	#6, D0
Fade_palette_frame:
	LEA	Palette_buffer.w, A0
	MOVEQ	#$0000003F, D1
Fade_palette_entry:
	MOVEQ	#0, D5
	MOVE.w	(A0), D2
	ROL.w	#4, D2
	BSR.b	Darken_palette_component
	BSR.b	Darken_palette_component
	BSR.b	Darken_palette_component
	MOVE.w	D5, (A0)+
	DBF	D1, Fade_palette_entry
	CLR.w	Practice_vblank_step.w
	JSR	Wait_for_vblank
	TST.b	Pal_flag.w
	BNE.b	Fade_palette_pal_extra
	JSR	Wait_for_vblank
Fade_palette_pal_extra:
	DBF	D0, Fade_palette_frame
	RTS
Darken_palette_component:
; Darken one 4-bit colour component extracted from the current palette word.
; Rolls D2 left by 4 to bring the next nibble into bits [3:0], subtracts 2
; (minimum 0), and ORs the result into D5 which accumulates the darkened word.
; Called three times per palette entry: once for each of R, G, B components.
; Inputs: D2 = packed colour word (rotated in-place), D5 = output accumulator
	LSL.w	#4, D5
	ROL.w	#4, D2
	MOVE.w	D2, D3
	ANDI.w	#$000E, D3
	SUBQ.w	#2, D3
	BCC.b	Darken_palette_clamp
	MOVEQ	#0, D3
Darken_palette_clamp:
	OR.w	D3, D5
	RTS
Send_D567_to_VDP:
; Write three pre-packed VDP control longwords (D5, D6, D7) to the VDP control
; port, followed by the cached DMA setup word (Vdp_dma_setup) and one extra
; control word from $FFFFFF0A.
;
; Bus arbitration: the VDP control port ($C00004) and the Z80 address space
; ($A00000-$A0FFFF) both reside on the 68K expansion bus.  Writing to the VDP
; while the Z80 also drives the bus causes bus contention.  This routine
; therefore requests Z80 bus ownership before every write sequence and releases
; it when done.  The spin-wait on bit 0 of Z80_bus_request blocks until the
; Z80 has acknowledged the request and tri-stated its outputs.
;
; Inputs: D5.l, D6.l = VDP address/command longwords
;         D7.w       = third VDP control word
;         Vdp_dma_setup.w = DMA command longword (low word)
	MOVE.w	#$0100, Z80_bus_request
	BTST.b	#0, Z80_bus_request
	BNE.b	Send_D567_to_VDP
	LEA	VDP_control_port, A5
	MOVE.l	D5, (A5)
	MOVE.l	D6, (A5)
	MOVE.w	D7, (A5)
	MOVE.w	Vdp_dma_setup.w, (A5)
	MOVE.w	Vdp_dma_fill_data.w, (A5)
	MOVE.w	#0, Z80_bus_request
	RTS
Start_vdp_dma_fill:
; Initiate a VDP DMA fill operation and spin-wait until it completes.
; Sets VDP auto-increment to 1 byte ($8F01), writes the fill command longword
; (D6) and fill length ($9780) to VDP control, then writes the VRAM destination
; address (D7) and triggers the fill by writing one byte to VDP data port.
; Polls VDP status bit 1 (DMA busy) until clear, then restores auto-increment
; to 2 bytes ($8F02).
;
; Inputs:
;  D6.l = VDP DMA fill command longword (fill value + VRAM address setup)
;  D7.l = VRAM write address command longword
	MOVEQ	#0, D5
	MOVE.w	#$8F01, VDP_control_port
	LEA	VDP_control_port, A5
	MOVE.l	D6, (A5)
	MOVE.w	#$9780, (A5)
	MOVE.l	D7, (A5)
	MOVE.b	D5, -$4(A5)
Start_dma_fill_wait:
	MOVE.w	(A5), D4
	ANDI.w	#2, D4
	BNE.b	Start_dma_fill_wait
	MOVE.w	#$8F02, VDP_control_port
	RTS
Decompress_to_vdp:
; Decompress tile graphics data from A0 and stream the decompressed pixels
; directly to the VDP data port (A4 = VDP_data_port).
; Uses a Huffman-like code table built by Build_decompression_code_table
; from a header embedded in the data stream.  Output is written as 32-bit
; longwords directly to VDP_data_port (tiles land in VRAM at whatever address
; the VDP is currently set to via a prior control-port write).
; Inputs:  A0 = compressed data pointer (consumed on return)
	MOVEM.l	A5/A4/A3/A1/A0/D7/D6/D5/D4/D3/D2/D1/D0, -(A7)
	LEA	Decompress_vdp_emit_group(PC), A3
	LEA	VDP_data_port, A4
	BRA.b	Decompress_shared_body
Decompress_to_ram:
; Decompress tile graphics data from A0 into a RAM buffer at A4.
; Identical algorithm to Decompress_to_vdp but the output sink is a
; sequential RAM destination (A4 incremented each longword) rather than
; the VDP data port.
; Inputs:  A0 = compressed data pointer (consumed on return)
	MOVEM.l	A5/A4/A3/A1/A0/D7/D6/D5/D4/D3/D2/D1/D0, -(A7)
	LEA	Decompress_ram_emit_group(PC), A3
Decompress_shared_body:
	LEA	Decomp_code_table.w, A1
	MOVE.w	(A0)+, D2
	LSL.w	#1, D2
	BCC.b	Decompress_code_table_skip
	LEA	$A(A3), A3
Decompress_code_table_skip:
	LSL.w	#2, D2
	MOVEA.w	D2, A5
	MOVEQ	#8, D3
	MOVEQ	#0, D2
	MOVEQ	#0, D4
	JSR	Build_decompression_code_table(PC)
	MOVE.b	(A0)+, D5
	ASL.w	#8, D5
	MOVE.b	(A0)+, D5
	MOVE.w	#$0010, D6
	JSR	Decompress_huffman_decode(PC)
	MOVEM.l	(A7)+, D0/D1/D2/D3/D4/D5/D6/D7/A0/A1/A3/A4/A5
	RTS
Decompress_huffman_decode:
	MOVE.w	D6, D7
	SUBQ.w	#8, D7
	MOVE.w	D5, D1
	LSR.w	D7, D1
	CMPI.b	#$FC, D1
	BCC.b	Decompress_huffman_extended
	ANDI.w	#$00FF, D1
	ADD.w	D1, D1
	MOVE.b	(A1,D1.w), D0
	EXT.w	D0
	SUB.w	D0, D6
	CMPI.w	#9, D6
	BCC.b	Decompress_huffman_next_nibble
	ADDQ.w	#8, D6
	ASL.w	#8, D5
	MOVE.b	(A0)+, D5
Decompress_huffman_next_nibble:
	MOVE.b	$1(A1,D1.w), D1
	MOVE.w	D1, D0
	ANDI.w	#$000F, D1
	ANDI.w	#$00F0, D0
Decompress_huffman_shift_out:
	LSR.w	#4, D0
Decompress_huffman_emit_nibble:
	LSL.l	#4, D4
	OR.b	D1, D4
	SUBQ.w	#1, D3
	BNE.b	Decompress_huffman_loop_back
	JMP	(A3)
;Decompress_huffman_Next_group
Decompress_huffman_Next_group:
	MOVEQ	#0, D4
	MOVEQ	#8, D3
Decompress_huffman_loop_back:
	DBF	D0, Decompress_huffman_emit_nibble
	BRA.b	Decompress_huffman_decode
Decompress_huffman_extended:
	SUBQ.w	#6, D6
	CMPI.w	#9, D6
	BCC.b	Decompress_huffman_ext_reload
	ADDQ.w	#8, D6
	ASL.w	#8, D5
	MOVE.b	(A0)+, D5
Decompress_huffman_ext_reload:
	SUBQ.w	#7, D6
	MOVE.w	D5, D1
	LSR.w	D6, D1
	MOVE.w	D1, D0
	ANDI.w	#$000F, D1
	ANDI.w	#$0070, D0
	CMPI.w	#9, D6
	BCC.b	Decompress_huffman_shift_out
	ADDQ.w	#8, D6
	ASL.w	#8, D5
	MOVE.b	(A0)+, D5
	BRA.b	Decompress_huffman_shift_out
Decompress_vdp_emit_group:
	MOVE.l	D4, (A4)
	SUBQ.w	#1, A5
	MOVE.w	A5, D4
	BNE.b	Decompress_huffman_Next_group
	RTS
	EOR.l	D4, D2
	MOVE.l	D2, (A4)
	SUBQ.w	#1, A5
	MOVE.w	A5, D4
	BNE.b	Decompress_huffman_Next_group
	RTS
Decompress_ram_emit_group:
	MOVE.l	D4, (A4)+
	SUBQ.w	#1, A5
	MOVE.w	A5, D4
	BNE.b	Decompress_huffman_Next_group
	RTS
	EOR.l	D4, D2
	MOVE.l	D2, (A4)+
	SUBQ.w	#1, A5
	MOVE.w	A5, D4
	BNE.b	Decompress_huffman_Next_group
	RTS
Build_decompression_code_table:
; Build a flat decode table at A1 ($FFFFFA00) from a compact descriptor in A0.
; Each descriptor entry encodes a bit-pattern length and its decoded nibble
; value, terminated by $FF.  The routine expands each entry into one or more
; slots in A1 so that the decompressor can look up a code nibble directly.
; Called once per compressed stream at the start of Decompress_to_vdp /
; Decompress_to_ram.
; Inputs:  A0 = descriptor stream (consumed), A1 = decode table output ($FFFFFA00)
	MOVE.b	(A0)+, D0
Build_code_table_next_entry:
	CMPI.b	#$FF, D0
	BNE.b	Build_code_table_process
	RTS
Build_code_table_process:
	MOVE.w	D0, D7
Build_code_table_read_slot:
	MOVE.b	(A0)+, D0
	CMPI.b	#$80, D0
	BCC.b	Build_code_table_next_entry
	MOVE.b	D0, D1
	ANDI.w	#$000F, D7
	ANDI.w	#$0070, D1
	OR.w	D1, D7
	ANDI.w	#$000F, D0
	MOVE.b	D0, D1
	LSL.w	#8, D1
	OR.w	D1, D7
	MOVEQ	#8, D1
	SUB.w	D0, D1
	BNE.b	Build_code_table_multi
	MOVE.b	(A0)+, D0
	ADD.w	D0, D0
	MOVE.w	D7, (A1,D0.w)
	BRA.b	Build_code_table_read_slot
Build_code_table_multi:
	MOVE.b	(A0)+, D0
	LSL.w	D1, D0
	ADD.w	D0, D0
	MOVEQ	#1, D5
	LSL.w	D1, D5
	SUBQ.w	#1, D5
Build_code_table_fill_loop:
	MOVE.w	D7, (A1,D0.w)
	ADDQ.w	#2, D0
	DBF	D5, Build_code_table_fill_loop
	BRA.b	Build_code_table_read_slot
Decompress_tilemap_to_buffer:
	MOVEM.l	A5/A4/A3/A2/A1/D7/D6/D5/D4/D3/D2/D1/D0, -(A7)
	MOVEA.w	D0, A3
	LEA	Tilemap_work_buf.w, A1
	MOVE.b	(A0)+, D0
	EXT.w	D0
	MOVEA.w	D0, A5
	MOVE.b	(A0)+, D0
	EXT.w	D0
	EXT.l	D0
	ROR.l	#1, D0
	ROR.w	#1, D0
	MOVE.l	D0, D4
	MOVEA.w	(A0)+, A2
	ADDA.w	A3, A2
	MOVEA.w	(A0)+, A4
	ADDA.w	A3, A4
	MOVE.b	(A0)+, D5
	ASL.w	#8, D5
	MOVE.b	(A0)+, D5
	MOVEQ	#$00000010, D6
;Decompress_tilemap_to_buffer_Loop
Decompress_tilemap_to_buffer_Loop:
	MOVEQ	#7, D0
	MOVE.w	D6, D7
	SUB.w	D0, D7
	MOVE.w	D5, D1
	LSR.w	D7, D1
	ANDI.w	#$007F, D1
	MOVE.w	D1, D2
	CMPI.w	#$0040, D1
	BCC.b	Decomp_tilemap_refill
	MOVEQ	#6, D0
	LSR.w	#1, D2
Decomp_tilemap_refill:
	JSR	Refill_tilemap_bit_buffer(PC)
	ANDI.w	#$000F, D2
	LSR.w	#4, D1
	ADD.w	D1, D1
	JMP	Decomp_tilemap_dispatch(PC,D1.w)
Decomp_tilemap_incrun_loop:
	MOVE.w	A2, (A1)+
	ADDQ.w	#1, A2
	DBF	D2, Decomp_tilemap_incrun_loop
	BRA.b	Decompress_tilemap_to_buffer_Loop
Decomp_tilemap_flatrun_loop:
	MOVE.w	A4, (A1)+
	DBF	D2, Decomp_tilemap_flatrun_loop
	BRA.b	Decompress_tilemap_to_buffer_Loop
Decomp_tilemap_reprun_decode:
	JSR	Decode_packed_tilemap_entry(PC)
Decomp_tilemap_reprun_loop:
	MOVE.w	D1, (A1)+
	DBF	D2, Decomp_tilemap_reprun_loop
	BRA.b	Decompress_tilemap_to_buffer_Loop
Decomp_tilemap_ascrun_decode:
	JSR	Decode_packed_tilemap_entry(PC)
Decomp_tilemap_ascrun_loop:
	MOVE.w	D1, (A1)+
	ADDQ.w	#1, D1
	DBF	D2, Decomp_tilemap_ascrun_loop
	BRA.b	Decompress_tilemap_to_buffer_Loop
Decomp_tilemap_descrun_decode:
	JSR	Decode_packed_tilemap_entry(PC)
Decomp_tilemap_descrun_loop:
	MOVE.w	D1, (A1)+
	SUBQ.w	#1, D1
	DBF	D2, Decomp_tilemap_descrun_loop
	BRA.b	Decompress_tilemap_to_buffer_Loop
Decomp_tilemap_litrun_head:
	CMPI.w	#$000F, D2
	BEQ.b	Decomp_tilemap_end
Decomp_tilemap_litrun_loop:
	JSR	Decode_packed_tilemap_entry(PC)
	MOVE.w	D1, (A1)+
	DBF	D2, Decomp_tilemap_litrun_loop
	BRA.b	Decompress_tilemap_to_buffer_Loop
Decomp_tilemap_dispatch:
	BRA.b	Decomp_tilemap_incrun_loop
	BRA.b	Decomp_tilemap_incrun_loop
	BRA.b	Decomp_tilemap_flatrun_loop
	BRA.b	Decomp_tilemap_flatrun_loop
	BRA.b	Decomp_tilemap_reprun_decode
	BRA.b	Decomp_tilemap_ascrun_decode
	BRA.b	Decomp_tilemap_descrun_decode
	BRA.b	Decomp_tilemap_litrun_head
Decomp_tilemap_end:
	SUBQ.w	#1, A0
	CMPI.w	#$0010, D6
	BNE.b	Decomp_tilemap_align
	SUBQ.w	#1, A0
Decomp_tilemap_align:
	MOVE.w	A0, D0
	LSR.w	#1, D0
	BCC.b	Decomp_tilemap_exit
	ADDQ.w	#1, A0
Decomp_tilemap_exit:
	MOVEM.l	(A7)+, D0-D7/A1-A5
	RTS
Decode_packed_tilemap_entry:
	MOVE.w	A3, D3
	SWAP	D4
	BPL.b	Decode_packed_fliph_done
	SUBQ.w	#1, D6
	BTST.l	D6, D5
	BEQ.b	Decode_packed_fliph_done
	ORI.w	#$1000, D3
Decode_packed_fliph_done:
	SWAP	D4
	BPL.b	Decode_packed_flipv_done
	SUBQ.w	#1, D6
	BTST.l	D6, D5
	BEQ.b	Decode_packed_flipv_done
	ORI.w	#$0800, D3
Decode_packed_flipv_done:
	MOVE.w	D5, D1
	MOVE.w	D6, D7
	SUB.w	A5, D7
	BCC.b	Decode_packed_enough_bits
	MOVE.w	D7, D6
	ADDI.w	#$0010, D6
	NEG.w	D7
	LSL.w	D7, D1
	MOVE.b	(A0), D5
	ROL.b	D7, D5
	ADD.w	D7, D7
	AND.w	Decode_packed_bit_mask_table(PC,D7.w), D5
	ADD.w	D5, D1
Decode_packed_mask_finish:
	MOVE.w	A5, D0
	ADD.w	D0, D0
	AND.w	Decode_packed_bit_mask_table(PC,D0.w), D1
	ADD.w	D3, D1
	MOVE.b	(A0)+, D5
	LSL.w	#8, D5
	MOVE.b	(A0)+, D5
	RTS
Decode_packed_enough_bits:
	BEQ.b	Decode_packed_exact_fit
	LSR.w	D7, D1
	MOVE.w	A5, D0
	ADD.w	D0, D0
	AND.w	Decode_packed_bit_mask_table(PC,D0.w), D1
	ADD.w	D3, D1
	MOVE.w	A5, D0
	BRA.b	Refill_tilemap_bit_buffer
Decode_packed_exact_fit:
	MOVEQ	#$00000010, D6
Decode_packed_bit_mask_table:
	BRA.b	Decode_packed_mask_finish
	dc.w	$0001, $0003, $0007, $000F, $001F, $003F, $007F, $00FF, $01FF, $03FF
	dc.b	$07, $FF, $0F, $FF, $1F, $FF, $3F, $FF, $7F, $FF, $FF, $FF
Refill_tilemap_bit_buffer:
	SUB.w	D0, D6
	CMPI.w	#9, D6
	BCC.b	Refill_tilemap_bit_buffer_ret
	ADDQ.w	#8, D6
	ASL.w	#8, D5
	MOVE.b	(A0)+, D5
Refill_tilemap_bit_buffer_ret:
	RTS
Load_streamed_decompression_descriptor:
	MOVEM.l	A2/A1, -(A7)
	LEA	Stream_descriptor_table, A1
	ADD.w	D0, D0
	MOVE.w	(A1,D0.w), D0
	LEA	(A1,D0.w), A1
	LEA	Decomp_stream_buf.w, A2
	MOVEQ	#$0000003F, D0
Load_stream_desc_clear_loop:
	CLR.w	(A2)+
	DBF	D0, Load_stream_desc_clear_loop
	LEA	Decomp_stream_buf.w, A2
	MOVE.w	(A1)+, D0
	BMI.b	Load_stream_desc_done
Load_stream_desc_copy_loop:
	MOVE.l	(A1)+, (A2)+
	MOVE.w	(A1)+, (A2)+
	DBF	D0, Load_stream_desc_copy_loop
Load_stream_desc_done:
	MOVEM.l	(A7)+, A1/A2
	RTS
Start_streamed_decompression:
	TST.l	Decomp_stream_src_ptr.w
	BEQ.b	Start_stream_decomp_skip
	TST.w	Decomp_stream_rows.w
	BNE.b	Start_stream_decomp_skip
	MOVEA.l	Decomp_stream_src_ptr.w, A0
	LEA	Decompress_vdp_emit_group, A3
	LEA	Decomp_code_table.w, A1
	MOVE.w	(A0)+, D2
	BPL.b	Start_stream_decomp_sink_select
	ADDA.w	#$000A, A3
Start_stream_decomp_sink_select:
	ANDI.w	#$7FFF, D2
	MOVE.w	D2, Decomp_stream_rows.w
	BSR.w	Build_decompression_code_table
	MOVE.b	(A0)+, D5
	ASL.w	#8, D5
	MOVE.b	(A0)+, D5
	MOVEQ	#$00000010, D6
	MOVEQ	#0, D0
	MOVE.l	A0, Decomp_stream_src_ptr.w
	MOVE.l	A3, Decomp_stream_jump_ptr.w
	MOVE.l	D0, Decomp_stream_d0.w
	MOVE.l	D0, Decomp_stream_d1.w
	MOVE.l	D0, Decomp_stream_d2.w
	MOVE.l	D5, Decomp_stream_d5.w
	MOVE.l	D6, Decomp_stream_d6.w
Start_stream_decomp_skip:
	RTS
Continue_streamed_decompression:
	TST.w	Decomp_stream_rows.w
	BEQ.b	Continue_stream_decomp_done
	LEA	VDP_control_port, A4
	MOVE.w	Decomp_stream_tile_ofs.w, D0
	ANDI.l	#$0000FFFF, D0
	LSL.l	#2, D0
	LSR.w	#2, D0
	ORI.w	#$4000, D0
	SWAP	D0
	MOVE.l	D0, (A4)
	SUBQ.w	#4, A4
	MOVEA.l	Decomp_stream_src_ptr.w, A0
	MOVEA.l	Decomp_stream_jump_ptr.w, A3
	MOVE.l	Decomp_stream_d0.w, D0
	MOVE.l	Decomp_stream_d1.w, D1
	MOVE.l	Decomp_stream_d2.w, D2
	MOVE.l	Decomp_stream_d5.w, D5
	MOVE.l	Decomp_stream_d6.w, D6
	LEA	Decomp_code_table.w, A1
	MOVE.w	#4, Decomp_stream_step.w
Continue_stream_decomp_inner:
	MOVEA.w	#8, A5
	BSR.w	Decompress_huffman_Next_group
	SUBQ.w	#1, Decomp_stream_rows.w
	BEQ.b	Continue_stream_decomp_flush
	SUBQ.w	#1, Decomp_stream_step.w
	BNE.b	Continue_stream_decomp_inner
	ADDI.w	#$0080, Decomp_stream_tile_ofs.w
	MOVE.l	A0, Decomp_stream_src_ptr.w
	MOVE.l	A3, Decomp_stream_jump_ptr.w
	MOVE.l	D0, Decomp_stream_d0.w
	MOVE.l	D1, Decomp_stream_d1.w
	MOVE.l	D2, Decomp_stream_d2.w
	MOVE.l	D5, Decomp_stream_d5.w
	MOVE.l	D6, Decomp_stream_d6.w
Continue_stream_decomp_done:
	RTS
Continue_stream_decomp_flush:
	LEA	Decomp_stream_buf.w, A0
	MOVEQ	#$0000000B, D0
Continue_stream_desc_shift_loop:
	MOVE.l	$6(A0), (A0)+
	DBF	D0, Continue_stream_desc_shift_loop
	RTS
Stream_descriptor_table:
	dc.w	$0002
	dc.b	$00, $00, $00, $05, $C9, $CA, $70, $80
Vdp_init_register_table:
	dc.w	$8004, $8134, $8238, $8338, $8406
	dc.b	$85, $7A, $86, $00, $87, $30, $88, $00, $89, $00, $8A, $FF, $8B, $03, $8C, $81, $8D, $3C, $8E, $00, $8F, $02, $90, $11, $91, $00, $92, $80
Update_objects_and_build_sprite_buffer:
	MOVEQ	#-1, D0
	MOVE.l	D0, Depth_sort_value.w
	LEA	Depth_sort_buf.w, A0
	MOVE.l	D0, (A0)+
	MOVE.l	D0, (A0)+
	MOVE.l	D0, (A0)+
	MOVE.l	D0, (A0)+
	MOVE.l	D0, (A0)+
	MOVE.l	D0, (A0)+
	MOVE.l	D0, (A0)+
	MOVE.l	D0, (A0)+
	MOVEQ	#0, D0
	MOVE.l	D0, (A0)+
	MOVE.l	D0, (A0)+
	MOVE.l	D0, (A0)+
	MOVE.l	D0, (A0)+
	MOVE.l	D0, (A0)+
	MOVE.l	D0, (A0)+
	MOVE.l	D0, (A0)+
	MOVE.l	D0, (A0)+
	MOVE.w	#$004C, Object_update_counter.w
	LEA	Main_object_pool.w, A0
Update_objects_loop:
	MOVE.l	(A0), D0
	BEQ.b	Update_objects_next
	MOVEA.l	D0, A1
	JSR	(A1) ; can jump to Init_background_ai_car_1, configured by Sign_handler_dispatch_rts
Update_objects_next:
	LEA	$40(A0), A0
	SUBQ.w	#1, Object_update_counter.w
	BNE.b	Update_objects_loop ; loop from A0=$FFFFAD80 in jumps of $40 at most #$004C steps (final iteration at $FFFFC040)
	LEA	Sprite_attr_buf.w, A6
	MOVEQ	#$00000052, D0
	LEA	Bg_sprite_row_buf.w, A5
	MOVE.w	Vdp_plane_row_bytes.w, Sprite_slots_remaining.w
	MOVE.w	Vdp_plane_tile_count.w, D7
Build_sprites_bg_row:
	MOVEA.l	A5, A4
	MOVE.w	(A4)+, D1
	BEQ.b	Build_sprites_bg_row_next
	ASR.w	#1, D1
	SUBQ.w	#1, D1
Build_sprites_bg_entry:
	MOVEA.w	(A4)+, A3
	MOVE.l	$4(A3), D2
	BEQ.b	Build_sprites_bg_entry_next
	MOVEA.l	D2, A2
	MOVE.w	(A2)+, D2
	MOVE.w	$16(A3), D3
	MOVE.w	$18(A3), D4
	MOVE.w	$C(A3), D6
Build_sprites_bg_sprite:
	MOVEQ	#-1, D5
	MOVE.b	(A2)+, D5
	ADD.w	D3, D5
	MOVE.w	D5, (A6)
	MOVE.b	(A2)+, $2(A6)
	MOVE.w	(A2)+, D5
	ADD.w	D6, D5
	MOVE.w	D5, $4(A6)
	MOVE.w	(A2)+, D5
	ADD.w	D4, D5
	MOVE.w	D5, $6(A6)
	CMP.w	D7, D5
	BCC.b	Build_sprites_bg_sprite_skip
	CMPI.w	#$0060, D5
	BLS.b	Build_sprites_bg_sprite_skip
	ADDQ.w	#8, A6
	SUBQ.w	#1, Sprite_slots_remaining.w
	BEQ.w	Build_sprites_link_chain
Build_sprites_bg_sprite_skip:
	DBF	D2, Build_sprites_bg_sprite
Build_sprites_bg_entry_next:
	DBF	D1, Build_sprites_bg_entry
Build_sprites_bg_row_next:
	LEA	-$10(A5), A5
	DBF	D0, Build_sprites_bg_row
	MOVEQ	#$00000048, D0
	LEA	Fg_sprite_row_buf.w, A5
	MOVE.w	#$0170, D7
Build_sprites_fg_row:
	MOVEA.l	A5, A4
	MOVE.w	(A4)+, D1
	BEQ.b	Build_sprites_fg_row_next
	ASR.w	#1, D1
	SUBQ.w	#1, D1
Build_sprites_fg_entry:
	MOVEA.w	(A4)+, A3
	MOVE.l	$4(A3), D2
	BEQ.b	Build_sprites_fg_entry_next
	MOVEA.l	D2, A2
	MOVE.w	(A2)+, D2
	MOVE.w	$16(A3), D3
	MOVE.w	$18(A3), D4
	MOVE.w	$C(A3), D6
Build_sprites_fg_sprite:
	MOVEQ	#-1, D5
	MOVE.b	(A2)+, D5
	ADD.w	D3, D5
	MOVE.w	D5, (A6)
	MOVE.b	(A2)+, $2(A6)
	MOVE.w	(A2)+, D5
	ADD.w	D6, D5
	MOVE.w	D5, $4(A6)
	MOVE.w	(A2)+, D5
	ADD.w	D4, D5
	MOVE.w	D5, $6(A6)
	CMP.w	D7, D5
	BCC.b	Build_sprites_fg_sprite_skip
	CMPI.w	#$0070, D5
	BLS.b	Build_sprites_fg_sprite_skip
	ADDQ.w	#8, A6
	SUBQ.w	#1, Sprite_slots_remaining.w
	BEQ.w	Build_sprites_link_chain
Build_sprites_fg_sprite_skip:
	DBF	D2, Build_sprites_fg_sprite
Build_sprites_fg_entry_next:
	DBF	D1, Build_sprites_fg_entry
Build_sprites_fg_row_next:
	LEA	-$10(A5), A5
	DBF	D0, Build_sprites_fg_row
Build_sprites_link_chain:
	LEA	Sprite_link_buf_main.w, A0
	MOVE.w	#$009B, D0
	MOVEQ	#0, D1
Build_sprites_clear_loop:
	MOVE.w	D1, (A0)
	LEA	$10(A0), A0
	DBF	D0, Build_sprites_clear_loop
	LEA	Sprite_attr_buf+4.w, A0
	MOVE.w	Vdp_plane_row_bytes.w, D0
	SUBQ.w	#1, D0
Build_sprites_fix_link_loop:
	CMPI.w	#$FFFE, (A0)
	BCS.b	Build_sprites_fix_link_next
	BNE.b	Build_sprites_fix_link_clr
	MOVE.w	#1, $2(A0)
	BRA.b	Build_sprites_fix_link_next
Build_sprites_fix_link_clr:
	CLR.w	$2(A0)
Build_sprites_fix_link_next:
	ADDQ.w	#8, A0
	DBF	D0, Build_sprites_fix_link_loop
	LEA	Sprite_attr_buf+3.w, A0
	MOVE.w	Vdp_plane_row_bytes.w, D0
	SUB.w	Sprite_slots_remaining.w, D0
	BNE.b	Build_sprites_write_links
	MOVE.w	#$0168, -$3(A0)
	CLR.b	(A0)
	RTS
Build_sprites_write_links:
	SUBQ.w	#2, D0
	BMI.b	Build_sprites_write_links_done
	MOVEQ	#1, D1
Build_sprites_write_links_loop:
	MOVE.b	D1, (A0)
	ADDQ.w	#1, D1
	ADDQ.w	#8, A0
	DBF	D0, Build_sprites_write_links_loop
Build_sprites_write_links_done:
	CLR.b	(A0)
	RTS
Queue_object_for_alt_sprite_buffer:
	LEA	Sprite_link_buf_alt.w, A1
	BRA.b	Queue_object_shared_body
Queue_object_for_sprite_buffer:
	LEA	Sprite_link_buf_main.w, A1
Queue_object_shared_body:
	MOVE.w	$E(A0), D0
	ANDI.w	#$FFFE, D0
	ASL.w	#3, D0
	ADDA.w	D0, A1
	MOVE.w	(A1), D1
	CMPI.w	#$000E, D1
	BCC.b	Queue_object_full
	ADDQ.w	#2, (A1)
	MOVE.w	A0, $2(A1,D1.w)
	RTS
Queue_object_full:
	ADDI.w	#$FFFF, D1
	RTS
Clear_main_object_pool:
	LEA	Main_object_pool.w, A0
	MOVEQ	#$0000004B, D1
	BRA.b	Clear_object_pool_loop
Clear_partial_main_object_pool:
	LEA	Main_object_pool.w, A0
	MOVEQ	#$0000000B, D1
	BRA.b	Clear_object_pool_loop
Clear_aux_object_pool:
	LEA	Aux_object_pool.w, A0
	MOVEQ	#$00000020, D1
Clear_object_pool_loop:
	BSR.b	Clear_object_slot
	LEA	$40(A0), A0
	DBF	D1, Clear_object_pool_loop
	RTS
Clear_object_slot:
	LEA	(A0), A1
	MOVEQ	#$0000000F, D0
Clear_object_slot_loop:
	CLR.l	(A1)+
	DBF	D0, Clear_object_slot_loop
	RTS
	MOVE.l	#Queue_object_for_alt_sprite_buffer, (A0)
	MOVE.l	#Scaled_sprite_frame_a_data, $4(A0)
	MOVE.w	#$0091, $E(A0)
	MOVE.w	#$00C8, $16(A0)
	MOVE.w	#$0100, $18(A0)
	BRA.b	Queue_object_for_alt_sprite_buffer
	MOVE.l	#Update_scaled_sprite, (A0)
	MOVE.l	#Scaled_sprite_frame_b_data, $4(A0)
	MOVE.w	#$0100, $18(A0)
Update_scaled_sprite:
	MOVE.w	$1A(A0), D0
	BNE.b	Update_scaled_sprite_body
	RTS
Update_scaled_sprite_body:
	ADD.w	D0, D0
	LEA	Road_scale_table.w, A1
	MOVE.w	(A1,D0.w), D1
	SUBI.w	#$002F, D1
	NEG.w	D1
	ADDI.w	#$0150, D1
	MOVE.w	D1, $16(A0)
	MOVE.w	Scaled_sprite_size_table(PC,D0.w), $E(A0)
	JMP	Queue_object_for_sprite_buffer(PC)
Scaled_sprite_frame_a_data:
	dc.b	$00, $03, $B2, $03, $FF, $FE, $00, $00, $B2, $03, $FF, $FF, $00, $00
	dc.b	$FA, $03, $FF, $FE, $00, $00, $FA, $03, $FF, $FF, $00, $00
Scaled_sprite_frame_b_data:
	dc.b	$00, $01, $E0, $03, $FF, $FE, $00, $00, $E0, $03, $FF, $FF, $00, $00
Scaled_sprite_size_table:
	dc.b	$00, $13
	dc.w	$0026, $0034, $0040, $0049, $0051
	dc.b	$00, $58
	dc.w	$005D
	dc.b	$00, $62, $00, $67
	dc.w	$006B
	dc.w	$006E
	dc.b	$00, $71, $00, $74, $00, $76, $00, $79, $00, $7B, $00, $7D, $00, $7E, $00, $80, $00, $82, $00, $83, $00, $84, $00, $85, $00, $87, $00, $88, $00, $89, $00, $8A
	dc.b	$00, $8B
	MOVE.w	$36(A0), D0
	SUBQ.w	#1, D0
	BPL.b	Update_flag_anim_wrap
	MOVEQ	#$00000015, D0
Update_flag_anim_wrap:
	MOVE.w	D0, $36(A0)
	LEA	Flag_anim_tiles_phase1(PC), A6
	CMPI.w	#$000B, D0
	BCS.b	Update_flag_anim_phase2
	LEA	Flag_anim_tiles_phase2(PC), A6
Update_flag_anim_phase2:
	MOVE.l	#$644E0003, D7
	MOVEQ	#$00000011, D6
	MOVEQ	#0, D5
	JMP	Queue_tilemap_draw
	MOVE.w	#$0120, $18(A0)
	MOVE.l	#Sprite_frame_data_12820, $4(A0)
	MOVE.w	#$00A1, $E(A0)
	MOVE.w	#$0108, $16(A0)
	BTST.b	#5, Frame_counter.w
	BEQ.b	Update_flag_enqueue_done
	JSR	Queue_object_for_sprite_buffer(PC)
Update_flag_enqueue_done:
	RTS
Flag_anim_tiles_phase1:
	dc.w	$87D9, $87DB, $87CE, $87DC, $87DC, $0000, $87DC, $87DD, $87CA, $87DB, $87DD, $0000, $87CB, $87DE, $87DD, $87DD, $87D8, $87D7
Flag_anim_tiles_phase2:
	dc.w	$87B1, $87B2, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000
Load_race_hud_graphics:
; Decompress and upload all graphics assets needed for the race HUD and road
; display to VRAM.
;
; Steps:
;  1. Decompress asset list at Race_hud_full_asset_list (12 entries: road tiles, car sprite,
;     HUD background, digit font, minimap tiles, etc.) to their VRAM addresses.
;  2. Load the current track's road tileset into VRAM at $5940 and $7000.
;  3. Decompress the car machine tilemap to $FFFFEA00 and build the car
;     tilemap priority-flip buffers via Build_car_tilemap_buffers.
;  4. If Track_index == $0C (Monaco), fill $0100 words of VRAM at $4840
;     with $DDDD (special track tile fill).
;  5. If Warm_up mode: load warm-up HUD tileset from Hud_tiles_warmup.
;     Else if Practice mode: load practice HUD tileset from Hud_tiles_practice.
;     Else if normal arcade race (Track_index_arcade_mode == 0): load normal
;     HUD tileset from Hud_tiles_normal.  Championship race skips this step.
	LEA	Race_hud_full_asset_list(PC), A1
	JSR	Decompress_asset_list_to_vdp
	JSR	Load_track_data_pointer
	MOVEA.l	(A1)+, A0
	MOVE.l	#$59400002, VDP_control_port
	JSR	Decompress_to_vdp
	MOVEA.l	(A1)+, A0
	MOVE.l	#$70000002, VDP_control_port
	JSR	Decompress_to_vdp
	MOVEA.l	(A1), A0
	MOVE.w	#$6000, D0
	JSR	Decompress_tilemap_to_buffer
	JSR	Build_car_tilemap_buffers(PC)
	CMPI.w	#$000C, Track_index.w
	BNE.b	Load_hud_gfx_mode_check
	MOVE.w	#$00FF, D0
	MOVE.w	#$DDDD, D1
	MOVE.l	#$48400002, VDP_control_port
Load_hud_gfx_monaco_fill_loop:
	MOVE.w	D1, VDP_data_port
	DBF	D0, Load_hud_gfx_monaco_fill_loop
Load_hud_gfx_mode_check:
	TST.w	Warm_up.w
	BEQ.b	Load_hud_gfx_practice_check
	LEA	Hud_tiles_warmup, A0
	BRA.b	Load_hud_gfx_decomp
Load_hud_gfx_practice_check:
	TST.w	Practice_mode.w
	BEQ.b	Load_hud_gfx_arcade_check
	LEA	Hud_tiles_practice, A0
	BRA.b	Load_hud_gfx_decomp
Load_hud_gfx_arcade_check:
	TST.w	Track_index_arcade_mode.w
	BNE.b	Load_hud_gfx_done
	LEA	Hud_tiles_normal, A0
Load_hud_gfx_decomp:
	MOVE.l	#$52400002, VDP_control_port
	JSR	Decompress_to_vdp
Load_hud_gfx_done:
	RTS
Initialize_race_hud:
; Build the initial race HUD layout in VRAM and the palette buffer.
;
; Called once at race start (after Load_race_hud_graphics).  Performs:
;  1. Copy HUD palette entries from stream at Race_hud_palette_init_data to $FFFFE980 palette buffer.
;  2. Initialize sprite objects via Initialize_hud_objects.
;  3. Draw HUD tilemap list (background panels, border tiles) from Race_hud_tilemap_list
;     to plane B using 32-cell row stride.
;  4. Decompress minimap track background tilemap (Race_minimap_bg_tilemap) into VRAM at
;     $62C4 (or $6370 for world championship), 9×10 cells.
;  5. Fill 64 words at $4000 and $5F80 with the blank tile index ($073F/$873F)
;     to clear the road plane rows before the first frame.
;  6. Fill 32 words at $6200 with priority road blank tile ($873C).
;  7. Decompress per-track minimap shape tilemap (from track data pointer) to
;     VRAM at $63B0 (or $6370 for championship), 7×11 cells.
;  8. Copy four 96/54-byte car portrait palette strips into $FFFFE980 via
;     Copy_word_run_to_buffer.
;  9. Initialize remaining objects: Copy_ai_scroll_data_to_objects (team palette VDP commands),
;     Initialize_road_scroll_state (road graphics state), Initialize_car_tile_scroll (car tile DMA).
; 10. Call Render_speed to show initial speed (0 km/h).
; 11. Draw shift indicator tilemap (manual/auto/semi, 8 or 6 tiles wide).
; 12. If championship, normal race, or practice: draw lap time table / timer.
	LEA	Race_hud_palette_init_data(PC), A6
	JSR	Copy_word_run_from_stream
	JSR	Initialize_hud_objects(PC)
	LEA	Race_hud_tilemap_list(PC), A1
	JSR	Draw_tilemap_list_to_vdp_32_cell_rows
	LEA	Race_minimap_bg_tilemap, A0
	MOVE.w	#$8000, D0
	MOVE.w	#$076F, D1
	MOVE.l	#$62C40003, D7
	MOVEQ	#8, D6
	MOVEQ	#9, D5
	JSR	Decompress_tilemap_to_vdp_32_cell_rows_with_base
	MOVE.l	#$40000003, VDP_control_port
	MOVEQ	#$0000003F, D0
Init_hud_clear_plane_a_loop:
	MOVE.w	#$073F, VDP_data_port
	DBF	D0, Init_hud_clear_plane_a_loop
	MOVE.l	#$5F800003, VDP_control_port
	MOVEQ	#$0000003F, D0
Init_hud_clear_plane_b_loop:
	MOVE.w	#$873F, VDP_data_port
	DBF	D0, Init_hud_clear_plane_b_loop
	MOVE.l	#$62000003, VDP_control_port
	MOVEQ	#$0000001F, D0
Init_hud_clear_road_row_loop:
	MOVE.w	#$873C, VDP_data_port
	DBF	D0, Init_hud_clear_road_row_loop
	JSR	Load_track_data_pointer
	LEA	$C(A1), A1 ; tile mapping for minimap
	MOVEA.l	(A1)+, A0
	MOVE.w	#$8000, D0
	MOVE.w	#$04C9, D1
	MOVE.l	#$63B00003, D7
	TST.w	Use_world_championship_tracks.w
	BEQ.b	Init_hud_minimap_champ
	MOVE.l	#$63700003, D7
Init_hud_minimap_champ:
	MOVEQ	#6, D6
	MOVEQ	#$0000000A, D5
	JSR	Decompress_tilemap_to_vdp_32_cell_rows_with_base
	MOVEA.l	(A1)+, A6
	MOVEQ	#$00000060, D0
	MOVEQ	#$0000000A, D1
	JSR	Copy_word_run_to_buffer
	MOVEA.l	(A1)+, A6
	MOVEQ	#$00000036, D0
	MOVEQ	#4, D1
	JSR	Copy_word_run_to_buffer
	MOVEA.l	(A1)+, A6
	MOVEQ	#$00000056, D0
	MOVEQ	#4, D1
	JSR	Copy_word_run_to_buffer
	MOVEA.l	(A1)+, A6
	MOVEQ	#$00000076, D0
	MOVEQ	#4, D1
	JSR	Copy_word_run_to_buffer
	JSR	Copy_ai_scroll_data_to_objects(PC)
	JSR	Initialize_road_scroll_state
	JSR	Initialize_car_tile_scroll(PC)
	JSR	Render_speed(PC)
	MOVE.l	#$63800003, D7
	MOVEQ	#7, D6
	MOVEQ	#1, D5
	LEA	Shift_indicator_tilemap_manual, A6
	TST.w	Shift_type.w
	BEQ.b	Init_hud_draw_shift
	MOVE.l	#$63820003, D7
	MOVEQ	#5, D6
	LEA	Shift_indicator_tilemap_gear1, A6
	CMPI.w	#1, Shift_type.w
	BEQ.b	Init_hud_draw_shift
	MOVEQ	#2, D5
Init_hud_draw_shift:
	JSR	Draw_tilemap_buffer_to_vdp_32_cell_rows
	TST.w	Use_world_championship_tracks.w
	BNE.b	Init_hud_champ_branch
	TST.w	Track_index_arcade_mode.w
	BNE.b	Init_hud_draw_laptime_rival
Init_hud_draw_laptime:
	MOVE.l	#$61460003, VDP_control_port
	MOVEA.l	Track_lap_time_base_ptr.w, A2
	MOVE.w	#$8000, D3
	JSR	Draw_bcd_time_to_vdp
	LEA	Hud_best_lap_tilemap_list(PC), A1
	JMP	Draw_packed_tilemap_list
Init_hud_draw_laptime_rival:
	MOVE.l	#$61040003, VDP_control_port
	MOVEA.l	Track_lap_time_base_ptr.w, A2
	MOVE.w	#$8000, D3
	JSR	Draw_bcd_time_to_vdp
	MOVE.l	#$61840003, VDP_control_port
	ADDQ.w	#4, A2
	MOVE.w	#$8000, D3
	JSR	Draw_bcd_time_to_vdp
	JSR	Render_placement_display_body(PC)
	LEA	Hud_rival_lap_tilemap_list(PC), A1
	JMP	Draw_packed_tilemap_list
Init_hud_champ_branch:
	TST.w	Warm_up.w
	BEQ.b	Init_hud_champ_race_check
	MOVE.l	#$61460003, VDP_control_port
	MOVEA.l	Track_lap_time_base_ptr.w, A2
	MOVE.w	#$8000, D3
	JSR	Draw_bcd_time_to_vdp
	LEA	Hud_champ_warmup_list(PC), A1
	JSR	Draw_packed_tilemap_list
	MOVE.w	Title_menu_cursor.w, D0
	ADD.w	D0, D0
	ADD.w	D0, D0
	LEA	Lap_number_tilemap_table, A6
	ADDA.w	D0, A6
	MOVE.l	#$627C0003, D7
	MOVEQ	#0, D6
	MOVEQ	#1, D5
	JMP	Draw_tilemap_buffer_to_vdp_32_cell_rows
Init_hud_champ_race_check:
	TST.w	Practice_mode.w
	BNE.w	Init_hud_draw_laptime
	TST.w	Track_index_arcade_mode.w
	BEQ.w	Init_hud_draw_laptime
	MOVE.l	#$61040003, VDP_control_port
	MOVEA.l	Track_lap_time_base_ptr.w, A2
	MOVE.w	#$8000, D3
	JSR	Draw_bcd_time_to_vdp
	MOVE.l	#$61840003, VDP_control_port
	ADDQ.w	#4, A2
	MOVE.w	#$8000, D3
	JSR	Draw_bcd_time_to_vdp
	LEA	Hud_position_rival_labels(PC), A6
	TST.w	Has_rival_flag.w
	BNE.b	Init_hud_rival_present
	LEA	Hud_your_position_label(PC), A6
Init_hud_rival_present:
	JSR	Draw_packed_tilemap_to_vdp
	TST.w	Has_rival_flag.w
	BEQ.b	Init_hud_player_ordinal
	MOVE.w	Rival_grid_position.w, D1
	MOVE.l	#$62660003, D7
	JSR	Draw_placement_ordinal_to_vdp
Init_hud_player_ordinal:
	MOVE.w	Player_grid_position.w, D1
	MOVE.l	#$625C0003, D7
	JSR	Draw_placement_ordinal_to_vdp
	LEA	Hud_champ_lap_tilemap_list(PC), A1
	JMP	Draw_packed_tilemap_list
Draw_lap_number_and_times:
	MOVE.w	Laps_completed.w, D0
	ADD.w	D0, D0
	ADD.w	D0, D0
	LEA	Lap_number_tilemap_table, A6
	ADDA.w	D0, A6
	MOVE.l	#$62780003, D7
	MOVEQ	#0, D6
	MOVEQ	#1, D5
	JSR	Draw_tilemap_buffer_to_vdp_32_cell_rows
	MOVE.w	#$E0AC, Screen_scroll.w
	LEA	Lap_time_table_ptr.w, A2
	MOVE.w	Laps_completed.w, Screen_timer.w
Draw_lap_times_loop:
	MOVE.w	Screen_scroll.w, D7
	JSR	Tile_index_to_vdp_command
	MOVE.l	D7, VDP_control_port
	MOVE.w	#$C000, D3
	JSR	Draw_bcd_time_to_vdp
	ADDQ.w	#4, A2
	ADDI.w	#$0040, Screen_scroll.w
	SUBQ.w	#1, Screen_timer.w
	BPL.b	Draw_lap_times_loop
	RTS
Initialize_hud_objects:
	TST.w	Use_world_championship_tracks.w
	BEQ.b	Init_hud_objects_copy_palette
	TST.w	Practice_mode.w
	BNE.b	Init_hud_objects_copy_palette
	MOVEQ	#$0000000F, D7
	MOVE.b	Player_team.w, D0
	LEA	(Palette_buffer+$C).w, A1
	BSR.b	Load_team_palette_entry
	TST.w	Track_index_arcade_mode.w
	BNE.b	Init_hud_objects_rival
	CLR.w	Has_rival_flag.w
Init_hud_objects_rival:
	MOVE.b	Rival_team.w, D0
	LEA	(Palette_buffer+$4C).w, A1
	BSR.b	Load_team_palette_entry
	MOVEQ	#$0000007F, D6
	TST.w	Has_rival_flag.w
	BEQ.b	Init_hud_objects_car3_check
	MOVE.b	Rival_team.w, D6
	AND.w	D7, D6
Init_hud_objects_car3_check:
	MOVE.b	Player_team.w, D0
	AND.w	D7, D0
	ADDQ.w	#1, D0
	AND.w	D7, D0
	CMP.w	D0, D6
	BNE.b	Init_hud_objects_car3_load
	ADDQ.w	#2, D0
Init_hud_objects_car3_load:
	LEA	(Palette_buffer+$2C).w, A1
	BSR.b	Load_team_palette_entry
Init_hud_objects_copy_palette:
	LEA	Team_palette_copy_buf.w, A0
	MOVE.l	(Palette_buffer+$2C).w, (A0)+
	MOVE.l	(Palette_buffer+$30).w, (A0)+
	MOVE.l	(Palette_buffer+$4C).w, (A0)+
	MOVE.l	(Palette_buffer+$50).w, (A0)+
	RTS
;Load_team_palette_entry
Load_team_palette_entry:
	AND.w	D7, D0
	LSL.w	#3, D0
	LEA	Team_colour_palette_table(PC), A0
	ADDA.w	D0, A0
	MOVE.l	(A0)+, (A1)+
	MOVE.l	(A0), (A1)
	RTS
;Queue_tilemap_draw
Queue_tilemap_draw:
; Appends a tilemap draw command to the deferred draw queue.
; Inputs:
;  D7 = VDP address command longword (destination tile cell)
;  A6 = source tilemap buffer pointer
;  D6 = tile count per row minus 1
;  D5 = row count minus 1
	MOVEA.l	Tilemap_queue_ptr.w, A5
	MOVE.l	D7, (A5)+
	MOVE.l	A6, (A5)+
	MOVE.b	D6, (A5)+
	MOVE.b	D5, (A5)+
	MOVE.l	A5, Tilemap_queue_ptr.w
	ADDQ.w	#1, Tilemap_queue_count.w
	RTS
;Flush_tilemap_draw_queue
Flush_tilemap_draw_queue:
; Drain the deferred tilemap draw queue built during the game frame.
; Each entry was enqueued by Queue_tilemap_draw during gameplay update.
; Processes all pending entries by calling Draw_tilemap_buffer_to_vdp_32_cell_rows
; for each, then implicitly resets by re-reading Tilemap_queue_count.
; Called from the VBlank handler once per frame.
	MOVE.w	Tilemap_queue_count.w, D0
	BEQ.b	Flush_tilemap_queue_done
	SUBQ.w	#1, D0
	LEA	Tilemap_draw_queue.w, A0
Flush_tilemap_queue_loop:
	MOVE.l	(A0)+, D7
	MOVEA.l	(A0)+, A6
	MOVEQ	#0, D6
	MOVEQ	#0, D5
	MOVE.b	(A0)+, D6
	MOVE.b	(A0)+, D5
	JSR	Draw_tilemap_buffer_to_vdp_32_cell_rows
	DBF	D0, Flush_tilemap_queue_loop
Flush_tilemap_queue_done:
	RTS
Render_placement_display:
; Redraw the race placement (position) tile strip if the dirty flag is set.
; Reads Race_time_bcd, unpacks three BCD nibbles (hundreds/tens/units of
; race time used for position display), converts each to a tile word using
; the base tile $87C0, then enqueues a 4-tile strip at VDP address $63360003
; (bottom-left HUD area) via Queue_tilemap_draw.
; Clears Placement_display_dirty after drawing.
	TST.w	Placement_display_dirty.w
	BEQ.b	Unpack_placement_nop
Render_placement_display_body:
	CLR.w	Placement_display_dirty.w
	LEA	(Digit_tilemap_buf+$AC).w, A1
	MOVE.w	Race_time_bcd.w, D0
	MOVEQ	#$0000000F, D2
	MOVEQ	#0, D3
	MOVE.w	#$87C0, D4
	BSR.b	Unpack_placement_nibble_to_tile
	BSR.b	Unpack_placement_nibble_to_tile
	BSR.b	Unpack_placement_nibble_to_tile
	BSR.b	Unpack_placement_units
	MOVE.l	#$63360003, D7
	MOVEQ	#3, D6
	MOVEQ	#0, D5
	LEA	(Digit_tilemap_buf+$AC).w, A6
	JMP	Queue_tilemap_draw(PC)
;Unpack_placement_nibble_to_tile
Unpack_placement_nibble_to_tile:
	ROL.w	#4, D0
	MOVE.w	D0, D1
	AND.w	D2, D1
	BEQ.b	Unpack_placement_zero
	ADD.w	D4, D1
	MOVEQ	#1, D3
	BRA.b	Unpack_placement_store
Unpack_placement_zero:
	TST.w	D3
	BEQ.b	Unpack_placement_store
	ADD.w	D4, D1
Unpack_placement_store:
	MOVE.w	D1, (A1)+
Unpack_placement_nop:
	RTS
Unpack_placement_units:
	ROL.w	#4, D0
	MOVE.w	D0, D1
	AND.w	D2, D1
	ADD.w	D4, D1
	MOVE.w	D1, (A1)+
	RTS
Render_speed:
; Redraw the speedometer digit tiles on the HUD.
; Reads Player_speed (km/h, binary), converts to BCD via Binary_to_decimal,
; unpacks three BCD digits into tile words in $FFFFE800 (no leading-zero
; suppression), then enqueues a 3×2 tile block at VDP address $66720003
; (speedometer area, plane B) via Queue_tilemap_draw.
	MOVE.w	Player_speed.w, D0
	JSR	Binary_to_decimal(PC) ; Output value D1 is $0123 if speed is 123km/h
	LEA	Digit_tilemap_buf.w, A1
	MOVEQ	#2, D0
	MOVEQ	#0, D7
	JSR	Unpack_bcd_digits_to_buffer(PC)
	MOVEQ	#2, D0
	JSR	Copy_digits_to_tilemap(PC)
	MOVE.l	#$66720003, D7
	MOVEQ	#2, D6
	MOVEQ	#1, D5
	LEA	Digit_tilemap_buf.w, A6
	JMP	Queue_tilemap_draw(PC)
;Unpack_bcd_digits_to_buffer
Unpack_bcd_digits_to_buffer:
	MOVEQ	#$0000000F, D4
	MOVE.w	D0, D3
	ADD.w	D3, D3
Unpack_bcd_digits_loop:
	MOVE.w	D1, D2
	AND.w	D4, D2
	ADD.w	D7, D2
	MOVE.w	D2, (A1,D3.w)
	SUBQ.w	#2, D3
	LSR.w	#4, D1
	DBF	D0, Unpack_bcd_digits_loop
	RTS
;Copy_digits_to_tilemap
Copy_digits_to_tilemap:
	MOVEQ	#0, D2
	BRA.b	Copy_digits_shared_body
;Copy_digits_to_tilemap_with_suppress
Copy_digits_to_tilemap_with_suppress:
	MOVEQ	#-1, D2
Copy_digits_shared_body:
	MOVE.w	D0, D1
	ADDQ.w	#1, D1
	ADD.w	D1, D1
	LEA	Hud_lap_number_tile_header, A2
Copy_digits_loop:
	MOVE.w	(A1), D3
	BNE.b	Copy_digits_nonzero
	TST.w	D2
	BNE.b	Copy_digits_emit
	TST.w	D0
	BEQ.b	Copy_digits_emit
	MOVEQ	#$0000000D, D3
	BRA.b	Copy_digits_emit
Copy_digits_nonzero:
	MOVEQ	#-1, D2
Copy_digits_emit:
	ADD.w	D3, D3
	ADD.w	D3, D3
	MOVE.w	(A2,D3.w), (A1)+
	MOVE.w	$2(A2,D3.w), -$2(A1,D1.w)
	DBF	D0, Copy_digits_loop
	RTS
Binary_to_decimal: ; For instance: input D0 = $007B yields output D1 = $0123
	CLR.l	Binary_to_decimal_bcd_scratch.w ; clears bytes referenced from A2 below
	LEA	Format_bcd_time_to_tile_buffer(PC), A1
	MOVEQ	#$0000000F, D2
Binary_to_decimal_loop: ; iterate through each bit in D0
	ROR.w	#1, D0
	BCS.b	Binary_to_decimal_bit_set ; if current bit in D0 was set, jump to perform decimal addition (ABCD)
	SUBQ.w	#3, A1
	BRA.b	Binary_to_decimal_next
Binary_to_decimal_bit_set:            ; then add corresponding value from byte table below
	LEA	Track_lap_time_records.w, A2 ; reuse lap-time block as BCD scratch (ABCD pre-dec: bytes at $FFFFFD00-$FFFFFD02)
	ADDI.w	#0, D0 ; clear extend bit
	ABCD	-(A1), -(A2)
	ABCD	-(A1), -(A2)
	ABCD	-(A1), -(A2)
Binary_to_decimal_next:
	DBF	D2, Binary_to_decimal_loop
	MOVE.l	Binary_to_decimal_bcd_scratch.w, D1
	RTS
; Table used by ABCD instructions above, input bits determine which rows to include in binary summation
	dc.b	$03, $27, $68
	dc.b	$01, $63, $84
	dc.b	$00, $81, $92
	dc.b	$00, $40, $96
	dc.b	$00, $20, $48
	dc.b	$00, $10, $24
	dc.b	$00, $05, $12
	dc.b	$00, $02, $56
	dc.b	$00, $01, $28
	dc.b	$00, $00, $64
	dc.b	$00, $00, $32
	dc.b	$00, $00, $16
	dc.b	$00, $00, $08
	dc.b	$00, $00, $04
	dc.b	$00, $00, $02
	dc.b	$00, $00, $01
Format_bcd_time_to_tile_buffer:
	MOVEQ	#$0000000F, D2
	ADDI.w	#$07C0, D3
	MOVE.w	D0, D1
	AND.w	D2, D1
	ADD.w	D3, D1
	MOVE.w	D1, -(A3)
	LSR.l	#4, D0
	MOVE.w	D0, D1
	AND.w	D2, D1
	ADD.w	D3, D1
	MOVE.w	D1, -(A3)
	LSR.l	#4, D0
	MOVEQ	#$00000027, D1
	ADD.w	D3, D1
	MOVE.w	D1, -(A3)
	MOVE.w	D0, D1
	AND.w	D2, D1
	ADD.w	D3, D1
	MOVE.w	D1, -(A3)
	LSR.l	#4, D0
	MOVE.w	D0, D1
	AND.w	D2, D1
	ADD.w	D3, D1
	MOVE.w	D1, -(A3)
	LSR.l	#4, D0
	MOVEQ	#$00000026, D1
	ADD.w	D3, D1
	MOVE.w	D1, -(A3)
	MOVE.w	D0, D1
	AND.w	D2, D1
	ADD.w	D3, D1
	MOVE.w	D1, -(A3)
	LSR.l	#4, D0
	MOVE.w	D0, D1
	AND.w	D2, D1
	BEQ.b	Format_bcd_time_leading_zero
	ADD.w	D3, D1
Format_bcd_time_leading_zero:
	MOVE.w	D1, -(A3)
	RTS
;Pack_hex_digits_to_tilemap
Pack_hex_digits_to_tilemap: ; Suspected number to hex digit conversion
	MOVEQ	#$0000000F, D2
	MOVE.w	D0, D1
	AND.w	D2, D1
	MOVE.w	D1, -(A1)
	LSR.l	#4, D0
	MOVE.w	D0, D1
	AND.w	D2, D1
	MOVE.w	D1, -(A1)
	LSR.l	#4, D0
	MOVE.w	#$000B, -(A1)
	MOVE.w	D0, D1
	AND.w	D2, D1
	MOVE.w	D1, -(A1)
	LSR.l	#4, D0
	MOVE.w	D0, D1
	AND.w	D2, D1
	MOVE.w	D1, -(A1)
	LSR.l	#4, D0
	MOVE.w	#$000A, -(A1)
	MOVE.w	D0, D1
	AND.w	D2, D1
	MOVE.w	D1, -(A1)
	LSR.l	#4, D0
	MOVE.w	D0, D1
	AND.w	D2, D1
	BNE.b	Pack_hex_leading_zero
	MOVE.w	#$000D, D1
Pack_hex_leading_zero:
	MOVE.w	D1, -(A1)
	RTS
Flush_pending_dma_transfers:
	LEA	Dma_queue_slot_a.w, A0
	MOVE.w	(A0), D7
	BEQ.b	Flush_dma_slot_a_skip
	MOVE.l	$2(A0), D6
	MOVE.l	#$940093F0, D5
	MOVE.l	#$4A400082, Vdp_dma_setup.w
	JSR	Send_D567_to_VDP
	CLR.w	(A0)
Flush_dma_slot_a_skip:
	MOVE.w	$6(A0), D7
	BEQ.b	Flush_dma_slot_b_skip
	MOVE.l	$8(A0), D6
	MOVE.l	#$940093C0, D5
	MOVE.l	#$4C200082, Vdp_dma_setup.w
	JSR	Send_D567_to_VDP
	CLR.w	$6(A0)
Flush_dma_slot_b_skip:
	MOVE.w	$C(A0), D7
	BEQ.b	Flush_dma_slot_c_skip
	MOVE.l	$E(A0), D6
	MOVE.l	#$940093C0, D5
	MOVE.l	#$4DA00082, Vdp_dma_setup.w
	JSR	Send_D567_to_VDP
	MOVE.w	$12(A0), D7
	MOVE.l	$14(A0), D6
	MOVE.l	#$940093C0, D5
	MOVE.l	#$4F200082, Vdp_dma_setup.w
	JSR	Send_D567_to_VDP
	CLR.w	$C(A0)
Flush_dma_slot_c_skip:
	MOVE.w	$18(A0), D7
	BEQ.b	Flush_dma_slot_d_skip
	MOVE.l	$1A(A0), D6
	MOVE.l	#$94019390, D5
	MOVE.l	#$43000082, Vdp_dma_setup.w
	JSR	Send_D567_to_VDP
	CLR.w	$18(A0)
Flush_dma_slot_d_skip:
	MOVE.w	$1E(A0), D7
	BEQ.b	Flush_dma_slot_e_skip
	MOVE.l	$20(A0), D6
	MOVE.l	#$940293D0, D5
	MOVE.l	#$7A000081, Vdp_dma_setup.w
	JSR	Send_D567_to_VDP
	CLR.w	$1E(A0)
Flush_dma_slot_e_skip:
	MOVE.w	$24(A0), D7
	BEQ.b	Flush_dma_crash_check
	MOVE.l	$26(A0), D6
	MOVE.l	#$94049380, D5
	MOVE.l	#$7A000081, Vdp_dma_setup.w
	JSR	Send_D567_to_VDP
	CLR.w	$24(A0)
Flush_dma_crash_check:
	MOVE.w	Crash_animation_flag.w, D0
	BEQ.b	Flush_dma_crash_done
	CLR.w	Crash_animation_flag.w
	LEA	$00FF5980, A6
	SUBQ.w	#1, D0
	BEQ.b	Flush_dma_crash_style_b
	LEA	Hud_rpm_crash_tiles(PC), A6
Flush_dma_crash_style_b:
	MOVE.l	#$664E0003, D7
	MOVEQ	#$00000011, D6
	MOVEQ	#2, D5
	JSR	Draw_tilemap_buffer_to_vdp_32_cell_rows
Flush_dma_crash_done:
	RTS
Update_car_palette_dma:
	MOVE.w	Car_palette_dma_id.w, D0
	BEQ.b	Update_hud_overtake_check
	LEA	Car_livery_palette_1_dma, A0
	SUBQ.w	#1, D0
	BEQ.b	Update_car_palette_send
	LEA	Car_livery_palette_2_dma, A0
Update_car_palette_send:
	MOVE.w	#$9700, D7
	MOVE.b	(A0)+, D7
	MOVE.w	#$9600, D6
	MOVE.b	(A0)+, D6
	SWAP	D6
	MOVE.w	#$9500, D6
	MOVE.b	(A0), D6
	MOVE.l	#$94019340, D5
	MOVE.l	#$52400082, Vdp_dma_setup.w
	JMP	Send_D567_to_VDP
Update_hud_overtake_check:
	TST.w	Track_index_arcade_mode.w
	BNE.w	Update_placement_anim_check
	TST.w	Overtake_event_flag.w
	BEQ.w	Update_overtake_done
	MOVE.w	Current_lap.w, D0
	JSR	Wrap_index_mod10(PC)
	LEA	Rival_placement_palette_cmds(PC), A0
	JSR	Load_palette_vdp_commands_from_table(PC)
	MOVE.l	#$94009340, D5
	MOVE.l	#$7F000083, Vdp_dma_setup.w
	JSR	Send_D567_to_VDP
	MOVE.w	D0, D4
	JSR	Load_palette_vdp_commands_from_table(PC)
	MOVE.l	#$7F800083, Vdp_dma_setup.w
	JSR	Send_D567_to_VDP
	LEA	$00FF5980, A6
	CMPI.w	#2, Overtake_event_flag.w
	BEQ.b	Update_overtake_style_b
	LEA	Overtake_tile_row(PC), A6
Update_overtake_style_b:
	MOVE.l	#$625A0003, D7
	MOVEQ	#3, D6
	MOVEQ	#1, D5
	JSR	Draw_tilemap_buffer_to_vdp_32_cell_rows
	MOVE.w	Current_lap.w, D0
	CMPI.w	#3, D0
	BLS.b	Update_overtake_lap_clamp
	MOVEQ	#3, D0
Update_overtake_lap_clamp:
	ADD.w	D0, D0
	ADD.w	D0, D0
	MOVE.l	#$62A20003, VDP_control_port
	LEA	Placement_tile_data(PC), A0
	MOVE.l	(A0,D0.w), VDP_data_port
	CLR.w	Overtake_event_flag.w
Update_overtake_done:
	RTS
Update_placement_anim_check:
	TST.w	Placement_anim_state.w
	BEQ.w	Update_placement_anim_b_check
	MOVE.w	Current_placement.w, D0
	JSR	Wrap_index_mod10(PC)
	LEA	Rival_placement_palette_cmds(PC), A0
	JSR	Load_palette_vdp_commands_from_table(PC)
	MOVE.l	#$94009340, D5
	MOVE.l	#$52400082, Vdp_dma_setup.w
	JSR	Send_D567_to_VDP
	MOVE.w	D0, D4
	JSR	Load_palette_vdp_commands_from_table(PC)
	MOVE.l	#$52C00082, Vdp_dma_setup.w
	JSR	Send_D567_to_VDP
	MOVE.w	Current_placement.w, D0
	CMPI.w	#3, D0
	BLS.b	Update_placement_lap_clamp
	MOVEQ	#3, D0
Update_placement_lap_clamp:
	ADD.w	D0, D0
	ADD.w	D0, D0
	LEA	Placement_tile_data(PC), A6
	ADDA.w	D0, A6
	LEA	Placement_tile_pair_a(PC), A4
	LEA	Placement_tile_row_b(PC), A3
	CMPI.w	#1, Placement_anim_state.w
	BEQ.b	Update_placement_draw
	LEA	Placement_tile_pair_b(PC), A4
	CMPI.w	#3, Placement_anim_state.w
	BEQ.b	Update_placement_draw
	LEA	$00FF5980, A6
	LEA	(A6), A3
Update_placement_draw:
	MOVE.l	#$62A20003, D7
	MOVEQ	#1, D6
	MOVEQ	#0, D5
	JSR	Draw_tilemap_buffer_to_vdp_32_cell_rows
	MOVE.l	#$625A0003, D7
	MOVEQ	#3, D6
	MOVEQ	#1, D5
	LEA	(A4), A6
	JSR	Draw_tilemap_buffer_to_vdp_32_cell_rows
	MOVE.l	#$62460003, D7
	MOVEQ	#9, D6
	MOVEQ	#1, D5
	LEA	(A3), A6
	JSR	Draw_tilemap_buffer_to_vdp_32_cell_rows
	CLR.w	Placement_anim_state.w
Update_placement_anim_b_check:
	TST.w	Placement_anim_state_b.w
	BEQ.w	Update_placement_b_done
	MOVE.w	Player_grid_position.w, D0
	JSR	Wrap_index_mod10(PC)
	LEA	Player_placement_palette_cmds(PC), A0
	JSR	Load_palette_vdp_commands_from_table(PC)
	MOVE.l	#$94009390, D5
	MOVE.l	#$53400082, Vdp_dma_setup.w
	JSR	Send_D567_to_VDP
	MOVE.w	D0, D4
	JSR	Load_palette_vdp_commands_from_table(PC)
	MOVE.l	#$54600082, Vdp_dma_setup.w
	JSR	Send_D567_to_VDP
	MOVE.w	Player_grid_position.w, D0
	CMPI.w	#3, D0
	BLS.b	Update_placement_b_clamp
	MOVEQ	#3, D0
Update_placement_b_clamp:
	ADD.w	D0, D0
	ADD.w	D0, D0
	LEA	Placement_tile_data(PC), A6
	ADDA.w	D0, A6
	LEA	Car_select_tile_row_a(PC), A4
	CMPI.w	#1, Placement_anim_state_b.w
	BEQ.b	Update_placement_b_draw
	LEA	Car_select_tile_row_b(PC), A4
	CMPI.w	#3, Placement_anim_state_b.w
	BEQ.b	Update_placement_b_draw
	LEA	$00FF5980, A6
Update_placement_b_draw:
	MOVE.l	#$63A20003, D7
	MOVEQ	#1, D6
	MOVEQ	#0, D5
	JSR	Draw_tilemap_buffer_to_vdp_32_cell_rows
	MOVE.l	#$63160003, D7
	MOVEQ	#5, D6
	MOVEQ	#2, D5
	LEA	(A4), A6
	JSR	Draw_tilemap_buffer_to_vdp_32_cell_rows
	CLR.w	Placement_anim_state_b.w
Update_placement_b_done:
	RTS
;Wrap_index_mod10
Wrap_index_mod10:
	ADDQ.w	#1, D0
	MOVE.w	#$000A, D1
	MOVEQ	#1, D4
	SUB.w	D1, D0
	BCC.b	Wrap_index_mod10_done
	ADD.w	D1, D0
	MOVE.w	D1, D4
Wrap_index_mod10_done:
	RTS
;Load_palette_vdp_commands_from_table
Load_palette_vdp_commands_from_table:
; Reads 3 palette bytes from table A0 at index D4 and packs them into VDP
; register-write command words in D7 (CRAM $97) and D6 (CRAM $96/$95).
; Inputs:  A0 = palette table base; D4 = entry index (0-based, multiplied by 4)
; Outputs: D7 = VDP command for register $97 with colour byte; D6 = $96/$95 pair
	ADD.w	D4, D4
	ADD.w	D4, D4
	MOVE.w	#$9700, D7
	MOVE.b	$1(A0,D4.w), D7
	MOVE.l	#$95009600, D6
	MOVE.b	$2(A0,D4.w), D6
	SWAP	D6
	MOVE.b	$3(A0,D4.w), D6
	RTS
;Build_car_tilemap_buffers
Build_car_tilemap_buffers:
; Copy the decompressed player car tilemap from $FFFFEA00 into six 9×32-word
; sub-buffers at $FFFFC080/$FFFFC0C0/$FFFFC100/$FFFFC140/$FFFFC180/$FFFFC1C0,
; each offset by tile base $057F.  These represent the six forward-facing car
; animation frames used during driving.
; Then build four 32×4 priority-flip mirror buffers at $FFFFCE00-$FFFFCF40
; by reading source tiles from $FFFFC8C0/$FFFFC880/$FFFFC840/$FFFFC900 and
; toggling bit 11 (V-flip) via Copy_tiles_with_priority_flip.  These are
; used for rendering the car from a low-angle perspective on hill sections.
; Inputs:  A6 initially $FFFFEA00 (decompressed car tilemap, see Decompress_to_vdp)
	MOVE.w	#$057F, D1
	MOVEQ	#$0000001F, D6
	MOVEQ	#8, D5
	LEA	Tilemap_work_buf.w, A6
	LEA	Decomp_stream_buf.w, A5
	JSR	Copy_tilemap_block_with_base
	MOVEQ	#8, D5
	LEA	Decomp_stream_jump_ptr.w, A5
	JSR	Copy_tilemap_block_with_base
	MOVEQ	#8, D5
	LEA	(Decomp_stream_buf+$80).w, A5
	JSR	Copy_tilemap_block_with_base
	MOVEQ	#8, D5
	LEA	(Decomp_stream_buf+$C0).w, A5
	JSR	Copy_tilemap_block_with_base
	MOVEQ	#8, D5
	LEA	Tilemap_work_buf.w, A6
	LEA	(Decomp_stream_buf+$100).w, A5
	JSR	Copy_tilemap_block_with_base
	MOVEQ	#8, D5
	LEA	(Decomp_stream_buf+$140).w, A5
	JSR	Copy_tilemap_block_with_base
	LEA	Road_car_priority_buf.w, A1
	LEA	(Decomp_stream_buf+$840).w, A0
	BSR.b	Copy_tiles_with_priority_flip
	LEA	(Road_car_priority_buf+$40).w, A1
	LEA	(Decomp_stream_buf+$800).w, A0
	BSR.b	Copy_tiles_with_priority_flip
	LEA	(Road_car_priority_buf+$80).w, A1
	LEA	(Decomp_stream_buf+$7C0).w, A0
	BSR.b	Copy_tiles_with_priority_flip
	LEA	(Road_car_priority_buf+$C0).w, A1
	LEA	(Decomp_stream_buf+$880).w, A0
	BSR.b	Copy_tiles_with_priority_flip
	LEA	(Road_car_priority_buf+$100).w, A1
	LEA	(Decomp_stream_buf+$840).w, A0
	BSR.b	Copy_tiles_with_priority_flip
	LEA	(Road_car_priority_buf+$140).w, A1
	LEA	(Decomp_stream_buf+$800).w, A0
;Copy_tiles_with_priority_flip
Copy_tiles_with_priority_flip:
	MOVEQ	#3, D0
Copy_tiles_with_priority_flip_Outer:
	LEA	(A0), A2
	LEA	(A1), A3
	MOVEQ	#$0000001F, D1
Copy_tiles_with_priority_flip_Inner:
	MOVE.w	-(A2), D2
	EORI.w	#$0800, D2
	MOVE.w	D2, (A3)+
	DBF	D1, Copy_tiles_with_priority_flip_Inner
	LEA	$180(A0), A0
	LEA	$180(A1), A1
	DBF	D0, Copy_tiles_with_priority_flip_Outer
	RTS
Initialize_car_tile_scroll:
; Initialize the car road-scroll tile display at the start of a race.
; Copies 4×32 longwords from the player car forward-facing buffer ($FFFFCE00)
; into the road-car scroll work buffer ($FFFF8B00), using Player_distance_steps
; as a circular index into the 32-entry tile ring.
; Then programs the VDP DMA registers for three sequential DMA copies
; (road car, road background, road priority strip) using fixed control
; longwords and a $40800083 DMA setup word.  Also calls Fill_opponent_scroll_ring to fill in
; the opponent car half of the road-car scroll buffer and
; Set_vdp_mode_h32_variant_a before the final DMA commit.
; Called from Initialize_race_hud (step 9) once before the first Race_loop frame.
	MOVE.w	Player_distance_steps.w, D0
	MOVE.w	D0, Road_scroll_distance_prev.w
	SUBI.w	#$0080, D0
	LSR.w	#2, D0
	ANDI.w	#$00FC, D0
	LEA	Road_car_priority_buf.w, A0
	ADDA.w	D0, A0
	MOVEQ	#$0000007C, D1
	AND.w	D1, D0
	MOVEQ	#3, D2
	LEA	Road_car_scroll_buf.w, A1
Initialize_car_tile_scroll_Outer:
	MOVEQ	#$0000001F, D3
Initialize_car_tile_scroll_Inner:
	MOVE.l	(A0)+, (A1,D0.w)
	ADDQ.w	#4, D0
	AND.w	D1, D0
	DBF	D3, Initialize_car_tile_scroll_Inner
	LEA	$100(A0), A0
	LEA	$80(A1), A1
	DBF	D2, Initialize_car_tile_scroll_Outer
	MOVE.w	#$977F, D7
	MOVE.l	#$96C59580, D6
	MOVE.l	#$94019300, D5
	MOVE.l	#$40800083, Vdp_dma_setup.w
	JSR	Send_D567_to_VDP
	MOVEQ	#8, D2
	BSR.b	Fill_opponent_scroll_ring
	BSR.b	Set_vdp_mode_h32_variant_a
	BRA.w	Set_vdp_mode_h32_variant_b
Update_car_scroll_column:
	MOVEQ	#8, D2
	CMPI.w	#2, Road_column_update_pending.w
	BEQ.b	Fill_opponent_scroll_ring
	MOVE.w	Opponent_scroll_column_span.w, D0
	LSR.w	#3, D0
	CMPI.w	#8, D0
	BHI.b	Fill_opponent_scroll_ring
	MOVE.w	D0, D2
;Fill_opponent_scroll_ring
Fill_opponent_scroll_ring:
	MOVE.w	Player_distance_steps.w, D0
	NEG.w	D0
	SUBI.w	#$0010, D0
	LSR.w	#2, D0
	ANDI.w	#$00FC, D0
	LEA	Decomp_stream_buf.w, A0
	ADDA.w	D0, A0
	MOVEQ	#$0000007C, D1
	AND.w	D1, D0
	MOVE.w	D0, D7
	LEA	Road_car_scroll_buf.w, A1
	MOVEQ	#8, D5
	SUB.w	D2, D5
	LSL.w	#7, D5
	ADDA.w	D5, A1
	ADDA.w	D5, A0
	ADDA.w	D5, A0
	ADDA.w	D5, A0
Fill_opponent_scroll_ring_Outer:
	MOVEQ	#$00000011, D3
Fill_opponent_scroll_ring_Inner:
	MOVE.l	(A0)+, (A1,D0.w)
	ADDQ.w	#4, D0
	AND.w	D1, D0
	DBF	D3, Fill_opponent_scroll_ring_Inner
	MOVE.w	D7, D0
	LEA	$138(A0), A0
	LEA	$80(A1), A1
	DBF	D2, Fill_opponent_scroll_ring_Outer
	RTS
;Set_vdp_mode_h32_variant_a
Set_vdp_mode_h32_variant_a:
	MOVE.w	#$977F, D7
	MOVE.l	#$96C59580, D6
	MOVE.l	#$940193C0, D5
	MOVE.l	#$42800083, Vdp_dma_setup.w
	JMP	Send_D567_to_VDP
Set_vdp_mode_h32_variant_b:
	MOVE.w	#$977F, D7
	MOVE.l	#$96C79540, D6
	MOVE.l	#$94009380, D5
	MOVE.l	#$46000083, Vdp_dma_setup.w
	JMP	Send_D567_to_VDP
Update_background_scroll_delta:
; Compute the per-frame horizontal scroll delta for the road background plane
; and update the car-tile scroll ring buffers with new column data.
;
; Each frame: compares Player_distance_steps against the cached value at
; $FFFF9266.  If the player moved forward ($FFFF9266 > current), calls
; Compute_vram_tile_address to compute new tile pointers for both the
; forward car buffer ($FFFFC080) and the priority-flip buffer ($FFFFCE00)
; and stores them at $FFFF9268.  If the player moved backward, calls
; Compute_vram_tile_address_neg instead.
;
; If $FFFF927E != 0 (car-column update pending flag), calls Update_car_scroll_column to
; copy fresh car tiles into the road-car scroll buffer ($FFFF8B00) and
; then optionally writes road-edge marker tiles into $FFFF8B00 columns
; using Fill_tilemap_column_stride, based on $FFFFAFD8 (road width) and
; $FFFFB018.  Sets $FFFF9276 = 2 to signal a full column update.
	MOVE.w	Player_distance_steps.w, D0
	MOVE.w	Road_scroll_distance_prev.w, D1
	MOVE.w	D0, Road_scroll_distance_prev.w
	SUB.w	D0, D1
	BEQ.b	Update_background_scroll_delta_Column_check
	BMI.w	Update_background_scroll_delta_Reverse
	MOVE.w	#1, Road_column_update_state.w
	LSR.w	#3, D1
	MOVE.w	D1, Road_column_step.w
	MOVE.w	D0, D2
	NEG.w	D0
	LEA	Road_column_src_ptr.w, A1
	LEA	Decomp_stream_buf.w, A0
	JSR	Compute_vram_tile_address(PC)
	MOVE.w	D2, D0
	LEA	Road_car_priority_buf.w, A0
	JSR	Compute_vram_tile_address_neg(PC)
	BRA.b	Update_background_scroll_delta_Column_check
Update_background_scroll_delta_Reverse:
	MOVE.w	#1, Road_column_update_state.w
	NEG.w	D1
	LSR.w	#3, D1
	ORI.w	#$8000, D1
	MOVE.w	D1, Road_column_step.w
	MOVE.w	D0, D2
	NEG.w	D0
	LEA	Road_column_src_ptr.w, A1
	LEA	Decomp_stream_buf.w, A0
	JSR	Compute_vram_tile_address_neg(PC)
	MOVE.w	D2, D0
	LEA	Road_car_priority_buf.w, A0
	JSR	Compute_vram_tile_address(PC)
Update_background_scroll_delta_Column_check:
	MOVE.w	Road_column_update_pending.w, D4
	BEQ.b	Update_background_scroll_delta_Rts
	CLR.w	Road_column_update_pending.w
	JSR	Update_car_scroll_column(PC)
	SUBQ.w	#2, D4
	BEQ.b	Update_background_scroll_delta_Signal_full
	LEA	Road_car_scroll_buf.w, A0
	MOVE.l	#$04420442, D3
	MOVEQ	#$0000007C, D4
	MOVE.w	Player_distance_steps.w, D1
	NEG.w	D1
	ANDI.w	#$01FF, D1
	MOVE.w	Road_scroll_origin_x.w, D0
	SUBI.w	#$0094, D0
	BMI.b	Update_background_scroll_delta_Left_edge_skip
	MOVE.w	D0, D5
	LSR.w	#4, D5
	ADD.w	D1, D0
	LSR.w	#3, D0
	MOVE.w	D0, D2
	ADD.w	D2, D2
	SUBQ.w	#2, D2
	MOVE.w	D5, D0
	ADDQ.w	#1, D0
	MOVEQ	#-4, D5
	JSR	Fill_tilemap_column_stride(PC)
Update_background_scroll_delta_Left_edge_skip:
	MOVE.w	(Main_object_pool+$298).w, D0
	SUBI.w	#$006C, D0
	BPL.b	Update_background_scroll_delta_Left_edge
	MOVEQ	#0, D0
Update_background_scroll_delta_Left_edge:
	MOVE.w	#$0108, D5
	CMP.w	D5, D0
	BCC.b	Update_background_scroll_delta_Signal_full
	SUB.w	D0, D5
	ADD.w	D1, D0
	LSR.w	#3, D0
	MOVE.w	D0, D2
	ADD.w	D2, D2
	LSR.w	#4, D5
	MOVE.w	D5, D0
	ADDQ.w	#1, D0
	MOVEQ	#4, D5
	JSR	Fill_tilemap_column_stride(PC)
Update_background_scroll_delta_Signal_full:
	MOVE.w	#2, Road_column_update_state.w
Update_background_scroll_delta_Rts:
	RTS
;Fill_tilemap_column_stride
Fill_tilemap_column_stride:
	AND.w	D4, D2
	LEA	(A0,D2.w), A1
	MOVE.l	D3, (A1)
	MOVE.l	D3, $80(A1)
	MOVE.l	D3, $100(A1)
	MOVE.l	D3, $180(A1)
	MOVE.l	D3, $200(A1)
	MOVE.l	D3, $280(A1)
	MOVE.l	D3, $300(A1)
	MOVE.l	D3, $380(A1)
	MOVE.l	D3, $400(A1)
	ADD.w	D5, D2
	DBF	D0, Fill_tilemap_column_stride
	RTS
;Compute_vram_tile_address
Compute_vram_tile_address:
	ADDI.w	#$0100, D0
	LSR.w	#2, D0
	MOVE.w	D0, D1
	ANDI.w	#$00FE, D0
	ADDA.w	D0, A0
	MOVE.l	A0, (A1)+
	ANDI.w	#$007E, D1
	MOVE.w	D1, (A1)+
	RTS
;Compute_vram_tile_address_neg
Compute_vram_tile_address_neg:
	SUBQ.w	#8, D0
	LSR.w	#2, D0
	MOVE.w	D0, D1
	ANDI.w	#$00FE, D0
	CMPI.w	#$0080, D0
	BCC.b	Compute_vram_tile_address_neg_Wrap
	ADDI.w	#$0100, D0
Compute_vram_tile_address_neg_Wrap:
	ADDA.w	D0, A0
	MOVE.l	A0, (A1)+
	ANDI.w	#$007E, D1
	MOVE.w	D1, (A1)+
	RTS
Flush_road_column_dma:
	LEA	VDP_data_port, A6
	TST.w	Road_column_tiles_dirty.w
	BEQ.b	Flush_road_column_dma_Skip_tiles
	MOVE.l	#$5F000003, $4(A6)
	LEA	Road_column_tile_buf.w, A0
	MOVE.w	#$000F, D0
Flush_road_column_dma_Tile_loop:
	MOVE.l	(A0)+, (A6)
	DBF	D0, Flush_road_column_dma_Tile_loop
	CLR.w	Road_column_tiles_dirty.w
Flush_road_column_dma_Skip_tiles:
	MOVE.w	Road_column_update_state.w, D4
	BNE.b	Flush_road_column_dma_Scroll_pending
	RTS
Flush_road_column_dma_Scroll_pending:
	CMPI.w	#2, D4
	BNE.b	Flush_road_column_dma_Write_cols
	JSR	Set_vdp_mode_h32_variant_a(PC)
Flush_road_column_dma_Write_cols:
	MOVE.w	#$8F80, VDP_control_port
	MOVE.w	#$C280, D0
	MOVE.w	#$007E, D1
	MOVEA.l	Road_column_src_ptr.w, A0
	MOVE.w	Road_column_step.w, D2
	BPL.w	Flush_road_column_dma_Fwd
	ANDI.w	#$7FFF, D2
	MOVEQ	#-2, D3
	MOVEQ	#2, D5
	BRA.b	Flush_road_column_dma_Col_loop_init
Flush_road_column_dma_Fwd:
	MOVEQ	#2, D3
	MOVEQ	#-2, D5
Flush_road_column_dma_Col_loop_init:
	ADDQ.w	#1, D2
	MOVE.w	D2, D6
	CMPI.w	#2, D4
	BEQ.b	Flush_road_column_dma_Priority_cols
	MOVE.w	Road_column_tile_base.w, D4
Flush_road_column_dma_Col_loop:
	MOVE.w	D0, D7
	ADD.w	D4, D7
	JSR	Tile_index_to_vdp_command
	MOVE.l	D7, $4(A6)
	MOVE.w	(A0), (A6)
	MOVE.w	$180(A0), (A6)
	MOVE.w	$300(A0), (A6)
	MOVE.w	$480(A0), (A6)
	MOVE.w	$600(A0), (A6)
	MOVE.w	$780(A0), (A6)
	MOVE.w	$900(A0), (A6)
	MOVE.w	$A80(A0), (A6)
	MOVE.w	$C00(A0), (A6)
	ADD.w	D3, D4
	AND.w	D1, D4
	ADDA.w	D3, A0
	DBF	D2, Flush_road_column_dma_Col_loop
Flush_road_column_dma_Priority_cols:
	MOVE.w	#$C080, D0
	MOVEA.l	Road_column_priority_ptr.w, A0
	MOVE.w	Road_column_priority_step.w, D4
Flush_road_column_dma_Priority_loop:
	MOVE.w	D0, D7
	ADD.w	D4, D7
	JSR	Tile_index_to_vdp_command
	MOVE.l	D7, $4(A6)
	MOVE.w	(A0), (A6)
	MOVE.w	$180(A0), (A6)
	MOVE.w	$300(A0), (A6)
	MOVE.w	$480(A0), (A6)
	ADD.w	D5, D4
	AND.w	D1, D4
	ADDA.w	D5, A0
	DBF	D6, Flush_road_column_dma_Priority_loop
	MOVE.w	#$8F02, VDP_control_port
	CLR.w	Road_column_update_state.w
	RTS
Send_sign_tileset_to_VDP:
; Stream the next frame of a sign tileset into VRAM via DMA.
; Signs are animated by uploading sequential 480-tile ($1E0) chunks from the
; sign tileset data.  This routine handles the frame counter and wraps around.
;
; $FFFF9264: non-zero = sign DMA pending this frame
; $FFFF9262: current frame counter within the tileset (counts down from $01E1)
; $FFFF925C: 4-byte DMA source address (updated each call by $1E0 tiles)
; $FFFF9260: 2-byte DMA length word
;
; DMA setup words D5/D6/D7 are built by packing the source address into
; VDP DMA length/address registers ($94/$93/$96/$95/$97) and the DMA command
; is stored in Vdp_dma_setup before calling Send_D567_to_VDP.
	TST.w	Sign_tileset_dma_pending.w
	BEQ.b	Send_sign_tileset_to_VDP_Rts
	MOVE.w	Sign_tileset_dma_word_3.w, D0 ; sign tilset byte 7-8
	SUBI.w	#$01E1, D0
	BCS.b	Send_sign_tileset_to_VDP_Last_frame ; jump if D0 was < $01E1
	ADDQ.w	#1, D0
	MOVE.w	D0, Sign_tileset_dma_word_3.w
	MOVE.w	#$01E0, D0
	BRA.b	Send_sign_tileset_to_VDP_Send
Send_sign_tileset_to_VDP_Last_frame:
	CLR.w	Sign_tileset_dma_pending.w
	ADDI.w	#$01E1, D0
Send_sign_tileset_to_VDP_Send:
	MOVE.l	#$00940000, D5
	MOVE.w	D0, D5 ; D5 = $009401Ex (x = 0 or 1)
	LSL.l	#8, D5 ; D5 = $9401Ex00
	MOVE.w	#$9300, D5 ; $94019300
	MOVE.b	D0, D5 ; D5 = $940193Ex
	MOVE.l	Sign_tileset_buf.w, D0 ; sign tilset byte 1-4 (--zzxxyy)
	MOVE.l	#$00960000, D6
	MOVE.w	D0, D6 ; D6 = $0096xxyy
	LSL.l	#8, D6 ; D6 = $96xxyy00
	MOVE.w	#$9500, D6 ; D6 = $96xx95yy
	MOVE.b	D0, D6 ; D6 = $96xx95yy
	MOVE.w	#$9700, D7
	SWAP	D0
	MOVE.b	D0, D7 ; D7 = $97zz
	MOVEQ	#0, D0
	MOVE.w	Sign_tileset_dma_word_2.w, D0 ; sign tilset byte 5-6
	LSL.l	#2, D0
	LSR.w	#2, D0
	SWAP	D0
	ORI.l	#$40000080, D0
	MOVE.l	D0, Vdp_dma_setup.w ; sent to VDP
	JSR	Send_D567_to_VDP
	ADDI.l	#$000001E0, Sign_tileset_buf.w
	ADDI.w	#$03C0, Sign_tileset_dma_word_2.w
Send_sign_tileset_to_VDP_Rts:
	RTS
Copy_ai_scroll_data_to_objects:
	LEA	(Palette_buffer+$36).w, A0
	LEA	Crash_approach_scroll_buf.w, A1
	MOVEQ	#4, D0
Copy_ai_scroll_data_to_objects_loop:
	MOVE.w	(A0)+, (A1)+
	MOVE.w	$1E(A0), $8(A1)
	MOVE.w	$3E(A0), $12(A1)
	DBF	D0, Copy_ai_scroll_data_to_objects_loop
	RTS
Race_hud_full_asset_list:
	dc.b	$00, $0B ; 12 objects
	dc.b	$00, $20
	dc.l	Race_hud_tiles_f
	dc.b	$4D, $00
	dc.l	Race_hud_car_tiles
	dc.b	$7A, $00
	dc.l	Car_sprite_data_53F50
	dc.b	$7F, $80
	dc.l	Car_sprite_data_53DBA
	dc.b	$83, $40
	dc.l	Car_sprite_data_53C28
	dc.b	$86, $40
	dc.l	Race_hud_tiles_c
	dc.b	$90, $A0
	dc.l	Race_hud_tiles_g
	dc.b	$95, $80
	dc.l	Race_hud_tiles_a
	dc.b	$9F, $20
	dc.l	Race_hud_car_tiles_b
	dc.b	$E7, $00
	dc.l	Race_hud_tiles_d
	dc.b	$EB, $80
	dc.l	Race_hud_tiles_e
	dc.b	$EE, $00
	dc.l	Race_hud_tiles_b
;Race_hud_tilemap_list
Race_hud_tilemap_list:
	dc.b	$00, $02
	dc.l	$E0BC0305
	dc.l	Hud_panel_tile_row
	dc.l	$E64E1102
	dc.l	Hud_rpm_crash_tiles
	dc.l	$E6780201
	dc.l	Hud_gear_tile_strip
;Hud_best_lap_tilemap_list
Hud_best_lap_tilemap_list:
	dc.b	$00, $01
	dc.l	Hud_best_lap_label
	dc.l	Hud_best_lap_timer_tilemap
;Hud_best_lap_label
Hud_best_lap_label:
	dc.b	$E1, $06, $FB, $C7, $C0
	txt "BEST", $FA
	txt "LAP", $FF
;Hud_best_lap_timer_tilemap
Hud_best_lap_timer_tilemap:
	dc.b	$E3, $1A, $FB, $C4, $AC, $06, $1A, $06, $06, $1B, $06, $06, $FE, $07, $FA, $07, $07, $FA, $07, $07, $FF, $00
;Hud_rival_lap_tilemap_list
Hud_rival_lap_tilemap_list:
	dc.b	$00, $08
	dc.l	Hud_lap_digit_row
	dc.l	Hud_best_lap_top
	dc.l	Hud_laps_3_label
	dc.l	Hud_laptime_label
	dc.l	Hud_3lap_timer_rows
	dc.l	Hud_lap_label
	dc.l	Hud_countdown_tilemap
	dc.l	Hud_countdown_digit
	dc.l	Hud_3lap_time_grid_a
;Hud_champ_lap_tilemap_list
Hud_champ_lap_tilemap_list:
	dc.b	$00, $05
	dc.l	Hud_best_lap_top
	dc.l	Hud_laps_5_label
	dc.l	Hud_laptime_label_b
	dc.l	Hud_5lap_timer_rows
	dc.l	Hud_lap_label
	dc.l	Hud_3lap_time_grid_b
;Hud_lap_digit_row
Hud_lap_digit_row:
	dc.b	$E0, $62, $FB, $A7, $70, $00, $01, $02, $03, $04, $FE, $05, $06, $07, $08, $09, $FF, $00
;Hud_best_lap_top
Hud_best_lap_top:
	dc.b	$E0, $C4, $FB, $C7, $C0
	txt "BEST", $FA
	txt "LAP", $FF
;Hud_laps_3_label
Hud_laps_3_label:
	dc.b	$E1, $44, $03, $FA
	txt "LAPS", $FF, $00
;Hud_laps_5_label
Hud_laps_5_label:
	dc.b	$E1, $44, $05, $FA
	txt "LAPS", $FF, $00
;Hud_laptime_label
Hud_laptime_label:
	dc.b	$E0, $EC
	txt "LAP", $FA
	txt "TIME", $FF, $00
;Hud_laptime_label_b
Hud_laptime_label_b:
	dc.b	$E0, $6C, $FB, $A7, $C0
	txt "LAP", $FA
	txt "TIME", $FF
;Hud_3lap_timer_rows
Hud_3lap_timer_rows:
	dc.b	$E0, $6E, $FB, $C4, $AC, $06, $1A, $06, $06, $1B, $06, $06, $FE, $07, $FA, $07, $07, $FA, $07, $07, $FD, $FB, $87, $C0, $00, $26, $00, $00, $27, $00, $00, $FE
	dc.b	$00, $26, $00, $00, $27, $00, $00, $FE, $00, $26, $00, $00, $27, $00, $00, $FF
;Hud_5lap_timer_rows
Hud_5lap_timer_rows:
	dc.b	$E0, $AE, $FB, $87, $C0, $00, $26, $00, $00, $27, $00, $00, $FE, $00, $26, $00, $00, $27, $00, $00, $FE, $00, $26, $00, $00, $27, $00, $00, $FE, $00, $26, $00
	dc.b	$00, $27, $00, $00, $FE, $00, $26, $00, $00, $27, $00, $00, $FF, $00
;Hud_lap_label
Hud_lap_label:
	dc.b	$E2, $72, $FB, $A7, $C0
	txt "LAP", $FF, $00
;Hud_countdown_tilemap
Hud_countdown_tilemap:
	dc.b	$E2, $F2, $FB, $C7, $C0, $0D, $29, $19, $29, $FF
;Hud_countdown_digit
Hud_countdown_digit:
	dc.b	$E2, $DE, $30, $FF
;Hud_3lap_time_grid_a
Hud_3lap_time_grid_a:
	dc.b	$E2, $78, $FB, $C4, $AC, $08, $1C, $0C, $FE, $09, $1D, $0D, $FF, $00
;Hud_3lap_time_grid_b
Hud_3lap_time_grid_b:
	dc.b	$E2, $78, $FB, $C4, $AC, $08, $1C, $10, $FE, $09, $1D, $11, $FF, $00
;Hud_champ_warmup_list
Hud_champ_warmup_list:
	dc.b	$00, $02
	dc.l	Hud_best_lap_label
	dc.l	Hud_best_lap_timer_tilemap
	dc.l	Hud_champ_lap_timer
;Hud_champ_lap_timer
Hud_champ_lap_timer:
	dc.b	$E2, $72, $FB, $A7, $C0
	txt "LAP"
	dc.b $FB, $C4, $AC, $08, $1C, $FE, $FA, $FA, $FA, $09, $1D, $FF
;Hud_position_rival_labels
Hud_position_rival_labels:
	dc.b	$E2, $44, $FB, $A7, $C0
	txt "POSITION", $FE, $FA
	txt "YOU", $2B
	txt "RIVAL"
	dc.b	$28, $FA, $FA, $FA, $FA, $FA, $2B, $FF
;Hud_your_position_label
Hud_your_position_label:
	dc.b	$E2, $46, $FB, $A7, $C0
	txt	"YOUR", $FE, $FA
	txt "POSITION", $28, $FF, $00
;Hud_panel_tile_row
Hud_panel_tile_row:
	dc.w	$0000, $0000, $873B, $875C, $875D, $873B, $873B, $875C, $875E, $873B, $873B, $875C, $875E, $873B, $873B, $875C, $875E, $873B, $873B, $875C, $875E, $873B
;Hud_rpm_crash_tiles
Hud_rpm_crash_tiles:
	dc.b	$84, $6D, $84, $70, $84, $73, $84, $76, $00, $00, $00, $00, $84, $89, $84, $8C, $84, $8F, $8C, $8F, $8C, $8C, $8C, $89, $00, $00, $00, $00, $8C, $82, $8C, $7F
	dc.b	$8C, $7C, $8C, $79, $84, $6E, $84, $71, $84, $74, $84, $77, $84, $85, $84, $87, $84, $8A, $84, $8D, $84, $90, $8C, $90, $8C, $8D, $8C, $8A, $8C, $87, $8C, $85
	dc.b	$8C, $83, $8C, $80, $8C, $7D, $8C, $7A, $84, $6F, $84, $72, $84, $75, $84, $78, $84, $86, $84, $88, $84, $8B, $84, $8E, $84, $91, $8C, $91, $8C, $8E, $8C, $8B
	dc.b	$8C, $88, $8C, $86, $8C, $84, $8C, $81, $8C, $7E, $8C, $7B
Placement_tile_data:
	dc.w	$A7DC, $A7DD, $A7D7, $A7CD, $A7DB, $A7CD, $A7DD, $A7D1
;Placement_tile_row_b
Placement_tile_row_b:
	dc.w	$A7D9, $A7D8, $A7DC, $A7D2, $A7DD, $A7D2, $A7D8, $A7D7, $0000, $0000, $0000, $0000, $0000, $0000, $A7D5, $A7D2, $A7D6, $A7D2, $A7DD, $A7E8
;Rival_placement_palette_cmds
Rival_placement_palette_cmds:
	dc.b	$00
	dc.b	$7F
	dc.b	$A4
	dc.b	$A0
	dc.b	$00
	dc.b	$7F
	dc.b	$A4
	dc.b	$E0
	dc.b	$00
	dc.b	$7F
	dc.b	$A5
	dc.b	$20
	dc.b	$00
	dc.b	$7F
	dc.b	$A5
	dc.b	$60
	dc.b	$00
	dc.b	$7F
	dc.b	$A5
	dc.b	$A0
	dc.b	$00
	dc.b	$7F
	dc.b	$A5
	dc.b	$E0
	dc.b	$00
	dc.b	$7F
	dc.b	$A6
	dc.b	$20
	dc.b	$00
	dc.b	$7F
	dc.b	$A6
	dc.b	$60
	dc.b	$00
	dc.b	$7F
	dc.b	$A6
	dc.b	$A0
	dc.b	$00
	dc.b	$7F
	dc.b	$A6
	dc.b	$E0
	dc.b	$00
	dc.b	$7F
	dc.b	$AC
	dc.b	$C0
;Player_placement_palette_cmds
Player_placement_palette_cmds:
	dc.b	$00, $7F, $A7, $20, $00
	dc.b	$7F
	dc.b	$A7
	dc.b	$B0
	dc.b	$00
	dc.b	$7F
	dc.b	$A8
	dc.b	$40
	dc.b	$00
	dc.b	$7F
	dc.b	$A8
	dc.b	$D0
	dc.b	$00
	dc.b	$7F
	dc.b	$A9
	dc.b	$60
	dc.b	$00
	dc.b	$7F
	dc.b	$A9
	dc.b	$F0
	dc.b	$00
	dc.b	$7F
	dc.b	$AA
	dc.b	$80
	dc.b	$00, $7F, $AB, $10, $00, $7F, $AB, $A0, $00, $7F, $AC, $30, $00
	dc.b	$7F
	dc.b	$AC
	dc.b	$C0
;Overtake_tile_row
Overtake_tile_row:
	dc.w	$87F8, $87F9, $87FC, $87FD, $87FA, $87FB, $87FE, $87FF
;Placement_tile_pair_a
Placement_tile_pair_a:
	dc.w	$8492, $8493, $8496, $8497, $8494, $8495, $8498, $8499
;Placement_tile_pair_b
Placement_tile_pair_b:
	dc.w	$A492, $A493, $A496, $A497, $A494, $A495, $A498, $A499
;Car_select_tile_row_a
Car_select_tile_row_a:
	dc.w	$0000, $849A, $849B, $84A3, $84A4, $84A5, $0000, $849D, $849E, $84A6, $84A7, $84A8, $0000, $84A0, $84A1, $84A9, $84AA, $84AB
;Car_select_tile_row_b
Car_select_tile_row_b:
	dc.w	$0000, $A49A, $A49B, $A4A3, $A4A4, $A4A5, $0000, $A49D, $A49E, $A4A6, $A4A7, $A4A8, $0000, $A4A0, $A4A1, $A4A9, $A4AA, $A4AB
;Race_hud_palette_init_data
Race_hud_palette_init_data:
	dc.b	$02, $29, $00, $00, $0E, $EE, $0A, $AA, $02, $22, $06, $66, $04, $4E, $00, $08, $0E, $EE, $08, $88, $0C, $00, $02, $2E, $00, $00, $04, $44, $00, $0E, $00, $CE
	dc.b	$00, $00, $00, $00, $02, $2E, $0E, $EE, $02, $22, $06, $66, $00, $0E, $00, $08, $00, $EE, $00, $88, $04, $44, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	dc.b	$00, $00, $00, $00, $00, $AE, $0E, $EE, $02, $22, $06, $66, $02, $A0, $00, $40, $02, $A0, $00, $40, $04, $44
Team_colour_palette_table: ; Teams in-game palette
	dc.b	$00, $0E, $00, $08,	$00, $EE,	$00, $88 ; Madonna
	dc.b	$02, $2E, $00, $08,	$02, $2E, $00, $08 ; Firenze
	dc.b	$0E, $44, $0A, $02,	$00, $EE, $00, $88 ; Millions
	dc.b	$00, $E0, $00, $60, $00, $EE, $00, $68 ; Bestowal
	dc.b	$0E, $EE, $06, $66, $0E, $44, $08, $00 ; Blanche
	dc.b	$0E, $24, $0A, $02, $0E, $EE, $08, $88 ; Tyrant
	dc.b	$02, $CE, $00, $4A, $02, $CE, $00, $4A ; Losel
	dc.b	$0E, $E2, $0A, $60, $0E, $E2, $0A, $60 ; May
	dc.b	$0E, $46, $0A, $02, $0E, $E8, $0A, $A0 ; Bullets
	dc.b	$02, $6E, $00, $28, $02, $6E, $00, $28 ; Dardan
	dc.b	$0E, $66, $0E, $02, $0E, $66, $0E, $02 ; Linden
	dc.b	$0E, $EE, $06, $66, $00, $CE, $00, $68 ; Minarae
	dc.b	$06, $E0, $02, $60, $06, $E0, $02, $60 ; Rigel
	dc.b	$0C, $EE, $06, $88, $0C, $EE, $06, $88 ; Comet
	dc.b	$06, $66, $02, $22, $00, $EE, $00, $8A ; Orchis
	dc.b	$0E, $EE, $06, $66, $02, $6E, $00, $28 ; ZeroForce
; ============================================================
; GAME FLOW OVERVIEW
;
; The game runs a per-frame callback loop (Frame_callback at $FFFFFF10).
; Each screen installs the next screen's init routine or frame handler
; into Frame_callback when it is ready to transition.
;
; Power-on attract cycle:
;   Race_preview_screen_init  ($23A2)  logo dissolve screen
;     → Attract_screen_logo_frame  ($22D0)  [frame]
;         [START]  → Title_menu ($293C)
;         [timeout] → Practice_mode_init ($3D96)  attract demo lap
;             → Championship_warmup_race_frame ($3D84)  [frame]
;                 → Driver_standings_init ($CCE0)  championship standings scroll
;                     → Driver_standings_frame ($CBEE)  [frame]
;                         [START]  → Title_menu
;                         [auto]   → Pre_race_screen_championship_init ($4BB2)  spinning-car preview
;                             → Pre_race_preview_car_frame ($4B76)  [frame]
;                                 [START/timeout] → Title_menu   (loops attract)
;
; Title screen:
;   Title_menu ($293C)
;     → Title_anim_frame ($2818)  [frame]
;
; From the title menu the player selects one of three modes:
;
;   WORLD CHAMPIONSHIP path:
;     Championship_start_init ($5690)  intro + track select
;       → Title_menu_frame ($5616)  [frame]  track chooser
;           → Options_screen_init ($32E6)  warm-up / race / machine / transmission
;               → Options_setup_frame ($31FE)  [frame]
;                   → Team_select_screen_init ($D2B0)  car/team selection
;                       → Team_select_frame ($CDE2)  [frame]
;                           → Championship_race_init ($375E)  race setup
;                               → Race_loop ($36B6)  [frame]  (full driving engine)
;                                   [finish] → Race_finish_results_init ($42F8)
;                                       → Race_results_frame ($429E)  [frame]
;                                           → Championship_next_race_init ($BD56)
;                                               → Race_result_overlay_frame ($B316)  [frame]
;                                                   → Championship_race_init  (next lap)
;                                           ... (16 races total)
;                                   [last race] → Championship_standings_init ($D5A0)
;                                       → Championship_team_select_frame ($E3D6)  [frame]
;                                           → Team_select_screen_init
;                                   → Championship_standings_2_init ($E94C)
;                                       → Championship_podium_frame ($E77A)  [frame]
;                                           → Team_select_screen_init (next season)
;
;   ARCADE path:
;     Options_screen_arcade_init ($32E0)
;       → Options_setup_frame ($31FE)  [frame]
;           → Arcade_race_init ($3800)  race setup
;               → Race_loop ($36B6)  [frame]
;                   [finish] → Race_finish_results_init ($42F8)
;                       → Race_results_frame ($429E)  [frame]
;                           [repeat] → Pre_race_display_frame ($44A8)  countdown overlay
;                               → Arcade_race_init  (next race)
;                           [game over] → Title_menu
;
;   FREE PRACTICE / WARM-UP:
;     Practice_mode_init ($3D96)
;       → Championship_warmup_race_frame ($3D84)  [frame]
;           → Driver_standings_init (after timer, re-joins attract cycle)
; ============================================================
;$000022D0
; Attract_screen_logo_frame — per-frame handler for the opening attract-mode logo dissolve.
; Pumps the streamed Huffman decompressor each frame and updates sprite objects.
; Dispatches through a 4-phase Screen_scroll table:
;   phase 0/2 — tick countdown timer
;   phase 1   — write one tilemap row chunk (dissolve step)
;   phase 3   — load background tilemap, arm Screen_timer=$017A (≈8 s long-timer)
; On START press → jumps immediately to Title_menu.
; On long-timer expiry → sets default game-mode state and jumps to Practice_mode_init
;   (begins the attract-demo race).
Attract_screen_logo_frame:
	JSR	Wait_for_vblank
	JSR	Start_streamed_decompression
	JSR	Update_objects_and_build_sprite_buffer
	BTST.b	#KEY_START, Input_click_bitset.w
	BNE.b	Attract_screen_logo_Start
	MOVE.w	Screen_scroll.w, D0
	JMP	Attract_screen_logo_dispatch(PC,D0.w)
Attract_screen_logo_dispatch:
	BRA.w	Attract_screen_logo_Tick
	BRA.w	Attract_screen_logo_Upload
	BRA.w	Attract_screen_logo_Tick
	BRA.w	Attract_screen_logo_Load_bg
	BRA.w	Attract_screen_logo_Tick
	MOVE.w	#1, Shift_type.w
	CLR.w	Use_world_championship_tracks.w
	MOVE.w	#1, Track_index_arcade_mode.w
	CLR.w	Track_index.w
	CLR.w	Practice_mode.w
	CLR.w	Warm_up.w
	CLR.w	Practice_flag.w
	MOVE.w	#2, Current_lap.w
	MOVE.w	#Engine_data_offset_practice, Engine_data_offset.w
	CLR.w	Acceleration_modifier.w
	MOVE.l	#Practice_mode_init, Frame_callback.w
	RTS
Attract_screen_logo_Start:
	MOVE.w	#9, Selection_count.w
	MOVE.l	#Title_menu, Frame_callback.w
	RTS
Attract_screen_logo_Tick:
	SUBQ.w	#1, Screen_timer.w
	BNE.b	Attract_screen_logo_Tick_rts
	ADDQ.w	#4, Screen_scroll.w
Attract_screen_logo_Tick_rts:
	RTS
Attract_screen_logo_Upload:
	MOVE.l	#$60820003, D7
	MOVEQ	#$00000026, D6
	MOVEQ	#$00000015, D5
	LEA	Tilemap_work_buf.w, A6
	JSR	Draw_tilemap_buffer_to_vdp_64_cell_rows
	ADDQ.w	#4, Screen_scroll.w
	MOVE.w	#$0017, Screen_timer.w
	RTS
Attract_screen_logo_Load_bg:
	LEA	Attract_screen_logo_tilemap, A0
	MOVE.w	#$0384, D0
	MOVE.l	#$6C200003, D7
	MOVEQ	#8, D6
	MOVEQ	#2, D5
	JSR	Decompress_tilemap_to_vdp_64_cell_rows
	ADDQ.w	#4, Screen_scroll.w
	MOVE.w	#$017A, Screen_timer.w
	RTS
;$000023A2
; Race_preview_screen_init — initialise the attract-mode logo screen (Sega/game logo dissolve).
; Fades palette to black, resets to H40 VDP mode, clears objects.
; Decompresses background and overlay tilemaps into VRAM.
; Arms Screen_timer=$0095 (149-frame display limit) and installs Attract_screen_logo_frame
; as the per-frame callback, then re-enables VBlank.
