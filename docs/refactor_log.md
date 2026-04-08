# Super Monaco GP — Refactor Log

Chronological record of major structural changes, module extractions, and
tooling additions.  Each entry references its task ID from `todos.json`.

---

## Phase 1: Labels and constants (pre-2026-03-07)

### All `loc_XXXX` label definitions renamed

All 4221 unnamed labels (`loc_XXXX`) were renamed to descriptive identifiers
using Title_Snake_Case or PascalCase (for data tables).  Original ROM addresses
are preserved as `;loc_XXXX` comments immediately above each renamed label.
Zero `loc_XXXX` definitions remain in any source file.

### All RAM and I/O addresses symbolized (ARCH-005)

Work RAM, I/O ports, and VDP register addresses were extracted from raw
`$FFFF...` and `$00C0...` literals into four split constants files:

- `hw_constants.asm` — VDP registers, Z80 bus ports, I/O port addresses
- `ram_addresses.asm` — All ~700+ work-RAM variable addresses
- `sound_constants.asm` — Z80 command port, audio struct addresses, music/SFX IDs
- `game_constants.asm` — Key constants (KEY_START, SHIFT_DOWN, etc.), menu states

`constants.asm` is a four-line include hub; it produces no ROM bytes.

---

## Phase 2: Source split (early 2026-03-07 / 2026-03-08)

### Split smgp.asm into a thin include hub (ARCH-001)

The original single-file `smgp.asm` (~44,500 lines) was split into:

- `smgp.asm` — 15-line include hub
- `smgp_full.asm` — read-only concatenated reference copy (ARCH-007)
- All code under `src/`

The split used `tools/check_split_addresses.py` before and after each extraction
step to verify that symbol addresses were unchanged.

### Extract header, vectors, and error traps (ARCH-002)

`header.asm` — ROM header ($000100–$0001FF) and exception vector table
($000000–$0000FF).  `init.asm` — EntryPoint ($00020E), hardware init, ROM
checksum verify, default lap-time init, main loop.

### Split gameplay code into 11 thematic modules (ARCH-003)

ROM code from $000518 through $00C1B4 extracted into:

| Module | ROM range | Rationale |
|--------|-----------|-----------|
| `src/core.asm` | $000518–$00237C | VDP services, decompression, PRNG, input — universal dependencies |
| `src/menus.asm` | $0023A2–$0036A8 | Title/attract/car-select — separate from race loop |
| `src/race.asm` | $0036B6–$005B00 | Race frame loop — top-level race sequencer |
| `src/driving.asm` | $005B02–$00674C | Player physics — isolated from rendering |
| `src/rendering.asm` | $00674E–$0073DC | Road scanline rendering |
| `src/race_support.asm` | $0073EE–$008244 | Race timer, gap display, minimap |
| `src/ai.asm` | $008250–$009AB2 | AI cars, placement, tire wear, sign parsing |
| `src/audio_effects.asm` | $009AC4–$00A150 | Sound effect trigger dispatch |
| `src/objects.asm` | $00A152–$00BF08 | Sprite management, standings UI |
| `src/endgame.asm` | $00BF30–$00C1A4 | Results screen, BCD display |
| `src/gameplay.asm` | $00C1B4–$080000 | Championship flow + data table hub |

Extraction order respected ROM order exactly.  Each extraction step was
verified bit-perfect with `verify.bat` before proceeding.

### Split major data tables into 22 dedicated sub-modules (ARCH-004)

Large `dc.b`/`dc.w`/`dc.l` data blocks inside `src/gameplay.asm` were
extracted into named sub-modules and linked via `include` directives.

Sub-modules created (all under `src/`):

```
endgame_game_over_data.asm     endgame_result_data.asm
endgame_credits_data.asm       endgame_data.asm
track_config_data.asm          sprite_frame_data.asm
result_screen_lists.asm        result_sprite_anim_data.asm
result_screen_assets.asm       result_screen_tiles_b.asm
driver_standings_data.asm      car_spec_text_data.asm
car_select_metadata.asm        driver_portrait_tilemaps.asm
driver_portrait_tiles.asm      team_messages_data.asm
crash_gauge_data.asm           car_sprite_blobs.asm
hud_and_minimap_data.asm       screen_art_data.asm
track_bg_data.asm              road_and_track_data.asm
audio_engine.asm
```

