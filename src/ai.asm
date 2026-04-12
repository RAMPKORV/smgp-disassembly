Update_race_position:
; Per-frame placement update called from the race loop.
; No-op during warm-up or practice.
;
; Arcade mode (Use_world_championship_tracks = 0):
;   Counts how many of the 15 AI cars (Rival_car_place_score array, $40 apart)
;   have a place-score > Player_place_score; the result D1 is the player's grid
;   rank (0 = 1st). Triggers Player_eliminated and the "lapped" object when the
;   player falls more than 2 positions behind Current_placement.
;   Tracks the leader (highest score) in Best_ai_car_ptr/Rival_ai_car_ptr and the
;   second-place car in Second_ai_car_ptr; updates rival portrait anim data ptr.
;   Awards placement-bonus points via Award_race_position_points when
;   Placement_award_pending is set.
;
; Championship mode (Use_world_championship_tracks = 1, Has_rival_flag = 0):
;   Same rank loop over 15 AI cars, stores result in Player_grid_position, and
;   draws the position ordinal HUD tile via Draw_placement_ordinal_to_vdp.
;
; Rival mode (Use_world_championship_tracks = 1, Has_rival_flag = 1):
;   Computes both Player_grid_position and Rival_grid_position separately
;   by comparing each against the 14 non-rival AI cars, then draws both
;   ordinals to the HUD.
	MOVE.w	Warm_up.w, D0
	OR.w	Practice_mode.w, D0
	BEQ.b	Update_race_position_Check_arcade
Update_race_position_Return_early:
	RTS
Update_race_position_Check_arcade:
	TST.w	Track_index_arcade_mode.w
	BEQ.b	Update_race_position_Return_early
	TST.w	Use_world_championship_tracks.w
	BNE.w	Update_race_position_Champ
	MOVE.w	Player_grid_position.w, D1
	TST.w	Retire_animation_flag.w
	BNE.w	Update_race_position_Check_pos_change
	TST.w	Placement_change_flag.w
	BEQ.b	Update_race_position_Poll_threshold
	MOVE.w	#2, New_placement.w
	MOVE.w	Laps_completed.w, D0
	BEQ.b	Update_race_position_Recalc
	CMPI.w	#3, D0
	BCS.b	Update_race_position_Advance_ptr
	BRA.b	Update_race_position_Recalc
Update_race_position_Poll_threshold:
	MOVE.w	New_placement.w, D0
	LEA	Track_placement_distance_table.w, A0
	MOVE.w	(A0,D0.w), D1
	CMP.w	Player_distance.w, D1
	BHI.b	Update_race_position_Recalc
	ADDQ.w	#2, D0
	CMPI.w	#6, D0
	BCS.b	Update_race_position_Wrap_placement
	MOVEQ	#0, D0
Update_race_position_Wrap_placement:
	MOVE.w	D0, New_placement.w
	MOVE.w	#1, Placement_award_pending.w
Update_race_position_Advance_ptr:
	MOVEA.l	Track_placement_seq_ptr.w, A0
	MOVE.w	(A0)+, D0
	MOVE.w	D0, Placement_next_threshold.w
	MOVE.l	A0, Track_placement_seq_ptr.w
	CMP.w	Player_grid_position.w, D0
	BCS.b	Update_race_position_Init_anim
	MOVE.w	D0, Current_placement.w
Update_race_position_Init_anim:
	MOVE.l	#$00008586, D1
	TST.w	Placement_change_flag.w
	BEQ.b	Update_race_position_Set_anim
	MOVE.l	#$000085A4, D1
Update_race_position_Set_anim:
	MOVE.l	D1, Placement_anim_ptr.w
	MOVE.w	#1, Placement_anim_state.w
Update_race_position_Recalc:
	CLR.w	Placement_change_flag.w
	MOVE.w	Current_placement.w, D1
	CMP.w	Placement_next_threshold.w, D1
	BEQ.b	Update_race_position_Rank_loop_init
	CMP.w	Player_grid_position.w, D1
	BLS.b	Update_race_position_Rank_loop_init
	MOVE.w	Player_grid_position.w, Current_placement.w
	MOVE.l	#$000085A4, Placement_anim_ptr.w
	MOVE.w	#1, Placement_anim_state.w
Update_race_position_Rank_loop_init:
	MOVE.w	Player_place_score.w, D0
	LEA	Rival_car_place_score.w, A0
	MOVEQ	#0, D1
	MOVEQ	#0, D5
	MOVEQ	#-1, D6
	MOVEQ	#0, D7
	MOVEQ	#$0000000E, D2
Update_race_position_Rank_loop:
	CMP.w	(A0), D7
	BHI.b	Update_race_position_Check_second
	MOVE.w	(A0), D7
	LEA	(A0), A6
Update_race_position_Check_second:
	CMP.w	(A0), D0
	BHI.b	Update_race_position_Check_behind
	ADDQ.w	#1, D1
	CMP.w	(A0), D6
	BLS.b	Update_race_position_Loop_next
	MOVE.w	(A0), D6
	LEA	(A0), A5
	BRA.b	Update_race_position_Loop_next
Update_race_position_Check_behind:
	CMP.w	(A0), D5
	BHI.b	Update_race_position_Loop_next
	MOVE.w	(A0), D5
	LEA	(A0), A4
Update_race_position_Loop_next:
	LEA	$40(A0), A0
	DBF	D2, Update_race_position_Rank_loop
	LEA	-$1E(A4), A4
	MOVE.w	A4, Best_ai_car_ptr.w
	LEA	-$1E(A5), A5
	MOVE.w	A5, Second_ai_car_ptr.w
	MOVE.w	Rival_ai_car_ptr.w, D0
	BEQ.b	Update_race_position_Set_rival_b
	MOVEA.w	D0, A4
	LEA	$400(A4), A4
	MOVE.l	#Rival_car_anim_data_a, $4(A4)
Update_race_position_Set_rival_b:
	LEA	-$1E(A6), A6
	MOVE.w	A6, Rival_ai_car_ptr.w
	LEA	(A6), A4
	LEA	$400(A4), A4
	MOVE.l	#Rival_car_anim_data_b, $4(A4)
Update_race_position_Check_pos_change:
	CMP.w	Player_grid_position.w, D1
	BEQ.b	Update_race_position_Calc_delta
	MOVE.w	D1, Player_grid_position.w
	MOVE.l	#$00010001, Placement_anim_state.w
Update_race_position_Calc_delta:
	SUB.w	Current_placement.w, D1
	BCS.w	Update_race_position_Check_award
	MOVEQ	#1, D0
	BTST.b	#1, Frame_counter.w
	BNE.b	Update_race_position_Store_anim
	MOVE.w	#2, D0
Update_race_position_Store_anim:
	MOVE.w	D0, Placement_anim_state.w
	MOVE.w	D0, Placement_anim_state_b.w
	TST.w	D1
	BEQ.b	Update_race_position_Tied
	SUBQ.w	#1, D1
	BEQ.b	Update_race_position_One_ahead
Update_race_position_Two_ahead:
	MOVE.w	#3, Placement_anim_state.w
	MOVE.w	#3, Placement_anim_state_b.w
	MOVE.w	Retire_animation_flag.w, D0
	OR.w	Player_eliminated.w, D0
	BNE.w	Update_race_position_Check_award
	MOVE.w	#1, Player_eliminated.w
	MOVE.l	#$0000853E, D1
	JSR	Alloc_aux_object_slot
	TST.w	Retire_flag.w
	BNE.b	Update_race_position_Check_award
	MOVE.w	#1, Laps_done_flag.w
	MOVE.w	#1, Race_finish_flag.w
	CLR.w	Audio_engine_flags
	MOVE.l	#$00009E08, D1
	JSR	Alloc_aux_object_slot
	BRA.b	Update_race_position_Check_award
Update_race_position_Tied:
	TST.w	Race_started.w
	BEQ.b	Update_race_position_Return
	MOVEA.w	Best_ai_car_ptr.w, A0
	MOVE.w	Player_place_score.w, D1
	SUB.w	$1E(A0), D1
	LSR.w	#4, D1
	ADDQ.w	#1, D1
	CMPI.w	#8, D1
	BLS.b	Update_race_position_Award_countdown
	MOVE.w	#8, D1
	BRA.b	Update_race_position_Award_countdown
Update_race_position_One_ahead:
	MOVEA.w	Second_ai_car_ptr.w, A0
	CMPI.w	#$0078, $E(A0)
	BCS.b	Update_race_position_Two_ahead
	MOVEQ	#1, D1
Update_race_position_Award_countdown:
	SUBQ.w	#1, Race_position_award_cooldown.w
	BPL.b	Update_race_position_Check_award
	MOVE.w	D1, Race_position_award_cooldown.w
	TST.w	Retire_flag.w
	BNE.b	Update_race_position_Check_award
	MOVE.w	#Sfx_checkpoint, Audio_sfx_cmd      ; checkpoint / lap event SFX
;Update_race_position_Check_award
Update_race_position_Check_award:
	TST.w	Placement_award_pending.w
	BEQ.b	Update_race_position_Return
	CLR.w	Placement_award_pending.w
	JSR	Award_race_position_points(PC)
Update_race_position_Return:
	RTS
Update_race_position_Champ:
	TST.w	Retire_animation_flag.w
	BNE.b	Update_race_position_Return
	TST.w	Has_rival_flag.w
	BNE.w	Update_race_position_Rival
	MOVE.w	Player_place_score.w, D0
	LEA	Rival_car_place_score.w, A0
	MOVEQ	#0, D1
	MOVEQ	#0, D7
	MOVEQ	#$0000000E, D2
Update_race_position_Champ_loop:
	CMP.w	(A0), D7
	BHI.b	Update_race_position_Champ_check_pos
	MOVE.w	(A0), D7
	LEA	(A0), A6
Update_race_position_Champ_check_pos:
	CMP.w	(A0), D0
	BHI.b	Update_race_position_Champ_next
	ADDQ.w	#1, D1
Update_race_position_Champ_next:
	LEA	$40(A0), A0
	DBF	D2, Update_race_position_Champ_loop
	MOVE.w	Rival_ai_car_ptr.w, D0
	BEQ.b	Update_race_position_Champ_set_rival_b
	MOVEA.w	D0, A4
	LEA	$400(A4), A4
	MOVE.l	#Rival_car_anim_data_a, $4(A4)
Update_race_position_Champ_set_rival_b:
	LEA	-$1E(A6), A6
	MOVE.w	A6, Rival_ai_car_ptr.w
	LEA	$400(A6), A6
	MOVE.l	#Rival_car_anim_data_b, $4(A6)
	MOVE.w	D1, Player_grid_position.w
	TST.w	Ai_active_flag.w
	BNE.b	Update_race_position_Done
	MOVE.l	#$625C0003, D7
Draw_placement_ordinal_to_vdp:
	LSL.w	#4, D1
	LEA	Placement_ordinal_tilemap(PC), A6
	ADDA.w	D1, A6
	MOVEQ	#3, D6
	MOVEQ	#1, D5
	JSR	Queue_tilemap_draw
Update_race_position_Done:
	RTS
Update_race_position_Rival:
	MOVE.w	Player_place_score.w, D0
	MOVE.w	Rival_car_place_score.w, D1
	LEA	(Ai_car_array+$5E).w, A0
	MOVEQ	#0, D2
	MOVEQ	#0, D3
	MOVEQ	#$0000000D, D4
Update_race_position_Rival_loop:
	CMP.w	(A0), D0
	BHI.b	Update_race_position_Rival_check_rival
	ADDQ.w	#1, D2
Update_race_position_Rival_check_rival:
	CMP.w	(A0), D1
	BHI.b	Update_race_position_Rival_next
	ADDQ.w	#1, D3
Update_race_position_Rival_next:
	LEA	$40(A0), A0
	DBF	D4, Update_race_position_Rival_loop
	CMP.w	D2, D3
	BNE.b	Update_race_position_Rival_compare
	CMP.w	D1, D0
Update_race_position_Rival_compare:
	BHI.b	Update_race_position_Rival_ahead
	ADDQ.w	#1, D2
	BRA.b	Update_race_position_Rival_store
Update_race_position_Rival_ahead:
	ADDQ.w	#1, D3
Update_race_position_Rival_store:
	MOVE.w	D2, Player_grid_position.w
	MOVE.w	D3, Rival_grid_position.w
	TST.w	Ai_active_flag.w
	BNE.b	Update_race_position_Done
	MOVE.w	D2, D1
	MOVE.l	#$625C0003, D7
	JSR	Draw_placement_ordinal_to_vdp(PC)
	MOVE.w	D3, D1
	MOVE.l	#$62660003, D7
	JMP	Draw_placement_ordinal_to_vdp(PC)
	SUBQ.w	#1, $22(A0)
	BPL.b	Update_placement_overlay_Wide_return
	MOVE.w	#4, $22(A0)
	NOT.w	$1A(A0)
	LEA	$00FF5980, A6
	LEA	(A6), A4
	TST.w	$1A(A0)
	BEQ.b	Update_placement_overlay_Draw_normal
	LEA	Placement_hud_tiles_wide_a(PC), A6
	LEA	Placement_hud_tiles_wide_b(PC), A4
Update_placement_overlay_Draw_normal:
	MOVE.l	#$63640003, D7
	MOVEQ	#6, D6
	MOVEQ	#0, D5
	JSR	Queue_tilemap_draw
	LEA	(A4), A6
	MOVE.l	#$63A80003, D7
	MOVEQ	#3, D6
	JSR	Queue_tilemap_draw
Update_placement_overlay_Wide_return:
	RTS
	MOVEQ	#2, D7
	MOVE.w	Current_placement.w, D0
	CMP.w	Player_grid_position.w, D0
	BLS.b	Update_placement_overlay_Set_b
	MOVEQ	#1, D7
