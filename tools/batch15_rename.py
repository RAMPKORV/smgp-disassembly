#!/usr/bin/env python3
"""Batch 15 label renames for smgp.asm.

Covers:
- Reset_vdp_update_state internals (screen/sprite clear loops)
- Copy_word_run_to_buffer loop
- Upload_palette_buffer_to_cram internals (PAL wait, DMA entry)
- Upload_palette_buffer_to_cram_delayed internals
- Upload_h32_tilemap / H40 shared tail
- Draw_tilemap_buffer_to_vdp shared body + row/tile loops
- loc_7BE (Decompress_tilemap_to_vdp_128cell_with_base entry)
- Decompress_tilemap_to_vdp_32cell_with_base shared decomp step
- Write_tilemap_rows_to_vdp row/tile loops + zero-tile skip
"""

import re

RENAMES = [
    # ---- Reset_vdp_update_state internals ----
    ("loc_6BE", "Reset_vdp_screen_clr_loop"),  # clear $40 longwords of screen timer area
    ("loc_6CC", "Reset_vdp_sprite_clr_loop"),  # clear $A0 longwords of sprite attr buf

    # ---- Copy_word_run_to_buffer loop ----
    ("loc_6E8", "Copy_word_run_loop"),          # copy D1+1 words from A6 to palette buffer

    # ---- Upload_palette_buffer_to_cram internals ----
    ("loc_6FA", "Upload_palette_pal_wait"),     # PAL-mode spin delay loop
    ("loc_6FE", "Upload_palette_dma"),          # DMA setup and JMP to Send_D567_to_VDP

    # ---- Upload_palette_buffer_to_cram_delayed internals ----
    ("loc_724", "Upload_palette_delayed_wait"), # shorter PAL-mode spin delay loop
    ("loc_728", "Upload_palette_delayed_dma"),  # DMA setup and JMP for delayed variant

    # ---- Upload_h32 / H40 shared DMA tail ----
    ("loc_762", "Upload_tilemap_dma"),          # shared DMA launch tail for H32/H40 tilemap

    # ---- Draw_tilemap_buffer_to_vdp shared body + loops ----
    ("loc_786", "Draw_tilemap_buffer_body"),    # common entry for all 3 row-stride variants
    ("loc_78C", "Draw_tilemap_buffer_row"),     # outer row loop (write VDP cmd, iterate tiles)
    ("loc_792", "Draw_tilemap_buffer_tile"),    # inner tile loop (write words to VDP data port)

    # ---- Decompress_tilemap_to_vdp_128cell_with_base entry ----
    ("loc_7BE", "Decompress_tilemap_128cell_with_base"), # 128-cell row-stride w/tile-base variant

    # ---- Decompress_tilemap_to_vdp_32cell_with_base shared tail ----
    ("loc_7D4", "Decompress_tilemap_with_base_body"),  # shared decompress+upload for both base variants

    # ---- Write_tilemap_rows_to_vdp internals ----
    ("loc_7E2", "Write_tilemap_rows_row"),      # outer row loop (write VDP address cmd)
    ("loc_7E8", "Write_tilemap_rows_tile"),     # inner tile loop (read tile word from buf)
    ("loc_7F6", "Write_tilemap_rows_zero"),     # zero-tile skip path (preserve tile zero)
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
