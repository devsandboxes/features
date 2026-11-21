#!/bin/sh
# Runs as the remote user after install.sh (see scripts/test-feature.sh).
# Outside devsandbox there is no broker: this checks the install only.
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
bin=/usr/local/bin/sentry-cli

check "sentry-cli on PATH" "[ \"\$(command -v sentry-cli)\" = $bin ]"
check "sentry-cli runs" "sentry-cli --version | grep -Eq '^sentry-cli [0-9]+\.[0-9]+\.[0-9]+'"
check "sentry-cli --help" "sentry-cli --help >/dev/null"
check "owned by root" "[ \"\$(stat -c %u $bin)\" = 0 ]"
check "not writable by the user" "[ \"\$(id -u)\" = 0 ] || [ ! -w $bin ]"
check "update check off" "[ \"\$SENTRY_DISABLE_UPDATE_CHECK\" = true ]"
check "no token baked in" "[ -z \"\${SENTRY_AUTH_TOKEN:-}\" ] && [ ! -e \"\$HOME/.sentryclirc\" ]"

exit "$failed"
