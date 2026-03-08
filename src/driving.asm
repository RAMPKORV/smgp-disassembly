Update_rpm:
	TST.w	Race_started.w
	BEQ.b	Update_rpm_Pre_race_anim
	TST.w	Spin_off_track_flag.w
	BNE.b	Update_rpm_Crash_decel
	BSR.w	Update_rpm_Collision_penalty
	BSR.w	Update_rpm_Slipstream
	BSR.w	Update_rpm_Slope_drag
	BSR.w	Update_rpm_Collision_speed
	MOVE.b	Control_key_accel.w, D5
	MOVE.b	Control_key_brake.w, D6
	TST.w	Crash_spin_flag.w
	BNE.b	Update_rpm_Accel_lookup
	BTST.b	D6, Input_state_bitset.w ; if brake key pressed
	BNE.w	Update_visual_rpm        ; then only update visual rpm, Update_breaking will do RPM update instead
Update_rpm_Accel_lookup:
	LEA	Acceleration_data, A1
	CLR.l	D0
	MOVE.w	Shift_type.w, D0
	LSL.l	#7, D0
	ADDA.l	D0, A1
	MOVE.w	Player_shift.w, D0
	LSL.w	#5, D0
	ADDA.l	D0, A1
	MOVE.w	Player_rpm.w, D0
	DIVS.w	#50, D0
	MOVE.w	#$FF00, D1
	MOVE.b	(A1,D0.w), D1 ; D1 = $FF00 + value from Acceleration_data
	BTST.l	#7, D1
	BNE.b	Apply_acceleration_done ; Jump if max rpm for shift?
	ANDI.w	#$00FF, D1 ; D1 = value from Acceleration_data (acc)
	MOVE.w	Acceleration_modifier.w, D0; # Either of $FFFF(-1), $0000, $0001, $0002
	BEQ.b	Apply_acceleration_done ; D0 == 0
	BMI.b	Update_rpm_Accel_degrade ; D0 < 0
	MOVE.w	D1, D2
	LSR.w	D0, D2 ; D2 = 0.5x or 0.25x acc
	ADD.w	D2, D1 ; acc = acc*1.25 or acc*1.5
	BRA.b	Apply_acceleration_done
Update_rpm_Accel_degrade:
	MOVE.w	D1, D2
	NEG.w	D0 ; $FFFF -> $0001 (only possible value)
	LSR.w	D0, D2 ; D2 = acc/2
	SUB.w	D2, D1 ; acc = acc/2
Apply_acceleration_done:
	TST.w	Road_marker_state.w
	BEQ.b	Update_rpm_Road_drag_done
	CLR.l	D2
	MOVE.w	Player_speed.w, D2
	LSR.w	#5, D2
	SUB.w	D2, D1
	CMPI.w	#2, Road_marker_state.w
	BNE.b	Update_rpm_Road_drag_done
	MOVE.w	Player_shift.w, D2
	LSL.w	#2, D2
	SUB.w	D2, D1
Update_rpm_Road_drag_done:
	MOVE.w	Player_shift.w, D2
	SUBQ.w	#8, D2
	TST.w	Crash_spin_flag.w
	BNE.b	Update_rpm_Accel_apply
	BTST.b	D5, Input_state_bitset.w ; if accelerate key pressed
	BNE.b	Update_rpm_Accel_apply
	BRA.b	Update_rpm_Idle_decel
	dc.b	$4A, $78, $91, $00, $67, $EC, $D4, $42, $0C, $78, $00, $01, $92, $08, $67, $02, $D4, $42
Update_rpm_Idle_decel:
	ADD.w	D2, Player_rpm.w
	BPL.b	Update_rpm_Clamp_max
	MOVE.w	#0, Player_rpm.w
	BRA.b	Update_visual_rpm
Update_rpm_Accel_apply:
	CMPI.w	#Engine_rpm_max, Player_rpm.w
	BCC.b	Update_rpm_At_max ; Jump if rpm >= max
	ADD.w	D1, Player_rpm.w ; Actual RPM update from calculated acceleration
	BPL.b	Update_rpm_Clamp_max
	MOVE.w	#0, Player_rpm.w
	BRA.b	Update_visual_rpm
Update_rpm_Clamp_max:
	CMPI.w	#Engine_rpm_max, Player_rpm.w
	BCS.b	Update_visual_rpm ; Jump if rpm < max
Update_rpm_At_max:
	ADDI.w	#-50, Player_rpm.w
; Update_visual_rpm - interpolate gauge needle (Visual_rpm) toward Player_rpm
;
; Called as fall-through from Update_rpm (and from Update_breaking via fall-through path).
; Visual_rpm approaches Player_rpm at up to +80 RPM/frame (rising) or -150 RPM/frame (falling).
; The +1 bias ensures the needle always "hunts" above zero when RPM is near zero.
Update_visual_rpm:
	MOVE.w	Player_rpm.w, D0
	ADDQ.w	#1, D0
	SUB.w	Visual_rpm.w, D0 ; D0 = (rpm+1) - visual_rpm == delta between rpm and visual (but +1)
	BMI.b	Update_visual_rpm_Falling ; Jump if (rpm+1) - visual_rpm < 0, meaning rpm+1 < visual_rpm (rpm is at least 2 less than visual)
	CMPI.w	#80, D0
	BCS.b	Apply_visual_rpm_delta ; if delta > 80
	MOVE.w	#80, D0  ; then delta = 80
	BRA.b	Apply_visual_rpm_delta
Update_visual_rpm_Falling:
	CMPI.w	#-150, D0
	BCC.b	Apply_visual_rpm_delta  ; if delta < -150
	MOVE.w	#-150, D0 ; then delta = -150
Apply_visual_rpm_delta:
	ADD.w	D0, Visual_rpm.w ; Add capped delta to visual rpm, making it approach actual rpm (but +1)
	RTS
Update_rpm_Collision_penalty:
	MOVE.w	Rpm_derivative.w, D0 ; Suspected derivative of rpm
	BEQ.b	Update_rpm_Collision_apply
	SUBQ.w	#1, D0
Update_rpm_Collision_apply:
	TST.w	Collision_flag.w
	BEQ.b	Update_rpm_Collision_rts
	CMPI.w	#$0040, D0
	BEQ.b	Update_rpm_Collision_set
	ADDQ.w	#2, D0
Update_rpm_Collision_set:
	MOVE.w	D0, Rpm_derivative.w
	LSR.w	#4, D0
	SUB.w	D0, Player_rpm.w
	BCC.b	Update_rpm_Collision_rts
	ADD.w	D0, Player_rpm.w
Update_rpm_Collision_rts:
	RTS
Update_rpm_Slipstream:
	MOVE.w	Player_speed.w, D4
	BEQ.b	Update_rpm_Slipstream_rts
	MOVE.w	Horizontal_position.w, D1
	MOVE.w	#$0060, D2
	MOVEQ	#0, D7
	LEA	Ai_car_array.w, A2
	MOVEQ	#$0000000E, D0
