#!/bin/sh
# Installs Sentry's CLI (`sentry`, a prebuilt glibc binary, its .gz checked
# against the sha256 Sentry's release registry lists for it) into
# /usr/local/lib/sentry, with the `sentry` launcher (it runs the version
# sentry-update made current in the shared bin dir, else this one) and
# sentry-update, the command devsandbox's `sentry` update runs in a container
# from this image. The token is devsandbox's business, not this script's: the
# claim in devcontainer-feature.json has the sandbox's sentry reach Sentry
# through devsandbox's broker with a phantom token.
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
    *[!0-9A-Za-z.-]* | "" | .* | -*) fail "bad version \`$VERSION\` (latest or a release like 0.50.0)" ;;
esac

# Before installing anything: no package would make a musl image work.
for loader in /lib/ld-musl-*; do
    [ -e "$loader" ] && fail "sentry ships no musl build (Alpine and the like): use a glibc-based image (Debian, Ubuntu, …)"
done

# --- prerequisites ----------------------------------------------------------

has_lib() {
    ldconfig -p 2>/dev/null | grep -q "[[:space:]]$1 "
}

missing=""
command -v curl >/dev/null 2>&1 || missing="$missing curl"
command -v gunzip >/dev/null 2>&1 || missing="$missing gzip"
command -v sha256sum >/dev/null 2>&1 || missing="$missing coreutils"
[ -e /etc/ssl/certs/ca-certificates.crt ] || missing="$missing ca-certificates"
has_lib libstdc++.so.6 || missing="$missing libstdc++6"
has_lib libatomic.so.1 || missing="$missing libatomic1"
if [ -n "$missing" ]; then
    command -v apt-get >/dev/null 2>&1 || fail "missing:$missing (only apt-based images are handled automatically)"
    apt-get update -y
    # shellcheck disable=SC2086 # word-split the package list on purpose
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $missing
    rm -rf /var/lib/apt/lists/*
fi

# --- binary -----------------------------------------------------------------

want=${VERSION#v}
if [ -x "$BAKED/sentry" ] && [ -r "$BAKED/version" ] && [ "$(cat "$BAKED/version")" = "$want" ]; then
    echo "sentry feature: sentry $want already installed"
else
    rm -rf "$BAKED"
    sh ./sentry-update.sh --bake "$VERSION"
fi
install -m 0755 sentry-launcher.sh /usr/local/bin/sentry
# After the bake: a version change empties $BAKED.
install -m 0755 sentry-update.sh "$BAKED/sentry-update"

echo "sentry feature: installed sentry $(cat "$BAKED/version")"
