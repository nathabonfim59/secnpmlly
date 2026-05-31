#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VALIDATOR="$ROOT_DIR/secnpmlly/validators/lockfile.js"
FIXTURES="$ROOT_DIR/tests/fixtures/lockfiles"

pass_count=0

run_valid() {
  name=$1
  type=$2
  file=$3
  shift 3

  if node "$VALIDATOR" --path "$file" --type "$type" "$@"; then
    printf 'ok - %s\n' "$name"
    pass_count=$((pass_count + 1))
  else
    printf 'not ok - %s\n' "$name" >&2
    exit 1
  fi
}

run_invalid() {
  name=$1
  type=$2
  file=$3
  shift 3

  if node "$VALIDATOR" --path "$file" --type "$type" "$@" >/tmp/secnpmlly-lockfile-test.out 2>&1; then
    printf 'not ok - %s unexpectedly passed\n' "$name" >&2
    exit 1
  fi

  if ! grep -q 'left-pad' /tmp/secnpmlly-lockfile-test.out; then
    printf 'not ok - %s did not report package finding\n' "$name" >&2
    cat /tmp/secnpmlly-lockfile-test.out >&2
    exit 1
  fi

  printf 'ok - %s\n' "$name"
  pass_count=$((pass_count + 1))
}

COMMON_FLAGS="--validate-https --validate-integrity --validate-package-names --format plain"

# shellcheck disable=SC2086 - COMMON_FLAGS is an intentional list of CLI args
run_valid 'npm package-lock v3' npm "$FIXTURES/valid/package-lock.json" $COMMON_FLAGS --allowed-hosts npm
# shellcheck disable=SC2086
run_invalid 'npm package-lock rejects bad source' npm "$FIXTURES/invalid/package-lock.json" $COMMON_FLAGS --allowed-hosts npm

# shellcheck disable=SC2086
run_valid 'npm shrinkwrap v1' npm "$FIXTURES/valid/npm-shrinkwrap.json" $COMMON_FLAGS --allowed-hosts npm
# shellcheck disable=SC2086
run_invalid 'npm shrinkwrap rejects bad integrity' npm "$FIXTURES/invalid/npm-shrinkwrap.json" $COMMON_FLAGS --allowed-hosts npm

# shellcheck disable=SC2086
run_valid 'pnpm lockfile v9' pnpm "$FIXTURES/valid/pnpm-lock.yaml" $COMMON_FLAGS --allowed-hosts npm
# shellcheck disable=SC2086
run_invalid 'pnpm lockfile rejects bad source' pnpm "$FIXTURES/invalid/pnpm-lock.yaml" $COMMON_FLAGS --allowed-hosts npm

# shellcheck disable=SC2086
run_valid 'yarn classic lockfile' yarn "$FIXTURES/valid/yarn.lock" $COMMON_FLAGS --allowed-hosts npm yarn
# shellcheck disable=SC2086
run_invalid 'yarn classic rejects bad source' yarn "$FIXTURES/invalid/yarn.lock" $COMMON_FLAGS --allowed-hosts npm yarn

# shellcheck disable=SC2086
run_valid 'yarn berry lockfile' yarn "$FIXTURES/valid/yarn-berry.lock" $COMMON_FLAGS --allowed-hosts npm yarn
# shellcheck disable=SC2086
run_invalid 'yarn berry rejects missing checksum' yarn "$FIXTURES/invalid/yarn-berry.lock" $COMMON_FLAGS --allowed-hosts npm yarn

# shellcheck disable=SC2086
run_valid 'bun text lockfile' bun "$FIXTURES/valid/bun.lock" $COMMON_FLAGS --allowed-hosts npm
# shellcheck disable=SC2086
run_invalid 'bun text lockfile rejects bad source' bun "$FIXTURES/invalid/bun.lock" $COMMON_FLAGS --allowed-hosts npm

printf '%s lockfile validator tests passed\n' "$pass_count"