Update_rpm_Slipstream_loop:
	MOVE.w	$26(A2), D5
	BEQ.b	Update_visual_rpm_Next
	SUB.w	D4, D5
	BCC.b	Update_rpm_Slipstream_check_x
	ADDI.w	#100, D5
	BMI.b	Update_visual_rpm_Next
Update_rpm_Slipstream_check_x:
	MOVE.w	$E(A2), D6
	BMI.b	Update_visual_rpm_Next
	CMP.w	D6, D2
	BCC.b	Update_visual_rpm_Next
	MOVE.w	$12(A2), D3
	SUB.w	D1, D3
	BPL.b	Update_rpm_Slipstream_abs_x
	NEG.w	D3
Update_rpm_Slipstream_abs_x:
	CMPI.w	#$0040, D3
	BCC.b	Update_visual_rpm_Next
	CMP.w	$E(A2), D7
	BCC.b	Update_visual_rpm_Next
	MOVE.w	$E(A2), D7
;Update_visual_rpm_Next
Update_visual_rpm_Next:
	LEA	$40(A2), A2
	DBF	D0, Update_rpm_Slipstream_loop
	TST.w	D7
	BEQ.b	Update_rpm_Slipstream_rts
	SUBI.w	#$0060, D7
	LSR.w	#5, D7
	ADDQ.w	#1, D7
	ADD.w	D7, Player_rpm.w
Update_rpm_Slipstream_rts:
	RTS
Update_rpm_Slope_drag:
	MOVE.w	Track_phys_slope_value.w, D0 ; physical slope at current position (negative = uphill → RPM drag)
	BEQ.b	Update_rpm_Return
	BTST.b	#0, Frame_counter.w
	BNE.b	Update_rpm_Return
	ADD.w	D0, Player_rpm.w
	BPL.b	Update_rpm_Return
	CLR.w	Player_rpm.w
Update_rpm_Return:
	RTS
Update_rpm_Collision_speed:
	MOVE.w	Collision_speed_penalty.w, D0
	BEQ.b	Update_rpm_Collision_speed_skip
	LSR.w	#3, D0
	ADDQ.w	#1, D0
	MOVE.w	Player_speed_raw.w, D1
	BEQ.b	Update_rpm_Collision_speed_skip
	LSR.w	#5, D1
	ADDQ.w	#1, D1
	MULS.w	D1, D0
	MOVE.w	#2, D1
	LSL.w	D1, D0
	ADDI.w	#80, D0
	SUB.w	D0, Player_speed_raw.w
	BCC.b	Update_rpm_Speed_apply    ; if speed < 0
	CLR.w	Player_speed_raw.w ; then speed = 0
	BRA.b	Update_rpm_Speed_apply
Update_rpm_Collision_speed_skip:
	TST.w	Ai_speed_override.w
	BEQ.b	Update_rpm_Speed_rts
	MOVE.w	Ai_speed_override.w, Player_speed_raw.w
Update_rpm_Speed_apply:
	MOVE.w	Player_speed_raw.w, Player_speed.w ; Deacceleration from non-lethal obstacle collision
	CLR.l	D0
	LEA	Engine_data, A1
	MOVE.w	Engine_data_offset.w, D0
	ADDA.l	D0, A1
	MOVE.w	Shift_type.w, D0
	LSL.l	#3, D0
	ADDA.l	D0, A1
	MOVE.w	Player_shift.w, D0
	LSL.l	#1, D0
	MOVE.w	(A1,D0.w), D1
	MOVE.w	Player_speed_raw.w, D0
	MULS.w	D1, D0
	DIVS.w	#100, D0
	MOVE.w	D0, Player_rpm.w
Update_rpm_Speed_rts:
	RTS
Acceleration_data: ; Derivative of RPM during acceleration
; Each "column" correspond to intervals of 50 engine RPM. [0-49], [50-59], ... [1550, 1599]
; Automatic
	dc.b	$32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $2A, $2A, $2A, $2C, $2C, $2E, $2E, $2F, $30, $32, $26, $16, $08, $FF, $FD, $FB, $00, $00 ; shift 0
	dc.b	$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $07, $07, $08, $08, $08, $09, $09, $09, $09, $0A, $0C, $0A, $07, $03, $FF, $FD, $FB, $00, $00 ; shift 1
	dc.b	$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $03, $03, $03, $04, $04, $04, $05, $05, $06, $06, $06, $07, $06, $03, $01, $FF, $FD, $FB, $00, $00 ; shift 2
	dc.b	$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $01, $01, $01, $01, $01, $01, $01, $FF, $FD, $FB, $F9, $00, $00 ; shift 3
; 4-shift
	dc.b	$32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $28, $28, $28, $29, $29, $2A, $2A, $2B, $2B, $2D, $1E, $0C, $05, $FF, $FD, $FB, $00, $00 ; shift 0
	dc.b	$01, $01, $01, $01, $02, $02, $02, $03, $03, $03, $04, $04, $05, $06, $06, $06, $07, $07, $07, $08, $08, $09, $09, $0B, $0A, $07, $03, $FF, $FD, $FB, $00, $00 ; shift 1
	dc.b	$01, $01, $01, $01, $01, $01, $01, $01, $02, $02, $02, $02, $03, $03, $03, $03, $04, $04, $04, $05, $05, $06, $06, $08, $05, $03, $01, $FF, $FD, $FB, $00, $00 ; shift 2
	dc.b	$01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $02, $02, $02, $02, $01, $01, $01, $01, $01, $FF, $FD, $FB, $00, $00 ; shift 3
; 7-shift
	dc.b	$32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $32, $26, $28, $2B, $2E, $32, $32, $32, $32, $32, $32, $1E, $0F, $05, $FF, $FD, $FB, $00, $00 ; shift 0
	dc.b	$05, $05, $05, $05, $05, $05, $05, $05, $05, $05, $05, $05, $05, $05, $09, $0A, $0B, $0B, $0D, $0D, $10, $10, $11, $13, $0E, $05, $01, $FF, $FD, $FB, $00, $00 ; shift 1
	dc.b	$03, $04, $03, $04, $03, $04, $04, $04, $04, $04, $05, $05, $05, $06, $06, $07, $07, $08, $08, $09, $09, $0A, $0A, $0B, $08, $04, $01, $FF, $FD, $FB, $00, $00 ; shift 2
	dc.b	$02, $02, $02, $02, $02, $02, $03, $03, $03, $03, $03, $04, $04, $04, $05, $05, $05, $06, $06, $07, $07, $07, $08, $08, $06, $04, $02, $FF, $FD, $FB, $00, $00 ; shift 3
	dc.b	$02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $03, $03, $03, $03, $03, $03, $04, $04, $04, $04, $04, $04, $05, $05, $03, $02, $01, $FF, $FD, $FB, $00, $00 ; shift 4
	dc.b	$01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $02, $02, $02, $02, $02, $02, $03, $03, $03, $03, $02, $01, $01, $FF, $FD, $FB, $00, $00 ; shift 5
	dc.b	$01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $FF, $FD, $FB, $F9           ; shift 6
