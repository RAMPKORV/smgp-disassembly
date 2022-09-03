#!/bin/bash

EXPECTED="ded2b235f625424f353c13c4d3a2cf89"
ACTUAL="$(md5sum out.bin)"

echo "Expected: $EXPECTED"
echo "Actual:   $ACTUAL"
