#!/bin/sh
# Installs sentry-cli's prebuilt static binary to /usr/local/bin/sentry-cli,
# checked against the sha256 Sentry's release registry lists for it. The token
# is devsandbox's business, not this script's: the claim in
# devcontainer-feature.json has the sandbox's sentry-cli reach Sentry through
# devsandbox's broker with a phantom token.
set -eu

VERSION="${VERSION:-latest}"
REGISTRY=https://release-registry.services.sentry.io/apps/sentry-cli
BIN=/usr/local/bin/sentry-cli

fail() {
    echo "sentry feature: $*" >&2
    exit 1
}

if [ "$(id -u)" -ne 0 ]; then
    fail "install.sh must run as root"
fi

# It goes into a URL.
case "$VERSION" in
    latest) ;;
    *[!0-9A-Za-z.-]* | "" | .* | -*) fail "bad version \`$VERSION\` (latest or a release like 3.8.2)" ;;
esac

# --- prerequisites ----------------------------------------------------------

missing=""
command -v curl >/dev/null 2>&1 || missing="$missing curl"
command -v sha256sum >/dev/null 2>&1 || missing="$missing coreutils"
[ -e /etc/ssl/certs/ca-certificates.crt ] || missing="$missing ca-certificates"
if [ -n "$missing" ]; then
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -y
        # shellcheck disable=SC2086 # word-split the package list on purpose
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $missing
        rm -rf /var/lib/apt/lists/*
    elif command -v apk >/dev/null 2>&1; then
        # shellcheck disable=SC2086 # word-split the package list on purpose
        apk add --no-cache $missing
    else
        fail "missing:$missing (only apt- and apk-based images are handled automatically)"
    fi
fi

# --- platform ---------------------------------------------------------------

case "$(uname -m)" in
    x86_64 | amd64) arch=x86_64 ;;
    aarch64 | arm64) arch=aarch64 ;;
    armv7l | armv7) arch=armv7 ;;
    i686 | i386) arch=i686 ;;
    *) fail "no sentry-cli binary for $(uname -m)" ;;
esac
asset="sentry-cli-Linux-$arch"

# --- binary -----------------------------------------------------------------

release=$(curl -fsSL "$REGISTRY/$VERSION") || fail "no sentry-cli release \`$VERSION\` in $REGISTRY"
# The `files` entry: {"checksums":{"sha256-hex":"…"},"url":"…"}.
entry=$(printf '%s' "$release" \
    | sed -n "s/.*\"$asset\":{\"checksums\":{\"sha256-hex\":\"\([0-9a-f]\{64\}\)\"},\"url\":\"\(https:[^\"]*\)\"}.*/\1 \2/p")
[ -n "$entry" ] || fail "release \`$VERSION\` lists no $asset with a sha256"
sum=${entry%% *}
url=${entry#* }

if [ -x "$BIN" ] && echo "$sum  $BIN" | sha256sum -c - >/dev/null 2>&1; then
    echo "sentry feature: $("$BIN" --version) already installed"
    exit 0
fi

tmp=$(mktemp "$BIN.XXXXXX")
trap 'rm -f "$tmp"' EXIT
curl -fsSL -o "$tmp" "$url" || fail "cannot download $url"
echo "$sum  $tmp" | sha256sum -c - >/dev/null || fail "$url doesn't match its sha256 $sum"
chmod 0755 "$tmp"
mv -f "$tmp" "$BIN"
trap - EXIT

echo "sentry feature: installed $("$BIN" --version)"
