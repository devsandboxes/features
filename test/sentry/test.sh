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
bin=/usr/local/lib/sentry/sentry

check "sentry on PATH is the launcher" "[ \"\$(command -v sentry)\" = /usr/local/bin/sentry ]"
check "sentry runs" "sentry --version | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+'"
check "baked version recorded" "[ \"\$(sentry --version)\" = \"\$(cat /usr/local/lib/sentry/version)\" ]"
check "sentry --help" "sentry --help >/dev/null"
check "owned by root" "[ \"\$(stat -c %u $bin)\" = 0 ] && [ \"\$(stat -c %u /usr/local/bin/sentry)\" = 0 ]"
check "not writable by the user" "[ \"\$(id -u)\" = 0 ] || { [ ! -w $bin ] && [ ! -w /usr/local/bin/sentry ]; }"
check "the update's command installed" "[ -x /usr/local/lib/sentry/sentry-update ] && [ \"\$(stat -c %u /usr/local/lib/sentry/sentry-update)\" = 0 ]"
check "telemetry and update check off" "[ \"\$SENTRY_CLI_NO_TELEMETRY\" = 1 ] && [ \"\$SENTRY_CLI_NO_UPDATE_CHECK\" = 1 ]"
check "cli upgrade points to devsandbox" "! sentry cli upgrade 2>/tmp/upgrade.err && grep -q 'devsandbox update sentry' /tmp/upgrade.err"
check "no token baked in" "[ -z \"\${SENTRY_AUTH_TOKEN:-}\" ] && [ ! -e \"\$HOME/.sentryclirc\" ]"
check "no shared bin dir: the image's sentry" "[ ! -e /var/lib/devsandbox/sentry/bin ]"

exit "$failed"
