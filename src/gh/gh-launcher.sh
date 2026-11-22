#!/bin/sh
# Installed as /usr/local/bin/gh. Runs the gh that gh-update made current in
# the shared bin dir, when the sandbox mounts one (read-only: the host
# updates it), so an update reaches every sandbox without a rebuild; else
# the image's own.
SHARED=/var/lib/devsandbox/gh/bin
BAKED=/usr/local/lib/gh

valid_version() {
    case "$1" in
        "" | .* | -* | *[!0-9A-Za-z.-]*) return 1 ;;
    esac
}

if [ -e "$SHARED/current" ]; then
    if [ -w "$SHARED" ]; then
        # Anything in the sandbox could have put that binary there.
        echo "gh: $SHARED is writable here, running the image's gh (mount it read-only)" >&2
    else
        read -r version < "$SHARED/current" || true
        if valid_version "${version:-}" && [ -x "$SHARED/$version/gh" ]; then
            exec "$SHARED/$version/gh" "$@"
        fi
        echo "gh: shared version \`${version:-}\` is missing, running the image's (gh-update on the host fixes it)" >&2
    fi
fi

exec "$BAKED/gh" "$@"
