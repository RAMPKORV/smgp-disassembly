; Track_data table
; Each entry is $48 bytes (72 bytes), 19 entries total:
;   16 championship tracks (indices 0-$0F), followed by 3 arcade Monaco variants.
;
; Field layout (offsets from entry base):
;   +$00 .l  minimap tile graphics pointer
;   +$04 .l  background tile graphics pointer
;   +$08 .l  background tile mapping pointer
;   +$0C .l  minimap tile mapping pointer
;   +$10 .l  background palette pointer
;   +$14 .l  sideline style pointer
;   +$18 .l  road style data pointer
;   +$1C .l  finish line style pointer
;   +$20 .w  Track_horizon_override_flag: 0 = default sky; 1 = special horizon colour patch
;            (only West Germany, Italy, Belgium have 1)
;   +$22 .w  track length in game distance units
;   +$24 .l  signs data pointer
;   +$28 .l  signs tileset pointer
;   +$2C .l  minimap position map pointer
;   +$30 .l  curve data pointer (RLE-encoded; decoded to Curve_data / Background_horizontal_displacement)
;   +$34 .l  visual slope data pointer (RLE-encoded; decoded to Visual_slope_data)
;   +$38 .l  physical slope data pointer (RLE-encoded; decoded to Physical_slope_data; drives RPM hill model)
;   +$3C .l  per-track BCD lap-time base pointer into Track_lap_time_records ($FFFFFD00 + 8 × track_index)
;   +$40 .l  per-lap target time table pointer (15 × 3-byte BCD records; loaded into Track_lap_target_buf)
;   +$44 .l  steering sensitivity divisors packed: high word = Steering_divisor_straight,
;            low word = Steering_divisor_curve (both .w; fed into DIVS in Update_horizontal_position)
;
; Load_track_data_pointer returns A1 → entry; Load_track_data reads all fields.
Track_data:
; San Marino
	dc.l	Minimap_tiles_San_Marino ; San Marino tiles used for minimap
	dc.l	Track_bg_tiles_San_Marino ; San Marino tiles used for background
	dc.l	Track_bg_tilemap_San_Marino ; San Marino background tile mapping
	dc.l	Minimap_map_San_Marino ; San Marino tile mapping for minimap
	dc.l	San_Marino_bg_palette ; San Marino background palette
	dc.l	San_Marino_sideline_style ; San Marino sideline style
	dc.l	San_Marino_road_style ; San Marino road style data
	dc.l	San_Marino_finish_line_style ; San Marino finish line style
	dc.w	$0000 ; horizon override flag (0 = default sky)
	dc.w	7040 ; track length
	dc.l	San_Marino_sign_data ; San Marino signs data
	dc.l	San_Marino_sign_tileset ; San Marino tileset for signs
	dc.l	San_Marino_minimap_pos ; San Marino map for minimap position
	dc.l	San_Marino_curve_data ; San Marino curve data
	dc.l	San_Marino_slope_data ; San Marino slope data (visual; decoded to Visual_slope_data)
	dc.l	San_Marino_phys_slope_data ; San Marino physical slope data (decoded to Physical_slope_data; hill RPM modifier)
	dc.l	Track_lap_time_records ; San Marino BCD lap-time record pointer (base = $FFFFFD00, +$08 per track)
	dc.l	San_Marino_lap_targets ; San Marino per-lap target time table (15 × 3-byte BCD entries)
	dc.l	$002B002B ; steering divisors: straight=$002B, curve=$002B (both 43)
; Brazil
	dc.l	Minimap_tiles_Brazil ; Brazil tiles used for minimap
	dc.l	Track_bg_tiles_Brazil ; Brazil tiles used for background
	dc.l	Track_bg_tilemap_Brazil ; Brazil background tile mapping
	dc.l	Minimap_map_Brazil ; Brazil tile mapping for minimap
	dc.l	Brazil_bg_palette ; Brazil background palette
	dc.l	Brazil_sideline_style ; Brazil sideline style
	dc.l	Brazil_road_style ; Brazil road style data
	dc.l	Brazil_finish_line_style ; Brazil finish line style
	dc.w	$0000 ; horizon override flag (0 = default sky)
	dc.w	6976 ; track length
	dc.l	Brazil_sign_data ; Brazil signs data
	dc.l	Brazil_sign_tileset ; Brazil tileset for signs
	dc.l	Brazil_minimap_pos ; Brazil map for minimap position
	dc.l	Brazil_curve_data ; Brazil curve data
	dc.l	Brazil_slope_data ; Brazil slope data (visual; decoded to Visual_slope_data)
	dc.l	Brazil_phys_slope_data ; Brazil physical slope data (decoded to Physical_slope_data; hill RPM modifier)
	dc.l	$FFFFFD08 ; Brazil BCD lap-time record pointer (Track_lap_time_records + $08)
	dc.l	Brazil_lap_targets ; Brazil per-lap target time table (15 × 3-byte BCD entries)
	dc.l	$002B002B ; steering divisors: straight=$002B, curve=$002B
; France
	dc.l	Minimap_tiles_France ; France tiles used for minimap
	dc.l	Track_bg_tiles_France ; France tiles used for background
	dc.l	Track_bg_tilemap_France ; France background tile mapping
	dc.l	Minimap_map_France ; France tile mapping for minimap
	dc.l	France_bg_palette ; France background palette
	dc.l	France_sideline_style ; France sideline style
	dc.l	France_road_style ; France road style data
	dc.l	France_finish_line_style ; France finish line style
	dc.w	$0000 ; horizon override flag (0 = default sky)
	dc.w	6144 ; track length
	dc.l	France_sign_data ; France signs data
	dc.l	France_sign_tileset ; France tileset for signs
	dc.l	France_minimap_pos ; France map for minimap position
	dc.l	France_curve_data ; France curve data
	dc.l	France_slope_data ; France slope data (visual; decoded to Visual_slope_data)
	dc.l	France_phys_slope_data ; France physical slope data (decoded to Physical_slope_data; hill RPM modifier)
	dc.l	$FFFFFD10 ; France BCD lap-time record pointer (Track_lap_time_records + $10)
	dc.l	France_lap_targets ; France per-lap target time table (15 × 3-byte BCD entries)
	dc.l	$002B002B ; steering divisors: straight=$002B, curve=$002B
