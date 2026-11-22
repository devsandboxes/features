#!/bin/sh
# sentry-update <shared bin dir> [version]: the command of the feature's
# `sentry` update, which devsandbox runs (`devsandbox update sentry [version]`,
# and on its schedule) in a throwaway container from the sandbox's image with
# only the dir writable. Puts sentry <version> (a release like 0.50.0, default
# latest) in <dir>/<version>/sentry, its .gz asset checked against the sha256
# Sentry's release registry lists for it, and makes it the one every
# sandbox's `sentry` launcher runs from its next call. Sandboxes mount the dir
# read-only. A version also rolls back.
#
# sentry-update --bake <version>: what install.sh runs at image build, as
# root: the image's own sentry in /usr/local/lib/sentry, the launcher's
# fallback.
set -eu

REGISTRY=https://release-registry.services.sentry.io/apps/sentry
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

# The binary is a Node single-executable built against glibc 2.28.
check_libc() {
    for loader in /lib/ld-musl-*; do
        [ -e "$loader" ] && fail "sentry ships no musl build (Alpine and the like): use a glibc-based image"
    done
    glibc=$(getconf GNU_LIBC_VERSION 2>/dev/null) || fail "no glibc found: sentry needs glibc 2.28 or later"
    glibc=${glibc#glibc }
    major=${glibc%%.*}
    minor=${glibc#*.}
    minor=${minor%%.*}
    if [ "$major" -lt 2 ] || { [ "$major" -eq 2 ] && [ "$minor" -lt 28 ]; }; then
        fail "glibc $glibc is too old: sentry needs 2.28 or later"
    fi
}

# fetch <version or latest> <dir>: sentry into <dir>/sentry, the resolved
# version into <dir>/version.
fetch() {
    case "$(uname -m)" in
        x86_64 | amd64) arch=x64 ;;
        aarch64 | arm64) arch=arm64 ;;
        *) fail "sentry ships Linux binaries for x86_64 and aarch64 only, not $(uname -m)" ;;
    esac
    check_libc
    spec=${1#v}
    valid_version "$spec" || fail "bad version \`$spec\` (latest or a release like 0.50.0)"
    asset="sentry-linux-$arch.gz"
    release=$(curl -fsSL "$REGISTRY/$spec") || fail "no sentry release \`$spec\` in $REGISTRY"
    version=$(printf '%s' "$release" | sed -n 's/.*"version":"\([^"]*\)".*/\1/p')
    valid_version "$version" || fail "the registry's release \`$spec\` names a bad version \`$version\`"
    # The `files` entry: {"checksums":{"sha256-hex":"…"},"url":"…"}.
    entry=$(printf '%s' "$release" \
        | sed -n "s/.*\"$asset\":{\"checksums\":{\"sha256-hex\":\"\([0-9a-f]\{64\}\)\"},\"url\":\"\(https:[^\"]*\)\"}.*/\1 \2/p")
    [ -n "$entry" ] || fail "sentry $version lists no $asset with a sha256"
    want=${entry%% *}
    url=${entry#* }
    echo "sentry-update: downloading $url" >&2
    curl -fsSL -o "$2/sentry.gz" "$url" || fail "cannot download $url"
    [ "$(sha256 "$2/sentry.gz")" = "$want" ] || fail "$url doesn't match its sha256 $want"
    gunzip -c "$2/sentry.gz" > "$2/sentry.part" || fail "cannot unpack $asset"
    rm -f "$2/sentry.gz"
    chmod 0755 "$2/sentry.part"
    mv -f "$2/sentry.part" "$2/sentry"
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
# it); older ones go. Running sentry processes keep theirs until they exit.
for dir in "$shared"/*/; do
    name=$(basename "$dir")
    [ "$name" = "$version" ] || [ "$name" = "$previous" ] || rm -rf "$dir"
done

if [ "$previous" = "$version" ]; then
    echo "sentry-update: $version already current"
else
    echo "sentry-update: ${previous:-none} -> $version (every sandbox, from its next sentry call)"
fi
