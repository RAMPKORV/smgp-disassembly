# Tooling Migration Inventory — Python → Node.js

**Task:** NODE-001  
**Status:** Complete  
**Date:** 2026-03-09

---

## Background

All project tooling must migrate from Python to Node.js/JavaScript.  
No new `.py` or `.ipynb` files should be added to the repository.  
This document classifies every Python file and Jupyter notebook and
records the migration action and target for each.

The three migration actions are:

| Action | Meaning |
|---|---|
| **PORT** | Actively used; must be ported to a Node.js equivalent before deletion |
| **DELETE** | Legacy one-shot helper; no longer useful; safe to delete without porting |
| **AUDIT** | Possibly useful; needs a short audit before deciding PORT or DELETE |

---

## Migration Policy

1. **No new Python tooling.** Contributors must never add new `.py` or `.ipynb` files.
   All new automation, editors, randomizers, tests, and linters must be JavaScript/Node.js.
2. **No extending existing Python tools.** Bug fixes or changes to Python files are only
   permitted as part of a concurrent porting effort.
3. **Deletion only after JS parity.** A Python file must not be deleted until its
   JavaScript replacement is committed and passing its own test suite.
4. **Run `verify.bat` before committing any deletion.** Deleting Python files does not
   change ROM bytes, so `verify.bat` should always pass; confirm it does.
5. **`tools/tests/run_tests.py` is the last Python file to delete.** It must be
   replaced by `tools/tests/run.js` first (NODE-003 / TEST-004).

---

## Actively Used — Must Port to Node.js (ACTION: PORT)

These files are on the active toolchain critical path. They must be ported before deletion.

### Core Checks and Indexes

| File | JS Target | Migration Task | Notes |
|---|---|---|---|
| `tools/run_checks.py` | `tools/run_checks.js` | NODE-003 | Runs 5 structural checks; called by pre-commit hook |
| `tools/check_split_addresses.py` | `tools/check_split_addresses.js` | NODE-003 | Compares symbol addresses against baseline; called by run_checks.py |
| `tools/index/symbol_map.py` | `tools/index/symbol_map.js` | NODE-003/TOOL-018 | Parses smgp.lst → tools/index/symbol_map.json; required by run_checks. Python file deleted (TOOL-018) |
| `tools/index/strings.py` | `tools/index/strings.js` | NODE-003 | Extracts all ROM text strings → tools/index/strings.json (765 lines, very complete) |

### Extract / Inject Pipeline

| File | JS Target | Migration Task | Notes |
|---|---|---|---|
| `tools/extract_track_data.py` | `tools/extract_track_data.js` | NODE-004 | Decodes all 19 tracks from data/tracks/ → tools/data/tracks.json |
| `tools/inject_track_data.py` | `tools/inject_track_data.js` | NODE-004 | Re-encodes tracks.json → data/tracks/ binary files; must preserve round-trip |
| `tools/extract_team_data.py` | `tools/extract_team_data.js` | NODE-004 | Reads 19 team tables from orig.bin → tools/data/teams.json |
| `tools/inject_team_data.py` | `tools/inject_team_data.js` | NODE-004 | Patches out.bin in-place at 19 known ROM addresses |
| `tools/extract_championship_data.py` | `tools/extract_championship_data.js` | NODE-004 | Reads 13 championship tables → tools/data/championship.json |
| `tools/inject_championship_data.py` | `tools/inject_championship_data.js` | NODE-004 | Patches out.bin in-place at 13 known ROM addresses |

### Editors

| File | JS Target | Migration Task | Notes |
|---|---|---|---|
| `tools/editor/track_editor.py` | `tools/editor/track_editor.js` | NODE-005 | Full track editing CLI; 8 subcommands; 580 lines |
| `tools/editor/team_editor.py` | `tools/editor/team_editor.js` | NODE-005 | Team/driver/car stats editor; ~580 lines |
| `tools/editor/championship_editor.py` | `tools/editor/championship_editor.js` | NODE-005 | Championship/progression editor; ~650 lines |

### Randomizer and Workspace

| File | JS Target | Migration Task | Notes |
|---|---|---|---|
| `tools/randomize.py` | `tools/randomize.js` | NODE-006 | Unified randomizer CLI; seed/flag parsing, full pipeline |
| `tools/restore_tracks.py` | `tools/restore_tracks.js` | NODE-006 | Restores tracks from backup; called after randomization |
| `tools/hack_workdir.py` | `tools/hack_workdir.js` | NODE-006 | Isolated build workspace system; copies project, randomizes, assembles |
| `tools/randomizer/track_randomizer.py` | `tools/randomizer/track_randomizer.js` | NODE-006 | Core track generation: curves, slopes, signs, minimap, art config |
| `tools/randomizer/track_validator.py` | `tools/randomizer/track_validator.js` | NODE-006 | Validates generated track data before inject/assemble |
| `tools/randomizer/team_randomizer.py` | `tools/randomizer/team_randomizer.js` | NODE-006 | Team/AI randomization with pool-preservation |
| `tools/randomizer/championship_randomizer.py` | `tools/randomizer/championship_randomizer.js` | NODE-006 | Championship race-order randomizer |

