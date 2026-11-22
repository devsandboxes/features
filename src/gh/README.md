# gh

Installs the [GitHub CLI](https://github.com/cli/cli) (`gh`, GitHub's Linux
release binary, checked against the release's `gh_<version>_checksums.txt`)
and claims a devsandbox `github` credential, so gh, git and anything else
talking to GitHub work in the sandbox without the token ever being in it, and
only on the sandbox's own repos.

devsandbox only: the claim is read by devsandbox (`customizations.devsandbox`);
elsewhere you get a plain gh with no token. Use it instead of
`ghcr.io/devcontainers/features/github-cli`, not beside it: two gh binaries
race on `PATH`.

```toml
[template.base]
features = { "ghcr.io/devsandboxes/features/gh:1" = {} }
```

## How it's brokered

The sandbox gets a phantom token (`GH_TOKEN`, `~/.config/gh/hosts.yml`).
Calls to `api.github.com` and `uploads.github.com` go through the sandbox's
proxy to devsandbox's credential broker on the host, which checks each one
against the claim's scopes and the sandbox's repo fence, swaps the phantom
for the real token and calls GitHub. git to `github.com` takes the same path
on a proxy port of its own, with devsandbox's credential helper; ssh remotes
(`git@github.com:`) are rewritten to https. Every call is a line in the
host's `access.log`. `GH_TELEMETRY=false` is set: gh would otherwise post
command names and flags to GitHub.

Before the first sandbox with this feature, store the token on the host (the
credential's name is yours; `--profile` limits it to sandboxes of that
profile):

```sh
devsandbox login github --feature ghcr.io/devsandboxes/features/gh:1 --profile work
```

It shows the claim, asks you to approve it, and reads the token (pasted, or
piped with `--yes`). When a later version of this feature changes the claim,
`devsandbox run` refuses it until you approve the change with
`devsandbox access approve github`.

## The token

- A **fine-grained personal access token** (`github_pat_…`): Settings >
  Developer settings > Personal access tokens > Fine-grained tokens. Select
  only the repos sandboxes may touch (one owner per token) and the
  permissions below. An expiry header GitHub sends back is recorded, and
  `devsandbox access ls` warns before it.
- A **GitHub App user token** (`ghu_…`), for repos spanning owners, pasted
  the same way. Logging one in with the app's device flow
  (`--method device --client-id <your app>`) isn't offered by this version of
  the claim yet.

Classic tokens and gh's own OAuth token (`ghp_`, `gho_`) reach every repo you
can, and are refused.

| Permission    | Level | For                                              |
| ------------- | ----- | ------------------------------------------------ |
| Contents      | Write | clone, push, releases, branch updates            |
| Pull requests | Write | `gh pr`                                          |
| Issues        | Write | `gh issue`, labels, comments                     |
| Actions       | Write | `gh run`, `gh workflow`, `gh cache`              |
| Discussions   | Write | discussions (optional)                           |
| Metadata      | Read  | required by GitHub                               |

Narrow what a sandbox may do with `access.github.scopes` in its devsandbox
config: `api.read`, `user.read`, `search.read`, `repo.read`, `actions.read`,
`actions.write`, `pr.write`, `pr.merge`, `issues.write`, `discussions.write`,
`git.push`, `releases.write`.

## The repo fence

A sandbox's credential reaches the repos its folders' remotes named when each
folder was first run, plus `access.github.repos`:

```toml
[sandbox.web.access.github]
repos = ["acme/shared-lib"]
scopes = ["repo.read", "pr.write", "git.push"]
```

Outside the fence, calls go to GitHub with no token at all: public repos
read over REST and git as they would anonymously (`gh api`, `gh release
download`, `gh search`, clones of public dependencies), private ones answer
404, and every write is refused with a message naming `access.github.repos`.
GraphQL reads (most of `gh repo view`, `gh pr list`, `gh issue list`, `gh
auth status`) pass under the token's own reach, fence or not: keep the token
down to the repos sandboxes may touch. GraphQL writes (`gh pr create`, `gh
issue comment`, `gh pr merge`, …) are checked against the fence by every id
they name.

Never allowed, whatever the config: deploy keys, ssh and GPG keys, webhooks,
adding collaborators or org members, runner registration tokens, writing
Actions secrets, and token-minting routes. Not covered by this version's
scope table, so refused: creating, renaming, archiving, deleting or editing
repos' settings (`gh repo create|edit|rename|archive|delete`), Actions
variables and secrets, gists writes, Projects, codespaces, and `gh repo fork`
(its target organization isn't attributed yet).

## Updating gh without a rebuild

The image's gh is the `version` option's. To update every sandbox at once,
mount a shared bin dir read-only and run `gh-update` on the host against it:

```toml
[template.base]
mounts = [{ type = "bind", source = "${sharedVolumes}/gh-bin", target = "/var/lib/devsandbox/gh/bin", readonly = true }]
```

```sh
curl -fsSLo gh-update.sh https://raw.githubusercontent.com/devsandboxes/features/main/src/gh/gh-update.sh
sh gh-update.sh ~/.devsandboxes/shared-volumes/gh-bin          # latest
sh gh-update.sh ~/.devsandboxes/shared-volumes/gh-bin 2.104.0  # a release, or a rollback
```

It downloads the release for the host's arch (`GH_UPDATE_ARCH=amd64|arm64`
for another), checks it against the release's checksums, puts it in
`<dir>/<version>/` and makes it current; the launcher (`/usr/local/bin/gh`)
runs it from the next call. A dir the sandbox can write is ignored (the
launcher runs the image's gh and says so). The claim stays this feature
version's: a route a newer gh calls that the scope table doesn't cover is
refused until a feature release covers it.

## Options

| Option    | Default  | Description                                        |
| --------- | -------- | -------------------------------------------------- |
| `version` | `latest` | gh version baked into the image (a release like `2.105.0`, or `latest`). |

## Platforms

Linux amd64, arm64, armv6 and 386 (the binary is static, so musl images work
too). `curl`, `tar`, `ca-certificates` and `coreutils` are installed with apt
or apk when missing.
