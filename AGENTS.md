# AGENTS.md - Super Monaco GP Disassembly

## Project Overview

Matching disassembly of **Super Monaco GP** (Sega Mega Drive / Genesis, 1990).
The goal is to produce Motorola 68000 assembly source that assembles to a ROM
binary byte-identical to the original.

- **CPU:** Motorola 68000 (main) + Zilog Z80 (sound, not yet disassembled)
- **Assembler:** SN 68k (asm68k) version 2.53
- **Platform:** Sega Mega Drive / Genesis

## Build Commands

### Build the ROM
```batch
build.bat
```
Direct invocation: `asm68k /k /p /o ae- smgp.asm,out.bin,,smgp.lst`

Flags: `/k` keep symbol case, `/p` generate listing, `/o ae-` disable auto even-alignment.
Output: `out.bin` (ROM binary), `smgp.lst` (listing with addresses).

`smgp.lst` is a primary reverse-engineering aid. Use it when auditing hidden pointers,
matching tuple-encoded data to ROM addresses, locating embedded substructures inside
large `dc.b`/`dc.w` blobs, and verifying exact label/address placement.

### Verify Build (Bit-Perfect Check)
```batch
verify.bat
```
Builds the ROM and checks its SHA256 against the known-good hash. Exit 0 = bit-perfect,
exit 1 = mismatch or build failure.

**CRITICAL: After ANY code change, run `verify.bat`. A non-bit-perfect build is never
acceptable. Do not proceed until the build is clean.**

There are no unit tests -- bit-perfect verification is the only test.

## File Structure

```
smgp.asm              Include hub (15 lines) - assembles all modules
constants.asm          Include hub for the 4 constants files
macros.asm             Assembler macros (txt, vdpComm, stopZ80, etc.)
header.asm             ROM header and M68K exception vector table
init.asm               EntryPoint and hardware initialization
hw_constants.asm       VDP, Z80, I/O port register addresses
ram_addresses.asm      RAM address constants (~817 lines)
sound_constants.asm    Audio engine struct, music/SFX IDs
game_constants.asm     Menu state values, shift types, control types
src/                   11 code modules + 11 data modules (split source)
  core.asm             Core game loop and dispatch
  menus.asm            Title screen, menu navigation
  race.asm             Race setup and main race loop
  driving.asm          Player driving mechanics
  rendering.asm        Road/sprite rendering
  race_support.asm     Race support routines
  ai.asm               AI car behavior
  audio_effects.asm    Sound effect triggers
  objects.asm          Object system and sprite management
  endgame.asm          Results, credits, game over
  gameplay.asm         Gameplay data tables and binary blobs (largest file)
smgp_full.asm          Concatenated single-file reference (~44,500 lines)
notes.txt              Reverse-engineering notes (memory map, data formats)
todos.json             Project task/roadmap tracking
labels.json            Label reference count data
  tools/                 Node.js analysis/editing/randomizer utilities (not part of ROM build)
build.bat              Windows build script
verify.bat             SHA256 build verification
asm68k.exe             Bundled assembler binary
```

## Code Style - Assembly (M68K)

### Indentation
- **Tabs** for indentation (not spaces).
- Labels at column 0, no indentation.
- Instructions indented one tab from column 0.
- Operands separated from mnemonic by a tab.

### Instruction Formatting
- **Mnemonics are UPPERCASE** with **lowercase size suffixes**: `MOVE.w`, `LEA`, `BRA.b`, `CLR.l`, `CMPI.w`, `JSR`, `RTS`.
- **Registers are uppercase**: `D0`-`D7`, `A0`-`A7`, `SP`, `SR`, `USP`, `CCR`.
- **Hex literals** use `$` prefix with **uppercase** hex digits: `$FFFF9100`, `#$0F00`.
- **Decimal literals** for game-meaningful physical constants (RPM, speed, points).
- **Branch size hints** are explicit: `BRA.b`, `BNE.w`, `BSR.w`, `BCC.b`.