---

## Phase 3A: Data documentation and track extraction (2026-03-09)

### Track data formats fully decoded (DOC-008)

All track data formats documented in `notes.txt`:

- Curve RLE: 3-byte (straight) or 5-byte (curve) records; `0xFF 0x00` terminator
- Visual slope RLE: 3-byte (flat) or 4-byte (slope) records; `0xFF` terminator
- Physical slope RLE: `b0 >= 0x80` = terminator; 3-byte flat, 4-byte slope
- Sign data: 4-byte records `(distance.w, count.b, sign_id.b)`, `0xFFFF` sentinel
- Sign tileset changes: 3-byte records `(distance.w, offset.b)`, `0xFF` sentinel
- Minimap: array of signed-byte (dx, dy) pairs; count = `track_length >> 6`
- Track_data record: $48 bytes, 18 named fields (8 pointers + 10 scalars)

All 19 tracks have labeled `curve_data`, `slope_data`, `phys_slope_data`,
`sign_data`, `sign_tileset`, and `minimap_pos` in `road_and_track_data.asm`.

### data/ tree and binary format specs established (DATA-003)

Created top-level `data/` directory tree:

```
data/
  tracks/       19 × 6 binary files (curve, slope, phys_slope, sign, tileset, minimap)
  art/          (reserved — art blobs not yet extracted)
  text/         (reserved — string data not yet extracted)
  audio/        (reserved — Z80 data not yet extracted)
  championship/ (reserved — championship tables not yet extracted)
  README.md     Pipeline conventions and per-category layouts
```

Also created `docs/data_formats.md` with binary format specifications.

### Track blobs extracted to data/tracks/ with incbin wrappers (EXTR-000)

All 19 tracks × 6 sections = 115 binary files extracted from `orig.bin`
into `data/tracks/`.  Lines 1405–2980 of `src/road_and_track_data.asm`
(dc.b/dc.w blob) replaced with `incbin` directives.

Key fix applied: `monaco_arcade` sign_tileset end address corrected (was
0x75C4A, corrected to 0x73E09).  Added `Monaco_arcade_post_sign_tileset_blob`
label for the unlabeled 7745-byte blob at ROM $073E09–$075C4A.

### Track data extractor and injector (EXTR-001, EXTR-002)

- `tools/extract_track_data.py` — reads `data/tracks/` binaries, decodes all
  RLE and sign formats, emits `tools/data/tracks.json` (19 tracks, all fields)
- `tools/inject_track_data.py` — re-encodes JSON back to `data/tracks/` binary
  files; no-op round-trip verified (0 files changed)

Six round-trip fidelity bugs fixed during EXTR-002 (curve/slope terminator
`_raw` fields, phys_slope <3-byte trailing, minimap odd-length padding,
sign_tileset off-by-one loop, monaco_arcade trailing `0x00`).

### Art asset catalog (DATA-001)

17 unique background tile sets, 18 tilemaps, 18 minimap tile sets, and 18
minimap map sets cataloged in `notes.txt` (ART ASSET CATALOG section).

---

## Phase 3B: Randomizer and editor pipeline (2026-03-09)

### Data annotation — team and driver tables (DOC-007)

Annotated in place within ASM source files:

- `Team_car_characteristics` — 16×5-byte records, all fields named
- `Team_engine_multiplier` — 16 bytes
- `InitialDriversAndTeamMap` / `SecondYearDriversAndTeamsMap` — 18 bytes each
- `PointsAwardedPerPlacement`
- `Team_palette_data` — 16×56-byte records, per-team truck/car colors
- `DriverPortraitTiles` — 18 labeled dc.l pointers
- `Driver_portrait_tilemaps.asm` — 17 per-driver tilemap records
- `car_spec_text_data.asm` — Car_spec_text_table (16) + Driver_info_table (17)
- `car_select_metadata.asm` — TeamMachineScreenStats 16×7 bytes (all bar values)
- `Ai_performance_table` — 16 per-team 8-byte rows
- `Post_race_driver_target_points` — 16 per-team 2-byte rows (promote/partner)

