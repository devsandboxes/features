# devsandboxes features

[devcontainer features](https://containers.dev/implementors/features/) for
[devsandbox](https://github.com/devsandboxes/devsandboxes), published to
`ghcr.io/devsandboxes/features/<id>`.

They target devsandbox, not the stock devcontainer CLI: mounts use
devsandbox's `${sharedVolumes}` and `${instance}` variables.

| Feature                    | What it does                                          |
| -------------------------- | ----------------------------------------------------- |
| [`zidane`](src/zidane)     | zidane agent TUI, with persisted config, state, data |

```yaml
sandbox:
  web:
    features:
      ghcr.io/devsandboxes/features/zidane:1: {}
```

## Layout

```
src/<id>/devcontainer-feature.json   metadata, options, mounts
src/<id>/install.sh                  runs as root at image build
src/<id>/README.md
test/<id>/test.sh                    runs as the remote user after install.sh
scripts/test-feature.sh              runs one feature's install + test in an image
```

## Adding a feature

1. `src/<id>/` with `devcontainer-feature.json` (`id` = folder name,
   `version` 1.0.0), `install.sh` and a README.
2. `test/<id>/test.sh`.
3. Add it to the table above.

CI (`test.yaml`) picks up every folder in `src/`: shellcheck, schema
validation, then `scripts/test-feature.sh` on each base image as root and as a
non-root user.

## Testing locally

```sh
scripts/test-feature.sh zidane debian:bookworm-slim dev
CONTAINER_RUNTIME=podman scripts/test-feature.sh zidane ubuntu:24.04
```

Needs `jq` and a container runtime.

## Releasing

Bump `version` in the feature's `devcontainer-feature.json` and merge to
`main`; `release.yaml` publishes versions not yet in the registry (as `1`,
`1.0` and `1.0.0`). devsandbox caches a fetched feature per tag: clear
`~/.cache/devsandbox/features/ghcr.io/devsandboxes/features/<id>` to pick up a
new release under the same tag.