; Update_engine_sound_pitch - write engine tone or shift-warning pulse to sound register
;
; Called from Race_loop step 5 (Update_engine_sound_pitch).
; In automatic mode: always writes normal pitch $022E.
; In manual modes: flickers to $0E86 (high pitch, every 4th frame) when:
;   - RPM < 700 and not in gear 0  → downshift warning
;   - RPM > 1300 and not at top gear → upshift warning
; The $0E86 pulse produces an audible warning to prompt the player to shift.
Update_engine_sound_pitch:
	MOVE.w	#$022E, D0
	MOVE.w	Shift_type.w, D1
	BEQ.b	Update_engine_sound_pitch_Write
	CMPI.w	#700, Player_rpm.w
	BCC.b	Update_engine_sound_pitch_High_rpm
	CMPI.w	#0, Player_shift.w
	BEQ.b	Update_engine_sound_pitch_Write
	BRA.b	Update_engine_sound_pitch_Warn
Update_engine_sound_pitch_High_rpm:
	CMPI.w	#1300, Player_rpm.w
	BCS.b	Update_engine_sound_pitch_Write
	CMPI.w	#6, Player_shift.w
	BEQ.b	Update_engine_sound_pitch_Write
	CMPI.w	#2, Shift_type.w
	BEQ.b	Update_engine_sound_pitch_Warn
	CMPI.w	#3, Player_shift.w
	BEQ.b	Update_engine_sound_pitch_Write
Update_engine_sound_pitch_Warn:
	BTST.b	#2, Frame_counter.w
	BEQ.b	Update_engine_sound_pitch_Write
	MOVE.w	#$0E86, D0
;Update_engine_sound_pitch_Write
Update_engine_sound_pitch_Write:
	MOVE.w	D0, Engine_sound_pitch.w ; $022E (normal) or $0E86 (shift-warning pulse)
	RTS
; Update_speed - derive Player_speed from Player_rpm using Engine_data table
;
; Called from Race_loop step 6 (drive model update, skipped when retired).
; Computes target speed = Player_rpm * 100 / Engine_data[team][shift_type][shift],
; where Engine_data entries give the RPM value that corresponds to 100 km/h for that gear.
; The delta to the current Player_speed is clamped to +2 / -5 km/h per frame to smooth
; the speedometer display and prevent instant speed jumps.
;
; Outputs:
;   Player_speed_raw - un-smoothed speed (km/h) for this RPM
;   Player_speed     - rate-limited smoothed speed (km/h)
Update_speed:
	CLR.l	D0
	LEA	Engine_data, A1
	MOVE.w	Engine_data_offset.w, D0
	ADDA.l	D0, A1
	MOVE.w	Shift_type.w, D0
	LSL.l	#3, D0
	ADDA.l	D0, A1
	MOVE.w	Player_shift.w, D0
	LSL.l	#1, D0
	MOVE.w	(A1,D0.w), D1 ; RPM for 100km/h for current shift
	MOVE.w	Player_rpm.w, D0 ; Current RPM
	MULS.w	#100, D0 ; D0 = D0 * 100
	DIVS.w	D1, D0 ; D0 = D0 / D1
	MOVE.w	D0, Player_speed_raw.w ; new speed before acceleration min/max check. ($9102)/D1*100
	SUB.w	Player_speed.w, D0 ; delta speed
	BMI.b	Update_speed_Decel_clamp ; if negative, go to max deacceleration check
	CMPI.w	#2, D0
	BCS.b	Apply_speed_delta ; if not D0 < 2 (max acceleration)
	MOVE.w	#2, D0   ; then D0 = 2
	BRA.b	Apply_speed_delta
Update_speed_Decel_clamp:
	CMPI.w	#-5, D0
	BCC.b	Apply_speed_delta   ; if D0 < -5 (max deacceleration)
	MOVE.w	#-5, D0 ; then D0 = -5
Apply_speed_delta:
	ADD.w	D0, Player_speed.w; Add delta speed and return
	RTS
Engine_data: ; Defines RPM at 100km/h for each shift and shift type, 6 different variants for different teams
	dc.w	1674, 823, 584, 467
	dc.w	1674, 816, 570, 446
	dc.w	1858, 923, 639, 507, 447, 418, 383
	dc.w	1662, 799, 548, 419
	dc.w	1662, 792, 534, 398
	dc.w	1850, 907, 615, 475, 407, 370, 327
; Practice mode:
	dc.w	1660, 795, 542, 411                ; RPM at 100km/h for automatic
	dc.w	1660, 788, 528, 390                ; RPM at 100km/h for 4-shift
	dc.w	1849, 905, 612, 471, 402, 364, 320 ; RPM at 100km/h for 7-shift
	dc.w	1658, 791, 536, 403
	dc.w	1652, 784, 522, 382
	dc.w	1848, 903, 609, 467, 397, 358, 313
	dc.w	1656, 787, 530, 395
	dc.w	1650, 780, 516, 374
	dc.w	1847, 901, 606, 463, 392, 352, 306
	dc.w	1654, 783, 524, 387
	dc.w	1648, 776, 510, 366
	dc.w	1846, 899, 603, 459, 387, 346, 299
; Update_breaking - apply brake deceleration to Player_rpm
;
; Called from Race_loop step 6 (drive model update, skipped when retired).
; Note: the "breaking" spelling is original to the ROM (not corrected).
;
; If brake key is held:
;   1. If rpm > Engine_rpm_max (1500): shed 40 RPM first.
;   2. Look up braking strength from Braking_strength_table [shift_type * 4 + shift]:
;        automatic (type 0): 50 / 40 / 30 / 20 RPM/frame for shifts 0-3
;        4-shift   (type 1): 50 / 40 / 30 / 20 RPM/frame for shifts 0-3
;        7-shift   (type 2): 48 / 42 / 36 / 30 / 24 / 18 / 12 / 6 for shifts 0-6
;   3. In world-championship mode (not practice): apply track-quality modifier from Braking_track_modifier_table
;      (signed byte adjustment ±6, indexed by Track_braking_index).
;   4. Player_rpm -= braking_strength; clamped to 0.
; Skipped entirely if Crash_spin_flag is set.
Update_breaking:
	TST.w	Crash_spin_flag.w
	BNE.b	Update_breaking_Return
	MOVE.b	Control_key_brake.w, D6
	BTST.b	D6, Input_state_bitset.w ; if break key pressed, then continue
	BEQ.b	Update_breaking_Return   ; else exit early
	CMPI.w	#Engine_rpm_max, Player_rpm.w
	BCS.b	Update_breaking_Apply           ; if rpm > max
	ADDI.w	#-40, Player_rpm.w ; then rpm = rpm-40
