#!/usr/bin/env node
'use strict';

const fs = require('fs');

const lockfile = process.argv[2];
if (!lockfile) {
  console.error('Usage: bun-lock.js <path-to-bun.lock>');
  process.exit(2);
}

const npmHosts = new Set(['registry.npmjs.org']);
const lines = fs.readFileSync(lockfile, 'utf8').split(/\r?\n/);
const findings = [];

let inPackages = false;
let sawPackages = false;

for (const line of lines) {
  if (!inPackages) {
    if (/^  "packages": \{$/.test(line)) {
      inPackages = true;
      sawPackages = true;
    }
    continue;
  }

  if (/^  \}/.test(line)) {
    inPackages = false;
    continue;
  }

  const match = line.match(/^    "([^"]+)": \[(.*)\],?$/);
  if (!match) {
    if (line.trim()) {
      findings.push(`invalid packages entry: ${line.trim()}`);
    }
    continue;
  }

  const name = match[1];
  const entry = match[2];
  const strings = [];
  entry.replace(/"((?:[^"\\]|\\.)*)"/g, (_match, value) => {
    strings.push(value);
    return '';
  });

  const resolution = strings[0] || '';
  const source = strings[1] || '';
  const integrity = strings.find((value) => value.startsWith('sha512-')) || '';

  if (source) {
    let url;
    try {
      url = new URL(source);
    } catch (_error) {
      findings.push(`${name}: invalid package URL ${source}`);
      continue;
    }

    if (url.protocol !== 'https:') {
      findings.push(`${name}: package URL is not HTTPS`);
    }
    if (!npmHosts.has(url.hostname)) {
      findings.push(`${name}: package URL host is not allowed: ${url.hostname}`);
    }
  }

  const localResolution =
    resolution.includes('@workspace:') ||
    resolution.includes('@file:') ||
    resolution.startsWith('file:');

  if (resolution && !localResolution && !integrity) {
    findings.push(`${name}: missing sha512 integrity`);
  }
}

if (!sawPackages) {
  findings.push('bun.lock does not contain a packages block');
}

if (findings.length) {
  for (const finding of findings) {
    console.error(finding);
  }
  process.exit(1);
}
