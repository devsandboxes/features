#!/bin/sh
# Installed as /usr/local/bin/zidane. Runs the version zidane-update made
# current in the shared bin dir (every sandbox mounts the same one), so an
# update reaches every sandbox without a rebuild. The first run seeds that dir
# with the image's own copy; without the dir (or with a broken `current`) the
# image's copy runs.
SHARED=/var/lib/devsandbox/zidane/bin
BAKED=/usr/local/lib/zidane

valid_version() {
    case "$1" in
        "" | .* | *[!A-Za-z0-9._+-]*) return 1 ;;
    esac
}

# `zidane upgrade` installs through a package manager (npm by default), which
# a sandbox doesn't have or can't write with, and would only update this
# container: with the shared bin dir it's zidane-update instead, which updates
# every sandbox. --check runs zidane's own (it only reads the registry).
if [ "${1:-}" = upgrade ] && [ -d "$SHARED" ]; then
    channel=latest
    dry=""
    shift
    while [ $# -gt 0 ]; do
        case "$1" in
            --check)
                set -- upgrade --check
                break
                ;;
            -h | --help)
                echo "zidane upgrade runs zidane-update here: it updates zidane in every sandbox sharing $SHARED."
                echo "Usage: zidane upgrade [--channel <tag>] [--check] [--dry-run]   (or zidane-update [version|tag])"
                exit 0
                ;;
            --channel)
                channel=${2:-}
                [ -n "$channel" ] || { echo "zidane upgrade: --channel requires a value" >&2; exit 2; }
                shift
                ;;
            --dry-run | --dryrun) dry=1 ;;
            --force | --tui-only) ;;
            --in-place | --inplace) echo "zidane upgrade: $1 ignored (zidane-update installs into $SHARED)" >&2 ;;
            --registry | --package-manager)
                echo "zidane upgrade: $1 ignored (zidane-update installs from npm into $SHARED)" >&2
                shift
                ;;
            *)
                echo "zidane upgrade: unknown argument: $1" >&2
                exit 2
                ;;
        esac
        shift
    done
    if [ "${1:-}" != upgrade ]; then
        if [ -n "$dry" ]; then
            echo "zidane upgrade: would run zidane-update $channel"
            exit 0
        fi
        exec zidane-update "$channel"
    fi
fi

if [ -e "$SHARED/current" ]; then
    read -r version < "$SHARED/current" || true
    if valid_version "${version:-}" && [ -x "$SHARED/$version/zidane" ]; then
        exec "$SHARED/$version/zidane" "$@"
    fi
    echo "zidane: shared version \`${version:-}\` is missing, running the image's (zidane-update fixes it)" >&2
elif [ -d "$SHARED" ] && [ -w "$SHARED" ] && read -r version < "$BAKED/version" && valid_version "$version"; then
    # Seed: best effort, a failure just means the image's copy runs.
    if [ ! -d "$SHARED/$version" ] && tmp=$(mktemp -d "$SHARED/.seed.XXXXXX" 2>/dev/null); then
        { cp "$BAKED/zidane" "$tmp/zidane" && mv -T "$tmp" "$SHARED/$version"; } 2>/dev/null || rm -rf "$tmp"
    fi
    # No-clobber: a zidane-update racing this one wins.
    if [ -x "$SHARED/$version/zidane" ] && printf '%s\n' "$version" > "$SHARED/.current.$" 2>/dev/null; then
        mv -n "$SHARED/.current.$" "$SHARED/current" 2>/dev/null
        rm -f "$SHARED/.current.$"
    fi
fi

exec "$BAKED/zidane" "$@"