Update_breaking_Apply:
	CLR.l	D1
	LEA	Braking_strength_table, A1
	MOVE.w	Shift_type.w, D0
	LSL.w	#2, D0
	ADD.w	Player_shift.w, D0
	MOVE.b	(A1,D0.w), D1
	TST.w	Use_world_championship_tracks.w
	BEQ.b	Subtract_rpm_floor_zero
	TST.w	Practice_mode.w
	BNE.b	Subtract_rpm_floor_zero
	MOVE.w	Track_braking_index.w, D0
	LEA	Braking_track_modifier_table(PC), A0
	ADD.w	(A0,D0.w), D1
	BPL.b	Subtract_rpm_floor_zero
	MOVEQ	#0, D1
Subtract_rpm_floor_zero:
	SUB.w	D1, Player_rpm.w
	BPL.b	Update_breaking_Return
	MOVE.w	#0, Player_rpm.w
Update_breaking_Return:
	RTS
Braking_strength_table:
; RPM reduction per frame while braking, indexed by [Shift_type*4 + Player_shift].
; automatic (0): 50/40/30/20 for shifts 0-3
; 4-shift   (1): 50/40/30/20 for shifts 0-3
; 7-shift   (2): 48/42/36/30/24/18/12/6 for shifts 0-6 (plus one extra entry)
	dc.b	$32
	dc.b	$28
	dc.b	$1E
	dc.b	$14, $32, $28, $1E, $14, $30, $2A, $24, $1E, $18, $12, $0C
	dc.b	$06
Braking_track_modifier_table:
; Signed byte adjustments to braking strength, indexed by Track_braking_index.
; Negative values = weaker braking (slippery), positive = stronger.
	dc.b	$FF, $FA, $FF, $FE
	dc.w	$0000
	dc.b	$00, $02, $00, $04, $00, $06
; Update_steering - process left/right input and update Road_x_offset / Steering_output
;
; Called from Race_loop step 10.
; Road_x_offset is an unsigned byte: $80 = lane centre, $08 = hard left, $F8 = hard right.
; Three track-edge zones determine the displacement step per frame:
;   D4 (default $0F): normal zone — standard lateral step
;   D5 (default $13): approach zone — larger step (entering track boundary)
;   D6 (default $18): hard boundary — maximum step (at the very edge)
; In world-championship mode, all four parameters are adjusted per track via Track_steering_index.
;
; If no key is pressed (or Retire_animation_flag active): auto-centre at rate D3 (default 9).
; Dead zone [$79..$87] around centre snaps to $80.
; Replay/AI override: Replay_steer_override 1 = force RIGHT, other nonzero = force LEFT.
;
; Outputs:
;   Road_x_offset  — new unsigned byte road centre position ($80 = centre)
;   Steering_output — signed offset with dead zone stripped, fed to Update_horizontal_position
Update_steering:
	MOVEQ	#9, D3
	MOVEQ	#$0000000F, D4
	MOVEQ	#$00000013, D5
	MOVEQ	#$00000018, D6
	TST.w	Use_world_championship_tracks.w
	BEQ.b	Update_steering_Check_input
	TST.w	Practice_mode.w
	BNE.b	Update_steering_Check_input
	MOVE.w	Track_steering_index.w, D0
	ADD.w	D0, D0
	ADD.w	D0, D0
	LEA	Track_steering_params(PC), A0
	ADDA.w	D0, A0
	ADD.w	(A0)+, D3
	ADD.w	(A0)+, D4
	ADD.w	(A0)+, D5
	ADD.w	(A0)+, D6
Update_steering_Check_input:
	MOVE.b	Road_x_offset.w, D7
	MOVE.b	Input_state_bitset.w, D0
	TST.w	Retire_animation_flag.w
	BNE.w	Update_steering_Auto_centre
	TST.w	Replay_steer_override.w
	BEQ.b	Update_steering_Apply_input
	CMPI.w	#1, Replay_steer_override.w
	BNE.b	Update_steering_Override_left
	BSET.l	#KEY_RIGHT, D0
	BCLR.l	#KEY_LEFT, D0
	BRA.b	Update_steering_Apply_input
Update_steering_Override_left:
	BCLR.l	#KEY_RIGHT, D0
	BSET.l	#KEY_LEFT, D0
Update_steering_Apply_input:
	ANDI.b	#$0C, D0 ; Reset keys except left+right
	BEQ.b	Update_steering_Auto_centre ; Jump if no key pressed
	CMP.b	Track_boundary_type.w, D0
	BEQ.b	Update_steering_Boundary
	BTST.l	#KEY_LEFT, D0
	BNE.b	Update_steering_Left_boundary
	CMPI.b	#$55, D7
	BCC.b	Update_steering_Normal_step
	MOVE.b	#8, Track_boundary_type.w
	MOVE.b	D5, Track_boundary_wobble.w
	CMPI.b	#$31, D7
	BCC.b	Update_steering_Boundary
	MOVE.b	D6, Track_boundary_wobble.w
	BRA.b	Update_steering_Boundary
Update_steering_Left_boundary:
	CMPI.b	#$AC, D7
	BCS.b	Update_steering_Normal_step
	MOVE.b	#4, Track_boundary_type.w
	MOVE.b	D5, Track_boundary_wobble.w
	CMPI.b	#$D0, D7
	BCS.b	Update_steering_Boundary
	MOVE.b	D6, Track_boundary_wobble.w
	BRA.b	Update_steering_Boundary
Update_steering_Normal_step:
	CLR.b	Track_boundary_type.w
	MOVE.w	D4, D1
	BRA.b	Update_steering_Apply_step
;Update_steering_Boundary
Update_steering_Boundary:
	MOVE.b	Track_boundary_wobble.w, D1
Update_steering_Apply_step:
	BTST.l	#KEY_RIGHT, D0
	BNE.b	Update_steering_Step_positive
	NEG.b	D1
Update_steering_Step_positive:
	ADD.b	D1, D7
	BCC.b	Update_steering_Underflow_check
	TST.b	D1
	BMI.b	Update_steering_Merge
	MOVEQ	#-1, D7
	BRA.b	Update_steering_Merge
Update_steering_Underflow_check:
	TST.b	D1
	BPL.b	Update_steering_Merge
	MOVEQ	#1, D7
	BRA.b	Update_steering_Merge
Update_steering_Auto_centre:
	CLR.b	Track_boundary_type.w
	CMPI.b	#$80, D7
	BEQ.b	Update_steering_Merge
	TST.b	D7
	BPL.b	Update_steering_Auto_centre_right
	NEG.b	D3
Update_steering_Auto_centre_right:
	ADD.b	D3, D7
	CMPI.b	#$79, D7
	BCS.b	Update_steering_Merge
	CMPI.b	#$88, D7
	BCC.b	Update_steering_Merge
	MOVE.w	#$0080, D7
;Update_steering_Merge
Update_steering_Merge:
	CMPI.b	#8, D7
	BCC.b	Update_steering_Clamp_max
	MOVEQ	#8, D7
	BRA.b	Update_steering_Write
