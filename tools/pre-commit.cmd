@echo off
rem tools/pre-commit.cmd
rem
rem Installs a Git pre-commit hook that runs verify.bat and
rem tools/run_checks.js before every commit.
rem
rem Usage (run once from the repo root):
rem   tools\pre-commit.cmd
rem
rem To uninstall, delete .git\hooks\pre-commit

setlocal

set "HOOK_DIR=.git\hooks"
set "HOOK_FILE=.git\hooks\pre-commit"

if not exist "%HOOK_DIR%\" (
    echo ERROR: .git\hooks directory not found. Run this from the repo root.
    exit /b 1
)

rem Write the hook script as a POSIX sh file (Git for Windows uses bash).
rem NOTE: EnableDelayedExpansion is intentionally OFF here so '!' is literal.
(
    echo #!/bin/sh
    echo # pre-commit hook for Super Monaco GP disassembly
    echo # Installed by tools/pre-commit.cmd
    echo #
    echo # Runs:
    echo #   1. verify.bat  -- bit-perfect SHA256 check
    echo #   2. node tools/run_checks.js  -- structural integrity checks
    echo.
    echo set -e
    echo.
    echo REPO_ROOT="$(git rev-parse --show-toplevel)"
    echo cd "$REPO_ROOT"
    echo.
    echo echo "=== pre-commit: running verify.bat ==="
    echo cmd.exe /c verify.bat
    echo if [ $? -ne 0 ]; then
    echo   echo "ERROR: verify.bat failed -- build is not bit-perfect"
    echo   exit 1
    echo fi
    echo.
    echo echo "=== pre-commit: running run_checks.js ==="
    echo node tools/run_checks.js
    echo if [ $? -ne 0 ]; then
    echo   echo "ERROR: run_checks.js failed -- fix structural errors before committing"
    echo   exit 1
    echo fi
    echo.
    echo echo "pre-commit checks passed."
) > "%HOOK_FILE%"

echo Installed pre-commit hook at: %HOOK_FILE%
echo.
echo The hook will run verify.bat and node tools/run_checks.js before each commit.
echo To skip in an emergency: git commit --no-verify
echo To uninstall: del %HOOK_FILE%

endlocal
exit /b 0