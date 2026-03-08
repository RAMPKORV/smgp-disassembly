; ============================================================
; Title / options menu state values
; ============================================================
; Title_menu_state values:
Title_menu_state_main      = 0 ; main menu (World Championship, Free Practice, Options, Arcade)
Title_menu_state_newpw     = 1 ; new/password sub-menu (New Game, Password)
Title_menu_state_champ     = 2 ; championship sub-menu (Warm Up, Race, Machine, Transmission);
                                ;   also shows track preview art
Title_menu_state_arcade    = 3 ; arcade/track-select sub-menu (track chooser)

; Shift_type values (Shift_type = $FFFFFF2E):
Shift_auto   = 0 ; automatic transmission
Shift_4speed = 1 ; 4-speed manual
Shift_7speed = 2 ; 7-speed manual

; Control_type values (Control_type = $FFFFFF1E):
; Values 0-5 are valid; the options screen wraps at 6 back to 0.
Control_type_count = 6 ; total number of control configurations

; Placement_anim_state values (Placement_anim_state = $FFFFFC7C):
Placement_anim_idle        = 0 ; no change animation running
Placement_anim_counting    = 1 ; animating position change (blinking)
Placement_anim_finished    = 3 ; position animation complete (holds final tile)

