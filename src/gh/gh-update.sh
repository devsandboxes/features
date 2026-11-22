#!/bin/sh
# gh-update <shared bin dir> [version]: the command of the feature's `gh`
# update, which devsandbox runs (`devsandbox update gh [version]`, and on its
# schedule) in a throwaway container from the sandbox's image with only the
# dir writable. Puts gh <version> (a release like 2.105.0, default latest) in
# <dir>/<version>/gh, checked against the release's gh_<version>_checksums.txt,
# and makes it the one every sandbox's `gh` launcher runs from its next call.
# Sandboxes mount the dir read-only. A version also rolls back.
#
# gh-update --bake <version>: what install.sh runs at image build, as root:
# the image's own gh in /usr/local/lib/gh, the launcher's fallback.
set -eu

RELEASES=https://github.com/cli/cli/releases
BAKED=/usr/local/lib/gh

fail() {
    echo "gh-update: $*" >&2
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

# fetch <version or latest> <dir>: gh into <dir>/gh, the resolved version
# into <dir>/version.
fetch() {
    case "$(uname -m)" in
        x86_64 | amd64) arch=amd64 ;;
        aarch64 | arm64) arch=arm64 ;;
        armv7l | armv7 | armv6l | armv6) arch=armv6 ;;
        i686 | i386 | 386) arch=386 ;;
        *) fail "no gh binary for $(uname -m)" ;;
    esac
    version=${1#v}
    if [ "$version" = latest ]; then
        # The latest release's page redirects to its tag: no API call, no rate limit.
        tag=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "$RELEASES/latest") \
            || fail "cannot resolve the latest gh release"
        version=${tag##*/v}
    fi
    valid_version "$version" || fail "bad version \`$version\` (latest or a release like 2.105.0)"
    asset="gh_${version}_linux_$arch.tar.gz"
    base="$RELEASES/download/v$version"
    echo "gh-update: downloading $base/$asset" >&2
    curl -fsSL -o "$2/sums" "$base/gh_${version}_checksums.txt" || fail "no gh release $version"
    want=$(awk -v a="$asset" '$2 == a { print $1 }' "$2/sums")
    [ -n "$want" ] || fail "gh $version lists no checksum for $asset"
    curl -fsSL -o "$2/gh.tgz" "$base/$asset" || fail "cannot download $base/$asset"
    [ "$(sha256 "$2/gh.tgz")" = "$want" ] || fail "$asset doesn't match its sha256 $want"
    tar -xzof "$2/gh.tgz" -C "$2" "gh_${version}_linux_$arch/bin/gh"
    mv "$2/gh_${version}_linux_$arch/bin/gh" "$2/gh"
    chmod 0755 "$2/gh"
    rm -rf "$2/sums" "$2/gh.tgz" "$2/gh_${version}_linux_$arch"
    printf '%s\n' "$version" > "$2/version"
}

if [ "${1:-}" = --bake ]; then
    install -d "$BAKED"
    fetch "${2:-latest}" "$BAKED"
    exit 0
fi

shared=${1:?usage: gh-update <shared bin dir> [version]}
spec=${2:-latest}
[ -d "$shared" ] || fail "$shared is not a directory"
[ -w "$shared" ] || fail "$shared is not writable here (\`devsandbox update gh\` runs gh-update with it writable)"

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
# it); older ones go. Running gh processes keep theirs until they exit.
for dir in "$shared"/*/; do
    name=$(basename "$dir")
    [ "$name" = "$version" ] || [ "$name" = "$previous" ] || rm -rf "$dir"
done

if [ "$previous" = "$version" ]; then
    echo "gh-update: $version already current"
else
    echo "gh-update: ${previous:-none} -> $version (every sandbox, from its next gh call)"
fi
