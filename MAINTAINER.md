# Maintainer Guide

## Release process

### One-time GPG setup

```bash
make setup-gpg
```

This generates a GPG key, exports the public key to `secnpmlly/keys/trusted.asc`, and configures git signing (repo-local only, never touches your global git config).

The private key stays in `~/.gnupg/` and **never** leaves your machine.

### Creating a release

```bash
# Bump version (patches the version file + auto-commits)
make patch          # 0.4.0 -> 0.4.1
# or
make minor          # 0.4.0 -> 0.5.0
# or
make major          # 0.4.0 -> 1.0.0

# Create GPG-signed tag
make tag

# Push commit + tag to origin
make push
```

Or set an explicit version:

```bash
make release V=2.0.0
make tag
make push
```

### How the signed update flow works

1. `make tag` creates an annotated, GPG-signed tag (`git tag -s`)
2. Users run `secnpmlly update`
3. The CLI fetches tags, verifies the signature against the trusted public key, and only then installs
4. If the public key changes between versions, users see a compromise warning and the update is aborted

### Key rotation

If you ever need to rotate your GPG key:

1. Generate a new key with `make setup-gpg`
2. Commit the new `secnpmlly/keys/trusted.asc`
3. Sign this commit with your **old** key (`git commit -S`)
4. Create a release as usual

This way users can verify the key rotation was done by the previous trusted key holder.

### Files that matter

| File | Purpose |
|---|---|
| `secnpmlly/version` | Current version number |
| `secnpmlly/keys/trusted.asc` | Your public GPG key |
| `secnpmlly/bin/secnpmlly` | CLI entry point (update, version, status) |
| `secnpmlly/secnpmlly.sh` | Shell function entry point (wrappers) |
| `secnpmlly/helpers.sh` | npq audit, lockfile-lint, prompt helpers |
| `secnpmlly/wrappers/*.sh` | Per-package-manager wrappers |
| `apply-protections.sh` | Installer script |
| `scripts/bump.sh` | Version bump logic |
