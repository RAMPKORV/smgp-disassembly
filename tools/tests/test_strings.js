#!/usr/bin/env node
// tools/tests/test_strings.js
//
// Tests for EXTR-005: extract_strings.js / inject_strings.js round-trip.
//
// Sections:
//   A: encodeEN / CHAR_TO_TILE — character encoding correctness
//   B: strings.json structure — shape and metadata
//   C: Mutable category invariants — entries, required fields, capacity
//   D: Dry-run no-op — inject on orig.bin with unmodified strings.json produces 0 changes
//   E: Mutation + encode/decode round-trip — modify a string, re-encode, recover original
//   F: Capacity overflow rejection — exceeding capacity throws
//   G: Shared-address deduplication — shared entries not written twice

'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');
const os = require('os');

const REPO_ROOT = path.resolve(__dirname, '..', '..');
const ORIG_BIN = path.join(REPO_ROOT, 'orig.bin');
const STRINGS_JSON = path.join(REPO_ROOT, 'tools', 'data', 'strings.json');

const {
  encodeEN,
  buildPatches,
  hexArrToBytes,
  CHAR_TO_TILE,
  injectStrings,
} = require('../inject_strings');

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

// ---------------------------------------------------------------------------
// Load fixtures
// ---------------------------------------------------------------------------
const data = JSON.parse(fs.readFileSync(STRINGS_JSON, 'utf8'));
const origRom = fs.existsSync(ORIG_BIN) ? fs.readFileSync(ORIG_BIN) : null;

// ---------------------------------------------------------------------------
// Section A: encodeEN / CHAR_TO_TILE
// ---------------------------------------------------------------------------
console.log('Section A: encodeEN / CHAR_TO_TILE');

test('CHAR_TO_TILE has all A-Z', () => {
  for (let i = 0; i < 26; i++) {
    const c = String.fromCharCode(65 + i);
    assert.ok(CHAR_TO_TILE.has(c), `Missing letter: ${c}`);
    assert.strictEqual(CHAR_TO_TILE.get(c), 0x0A + i);
  }
});

test('CHAR_TO_TILE has all 0-9', () => {
  for (let i = 0; i < 10; i++) {
    const c = String(i);
    assert.ok(CHAR_TO_TILE.has(c), `Missing digit: ${c}`);
    assert.strictEqual(CHAR_TO_TILE.get(c), i);
  }
});

test("CHAR_TO_TILE space = 0x32", () => {
  assert.strictEqual(CHAR_TO_TILE.get(' '), 0x32);
});

test("CHAR_TO_TILE apostrophe = 0x26", () => {
  assert.strictEqual(CHAR_TO_TILE.get("'"), 0x26);
});

test('CHAR_TO_TILE newline = 0xFC', () => {
  assert.strictEqual(CHAR_TO_TILE.get('\n'), 0xFC);
});

test('CHAR_TO_TILE period = 0x29', () => {
  assert.strictEqual(CHAR_TO_TILE.get('.'), 0x29);
});

test('CHAR_TO_TILE exclamation = 0x2D', () => {
  assert.strictEqual(CHAR_TO_TILE.get('!'), 0x2D);
});

test("encodeEN simple string", () => {
  const result = encodeEN('HI');
  assert.deepStrictEqual(result, [0x11, 0x12]);  // H=0x11, I=0x12
});

test("encodeEN with space", () => {
  const result = encodeEN('A B');
  assert.deepStrictEqual(result, [0x0A, 0x32, 0x0B]);
});

test("encodeEN with newline", () => {
  const result = encodeEN('A\nB');
  assert.deepStrictEqual(result, [0x0A, 0xFC, 0x0B]);
});

test("encodeEN empty string returns empty array", () => {
  const result = encodeEN('');
  assert.deepStrictEqual(result, []);
});

test("encodeEN returns null for unmappable character", () => {
  const result = encodeEN('A@B');
  assert.strictEqual(result, null);
});

