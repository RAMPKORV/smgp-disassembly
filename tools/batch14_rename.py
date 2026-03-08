#!/usr/bin/env python3
"""Batch 14 label renames for smgp.asm.

Covers:
- EntryPoint internal labels (boot sequence, loops, error handler internals)
- Wait_for_vblank internal loop
- Decompress_asset_list_to_vdp loop
- PRNG routine (loc_57C) rename + nonzero-seed branch
- Initialize_vdp loops
- Shared H40/H32 VDP DMA tail
- Vdp_init_register_table data label
"""

import re
import sys

RENAMES = [
    # ---- EntryPoint boot sequence internals ----
    ("loc_214", "EntryPoint_Settle_loop"),     # I/O port settle wait loop
    ("loc_220", "EntryPoint_Cold_boot"),       # cold-boot entry point
    ("loc_23A", "EntryPoint_Tmss_done"),       # after TMSS register unlock
    ("loc_244", "EntryPoint_Vdp_init_loop"),   # VDP register init write loop
    ("loc_25A", "EntryPoint_Z80_grant_wait"),  # spin until Z80 grants bus
    ("loc_260", "EntryPoint_Z80_copy_loop"),   # copy Z80 init bytes to Z80 RAM
    ("loc_26C", "EntryPoint_Ram_clear_loop"),  # initial work RAM clear loop
    ("loc_280", "EntryPoint_Vram_clear_loop"), # VRAM zero-fill loop
    ("loc_28E", "EntryPoint_Spr_clear_loop"),  # sprite attribute table zero-fill loop
    ("loc_296", "EntryPoint_Vreg_copy_loop"),  # VDP register copy loop
    ("loc_2C0", "EntryPoint_Checksum_loop"),   # ROM checksum accumulation loop
    ("loc_2EE", "EntryPoint_Warm_boot"),       # warm-boot entry (sentinel already set)
    ("loc_302", "EntryPoint_Ram_init_loop"),   # full work RAM zero loop (warm boot)
    ("loc_36A", "EntryPoint_Main_loop"),       # main game frame loop
    ("loc_388", "EntryPoint_Bad_rom_fill"),    # tile fill loop inside bad-ROM handler
    ("loc_394", "EntryPoint_Bad_rom_halt"),    # infinite halt loop (CPU stopped)

    # ---- Wait_for_vblank internal ----
    ("loc_39A", "Wait_for_vblank_loop"),       # busy-wait poll until VBI fires

    # ---- Decompress_asset_list_to_vdp loop ----
    ("loc_530", "Decompress_asset_list_loop"), # per-entry decompress loop

    # ---- PRNG routine and nonzero-seed branch ----
    ("loc_57C", "Prng"),                      # 32-bit LCG pseudo-random number generator
    ("loc_58A", "Prng_nonzero_seed"),         # path taken when state is already non-zero

    # ---- Initialize_vdp loops ----
    ("loc_60A", "Initialize_vdp_reg_loop"),   # write VDP register init table loop
    ("loc_620", "Initialize_vdp_vram_loop"),  # VRAM zero-fill loop

    # ---- Shared H40/H32 DMA tail ----
    ("loc_67C", "Initialize_vdp_dma_common"), # common DMA-fill tail for H40 and H32 init

    # ---- VDP register init data table ----
    ("loc_D36", "Vdp_init_register_table"),   # 19-entry VDP register initialisation table
]

ASM_FILE = "smgp.asm"

with open(ASM_FILE, encoding="latin-1") as f:
    content = f.read()

original = content
total_replacements = 0

for old, new in RENAMES:
    count = len(re.findall(r'\b' + re.escape(old) + r'\b', content))
    if count == 0:
        print(f"WARNING: {old} not found")
        continue

    # Step 1: Replace all references with word-boundary regex
    new_content = re.sub(r'\b' + re.escape(old) + r'\b', new, content)

    # Step 2: Insert preservation comment above the definition line.
    new_content = re.sub(
        r'^(' + re.escape(new) + r')(:[^\S\n]*\n)',
        r';' + old + r'\n\1\2',
        new_content,
        flags=re.MULTILINE
    )

    replacements = count
    print(f"{old} -> {new}: {replacements} occurrence(s)")
    total_replacements += replacements
    content = new_content

# Verify no double-colons introduced
if '::' in content and '::' not in original:
    print("ERROR: Double-colon detected in output!")
else:
    print("No double-colon issues detected.")

with open(ASM_FILE, "w", encoding="latin-1") as f:
    f.write(content)

print(f"\nDone. Total replacements: {total_replacements}")
print(f"Labels renamed: {len(RENAMES)}")
