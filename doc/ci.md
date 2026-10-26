# Continuous integration

Part of the [development notes](devel.md).

The toolchain is built and tested by GitHub Actions in this repository:
`.github/workflows/toolchain.yml` does the work, `ci-command.yml` handles
`/ci` comments and `release.yml` builds releases. Nothing builds on a plain
push. A build starts in one of four ways:

| trigger | what it builds |
|---|---|
| a `/ci` comment on a pull request | the pull request, on the platforms and make targets the comment names |
| a `ci-*` label on a pull request | the pull request, as the label says |
| "Run workflow" (a dispatch) | any branch, with the inputs given |
| pushing a `v*` tag | a release |

Pull requests are built as GitHub merges them into their base branch
(`refs/pull/N/merge`), so they are tested against the current base rather
than the base they were branched from. GitHub refreshes that merge within
seconds of a push. A pull request with conflicts has no merge to build:
rebase it first.

The Jenkins check on pull requests is separate: it builds the Docker images
on jenkins.amigadev.com, including the AmigaOS-native one, from the
`Dockerfile*` files.

## /ci comments

```
/ci <platform> [<module>=<branch>...] [make <target>... [VAR=value]...]
```

A comment that starts with `/ci` builds the pull request. Each `/ci` line
is a separate job, and they all run in parallel. For example:

```
/ci linux
/ci macos
/ci linux-arm make check-c board=volamos-newlib
/ci linux-arm make all all-sdk libpng check-c++
/ci linux binutils=amiga-2.47 make check-c
```

A `<module>=<branch>` word builds that module, named as in `default-repos`,
from another branch of its repository.

The words after `make` go to make as they are. Without `make`, the platform
builds the whole distribution and runs the fast tests:

```
make all all-sdk vbcc vlink zlib libpng check-gdb-libpython package \
  check-multilib check-binutils check-gcc-amigaos check-libnix check-libpthread
```

`/ci` alone lists the platforms.

| platform | runner | without `make` |
|---|---|---|
| `linux` | x86-64 Ubuntu | the make targets above |
| `linux-x86` | x86-64 Ubuntu | the same as `linux`, which will become `linux-arm` |
| `linux-arm` | arm64 Ubuntu | same, but faster |
| `linux-gcc6` | x86-64 Ubuntu | same, with gcc branch `amiga6` |
| `macos` | macOS 15 | same |
| `amigaos` | x86-64 Ubuntu | the Linux build, then the AmigaOS-hosted toolchain bootstrapped with it |
| `mingw` | MinGW cross container | the Windows-hosted toolchain and its installer |

`make` works on the first four. `amigaos` and `mingw` build compilers that
cannot run on the runner, so a `make` there fails.

A job runs its targets one after the other, because the gcc testsuites
share `gcc.sum`, and stops at the first that fails. A check target builds
what it tests when it is missing. Any `VAR=value` word, such as `board=`, is
passed to every target.

- **Results.** The comment gets a rocket and a reply with the run's link.
  The run shows in the pull request's checks as a commit status named after
  the comment's `/ci` lines: pending, then success when every job passed.
  Posting the same comment again rebuilds and updates that line.
- **Who.** Only owners, members and collaborators can start a build.
- **Which workflows.** `/ci` always runs the workflows on `master`, as
  GitHub does for every comment-triggered workflow. A pull request that
  changes the workflows themselves is not tested by `/ci`: use a label or
  a dispatch for it.
- **The parser** is `.github/scripts/ci-command.py`. To see what a comment
  would do: `echo '/ci linux-arm make check-c' | .github/scripts/ci-command.py --dry-run`.

## Labels

A `ci-*` label on a pull request builds it with the pull request's own
workflows, so it is the way to test a change to them. Remove and re-add a
label to rebuild after a push. The platform labels are the `/ci` platforms
above (`ci-linux`, `ci-linux-arm`, ...), without `make`. Each `ci-check-*`
label runs one testsuite on `linux-arm`:

| label | same as |
|---|---|
| `ci-check-c` | `/ci linux-arm make check-c` |
| `ci-check-c-fpu` | `/ci linux-arm make check-c board=volamos-fpu` |
| `ci-check-c-ixemul` | `/ci linux-arm make check-c board=volamos-ixemul` |
| `ci-check-c-newlib` | `/ci linux-arm make check-c board=volamos-newlib` |
| `ci-check-c++` | `/ci linux-arm make check-c++` |
| `ci-check-c++-baserel32` | `/ci linux-arm make check-c++ board=volamos-020-baserel32` |
| `ci-check-c++-newlib` | `/ci linux-arm make check-c++ board=volamos-newlib` |
| `ci-check-newlib` | `/ci linux-arm make check-newlib` |

## Dispatch

"Run workflow" in the Actions tab, on the "Bootstrap toolchain" workflow,
builds any branch of this repository with its own workflows. From the
command line:

```
gh workflow run toolchain.yml --ref my-branch \
  -f make_args='check-c board=volamos-fpu' \
  -f runner=ubuntu-24.04-arm \
  -f build_hosted=false
```

The inputs include `gcc_version` (the gcc branch `amiga<version>`),
`make_args`, `runner`, `repos` (module overrides, below), `tag`,
`build_hosted` and `simulator` (`volamos`, or `vamos` for comparison).
Dispatched runs are not attached to a pull request: find them in the
Actions tab, filtered by branch.

## Module repositories

A module repository (AmigaPorts/gcc and AmigaPorts/libnix today) has two
small workflows that call this repository's: `ci-label.yml` for the labels
and `ci-command.yml` for `/ci` comments. Labels and `/ci` comments on its
pull requests build this repository's `master` with the module's pull
request, as merged into its base, swapped in for the module. That swap is the `repos` input,
`module=URL#ref`. For example, `gcc=https://github.com/AmigaPorts/gcc.git#refs/pull/131/merge`.
A gcc pull request builds the toolchain for its own branch: `amiga6` builds
gcc 6, `amiga16.2` builds 16.2.

## Results

The `/ci make` and `ci-check-*` runs use the same make targets and boards
as a local test, so a failure reproduces with the same command, for example
`make check-c board=volamos-fpu`: see [testing.md](testing.md).

A run's summary page shows the module revisions it built, the commit, and
each testsuite's summary. The `testsuite-results-*` artifact has the `.sum`
and `.log` files and the `*.summary.txt` of every check target that ran. A
failed build uploads `build-logs-*`, with the configure logs. A full build
also uploads the toolchain tarball.

## Releases

Pushing a `v*` tag runs `release.yml`. It builds every module at the
`m68k-amigaos-gcc-<tag>` tag that `make release-tag` made in it, and fails
if a module lacks that tag. It runs the C testsuite on Linux as a release
gate, builds the macOS, AmigaOS and Windows packages, and publishes them as
a GitHub release, with the tag message as the release notes. Making a
release is in [releng.md](releng.md).