Update_placement_overlay_Set_b:
	MOVE.w	D7, $2A(A0)
	TST.w	Overtake_flag.w
	BNE.b	Update_placement_overlay_Init
	MOVE.w	#1, Overtake_flag.w
Update_placement_overlay_Init:
	MOVE.l	#Update_placement_overlay_Frame, (A0)
	MOVE.w	#$000E, $1C(A0)
	CLR.w	$22(A0)
	CLR.w	$1A(A0)
Update_placement_overlay_Frame:
	TST.w	Player_eliminated.w
	BEQ.b	Update_placement_overlay_Alive
	CLR.w	$1A(A0)
	BSR.b	Update_placement_overlay_Redraw
	BRA.b	Update_placement_overlay_Clear
Update_placement_overlay_Alive:
	SUBQ.w	#1, $22(A0)
	BPL.b	Update_placement_overlay_Done
	MOVE.w	#4, $22(A0)
	NOT.w	$1A(A0)
	SUBQ.w	#1, $1C(A0)
	BPL.b	Update_placement_overlay_Tick
Update_placement_overlay_Clear:
	JMP	Clear_object_slot
Update_placement_overlay_Tick:
	CMPI.w	#7, $1C(A0)
	BNE.b	Update_placement_overlay_Redraw
	MOVE.w	$2A(A0), D0
	BEQ.b	Update_placement_overlay_Redraw
	MOVE.w	D0, $00FF5AC2
Update_placement_overlay_Redraw:
	LEA	$00FF5980, A6
	LEA	(A6), A4
	TST.w	$1A(A0)
	BEQ.b	Update_placement_overlay_Queue
	LEA	Placement_hud_tiles_a(PC), A6
	LEA	Placement_hud_tiles_b(PC), A4
Update_placement_overlay_Queue:
	MOVE.l	#$62640003, D7
	MOVEQ	#4, D6
	MOVEQ	#0, D5
	JSR	Queue_tilemap_draw
	LEA	(A4), A6
	MOVE.l	#$62A80003, D7
	MOVEQ	#4, D6
	JSR	Queue_tilemap_draw
Update_placement_overlay_Done:
	RTS
;Decrement_lap_time_bcd
Decrement_lap_time_bcd:
	LEA	Rival_grid_position.w, A1
	LEA	Update_pit_prompt(PC), A2
	ADDI.w	#0, D0
	SBCD	-(A2), -(A1)
	SBCD	-(A2), -(A1)
	BCC.b	Decrement_lap_time_Check
	CLR.w	(A1)
Decrement_lap_time_Check:
	TST.w	Use_world_championship_tracks.w
	BNE.b	Decrement_lap_time_Return
	TST.w	Track_index_arcade_mode.w
	BEQ.b	Decrement_lap_time_Return
	MOVE.w	#1, Placement_display_dirty.w
Decrement_lap_time_Return:
	RTS
;Award_race_position_points
Award_race_position_points:
; Add placement bonus points to Race_time_bcd (the accumulated time/score used
; for standing selection in championship mode).
; Called when Placement_award_pending is set (arcade mode only).
;
; Inputs:  Player_grid_position (0 = 1st), Current_placement
; Output:  Race_time_bcd incremented by Race_placement_bonus_table[Player_grid_position]
;
; Only awards if Player_grid_position < Current_placement (i.e. player moved up).
	MOVE.w	Player_grid_position.w, D0
	CMP.w	Current_placement.w, D0
	BCC.b	Decrement_lap_time_Return
	ADD.w	D0, D0
	LEA	Race_placement_bonus_table(PC), A1
	MOVE.w	(A1,D0.w), D2
Award_race_position_points_Add:
	MOVE.w	Race_time_bcd.w, D0
	MOVEQ	#0, D1
	JSR	Bcd_add_loop
	MOVE.w	D0, Race_time_bcd.w
	BRA.b	Decrement_lap_time_Check
Advance_lap_checkpoint:
	MOVE.w	Lap_checkpoint_target.w, D0
	CMP.w	Player_place_score.w, D0
	BLS.b	Advance_lap_checkpoint_Add
	RTS
Advance_lap_checkpoint_Add:
	ADDI.w	#$003C, D0
	MOVE.w	D0, Lap_checkpoint_target.w
	MOVEQ	#1, D2
	BRA.b	Award_race_position_points_Add
Race_placement_bonus_table:
; BCD bonus awarded per grid position (index = Player_grid_position, 0-based).
; 13 entries; position 0 (1st) gives $14 points, position 12 (13th) gives $02.
; Used by Award_race_position_points and added to Race_time_bcd via Bcd_add_loop.
	dc.w	$0014
	dc.w	$0013
	dc.w	$0012
	dc.w	$0011
	dc.w	$0010
	dc.w	$0009
	dc.w	$0008
	dc.w	$0007
	dc.w	$0006
	dc.w	$0005
	dc.w	$0004
	dc.w	$0003
	dc.w	$0002
Curve_displacement_table:
; 48 signed-word lateral displacement values indexed by curve sharpness byte
; (lower 6 bits of curve data byte, values 1–47). Entry 0 is a guard ($0001).
; Used by the driving model to compute road X displacement from curve sharpness.
; Sharpness 1 = extreme (large displacement $24D4), sharpness 47 = soft ($0105).
	dc.w	$0001
	dc.w	$24D4
	dc.w	$1B8C
	dc.w	$1861
	dc.w	$1601
	dc.w	$1251
	dc.w	$10F1
	dc.w	$0FB0
	dc.w	$0EAB
	dc.w	$0DB8
	dc.w	$0C3C
	dc.w	$09FF
	dc.w	$0929
	dc.w	$0873
	dc.w	$07D8
	dc.w	$0717
	dc.w	$0678
	dc.w	$057E
	dc.w	$04C8
	dc.w	$047D
	dc.w	$03FF
	dc.w	$038B
	dc.w	$036F
	dc.w	$033C
	dc.w	$030E
	dc.w	$02EE
	dc.w	$02C0
	dc.w	$0287
	dc.w	$0271
	dc.w	$0264
	dc.w	$0233
	dc.w	$0209
	dc.w	$01F6
	dc.w	$01F2
	dc.w	$01CD
	dc.w	$01A4
	dc.w	$0198
	dc.w	$0192
	dc.w	$016D
	dc.w	$0160
	dc.w	$015B
	dc.w	$0139
	dc.w	$012F
	dc.w	$012A
	dc.w	$0122
	dc.w	$0119
	dc.w	$0111
	dc.w	$0105
Placement_hud_tiles_a:
	dc.w	$A7F1, $A7F2, $A7D7, $A7CE, $A7E0
Placement_hud_tiles_b:
	dc.w	$A7D5, $A7D2, $A7D6, $A7D2, $A7DD
Placement_hud_tiles_wide_a:
	dc.w	$A7F1, $A7F2, $A7D5, $A7D2, $A7D6, $A7D2, $A7DD
Placement_hud_tiles_wide_b:
	dc.w	$A7D8, $A7DF, $A7CE, $A7DB
	dc.w	$0010
Update_pit_prompt:
	TST.w	Use_world_championship_tracks.w
	BEQ.w	Update_pit_prompt_Return
	TST.w	Track_index_arcade_mode.w
	BEQ.w	Update_pit_prompt_Return
	CLR.w	Pit_prompt_flag.w
	TST.w	Tire_wear_degrade_level.w
	BEQ.b	Update_pit_prompt_Return
	CMPI.w	#4, Laps_completed.w
	BEQ.b	Update_pit_prompt_Display
	MOVE.w	Background_zone_2_distance.w, D0
	SUBI.w	#$012C, D0
	CMP.w	Player_distance.w, D0
	BHI.b	Update_pit_prompt_Display
	ADDI.w	#$0154, D0
	CMP.w	Player_distance.w, D0
	BCS.b	Update_pit_prompt_Display
	MOVE.w	#1, Pit_prompt_flag.w
	BTST.b	#KEY_C, Input_state_bitset.w
	BEQ.b	Update_pit_prompt_Display
	MOVE.w	#1, Pit_in_flag.w
;Update_pit_prompt_Display
Update_pit_prompt_Display:
	LEA	Pit_prompt_tilemap(PC), A6
	MOVEQ	#1, D0
	TST.w	Pit_in_flag.w
	BNE.b	Update_pit_prompt_Queue
	TST.w	Pit_prompt_flag.w
	BEQ.b	Update_pit_prompt_No_prompt
	BTST.b	#0, Frame_counter.w
	BNE.b	Update_pit_prompt_Queue
	BEQ.b	Update_pit_prompt_Hide
Update_pit_prompt_No_prompt:
	TST.w	Tire_wear_degrade_level.w
	BEQ.b	Update_pit_prompt_Hide
	MOVEQ	#2, D0
	BTST.b	#1, Frame_counter.w
	BNE.b	Update_pit_prompt_Queue
Update_pit_prompt_Hide:
	LEA	$00FF5980, A6
	MOVEQ	#0, D0
Update_pit_prompt_Queue:
	MOVE.w	D0, Car_palette_dma_id.w
	MOVE.l	#$63960003, D7
	MOVEQ	#9, D6
	MOVEQ	#1, D5
	JSR	Queue_tilemap_draw
Update_pit_prompt_Return:
	RTS
;Update_tire_wear_counter
Update_tire_wear_counter:
; Championship-mode per-frame tire wear simulation.
; No-op outside championship/arcade mode.
;
; Three wear channels: steering, engine, and acceleration.
; Each channel subtracts its wear rate from a durability accumulator each frame.
; When the accumulator underflows, $14 is added back (20-unit tick), a degrade
; flag bit is set in D7, and the relevant performance index is decremented by 2:
;   Steering channel: Track_steering_index decremented (harder to steer)
;   Engine channel:   Team_car_engine_data decremented (lower top speed)
;   Accel channel:    Team_car_acceleration decremented (slower acceleration)
; All indices clamp to 0 (minimum performance, not worse).
;
; When any channel degrades, Tire_wear_degrade_level is updated and
; Overtake_flag is set to $16 (triggers tire smoke/squeal feedback).
; When the acceleration channel degrades (D7 = 2), Load_team_car_data is called
; to re-resolve the engine/accel tables for the new degraded indices.
	TST.w	Use_world_championship_tracks.w
	BEQ.w	Update_tire_wear_counter_Return
	TST.w	Track_index_arcade_mode.w
Update_tire_wear_counter_Arcade:
	BEQ.w	Update_tire_wear_counter_Return
	MOVEQ	#0, D7
	MOVE.w	Tire_steering_wear_rate.w, D0
	SUB.w	D0, Tire_steering_durability_acc.w
	BCC.b	Update_tire_wear_counter_Steering_pct
	CLR.w	Tire_steering_durability_acc.w
Update_tire_wear_counter_Steering_pct:
	SUB.w	D0, Tire_steering_durability.w
	BCC.b	Update_tire_wear_counter_Engine_setup
	ADDI.w	#$0014, Tire_steering_durability.w
	MOVEQ	#1, D7
	SUBQ.w	#2, Track_steering_index.w
	BCC.b	Update_tire_wear_counter_Engine_setup
	CLR.w	Track_steering_index.w
Update_tire_wear_counter_Engine_setup:
	MOVE.w	Tire_engine_wear_rate.w, D0
	SUB.w	D0, Tire_engine_durability_acc.w
	BCC.b	Update_tire_wear_counter_Engine_pct
	CLR.w	Tire_engine_durability_acc.w
Update_tire_wear_counter_Engine_pct:
	SUB.w	D0, Tire_engine_durability.w
	BCC.b	Update_tire_wear_counter_Accel_setup
	ADDI.w	#$0014, Tire_engine_durability.w
	MOVEQ	#2, D7
	SUBQ.w	#2, Team_car_engine_data.w
	BCC.b	Update_tire_wear_counter_Accel_setup
	CLR.w	Team_car_engine_data.w
Update_tire_wear_counter_Accel_setup:
	MOVE.w	Tire_accel_wear_rate.w, D0
	SUB.w	D0, Tire_accel_durability_acc.w
	BCC.b	Update_tire_wear_counter_Accel_pct
	CLR.w	Tire_accel_durability_acc.w
Update_tire_wear_counter_Accel_pct:
	SUB.w	D0, Tire_accel_durability.w
	BCC.b	Update_tire_wear_counter_Check_degrade
	ADDI.w	#$0014, Tire_accel_durability.w
	MOVEQ	#2, D7
	SUBQ.w	#2, Team_car_acceleration.w
	BCC.b	Update_tire_wear_counter_Check_degrade
	CLR.w	Team_car_acceleration.w
Update_tire_wear_counter_Check_degrade:
	TST.w	D7
	BEQ.b	Update_tire_wear_counter_Return
	MOVE.w	D7, Tire_wear_degrade_level.w
	MOVE.w	#$0016, Overtake_flag.w
	SUBQ.w	#2, D7
	BNE.b	Update_tire_wear_counter_Return
	JSR	Load_team_car_data
Update_tire_wear_counter_Return:
	RTS
Pit_prompt_tilemap:
	dc.w	$8492, $8493, $8494, $8495, $8496, $8497, $8498, $8499, $849A, $849B, $849C, $849D, $849E, $849F, $84A0, $84A1, $84A2, $84A3, $84A4, $84A5
