@echo off
REM Super Monaco GP ROM Build Verification Script
REM Builds the ROM and verifies it matches the expected hash

set EXPECTED_HASH=9046c9d67f15ab0f68d9e73b0cc516b6fd1637a8db0da4a03dcff8933c12dfa1
set ROM_FILE=out.bin

echo Building ROM...
call asm68k /k /p /o ae- smgp.asm,out.bin,,smgp.lst
if errorlevel 1 (
    echo BUILD FAILED
    exit /b 1
)

echo.
echo Verifying ROM hash...

REM Use Node.js to compute SHA256 hash (avoids certutil CR/LF parsing issues)
for /f %%a in ('node -e "const c=require('crypto'),fs=require('fs');process.stdout.write(c.createHash('sha256').update(fs.readFileSync('%ROM_FILE%')).digest('hex'))"') do set "ACTUAL_HASH=%%a"

if /i "%ACTUAL_HASH%"=="%EXPECTED_HASH%" (
    echo.
    echo ========================================
    echo   BUILD VERIFIED - ROM IS BIT-PERFECT
    echo ========================================
    echo Hash: %ACTUAL_HASH%
    exit /b 0
) else (
    echo.
    echo ========================================
    echo   VERIFICATION FAILED - ROM MISMATCH
    echo ========================================
    echo Expected: %EXPECTED_HASH%
    echo Actual:   %ACTUAL_HASH%
    exit /b 1
)
