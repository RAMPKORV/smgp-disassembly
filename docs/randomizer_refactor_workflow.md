# Randomizer Refactor Workflow

This is the required safety loop for future randomizer and workspace-tool refactors.

## Operating model

- Keep `master` / the repo root bit-perfect-buildable at all times.
- Treat `tools/hack_workdir.js` and the workspace-safe default `tools/randomize.js` flow as the normal path.
- Use `tools/randomize.js --in-root` only for deliberate debugging when a workspace build is not enough.
- Close every meaningful checkpoint with canonical PowerShell `verify.bat`.

## Before changing behavior-sensitive code

1. Read the active task in `randomizer-refactor-todos.json`.
2. Decide whether the change is structural, algorithmic, or only reporting/tooling.
3. Add or expand direct tests before moving risky helpers.
4. Freeze compact baselines before algorithm or data-flow changes.
5. Prefer narrow helper extraction over broad churn.

## Fast refactor loop

Use the smallest relevant fast tier first. Typical commands:

```text
node tools/tests/test_randomize_actions.js
node tools/tests/test_randomize_modules.js
node tools/tests/test_randomizer_cli.js
node tools/tests/test_hack_workdir.js
node tools/tests/test_randomizer_smoke.js --no-build
```

Add more focused suites when the change touches a specific subsystem, for example:

- minimap packaging/reporting: `tools/tests/test_generated_minimap_assets.js`, `tools/tests/test_generated_minimap_pos.js`, `tools/tests/test_minimap_cli_tools.js`
- workspace/build flow: `tools/tests/test_canonical_build.js`, `tools/tests/test_workspace_guard.js`, `tools/tests/test_hack_workdir.js`
- checkpoint/restore flow: `tools/tests/test_in_root_checkpoint.js`, `tools/tests/test_randomize_actions.js`

## Workspace-safe validation

Before claiming a tool-flow refactor is safe, run a real workspace build:

```text
node tools/hack_workdir.js SMGP-1-01-12345 --keep --force --output build/roms/test_randomized.bin
```

This must succeed without mutating the repo root.

## In-root debug workflow

Only use this when workspace-safe validation is not enough:

```text
node tools/randomize.js SMGP-1-01-12345 --in-root
```

Rules:

- Starting an in-root run creates an explicit checkpoint in `build/checkpoints/in_root_debug/`.
- Do not start another in-root session while that checkpoint exists.
- `tools/restore_tracks.js` restores the checkpoint and removes it.
- Legacy `*.orig.*` backups are compatibility fallback only; new work should rely on the checkpoint flow.

To restore and re-confirm the root tree:

```text
node tools/restore_tracks.js --verify
```

## Closing a refactor checkpoint

Run the appropriate full checkpoint validation before marking the task done:

```text
node tools/tests/test_randomizer_smoke.js
powershell -NoProfile -ExecutionPolicy Bypass -Command "& .\verify.bat"
```

If behavior changed intentionally, update the relevant baselines and note the reason in the roadmap or companion docs instead of silently accepting drift.