Update_steering_Clamp_max:
	CMPI.b	#$F8, D7
	BCS.b	Update_steering_Write
	MOVE.w	#$00F8, D7
Update_steering_Write:
	MOVE.b	D7, Road_x_offset.w
	SUBI.b	#$80, D7
	BMI.b	Update_steering_Deadzone_neg
	SUBQ.b	#8, D7
	BCC.b	Apply_steering_output
	MOVEQ	#0, D7
	BRA.b	Apply_steering_output
Update_steering_Deadzone_neg:
	ADDQ.b	#8, D7
	BCC.b	Apply_steering_output
	MOVEQ	#0, D7
Apply_steering_output:
	MOVE.b	D7, Steering_output.w
	RTS
Track_steering_params:
; Per-track signed word adjustments to (D3=auto-centre, D4=normal zone, D5=approach zone, D6=hard boundary).
; Indexed by Track_steering_index (0-4), 4 words per entry.
; Entries 0-4 = tracks 1-5 (based on Track_steering_index from Track_data +$44).
	dc.w	$FFFC, $FFF8, $FFF8, $FFF0, $FFFF, $FFFE, $FFFE, $FFFC, $0000, $0000, $0000, $0000, $0001, $0002, $0002, $0004, $0002, $0004, $0004, $0008
Load_track_data:
; Load and decompress all per-track data for the current track.
; Calls Load_track_data_pointer to get A1 → Track_data entry, then:
;   1. Read Track_horizon_override_flag (+$20) and track length (+$22)
;   2. Copy signs data (+$24) and tileset (+$28) pointers to $FFFF9240/$FFFF9254
;   3. Read minimap position map pointer (+$2C) → Minimap_track_map_ptr
;   4. RLE-decompress curve data (+$30) → Curve_data and Background_horizontal_displacement
;   5. RLE-decompress visual slope data (+$34) → Visual_slope_data and Background_vertical_displacement
;   6. RLE-decompress physical slope data (+$38) → Physical_slope_data
;   7. Load BCD lap-time base pointer (+$3C) → Track_lap_time_base_ptr
;   8. Expand per-lap target times (+$40) → Track_lap_target_buf (15 × 4-byte BCD records)
;   9. Initialise BCD lap time accumulator at $FFFFAD74 from Shift_type
;  10. Load steering divisors (+$44) → Steering_divisor_straight / Steering_divisor_curve
;  11. Initialise placement sequence from Arcade_placement_seq_v1/Arcade_placement_seq_v2
	JSR	Load_track_data_pointer
	LEA	$20(A1), A1
	MOVE.w	(A1)+, Track_horizon_override_flag.w ; 1 = special horizon palette (West Germany, Italy, Belgium)
	MOVE.w	(A1)+, D2 ; track length
	MOVE.w	D2, Track_length.w
	SUBI.w	#$00A9, D2
	MOVE.w	D2, Background_zone_1_distance.w
	SUBI.w	#$00A0, D2
	MOVE.w	D2, Background_zone_2_distance.w
	MOVE.l	(A1), Signs_data_start_ptr.w ; signs data
	MOVE.l	(A1)+, Signs_data_ptr.w ; signs data
	MOVE.l	(A1), Signs_tileset_start_ptr.w ; tileset for signs
	MOVE.l	(A1)+, Signs_tileset_ptr.w ; tileset for signs
	MOVE.l	(A1)+, Minimap_track_map_ptr.w ; map for minimap position
	MOVEA.l	(A1)+, A0 ; curve data
	LEA	Curve_data, A3 ; curve data after RLE decompression
	LEA	Background_horizontal_displacement, A2
	MOVEQ	#0, D2
	MOVE.b	#$FF, (A3)+
Load_track_data_Curve_loop:
	MOVEQ	#0, D7
	MOVEQ	#0, D3
	MOVE.w	D2, D3 ; D2 = accumulated background displacement
	MOVE.b	(A0)+, D6
	BMI.b	Load_track_data_Slope_start
	LSL.w	#8, D6
	MOVE.b	(A0)+, D6 ; D6 = length
	MOVE.b	(A0)+, D1 ; D1 = curve data
	BEQ.b	Load_track_data_Curve_entry
	MOVEQ	#0, D5    ; ...
	MOVE.b	(A0)+, D5 ; ...
	LSL.w	#8, D5    ; ...
	MOVE.b	(A0)+, D5 ; D5 = background displacement
	BTST.l	#6, D1
	BEQ.b	Load_track_data_Curve_right ; jump if right turn
	SUB.w	D5, D2
	BRA.b	Load_track_data_Curve_disp_store
Load_track_data_Curve_right:
	ADD.w	D5, D2
Load_track_data_Curve_disp_store:
	SWAP	D5
	JSR	Divide_fractional ; D7 = D5 / D6 = displacement / length = displacement per step
	BTST.l	#6, D1
	BEQ.b	Load_track_data_Curve_entry ; jump if right turn
	NEG.l	D7
Load_track_data_Curve_entry:
	SUBQ.w	#1, D6 ; fix below loop count
Load_track_data_Curve_entry_loop:
	MOVE.b	D1, (A3)+ ; write decompressed curve data
	SWAP	D3         ; ...
	ADD.l	D7, D3     ; ...
	SWAP	D3         ; D3 = D3+D7 with fractional addition
	ANDI.w	#$03FF, D3 ; modulo 1024. So N=0, W=256, S=512, E=768
	MOVE.w	D3, (A2)+ ; write decomperssed horizontal background displacement
	DBF	D6, Load_track_data_Curve_entry_loop
	BRA.b	Load_track_data_Curve_loop
Load_track_data_Slope_start:
	MOVE.b	#$FF, (A3)
	MOVEA.l	(A1)+, A0 ; slope data
	LEA	Visual_slope_data, A3
	LEA	Background_vertical_displacement, A2
	MOVE.b	(A0)+, D2 ; initial vertical background displacement
	EXT.w	D2
	MOVE.b	#$FF, (A3)+
Load_track_data_Slope_loop:
	MOVEQ	#0, D7
	MOVE.b	(A0)+, D6
	BMI.b	Load_track_data_Physslope_start
	LSL.w	#8, D6
	MOVE.b	(A0)+, D6
	MOVE.b	(A0)+, D1
	BEQ.b	Load_track_data_Slope_entry
	MOVE.b	(A0)+, D7
	LSL.w	#8, D7
	BTST.l	#6, D1
	BEQ.b	Load_track_data_Slope_entry ; jump if down slope
	NEG.l	D7
Load_track_data_Slope_entry:
	SUBQ.w	#1, D6
Load_track_data_Slope_entry_loop:
	MOVE.b	D1, (A3)+ ; write decompressed slope data
	SWAP	D2     ; ...
	ADD.l	D7, D2 ; ...
	SWAP	D2     ; integrate vertical background displacement (accumulate D7 onto D2)
	MOVE.b	D2, (A2)+ ; write decomperssed vertical background displacement
	DBF	D6, Load_track_data_Slope_entry_loop
	BRA.b	Load_track_data_Slope_loop
