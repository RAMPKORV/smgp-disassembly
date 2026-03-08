#!/usr/bin/env python3
"""Batch 13 label renames for smgp.asm.

Covers:
- Car sprite pointer table (loc_12A61)
- Sprite frame data blocks in 112xx/113xx range
- Sprite frame data blocks completing the 129xx retire series
- Car sprite pixel data blocks in 51xxx-53xxx range (69 entries)
- A few high-reference control-flow labels (loc_376, loc_3C4, loc_564)

Bug fix: This script inserts preservation comments AFTER the reference
replacement pass, so the ';loc_XXXX' comment is never subject to
word-boundary replacement.

Also fixes loc_12986 which is missing its colon (definition line bug
from prior batch script).
"""

import re

RENAMES = [
    # Car sprite pointer table (palette + 99 dc.l pointers for 11x9 angle/distance grid)
    ("loc_12A61", "Car_sprite_ptr_table"),

    # Sprite frame data (retire/wreck animation, completing the 12xxx series)
    ("loc_12986", "Sprite_frame_data_12986"),
    ("loc_1298E", "Sprite_frame_data_1298E"),
    ("loc_12996", "Sprite_frame_data_12996"),
    ("loc_129A6", "Sprite_frame_data_129A6"),

    # Sprite frame data (AI car finish-line animation, 112xx-113xx series)
    ("loc_112F2", "Sprite_frame_data_112F2"),
    ("loc_11374", "Sprite_frame_data_11374"),
    ("loc_1137C", "Sprite_frame_data_1137C"),
    ("loc_11384", "Sprite_frame_data_11384"),
    ("loc_11392", "Sprite_frame_data_11392"),
    ("loc_113A0", "Sprite_frame_data_113A0"),
    ("loc_113A8", "Sprite_frame_data_113A8"),

    # Car sprite pixel data blocks (48-byte MOVEM frames, 11 angles x 9 distances)
    # Angle group 0 (straight, furthest first)
    ("loc_51868", "Car_sprite_data_51868"),
    ("loc_51988", "Car_sprite_data_51988"),
    ("loc_51A48", "Car_sprite_data_51A48"),
    ("loc_51AC8", "Car_sprite_data_51AC8"),
    ("loc_51AE8", "Car_sprite_data_51AE8"),
    ("loc_51B08", "Car_sprite_data_51B08"),
    ("loc_51B28", "Car_sprite_data_51B28"),
    ("loc_51C48", "Car_sprite_data_51C48"),
    ("loc_51D08", "Car_sprite_data_51D08"),
    ("loc_51D88", "Car_sprite_data_51D88"),
    ("loc_51DA8", "Car_sprite_data_51DA8"),
    ("loc_51DC8", "Car_sprite_data_51DC8"),
    ("loc_51DE8", "Car_sprite_data_51DE8"),
    ("loc_51F08", "Car_sprite_data_51F08"),
    ("loc_52028", "Car_sprite_data_52028"),
    ("loc_520A8", "Car_sprite_data_520A8"),
    ("loc_520C8", "Car_sprite_data_520C8"),
    ("loc_520E8", "Car_sprite_data_520E8"),
    ("loc_52108", "Car_sprite_data_52108"),
    ("loc_52228", "Car_sprite_data_52228"),
    ("loc_522E8", "Car_sprite_data_522E8"),
    ("loc_52368", "Car_sprite_data_52368"),
    ("loc_52388", "Car_sprite_data_52388"),
    ("loc_523A8", "Car_sprite_data_523A8"),
    ("loc_523C8", "Car_sprite_data_523C8"),
    ("loc_524E8", "Car_sprite_data_524E8"),
    ("loc_525A8", "Car_sprite_data_525A8"),
    ("loc_52628", "Car_sprite_data_52628"),
    ("loc_52648", "Car_sprite_data_52648"),
    ("loc_52668", "Car_sprite_data_52668"),
    ("loc_52688", "Car_sprite_data_52688"),
    ("loc_527A8", "Car_sprite_data_527A8"),
    ("loc_528C8", "Car_sprite_data_528C8"),
    ("loc_52948", "Car_sprite_data_52948"),
    ("loc_52968", "Car_sprite_data_52968"),
    ("loc_52988", "Car_sprite_data_52988"),
    ("loc_529A8", "Car_sprite_data_529A8"),
    ("loc_52AC8", "Car_sprite_data_52AC8"),
    ("loc_52B88", "Car_sprite_data_52B88"),
    ("loc_52C08", "Car_sprite_data_52C08"),
    ("loc_52C28", "Car_sprite_data_52C28"),
    ("loc_52C48", "Car_sprite_data_52C48"),
    ("loc_52C68", "Car_sprite_data_52C68"),
    ("loc_52D88", "Car_sprite_data_52D88"),
    ("loc_52E48", "Car_sprite_data_52E48"),
    ("loc_52EC8", "Car_sprite_data_52EC8"),
    ("loc_52EE8", "Car_sprite_data_52EE8"),
    ("loc_52F08", "Car_sprite_data_52F08"),
    ("loc_52F28", "Car_sprite_data_52F28"),
    ("loc_53048", "Car_sprite_data_53048"),
    ("loc_53108", "Car_sprite_data_53108"),
    ("loc_53188", "Car_sprite_data_53188"),
    ("loc_531A8", "Car_sprite_data_531A8"),
    ("loc_531C8", "Car_sprite_data_531C8"),
    ("loc_531E8", "Car_sprite_data_531E8"),
    ("loc_53308", "Car_sprite_data_53308"),
    ("loc_533C8", "Car_sprite_data_533C8"),
    ("loc_53448", "Car_sprite_data_53448"),
    ("loc_53468", "Car_sprite_data_53468"),
    ("loc_53488", "Car_sprite_data_53488"),
    ("loc_534A8", "Car_sprite_data_534A8"),
    ("loc_535C8", "Car_sprite_data_535C8"),
    ("loc_53688", "Car_sprite_data_53688"),
    ("loc_536C8", "Car_sprite_data_536C8"),
    ("loc_536E8", "Car_sprite_data_536E8"),
    ("loc_53708", "Car_sprite_data_53708"),
    ("loc_53C28", "Car_sprite_data_53C28"),
    ("loc_53DBA", "Car_sprite_data_53DBA"),
    ("loc_53F50", "Car_sprite_data_53F50"),

    # Control-flow labels
    ("loc_376",  "Bad_rom_handler"),    # checksum mismatch -> blue screen, infinite loop
    ("loc_3C4",  "Vblank_interrupt_tail"),  # tail of Vertical_blank_interrupt after callback dispatch
    ("loc_564",  "Draw_tilemap_list_loop"), # shared inner loop for Draw_tilemap_list_to_vdp_*
]