### Test Suite

| File | JS Target | Migration Task | Notes |
|---|---|---|---|
| `tools/tests/run_tests.py` | `tools/tests/run.js` | NODE-007 | Test runner / aggregator; discovers and runs all test_*.py |
| `tools/tests/test_roundtrip.py` | `tools/tests/test_roundtrip.js` | NODE-007 | 518 tests: encode/decode round-trips for all 19 tracks × 6 binary types |
| `tools/tests/test_track_validator.py` | `tools/tests/test_track_validator.js` | NODE-007 | 59 tests: validator against 19 ROM tracks + malformed inputs |
| `tools/tests/test_rle.py` | `tools/tests/test_rle.js` | NODE-007 | 213 tests: curve/slope/phys-slope RLE encode-decode |
| `tools/tests/test_randomizer_smoke.py` | `tools/tests/test_randomizer_smoke.js` | NODE-007 | 65 tests: end-to-end randomizer + assemble smoke test |
| `tools/tests/test_hack_workdir.py` | `tools/tests/test_hack_workdir.js` | NODE-007 | 66 tests: workspace seed validation, dry-run, copy logic |
| `tools/tests/test_art_config.py` | `tools/tests/test_art_config.js` | NODE-007 | 250 tests: art-config randomizer and ASM rebuild |
| `tools/tests/test_championship_data.py` | `tools/tests/test_championship_data.js` | NODE-007 | Championship extract/inject round-trip tests |
| `tools/tests/test_championship_editor.py` | `tools/tests/test_championship_editor.js` | NODE-007 | Championship editor CLI tests |
| `tools/tests/test_championship_randomizer.py` | `tools/tests/test_championship_randomizer.js` | NODE-007 | Championship randomizer tests |
| `tools/tests/test_team_data.py` | `tools/tests/test_team_data.js` | NODE-007 | Team extract/inject round-trip tests (2056 tests) |
| `tools/tests/test_team_editor.py` | `tools/tests/test_team_editor.js` | NODE-007 | Team editor CLI tests |
| `tools/tests/test_team_randomizer.py` | `tools/tests/test_team_randomizer.js` | NODE-007 | Team randomizer tests |
| `tools/tests/test_track_editor.py` | `tools/tests/test_track_editor.js` | NODE-007 | Track editor CLI tests |

### Package Init Files (Will Be Deleted with Python)

| File | JS Target | Notes |
|---|---|---|
| `tools/randomizer/__init__.py` | _(none)_ | Node.js uses CommonJS/ESM; no __init__.py needed |
| `tools/tests/__init__.py` | _(none)_ | Same; delete with NODE-008 |

---

## Legacy One-Shot Helpers — Safe to Delete (ACTION: DELETE)

These files were used during Phase 1–2 label-renaming work. The work is complete
(all 4221 labels named, 0 `loc_` definitions remaining). They have no ongoing utility.

| File | Reason for Deletion |
|---|---|
| `tools/batch12_rename.py` | One-shot batch rename; Phase 1 work complete |
| `tools/batch13_rename.py` | One-shot batch rename; Phase 1 work complete |
| `tools/batch14_rename.py` | One-shot batch rename; Phase 1 work complete |
| `tools/batch15_rename.py` | One-shot batch rename; Phase 1 work complete |
| `tools/batch16_rename.py` | One-shot batch rename; Phase 1 work complete |
| `tools/batch17_rename.py` | One-shot batch rename; Phase 1 work complete |
| `tools/batch18_rename.py` | One-shot batch rename; Phase 1 work complete |
| `tools/batch19_rename.py` | One-shot batch rename; Phase 1 work complete |
| `tools/batch20_rename.py` | One-shot batch rename; Phase 1 work complete |
| `tools/batch21_rename.py` | One-shot batch rename; Phase 1 work complete |
| `tools/batch22_rename.py` | One-shot batch rename; Phase 1 work complete |
| `tools/batch23_rename.py` | One-shot batch rename; Phase 1 work complete |
| `tools/batch24_rename.py` | One-shot batch rename; Phase 1 work complete |
| `tools/batch25_rename.py` | One-shot batch rename; Phase 1 work complete |
| `tools/batch26_rename.py` | One-shot batch rename; Phase 1 work complete |
| `tools/batch36_rename.py` | One-shot batch rename; Phase 1 work complete |
| `tools/fix_preservation_comments.py` | One-shot cleanup; all `;loc_XXXX` comments correct |
| `tools/replace_constants.py` | One-shot constant symbolization; work complete |
| `tools/split_constants.py` | One-shot file-split helper; constants split is complete |
| `tools/add_newline_before_functions.py` | One-shot formatting pass; complete |
| `tools/report_raw_ram_refs.py` | One-shot audit aid; raw-RAM audit complete |
| `tools/translate_hex.py` | One-shot hex→decimal translator; no longer needed |
| `tools/util.py` | Shared utility class for batch rename scripts; obsolete with them |
| `tools/Road_displacement.ipynb` | Exploratory notebook; findings documented in notes.txt |
| `tools/Render_slopes.ipynb` | Exploratory notebook; findings documented in notes.txt |
| `tools/Render_maps.ipynb` | Exploratory notebook; findings documented in notes.txt |
| `tools/Format_data.ipynb` | Exploratory notebook; findings documented in notes.txt |

