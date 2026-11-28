#!/usr/bin/env bash
# Host-guard test for utm-smoke.sh: --dry-run exits 0 and prints the
# ssh sequence; localhost-class and non-allowlisted targets exit 2
# without any ssh attempt.
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
case "$out" in
    *"Contents/MacOS/mimir"*) ;;
    *) echo "FAIL: --dry-run does not launch Contents/MacOS/mimir"; fail=1 ;;
esac

expect_2() {
    desc="$1"; shift
    "$@" >/dev/null 2>&1
    code=$?
    [ "$code" -eq 2 ] || { echo "FAIL: $desc exited $code, want 2"; fail=1; }
}

expect_2 "UTM_HOST=localhost" env UTM_HOST=localhost ./scripts/qa/utm-smoke.sh --dry-run
expect_2 "ALIDADE_UTM_HOST=127.0.0.1" env ALIDADE_UTM_HOST=127.0.0.1 ./scripts/qa/utm-smoke.sh --dry-run
expect_2 "--host localhost" ./scripts/qa/utm-smoke.sh --host localhost --dry-run
expect_2 "--host ::1" ./scripts/qa/utm-smoke.sh --host "::1" --dry-run
expect_2 "--host local uname -n" ./scripts/qa/utm-smoke.sh --host "$(uname -n)" --dry-run
expect_2 "--host non-allowlisted" ./scripts/qa/utm-smoke.sh --host some-other-mac --dry-run
expect_2 "injection view" ./scripts/qa/utm-smoke.sh --view 'x; id' --dry-run

if [ "$fail" -eq 0 ]; then
    echo "utm-smoke-test: ok (dry-run=0, localhost/127.0.0.1/--host localhost/::1/uname -n/non-allowlisted/injection=2)"
fi
exit "$fail"
