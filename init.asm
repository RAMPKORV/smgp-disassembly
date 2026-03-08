; =============================================================================
; ENTRY POINT AND HARDWARE INITIALISATION  ($000210 - ...)
; =============================================================================
; Called from the reset vector.  Full boot sequence:
;
;  1. TMSS check ($210-$225):
;       Test Io_port_settle_l / Io_port_settle_w (slow I/O settle delay area).
;       If non-zero, Boot_init_sentinel is already set → skip to InitDone path.
;       Otherwise fall into the cold-boot VDP/Z80 pre-init block.
;
;  2. Cold-boot pre-init ($226-$2A0):
;       Load register set from Boot_init_data (register init table):
;         D5 = $00008000, D6 = $3FFF, D7 = $0100
;         A0 = Z80 RAM ($00A00000), A1 = Z80_bus_request ($A11100)
;         A2 = Z80_reset ($A11200), A3 = VDP_data_port ($C00000)
;         A4 = VDP_control_port ($C00004)
;       Read Z80 RAM word (A1-$1100 = $A00000); if non-zero the TMSS ASIC is
;       present — write "SEGA" ($53454741) to TMSS register ($A14000) to unlock
;       VDP access.  Skip if TMSS not present (older hardware revisions).
;       Clear D0, set USP to 0.
;       Write 24 VDP initialisation bytes from Boot_init_data+$1C to VDP_control_port.
;       Set VRAM write at $0080 via VDP_control_port.
;       Request Z80 bus ($A11100 = $0100), assert Z80 reset ($A11200 = $0100,
;       $0000, then $0100), wait for bus grant, copy 40 bytes to Z80 RAM.
;       Release Z80 bus ($A11100 = $0000, $A11200 = $0000).
;       Zero $10000 bytes of work RAM via pre-decrement from address 0 ($D6=$3FFF
;       iterations of MOVE.l D0=0, -(A6=0) wraps through $FFFFFFFC downward).
;       Write VDP mode registers $81048F02 (display on, H-int enabled, sprite base).
;       Set VRAM write target at $C0000000.
;       Clear $20 VRAM longwords (32-bit writes to VDP_data_port × $20).
;       Set VRAM write at $0010.
;       Write 4 bytes ($10 area) from remaining Boot_init_data bytes.
;       Release Z80 reset and restore registers from USP (zeroed) area.
;       Disable interrupts (SR = $2700).
;
;  3. ROM checksum verification ($2A0-$2C0):
;       Compute 16-bit checksum: sum all words from ErrorTrap1 ($0200) to
;       EndOfRom-1 (ROMEndLoc gives the byte address; divided by 2 for word
;       count, adjusted for DBF semantics).  Uses a two-level DBF loop to
;       handle the >$10000 iteration count: D0.high holds the outer loop count,
;       D2.low the inner.  Compare result against the stored checksum word at
;       Rom_checksum ($018E in ROM).  If mismatch → jump to bad-ROM handler at
;       Bad_rom_handler (fills plane A with tile $000E, then infinite-loops = red/dark
;       screen, emulator refuses to boot).
;
;  4. First-boot-only initialization ($2C0-$2EE):
;       Call loc_510A (Initialize_default_lap_times): copies ROM default BCD
;       lap-time records into RAM at Track_lap_time_records.
;       Read Version_register ($00A10001) bit 7 (1 = overseas/NTSC).
;       Store result via SNE to $FFFFFF27 (low byte of English_flag word):
;         overseas → English_flag.l = $FFFF (English text)
;         domestic → English_flag.l = $0000 (Japanese text)
;       Write "init" sentinel ($696E6974) to Boot_init_sentinel ($FFFFFFFC) so
;       power-cycle warm-reboots skip the full hardware pre-init.
;
;  5. Full RAM/hardware init ($2EE-$36A): (also entered on warm reboot)
;       Clear entire 64 KB work RAM via CLR.l loop ($1F3F iterations = $8000
;       longwords = $20000 bytes). Note this clears English_flag set above —
;       English_flag is re-initialised by the Options screen later.
;       Set all three I/O direction ports to $40 (port 1-3 output enable).
;       Read Version_register again and set Overseas_flag / Pal_flag via SNE.
;       Initialize VDP registers (Initialize_vdp).
;       Clear audio engine state (Audio_engine_flags = 0).
;       Load Z80 sound driver (Load_z80_driver).
;       Install hblank handler in RAM (Install_hblank_handler).
;       Call loc_6428 (Initialize_ui_buffers): decompresses and sets up all
;         persistent UI tilemap buffers used by the attract/title screens.
;       Load startup graphics (Load_startup_graphics): decompresses initial
;         title/attract tile data to VRAM and RAM.
;       Set Frame_callback = Race_preview_screen_init ($2592).
;       Set Vblank_callback = Default_vblank_handler ($03D8).
;       Enable VBI (Vblank_enable = 1), unmask interrupts (SR &= ~$0700).
;
;  6. Main loop ($36A):
;       Increment Frame_counter.
;       Load and JSR to Frame_callback (function pointer, updated each screen).
;       Loop forever.
EntryPoint:
	TST.l	Io_port_settle_l    ; check I/O settle area — non-zero = warm reboot already done