Load_track_data_Physslope_start:
	MOVE.b	#$FF, (A3)
	MOVEA.l	(A1)+, A0 ; physical slope data (decoded to Physical_slope_data at $00FF8300)
	LEA	Physical_slope_data, A2 ; destination: physical slope table
Load_track_data_Physslope_loop:
	MOVE.b	(A0)+, D6
	BMI.b	Load_track_data_Timing_start
	LSL.w	#8, D6
	MOVE.b	(A0)+, D6
	MOVE.b	(A0)+, D1
	SUBQ.w	#1, D6
Load_track_data_Physslope_entry_loop:
	MOVE.b	D1, (A2)+
	DBF	D6, Load_track_data_Physslope_entry_loop
	BRA.b	Load_track_data_Physslope_loop
Load_track_data_Timing_start:
	MOVE.l	(A1)+, Track_lap_time_base_ptr.w ; Track_data +$3C: pointer into Track_lap_time_records for current track
	MOVEA.l	(A1)+, A2
	LEA	Track_lap_target_buf.w, A3
	MOVEQ	#$0000000E, D0
Load_track_data_Lap_target_loop:
	CLR.b	(A3)+
	MOVE.b	(A2)+, (A3)+
	MOVE.b	(A2)+, (A3)+
	MOVE.b	(A2)+, (A3)+
	DBF	D0, Load_track_data_Lap_target_loop
	TST.w	Use_world_championship_tracks.w
	BEQ.b	Load_track_data_Steering_init
	MOVEQ	#$00000050, D7
	MOVEQ	#6, D6
	MOVEQ	#0, D5
	MOVEQ	#$00000060, D4
	MOVEQ	#$00000040, D3
	MOVEQ	#1, D2
	MOVE.w	Shift_type.w, D0
	BEQ.b	Load_track_data_Bcd_init_auto
	MOVEQ	#0, D7
	MOVEQ	#4, D6
	SUBQ.w	#1, D0
	BNE.b	Load_track_data_Steering_init
Load_track_data_Bcd_init_auto:
	LEA	(Track_lap_target_buf+$34).w, A6
	MOVEQ	#$0000000D, D1
Load_track_data_Bcd_loop:
	ADDI.w	#0, D0
	MOVE.b	$3(A6), D0
	ABCD	D7, D0
	MOVE.b	D0, $3(A6)
	MOVE.b	$2(A6), D0
	ABCD	D6, D0
	BCS.b	Load_track_data_Bcd_carry
	CMP.b	D4, D0
	BCS.b	Load_track_data_Bcd_next
	MOVE.b	D0, $2(A6)
	MOVE.b	$1(A6), D0
	ABCD	D2, D0
	MOVE.b	D0, $1(A6)
	ADDI.w	#0, D0
	MOVE.b	$2(A6), D0
	SBCD	D4, D0
	BRA.b	Load_track_data_Bcd_next
Load_track_data_Bcd_carry:
	MOVE.b	D0, $2(A6)
	MOVE.b	$1(A6), D0
	ABCD	D5, D0
	MOVE.b	D0, $1(A6)
	ADDI.w	#0, D0
	MOVE.b	$2(A6), D0
	ABCD	D3, D0
Load_track_data_Bcd_next:
	MOVE.b	D0, $2(A6)
	LEA	-$4(A6), A6
	DBF	D1, Load_track_data_Bcd_loop
Load_track_data_Steering_init:
	MOVE.l	(A1)+, Steering_divisor_straight.w ; Track_data +$44: steering divisors (.w straight, .w curve)
	MOVE.w	Track_length.w, Track_placement_distance_table.w
	MOVE.l	Track_sky_palette_ptr, Track_sky_palette_ptr_buf.w
	LEA	Arcade_placement_seq_v1(PC), A6
	CMPI.w	#1, Track_index_arcade_mode.w
	BEQ.b	Load_track_data_Arcade_placement
	LEA	Arcade_placement_seq_v2(PC), A6
Load_track_data_Arcade_placement:
	MOVE.w	(A6), Current_placement.w
	MOVE.w	(A6)+, Placement_next_threshold.w
	MOVE.l	A6, Track_placement_seq_ptr.w
	RTS
Initialize_road_graphics_state:
; Initialise the per-row road scale table at $FFFF9700 and the per-row
; Y-position table at $FFFF9480, then seed Player_distance_fixed from the
; Background_horizontal_displacement table at the current Player_distance.
;
; $FFFF9700: 60 pairs of words, counting down from $2F ($47 iterations).
;            These represent scan-line scale factors for the road perspective.
; $FFFF9480: 19 pairs of words, counting up from $B4 ($12 iterations).
;            These represent screen Y positions for road row boundaries.
;
; Player_distance_fixed is the smooth (sub-step) parallax integration
; accumulator.  Seeding it from the displacement table at startup prevents
; a one-frame snap on the first rendered frame.
	LEA	Road_scale_table.w, A0
	MOVEQ	#$0000003B, D0
	MOVEQ	#$0000002F, D1
Initialize_road_graphics_state_Scale_loop:
	MOVE.w	D1, (A0)+
	MOVE.w	D1, (A0)+
	SUBQ.w	#1, D1
	DBF	D0, Initialize_road_graphics_state_Scale_loop
	LEA	Road_row_y_buf.w, A0
	MOVE.w	#$00B4, D0
	MOVEQ	#$00000012, D1
Initialize_road_graphics_state_Y_loop:
	MOVE.w	D0, (A0)+
	MOVE.w	D0, (A0)+
	ADDQ.w	#1, D0
	DBF	D1, Initialize_road_graphics_state_Y_loop
	MOVE.w	Player_distance.w, D0
	LSR.w	#1, D0
	ANDI.w	#$FFFE, D0
	LEA	Background_horizontal_displacement, A0
	MOVE.w	(A0,D0.w), D0
	MOVE.w	D0, Player_distance_fixed.w
	RTS
Initialize_ui_tilemap_buffers:
; Decompress and arrange all persistent UI tilemap buffers in work RAM.
;
; These buffers hold the pre-rendered tile-attribute words for the title screen,
; championship standings, options screen, team select, and related UI panels.
; They are built once at boot and reused each time the corresponding screen is
; entered, avoiding repeated decompression during gameplay.
;
; Steps:
;  1. Fill $FFFFD900 with $0700 words of $04F9 (blank tile pattern) to clear
;     the UI scratch area.
;  2. Decompress the packed UI tilemap from ROM (Ui_tilemap_source) into the scratch
;     area via Decompress_tilemap_to_buffer.
;  3. Copy multiple 2D rectangular sub-regions from the decompressed tilemap
;     into their permanent layout RAM slots using Copy_2d_rect_words.
;     Each slot corresponds to one re-usable screen panel (results, standings,
;     options rows, team select boxes, etc.).
;  4. Duplicate the main panel block to a second bank for double-buffering.
;  5. Repeat for a second packed tilemap (H32-mode variant or second set of
;     screens) with additional Copy_2d_rect_words calls.
;  6. Copy the assembled set to $FFFFE000 (the tilemap draw queue input area).
	LEA	Ui_tilemap_scratch_a.w, A0
	MOVE.w	#$04F9, D0
	MOVE.w	#$06FF, D1
