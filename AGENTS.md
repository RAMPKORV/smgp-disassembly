# AGENTS.md - Super Monaco GP Disassembly

## Project Overview

Matching disassembly of **Super Monaco GP** (Sega Mega Drive / Genesis, 1990).
The goal is to produce Motorola 68000 assembly source that assembles to a ROM
binary byte-identical to the original. The main source is a single monolithic
file `smgp.asm` (~43,700 lines) with two included support files.

- **CPU:** Motorola 68000 (main) + Zilog Z80 (sound, not yet disassembled)
- **Assembler:** SN 68k (asm68k) version 2.53
- **Platform:** Sega Mega Drive / Genesis

## Build Commands

### Build the ROM
```batch
build.bat
```
From this CLI on Windows, `./build.bat` works and shows the assembler output directly.
From Git Bash/WSL: `cmd //c build.bat`

Direct invocation: `asm68k /k /p /o ae- smgp.asm,out.bin,,smgp.lst`

Flags: `/k` keep symbol case, `/p` generate listing, `/o ae-` disable auto even-alignment.
Output: `out.bin` (ROM binary), `smgp.lst` (listing with addresses).

`smgp.lst` is a primary reverse-engineering aid, not just build output. Use it proactively
when auditing hidden pointers, matching tuple-encoded data to ROM addresses, locating
embedded substructures inside large `dc.b`/`dc.w` blobs, and verifying exact label/address
placement before editing assembly source.

### Verify Build (Bit-Perfect Check)
```batch
verify.bat
```
From this CLI on Windows, `./verify.bat` works and shows the verification result directly.
From Git Bash/WSL: `cmd //c verify.bat`

Compatibility alias: `varify.bat`

Builds the ROM and checks its SHA256 against the known-good hash. Exit 0 = bit-perfect,
exit 1 = mismatch or build failure.

**CRITICAL: After ANY code change, run `verify.bat`. A non-bit-perfect build is never
acceptable. Do not proceed until the build is clean.**

There are no unit tests — bit-perfect verification is the only test.

### Modifying the ROM
If changes alter code/data size, insert `NOP` instructions to maintain the
exact 524,288-byte ROM size. The checksum at offset `$018E` must also be
updated (use [Sega Genesis Checksum Utility](https://github.com/mrhappyasthma/Sega-Genesis-Checksum-Utility))
or the emulator will refuse to boot (red screen).

## File Structure

```
smgp.asm            Main disassembly source (~43,700 lines)
constants.asm       Named constants (RAM addresses, hardware ports, key codes)
macros.asm          Assembler macros (txt macro for text encoding)
build.bat           Windows build script (1 line)
verify.bat          Windows SHA256 build verification
varify.bat          Compatibility alias for verify.bat
build.sh            Legacy Linux/macOS Docker build script
validate.sh         Legacy MD5 + size validator
asm68k.exe          Bundled assembler binary
notes.txt           Reverse-engineering notes (memory map, data formats, TODOs)
tools/              Python analysis/formatting utilities (not part of ROM build)
```

### smgp.asm Internal Layout (top to bottom)
1. Includes (`macros.asm`, `constants.asm`)
2. M68K exception vector table (reset, interrupts, traps)
3. Sega Mega Drive ROM header
4. Error trap handlers
5. `EntryPoint` - hardware initialization
6. Game routines (named and `loc_XXXX` labels intermixed)
7. Data tables (track data, acceleration, engine, team/driver data)
8. Binary data blobs (compressed tiles, palettes, sound)
9. Z80 sound driver data
10. `EndOfRom` label + `END` directive

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
- **Decimal literals** for game-meaningful physical constants (RPM, speed, points): `1500`, `100`, `50`.
- **Branch size hints** are explicit: `BRA.b`, `BNE.w`, `BSR.w`, `BCC.b`.

### Naming Conventions

**Named labels (reverse-engineered)** - use `Title_Snake_Case`:
- Routines: `Update_shift`, `Update_rpm`, `Render_speed`, `Binary_to_decimal`, `Integrate_curveslope`
- Data: `Acceleration_data`, `Engine_data`, `Track_data`, `Road_displacement_table`
- Some data tables use **PascalCase**: `PointsAwardedPerPlacement`, `DriverPortraitTiles`, `TeamMessagesBeforeRace`
- Prefer `Title_Snake_Case` for new labels; PascalCase is acceptable for data tables.

**Auto-generated labels** (not yet reverse-engineered): `loc_XXXX` where `XXXX` is the uppercase hex ROM address. Example: `loc_20C`, `loc_3B4`, `loc_5AB0`.

**Constants** (in `constants.asm`):
- RAM addresses / variables: `Title_Snake_Case` (`Player_shift`, `Track_index`, `Race_started`)
- Hardware registers: `Title_Snake_Case` (`VDP_control_port`, `Z80_bus_request`)
- Key constants: `UPPER_SNAKE_CASE` (`KEY_START`, `KEY_A`, `KEY_UP`)
- Numeric constants: `Title_Snake_Case` (`Engine_rpm_max = 1500`)
- Assignment syntax: `NAME = value` (not `equ`)

**Special labels**: `StartOfRom`, `EndOfRom`, `EntryPoint`, `Header`, `Vectors` (PascalCase).

### Comment Conventions
- Use `;` for inline comments after instructions.
- Document conditional logic with if/then/else pseudo-code:
  ```asm
  BTST.b  D5, Input_state_bitset.w ; if shift down key pressed
  BNE.w   loc_5A62                 ; then shift down
  ```
- Document branch targets with "Jump to when..." annotations:
  ```asm
  loc_59DA: ; Jump to when shift type is Automatic
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
  ;D2 = curve/slope data for step
  ```
- No file-level headers, copyright blocks, or section dividers.

### Data Definitions
- `dc.b` for bytes, `dc.w` for words, `dc.l` for longs.
- Long byte arrays: 32 comma-separated values per `dc.b` line.
- Pointer/address tables: one `dc.l` per line with descriptive comment.

## Code Style - Constants File

In `constants.asm`, constants are simple assignments grouped loosely:
1. Hardware registers
2. Player state variables
3. Game state variables
4. Decompressed data addresses
5. Car/team data
6. Flags and settings
7. Input key constants

## Code Style - Python Tools

The `tools/` directory contains analysis utilities (not part of ROM build):
- **snake_case** for functions and variables: `extract_loc_data`, `parse_signed_byte`
- **UPPER_SNAKE_CASE** for constants: `NUM_TRACKS`
- Shebang: `#!/usr/bin/env python3`
- Standard PEP 8 conventions, no type hints, no docstrings

## Git Conventions

- Commit messages: short present-tense phrases, no conventional-commits prefix.
  Examples: "Document Update_shift", "Define Player_rpm", "Use decimal literals for physical constants"
- Primary branch: `master`
- The repository must always have code that assembles to match the checksum.

## Debugging

Use [Exodus Emulator](https://www.exodusemulator.com/) for running and debugging
the ROM - it supports breakpoints, memory/register inspection, and step execution.

## Key Constraints

1. **Binary must match exactly.** Every change must preserve the byte-identical output. Run `verify.bat` after every build.
2. **ROM size is fixed at 524,288 bytes.** If code changes alter size, pad with `NOP`s.
3. **Checksum must be correct** or the emulator shows a red screen. Update the word at `$018E` if the binary changes.
4. **This is an ongoing reverse-engineering effort.** Most labels are still auto-generated `loc_XXXX`. When renaming a label, preserve the old address as a comment above the new name.
