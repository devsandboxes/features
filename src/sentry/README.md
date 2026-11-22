# sentry

Installs [sentry-cli](https://github.com/getsentry/sentry-cli) (Sentry's static
Linux binary, checked against the sha256 its release registry lists) and claims
a devsandbox `sentry` credential, so sentry-cli works in the sandbox without
the token ever being in it. devsandbox keeps it updated in every sandbox.

devsandbox only: the claim is read by devsandbox (`customizations.devsandbox`);
elsewhere you get a plain sentry-cli with no token.

```yaml
features:
  ghcr.io/devsandboxes/features/sentry:1:
    version: latest
```

## How it's brokered

The sandbox gets a phantom token (`SENTRY_AUTH_TOKEN`, `~/.sentryclirc`) and
`SENTRY_URL` pointing at a loopback port. sentry-cli's calls go through that
port to devsandbox's credential broker on the host, which checks each call
against the claim's scopes, swaps the phantom for the real token and calls
Sentry. The upload URLs Sentry answers with come back pointed at the loopback
too, so source-map and debug-file uploads take the same path. Every call is a
line in the host's `access.log`.

Before the first sandbox with this feature, store the token on the host (the
credential's name is yours; `--profile` limits it to sandboxes of that
profile):

```sh
devsandbox login sentry-work --feature ghcr.io/devsandboxes/features/sentry:1 --profile work
```

It shows the claim, asks you to approve it, and reads the token (pasted, or
piped with `--yes`). Without `--profile` it serves every profile. When a
later version of this feature changes the claim, `devsandbox run` refuses it
until you approve the change with `devsandbox access approve sentry-work`.

## The token

An internal integration's token: in Sentry, Settings > Developer Settings >
Custom Integrations > Create New Integration > Internal Integration, then its
token. It's bound to one organization; give it these permissions:

| Permission    | Level | For                                              |
| ------------- | ----- | ------------------------------------------------ |
| Release       | Admin | `releases`, source-map and debug-file uploads    |
| Project       | Write | debug-file uploads                               |
| Issue & Event | Read  | reading issues and events                        |
| Organization  | Read  | the organization and project lookups             |

Narrow what a sandbox may do with `access.sentry` in its devsandbox config
(`scopes`: `org.read`, `releases.read`, `releases.write`, `uploads`,
`issues.read`). Token-minting routes (org auth tokens, integration tokens,
project client keys) are refused whatever the grant.

## Updating

devsandbox updates sentry-cli in every sandbox weekly, with no setup and no
rebuild. To change how often (or `never`):

```yaml
updates:
  sentry: 1d
```

To update now, or roll back to a release (with `sentry: never` to keep it):

```sh
devsandbox update sentry
devsandbox update sentry 3.8.1
```

Sandboxes can't change their sentry-cli: the update is mounted read-only.

## Options

| Option    | Default  | Description                                        |
| --------- | -------- | -------------------------------------------------- |
| `version` | `latest` | sentry-cli version baked into the image (a release like `3.8.2`, or `latest`). |

`SENTRY_DISABLE_UPDATE_CHECK` is set: sentry-cli changes with devsandbox's
update, not with `sentry-cli update`.

## Platforms

Linux x86_64, aarch64, armv7 and i686 (the binary is static, so musl images
work too). `curl`, `ca-certificates` and `coreutils` are installed with apt or
apk when missing.
