#!/usr/bin/env bash
# Host-guard test for utm-smoke.sh: --dry-run exits 0 and prints the
# ssh sequence; a localhost target exits 2 without any ssh attempt.
set -u
cd "$(dirname "$0")/../.." || exit 1

fail=0
out="$(./scripts/qa/utm-smoke.sh --dry-run 2>&1)"
code=$?
[ "$code" -eq 0 ] || { echo "FAIL: --dry-run exited $code"; fail=1; }
case "$out" in
    *"ssh"*"macos-test-02"*"axcli"*) ;;
    *) echo "FAIL: --dry-run missing ssh/axcli sequence"; fail=1 ;;
esac
case "$out" in
    *"screencapture -x"*) ;;
    *) echo "FAIL: --dry-run missing screencapture -x"; fail=1 ;;
esac

UTM_HOST=localhost ./scripts/qa/utm-smoke.sh --dry-run >/dev/null 2>&1
code=$?
[ "$code" -eq 2 ] || { echo "FAIL: UTM_HOST=localhost exited $code, want 2"; fail=1; }

ALIDADE_UTM_HOST=127.0.0.1 ./scripts/qa/utm-smoke.sh --dry-run >/dev/null 2>&1
code=$?
[ "$code" -eq 2 ] || { echo "FAIL: ALIDADE_UTM_HOST=127.0.0.1 exited $code, want 2"; fail=1; }

if [ "$fail" -eq 0 ]; then
    echo "utm-smoke-test: ok (dry-run=0, localhost=2, 127.0.0.1=2)"
fi
exit "$fail"
