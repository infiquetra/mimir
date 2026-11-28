#!/usr/bin/env bash
# Tier 2 visual smoke inside the macos-test-02/03 UTM guest (ADR-013).
# Never runs a GUI, screencapture, or cliclick on the operator host:
# the host is refused with exit 2 before any ssh is attempted.
set -euo pipefail

usage() {
    echo "usage: $0 [--host <macos-test-02|macos-test-03>] [--dry-run] [--view <name>] [--app <path>]" >&2
}

host="${ALIDADE_UTM_HOST:-${UTM_HOST:-macos-test-02}}"
dry_run=0
view="dashboard"
app_path=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --host)
            [ "$#" -ge 2 ] || { usage; exit 2; }
            host="$2"; shift 2 ;;
        --dry-run) dry_run=1; shift ;;
        --view)
            [ "$#" -ge 2 ] || { usage; exit 2; }
            view="$2"; shift 2 ;;
        --app)
            [ "$#" -ge 2 ] || { usage; exit 2; }
            app_path="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown argument: $1" >&2; usage; exit 2 ;;
    esac
done

local_name="$(uname -n)"
case "$host" in
    localhost|127.0.0.1|::1|"$local_name")
        echo "[UTM-SMOKE] refusing host target '$host': Tier 2 runs only inside the UTM guest" >&2
        exit 2 ;;
    macos-test-02|macos-test-03) ;;
    *)
        echo "[UTM-SMOKE] refusing host target '$host': allowlist is macos-test-02|macos-test-03" >&2
        exit 2 ;;
esac

guest="${host}.local"
app_cmd="${app_path:-./Alidade.app/Contents/MacOS/Alidade}"
shot_dir="/tmp/alidade-utm-smoke"

print_sequence() {
    echo "ssh -4 -o BatchMode=yes ${guest} 'umask 077; mkdir -p ${shot_dir}; ${app_cmd} --demo --view ${view} --window-size 1440x900 --fixed-dt & echo \$! > ${shot_dir}/app.pid; sleep 5'"
    echo "ssh -4 -o BatchMode=yes ${guest} 'axcli tree --app Alidade > ${shot_dir}/${view}-accessibility.txt; axcli windows --app Alidade'"
    echo "ssh -4 -o BatchMode=yes ${guest} 'screencapture -x ${shot_dir}/${view}-1440x900.png'"
    echo "ssh -4 -o BatchMode=yes ${guest} 'kill \$(cat ${shot_dir}/app.pid) 2>/dev/null || true'"
    echo "scp -4 ${guest}:${shot_dir}/${view}-1440x900.png ${shot_dir}/${view}-1440x900.png"
}

if [ "$dry_run" -eq 1 ]; then
    print_sequence
    exit 0
fi

if ! ssh -4 -o BatchMode=yes -o ConnectTimeout=10 "$guest" 'true' 2>/dev/null; then
    echo "[UTM-SMOKE] guest $guest is offline/unreachable over ssh; not falling back to localhost" >&2
    exit 1
fi

ssh -4 -o BatchMode=yes "$guest" "umask 077; mkdir -p ${shot_dir}; ${app_cmd} --demo --view ${view} --window-size 1440x900 --fixed-dt & echo \$! > ${shot_dir}/app.pid; sleep 5"
ssh -4 -o BatchMode=yes "$guest" "axcli tree --app Alidade > ${shot_dir}/${view}-accessibility.txt; axcli windows --app Alidade"
ssh -4 -o BatchMode=yes "$guest" "screencapture -x ${shot_dir}/${view}-1440x900.png"
ssh -4 -o BatchMode=yes "$guest" 'kill $(cat '"${shot_dir}"'/app.pid) 2>/dev/null || true'
mkdir -p "$shot_dir"
scp -4 "${guest}:${shot_dir}/${view}-1440x900.png" "${shot_dir}/${view}-1440x900.png"
echo "[UTM-SMOKE] captured ${shot_dir}/${view}-1440x900.png from $guest"
