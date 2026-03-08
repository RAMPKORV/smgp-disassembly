; ============================================================
; Sound control register
; ============================================================
Engine_sound_pitch = $FFFFE996 ; word written to control engine sound pitch:
                                ;   $022E (558)  = normal engine tone
                                ;   $0E86 (3718) = high-pitch shift-warning pulse

; ============================================================
; Audio engine state struct at $FF5AC0 (68K-side audio driver state)
;
; The 68K drives its own YM2612/PSG-based engine sound system using a 68K-side
; audio engine state struct at $FF5AC0.  The per-frame update routine
; (Update_audio_engine, called once per Race_loop frame) reads RPM/speed/shift
; state, encodes note data via Encode_z80_note, and then writes the encoded
; bytes directly to the Z80 RAM window ($A01FA0-$A01FC6) using the Z80 bus
; arbitration sequence in Write_byte_to_z80_ram.  The struct is also used to
; sequence music playback commands and per-channel volume envelopes.
;
; Struct base: $FF5AC0  (A6 in Update_audio_engine)
; Scratch buffer: $FF5AF0  (A4 in Update_audio_engine; 12 bytes of note data)
;
; Field offsets (all .w unless noted):
;   +$00  music command latch  – game code writes a song ID here to queue a track change
;   +$02  music mode/state     – bits 0-3 = active mode; written $000F to silence all channels
;   +$04  engine speed word    – scaled player speed for pitch calculation
;   +$06  channel flags        – bit 0 = engine sound active; bit 1 = ?
;   +$08  PSG ch1 note         – note/frequency index for PSG channel 1 ($00FF = silent)
;   +$0A  PSG ch1 pitch bend
;   +$0C  PSG ch2 note         – note/frequency index for PSG channel 2 ($00FF = silent)
;   +$0E  PSG ch2 pitch bend
;   +$12  fade-in/out counter  – counts down to 0; non-zero suppresses volume write
;   +$14  previous shift word  – last sampled Player_shift value for change detection
;   +$16  vibrato/bend counter – decrements; controls vibrato depth modulation
;   +$18  volume word          – current volume level sent to Z80
;   +$1A  pitch word           – current base pitch sent to Z80 (derived from speed)
;   +$1C  frame counter        – free-running +1 per Update_audio_engine call
;   +$1E  engine flags byte    – bit 0 = rev-up/screech active; bit 1 = fade-in pending
;   +$20  note step counter    – counts through the loc_762AA note-sequence table (mod $001F)
;   +$22  sequence timer       – countdown to next note-sequence step; $8000 = halted
;   +$24  command-latch byte   – pending per-channel command byte; 0 = no command
;   +$26  screech hold counter – frames to hold the screech/rev note
;   +$28  PSG channel data     – two-byte PSG state packed as longword
;   +$29  screech decay counter
;
; Audio_engine_state = $FF5AC0
; Audio_engine_scratch = $FF5AF0  (12-byte buffer used by Encode_z80_note calls)
; ============================================================
Audio_engine_state    = $00FF5AC0 ; base of 68K audio engine state struct
Audio_engine_scratch  = $00FF5AF0 ; 12-byte per-frame note data scratch buffer

; Audio engine control fields (absolute addresses for use outside the update routine):
Audio_music_cmd     = $00FF5AC0   ; +$00 .w  music track command latch (game code writes song ID here)
Audio_music_state   = $00FF5AC2   ; +$02 .w  music mode/state word
Audio_engine_speed  = $00FF5AC4   ; +$04 .w  scaled speed word for engine pitch calculation
Audio_engine_flags  = $00FF5AC6   ; +$06 .w  channel enable flags (bit 0 = engine on)
Audio_engine_vol_ch1 = $00FF5AC8  ; +$08 .w  PSG channel 1 volume/note word ($00FF = silent)
Audio_engine_vol_ch2 = $00FF5ACC  ; +$0C .w  PSG channel 2 volume/note word ($00FF = silent)
Audio_sfx_cmd       = $00FF5AE0   ; +$20 .w  sound-effect command port (game code writes SFX ID here)
Audio_seq_timer     = $00FF5AE2   ; +$22 .w  sequence countdown timer ($8000 = halted)
Audio_ctrl_mode     = $00FF5AE4   ; +$24 .b  audio control mode byte ($80 = trigger playback, $01 = mode 1)