### Naming Conventions

**Named labels** - use `Title_Snake_Case`:
- Routines: `Update_shift`, `Update_rpm`, `Render_speed`, `Binary_to_decimal`
- Data: `Acceleration_data`, `Engine_data`, `Track_data`
- Some data tables use **PascalCase**: `PointsAwardedPerPlacement`, `DriverPortraitTiles`
- Prefer `Title_Snake_Case` for new labels; PascalCase is acceptable for data tables.

**Preservation comments** - all `loc_XXXX` definitions have been renamed. ~3099 preservation
comments (`;loc_XXXX` above the renamed label) remain throughout the codebase.

**Constants** (in constants files):
- RAM addresses / variables: `Title_Snake_Case` (`Player_shift`, `Track_index`)
- Hardware registers: `Title_Snake_Case` (`VDP_control_port`, `Z80_bus_request`)
- Key constants: `UPPER_SNAKE_CASE` (`KEY_START`, `KEY_A`, `KEY_UP`)
- Assignment syntax: `NAME = value` (not `equ`)

**Special labels**: `StartOfRom`, `EndOfRom`, `EntryPoint`, `Header`, `Vectors` (PascalCase).

### Comment Conventions
- Use `;` for inline comments after instructions.
- Document conditional logic with if/then/else pseudo-code:
  ```asm
  BTST.b  D5, Input_state_bitset.w ; if shift down key pressed
  BNE.w   loc_5A62                 ; then shift down
  ```
- Preserve the original ROM address as a comment when renaming a label:
  ```asm
  ;loc_59BC
  Update_shift:
  ```
- Document function inputs/outputs above complex routines:
  ```asm
  Integrate_curveslope:
  ; Inputs:
  ;D0 = "step" (distance travelled on track)
  ;D1 = value of curve/slope data at previous step, initially -1
  ```
- No file-level headers, copyright blocks, or section dividers.

### Data Definitions
- `dc.b` for bytes, `dc.w` for words, `dc.l` for longs.
- Long byte arrays: 32 comma-separated values per `dc.b` line.
- Pointer/address tables: one `dc.l` per line with descriptive comment.

## Code Style - Constants Files

Constants are split across 4 files, grouped by domain:
- `hw_constants.asm` -- VDP, Z80, I/O port registers
- `ram_addresses.asm` -- All RAM variable addresses (largest, ~817 lines)
- `sound_constants.asm` -- Audio engine addresses, music/SFX IDs
- `game_constants.asm` -- Menu states, shift types, control types

## Code Style - Node.js Tools

The `tools/` directory uses Node.js/JavaScript tooling only (not part of ROM build):
- **NEVER use Python** for new or updated tooling in this project
- **NEVER add `.py` files or Jupyter notebooks**; replace existing Python tooling with Node.js scripts
- Use JavaScript with Node.js for automation, extract/inject scripts, editors, randomizers, linters, and tests
- Prefer the Node.js standard library; keep dependencies minimal and justified
- Use **snake_case** for filenames when it matches existing tool naming
- Use **camelCase** for functions/variables and **UPPER_SNAKE_CASE** for constants inside JavaScript code

## Git Conventions

- Commit messages: short present-tense phrases, no conventional-commits prefix.
  Examples: "Name remaining RAM addresses", "Replace raw hex dc.l pointer literals with named labels"
- Primary branch: `master`
- The repository must always have code that assembles to match the checksum.

## Debugging

