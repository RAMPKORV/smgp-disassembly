'use strict';

const fs = require('fs');
const path = require('path');

const { XorShift32, deriveSubseed, MOD_TRACK_CONFIG } = require('./randomizer_shared');

const CHAMPIONSHIP_ART_SETS = [
	{ art_name: 'San_Marino', horizon_override: 0, steering: '$002B002B', bg_palette_label: 'San_Marino_bg_palette', sideline_label: 'San_Marino_sideline_style', road_label: 'San_Marino_road_style', finish_label: 'San_Marino_finish_line_style', bg_tiles_label: 'Track_bg_tiles_San_Marino', bg_tilemap_label: 'Track_bg_tilemap_San_Marino', minimap_tiles_label: 'Minimap_tiles_San_Marino', minimap_map_label: 'Minimap_map_San_Marino' },
	{ art_name: 'Brazil', horizon_override: 0, steering: '$002B002B', bg_palette_label: 'Brazil_bg_palette', sideline_label: 'Brazil_sideline_style', road_label: 'Brazil_road_style', finish_label: 'Brazil_finish_line_style', bg_tiles_label: 'Track_bg_tiles_Brazil', bg_tilemap_label: 'Track_bg_tilemap_Brazil', minimap_tiles_label: 'Minimap_tiles_Brazil', minimap_map_label: 'Minimap_map_Brazil' },
	{ art_name: 'France', horizon_override: 0, steering: '$002B002B', bg_palette_label: 'France_bg_palette', sideline_label: 'France_sideline_style', road_label: 'France_road_style', finish_label: 'France_finish_line_style', bg_tiles_label: 'Track_bg_tiles_France', bg_tilemap_label: 'Track_bg_tilemap_France', minimap_tiles_label: 'Minimap_tiles_France', minimap_map_label: 'Minimap_map_France' },
	{ art_name: 'Hungary', horizon_override: 0, steering: '$002c002e', bg_palette_label: 'Hungary_bg_palette', sideline_label: 'Hungary_sideline_style', road_label: 'Hungary_road_style', finish_label: 'Hungary_finish_line_style', bg_tiles_label: 'Track_bg_tiles_Hungary', bg_tilemap_label: 'Track_bg_tilemap_Hungary', minimap_tiles_label: 'Minimap_tiles_Hungary', minimap_map_label: 'Minimap_map_Hungary' },
	{ art_name: 'West_Germany', horizon_override: 1, steering: '$002B002B', bg_palette_label: 'West_Germany_bg_palette', sideline_label: 'West_Germany_sideline_style', road_label: 'West_Germany_road_style', finish_label: 'West_Germany_finish_line_style', bg_tiles_label: 'Track_bg_tiles_West_Germany', bg_tilemap_label: 'Track_bg_tilemap_West_Germany', minimap_tiles_label: 'Minimap_tiles_West_Germany', minimap_map_label: 'Minimap_map_West_Germany' },
	{ art_name: 'Usa', horizon_override: 0, steering: '$002B002B', bg_palette_label: 'Usa_bg_palette', sideline_label: 'Usa_sideline_style', road_label: 'Usa_road_style', finish_label: 'Usa_finish_line_style', bg_tiles_label: 'Track_bg_tiles_Usa', bg_tilemap_label: 'Track_bg_tilemap_Usa', minimap_tiles_label: 'Minimap_tiles_USA', minimap_map_label: 'Minimap_map_USA' },
	{ art_name: 'Canada', horizon_override: 0, steering: '$002B002B', bg_palette_label: 'Canada_bg_palette', sideline_label: 'Canada_sideline_style', road_label: 'Canada_road_style', finish_label: 'Canada_finish_line_style', bg_tiles_label: 'Track_bg_tiles_Canada', bg_tilemap_label: 'Track_bg_tilemap_Canada', minimap_tiles_label: 'Minimap_tiles_Canada', minimap_map_label: 'Minimap_map_Canada' },
	{ art_name: 'Great_Britain', horizon_override: 0, steering: '$002B002B', bg_palette_label: 'Great_Britain_bg_palette', sideline_label: 'Great_Britain_sideline_style', road_label: 'Great_Britain_road_style', finish_label: 'Great_Britain_finish_line_style', bg_tiles_label: 'Track_bg_tiles_Great_Britain', bg_tilemap_label: 'Track_bg_tilemap_Great_Britain', minimap_tiles_label: 'Minimap_tiles_Great_Britain', minimap_map_label: 'Minimap_map_Great_Britain' },
	{ art_name: 'Italy', horizon_override: 1, steering: '$002B002B', bg_palette_label: 'Italy_bg_palette-2', sideline_label: 'Italy_sideline_style', road_label: 'Italy_road_style', finish_label: 'Italy_finish_line_style', bg_tiles_label: 'Track_bg_tiles_Italy', bg_tilemap_label: 'Track_bg_tilemap_Italy', minimap_tiles_label: 'Minimap_tiles_Italy', minimap_map_label: 'Minimap_map_Italy' },
	{ art_name: 'Portugal', horizon_override: 0, steering: '$002B002B', bg_palette_label: 'Portugal_bg_palette', sideline_label: 'Portugal_sideline_style', road_label: 'Portugal_road_style', finish_label: 'Portugal_finish_line_style', bg_tiles_label: 'Track_bg_tiles_Portugal', bg_tilemap_label: 'Track_bg_tilemap_Portugal', minimap_tiles_label: 'Minimap_tiles_Portugal', minimap_map_label: 'Minimap_map_Portugal' },
	{ art_name: 'Spain', horizon_override: 0, steering: '$002B002B', bg_palette_label: 'Spain_bg_palette', sideline_label: 'Spain_sideline_style', road_label: 'Spain_road_style', finish_label: 'Spain_finish_line_style', bg_tiles_label: 'Track_bg_tiles_Spain', bg_tilemap_label: 'Track_bg_tilemap_Spain', minimap_tiles_label: 'Minimap_tiles_Spain', minimap_map_label: 'Minimap_map_Spain' },
	{ art_name: 'Mexico', horizon_override: 0, steering: '$002B002B', bg_palette_label: 'Mexico_bg_palette', sideline_label: 'Mexico_sideline_style', road_label: 'Mexico_road_style', finish_label: 'Mexico_finish_line_style', bg_tiles_label: 'Track_bg_tiles_Mexico', bg_tilemap_label: 'Track_bg_tilemap_Mexico', minimap_tiles_label: 'Minimap_tiles_Mexico', minimap_map_label: 'Minimap_map_Mexico' },
	{ art_name: 'Japan', horizon_override: 0, steering: '$002B002B', bg_palette_label: 'Japan_bg_palette', sideline_label: 'Japan_sideline_style', road_label: 'Japan_road_style', finish_label: 'Japan_finish_line_style', bg_tiles_label: 'Track_bg_tiles_Japan', bg_tilemap_label: 'Track_bg_tilemap_Japan', minimap_tiles_label: 'Minimap_tiles_Japan', minimap_map_label: 'Minimap_map_Japan' },
	{ art_name: 'Belgium', horizon_override: 1, steering: '$002B002B', bg_palette_label: 'Belgium_bg_palette', sideline_label: 'Belgium_sideline_style', road_label: 'Belgium_road_style', finish_label: 'Belgium_finish_line_style', bg_tiles_label: 'Track_bg_tiles_Belgium', bg_tilemap_label: 'Track_bg_tilemap_Belgium', minimap_tiles_label: 'Minimap_tiles_Belgium', minimap_map_label: 'Minimap_map_Belgium' },
	{ art_name: 'Australia', horizon_override: 0, steering: '$002B002B', bg_palette_label: 'Australia_bg_palette', sideline_label: 'Australia_sideline_style', road_label: 'Australia_road_style', finish_label: 'Australia_finish_line_style', bg_tiles_label: 'Track_bg_tiles_Australia', bg_tilemap_label: 'Track_bg_tilemap_Australia', minimap_tiles_label: 'Minimap_tiles_Australia', minimap_map_label: 'Minimap_map_Australia' },
	{ art_name: 'Monaco', horizon_override: 0, steering: '$002B002B', bg_palette_label: 'Monaco_bg_palette', sideline_label: 'Monaco_sideline_style', road_label: 'Monaco_road_style', finish_label: 'Monaco_finish_line_style', bg_tiles_label: 'Track_bg_tiles_Monaco', bg_tilemap_label: 'Track_bg_tilemap_Monaco', minimap_tiles_label: 'Minimap_tiles_Monaco', minimap_map_label: 'Minimap_map_Monaco' },
];