EntryPoint_Settle_loop:
	BNE.w	EntryPoint_Warm_boot             ; warm reboot: skip to full RAM init (Boot_init_sentinel check)
	TST.w	Io_port_settle_w    ; second half of settle area (debounce complete)
	BNE.b	EntryPoint_Settle_loop
EntryPoint_Cold_boot:
	; ---- Cold-boot: load register-init table and perform pre-boot hardware setup ----
	LEA	Boot_init_data(PC), A5         ; A5 = register init data table (VDP init bytes follow)
	MOVEM.l	(A5)+, D5-D7/A0-A4  ; load D5-D7 and A0-A4 from table; A5 advances past them
	; After MOVEM: D5=$8000, D6=$3FFF, D7=$0100,
	;   A0=Z80_ram($A00000), A1=Z80_bus_request($A11100),
	;   A2=Z80_reset($A11200), A3=VDP_data_port($C00000), A4=VDP_control_port($C00004)
	MOVE.w	-$1100(A1), D0      ; read $A00000 (Z80 RAM[0]) — non-zero indicates TMSS present
	ANDI.w	#$0F00, D0          ; isolate TMSS detect bits
	BEQ.b	EntryPoint_Tmss_done             ; TMSS not present → skip unlock
	MOVE.l	#$53454741, $2F00(A1) ; write "SEGA" to TMSS register ($A14000) to unlock VDP
EntryPoint_Tmss_done:
	MOVE.w	(A4), D0            ; dummy read of VDP control port (status register)
	MOVEQ	#0, D0              ; D0 = 0 (also zeroes address for USP)
	MOVEA.l	D0, A6              ; A6 = $00000000 (used as pre-decrement base for RAM clear)
	MOVE.l	A6, USP             ; USP = 0
	MOVEQ	#$00000017, D1      ; D1 = 23 (24-1 VDP init bytes)
EntryPoint_Vdp_init_loop:
	; Write 24 VDP register init values from A5 (Boot_init_data data) to VDP_control_port.
	; Each byte is written as a word after adding D7=$0100 (register address prefix).
	MOVE.b	(A5)+, D5           ; read next init byte
	MOVE.w	D5, (A4)            ; write to VDP control port
	ADD.w	D7, D5              ; advance register index by 1 (D7=$0100 = reg base)
	DBF	D1, EntryPoint_Vdp_init_loop
	MOVE.l	#$40000080, (A4)    ; set VDP VRAM write address to $0080
	; ---- Z80 bus: assert reset and wait for grant, then copy 40 bytes to Z80 RAM ----
	MOVE.w	D0, (A3)            ; D0=0 → write 0 to VDP_data_port (clear VRAM at $0080)
	MOVE.w	D7, (A1)            ; Z80_bus_request = $0100 → 68K requests Z80 bus
	MOVE.w	D7, (A2)            ; Z80_reset = $0100 → deassert Z80 reset
EntryPoint_Z80_grant_wait:
	BTST.b	D0, (A1)            ; D0=0: test bit 0 of Z80_bus_request — 0 = bus granted
	BNE.b	EntryPoint_Z80_grant_wait             ; wait until Z80 grants the bus
	MOVEQ	#$00000027, D2      ; D2 = 39 (40-1 bytes to copy)
