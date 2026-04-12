'use strict';

class XorShift32 {
	constructor(seed) {
		this.state = (seed !== 0) ? (seed >>> 0) : 1;
	}

	next() {
		let x = this.state;
		x ^= (x << 13) & 0xFFFFFFFF;
		x ^= (x >>> 17);
		x ^= (x << 5) & 0xFFFFFFFF;
		this.state = x >>> 0;
		return this.state;
	}

	randInt(lo, hi) {
		const span = hi - lo + 1;
		return lo + (this.next() % span);
	}

	randFloat() {
		return (this.next() & 0xFFFFFF) / 0x1000000;
	}

	choice(items) {
		return items[this.next() % items.length];
	}

	weightedChoice(items, weights) {
		const total = weights.reduce((a, b) => a + b, 0);
		let r = this.next() % total;
		for (let i = 0; i < items.length; i++) {
			r -= weights[i];
			if (r < 0) return items[i];
		}
		return items[items.length - 1];
	}
}

const MOD_TRACK_CURVES  = 1;
const MOD_TRACK_SLOPES  = 2;
const MOD_TRACK_SIGNS   = 3;
const MOD_TRACK_MINIMAP = 4;
const MOD_TRACK_CONFIG  = 5;
const MOD_TEAMS         = 6;
const MOD_AI            = 7;
const MOD_CHAMPIONSHIP  = 8;

function deriveSubseed(masterSeed, moduleId) {
	let x = ((masterSeed >>> 0) ^ ((moduleId * 0x9E3779B9) >>> 0)) >>> 0;
	x ^= (x << 13) & 0xFFFFFFFF;
	x ^= (x >>> 17);
	x ^= (x << 5) & 0xFFFFFFFF;
	x = x >>> 0;
	return x !== 0 ? x : 1;
}

const FLAG_TRACKS       = 0x01;
const FLAG_TRACK_CONFIG = 0x02;
const FLAG_TEAMS        = 0x04;
const FLAG_AI           = 0x08;
const FLAG_CHAMPIONSHIP = 0x10;
const FLAG_SIGNS        = 0x20;
const FLAG_ALL          = 0x3F;

const SEED_RE = /^SMGP-(\d+)-([0-9A-Fa-f]+)-(\d+)$/;

function parseSeed(seedStr) {
	const m = SEED_RE.exec(seedStr.trim());
	if (!m) {
		throw new Error(
			`Invalid seed format: ${JSON.stringify(seedStr)}  (expected SMGP-<v>-<flags_hex>-<decimal>)`
		);
	}
	const version = parseInt(m[1], 10);
	const flags   = parseInt(m[2], 16);
	const seed    = parseInt(m[3], 10);
	return [version, flags, seed];
}

module.exports = {
	XorShift32,
	MOD_TRACK_CURVES,
	MOD_TRACK_SLOPES,
	MOD_TRACK_SIGNS,
	MOD_TRACK_MINIMAP,
	MOD_TRACK_CONFIG,
	MOD_TEAMS,
	MOD_AI,
	MOD_CHAMPIONSHIP,
	deriveSubseed,
	FLAG_TRACKS,
	FLAG_TRACK_CONFIG,
	FLAG_TEAMS,
	FLAG_AI,
	FLAG_CHAMPIONSHIP,
	FLAG_SIGNS,
	FLAG_ALL,
	parseSeed,
};
