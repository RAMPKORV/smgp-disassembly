#!/usr/bin/env node
'use strict';

const assert = require('assert');
const { readJson } = require('../lib/json');
const { validateTracks } = require('../randomizer/track_validator');

let passed = 0;
let failed = 0;

function test(name, fn) {
  try {
    fn();
    passed++;
  } catch (err) {
    failed++;
    console.error(`FAIL: ${name}`);
    console.error(`  ${err.message}`);
  }
}

const data = readJson('tools/data/tracks.json');

test('current tracks pass runtime-oriented validator checks', () => {
  const errors = validateTracks(data.tracks);
  assert.strictEqual(errors.length, 0, errors.slice(0, 10).map(e => e.toString()).join('\n'));
});

console.log(`\nResults: ${passed} passed, ${failed} failed, ${passed + failed} total`);
if (failed > 0) process.exit(1);
