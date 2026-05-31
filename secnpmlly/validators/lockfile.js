#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const HOST_ALIASES = {
  npm: ['registry.npmjs.org'],
  yarn: ['registry.yarnpkg.com'],
  verdaccio: ['registry.verdaccio.org'],
};

const DEFAULTS = {
  paths: [],
  type: '',
  format: 'pretty',
  validateHttps: false,
  validatePackageNames: false,
  validateIntegrity: false,
  emptyHostname: true,
  allowedHosts: [],
  allowedSchemes: [],
  allowedUrls: [],
  allowedPackageNameAliases: {},
  integrityExclude: new Set(),
};

function usage() {
  console.error(`Usage: lockfile.js --path <lockfile> [options]

Options:
  -p, --path <path>                         path to a lockfile
  -t, --type <npm|pnpm|yarn|bun>            lockfile type
  -f, --format <pretty|plain>               report format
  -s, --validate-https                      require https: URLs
  -a, --allowed-hosts <host...>             allowed URL hosts or aliases
  -o, --allowed-schemes <scheme...>         allowed URL schemes
  -u, --allowed-urls <url...>               exact allowed URLs
  -e, --empty-hostname <true|false>         allow URLs with no hostname
  -n, --validate-package-names              URL tarball must match package
  -i, --validate-integrity                  integrity/checksum must be sha512
  -l, --allowed-package-name-aliases <a:b>  package-name alias pair
      --integrity-exclude <package>         skip integrity for package
`);
}

function parseArgs(argv) {
  const options = {
    ...DEFAULTS,
    paths: [],
    allowedHosts: [],
    allowedSchemes: [],
    allowedUrls: [],
    allowedPackageNameAliases: {},
    integrityExclude: new Set(),
  };

  const readValues = (index) => {
    const values = [];
    while (index + 1 < argv.length && !argv[index + 1].startsWith('-')) {
      values.push(argv[++index]);
    }
    return { values, index };
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '-p' || arg === '--path') {
      options.paths.push(argv[++i]);
    } else if (arg === '-t' || arg === '--type') {
      options.type = argv[++i] || '';
    } else if (arg === '-f' || arg === '--format') {
      options.format = argv[++i] || 'pretty';
    } else if (arg === '-s' || arg === '--validate-https') {
      options.validateHttps = true;
    } else if (arg === '-n' || arg === '--validate-package-names') {
      options.validatePackageNames = true;
    } else if (arg === '-i' || arg === '--validate-integrity') {
      options.validateIntegrity = true;
    } else if (arg === '-e' || arg === '--empty-hostname') {
      const next = argv[i + 1];
      if (next && !next.startsWith('-')) {
        options.emptyHostname = next !== 'false';
        i += 1;
      } else {
        options.emptyHostname = true;
      }
    } else if (arg === '-a' || arg === '--allowed-hosts') {
      const result = readValues(i);
      options.allowedHosts.push(...result.values);
      i = result.index;
    } else if (arg === '-o' || arg === '--allowed-schemes') {
      const result = readValues(i);
      options.allowedSchemes.push(...result.values.map(normalizeScheme));
      i = result.index;
    } else if (arg === '-u' || arg === '--allowed-urls') {
      const result = readValues(i);
      options.allowedUrls.push(...result.values);
      i = result.index;
    } else if (arg === '-l' || arg === '--allowed-package-name-aliases') {
      const result = readValues(i);
      for (const value of result.values) {
        const [alias, actual] = value.split(':');
        if (alias && actual) options.allowedPackageNameAliases[alias] = actual;
      }
      i = result.index;
    } else if (arg === '--integrity-exclude') {
      const result = readValues(i);
      for (const value of result.values) options.integrityExclude.add(value);
      i = result.index;
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }

  if (options.validateHttps && options.allowedSchemes.length) {
    throw new Error('arguments allowed-schemes and validate-https are mutually exclusive');
  }
  if (!options.paths.length) {
    throw new Error('missing required --path argument');
  }
  if (options.format !== 'pretty' && options.format !== 'plain') {
    throw new Error('format must be "pretty" or "plain"');
  }
  return options;
}

function normalizeScheme(value) {
  return value.endsWith(':') ? value : `${value}:`;
}

function expandAllowedHosts(values) {
  const hosts = new Set();
  for (const value of values) {
    const alias = HOST_ALIASES[value];
    if (alias) {
      for (const host of alias) hosts.add(host);
    } else {
      hosts.add(value);
    }
  }
  return hosts;
}

function inferType(lockfile) {
  const base = path.basename(lockfile);
  if (base === 'package-lock.json' || base === 'npm-shrinkwrap.json') return 'npm';
  if (base === 'pnpm-lock.yaml') return 'pnpm';
  if (base === 'yarn.lock') return 'yarn';
  if (base === 'bun.lock') return 'bun';
  return '';
}