Placement_ordinal_tilemap:
	dc.w	$0000, $84B4, $0000, $0000, $0000, $84B5, $A7DC, $A7DD, $0000, $84B6, $0000, $0000, $0000, $84B7, $A7D7, $A7CD, $0000, $84B8, $0000, $0000, $0000, $84B9, $A7DB, $A7CD, $0000, $84BA, $0000, $0000, $0000, $84BB, $A7DD, $A7D1
	dc.w	$0000, $84BC, $0000, $0000, $0000, $84BD, $A7DD, $A7D1, $0000, $84BE, $0000, $0000, $0000, $84BF, $A7DD, $A7D1, $0000, $84C0, $0000, $0000, $0000, $84C1, $A7DD, $A7D1, $0000, $84C2, $0000, $0000, $0000, $84C3, $A7DD, $A7D1
	dc.w	$0000, $84C4, $0000, $0000, $0000, $84C5, $A7DD, $A7D1, $84B4, $84B2, $0000, $0000, $84B5, $84B3, $A7DD, $A7D1, $84B4, $84B4, $0000, $0000, $84B5, $84B5, $A7DD, $A7D1, $84B4, $84B6, $0000, $0000, $84B5, $84B7, $A7DD, $A7D1
	dc.w	$84B4, $84B8, $0000, $0000, $84B5, $84B9, $A7DD, $A7D1, $84B4, $84BA, $0000, $0000, $84B5, $84BB, $A7DD, $A7D1, $84B4, $84BC, $0000, $0000, $84B5, $84BD, $A7DD, $A7D1, $84B4, $84BE, $0000, $0000, $84B5, $84BF, $A7DD, $A7D1
Steering_curve_divisors:
	dc.w	$0008, $0018
	dc.w	$0002, $0006
	dc.w	$0000, $0000
	dc.w	$FFFE, $FFFA
	dc.w	$FFFC, $FFF4
Parse_tileset_for_signs:
; Advance the sign tileset stream pointer to the next entry whose track
; distance is within 120 units of the player, then write its 10-byte DMA
; descriptor into Sign_tileset_buf ($FFFF925C).
;
; Called once per frame from the race loop (step that handles signage).
; No-op while Finish_line_sign_active is set (flagkeeper tileset already loaded).
;
; Sign tileset stream format (Track_data +$28):
;   Word 0 (.w) : track distance of this tileset switch
;   Word 1 (.w) : byte offset into Sign_tileset_table
;   Terminated by $FFFF (negative distance → BPL falls through → reset pointer)
;
; Sign_tileset_table entry format (8 bytes):
;   Longword : DMA source address
;   Word     : DMA transfer length
;   Word     : secondary word field
;
; Output: Sign_tileset_buf ($FFFF925C) filled with 8 bytes from the table
;         entry plus a $FFFF sentinel word.
	TST.w	Finish_line_sign_active.w
	BNE.b	Parse_tileset_for_signs_Return
	MOVEA.l	Signs_tileset_ptr.w, A0   ; current read position in tileset stream
	MOVE.w	(A0)+, D0                  ; track distance of next tileset entry
	BPL.b	Parse_tileset_for_signs_Check_distance
	MOVE.l	Signs_tileset_start_ptr.w, Signs_tileset_ptr.w ; end sentinel ($FFFF) → reset to start
	BRA.b	Parse_tileset_for_signs
Parse_tileset_for_signs_Check_distance:
	SUB.w	Player_distance.w, D0     ; D0 = distance from player to entry
	CMPI.w	#$0078, D0
	BCS.b	Parse_tileset_for_signs_Near                   ; jump if within 120 units
	ADD.w	Track_length.w, D0         ; wrap: check again relative to track end
	CMPI.w	#$0078, D0
	BCC.b	Parse_tileset_for_signs_Return                   ; still > 120 → not yet; return
Parse_tileset_for_signs_Near:
	MOVE.w	(A0)+, D0                  ; D0 = byte offset into Sign_tileset_table
	MOVE.l	A0, Signs_tileset_ptr.w    ; save advanced stream pointer
	LEA	Sign_tileset_table, A0
	ADDA.w	D0, A0
Parse_tileset_for_signs_Write_buf:
	LEA	Sign_tileset_buf.w, A1       ; write 10-byte DMA descriptor + $FFFF sentinel
	MOVE.l	(A0)+, (A1)+
	MOVE.w	(A0)+, (A1)+
	MOVE.w	(A0), (A1)+
	MOVE.w	#$FFFF, (A1)
Parse_tileset_for_signs_Return:
	RTS
Parse_sign_data:
; Advance the sign data stream pointer to the next sign whose track distance
; is within 120 units of the player, then allocate an aux object slot for it.
;
; Called once per frame from the race loop alongside Parse_tileset_for_signs.
; No-op while Finish_line_sign_active is set.
;
; In practice/warm-up mode: jumps straight to the main sign-spawn path.
; In championship/arcade mode: only spawns signs during the first lap
;   (championship) or during the correct lap count (arcade multi-lap).
; Near the finish line (< 120 units from track end): loads the flagkeeper
;   tileset (Flagkeeper_tileset) and sets Finish_line_sign_active = 1.
;
; Sign data stream format (Track_data +$24):
;   Word 0 (.w) : track distance of this sign group
;   Byte 2      : number of signs in the row group
;   Byte 3      : sign identifier (index into Sign_lookup_table × 4)
;   Terminated by $FFFF distance word (negative → reset pointer to stream start)
;
; Sign lookup table (Sign_lookup_table):
;   Each entry is a .l pointer to a byte list of tile-frame indices, $FF-terminated.
;   Values 0       = special/null sign
;   Values 1–$14   = normal signs → aux object handler from Sign_handler_dispatch_rts dispatch table
;   Values $15+    = special objects (tunnel, etc.) → stored at Tunnel_handler_ptr
;
; Signs in a row: Signs_in_row_count signs are placed at Signs_location,
;   Signs_location+$10, +$20, … (spacing of $10 per sign).
;
; On sign spawn: Alloc_aux_object_slot is called with D1=handler, D0=location.
	TST.w	Finish_line_sign_active.w
	BNE.b	Parse_tileset_for_signs_Return
	MOVE.w	Warm_up.w, D0
	OR.w	Practice_mode.w, D0
	BNE.b	Parse_sign_data_Next
	TST.w	Track_index_arcade_mode.w
	BNE.b	Parse_sign_data_Arcade_lap_gate
	TST.w	Laps_completed.w
	BEQ.b	Parse_sign_data_Finish_line_check
	BRA.b	Parse_sign_data_Next
Parse_sign_data_Arcade_lap_gate:
	MOVE.w	Use_world_championship_tracks.w, D0
	ADD.w	D0, D0
	ADDQ.w	#2, D0
	CMP.w	Laps_completed.w, D0
	BNE.b	Parse_sign_data_Next
Parse_sign_data_Finish_line_check:
	MOVE.w	Track_length.w, D0
	SUB.w	Player_distance.w, D0
	CMPI.w	#$0078, D0
	BCC.b	Parse_sign_data_Next                          ; > 120 units to end → no finish-line sign yet
	MOVE.w	#1, Finish_line_sign_active.w      ; arm flagkeeper; block further sign spawns
	MOVE.l	#Flagkeeper_car_obj_guard, Flagkeeper_obj_ptr.w            ; flagkeeper full-track handler pointer
	LEA	Flagkeeper_tileset, A0
	BRA.b	Parse_tileset_for_signs_Write_buf                           ; write Flagkeeper_tileset tileset to Sign_tileset_buf
;Parse_sign_data_Next
Parse_sign_data_Next:
	MOVEA.l	Signs_data_ptr.w, A0
	MOVE.w	(A0)+, D0                          ; D0 = sign group distance from track start
	BPL.b	Parse_sign_data_Check_proximity
	MOVE.l	Signs_data_start_ptr.w, Signs_data_ptr.w ; end sentinel → reset to start (new lap)
	BRA.b	Parse_sign_data
Parse_sign_data_Check_proximity: ; sign is at D0 distance from start
	MOVE.w	D0, D1
	SUB.w	Player_distance.w, D1             ; D1 = distance to sign
	CMPI.w	#$0078, D1
	BCS.b	Parse_sign_data_Consume_record                           ; jump if within 120 units
	ADD.w	Track_length.w, D1                 ; wrap: check again relative to track end
	CMPI.w	#$0078, D1
	BCC.b	Parse_sign_data_Row_loop                           ; still out of range → return
Parse_sign_data_Consume_record:
	ADDQ.l	#4, Signs_data_ptr.w               ; consume this 4-byte record
	MOVE.w	D0, Signs_location.w               ; store sign's track distance
	MOVE.b	(A0)+, D0                          ; D0 = signs-in-row count
	EXT.w	D0
	MOVE.w	D0, Signs_in_row_count.w
	MOVE.b	(A0)+, D0                          ; D0 = sign identifier (index into Sign_lookup_table)
	EXT.w	D0
	ADD.w	D0, D0
	ADD.w	D0, D0                             ; D0 × 4 = byte offset into Sign_lookup_table
	LEA	Sign_lookup_table, A0
	ADDA.w	D0, A0
	MOVE.l	(A0), Sign_table_entry_start.w     ; save pointer to start of frame-index list
	MOVE.l	(A0), Sign_table_entry_ptr.w       ; also set current read position
Parse_sign_data_Row_loop:
	MOVE.w	Signs_in_row_count.w, D0           ; D0 = signs remaining in row
	BEQ.b	Alloc_aux_object_slot_Return                            ; 0 → nothing to spawn; return
	MOVE.w	Signs_location.w, D0               ; D0 = distance of next sign in row
	MOVE.w	D0, D1
	SUB.w	Player_distance.w, D1 ; D1 = distance to sign
	CMPI.w	#$0078, D1
	BCS.b	Parse_sign_data_Advance_location ; jump if distance to sign < 120
	ADD.w	Track_length.w, D1
	CMPI.w	#$0078, D1
	BCC.b	Alloc_aux_object_slot_Return ; continue if distance to sign? < 120 (sign appears for next lap?)
Parse_sign_data_Advance_location:
	ADDI.w	#$0010, Signs_location.w   ; advance location by spacing to next sign in row
Parse_sign_data_Read_frame_index:
	MOVEA.l	Sign_table_entry_ptr.w, A0 ; current position in frame-index list
	MOVE.b	(A0)+, D1                   ; D1 = frame-index byte ($FF = end of list)
	BPL.b	Parse_sign_data_Dispatch
	MOVE.l	Sign_table_entry_start.w, Sign_table_entry_ptr.w ; $FF sentinel → restart list
	SUBQ.w	#1, Signs_in_row_count.w    ; one fewer sign in this row
	BNE.b	Parse_sign_data_Read_frame_index                    ; loop while more signs remain
	BRA.b	Alloc_aux_object_slot_Return
Parse_sign_data_Dispatch:
	MOVE.l	A0, Sign_table_entry_ptr.w  ; save advanced frame-index list pointer
	EXT.w	D1
	BEQ.b	Alloc_aux_object_slot_Return ; jump to RTS if sign table byte = 0 (special sign?)
	CMPI.w	#$0015, D1
	BCC.b	Parse_sign_data_Special ; jump if sign table byte >= $0015 (special sign, tunnel?)
	ADD.w	D1, D1
	ADD.w	D1, D1 ; D1 is at least 4, so below lookup begins at Init_background_ai_car_0 declaration
	MOVE.l	Sign_handler_dispatch_rts-2(PC,D1.w), D1
	ADD.w	Total_distance.w, D0 ; some multiple of track length?
;Alloc_aux_object_slot
Alloc_aux_object_slot:
; Finds a free slot (handler == 0) in the aux object pool at $FFFFB840,
; writes handler pointer D1 and initial data D0 into it.
; Carry clear = slot allocated; Carry set (via fallthrough branch) = pool full.
	LEA	Aux_object_pool.w, A1
	MOVEQ	#$00000020, D2
;Find_free_aux_object_slot
Find_free_aux_object_slot:
; Inner search loop; also callable directly to search from A1 with D2 limit.
	TST.l	(A1)
	BEQ.b	Find_free_aux_object_slot_Found
	LEA	$40(A1), A1
	DBF	D2, Find_free_aux_object_slot
	ADDQ.w	#2, D2
	BRA.b	Alloc_aux_object_slot_Return
Find_free_aux_object_slot_Found:
	MOVE.l	D1, (A1)
	MOVE.w	D0, $1E(A1)
;Alloc_aux_object_slot_Return
Alloc_aux_object_slot_Return:
	RTS
Parse_sign_data_Special:
	SUBI.w	#$0015, D1
	ADD.w	D1, D1
	ADD.w	D1, D1
	MOVE.l	Special_sign_dispatch_table(PC,D1.w), Special_sign_obj_ptr.w
	ADD.w	Total_distance.w, D0
	MOVE.w	D0, (Road_scroll_origin_x+$6).w
Sign_handler_dispatch_rts:
	RTS
	dc.l	Init_background_ai_car_0
	dc.l	Init_background_ai_car_1 ; first san marino sign
	dc.l	Background_ai_car_c_obj_spawn
	dc.l	Background_ai_car_d_obj_init
	dc.l	Init_background_ai_car_4
	dc.l	Init_background_ai_car_5
	dc.l	Init_background_ai_car_6
	dc.l	Init_background_ai_car_7
	dc.l	Init_background_ai_car_15
	dc.l	Init_background_ai_car_14
	dc.l	Init_background_ai_car_12
	dc.l	Init_background_ai_car_13
	dc.l	Init_background_ai_car_8
	dc.l	Init_background_ai_car_9
	dc.l	Init_background_ai_car_2
	dc.l	Init_background_ai_car_3
	dc.l	Spawn_background_ai_car_0
	dc.l	Spawn_background_ai_car_1
	dc.l	Init_background_ai_car_10
	dc.l	Init_background_ai_car_11
Special_sign_dispatch_table:
	dc.l	Crash_car_obj_init
	dc.l	Crash_approach_obj_init
	dc.l	Rival_approach_obj_init
