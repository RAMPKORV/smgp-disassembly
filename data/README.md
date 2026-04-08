# Super Monaco GP — data/ directory

This directory is the **binary source-of-truth layer** for all structured game data
extracted from the Super Monaco GP ROM.  It is modeled after the vermilion project's
top-level `data/` tree.

The extraction pipeline runs in two stages:

```
ROM / ASM source
  └─ tools/extract_*.py  →  data/<category>/  (binary + manifest .json files)
                               └─ tools/data/*.json  (structured edit layer)
                                    └─ tools/inject_*.py  →  data/<category>/  →  ASM wrappers
```

**Important:**  As of EXTR-000 (complete), the ASM source for track data
(`src/road_and_track_data.asm`) uses `incbin` directives that reference files
in `data/tracks/`.  **`data/tracks/` is now the authoritative edit surface for
track data** — never edit the `incbin` target files by hand; always go through
`tools/data/tracks.json` + `tools/inject_track_data.py`.  Other categories
(art, text, audio, championship) are still in `dc.b`/`dc.w`/`dc.l` form and
will be migrated as their extraction tasks (DATA-001, EXTR-003–006) land.
See `docs/modding_architecture.md` for the full pipeline architecture.

---

## Directory layout

```
data/
  tracks/               Per-track binary streams and manifests (EXTR-000 target)
  art/                  Compressed tile blobs, palettes, tilemaps (DATA-001 target)
  text/                 String tables and message data (EXTR-005 target)
  audio/                Z80 driver payload and music/SFX data (AUDIO-001 target)
  championship/         Race order, points tables, AI data (EXTR-006 target)
```

---

## tracks/

Populated by `tools/extract_track_data.py` (task EXTR-001), consumed by
`tools/inject_track_data.py` (EXTR-002) and `tools/randomizer/track_randomizer.py`
(RAND-002 through RAND-007).

Planned file naming convention (one subdirectory per track):

```
data/tracks/
  manifest.json                   Master track table: 19 entries with scalar fields
                                  and paths to each per-track binary file.
  san_marino/
    curve_data.bin                Decompressed curve byte stream (one byte per step)
    curve_data_rle.bin            ROM RLE-encoded form (round-trip reference)
    slope_visual.bin              Decompressed visual slope stream
    slope_visual_rle.bin          ROM RLE-encoded form
    slope_phys.bin                Decompressed physical slope stream
    slope_phys_rle.bin            ROM RLE-encoded form
    sign_data.bin                 Sign records (4 bytes each, $FFFF terminated)
    sign_tileset.bin              Sign tileset records (4 bytes each, $FFFF terminated)
    minimap_pos.bin               Minimap (x,y) byte pairs
    lap_targets.bin               15 × 3-byte BCD lap-time targets + sentinel + pad
  brazil/
    ...
  (one directory per track, snake_case, 19 total)
```

Track names (index order matches Track_data table in track_config_data.asm):

| Index | Name              | ASM prefix          |
|-------|-------------------|---------------------|
|  0    | San Marino        | `San_Marino_`       |
|  1    | Brazil            | `Brazil_`           |
|  2    | France            | `France_`           |
|  3    | Hungary           | `Hungary_`          |
|  4    | West Germany      | `West_Germany_`     |
|  5    | USA               | `Usa_`              |
|  6    | Canada            | `Canada_`           |
|  7    | Great Britain     | `Great_Britain_`    |
|  8    | Italy             | `Italy_`            |
|  9    | Portugal          | `Portugal_`         |
| 10    | Spain             | `Spain_`            |
| 11    | Mexico            | `Mexico_`           |
| 12    | Japan             | `Japan_`            |
| 13    | Australia         | `Australia_`        |
| 14    | Monaco (champ)    | `Monaco_`           |
| 15    | (unused / TBD)    |                     |
| 16    | Monaco prelim     | `Monaco_Prelim_`    |
| 17    | Monaco main       | `Monaco_Main_`      |
| 18    | Monaco wet        | `Monaco_Wet_`       |

`manifest.json` schema (one entry per track):

```json
{
  "tracks": [
    {
      "index": 0,
      "name": "San Marino",
      "slug": "san_marino",
      "track_length": 7040,
      "horizon_override": 0,
      "steering_divisors": { "straight": 43, "curve": 43 },
      "files": {
        "curve_data":        "san_marino/curve_data.bin",
        "curve_data_rle":    "san_marino/curve_data_rle.bin",
        "slope_visual":      "san_marino/slope_visual.bin",
        "slope_visual_rle":  "san_marino/slope_visual_rle.bin",
        "slope_phys":        "san_marino/slope_phys.bin",
        "slope_phys_rle":    "san_marino/slope_phys_rle.bin",
        "sign_data":         "san_marino/sign_data.bin",
        "sign_tileset":      "san_marino/sign_tileset.bin",
        "minimap_pos":       "san_marino/minimap_pos.bin",
        "lap_targets":       "san_marino/lap_targets.bin"
      },
      "art_refs": {
        "minimap_tiles":     "art/minimap_tiles_san_marino.bin",
        "bg_tiles":          "art/track_bg_tiles_san_marino.bin",
        "bg_tilemap":        "art/track_bg_tilemap_san_marino.bin",
        "minimap_map":       "art/minimap_map_san_marino.bin",
        "bg_palette":        "art/san_marino_bg_palette.bin",
        "sideline_style":    "art/san_marino_sideline_style.bin",
        "road_style":        "art/san_marino_road_style.bin",
        "finish_line_style": "art/san_marino_finish_line_style.bin"
      }
    }
  ]
}
```

