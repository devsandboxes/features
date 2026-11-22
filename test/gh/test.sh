#!/bin/sh
# Runs as the remote user after install.sh (see scripts/test-feature.sh).
# Outside devsandbox there is no broker: this checks the install and the
# launcher only.
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
bin=/usr/local/lib/gh/gh

check "gh on PATH is the launcher" "[ \"\$(command -v gh)\" = /usr/local/bin/gh ]"
check "gh runs" "gh --version | grep -Eq '^gh version [0-9]+\.[0-9]+\.[0-9]+'"
check "baked version recorded" "gh --version | grep -qF \"gh version \$(cat /usr/local/lib/gh/version) \""
check "gh --help" "gh --help >/dev/null"
check "owned by root" "[ \"\$(stat -c %u $bin)\" = 0 ] && [ \"\$(stat -c %u /usr/local/bin/gh)\" = 0 ]"
check "not writable by the user" "[ \"\$(id -u)\" = 0 ] || { [ ! -w $bin ] && [ ! -w /usr/local/bin/gh ]; }"
check "telemetry off" "[ \"\$GH_TELEMETRY\" = false ]"
check "no token baked in" "[ -z \"\${GH_TOKEN:-}\" ] && [ -z \"\${GITHUB_TOKEN:-}\" ] && [ ! -e \"\$HOME/.config/gh/hosts.yml\" ]"
check "no shared bin dir: the image's gh" "[ ! -e /var/lib/devsandbox/gh/bin ]"

exit "$failed"
