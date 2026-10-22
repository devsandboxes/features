#!/bin/sh
# Runs as the remote user after install.sh (see scripts/test-feature.sh).
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

check "zidane on PATH" 'command -v zidane >/dev/null'
check "zidane runs" 'zidane --version >/dev/null'
check "daemon socket env" '[ "$ZIDANE_DAEMON_SOCKET" = /var/lib/devsandbox/zidane/data/daemon/daemon.sock ]'
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

exit "$failed"
