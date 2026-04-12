# Super Monaco GP — Modding and Data Round-Trip Architecture

Reference document for contributors who want to understand how the modding
pipeline works end-to-end: where data lives, how to edit it safely, how the
assembler build relates to the extracted `data/` layer, and how the randomizer
and editor CLIs slot into the workflow.

Task: EDIT-001.  Prerequisites: EXTR-001 (track extraction), EXTR-002 (track
injection), DATA-003 (data/ tree), RAND-001 (randomizer architecture).

---

## Table of Contents

1. [Design philosophy](#1-design-philosophy)
2. [Three-layer data model](#2-three-layer-data-model)
3. [File ownership map](#3-file-ownership-map)
4. [What is safe to edit](#4-what-is-safe-to-edit)
5. [Standard editing workflow](#5-standard-editing-workflow)
6. [Randomizer workflow](#6-randomizer-workflow)
7. [ASM wrapper conventions](#7-asm-wrapper-conventions)
8. [Checksum and verify.bat](#8-checksum-and-verifybat)
9. [Round-trip correctness guarantee](#9-round-trip-correctness-guarantee)
10. [Hack workspace system](#10-hack-workspace-system)
11. [Seed format quick reference](#11-seed-format-quick-reference)
12. [CLI quick reference](#12-cli-quick-reference)
13. [Adding a new data category](#13-adding-a-new-data-category)
14. [Known limitations](#14-known-limitations)
15. [File layout](#15-file-layout)

---

## 1. Design philosophy

**The edit surface for game data is `data/` and `tools/data/*.json`, never raw
ASM dc.b/dc.w/dc.l blobs.**

Rationale:

- Large `dc.b` blocks are fragile.  Offsets, lengths, and pointer relationships
  cannot be statically verified by a text editor or linter.
- Extracted binary files in `data/` have stable, well-defined names; tools that
  operate on them do not require parsing assembly syntax.
- The JSON layer (`tools/data/*.json`) provides a human-readable, diffable,
  type-safe edit surface on top of the binary layer.
- The assembler (`asm68k`) remains the final authority on the ROM binary via
  `verify.bat`.  The pipeline must never break `verify.bat`.

This model is directly inspired by the Vermilion project's architecture, which
uses a top-level `data/` binary tree, a `tools/data/` JSON layer, and a
strictly separated `inject → build → verify` gate.

---

## 2. Three-layer data model

```
┌────────────────────────────────────────────────────────────────────────────┐
│ Layer 3 — Structured edit layer                                            │
│                                                                            │
│   tools/data/tracks.json           Human-readable decoded track data      │
│   tools/data/teams.json            (future) Team/car stats                │
│   tools/data/championship.json     (future) Race order, points tables     │
│   tools/data/strings.json          (future) All game text                 │
│                                                                            │
│   Edit these files manually, or let an editor CLI do it for you.          │
│   The randomizer also writes to these files (backed up as *.orig.json).   │
└─────────────────────────────────┬──────────────────────────────────────────┘
                                  │  tools/inject_*.js
                                  ▼
┌────────────────────────────────────────────────────────────────────────────┐
│ Layer 2 — Binary source-of-truth layer                                     │
│                                                                            │
│   data/tracks/<slug>/*.bin         Per-track binary streams               │
│   data/art/                        (future) Compressed tile/palette blobs │
│   data/text/                       (future) Raw string data               │
│   data/audio/                      (future) Z80 driver payload            │
│   data/championship/               (future) Race order / points binaries  │
│                                                                            │
│   These are the files referenced by `incbin` directives in the ASM source.│
│   Never edit them by hand — always go through layer 3 + injector.         │
└─────────────────────────────────┬──────────────────────────────────────────┘
                                  │  incbin directives in src/*.asm
                                  ▼
┌────────────────────────────────────────────────────────────────────────────┐
│ Layer 1 — Assembler build layer                                            │
│                                                                            │
│   smgp.asm (include hub)                                                   │
│   src/*.asm (code + thin ASM wrappers for incbin regions)                  │
│   constants.asm / hw_constants.asm / ram_addresses.asm / etc.              │
│                                                                            │
│   Assembled by: asm68k /k /p /o ae- smgp.asm,out.bin,,smgp.lst            │
│   Verified by:  verify.bat  (SHA256 of out.bin vs. known-good hash)       │
└────────────────────────────────────────────────────────────────────────────┘
```

Data flows **down** when building: JSON → binary → ROM.  
Data flows **up** when extracting: ROM → binary → JSON.  
The assembler always reads from Layer 1.  The randomizer and editors work on
Layers 2 and 3 only.

---

## 3. File ownership map

| Category       | Layer 3 (JSON)                    | Layer 2 (binary)           | Layer 1 (ASM)                             | Status           |
|----------------|-----------------------------------|----------------------------|-------------------------------------------|------------------|
| Track data     | `tools/data/tracks.json`          | `data/tracks/<slug>/*.bin` | `src/road_and_track_data.asm` (incbin)    | Complete         |
| Track config   | part of `tools/data/tracks.json`  | —                          | `src/track_config_data.asm` (dc.l/dc.w)  | Partial (RAND-006)|
| Team/car stats | `tools/data/teams.json`           | `data/teams/`              | `src/track_config_data.asm`               | Future (EXTR-003)|
| Text/strings   | `tools/data/strings.json`         | `data/text/`               | `src/team_messages_data.asm`, etc.        | Future (EXTR-005)|
| Championship   | `tools/data/championship.json`    | `data/championship/`       | `src/gameplay.asm`                        | Future (EXTR-006)|
| Art/graphics   | (index only, no structured edit)  | `data/art/`                | `src/track_bg_data.asm`, etc.             | Future (DATA-001)|
| Audio          | —                                 | `data/audio/z80_driver.bin`| `src/audio_engine.asm`                    | Future (AUDIO-001)|

**Currently active layer 2 regions** (backed by `incbin` in ASM source):

- `data/tracks/<slug>/curve_data_rle.bin` → `<Slug>_curve_data:` label
- `data/tracks/<slug>/slope_visual_rle.bin` → `<Slug>_slope_data:` label
- `data/tracks/<slug>/slope_phys_rle.bin` → `<Slug>_phys_slope_data:` label
- `data/tracks/<slug>/sign_data.bin` → `<Slug>_sign_data:` label
- `data/tracks/<slug>/sign_tileset.bin` → `<Slug>_sign_tileset:` label
- `data/tracks/<slug>/minimap_pos.bin` → `<Slug>_minimap_pos:` label
- `data/tracks/<slug>/lap_targets.bin` → `<Slug>_lap_targets:` label

All other structured data in `src/*.asm` is still in dc.b/dc.w/dc.l form and
has not yet been converted to `incbin` wrappers.

---

## 4. What is safe to edit

### Safe: Layer 2 (binary) via Layer 3 (JSON) + injector

The following data categories are fully supported by the extract → edit → inject
pipeline.  After injection, run `cmd //c build.bat` followed by `cmd //c verify.bat`
(or use the hack workspace system to avoid touching the working tree).

| Data class                 | Edit via                               | Constraints                           |
|----------------------------|----------------------------------------|---------------------------------------|
| Track curve sequences      | `tools/data/tracks.json` curves field  | See `docs/data_formats.md §2–3`       |
| Track slope profiles       | `tools/data/tracks.json` slopes field  | See `docs/data_formats.md §4–7`       |
| Sign placement             | `tools/data/tracks.json` sign_data     | See `docs/data_formats.md §8`         |
| Sign tileset triggers      | `tools/data/tracks.json` sign_tileset  | See `docs/data_formats.md §9`         |
| Minimap path               | `tools/data/tracks.json` minimap_pos   | See `docs/data_formats.md §10`        |
| Lap time targets           | `tools/data/tracks.json` lap_targets   | See `docs/data_formats.md §11`        |
| Track scalar config        | `tools/data/tracks.json` scalars       | track_length, steering_divisors, etc. |

### Unsafe / not yet supported

| Data class                   | Reason                                        | Blocking task  |
|------------------------------|-----------------------------------------------|----------------|
| Track pointer fields         | Point to ROM labels; change requires relinking| EXTR-003+      |
| Team/car stats               | No extractor yet                              | EXTR-003       |
| Text / team messages         | No extractor + encoding not documented        | EXTR-005       |
| Championship race order      | No extractor yet                              | EXTR-006       |
| Art / tile graphics          | Compression format not documented             | DATA-001/002   |
| Z80 audio                    | Driver not disassembled                       | AUDIO-001      |
| Code (any src/*.asm)         | Any change must verify bit-perfect            | —              |

### Editing code

Any change to the ASM source must:
1. Preserve byte-identical output — run `cmd //c verify.bat` after every change.
2. Follow naming conventions in `AGENTS.md` (labels, constants, comments).
3. Not introduce raw RAM/I/O literals — use symbolic constants.
4. Preserve all `;loc_XXXX` comments above renamed labels.

---

## 5. Standard editing workflow

### Editing existing track data

```
# 1. Extract current track data (if not already done or if data/ was modified)
node tools/extract_track_data.js

# 2. Open and edit the JSON
$EDITOR tools/data/tracks.json

# 3. Validate constraints (optional but recommended before injection)
node tools/tests/run.js --filter track_validator

# 4. Inject modified JSON back to data/tracks/ binaries
node tools/inject_track_data.js

# 5. Rebuild and verify
cmd //c build.bat
cmd //c verify.bat
```

`verify.bat` will exit 0 only if the output ROM is byte-identical to the
original ROM hash.  If you have intentionally modified track data, `verify.bat`
will fail — this is expected.  Use `cmd //c build.bat` as the success gate for
intentional changes, and check the assembler exits 0 with "0 error(s)".

To restore the original unmodified ROM:

```
node tools/restore_tracks.js --verify
```

### Editing code or constants

```
# 1. Make the change in the relevant src/*.asm or constants file
# 2. Rebuild and verify bit-perfect output
cmd //c verify.bat
# If verify.bat fails, isolate and fix before proceeding
```

---

## 6. Randomizer workflow

The randomizer modifies track data in memory using a seeded PRNG, validates the
result, writes modified JSON and binary files, and assembles the ROM.

```
# Generate a randomized ROM in an isolated workspace (recommended):
node tools/hack_workdir.js SMGP-1-01-12345

# Or: inspect the workspace-safe plan without mutating anything:
node tools/randomize.js SMGP-1-01-12345 --dry-run

# Or: debug in-root with an explicit checkpoint (use with care):
node tools/randomize.js SMGP-1-01-12345 --in-root

# Restore the original track data and clear any in-root checkpoint:
node tools/restore_tracks.js --verify
```

The randomizer pipeline internally:

1. Reads `tools/data/tracks.json` (Layer 3).
2. Randomizes all 19 tracks in memory using sub-seeded PRNG instances.
3. Validates all generated tracks with `track_validator.js`.
4. In workspace-safe mode, performs the mutations in the isolated workspace.
5. In explicit `--in-root` mode, creates an in-root checkpoint under `build/checkpoints/in_root_debug/` before mutating tracked inputs.
6. Writes modified `tools/data/tracks.json` and related generated files.
7. Calls `inject_track_data.js` to push binary files to `data/tracks/`.
8. Calls `build.bat` — checks assembler exit 0 with "0 error(s)".

Because `verify.bat` compares against the original ROM hash, it will always
fail after randomization.  The correct success gate for a randomized build is
assembler success (see §8).

---

## 7. ASM wrapper conventions

When a data region is moved from `dc.b` blobs to `incbin` wrappers, the ASM
source follows this convention:

```asm
;loc_XXXX  (preservation comment for the original ROM address)
San_Marino_curve_data:
    incbin  "data/tracks/san_marino/curve_data_rle.bin"
```

Rules:

- One `incbin` per binary file.  No inline `dc.b` mixed into an incbin region.
- Label naming: `<ASM_prefix>_<data_type>:` matching the Track_data pointer
  field name (e.g. `San_Marino_curve_data`, `Brazil_sign_data`).
- The `;loc_XXXX` preservation comment must immediately precede the label.
- The injector (`tools/inject_track_data.js`) rewrites only the binary files;
  it does **not** modify the ASM source.  The ASM wrapper is written once and
  remains stable as long as the slug-to-label mapping does not change.
- If a track is reordered or renamed, both the `incbin` label and the
  `Track_data` table pointer in `src/track_config_data.asm` must be updated
  consistently.

### Pointer fields (not yet extracted)

The `Track_data` table (`src/track_config_data.asm`) still uses `dc.l` literals
for art pointer fields (bg_tiles_ptr, bg_tilemap_ptr, etc.).  These point to
ROM labels and must remain as symbolic `dc.l Label` references.  The injector
does not touch `track_config_data.asm` for Phase 3A/3B.

Art pointer assignment for RAND-006 will be handled by an in-memory patch to
the Track_data table in a dedicated patcher module, not by rewriting
`track_config_data.asm` text.

---

## 8. Checksum and verify.bat

The ROM header at byte `$018E` contains a 16-bit checksum over bytes
`$000200–$07FFFF`.  The assembler does **not** update this automatically.

`verify.bat` works by comparing the SHA256 of `out.bin` against a known-good
hash.  It does **not** independently validate the header checksum.  The checksum
in the assembled ROM is whatever the ASM source emits at `header.asm:+$8E`.

### Rules

| Situation                          | Gate to use               | Why                                      |
|------------------------------------|---------------------------|------------------------------------------|
| Code change / constant rename      | `cmd //c verify.bat`      | Must be bit-perfect                      |
| Intentional data modification      | `cmd //c build.bat`       | Assembler success is the correctness bar |
| Randomized ROM                     | `cmd //c build.bat`       | Hash will always differ from original    |
| Restoring original ROM             | `cmd //c verify.bat`      | Confirms full round-trip integrity       |

### What `verify.bat` checks

```
build.bat  →  asm68k exits 0, "0 error(s)" in output
SHA256(out.bin) == KNOWN_GOOD_HASH
```

### What `build.bat` checks

```
asm68k /k /p /o ae- smgp.asm,out.bin,,smgp.lst
exit code == 0  AND  stdout contains "0 error(s)"
```

Use `build.bat` as the success gate whenever `verify.bat` is expected to fail
(e.g. after any intentional data change or randomization).

---

## 9. Round-trip correctness guarantee

Before any editor or randomizer depends on a data category, its pipeline must
pass a **no-op round-trip test**:

```
extract → inject (unmodified) → build.bat → verify.bat
```

The round-trip must produce a bit-identical ROM.  This is the single strongest
correctness guarantee available short of running the game.

### Currently passing round-trips

| Category   | Test file                           | Status   |
|------------|-------------------------------------|----------|
| Tracks     | `tools/tests/test_roundtrip.js`     | Passing  |
| RLE codecs | `tools/tests/test_rle.js`           | Passing  |
| Validator  | `tools/tests/test_track_validator.js` | Passing|

Run all tests:

```
node tools/tests/run.js
```

### Round-trip for future categories

When EXTR-005 (strings) is implemented, it must add round-trip tests to
`tools/tests/test_roundtrip.js` before any editor or randomizer builds on it.

---

## 10. Hack workspace system

`tools/hack_workdir.js` is the recommended way to produce a randomized ROM.  It
creates an isolated copy of the project, runs the randomizer there, assembles
the ROM, and writes the output binary — without touching the original working
tree.

```
node tools/hack_workdir.js SMGP-1-01-12345
```

This produces `out_SMGP-1-01-12345.bin` in the repo root.

### When to use the workspace system

| Use case                                   | Recommended tool                  |
|--------------------------------------------|-----------------------------------|
| Sharing a ROM with another person          | `hack_workdir.js`                 |
| Testing a specific seed non-destructively  | `hack_workdir.js`                 |
| Developing / debugging the randomizer      | `randomize.js --dry-run`, then `--in-root` only if needed |
| Editing track data manually and building   | Direct in-place workflow (§5)     |
| Confirming an original ROM is bit-perfect  | `verify.bat` directly             |

### Workspace directory

```
build/workspaces/
  SMGP-1-01-12345/      ← one directory per seed
    smgp.asm
    src/
    data/
    tools/
    asm68k.exe
    build.bat
    out.bin             ← assembled ROM (may differ from original)
    randomizer.log      ← per-run log
```

Workspaces are kept by default.  Use `--keep` to keep or let them expire.
Use `--list` to see all existing workspaces.  Use `--force` to overwrite.

---

## 11. Seed format quick reference

```
SMGP-<version>-<flags_hex>-<seed_decimal>
```

| Field            | Type     | Example   | Notes                               |
|------------------|----------|-----------|-------------------------------------|
| `SMGP`           | fixed    | `SMGP`    | Magic prefix                        |
| `<version>`      | digit    | `1`       | Randomizer version                  |
| `<flags_hex>`    | hex      | `01`      | Bitmask; see table below            |
| `<seed_decimal>` | decimal  | `12345`   | PRNG seed; range 0–4294967295       |

### Flag bits

| Bit | Hex   | Name              | What it randomizes                         | Status     |
|-----|-------|-------------------|--------------------------------------------|------------|
| 0   | 0x01  | RAND_TRACKS       | Curve, slope, signs, minimap               | Implemented|
| 1   | 0x02  | RAND_TRACK_CONFIG | Art/road-style assignment                  | Pending    |
| 2   | 0x04  | RAND_TEAMS        | Team car stats                             | Pending    |
| 3   | 0x08  | RAND_AI           | AI placement parameters                    | Pending    |
| 4   | 0x10  | RAND_CHAMPIONSHIP | Championship race order                    | Pending    |
| 5   | 0x20  | RAND_SIGNS        | Sign IDs only (independent of RAND_TRACKS) | Pending    |
| 6   | 0x40  | reserved          | —                                          | —          |
| 7   | 0x80  | reserved          | —                                          | —          |

### Example seeds

```
SMGP-1-01-0          # no-op: RAND_TRACKS flag + zero seed = validate only
SMGP-1-01-12345      # randomize tracks, seed 12345
SMGP-1-FF-99999      # all flags enabled, seed 99999 (most flags pending)
SMGP-1-00-0          # no-op: zero flags = identity (for round-trip testing)
```

---

## 12. CLI quick reference

### Extraction

```bash
# Extract all 19 tracks from data/tracks/ to tools/data/tracks.json
node tools/extract_track_data.js

# Extract all categories
node tools/extract_game_data.js --all
```

### Injection

```bash
# Inject tools/data/tracks.json back to data/tracks/ binaries
node tools/inject_track_data.js

# Dry-run: show what would change without writing
node tools/inject_track_data.js --dry-run

# Inject a specific track only
node tools/inject_track_data.js --tracks san_marino france

# Inject all categories
node tools/inject_game_data.js --all
```

### Randomization

```bash
# Randomize in isolated workspace (recommended)
node tools/hack_workdir.js SMGP-1-01-12345

# Randomize in-place (modifies data/ directly)
node tools/randomize.js SMGP-1-01-12345

# Dry-run: show what would change
node tools/randomize.js SMGP-1-01-12345 --dry-run

# Restore original track data after in-place randomization
node tools/restore_tracks.js --verify
```

### Build and verify

```bash
# Assemble ROM only (gate for randomized builds)
cmd //c build.bat

# Assemble and check bit-perfect identity (gate for code/constant changes)
cmd //c verify.bat
```

### Testing

```bash
# Run all tests
node tools/tests/run.js

# Run specific test suite
node tools/tests/run.js --filter roundtrip
node tools/tests/run.js --filter rle
node tools/tests/run.js --filter track_validator
```

### Structural checks

```bash
# Run linters and structural checks
node tools/run_checks.js
```

---

## 13. Adding a new data category

To add a new category (e.g. team data) to the pipeline:

1. **Document the binary format** — add a section to `docs/data_formats.md`.
2. **Extract to `data/<category>/`** — write `tools/extract_<category>_data.js`
   that reads raw bytes from the ROM-backed ASM source (or from `orig.bin`) and
   writes binary files under `data/<category>/`.
3. **Emit JSON** — the extractor must also emit a `tools/data/<category>.json`
   with decoded, human-readable fields.
4. **Write injector** — `tools/inject_<category>_data.js` reads the JSON,
   re-encodes it, and writes binary files back to `data/<category>/`.
5. **Add ASM wrappers** — replace the `dc.b`/`dc.w` block in the relevant
   `src/*.asm` file with `incbin "data/<category>/..."` directives.
6. **Round-trip test** — add a test to `tools/tests/test_roundtrip.js` that
   verifies the no-op extract → inject produces a bit-identical ROM.
7. **Wire into unified CLI** — add `--<category>` flag to
   `tools/extract_game_data.js` and `tools/inject_game_data.js`.

Do not skip step 6.  Any editor or randomizer built on a category with no
round-trip test risks silent data corruption.

---

## 14. Known limitations

- **`track_config_data.asm` is not yet fully extracted.**  The Track_data table
  still uses `dc.l LabelName` for art pointer fields.  RAND-006 (art/config
  assignment) must handle this by patching pointers in the assembled binary or
  by building a dedicated patcher module rather than rewriting the ASM text.

- **Monaco arcade tracks share sign tilesets.**  Tracks 16, 17, and 18 use the
  `Monaco_arcade_post_sign_tileset_blob` region.  The injector must treat them
  consistently.  If the randomizer generates independent sign tilesets for these
  tracks, the blob must be duplicated or the sharing relationship must be broken
  by adding new labeled sections.

- **Lap targets are shared between adjacent tracks.**  Several tracks share
  lap target tables (USA uses Canada's targets, Canada uses Great Britain's,
  etc.).  The injector preserves this sharing; editors and randomizers must be
  aware that modifying one track's targets may affect another.

- **Art blobs are opaque.**  The compression format for tile data
  (`src/track_bg_data.asm`, `src/car_sprite_blobs.asm`, etc.) is not yet
  documented (task DATA-002).  Phase 3A/3B art assignment can only shuffle
  existing ROM art references; generating new art requires a working
  compressor/decompressor.

- **Z80 audio is not yet disassembled.**  The `src/audio_engine.asm` blob is
  opaque until AUDIO-001 is complete.  Music track assignment is possible by
  shuffling known command IDs, but new music requires full driver disassembly.

- **No web UI or GUI.**  All tooling is Node.js CLI.  A future goal is to
  expose the JSON layer via a simple local web editor, but this is out of scope
  for Phase 3.

---

## 15. File layout

```
smgp.asm                          Include hub (15 lines)
src/
  road_and_track_data.asm         incbin wrappers for 114+ track binary files
  track_config_data.asm           Track_data table (dc.l pointers + scalars)
  driving.asm                     Track consumer: curve/slope decompressor
  rendering.asm                   Track consumer: minimap, background scroller
  ai.asm                          Sign parser, AI placement
  ...

data/
  README.md                       This directory's pipeline conventions
  tracks/
    manifest.json                 Master list of 19 tracks with scalar fields
    san_marino/                   One subdirectory per track (19 total)
      curve_data.bin              Decompressed curve stream (1 byte/step)
      curve_data_rle.bin          ROM RLE-encoded form (incbin target)
      slope_visual.bin            Decompressed visual slope stream
      slope_visual_rle.bin        ROM RLE-encoded form (incbin target)
      slope_phys.bin              Decompressed physical slope stream
      slope_phys_rle.bin          ROM RLE-encoded form (incbin target)
      sign_data.bin               Sign records (incbin target)
      sign_tileset.bin            Sign tileset records (incbin target)
      minimap_pos.bin             Minimap (x,y) pairs (incbin target)
      lap_targets.bin             BCD lap-time targets (incbin target)
    brazil/ france/ ... (18 more)
  art/                            (future) Compressed tile blobs
  text/                           (future) String data
  audio/                          (future) Z80 driver payload
  championship/                   (future) Race order / points tables

tools/
  extract_track_data.js           Track extractor: data/tracks/ → JSON
  inject_track_data.js            Track injector:  JSON → data/tracks/
  restore_tracks.js               Restores original data after randomization
  randomize.js                    Unified randomizer entry point
  hack_workdir.js                 Isolated build workspace system
  extract_game_data.js            Unified extractor (--tracks/--teams/--championship/--all)
  inject_game_data.js             Unified injector  (same flags)
  run_checks.js                   Structural linters and integrity checks
  check_split_addresses.js        Verify address stability after splits
  randomizer/
    track_randomizer.js           Curve / slope / sign / minimap generation
    track_validator.js            Track data constraint validator
    team_randomizer.js            Team/car stats randomizer
    championship_randomizer.js    Race order randomizer
  data/
    tracks.json                   Decoded track data (Layer 3 edit surface)
    tracks.orig.json              Backup created during randomization
    teams.json                    Team/car stats (Layer 3)
    championship.json             Championship data (Layer 3)
    strings.json                  (future) Game text
  tests/
    run.js                        Test runner / aggregator
    test_roundtrip.js             Extract → inject round-trip tests
    test_rle.js                   RLE encode/decode tests
    test_track_validator.js       Track validator correctness tests
    test_team_data.js             Team extract/inject round-trip tests
    test_championship_data.js     Championship extract/inject round-trip tests
    test_randomizer.js            Randomizer unit tests
    test_checks.js                Structural check tests
  editor/
    track_editor.js               Track editor CLI
    team_editor.js                Team/car stats editor CLI
    championship_editor.js        Championship editor CLI
    text_editor.js                (future) Text editor CLI
  lib/
    binary.js                     Read/write helpers for binary buffers
    rom.js                        ROM load/save + path constants
    json.js                       JSON read/write with stable formatting
    fs.js                         Filesystem utilities
    cli.js                        Argument parsing utilities
  index/
    symbol_map.js / symbol_map.json  Label→address map from smgp.lst
    strings.js / strings.json        All ROM text strings with addresses

docs/
  modding_architecture.md         This document (EDIT-001)
  randomizer_architecture.md      Randomizer design, seed format, modules
  data_formats.md                 Binary format specs for all data/ categories

build/
  workspaces/                     Temporary hack workspace directories
```

---

*See `docs/randomizer_architecture.md` for the randomizer seed format, flag
bits, PRNG algorithm, and module breakdown.*  
*See `docs/data_formats.md` for binary format specifications for all `data/`
categories.*  
*See `data/README.md` for the overall extraction pipeline conventions.*
