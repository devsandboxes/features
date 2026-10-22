#!/bin/sh
# Installs zidane-tui's prebuilt binary from the npm registry (no node needed)
# and links the remote user's zidane dirs to the fixed mount targets declared
# in devcontainer-feature.json. Mount targets can't depend on the user's home
# (feature mounts are static), hence the symlinks.
set -eu

VERSION="${VERSION:-latest}"
MOUNT_ROOT=/var/lib/devsandbox/zidane
REGISTRY=https://registry.npmjs.org

fail() {
    echo "zidane feature: $*" >&2
    exit 1
}

if [ "$(id -u)" -ne 0 ]; then
    fail "install.sh must run as root"
fi

# --- prerequisites ----------------------------------------------------------

missing=""
command -v curl >/dev/null 2>&1 || missing="$missing curl"
command -v tar >/dev/null 2>&1 || missing="$missing tar"
command -v sha1sum >/dev/null 2>&1 || missing="$missing coreutils"
[ -e /etc/ssl/certs/ca-certificates.crt ] || missing="$missing ca-certificates"
if [ -n "$missing" ]; then
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -y
        # shellcheck disable=SC2086 # word-split the package list on purpose
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $missing
        rm -rf /var/lib/apt/lists/*
    else
        fail "missing:$missing (only apt-based images are handled automatically)"
    fi
fi

# --- platform ---------------------------------------------------------------

case "$(uname -m)" in
    x86_64 | amd64) arch=x64 ;;
    aarch64 | arm64) arch=arm64 ;;
    *) fail "no zidane binary for $(uname -m) (linux x64 and arm64 only)" ;;
esac
if ldd --version 2>&1 | grep -qi musl; then
    fail "no zidane binary for musl (glibc images only)"
fi

# --- binary -----------------------------------------------------------------

package="zidane-tui-linux-$arch"
meta=$(curl -fsSL "$REGISTRY/$package/$VERSION") \
    || fail "cannot resolve $package@$VERSION from $REGISTRY"
# The per-version document is one JSON object; these keys appear once in it.
tarball=$(printf '%s' "$meta" | sed -n 's/.*"tarball":"\([^"]*\)".*/\1/p')
shasum=$(printf '%s' "$meta" | sed -n 's/.*"shasum":"\([^"]*\)".*/\1/p')
if [ -z "$tarball" ] || [ -z "$shasum" ]; then
    fail "unexpected registry answer for $package@$VERSION"
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
echo "zidane feature: downloading $tarball"
curl -fsSL -o "$tmp/pkg.tgz" "$tarball"
echo "$shasum  $tmp/pkg.tgz" | sha1sum -c - >/dev/null || fail "checksum mismatch for $tarball"
tar -xzf "$tmp/pkg.tgz" -C "$tmp" package/bin/zidane
install -m 0755 "$tmp/package/bin/zidane" /usr/local/bin/zidane

# --- dirs -------------------------------------------------------------------

user="${_REMOTE_USER:-root}"
home="${_REMOTE_USER_HOME:-$(getent passwd "$user" | cut -d: -f6)}"
[ -n "$home" ] || fail "cannot find the home of remote user \`$user\`"
group=$(id -gn "$user")

# The mount targets, for a container started without them (plain devcontainer
# CLI, tests): zidane still works, just without persistence.
for d in config data state cache skills extensions; do
    install -d -o "$user" -g "$group" "$MOUNT_ROOT/$d"
done

# link <path under $home> <mount target>
link() {
    path="$home/$1"
    # Create missing parents one level at a time so each is owned by the user.
    rel=""
    for part in $(dirname "$1" | tr '/' ' '); do
        rel="$rel/$part"
        [ -d "$home$rel" ] || install -d -o "$user" -g "$group" "$home$rel"
    done
    if [ -L "$path" ]; then
        rm -f "$path"
    elif [ -d "$path" ]; then
        rmdir "$path" 2>/dev/null || fail "$path exists and is not empty"
    elif [ -e "$path" ]; then
        fail "$path exists and is not a directory"
    fi
    ln -s "$2" "$path"
    chown -h "$user:$group" "$path"
}

link .config/zidane "$MOUNT_ROOT/config"
link .local/share/zidane "$MOUNT_ROOT/data"
link .local/state/zidane "$MOUNT_ROOT/state"
link .cache/zidane "$MOUNT_ROOT/cache"
link .agents/skills "$MOUNT_ROOT/skills"
link .agents/extensions "$MOUNT_ROOT/extensions"

echo "zidane feature: installed $(/usr/local/bin/zidane --version 2>/dev/null || echo "$package@$VERSION") for $user"
