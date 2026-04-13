# Super Monaco GP Randomizer — User Guide

Task: RAND-012.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Quick start](#2-quick-start)
3. [Seed format](#3-seed-format)
4. [Flag bits](#4-flag-bits)
5. [Randomizer modules](#5-randomizer-modules)
6. [Command reference](#6-command-reference)
7. [Editors](#7-editors)
8. [Sharing seeds](#8-sharing-seeds)
9. [Known limitations](#9-known-limitations)
10. [FAQ](#10-faq)

---

## 1. Overview

The Super Monaco GP randomizer generates modified ROM binaries with different
track layouts, team stats, and championship structures.  Given the same seed
string and the same source ROM, two independent runs always produce
bit-identical output.

The randomizer ships with five independent modules:

| Module       | Flag   | What changes                                       |
|--------------|--------|-----------------------------------------------------|
| TRACKS       | `0x01` | Curve layouts, slope profiles, signs, minimap paths |
| TRACK_CONFIG | `0x02` | Art/road-style assignment, steering divisors        |
| TEAMS        | `0x04` | Acceleration tables, top speed, engine curves       |
| AI           | `0x08` | AI placement parameters and performance scores      |
| CHAMPIONSHIP | `0x10` | Championship race order, rival grid, lap-time table |

Modules can be combined freely.  `0x1F` (all five) produces a fully randomized
game.

---

## 2. Quick start

### Requirements

- Node.js 18+ on `PATH`
- `asm68k.exe` in the repo root (included)
- A built `out.bin` (run `build.bat` once after cloning)

### Run the randomizer

```batch
REM Randomize everything, seed 12345
node tools/randomize.js SMGP-1-1F-12345

REM Tracks only
node tools/randomize.js SMGP-1-01-99999

REM Championship race order only
node tools/randomize.js SMGP-1-10-42

REM Dry-run: validate without writing any files
node tools/randomize.js SMGP-1-1F-12345 --dry-run
```

The script modifies `tools/data/tracks.json` (and/or `teams.json`,
`championship.json`), re-injects the binary data, and reassembles `out.bin`.

### Restore the original

```batch
node tools/restore_tracks.js
```

This restores `tools/data/tracks.json` from the backup copy written during the
last randomization run and re-injects the original track data.

---

## 3. Seed format

```
SMGP-<version>-<flags_hex>-<seed_decimal>
```

| Field            | Example    | Meaning                                              |
|------------------|------------|------------------------------------------------------|
| `SMGP`           | `SMGP`     | Fixed prefix                                         |
| `<version>`      | `1`        | Randomizer format version (currently always `1`)     |
| `<flags_hex>`    | `1F`       | Upper-case hex bitmask of enabled modules            |
| `<seed_decimal>` | `12345`    | 32-bit integer PRNG seed (0–4294967295)              |

### Examples

```
SMGP-1-1F-12345      all five modules, seed 12345
SMGP-1-01-0          tracks only, seed 0
SMGP-1-00-42         no modules (identity / validation check), seed 42
SMGP-1-10-7777777    championship order only, seed 7777777
SMGP-1-1F-4294967295 all modules, maximum seed
```

### Rules

- `SMGP` prefix is case-sensitive.
- `<flags_hex>` is case-insensitive (`1f` and `1F` are both valid).
- `<seed_decimal>` is a plain decimal integer, no leading zeros required.
- Undefined flag bits (`0x20`–`0x80`) are reserved; they are accepted but
  currently ignored.

---

## 4. Flag bits

| Bit | Hex    | Name             | Description                                       |
|-----|--------|------------------|---------------------------------------------------|
| 0   | `0x01` | `FLAG_TRACKS`    | Randomize curve/slope/sign/minimap for all tracks |
| 1   | `0x02` | `FLAG_TRACK_CONFIG` | Shuffle art and road-style assignments         |
| 2   | `0x04` | `FLAG_TEAMS`     | Randomize team car stats (acceleration, top speed)|
| 3   | `0x08` | `FLAG_AI`        | Randomize AI performance parameters               |
| 4   | `0x10` | `FLAG_CHAMPIONSHIP` | Shuffle championship race order and grid data  |

### Convenience combinations

| Hex    | Modules active                          |
|--------|-----------------------------------------|
| `0x01` | Tracks only                             |
| `0x03` | Tracks + art config                     |
| `0x0C` | Teams + AI                              |
| `0x1F` | All five modules (full randomization)   |
| `0x00` | None (no-op; useful for round-trip test)|

---

## 5. Randomizer modules

### 5.1 TRACKS (`0x01`) — Track curve/slope/sign/minimap

Generates entirely new track layouts for all 19 tracks using a map-first
geometry pipeline:

- **Geometry** — Sample points inside the minimap canvas, build a closed loop,
  smooth/resample it, and keep that centerline as the source of truth.
- **Curves** — Project curve bytes/RLE from geometry instead of treating curve
  data as the shape authority.
- **Slopes** — Non-crossing tracks stay mostly flat; crossing-enabled tracks
  derive lower/upper branch separation from geometry so the lower branch reads
  as an underpass.
- **Signs** — Core sign spacing still follows stock-style runtime-safe rules,
  while crossing tracks add tunnel/under-bridge handling from transient
  geometry metadata.
- **Minimap** — Runtime minimap pairs and generated preview assets both come
  from geometry, but are validated separately so marker sync and preview
  packing regressions are caught independently.

Each track also rolls a deterministic 1-in-16 eligibility bit for a rare single
grade-separated crossing. When selected, the generator injects exactly one
crossing and rejects the result unless topology validation can confirm the
derived upper/lower separation.

All generated tracks pass `track_validator.validate_track()` before injection.

### 5.2 TRACK_CONFIG (`0x02`) — Art and road-style assignment

Shuffles which of the 16 art sets (background horizon, road texture, sideline
style, finishline style, palette) is assigned to each of the 16 championship
tracks.  The 3 non-championship arcade tracks are unaffected.

### 5.3 TEAMS (`0x04`) — Team car statistics

Within each valid pool, Fisher-Yates shuffles:
- `accel_index` assignments (which of the 4 acceleration profiles each team uses)
- `engine_index` assignments (which of the 6 engine RPM curves each team uses)

Also lightly perturbs steering/braking indices (±2, 40% chance per team) and
shuffles `tire_wear_multiplier` across teams.  Machine-screen stat bars are
re-derived from the shuffled characteristics so the garage screen stays
consistent.

### 5.4 AI (`0x08`) — AI placement parameters

- Shuffles `ai_performance_factor_by_team` (16 values, Fisher-Yates).
- Shuffles `ai_performance_table` rows (16 × 8 entries, Fisher-Yates).
- Lightly perturbs `post_race_driver_target_points` thresholds while enforcing
  the constraint `partner_threshold >= promote_threshold + 2`.

### 5.5 CHAMPIONSHIP (`0x10`) — Championship race order

- **Race order** — Fisher-Yates shuffle of slots 0–14.  Slot 15 (Monaco, the
  championship finale) is always kept fixed.
- **Rival grid** — Fisher-Yates shuffle of `rival_grid_base_table` (16 entries).
- **Rival delta** — Each of the 11 `rival_grid_delta_table` entries has a 50%
  chance of shifting ±1, clamped to the observed range [–3, +2].
- **Lap-time table** — The 14 inner word pairs of `pre_race_lap_time_offset_table`
  are shuffled; the leading BCD anchor and trailing terminator are fixed.

---

## 6. Command reference

### 6.1 `tools/randomize.js` — Unified randomizer CLI

```
node tools/randomize.js SEED [--dry-run] [--verbose]
```

| Option       | Description                                                    |
|--------------|----------------------------------------------------------------|
| `SEED`       | Seed string in `SMGP-v-flags-decimal` format                   |
| `--dry-run`  | Validate but do not write any files or ROM                     |
| `--tracks`   | Restrict randomization to selected track slugs                 |
| `--input`    | Use an alternate tracks JSON input                             |
| `--no-build` | Skip the in-root ROM build step                                |
| `--in-root`  | Debug-only mode that mutates the repo root with a checkpoint   |
| `--verbose`  | Print per-module detail                                        |

By default, `tools/randomize.js` forwards to the workspace-safe flow and does
not mutate the repo root.  Explicit `--in-root` runs create an in-root
checkpoint under `build/checkpoints/in_root_debug/`; use
`tools/restore_tracks.js` to restore and clear it.

**Output:** Workspace-safe runs write a randomized ROM under `build/roms/` by
default.  Explicit in-root builds modify repo-root `out.bin`, which is expected
to differ from `orig.bin` until restored.

### 6.2 `tools/restore_tracks.js` — Restore original data

```
node tools/restore_tracks.js [--verify]
```

Restores `tools/data/tracks.json` from its backup and re-injects original
track binaries.  It first restores any active in-root checkpoint and then falls
back to legacy `*.orig.*` backups if present.  `--verify` additionally runs
`verify.bat` to confirm the ROM is bit-perfect again.

### 6.3 `tools/hack_workdir.js` — Isolated build workspace

```
node tools/hack_workdir.js SEED [--output OUT.BIN] [--keep] [--force] [--dry-run] [--verbose]
node tools/hack_workdir.js --list
```

Copies the project to a temporary directory under `build/workspaces/<seed>/`,
runs the randomizer there, assembles the ROM, and copies the output binary
without touching the original source tree.  This is the recommended flow for
normal seed testing and refactor validation.

| Option       | Description                                              |
|--------------|----------------------------------------------------------|
| `--seed`     | Seed string                                              |
| `--output`   | Where to write the output ROM (default: `out_<seed>.bin`)|
| `--keep`     | Do not delete the workspace after a successful build     |
| `--force`    | Overwrite existing workspace                             |
| `--dry-run`  | Print what would happen; do not copy or build            |
| `--list`     | List all existing workspaces under `build/workspaces/`   |

---

## 7. Editors

The project includes interactive CLI editors for direct data editing without
randomization.  Changes are validated before saving and can be injected into
`out.bin` at any time.

### 7.1 Track editor

```
node tools/editor/track_editor.js [TRACK] COMMAND [OPTIONS]
```

Key subcommands: `list`, `show`, `set-field`, `set-curve`, `add-curve`,
`del-curve`, `set-slope`, `add-slope`, `del-slope`, `set-sign`, `add-sign`,
`del-sign`, `validate`, `inject`.

`TRACK` resolves by index (0–18), name substring, or slug.

### 7.2 Team editor

```
node tools/editor/team_editor.js COMMAND [TEAM] [OPTIONS]
```

Key subcommands: `list-teams`, `list-drivers`, `show`, `show-engine`,
`show-points`, `show-accel`, `set-ai-factor`, `set-ai-table`, `set-car`,
`set-engine`, `set-tire-wear`, `set-stats`, `set-thresholds`, `set-points`,
`set-accel-mod`, `validate`, `inject`.

### 7.3 Championship editor

```
node tools/editor/championship_editor.js COMMAND [ARGS] [OPTIONS]
```

Key subcommands: `show-order`, `show-points`, `show-thresholds`, `show-rivals`,
`show-lap-times`, `show-ai-factor`, `show-ai-table`, `show-ai-placement`,
`set-order`, `move-track`, `set-points`, `set-threshold`, `set-rival-base`,
`set-rival-delta`, `set-ai-factor`, `set-ai-table`, `validate`, `inject`.

---

## 8. Sharing seeds

A seed string fully specifies the ROM modification.  To share a randomized ROM
with someone:

1. Send them the seed string (e.g. `SMGP-1-1F-12345`) and the version of this
   repo (git commit hash).
2. They run `node tools/randomize.js SMGP-1-1F-12345` on their local
   build and get an identical `out.bin`.

Alternatively, use `hack_workdir.js` to produce a standalone `out.bin` that
can be loaded directly in an emulator without any additional steps.

```batch
node tools/hack_workdir.js SMGP-1-1F-12345 --output smgp_random_12345.bin
```

---

## 9. Known limitations

| Limitation | Details |
|---|---|
| **Monaco is always the final race** | Slot 15 is hardcoded as the championship finale.  The race order randomizer shuffles only slots 0–14. |
| **Art assets are fixed** | The randomizer shuffles existing art assignments; it cannot generate new background art or sprites (requires a tile decompressor — DATA-002). |
| **Z80 audio is untouched** | Music/SFX assignments are not randomized (requires AUDIO-001). |
| **Text is not randomized** | Driver names, team messages, and sign text cannot be randomized until EXTR-005 is implemented. |
| **Randomized ROMs do not pass `verify.bat`** | `verify.bat` checks against the original SHA256 and will always fail for a randomized ROM.  Use `build.bat` (assembler exit 0) as the correctness gate instead. |
| **Track art re-use** | Multiple championship tracks may end up sharing the same art set after a shuffle (this is consistent with some original ROM tracks doing the same). |
| **No prelim-only randomization** | The 3 non-championship (arcade) tracks are always excluded from the championship art shuffle. |
| **Crossing support is tooling-first** | The rare single-crossing path currently relies on geometry-derived previews and tunnel-style lower-branch handling. If that ever proves unreadable or behaviorally wrong, runtime/ASM work is a later explicit escalation rather than an implied documented bridge system. |

---

## 10. FAQ

**Q: How do I run the randomizer on Windows?**

```batch
node tools/randomize.js SMGP-1-1F-12345
```

Requires Node.js 18+ on `PATH`.  No additional packages needed (standard library only).

---

**Q: The ROM doesn't load in my emulator after randomization.  What happened?**

The most common causes are:

1. The assembler produced an error — check the output of `build.bat` for
   `errors(s)` messages.
2. A randomized track exceeded its binary size budget — the validator should
   have caught this before injection, but run `node tools/randomize.js
   YOUR-SEED --dry-run` to check.
3. The Sega header checksum was not updated — currently, `build.bat` does not
   update the checksum word.  Some emulators show a "checksum error" screen but
   continue to run; Exodus emulator is recommended for testing.

---

**Q: Does the seed need to be kept secret?**

No.  The seed fully determines the output; secrecy provides no benefit.
Sharing the seed is the intended distribution mechanism (see §8).

---

**Q: Can I use the same seed on different versions of the randomizer?**

Seeds are versioned by the `<version>` field.  Version `1` seeds are tied to
the current module layout and PRNG derivation scheme defined in
`docs/randomizer_architecture.md §4`.  A future version `2` would increment
the version field and may produce different output for the same decimal seed.

---

**Q: What is a "no-op seed"?**

`SMGP-1-00-0` has flags `0x00` so no modules run.  The output ROM should be
bit-identical to the input.  This is the round-trip correctness test and is
automatically verified by the test suite (`tools/tests/test_randomizer_smoke.js`).

---

**Q: How do I run all the tests?**

```batch
node tools/tests/run.js
```

All 3672 tests should pass on an unmodified checkout.  After randomization,
restore the original data first:

```batch
node tools/restore_tracks.js
node tools/tests/run.js
```

---

**Q: How do I verify the original ROM after editing?**

```batch
node tools/restore_tracks.js --verify
```

This restores track data and runs `verify.bat` to confirm the SHA256 matches
`orig.bin`.

---

**Q: Can I combine a randomized seed with manual editor changes?**

Yes.  Run the randomizer first, then use the editors to fine-tune specific
values.  All editors validate before saving and inject directly into `out.bin`.

---

*See also: `docs/randomizer_architecture.md` (technical design) and
`docs/modding_architecture.md` (data pipeline and extract/inject workflow).*