; Init_ai_sign_pass: initialise the AI sign-pass object (installed via Special_sign_dispatch_table + $C)
	MOVE.l	#Update_ai_sign_pass_Frame, (A0)
	MOVE.w	$12(A0), $36(A0)
	MOVE.w	$1A(A0), $1E(A0)
	MOVE.w	#$FFFF, $22(A0)
	MOVE.b	#3, $24(A0)
	ADDQ.w	#1, Frame_subtick.w
	ANDI.w	#3, Frame_subtick.w
Update_ai_sign_pass_Frame:
	TST.b	$25(A0)
	BEQ.b	Update_ai_sign_pass_Movement
	MOVE.w	#$2000, $C(A0)
	JSR	Compute_ai_position_and_depth_sort(PC)
	LEA	Ai_screen_x_dispatch_table, A1
	JSR	(A1,D7.w)
	CMPA.w	#0, A6
	BEQ.b	Update_ai_sign_pass_No_collision
	JSR	Check_ai_collision_with_player(PC)
Update_ai_sign_pass_No_collision:
	CLR.l	$38(A0)
	RTS
Update_ai_sign_pass_Movement:
	TST.b	$3F(A0)
	BNE.w	Update_background_ai_car
	CMPI.w	#$28BC, $1E(A0)
	BCS.w	Update_background_ai_car
	CMPI.w	#$000C, Player_grid_position.w
	BCS.b	Update_ai_sign_pass_Check_spawn
	MOVE.b	#$FF, $3F(A0)
	MOVE.w	#$0140, D0
	MOVE.w	D0, $30(A0)
	LSL.w	#7, D0
	MOVE.w	D0, $32(A0)
	MOVE.w	#$00E6, $34(A0)
	MOVE.b	#4, $2B(A0)
	BRA.w	Update_background_ai_car
Update_ai_sign_pass_Check_spawn:
	MOVE.w	Frame_subtick.w, D7
	BEQ.w	Update_background_ai_car
	MOVE.w	Player_place_score.w, D0
	SUB.w	$1E(A0), D0
	BMI.w	Update_background_ai_car
	CMPI.w	#$00A0, D0
	BCS.w	Update_background_ai_car
	MOVE.w	#$0AFC, D0
	MOVE.w	#$0100, D1
	LSR.w	#1, D7
	BCC.b	Update_ai_sign_pass_Proximity_check
	MOVE.w	#$1154, D0
	NEG.w	D1
Update_ai_sign_pass_Proximity_check:
	CMP.w	$1A(A0), D0
	BHI.w	Update_background_ai_car
	ADDQ.w	#8, D0
	CMP.w	$1A(A0), D0
	BCS.b	Update_background_ai_car
	MOVE.b	#$FF, $25(A0)
	MOVE.w	D1, $12(A0)
	TST.b	$10(A0)
	BEQ.b	Update_ai_sign_pass_Alloc_smoke
	CLR.b	$10(A0)
	BRA.b	Update_ai_sign_pass_Loop_back
Update_ai_sign_pass_Alloc_smoke:
	MOVE.l	#$00009CE8, D1
	JSR	Alloc_and_init_aux_object_slot
	BCS.b	Update_ai_sign_pass_Loop_back
	MOVE.l	A0, $30(A1)
Update_ai_sign_pass_Loop_back:
	BRA.w	Update_ai_sign_pass_Frame
Init_rival_car_intro:
	MOVE.l	#Update_rival_car_intro_Frame, (A0)
	MOVE.w	$12(A0), $36(A0)
	MOVE.w	$1A(A0), $1E(A0)
	MOVE.w	#$FFFF, $22(A0)
	MOVE.b	#3, $24(A0)
	MOVE.b	#1, $3C(A0)
Update_rival_car_intro_Frame:
	JSR	Skip_if_hidden_flag(PC)
	BRA.b	Update_background_ai_car
Init_ai_car_hidden:
	MOVE.l	#Update_background_ai_car, (A0)
	MOVE.w	$12(A0), $36(A0)
	MOVE.w	$1A(A0), $1E(A0)
	MOVE.w	#$FFFF, $22(A0)
	MOVE.b	#3, $24(A0)
	CLR.b	$3C(A0)
Update_background_ai_car:
; Per-frame update handler for background AI competitor cars.
; Installed via: MOVE.l #Update_background_ai_car, (A0)
; A0 = pointer to AI car object slot ($40 bytes).
; Skips movement if race not started or finished.
; When obstacle flag ($3E) is set, skips straight to Advance_ai_track_position.
; Otherwise runs lateral lane-change oscillation, then falls to Advance_ai_track_position.
	TST.w	Race_finish_flag.w
	BNE.w	Update_background_ai_car_Finish
	TST.w	Race_started.w
	BEQ.w	Update_background_ai_car_Finish
	TST.b	$3E(A0)
	BNE.w	Advance_ai_track_position
	TST.b	$10(A0)
	BEQ.b	Update_background_ai_car_Approach
	SUBQ.b	#1, $15(A0)
	BPL.b	Update_background_ai_car_Osc_done
	MOVE.b	#1, $15(A0)
	MOVE.b	$11(A0), D0
	ADD.b	$14(A0), D0
	BEQ.b	Update_background_ai_car_Osc_flip
	CMPI.b	#$10, D0
	BNE.b	Update_background_ai_car_Osc_store
Update_background_ai_car_Osc_flip:
	NEG.b	$14(A0)
Update_background_ai_car_Osc_store:
	MOVE.b	D0, $11(A0)
	SUBQ.b	#1, $10(A0)
Update_background_ai_car_Osc_done:
	MOVE.w	$26(A0), D0
	SUBQ.w	#2, D0
	BPL.b	Update_background_ai_car_Osc_speed
	MOVEQ	#8, D0
Update_background_ai_car_Osc_speed:
	MOVE.w	D0, $26(A0)
	BRA.w	Advance_ai_track_position
Update_background_ai_car_Approach:
	LEA	$38(A0), A2
	MOVEQ	#1, D7
Update_background_ai_car_Approach_loop:
	MOVE.w	(A2)+, D0
	BEQ.w	Update_background_ai_car_Curve
	MOVE.l	#$00070008, D3
	MOVE.l	#$00A00080, D5
	CMPI.w	#$FFFF, D0
	BNE.b	Update_background_ai_car_Approach_from_ptr
	SWAP	D3
	ADD.w	$22(A0), D3
	SWAP	D5
	LEA	Player_obj.w, A1
	BRA.b	Update_background_ai_car_Approach_diff
Update_background_ai_car_Approach_from_ptr:
	MOVEA.w	D0, A1
Update_background_ai_car_Approach_diff:
	MOVE.w	$12(A1), D0
	SUB.w	$12(A0), D0
	BPL.b	Update_background_ai_car_Approach_close
	NEG.w	D0
Update_background_ai_car_Approach_close:
	CMP.w	D5, D0
	BCC.w	Update_background_ai_car_Curve
	CMPI.w	#$0048, D0
	SCS	D6
	MOVE.w	$1E(A1), D0
	SUB.w	$1E(A0), D0
	CMPI.w	#$003C, D0
	BCC.w	Update_background_ai_car_Curve
	CMPI.w	#$0028, D0
	BCC.b	Update_background_ai_car_Steer_Join
	CMPI.w	#$000C, D0
	BHI.b	Update_background_ai_car_Approach_steer_other
	TST.b	D6
	BNE.b	Update_background_ai_car_Approach_steer_to_target
	MOVE.w	$12(A0), D0
	BPL.b	Update_background_ai_car_Approach_side_check
	NEG.w	D0
Update_background_ai_car_Approach_side_check:
	CMPI.w	#$00A0, D0
	BCS.b	Update_background_ai_car_Approach_steer_other
Update_background_ai_car_Approach_steer_to_target:
	MOVE.w	$26(A1), D0
	SUBI.w	#$0028, D0
	MOVE.w	$22(A0), D1
	ADDQ.w	#1, D1
	ADD.w	D1, D1
	ADD.w	D1, D1
	ADD.w	D1, D0
	BPL.b	Update_background_ai_car_Approach_clamp_steer
	MOVEQ	#1, D0
Update_background_ai_car_Approach_clamp_steer:
	MOVE.w	D0, $26(A0)
	MOVEQ	#-1, D6
	BRA.b	Update_background_ai_car_Steer_Join
Update_background_ai_car_Approach_steer_other:
	MOVE.w	$26(A1), D1
	SUB.w	$26(A0), D1
	BEQ.b	Update_background_ai_car_Steer_Join
	BCC.b	Update_background_ai_car_Curve
	TST.b	D6
	BEQ.b	Update_background_ai_car_Steer_Join
	ASR.w	#2, D1
	ADD.w	D1, $26(A0)
Update_background_ai_car_Steer_Join:
	MOVE.w	$12(A1), D1
	CMPI.w	#$FFA0, D1
	BLE.b	Update_background_ai_car_Steer
	NEG.w	D3
	CMPI.w	#$0060, D1
	BGE.b	Update_background_ai_car_Steer
	CMP.w	$12(A0), D1
	BNE.b	Update_background_ai_car_Approach_x_compare
	TST.w	D1
	BPL.b	Update_background_ai_car_Steer
	NEG.w	D3
	BRA.b	Update_background_ai_car_Steer
Update_background_ai_car_Approach_x_compare:
	BGT.b	Update_background_ai_car_Steer
	NEG.w	D3
;Update_background_ai_car_Steer
Update_background_ai_car_Steer:
	MOVE.w	D3, D0
	JSR	Apply_lateral_offset_clamped(PC)
	CLR.b	$3D(A0)
	TST.b	D6
	BEQ.w	Update_background_ai_car_Advance
	BRA.w	Advance_ai_track_position
;Update_background_ai_car_Curve
Update_background_ai_car_Curve:
	DBF	D7, Update_background_ai_car_Approach_loop
	LEA	Curve_data+1, A5
	MOVE.w	$1A(A0), D0
	MOVE.w	D0, D1
	LSR.w	#2, D0
	MOVE.b	(A5,D0.w), D2
	MOVE.w	D2, D4
	ANDI.w	#$003F, D2
	ADDI.w	#$0046, D1
	CMP.w	Track_length.w, D1
	BCS.b	Update_background_ai_car_Curve_lookahead_wrap
	SUB.w	Track_length.w, D1
Update_background_ai_car_Curve_lookahead_wrap:
	LSR.w	#2, D1
	MOVE.b	(A5,D1.w), D3
	MOVE.w	D3, D5
	ANDI.w	#$003F, D3
	TST.w	D2
	BEQ.b	Update_background_ai_car_Curve_ahead_only
	CMPI.w	#$000B, D2
	BHI.b	Update_background_ai_car_Curve_ahead_only
	TST.w	D3
	BEQ.w	Update_background_ai_car_Lateral
	CMPI.w	#$000B, D3
	BHI.w	Update_background_ai_car_Lateral
	ADD.w	D3, D3
	MOVE.w	D3, D0
	ADD.w	D3, D3
	ADD.w	D3, D3
	ADD.w	D0, D3
	ADD.w	$34(A0), D3
	CMP.w	$26(A0), D3
	BCS.b	Update_background_ai_car_Curve_decel
	TST.b	$3D(A0)
	BNE.w	Update_background_ai_car_Advance
	MOVEQ	#4, D0
	JSR	Apply_lateral_offset_clamped_with_flip(PC)
	BRA.w	Update_background_ai_car_Advance
Update_background_ai_car_Curve_decel:
	SUBQ.w	#3, $26(A0)
	TST.b	$3D(A0)
	BNE.w	Update_background_ai_car_Advance_Done
	MOVEQ	#-7, D0
	JSR	Apply_lateral_offset_clamped_with_flip(PC)
	BRA.w	Advance_ai_track_position
Update_background_ai_car_Curve_ahead_only:
	TST.w	D3
	BEQ.b	Update_background_ai_car_Lateral
	CMPI.w	#$000B, D3
	BHI.b	Update_background_ai_car_Lateral
	BTST.l	#6, D5
	BNE.b	Update_background_ai_car_Curve_facing_right
	CMPI.w	#$FF60, $12(A0)
	BLT.b	Update_background_ai_car_Apply_curve_speed
	BRA.b	Update_background_ai_car_Curve_centred
Update_background_ai_car_Curve_facing_right:
	CMPI.w	#$00A0, $12(A0)
	BGT.b	Update_background_ai_car_Apply_curve_speed
Update_background_ai_car_Curve_centred:
	TST.b	$3D(A0)
	BNE.b	Update_background_ai_car_Apply_curve_speed
	MOVEQ	#5, D0
	MOVE.w	D5, D4
	JSR	Apply_lateral_offset_clamped_with_flip(PC)
Update_background_ai_car_Apply_curve_speed:
	MOVE.w	D3, D2
	ADD.w	D3, D3
	MOVE.w	D3, D0
	ADD.w	D3, D3
	ADD.w	D3, D3
	ADD.w	D0, D3
	ADD.w	$34(A0), D3
	CMP.w	$26(A0), D3
	BCC.b	Update_background_ai_car_Advance
	SUBI.w	#$000C, D2
	ADD.w	D2, $26(A0)
	BRA.b	Update_background_ai_car_Advance_Done
;Update_background_ai_car_Lateral
Update_background_ai_car_Lateral:
	TST.b	$3D(A0)
	BNE.b	Update_background_ai_car_Advance
	MOVE.w	$12(A0), D1
	SUB.w	$36(A0), D1
	SLT	D2
	BPL.b	Update_background_ai_car_Lat_abs
	NEG.w	D1
Update_background_ai_car_Lat_abs:
	CMPI.w	#8, D1
	BCS.b	Update_background_ai_car_Advance
	MOVEQ	#4, D0
	TST.b	D2
	BNE.b	Update_background_ai_car_Lat_neg
	NEG.w	D0
