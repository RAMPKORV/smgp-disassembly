'use strict';

const fs = require('fs');
const http = require('http');
const path = require('path');
const { spawn } = require('child_process');
const { patchRomChecksum } = require('./patch_rom_checksum');
const { getMinimapPreview } = require('./lib/minimap_preview');
const { buildGeneratedMinimapPreview } = require('./lib/minimap_render');
const { loadTracksData, findTrack } = require('./lib/minimap_analysis');

const PORT = parseInt(process.env.SMGP_TOOLS_PORT || '3210', 10);
const HOST = process.env.SMGP_TOOLS_HOST || '127.0.0.1';
const PROJECT_ROOT = path.resolve(__dirname, '..');
const TOOLS_DIR = path.join(PROJECT_ROOT, 'tools');
const INDEX_HTML = path.join(TOOLS_DIR, 'index.html');

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.txt': 'text/plain; charset=utf-8',
};

function listJsFiles(dir) {
  const results = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...listJsFiles(fullPath));
      continue;
    }
    if (entry.isFile() && fullPath.endsWith('.js')) {
      results.push(fullPath);
    }
  }
  return results;
}

const ALLOWED_BATCHES = new Map([
  ['build.bat', path.join(PROJECT_ROOT, 'build.bat')],
  ['verify.bat', path.join(PROJECT_ROOT, 'verify.bat')],
]);

const ALLOWED_NODE_SCRIPTS = new Set(
  listJsFiles(TOOLS_DIR).filter((filePath) => path.resolve(filePath) !== path.resolve(__filename))
);

const ALLOWED_COMMANDS = new Map([
  ['build-rom', {
    command: 'cmd',
    args: ['/c', 'build.bat'],
    cwd: PROJECT_ROOT,
    shell: false,
  }],
  ['verify-rom', {
    command: 'cmd',
    args: ['/c', 'verify.bat'],
    cwd: PROJECT_ROOT,
    shell: false,
  }],
  ['run-checks', {
    command: process.execPath,
    args: [path.join(TOOLS_DIR, 'run_checks.js')],
    cwd: PROJECT_ROOT,
    shell: false,
  }],
  ['tests-runner', {
    command: process.execPath,
    args: [path.join(TOOLS_DIR, 'tests', 'run.js')],
    cwd: PROJECT_ROOT,
    shell: false,
  }],
]);

let activeTask = null;

function sendJson(res, statusCode, value) {
  const body = JSON.stringify(value, null, 2) + '\n';
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
  });
  res.end(body);
}

function sendText(res, statusCode, text, contentType) {
  res.writeHead(statusCode, {
    'Content-Type': contentType || 'text/plain; charset=utf-8',
    'Cache-Control': 'no-store',
  });
  res.end(text);
}

function parseBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', chunk => {
      body += chunk;
      if (body.length > 1024 * 1024) {
        reject(new Error('Request body too large'));
        req.destroy();
      }
    });
    req.on('end', () => {
      if (!body) {
        resolve({});
        return;
      }
      try {
        resolve(JSON.parse(body));
      } catch (error) {
        reject(new Error('Invalid JSON request body'));
      }
    });
    req.on('error', reject);
  });
}

function safeRelativePath(urlPath) {
  const raw = decodeURIComponent(urlPath.split('?')[0]);
  const normalized = raw === '/' ? '/tools/index.html' : raw;
  const absolute = path.resolve(PROJECT_ROOT, '.' + normalized);
  if (!absolute.startsWith(PROJECT_ROOT)) return null;
  return absolute;
}

function serveStatic(req, res) {
  const filePath = safeRelativePath(req.url);
  if (!filePath) {
    sendText(res, 403, 'Forbidden');
    return;
  }

  const fallback = filePath === path.join(PROJECT_ROOT, 'tools') ? INDEX_HTML : filePath;
  const target = fs.existsSync(fallback) && fs.statSync(fallback).isDirectory() ? path.join(fallback, 'index.html') : fallback;

  if (!fs.existsSync(target) || !fs.statSync(target).isFile()) {
    sendText(res, 404, 'Not found');
    return;
  }

  const ext = path.extname(target).toLowerCase();
  const type = MIME_TYPES[ext] || 'application/octet-stream';
  res.writeHead(200, { 'Content-Type': type, 'Cache-Control': 'no-store' });
  fs.createReadStream(target).pipe(res);
}

