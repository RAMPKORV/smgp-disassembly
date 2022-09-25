; TODO: Verify and come up with variable names
; 0xfc01: cursor position in menu
; 0xfc10: cursor position on title screen
; 0x5ac9: the volume of 'enemy' car engine sounds
; 0x5adc: some sort of frame counter that is reset when you start a race etc
; 0x5b01: Track data (curves)
; 0x900a: Amount of (warmup?) laps to drive. 16-bit.
; 0x9030: List of driver points awarded, by team order
; 0x9043: Player team
; 0x9044: Drivers and teams mapping
; 0x905E: ???
; 0x906E: The placement (this round) of each team during the results
; 0x907E: Points awarded (this round) per team during results
; 0x9100: Current shift
; 0x9102: Engine RPM. When meter is 10, value is 1000
; 0x9104: Engine RPM to be rendered (used for smooth gauge movement)
; 0x9106: Speed (why two?)
; 0x9108: Speed
; 0x9144.w: Current track idx to be loaded from Track_data
; 0x9146.w: 0 right before lap start, then 1 when lap starts. When 0, several code paths are skipped and RPM only updates visually
; 0x9148.w: practice mode
; 0x914A.w: warm up
; Data written from Team_car_characteristics:
; - 0x915C: Acceleration selector
; - 0x915E: Engine_data_offset selector
; - 0x9160: steering?
; - 0x9162: breaks?
; - 0x9164: rpm?
; 0x9161: steering
; 0x9180: "Engine_data_variant" - RPM for current shift offset (based on Player_team, practice mode is $003C)
; 0x9182: Acceleration modifier based on Player_team (0 in practice mode)
; 0x9206: ?
; 0x9208: Controls acceleration. 0 in practice mode, can be 1 or 2.
; 0x9222: ?
; 0x9226; ?
; 0x9240: Pointer to start of signs data for current track
; 0x9244: Pointer to current signs data location
; 0x924C.l: Pointer to signs data (in ROM)
; 0x9250: ?
; 0xA980: ? Some struct
; 0xAE00: Player state struct ??
; 0xae12: Player horizontal position (0 middle, positive right, negative left)
; 0xae1a: Player distance on current track
; 0xae26: Player's current speed (read only)
; 0xE9EC: 10 bytes determines team color
; 0xFC14: ?
; 0xfc50: crash recoil from signs (word)
; 0xfc54: Set last bit to crash/retire (word)
; 0xfc80: Disables speed update (boolean)
; 0xFCA6: Typically false, setting to true makes car almost always accelerate
; 0xFF04: Input key state bitset: start, A, C, B, right, left, down, up
; 0xFF05: Input key click bitset: Set for one frame if key clicked?
; 0xFF20: Input key mapping ("Control type" in settings)
; - 0xFF20: Key for Shift down
; - 0xFF21: Key for Shift up
; - 0xFF22: Key for Accelerate
; - 0xFF23: Key for Break
; 0xff26: Language. 0 = Japanese, 1 = English
; 0xffae: Copy of speed (useless, only written to?)
; 0xff2e: Current shift type (0 = automatic, 1 = 4-shift, 2 = 7-shift)
