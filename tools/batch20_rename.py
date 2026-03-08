#!/usr/bin/env python3
# Batch 20: Update_objects_and_build_sprite_buffer internals
#
# loc_D92  -> Update_objects_loop            (main object-update loop)
# loc_D9A  -> Update_objects_next            (advance to next object slot)
# loc_DB8  -> Build_sprites_bg_row           (outer loop over BG sprite groups)
# loc_DC2  -> Build_sprites_bg_entry         (inner loop: per-entry within group)
# loc_DDA  -> Build_sprites_bg_sprite        (per-sprite inner body, BG layer)
# loc_E0A  -> Build_sprites_bg_sprite_skip   (clipped/OOB sprite skip, BG layer)
# loc_E0E  -> Build_sprites_bg_entry_next    (DBF end of BG entry inner loop)
# loc_E12  -> Build_sprites_bg_row_next      (DBF end of BG row outer loop)
# loc_E24  -> Build_sprites_fg_row           (outer loop over FG sprite groups)
# loc_E2E  -> Build_sprites_fg_entry         (inner loop: per-entry within group)
# loc_E46  -> Build_sprites_fg_sprite        (per-sprite inner body, FG layer)
# loc_E76  -> Build_sprites_fg_sprite_skip   (clipped/OOB sprite skip, FG layer)
# loc_E7A  -> Build_sprites_fg_entry_next    (DBF end of FG entry inner loop)
# loc_E7E  -> Build_sprites_fg_row_next      (DBF end of FG row outer loop)
# loc_E86  -> Build_sprites_link_chain       (write link chain / finish sprite list)
# loc_E90  -> Build_sprites_clear_loop       (clear remaining sprite slots)
# loc_EA4  -> Build_sprites_fix_link_loop    (fix up link bytes in sprite list)
# loc_EB4  -> Build_sprites_fix_link_clr     (clear link byte for terminator sprite)
# loc_EB8  -> Build_sprites_fix_link_next    (advance to next entry in fix-up loop)
# loc_ED6  -> Build_sprites_write_links      (write sequential link bytes)
# loc_EDC  -> Build_sprites_write_links_loop (write link byte loop)
# loc_EE6  -> Build_sprites_write_links_done (terminate link chain)

import re

SOURCE = r'E:\Romhacking\smgp-disassembly\smgp.asm'

RENAMES = [
    ('loc_D92', 'Update_objects_loop'),
    ('loc_D9A', 'Update_objects_next'),
    ('loc_DB8', 'Build_sprites_bg_row'),
    ('loc_DC2', 'Build_sprites_bg_entry'),
    ('loc_DDA', 'Build_sprites_bg_sprite'),
    ('loc_E0A', 'Build_sprites_bg_sprite_skip'),
    ('loc_E0E', 'Build_sprites_bg_entry_next'),
    ('loc_E12', 'Build_sprites_bg_row_next'),
    ('loc_E24', 'Build_sprites_fg_row'),
    ('loc_E2E', 'Build_sprites_fg_entry'),
    ('loc_E46', 'Build_sprites_fg_sprite'),
    ('loc_E76', 'Build_sprites_fg_sprite_skip'),
    ('loc_E7A', 'Build_sprites_fg_entry_next'),
    ('loc_E7E', 'Build_sprites_fg_row_next'),
    ('loc_E86', 'Build_sprites_link_chain'),
    ('loc_E90', 'Build_sprites_clear_loop'),
    ('loc_EA4', 'Build_sprites_fix_link_loop'),
    ('loc_EB4', 'Build_sprites_fix_link_clr'),
    ('loc_EB8', 'Build_sprites_fix_link_next'),
    ('loc_ED6', 'Build_sprites_write_links'),
    ('loc_EDC', 'Build_sprites_write_links_loop'),
    ('loc_EE6', 'Build_sprites_write_links_done'),
]

with open(SOURCE, encoding='latin-1') as f:
    content = f.read()

total_replacements = 0
for old, new in RENAMES:
    pattern = r'\b' + re.escape(old) + r'\b'
    new_content, count = re.subn(pattern, new, content)
    if count == 0:
        print(f'WARNING: {old} not found')
    else:
        print(f'  {old} -> {new}: {count} replacement(s)')
        total_replacements += count
        content = new_content

# Insert preservation comments above each definition line
for old, new in RENAMES:
    def_pattern = r'^(' + re.escape(new) + r':)'
    def repl(m):
        return f';{old}\n{m.group(1)}'
    new_content, count = re.subn(def_pattern, repl, content, flags=re.MULTILINE)
    if count == 0:
        print(f'WARNING: definition for {new}: not found (preservation comment not inserted)')
    else:
        content = new_content

with open(SOURCE, 'w', encoding='latin-1') as f:
    f.write(content)

print(f'\nDone. {total_replacements} total replacements across {len(RENAMES)} labels.')
