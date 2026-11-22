#!/bin/sh
# Installed as /usr/local/bin/zidane. Runs the zidane that zidane-update made
# current in the shared bin dir (mounted read-only: only devsandbox's `zidane`
# update writes it), so an update reaches every sandbox without a rebuild;
# else the image's own.
SHARED=/var/lib/devsandbox/zidane/bin
BAKED=/usr/local/lib/zidane

valid_version() {
    case "$1" in
        "" | .* | *[!A-Za-z0-9._+-]*) return 1 ;;
    esac
}

# `zidane upgrade` installs through a package manager into this container
# only; devsandbox updates the shared copy instead. --check and --help only
# read, so they stay zidane's own.
if [ "${1:-}" = upgrade ]; then
    own=""
    for arg in "$@"; do
        case "$arg" in
            --check | -h | --help) own=1 ;;
        esac
    done
    if [ -z "$own" ]; then
        echo "zidane upgrade: devsandbox updates zidane in every sandbox; run \`devsandbox update zidane [version]\` on the host" >&2
        exit 1
    fi
fi

if [ -e "$SHARED/current" ]; then
    if [ -w "$SHARED" ]; then
        # Anything in the sandbox could have put that binary there.
        echo "zidane: $SHARED is writable here, running the image's zidane (mount it read-only)" >&2
    else
        read -r version < "$SHARED/current" || true
        if valid_version "${version:-}" && [ -x "$SHARED/$version/zidane" ]; then
            exec "$SHARED/$version/zidane" "$@"
        fi
        echo "zidane: shared version \`${version:-}\` is missing, running the image's (\`devsandbox update zidane\` fixes it)" >&2
    fi
fi

exec "$BAKED/zidane" "$@"