Use [Exodus Emulator](https://www.exodusemulator.com/) for running and debugging
the ROM -- it supports breakpoints, memory/register inspection, and step execution.

## Key Constraints

1. **Binary must match exactly.** Every change must preserve byte-identical output. Run `verify.bat` after every build.
2. **ROM size is fixed at 524,288 bytes.** If code changes alter size, pad with `NOP`s.
3. **Checksum must be correct** or the emulator shows a red screen. Update the word at `$018E` if the binary changes.
4. **All loc_ labels have been renamed.** When editing labels, preserve the `;loc_XXXX` comment above for traceability.
5. **Modular source structure.** `smgp.asm` is an include hub. Edit the individual module files under `src/`, not the concatenated `smgp_full.asm`.
6. **Tooling language policy.** This project uses Node.js tooling and NEVER Python. Do not create or extend Python scripts; port any needed tooling to JavaScript instead.


## Tooling Guardrails

- **Do not guess at Windows batch/PowerShell invocation.** In this environment, run canonical build verification via PowerShell:
  - `powershell -NoProfile -ExecutionPolicy Bypass -Command "& .\build.bat"`
  - `powershell -NoProfile -ExecutionPolicy Bypass -Command "& .\verify.bat"`
- **Do not try to inline asm68k with bash wrappers** when checking canonical builds; arguments like `/p` can be mangled and produce false results.
- **If `build.bat` fails with missing `data/tracks/.../*.bin`, treat the root tree as broken immediately.** Restore the canonical extracted track data before doing anything else.
- **Before claiming the root tree is canonical, actually run `verify.bat` and report the result.** Do not infer success from partial shell output.
- **When preserving a broken or experimental state, checkpoint it first on a commit/branch, then restore the root tree to a verified commit. Never leave `master` non-bit-perfect between steps.**
- **Master operating model:** keep `master` bit-perfect-buildable while still allowing randomizer tooling on `master`. Randomized ROM generation must default to workspace-only flows (`tools/hack_workdir.js` / workspace-safe `tools/randomize.js`) and must not mutate the root source tree unless explicitly using a debugging-only in-root mode.

## Randomizer Refactor Workflow

- Prefer the workspace-safe flow for randomizer/tooling changes; do not use in-root mutation unless you are deliberately debugging a root-only issue.
- Before structural or algorithmic refactors, add direct tests first and freeze any compact baselines you need.
- Use the fast test tier during iteration, then run a real workspace build before claiming tool-flow changes are safe.
- In-root debug runs now create an explicit checkpoint under `build/checkpoints/in_root_debug/`; clear it with `node tools/restore_tracks.js --verify` before starting another in-root session.
- Close every randomizer refactor checkpoint with canonical PowerShell verify.
- See `docs/randomizer_refactor_workflow.md` for the expected command loop.

## Randomizer Anti-Overfitting Guardrails

- The randomizer must work for arbitrary seeds and arbitrary runtime-safe tracks. Treat any seed-specific or track-name-specific fix as presumptively wrong until proven to be a direct encoding of an actual ROM rule.
- Never hardcode randomizer behavior around a screenshot, a single seed, or a hand-picked track slug unless the ROM/disassembly itself contains a matching per-track rule or data table and you can point to it explicitly.
- Never write regression tests that freeze behavior to a named stock track, a hand-picked screenshot window, or exact pixel/tile coordinates just because that case exposed the bug. Those tests overfit the implementation and block valid randomizer changes.
- A named-track test is only acceptable when the behavior is explicitly defined by ROM/disassembly data for that track, and the expected result must be derived from source data or decoded ROM semantics rather than copied in as ad-hoc literals.
- Prefer invariant-driven coverage: synthetic fixtures, all-track/property-style assertions, arbitrary-seed checks, round-trip checks, and runtime-path validation against derived ROM data.
- If a bug is first seen on one track, generalize the regression before committing it: either reproduce the failure with a synthetic fixture or express the rule as a class-wide invariant. Do not keep screenshot-driven or slug-driven tests as the long-term fix.
- Before keeping any new randomizer/minimap test, explicitly ask whether it would still pass after a legitimate generator improvement that preserves ROM rules. If the answer is no, rewrite or delete the test.
- Do not steer randomized map/minimap generation back toward stock slot shapes as a fallback. Remove the bad candidate and fix the generator/renderer instead of blending against stock guides, stock minimap pairs, or stock preview silhouettes.
- Do not keep track-family-specific acceptance logic (for example Monaco-only minimap thresholds) unless the distinction is directly derived from ROM/disassembly behavior.
- Do not rank randomized minimap candidates primarily by stock-proxy metrics such as stock sign-match similarity, stock used-cell floors, stock phase alignment, or stock silhouette similarity. Prefer direct rendered-output validity and generator invariants.
- If a heuristic only exists to rescue weak output so it looks more like stock preview art, treat it as suspect and remove it unless it can be justified as a general rendering rule.
- When evaluating a generator change, verify the actual built ROM/rendered path before claiming success. Do not rely on internal geometry metrics or intermediate previews as proof.
- Before adding a patch step, identify which layer of the ROM is actually responsible: generated minimap tiles, generated minimap map, stock packed course-select overlay, runtime tile base, etc. Verify the layer in disassembly/source first.
- If a fix depends on per-track behavior, derive it from the source data/packed stream/ROM semantics programmatically. Do not maintain ad-hoc `PATCHES_BY_SLUG`/offset tables for randomized output when those offsets can be decoded from existing data.
- When you suspect a visual bug, first prove whether it comes from generated assets, a stock overlay, or the compositor path. Do not patch symptoms until the owning layer is identified.
- If a proposed fix removes or redraws a whole screen layer (text, overlay, tilemap, helper path, etc.), state that explicitly before implementation and verify the exact user-visible consequence afterward. Do not describe a whole-layer suppression as a narrow visual fix.
- If a change fixes one symptom but introduces a new visible regression in another layer (for example text corruption after a map fix), treat that as evidence the layer model is still wrong. Revert the assumption, update the diagnosis, and avoid adding tests that bless the regressed state.
- Never lock in a broken intermediate state with regression tests just because it is the newest output. A failing screenshot is debugging evidence, not a contract.
- For compositor/path bugs, prefer tests that prove layer ownership and hook behavior (which helper runs, which tile slots are preserved, which addresses/pointers are used) before any screenshot-adjacent assertions.
- Before keeping a runtime patch, ask whether it preserves all unaffected screen content. If it fixes the target artifact by deleting unrelated content, it is not a valid fix.
- When multiple symptoms share a screen, do not assume they share one cause. Prove whether text/UI corruption and map corruption come from the same layer before writing code or tests.
- If multiple attempted fixes fail to change a single visible pixel of the target bug, stop iterating on nearby theories. Re-open diagnosis from the live ROM path and identify one concrete piece of evidence that the next change touches the owning layer.
- Do not treat passing helper/unit tests as evidence that a screen bug is fixed when the user-visible ROM output is unchanged. A no-op-on-screen result means the wrong layer or wrong data path is still being modified.
- After any runtime visual fix, compare the expected changed layer against the actual observed outcome. If the observed output is unchanged, explicitly conclude that the patch did not hit the owning path and remove or rethink the change instead of stacking more patches.
- Avoid long debugging loops with net-negative productivity: when two successive fixes fail to improve the target pixels, switch from patching to instrumentation/ownership proof before writing more code.
- If the user names a specific screen/state (for example free practice track select, title menu preview, championship preview, results screen), trace that exact runtime path first. Do not assume another superficially similar screen shares the same draw calls, layers, or VRAM destinations.
- After a failed visual fix, explicitly ask: did this patch target the exact screen/state the user reported, or only a related one? If not exact, revert course immediately and trace the correct path before any more edits.
- When a patch changes some other screen element but leaves the target pixels unchanged, treat that as proof the patch hit a neighboring path rather than the owning one. Remove the neighbor-path patch instead of expanding it.
- A fix that corrupts unaffected content on the reported screen is evidence of wrong-path debugging, not partial success. Roll back the assumption and re-open path ownership.
- For title/options/free-practice preview bugs, do not assume the `race.asm` championship preview loader owns the screen. Prove whether the screen is actually using `menus.asm` title-preview assets (`Title_sign_*`, `Round_sign_*`) before patching any race-preview path.
- Any temporary workaround must be labeled as temporary in the code and replaced with a derived/general solution before the task is considered complete.