function hasGlob(value) {
  return /[*?]/.test(value);
}

function globToRegExp(pattern) {
  let out = '^';
  for (let i = 0; i < pattern.length; i += 1) {
    const char = pattern[i];
    if (char === '*') {
      if (pattern[i + 1] === '*') {
        out += '.*';
        i += 1;
      } else {
        out += '[^/]*';
      }
    } else if (char === '?') {
      out += '[^/]';
    } else {
      out += char.replace(/[|\\{}()[\]^$+?.]/g, '\\$&');
    }
  }
  return new RegExp(`${out}$`);
}

function walkFiles(dir, files = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name !== 'node_modules' && entry.name !== '.git') walkFiles(fullPath, files);
    } else if (entry.isFile()) {
      files.push(fullPath);
    }
  }
  return files;
}

function expandPaths(paths) {
  const expanded = [];
  for (const value of paths) {
    if (!hasGlob(value)) {
      expanded.push(value);
      continue;
    }

    const firstGlob = value.search(/[*?]/);
    const prefix = firstGlob === -1 ? value : value.slice(0, firstGlob);
    const slash = Math.max(prefix.lastIndexOf('/'), prefix.lastIndexOf(path.sep));
    const root = slash >= 0 ? prefix.slice(0, slash || 1) : '.';
    const searchRoot = path.resolve(root);
    if (!fs.existsSync(searchRoot)) continue;

    const absolutePattern = path.resolve(value).split(path.sep).join('/');
    const matcher = globToRegExp(absolutePattern);
    for (const file of walkFiles(searchRoot)) {
      const normalized = path.resolve(file).split(path.sep).join('/');
      if (matcher.test(normalized)) expanded.push(file);
    }
  }
  return expanded;
}

function packageNameFromPath(entryPath) {
  const parts = entryPath.split('node_modules/');
  return parts[parts.length - 1] || entryPath;
}

function packageNameFromSpecifier(specifier) {
  const cleaned = specifier.replace(/^npm:/, '');
  if (cleaned.startsWith('@')) {
    const match = cleaned.match(/^(@[^/@]+\/[^/@]+)/);
    return match ? match[1] : cleaned;
  }
  return cleaned.split('@')[0];
}

function packageNameFromTarball(url) {
  const pathname = decodeURIComponent(url.pathname);
  const parts = pathname.split('/-/');
  if (parts.length < 2) return '';
  const before = parts[0].replace(/^\/+/, '');
  const segments = before.split('/');
  if (segments[0] && segments[0].startsWith('@') && segments[1]) {
    return `${segments[0]}/${segments[1]}`;
  }
  return segments[0] || '';
}

function isLocalReference(value) {
  return /^(file:|link:|workspace:|portal:|patch:|npm:link:|npm:file:)/.test(value || '');
}

function isSha512(value) {
  return typeof value === 'string' && /^sha512-[A-Za-z0-9+/=]+$/.test(value);
}

function isSha512Checksum(value) {
  return typeof value === 'string' && (/^sha512-/.test(value) || /^[0-9]+\/[a-f0-9]+$/i.test(value));
}

function addFinding(findings, lockfile, subject, message) {
  findings.push(`${lockfile}: ${subject}: ${message}`);
}

function validateResource(resource, options, findings, lockfile) {
  if (!resource.url || isLocalReference(resource.url)) return;
  if (options.allowedUrls.includes(resource.url)) return;

  let parsed;
  try {
    parsed = new URL(resource.url);
  } catch (_error) {
    addFinding(findings, lockfile, resource.name, `invalid URL ${resource.url}`);
    return;
  }

  if (!options.emptyHostname && !parsed.hostname) {
    addFinding(findings, lockfile, resource.name, 'URL hostname is empty');
  }

  if (options.validateHttps && parsed.protocol !== 'https:') {
    addFinding(findings, lockfile, resource.name, `URL scheme is not https: (${parsed.protocol})`);
  }

  if (options.allowedSchemes.length && !options.allowedSchemes.includes(parsed.protocol)) {
    addFinding(findings, lockfile, resource.name, `URL scheme is not allowed: ${parsed.protocol}`);
  }

  const allowedHosts = expandAllowedHosts(options.allowedHosts);
  if (allowedHosts.size && parsed.hostname && !allowedHosts.has(parsed.hostname)) {
    addFinding(findings, lockfile, resource.name, `URL host is not allowed: ${parsed.hostname}`);
  }

  if (options.validatePackageNames && parsed.hostname) {
    const actualName = packageNameFromTarball(parsed);
    const expectedName = options.allowedPackageNameAliases[resource.name] || resource.name;
    if (actualName && actualName !== expectedName) {
      addFinding(findings, lockfile, resource.name, `URL package name "${actualName}" does not match "${expectedName}"`);
    }
  }
}