Initialize_ui_tilemap_buffers_Clear_loop:
	MOVE.w	D0, (A0)+
	DBF	D1, Initialize_ui_tilemap_buffers_Clear_loop
	LEA	Ui_tilemap_source, A0
	JSR	Decompress_tilemap_to_buffer
	MOVEQ	#7, D6
	MOVEQ	#4, D5
	MOVE.w	#$0024, D4
	MOVE.w	#$0080, D3
	LEA	(Tilemap_work_buf+$14).w, A6
	LEA	Ui_tilemap_panel_a.w, A5
	JSR	Copy_2d_rect_words(PC)
	MOVEQ	#4, D5
	LEA	(Championship_logo_buf+$1B0).w, A6
	LEA	Ui_tilemap_panel_b.w, A5
	JSR	Copy_2d_rect_words(PC)
	MOVEQ	#$00000017, D6
	MOVEQ	#4, D5
	MOVE.w	#$0030, D4
	LEA	(Tilemap_work_buf+$1B0).w, A6
	LEA	Ui_tilemap_panel_a_alt.w, A5
	JSR	Copy_2d_rect_words(PC)
	MOVEQ	#4, D5
	LEA	(Tilemap_work_buf+$3F0).w, A6
	LEA	Ui_tilemap_panel_b_alt.w, A5
	JSR	Copy_2d_rect_words(PC)
	LEA	Ui_tilemap_panel_a.w, A0
	LEA	Ui_tilemap_panel_a_copy.w, A1
	MOVE.w	#$009F, D0
Initialize_ui_tilemap_buffers_Copy_loop:
	MOVE.l	(A0)+, (A1)+
	DBF	D0, Initialize_ui_tilemap_buffers_Copy_loop
	MOVEQ	#4, D5
	LEA	(Championship_logo_buf+$360).w, A6
	LEA	Ui_tilemap_panel_c.w, A5
	JSR	Copy_2d_rect_words(PC)
	MOVEQ	#7, D6
	MOVEQ	#4, D5
	MOVE.w	#$0024, D4
	LEA	(Championship_logo_buf+$5A0).w, A6
	LEA	Ui_tilemap_panel_d.w, A5
	JSR	Copy_2d_rect_words(PC)
	MOVEQ	#$00000011, D6
	MOVEQ	#6, D5
	MOVE.w	#$0024, D4
	MOVE.w	#$0100, D3
	LEA	(Tilemap_work_buf+$B4).w, A6
	LEA	Ui_tilemap_panel_e.w, A5
	JSR	Copy_2d_rect_words(PC)
	MOVEQ	#6, D5
	LEA	(Championship_logo_buf+$264).w, A6
	LEA	Ui_tilemap_panel_f.w, A5
	JSR	Copy_2d_rect_words(PC)
	MOVEQ	#$00000017, D6
	MOVEQ	#6, D5
	MOVE.w	#$0030, D4
	LEA	(Tilemap_work_buf+$2A0).w, A6
	LEA	Ui_tilemap_panel_g.w, A5
	JSR	Copy_2d_rect_words(PC)
	MOVEQ	#6, D5
	LEA	(Championship_logo_buf+$60).w, A6
	LEA	Ui_tilemap_panel_h.w, A5
	JSR	Copy_2d_rect_words(PC)
	LEA	Ui_tilemap_scratch_a.w, A0
	LEA	Ui_tilemap_scratch_b.w, A1
	MOVE.w	#$01BF, D0
Initialize_ui_tilemap_buffers_Copy2_loop:
	MOVE.l	(A0)+, (A1)+
	DBF	D0, Initialize_ui_tilemap_buffers_Copy2_loop
	MOVEQ	#6, D5
	LEA	(Championship_logo_buf+$450).w, A6
	LEA	Ui_tilemap_panel_i.w, A5
	JSR	Copy_2d_rect_words(PC)
	MOVEQ	#$00000011, D6
	MOVEQ	#6, D5
	MOVE.w	#$0024, D4
	LEA	(Championship_logo_buf+$654).w, A6
	LEA	Ui_tilemap_panel_j.w, A5
	JSR	Copy_2d_rect_words(PC)
	LEA	Ui_tilemap_panel_a.w, A0
	LEA	Ui_tilemap_panel_a_copy.w, A1
	MOVE.l	#$60006000, D1
	MOVE.l	#$20002000, D2
	MOVE.w	#$009F, D0
	BSR.b	Apply_tilemap_attr_Or_loop
	LEA	Ui_tilemap_scratch_a.w, A0
	LEA	Ui_tilemap_scratch_b.w, A1
	MOVE.w	#$01BF, D0
Apply_tilemap_attr_Or_loop:
	MOVE.l	(A0), D3
	OR.l	D1, D3
	MOVE.l	D3, (A0)+
	MOVE.l	(A1), D3
	OR.l	D2, D3
	MOVE.l	D3, (A1)+
	DBF	D0, Apply_tilemap_attr_Or_loop
	RTS
;Copy_2d_rect_words
Copy_2d_rect_words:
; Copies a 2-D rectangle of words: (D6+1) words per row, (D5+1) rows.
; Source stride: D4 bytes added to A6 after each row.
; Destination stride: D3 bytes added to A5 after each row.
; Inputs:  A5=dest, A6=src, D6=words/row-1, D5=rows-1, D3=dest stride, D4=src stride
	LEA	(A5), A3
	LEA	(A6), A4
	MOVE.w	D6, D2
Copy_2d_rect_words_Inner_loop:
	MOVE.w	(A4)+, (A3)+
	DBF	D2, Copy_2d_rect_words_Inner_loop
	ADDA.w	D3, A5
	ADDA.w	D4, A6
	DBF	D5, Copy_2d_rect_words
	RTS
Initialize_road_scroll_state:
	LEA	Road_curve_interp_buf.w, A0
	LEA	Road_curve_prev_buf.w, A1
	MOVEQ	#6, D0
