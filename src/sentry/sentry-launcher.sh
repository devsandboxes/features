#!/bin/sh
# Installed as /usr/local/bin/sentry. Runs the sentry that sentry-update made
# current in the shared bin dir (mounted read-only: only devsandbox's
# `sentry` update writes it), so an update reaches every sandbox without a
# rebuild; else the image's own.
SHARED=/var/lib/devsandbox/sentry/bin
BAKED=/usr/local/lib/sentry

valid_version() {
    case "$1" in
        "" | .* | -* | *[!0-9A-Za-z.-]*) return 1 ;;
    esac
}

# `sentry cli upgrade` replaces the binary it runs from, in this container
# only; devsandbox updates the shared copy instead. --check and --help only
# read, so they stay sentry's own.
if [ "${1:-}" = cli ] && [ "${2:-}" = upgrade ]; then
    own=""
    for arg in "$@"; do
        case "$arg" in
            --check | -h | --help) own=1 ;;
        esac
    done
    if [ -z "$own" ]; then
        echo "sentry cli upgrade: devsandbox updates sentry in every sandbox; run \`devsandbox update sentry [version]\` on the host" >&2
        exit 1
    fi
fi

if [ -e "$SHARED/current" ]; then
    if [ -w "$SHARED" ]; then
        # Anything in the sandbox could have put that binary there.
        echo "sentry: $SHARED is writable here, running the image's sentry (mount it read-only)" >&2
    else
        read -r version < "$SHARED/current" || true
        if valid_version "${version:-}" && [ -x "$SHARED/$version/sentry" ]; then
            exec "$SHARED/$version/sentry" "$@"
        fi
        echo "sentry: shared version \`${version:-}\` is missing, running the image's (\`devsandbox update sentry\` fixes it)" >&2
    fi
fi

exec "$BAKED/sentry" "$@"