Bug fix: Corrupt byte sequences in `Post_race_driver_target_points` and
`Ai_performance_table` (introduced by a prior reformatting session) were
identified and restored to original values.

### Championship progression documented (DOC-009)

Full championship flow documented in `notes.txt` (~120 lines):

- 16-race track order (San Marino → Monaco)
- Points system: 9/6/4/3/2/1 for placements 1–6
- Standings sort: PRNG + bubble sort + BCD accumulator
- Elimination: score-based (no per-race placement floor)
- Rival system: 3 assignment paths, `Promoted_teams_bitfield` encoding
- Password system: 58-byte save buffer, 4-nibble EOR/rotate checksum

### Team/car data extractor and injector (EXTR-003, EXTR-004)

- `tools/extract_team_data.py` — reads 19 tables from `orig.bin` at known
  ROM addresses, emits `tools/data/teams.json`
- `tools/inject_team_data.py` — patches `out.bin` in-place at 19 fixed-size
  addresses; no-op round-trip confirmed

Test suite: `tools/tests/test_team_data.py` — 2056 tests (all pass).

### Randomizer architecture document (RAND-001)

`docs/randomizer_architecture.md` — seed format, flag bits, xorshift32 PRNG,
sub-seed derivation, pipeline diagram, track generation strategy, validity
checks, hack workspace design.

### Track randomizer (RAND-002 through RAND-006)

`tools/randomizer/track_randomizer.py` implements:

- `generate_curve_rle()` — curve sequences with mandatory post-curve straights,
  weighted sharpness, correct curve_byte encoding
- `generate_slope_rle()` — visual slope (89.6% flat, bg_vert_disp from known set)
- `generate_phys_slope_rle()` — derived from visual slope, high-bit terminator
- `generate_sign_data()` — sign records, spacing 100–500, sign_id pool (39 values)
- `generate_sign_tileset()` — tileset changes at ~1500-unit intervals
- `generate_minimap()` — integrates curve bytes, samples every 64 steps
- `randomize_art_config()` — Fisher-Yates shuffle of 16 art sets

### Track validator (RAND-007)

`tools/randomizer/track_validator.py` — validates generated track data against
all known constraints.  All 19 ROM tracks pass.  Discovered: `track_length`
must be a multiple of 64 (not 128 as previously noted); fixed in both
`track_validator.py` and `track_randomizer.py`.

### Modding architecture document (EDIT-001)

`docs/modding_architecture.md` — three-layer model, file ownership map, safe
edit categories, standard workflow, randomizer workflow, ASM wrapper
conventions, checksum/verify.bat gate, round-trip guarantee, hack workspace
system, seed format, CLI reference, known limitations.

### Unified randomizer CLI (RAND-010)

`tools/randomize.py` — parse seed → randomize tracks → validate → inject →
assemble.  `tools/restore_tracks.py` — restore from backup.

Key finding: `verify.bat` checks the original SHA256, so it is not usable for
randomized ROMs.  `build.bat` (assembler exit 0 + "0 error(s)") is the gate
for randomized builds.

### Hack workspace system (RAND-011)

`tools/hack_workdir.py` — isolated build pipeline: validate seed → create
`build/workspaces/<seed>/` → copy 203 files → run randomizer → assemble →
copy `out.bin` to `--output`.  Workspace cleaned on success unless `--keep`.
Original source tree never modified.

### Art config shuffle (RAND-006) and editors (EDIT-002, EDIT-003)

`tools/editor/track_editor.py` — 580-line track editor CLI (14 subcommands,
constraint validation, inject integration).

`tools/editor/team_editor.py` — 580-line team/car editor CLI (22 subcommands,
stat range validation, inject integration).

### gitignore update (REGR-003)

Fixed overly broad `*.bin` rule (was hiding `data/tracks/*.bin` incbin assets
from git).  New rules:

