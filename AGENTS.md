# AGENTS.md

## Project

secnpmlly — shell-based supply-chain protection for npm/pnpm/bun. Wraps package manager commands with npq audits and lockfile-lint checks.

## Conventions

- **Language**: POSIX-compatible shell (bash + zsh). No bashisms in sourced runtime files.
- **No runtime deps** beyond `npq`, `lockfile-lint`, `git`.
- **Idempotent**: `apply-protections.sh` must be safe to rerun.
- **TTY-safe**: always use `c()` from `colors.sh` for output. Never raw ANSI escapes.
- **Security-critical paths**: wrappers (`wrappers/*.sh`), update flow (`bin/secnpmlly`), GPG verification — extra caution on any change here.

## Commits

- **Conventional commits**: `feat:`, `fix:`, `chore:`, `refactor:`, `docs:` with optional scope in parens.
- One bump commit per release: `chore: bump version to X.Y.Z`.
- Releases use GPG-signed tags (`make patch|minor|major`).

## Structure

- `secnpmlly/` — all runtime code (version, wrappers, helpers, keys, CLI).
- `apply-protections.sh` — installer.
- `scripts/bump.sh` — version bump + signed tag.
- `Makefile` — release automation.

## Before commiting changes

1. Test in both bash and zsh.
2. Verify `apply-protections.sh` is still idempotent.
3. Security issues → email `dev@nathabonfim59.com`, never a public issue.