const CHAMPIONSHIP_TRACK_NAMES = [
	'San Marino', 'Brazil', 'France', 'Hungary', 'West Germany',
	'USA', 'Canada', 'Great Britain', 'Italy', 'Portugal',
	'Spain', 'Mexico', 'Japan', 'Belgium', 'Australia', 'Monaco',
];

function _shuffleList(items, rng) {
	const lst = items.slice();
	for (let i = lst.length - 1; i > 0; i--) {
		const j = rng.next() % (i + 1);
		[lst[i], lst[j]] = [lst[j], lst[i]];
	}
	return lst;
}

function randomizeArtConfig(masterSeed, verbose = false) {
	const rng = new XorShift32(deriveSubseed(masterSeed, MOD_TRACK_CONFIG));
	const shuffled = _shuffleList(CHAMPIONSHIP_ART_SETS, rng);
	if (verbose) {
		for (let i = 0; i < shuffled.length; i++) {
			const origName = CHAMPIONSHIP_TRACK_NAMES[i];
			process.stdout.write(`  Slot ${String(i).padStart(2)} (${origName.padEnd(15)}) <- art set: ${shuffled[i].art_name}\n`);
		}
	}
	return shuffled;
}

function _steeringComment(steeringVal) {
	const s = steeringVal.toLowerCase().replace(/\$/g, '');
	if (s.length === 8) {
		try {
			const straight = parseInt(s.slice(0, 4), 16);
			const curve = parseInt(s.slice(4), 16);
			return `straight=$${s.slice(0, 4).toUpperCase()} (${straight}), curve=$${s.slice(4).toUpperCase()} (${curve})`;
		} catch (_) {
			// fall through
		}
	}
	return steeringVal;
}