function runAllowedCommand(key) {
  const config = ALLOWED_COMMANDS.get(key);
  if (!config) {
    return Promise.reject(new Error(`Unknown command key: ${key}`));
  }
  if (activeTask) {
    return Promise.reject(new Error(`Another command is already running: ${activeTask.key}`));
  }

  return new Promise((resolve) => {
    const child = spawn(config.command, config.args, {
      cwd: config.cwd,
      shell: !!config.shell,
      windowsHide: true,
      env: { ...process.env },
    });

    const startedAt = Date.now();
    let stdout = '';
    let stderr = '';

    activeTask = { key, child, startedAt };

    child.stdout.on('data', chunk => {
      stdout += chunk.toString();
    });

    child.stderr.on('data', chunk => {
      stderr += chunk.toString();
    });

    child.on('error', error => {
      activeTask = null;
      resolve({
        ok: false,
        key,
        exitCode: null,
        durationMs: Date.now() - startedAt,
        stdout,
        stderr: `${stderr}${stderr ? '\n' : ''}${error.message}`,
      });
    });

    child.on('close', exitCode => {
      activeTask = null;
      resolve({
        ok: exitCode === 0,
        key,
        exitCode,
        durationMs: Date.now() - startedAt,
        stdout,
        stderr,
      });
    });
  });
}

function maybePatchOutputChecksum(result) {
  if (!result || !result.ok) return result;
  const buildOrVerify = result.key === 'build-rom' || result.key === 'verify-rom';
  const randomizedBuild = result.mode === 'node' && (
    result.script === path.join('tools', 'randomize.js') ||
    result.script === path.join('tools', 'hack_workdir.js')
  );
  if (!buildOrVerify && !randomizedBuild) return result;

  let bitPerfect = false;
  if (result.key === 'verify-rom') {
    const text = `${result.stdout || ''}\n${result.stderr || ''}`;
    bitPerfect = text.includes('BUILD VERIFIED - ROM IS BIT-PERFECT');
  }

  if (bitPerfect) {
    result.checksumPatched = false;
    result.bitPerfect = true;
    return result;
  }

  if (buildOrVerify) {
    const romPath = path.join(PROJECT_ROOT, 'out.bin');
    if (!fs.existsSync(romPath)) return result;
    const patch = patchRomChecksum(romPath);
    result.checksumPatched = true;
    result.bitPerfect = false;
    result.checksum = patch;
    result.stdout = `${result.stdout || ''}${result.stdout ? '\n' : ''}[checksum] ${patch.changed ? 'patched' : 'verified'} header word ${patch.oldChecksum.toString(16).toUpperCase().padStart(4, '0')} -> ${patch.newChecksum.toString(16).toUpperCase().padStart(4, '0')}\n`;
    return result;
  }

  result.checksumPatched = true;
  result.bitPerfect = false;
  return result;
}

function validateArgs(args) {
  if (!Array.isArray(args)) throw new Error('args must be an array');
  if (args.length > 64) throw new Error('too many args');
  return args.map((arg) => {
    if (typeof arg !== 'string') throw new Error('all args must be strings');
    if (arg.length > 2000) throw new Error('arg too long');
    return arg;
  });
}