; Z80 RAM communication addresses (offsets within Z80 address space at $A00000):
; These are the specific Z80 RAM locations the 68K writes to via Write_byte_to_z80_ram.
; Actual Z80 RAM is 8 KB at Z80 offsets $0000-$1FFF.
Z80_audio_music_cmd = $00A01C09   ; Z80 RAM: music command byte (song ID $81-$8F -> $01-$0F)
Z80_audio_sfx_cmd_b = $00A01C0D   ; Z80 RAM: SFX command slot B (3 bytes)
Z80_audio_sfx_cmd_c = $00A01C10   ; Z80 RAM: SFX command slot C (1 byte)
Z80_audio_engine_ch1 = $00A01FA0  ; Z80 RAM: PSG engine channel 1 note data (6 bytes)
Z80_audio_engine_ch1b = $00A01FA2 ; Z80 RAM: PSG engine channel 1 note data (16 bytes, long block)
Z80_audio_engine_ch2 = $00A01FC0  ; Z80 RAM: PSG engine channel 2 note data (6 bytes)
Z80_audio_engine_ch2b = $00A01FC2 ; Z80 RAM: PSG engine channel 2 note data (4 bytes, long block)
Z80_audio_pitch_sfm  = $00A01FB3  ; Z80 RAM: FM engine pitch/mode byte
Z80_audio_key_on     = $00A01FB7  ; Z80 RAM: key-on/off command byte for YM2612 channel

; ------------------------------------------------------------
; Music track IDs (written to Audio_music_cmd before Trigger_music_playback)
; The 68K encodes the final Z80 command as $80 + song_id.
; ------------------------------------------------------------
Music_credits            = 2    ; credits scroll screen
Music_pre_race           = 3    ; pre-race briefing screen (both arcade and championship)
Music_race_results       = 5    ; race finish results screen (Race_results_frame)
Music_title_screen       = 6    ; title screen / attract mode
Music_race               = 7    ; in-race music (triggered at race start via AI car init)
Music_game_over          = 8    ; game over confirm screen
Music_team_select        = 9    ; team / driver select screen
Music_championship_start = 14   ; championship start screen (driver/team intro)
Music_championship_next  = 13   ; next race in championship (standard team)
Music_championship_next_special = 11 ; next race in championship (special/Marlboro team path)
Music_race_result_overlay = $0C ; race result overlay screen (Race_result_overlay_frame)
Music_rival_encounter    = $11  ; rival team encounter / briefing screen (attract and championship)
Music_championship_final = $0F  ; championship final ending cutscene

; Arcade race music is set from Options_cursor_update ($10 = music on, 0 = silent)

; ------------------------------------------------------------
; Sound effect IDs (written to Audio_sfx_cmd)
; ------------------------------------------------------------
Sfx_menu_cursor          = $02  ; menu cursor move / option scroll sound
Sfx_pre_race_countdown   = $04  ; pre-race countdown (practice mode path)
Sfx_race_start_go        = $05  ; race start "go" signal (practice mode path)
Sfx_checkpoint           = $06  ; checkpoint / lap marker event
Sfx_menu_confirm         = $0E  ; menu item confirm / navigation sound
Sfx_collision_thud       = $0B  ; car collision thud
Sfx_asphalt              = $10  ; on-road tyre/surface sound
Sfx_rough_road           = $11  ; rough road surface (Road_marker_state == 2)
Sfx_gravel               = $12  ; gravel / grass off-road
Sfx_demo_transition      = $1B  ; attract/demo button-press screen transition (written twice)