; Hungary
	dc.l	Minimap_tiles_Hungary ; Hungary tiles used for minimap
	dc.l	Track_bg_tiles_Hungary ; Hungary tiles used for background
	dc.l	Track_bg_tilemap_Hungary ; Hungary background tile mapping
	dc.l	Minimap_map_Hungary ; Hungary tile mapping for minimap
	dc.l	Hungary_bg_palette ; Hungary background palette
	dc.l	Hungary_sideline_style ; Hungary sideline style
	dc.l	Hungary_road_style ; Hungary road style data
	dc.l	Hungary_finish_line_style ; Hungary finish line style
	dc.w	$0000 ; horizon override flag (0 = default sky)
	dc.w	6464 ; track length
	dc.l	Hungary_sign_data ; Hungary signs data
	dc.l	Hungary_sign_tileset ; Hungary tileset for signs
	dc.l	Hungary_minimap_pos ; Hungary map for minimap position
	dc.l	Hungary_curve_data ; Hungary curve data
	dc.l	Hungary_slope_data ; Hungary slope data (visual; decoded to Visual_slope_data)
	dc.l	Hungary_phys_slope_data ; Hungary physical slope data (decoded to Physical_slope_data; hill RPM modifier)
	dc.l	$FFFFFD18 ; Hungary BCD lap-time record pointer (Track_lap_time_records + $18)
	dc.l	Hungary_lap_targets ; Hungary per-lap target time table (15 × 3-byte BCD entries)
	dc.l	$002c002e ; steering divisors: straight=$002C, curve=$002E (slightly less sensitive on curves)
; West Germany
	dc.l	Minimap_tiles_West_Germany ; West Germany tiles used for minimap
	dc.l	Track_bg_tiles_West_Germany ; West Germany tiles used for background
	dc.l	Track_bg_tilemap_West_Germany ; West Germany background tile mapping
	dc.l	Minimap_map_West_Germany ; West Germany tile mapping for minimap
	dc.l	West_Germany_bg_palette ; West Germany background palette
	dc.l	West_Germany_sideline_style ; West Germany sideline style
	dc.l	West_Germany_road_style ; West Germany road style data
	dc.l	West_Germany_finish_line_style ; West Germany finish line style
	dc.w	$0001 ; horizon override flag (1 = special sky colour patch applied each frame)
	dc.w	7488 ; track length
	dc.l	West_Germany_sign_data ; West Germany signs data
	dc.l	West_Germany_sign_tileset ; West Germany tileset for signs
	dc.l	West_Germany_minimap_pos ; West Germany map for minimap position
	dc.l	West_Germany_curve_data ; West Germany curve data
	dc.l	West_Germany_slope_data ; West Germany slope data (visual; decoded to Visual_slope_data)
	dc.l	West_Germany_phys_slope_data ; West Germany physical slope data (decoded to Physical_slope_data; hill RPM modifier)
	dc.l	$FFFFFD20 ; West Germany BCD lap-time record pointer (Track_lap_time_records + $20)
	dc.l	West_Germany_lap_targets ; West Germany per-lap target time table (15 × 3-byte BCD entries)
	dc.l	$002B002B ; steering divisors: straight=$002B, curve=$002B
; USA
	dc.l	Minimap_tiles_USA ; USA tiles used for minimap
	dc.l	Track_bg_tiles_Usa ; USA tiles used for background
	dc.l	Track_bg_tilemap_Usa ; USA background tile mapping
	dc.l	Minimap_map_USA ; USA tile mapping for minimap
	dc.l	Usa_bg_palette ; USA background palette
	dc.l	Usa_sideline_style ; USA sideline style
	dc.l	Usa_road_style ; USA road style data
	dc.l	Usa_finish_line_style ; USA finish line style
	dc.w	$0000 ; horizon override flag (0 = default sky)
	dc.w	7168 ; track length
	dc.l	Usa_sign_data ; USA signs data
	dc.l	Usa_sign_tileset ; USA tileset for signs
	dc.l	Usa_minimap_pos ; USA map for minimap position
	dc.l	Usa_curve_data ; USA curve data
	dc.l	Usa_slope_data ; USA slope data (visual; decoded to Visual_slope_data)
	dc.l	Usa_phys_slope_data ; USA physical slope data (decoded to Physical_slope_data; hill RPM modifier)
	dc.l	$FFFFFD28 ; USA BCD lap-time record pointer (Track_lap_time_records + $28)
	dc.l	Canada_lap_targets ; USA per-lap target time table (15 × 3-byte BCD entries)
	dc.l	$002B002B ; steering divisors: straight=$002B, curve=$002B
; Canada
	dc.l	Minimap_tiles_Canada ; Canada tiles used for minimap
	dc.l	Track_bg_tiles_Canada ; Canada tiles used for background
	dc.l	Track_bg_tilemap_Canada ; Canada background tile mapping
	dc.l	Minimap_map_Canada ; Canada tile mapping for minimap
	dc.l	Canada_bg_palette ; Canada background palette
	dc.l	Canada_sideline_style ; Canada sideline style
	dc.l	Canada_road_style ; Canada road style data
	dc.l	Canada_finish_line_style ; Canada finish line style
	dc.w	$0000 ; horizon override flag (0 = default sky)
	dc.w	6720 ; track length
	dc.l	Canada_sign_data ; Canada signs data
	dc.l	Canada_sign_tileset ; Canada tileset for signs
	dc.l	Canada_minimap_pos ; Canada map for minimap position
	dc.l	Canada_curve_data ; Canada curve data
	dc.l	Canada_slope_data ; Canada slope data (visual; decoded to Visual_slope_data)
	dc.l	Canada_phys_slope_data ; Canada physical slope data (decoded to Physical_slope_data; hill RPM modifier)
	dc.l	$FFFFFD30 ; Canada BCD lap-time record pointer (Track_lap_time_records + $30)
	dc.l	Great_Britain_lap_targets; Canada per-lap target time table (15 × 3-byte BCD entries)
	dc.l	$002B002B ; steering divisors: straight=$002B, curve=$002B
