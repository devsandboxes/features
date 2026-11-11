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
bin=/var/lib/devsandbox/zidane/bin
baked=$(cat /usr/local/lib/zidane/version)

check "zidane on PATH" 'command -v zidane >/dev/null'
check "zidane-update on PATH" 'command -v zidane-update >/dev/null'
check "zidane runs" 'zidane --version >/dev/null'
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

# The first run seeded the shared bin dir with the image's copy.
check "first run seeds current" "[ \"\$(cat $bin/current)\" = '$baked' ]"
check "seeded binary" "[ -x '$bin/$baked/zidane' ]"
check "no seed leftovers" "[ -z \"\$(find $bin -maxdepth 1 -name '.*' ! -name . )\" ]"

# The launcher runs whatever current names (a stand-in binary here).
mkdir -p "$bin/9.9.9-test"
printf '#!/bin/sh\necho stand-in "$@"\n' > "$bin/9.9.9-test/zidane"
chmod +x "$bin/9.9.9-test/zidane"
echo 9.9.9-test > "$bin/current"
check "runs the current version" "[ \"\$(zidane a b)\" = 'stand-in a b' ]"

# A current that's missing or escapes the dir falls back to the image's copy.
for bad in 1.0.0-missing ../../../usr/bin; do
    echo "$bad" > "$bin/current"
    check "current \`$bad\` falls back" "zidane --version >/dev/null 2>&1 && [ \"\$(zidane --version 2>/dev/null)\" != stand-in ]"
done

# zidane-update installs a real version, makes it current and prunes all but
# it and the previous one.
echo 9.9.9-test > "$bin/current"
mkdir -p "$bin/0.0.0-old"
check "zidane-update latest" "zidane-update latest >/dev/null"
new=$(cat "$bin/current")
check "current is the update ($new)" "[ -x '$bin/$new/zidane' ] && zidane --version >/dev/null"
check "previous kept" "[ -d '$bin/9.9.9-test' ]"
check "older pruned" "[ ! -e '$bin/0.0.0-old' ]"
check "update leftovers cleaned" "[ -z \"\$(find $bin -maxdepth 1 -name '.*' ! -name . )\" ]"
check "rollback" "zidane-update '$baked' >/dev/null && [ \"\$(cat $bin/current)\" = '$baked' ]"
check "bad version refused" "! zidane-update 'no/such' >/dev/null 2>&1"

# `zidane upgrade` goes through zidane-update, not a package manager.
check "upgrade --dry-run" "[ \"\$(zidane upgrade --dry-run --channel next)\" = 'zidane upgrade: would run zidane-update next' ]"
check "upgrade --help" "zidane upgrade --help | grep -q zidane-update"
check "upgrade --check is zidane's" "zidane upgrade --check >/dev/null"
check "upgrade bad arg" "! zidane upgrade --nope >/dev/null 2>&1"
echo 9.9.9-test > "$bin/current"
check "upgrade" "zidane upgrade >/dev/null 2>&1 && [ \"\$(cat $bin/current)\" != 9.9.9-test ] && zidane --version >/dev/null"

exit "$failed"
