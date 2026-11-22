#!/bin/sh
# Runs as the remote user after install.sh (see scripts/test-feature.sh).
# Without devsandbox's mounts there is no shared bin dir: the launcher runs the
# image's zidane, and zidane-update is tried on a dir of its own.
set -eu

check() {
    if eval "$2"; then
        echo "ok   $1"
    else
        echo "FAIL $1" >&2
        failed=1
    fi
}
failed=0
update=/usr/local/lib/zidane/zidane-update

check "zidane on PATH is the launcher" "[ \"\$(command -v zidane)\" = /usr/local/bin/zidane ]"
check "no zidane-update on PATH" '! command -v zidane-update >/dev/null'
check "zidane runs" 'zidane --version >/dev/null'
check "the update's command installed" "[ -x $update ] && [ \"\$(stat -c %u $update)\" = 0 ]"
check "no shared bin dir: the image's zidane" "[ ! -e /var/lib/devsandbox/zidane/bin ]"
check "daemon socket env" "[ \"\$ZIDANE_DAEMON_SOCKET\" = /var/lib/devsandbox/zidane/data/daemon/daemon.sock ]"
for pair in \
    .config/zidane:config \
    .local/share/zidane:data \
    .local/state/zidane:state \
    .cache/zidane:cache \
    .agents/skills:skills \
    .agents/extensions:extensions; do
    path="$HOME/${pair%%:*}"
    target="/var/lib/devsandbox/zidane/${pair##*:}"
    check "$path -> $target" "[ \"\$(readlink '$path')\" = '$target' ]"
    check "$path writable" "touch '$path/.probe' && rm '$path/.probe'"
done

# zidane-update installs a real version, makes it current and prunes all but
# it and the previous one.
dir=$(mktemp -d)
mkdir "$dir/9.9.9-test" "$dir/0.0.0-old"
echo 9.9.9-test > "$dir/current"
check "zidane-update latest" "$update '$dir' latest >/dev/null"
new=$(cat "$dir/current")
check "current is the update ($new)" "[ -x '$dir/$new/zidane' ] && '$dir/$new/zidane' --version >/dev/null"
check "previous kept" "[ -d '$dir/9.9.9-test' ]"
check "older pruned" "[ ! -e '$dir/0.0.0-old' ]"
check "update leftovers cleaned" "[ -z \"\$(find '$dir' -maxdepth 1 -name '.*' ! -name . )\" ]"
check "bad version refused" "! $update '$dir' 'no/such' >/dev/null 2>&1"
check "no dir refused" "! $update >/dev/null 2>&1"
chmod a-w "$dir"
check "read-only dir refused" "[ \"\$(id -u)\" = 0 ] || ! $update '$dir' latest >/dev/null 2>&1"
chmod u+w "$dir"
rm -rf "$dir"

# `zidane upgrade` is devsandbox's, except zidane's read-only --check.
check "upgrade points at devsandbox" "zidane upgrade 2>&1 | grep -q 'devsandbox update zidane'"
check "upgrade fails" "! zidane upgrade >/dev/null 2>&1"
check "upgrade --channel fails" "! zidane upgrade --channel next >/dev/null 2>&1"
check "upgrade --check is zidane's" "zidane upgrade --check >/dev/null"

exit "$failed"