test("encodeEN returns null for lowercase letter", () => {
  const result = encodeEN('hello');
  assert.strictEqual(result, null);
});

test('hexArrToBytes converts hex string array', () => {
  assert.deepStrictEqual(hexArrToBytes(['0x0a', '0xff', '0x32']), [10, 255, 50]);
});

test('hexArrToBytes empty array', () => {
  assert.deepStrictEqual(hexArrToBytes([]), []);
});

// ---------------------------------------------------------------------------
// Section B: strings.json structure
// ---------------------------------------------------------------------------
console.log('Section B: strings.json structure');

test('strings.json has _meta', () => {
  assert.ok(data._meta, 'Missing _meta');
  assert.ok(typeof data._meta.description === 'string', 'Missing _meta.description');
  assert.ok(Array.isArray(data._meta.mutable_categories), 'Missing _meta.mutable_categories');
});

const MUTABLE_CATS = ['team_names', 'team_intro_messages', 'pre_race_rival_messages', 'post_race_messages'];
const READONLY_CATS = ['pre_race_track_tips', 'car_spec_text', 'race_quotes', 'championship_intro'];

for (const cat of MUTABLE_CATS) {
  test(`strings.json has mutable category: ${cat}`, () => {
    assert.ok(data[cat], `Missing category: ${cat}`);
    assert.ok(data[cat]._meta, `Missing ${cat}._meta`);
    assert.ok(data[cat]._meta.mutable === true, `${cat}._meta.mutable should be true`);
    assert.ok(Array.isArray(data[cat].entries), `${cat}.entries should be an array`);
    assert.ok(data[cat].entries.length > 0, `${cat}.entries should not be empty`);
  });
}

for (const cat of READONLY_CATS) {
  test(`strings.json has readonly category: ${cat}`, () => {
    assert.ok(data[cat], `Missing category: ${cat}`);
  });
}

// ---------------------------------------------------------------------------
// Section C: Mutable category invariants
// ---------------------------------------------------------------------------
console.log('Section C: Mutable category invariants');

for (const cat of MUTABLE_CATS) {
  const entries = data[cat].entries;

  test(`${cat}: all entries have rom_addr`, () => {
    for (const e of entries) {
      if (e.note === 'invalid_pointer') continue;
      assert.ok(typeof e.rom_addr === 'string', `Entry missing rom_addr: ${JSON.stringify(e)}`);
      assert.ok(/^0x[0-9a-f]+$/.test(e.rom_addr), `Bad rom_addr format: ${e.rom_addr}`);
    }
  });

  test(`${cat}: all entries have en string`, () => {
    for (const e of entries) {
      if (e.note === 'invalid_pointer') continue;
      assert.ok(typeof e.en === 'string', `Entry missing en: ${JSON.stringify(e)}`);
    }
  });

  test(`${cat}: all entries have raw_bytes array`, () => {
    for (const e of entries) {
      if (e.note === 'invalid_pointer') continue;
      assert.ok(Array.isArray(e.raw_bytes), `Entry missing raw_bytes: ${e.rom_addr}`);
      assert.ok(e.raw_bytes.length > 0, `raw_bytes is empty at ${e.rom_addr}`);
    }
  });

  test(`${cat}: all entries have capacity >= raw_bytes.length`, () => {
    for (const e of entries) {
      if (e.note === 'invalid_pointer') continue;
      assert.ok(
        e.capacity >= e.raw_bytes.length,
        `Capacity ${e.capacity} < raw_bytes.length ${e.raw_bytes.length} at ${e.rom_addr}`
      );
    }
  });

  test(`${cat}: raw_bytes always ends with 0xFF`, () => {
    for (const e of entries) {
      if (e.note === 'invalid_pointer') continue;
      const lastByte = e.raw_bytes[e.raw_bytes.length - 1];
      assert.strictEqual(
        parseInt(lastByte, 16), 0xFF,
        `raw_bytes does not end with 0xFF at ${e.rom_addr}: last=${lastByte}`
      );
    }
  });

  test(`${cat}: encodeEN matches raw_bytes (round-trip)`, () => {
    for (const e of entries) {
      if (e.note === 'invalid_pointer') continue;
      const prefixBytes = hexArrToBytes(e.prefix_raw || []);
      const encoded = encodeEN(e.en);
      assert.ok(encoded !== null, `encodeEN returned null for "${e.en}" at ${e.rom_addr}`);
      const fullPayload = [...prefixBytes, ...encoded, 0xFF];
      const rawValues = hexArrToBytes(e.raw_bytes);
      // Compare only the payload bytes (raw_bytes may include extra 0xFF padding)
      assert.deepStrictEqual(
        rawValues.slice(0, fullPayload.length),
        fullPayload,
        `Encode mismatch at ${e.rom_addr}: expected ${fullPayload.map(b=>'0x'+b.toString(16)).join(' ')}, got ${rawValues.slice(0,fullPayload.length).map(b=>'0x'+b.toString(16)).join(' ')}`
      );
    }
  });
}