function runStructuredCommand(body) {
  if (activeTask) {
    return Promise.reject(new Error(`Another command is already running: ${activeTask.key}`));
  }

  const mode = String(body.mode || '');
  const timeout = Math.max(1000, Math.min(parseInt(body.timeout || '120000', 10) || 120000, 30 * 60 * 1000));

  if (mode === 'batch') {
    const batch = String(body.batch || '');
    if (!ALLOWED_BATCHES.has(batch)) {
      return Promise.reject(new Error(`Batch not allowed: ${batch}`));
    }
    return new Promise((resolve) => {
      const startedAt = Date.now();
      const child = spawn('cmd', ['/c', batch], {
        cwd: PROJECT_ROOT,
        shell: false,
        windowsHide: true,
        env: { ...process.env },
      });
      let stdout = '';
      let stderr = '';
      let finished = false;
      activeTask = { key: batch, child, startedAt };
      const timer = setTimeout(() => {
        if (finished) return;
        try { child.kill(); } catch (_) {}
      }, timeout);
      child.stdout.on('data', (chunk) => { stdout += chunk.toString(); });
      child.stderr.on('data', (chunk) => { stderr += chunk.toString(); });
      child.on('close', (exitCode) => {
        finished = true;
        clearTimeout(timer);
        activeTask = null;
        resolve({ ok: exitCode === 0, exitCode, durationMs: Date.now() - startedAt, stdout, stderr, mode, batch });
      });
      child.on('error', (error) => {
        finished = true;
        clearTimeout(timer);
        activeTask = null;
        resolve({ ok: false, exitCode: null, durationMs: Date.now() - startedAt, stdout, stderr: `${stderr}${stderr ? '\n' : ''}${error.message}`, mode, batch });
      });
    });
  }

  if (mode === 'node') {
    const script = path.resolve(PROJECT_ROOT, String(body.script || ''));
    if (!script.startsWith(TOOLS_DIR + path.sep) && script !== path.join(TOOLS_DIR, path.basename(script))) {
      return Promise.reject(new Error('Script must live under tools/'));
    }
    if (!ALLOWED_NODE_SCRIPTS.has(script)) {
      return Promise.reject(new Error(`Script not allowed: ${path.relative(PROJECT_ROOT, script)}`));
    }
    const args = validateArgs(body.args || []);
    return new Promise((resolve) => {
      const startedAt = Date.now();
      const child = spawn(process.execPath, [script, ...args], {
        cwd: PROJECT_ROOT,
        shell: false,
        windowsHide: true,
        env: { ...process.env },
      });
      let stdout = '';
      let stderr = '';
      let finished = false;
      activeTask = { key: path.relative(PROJECT_ROOT, script), child, startedAt };
      const timer = setTimeout(() => {
        if (finished) return;
        try { child.kill(); } catch (_) {}
      }, timeout);
      child.stdout.on('data', (chunk) => { stdout += chunk.toString(); });
      child.stderr.on('data', (chunk) => { stderr += chunk.toString(); });
      child.on('close', (exitCode) => {
        finished = true;
        clearTimeout(timer);
        activeTask = null;
        resolve({ ok: exitCode === 0, exitCode, durationMs: Date.now() - startedAt, stdout, stderr, mode, script: path.relative(PROJECT_ROOT, script), args });
      });
      child.on('error', (error) => {
        finished = true;
        clearTimeout(timer);
        activeTask = null;
        resolve({ ok: false, exitCode: null, durationMs: Date.now() - startedAt, stdout, stderr: `${stderr}${stderr ? '\n' : ''}${error.message}`, mode, script: path.relative(PROJECT_ROOT, script), args });
      });
    });
  }

  return Promise.reject(new Error(`Unsupported mode: ${mode}`));
}

