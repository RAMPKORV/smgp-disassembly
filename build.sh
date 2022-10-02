#!/usr/bin/env bash

set -e

# SN 68k version 2.53, same version as asm68k.exe in repo
# https://github.com/rhargreaves/asm68k-docker-image/blob/master/Dockerfile
docker run --rm -v $(pwd):/src rhargreaves/asm68k /k /p /o ae- smgp.asm,out.bin,,smgp.lst

echo
./validate.sh
