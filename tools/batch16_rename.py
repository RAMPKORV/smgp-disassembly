#!/usr/bin/env python3
"""Batch 16 label renames for smgp.asm.

Covers:
- Copy_tilemap_block_with_base internals
- Draw_packed_tilemap_to_vdp internals (fetch, emit, ctrl, dispatch, base variants)
- Draw_packed_tilemap_list loop
- Fade_palette_to_black internals
- Darken_palette_component min-zero clamp
- Start_vdp_dma_fill busy-wait loop
"""

import re

RENAMES = [
    # ---- Copy_tilemap_block_with_base internals ----
    ("loc_826", "Copy_tilemap_block_row"),  # outer row loop
    ("loc_82A", "Copy_tilemap_block_tile"), # inner tile copy loop
    ("loc_838", "Copy_tilemap_block_zero"), # zero-tile skip path

    # ---- Draw_packed_tilemap_to_vdp internals ----
    ("loc_858", "Draw_packed_fetch"),       # main fetch-byte / dispatch loop
    ("loc_864", "Draw_packed_emit"),        # emit tile word to VDP data port
    ("loc_868", "Draw_packed_ctrl"),        # handle control byte >= $FA
    ("loc_874", "Draw_packed_dispatch"),    # jump table for control bytes $FA-$FE
    ("loc_88A", "Draw_packed_new_base"),    # control $FA: read new base word from stream
    ("loc_892", "Draw_packed_base_add80"),  # control $FB: add $80 to tile base
    ("loc_896", "Draw_packed_base_add40a"), # control $FC: add $40 more
    ("loc_89A", "Draw_packed_base_add40b"), # control $FD: add $40 more again

    # ---- Draw_packed_tilemap_list loop ----
    ("loc_8A2", "Draw_packed_list_loop"),   # per-entry dispatch loop

    # ---- Fade_palette_to_black internals ----
    ("loc_8CC", "Fade_palette_frame"),      # outer 7-frame iteration loop
    ("loc_8D2", "Fade_palette_entry"),      # inner per-palette-entry loop
    ("loc_8FA", "Fade_palette_pal_extra"),  # PAL: extra VBlank wait

    # ---- Darken_palette_component min-zero clamp ----
    ("loc_910", "Darken_palette_clamp"),    # clamp component to 0 if underflow

    # ---- Start_vdp_dma_fill busy-wait ----
    ("loc_960", "Start_dma_fill_wait"),     # spin until VDP DMA-busy bit clears
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

    new_content = re.sub(r'\b' + re.escape(old) + r'\b', new, content)

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

if '::' in content and '::' not in original:
    print("ERROR: Double-colon detected in output!")
else:
    print("No double-colon issues detected.")

with open(ASM_FILE, "w", encoding="latin-1") as f:
    f.write(content)

print(f"\nDone. Total replacements: {total_replacements}")
print(f"Labels renamed: {len(RENAMES)}")
