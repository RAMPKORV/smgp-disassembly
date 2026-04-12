// tools/lib/cli.js
//
// Minimal CLI argument parsing and output helpers.
// No external dependencies — uses process.argv and process.exit directly.
//
// Usage pattern:
//   const { parseArgs, die, info } = require('./lib/cli');
//   const args = parseArgs(process.argv.slice(2), {
//     flags: ['--dry-run', '--verbose'],
//     options: ['--rom', '--out', '--seed'],
//   });
//   if (args.flags['--dry-run']) { ... }
//   const romPath = args.options['--rom'] || DEFAULT_ROM_PATH;

'use strict';

function writeLine(stream, message) {
	stream.write(message.endsWith('\n') ? message : `${message}\n`);
}

/**
 * Parse a flat argv array into flags (boolean) and options (key=value).
 *
 * @param {string[]} argv - e.g. process.argv.slice(2)
 * @param {object} spec
 * @param {string[]} [spec.flags]   - boolean flags like '--dry-run'
 * @param {string[]} [spec.options] - value-taking options like '--out'
 * @returns {{ flags: Object<string,boolean>, options: Object<string,string|null>, positional: string[] }}
 */
function parseArgs(argv, spec = {}) {
  const knownFlags = new Set(spec.flags || []);
  const knownOptions = new Set(spec.options || []);

  const flags = {};
  const options = {};
  const positional = [];

  for (const f of knownFlags) flags[f] = false;
  for (const o of knownOptions) options[o] = null;

  let i = 0;
  while (i < argv.length) {
    const arg = argv[i];
    if (knownFlags.has(arg)) {
      flags[arg] = true;
      i++;
    } else if (knownOptions.has(arg)) {
      if (i + 1 >= argv.length) {
        die(`Option ${arg} requires a value`);
      }
      options[arg] = argv[i + 1];
      i += 2;
    } else if (arg.startsWith('--')) {
      // Unknown option — check for --foo=bar style
      const eq = arg.indexOf('=');
      if (eq !== -1) {
        const key = arg.slice(0, eq);
        const val = arg.slice(eq + 1);
        if (knownOptions.has(key)) {
          options[key] = val;
        } else {
          die(`Unknown option: ${key}`);
        }
      } else {
        die(`Unknown option: ${arg}`);
      }
      i++;
    } else {
      positional.push(arg);
      i++;
    }
  }

  return { flags, options, positional };
}

/**
 * Print an error message to stderr and exit with code 1.
 * @param {string} message
 */
function die(message) {
  writeLine(process.stderr, `ERROR: ${message}`);
  process.exit(1);
}

/**
 * Print an informational message to stdout.
 * @param {string} message
 */
function info(message) {
  writeLine(process.stdout, message);
}

/**
 * Print a warning message to stderr.
 * @param {string} message
 */
function warn(message) {
  writeLine(process.stderr, `WARNING: ${message}`);
}

function printUsage(message, options = {}) {
	writeLine(options.stderr ? process.stderr : process.stdout, message);
}

function printJson(value) {
	writeLine(process.stdout, JSON.stringify(value, null, 2));
}

module.exports = {
  parseArgs,
  die,
  info,
  warn,
  printUsage,
  printJson,
};