EntryPoint_Z80_copy_loop:
	MOVE.b	(A5)+, (A0)+        ; copy Z80 init bytes from A5 → Z80 RAM at A0
	DBF	D2, EntryPoint_Z80_copy_loop
	MOVE.w	D0, (A2)            ; Z80_reset = 0 → assert Z80 reset
	MOVE.w	D0, (A1)            ; Z80_bus_request = 0 → release bus (Z80 can run)
	MOVE.w	D7, (A2)            ; Z80_reset = $0100 → deassert reset (Z80 starts)
EntryPoint_Ram_clear_loop:
	; Zero entire work RAM ($10000 bytes) by pushing D0=0 via pre-decrement from A6=0.
	; 68K address space wraps: first write goes to $FFFFFFFC, then $FFFFFFF8, etc.,
	; filling all $10000 bytes of work RAM ($FFFF0000-$FFFFFFFF) with zero.
	MOVE.l	D0, -(A6)           ; D0=0, A6 pre-decremented; wraps through all work RAM
	DBF	D6, EntryPoint_Ram_clear_loop             ; D6=$3FFF → 16384 iterations = $10000 bytes cleared
	MOVE.l	#$81048F02, (A4)    ; VDP: mode reg $01=$04 (display on), mode reg $0F=$02
	MOVE.l	#$C0000000, (A4)    ; VDP VRAM write mode at address $0000 (start of VRAM)
	MOVEQ	#$0000001F, D3      ; D3 = 31 (32-1 longwords)
EntryPoint_Vram_clear_loop:
	MOVE.l	D0, (A3)            ; write 0 to VDP_data_port — clears $80 bytes of VRAM
	DBF	D3, EntryPoint_Vram_clear_loop
	MOVE.l	#$40000010, (A4)    ; VDP VRAM write address = $0010 (sprite attr table base)
	MOVEQ	#$00000013, D4      ; D4 = 19 (20-1 longwords)
EntryPoint_Spr_clear_loop:
	MOVE.l	D0, (A3)            ; write 0 to VDP_data_port — clears $50 bytes at $0010
	DBF	D4, EntryPoint_Spr_clear_loop
	MOVEQ	#3, D5              ; D5 = 3 (4-1 bytes)
EntryPoint_Vreg_copy_loop:
	MOVE.b	(A5)+, $10(A3)      ; copy 4 bytes from A5 to VDP_data_port+$10 (write reg)
	DBF	D5, EntryPoint_Vreg_copy_loop
	MOVE.w	D0, (A2)            ; Z80_reset = 0
	MOVEM.l	(A6), D0-D7/A0-A6  ; restore D0-D7/A0-A6 from USP area (all zero at this point)
	; ---- ROM checksum verification ----
	MOVE	#$2700, SR          ; disable all interrupts for checksum calculation
	LEA	ROMEndLoc.w, A0
	MOVE.l	(A0), D0            ; D0 = last ROM byte address (EndOfRom - 1)
	ADDQ.l	#1, D0              ; D0 = ROM size in bytes
	LEA	ErrorTrap1.w, A0    ; A0 = $0200 (start of checksum region, skip vector table+header)
	SUB.l	A0, D0              ; D0 = byte count of checksum region
	ASR.l	#1, D0              ; D0 = word count of checksum region
	MOVE.w	D0, D2              ; D2 = low word (inner loop count)
	SUBQ.w	#1, D2              ; adjust for DBF (first iteration is 'free')
	SWAP	D0                  ; D0.h = 0, D0.l = high word (outer loop count for DBF)
	MOVEQ	#0, D1              ; D1 = running checksum accumulator