function buildTrackConfigAsm(artAssignment, originalAsmPath) {
	const content = fs.readFileSync(originalAsmPath, 'utf8');
	const lines = content.split('\n').map(line => line + '\n');
	let trackDataStart = null;
	for (let i = 0; i < lines.length; i++) {
		if (lines[i].trim() === 'Track_data:') {
			trackDataStart = i;
			break;
		}
	}
	if (trackDataStart === null) throw new Error(`Could not find "Track_data:" label in ${originalAsmPath}`);

	const LINES_PER_BLOCK = 20;
	const blockStarts = {};
	for (let i = 0; i < lines.length; i++) {
		const stripped = lines[i].trim();
		if (stripped.startsWith(';') && !stripped.startsWith(';;')) {
			const candidate = stripped.slice(1).trim();
			if (CHAMPIONSHIP_TRACK_NAMES.includes(candidate)) blockStarts[candidate] = i;
		}
	}

	const missing = CHAMPIONSHIP_TRACK_NAMES.filter(name => !(name in blockStarts));
	if (missing.length > 0) throw new Error(`Only found ${Object.keys(blockStarts).length}/16 championship track blocks. Missing: ${missing.join(', ')}`);

	function extractDcLabel(line) {
		const parts = line.split('\t');
		if (parts.length >= 3) return parts[2].split(';')[0].trim();
		return '';
	}

	const newLines = lines.slice();
	for (let slotIdx = 0; slotIdx < CHAMPIONSHIP_TRACK_NAMES.length; slotIdx++) {
		const trackName = CHAMPIONSHIP_TRACK_NAMES[slotIdx];
		const art = artAssignment[slotIdx];
		const blockStart = blockStarts[trackName];
		const blockLines = [];
		for (let j = 0; j < LINES_PER_BLOCK; j++) blockLines.push((newLines[blockStart + j] || '\n').replace(/\r?\n$/, ''));

		const signDataLabel = extractDcLabel(blockLines[11]);
		const signTilesetLabel = extractDcLabel(blockLines[12]);
		const minimapPosLabel = extractDcLabel(blockLines[13]);
		const trackLengthVal = extractDcLabel(blockLines[10]);
		const curveDataLabel = extractDcLabel(blockLines[14]);
		const slopeDataLabel = extractDcLabel(blockLines[15]);
		const physSlopeLabel = extractDcLabel(blockLines[16]);
		const lapTimePtrVal = extractDcLabel(blockLines[17]);
		const lapTargetsLabel = extractDcLabel(blockLines[18]);
		let lapTimeComment;
		if (lapTimePtrVal === 'Track_lap_time_records') lapTimeComment = 'base = $FFFFFD00, +$08 per track';
		else lapTimeComment = `Track_lap_time_records + $${lapTimePtrVal.replace('$FFFFFD', '')}`;

		const horizonFlagStr = art.horizon_override ? '$0001' : '$0000';
		const horizonComment = art.horizon_override ? '1 = special sky colour patch applied each frame' : '0 = default sky';
		const newBlock = [
			`; ${trackName}\n`,
			`\tdc.l\t${art.minimap_tiles_label} ; ${trackName} tiles used for minimap\n`,
			`\tdc.l\t${art.bg_tiles_label} ; ${trackName} tiles used for background\n`,
			`\tdc.l\t${art.bg_tilemap_label} ; ${trackName} background tile mapping\n`,
			`\tdc.l\t${art.minimap_map_label} ; ${trackName} tile mapping for minimap\n`,
			`\tdc.l\t${art.bg_palette_label} ; ${trackName} background palette\n`,
			`\tdc.l\t${art.sideline_label} ; ${trackName} sideline style\n`,
			`\tdc.l\t${art.road_label} ; ${trackName} road style data\n`,
			`\tdc.l\t${art.finish_label} ; ${trackName} finish line style\n`,
			`\tdc.w\t${horizonFlagStr} ; horizon override flag (${horizonComment})\n`,
			`\tdc.w\t${trackLengthVal} ; track length\n`,
			`\tdc.l\t${signDataLabel} ; ${trackName} signs data\n`,
			`\tdc.l\t${signTilesetLabel} ; ${trackName} tileset for signs\n`,
			`\tdc.l\t${minimapPosLabel} ; ${trackName} map for minimap position\n`,
			`\tdc.l\t${curveDataLabel} ; ${trackName} curve data\n`,
			`\tdc.l\t${slopeDataLabel} ; ${trackName} slope data (visual; decoded to Visual_slope_data)\n`,
			`\tdc.l\t${physSlopeLabel} ; ${trackName} physical slope data (decoded to Physical_slope_data; hill RPM modifier)\n`,
			`\tdc.l\t${lapTimePtrVal} ; ${trackName} BCD lap-time record pointer (${lapTimeComment})\n`,
			`\tdc.l\t${lapTargetsLabel} ; ${trackName} per-lap target time table (15 x 3-byte BCD entries)\n`,
			`\tdc.l\t${art.steering} ; steering divisors: ${_steeringComment(art.steering)}\n`,
		];
		newLines.splice(blockStart, LINES_PER_BLOCK, ...newBlock);
	}

	return newLines.join('');
}

function injectArtConfig(artAssignment, repoRoot, dryRun = false, verbose = false) {
	const asmPath = path.join(repoRoot, 'src', 'track_config_data.asm');
	if (!fs.existsSync(asmPath)) throw new Error(`track_config_data.asm not found: ${asmPath}`);
	const newContent = buildTrackConfigAsm(artAssignment, asmPath);
	if (dryRun) {
		if (verbose) process.stdout.write('  [dry-run] Would rewrite src/track_config_data.asm with new art assignment.\n');
		return true;
	}
	fs.writeFileSync(asmPath, newContent, 'utf8');
	if (verbose) process.stdout.write(`  Rewrote ${asmPath} with shuffled art assignment.\n`);
	return true;
}

module.exports = {
	CHAMPIONSHIP_ART_SETS,
	CHAMPIONSHIP_TRACK_NAMES,
	_shuffleList,
	randomizeArtConfig,
	buildTrackConfigAsm,
	injectArtConfig,
};