- `/*.bin` — root-level ROM images only
- `*.lst` — assembler listings
- `build/` — workspace temp dirs
- `**/__pycache__/`, `*.pyc`, `*.pyo` — Python cache
- `tools/data/tracks.orig.json` — randomizer backup

### Test suite (TEST-001 through TEST-007)

| Suite | File | Tests |
|-------|------|-------|
| Round-trip | `tools/tests/test_roundtrip.py` | 518 |
| Track validator | `tools/tests/test_track_validator.py` | 59 |
| RLE | `tools/tests/test_rle.py` | 213 |
| Test runner | `tools/tests/run_tests.py` | — |
| Hack workspace | `tools/tests/test_hack_workdir.py` | 66 |
| Randomizer smoke | `tools/tests/test_randomizer_smoke.py` | 65 |
| Art config | `tools/tests/test_art_config.py` | 250 |
| Team data | `tools/tests/test_team_data.py` | 2056 |
| Track editor | `tools/tests/test_track_editor.py` | 81 |
| Team editor | `tools/tests/test_team_editor.py` | 86 |

All tests pass.  Total: >3,000 tests.

---

## Phase 3C: Node.js migration (2026-03-09)

The entire toolchain was rewritten from Python to Node.js/JavaScript.  No new
Python tooling is permitted; all automation, editors, randomizers, and tests
now target Node.js.

### Shared tooling foundation (NODE-002)

`tools/lib/prng.js` — xorshift32 seeded PRNG (matches Python implementation).
`tools/lib/rle.js` — curve/slope RLE encode/decode.
`tools/lib/track_schema.js` — track JSON validation.
`package.json` with `npm test`, `npm run extract`, `npm run inject` scripts.

### Indexes and checks replaced (NODE-003)

All index generators rewritten as Node.js:

- `tools/index/functions.js` — 4266 symbols, header coverage (73/376 = 19%)
- `tools/index/callsites.js` — 5655 cross-references across 42 source files
- `tools/index/include_graph.js` — 43 files, 42 edges, max depth 2
- `tools/index/strings.js` — 859 string entries across 11 categories
- `tools/index/hotspots.js` — 59 unreferenced routines, 14 high-ref hotspots
- `tools/index/coverage_report.js` — per-file comment density and header coverage
- `tools/run_checks.js` — aggregator for all 6+ structural linters
- `tools/lint_backslide.js` — raw RAM/IO literal and raw-pointer regression linter

### Extract/inject pipeline replaced (NODE-004)

- `tools/extract_game_data.js` — unified extractor (`--tracks/--teams/--championship/--all`)
- `tools/inject_game_data.js` — unified injector (same flags, `--dry-run`)
- `tools/extract_strings.js` / `tools/inject_strings.js` — 4 mutable EN string
  categories; no-op dry-run verified; 3737-test JS suite passing

### Editor CLIs replaced (NODE-005)

- `tools/editor/track_editor.js` — 14 subcommands (Node.js replacement for track_editor.py)
- `tools/editor/team_editor.js` — 22 subcommands
- `tools/editor/text_editor.js` — 7 subcommands including charset reference
- `tools/editor/championship_editor.js` — show/set/validate/inject subcommands

### Randomizer and workspace stack replaced (NODE-006)

- `tools/randomizer/track_randomizer.js` — curve/slope/sign/minimap/art generation
- `tools/randomizer/track_validator.js` — all 19 ROM tracks pass; constraint coverage
- `tools/randomizer/team_randomizer.js` — Fisher-Yates pool shuffles, AI perturbation
- `tools/randomizer/championship_randomizer.js` — race order shuffle, Monaco fixed
- `tools/randomize.js` — unified CLI: parse seed → randomize → validate → inject → build
- `tools/hack_workdir.js` — isolated build workspace; original source never modified
- `tools/restore_tracks.js` — restore from `tracks.orig.json` backup

### Test suite replaced (NODE-007)

All Python test files replaced by JavaScript equivalents.  JS runner:
`tools/tests/run.js`.  Grand total: **4045+ tests**, all passing.

