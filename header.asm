; =============================================================================
; ROM HEADER AND EXCEPTION VECTOR TABLE  ($000000 - $0001FF)
; =============================================================================
; The first $200 bytes of a Sega Mega Drive ROM contain two fixed structures
; required by the 68000 hardware and the Mega Drive BIOS:
;
;  $000000 - $0000FF  M68K exception vector table (64 longword handlers)
;  $000100 - $0001FF  Sega Mega Drive ROM header (ASCII strings + memory map)
;
; VECTOR TABLE ($000000 - $0000FF)
; ---------------------------------
; The M68K reads this table on reset.  Each entry is a 32-bit handler address.
;  Offset  Vector #  Description
;  $00     0         Initial Supervisor Stack Pointer (loaded into A7/SSP)
;  $04     1         Initial Program Counter (first instruction = EntryPoint)
;  $08     2         Bus error
;  $0C     3         Address error
;  $10     4         Illegal instruction
;  $14     5         Division by zero
;  $18     6         CHK instruction exception
;  $1C     7         TRAPV instruction exception
;  $20     8         Privilege violation
;  $24     9         TRACE exception
;  $28     10        Line-A emulator (unimplemented instruction $Axxx)
;  $2C     11        Line-F emulator (unimplemented instruction $Fxxx)
;  $30-$5C 12-23     Reserved (unused by 68000)
;  $60     24        Spurious interrupt
;  $64-$6C 25-27     IRQ levels 1-3 (unused)
;  $70     28        IRQ level 4 = horizontal blank interrupt (HINT)
;  $74     29        IRQ level 5 (unused)
;  $78     30        IRQ level 6 = vertical blank interrupt (VINT)
;  $7C     31        IRQ level 7 (NMI, unused)
;  $80-$BC 32-47     TRAP #0-#15 (all unused — return immediately)
;  $C0-$FF 48-63     Reserved (point to ErrorTrap3 infinite-loop halt)
;
; ACTIVE INTERRUPT HANDLERS:
;  IRQ 4 (HINT, $70): Points to Hblank_handler_stub in RAM ($FFFFFFD2).
;    The stub is copied there at startup by Install_hblank_handler and
;    contains a short inline handler (road-line palette effect + hscroll update).
;  IRQ 6 (VINT, $78): Points to Vertical_blank_interrupt, which calls the
;    Vblank_callback function pointer, runs Update_audio_engine, and increments
;    Vblank_counter so the main loop can sync to 50/60 Hz.
StartOfRom:
Vectors:
;Initial_sp
Initial_sp:
	dc.l	$00FF0100  ; Initial stack pointer value ($00FF0100 = top of 68K work RAM)
;Reset_vector
Reset_vector:
	dc.l	EntryPoint ; Reset vector: first instruction executed on power-on
;Bus_error_vector
Bus_error_vector:
	dc.l	ErrorTrap1 ; Bus error        — NOP + infinite branch
	dc.l	ErrorTrap1 ; Address error    — NOP + infinite branch
	dc.l	ErrorTrap2 ; Illegal instruction — NOP + infinite branch
	dc.l	ErrorTrap2 ; Division by zero — NOP + infinite branch
	dc.l	ErrorTrap3 ; CHK exception    — NOP + infinite branch
	dc.l	ErrorTrap3 ; TRAPV exception  — NOP + infinite branch
	dc.l	ErrorTrap3 ; Privilege violation — NOP + infinite branch
	dc.l	ErrorTrap3 ; TRACE exception  — NOP + infinite branch
	dc.l	ErrorTrap3 ; Line-A emulator  — NOP + infinite branch
	dc.l	ErrorTrap3 ; Line-F emulator  — NOP + infinite branch
	dc.l	ErrorTrap3 ; Reserved #12
	dc.l	ErrorTrap3 ; Reserved #13
	dc.l	ErrorTrap3 ; Reserved #14
	dc.l	ErrorTrap3 ; Reserved #15
	dc.l	ErrorTrap3 ; Reserved #16
	dc.l	ErrorTrap3 ; Reserved #17
	dc.l	ErrorTrap3 ; Reserved #18
	dc.l	ErrorTrap3 ; Reserved #19
	dc.l	ErrorTrap3 ; Reserved #20
	dc.l	ErrorTrap3 ; Reserved #21
	dc.l	ErrorTrap3 ; Reserved #22
	dc.l	ErrorTrap3 ; Reserved #23
	dc.l	ErrorTrap3 ; Spurious interrupt
	dc.l	Return_from_exception ; IRQ level 1 (unused — RTE)
	dc.l	Return_from_exception ; IRQ level 2 (unused — RTE)
	dc.l	Return_from_exception ; IRQ level 3 (unused — RTE)
	dc.l	Hblank_handler_stub  ; IRQ level 4 — horizontal blank (HINT), handler in RAM
	dc.l	Return_from_exception ; IRQ level 5 (unused — RTE)
	dc.l	Vertical_blank_interrupt ; IRQ level 6 — vertical blank (VINT)
	dc.l	Return_from_exception ; IRQ level 7 (unused — RTE)
	dc.l	Return_from_exception ; TRAP #00 (unused — RTE)
	dc.l	Return_from_exception ; TRAP #01 (unused — RTE)
	dc.l	Return_from_exception ; TRAP #02 (unused — RTE)
	dc.l	Return_from_exception ; TRAP #03 (unused — RTE)
	dc.l	Return_from_exception ; TRAP #04 (unused — RTE)
	dc.l	Return_from_exception ; TRAP #05 (unused — RTE)
	dc.l	Return_from_exception ; TRAP #06 (unused — RTE)
	dc.l	Return_from_exception ; TRAP #07 (unused — RTE)
	dc.l	Return_from_exception ; TRAP #08 (unused — RTE)
	dc.l	Return_from_exception ; TRAP #09 (unused — RTE)
	dc.l	Return_from_exception ; TRAP #10 (unused — RTE)
	dc.l	Return_from_exception ; TRAP #11 (unused — RTE)
	dc.l	Return_from_exception ; TRAP #12 (unused — RTE)
	dc.l	Return_from_exception ; TRAP #13 (unused — RTE)
	dc.l	Return_from_exception ; TRAP #14 (unused — RTE)
	dc.l	Return_from_exception ; TRAP #15 (unused — RTE)
	dc.l	ErrorTrap3 ; Reserved #48
	dc.l	ErrorTrap3 ; Reserved #49
	dc.l	ErrorTrap3 ; Reserved #50
	dc.l	ErrorTrap3 ; Reserved #51
	dc.l	ErrorTrap3 ; Reserved #52
	dc.l	ErrorTrap3 ; Reserved #53
	dc.l	ErrorTrap3 ; Reserved #54
	dc.l	ErrorTrap3 ; Reserved #55
	dc.l	ErrorTrap3 ; Reserved #56
	dc.l	ErrorTrap3 ; Reserved #57
	dc.l	ErrorTrap3 ; Reserved #58
	dc.l	ErrorTrap3 ; Reserved #59
	dc.l	ErrorTrap3 ; Reserved #60
	dc.l	ErrorTrap3 ; Reserved #61
	dc.l	ErrorTrap3 ; Reserved #62
	dc.l	ErrorTrap3 ; Reserved #63
