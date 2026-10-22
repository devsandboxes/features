# zidane

Installs the [zidane](https://github.com/Tahul/zidane) agent TUI
(`/usr/local/bin/zidane`, from the `zidane-tui-linux-<arch>` npm package, no
node needed) and persists its dirs under devsandbox's shared volumes.

devsandbox only: the mounts use `${sharedVolumes}` and `${instance}`.

```yaml
features:
  ghcr.io/devsandboxes/features/zidane:1:
    version: latest
```

## Options

| Option    | Default  | Description                                     |
| --------- | -------- | ----------------------------------------------- |
| `version` | `latest` | zidane-tui version to install (npm version or dist-tag). |

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

Directory mounts only: zidane writes through tmp + rename, which fails with
`EBUSY` over a file mount. `ZIDANE_DAEMON_SOCKET` points into the per-instance
data dir so instances don't share a daemon.

A sandbox `mounts` entry on one of these targets replaces the feature's.

## Platforms

Linux x64 and arm64, glibc only. `curl`, `ca-certificates` and `coreutils` are
installed with apt when missing.