| Suite | File | Tests |
|-------|------|-------|
| Functions index | `test_functions_index.js` | 3798 |
| Callsites index | `test_callsites.js` | 3860 |
| Hotspots | `test_hotspots.js` | 60 |
| Coverage report | `test_coverage_report.js` | 55 |
| Lint backslide | `test_lint_backslide.js` | 70 |
| Strings | `test_strings.js` | 3737 |

### Legacy Python scripts removed (NODE-008, NODE-009)

All Python extractors, injectors, editors, randomizers, and test files deleted.
Only `smgp_full.asm` (read-only reference) and `orig.bin` remain as non-JS
non-ASM files at the project root.

---

## Phase 3D: Team, championship, and text pipeline (2026-03-09)

### String extract/inject pipeline (EXTR-005)

- `tools/extract_strings.js` — 4 mutable EN categories + 5 read-only reference
  categories → `tools/data/strings.json` (859 entries)
- `tools/inject_strings.js` — patches `out.bin` in-place; no-op dry-run clean
- Bug fix: injector was over-padding to `capacity` with `0xFF`, overwriting
  legitimate `0x00` bytes; fixed to write only the natural payload

### Championship extract/inject pipeline (EXTR-006)

13 championship tables extracted from `orig.bin` to `tools/data/championship.json`
(1011 lines): PointsAwardedPerPlacement, Ai_performance_table, rival grid tables,
Ai_placement_data (standard/easy/champ), lap-time offset table, and more.

`tools/inject_championship_data.js` — patches `out.bin` in-place; no-op dry-run
confirms 0 bytes changed.

### Team/AI randomizer (RAND-008)

`tools/randomizer/team_randomizer.js`:

- `randomize_teams()` — shuffles accel_index/engine_index pools (Fisher-Yates),
  perturbs steering/braking, shuffles tire_wear_multiplier pool
- `randomize_ai()` — shuffles ai_performance_factor and ai_performance_table rows,
  perturbs post_race_driver_target_points with `partner_threshold >= promote + 2`

### Championship randomizer (RAND-009)

`tools/randomizer/championship_randomizer.js`:

- Shuffles race slots 0–14 (Monaco slot 15 fixed)
- Shuffles rival_grid_base_table pool; perturbs rival_grid_delta_table entries
- Shuffles inner 14 pairs of pre_race_lap_time_offset_table

### Championship editor CLI (EDIT-005)

`tools/editor/championship_editor.js` — 14 subcommands:
`show-order`, `show-points`, `show-thresholds`, `show-rivals`, `show-ai-factor`,
`show-ai-table`, `show-ai-placement`, `set-order`, `move-track`, `set-points`,
`set-threshold`, `set-ai-factor`, `set-ai-table`, `validate`, `inject`.

---

## Phase 3E: Tooling hardening and Polish (2026-03-09)

### Pre-commit hooks (REGR-001)

`tools/pre-commit.cmd` and `tools/pre-commit.sh` — installers that write a
POSIX sh hook to `.git/hooks/pre-commit` running `verify.bat` + `node tools/run_checks.js`.
Key fix: `EnableDelayedExpansion` must not be active when writing the `#!/bin/sh` shebang.

### Regression lint (REGR-002)

`tools/lint_backslide.js` — detects newly introduced raw RAM/IO literals
(RAW_ADDR) and raw ROM pointer values (RAW_PTR) in code modules.  Frozen
allowlist of 29 known exceptions (all Z80 audio window addresses, pending
AUDIO-001).  Integrated as check 6 in `tools/run_checks.js`.

### Index tooling (TOOL-007 through TOOL-013)

Complete index suite:
- **functions.js** — all 4266 symbols with kind, source file, size estimate,
  header coverage flag
- **callsites.js** — 5655 refs; kinds: call/branch/lea/data_ptr/data_word
- **include_graph.js** — full `smgp.asm` include tree (43 files, max depth 2)
- **strings.js** — 859 string entries across 11 categories
- **hotspots.js** — top 14 hotspots; 59 unreferenced routines; 159 single-site
- **coverage_report.js** — project-wide 6.0% comment density; 73/376 (19.4%)
  header coverage; identifies `src/gameplay.asm` (2.9%) and `src/menus.asm`
  (0% header coverage) as priority annotation targets