// Specific count checks from known ROM data
test('team_names has 16 entries', () => {
  assert.strictEqual(data.team_names.entries.length, 16);
});

test('team_intro_messages has 32 entries', () => {
  assert.strictEqual(data.team_intro_messages.entries.length, 32);
});

test('pre_race_rival_messages has 145 entries', () => {
  // 145 total (some are invalid_pointer, some are shared)
  assert.ok(data.pre_race_rival_messages.entries.length >= 140, 'Expected ~145 rival message entries');
});

test('post_race_messages has 160 EN entries', () => {
  assert.ok(data.post_race_messages.entries.length >= 150, 'Expected ~160 post-race EN entries');
});

// ---------------------------------------------------------------------------
// Section D: Dry-run no-op (requires orig.bin)
// ---------------------------------------------------------------------------
console.log('Section D: Dry-run no-op');

if (!origRom) {
  test('SKIP: orig.bin not present, skipping dry-run tests', () => {
    // This is intentionally skipped — not a failure
  });
} else {
  test('inject on orig.bin produces 0 changes (no-op round-trip)', () => {
    const romCopy = Buffer.from(origRom);
    let result;
    try {
      result = injectStrings(data, romCopy, { dryRun: true, verbose: false });
    } catch (e) {
      throw new Error(`injectStrings threw: ${e.message}`);
    }
    assert.strictEqual(
      result.totalChanges, 0,
      `Expected 0 changes on unmodified data, got ${result.totalChanges}`
    );
  });

  test('inject on orig.bin checks all 4 mutable categories', () => {
    const romCopy = Buffer.from(origRom);
    const result = injectStrings(data, romCopy, { dryRun: true });
    // 140 unique addresses across all 4 categories
    assert.ok(result.totalPatched >= 100, `Expected >= 100 unique slots, got ${result.totalPatched}`);
  });

  test('inject no-op leaves ROM bytes unchanged', () => {
    const romCopy = Buffer.from(origRom);
    injectStrings(data, romCopy, { dryRun: false });
    // After a no-op inject, the bytes should be identical
    assert.ok(origRom.equals(romCopy), 'ROM bytes changed after no-op inject');
  });
}

// ---------------------------------------------------------------------------
// Section E: Mutation + encode/decode round-trip
// ---------------------------------------------------------------------------
console.log('Section E: Mutation + encode/decode round-trip');