### Round-trip guarantee

Before any editor or randomizer depends on the pipeline, extraction and injection
must pass a **no-op round-trip test**:

1. Extract all 19 tracks → `data/tracks/`
2. Inject unmodified `data/tracks/` back → rebuild ASM wrappers
3. `cmd //c verify.bat` must exit 0 (byte-identical ROM)

This test is defined in `tools/tests/test_roundtrip.py` (TEST-001).

---

## art/

Populated by `tools/extract_art_data.py` (task DATA-001 / future EXTR task).

Compressed tile blobs, palettes, tilemaps, and portrait data extracted from:
- `src/track_bg_data.asm`      — per-track background tile sets and tilemaps
- `src/car_sprite_blobs.asm`   — car sprite data
- `src/screen_art_data.asm`    — UI and screen artwork
- `src/driver_portrait_tiles.asm`  — driver portrait tiles
- `src/hud_and_minimap_data.asm`   — HUD and minimap tile graphics

Art blobs are currently opaque compressed payloads.  The compression format
(believed to be a custom Huffman variant; decompressor at `Decomp_code_table`
$FFFFFA00) must be documented (task DATA-002) before re-compression is possible.

For the track randomizer (phase 3A/3B), art assignment can shuffle references
to **existing** extracted blobs without re-compression.  Full art editing (new
tile sets) requires a working compressor, which is a lower-priority goal.

Planned naming: `<label_name_lowercase>.bin`
Example: `art/track_bg_tiles_san_marino.bin`, `art/san_marino_bg_palette.bin`

---

## text/

Populated by `tools/extract_strings.py` (task EXTR-005).

Contains raw string/message data extracted from:
- `src/team_messages_data.asm`   — Japanese and English team messages
- `src/car_spec_text_data.asm`   — car specification text
- Text embedded in `src/menus.asm`, `src/endgame_data.asm`, etc.

The game uses a custom tile-mapped character encoding (not ASCII).
The encoding table must be documented before text editing is possible.

Files:
```
data/text/
  team_messages_jp.bin     Raw Japanese team message strings
  team_messages_en.bin     Raw English team message strings
  car_spec_text.bin        Car specification text strings
  menu_strings.bin         Menu and UI text (if separable)
  encoding_table.json      Character code → glyph mapping (once documented)
```

---

## audio/

Populated once the Z80 driver is documented (task AUDIO-001).

The Z80 driver payload is a single opaque blob in `src/audio_engine.asm`.
Until AUDIO-001 is complete, this directory holds only the raw payload binary.

Files:
```
data/audio/
  z80_driver.bin           Raw Z80 driver ROM payload (extracted verbatim)
  z80_driver_manifest.json Known offsets: command table, music entries, SFX entries
```

---

## championship/

Populated by `tools/extract_championship_data.py` (task EXTR-006).

Championship flow data extracted from:
- `src/gameplay.asm`   — race order tables, AI placement data
- `src/race.asm`       — track selection, championship mode logic
- `src/menus.asm`      — qualification thresholds

Files:
```
data/championship/
  race_order.bin           Championship track sequence (16 entries)
  points_table.bin         Points awarded by finishing position
  ai_placement_data.bin    Per-team AI speed/acceleration parameters
  manifest.json            Scalar fields and file paths
```

---

## Editing workflow

Once a category is fully extracted and the no-op round-trip passes:

1. Run the extractor:  `python tools/extract_game_data.py --tracks`
2. Edit JSON in `tools/data/tracks.json` (the structured edit layer)
3. Run the injector:  `python tools/inject_game_data.py --tracks`
4. Rebuild and verify: `cmd //c verify.bat`

For the **randomizer**, replace step 2 with:
`python tools/randomize.py --seed SMGP-1-FF-12345`

See `docs/data_formats.md` for binary format specifications.
See `docs/randomizer_architecture.md` for the full randomizer workflow (once written).

---

## Constraints

- **Never edit `data/` files by hand** after the extraction pipeline is live.
  Always go through the JSON edit layer or the editor CLIs.
- **`data/` files are not part of the ROM build.**  The assembler reads only
  `.asm` source files.  During phase 3A the ASM files remain authoritative;
  `data/` holds extracted copies for tooling use.
- **After EXTR-000 lands**, specific data regions will be replaced with
  `incbin data/tracks/...` wrappers in the ASM source, making `data/` the
  authoritative edit surface for those regions.
- **Round-trip tests must pass before any editor or randomizer is built.**
  See `tools/tests/test_roundtrip.py`.