---

## Phase 4: Deep documentation pass (2026-03-09)

### Rendering pipeline headers (DOC-011)

Added function headers to all 7 undocumented routines in `src/rendering.asm`:
`Advance_player_distance`, `Interpolate_curveslope_segment`,
`Scale_curveslope_entry`, `Flush_vdp_mode_and_signs`, `Upload_tilemap_rows_to_vdp`,
`Fill_table_stride_loop`.  All 7 inline data tables annotated with format comments.

### Object system headers (DOC-012)

Function headers added to all major routines in `src/objects.asm`: object pool
allocator, per-frame dispatch, sprite attribute buffer builder, object state
machine structure.

### Menu and state machine headers (DOC-014)

Full function headers added to all 21 routines/data labels in `src/menus.asm`.
Dispatch-flow and I/O contract comments for code routines; format comments for
all 9 inline data tables.  Header coverage rose from 133 to 142 project-wide.

### Race loop headers (DOC-015)

Post-label function headers added to all 58 top-level symbols in `src/race.asm`.
Full I/O contracts for `Update_shift`, `Update_rpm_Crash_decel_chk`,
`Sync_visual_rpm`, `Fill_vram_rect`, `Load_track_preview_data`,
`Championship_start_init`.  All data tables annotated.  Header coverage rose
to 198/376 project-wide.

### notes.txt modernization (DOC-013, NOTES-001)

`notes.txt` completely rewritten (~1079 lines).  New sections added:

- **MENU AND STATE MACHINE DISPATCH** — Frame_callback model, attract cycle,
  title, options, race loop, Screen_timer convention
- **RENDERING PIPELINE** — scanline descriptor table format,
  Road_scanline_descriptor_table at $6F940, perspective scale tables,
  H-blank/VDP scroll, sign tileset DMA constraint (≥1500 unit spacing)
- **OBJECT SYSTEM AND SPRITE POOL MANAGEMENT** — pool layout, $40-byte slot
  format, per-frame dispatch, Sprite_attr_buf, object type codes, key routines
- **AUDIO SUBSYSTEM** — 68K engine state struct (all offsets), per-frame update,
  Z80 bus arbitration protocol, music/SFX trigger flow, Z80 RAM interface window

MEMORY MAP updated with `Audio_ctrl_mode`, `Audio_seq_timer`,
`Sign_tileset_dma_pending`, all Z80 audio interface addresses.

TRACK DATA VALIDITY CONSTRAINTS corrected: minimap formula is `track_length >> 6`
(not `(track_length >> 5) + 1` as previously noted); sign tileset spacing
constraint (rule #9, ≥1500 units) added.

---

## Current state (2026-03-09)

- 0 `loc_XXXX` label definitions remain
- 4266 symbols named in symbol map
- All RAM/IO addresses symbolized (817-line `ram_addresses.asm`)
- 30+ source modules (11 code + 22+ data) in `src/`
- Track data fully extracted to `data/tracks/` (115 binary files)
- Full extract/inject pipeline for tracks, teams, strings, and championship
- Full track randomizer pipeline (curve/slope/sign/minimap/art/team/championship)
- Hack workspace system for isolated randomized builds
- 4045+ automated tests (Node.js), all passing
- Function headers added to 198/376 routines (52.7% header coverage)
- Project-wide comment density: 6.0%

## Known remaining gaps

- **Z80 audio driver** (`src/audio_engine.asm`): opaque `dc.b` blob;
  68K interface fully documented but Z80 program not disassembled (AUDIO-001/002)
- **Art blob extraction**: `data/art/` exists but no blobs extracted;
  tile compression format (Huffman, `Decompress_to_vdp`) not yet reverse-
  engineered well enough to write a compressor (DATA-002)
- **Dedicated linter suite** (TOOL-011): `lint_raw_ram.js`, `lint_raw_vdp.js`,
  `lint_dup_constants.js`, `audit_magic_numbers.js` not yet written
- **Refactor log maintenance** (NOTES-002): this file; update as work lands