ASM_FILE = "smgp.asm"

with open(ASM_FILE, encoding="latin-1") as f:
    content = f.read()

original = content
total_replacements = 0

# Special fix: loc_12986 is missing its colon on the definition line.
if "\nloc_12986\n" in content:
    content = content.replace("\nloc_12986\n", "\nloc_12986:\n")
    print("Fixed: loc_12986 missing colon restored")

for old, new in RENAMES:
    count = len(re.findall(r'\b' + re.escape(old) + r'\b', content))
    if count == 0:
        print(f"WARNING: {old} not found")
        continue

    # Step 1: Replace all references (including definition line) with word-boundary regex
    new_content = re.sub(r'\b' + re.escape(old) + r'\b', new, content)

    # Step 2: Insert preservation comment above the definition line.
    # The definition is now 'new:' (possibly with trailing whitespace/newline).
    # Insert ';old\n' before 'new:\n' at the start of a line.
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

# Verify preservation comments are correct (check a sample)
sample_checks = [
    ("loc_12A61", "Car_sprite_ptr_table"),
    ("loc_51B08", "Car_sprite_data_51B08"),
    ("loc_112F2", "Sprite_frame_data_112F2"),
    ("loc_376",   "Bad_rom_handler"),
]
for old, new in sample_checks:
    if f";{old}\n{new}:" in content:
        print(f"OK: ;{old} preservation comment correct")
    elif f"{new}:" in content:
        print(f"WARNING: {new}: found but ;{old} preservation comment missing or malformed")
    else:
        print(f"WARNING: {new}: definition not found")

with open(ASM_FILE, "w", encoding="latin-1") as f:
    f.write(content)

print(f"\nDone. Total replacements: {total_replacements}")
print(f"Labels renamed: {len(RENAMES)}")
