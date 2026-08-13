#!/usr/bin/env bash

set -euo pipefail

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash -n "$TEST_ROOT"/scripts/*.sh "$TEST_ROOT"/tests/*.sh
bash "$TEST_ROOT/scripts/select-role.sh" --self-test
bash "$TEST_ROOT/scripts/quality-ledger.sh" --self-test
bash "$TEST_ROOT/tests/test-doc-sync.sh"
bash "$TEST_ROOT/scripts/check-external-facts.sh" "$TEST_ROOT"

echo "role-governance: all tests passed"
