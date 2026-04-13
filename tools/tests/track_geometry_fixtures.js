'use strict';

const { clonePointPath } = require('./randomizer_test_utils');

const FIXTURES = Object.freeze({
	square_loop: {
		description: 'Simple square with no self intersections',
		points: [[0, 0], [4, 0], [4, 4], [0, 4]],
		expectedProperCrossings: 0,
	},
	rectangle_loop: {
		description: 'Simple rectangle with no self intersections',
		points: [[0, 0], [8, 0], [8, 6], [0, 6]],
		expectedProperCrossings: 0,
	},
	single_crossing_bow_tie: {
		description: 'Bow-tie loop with one true crossing',
		points: [[0, 0], [6, 6], [0, 6], [6, 0]],
		expectedProperCrossings: 1,
	},
	shared_endpoint_touch: {
		description: 'Loop that revisits one vertex without a true crossing',
		points: [[0, 0], [4, 0], [4, 4], [2, 2], [0, 4], [2, 2]],
		expectedProperCrossings: 0,
		expectedSharedEndpointTouches: 1,
	},
	near_miss_loop: {
		description: 'Loop with a narrow gap that should not count as an intersection',
		points: [[0, 0], [6, 0], [6, 6], [3.1, 6], [3.1, 0.2], [2.9, 0.2], [2.9, 6], [0, 6]],
		expectedProperCrossings: 0,
	},
	multiple_crossing_star: {
		description: 'Pentagram-style loop with multiple true crossings',
		points: [[0, -10], [5.878, 8.09], [-9.511, -3.09], [9.511, -3.09], [-5.878, 8.09]],
		minProperCrossings: 5,
	},
});

function getTrackGeometryFixture(name) {
	const fixture = FIXTURES[name];
	if (!fixture) throw new Error(`Unknown track geometry fixture: ${name}`);
	return {
		name,
		description: fixture.description,
		points: clonePointPath(fixture.points),
		expectedProperCrossings: fixture.expectedProperCrossings,
		expectedSharedEndpointTouches: fixture.expectedSharedEndpointTouches,
		minProperCrossings: fixture.minProperCrossings,
	};
}

function listTrackGeometryFixtureNames() {
	return Object.keys(FIXTURES);
}

module.exports = {
	getTrackGeometryFixture,
	listTrackGeometryFixtureNames,
};
