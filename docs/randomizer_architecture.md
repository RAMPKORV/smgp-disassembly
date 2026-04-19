# Super Monaco GP Randomizer — Architecture Reference

Design document for the track randomizer and game editor.  
Task: RAND-001.  Prerequisite: EXTR-001 (track data extraction pipeline complete).

---

## Table of Contents

1. [Goals and scope](#1-goals-and-scope)
2. [Seed format](#2-seed-format)
3. [Flag bits](#3-flag-bits)
4. [PRNG and sub-seed derivation](#4-prng-and-sub-seed-derivation)
5. [Pipeline overview](#5-pipeline-overview)
6. [Module breakdown](#6-module-breakdown)
7. [Track generation strategy](#7-track-generation-strategy)
8. [Track validation rules](#8-track-validation-rules)
9. [Hack workspace system](#9-hack-workspace-system)
10. [Unified CLI reference](#10-unified-cli-reference)
11. [Known limitations](#11-known-limitations)
12. [File layout](#12-file-layout)

---

## 1. Goals and scope

The randomizer produces ROM binaries with modified game content derived from a
seed string.  Given the same seed and the same flag set, two independent runs on
the same source ROM must produce bit-identical output ROMs.

**In scope (Phase 3):**

| Module       | What it randomizes                                           |
|--------------|--------------------------------------------------------------|
| Track curves | Curve sequences, slope profiles, sign placement, minimap     |
| Track config | Art/road-style assignment, steering divisors, track length   |
| Team stats   | Acceleration tables, top speed, engine curve (RAND-008)      |
| Championship | Race order, points table, qualification thresholds (RAND-009)|

**Out of scope (Phase 4+):**

- New art assets (requires working decompressor — DATA-002)
- Z80 audio remixing (requires AUDIO-001)
- Driver name / text randomization (requires EXTR-005)

---

## 2. Seed format

```
SMGP-<version>-<flags_hex>-<seed_decimal>
```

### Components

| Field          | Length   | Meaning                                                  |
|----------------|----------|----------------------------------------------------------|
| `SMGP`         | fixed    | Magic prefix identifying this as a Super Monaco GP seed  |
| `<version>`    | 1 digit  | Randomizer version (currently `1`)                       |
| `<flags_hex>`  | 2+ hex   | Upper-case hexadecimal flag bitmask (see §3)             |
| `<seed_decimal>` | 1–10 digits | Base-10 PRNG seed (0–4294967295)                  |

### Examples

```
SMGP-1-FF-12345      # all flags enabled, seed 12345
SMGP-1-01-99999      # tracks only, seed 99999
SMGP-1-00-0          # no randomization (identity check / validation only)
SMGP-1-1F-42         # tracks + teams, seed 42
```

### Parsing

```python
import re
SEED_RE = re.compile(r'^SMGP-(\d+)-([0-9A-Fa-f]+)-(\d+)$')
m = SEED_RE.match(seed_str)
if not m:
    raise ValueError(f'Invalid seed format: {seed_str!r}')
version = int(m.group(1))
flags   = int(m.group(2), 16)
seed    = int(m.group(3))
```

---

## 3. Flag bits

The `<flags_hex>` field is a bitmask.  Undefined bits are reserved and must be
zero.

| Bit | Hex   | Module           | Description                                          |
|-----|-------|------------------|------------------------------------------------------|
| 0   | 0x01  | RAND_TRACKS      | Randomize track curves, slopes, signs, minimap       |
| 1   | 0x02  | RAND_TRACK_CONFIG| Shuffle art/road style assignment per track          |
| 2   | 0x04  | RAND_TEAMS       | Randomize team car-stats (acceleration, top speed)   |
| 3   | 0x08  | RAND_AI          | Randomize AI placement parameters                    |
| 4   | 0x10  | RAND_CHAMPIONSHIP| Shuffle championship race order                      |
| 5   | 0x20  | RAND_SIGNS       | Randomize sign placement independently of track gen  |
| 6   | 0x40  | reserved         | —                                                    |
| 7   | 0x80  | reserved         | —                                                    |

Convenience constants:

```python
FLAG_TRACKS       = 0x01
FLAG_TRACK_CONFIG = 0x02
FLAG_TEAMS        = 0x04
FLAG_AI           = 0x08
FLAG_CHAMPIONSHIP = 0x10
FLAG_SIGNS        = 0x20
FLAG_ALL          = 0x3F
```

---

## 4. PRNG and sub-seed derivation

### PRNG algorithm

32-bit xorshift (xorshift32), matching the algorithm used in the Vermilion
reference project for consistency and portability.

```python
class XorShift32:
    def __init__(self, seed):
        self.state = seed if seed != 0 else 1  # zero seed is invalid

    def next(self):
        x = self.state
        x ^= (x << 13) & 0xFFFFFFFF
        x ^= (x >> 17) & 0xFFFFFFFF
        x ^= (x <<  5) & 0xFFFFFFFF
        self.state = x & 0xFFFFFFFF
        return self.state

    def rand_int(self, lo, hi):
        """Return a random integer in [lo, hi] inclusive."""
        span = hi - lo + 1
        return lo + (self.next() % span)
```

### Sub-seed derivation

Each randomizer module receives its own seeded PRNG instance derived from the
master seed.  This ensures that enabling/disabling one module does not affect
the output of any other module.

```python
def derive_subseed(master_seed, module_id):
    """Derive a deterministic per-module seed from the master seed.

    module_id is a fixed integer constant for each randomizer module.
    Uses a simple mix to avoid correlated seeds.
    """
    x = (master_seed ^ (module_id * 0x9E3779B9)) & 0xFFFFFFFF
    # One round of xorshift to further decorrelate
    x ^= (x << 13) & 0xFFFFFFFF
    x ^= (x >> 17) & 0xFFFFFFFF
    x ^= (x <<  5) & 0xFFFFFFFF
    return x if x != 0 else 1
```

Module ID assignments (fixed, never changed between versions):

| Module ID | Constant              | Module                    |
|-----------|-----------------------|---------------------------|
| 1         | `MOD_TRACK_CURVES`    | Curve generation          |
| 2         | `MOD_TRACK_SLOPES`    | Slope generation          |
| 3         | `MOD_TRACK_SIGNS`     | Sign placement            |
| 4         | `MOD_TRACK_MINIMAP`   | Minimap generation        |
| 5         | `MOD_TRACK_CONFIG`    | Art/config assignment     |
| 6         | `MOD_TEAMS`           | Team car stats            |
| 7         | `MOD_AI`              | AI placement parameters   |
| 8         | `MOD_CHAMPIONSHIP`    | Championship race order   |

---

## 5. Pipeline overview

```
Original ROM (orig.bin)
  └─ tools/extract_track_data.js   → data/tracks/ (EXTR-000, already done)
       └─ tools/extract_track_data.js → tools/data/tracks.json (EXTR-001, done)

tools/randomize.js SMGP-1-FF-12345
  ├─ Parse seed string → (version, flags, master_seed)
  ├─ Extract fresh JSON snapshot from data/ (or reuse existing tools/data/*.json)
  ├─ For each enabled module, run randomizer with derived sub-seed:
  │     tools/randomizer/track_randomizer.js  → modifies tracks.json in memory
  │     tools/randomizer/team_randomizer.js   → modifies teams.json in memory
  │     tools/randomizer/championship_randomizer.js → modifies championship.json
  ├─ Validate all modified data (tools/randomizer/track_validator.js)
  ├─ Inject all modified JSON back to data/ binaries:
  │     tools/inject_track_data.js   (writes data/tracks/<slug>/*.bin)
  │     tools/inject_team_data.js    (writes data/teams/*.bin)
  │     tools/inject_championship_data.js (writes data/championship/*.bin)
  ├─ Rebuild ROM:  cmd //c build.bat
  ├─ Verify ROM:   cmd //c verify.bat (SHA256 must match for no-op seed)
  └─ Output:  out.bin  (or hack_workdir copy if using --workspace)
```

The **no-op seed** `SMGP-1-00-0` (zero flags) must produce a bit-identical ROM.
This is the round-trip correctness test run on every CI check.

---

## 6. Module breakdown

### tools/randomizer/track_randomizer.js (RAND-002 through RAND-006)

Primary deliverable.  Generates entirely new track layouts for all 19 tracks
(or a selected subset).  Sub-tasks:

- **RAND-002** Curve generation: produce random but driveable curve sequences.
- **RAND-003** Slope generation: generate visual + physical slope profiles.
- **RAND-004** Sign placement: place road signs at appropriate intervals.
- **RAND-005** Minimap generation: the active pipeline derives runtime minimap pairs and generated preview assets from transient geometry-state centerlines, with separate regression gates for runtime marker paths and course-select preview assets. Course-select contour emission is now locked by a direct structural contract rather than screenshot-only cleanup.
- **RAND-006** Art/config assignment: assign road styles and background art.

Each sub-task runs with its own derived PRNG seed (§4).

### tools/randomizer/track_validator.js (RAND-007)

Validates that generated track data satisfies all constraints documented in
`docs/data_formats.md §13` and `notes.txt TRACK DATA VALIDITY CONSTRAINTS`.
Called automatically by `tools/randomize.js` before injection.

Returns a list of `ValidationError` objects (empty = pass).

### tools/randomizer/team_randomizer.js (RAND-008)

Randomizes team car statistics within empirically-derived safe ranges.
Reads from `tools/data/teams.json` (requires EXTR-003).

### tools/randomizer/championship_randomizer.js (RAND-009)

Shuffles championship race order and adjusts points tables.
Reads from `tools/data/championship.json` (requires EXTR-006).

---

## 7. Track generation strategy

### Inputs

- All 19 original tracks decoded via `tools/data/tracks.json` (EXTR-001).
- Validity constraints from `docs/data_formats.md §13`.
- Statistical analysis of original track data (segment length distributions,
  curve-byte distributions, slope delta patterns) to derive generator priors.

### Frozen curve-first assumptions (TRR-001 baseline)

The current compact baselines in `tools/data/randomizer_baselines.json` and
`tools/data/minimap_validation_snapshots.json` intentionally freeze the
pre-revamp behaviour below. They are expected to drift once the map-first
pipeline lands, but only as an explicit, documented change.

- `curve_rle_segments` / `curve_decompressed` are currently treated as the
  randomized track-shape authority.
- Runtime `minimap_pos` generation and course-select preview generation both
  start from curve-derived path reconstruction.
- Sign placement and special-road planning consume curve windows instead of
  geometry-derived feature anchors.
- Candidate scoring historically preferred preview/curve agreement metrics over direct
  geometry-quality metrics; the active map-first branch now scores topology,
  resample-budget fit, and seam/start stability first.

### Map-first geometry contract (TRR-003)

Phase 1 of the revamp locks a single transient in-memory geometry object as the
future source of truth for randomized track shape:

```js
geometry_state = {
  canvas: {
    panel_width: 56,
    panel_height: 88,
    margin: 2,
    width: 52,
    height: 84,
  },
  sampled_points: [...],
  loop_points: [...],
  smoothed_centerline: [...],
  resampled_centerline: [...],
  topology: {
    crossing_count: 0,
    crossing_candidates: [...],
    eligible_for_grade_separated_crossing: false,
  },
  projections: {
    curve: null,
    slope: null,
    minimap_runtime: null,
    minimap_preview: null,
    sign_features: null,
  },
};
```

Canvas dimensions are tied directly to `tools/lib/minimap_layout.js`: the
geometry lives inside the 56x88 minimap panel (`7 * 8` by `11 * 8`) with a
locked 2-pixel safety margin on each side, leaving a 52x84 drawable region for
point sampling, smoothing, and preview fitting.

### Target track length

The current pipeline in `tools/randomizer/track_pipeline.js` keeps each track on
its original `track.track_length` budget, and phase 1 of the map-first revamp
keeps that rule. Geometry generation may change shape freely, but downstream
projection must still emit:

- `track_length >> 2` curve/slope steps for runtime road data.
- `track_length >> 6` runtime minimap `(x, y)` pairs.
- Separate runtime `minimap_pos` and course-select preview outputs, each with
  their own regression gates.

### Curve generation (RAND-002)

The curve byte stream is a sequence of segments.  Each segment is defined by:

```
(length, curve_byte, bg_disp)
```

Generation algorithm:

1. Pick total target length `L` in [4000, 7500].
2. Initialize position `pos = 0`, remaining `rem = L / 4` (compressed steps).
3. Loop until `rem <= 0`:
   a. Pick segment type: straight (weight ~40%) or curve (weight ~60%).
   b. For straight: pick length in [4, 80], set `curve_byte = 0`, `bg_disp = 0`.
   c. For curve:
      - Pick direction: left ($01–$2F) or right ($41–$6F) with equal probability.
      - Pick sharpness index `s` in [1, 47]: weight toward softer curves
        (s ~ 20–40 is most common in ROM tracks).
      - Set `curve_byte = s` (left) or `0x40 | s` (right).
      - Pick `bg_disp` in [−64, +64] × 256 (matching sign to curve direction).
      - Pick length in [4, 64].
   d. Enforce minimum straight gap: if last segment was a curve, insert a short
      straight (length 4–12) before the next curve.
   e. Append segment, decrement `rem`.
4. Clamp final segment length to prevent overshooting `L / 4`.
5. Append terminator: `{type: 'terminator', curve_byte: 0xFF, length: 0}`.
6. Validate: no $30–$7F bytes, exactly one terminator, total decompressed length
   equals `L / 4`, decompressed stream fits in 2048 bytes.

### Slope generation (RAND-003)

Visual slope mirrors the structure of curve data.  Physical slope is derived
from visual slope with a simpler model (only −1/0/+1 values used in ROM tracks).

Visual slope generation:
- Pick `initial_bg_disp` in [−20, +20].
- Generate flat/slope segments aligned to curve segment boundaries where
  possible (slopes complement curves).
- Slope values restricted to {$00, $01–$2F, $41–$6F} (same constraints as
  curves).  For ROM-compatible output, restrict to sharpness index ≤ 20.
- Each slope segment carries a `bg_vert_disp` signed byte in [−3, +3].

Physical slope:
- For each visual slope segment: if slope_byte is in $01–$10 (steep down),
  use phys_byte = $FF (−1); if in $41–$50 (steep up), use phys_byte = $01;
  otherwise $00.
- Physical slope terminator quirk must be reproduced exactly (see
  `docs/data_formats.md §7`).

### Sign placement (RAND-004)

Distribute sign records along the track.

Rules:
1. Minimum spacing between sign groups: 300 distance units.
2. Maximum sign count per group: 3.
3. Valid sign_id: 0–$14 (20 types).
4. No signs within 120 units of track end (finish-line blackout zone).
5. Generate 1 sign tileset change per ~1500 distance units.

Algorithm:
1. Walk through track distance in steps, maintaining a spacing counter.
2. At each candidate position (when spacing counter expires), roll to spawn
   a sign group (probability ~0.4).
3. Pick count in [1, 3], pick sign_id uniformly in [0, $14].
4. Reset spacing counter to rand_int(300, 600).
5. Generate sign tileset changes at fixed intervals using `tileset_offset = 0`
   (default tileset; full tileset randomization requires DATA-001).
6. Terminate sign_data with $FFFF, sign_tileset with $FFFF.

### Minimap generation (RAND-005)

The runtime minimap stream is consumed as a flat array of signed-byte `(x, y)`
pairs. `Compute_minimap_index` in `src/race_support.asm` shifts track distance
right by 5 and clears bit 0 before loading two bytes, so the real runtime
contract is one pair per 64 distance units: `track_length >> 6` total pairs.

Current implementation status:

1. Generate a closed top-down path from track data.
2. Sample exactly `track_length >> 6` points along that path.
3. Encode the result as signed-byte `(x, y)` pairs for `minimap_pos.bin`.

Revamp target:

1. Use the geometry-state centerline as the source of truth for both runtime
   marker-path generation and course-select preview generation.
2. Keep runtime `minimap_pos` generation and preview asset generation as
   separate deliverables with separate regression tests.
3. Preserve the runtime pair-count contract even after the geometry source of
   truth changes.
4. Crossing-enabled seeds roll a deterministic 1-in-16 eligibility bit per
   master seed and track slot. When selected, the generator injects exactly one
   grade-separated crossing into the centerline, carries transient lower/upper
   branch metadata in `geometry_state.topology.single_grade_separated_crossing`,
   and derives underpass/tunnel handling from projection data instead of adding
   persisted schema fields to `tools/data/tracks.json`.

#### Course-select contour contract

The course-select preview path is separate from runtime `minimap_pos` generation.
It now follows a structural contract derived from stock preview behavior and
enforced by minimap-specific tests.

- Road pixels are authoritative. The contour emitter starts from the styled road
  mask and emits course-select contour pixels from that mask instead of relying
  on broad post hoc tile pruning.
- Start-marker handling is separate. Marker pixels must remain a compact on-road
  horizontal bar and must not change contour pixels outside marker positions.
- Stock-style thickness is preserved. The rasterizer keeps the existing 1px
  outline around the white road body plus the stock-style 2px right-side black
  extension where that straight-wall shape legitimately occurs.
- Legal roadless contour fragments are limited to structural seam roles such as
  two-ended bridges, narrow seam continuations, and anchored empty-cell
  continuations whose removal would damage contour topology.
- Illegal roadless contour fragments are removed. This includes detached orphan
  specks, detached mixed-cell outline spurs, and roadless single-handoff tails
  or stubs that do not improve contour connectivity.
- The remaining fallback cleanup is intentionally narrow. Any final pruning is
  limited to proven-illegal roadless single-handoff fragments and must refuse
  any deletion that would increase the number of black contour components.

Stock-oracle facts now locked by tests:

- Occupied stock minimap cells are dense (`>= 32` pixels).
- Occupied stock minimap cells touch left, right, and top edges, with only edge
  masks `1110` or `1111`.
- The occupied stock-cell vocabulary is limited to 12 signatures.

Primary structural guards live in:

- `tools/tests/test_generated_minimap_assets.js`
- `tools/tests/test_minimap_stock_contour_contract.js`
- `tools/tests/test_minimap_seed_fuzz.js`
- `tools/tests/test_randomizer_smoke.js`

### Art and config assignment (RAND-006)

For each generated track, assign:
- `bg_tiles_ptr`, `bg_tilemap_ptr`, `bg_palette_ptr` — from a pool of existing
  art assets cataloged by DATA-001.  Initially: shuffle assignments between
  existing tracks (no new art).
- `road_style_ptr`, `sideline_style_ptr` — shuffle between existing styles.
- `finish_line_style_ptr` — pick from 2–3 existing finish-line styles.
- `steering_divisors` — pick from {$002B002B, $002F0038} or generate a value
  in [$0028, $0035] for both straight and curve.
- `horizon_override` — 0 or 1; pick from {0: 0.8, 1: 0.2}.

Constraint: art pointer fields must point to valid labeled data in the ROM.
Until DATA-001 is complete, only existing ROM art labels may be used.

---

## 8. Track validation rules

Implemented in `tools/randomizer/track_validator.js` (RAND-007).

All checks from `docs/data_formats.md §13` are enforced.  The validator
returns a list of `ValidationError(track_index, field, message)` objects.

| Check                           | Field            | Condition                                  |
|---------------------------------|------------------|--------------------------------------------|
| Track length range              | `track_length`   | 329 ≤ length ≤ 8188                        |
| Curve byte validity             | `curve_bytes`    | All bytes in {$00, $01–$2F, $41–$6F, $80+}|
| Curve sentinel count            | `curve_bytes`    | Exactly one $80+ byte at stream end        |
| Curve buffer fit                | `curve_bytes`    | Decompressed length ≤ 2047 bytes           |
| Slope byte validity             | `slope_bytes`    | Same encoding rules as curve               |
| Slope sentinel count            | `slope_bytes`    | Exactly one $80+ byte at stream end        |
| Slope buffer fit                | `slope_bytes`    | Decompressed length ≤ 2047 bytes           |
| Decompressed length invariant   | all streams      | Decompressed length = track_length / 4     |
| Steering divisors non-zero      | `steering_*`     | Both values > 0                            |
| Sign ID range                   | `sign_data`      | All sign_id in [0, $14]                    |
| Sign data terminator            | `sign_data`      | Last record has distance = $FFFF           |
| Sign distances in range         | `sign_data`      | All distances < track_length               |
| Minimap size                    | `minimap_pos`    | len(pairs) = track_length >> 6            |
| Geometry topology               | `topology`       | zero proper crossings, or exactly one approved grade-separated crossing |
| Lap targets sentinel            | `lap_targets`    | Entry 14 = [$99, $00, $00]                 |

---

## 9. Hack workspace system

`tools/hack_workdir.js` (RAND-011) creates a safe isolated copy of the project
for each randomization run.  This prevents accidental modification of the
working tree's source files.

### Workflow

```
node tools/hack_workdir.js SMGP-1-FF-12345 [--output rom_output.bin]
```

1. Create a temporary directory under `build/workspaces/<seed>/`.
2. Copy the minimal set of files needed for a build:
   - `smgp.asm`, all `src/` modules, constants files, headers, macros
   - `data/tracks/` and other `data/` subdirectories
   - `tools/` (for inject scripts)
   - `asm68k.exe`, `build.bat`, `verify.bat`
3. Run `node tools/randomize.js <seed>` inside the workspace.
4. Run `build.bat` in the workspace.
5. Copy the resulting `out.bin` to `--output` (default: `out_<seed>.bin`).
6. On success, optionally delete the temporary directory.
7. Return exit code 0 on success, 1 on validation or build failure.

### Directory structure

```
build/workspaces/
  SMGP-1-FF-12345/
    smgp.asm
    src/
    data/
    tools/
    asm68k.exe
    build.bat
    verify.bat
    out.bin              <- randomized ROM
    randomizer.log       <- per-run log
```

---

## 10. Unified CLI reference

### tools/randomize.js

```
usage: node tools/randomize.js SEED [options]

options:
  --tracks SLUG ...     Only randomize the specified track slugs
  --no-validate         Skip validation step (dangerous; for debugging only)
  --dry-run             Show what would change without writing any files
  --verbose, -v         Print per-step statistics
```

### tools/extract_game_data.js (EXTR-007)

```
usage: node tools/extract_game_data.js [--tracks] [--teams] [--championship]
                                        [--strings] [--all] [--dry-run]
```

### tools/inject_game_data.js (EXTR-007)

```
usage: node tools/inject_game_data.js [--tracks] [--teams] [--championship]
                                        [--strings] [--all] [--dry-run]
```

---

## 11. Known limitations

- **Art pool is fixed:** Phase 3A/3B can only shuffle art assignments between
  existing ROM art regions.  New track visuals require a working decompressor
  (DATA-002, not yet implemented).

- **Z80 audio is not randomized:** Music track assignment per level is possible
  (shuffle existing IDs) but not implemented until AUDIO-001 is complete.

- **Text is not randomized:** Driver names, track names, and team messages are
  out of scope until EXTR-005 is complete.

- **Track count is fixed at 19:** The ROM's `Track_data` table is 19 entries
  and the championship flow references fixed track indices.  Adding new tracks
  requires changes to `track_config_data.asm` and championship logic.

- **Monaco arcade tracks share sign tilesets:** Tracks 17 and 18 share the
  `Monaco_arcade_post_sign_tileset_blob` region.  The randomizer must either
  treat them as a unit or copy the tileset data if it diverges.

- **Lap targets are not track-specific in ROM:** Several tracks share lap
  target tables (USA→Canada targets, Canada→Great Britain targets, etc.).
  The randomizer must be aware of these sharing relationships to avoid
  accidentally changing targets for the wrong track.

---

## 12. File layout

```
tools/
  randomize.js                  Unified randomizer entry point (RAND-010)
  hack_workdir.js               Workspace isolation system (RAND-011)
  extract_track_data.js         Track extractor: data/tracks/ → JSON (EXTR-001)
  inject_track_data.js          Track injector: JSON → data/tracks/ (EXTR-002)
  extract_game_data.js          Unified extractor entry point (EXTR-007)
  inject_game_data.js           Unified injector entry point (EXTR-007)
  randomizer/
    track_randomizer.js         Curve + slope + sign + minimap gen (RAND-002–005)
    team_randomizer.js          Team car stats randomizer (RAND-008)
    championship_randomizer.js  Race order randomizer (RAND-009)
    track_validator.js          Track data validator (RAND-007)
  tests/
    run.js                      Test runner / aggregator
    test_roundtrip.js           Extract→inject no-op tests (TEST-001, done)
    test_rle.js                 RLE encode/decode tests (TEST-003, done)
    test_track_validator.js     Validator tests (TEST-002)

docs/
  randomizer_architecture.md    This document
  data_formats.md               Binary format specs (DATA-003)
  modding_architecture.md       Full modding pipeline doc (EDIT-001)

data/
  tracks/                       Extracted track binaries (EXTR-000, done)
  art/                          Art blobs (DATA-001, pending)
  text/                         String data (EXTR-005, pending)
  audio/                        Z80 driver payload (AUDIO-001, pending)
  championship/                 Championship data (EXTR-006, pending)

tools/data/
  tracks.json                   Decoded track data JSON (EXTR-001, done)
  teams.json                    Team car stats JSON (EXTR-003, pending)
  championship.json             Championship flow JSON (EXTR-006, pending)
  strings.json                  Game text JSON (EXTR-005, pending)

build/workspaces/               Temporary hack workspace directories (RAND-011)
```

---

*See `data/README.md` for the overall extraction pipeline architecture.*  
*See `docs/data_formats.md` for binary format specifications.*  
*See `notes.txt` for track data validity constraints (DOC-008).*
