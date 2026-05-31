# secnpmlly

> Supply-chain protection for npm, pnpm, and bun.

`secnpmlly` wraps your package manager commands with security checks before and after every install, so you don't have to think about it.

## What it does

| When you run | What actually happens |
|---|---|
| `npm install` | `npm ci` + lockfile integrity check |
| `npm install <pkg>` | npq audit, then `npm install`, then lockfile check |
| `npx <pkg>` | npq audit, then execute |
| `pnpm install` | `pnpm install --frozen-lockfile` + lockfile check |
| `pnpm add <pkg>` | npq audit, then `pnpm add`, then lockfile check |
| `pnpm dlx <pkg>` | npq audit, then execute |
| `bun install` | `bun install --frozen-lockfile` + lockfile check |
| `bun add <pkg>` | npq audit, then `bun add`, then lockfile check |
| `bun x <pkg>` | npq audit, then execute |
| `bunx <pkg>` | npq audit, then execute |

On **npq** or **lockfile-lint** failure, you are prompted `[y/N]` (default: abort).

## Protections

### Config hardening

| File | Settings |
|---|---|
| `~/.npmrc` | `min-release-age=7`, `ignore-scripts=true`, `allow-git=none` |
| `~/.bunconfig.toml` | `minimumReleaseAge = 604800`, `ignore-scripts = true` |
| `~/.config/pnpm/config.yaml` | `minimumReleaseAge: 10080`, `blockExoticSubdeps: true`, `trustPolicy: no-downgrade` |

### Tools installed

- **[npq](https://github.com/lirantal/npq)** - Audits packages before install (age, popularity, provenance, maintainer trust)
- **[lockfile-lint](https://github.com/lirantal/lockfile-lint)** - Verifies lockfile integrity (HTTPS-only, sha512 hashes, package name validation, allowed hosts)

### GPG-signed updates

Every release is tagged with a GPG signature. When you run `secnpmlly update`:

1. Fetches tags from remote (no blind merge)
2. Verifies the tag was signed by the trusted key
3. Detects if the public key has changed (possible compromise warning)
4. Only then merges and reinstalls

## Install

One line:

```bash
curl -fsSL https://raw.githubusercontent.com/nathabonfim59/secnpmlly/main/install.sh | bash
```

Or manually:

```bash
git clone https://github.com/nathabonfim59/secnpmlly.git
cd secnpmlly
bash apply-protections.sh
```

Reload your shell:

```bash
source ~/.bashrc   # or ~/.zshrc
```

Verify:

```bash
secnpmlly status
```

## Usage

```
secnpmlly version          Show version
secnpmlly status           Show active wrappers
secnpmlly update           Verify and install latest signed release
secnpmlly help             Show help
```

Your normal `npm`, `npx`, `pnpm`, `bun` commands are now wrapped automatically. No workflow changes needed.

## How updates work

```
secnpmlly update
```

1. Imports the maintainer's public GPG key (asks first)
2. `git fetch origin --tags`
3. Finds the latest signed tag newer than your version
4. Verifies the tag signature matches the trusted key
5. If the public key changed: shows a compromise warning, clones to a safe temp directory with no execution permissions for manual review
6. `git merge --ff-only <tag>`
7. Re-runs `apply-protections.sh`

## Project structure

```
secnpmlly/
├── version               # Current version
├── secnpmlly.sh          # Shell rc entry point (sources wrappers)
├── colors.sh             # TTY-aware color output
├── helpers.sh            # Shared audit/lint/prompt helpers
├── keys/
│   └── trusted.asc       # Maintainer's public GPG key
├── bin/
│   └── secnpmlly         # CLI binary (symlinked to ~/.local/bin)
└── wrappers/
    ├── npm.sh
    ├── npx.sh
    ├── pnpm.sh
    └── bun.sh

apply-protections.sh      # Installer
setup-gpg.sh              # One-time GPG key setup (maintainers)
scripts/bump.sh           # Version bump helper
Makefile                  # Release automation
```

## Uninstall

```bash
make clean
```

Then remove the source line from your `~/.bashrc` or `~/.zshrc`:

```
# >>> secnpmlly >>>
source "$HOME/.local/share/secnpmlly/secnpmlly.sh"
# <<< secnpmlly <<<
```

## More documentation

- [MAINTAINER.md](MAINTAINER.md) - Release process, GPG key management, key rotation
- [CONTRIBUTING.md](CONTRIBUTING.md) - How to contribute, security policy

## Acknowledgements

The idea for secnpmlly was inspired by this video:

**[npm installs can hack your laptop (Here's how to stop it)](https://www.youtube.com/watch?v=Wq6yMdt11LM)**

## License

MIT
