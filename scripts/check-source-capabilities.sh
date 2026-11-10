#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 "$ROOT_DIR/scripts/test-lifecycle.py"
if test -n "${VERSION_TAG:-}"; then
    expected_version="${VERSION_TAG#v}"
    test "$expected_version" != "$VERSION_TAG"
    grep -Fq "#define PLUGIN_VERSION \"$expected_version\"" "$ROOT_DIR/src/kgb_zombie_infection.sma"
fi
printf 'Zombie Infection source and lifecycle specification checks passed.\n'
