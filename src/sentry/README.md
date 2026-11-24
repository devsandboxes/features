# sentry

Installs [Sentry's CLI](https://cli.sentry.dev) (`sentry`) and gives the
sandbox Sentry access without the token ever being in it. devsandbox keeps
sentry up to date in every sandbox.

devsandbox ≥ 0.11.1 only: elsewhere you get a plain sentry with no token.

```yaml
template:
  base:
    features:
      ghcr.io/devsandboxes/features/sentry:1: {}
```

## How it's brokered

The sandbox holds a phantom token (`SENTRY_AUTH_TOKEN`). sentry talks to
sentry.io and its regions (`us.sentry.io`, `de.sentry.io`) through
devsandbox, which swaps the phantom for the real token on each call, after
checking the call against the sandbox's scopes. sentry's telemetry and
update check are off.

Log the token in once, on the host, naming the orgs sandboxes may use
(`--org`, repeatable). With Sentry's own login page (the device flow
sentry's `auth login` uses):

```sh
devsandbox login sentry --feature ghcr.io/devsandboxes/features/sentry:1 --method device --org my-org
```

Or with a user auth token (`sntryu_…`, from Sentry's _Personal Tokens_
page, which the login opens):

```sh
devsandbox login sentry --feature ghcr.io/devsandboxes/features/sentry:1 --method paste --org my-org
```

It shows which account the token belongs to before storing it. When a
feature update changes what the token may be used for, `devsandbox run` asks
you to approve it.

## Orgs

A Sentry token reaches every org its account is in. devsandbox refuses
any call naming an org the credential doesn't list, by slug or id, and
sentry's org list shows only those. A credential listing none has every
org call refused: add `orgs = ["my-org"]` to its entry in devsandbox's
`credentials.toml`, or log in again with `--org`. A sandbox can narrow
the list further:

```yaml
sandbox:
  web:
    access:
      sentry:
        orgs: [my-org]
```

## Scopes

Every scope is allowed unless the sandbox lists the ones it may use:

| Scope              | Used by                                                  |
| ------------------ | -------------------------------------------------------- |
| `org.read`         | orgs, projects, teams, repos, integrations, `auth`       |
| `dsn.read`         | `project view`, DSN lookups                              |
| `issues.read`      | `issue list`/`view`, `event view`                        |
| `events.read`      | `explore`, `trace`, `span`, `log`, `replay`              |
| `issues.write`     | resolving, assigning and linking issues                  |
| `seer`             | `issue explain`/`plan` (starting Seer)                   |
| `releases.read`    | `release list`/`view`                                    |
| `releases.write`   | `release create`/`finalize`/`deploy`/`delete`            |
| `uploads`          | `sourcemap`, `debug-files`, `build upload`               |
| `projects.write`   | `project create` (and its team), code mappings           |
| `alerts.read`      | `alert` and `monitor` reads                              |
| `alerts.write`     | creating, editing and deleting alerts                    |
| `dashboards.read`  | `dashboard list`/`view`                                  |
| `dashboards.write` | creating and editing dashboards                          |

`sentry api` reaches only the routes of those scopes. Never allowed:
deleting organizations, projects, teams or integrations, auth tokens and
client keys, and starting trials.

```yaml
sandbox:
  web:
    access:
      sentry:
        scopes: [org.read, issues.read, events.read]
```

## Updating

devsandbox updates sentry in every sandbox weekly, with no setup and no
rebuild. To change how often (or `never`):

```yaml
updates:
  sentry: 1d
```

To update now, or roll back to a release (with `sentry: never` to keep it):

```sh
devsandbox update sentry
devsandbox update sentry 0.49.0
```

Sandboxes can't change their sentry: the update is mounted read-only, and
`sentry cli upgrade` points to `devsandbox update sentry`.

## Options

| Option    | Default  | Description                                        |
| --------- | -------- | -------------------------------------------------- |
| `version` | `latest` | sentry version baked into the image (a release like `0.50.0`, or `latest`). |

## Platforms

Linux x86_64 and aarch64 with glibc 2.28 or later; musl images (Alpine) are
refused. `curl`, `gzip`, `ca-certificates`, `coreutils`, `libstdc++6` and
`libatomic1` are installed with apt when missing.
