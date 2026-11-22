#!/bin/sh
# sentry-update <shared bin dir> [version]: the command of the feature's
# `sentry` update, which devsandbox runs (`devsandbox update sentry [version]`,
# and on its schedule) in a throwaway container from the sandbox's image with
# only the dir writable. Puts sentry-cli <version> (a release like 3.8.2,
# default latest) in <dir>/<version>/sentry-cli, checked against the sha256
# Sentry's release registry lists for it, and makes it the one every
# sandbox's `sentry-cli` launcher runs from its next call. Sandboxes mount the
# dir read-only. A version also rolls back.
#
# sentry-update --bake <version>: what install.sh runs at image build, as
# root: the image's own sentry-cli in /usr/local/lib/sentry, the launcher's
# fallback.
set -eu

REGISTRY=https://release-registry.services.sentry.io/apps/sentry-cli
BAKED=/usr/local/lib/sentry

fail() {
    echo "sentry-update: $*" >&2
    exit 1
}

# A version names a dir and goes into a URL: no `/`, no leading dot or dash.
valid_version() {
    case "$1" in
        "" | .* | -* | *[!0-9A-Za-z.-]*) return 1 ;;
    esac
}

sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | cut -d' ' -f1
    else
        shasum -a 256 "$1" | cut -d' ' -f1
    fi
}

# fetch <version or latest> <dir>: sentry-cli into <dir>/sentry-cli, the
# resolved version into <dir>/version.
fetch() {
    case "$(uname -m)" in
        x86_64 | amd64) arch=x86_64 ;;
        aarch64 | arm64) arch=aarch64 ;;
        armv7l | armv7) arch=armv7 ;;
        i686 | i386) arch=i686 ;;
        *) fail "no sentry-cli binary for $(uname -m)" ;;
    esac
    spec=${1#v}
    valid_version "$spec" || fail "bad version \`$spec\` (latest or a release like 3.8.2)"
    asset="sentry-cli-Linux-$arch"
    release=$(curl -fsSL "$REGISTRY/$spec") || fail "no sentry-cli release \`$spec\` in $REGISTRY"
    version=$(printf '%s' "$release" | sed -n 's/.*"version":"\([^"]*\)".*/\1/p')
    valid_version "$version" || fail "the registry's release \`$spec\` names a bad version \`$version\`"
    # The `files` entry: {"checksums":{"sha256-hex":"…"},"url":"…"}.
    entry=$(printf '%s' "$release" \
        | sed -n "s/.*\"$asset\":{\"checksums\":{\"sha256-hex\":\"\([0-9a-f]\{64\}\)\"},\"url\":\"\(https:[^\"]*\)\"}.*/\1 \2/p")
    [ -n "$entry" ] || fail "sentry-cli $version lists no $asset with a sha256"
    want=${entry%% *}
    url=${entry#* }
    echo "sentry-update: downloading $url" >&2
    curl -fsSL -o "$2/sentry-cli.part" "$url" || fail "cannot download $url"
    [ "$(sha256 "$2/sentry-cli.part")" = "$want" ] || fail "$url doesn't match its sha256 $want"
    chmod 0755 "$2/sentry-cli.part"
    mv -f "$2/sentry-cli.part" "$2/sentry-cli"
    printf '%s\n' "$version" > "$2/version"
}

if [ "${1:-}" = --bake ]; then
    install -d "$BAKED"
    fetch "${2:-latest}" "$BAKED"
    exit 0
fi

shared=${1:?usage: sentry-update <shared bin dir> [version]}
spec=${2:-latest}
[ -d "$shared" ] || fail "$shared is not a directory"
[ -w "$shared" ] || fail "$shared is not writable here (\`devsandbox update sentry\` runs sentry-update with it writable)"

# Downloaded next to its final place (same filesystem), then renamed in.
tmp=$(mktemp -d "$shared/.update.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
# mktemp's 0700 would keep the sandbox's remote user from running it.
chmod 0755 "$tmp"
fetch "$spec" "$tmp"
read -r version < "$tmp/version"
rm -f "$tmp/version"
if [ ! -d "$shared/$version" ]; then
    mv "$tmp" "$shared/$version"
fi

previous=""
if [ -r "$shared/current" ]; then
    read -r previous < "$shared/current" || true
fi
printf '%s\n' "$version" > "$shared/.current.$$"
mv -f "$shared/.current.$$" "$shared/current"

# Keep the new and the previous version (a launcher may be about to start
# it); older ones go. Running sentry-cli processes keep theirs until they exit.
for dir in "$shared"/*/; do
    name=$(basename "$dir")
    [ "$name" = "$version" ] || [ "$name" = "$previous" ] || rm -rf "$dir"
done

if [ "$previous" = "$version" ]; then
    echo "sentry-update: $version already current"
else
    echo "sentry-update: ${previous:-none} -> $version (every sandbox, from its next sentry-cli call)"
fi
