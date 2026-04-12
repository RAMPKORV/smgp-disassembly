'use strict';

const SIGN_ID_POOL = [
	0, 1, 2, 4, 5, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 20,
	21, 22, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 36, 37,
	39, 40, 41, 44, 45, 46, 48, 49, 50,
];

const SIGN_TILESET_OFFSETS = Array.from({ length: 12 }, (_, i) => i * 8);
const STANDARD_SIGN_TILESET_OFFSETS = SIGN_TILESET_OFFSETS.filter(offset => offset !== 80 && offset !== 88);
const HORIZON_SIGN_TILESET_OFFSETS = SIGN_TILESET_OFFSETS.filter(offset => offset !== 88);
const SIGN_TILESET_MIN_SPACING = 1500;
const SAFE_SIGN_TILESET_GUARD_DISTANCE = 256;

const TILESET_SIGN_ID_MAP = new Map([
	[0,  [28, 29]],
	[8,  [28, 29]],
	[16, [4, 5]],
	[24, [16, 17]],
	[32, [20, 21]],
	[40, [24, 25]],
	[48, [32, 33]],
	[56, [36, 37]],
	[64, [40, 41]],
	[72, [44, 45]],
	[80, [12, 13]],
	[88, [2, 50]],
]);

const LEFT_SIGN_IDS = new Set([4, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48]);
const RIGHT_SIGN_IDS = new Set([5, 13, 17, 21, 25, 29, 33, 37, 41, 45, 49]);
const SPECIAL_SIGN_IDS = new Set([48, 49, 50]);

const SIGN_SEQUENCE_SLOT_COUNT = new Map([
	[0, 1], [1, 1], [2, 2], [4, 2], [5, 2], [6, 4], [7, 4],
	[8, 2], [9, 2], [10, 4], [11, 4], [12, 2], [13, 2], [14, 4], [15, 4],
	[16, 2], [17, 2], [18, 4], [19, 4], [20, 2], [21, 2], [22, 4], [23, 4],
	[24, 2], [25, 2], [26, 4], [27, 4], [28, 1], [29, 1], [30, 1], [31, 1],
	[32, 2], [33, 2], [34, 4], [35, 4], [36, 2], [37, 2], [38, 4], [39, 4],
	[40, 2], [41, 2], [42, 4], [43, 4], [44, 2], [45, 2], [46, 4], [47, 4],
	[48, 1], [49, 1], [50, 1],
]);

const TUNNEL_TILESET_OFFSET = 88;
const TUNNEL_ENTRY_SIGN_ID = 49;
const TUNNEL_INTERIOR_SIGN_ID = 2;
const TUNNEL_EXIT_SIGN_ID = 50;

function cyclicTrackDistance(a, b, trackLength) {
	const diff = Math.abs(a - b);
	if (!Number.isInteger(trackLength) || trackLength <= 0) return diff;
	return Math.min(diff, trackLength - diff);
}

function getSignRuntimeRowSpan(signId, count) {
	const sequenceSlots = SIGN_SEQUENCE_SLOT_COUNT.get(signId) || 1;
	const repeatCount = Math.max(1, count | 0);
	return Math.max(1, sequenceSlots * repeatCount);
}

function getActiveTilesetOffset(records, distance) {
	if (!Array.isArray(records) || records.length === 0) return 8;
	let active = records[0].tileset_offset;
	for (const record of records) {
		if (record.distance > distance) break;
		active = record.tileset_offset;
	}
	return active;
}

function getActiveTilesetRecord(signTileset, distance) {
	if (!Array.isArray(signTileset) || signTileset.length === 0) return null;
	let index = 0;
	while (index + 1 < signTileset.length && signTileset[index + 1].distance <= distance) {
		index++;
	}
	return signTileset[index] || null;
}

function isAllowedSignIdForTileset(tilesetOffset, signId, options = {}) {
	if (options.isArcadeWet && tilesetOffset === TUNNEL_TILESET_OFFSET) return true;
	const allowedIds = TILESET_SIGN_ID_MAP.get(tilesetOffset);
	if (!allowedIds) return true;
	if (typeof allowedIds.has === 'function') return allowedIds.has(signId);
	return allowedIds.includes(signId);
}

function pickSignIdForTileset(rng, tilesetOffset, directionalHint = 0) {
	const allowedBase = TILESET_SIGN_ID_MAP.get(tilesetOffset) || SIGN_ID_POOL;
	const allowed = allowedBase.filter(id => !SPECIAL_SIGN_IDS.has(id));
	if (directionalHint < 0) {
		const left = allowed.filter(id => LEFT_SIGN_IDS.has(id));
		if (left.length > 0) return rng.choice(left);
	}
	if (directionalHint > 0) {
		const right = allowed.filter(id => RIGHT_SIGN_IDS.has(id));
		if (right.length > 0) return rng.choice(right);
	}
	const neutral = allowed.filter(id => !LEFT_SIGN_IDS.has(id) && !RIGHT_SIGN_IDS.has(id));
	return rng.choice(neutral.length > 0 ? neutral : allowed);
}

module.exports = {
	SIGN_ID_POOL,
	SIGN_TILESET_OFFSETS,
	STANDARD_SIGN_TILESET_OFFSETS,
	HORIZON_SIGN_TILESET_OFFSETS,
	SIGN_TILESET_MIN_SPACING,
	SAFE_SIGN_TILESET_GUARD_DISTANCE,
	TILESET_SIGN_ID_MAP,
	LEFT_SIGN_IDS,
	RIGHT_SIGN_IDS,
	SPECIAL_SIGN_IDS,
	SIGN_SEQUENCE_SLOT_COUNT,
	TUNNEL_TILESET_OFFSET,
	TUNNEL_ENTRY_SIGN_ID,
	TUNNEL_INTERIOR_SIGN_ID,
	TUNNEL_EXIT_SIGN_ID,
	cyclicTrackDistance,
	getSignRuntimeRowSpan,
	getActiveTilesetOffset,
	getActiveTilesetRecord,
	isAllowedSignIdForTileset,
	pickSignIdForTileset,
};
