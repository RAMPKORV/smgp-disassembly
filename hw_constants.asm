; ============================================================
; Hardware registers
; ============================================================
VDP_control_port = $C00004
VDP_data_port    = $C00000
Z80_bus_request  = $A11100  ; write $0100 to request, $0000 to release; bit 0 = bus not yet granted
Z80_reset        = $A11200  ; write $0000 to assert reset, $0100 to release reset
Z80_ram          = $A00000  ; base address of Z80 address space as seen from 68K ($A00000-$A0FFFF)

; I/O port registers ($A10000 area)
; The Mega Drive exposes its controller/expansion ports here.
; All accesses must be bracketed by Z80 bus request/release
; because the Z80 also drives the bus during its ISR.
; Registers exist as 16-bit slots; the 68K accesses data bytes at odd addresses.
; Even addresses carry the upper half of each 16-bit slot (used at boot for settle checks).
Version_register    = $00A10001 ; .b  hardware version byte: bit 7 = overseas, bit 6 = PAL
Io_ctrl_port_1_data = $00A10003 ; .b  controller port 1 data register (read: button state)
Io_ctrl_port_2_data = $00A10005 ; .b  controller port 2 data register
Io_ctrl_port_3_data = $00A10007 ; .b  controller port 3 / expansion port data register
Io_ctrl_port_1_dir  = $00A10009 ; .b  controller port 1 direction register ($40 = TH output)
Io_ctrl_port_2_dir  = $00A1000B ; .b  controller port 2 direction register
Io_ctrl_port_3_dir  = $00A1000D ; .b  controller port 3 / expansion port direction register
; Boot settle check addresses (even = upper byte of 16-bit port slot; reads before RAM init):
Io_port_settle_l    = $00A10008 ; .l  read as longword at boot entry to flush pending I/O state
Io_port_settle_w    = $00A1000C ; .w  read as word in settle-wait loop until both ports are idle