EntryPoint_Checksum_loop:
	ADD.w	(A0)+, D1           ; sum each ROM word into D1 (16-bit, discards carry)
	DBF	D2, EntryPoint_Checksum_loop         ; inner loop: $10000 words max per outer iteration
	DBF	D0, EntryPoint_Checksum_loop         ; outer loop: handles ROMs larger than $10000 words
	CMP.w	Rom_checksum.w, D1       ; compare checksum with stored value at ROM header $018E
	BNE.w	Bad_rom_handler             ; mismatch → bad ROM handler (blue screen, infinite loop)
	; ---- First-boot only: init default lap times, detect language, set sentinel ----
	JSR	Initialize_default_lap_times ; copy ROM default BCD lap records to RAM
	MOVE.b	Version_register, D0 ; read hardware version register
	BTST.l	#7, D0              ; bit 7: 1 = overseas/NTSC cartridge
	SNE	English_flag_b.w    ; English_flag.l = $FFFF (English) or $0000 (Japanese)
	MOVE.l	#$696E6974, Boot_init_sentinel.w ; write "init" — skip cold-boot on next reset
EntryPoint_Warm_boot:
	; ---- Warm-reboot entry / full hardware + RAM init ----
	CMPI.l	#$696E6974, Boot_init_sentinel.w ; check sentinel ("init")
	BNE.w	EntryPoint_Cold_boot             ; not set yet → loop back to cold-boot pre-init
	LEA	Work_ram_start.w, A0
	MOVE.w	#$1F3F, D0          ; $1F40 longwords = $7D00 bytes (full 32 KB work RAM)
EntryPoint_Ram_init_loop:
	CLR.l	(A0)+               ; zero 4 bytes
	DBF	D0, EntryPoint_Ram_init_loop         ; repeat $1F40 times — clears all work RAM
	MOVEQ	#$00000040, D0      ; $40 = I/O dir register value (all outputs)
	LEA	Io_ctrl_port_1_dir, A0
	MOVE.b	D0, $0(A0)          ; I/O port 1 direction = all outputs
	MOVE.b	D0, $2(A0)          ; I/O port 2 direction = all outputs
	MOVE.b	D0, $4(A0)          ; I/O port 3 direction = all outputs
	MOVE.b	Version_register, D0 ; read version register again
	BTST.l	#7, D0              ; bit 7: 1 = overseas
	SNE	Overseas_flag.w     ; Overseas_flag = $FF (overseas) or $00 (domestic)
	BTST.l	#6, D0              ; bit 6: 1 = PAL
	SNE	Pal_flag.w          ; Pal_flag = $FF (PAL 50 Hz) or $00 (NTSC 60 Hz)
	JSR	Initialize_vdp
	CLR.w	Audio_engine_flags  ; disable audio engine before loading Z80 driver
	JSR	Load_z80_driver(PC)
	JSR	Install_hblank_handler(PC)
	JSR	Initialize_ui_tilemap_buffers ; decompress and arrange all UI tilemap buffers
	JSR	Load_startup_graphics(PC) ; decompress initial attract/title tile data
	MOVE.l	#$00002592, Frame_callback.w  ; first screen = Race_preview_screen_init
	MOVE.l	#$000003D8, Vblank_callback.w ; VBI handler = Default_vblank_handler
	MOVE.w	#1, Vblank_enable.w ; allow VBI handler to fire
	ANDI	#$F8FF, SR          ; unmask CPU interrupts (IPL → 0)
EntryPoint_Main_loop:
	; ---- Main game loop (runs forever, ~50/60 Hz via VBI) ----
	ADDQ.b	#1, Frame_counter.w ; increment per-frame counter (wraps at 256)
	MOVEA.l	Frame_callback.w, A0 ; load current screen handler pointer
	JSR	(A0)                ; call it — each screen updates its own Frame_callback
	BRA.b	EntryPoint_Main_loop             ; loop unconditionally
Bad_rom_handler:
	; ---- Bad-ROM handler: checksum mismatch ----
	; Initializes VDP, writes tile $000E (dark colour) to all 64 plane-A cells,
	; then halts in an infinite loop.  Emulators detect the blank dark screen as
	; the "wrong region / bad checksum" error; some show a red screen overlay.
	JSR	Initialize_vdp
	MOVE.l	#$C0000000, VDP_control_port ; VRAM write at address $0000
	MOVEQ	#$0000003F, D7      ; 64-1 words
EntryPoint_Bad_rom_fill:
	MOVE.w	#$000E, VDP_data_port ; write tile index $000E (dark palette entry)
	DBF	D7, EntryPoint_Bad_rom_fill
