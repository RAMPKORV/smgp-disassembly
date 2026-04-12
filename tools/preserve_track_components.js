#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const { parseArgs, die, info } = require('./lib/cli');
const { REPO_ROOT } = require('./lib/rom');
const { injectTrack } = require('./inject_track_data');
const { buildSyncedTrackConfig } = require('./sync_track_config');
const { TRACK_METADATA_FIELDS } = require('./randomizer/track_metadata');

const COMPONENT_FIELDS = new Map([
	['curves', [
		'curve_rle_segments',
		'curve_decompressed',
	]],
	['slopes', [
		'slope_initial_bg_disp',
		'slope_rle_segments',
		'slope_decompressed',
		'phys_slope_rle_segments',
		'phys_slope_decompressed',
	]],
	['signs', [
		'sign_data',
		'sign_tileset',
		'sign_tileset_trailing',
		TRACK_METADATA_FIELDS.preserveOriginalSignCadence,
	]],
	['minimap', [
		'minimap_pos',
		'minimap_pos_trailing',
		TRACK_METADATA_FIELDS.generatedMinimapPreview,
	]],
]);

function clone(value) {
	return value === undefined ? undefined : JSON.parse(JSON.stringify(value));
}

function parseComponentList(raw) {
	if (!raw) die('missing --components list');
	const requested = raw.split(/[\s,]+/).filter(Boolean).map(name => name.toLowerCase());
	if (requested.includes('all')) return Array.from(COMPONENT_FIELDS.keys());
	for (const name of requested) {
		if (!COMPONENT_FIELDS.has(name)) {
			die(`unknown component ${JSON.stringify(name)} (expected one of: ${Array.from(COMPONENT_FIELDS.keys()).join(', ')}, all)`);
		}
	}
	return Array.from(new Set(requested));
}

function loadJson(filePath) {
	return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function writeTrackConfig(workspaceDir, tracksData) {
	const trackConfigPath = path.join(workspaceDir, 'src', 'track_config_data.asm');
	const lines = fs.readFileSync(trackConfigPath, 'utf8').split(/(?<=\n)/);
	const syncResult = buildSyncedTrackConfig(lines, tracksData);
	fs.writeFileSync(trackConfigPath, syncResult.content, 'utf8');
	return syncResult.changed;
}

function main() {
	const args = parseArgs(process.argv.slice(2), {
		flags: ['--verbose', '-v'],
		options: ['--workspace', '--components', '--source', '--tracks'],
	});

	const verbose = args.flags['--verbose'] || args.flags['-v'];
	const workspaceArg = args.options['--workspace'];
	if (!workspaceArg) die('missing --workspace path');

	const workspaceDir = path.resolve(REPO_ROOT, workspaceArg);
	const sourceTracksPath = args.options['--source']
		? path.resolve(REPO_ROOT, args.options['--source'])
		: path.join(REPO_ROOT, 'tools', 'data', 'tracks.json');
	const components = parseComponentList(args.options['--components']);
	const trackSlugs = args.options['--tracks']
		? new Set(args.options['--tracks'].split(/[\s,]+/).filter(Boolean))
		: null;

	const workspaceTracksPath = path.join(workspaceDir, 'tools', 'data', 'tracks.json');
	const workspaceDataDir = path.join(workspaceDir, 'data', 'tracks');

	if (!fs.existsSync(workspaceDir)) die(`workspace not found: ${workspaceDir}`);
	if (!fs.existsSync(workspaceTracksPath)) die(`workspace tracks.json not found: ${workspaceTracksPath}`);
	if (!fs.existsSync(sourceTracksPath)) die(`source tracks.json not found: ${sourceTracksPath}`);

	const sourceData = loadJson(sourceTracksPath);
	const workspaceData = loadJson(workspaceTracksPath);
	const sourceBySlug = new Map((sourceData.tracks || []).map(track => [track.slug, track]));

	let changedTracks = 0;
	let injectedFiles = 0;

	for (const track of workspaceData.tracks || []) {
		if (trackSlugs && !trackSlugs.has(track.slug)) continue;
		const sourceTrack = sourceBySlug.get(track.slug);
		if (!sourceTrack) die(`source track not found for slug ${track.slug}`);

		for (const component of components) {
			for (const field of COMPONENT_FIELDS.get(component)) {
				if (Object.prototype.hasOwnProperty.call(sourceTrack, field)) {
					track[field] = clone(sourceTrack[field]);
				} else {
					delete track[field];
				}
			}
		}

		const results = injectTrack(track, workspaceDataDir, false, verbose);
		injectedFiles += Object.values(results).filter(entry => entry.changed).length;
		changedTracks++;
	}

	fs.writeFileSync(workspaceTracksPath, JSON.stringify(workspaceData, null, 2), 'utf8');
	const changedTrackConfigLines = writeTrackConfig(workspaceDir, workspaceData);

	info(`workspace: ${workspaceDir}`);
	info(`components restored from stock: ${components.join(', ')}`);
	info(`tracks updated: ${changedTracks}`);
	info(`binary files updated: ${injectedFiles}`);
	info(`track_config_data.asm lines changed: ${changedTrackConfigLines}`);
}

if (require.main === module) main();