; =============================================================================
; SEGA MEGA DRIVE ROM HEADER  ($000100 - $0001FF)
; =============================================================================
; This 256-byte block is read by the Mega Drive BIOS/TMSS hardware to verify
; the cartridge and provide metadata.  All text fields are ASCII, padded with
; spaces to their fixed widths.  The BIOS checks the console name field for
; "SEGA MEGA DRIVE" (or "SEGA GENESIS") before granting VDP access on TMSS
; hardware.  Emulators also use the region field and ROM/RAM map entries.
;
;  Offset  Size  Description
;  $00     16    Console name: "SEGA MEGA DRIVE "
;  $10     16    Copyright/date: "(C)SEGA 1990.JUN"
;  $20     48    Domestic (JP) game name: "Super Monaco GP" + spaces
;  $50     48    International game name: "Super Monaco GP" + spaces
;  $80     14    Product/version code: "GM     4026-01"
;  $8E      2    Checksum word (sum of all ROM words from $0200 to end)
;  $90     16    I/O device support: 'J' = 3-button joypad, rest spaces
;  $A0      4    ROM start address: $00000000
;  $A4      4    ROM end address: EndOfRom - 1
;  $A8      4    RAM start address: $00FF0000
;  $AC      4    RAM end address: $00FFFFFF
;  $B0      4    Backup RAM ID: "    " (no SRAM)
;  $B4      4    Backup RAM start address: spaces (no SRAM)
;  $B8      4    Backup RAM end address: spaces (no SRAM)
;  $BC     12    Modem support: blank (no modem)
;  $C8     52    Notes/memo: blank (unused, free to use without affecting the ROM)
;  $FC     16    Region codes: "JUE " = Japan, USA, Europe supported
Header:
	dc.b "SEGA MEGA DRIVE " ; Console name (must match for TMSS unlock on VA1+ hardware)
	dc.b "(C)SEGA 1990.JUN" ; Copyright holder and release date
	dc.b "Super Monaco GP                                 " ; Domestic (Japan) title (48 bytes)
	dc.b "Super Monaco GP                                 " ; International title (48 bytes)
	dc.b "GM     4026-01" ; Product code (GM = game, 4026-01 = part/revision number)
;Rom_checksum
Rom_checksum:
	dc.w	$65B5 ; Checksum: sum of all ROM words from $0200 to end of ROM
	dc.b	'J               ' ; I/O device support ('J' = standard 3-button joystick/joypad)
	dc.l StartOfRom ; ROM start address ($00000000)
ROMEndLoc:
	dc.l EndOfRom-1 ; ROM end address (assembled at link time from EndOfRom label)
	dc.l $00FF0000 ; Work RAM start address
	dc.l $00FFFFFF ; Work RAM end address
	dc.b "    "		; Backup/SRAM ID ("    " = no battery-backed SRAM present)
	dc.l $20202020		; Backup RAM start address (spaces = unused)
	dc.l $20202020		; Backup RAM end address (spaces = unused)
	dc.b "            "	; Modem support string (blank = no modem)
	dc.b "                                        "	; Memo/notes field (52 bytes, no ROM effect)
	dc.b "JUE             " ; Region support: J=Japan, U=USA, E=Europe
; =============================================================================
; ERROR TRAP HANDLERS  ($000200 - $00020F)
; =============================================================================
; Three variants, all structurally identical: NOP + infinite BRA.b back to self.
; The three variants exist so the vector table can point distinct addresses at
; each class of exception, making it possible to identify which exception fired
; in a hardware debugger by inspecting the PC of the halted CPU.
;
;  ErrorTrap1 ($0200): Bus error, Address error
;  ErrorTrap2 ($0204): Illegal instruction, Division by zero
;  ErrorTrap3 ($0208): All other reserved/unused exception vectors
;
; In all cases the CPU halts here indefinitely with interrupts still masked.
; There is no error display; the screen freezes or shows corrupted output.
ErrorTrap1:
	NOP
	BRA.b	ErrorTrap1
ErrorTrap2:
	NOP
	BRA.b	ErrorTrap2
ErrorTrap3:
	NOP
	BRA.b	ErrorTrap3
Return_from_exception:
	RTE
