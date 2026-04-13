'use strict';

const MINIMAP_PANEL_TILES_W = 7;
const MINIMAP_PANEL_TILES_H = 11;
const MINIMAP_TILE_SIZE_PX = 8;
const MINIMAP_PANEL_CELL_COUNT = MINIMAP_PANEL_TILES_W * MINIMAP_PANEL_TILES_H;
const MINIMAP_PANEL_PX_W = MINIMAP_PANEL_TILES_W * MINIMAP_TILE_SIZE_PX;
const MINIMAP_PANEL_PX_H = MINIMAP_PANEL_TILES_H * MINIMAP_TILE_SIZE_PX;
const MINIMAP_TILE_INDEX_MASK = 0x07FF;
const MAP_FIRST_CANVAS_MARGIN_PX = 2;

function buildMapFirstCanvas(marginPx = MAP_FIRST_CANVAS_MARGIN_PX) {
	const margin = Math.max(0, marginPx | 0);
	const width = Math.max(1, MINIMAP_PANEL_PX_W - (margin * 2));
	const height = Math.max(1, MINIMAP_PANEL_PX_H - (margin * 2));
	return {
		panel_width: MINIMAP_PANEL_PX_W,
		panel_height: MINIMAP_PANEL_PX_H,
		margin,
		width,
		height,
		x_min: margin,
		y_min: margin,
		x_max: margin + width - 1,
		y_max: margin + height - 1,
	};
}

module.exports = {
	MINIMAP_PANEL_TILES_W,
	MINIMAP_PANEL_TILES_H,
	MINIMAP_TILE_SIZE_PX,
	MINIMAP_PANEL_CELL_COUNT,
	MINIMAP_PANEL_PX_W,
	MINIMAP_PANEL_PX_H,
	MINIMAP_TILE_INDEX_MASK,
	MAP_FIRST_CANVAS_MARGIN_PX,
	buildMapFirstCanvas,
};
