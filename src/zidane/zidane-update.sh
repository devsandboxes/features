#!/bin/sh
# zidane-update [version]: installs zidane-tui <version> (an npm version or
# dist-tag, default latest) into the shared bin dir and makes it the one every
# sandbox's `zidane` launcher runs from its next start. Running sessions keep
# their binary. `zidane-update 1.2.3` also rolls back.
#
# zidane-update --bake <version>: what install.sh runs at image build, as
# root: the image's own copy, in /usr/local/lib/zidane, which seeds the shared
# dir on first run and is the fallback without it.
set -eu

REGISTRY=https://registry.npmjs.org
SHARED=/var/lib/devsandbox/zidane/bin
BAKED=/usr/local/lib/zidane

fail() {
    echo "zidane-update: $*" >&2
    exit 1
}

# A version names a dir under $SHARED: no `/`, no leading dot.
valid_version() {
    case "$1" in
        "" | .* | *[!A-Za-z0-9._+-]*) return 1 ;;
    esac
}

# fetch <version or tag> <dir>: zidane into <dir>/zidane, the resolved version
# into <dir>/version.
fetch() {
    case "$(uname -m)" in
        x86_64 | amd64) arch=x64 ;;
        aarch64 | arm64) arch=arm64 ;;
        *) fail "no zidane binary for $(uname -m) (linux x64 and arm64 only)" ;;
    esac
    package="zidane-tui-linux-$arch"
    meta=$(curl -fsSL "$REGISTRY/$package/$1") \
        || fail "cannot resolve $package@$1 from $REGISTRY"
    # The per-version document is one JSON object; these keys appear once in it.
    tarball=$(printf '%s' "$meta" | sed -n 's/.*"tarball":"\([^"]*\)".*/\1/p')
    shasum=$(printf '%s' "$meta" | sed -n 's/.*"shasum":"\([^"]*\)".*/\1/p')
    version=$(printf '%s' "$meta" | sed -n 's/.*"version":"\([^"]*\)".*/\1/p')
    if [ -z "$tarball" ] || [ -z "$shasum" ] || ! valid_version "$version"; then
        fail "unexpected registry answer for $package@$1"
    fi
    echo "zidane-update: downloading $tarball" >&2
    curl -fsSL -o "$2/pkg.tgz" "$tarball"
    echo "$shasum  $2/pkg.tgz" | sha1sum -c - >/dev/null || fail "checksum mismatch for $tarball"
    tar -xzf "$2/pkg.tgz" -C "$2" package/bin/zidane
    mv "$2/package/bin/zidane" "$2/zidane"
    chmod 0755 "$2/zidane"
    rm -rf "$2/pkg.tgz" "$2/package"
    printf '%s\n' "$version" > "$2/version"
}

if [ "${1:-}" = --bake ]; then
    install -d "$BAKED"
    fetch "${2:-latest}" "$BAKED"
    exit 0
fi

spec=${1:-latest}
[ -d "$SHARED" ] || fail "$SHARED is missing (not a devsandbox container?)"
[ -w "$SHARED" ] || fail "$SHARED is not writable"

# Downloaded next to its final place (same filesystem), then renamed in.
tmp=$(mktemp -d "$SHARED/.update.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
fetch "$spec" "$tmp"
read -r version < "$tmp/version"
rm -f "$tmp/version"
# Another sandbox may have installed it meanwhile: keep theirs.
[ -d "$SHARED/$version" ] || mv -T "$tmp" "$SHARED/$version" 2>/dev/null || true

previous=""
[ -r "$SHARED/current" ] && read -r previous < "$SHARED/current" || true
printf '%s\n' "$version" > "$SHARED/.current.$$"
mv -f "$SHARED/.current.$$" "$SHARED/current"

# Keep the new and the previous version (a launcher may be about to start it);
# older ones go. Sessions running one keep it until they exit.
for dir in "$SHARED"/*/; do
    name=$(basename "$dir")
    [ "$name" = "$version" ] || [ "$name" = "$previous" ] || rm -rf "$dir"
done

if [ "$previous" = "$version" ]; then
    echo "zidane-update: $version already current"
else
    echo "zidane-update: ${previous:-none} -> $version (new zidane sessions in every sandbox)"
fi
