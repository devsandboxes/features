#!/bin/sh
# Installs gh's prebuilt Linux binary from its GitHub release, checked against
# the release's gh_<version>_checksums.txt, into /usr/local/lib/gh, with the
# `gh` launcher (it runs the version gh-update made current in a mounted
# shared bin dir, else this one). The token is devsandbox's business, not
# this script's: the claim in devcontainer-feature.json has the sandbox's gh
# and git reach GitHub through devsandbox's broker with a phantom token.
set -eu

VERSION="${VERSION:-latest}"
BAKED=/usr/local/lib/gh

fail() {
    echo "gh feature: $*" >&2
    exit 1
}

if [ "$(id -u)" -ne 0 ]; then
    fail "install.sh must run as root"
fi

# It goes into a URL.
case "$VERSION" in
    latest) ;;
    *[!0-9A-Za-z.-]* | "" | .* | -*) fail "bad version \`$VERSION\` (latest or a release like 2.105.0)" ;;
esac

# --- prerequisites ----------------------------------------------------------

missing=""
command -v curl >/dev/null 2>&1 || missing="$missing curl"
command -v tar >/dev/null 2>&1 || missing="$missing tar"
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

# --- binary -----------------------------------------------------------------

want=${VERSION#v}
if [ -x "$BAKED/gh" ] && [ -r "$BAKED/version" ] && [ "$(cat "$BAKED/version")" = "$want" ]; then
    echo "gh feature: gh $want already installed"
else
    rm -rf "$BAKED"
    sh ./gh-update.sh --bake "$VERSION"
fi
install -m 0755 gh-launcher.sh /usr/local/bin/gh

echo "gh feature: installed gh $(cat "$BAKED/version")"