; Great Britain
	dc.l	Minimap_tiles_Great_Britain  ; Great Britain tiles used for minimap
	dc.l	Track_bg_tiles_Great_Britain  ; Great Britain tiles used for background
	dc.l	Track_bg_tilemap_Great_Britain  ; Great Britain background tile mapping
	dc.l	Minimap_map_Great_Britain  ; Great Britain tile mapping for minimap
	dc.l	Great_Britain_bg_palette  ; Great Britain background palette
	dc.l	Great_Britain_sideline_style ; Great Britain sideline style
	dc.l	Great_Britain_road_style  ; Great Britain road style data
	dc.l	Great_Britain_finish_line_style  ; Great Britain finish line style
	dc.w	$0000 ; horizon override flag (0 = default sky)
	dc.w	6912 ; track length
	dc.l	Great_Britain_sign_data ; Great Britain signs data
	dc.l	Great_Britain_sign_tileset ; Great Britain tileset for signs
	dc.l	Great_Britain_minimap_pos ; Great Britain map for minimap position
	dc.l	Great_Britain_curve_data ; Great Britain curve data
	dc.l	Great_Britain_slope_data ; Great Britain slope data (visual; decoded to Visual_slope_data)
	dc.l	Great_Britain_phys_slope_data ; Great Britain physical slope data (decoded to Physical_slope_data; hill RPM modifier)
	dc.l	$FFFFFD38 ; Great Britain BCD lap-time record pointer (Track_lap_time_records + $38)
	dc.l	Italy_lap_targets; Great Britain per-lap target time table (15 × 3-byte BCD entries)
	dc.l	$002B002B ; steering divisors: straight=$002B, curve=$002B
; Italy
	dc.l	Minimap_tiles_Italy ; Italy tiles used for minimap
	dc.l	Track_bg_tiles_Italy ; Italy tiles used for background
	dc.l	Track_bg_tilemap_Italy ; Italy background tile mapping
	dc.l	Minimap_map_Italy ; Italy tile mapping for minimap
	dc.l	Italy_bg_palette-2 ; Italy background palette
	dc.l	Italy_sideline_style ; Italy sideline style
	dc.l	Italy_road_style ; Italy road style data
	dc.l	Italy_finish_line_style ; Italy finish line style
	dc.w	$0001 ; horizon override flag (1 = special sky colour patch applied each frame)
	dc.w	7616 ; track length
	dc.l	Italy_sign_data ; Italy signs data
	dc.l	Italy_sign_tileset ; Italy tileset for signs
	dc.l	Italy_minimap_pos ; Italy map for minimap position
	dc.l	Italy_curve_data ; Italy curve data
	dc.l	Italy_slope_data ; Italy slope data (visual; decoded to Visual_slope_data)
	dc.l	Italy_phys_slope_data ; Italy physical slope data (decoded to Physical_slope_data; hill RPM modifier)
	dc.l	$FFFFFD40 ; Italy BCD lap-time record pointer (Track_lap_time_records + $40)
	dc.l	Spain_lap_targets ; Italy per-lap target time table (15 × 3-byte BCD entries)
	dc.l	$002B002B ; steering divisors: straight=$002B, curve=$002B
; Portugal
	dc.l	Minimap_tiles_Portugal ; Portugal tiles used for minimap
	dc.l	Track_bg_tiles_Portugal ; Portugal tiles used for background
	dc.l	Track_bg_tilemap_Portugal ; Portugal background tile mapping
	dc.l	Minimap_map_Portugal ; Portugal tile mapping for minimap
	dc.l	Portugal_bg_palette ; Portugal background palette
	dc.l	Portugal_sideline_style ; Portugal sideline style
	dc.l	Portugal_road_style ; Portugal road style data
	dc.l	Portugal_finish_line_style ; Portugal finish line style
	dc.w	$0000 ; horizon override flag (0 = default sky)
	dc.w	6592 ; track length
	dc.l	Portugal_sign_data ; Portugal signs data
	dc.l	Portugal_sign_tileset ; Portugal tileset for signs
	dc.l	Portugal_minimap_pos ; Portugal map for minimap position
	dc.l	Portugal_curve_data ; Portugal curve data
	dc.l	Portugal_slope_data ; Portugal slope data (visual; decoded to Visual_slope_data)
	dc.l	Portugal_phys_slope_data ; Portugal physical slope data (decoded to Physical_slope_data; hill RPM modifier)
	dc.l	$FFFFFD48 ; Portugal BCD lap-time record pointer (Track_lap_time_records + $48)
	dc.l	Mexico_lap_targets ; Portugal per-lap target time table (15 × 3-byte BCD entries)
	dc.l	$002B002B ; steering divisors: straight=$002B, curve=$002B
; Spain
	dc.l	Minimap_tiles_Spain ; Spain tiles used for minimap
	dc.l	Track_bg_tiles_Spain ; Spain tiles used for background
	dc.l	Track_bg_tilemap_Spain ; Spain background tile mapping
	dc.l	Minimap_map_Spain ; Spain tile mapping for minimap
	dc.l	Spain_bg_palette ; Spain background palette
	dc.l	Spain_sideline_style ; Spain sideline style
	dc.l	Spain_road_style ; Spain road style data
	dc.l	Spain_finish_line_style ; Spain finish line style
	dc.w	$0000 ; horizon override flag (0 = default sky)
	dc.w	6784 ; track length
	dc.l	Spain_sign_data ; Spain signs data
	dc.l	Spain_sign_tileset ; Spain tileset for signs
	dc.l	Spain_minimap_pos ; Spain map for minimap position
	dc.l	Spain_curve_data ; Spain curve data
	dc.l	Spain_slope_data ; Spain slope data (visual; decoded to Visual_slope_data)
	dc.l	Spain_phys_slope_data ; Spain physical slope data (decoded to Physical_slope_data; hill RPM modifier)
	dc.l	$FFFFFD50 ; Spain BCD lap-time record pointer (Track_lap_time_records + $50)
	dc.l	Japan_lap_targets ; Spain per-lap target time table (15 × 3-byte BCD entries)
	dc.l	$002B002B ; steering divisors: straight=$002B, curve=$002B
; Mexico
	dc.l	Minimap_tiles_Mexico ; Mexico tiles used for minimap
	dc.l	Track_bg_tiles_Mexico ; Mexico tiles used for background
	dc.l	Track_bg_tilemap_Mexico ; Mexico background tile mapping
	dc.l	Minimap_map_Mexico ; Mexico tile mapping for minimap
	dc.l	Mexico_bg_palette ; Mexico background palette
	dc.l	Mexico_sideline_style ; Mexico sideline style
	dc.l	Mexico_road_style ; Mexico road style data
	dc.l	Mexico_finish_line_style ; Mexico finish line style
	dc.w	$0000 ; horizon override flag (0 = default sky)
	dc.w	6848 ; track length
	dc.l	Mexico_sign_data ; Mexico signs data
	dc.l	Mexico_sign_tileset ; Mexico tileset for signs
	dc.l	Mexico_minimap_pos ; Mexico map for minimap position
	dc.l	Mexico_curve_data ; Mexico curve data
	dc.l	Mexico_slope_data ; Mexico slope data (visual; decoded to Visual_slope_data)
	dc.l	Mexico_phys_slope_data ; Mexico physical slope data (decoded to Physical_slope_data; hill RPM modifier)
	dc.l	$FFFFFD58 ; Mexico BCD lap-time record pointer (Track_lap_time_records + $58)
	dc.l	Australia_lap_targets ; Mexico per-lap target time table (15 × 3-byte BCD entries)
	dc.l	$002B002B ; steering divisors: straight=$002B, curve=$002B