Update_background_ai_car_Lat_neg:
	JSR	Apply_lateral_offset_clamped(PC)
;Update_background_ai_car_Advance
Update_background_ai_car_Advance:
	MOVE.b	$2B(A0), D2
	EXT.w	D2
	LEA	Bg_ai_car_speed_scale_table(PC), A1
	MOVE.l	(A1,D2.w), D2
	MOVE.l	$32(A0), D0
	CLR.w	D0
	MOVE.l	$26(A0), D1
	LSL.l	#7, D1
	SUB.l	D1, D0
	MOVEQ	#$0000000F, D1
	LSR.l	D1, D0
	ADD.l	D2, D0
	ADD.l	D0, $26(A0)
	MOVE.w	$30(A0), D0
	CMP.w	$26(A0), D0
	BHI.b	Update_background_ai_car_Advance_Done
	MOVE.w	D0, $26(A0)
	CLR.w	$28(A0)
Update_background_ai_car_Advance_Done:
	TST.b	$3D(A0)
	BEQ.b	Advance_ai_track_position
	MOVE.w	$12(A0), D0
	BPL.b	Update_background_ai_car_Nudge_abs
	NEG.w	D0
Update_background_ai_car_Nudge_abs:
	CMPI.w	#$0090, D0
	BCC.b	Advance_ai_track_position
	TST.w	$22(A0)
	BMI.b	Advance_ai_track_position
	MOVE.w	Horizontal_position.w, D0
	SUB.w	$12(A0), D0
	SLT	D1
	BPL.b	Update_background_ai_car_Nudge_check
	NEG.w	D0
Update_background_ai_car_Nudge_check:
	CMPI.w	#$0048, D0
	BCS.b	Advance_ai_track_position
	CMPI.w	#$00B8, D0
	BCC.b	Advance_ai_track_position
	MOVEQ	#4, D0
	SUB.w	$22(A0), D0
	TST.b	D1
	BNE.b	Update_background_ai_car_Nudge_neg
	NEG.w	D0
Update_background_ai_car_Nudge_neg:
	JSR	Apply_lateral_offset_clamped(PC)
Advance_ai_track_position:
; Shared merge point: advance AI car track position by its current speed.
; Uses Speed_to_distance_table speed-to-distance table: D0 = speed*4 word index.
; Adds distance delta to $1E(A0) (AI track distance lo-word) and $1A(A0) (hi-word offset).
; When position wraps past Track_length, increments lap count and may set obstacle flag.
	MOVE.w	$26(A0), D0
	ADD.w	D0, D0
	ADD.w	D0, D0
	LEA	Speed_to_distance_table, A1
	MOVE.l	(A1,D0.w), D0
	ADD.l	D0, $1E(A0)
	ADD.l	$1A(A0), D0
	SWAP	D0
	CMP.w	Track_length.w, D0
	BCS.b	Advance_ai_track_position_Done
	SUB.w	Track_length.w, D0
	ADDQ.w	#1, $22(A0)
	TST.b	$3C(A0)
	BEQ.b	Advance_ai_track_position_Lap_std
	TST.w	Ai_active_flag.w
	BEQ.b	Advance_ai_track_position_Lap_rival
	TST.w	Ai_lap_transition_flag.w
	BNE.b	Advance_ai_track_position_Lap_rival
	MOVE.w	#1, Ai_lap_transition_flag.w
Advance_ai_track_position_Lap_rival:
	CMPI.w	#5, $22(A0)
	BNE.b	Advance_ai_track_position_Done
	MOVE.b	#$FF, $3E(A0)
	BRA.b	Advance_ai_track_position_Done
Advance_ai_track_position_Lap_std:
	CMPI.w	#3, $22(A0)
	BNE.b	Advance_ai_track_position_Done
	MOVE.b	#$FF, $3E(A0)
Advance_ai_track_position_Done:
	SWAP	D0
	MOVE.l	D0, $1A(A0)
	SWAP	D0
	JSR	Compute_minimap_index
Update_background_ai_car_Finish:
	MOVE.w	#$2000, $C(A0)
	CLR.b	$3D(A0)
	JSR	Compute_ai_position_and_depth_sort(PC)
	LEA	Ai_screen_x_dispatch_table, A1
	JSR	(A1,D7.w)
	TST.b	$3C(A0)
	BEQ.b	Update_background_ai_car_Rival_clear_anim
	MOVE.w	#$2000, $C(A0)
Update_background_ai_car_Rival_clear_anim:
	TST.b	$3E(A0)
	BEQ.b	Update_background_ai_car_Live_check
	BTST.b	#0, Frame_counter.w
	BNE.b	Update_background_ai_car_Obstacle_osc
	CLR.l	$4(A0)
Update_background_ai_car_Obstacle_osc:
	MOVEQ	#1, D0
	CMPI.w	#$0060, $26(A0)
	BCS.b	Update_background_ai_car_Obstacle_dir
	NEG.w	D0
Update_background_ai_car_Obstacle_dir:
	ADD.w	D0, $26(A0)
	MOVEQ	#0, D0
	JSR	Load_minimap_position
	CMPI.w	#$00B0, $1A(A0)
	BCS.b	Advance_ai_track_position_Exit
	ADDI.w	#$000C, $12(A0)
	CMPI.w	#$01E0, $12(A0)
	BLE.b	Advance_ai_track_position_Exit
	MOVE.w	#$01E0, $12(A0)
	CLR.l	$4(A0)
	MOVEQ	#-2, D0
	JSR	Load_minimap_position
	TST.b	$3F(A0)
	BNE.b	Advance_ai_track_position_Exit
	ADDQ.w	#1, Checkpoint_index.w
	MOVE.b	#$FF, $3F(A0)
	CMPI.w	#$000F, Checkpoint_index.w
	BNE.b	Advance_ai_track_position_Exit
	MOVE.l	#$0000BD56, Frame_callback.w
Advance_ai_track_position_Exit:
	RTS
Update_background_ai_car_Live_check:
	CMPA.w	#0, A6
	BEQ.b	Advance_ai_check_collision
	JSR	Check_ai_collision_with_player(PC)
Advance_ai_check_collision:
	CLR.l	$38(A0)
	MOVE.b	Frame_counter.w, D0
	ADD.w	Object_update_counter.w, D0
	LSR.w	#1, D0
	BCC.b	Advance_ai_track_position_Return
	MOVE.w	$1A(A0), D0
	LSR.w	#2, D0
	MOVE.b	$2D(A0), D1
	MOVE.b	$2F(A0), D2
	LEA	Physical_slope_data, A5
	MOVE.b	(A5,D0.w), D3 ; physical slope at AI car's track position
	MOVE.b	D3, $2D(A0)
	LEA	Curve_data+1, A5
	MOVE.b	(A5,D0.w), D4
	MOVE.b	D4, $2F(A0)
	TST.b	D3
	BMI.b	Advance_ai_track_position_Slope_neg
	BNE.b	Advance_ai_track_position_Slope_check_curve
	SUBQ.b	#1, D1
	BEQ.b	Advance_ai_track_position_Slope_smoke
	BRA.b	Advance_ai_track_position_Slope_check_curve
Advance_ai_track_position_Slope_neg:
	TST.b	D1
	BPL.b	Advance_ai_track_position_Slope_smoke
Advance_ai_track_position_Slope_check_curve:
	TST.b	D4
	BEQ.b	Advance_ai_track_position_Return
	TST.b	D2
	BNE.b	Advance_ai_track_position_Return
Advance_ai_track_position_Slope_smoke:
	TST.w	D7
	BEQ.b	Advance_ai_track_position_Return
	CMPI.w	#$00A0, $26(A0)
	BCS.b	Advance_ai_track_position_Return
	BTST.b	#0, $1B(A0)
	BEQ.b	Advance_ai_track_position_Return
	MOVE.w	$1A(A0), D0
	MOVE.l	#$0000A0CC, D1
	JSR	Alloc_and_init_aux_object_slot
	BCS.b	Advance_ai_track_position_Return
	MOVE.w	$12(A0), $12(A1)
	MOVE.w	$26(A0), D0
	LSR.w	#3, D0
	MOVE.w	D0, $26(A1)
;Advance_ai_track_position_Return
Advance_ai_track_position_Return:
	RTS
;Apply_lateral_offset_clamped_with_flip
Apply_lateral_offset_clamped_with_flip:
; Variant of Apply_lateral_offset_clamped that negates D0 if bit 6 of D4 is 0.
; Inputs:  D0 = lateral delta, D4 = direction flags, A0 = object slot
	ANDI.w	#$0040, D4
	BNE.b	Apply_lateral_offset_clamped
	NEG.w	D0
;Apply_lateral_offset_clamped
Apply_lateral_offset_clamped:
; Adds D0 to the object's lateral offset ($12(A0)), clamps to ±$B8.
; Inputs:  D0 = signed lateral delta, A0 = object slot
; Output:  $12(A0) updated
	ADD.w	$12(A0), D0
	SMI	D1
	BPL.b	Apply_lateral_offset_clamped_Positive
	NEG.w	D0
Apply_lateral_offset_clamped_Positive:
	CMPI.w	#$00B8, D0
	BLS.b	Apply_lateral_offset_clamped_Clamp_done
	MOVE.w	#$00B8, D0
Apply_lateral_offset_clamped_Clamp_done:
	TST.b	D1
	BEQ.b	Apply_lateral_offset_clamped_Write
	NEG.w	D0
Apply_lateral_offset_clamped_Write:
	MOVE.w	D0, $12(A0)
	RTS
Init_rival_ai_car:
; Initialise the rival car AI object for championship mode.
; Called once at race start; A0 = rival car object slot.
;
; Speed and acceleration parameters are read from Ai_placement_data_champ
; (5 bytes per entry, indexed by Rival_team & $0F):
;   Bytes 0-1: max speed high word (big-endian byte pair)
;   Bytes 2-3: acceleration word
;   Byte  4:   speed scale index → $2B(A0) (indexes Bg_ai_car_speed_scale_table)
;
; The player-vs-rival team match-up applies signed word adjustments from
; Ai_placement_champ_offsets (indexed by (player_group - rival_group) × 16):
;   Words 0,1 → added to max speed and acceleration respectively.
;
; Shift type bonuses are applied to max speed:
;   Auto (Shift_type = 0): no bonus
;   4-speed (Shift_type = 1): +$16
;   7-speed (Shift_type = 2): +$16 +$44
;
; Player_state_flags bit 3 (team-level advantage flag):
;   If set, max speed += $0A, acceleration += $0C, speed scale = 8,
;   initial speed = $32, rival flag ($3C) set to $FF.
;
; Track 3 (Hungary) applies a -6 acceleration penalty.
;
; Object fields set:
;   $30(A0) = max speed
;   $32(A0) = max speed × 128 (fixed-point threshold for speed integration)
;   $34(A0) = acceleration
;   $2B(A0) = speed scale index
;   (A0)    = frame handler: Update_rival_ai_car_Frame
;   $36(A0) = initial lateral X (copy of $12)
;   $1E(A0) = initial track position (copy of $1A)
;   $22(A0) = $FFFF (lap count, pre-decremented at first wrap)
;   $24(A0) = 3 (render type)
	MOVE.b	Player_team.w, D0
	ANDI.w	#$000F, D0
	LSR.w	#2, D0
	MOVE.b	Rival_team.w, D1
	ANDI.w	#$000F, D1
	LSR.w	#2, D1
	SUB.w	D0, D1
	LSL.w	#4, D1
	LEA	Ai_placement_champ_offsets, A6
	ADDA.w	D1, A6
	MOVE.b	Rival_team.w, D0
	ANDI.w	#$000F, D0
	MULU.w	#5, D0
	LEA	Ai_placement_data_champ, A1
	ADDA.w	D0, A1
	MOVE.b	(A1)+, D0
	LSL.w	#8, D0
	MOVE.b	(A1)+, D0
	TST.w	Shift_type.w
	BEQ.b	Init_rival_ai_car_After_shift
	ADDI.w	#$0016, D0
	CMPI.w	#1, Shift_type.w
	BEQ.b	Init_rival_ai_car_After_shift
	ADDI.w	#$0044, D0
Init_rival_ai_car_After_shift:
	BTST.b	#3, Player_state_flags.w
	BEQ.b	Init_rival_ai_car_After_team
	ADDI.w	#$000A, D0
Init_rival_ai_car_After_team:
	ADD.w	(A6)+, D0
	MOVE.w	D0, $30(A0)
	LSL.w	#7, D0
	MOVE.w	D0, $32(A0)
	MOVE.b	(A1)+, D0
	LSL.w	#8, D0
	MOVE.b	(A1)+, D0
	ADD.w	(A6)+, D0
	CMPI.w	#3, Track_index.w
	BNE.b	Init_rival_ai_car_After_track
	SUBQ.w	#6, D0
Init_rival_ai_car_After_track:
	MOVE.w	D0, $34(A0)
	MOVE.b	(A1)+, $2B(A0)
	BTST.b	#3, Player_state_flags.w
	BEQ.b	Init_rival_ai_car_Install_frame
	MOVE.b	#8, $2B(A0)
	ADDI.w	#$000C, $34(A0)
	MOVE.w	#$0032, $26(A0)
	MOVE.b	#$FF, $3C(A0)
Init_rival_ai_car_Install_frame:
	MOVE.l	#Update_rival_ai_car_Frame, (A0)
	MOVE.w	$12(A0), $36(A0)
	MOVE.w	$1A(A0), $1E(A0)
	MOVE.w	#$FFFF, $22(A0)
	MOVE.b	#3, $24(A0)
