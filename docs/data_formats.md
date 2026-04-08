# Super Monaco GP — data/ Binary Format Specifications

Reference document for all binary formats used in the `data/` extraction pipeline.
Derived from reverse-engineering documented in `notes.txt`, `src/road_and_track_data.asm`,
`src/track_config_data.asm`, `src/driving.asm`, and `src/rendering.asm`.

See `data/README.md` for the overall pipeline architecture and directory layout.

---

## Table of Contents

1. [Track_data record (ROM table)](#1-track_data-record-rom-table)
2. [Curve data — decompressed format](#2-curve-data--decompressed-format)
3. [Curve data — ROM RLE encoding](#3-curve-data--rom-rle-encoding)
4. [Visual slope data — decompressed format](#4-visual-slope-data--decompressed-format)
5. [Visual slope data — ROM RLE encoding](#5-visual-slope-data--rom-rle-encoding)
6. [Physical slope data — decompressed format](#6-physical-slope-data--decompressed-format)
7. [Physical slope data — ROM RLE encoding](#7-physical-slope-data--rom-rle-encoding)
8. [Sign data record format](#8-sign-data-record-format)
9. [Sign tileset stream format](#9-sign-tileset-stream-format)
10. [Minimap position map](#10-minimap-position-map)
11. [Lap targets table](#11-lap-targets-table)
12. [Art/palette blobs](#12-artpalette-blobs)
13. [Validity constraints summary](#13-validity-constraints-summary)

---

## 1. Track_data record (ROM table)

Source: `src/track_config_data.asm` (label `Track_data`).  
RAM load: `Load_track_data` in `src/race.asm`.

Each entry is **$48 bytes (72 bytes)**. 19 entries total: indices 0–15 are
championship tracks in race order; indices 16–18 are arcade Monaco variants
(prelim, main, wet).

| Offset | Size | Field                    | Notes                                                     |
|--------|------|--------------------------|-----------------------------------------------------------|
| +$00   | .l   | minimap_tiles_ptr        | → compressed minimap tile graphics                        |
| +$04   | .l   | bg_tiles_ptr             | → compressed background tile graphics                     |
| +$08   | .l   | bg_tilemap_ptr           | → background tile mapping                                 |
| +$0C   | .l   | minimap_map_ptr          | → minimap tile mapping                                    |
| +$10   | .l   | bg_palette_ptr           | → 16-colour background palette (32 bytes)                 |
| +$14   | .l   | sideline_style_ptr       | → sideline style descriptor                               |
| +$18   | .l   | road_style_ptr           | → road style data                                         |
| +$1C   | .l   | finish_line_style_ptr    | → finish line style data                                  |
| +$20   | .w   | horizon_override         | 0 = default sky; 1 = special horizon colour patch         |
| +$22   | .w   | track_length             | Game distance units. Valid range: 329–8188.               |
| +$24   | .l   | sign_data_ptr            | → sign records (4 bytes each, $FFFF-terminated)           |
| +$28   | .l   | sign_tileset_ptr         | → sign tileset records (4 bytes each, $FFFF-terminated)   |
| +$2C   | .l   | minimap_pos_ptr          | → (x,y) signed byte pairs                                 |
| +$30   | .l   | curve_data_ptr           | → RLE-encoded curve data                                  |
| +$34   | .l   | slope_visual_ptr         | → RLE-encoded visual slope data                           |
| +$38   | .l   | slope_phys_ptr           | → RLE-encoded physical slope data                         |
| +$3C   | .l   | lap_time_record_ptr      | → BCD lap-time best records ($FFFFFD00 + 8×index)         |
| +$40   | .l   | lap_targets_ptr          | → 15 × 3-byte BCD per-lap target table                    |
| +$44   | .l   | steering_divisors        | High word = straight divisor, low word = curve divisor    |

`data/tracks/manifest.json` mirrors this structure in JSON with paths to the
per-track binary files.

---

## 2. Curve data — decompressed format

**File:** `data/tracks/<slug>/curve_data.bin`  
**RAM buffer:** `Curve_data` at $00FF5B00, 2048 bytes max.  
**Consumer:** `Integrate_curveslope` in `src/driving.asm`.

One byte per track step forward. The decompressor (`Load_track_curve_data` /
`Update_slope_data`) fills the buffer once per lap-load; the engine reads 40
bytes ahead each frame.

### Byte encoding

| Value     | Meaning                                           |
|-----------|---------------------------------------------------|
| $00       | Straight                                          |
| $01–$2F   | Left turn; $01 = extreme, $2F = softest (47 values)|
| $41–$6F   | Right turn; $41 = softest, $6F = extreme (47 values)|
| $30–$3F   | **INVALID** — lower 6 bits ≥ 48; game freezes     |
| $70–$7F   | **INVALID** — same reason                         |
| $80–$FF   | Lap-wrap sentinel; engine resets read pointer      |

Sharpness index = `byte & $3F`.  Must be 0 or 1–47.  
`Road_displacement_table` has one guard entry (index 0) and 47 real sub-arrays.

### Constraints

- Total valid bytes (excluding sentinel) must be ≤ 2046 (`track_length` ≤ 8188
  gives ≤ 2047 steps after the `length>>2` indexing; the 40-byte look-ahead
  means the buffer must hold at least `track_length` bytes).
- Exactly one sentinel ($80+) must appear at the logical end of the stream.
- Values $30–$7F must never appear.

---

## 3. Curve data — ROM RLE encoding

**File:** `data/tracks/<slug>/curve_data_rle.bin`  
**Source label:** `<Track>_curve_data` in `src/road_and_track_data.asm`.

The ROM stores curve data as variable-length RLE records decoded into RAM by
the track loader.  Each segment describes a run of identical curve bytes
accompanied by a background horizontal scroll delta.

### Straight segment (3 bytes)

```
$00          ; segment type marker (straight)
<length_lo>  ; run length low byte
$00          ; background horizontal displacement (zero for straights)
```

### Curve segment (5 bytes)

```
<length_hi>  ; high byte of run length (e.g. $02 = +512 steps)
<length_lo>  ; low byte of run length
<curve_byte> ; the decompressed curve value ($01–$2F or $41–$6F)
<bg_disp_hi> ; high byte of background horizontal scroll delta (signed)
<bg_disp_lo> ; low byte of background horizontal scroll delta (signed)
```

Total run length = `(length_hi × 256) + length_lo`.  
`bg_disp` is a 16-bit signed value added to the background scroll accumulator
per step.

### Terminator (2 bytes)

```
$FF  ; sentinel — also the lap-wrap byte placed at end of decompressed stream
$00  ; padding byte after sentinel
```

### Notes

- The decompressor distinguishes straights from curves by `length_hi`: if
  `length_hi == $00` and `curve_byte` (third byte) is $00, it is a straight.
  Non-zero `length_hi` forces a curve decode.  Implementations must reproduce
  this logic exactly for round-trip fidelity.
- `bg_disp` accumulates into `Background_horizontal_displacement` ($00FF6300);
  absolute displacement is stored, not delta, in the RAM buffer.

---

## 4. Visual slope data — decompressed format

**File:** `data/tracks/<slug>/slope_visual.bin`  
**RAM buffer:** `Visual_slope_data` at $00FF7300, 2048 bytes.  
**Consumer:** `Integrate_curveslope` → background vertical shift each frame.

### Byte encoding (identical to curve encoding)

| Value     | Meaning                                |
|-----------|----------------------------------------|
| $00       | Flat                                   |
| $01–$2F   | Downslope; $01 = extreme, $2F = softest|
| $41–$6F   | Upslope; $41 = softest, $6F = extreme  |
| $30–$3F   | **INVALID**                            |
| $70–$7F   | **INVALID**                            |
| $80+      | Sentinel / lap-wrap                    |

Same constraints as curve data.

---

## 5. Visual slope data — ROM RLE encoding

**File:** `data/tracks/<slug>/slope_visual_rle.bin`  
**Source label:** `<Track>_slope_data` in `src/road_and_track_data.asm`.

### Header (1 byte)

```
<init_disp>  ; initial vertical background displacement before first record
```

### Flat segment (3 bytes)

```
<len_hi>     ; high byte of run length
<len_lo>     ; low byte of run length
$00          ; slope byte = flat
```

### Slope segment (4 bytes)

```
<len_hi>      ; high byte of run length
<len_lo>      ; low byte of run length
<slope_byte>  ; decompressed slope value ($01–$2F or $41–$6F)
<bg_vert>     ; background vertical displacement delta (signed byte)
```

### Terminator

```
$FF
```

---

## 6. Physical slope data — decompressed format

**File:** `data/tracks/<slug>/slope_phys.bin`  
**RAM buffer:** `Physical_slope_data` at $00FF8300, ≥2048 bytes.  
**Consumer:** `Update_rpm` — negative = uphill RPM drag.

### Byte encoding

Signed bytes stored verbatim:

| Value     | Meaning              |
|-----------|----------------------|
| $FF (−1)  | Downhill             |
| $00       | Flat                 |
| $01       | Uphill               |

ROM tracks use only these three values.  Wider range (−128 to +127) is
technically valid given the signed arithmetic in `Update_rpm`, but values
beyond ±1 are untested and may cause extreme RPM effects.

---

## 7. Physical slope data — ROM RLE encoding

**File:** `data/tracks/<slug>/slope_phys_rle.bin`  
**Source label:** `<Track>_phys_slope_data` in `src/road_and_track_data.asm`.

Simpler format than visual slope — no header byte, no background displacement.

### Segment (3 bytes)

```
<len_hi>        ; high byte of run length
<len_lo>        ; low byte of run length
<phys_slope>    ; physical slope byte (signed: $FF=down, $00=flat, $01=up)
```

### Terminator

```
$FF
```

**Important quirk:** The $FF terminator acts as the `len_hi` byte of a phantom
final record, so the decoder consumes 2 more bytes after it.  The last real
segment must be constructed so that its final 2 bytes are consumed cleanly (or
padded with $00 $00) to match the existing ROM tracks exactly.

---

## 8. Sign data record format

**File:** `data/tracks/<slug>/sign_data.bin`  
**Source label:** `<Track>_sign_data` in `src/road_and_track_data.asm`.  
**Consumer:** `Parse_sign_data` in `src/ai.asm`.

4-byte records, $FFFF-terminated.

### Record layout

| Bytes | Field    | Notes                                                           |
|-------|----------|-----------------------------------------------------------------|
| 0–1   | distance | .w  Track distance at which signs spawn (unsigned)             |
| 2     | count    | .b  Number of signs in this group                              |
| 3     | sign_id  | .b  Sign type: 0–$14 (20-entry dispatch table in ai.asm)       |

### Terminator

```
$FF $FF  ; two bytes ($FFFF as a word); triggers lap-wrap behaviour
```

### Spawn logic

A sign spawns when `(sign_distance − player_distance) < $0078` (120 units).  
Signs in a group are spaced 16 distance units apart.  
When `(track_length − player_distance) < 120`, the finish line blocks all
sign spawns regardless.

### Valid sign_id values

0–$14 (20 types, per dispatch table at `Sign_spawn_table` in `src/ai.asm`).

---

## 9. Sign tileset stream format

**File:** `data/tracks/<slug>/sign_tileset.bin`  
**Source label:** `<Track>_sign_tileset` in `src/road_and_track_data.asm`.  
**Consumer:** `Parse_tileset_for_signs` in `src/ai.asm`.

4-byte records, $FFFF-terminated.

### Record layout

| Bytes | Field               | Notes                                              |
|-------|---------------------|----------------------------------------------------|
| 0–1   | distance            | .w  Track distance at which this tileset applies   |
| 2–3   | tileset_byte_offset | .w  Byte offset into sign tile graphics data        |

### Terminator

```
$FF $FF
```

---

## 10. Minimap position map

**File:** `data/tracks/<slug>/minimap_pos.bin`  
**Source label:** `<Track>_minimap_pos` in `src/road_and_track_data.asm`.  
**Consumer:** `Update_minimap` / `Render_minimap` in `src/rendering.asm`.

Flat array of **signed byte pairs (x, y)**.  No explicit length field; the
array must contain at least `(track_length >> 5) + 1` pairs.

### Minimum size

| track_length | min pairs | min bytes |
|-------------|-----------|-----------|
| 3392        | 107       | 214       |
| 6144        | 193       | 386       |
| 7040        | 221       | 442       |
| 7744        | 243       | 486       |

Coordinate range: −128 to +127.  The minimap is rendered in a small rectangle
on the HUD; (0, 0) is approximately the start/finish line.

---

## 11. Lap targets table

**File:** `data/tracks/<slug>/lap_targets.bin`  
**Source label:** `<Track>_lap_targets` in `src/road_and_track_data.asm`.

15 × 3-byte BCD entries followed by a sentinel and pad byte.

### Entry format (3 bytes)

| Byte | Field        | Notes                                     |
|------|--------------|-------------------------------------------|
| 0    | minutes_BCD  | Packed BCD, e.g. $01 = 1 minute           |
| 1    | seconds_BCD  | Packed BCD, e.g. $23 = 23 seconds         |
| 2    | centisec_BCD | Packed BCD hundredths, e.g. $45 = 0.45 s  |

### Terminator

```
$99 $00 $00   ; sentinel entry (minutes = $99 signals end)
$00           ; trailing pad byte
```

Total size per track: (15 × 3) + 3 + 1 = **49 bytes**.

---

## 12. Art/palette blobs

**Directory:** `data/art/`  
**Status:** Not yet extracted (task DATA-001 / DATA-002 are prerequisites).

Art data is currently opaque compressed payloads.  Until DATA-002 documents the
compression format, `data/art/` files will be verbatim binary copies extracted
by address range from the ROM using the symbol map.

Known art source files:

| ASM source file                    | Content                                      |
|------------------------------------|----------------------------------------------|
| `src/track_bg_data.asm`            | Per-track background tiles and tilemaps       |
| `src/car_sprite_blobs.asm`         | Car sprite compressed tile data               |
| `src/screen_art_data.asm`          | Title/result screen artwork                   |
| `src/driver_portrait_tiles.asm`    | Driver portrait tile data                     |
| `src/driver_portrait_tilemaps.asm` | Driver portrait tilemaps                      |
| `src/hud_and_minimap_data.asm`     | HUD graphics, minimap tile sets               |
| `src/result_screen_tiles_b.asm`    | Secondary result screen tile data             |

Compression: believed to be a custom Huffman variant.  Decompressor RAM at
`Decomp_code_table` ($FFFFFA00).  A streaming state machine at
`Decomp_stream_buf` ($FFFFC080) drives tile DMA during track load.

---

## 13. Validity constraints summary

These are the hard constraints for track data.  Violating any of them causes
crashes, visual glitches, or incorrect gameplay.  The track validator
(`tools/randomizer/track_validator.js`, task RAND-007) enforces all of them.

### Track length

- Minimum: **329** (rendering tables have a length-329 lower bound check)
- Maximum safe: **8188** (decompressed buffers are 2048 bytes; `length>>2` indexes them)
- Hard absolute max: 65415 (signed 16-bit arithmetic wraps at 65536)
- Recommended range: 3400–8000

### Curve bytes

- Valid: `$00`, `$01–$2F`, `$41–$6F`
- Forbidden: `$30–$7F` (undefined table indices — game freezes)
- Exactly one sentinel (`$80+`) at logical end of stream
- Decompressed stream must fit in 2048 bytes

### Slope bytes (visual and decompressed physical)

- Same encoding as curve bytes; same forbidden range
- Same sentinel rule

### Physical slope bytes (decompressed)

- Signed byte; only $FF, $00, $01 are tested in ROM tracks
- Values outside ±1 are technically valid but untested

### Steering divisors

- Both straight and curve divisors must be **non-zero** (DIVS instruction; zero
  causes division-by-zero trap)
- Typical value: $002B (43); Wet Monaco: $002F/$0038

### Sign data

- `sign_id` must be in range 0–$14
- Terminated by $FFFF word
- Sign distances must be positive and less than `track_length`

### Minimap position map

- Must contain at least `(track_length >> 5) + 1` pairs

### Lap targets

- Must end with $99,$00,$00 sentinel + one $00 pad byte
- 14 real entries + 1 sentinel = 15 total

### RLE encoding

- Straight segments: `$00, <len_lo>, $00` (3 bytes)
- Curve segments: `<len_hi>, <len_lo>, <curve_byte>, <bg_disp_hi>, <bg_disp_lo>` (5 bytes)
- Total encoded size is not directly constrained, but the decompressed stream must
  fit in 2048 bytes
- Terminator: `$FF, $00`