function validateIntegrity(resource, options, findings, lockfile) {
  if (!options.validateIntegrity) return;
  if (!resource.name || options.integrityExclude.has(resource.name)) return;
  if (resource.local || isLocalReference(resource.url) || isLocalReference(resource.version)) return;
  if (resource.bundled) return;

  if (!resource.integrity) {
    addFinding(findings, lockfile, resource.name, 'missing integrity');
    return;
  }

  const ok = resource.checksum ? isSha512Checksum(resource.integrity) : isSha512(resource.integrity);
  if (!ok) {
    addFinding(findings, lockfile, resource.name, 'integrity is not sha512');
  }
}

function validateResources(resources, options, findings, lockfile) {
  for (const resource of resources) {
    validateResource(resource, options, findings, lockfile);
    validateIntegrity(resource, options, findings, lockfile);
  }
}

function collectNpmDependencies(deps, resources) {
  if (!deps || typeof deps !== 'object') return;
  for (const [name, dep] of Object.entries(deps)) {
    if (!dep || typeof dep !== 'object') continue;
    resources.push({
      name,
      version: dep.version || '',
      url: dep.resolved || '',
      integrity: dep.integrity || '',
      bundled: dep.bundled === true,
      local: isLocalReference(dep.version) || isLocalReference(dep.resolved),
    });
    collectNpmDependencies(dep.dependencies, resources);
  }
}

function parseNpm(lockfile, content) {
  const data = JSON.parse(content);
  const resources = [];

  if (data.packages && typeof data.packages === 'object') {
    for (const [entryPath, entry] of Object.entries(data.packages)) {
      if (!entryPath || !entry || typeof entry !== 'object') continue;
      const name = entry.name || packageNameFromPath(entryPath);
      resources.push({
        name,
        version: entry.version || '',
        url: entry.resolved || '',
        integrity: entry.integrity || '',
        bundled: entry.inBundle === true || entry.bundled === true,
        local: entry.link === true || isLocalReference(entry.resolved) || isLocalReference(entry.version),
      });
    }
  }

  collectNpmDependencies(data.dependencies, resources);

  if (!resources.length) {
    throw new Error(`${lockfile} does not contain npm package entries`);
  }
  return resources;
}

function parseQuotedValue(line) {
  const quoted = line.match(/"((?:[^"\\]|\\.)*)"/);
  if (quoted) return quoted[1];
  const colon = line.indexOf(':');
  return colon === -1 ? '' : line.slice(colon + 1).trim();
}

function parseYarn(lockfile, content) {
  const resources = [];
  const lines = content.split(/\r?\n/);
  let current = null;

  const flush = () => {
    if (!current) return;
    const resolution = current.resolution || current.name;
    const isNpm = current.url || /(^|[@:])npm:/.test(resolution) || /@npm:/.test(current.name);
    resources.push({
      name: packageNameFromSpecifier(current.name.split(',')[0].trim().replace(/^"|"$/g, '')),
      version: resolution,
      url: current.url || '',
      integrity: current.integrity || current.checksum || '',
      checksum: Boolean(current.checksum && !current.integrity),
      local: !isNpm || isLocalReference(resolution),
    });
  };

  for (const line of lines) {
    if (!line.trim() || line.startsWith('#')) continue;
    if (!/^\s/.test(line) && line.endsWith(':')) {
      flush();
      current = { name: line.slice(0, -1) };
      continue;
    }
    if (!current) continue;

    const trimmed = line.trim();
    if (trimmed.startsWith('resolved ')) current.url = parseQuotedValue(trimmed);
    else if (trimmed.startsWith('integrity ')) current.integrity = trimmed.slice('integrity '.length).trim();
    else if (trimmed.startsWith('resolution:')) current.resolution = parseQuotedValue(trimmed);
    else if (trimmed.startsWith('checksum:')) current.checksum = parseQuotedValue(trimmed);
  }
  flush();

  if (!resources.length) {
    throw new Error(`${lockfile} does not contain yarn package entries`);
  }
  return resources;
}

