#!/bin/sh
# Installed as /usr/local/bin/sentry-cli. Runs the sentry-cli that
# sentry-update made current in the shared bin dir (mounted read-only: only
# devsandbox's `sentry` update writes it), so an update reaches every sandbox
# without a rebuild; else the image's own.
SHARED=/var/lib/devsandbox/sentry/bin
BAKED=/usr/local/lib/sentry

valid_version() {
    case "$1" in
        "" | .* | -* | *[!0-9A-Za-z.-]*) return 1 ;;
    esac
}

if [ -e "$SHARED/current" ]; then
    if [ -w "$SHARED" ]; then
        # Anything in the sandbox could have put that binary there.
        echo "sentry-cli: $SHARED is writable here, running the image's sentry-cli (mount it read-only)" >&2
    else
        read -r version < "$SHARED/current" || true
        if valid_version "${version:-}" && [ -x "$SHARED/$version/sentry-cli" ]; then
            exec "$SHARED/$version/sentry-cli" "$@"
        fi
        echo "sentry-cli: shared version \`${version:-}\` is missing, running the image's (\`devsandbox update sentry\` fixes it)" >&2
    fi
fi

exec "$BAKED/sentry-cli" "$@"