Update_rival_ai_car_Frame:
	JSR	Skip_if_hidden_flag(PC)
	TST.b	$3C(A0)
	BEQ.b	Update_rival_ai_car_Rival_flag
	CLR.b	$3D(A0)
Update_rival_ai_car_Rival_flag:
	TST.w	Race_finish_flag.w
	BNE.w	Advance_rival_track_position_Finish
	TST.w	Race_started.w
	BEQ.w	Advance_rival_track_position_Finish
	TST.b	$3E(A0)
	BNE.w	Advance_rival_track_position_Step
	TST.b	$10(A0)
	BEQ.b	Update_rival_ai_car_Approach
	SUBQ.b	#1, $15(A0)
	BPL.b	Update_rival_ai_car_Osc_done
	MOVE.b	#1, $15(A0)
	MOVE.b	$11(A0), D0
	ADD.b	$14(A0), D0
	BEQ.b	Update_rival_ai_car_Osc_flip
	CMPI.b	#$10, D0
	BNE.b	Update_rival_ai_car_Osc_store
Update_rival_ai_car_Osc_flip:
	NEG.b	$14(A0)
Update_rival_ai_car_Osc_store:
	MOVE.b	D0, $11(A0)
	SUBQ.b	#1, $10(A0)
Update_rival_ai_car_Osc_done:
	TST.b	$3C(A0)
	BNE.w	Update_rival_ai_car_Steer
	MOVE.w	$26(A0), D0
	SUBQ.w	#2, D0
	BPL.b	Update_rival_ai_car_Osc_speed
	MOVEQ	#8, D0
Update_rival_ai_car_Osc_speed:
	MOVE.w	D0, $26(A0)
	BRA.w	Advance_rival_track_position
Update_rival_ai_car_Approach:
	LEA	$38(A0), A2
	MOVEQ	#1, D7
Update_rival_ai_car_Approach_loop:
	MOVE.w	(A2)+, D0
	BEQ.w	Update_rival_ai_car_Curve
	MOVE.l	#$00070008, D3
	MOVE.l	#$00A00080, D5
	CMPI.w	#$FFFF, D0
	BNE.b	Update_rival_ai_car_Approach_from_ptr
	SWAP	D3
	ADD.w	$22(A0), D3
	SWAP	D5
	LEA	Player_obj.w, A1
	BRA.b	Update_rival_ai_car_Approach_diff
Update_rival_ai_car_Approach_from_ptr:
	MOVEA.w	D0, A1
Update_rival_ai_car_Approach_diff:
	MOVE.w	$12(A1), D0
	SUB.w	$12(A0), D0
	BPL.b	Update_rival_ai_car_Approach_close
	NEG.w	D0
Update_rival_ai_car_Approach_close:
	CMP.w	D5, D0
	BCC.w	Update_rival_ai_car_Curve
	CMPI.w	#$0050, D0
	SCS	D6
	MOVE.w	$1E(A1), D0
	SUB.w	$1E(A0), D0
	CMPI.w	#$003C, D0
	BCC.w	Update_rival_ai_car_Curve
	CMPI.w	#$0028, D0
	BCC.b	Update_rival_ai_car_Steer_Join
	CMPI.w	#$000C, D0
	BHI.b	Update_rival_ai_car_Approach_steer_other
	TST.b	D6
	BNE.b	Update_rival_ai_car_Approach_steer_to_target
	MOVE.w	$12(A0), D0
	BPL.b	Update_rival_ai_car_Approach_side_check
	NEG.w	D0
Update_rival_ai_car_Approach_side_check:
	CMPI.w	#$00A0, D0
	BCS.b	Update_rival_ai_car_Approach_steer_other
Update_rival_ai_car_Approach_steer_to_target:
	MOVE.w	$26(A1), D0
	SUBI.w	#$0028, D0
	MOVE.w	$22(A0), D1
	ADDQ.w	#1, D1
	ADD.w	D1, D1
	ADD.w	D1, D1
	ADD.w	D1, D0
	BPL.b	Update_rival_ai_car_Approach_clamp_steer
	MOVEQ	#1, D0
Update_rival_ai_car_Approach_clamp_steer:
	MOVE.w	D0, $26(A0)
	MOVEQ	#-1, D6
	BRA.b	Update_rival_ai_car_Steer_Join
Update_rival_ai_car_Approach_steer_other:
	MOVE.w	$26(A1), D1
	SUB.w	$26(A0), D1
	BEQ.b	Update_rival_ai_car_Steer_Join
	BCC.b	Update_rival_ai_car_Curve
	TST.b	D6
	BEQ.b	Update_rival_ai_car_Steer_Join
	ASR.w	#2, D1
	ADD.w	D1, $26(A0)
Update_rival_ai_car_Steer_Join:
	MOVE.w	$12(A1), D1
	CMPI.w	#$FFA0, D1
	BLE.b	Update_rival_ai_car_Steer_Apply
	NEG.w	D3
	CMPI.w	#$0060, D1
	BGE.b	Update_rival_ai_car_Steer_Apply
	CMP.w	$12(A0), D1
	BNE.b	Update_rival_ai_car_Approach_x_compare
	TST.w	D1
	BPL.b	Update_rival_ai_car_Steer_Apply
	NEG.w	D3
	BRA.b	Update_rival_ai_car_Steer_Apply
Update_rival_ai_car_Approach_x_compare:
	BGT.b	Update_rival_ai_car_Steer_Apply
	NEG.w	D3
;Update_rival_ai_car_Steer_Apply
Update_rival_ai_car_Steer_Apply:
	MOVE.w	D3, D0
	JSR	Apply_lateral_offset_clamped(PC)
	CLR.b	$3D(A0)
	TST.b	D6
	BEQ.w	Update_rival_ai_car_Advance
	BRA.w	Advance_rival_track_position
Update_rival_ai_car_Curve:
	DBF	D7, Update_rival_ai_car_Approach_loop
	LEA	Curve_data+1, A5
	MOVE.w	$1A(A0), D0
	MOVE.w	D0, D1
	LSR.w	#2, D0
	MOVE.b	(A5,D0.w), D2
	MOVE.w	D2, D4
	ANDI.w	#$003F, D2
	ADDI.w	#$0046, D1
	CMP.w	Track_length.w, D1
	BCS.b	Update_rival_ai_car_Curve_lookahead_wrap
	SUB.w	Track_length.w, D1
Update_rival_ai_car_Curve_lookahead_wrap:
	LSR.w	#2, D1
	MOVE.b	(A5,D1.w), D3
	MOVE.w	D3, D5
	ANDI.w	#$003F, D3
	TST.w	D2
	BEQ.b	Update_rival_ai_car_Curve_ahead_only
	CMPI.w	#$000B, D2
	BHI.b	Update_rival_ai_car_Curve_ahead_only
	TST.w	D3
	BEQ.w	Update_rival_ai_car_Steer
	CMPI.w	#$000B, D3
	BHI.w	Update_rival_ai_car_Steer
	ADD.w	D3, D3
	MOVE.w	D3, D0
	ADD.w	D3, D3
	ADD.w	D3, D3
	ADD.w	D0, D3
	ADD.w	$34(A0), D3
	CMP.w	$26(A0), D3
	BCS.b	Update_rival_ai_car_Curve_decel
	TST.b	$3D(A0)
	BNE.w	Update_rival_ai_car_Advance
	MOVEQ	#4, D0
	JSR	Apply_lateral_offset_clamped_with_flip(PC)
	BRA.w	Update_rival_ai_car_Advance
Update_rival_ai_car_Curve_decel:
	SUBQ.w	#3, $26(A0)
	TST.b	$3D(A0)
	BNE.w	Update_rival_ai_car_Advance_Done
	MOVEQ	#-7, D0
	JSR	Apply_lateral_offset_clamped_with_flip(PC)
	BRA.w	Advance_rival_track_position
Update_rival_ai_car_Curve_ahead_only:
	TST.w	D3
	BEQ.b	Update_rival_ai_car_Steer
	CMPI.w	#$000B, D3
	BHI.b	Update_rival_ai_car_Steer
	BTST.l	#6, D5
	BNE.b	Update_rival_ai_car_Curve_facing_right
	CMPI.w	#$FF60, $12(A0)
	BLT.b	Update_rival_ai_car_Apply_curve_speed
	BRA.b	Update_rival_ai_car_Curve_centred
Update_rival_ai_car_Curve_facing_right:
	CMPI.w	#$00A0, $12(A0)
	BGT.b	Update_rival_ai_car_Apply_curve_speed
Update_rival_ai_car_Curve_centred:
	TST.b	$3D(A0)
	BNE.b	Update_rival_ai_car_Apply_curve_speed
	MOVEQ	#5, D0
	MOVE.w	D5, D4
	JSR	Apply_lateral_offset_clamped_with_flip(PC)
Update_rival_ai_car_Apply_curve_speed:
	MOVE.w	D3, D2
	ADD.w	D3, D3
	MOVE.w	D3, D0
	ADD.w	D3, D3
	ADD.w	D3, D3
	ADD.w	D0, D3
	ADD.w	$34(A0), D3
	CMP.w	$26(A0), D3
	BCC.b	Update_rival_ai_car_Advance
	SUBI.w	#$000C, D2
	ADD.w	D2, $26(A0)
	BRA.b	Update_rival_ai_car_Advance_Done
;Update_rival_ai_car_Steer
Update_rival_ai_car_Steer:
	TST.b	$3D(A0)
	BNE.b	Update_rival_ai_car_Advance
	MOVE.w	$12(A0), D1
	SUB.w	$36(A0), D1
	SLT	D2
	BPL.b	Update_rival_ai_car_Lat_abs
	NEG.w	D1
Update_rival_ai_car_Lat_abs:
	CMPI.w	#8, D1
	BCS.b	Update_rival_ai_car_Advance
	MOVEQ	#4, D0
	TST.b	D2
	BNE.b	Update_rival_ai_car_Lat_neg
	NEG.w	D0
Update_rival_ai_car_Lat_neg:
	JSR	Apply_lateral_offset_clamped(PC)
;Update_rival_ai_car_Advance
Update_rival_ai_car_Advance:
	MOVE.b	$2B(A0), D2
	EXT.w	D2
	LEA	Bg_ai_car_speed_scale_table(PC), A1
	MOVE.l	(A1,D2.w), D2
	MOVE.l	$32(A0), D0
	CLR.w	D0
	MOVE.l	$26(A0), D1
	LSL.l	#7, D1
	SUB.l	D1, D0
	MOVEQ	#$0000000F, D1
	LSR.l	D1, D0
	ADD.l	D2, D0
	ADD.l	D0, $26(A0)
	MOVE.w	$30(A0), D0
	CMP.w	$26(A0), D0
	BHI.b	Update_rival_ai_car_Advance_Done
	MOVE.w	D0, $26(A0)
	CLR.w	$28(A0)
Update_rival_ai_car_Advance_Done:
	TST.b	$3D(A0)
	BEQ.b	Advance_rival_track_position
	MOVE.w	$12(A0), D0
	BPL.b	Update_rival_ai_car_Nudge_abs
	NEG.w	D0
Update_rival_ai_car_Nudge_abs:
	CMPI.w	#$0090, D0
	BCC.b	Advance_rival_track_position
	TST.w	$22(A0)
	BMI.b	Advance_rival_track_position
	MOVE.w	Horizontal_position.w, D0
	SUB.w	$12(A0), D0
	SLT	D1
	BPL.b	Update_rival_ai_car_Nudge_check
	NEG.w	D0
Update_rival_ai_car_Nudge_check:
	CMPI.w	#$0048, D0
	BCS.b	Advance_rival_track_position
	CMPI.w	#$00B8, D0
	BCC.b	Advance_rival_track_position
	MOVEQ	#4, D0
	SUB.w	$22(A0), D0
	TST.b	D1
	BNE.b	Update_rival_ai_car_Nudge_neg
	NEG.w	D0
Update_rival_ai_car_Nudge_neg:
	JSR	Apply_lateral_offset_clamped(PC)
Advance_rival_track_position:
; Shared merge point for the rival car: advance track position by speed,
; and also check proximity to player to clamp rival speed to player speed
; when the rival's place score is ahead of the player's by < 100 points.
; Mirror of Advance_ai_track_position but for the rival object.
	TST.b	$3C(A0)
	BPL.b	Advance_rival_track_position_Step
	MOVE.w	Player_place_score.w, D0
	SUB.w	$1E(A0), D0
	BPL.b	Advance_rival_track_position_Step
	NEG.w	D0
	CMPI.w	#100, D0
	BCC.b	Advance_rival_track_position_Step
	MOVE.w	Player_speed.w, D0
	CMP.w	$26(A0), D0
	BCS.b	Advance_rival_track_position_Step
	MOVE.w	D0, $26(A0)
;Advance_rival_track_position_Step
Advance_rival_track_position_Step:
	MOVE.w	$26(A0), D0
	ADD.w	D0, D0
	ADD.w	D0, D0
	LEA	Speed_to_distance_table, A1
	MOVE.l	(A1,D0.w), D0
	ADD.l	D0, $1E(A0)
	ADD.l	$1A(A0), D0
	SWAP	D0
	CMP.w	Track_length.w, D0
	BCS.b	Advance_rival_track_position_Done
	TST.w	Ai_active_flag.w
	BEQ.b	Advance_rival_track_position_Lap
	TST.w	Ai_lap_transition_flag.w
	BNE.b	Advance_rival_track_position_Lap
	MOVE.w	#2, Ai_lap_transition_flag.w
Advance_rival_track_position_Lap:
	SUB.w	Track_length.w, D0
	ADDQ.w	#1, $22(A0)
	CMPI.w	#5, $22(A0)
	BNE.b	Advance_rival_track_position_Done
	MOVE.b	#$FF, $3E(A0)
