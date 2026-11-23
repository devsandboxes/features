# zidane

Installs the [zidane](https://github.com/Tahul/zidane) agent TUI
(`/usr/local/bin/zidane`, from the `zidane-tui-linux-<arch>` npm package, no
node needed) and persists its dirs under devsandbox's shared volumes.
devsandbox keeps it updated in every sandbox, without a rebuild or a restart.

devsandbox ≥ 0.11 only: the mounts use `${sharedVolumes}` and `${instance}`.

```yaml
features:
  ghcr.io/devsandboxes/features/zidane:2:
    version: latest
```

## Options

| Option    | Default  | Description                                     |
| --------- | -------- | ----------------------------------------------- |
| `version` | `latest` | zidane-tui version baked into the image (npm version or dist-tag). The version devsandbox's `zidane` update made current runs instead. |

## Updating

devsandbox updates zidane in every sandbox weekly, with no setup and no
rebuild. New zidane sessions get the update; running ones keep theirs. To
change how often (or `never`):

```yaml
updates:
  zidane: 1d
```

To update now, or roll back to a version (with `zidane: never` to keep it):

```sh
devsandbox update zidane
devsandbox update zidane 9.1.17   # an npm version or dist-tag
```

Sandboxes can't change their zidane: the update is mounted read-only, and
`zidane upgrade` in a sandbox points at `devsandbox update zidane`
(`zidane upgrade --check` is zidane's own). The skills and extensions dirs
stay shared and writable by every sandbox: they're config, not binaries.

## Storage

Mounted at fixed paths under `/var/lib/devsandbox/zidane/`, symlinked from the
remote user's home (feature mounts can't depend on the user):

| In the home            | Host (`${sharedVolumes}/…`)  | Shared by        |
| ---------------------- | ---------------------------- | ---------------- |
| `~/.config/zidane`     | `zidane-config`              | every sandbox    |
| `~/.local/share/zidane`| `zidane/${instance}`         | this instance    |
| `~/.local/state/zidane`| `zidane-state`               | every sandbox    |
| `~/.cache/zidane`      | `zidane-cache/${instance}`   | this instance    |
| `~/.agents/skills`     | `zidane-skills`              | every sandbox    |
| `~/.agents/extensions` | `zidane-extensions`          | every sandbox    |
| (the binary)           | `zidane-bin`, read-only      | every sandbox    |

Directory mounts only: zidane writes through tmp + rename, which fails with
`EBUSY` over a file mount. `ZIDANE_DAEMON_SOCKET` points into the per-instance
data dir so instances don't share a daemon.

A sandbox `mounts` entry on one of these targets replaces the feature's.

## Platforms

Linux x64 and arm64, glibc only. `curl`, `ca-certificates` and `coreutils` are
installed with apt when missing (the update uses them too).
