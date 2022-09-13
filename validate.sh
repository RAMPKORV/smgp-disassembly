#!/bin/bash

# Usage: ./build.bat && validate.sh

set -e

EXPECTED_MD5="ded2b235f625424f353c13c4d3a2cf89"
ACTUAL_MD5="$(md5sum out.bin | awk '{print $1}')"

EXPECTED_SIZE="524288"
ACTUAL_SIZE="$(wc -c out.bin | awk '{print $1}')"

echo " * Checksum * "
echo "Expected: $EXPECTED_MD5"
echo "Actual:   $ACTUAL_MD5"
echo
echo " * Size * "
echo "Expected: $EXPECTED_SIZE"
echo "Actual:   $ACTUAL_SIZE"