Initialize_road_scroll_state_Loop:
	MOVE.w	(A0), (A1)
	LEA	$10(A0), A0
	LEA	$A(A1), A1
	DBF	D0, Initialize_road_scroll_state_Loop
	LEA	Ui_tilemap_panel_a.w, A0
	LEA	Ui_tilemap_scratch_a.w, A1
	JSR	Copy_displacement_rows_to_work_buffer(PC)
	MOVE.w	#$2000, D0
	MOVE.l	#$59000003, VDP_control_port
	JSR	Write_road_scroll_with_sky_to_vdp(PC)
	LEA	Ui_tilemap_panel_a.w, A0
	LEA	Ui_tilemap_scratch_a.w, A1
	JSR	Copy_displacement_rows_to_work_buffer(PC)
	MOVE.w	#$4000, D0
	MOVE.l	#$53000003, VDP_control_port
	JSR	Write_road_scroll_with_sky_to_vdp(PC)
	LEA	Ui_tilemap_panel_a_copy.w, A0
	LEA	Ui_tilemap_scratch_b.w, A1
	JSR	Copy_displacement_rows_to_work_buffer(PC)
	MOVE.w	#$4000, D0
	MOVE.l	#$47000003, VDP_control_port
	JSR	Write_road_scroll_with_sky_to_vdp(PC)
	TST.w	Background_zone_index.w
	BNE.b	Render_road_bg_Zone_nonzero
	LEA	Ui_tilemap_panel_a.w, A0
	LEA	Ui_tilemap_scratch_a.w, A1
	JSR	Copy_displacement_rows_to_work_buffer(PC)
	MOVE.w	#$6000, D0
	MOVE.l	#$4D000003, VDP_control_port
	BRA.w	Write_road_scroll_with_sky_to_vdp
Render_road_bg_Zone_nonzero:
	LEA	Ui_tilemap_panel_a_copy.w, A0
	LEA	Ui_tilemap_scratch_b.w, A1
	JSR	Copy_displacement_rows_to_work_buffer(PC)
	MOVE.w	#$2000, D0
	MOVE.l	#$4D000003, VDP_control_port
;Write_road_scroll_with_sky_to_vdp
Write_road_scroll_with_sky_to_vdp:
; Write 768 H-scroll words from the road scroll work buffer ($FFFFF600) to
; the VDP data port.  Each word has its top nibble masked off (AND $9FFF) and
; the sky colour (D0) ORed in, so the sky row colour can be changed without
; rebuilding the whole scroll table.
;
; Called from the VBlank handler after the HScroll table has been set up in
; VRAM by Update_road_tile_scroll.  The 768 words cover all 224 scan lines
; in per-line HScroll mode.
;
; Inputs:
;  D0.w = sky colour / palette bits to OR into each HScroll word
	MOVE.w	#$02FF, D1
	MOVE.w	#$9FFF, D2
	LEA	Road_hscroll_buf.w, A0
	LEA	VDP_data_port, A1
Write_road_scroll_with_sky_to_vdp_Loop:
	MOVE.w	(A0)+, D3
	AND.w	D2, D3
	OR.w	D0, D3
	MOVE.w	D3, (A1)
	DBF	D1, Write_road_scroll_with_sky_to_vdp_Loop
	RTS
;Copy_displacement_rows_to_work_buffer
Copy_displacement_rows_to_work_buffer:
; Bulk-copy a road scroll displacement row table from A0 into the work buffer
; at $FFFFF600 using MOVEM for maximum throughput (14 × 48-byte chunks +
; one 16-byte partial), then patch 7 rows using the curved-road displacement
; values from the $FFFF9658 per-scanline curve table.
;
; The main copy covers the straight/flat road H-scroll values pre-computed for
; the current background zone.  The patch loop applies lateral displacement for
; curves: each of the 7 road rows gets 32 displacement entries re-indexed from
; a 256-entry displacement look-up table, centred at $80 and negated.
;
; Inputs:
;  A0 = source road scroll row table (one of $FFFFD400, $FFFFD680, or similar)
;  A1 = base of displacement reference table (set by caller in Update_road_tile_scroll)
; Outputs:
;  $FFFFF600 = updated road H-scroll work buffer (ready for Write_road_scroll_with_sky_to_vdp)
	LEA	Road_hscroll_buf.w, A2
	MOVEM.l	(A0)+, D0-D7/A3-A6
	MOVEM.l	D0-D7/A3-A6, (A2)
	LEA	$30(A2), A2
	MOVEM.l	(A0)+, D0-D7/A3-A6
	MOVEM.l	D0-D7/A3-A6, (A2)
	LEA	$30(A2), A2
	MOVEM.l	(A0)+, D0-D7/A3-A6
	MOVEM.l	D0-D7/A3-A6, (A2)
	LEA	$30(A2), A2
	MOVEM.l	(A0)+, D0-D7/A3-A6
	MOVEM.l	D0-D7/A3-A6, (A2)
	LEA	$30(A2), A2
	MOVEM.l	(A0)+, D0-D7/A3-A6
	MOVEM.l	D0-D7/A3-A6, (A2)
	LEA	$30(A2), A2
	MOVEM.l	(A0)+, D0-D7/A3-A6
	MOVEM.l	D0-D7/A3-A6, (A2)
	LEA	$30(A2), A2
	MOVEM.l	(A0)+, D0-D7/A3-A6
	MOVEM.l	D0-D7/A3-A6, (A2)
	LEA	$30(A2), A2
	MOVEM.l	(A0)+, D0-D7/A3-A6
	MOVEM.l	D0-D7/A3-A6, (A2)
	LEA	$30(A2), A2
	MOVEM.l	(A0)+, D0-D7/A3-A6
	MOVEM.l	D0-D7/A3-A6, (A2)
	LEA	$30(A2), A2
	MOVEM.l	(A0)+, D0-D7/A3-A6
	MOVEM.l	D0-D7/A3-A6, (A2)
	LEA	$30(A2), A2
	MOVEM.l	(A0)+, D0-D7/A3-A6
	MOVEM.l	D0-D7/A3-A6, (A2)
	LEA	$30(A2), A2
	MOVEM.l	(A0)+, D0-D7/A3-A6
	MOVEM.l	D0-D7/A3-A6, (A2)
	LEA	$30(A2), A2
	MOVEM.l	(A0)+, D0-D7/A3-A6
	MOVEM.l	D0-D7/A3-A6, (A2)
	LEA	$30(A2), A2
	MOVEM.l	(A0)+, D0-D3
	MOVEM.l	D0-D3, (A2)
	LEA	$10(A2), A2
	LEA	Road_curve_interp_buf.w, A0
	MOVE.w	#$00FC, D1
	MOVE.w	#$007C, D4
	MOVEQ	#6, D0
Copy_displacement_rows_Row_loop:
	MOVE.w	(A0), D2
	NEG.w	D2
	SUBI.w	#$0080, D2
	MOVE.w	D2, D5
	ADDI.w	#$0100, D2
	LSR.w	#2, D2
	LSR.w	#2, D5
	MOVEQ	#$0000001F, D3
Copy_displacement_rows_Inner_loop:
	AND.w	D1, D2
	AND.w	D4, D5
	MOVE.l	(A1,D2.w), (A2,D5.w)
	ADDQ.w	#4, D2
	ADDQ.w	#4, D5
	DBF	D3, Copy_displacement_rows_Inner_loop
	LEA	$10(A0), A0
	LEA	$100(A1), A1
	LEA	$80(A2), A2
	DBF	D0, Copy_displacement_rows_Row_loop
Copy_displacement_rows_Rts:
	RTS
