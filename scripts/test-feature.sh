#!/bin/sh
# Usage: scripts/test-feature.sh <feature> <image> [remote user]
#
# Runs src/<feature>/install.sh in <image> the way devsandbox does (root, with
# _REMOTE_USER / _REMOTE_USER_HOME and option env vars set from the defaults),
# then test/<feature>/test.sh as the remote user, with the feature's
# containerEnv. Not `devcontainer features test`: the stock CLI can't apply
# devsandbox mounts (${sharedVolumes}, ${instance}).
#
# A non-root user that doesn't exist in the image is created first. The runtime
# is $CONTAINER_RUNTIME (default docker). Needs jq on the host.
set -eu

feature=${1:?feature}
image=${2:?image}
user=${3:-root}
runtime=${CONTAINER_RUNTIME:-docker}
root=$(cd "$(dirname "$0")/.." && pwd)
json="$root/src/$feature/devcontainer-feature.json"

[ -f "$json" ] || { echo "no feature at src/$feature" >&2; exit 1; }

# Option defaults as upper-cased env vars, like the devcontainer spec.
env_args=$(jq -r '.options // {} | to_entries[]
    | "-e \(.key | ascii_upcase | gsub("[^A-Z0-9_]"; "_"))=\(.value.default)"' "$json")
container_env=$(jq -r '.containerEnv // {} | to_entries[] | "export \(.key)=\(.value | @sh)"' "$json")

script=$(cat <<EOF
set -eu
if [ "$user" != root ] && ! id "$user" >/dev/null 2>&1; then
    useradd -m -s /bin/sh "$user"
fi
home=\$(getent passwd "$user" | cut -d: -f6)
cp -r /feature /tmp/feature
cd /tmp/feature
_REMOTE_USER="$user" _REMOTE_USER_HOME="\$home" _CONTAINER_USER=root _CONTAINER_USER_HOME=/root sh ./install.sh
cat > /tmp/test-env.sh <<'ENV'
$container_env
ENV
su "$user" -s /bin/sh -c "HOME=\$home; export HOME; . /tmp/test-env.sh; sh /test/test.sh"
EOF
)

# shellcheck disable=SC2086 # env_args is a list of `-e K=V` words
"$runtime" run --rm \
    -v "$root/src/$feature:/feature:ro" \
    -v "$root/test/$feature:/test:ro" \
    $env_args \
    "$image" sh -c "$script"
