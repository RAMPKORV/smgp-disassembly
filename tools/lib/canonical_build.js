'use strict';

const { spawnSync } = require('child_process');

function runCanonicalBatch(scriptName, workDir, options = {}) {
	const command = `& .\\${scriptName}`;
	const result = spawnSync(
		'powershell',
		['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', command],
		{
			cwd: workDir,
			encoding: 'utf8',
			stdio: options.stdio || 'pipe',
		}
	);
	const output = (result.stdout || '') + (result.stderr || '');
	return {
		ok: result.status === 0,
		status: result.status,
		output,
		command,
		scriptName,
	};
}

function runCanonicalBuild(workDir, options = {}) {
	return runCanonicalBatch('build.bat', workDir, options);
}

function runCanonicalVerify(workDir, options = {}) {
	return runCanonicalBatch('verify.bat', workDir, options);
}

module.exports = {
	runCanonicalBatch,
	runCanonicalBuild,
	runCanonicalVerify,
};