Advance_rival_track_position_Done:
	SWAP	D0
	MOVE.l	D0, $1A(A0)
	SWAP	D0
	JSR	Compute_minimap_index
Advance_rival_track_position_Finish:
	CLR.b	$3D(A0)
	JSR	Compute_ai_position_and_depth_sort(PC)
	LEA	Ai_screen_x_dispatch_table, A1
	JSR	(A1,D7.w)
	MOVE.w	#$4000, $C(A0)
	TST.b	$3E(A0)
	BEQ.b	Advance_rival_track_position_Live_check
	BTST.b	#0, Frame_counter.w
	BNE.b	Advance_rival_track_position_Obstacle_osc
	CLR.l	$4(A0)
Advance_rival_track_position_Obstacle_osc:
	MOVEQ	#1, D0
	CMPI.w	#$0060, $26(A0)
	BCS.b	Update_rival_ai_car_Obstacle_dir
	NEG.w	D0
Update_rival_ai_car_Obstacle_dir:
	ADD.w	D0, $26(A0)
	MOVEQ	#0, D0
	JSR	Load_minimap_position
	CMPI.w	#$00B0, $1A(A0)
	BCS.b	Advance_rival_track_position_Exit
	ADDI.w	#$000C, $12(A0)
	CMPI.w	#$01E0, $12(A0)
	BLE.b	Advance_rival_track_position_Exit
	MOVE.w	#$01E0, $12(A0)
	CLR.l	$4(A0)
	MOVEQ	#-2, D0
	JSR	Load_minimap_position
	TST.b	$3F(A0)
	BNE.b	Advance_rival_track_position_Exit
	ADDQ.w	#1, Checkpoint_index.w
	MOVE.b	#$FF, $3F(A0)
	CMPI.w	#$000F, Checkpoint_index.w
	BNE.b	Advance_rival_track_position_Exit
	MOVE.l	#$0000BD56, Frame_callback.w
Advance_rival_track_position_Exit:
	RTS
Advance_rival_track_position_Live_check:
	CMPA.w	#0, A6
	BEQ.w	Advance_ai_check_collision
	JSR	Check_ai_collision_with_player(PC)
	BRA.w	Advance_ai_check_collision
;Check_ai_collision_with_player
Check_ai_collision_with_player:
; Detect and respond to a lateral collision between an AI car and the player.
; Called from the background and rival AI update paths when the car is on-screen.
; A0 = AI car object slot.
;
; No-op if: the AI car is already in a post-collision oscillation ($10(A0) != 0),
;           or if Replay_steer_override is set (warm-up/AI inject active).
;
; Collision detection:
;   Player X window: [Horizontal_position - $40, Horizontal_position + $40].
;   If AI car $12(A0) is within this window, a collision is detected.
;
; Overlap classification (D6 = lateral push, D0 = speed penalty):
;   Left side (AI to the left):  D6 = -3, D0 = 7 (light push left)
;   Right side (AI to the right): D6 = +3, D0 = 9 (light push right)
;   Centre overlap:              D6 =  0, D0 = 8 (centred)
;
; On collision:
;   Sets Overtake_flag (if not already set), Ai_x_delta, Ai_overtake_ready.
;   If $25(A0) (sign-pass flag) is set: writes Ai_x_delta based on relative
;     positions and sets Ai_speed_delta = Player_speed / 4.
;   Otherwise (normal road car): triggers AI oscillation ($11, $14), allocates
;     a smoke aux object, resets rival's max speed/accel to arcade start-grid
;     values, and computes Ai_speed_delta from relative speed delta.
	TST.b	$10(A0)
	BNE.b	Check_ai_collision_with_player_Return
	TST.w	Replay_steer_override.w
	BNE.b	Check_ai_collision_with_player_Return
	MOVE.w	Horizontal_position.w, D0
	SUBI.w	#$0040, D0
	CMP.w	$12(A0), D0
	BGE.b	Check_ai_collision_with_player_Return
	ADDI.w	#$0080, D0
	CMP.w	$12(A0), D0
	BLE.b	Check_ai_collision_with_player_Return
	MOVE.w	Horizontal_position.w, D1
	MOVEQ	#3, D6
	MOVEQ	#9, D0
	SUBI.w	#$0028, D1
	CMP.w	$12(A0), D1
	BGE.b	Check_ai_collision_with_player_Overlap
	MOVEQ	#-3, D6
	MOVEQ	#7, D0
	ADDI.w	#$0050, D1
	CMP.w	$12(A0), D1
	BLE.b	Check_ai_collision_with_player_Overlap
	MOVEQ	#0, D6
	MOVEQ	#8, D0
Check_ai_collision_with_player_Overlap:
	TST.w	Overtake_flag.w
	BNE.b	Check_ai_collision_with_player_Set_flags
	MOVE.w	D0, Overtake_flag.w
Check_ai_collision_with_player_Set_flags:
	MOVE.w	#1, Ai_overtake_ready.w
	MOVE.w	D6, Ai_x_delta.w
	TST.b	$25(A0)
	BEQ.b	Check_ai_collision_with_player_Wiggle
	MOVEQ	#4, D6
	MOVE.w	Horizontal_position.w, D0
	CMP.w	$12(A0), D0
	BGE.b	Check_ai_collision_with_player_Dodge_right
	MOVEQ	#-4, D6
Check_ai_collision_with_player_Dodge_right:
	MOVE.w	D6, Ai_x_delta.w
	MOVE.w	Player_speed.w, D0
	LSR.w	#2, D0
	MOVE.w	D0, Ai_speed_delta.w
Check_ai_collision_with_player_Return:
	RTS
Check_ai_collision_with_player_Wiggle:
	MOVE.b	#8, $11(A0)
	MOVE.b	#$FC, $14(A0)
	MOVE.l	#$00009CE8, D1
	JSR	Alloc_and_init_aux_object_slot
	BCS.b	Check_ai_collision_with_player_No_smoke
	MOVE.l	A0, $30(A1)
Check_ai_collision_with_player_No_smoke:
	MOVE.l	#$00240014, D3
	TST.w	Use_world_championship_tracks.w
	BNE.b	Check_ai_collision_with_player_Champ_speed
	MOVE.l	#$003C0024, D3
	MOVE.w	Player_start_grid_arcade.w, D0
	MOVE.w	D0, $30(A0)
	LSL.w	#7, D0
	MOVE.w	D0, $32(A0)
	MOVE.w	Rival_start_grid_arcade.w, $34(A0)
	CLR.b	$2B(A0)
Check_ai_collision_with_player_Champ_speed:
	MOVE.w	Player_speed.w, D1
	MOVE.w	$26(A0), D0
	MOVE.w	D1, D2
	SUB.w	D0, D2
	BPL.b	Check_ai_collision_with_player_Generic
	NEG.w	D2
Check_ai_collision_with_player_Generic:
	CMPA.w	#1, A6
	BEQ.b	Check_ai_collision_with_player_Direct
	MOVE.b	D3, $10(A0)
	TST.b	$3C(A0)
	BMI.b	Check_ai_collision_with_player_Rival_halve
	LSR	$26(A0)
Check_ai_collision_with_player_Rival_halve:
	LSR.w	#1, D2
	CMP.w	D0, D1
	BCS.b	Check_ai_collision_with_player_Delta_sign
	NEG.w	D2
Check_ai_collision_with_player_Delta_sign:
	ADD.w	D2, D1
	BPL.b	Check_ai_collision_with_player_Apply_delta
	MOVEQ	#0, D1
Check_ai_collision_with_player_Apply_delta:
	MOVE.w	D1, Ai_speed_delta.w
	RTS
Check_ai_collision_with_player_Direct:
	SWAP	D3
	MOVE.b	D3, $10(A0)
	LSR.w	#1, D1
	MOVE.w	D1, Ai_speed_delta.w
	CMP.w	D0, D1
	BCC.b	Check_ai_collision_with_player_Direct_sign
	NEG.w	D2
Check_ai_collision_with_player_Direct_sign:
	ADD.w	D2, $26(A0)
	BPL.b	Check_ai_collision_with_player_Direct_clamp
	CLR.l	$26(A0)
	RTS
Check_ai_collision_with_player_Direct_clamp:
	MOVE.w	$30(A0), D0
	CMP.w	$26(A0), D0
	BHI.b	Check_ai_collision_with_player_Direct_cap
	MOVE.w	D0, $26(A0)
	CLR.w	$28(A0)
Check_ai_collision_with_player_Direct_cap:
	RTS
;Skip_if_hidden_flag
Skip_if_hidden_flag:
	TST.w	Race_timer_freeze.w
	BEQ.b	Skip_if_hidden_flag_Return
	MOVE.l	(A7)+, D0
	RTS
Skip_if_hidden_flag_Return:
	RTS
Ai_screen_x_dispatch_table:
; Indexed jump table for AI car screen-X update behavior.
; Called via: LEA Ai_screen_x_dispatch_table, A1 / JSR (A1,D7.w)
; Index 0 (D7=0): RTS (no-op, car hidden or not updating screen X).
; Index +2: NOP word ($4E71) padding.
; Index +4: BRA to Compute_rival_screen_x (standard screen-X calculation path).
; D7 is used as the byte offset into the table.
	RTS
	dc.b	$4E, $71
	BRA.w	Compute_rival_screen_x
Compute_ai_screen_x:
	MOVE.w	D0, D1
	LSR.w	#1, D1
	ANDI.w	#$FFFE, D1
	LEA	Road_row_x_buf.w, A1
	MOVE.w	(A1,D1.w), D1
	ADDI.w	#$0180, D1
	ADD.w	D3, D3
	LEA	Ai_screen_x_scale_table, A1
	MOVE.w	(A1,D3.w), D2
	MOVE.w	$12(A0), D3
	SMI	D6
	BPL.b	Compute_ai_screen_x_Negate_x
	NEG.w	D3
Compute_ai_screen_x_Negate_x:
	MULU.w	D2, D3
	SWAP	D3
	TST.b	D6
	BPL.b	Compute_ai_screen_x_Apply_x
	NEG.w	D3
Compute_ai_screen_x_Apply_x:
	ADD.w	D3, D1
	MOVE.w	D1, $18(A0)
	CMPI.w	#$0074, D1
	BCS.b	Compute_ai_screen_x_Offscreen
	CMPI.w	#$018C, D1
	BCS.b	Compute_ai_screen_x_Onscreen
Compute_ai_screen_x_Offscreen:
	RTS
Compute_ai_screen_x_Onscreen:
	CMPI.b	#1, $24(A0)
	BEQ.w	Assign_ai_sprite_depth_frame_apply
	TST.b	$10(A0)
	BEQ.b	Compute_ai_screen_x_No_forced_frame
	MOVE.b	$11(A0), D1
	EXT.w	D1
	BRA.b	Assign_ai_sprite_depth_frame
Compute_ai_screen_x_No_forced_frame:
	MOVEQ	#8, D1
	CMPI.w	#6, D0
	BCS.b	Assign_ai_sprite_depth_frame
	LEA	Road_bg_curve_interp_buf.w, A1
	MOVE.w	-$6(A1,D0.w), D2
	SUB.w	(A1,D0.w), D2
	SMI	D3
	BPL.b	Compute_ai_screen_x_Curve_negate
	NEG.w	D2
Compute_ai_screen_x_Curve_negate:
	ANDI.w	#$FFFC, D2
	TST.b	D3
	BEQ.b	Compute_ai_screen_x_Curve_apply
	NEG.w	D2
Compute_ai_screen_x_Curve_apply:
	MOVEQ	#-4, D5
	MOVE.w	$12(A0), D3
	SUB.w	Horizontal_position.w, D3
	BPL.b	Compute_ai_screen_x_Offset_check
	NEG.w	D3
	NEG.w	D5
Compute_ai_screen_x_Offset_check:
	SUBI.w	#$004C, D3
	BCS.b	Compute_ai_screen_x_Clamp_min
	ADD.w	D5, D1
	SUBI.w	#$0090, D3
	BCS.b	Compute_ai_screen_x_Clamp_min
	ADD.w	D5, D1
Compute_ai_screen_x_Clamp_min:
	ADD.w	D2, D1
	BPL.b	Compute_ai_screen_x_Clamp_max
	MOVEQ	#0, D1
	BRA.b	Assign_ai_sprite_depth_frame
Compute_ai_screen_x_Clamp_max:
	CMPI.w	#$0010, D1
	BLS.b	Assign_ai_sprite_depth_frame
	MOVE.w	#$0010, D1
Assign_ai_sprite_depth_frame:
	SUBQ.w	#8, D1
	LEA	Ai_sprite_depth_frame_ptrs(PC), A1
	MOVE.l	(A1,D1.w), $8(A0)
	MOVE.b	D1, $2A(A0)
;Assign_ai_sprite_depth_frame_apply
Assign_ai_sprite_depth_frame_apply:
	LEA	Road_row_y_buf.w, A1
	MOVE.w	(A1,D0.w), $16(A0)
	LEA	Ai_screen_x_to_angle_table(PC), A1
	MOVE.b	(A1,D4.w), D4
	MOVEA.l	$8(A0), A1
	MOVE.l	(A1,D4.w), $4(A0)
	JMP	Queue_object_for_alt_sprite_buffer
Compute_rival_screen_x:
	LEA	Road_scanline_x_buf.w, A1
	MOVE.w	(A1,D0.w), D1
	ADDI.w	#$0180, D1
	ADD.w	D3, D3
	LEA	Ai_screen_x_scale_table, A1
	MOVE.w	(A1,D3.w), D2
	MOVE.w	$12(A0), D3
	MOVE.w	D3, D5
	SMI	D6
	BPL.b	Compute_rival_screen_x_Negate_x
	NEG.w	D3