**Deletion task:** NODE-008 (depends on NODE-001). Batch-delete all of the above in a
single commit that includes a `verify.bat` confirmation. No JS replacement needed.

---

## Needs Brief Audit Before Deciding (ACTION: AUDIT)

| File | Question | Recommendation |
|---|---|---|
| `tools/extract_track_blobs.py` | Is it still needed now that EXTR-000 extracted all track blobs and data/tracks/ is populated? | **DELETE** — EXTR-000 is done and data/tracks/ is committed; this script is superseded by `tools/extract_track_data.py`. |
| `tools/report_hidden_pointers.py` | Is the hidden-pointer scan still useful for future audit work? The audit is marked complete (PTR-001–003). | **DELETE** — Pointer audit complete; output already in `tools/index/hidden_pointer_candidates.json`. The script is historical; delete with NODE-008. |

Both are safe to include in the NODE-008 deletion batch.

---

## Summary Counts

| Action | Files |
|---|---|
| PORT (to Node.js) | 36 Python files (14 core/extract/editor, 15 test suite, 7 randomizer/workspace) |
| DELETE (no port needed) | 27 files (16 batch-rename, 7 legacy utilities, 4 Jupyter notebooks) |
| AUDIT → DELETE | 2 files (`extract_track_blobs.py`, `report_hidden_pointers.py`) |
| **Total Python/Jupyter** | **65 files** |

---

## Migration Sequence

The NODE tasks must be completed in dependency order:

```
NODE-001 (this doc)
  └── NODE-002: shared Node.js foundation (package.json, tools/lib/, tools/tests/run.js)
        ├── NODE-003: port run_checks, check_split_addresses, symbol_map, strings
        │     └── NODE-007: port test suite (depends on all PORT tasks)
        ├── NODE-004: port extract/inject pipeline
        │     └── NODE-005: port editors
        │           └── NODE-006: port randomizer + workspace
        └── NODE-008: delete legacy Python (depends on NODE-001 only)
              └── NODE-009: final cleanup after all JS replacements verified
```

---

## Porting Notes

### Key Python → JavaScript Patterns

| Python | JavaScript/Node.js |
|---|---|
| `open(path, 'rb').read()` | `fs.readFileSync(path)` → `Buffer` |
| `struct.unpack_from('>H', rom, off)` | `buf.readUInt16BE(off)` |
| `struct.unpack_from('>L', rom, off)` | `buf.readUInt32BE(off)` |
| `argparse.ArgumentParser` | `process.argv` + manual parsing, or `minimist` |
| `json.dump(data, f, indent=2)` | `JSON.stringify(data, null, 2)` + `fs.writeFileSync` |
| `subprocess.run([...], capture_output=True)` | `child_process.spawnSync(...)` |
| `Path(__file__).resolve().parent.parent` | `path.resolve(__dirname, '..', '..')` |
| `re.compile(r'...')` | `new RegExp('...')` |
| `unittest.TestCase` | Plain JS `assert` + lightweight test harness in `tools/tests/run.js` |
| `sys.exit(code)` | `process.exit(code)` |

### Round-Trip Fidelity Requirements

The following extract/inject pairs must preserve byte-identical output when fed
unmodified source data (no-op round-trip test required before each JS port ships):

- `extract_track_data` / `inject_track_data` — 114 binary files in data/tracks/
- `extract_team_data` / `inject_team_data` — 19 fixed-size tables in out.bin
- `extract_championship_data` / `inject_championship_data` — 13 tables in out.bin

All three Python implementations pass their no-op round-trips today. The JS ports
must pass the same tests before the Python originals are deleted.

### ROM Address Constants

Hardcoded ROM addresses in the Python tools (e.g. `TABLE = 0x3B9A2`) must be
preserved exactly in the JS ports. Do not symbolize or look up addresses at
runtime during the port — maintain the same hardcoded constants to keep the port
risk minimal. Symbolic lookup can be a follow-up improvement.

---

## Status Tracking

| Task | Description | Status |
|---|---|---|
| NODE-001 | This inventory document | **done** |
| NODE-002 | Shared Node.js foundation | **done** |
| NODE-003 | Port checks + indexes | **done** |
| NODE-004 | Port extract/inject pipeline | **done** |
| NODE-005 | Port editors | **done** |
| NODE-006 | Port randomizer + workspace | **done** |
| NODE-007 | Port test suite | **done** |
| NODE-008 | Delete legacy Python | **done** |
| NODE-009 | Final cleanup | **done** |
