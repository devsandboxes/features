#!/bin/sh
# Installs sentry-cli's prebuilt static binary, checked against the sha256
# Sentry's release registry lists for it, into /usr/local/lib/sentry, with the
# `sentry-cli` launcher (it runs the version sentry-update made current in the
# shared bin dir, else this one) and sentry-update, the command devsandbox's
# `sentry` update runs in a container from this image. The token is
# devsandbox's business, not this script's: the claim in
# devcontainer-feature.json has the sandbox's sentry-cli reach Sentry through
# devsandbox's broker with a phantom token.
set -eu

VERSION="${VERSION:-latest}"
BAKED=/usr/local/lib/sentry

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

# --- binary -----------------------------------------------------------------

if [ -x "$BAKED/sentry-cli" ] && [ -r "$BAKED/version" ] && [ "$(cat "$BAKED/version")" = "$VERSION" ]; then
    echo "sentry feature: sentry-cli $VERSION already installed"
else
    rm -rf "$BAKED"
    sh ./sentry-update.sh --bake "$VERSION"
fi
install -m 0755 sentry-launcher.sh /usr/local/bin/sentry-cli
# After the bake: a version change empties $BAKED.
install -m 0755 sentry-update.sh "$BAKED/sentry-update"

echo "sentry feature: installed sentry-cli $(cat "$BAKED/version")"
