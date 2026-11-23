# gh

Installs the [GitHub CLI](https://github.com/cli/cli) and gives the sandbox
GitHub access without the token ever being in it, limited to the sandbox's
own repos. devsandbox keeps gh up to date in every sandbox.

devsandbox ≥ 0.11 only: elsewhere you get a plain gh with no token. Use it instead
of `ghcr.io/devcontainers/features/github-cli`, not beside it.

```yaml
template:
  base:
    features:
      ghcr.io/devsandboxes/features/gh:1: {}
```

## How it's brokered

The sandbox holds a phantom token. devsandbox, on the host, swaps it for the
real one on each call, after checking the call against the sandbox's scopes
and repo fence. gh's telemetry is off.

Log the token in once, on the host:

```sh
devsandbox login github --feature ghcr.io/devsandboxes/features/gh:1
```

It shows which account the token belongs to before storing it. When a
feature update changes what the token may be used for, `devsandbox run` asks
you to approve it.

## The token

A **fine-grained personal access token**, the usual pick. The login opens
GitHub's token page with the permissions below filled in; select only the
repos sandboxes may touch:

```sh
devsandbox login github --feature ghcr.io/devsandboxes/features/gh:1 \
  --method paste --owner acme   # --owner is optional
```

A **GitHub App user token**, for repos spread over several owners. Needs a
GitHub App of your own, with device flow enabled and the permissions below:

```sh
devsandbox login github --feature ghcr.io/devsandboxes/features/gh:1 \
  --method device --client-id <your app's client id>
```

**gh's own login**, only when your org allows neither of the above. It
reaches every repo your account can:

```sh
devsandbox login github --feature ghcr.io/devsandboxes/features/gh:1 --broad
```

Classic tokens (`ghp_…`) are refused.

## Permissions

What the fine-grained token (or your GitHub App) needs, and which gh
commands use each. devsandbox's login page fills them in.

| Permission      | Level | Used by                                       |
| --------------- | ----- | --------------------------------------------- |
| Contents        | Write | `git clone`/`push`, `gh release`, `gh pr merge` |
| Pull requests   | Write | `gh pr`                                       |
| Issues          | Write | `gh issue`, `gh label`                        |
| Actions         | Write | `gh run`, `gh workflow`, `gh cache`           |
| Checks          | Read  | `gh pr checks`                                |
| Commit statuses | Read  | `gh pr checks`                                |
| Discussions     | Write | discussions (optional)                        |
| Metadata        | Read  | required by GitHub                            |

To give one sandbox less, list what it may do in `access.github.scopes`
(e.g. `[repo.read, pr.write]`).

## The repo fence

- The fence holds the repos of the sandbox's folders, plus any you list in
  `access.github.repos`.

- Outside it, reads go to GitHub without a token (public repos work,
  private ones don't) and writes are refused.

- GraphQL reads (much of `gh pr list`, `gh repo view`) still pass under the
  token's own reach, so keep the token narrow.

- Never allowed: deploy, ssh and GPG keys, webhooks, collaborators, and
  writing Actions secrets.

```yaml
sandbox:
  web:
    access:
      github:
        repos: [acme/shared-lib]
        scopes: [repo.read, pr.write, git.push]
```

## Updating

devsandbox updates gh in every sandbox weekly, with no setup and no rebuild.
To change how often (or `never`):

```yaml
updates:
  gh: 1d
```

To update now, or roll back to a release (with `gh: never` to keep it):

```sh
devsandbox update gh
devsandbox update gh 2.104.0
```

Sandboxes can't change their gh: the update is mounted read-only.

## Options

| Option    | Default  | Description                                        |
| --------- | -------- | -------------------------------------------------- |
| `version` | `latest` | gh version baked into the image (a release like `2.105.0`, or `latest`). |

## Platforms

Linux amd64, arm64, armv6 and 386 (the binary is static, so musl images work
too). `curl`, `tar`, `ca-certificates` and `coreutils` are installed with apt
or apk when missing.