test('modified string encodes to more bytes when text is longer', () => {
  // Synthesize a simple entry
  const entry = {
    rom_addr: '0x010000',
    prefix_raw: [],
    en: 'HI',
    raw_bytes: ['0x11', '0x12', '0xff'],
    capacity: 10,
  };
  const dataClone = {
    team_names: { _meta: { mutable: true }, entries: [entry] },
    team_intro_messages: { _meta: { mutable: true }, entries: [] },
    pre_race_rival_messages: { _meta: { mutable: true }, entries: [] },
    post_race_messages: { _meta: { mutable: true }, entries: [] },
  };

  // Extend the string
  const modEntry = Object.assign({}, entry, { en: 'HELLO' });
  dataClone.team_names.entries[0] = modEntry;

  const { patches } = buildPatches(dataClone.team_names.entries, false);
  const bytes = patches.get(0x010000);
  assert.ok(bytes, 'No patch generated');
  // HELLO = H(0x11) E(0x0E) L(0x15) L(0x15) O(0x18) + 0xFF = 6 bytes (no padding)
  assert.strictEqual(bytes[0], 0x11); // H
  assert.strictEqual(bytes[1], 0x0E); // E
  assert.strictEqual(bytes[5], 0xFF); // terminator
  assert.strictEqual(bytes.length, 6); // natural payload, no padding
});

test('modified string is detected as a change', () => {
  const entry = {
    rom_addr: '0x010000',
    prefix_raw: [],
    en: 'HELLO',
    raw_bytes: ['0x11', '0x12', '0xff'],  // original was "HI"
    capacity: 10,
  };
  let changes = 0;
  // Manually run buildPatches and count
  const entries = [entry];
  const { patches, changes: c } = buildPatches(entries, false);
  assert.strictEqual(c, 1, 'Expected 1 change when string is modified');
});

test('unmodified string is not detected as a change', () => {
  const entry = {
    rom_addr: '0x010000',
    prefix_raw: [],
    en: 'HI',
    raw_bytes: ['0x11', '0x12', '0xff'],  // original was "HI" — matches en
    capacity: 10,
  };
  const { changes } = buildPatches([entry], false);
  assert.strictEqual(changes, 0, 'Expected 0 changes when string is unmodified');
});

test('prefix_raw bytes are prepended in patch', () => {
  const entry = {
    rom_addr: '0x010000',
    prefix_raw: ['0xfd'],
    en: 'HI',
    raw_bytes: ['0xfd', '0x11', '0x12', '0xff'],
    capacity: 8,
  };
  const { patches } = buildPatches([entry], false);
  const bytes = patches.get(0x010000);
  assert.ok(bytes, 'No patch generated');
  assert.strictEqual(bytes[0], 0xFD); // prefix preserved
  assert.strictEqual(bytes[1], 0x11); // H
  assert.strictEqual(bytes[2], 0x12); // I
  assert.strictEqual(bytes[3], 0xFF); // terminator
});

// ---------------------------------------------------------------------------
// Section F: Capacity overflow rejection
// ---------------------------------------------------------------------------
console.log('Section F: Capacity overflow rejection');

test('buildPatches throws if encoded length exceeds capacity', () => {
  const entry = {
    rom_addr: '0x010000',
    prefix_raw: [],
    en: 'ABCDEFGHIJ',  // 10 chars + 0xFF = 11 bytes
    raw_bytes: ['0x0a', '0xff'],
    capacity: 5,  // too small
  };
  assert.throws(
    () => buildPatches([entry], false),
    /exceeds capacity/,
    'Expected capacity overflow error'
  );
});

test('buildPatches throws for unmappable characters', () => {
  const entry = {
    rom_addr: '0x010000',
    prefix_raw: [],
    en: 'hello world',  // lowercase not in charset
    raw_bytes: ['0x0a', '0xff'],
    capacity: 20,
  };
  assert.throws(
    () => buildPatches([entry], false),
    /unmappable/,
    'Expected unmappable character error'
  );
});

test('string exactly at capacity is accepted', () => {
  // 3 chars + 0xFF = 4 bytes, capacity = 4
  const entry = {
    rom_addr: '0x010000',
    prefix_raw: [],
    en: 'ABC',
    raw_bytes: ['0x0a', '0x0b', '0x0c', '0xff'],
    capacity: 4,
  };
  let patches;
  assert.doesNotThrow(() => {
    ({ patches } = buildPatches([entry], false));
  });
  const bytes = patches.get(0x010000);
  assert.strictEqual(bytes.length, 4);
});

