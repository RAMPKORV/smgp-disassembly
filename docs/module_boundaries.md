# Super Monaco GP — Module Boundaries

Reference document for contributors describing module ownership, ROM address
ranges, inter-module call boundaries, and the rationale for each split.

Task: ARCH-006.  Prerequisites: ARCH-003, ARCH-004.

---

## Table of Contents

1. [Build structure](#1-build-structure)
2. [Top-level files](#2-top-level-files)
3. [Code modules (src/)](#3-code-modules-src)
4. [Data modules (src/)](#4-data-modules-src)
5. [Constants files](#5-constants-files)
6. [Inter-module call graph](#6-inter-module-call-graph)
7. [Data flow summary](#7-data-flow-summary)
8. [Ownership rules](#8-ownership-rules)

---

## 1. Build structure

`smgp.asm` is a 15-line include hub that assembles the entire ROM in order:

```
smgp.asm
  macros.asm            (no ROM bytes — macro definitions only)
  constants.asm         (no ROM bytes — constant definitions only)
    hw_constants.asm
    ram_addresses.asm
    sound_constants.asm
    game_constants.asm
  header.asm            ROM header and exception vector table
  init.asm              EntryPoint and hardware initialisation
  src/core.asm          Core game loop and utility routines
  src/menus.asm         Title screen and menu navigation
  src/race.asm          Race setup and main race loop
  src/driving.asm       Player driving mechanics
  src/rendering.asm     Road/sprite rendering
  src/race_support.asm  Race support routines
  src/ai.asm            AI car behavior
  src/audio_effects.asm Sound effect triggers
  src/objects.asm       Object system and sprite management
  src/endgame.asm       Results, credits, game over
  src/gameplay.asm      Gameplay code + all data tables (sub-includes follow)
    src/endgame_game_over_data.asm
    src/endgame_result_data.asm
    src/endgame_credits_data.asm
    src/endgame_data.asm
    src/track_config_data.asm
    src/sprite_frame_data.asm
    src/result_screen_lists.asm
    src/result_sprite_anim_data.asm
    src/result_screen_assets.asm
    src/result_screen_tiles_b.asm
    src/driver_standings_data.asm
    src/car_spec_text_data.asm
    src/car_select_metadata.asm
    src/driver_portrait_tilemaps.asm
    src/driver_portrait_tiles.asm
    src/team_messages_data.asm
    src/crash_gauge_data.asm
    src/car_sprite_blobs.asm
    src/hud_and_minimap_data.asm
    src/screen_art_data.asm
    src/track_bg_data.asm
    src/road_and_track_data.asm
    src/audio_engine.asm
```

ROM size is fixed at **524,288 bytes** ($080000).  All modules must assemble
to a byte-identical ROM.  Run `verify.bat` after every change.

---

## 2. Top-level files

| File | ROM range | Lines | Purpose |
|------|-----------|-------|---------|
| `header.asm` | $000000–$00020D | ~60 | Exception vectors + SEGA ROM header |
| `init.asm` | $00020E–$000517 | 360 | EntryPoint, hardware init, ROM checksum, main loop |
| `macros.asm` | — | ~60 | `txt`, `vdpComm`, `stopZ80`, `startZ80` macros |
| `constants.asm` | — | 4 | Include hub for the 4 constants files |

### header.asm

Contains the 256-byte SEGA Mega Drive ROM header ($000100–$0001FF) and the
M68K exception vector table ($000000–$0000FF).  The checksum word at
`Rom_checksum` ($00018E) must equal the sum of all ROM words from $000200
onward — `verify.bat` checks this.  All 64 exception vectors point to one
of three `ErrorTrap` handlers defined in `init.asm`.

### init.asm

ROM range $00020E–$0004B4 (includes `Boot_init_data` table).

Boot sequence in order:
1. TMSS warm/cold-boot detection ($020E–$021F)
2. Cold-boot VDP + Z80 pre-init ($0220–$02A0)
3. ROM checksum verify ($02A0–$02C0); mismatch → `Bad_rom_handler` (red screen)
4. First-boot-only init: default lap times, NTSC/PAL detect, English flag ($02C0–$02EE)
5. Full RAM clear + hardware init (entered on warm reboot too) ($02EE–$036A)
6. `Frame_loop`: loads `Frame_callback`, JSRs to it, loops forever ($036A–$036C)

Key exported labels: `EntryPoint`, `Frame_loop`, `Frame_callback` (RAM pointer),
`Boot_init_data`, `Bad_rom_handler`, `Initialize_default_lap_times`.

---

## 3. Code modules (src/)

Address ranges derived from first and last symbol in each file.

### src/core.asm — $000518–$00237C (2892 lines)

**Ownership:** VDP utility layer, decompression engine, PRNG, input handling,
palette management, sprite-buffer management, tilemap/draw-queue primitives.

This is the shared services library for all other code modules.  It has no
dependencies on gameplay state beyond RAM variables.

Key routine groups:

| Group | First routine | Purpose |
|-------|---------------|---------|
| Math | `Divide_fractional` | Fixed-point 16.16 division |
| Decompression | `Decompress_asset_list_to_vdp` | Decompress + upload asset list to VRAM |
| PRNG | `Prng` | LCG pseudo-random number generator |
| Input | `Update_input_bitset` | Read joypad, debounce, store button bitsets |
| VDP init | `Initialize_h32_vdp_state` | H32 (256 px) VDP mode setup |
| VDP init | `Initialize_h40_vdp_state` | H40 (320 px) VDP mode setup |
| Palette | `Fade_palette_to_black` | Fade palette to black via interpolation |
| Palette | `Upload_palette_buffer_to_cram` | Burst-write palette buffer to CRAM |
| Tilemap | `Draw_tilemap_buffer_to_vdp_64_cell_rows` | Draw 64-tile-wide tilemap to VRAM |
| DMA | `Flush_pending_dma_transfers` | Commit DMA queue to VDP |
| Sprites | `Update_objects_and_build_sprite_buffer` | Dispatch object handlers, build sprite table |
| BCD | `Binary_to_decimal` | Binary→BCD conversion |
| BCD | `Format_bcd_time_to_tile_buffer` | BCD time value → tile indices |
| VBlank | `Wait_for_vblank_cycle` | Spin until VBlank and call VBlank handler |

Modules that call into `core`: all of them.  `core` does not call back into
any other code module except through the `Frame_callback` function pointer.

### src/menus.asm — $0023A2–$0036A8 (1374 lines)

**Ownership:** Title screen, attract mode, car-selection screen, options screen,
practice mode selector, name entry.

The attract-mode and race-preview routines set `Frame_callback` and run their
own `Frame_loop`-style VBlank handler.  The main flow is:

```
Race_preview_screen_init  →  car selection  →  Options screen  →  Race_loop
```

Calls into: `core` (all VDP/palette/input primitives),
`gameplay_code` (`Initialize_drivers_and_teams`).

Does not call: `race`, `driving`, `rendering`, `ai`, `audio_effects`,
`objects`, `race_support`.

Key exported labels: `Race_preview_screen_init`, `Clear_driver_points`.

### src/race.asm — $0036B6–$005B00 (2558 lines)

**Ownership:** Race frame loop, race initialization sequence, VBlank handlers
for race and pre-race animation, lap/finish detection, practice mode, grid
setup, rival assignment entry.

`Race_loop` is the top-level per-frame dispatcher during a race.  It sequences:
input → driving → rendering → AI → audio → objects → HUD → VBlank wait.

Calls into: `core` (VDP/DMA/palette/sprite primitives), `driving`
(`Update_rpm`, `Update_speed`, `Update_steering`, `Load_track_data`),
`rendering` (`Update_road_graphics`, `Advance_player_distance`,
`Update_slope_data`, `Flush_vdp_mode_and_signs`), `race_support`
(`Update_race_timer`, `Update_horizontal_position`, `Update_gap_to_rival_display`),
`ai` (`Update_race_position`, `Parse_sign_data`, `Parse_tileset_for_signs`,
`Advance_lap_checkpoint`, `Update_pit_prompt`), `audio_effects`
(`Update_engine_and_tire_sounds`), `objects` (`Update_rival_sprite_tiles`,
`Apply_sorted_positions_to_cars`), `gameplay_code` (data access helpers).

Key exported labels: `Race_loop`, `Draw_bcd_time_to_vdp`,
`Render_packed_digits_to_vdp`.

### src/driving.asm — $005B02–$00674C (1038 lines)

**Ownership:** Player physics — RPM model, gear shifts, speed integration,
steering, braking, road-scroll state initialisation, track data loading.

Inputs come from the joypad bitset (read by `core`).  Outputs are written to
RAM variables (`Player_rpm`, `Player_speed_raw`, `Player_shift`,
`Player_distance`, etc.) consumed by `rendering` and `race`.

Calls into: `core` (`Divide_fractional`, `Decompress_tilemap_to_buffer`),
`gameplay_code` (`Load_track_data_pointer`).

Key exported labels: `Update_rpm`, `Update_speed`, `Update_steering`,
`Update_breaking`, `Load_track_data`, `Initialize_road_graphics_state`,
`Initialize_road_scroll_state`, `Update_engine_sound_pitch`.

### src/rendering.asm — $00674E–$0073DC (1348 lines)

**Ownership:** Road scanline rendering, road-scroll updates, slope integration,
background scroll, sign-mode VDP flush, arcade-mode placement display.

The road renderer uses a per-scanline displacement table built from curve and
slope data.  Each frame, `Update_road_graphics` rebuilds the displacement
columns, then `Flush_road_column_dma` (in `core`) DMA-transfers them.

Calls into: `core` (`Divide_fractional`, `Send_D567_to_VDP`,
`Set_vdp_mode_h32_variant_b`), `driving`
(`Copy_displacement_rows_to_work_buffer`), `race_support`
(`Compute_curve_speed_factor`).

Key exported labels: `Update_road_graphics`, `Update_road_tile_scroll`,
`Update_background_scroll_delta`, `Update_slope_data`,
`Advance_player_distance`, `Flush_vdp_mode_and_signs`,
`Upload_tilemap_rows_to_vdp`.

### src/race_support.asm — $0073EE–$008244 (1177 lines)

**Ownership:** Race timer (BCD countdown and lap recording), gap-to-rival
display, horizontal position updates, minimap position lookup, curve speed
factor computation, palette streaming helpers.

Calls into: `core` (tilemap/BCD/sprite-queue primitives),
`ai` (`Update_tire_wear_counter`, `Award_race_position_points`,
`Decrement_lap_time_bcd`, `Find_free_aux_object_slot`, `Alloc_aux_object_slot`).

Key exported labels: `Update_race_timer`, `Update_horizontal_position`,
`Update_gap_to_rival_display`, `Compute_curve_speed_factor`,
`Load_minimap_position`, `Compute_minimap_index`, `Write_3_palette_vdp_bytes`.

### src/ai.asm — $008250–$009AB2 (2334 lines)

**Ownership:** AI car placement scoring, rival car behavior, tire wear, lap
checkpoint logic, pit prompt, sign-data parser, sign-tileset parser,
depth-sort buffer management, race position award.

The AI system manages 15 AI cars (in `Ai_car_array`) plus the special
`Rival_car_obj`.  `Update_race_position` is the per-frame AI placement scorer
called from `race`.

Calls into: `core` (`Queue_tilemap_draw`), `gameplay_code`
(`Load_team_car_data`, `Bcd_add_loop`), `race_support`
(`Load_minimap_position`, `Compute_minimap_index`),
`audio_effects` (`Alloc_and_init_aux_object_slot`).

Key exported labels: `Update_race_position`, `Parse_sign_data`,
`Parse_tileset_for_signs`, `Advance_lap_checkpoint`, `Update_tire_wear_counter`,
`Award_race_position_points`, `Find_free_aux_object_slot`,
`Alloc_aux_object_slot`, `Compute_ai_screen_x_offset`, `Skip_if_hidden_flag`,
`Draw_placement_ordinal_to_vdp`.

### src/audio_effects.asm — $009AC4–$00A150 (576 lines)

**Ownership:** Sound effect trigger dispatch, engine-sound pitch calculation,
tire-squeal sounds, auxiliary object slot allocation for audio.

Bridges the M68K game logic to the Z80 sound driver via a command queue in
Z80 RAM.  Does not contain the Z80 driver itself (that is `src/audio_engine.asm`).

Calls into: `ai` (`Compute_ai_screen_x_offset`, `Skip_if_hidden_flag`),
`race_support` (`Write_3_palette_vdp_bytes`).

Key exported labels: `Update_engine_and_tire_sounds`,
`Alloc_and_init_aux_object_slot`, `Find_free_aux_slot_loop_Return`.

### src/objects.asm — $00A152–$00BF08 (2143 lines)

**Ownership:** Rival sprite tile updates, car sprite management, standings
screens, championship standings input, podium + minimap dispatch, music
selection commit, HUD element builders (gear indicator, race timer tiles,
message panels).

This module bridges the AI car state (addresses, positions) to the VDP sprite
buffer.  It also owns the post-race result flow entry point.

Calls into: `core` (VDP/sprite/tilemap primitives), `ai` (position/slot/
depth-sort helpers), `race_support` (`Update_race_timer`,
`Update_gap_to_rival_display`), `endgame` (`Init_race_result_scores`,
`Initialize_results_screen`, `Update_race_result_scores`),
`gameplay_code` (championship/standings/HUD data access helpers).

Key exported labels: `Update_rival_sprite_tiles`, `Apply_sorted_positions_to_cars`,
`Build_result_scroll_table`, `Commit_music_selection`.

### src/endgame.asm — $00BF30–$00C1A4 (165 lines)

**Ownership:** Race results screen init, result-score update, BCD digit
writing, second VBlank handler for race preview.

A small module that owns only the result-screen state machine and some
BCD utilities used by the results display.

Calls into: `core` (all VDP/palette/DMA/BCD primitives).

Key exported labels: `Race_preview_vblank_handler_2`,
`Initialize_results_screen`, `Init_race_result_scores`,
`Update_race_result_scores`.

### src/gameplay.asm — $00C1B4–$080000 (9655 lines, includes 22 sub-modules)

**Ownership:** Championship flow orchestration, standing management, driver/
team initialisation, track-data pointer dispatchers, car-selection graphics,
message panel rendering, font/text utilities, all data tables (via sub-includes).

`gameplay.asm` is the largest code file in the project and serves as both
the high-level championship state machine and the include hub for all data
modules.  The code section (before the first `include`) handles:

- Championship standings display and input
- Driver/team initialisation (`Initialize_drivers_and_teams`)
- Track/car/driver data pointer loaders (`Load_track_data_pointer`,
  `Load_driver_name_text_pointer`, `Load_car_spec_text_pointer`)
- Standings-order PRNG + sort
- Rival promotion logic
- Message panel, font, and BCD text rendering utilities
- Password save/load (`Save_player_state_to_buffer` / `Restore_player_state`)

Calls into: `core` (all VDP/palette/BCD/tilemap primitives), `menus`
(`Clear_driver_points`), `objects` (`Build_result_scroll_table`),
`race` (`Render_packed_digits_to_vdp`), `ai` (`Alloc_aux_object_slot`),
`race_support` (`Load_minimap_position`).

Key exported labels: `Draw_track_name_and_championship_standings`,
`Initialize_drivers_and_teams`, `Load_track_data_pointer`,
`Load_team_car_data`, `Sort_championship_standings`,
`Initialize_standings_order_buffer`, `Assign_initial_rival_team`,
`Advance_rival_promotion_state`, `Bcd_add_loop`, `EndOfRom`.

---

## 4. Data modules (src/)

All data modules are sub-included from `src/gameplay.asm`.  They contain only
`dc.b`/`dc.w`/`dc.l` data definitions (and, for track data, `incbin`
directives for extracted `data/tracks/` binary files).

| Module | ROM range | Lines | Content |
|--------|-----------|-------|---------|
| `src/track_config_data.asm` | $00F872–$010456 | 754 | 19 Track_data records, 16 championship art-config blocks |
| `src/sprite_frame_data.asm` | $010484–$012BF5 | 1668 | Car sprite frame tables (all teams and animation states) |
| `src/result_screen_lists.asm` | $0145B0–$014604 | 31 | Result screen asset lists |
| `src/result_sprite_anim_data.asm` | $0149C8–$014EE6 | 50 | Result screen sprite animation data |
| `src/result_screen_assets.asm` | $014EF4–$014F9A | 164 | Result screen compressed asset definitions |
| `src/result_screen_tiles_b.asm` | $016166–$016F32 | 163 | Result screen tile set B |
| `src/driver_standings_data.asm` | $016F3A–$019108 | 336 | Driver standings display assets |
| `src/car_spec_text_data.asm` | $019114–$0195A0 | 314 | Car spec text (ENG/TM/SUS/TIR/BRA labels, driver info) |
| `src/car_select_metadata.asm` | $0195AC–$0198A4 | 100 | TeamMachineScreenStats — bar values for car-select UI |
| `src/driver_portrait_tilemaps.asm` | $0198EC–$019A34 | 53 | 17 per-driver portrait tilemap records |
| `src/driver_portrait_tiles.asm` | $019A7C–$01DE04 | 599 | 18 driver portrait compressed tile data |
| `src/team_messages_data.asm` | $03A27A–$03C898 | 1564 | JP/EN team messages (pre/post-race) |
| `src/crash_gauge_data.asm` | $03C8C0–$03CE09 | 329 | Crash/damage gauge graphics and tables |
| `src/car_sprite_blobs.asm` | $03CEB0–$053F50 | 4801 | Compressed car sprite tiles (all 16 teams) |
| `src/hud_and_minimap_data.asm` | $054020–$0569EE | 426 | HUD tiles, minimap tiles, fonts |
| `src/screen_art_data.asm` | $056A1C–$06263A | 1911 | Background screen art (title, menus, podium, etc.) |
| `src/track_bg_data.asm` | $063910–$06DCF8 | 1719 | Track background tile sets (compressed) |
| `src/road_and_track_data.asm` | $06E750–$073E09 | 1638 | Track curve/slope/sign/minimap data (incbin from data/tracks/) |
| `src/audio_engine.asm` | $0763F0–$07FFFF | 1848 | Z80 sound driver (opaque dc.b blob, not yet disassembled) |
| `src/endgame_game_over_data.asm` | $00DAF2–$00DB12 | 8 | Game-over screen data |
| `src/endgame_result_data.asm` | $00DDCC–$00DE36 | 28 | Result screen data |
| `src/endgame_credits_data.asm` | $00E068–$00E074 | 14 | Credits screen data |
| `src/endgame_data.asm` | $00E326–$00E3CE | 58 | Endgame misc data |

### road_and_track_data.asm — incbin-backed

This module uses `incbin` directives to pull in 115 binary files from
`data/tracks/` (19 tracks × 6 sections: curve, slope, phys_slope, sign,
sign_tileset, minimap).  The files were extracted from the original ROM by
`tools/extract_track_blobs.py`.  Editing track data is done through
`tools/data/tracks.json` + `tools/inject_track_data.py`, not by editing
the source directly.

---

## 5. Constants files

| File | Lines | Content |
|------|-------|---------|
| `hw_constants.asm` | ~60 | VDP registers, Z80 bus ports, I/O port addresses |
| `ram_addresses.asm` | ~817 | All work-RAM variable addresses ($FFFF8000–$FFFFEFFF) |
| `sound_constants.asm` | ~80 | Z80 command port, audio struct addresses, music/SFX IDs |
| `game_constants.asm` | ~40 | Key constants (KEY_START, SHIFT_DOWN, etc.), menu states |

Constants are assembled before any code modules and are available everywhere.
No file should use a raw `$FFFF...` RAM address where a named constant exists.

---

## 6. Inter-module call graph

Summary of which modules call into which (JSR/BSR only; data references not shown).

```
init.asm  ──→  core (via Frame_callback)
                │
     ┌──────────┴──────────────────────────────────────┐
     ▼                                                  │
menus.asm  ──→  core                                    │
     │          gameplay_code                           │
     └──────────────────────────────────────────────────┤
                                                        │
race.asm  ──→  core                                     │
     │         driving                                  │
     │         rendering                                │
     │         race_support                             │
     │         ai                                       │
     │         audio_effects                            │
     │         objects                                  │
     │         gameplay_code                            │
     └──────────────────────────────────────────────────┤
                                                        │
driving.asm  ──→  core                                  │
               gameplay_code                            │
                                                        │
rendering.asm  ──→  core                                │
                    driving                             │
                    race_support                        │
                                                        │
race_support.asm  ──→  core                             │
                       ai                               │
                                                        │
ai.asm  ──→  core                                       │
             gameplay_code                              │
             race_support                               │
             audio_effects                              │
                                                        │
audio_effects.asm  ──→  ai                              │
                        race_support                    │
                                                        │
objects.asm  ──→  core                                  │
                  ai                                    │
                  race_support                          │
                  endgame                               │
                  gameplay_code                         │
                                                        │
endgame.asm  ──→  core                                  │
                                                        │
gameplay_code  ──→  core                                │
                    menus                               │
                    objects                             │
                    race                                │
                    ai                                  │
                    race_support                        │
```

### Notes on the call graph

- **`core` is the universal dependency.**  Every other module calls into `core`
  for VDP, palette, DMA, BCD, and sprite-buffer services.  `core` itself only
  calls back into other modules through function pointers (`Frame_callback`).

- **`gameplay_code` is the data-access hub.**  It provides pointer-loader
  helpers (`Load_track_data_pointer`, `Load_team_car_data`, etc.) called from
  many modules that need to navigate the large data tables.  This pattern
  isolates the table-offset arithmetic to one location.

- **`race` is the top-level race dispatcher.**  It sequences all race-frame
  systems.  Modules below it (`driving`, `rendering`, `ai`, etc.) do not call
  upward into `race`.

- **No circular dependencies.**  The graph is a DAG: `core` ← everything;
  `gameplay_code` ← most code modules (for data access); leaf modules
  (`driving`, `rendering`) do not call `race` or `objects`.

---

## 7. Data flow summary

```
ROM data (data/tracks/ + src/ tables)
         │
         │  incbin / dc.w / dc.l
         ▼
    Assembly (asm68k)
         │
         │  assemble → out.bin
         ▼
       ROM binary (524,288 bytes)
         │
         │  verify.bat (SHA256 check)
         ▼
     Bit-perfect verified build

Edit workflow (modding):
  tools/data/tracks.json  ──→  inject_track_data.py  ──→  data/tracks/*.bin
  tools/data/teams.json   ──→  inject_team_data.py   ──→  (patches out.bin)
  editor CLIs             ──→  JSON layer             ──→  inject  ──→  build
```

RAM data flow during a race frame:

```
Update_input_bitset  (core)
    → joypad bitsets → driving RAM vars
Update_rpm / Update_speed / Update_steering  (driving)
    → Player_speed_raw, Player_rpm, Player_distance, Player_shift
Advance_player_distance  (rendering)
    → Cur_curve_step, Cur_slope_step, road displacement table
Update_road_graphics  (rendering)
    → VDP road column DMA
Update_race_position  (ai)
    → Depth_sort_buf, placement scores
Update_rival_sprite_tiles  (objects)
    → VDP sprite attribute table
```

---

## 8. Ownership rules

1. **Edit only the module that owns the label.**  Labels defined in one module
   must not be moved to another unless the ROM address and surrounding code are
   unaffected.

2. **All cross-module communication is through JSR/BSR to named labels or
   through RAM variables.**  There is no shared stack frame or register
   convention beyond what individual routines document in their headers.

3. **Data access from code modules goes through helpers in `gameplay_code`.**
   Do not add raw table-offset arithmetic to `race.asm`, `objects.asm`, etc.
   Add a new helper in `gameplay.asm` instead.

4. **Never add `include` directives to code modules.**  Only `smgp.asm` and
   `src/gameplay.asm` may include sub-files.

5. **`src/road_and_track_data.asm` must use `incbin` only.**  Track binary
   payloads live in `data/tracks/`; the ASM file is a thin wrapper.

6. **New constants go in the appropriate split file.**  Hardware registers →
   `hw_constants.asm`; RAM addresses → `ram_addresses.asm`; audio IDs →
   `sound_constants.asm`; game flow constants → `game_constants.asm`.