EntryPoint_Bad_rom_halt:
	BRA.b	EntryPoint_Bad_rom_halt             ; infinite loop — CPU halted
Wait_for_vblank:
; Synchronise the caller to the next vertical blank interrupt.
; Clears Vblank_counter then busy-waits until the VBI handler increments it.
; This produces one full frame of latency and is used before palette/VDP
; operations that must complete outside the active display period.
	CLR.w	Vblank_counter.w
Wait_for_vblank_loop:
	TST.w	Vblank_counter.w
	BEQ.b	Wait_for_vblank_loop
	RTS
Wait_for_practice_vblank_cycle:
	JSR	Wait_for_vblank(PC)
	CMPI.w	#$000C, Practice_vblank_step.w
	BLT.b	Wait_for_practice_vblank_cycle
	CLR.w	Practice_vblank_step.w
	RTS
Vertical_blank_interrupt:
	MOVEM.l	D0-D7/A0-A6, -(A7)
	TST.w	Vblank_enable.w
	BEQ.b	Vblank_interrupt_tail
	MOVEA.l	Vblank_callback.w, A0
	JSR	(A0) ; =Practice_mode_vblank_handler in practice mode
Vblank_interrupt_tail:
	ANDI	#$F8FF, SR
	JSR	Update_audio_engine
	ADDQ.w	#1, Vblank_counter.w
	MOVEM.l	(A7)+, D0-D7/A0-A6
	RTE
;$000003D8
Default_vblank_handler:
	JSR	Upload_h40_tilemap_buffer_to_vram
	BRA.b	Vblank_tail
;$000003E0
Default_vblank_handler_h32:
	JSR	Upload_h32_tilemap_buffer_to_vram
Vblank_tail:
	JSR	Update_input_bitset
	JMP	Upload_palette_buffer_to_cram
Install_hblank_handler:
	LEA	Hblank_handler_stub_src(PC), A0
	LEA	Hblank_handler_stub.w, A1
	MOVE.w	#$0014, D0
Install_hblank_handler_Loop:
	MOVE.w	(A0)+, (A1)+
	DBF	D0, Install_hblank_handler_Loop
	RTS
Hblank_handler_stub_src:
	dc.w	$0C39, $00DE, $00C0, $0008, $6608, $33FC, $8AFF, $00C0, $0004, $23FC, $4002, $0010, $00C0, $0004, $33F8, $9D40, $00C0, $0000, $5478, $FFF0, $4E73
Load_startup_graphics:
	LEA	Road_tiles_startup, A0
	MOVE.l	#$78000003, VDP_control_port
	JSR	Decompress_to_vdp
	LEA	Startup_screen_tiles_b, A0
	LEA	$00FF4940, A4
	JSR	Decompress_to_ram
	LEA	Startup_tileset_data, A0
	LEA	$00FF0100, A4
	JMP	Decompress_to_ram
Load_z80_driver:
; Copy the Z80 sound driver code from Z80_data (ROM) to Z80 RAM ($A00000),
; then release bus control to let the Z80 execute the freshly loaded driver.
;
; Protocol:
;   1. Write $0100 to Z80_bus_request ($A11100) to request 68K ownership of Z80 bus.
;   2. Reset_z80 asserts Z80 /RESET ($A11200 = $0000) then releases it ($0100) to
;      ensure the Z80 is in a known idle state before the 68K writes to its RAM.
;   3. Copy $1C10 bytes from Z80_data to Z80 RAM at $A00000.
;   4. Reset_z80 again to force the Z80 to start executing from address $0000 in its
;      freshly loaded RAM.
;   5. Write $0000 to Z80_bus_request to release the bus, letting the Z80 run.
;   6. Fall through to Halt_audio_sequence to initialise the audio sequence timer.
;
; The Z80 driver code is a complete sound driver that handles YM2612 FM synthesis
; and PSG tone generation.  Once loaded, the 68K communicates with it solely by
; writing command bytes to specific Z80 RAM locations via Write_byte_to_z80_ram.
	MOVE.w	#$0100, Z80_bus_request
	BSR.b	Reset_z80
	LEA	Z80_data, A5
	LEA	$00A00000, A6
	MOVE.w	#$1C0F, D0