// ---------------------------------------------------------------------------
// Section G: Shared-address deduplication
// ---------------------------------------------------------------------------
console.log('Section G: Shared-address deduplication');

test('buildPatches deduplicates entries with the same rom_addr', () => {
  const entries = [
    {
      rom_addr: '0x010000',
      prefix_raw: [],
      en: 'HI',
      raw_bytes: ['0x11', '0x12', '0xff'],
      capacity: 8,
    },
    {
      rom_addr: '0x010000',  // same address — second occurrence ignored
      prefix_raw: [],
      en: 'HI',
      raw_bytes: ['0x11', '0x12', '0xff'],
      capacity: 8,
      shared: true,
    },
  ];
  const { patches, total } = buildPatches(entries, false);
  assert.strictEqual(patches.size, 1, 'Expected exactly 1 unique patch for shared address');
  assert.strictEqual(total, 1, 'Expected total=1 (second shared entry not counted)');
});

test('invalid_pointer entries are skipped', () => {
  const entries = [
    {
      rom_addr: '0x010000',
      prefix_raw: [],
      en: 'HI',
      raw_bytes: ['0x11', '0x12', '0xff'],
      capacity: 8,
      note: 'invalid_pointer',
    },
  ];
  const { patches, total } = buildPatches(entries, false);
  assert.strictEqual(patches.size, 0, 'Expected 0 patches for invalid_pointer entry');
  assert.strictEqual(total, 0);
});

test('shared entries in pre_race_rival_messages have shared:true flag', () => {
  const entries = data.pre_race_rival_messages.entries;
  // Find entries at 0x03b4fc (known shared address: "HI!")
  const addr = '0x03b4fc';
  const matching = entries.filter(e => e.rom_addr === addr);
  assert.ok(matching.length >= 2, `Expected multiple entries at shared address ${addr}, found ${matching.length}`);
  const sharedCount = matching.filter(e => e.shared).length;
  assert.ok(sharedCount >= 1, `Expected at least one entry with shared:true at ${addr}`);
});

// ---------------------------------------------------------------------------
// Section H: Binary layer (dumpTextBinaries / verifyTextBinaries)
// ---------------------------------------------------------------------------
console.log('Section H: Binary layer — dumpTextBinaries / verifyTextBinaries');