; Japan
	dc.l	Minimap_tiles_Japan ; Japan tiles used for minimap
	dc.l	Track_bg_tiles_Japan ; Japan tiles used for background
	dc.l	Track_bg_tilemap_Japan ; Japan background tile mapping
	dc.l	Minimap_map_Japan ; Japan tile mapping for minimap
	dc.l	Japan_bg_palette ; Japan background palette
	dc.l	Japan_sideline_style ; Japan sideline style
	dc.l	Japan_road_style ; Japan road style data
	dc.l	Japan_finish_line_style ; Japan finish line style
	dc.w	$0000 ; horizon override flag (0 = default sky)
	dc.w	7552 ; track length
	dc.l	Japan_sign_data ; Japan signs data
	dc.l	Japan_sign_tileset ; Japan tileset for signs
	dc.l	Japan_minimap_pos ; Japan map for minimap position
	dc.l	Japan_curve_data ; Japan curve data
	dc.l	Japan_slope_data ; Japan slope data (visual; decoded to Visual_slope_data)
	dc.l	Japan_phys_slope_data ; Japan physical slope data (decoded to Physical_slope_data; hill RPM modifier)
	dc.l	$FFFFFD60 ; Japan BCD lap-time record pointer (Track_lap_time_records + $60)
	dc.l	Portugal_lap_targets ; Japan per-lap target time table (15 × 3-byte BCD entries)
	dc.l	$002B002B ; steering divisors: straight=$002B, curve=$002B
; Belgium
	dc.l	Minimap_tiles_Belgium ; Belgium tiles used for minimap
	dc.l	Track_bg_tiles_Belgium ; Belgium tiles used for background
	dc.l	Track_bg_tilemap_Belgium ; Belgium background tile mapping
	dc.l	Minimap_map_Belgium ; Belgium tile mapping for minimap
	dc.l	Belgium_bg_palette ; Belgium background palette
	dc.l	Belgium_sideline_style ; Belgium sideline style
	dc.l	Belgium_road_style ; Belgium road style data
	dc.l	Belgium_finish_line_style ; Belgium finish line style
	dc.w	$0001 ; horizon override flag (1 = special sky colour patch applied each frame)
	dc.w	7744 ; track length
	dc.l	Belgium_sign_data ; Belgium signs data
	dc.l	Belgium_sign_tileset ; Belgium tileset for signs
	dc.l	Belgium_minimap_pos ; Belgium map for minimap position
	dc.l	Belgium_curve_data ; Belgium curve data
	dc.l	Belgium_slope_data ; Belgium slope data (visual; decoded to Visual_slope_data)
	dc.l	Belgium_phys_slope_data ; Belgium physical slope data (decoded to Physical_slope_data; hill RPM modifier)
	dc.l	$FFFFFD68 ; Belgium BCD lap-time record pointer (Track_lap_time_records + $68)
	dc.l	Belgium_lap_targets ; Belgium per-lap target time table (15 × 3-byte BCD entries)
	dc.l	$002B002B ; steering divisors: straight=$002B, curve=$002B
; Australia
	dc.l	Minimap_tiles_Australia ; Australia tiles used for minimap
	dc.l	Track_bg_tiles_Australia ; Australia tiles used for background
	dc.l	Track_bg_tilemap_Australia ; Australia background tile mapping
	dc.l	Minimap_map_Australia ; Australia tile mapping for minimap
	dc.l	Australia_bg_palette ; Australia background palette
	dc.l	Australia_sideline_style ; Australia sideline style
	dc.l	Australia_road_style ; Australia road style data
	dc.l	Australia_finish_line_style ; Australia finish line style
	dc.w	$0000 ; horizon override flag (0 = default sky)
	dc.w	6080 ; track length
	dc.l	Australia_sign_data ; Australia signs data
	dc.l	Australia_sign_tileset ; Australia tileset for signs
	dc.l	Australia_minimap_pos ; Australia map for minimap position
	dc.l	Australia_curve_data ; Australia curve data
	dc.l	Australia_slope_data ; Australia slope data (visual; decoded to Visual_slope_data)
	dc.l	Australia_phys_slope_data ; Australia physical slope data (decoded to Physical_slope_data; hill RPM modifier)
	dc.l	$FFFFFD70 ; Australia BCD lap-time record pointer (Track_lap_time_records + $70)
	dc.l	Usa_lap_targets ; Australia per-lap target time table (15 × 3-byte BCD entries)
	dc.l	$002B002B ; steering divisors: straight=$002B, curve=$002B
; Monaco
	dc.l	Minimap_tiles_Monaco ; Monaco tiles used for minimap
	dc.l	Track_bg_tiles_Monaco ; Monaco tiles used for background
	dc.l	Track_bg_tilemap_Monaco ; Monaco background tile mapping
	dc.l	Minimap_map_Monaco ; Monaco tile mapping for minimap
	dc.l	Monaco_bg_palette ; Monaco background palette
	dc.l	Monaco_sideline_style ; Monaco sideline style
	dc.l	Monaco_road_style ; Monaco road style data
	dc.l	Monaco_finish_line_style ; Monaco finish line style
	dc.w	$0000 ; horizon override flag (0 = default sky)
	dc.w	6144 ; track length
	dc.l	Monaco_sign_data ; Monaco signs data
	dc.l	Monaco_sign_tileset ; Monaco tileset for signs
	dc.l	Monaco_minimap_pos ; Monaco map for minimap position
	dc.l	Monaco_curve_data ; Monaco curve data
	dc.l	Monaco_slope_data ; Monaco slope data (visual; decoded to Visual_slope_data)
	dc.l	Monaco_phys_slope_data ; Monaco physical slope data (decoded to Physical_slope_data; hill RPM modifier)
	dc.l	$FFFFFD78 ; Monaco BCD lap-time record pointer (Track_lap_time_records + $78)
	dc.l	Monaco_lap_targets ; Monaco per-lap target time table (15 × 3-byte BCD entries)
	dc.l	$002B002B ; steering divisors: straight=$002B, curve=$002B