Load_z80_driver_Loop:
	MOVE.b	(A5)+, (A6)+
	DBF	D0, Load_z80_driver_Loop
	BSR.b	Reset_z80
	MOVE.w	#0, Z80_bus_request
	JMP	Halt_audio_sequence
Reset_z80:
; Assert and then release the Z80 hardware reset line.
;
; Write $0000 to Z80_reset ($A11200) to pull /RESET low, hold for ~14 NOPs
; (sufficient setup time), then write $0100 to release /RESET.  After release
; the Z80 will start (or re-start) execution from address $0000 in its RAM.
;
; NOTE: The 68K must already hold Z80_bus_request ($A11100 = $0100) before
; calling this routine; the Z80 bus must not be released between the reset
; assertion and the data copy that follows in Load_z80_driver.
	MOVE.w	#0, Z80_reset
	MOVEQ	#$0000000D, D0
Reset_z80_Loop:
	NOP
	DBF	D0, Reset_z80_Loop
	MOVE.w	#$0100, Z80_reset
	RTS
;Boot_init_data
Boot_init_data:
; Register initialisation table used by EntryPoint cold-boot pre-init.
; MOVEM.l (A5)+, D5-D7/A0-A4 loads the first 7 longwords into registers;
; the byte arrays that follow are consumed as init data by subsequent loops.
;
; Register values loaded:
;   D5 = $00008000  (TMSS check threshold / VDP reg write scratch)
;   D6 = $00003FFF  (RAM clear loop count: $4000 iterations = $10000 bytes)
;   D7 = $00000100  (Z80/reset port enable value; VDP register address step)
;   A0 = $00A00000  (Z80 RAM base)
;   A1 = Z80_bus_request  ($00A11100)
;   A2 = Z80_reset        ($00A11200)
;   A3 = VDP_data_port    ($00C00000)
;   A4 = VDP_control_port ($00C00004)
;
; VDP register init bytes (24 bytes, written with D7=$0100 offset per byte):
;   Written as MOVE.w D5, VDP_control_port with D5 = byte + $0100.
;   Bytes: $04 $14 $30 $3C $07 $6C $00 $00 $00 $00 $FF $00
;          $81 $37 $00 $01 $01 $00 $00 $FF $FF $00 $00 $80
;
; Z80 init bytes (40 bytes, copied verbatim to Z80 RAM at $A00000):
;   These bytes set up the Z80 register state and minimal startup code
;   that the Z80 runs briefly before Load_z80_driver copies the full driver.
;   $AF $01 $D7 $1F $11 $29 $00 $21 $28 $00 $F9 $77 $ED $B0 $DD $E1
;   $FD $E1 $ED $47 $ED $4F $08 $D9 $F1 $C1 $D1 $E1 $08 $D9 $F1 $D1
;   $E1 $F9 $F3 $ED $56 $36 $E9 $E9
;
; Trailing 4 bytes written to VDP_data_port+$10 at EntryPoint_Vreg_copy_loop: $9F $BF $DF $FF
	dc.l	$00008000	;D5 = TMSS check / VDP reg scratch
	dc.l	$00003FFF	;D6 = RAM clear loop count
	dc.l	$00000100	;D7 = Z80 bus request / VDP register address step
	dc.l	$00A00000	;A0 = Z80 RAM base
	dc.l	Z80_bus_request	;A1 = $00A11100
	dc.l	Z80_reset	;A2 = $00A11200
	dc.l	VDP_data_port	;A3 = $00C00000
	dc.l	VDP_control_port	;A4 = $00C00004
	dc.b	$04, $14, $30, $3C, $07, $6C, $00, $00, $00, $00, $FF, $00, $81, $37, $00, $01, $01, $00, $00, $FF, $FF, $00, $00, $80, $AF, $01, $D7, $1F, $11, $29, $00, $21
	dc.b	$28, $00, $F9, $77, $ED, $B0, $DD, $E1, $FD, $E1, $ED, $47, $ED, $4F, $08, $D9, $F1, $C1, $D1, $E1, $08, $D9, $F1, $D1, $E1, $F9, $F3, $ED, $56, $36, $E9, $E9
	dc.b	$9F, $BF, $DF, $FF
