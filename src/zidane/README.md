# zidane

Installs the [zidane](https://github.com/Tahul/zidane) agent TUI
(`/usr/local/bin/zidane`, from the `zidane-tui-linux-<arch>` npm package, no
node needed) and persists its dirs under devsandbox's shared volumes.
`zidane-update` updates it in every sandbox at once, without a rebuild or a
restart.

devsandbox only: the mounts use `${sharedVolumes}` and `${instance}`.

```yaml
features:
  ghcr.io/devsandboxes/features/zidane:2:
    version: latest
```

## Options

| Option    | Default  | Description                                     |
| --------- | -------- | ----------------------------------------------- |
| `version` | `latest` | zidane-tui version baked into the image (npm version or dist-tag). Seeds the shared copy on first run; after that `zidane-update` picks the version. |

## Updating

```sh
zidane-update          # latest
zidane-update 9.1.17   # a version or dist-tag; also how you roll back
```

`zidane upgrade` (what zidane tells you to run) does the same: the launcher
turns it into `zidane-update` (`--channel <tag>` picks the tag, `--check` is
zidane's own, package-manager flags are ignored). zidane's own upgrade goes
through a package manager (npm by default), which a sandbox usually lacks or
can't write with, and would only update one container.

Run it in any sandbox: it downloads the version into the shared bin dir
(`${sharedVolumes}/zidane-bin/<version>/`) and names it in `current`. Every
sandbox's `zidane` is a launcher that runs the version `current` names, so new
zidane sessions everywhere get it; running ones keep theirs. It keeps the new
and the previous version and removes older ones.

The image keeps its own copy (`/usr/local/lib/zidane/`, the `version` option).
The first `zidane` run seeds the shared dir with it when `current` doesn't
exist yet; after that, rebuilding an image doesn't change which version runs.
Without the shared dir, or when `current` names a version that isn't there,
the image's copy runs.

The shared bin dir is writable by every sandbox sharing it, so any of them
can change the binary all of them run (as with `zidane-skills` and
`zidane-extensions`). On another machine the shared volumes start empty: the
first run there seeds that machine's own copy.

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
| (the binary)           | `zidane-bin`                 | every sandbox    |

Directory mounts only: zidane writes through tmp + rename, which fails with
`EBUSY` over a file mount. `ZIDANE_DAEMON_SOCKET` points into the per-instance
data dir so instances don't share a daemon.

A sandbox `mounts` entry on one of these targets replaces the feature's.

## Platforms

Linux x64 and arm64, glibc only. `curl`, `ca-certificates` and `coreutils` are
installed with apt when missing (`zidane-update` uses them too).