function handleApi(req, res) {
  if (req.method === 'GET' && req.url === '/api/status') {
    sendJson(res, 200, {
      ok: true,
      activeTask: activeTask ? { key: activeTask.key, startedAt: activeTask.startedAt } : null,
      commands: Array.from(ALLOWED_COMMANDS.keys()),
      nodeScripts: Array.from(ALLOWED_NODE_SCRIPTS).map((filePath) => path.relative(PROJECT_ROOT, filePath)).sort(),
      batches: Array.from(ALLOWED_BATCHES.keys()),
      port: PORT,
      host: HOST,
    });
    return;
  }

  if (req.method === 'GET' && req.url.startsWith('/api/minimap-preview')) {
    try {
      const url = new URL(req.url, `http://${HOST}:${PORT}`);
      const slug = String(url.searchParams.get('slug') || '');
      sendJson(res, 200, { ok: true, preview: getMinimapPreview(slug) });
    } catch (error) {
      sendJson(res, 400, { ok: false, error: error.message });
    }
    return;
  }

	if (req.method === 'GET' && req.url === '/api/latest-minimap-workspace') {
		try {
			const workspacesDir = path.join(PROJECT_ROOT, 'build', 'workspaces');
			const candidates = fs.existsSync(workspacesDir)
				? fs.readdirSync(workspacesDir)
					.map(name => path.join(workspacesDir, name))
					.filter(dir => fs.existsSync(path.join(dir, 'tools', 'data', 'tracks.json')))
					.sort((a, b) => fs.statSync(path.join(b, 'tools', 'data', 'tracks.json')).mtimeMs - fs.statSync(path.join(a, 'tools', 'data', 'tracks.json')).mtimeMs)
				: [];
			if (candidates.length === 0) throw new Error('No workspace tracks.json found');
			const latest = candidates[0];
			const tracks = JSON.parse(fs.readFileSync(path.join(latest, 'tools', 'data', 'tracks.json'), 'utf8'));
			sendJson(res, 200, { ok: true, workspace: path.basename(latest), tracks });
		} catch (error) {
			sendJson(res, 400, { ok: false, error: error.message });
		}
		return;
	}

	if (req.method === 'GET' && req.url.startsWith('/api/generated-minimap-preview')) {
		try {
			const url = new URL(req.url, `http://${HOST}:${PORT}`);
			const slug = String(url.searchParams.get('slug') || '');
			const tracksJson = url.searchParams.get('tracks');
			const tracksData = tracksJson ? JSON.parse(tracksJson) : loadTracksData();
			const track = findTrack(slug, tracksData);
			if (!track) throw new Error(`track not found: ${slug}`);
			sendJson(res, 200, { ok: true, preview: buildGeneratedMinimapPreview(track) });
		} catch (error) {
			sendJson(res, 400, { ok: false, error: error.message });
		}
		return;
	}

	if (req.method === 'POST' && req.url === '/api/generated-minimap-preview') {
		parseBody(req)
			.then(body => {
				const slug = String(body.slug || '');
				const tracksData = body.tracks && Array.isArray(body.tracks.tracks)
					? body.tracks
					: loadTracksData();
				const track = findTrack(slug, tracksData);
				if (!track) throw new Error(`track not found: ${slug}`);
				sendJson(res, 200, { ok: true, preview: buildGeneratedMinimapPreview(track) });
			})
			.catch(error => sendJson(res, 400, { ok: false, error: error.message }));
		return;
	}

  if (req.method === 'POST' && req.url === '/api/run') {
    parseBody(req)
      .then(body => {
        const key = String(body.key || '');
        return runAllowedCommand(key)
          .then(result => sendJson(res, 200, maybePatchOutputChecksum(result)))
          .catch(error => sendJson(res, 400, { ok: false, error: error.message }));
      })
      .catch(error => sendJson(res, 400, { ok: false, error: error.message }));
    return;
  }

  if (req.method === 'POST' && req.url === '/api/execute') {
    parseBody(req)
      .then(body => runStructuredCommand(body)
        .then(result => sendJson(res, 200, maybePatchOutputChecksum(result)))
        .catch(error => sendJson(res, 400, { ok: false, error: error.message })))
      .catch(error => sendJson(res, 400, { ok: false, error: error.message }));
    return;
  }

  sendJson(res, 404, { ok: false, error: 'Unknown API endpoint' });
}

const server = http.createServer((req, res) => {
  if (req.url.startsWith('/api/')) {
    handleApi(req, res);
    return;
  }
  serveStatic(req, res);
});

server.listen(PORT, HOST, () => {
  process.stdout.write(`SMGP tools server listening on http://${HOST}:${PORT}/tools/index.html\n`);
});
