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
tools/                 Python analysis/formatting utilities (not part of ROM build)
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

## Code Style - Python Tools

The `tools/` directory contains analysis utilities (not part of ROM build):
- **snake_case** for functions and variables
- **UPPER_SNAKE_CASE** for constants
- Shebang: `#!/usr/bin/env python3`
- Standard PEP 8 conventions, no type hints, no docstrings

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
