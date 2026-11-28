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

# --view is interpolated into remote shell strings: allowlist the
# exact CLI view names (View::from_cli_name in src/app/state.rs)
# so no shell metacharacter can reach the guest.
case "$view" in
    dashboard|characters|char|skills|skill|wallet|assets|asset|market|industry|planets|pi|fittings|fitting|settings|exploration|explore|pantry|mining|corporation|corp) ;;
    *)
        echo "[UTM-SMOKE] refusing view '$view': not a known view name" >&2
        exit 2 ;;
esac

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
# The bundle executable is Contents/MacOS/mimir (scripts/bundle-macos.sh
# keeps CFBundleExecutable=mimir under the Alidade.app name).
remote_app_dir="/tmp/alidade-utm-app"
app_cmd="${app_path:-${remote_app_dir}/Alidade.app/Contents/MacOS/mimir}"
shot_dir="/tmp/alidade-utm-smoke"
lock_dir="/tmp/alidade-visual-qa.lock"
q_app="$(printf '%q' "$app_cmd")"
q_view="$(printf '%q' "$view")"

print_sequence() {
    echo "ssh -4 -o BatchMode=yes ${guest} 'uname -n'  # must differ from local ${local_name}"
    echo "ssh -4 -o BatchMode=yes ${guest} 'umask 077; mkdir ${lock_dir} && trap \"rmdir ${lock_dir}\" EXIT; mkdir -p ${shot_dir}'"
    if [ -n "$app_path" ]; then
        echo "scp -4 -r $(printf '%q' "$app_path") ${guest}:${remote_app_dir}/"
    else
        echo "# no --app given: using pre-staged ${app_cmd} on the guest"
    fi
    echo "ssh -4 -o BatchMode=yes ${guest} '${q_app} --demo --view ${q_view} >/tmp/alidade-utm.log 2>&1 </dev/null & echo \$! > ${shot_dir}/app.pid; sleep 5; kill -0 \$(cat ${shot_dir}/app.pid)'"
    echo "ssh -4 -o BatchMode=yes ${guest} 'axcli tree --app Alidade > ${shot_dir}/${view}-accessibility.txt; axcli windows --app Alidade'"
    echo "ssh -4 -o BatchMode=yes ${guest} 'wid=\$(axcli windows --app Alidade | head -n 1); screencapture -x -o -l \$wid ${shot_dir}/${view}-1440x900.png'"
    echo "ssh -4 -o BatchMode=yes ${guest} 'kill \$(cat ${shot_dir}/app.pid) 2>/dev/null || true; rmdir ${lock_dir}'"
    echo "scp -4 ${guest}:${shot_dir}/${view}-1440x900.png ${shot_dir}/${view}-1440x900.png"
}

if [ "$dry_run" -eq 1 ]; then
    print_sequence
    exit 0
fi

# Live path: prove the remote really is another machine.
remote_name="$(ssh -4 -o BatchMode=yes -o ConnectTimeout=10 "$guest" 'uname -n' 2>/dev/null || true)"
if [ -z "$remote_name" ]; then
    echo "[UTM-SMOKE] guest $guest is offline/unreachable over ssh; not falling back to localhost" >&2
    exit 1
fi
if [ "$remote_name" = "$local_name" ]; then
    echo "[UTM-SMOKE] refusing: remote uname -n matches local host ($local_name)" >&2
    exit 2
fi

# Guest lock: serialize Tier 2 runs; always released by trap in-guest
# and by the explicit unlock at the end of this script.
if ! ssh -4 -o BatchMode=yes "$guest" "umask 077; mkdir $lock_dir"; then
    echo "[UTM-SMOKE] guest lock $lock_dir already held on $guest" >&2
    exit 1
fi
unlock_guest() {
    ssh -4 -o BatchMode=yes "$guest" "rmdir $lock_dir 2>/dev/null || true" || true
}
trap unlock_guest EXIT

ssh -4 -o BatchMode=yes "$guest" "mkdir -p $shot_dir"
if [ -n "$app_path" ]; then
    ssh -4 -o BatchMode=yes "$guest" "mkdir -p $remote_app_dir"
    scp -4 -r "$app_path" "$guest:$remote_app_dir/"
fi

ssh -4 -o BatchMode=yes "$guest" "$q_app --demo --view $q_view >/tmp/alidade-utm.log 2>&1 </dev/null & echo \$! > $shot_dir/app.pid; sleep 5; kill -0 \$(cat $shot_dir/app.pid)"
ssh -4 -o BatchMode=yes "$guest" "axcli tree --app Alidade > $shot_dir/$view-accessibility.txt; axcli windows --app Alidade"
ssh -4 -o BatchMode=yes "$guest" "wid=\$(axcli windows --app Alidade | head -n 1); screencapture -x -o -l \$wid $shot_dir/$view-1440x900.png"
ssh -4 -o BatchMode=yes "$guest" "kill \$(cat $shot_dir/app.pid) 2>/dev/null || true"
mkdir -p "$shot_dir"
scp -4 "$guest:$shot_dir/$view-1440x900.png" "$shot_dir/$view-1440x900.png"
echo "[UTM-SMOKE] captured $shot_dir/$view-1440x900.png from $guest"
