#!/usr/bin/env node
// tools/tests/run.js
//
// Node.js test runner for smgp-tools.
//
// Discovers all test_*.js files under tools/tests/ and runs them as child
// processes. Reports per-file pass/fail counts and a grand total. Exits
// non-zero if any test fails.
//
// Usage:
//   node tools/tests/run.js [--filter PATTERN] [--verbose]
//
// Options:
//   --filter PATTERN   Only run test files whose basename matches PATTERN
//   --verbose          Print stdout/stderr from passing test files too
//
// Each JS test file is expected to:
//   - Use the assert module (or any assertion library) to signal failures
//   - Call process.exit(0) on full pass (or exit with code 0 implicitly)
//   - Call process.exit(1) (or throw) on failure
//   - Optionally print a summary line matching:
//       Results: X passed, Y failed, Z total
//     for aggregated reporting. If absent, exit code is used (0=pass, non-0=fail).

'use strict';

const { execFileSync, spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..', '..');
const TESTS_DIR = __dirname;

// ---------------------------------------------------------------------------
// Arg parsing
// ---------------------------------------------------------------------------

const argv = process.argv.slice(2);
let filterPattern = null;
let verbose = false;

for (let i = 0; i < argv.length; i++) {
  if (argv[i] === '--filter' && argv[i + 1]) {
    filterPattern = argv[++i];
  } else if (argv[i] === '--verbose' || argv[i] === '-v') {
    verbose = true;
  }
}

// ---------------------------------------------------------------------------
// Discover JS test files
// ---------------------------------------------------------------------------

const allFiles = fs.readdirSync(TESTS_DIR)
  .filter(f => f.startsWith('test_') && f.endsWith('.js'))
  .sort()
  .map(f => path.join(TESTS_DIR, f));

const testFiles = filterPattern
  ? allFiles.filter(f => path.basename(f).includes(filterPattern))
  : allFiles;

// ---------------------------------------------------------------------------
// Run JS tests
// ---------------------------------------------------------------------------

let jsPassed = 0;
let jsFailed = 0;

if (testFiles.length === 0) {
  console.log('No JS test files found (test_*.js). JS test suite is empty.');
} else {
  console.log(`Running ${testFiles.length} JS test file(s)...\n`);

  for (const testFile of testFiles) {
    const rel = path.relative(REPO_ROOT, testFile);
    const result = spawnSync(process.execPath, [testFile], {
      cwd: REPO_ROOT,
      encoding: 'utf8',
    });

    // Try to parse a summary line from stdout
    const summaryMatch = (result.stdout || '').match(
      /Results:\s*(\d+)\s*passed,\s*(\d+)\s*failed/
    );

    const filePassed = summaryMatch ? parseInt(summaryMatch[1], 10) : (result.status === 0 ? 1 : 0);
    const fileFailed = summaryMatch ? parseInt(summaryMatch[2], 10) : (result.status !== 0 ? 1 : 0);
    const fileOk = fileFailed === 0 && result.status === 0;

    if (fileOk) {
      jsPassed += filePassed;
      if (verbose) {
        console.log(`PASS  ${rel}`);
        if (result.stdout) process.stdout.write(result.stdout);
      } else {
        const label = summaryMatch ? `${filePassed} passed` : 'pass';
        console.log(`PASS  ${rel}  (${label})`);
      }
    } else {
      jsFailed += fileFailed || 1;
      jsPassed += filePassed;
      console.log(`FAIL  ${rel}`);
      if (result.stdout) process.stdout.write(result.stdout);
      if (result.stderr) process.stderr.write(result.stderr);
    }
  }
}

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------

if (testFiles.length > 0) {
  console.log(`\n=== JS Test Summary ===`);
  console.log(`Total: ${jsPassed + jsFailed}  Passed: ${jsPassed}  Failed: ${jsFailed}`);
}

process.exit(jsFailed === 0 ? 0 : 1);