; Monaco (Arcade preliminary)
	dc.l	Minimap_tiles_Monaco_prelim ; Monaco (Arcade preliminary) tiles used for minimap
	dc.l	Track_bg_tiles_Monaco_arcade ; Monaco (Arcade preliminary) tiles used for background
	dc.l	Track_bg_tilemap_Monaco_arcade ; Monaco (Arcade preliminary) background tile mapping
	dc.l	Minimap_map_Monaco_prelim ; Monaco (Arcade preliminary) tile mapping for minimap
	dc.l	Monaco_arcade_bg_palette ; Monaco (Arcade preliminary) background palette
	dc.l	Monaco_arcade_sideline_style-2 ; Monaco (Arcade preliminary) sideline style
	dc.l	Monaco_arcade_road_style ; Monaco (Arcade preliminary) road style data
	dc.l	Monaco_arcade_finish_line_style ; Monaco (Arcade preliminary) finish line style
	dc.w	$0000 ; horizon override flag (0 = default sky)
	dc.w	3392 ; track length
	dc.l	Monaco_arcade_prelim_sign_data ; Monaco (Arcade preliminary) signs data
	dc.l	Monaco_arcade_prelim_sign_tileset ; Monaco (Arcade preliminary) tileset for signs
	dc.l	Monaco_arcade_prelim_minimap_pos ; Monaco (Arcade preliminary) map for minimap position
	dc.l	Monaco_arcade_prelim_curve_data ; Monaco (Arcade preliminary) curve data
	dc.l	Monaco_arcade_prelim_slope_data ; Monaco (Arcade preliminary) slope data (visual; decoded to Visual_slope_data)
	dc.l	Monaco_arcade_prelim_phys_slope_data ; Monaco (Arcade preliminary) physical slope data (decoded to Physical_slope_data)
	dc.l	$FFFFFD80 ; Monaco (Arcade preliminary) BCD lap-time record pointer (Track_lap_time_records + $80)
	dc.l	Monaco_arcade_lap_targets ; Monaco (Arcade preliminary) per-lap target time table (15 × 3-byte BCD entries)
	dc.l	$002B002B ; steering divisors: straight=$002B, curve=$002B
; Monaco (Arcade main)
	dc.l	Minimap_tiles_Monaco_arcade ; Monaco (Arcade main) tiles used for minimap
	dc.l	Track_bg_tiles_Monaco_arcade ; Monaco (Arcade main) tiles used for background
	dc.l	Track_bg_tilemap_Monaco_arcade ; Monaco (Arcade main) background tile mapping
	dc.l	Minimap_map_Monaco_arcade ; Monaco (Arcade main) tile mapping for minimap
	dc.l	Monaco_arcade_bg_palette  ; Monaco (Arcade main) background palette
	dc.l	Monaco_arcade_sideline_style-2 ; Monaco (Arcade main) sideline style
	dc.l	Monaco_arcade_road_style ; Monaco (Arcade main) road style data
	dc.l	Monaco_arcade_finish_line_style ; Monaco (Arcade main) finish line style
	dc.w	$0000 ; horizon override flag (0 = default sky)
	dc.w	7616 ; track length
	dc.l	Monaco_arcade_sign_data ; Monaco (Arcade main) signs data
	dc.l	Monaco_arcade_sign_tileset ; Monaco (Arcade main) tileset for signs
	dc.l	Monaco_arcade_minimap_pos  ; Monaco (Arcade main) map for minimap position
	dc.l	Monaco_arcade_curve_data ; Monaco (Arcade main) curve data
	dc.l	Monaco_arcade_slope_data ; Monaco (Arcade main) slope data (visual; decoded to Visual_slope_data)
	dc.l	Monaco_arcade_phys_slope_data ; Monaco (Arcade main) physical slope data (decoded to Physical_slope_data)
	dc.l	$FFFFFD88 ; Monaco (Arcade main) BCD lap-time record pointer (Track_lap_time_records + $88)
	dc.l	Monaco_arcade_lap_targets ; Monaco (Arcade main) per-lap target time table (15 × 3-byte BCD entries)
	dc.l	$002B002B ; steering divisors: straight=$002B, curve=$002B
; Monaco (Arcade Wet Condition)
	dc.l	Minimap_tiles_Monaco_arcade ; Monaco (Arcade Wet Condition) tiles used for minimap
	dc.l	Track_bg_tiles_Monaco_arcade ; Monaco (Arcade Wet Condition) tiles used for background
	dc.l	Track_bg_tilemap_Monaco_arcade_wet ; Monaco (Arcade Wet Condition) background tile mapping
	dc.l	Minimap_map_Monaco_arcade ; Monaco (Arcade Wet Condition) tile mapping for minimap
	dc.l	Monaco_arcade_wet_bg_palette ; Monaco (Arcade Wet Condition) background palette
	dc.l	Monaco_arcade_wet_sideline_style ; Monaco (Arcade Wet Condition) sideline style
	dc.l	Monaco_arcade_wet_road_style ; Monaco (Arcade Wet Condition) road style data
	dc.l	Monaco_arcade_wet_finish_line_style ; Monaco (Arcade Wet Condition) finish line style
	dc.w	$0000 ; horizon override flag (0 = default sky)
	dc.w	7616 ; track length
	dc.l	Monaco_arcade_sign_data ; Monaco (Arcade Wet Condition) signs data
	dc.l	Monaco_arcade_sign_tileset  ; Monaco (Arcade Wet Condition) tileset for signs
	dc.l	Monaco_arcade_minimap_pos ; Monaco (Arcade Wet Condition) map for minimap position
	dc.l	Monaco_arcade_curve_data ; Monaco (Arcade Wet Condition) curve data
	dc.l	Monaco_arcade_slope_data ; Monaco (Arcade Wet Condition) slope data (visual; decoded to Visual_slope_data)
	dc.l	Monaco_arcade_phys_slope_data ; Monaco (Arcade Wet Condition) physical slope data (decoded to Physical_slope_data)
	dc.l	$FFFFFD88 ; Monaco (Arcade Wet Condition) BCD lap-time record pointer (shares Monaco Arcade main)
	dc.l	Monaco_arcade_lap_targets ; Monaco (Arcade Wet Condition) per-lap target time table (15 × 3-byte BCD entries)
	dc.l	$002f0038 ; steering divisors: straight=$002F (47), curve=$0038 (56) — wet tyres, reduced sensitivity
;Track_sky_palette_ptr
Track_sky_palette_ptr:
	dc.l	$0A1014F0
