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
bin=/usr/local/lib/sentry/sentry-cli

check "sentry-cli on PATH is the launcher" "[ \"\$(command -v sentry-cli)\" = /usr/local/bin/sentry-cli ]"
check "sentry-cli runs" "sentry-cli --version | grep -Eq '^sentry-cli [0-9]+\.[0-9]+\.[0-9]+'"
check "baked version recorded" "[ \"\$(sentry-cli --version)\" = \"sentry-cli \$(cat /usr/local/lib/sentry/version)\" ]"
check "sentry-cli --help" "sentry-cli --help >/dev/null"
check "owned by root" "[ \"\$(stat -c %u $bin)\" = 0 ] && [ \"\$(stat -c %u /usr/local/bin/sentry-cli)\" = 0 ]"
check "not writable by the user" "[ \"\$(id -u)\" = 0 ] || { [ ! -w $bin ] && [ ! -w /usr/local/bin/sentry-cli ]; }"
check "the update's command installed" "[ -x /usr/local/lib/sentry/sentry-update ] && [ \"\$(stat -c %u /usr/local/lib/sentry/sentry-update)\" = 0 ]"
check "update check off" "[ \"\$SENTRY_DISABLE_UPDATE_CHECK\" = true ]"
check "no token baked in" "[ -z \"\${SENTRY_AUTH_TOKEN:-}\" ] && [ ! -e \"\$HOME/.sentryclirc\" ]"
check "no shared bin dir: the image's sentry-cli" "[ ! -e /var/lib/devsandbox/sentry/bin ]"

exit "$failed"