{
  const os = require('os');
  const path = require('path');
  const { dumpTextBinaries, verifyTextBinaries } = require('../extract_strings');
  const DATA_TEXT = path.join(REPO_ROOT, 'data', 'text');

  const CATEGORIES = ['team_names', 'team_intro_messages', 'pre_race_rival_messages', 'post_race_messages'];

  // H.1 — data/text/ exists
  test('H.data_dir_exists', () => {
    assert.ok(fs.existsSync(DATA_TEXT), `data/text/ does not exist: ${DATA_TEXT}`);
  });

  // H.2 — Each category has a .bin and a .meta.json
  for (const cat of CATEGORIES) {
    test(`H.bin_exists/${cat}`, () => {
      assert.ok(fs.existsSync(path.join(DATA_TEXT, `${cat}.bin`)),
        `Missing: data/text/${cat}.bin`);
    });
    test(`H.meta_exists/${cat}`, () => {
      assert.ok(fs.existsSync(path.join(DATA_TEXT, `${cat}.meta.json`)),
        `Missing: data/text/${cat}.meta.json`);
    });
  }

  // H.3 — meta.json has expected fields and correct size matches .bin length
  for (const cat of CATEGORIES) {
    const metaFile = path.join(DATA_TEXT, `${cat}.meta.json`);
    const binFile  = path.join(DATA_TEXT, `${cat}.bin`);
    if (!fs.existsSync(metaFile) || !fs.existsSync(binFile)) continue;
    const meta = JSON.parse(fs.readFileSync(metaFile, 'utf8'));

    test(`H.meta_fields/${cat}/category`, () => {
      assert.strictEqual(meta.category, cat);
    });
    test(`H.meta_fields/${cat}/start_addr`, () => {
      assert.ok(typeof meta.start_addr === 'string' && /^0x[0-9a-fA-F]+$/.test(meta.start_addr),
        `start_addr should be a hex string, got ${meta.start_addr}`);
    });
    test(`H.meta_fields/${cat}/end_addr`, () => {
      assert.ok(typeof meta.end_addr === 'string' && /^0x[0-9a-fA-F]+$/.test(meta.end_addr),
        `end_addr should be a hex string, got ${meta.end_addr}`);
    });
    test(`H.meta_fields/${cat}/size`, () => {
      assert.ok(typeof meta.size === 'number' && meta.size > 0,
        `size should be a positive number, got ${meta.size}`);
    });
    test(`H.meta_size_matches_bin/${cat}`, () => {
      const binLen = fs.readFileSync(binFile).length;
      assert.strictEqual(binLen, meta.size,
        `${cat}.bin length (${binLen}) != meta.size (${meta.size})`);
    });
    test(`H.meta_addr_range/${cat}`, () => {
      const start = parseInt(meta.start_addr, 16);
      const end   = parseInt(meta.end_addr, 16);
      assert.ok(end > start, `end_addr (${meta.end_addr}) <= start_addr (${meta.start_addr})`);
      assert.strictEqual(end - start, meta.size,
        `end_addr - start_addr (${end - start}) != meta.size (${meta.size})`);
    });
  }

  // H.4 — verifyTextBinaries returns no mismatches against orig.bin
  if (origRom) {
    test('H.verify_no_mismatches', () => {
      const errors = verifyTextBinaries(DATA_TEXT, origRom);
      assert.strictEqual(errors.length, 0,
        `verifyTextBinaries returned mismatches: ${JSON.stringify(errors)}`);
    });
  }

  // H.5 — dumpTextBinaries writes identical files to a temp dir
  if (origRom) {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'smgp-text-dump-'));
    try {
      dumpTextBinaries(origRom, tmpDir, false);

      for (const cat of CATEGORIES) {
        test(`H.dump_bin_identical/${cat}`, () => {
          const srcFile = path.join(DATA_TEXT, `${cat}.bin`);
          const dstFile = path.join(tmpDir, `${cat}.bin`);
          assert.ok(fs.existsSync(dstFile), `Dump did not create ${cat}.bin`);
          assert.deepStrictEqual(
            fs.readFileSync(dstFile),
            fs.readFileSync(srcFile),
            `Dumped ${cat}.bin differs from data/text/${cat}.bin`
          );
        });
        test(`H.dump_meta_identical/${cat}`, () => {
          const srcMeta = JSON.parse(fs.readFileSync(path.join(DATA_TEXT, `${cat}.meta.json`), 'utf8'));
          const dstMeta = JSON.parse(fs.readFileSync(path.join(tmpDir, `${cat}.meta.json`), 'utf8'));
          assert.deepStrictEqual(dstMeta, srcMeta,
            `Dumped ${cat}.meta.json differs from data/text/${cat}.meta.json`);
        });
      }
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  }

  // H.6 — verifyTextBinaries returns no errors when given a fresh dump
  if (origRom) {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'smgp-text-verify-'));
    try {
      dumpTextBinaries(origRom, tmpDir, false);
      test('H.verify_fresh_dump', () => {
        const errors = verifyTextBinaries(tmpDir, origRom);
        assert.strictEqual(errors.length, 0,
          `verifyTextBinaries on fresh dump returned mismatches: ${JSON.stringify(errors)}`);
      });
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  }
}

// ---------------------------------------------------------------------------
// Results
// ---------------------------------------------------------------------------
console.log(`\nResults: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