;San_Marino_bg_palette
San_Marino_bg_palette:
	dc.w	$0EC8, $0CCA, $0A86, $0664, $0242, $0244, $0488, $06AA, $08CC, $026A, $0000
;Monaco_bg_palette
Monaco_bg_palette:
	dc.w	$0EEA, $0EEE, $0CCC, $0888, $0EC8, $0EA6, $048A, $08AA, $02A8, $0286, $0464
;Mexico_bg_palette
Mexico_bg_palette:
	dc.w	$0CC8, $06AC, $046C, $0264, $0A86, $0888, $0CCC, $0EEE, $0CCA, $0468, $0244
;France_bg_palette
France_bg_palette:
	dc.w	$0EC8, $0CCA, $0ACC, $0AAA, $0664, $0486, $0CA8, $0CEE, $046A, $0886, $0ECA
;Great_Britain_bg_palette
Great_Britain_bg_palette:
	dc.w	$0CCA, $0464, $0486, $0442, $0664, $0264, $0688, $0488, $0888, $0AAA, $0246
;West_Germany_bg_palette
West_Germany_bg_palette:
	dc.w	$0EC6, $0442, $0264, $0664, $0686, $0CA6, $0EC8, $0266, $0ECA, $0086, $0000
;Hungary_bg_palette
Hungary_bg_palette:
	dc.w	$0EC8, $08CE, $0ECA, $0664, $0AA8, $0288, $06AA, $0466, $0CEE, $0264, $0242
;Belgium_bg_palette
Belgium_bg_palette:
	dc.w	$0EE6, $0EEA, $0664, $0886, $0AA8, $0466, $0688, $0286, $0444, $0EE8, $0000
;Portugal_bg_palette
Portugal_bg_palette:
	dc.w	$0ECA, $0ECC, $06AC, $0886, $0000, $0888, $0CCC, $0244, $0288, $0AAA, $066C
;Spain_bg_palette
Spain_bg_palette:
	dc.w	$0EE8, $0EEC, $06AC, $0EEA, $0044, $0466, $048A, $08CE, $0066, $0888, $0688
;Australia_bg_palette
Australia_bg_palette:
	dc.w	$0EC6, $0CC8, $0CCA, $0486, $0CCC, $0888, $0666, $0444, $0AAA, $0864, $066C
;Usa_bg_palette
Usa_bg_palette:
	dc.w	$0EE4, $0EE8, $0EEA, $0486, $0EEE, $0888, $0666, $0444, $0AAA, $0ACC, $068A
;Japan_bg_palette
Japan_bg_palette:
	dc.w	$0CA8, $0264, $0688, $0442, $0864, $0666, $0AAA, $0CCC, $0CAA, $0286, $0888
;Canada_bg_palette
Canada_bg_palette:
	dc.w	$0ECA, $0666, $0286, $0EAA, $0AAA, $0CCA, $0CCC, $0888, $068A, $0644
	dc.l	$02660EEA
;Italy_bg_palette
Italy_bg_palette:
	dc.b	$06
	dc.b	$64
	dc.b	$02, $86
	dc.w	$0A86
	dc.w	$0AA6
	dc.l	$0AAA0CCC
	dc.l	$066C0ACC
	dc.w	$0888
	dc.w	$0EEC
;Brazil_bg_palette
Brazil_bg_palette:
	dc.w	$0EC8
	dc.b	$0E
	dc.b	$CA
	dc.w	$0CA8
	dc.w	$0A86
	dc.b	$06, $64, $06, $86
	dc.w	$0242
	dc.w	$0888
	dc.w	$0AAA
	dc.l	$0CCC0EEE
;Monaco_arcade_bg_palette
Monaco_arcade_bg_palette:
	dc.w	$0EEA
	dc.w	$0EEE
	dc.b	$0C, $CC, $08
	dc.b	$88
	dc.b	$0E, $C8, $0E, $A6, $04
	dc.b	$8A
	dc.b	$08
	dc.b	$AA
	dc.b	$02
	dc.b	$A8
	dc.b	$02
	dc.b	$86
	dc.b	$04, $64
;Monaco_arcade_wet_bg_palette
Monaco_arcade_wet_bg_palette:
	dc.w	$0A88, $0CCC
	dc.w	$0888
	dc.b	$04
	dc.b	$44
	dc.w	$0A66
	dc.w	$0844
	dc.w	$0246
	dc.b	$04, $66, $02, $64
	dc.w	$0042
	dc.l	$002000A0
;Monaco_arcade_sideline_style
Monaco_arcade_sideline_style:
	dc.w	$0E00
	dc.w	$0EEE
	dc.b	$06, $66, $06, $66
;Monaco_arcade_road_style
Monaco_arcade_road_style:
	dc.w	$0080, $0EEE, $0EEE, $0EEE, $0666
;Monaco_arcade_finish_line_style
Monaco_arcade_finish_line_style:
	dc.w	$0080, $0EEE, $0EEE, $0CCC, $0CCC
;Monaco_arcade_wet_sideline_style
Monaco_arcade_wet_sideline_style:
	dc.w	$0080, $0C00, $0CCC, $0444, $0444
;Monaco_arcade_wet_road_style
Monaco_arcade_wet_road_style:
	dc.w	$0060, $0CCC, $0CCC, $0CCC, $0444
;Monaco_arcade_wet_finish_line_style
Monaco_arcade_wet_finish_line_style:
	dc.w	$0060, $0CCC, $0CCC, $0AAA, $0AAA
;San_Marino_sideline_style
San_Marino_sideline_style:
	dc.w	$02A0, $022C, $0EEE, $0666, $0666
;San_Marino_road_style
San_Marino_road_style:
	dc.w	$0480, $0EEE, $0EEE, $0EEE, $0666
;San_Marino_finish_line_style
San_Marino_finish_line_style:
	dc.w	$0480, $0EEE, $0EEE, $0CCC, $0CCC
;Brazil_sideline_style
Brazil_sideline_style:
	dc.w	$04A4, $022C, $0EEE, $0666, $0666
;Brazil_road_style
Brazil_road_style:
	dc.w	$0282, $0EEE, $0EEE, $0466, $0466
;Brazil_finish_line_style
Brazil_finish_line_style:
	dc.w	$0282, $0EEE, $0EEE, $0CCC, $0CCC
;France_sideline_style
France_sideline_style:
	dc.w	$02A2, $0E00, $0EEE, $0888, $0888
;France_road_style
France_road_style:
	dc.w	$0484, $0EEE, $0EEE, $0EEE, $0888
