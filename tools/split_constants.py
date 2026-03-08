#!/usr/bin/env python3

import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def section_start(lines, title):
    index = lines.index(title)
    while index > 0 and lines[index - 1].strip() == "":
        index -= 1
    if index > 0 and lines[index - 1].startswith("; ==="):
        index -= 1
    return index


def main():
    text = subprocess.check_output(
        ["git", "show", "HEAD:constants.asm"],
        cwd=ROOT,
    ).decode("latin-1")
    lines = text.splitlines()

    start_vdp = section_start(lines, "; VDP display geometry (fast-page RAM, $FFFFFF14-$FFFFFF24)")
    start_sound = section_start(lines, "; Sound control register")
    start_game = section_start(lines, "; Title / options menu state values")
    start_ram = section_start(lines, "; RAM buffer base addresses")

    hw_lines = lines[:start_vdp]
    ram_lines = lines[start_vdp:start_sound] + [""] + lines[start_ram:]
    sound_lines = lines[start_sound:start_game]
    game_lines = lines[start_game:start_ram]

    (ROOT / "hw_constants.asm").write_text("\n".join(hw_lines) + "\n", encoding="latin-1")
    (ROOT / "ram_addresses.asm").write_text("\n".join(ram_lines) + "\n", encoding="latin-1")
    (ROOT / "sound_constants.asm").write_text("\n".join(sound_lines) + "\n", encoding="latin-1")
    (ROOT / "game_constants.asm").write_text("\n".join(game_lines) + "\n", encoding="latin-1")
    (ROOT / "constants.asm").write_text(
        '\tinclude "hw_constants.asm"\n'
        '\tinclude "ram_addresses.asm"\n'
        '\tinclude "sound_constants.asm"\n'
        '\tinclude "game_constants.asm"\n',
        encoding="latin-1",
    )


if __name__ == "__main__":
    main()
