#!/usr/bin/env node
'use strict';

const path = require('path');
const { spawnSync } = require('child_process');

const scriptPath = path.join(__dirname, 'test_randomizer.js');
const result = spawnSync(process.execPath, [scriptPath, '--slow', ...process.argv.slice(2)], {
	stdio: 'inherit',
});

process.exit(result.status === null ? 1 : result.status);