;France_finish_line_style
France_finish_line_style:
	dc.w	$0484, $0EEE, $0EEE, $0CCC, $0CCC
;Hungary_sideline_style
Hungary_sideline_style:
	dc.w	$00A8, $022C, $0EEE, $0466, $0466
;Hungary_road_style
Hungary_road_style:
	dc.w	$0086, $0EEE, $0EEE, $0666, $0666
;Hungary_finish_line_style
Hungary_finish_line_style:
	dc.w	$0086, $0EEE, $0EEE, $0CCC, $0CCC
;West_Germany_sideline_style
West_Germany_sideline_style:
	dc.w	$00A2, $0E00, $0EEE, $0666, $0666
;West_Germany_road_style
West_Germany_road_style:
	dc.w	$0482, $0EEE, $0EEE, $0EEE, $0666
;West_Germany_finish_line_style
West_Germany_finish_line_style:
	dc.w	$0482, $0EEE, $0EEE, $0CCC, $0CCC
;Usa_sideline_style
Usa_sideline_style:
	dc.w	$08AA, $044C, $0EEE, $0666, $0666
;Usa_road_style
Usa_road_style:
	dc.w	$0888, $0EEE, $0EEE, $0EEE, $0666
;Usa_finish_line_style
Usa_finish_line_style:
	dc.w	$0888, $0EEE, $0EEE, $0CCC, $0CCC
;Canada_sideline_style
Canada_sideline_style:
	dc.w	$02A0, $022C, $0EEE, $0888, $0888
;Canada_road_style
Canada_road_style:
	dc.w	$0280, $0EEE, $0EEE, $0888, $0888
;Canada_finish_line_style
Canada_finish_line_style:
	dc.w	$0280, $0EEE, $0EEE, $0CCC, $0CCC
;Great_Britain_sideline_style
Great_Britain_sideline_style:
	dc.w	$00A0, $0222, $0EEE, $0666, $0666
;Great_Britain_road_style
Great_Britain_road_style:
	dc.w	$0480, $0EEE, $0EEE, $0EEE, $0666
;Great_Britain_finish_line_style
Great_Britain_finish_line_style:
	dc.w	$0480, $0EEE, $0EEE, $0CCC, $0CCC
;Italy_sideline_style
Italy_sideline_style:
	dc.w	$02A0, $022C, $0EEE, $0666, $0666
;Italy_road_style
Italy_road_style:
	dc.w	$0480, $0EEE, $0EEE, $0EEE, $0666
;Italy_finish_line_style
Italy_finish_line_style:
	dc.w	$0480, $0EEE, $0EEE, $0CCC, $0CCC
;Portugal_sideline_style
Portugal_sideline_style:
	dc.w	$02AA, $022A, $0EEE, $0688, $0688
;Portugal_road_style
Portugal_road_style:
	dc.w	$06AC, $0EEE, $0EEE, $0EEE, $0688
;Portugal_finish_line_style
Portugal_finish_line_style:
	dc.w	$06AC, $0EEE, $0EEE, $0CCC, $0CCC
;Spain_sideline_style
Spain_sideline_style:
	dc.w	$04AA, $0C22, $0EEE, $0888, $0888
;Spain_road_style
Spain_road_style:
	dc.w	$0488, $0EEE, $0EEE, $0EEE, $0888
;Spain_finish_line_style
Spain_finish_line_style:
	dc.w	$0488, $0EEE, $0EEE, $0CCC, $0CCC
;Mexico_sideline_style
Mexico_sideline_style:
	dc.w	$00A8, $024E, $0EEE, $0888, $0888
;Mexico_road_style
Mexico_road_style:
	dc.w	$0288, $0EEE, $0EEE, $0688, $0688
;Mexico_finish_line_style
Mexico_finish_line_style:
	dc.w	$0288, $0EEE, $0EEE, $0CCC, $0CCC
;Japan_sideline_style
Japan_sideline_style:
	dc.w	$0086, $022C, $0EEE, $0666, $0666
;Japan_road_style
Japan_road_style:
	dc.w	$0284, $0EEE, $0EEE, $0666, $0666
;Japan_finish_line_style
Japan_finish_line_style:
	dc.w	$0284, $0EEE, $0EEE, $0CCC, $0CCC
;Belgium_sideline_style
Belgium_sideline_style:
	dc.w	$04A2, $022C, $0EEE, $0666, $0666
;Belgium_road_style
Belgium_road_style:
	dc.w	$0480, $0EEE, $0EEE, $0EEE, $0666
;Belgium_finish_line_style
Belgium_finish_line_style:
	dc.w	$0480, $0EEE, $0EEE, $0CCC, $0CCC
;Australia_sideline_style
Australia_sideline_style:
	dc.w	$00A2, $0C22, $0EEE, $0666, $0666
;Australia_road_style
Australia_road_style:
	dc.w	$0280, $0EEE, $0EEE, $0EEE, $0666
;Australia_finish_line_style
Australia_finish_line_style:
	dc.w	$0280, $0EEE, $0EEE, $0CCC, $0CCC
;Monaco_sideline_style
Monaco_sideline_style:
	dc.w	$00A0, $022A, $0EEE, $0888, $0888
;Monaco_road_style
Monaco_road_style:
	dc.w	$0480, $0EEE, $0EEE, $0EEE, $0888
;Monaco_finish_line_style
Monaco_finish_line_style:
	dc.w	$0480, $0EEE, $0EEE, $0CCC, $0CCC
;San_Marino_lap_targets
San_Marino_lap_targets:
	dc.b	$00, $47, $50, $00, $47, $65, $00, $47, $86, $00, $48, $55, $00, $49, $75, $00, $50, $51, $00, $52, $36, $00, $53, $12, $00, $54, $23, $00, $55, $45, $00, $56
	dc.b	$28, $00, $57, $11, $00, $57, $82, $00, $59, $55, $99, $00, $00
	dc.b	$00
;Brazil_lap_targets
Brazil_lap_targets:
	dc.b	$00, $47, $93, $00, $48, $10, $00, $48, $32, $00, $49, $01, $00, $50, $22, $00, $51, $84, $00, $53, $62, $00, $54, $74, $00, $55, $97, $00, $57, $31, $00, $59
	dc.b	$14, $01, $01, $02, $01, $02, $88, $01, $04, $75, $99, $00, $00
	dc.b	$00
