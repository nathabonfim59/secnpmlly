# Contributing to secnpmlly

Thank you for your interest in improving secnpmlly.

## Security model

secnpmlly is a supply-chain security tool. Because of its nature, the project has a strict security policy:

- **Only [@nathabonfim59](https://github.com/nathabonfim59)** can merge pull requests and create releases
- **All releases** must be signed with the maintainer's GPG key
- The public key is stored in `secnpmlly/keys/trusted.asc` and any change to it is treated as a potential compromise by the update system

## How to contribute

1. **Fork** the repository
2. Create a **feature branch** from `main`
3. Make your changes
4. Open a **pull request** with a clear description

## Code review

All PRs are reviewed by the maintainer before merging. Changes that affect security-critical paths (wrappers, update flow, GPG verification) will receive extra scrutiny.

## What to keep in mind

- **Shell compatibility**: all scripts must work in both bash and zsh without relying on bash-specific features in the sourced runtime files
- **No external dependencies** beyond `npq`, `lockfile-lint`, and `git` in the runtime wrappers
- **Idempotent**: `apply-protections.sh` must be safe to run multiple times
- **TTY-safe**: use the `c()` function from `colors.sh` for any output, never raw ANSI escapes

## Reporting security issues

If you find a vulnerability, please **do not** open a public issue. Email the maintainer directly at `dev@nathabonfim59.com`.
