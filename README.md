# smgp-disassembly

Reverse engineering of Super Monaco GP for Sega Mega Drive.

### How to build

`./build.bat && ./validate.sh`

The repository should always have code commited that matches the checksum when built.

### How to run and debug

We use [Exodus Emulator](https://www.exodusemulator.com/) which has debugging features such as setting breakpoints and inspecting memory and registers.

### How to modify

Modify `smgp.asm` and insert `NOP`'s if needed so the size in `validate.sh` matches (seems to cause alignment issues otherwise).

You also need to [fix the checksum](https://github.com/mrhappyasthma/Sega-Genesis-Checksum-Utility) or the emulator won't run it (red screen).