;France_lap_targets
France_lap_targets:
	dc.b	$00, $41, $15, $00, $41, $28, $00, $41, $47, $00, $41, $76, $00, $42, $97, $00, $44, $03, $00, $45, $20, $00, $46, $11, $00, $47, $09, $00, $48, $48, $00, $49
	dc.b	$32, $00, $50, $25, $00, $51, $42, $00, $53, $25, $99, $00, $00
	dc.b	$00
;Hungary_lap_targets
Hungary_lap_targets:
	dc.b	$00, $45, $55, $00, $45, $69, $00, $45, $90, $00, $46, $57, $00, $47, $72, $00, $48, $91, $00, $50, $04, $00, $51, $29, $00, $52, $22, $00, $52, $87, $00, $54
	dc.b	$36, $00, $54, $67, $00, $55, $79, $00, $58, $00, $99, $00, $00
	dc.b	$00
;West_Germany_lap_targets
West_Germany_lap_targets:
	dc.b	$00, $50, $75, $00, $50, $91, $00, $51, $13, $00, $51, $62, $00, $52, $50, $00, $53, $55, $00, $54, $71, $00, $55, $84, $00, $56, $97, $00, $58, $02, $00, $59
	dc.b	$14, $01, $00, $25, $01, $01, $38, $01, $02, $40, $99, $00, $00
	dc.b	$00
;Canada_lap_targets
Canada_lap_targets:
	dc.b	$00, $48, $90, $00, $49, $06, $00, $49, $27, $00, $49, $61, $00, $50, $71, $00, $51, $77, $00, $52, $86, $00, $53, $97, $00, $55, $16, $00, $56, $33, $00, $57
	dc.b	$24, $00, $58, $22, $01, $00, $36, $01, $02, $65, $99, $00, $00
	dc.b	$00
;Great_Britain_lap_targets
Great_Britain_lap_targets:
	dc.b	$00, $45, $90, $00, $46, $04, $00, $46, $25, $00, $46, $59, $00, $47, $62, $00, $48, $92, $00, $49, $84, $00, $51, $08, $00, $52, $21, $00, $53, $43, $00, $54
	dc.b	$62, $00, $55, $76, $00, $57, $47, $00, $59, $45, $99, $00, $00
	dc.b	$00
;Italy_lap_targets
Italy_lap_targets:
	dc.b	$00, $47, $45, $00, $47, $60, $00, $47, $81, $00, $48, $14, $00, $48, $64, $00, $48, $86, $00, $49, $21, $00, $49, $69, $00, $50, $25, $00, $50, $64, $00, $52
	dc.b	$31, $00, $53, $07, $00, $54, $18, $00, $55, $25, $99, $00, $00
	dc.b	$00
;Spain_lap_targets
Spain_lap_targets:
	dc.b	$00, $51, $35, $00, $51, $51, $00, $51, $74, $00, $52, $09, $00, $52, $83, $00, $53, $24, $00, $53, $76, $00, $54, $78, $00, $55, $87, $00, $57, $01, $00, $57
	dc.b	$74, $00, $58, $56, $00, $59, $86, $01, $01, $00, $99, $00, $00
	dc.b	$00
;Mexico_lap_targets
Mexico_lap_targets:
	dc.b	$00, $44, $80, $00, $44, $94, $00, $45, $14, $00, $45, $80, $00, $46, $50, $00, $47, $70, $00, $48, $81, $00, $49, $85, $00, $51, $16, $00, $52, $23, $00, $53
	dc.b	$75, $00, $55, $47, $00, $57, $36, $00, $59, $40, $99, $00, $00
	dc.b	$00
;Japan_lap_targets
Japan_lap_targets:
	dc.b	$00, $47, $45, $00, $47, $60, $00, $47, $81, $00, $48, $50, $00, $49, $69, $00, $50, $80, $00, $52, $11, $00, $53, $73, $00, $54, $94, $00, $57, $28, $00, $59
	dc.b	$31, $01, $01, $10, $01, $03, $02, $01, $04, $95, $99, $00, $00
	dc.b	$00
;Australia_lap_targets
Australia_lap_targets:
	dc.b	$00, $46, $20, $00, $46, $36, $00, $46, $55, $00, $46, $87, $00, $47, $58, $00, $48, $69, $00, $49, $76, $00, $50, $92, $00, $52, $05, $00, $53, $19, $00, $54
	dc.b	$23, $00, $55, $41, $00, $56, $19, $00, $57, $30, $99, $00, $00
	dc.b	$00
;Portugal_lap_targets
Portugal_lap_targets:
	dc.b	$00, $52, $95, $00, $53, $11, $00, $53, $35, $00, $53, $74, $00, $54, $86, $00, $55, $71, $00, $56, $92, $00, $58, $50, $01, $00, $61, $01, $02, $90, $01, $05
	dc.b	$25, $01, $07, $18, $01, $09, $42, $01, $11, $60, $99, $00, $00
	dc.b	$00
;Belgium_lap_targets
Belgium_lap_targets:
	dc.b	$00, $52, $80, $00, $52, $96, $00, $53, $20, $00, $53, $58, $00, $53, $96, $00, $55, $27, $00, $55, $93, $00, $57, $03, $00, $58, $97, $01, $00, $20, $01, $01
	dc.b	$54, $01, $03, $63, $01, $05, $77, $01, $09, $00, $99, $00, $00
	dc.b	$00
;Usa_lap_targets
Usa_lap_targets:
	dc.b	$00, $41, $50, $00, $41, $66, $00, $41, $83, $00, $42, $51, $00, $43, $66, $00, $44, $73, $00, $45, $94, $00, $47, $13, $00, $48, $20, $00, $49, $49, $00, $50
	dc.b	$54, $00, $52, $57, $00, $54, $62, $00, $56, $65, $99, $00, $00
	dc.b	$00
;Monaco_lap_targets
Monaco_lap_targets:
	dc.b	$00, $45, $20, $00, $45, $36, $00, $45, $55, $00, $46, $71, $00, $47, $89, $00, $48, $92, $00, $50, $08, $00, $51, $22, $00, $52, $39, $00, $53, $58, $00, $55
	dc.b	$86, $00, $58, $05, $01, $00, $16, $01, $02, $35, $99, $00, $00
	dc.b	$00
;Monaco_arcade_lap_targets
Monaco_arcade_lap_targets:
	dc.b	$00, $32, $00, $00, $32, $18, $00, $32, $43, $00, $32, $70, $00, $32, $85, $00, $33, $46, $00, $33, $73, $00, $34, $16, $00, $34, $75, $00, $35, $42, $00, $35
	dc.b	$91, $00, $36, $72, $00, $38, $88, $00, $40, $41, $99, $00, $00
	dc.b	$00