function parseBun(lockfile, content) {
  const resources = [];
  const lines = content.split(/\r?\n/);
  let inPackages = false;
  let sawPackages = false;

  for (const line of lines) {
    if (!inPackages) {
      if (/^ {2}"packages": \{$/.test(line)) {
        inPackages = true;
        sawPackages = true;
      }
      continue;
    }
    if (/^ {2}\}/.test(line)) break;

    const match = line.match(/^ {4}"([^"]+)": \[(.*)\],?$/);
    if (!match) continue;

    const name = match[1];
    const entry = match[2];
    const strings = [];
    entry.replace(/"((?:[^"\\]|\\.)*)"/g, (_match, value) => {
      strings.push(value);
      return '';
    });

    const resolution = strings[0] || '';
    const url = strings[1] || '';
    const integrity = strings.find((value) => value.startsWith('sha')) || '';
    resources.push({
      name,
      version: resolution,
      url,
      integrity,
      local: isLocalReference(resolution) || resolution.includes('@workspace:') || resolution.includes('@file:'),
    });
  }

  if (!sawPackages || !resources.length) {
    throw new Error(`${lockfile} does not contain bun package entries`);
  }
  return resources;
}

function parseInlineYamlMap(value) {
  const map = {};
  const inner = value.trim().replace(/^\{/, '').replace(/\}$/, '');
  for (const part of inner.split(',')) {
    const index = part.indexOf(':');
    if (index === -1) continue;
    const key = part.slice(0, index).trim();
    const raw = part.slice(index + 1).trim();
    map[key] = raw.replace(/^['"]|['"]$/g, '');
  }
  return map;
}

function parsePnpmName(key) {
  let value = key.replace(/^['"]|['"]$/g, '');
  if (value.startsWith('/')) value = value.slice(1);
  if (value.startsWith('@')) {
    const parts = value.split('/');
    return parts.length >= 2 ? `${parts[0]}/${parts[1].split('@')[0]}` : value;
  }
  return value.split('@')[0];
}

function parsePnpm(lockfile, content) {
  const resources = [];
  const lines = content.split(/\r?\n/);
  let inPackages = false;
  let current = null;
  let inResolution = false;

  const flush = () => {
    if (!current) return;
    resources.push({
      name: current.name,
      version: current.key,
      url: current.tarball || '',
      integrity: current.integrity || '',
      local: /^link:|^file:|^workspace:/.test(current.key) || isLocalReference(current.tarball),
    });
  };

  for (const line of lines) {
    if (/^\S/.test(line)) {
      if (line === 'packages:') {
        flush();
        current = null;
        inPackages = true;
        inResolution = false;
      } else if (inPackages) {
        break;
      }
      continue;
    }

    if (!inPackages) continue;
    const entry = line.match(/^ {2}([^ ].*):$/);
    if (entry) {
      flush();
      current = { key: entry[1].replace(/^['"]|['"]$/g, ''), name: parsePnpmName(entry[1]) };
      inResolution = false;
      continue;
    }
    if (!current) continue;

    const trimmed = line.trim();
    if (trimmed.startsWith('resolution:')) {
      inResolution = true;
      const value = trimmed.slice('resolution:'.length).trim();
      if (value.startsWith('{')) {
        const map = parseInlineYamlMap(value);
        if (map.integrity) current.integrity = map.integrity;
        if (map.tarball) current.tarball = map.tarball;
      }
    } else if (/^\S/.test(trimmed) && !trimmed.startsWith('integrity:') && !trimmed.startsWith('tarball:')) {
      inResolution = false;
    }

    if (inResolution && trimmed.startsWith('integrity:')) {
      current.integrity = trimmed.slice('integrity:'.length).trim().replace(/^['"]|['"]$/g, '');
    } else if (inResolution && trimmed.startsWith('tarball:')) {
      current.tarball = trimmed.slice('tarball:'.length).trim().replace(/^['"]|['"]$/g, '');
    }
  }
  flush();

  if (!resources.length) {
    throw new Error(`${lockfile} does not contain pnpm package entries`);
  }
  return resources;
}

function parseLockfile(lockfile, type, content) {
  if (type === 'npm') return parseNpm(lockfile, content);
  if (type === 'pnpm') return parsePnpm(lockfile, content);
  if (type === 'yarn') return parseYarn(lockfile, content);
  if (type === 'bun') return parseBun(lockfile, content);
  throw new Error(`unsupported lockfile type: ${type || 'unknown'}`);
}

function run() {
  const options = parseArgs(process.argv.slice(2));
  const findings = [];
  const paths = expandPaths(options.paths);

  if (!paths.length) {
    throw new Error('no lockfiles matched --path');
  }

  for (const lockfile of paths) {
    const type = options.type || inferType(lockfile);
    const content = fs.readFileSync(lockfile, 'utf8');
    const resources = parseLockfile(lockfile, type, content);
    validateResources(resources, options, findings, lockfile);
  }

  if (findings.length) {
    for (const finding of findings) {
      console.error(options.format === 'plain' ? finding : `- ${finding}`);
    }
    process.exit(1);
  }
}

try {
  run();
} catch (error) {
  console.error(error.message);
  usage();
  process.exit(2);
}