Compute_rival_screen_x_Negate_x:
	MULU.w	D2, D3
	SWAP	D3
	TST.b	D6
	BPL.b	Compute_rival_screen_x_Apply_x
	NEG.w	D3
Compute_rival_screen_x_Apply_x:
	ADD.w	D3, D1
	CMPI.w	#$009F, $E(A0)
	BCS.b	Compute_rival_screen_x_Wide_add
	ADD.w	D5, D1
Compute_rival_screen_x_Wide_add:
	MOVE.w	D1, $18(A0)
	CMPI.w	#$0038, D1
	BCS.b	Compute_rival_screen_x_Offscreen
	CMPI.w	#$01C8, D1
	BCS.b	Compute_rival_screen_x_Onscreen
Compute_rival_screen_x_Offscreen:
	RTS
Compute_rival_screen_x_Onscreen:
	CMPI.b	#1, $24(A0)
	BEQ.w	Compute_rival_screen_x_Queue
	TST.b	$10(A0)
	BEQ.b	Compute_rival_screen_x_No_forced_frame
	MOVE.b	$11(A0), D1
	EXT.w	D1
	BRA.b	Assign_rival_sprite_depth_frame
Compute_rival_screen_x_No_forced_frame:
	MOVEQ	#8, D1
	CMPI.w	#6, D0
	BCS.b	Assign_rival_sprite_depth_frame
	LEA	(Road_row_y_buf+$80).w, A1
	MOVE.w	-$6(A1,D0.w), D2
	SUB.w	(A1,D0.w), D2
	SMI	D3
	BPL.b	Compute_rival_screen_x_Curve_negate
	NEG.w	D2
Compute_rival_screen_x_Curve_negate:
	ANDI.w	#$FFFC, D2
	TST.b	D3
	BEQ.b	Compute_rival_screen_x_Curve_apply
	NEG.w	D2
Compute_rival_screen_x_Curve_apply:
	MOVEQ	#-4, D5
	MOVE.w	$12(A0), D3
	SUB.w	Horizontal_position.w, D3
	BPL.b	Compute_rival_screen_x_Offset_check
	NEG.w	D3
	NEG.w	D5
Compute_rival_screen_x_Offset_check:
	SUBI.w	#$004C, D3
	BCS.b	Compute_rival_screen_x_Clamp_min
	ADD.w	D5, D1
	SUBI.w	#$0090, D3
	BCS.b	Compute_rival_screen_x_Clamp_min
	ADD.w	D5, D1
Compute_rival_screen_x_Clamp_min:
	ADD.w	D2, D1
	BPL.b	Compute_rival_screen_x_Clamp_max
	MOVEQ	#0, D1
	BRA.b	Assign_rival_sprite_depth_frame
Compute_rival_screen_x_Clamp_max:
	CMPI.w	#$0010, D1
	BLS.b	Assign_rival_sprite_depth_frame
	MOVE.w	#$0010, D1
Assign_rival_sprite_depth_frame:
	SUBQ.w	#8, D1
	LEA	Rival_sprite_depth_frame_ptrs(PC), A1
	MOVE.l	(A1,D1.w), $8(A0)
	MOVE.b	D1, $2A(A0)
	MOVE.w	Player_place_score.w, D1
	CMP.w	$1E(A0), D1
	BLS.b	Compute_rival_screen_x_Queue
	MOVE.w	#$4000, $C(A0)
Compute_rival_screen_x_Queue:
	LEA	Road_scale_table.w, A1
	MOVE.w	(A1,D0.w), D1
	SUBI.w	#$002F, D1
	NEG.w	D1
	ADDI.w	#$0130, D1
	MOVE.w	D1, $16(A0)
	LEA	Ai_screen_x_to_angle_table(PC), A1
	MOVE.b	(A1,D4.w), D4
	MOVEA.l	$8(A0), A1
	MOVE.l	(A1,D4.w), $4(A0)
	JMP	Queue_object_for_sprite_buffer
;Compute_ai_position_and_depth_sort
Compute_ai_position_and_depth_sort:
; Determine whether an AI car is ahead of or behind the player, compute its
; screen-row index (D0) and depth-sort insertion key (D7), and maintain
; the leader/second-place pointers for Update_race_position.
; A0 = AI car object slot.
;
; Track-distance comparison:
;   D1 = AI_dist - Player_dist.  If 0 ≤ D1 < $A2 → car is ahead (close).
;   Wrap: add Track_length and re-test.  If still ≥ $A2 → try behind direction.
;   D2 = Player_dist - AI_dist.  If 0 ≤ D2 < $92 → car is behind.
;   Otherwise the car is off-screen; sets $E(A0) = $FFFF, D7 = 0, returns.
;
; Ahead path (car ahead of player):
;   Inserts AI $1E score into Depth_sort_buf (15-entry insertion-sorted list,
;   lowest score first). Companion pointer written to $20(A1) (object address).
;   Updates Depth_sort_value / Depth_sort_leader_ptr (car furthest ahead) and
;   Depth_sort_prev / Depth_sort_prev_ptr (second furthest).
;   If within 4 units ahead, sets A6 += 2 (used as collision candidate flag).
;   Screen-row offset D4 = $91 - D2 (distance from player → row index into
;   Ai_screen_y_table). D7 = 8 + screen-row index word.
;
; Behind path (car behind player):
;   Same insertion sort into Depth_sort_buf.
;   If within $1C units behind, sets nudge inhibit $3D(A0) = $FF.
;   If within 4 units behind, sets A6 += 1 (collision candidate).
;   D4 = $A1 - D1 → row index; D7 = 4 (base dispatch index for behind path).
;
; Output:
;   D0  = screen row index (word offset into road-row tables)
;   D7  = dispatch index into Ai_screen_x_dispatch_table (0=hidden, 4=behind, 8=ahead)
;   D3  = $8000 if ahead, 0 if behind (passed to screen-X routines)
;   D4  = screen-Y row index (byte offset into Ai_screen_y_table)
;   A6  = 0 (no collision), 1 (behind/close), 2 (ahead/close), 3 (both)
;   $E(A0) = row word (used by rival speed-clamp check in Compute_rival_screen_x)
	MOVEA.w	#0, A6
	MOVE.w	Track_length.w, D5
	MOVE.w	$1A(A0), D1
	MOVE.w	D1, D0
	MOVE.w	Player_distance.w, D2
	MOVEQ	#4, D7
	SUB.w	D2, D1
	CMPI.w	#$00A2, D1
	BCS.w	Compute_ai_position_Behind
	ADD.w	D5, D1
	CMPI.w	#$00A2, D1
	BCS.w	Compute_ai_position_Behind
	MOVEQ	#8, D7
	SUB.w	D0, D2
	CMPI.w	#$0092, D2
	BCS.b	Compute_ai_position_Ahead_far
	ADD.w	D5, D2
	CMPI.w	#$0092, D2
	BCS.b	Compute_ai_position_Ahead_far
;Compute_ai_position_Offscreen
Compute_ai_position_Offscreen:
	MOVE.w	#$FFFF, $E(A0)
	MOVEQ	#0, D7
	RTS
Compute_ai_position_Ahead_far:
	MOVE.w	$1E(A0), D0
	MOVEQ	#$0000000E, D3
	LEA	Depth_sort_buf.w, A1
Compute_ai_position_Ahead_far_sort_scan:
	CMP.w	(A1)+, D0
	BCS.b	Compute_ai_position_Ahead_far_sort_insert
	SUBQ.w	#1, D3
	BRA.b	Compute_ai_position_Ahead_far_sort_scan
Compute_ai_position_Ahead_far_sort_insert:
	TST.w	D3
	BMI.b	Compute_ai_position_Ahead_far_sort_write
	LEA	Score_scratch_buf.w, A2
Compute_ai_position_Ahead_far_sort_shift:
	MOVE.w	$1C(A2), $1E(A2)
	MOVE.w	-$4(A2), -(A2)
	DBF	D3, Compute_ai_position_Ahead_far_sort_shift
Compute_ai_position_Ahead_far_sort_write:
	MOVE.w	D0, -(A1)
	MOVE.w	A0, $20(A1)
	CMPI.w	#4, D2
	BHI.b	Compute_ai_position_Ahead_far_leader
	ADDQ.w	#2, A6
Compute_ai_position_Ahead_far_leader:
	CMP.w	Depth_sort_value.w, D2
	BCC.b	Compute_ai_position_Ahead_far_prev_leader
	MOVE.w	Depth_sort_value.w, Depth_sort_prev.w
	MOVE.w	Depth_sort_leader_ptr.w, Depth_sort_prev_ptr.w
	MOVE.w	D2, Depth_sort_value.w
	MOVE.w	A0, Depth_sort_leader_ptr.w
	BRA.b	Compute_ai_position_Ahead_far_screen_y
Compute_ai_position_Ahead_far_prev_leader:
	CMP.w	Depth_sort_prev.w, D2
	BCC.b	Compute_ai_position_Ahead_far_screen_y
	MOVE.w	D2, Depth_sort_prev.w
	MOVE.w	A0, Depth_sort_prev_ptr.w
Compute_ai_position_Ahead_far_screen_y:
	SUBQ.w	#8, D2
	BCS.b	Compute_ai_position_Offscreen
	MOVE.w	#$0091, D4
	SUB.w	D2, D4
	MOVE.w	#$8000, D3
	BRA.b	Compute_ai_position_Ahead_far_y_calc
Compute_ai_position_Behind:
	MOVE.w	$1E(A0), D0
	MOVEQ	#$0000000E, D3
	LEA	Depth_sort_buf.w, A1
Compute_ai_position_Behind_sort_scan:
	CMP.w	(A1)+, D0
	BCS.b	Compute_ai_position_Behind_sort_insert
	SUBQ.w	#1, D3
	BRA.b	Compute_ai_position_Behind_sort_scan
Compute_ai_position_Behind_sort_insert:
	TST.w	D3
	BMI.b	Compute_ai_position_Behind_sort_write
	LEA	Score_scratch_buf.w, A2
Compute_ai_position_Behind_sort_shift:
	MOVE.w	$1C(A2), $1E(A2)
	MOVE.w	-$4(A2), -(A2)
	DBF	D3, Compute_ai_position_Behind_sort_shift
Compute_ai_position_Behind_sort_write:
	MOVE.w	D0, -(A1)
	MOVE.w	A0, $20(A1)
	CMPI.w	#5, D1
	BHI.b	Compute_ai_position_Behind_leader
	ADDQ.w	#1, A6
Compute_ai_position_Behind_leader:
	CMP.w	Depth_sort_value.w, D1
	BCC.b	Compute_ai_position_Behind_prev_leader
	MOVE.w	Depth_sort_value.w, Depth_sort_prev.w
	MOVE.w	Depth_sort_leader_ptr.w, Depth_sort_prev_ptr.w
	MOVE.w	D1, Depth_sort_value.w
	MOVE.w	A0, Depth_sort_leader_ptr.w
	BRA.b	Compute_ai_position_Behind_screen_y
Compute_ai_position_Behind_prev_leader:
	CMP.w	Depth_sort_prev.w, D1
	BCC.b	Compute_ai_position_Behind_screen_y
	MOVE.w	D1, Depth_sort_prev.w
	MOVE.w	A0, Depth_sort_prev_ptr.w
Compute_ai_position_Behind_screen_y:
	CMPI.w	#$001C, D1
	BCC.b	Compute_ai_position_Behind_near_mark
	MOVE.b	#$FF, $3D(A0)
Compute_ai_position_Behind_near_mark:
	SUBQ.w	#4, D1
	BCS.w	Compute_ai_position_Offscreen
	MOVE.w	#$00A1, D4
	SUB.w	D1, D4
	MOVEQ	#0, D3
Compute_ai_position_Ahead_far_y_calc:
	LEA	Ai_screen_y_table, A1
	MOVE.b	(A1,D4.w), D0
	EXT.w	D0
	ADD.w	D0, D0
	ADD.w	D4, D3
	MOVE.w	D3, $E(A0)
	RTS
;Compute_ai_screen_x_offset
Compute_ai_screen_x_offset:
	MOVE.w	Track_length.w, D5
	MOVE.w	$1A(A0), D1
	MOVE.w	D1, D0
	MOVE.w	Player_distance.w, D2
	MOVEQ	#4, D7
	SUB.w	D2, D1
	CMPI.w	#$00A2, D1
	BCS.b	Compute_ai_screen_x_offset_Ahead
	ADD.w	D5, D1
	CMPI.w	#$00A2, D1
	BCS.b	Compute_ai_screen_x_offset_Ahead
	MOVEQ	#8, D7
	SUB.w	D0, D2
	CMPI.w	#$0092, D2
	BCS.b	Compute_ai_screen_x_offset_Behind
	ADD.w	D5, D2
	CMPI.w	#$0092, D2
	BCS.b	Compute_ai_screen_x_offset_Behind
	BRA.w	Compute_ai_position_Offscreen
Compute_ai_screen_x_offset_Ahead:
	SUBQ.w	#4, D1
	BCS.w	Compute_ai_position_Offscreen
	MOVE.w	#$00A1, D4
	SUB.w	D1, D4
	MOVEQ	#0, D3
Compute_ai_screen_x_offset_Y_calc:
	LEA	Ai_screen_y_table, A1
	MOVE.b	(A1,D4.w), D0
	EXT.w	D0
	ADD.w	D0, D0
	ADD.w	D4, D3
	MOVE.w	D3, $E(A0)
	RTS
Compute_ai_screen_x_offset_Behind:
	SUBQ.w	#8, D2
	BCS.w	Compute_ai_position_Offscreen
	MOVE.w	#$0091, D4
	SUB.w	D2, D4
	MOVE.w	#$8000, D3
	BRA.b	Compute_ai_screen_x_offset_Y_calc
