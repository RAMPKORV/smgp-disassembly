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

## Frozen compact baselines

- `tools/data/randomizer_baselines.json` is the compact frozen summary of the
  current curve-first generator.
- `tools/data/minimap_validation_snapshots.json` is the compact frozen summary
  of current minimap validation/reporting behaviour.
- Refresh either fixture only when behaviour drift is intentional, and record
  the reason in `track-randomization-revamp-todos.json` and companion docs.
- The active map-first baselines now intentionally encode geometry-driven
  preview transforms, topology summaries, and any sign-count drift caused by
  geometry-first candidate selection or crossing-safe underpass handling.

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

For the map-first crossing revamp, keep one known non-crossing seed and one
known crossing seed handy for manual checks. Current stable examples:

- non-crossing workspace regression seed: `SMGP-1-01-12345`
- crossing spot-check seed for track 0: master seed `48`

## Canonical artifact boundaries

- Canonical root track bytes come from `orig.bin` plus the committed
  `data/tracks/<slug>/*.bin` blobs that the assembler consumes.
- `tools/data/tracks.json` is the structured edit surface, not the canonical
  proof of root bytes.
- Generated wrappers such as `src/road_and_track_data_generated.asm` and
  `data/tracks/generated_minimap_data.asm` are reproducible workspace artifacts;
  they must stay in sync with the canonical blobs, but they are not the source
  used to prove root restoration.
- `tools/restore_tracks.js --verify` must restore the root tree from canonical
  blob sources / checkpoints and only then run canonical `verify.bat`; do not
  treat a JSON re-encode as proof that canonical root bytes were restored.

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

## Runtime escalation gate

- Phase 1 remains tooling-first even for the new single-crossing path.
- Only escalate into ASM/runtime work when generated preview assets cannot make
  the underpass readable while keeping the border intact, or when tunnel-style
  lower-branch handling proves behaviorally insufficient.
- If escalation is required, document the missing behavior first and narrow it
  to the specific runtime files called out in `track-randomization-revamp-todos.json`.
