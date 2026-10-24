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

A comment whose first line starts with `/ci` builds the pull request:

```
/ci linux macos
/ci linux-arm make check-c board=volamos-newlib
/ci make check-c++ board=volamos-020-baserel32
/ci make check-shell
```

The words before `make` name platforms. The words after it go to make as
they are, in place of the default tests. Without a platform, `make` runs on
`linux-arm`. `/ci` alone lists the platforms.

| platform | runner | default build and tests |
|---|---|---|
| `linux` | x86-64 Ubuntu | `make all`, `all-sdk`, vbcc, zlib/libpng, the release tarball; then `check-multilib`, `check-binutils`, `check-gcc-amigaos`, `check-libnix`, `check-libpthread` |
| `linux-arm` | arm64 Ubuntu | same, but faster |
| `linux-gcc6` | x86-64 Ubuntu | same, with gcc branch `amiga6` |
| `macos` | macOS 15 | same |
| `amigaos` | x86-64 Ubuntu | the Linux build, then the AmigaOS-hosted toolchain bootstrapped with it |
| `mingw` | MinGW cross container | the Windows-hosted toolchain and its installer |

`make` works on the first four. `amigaos` and `mingw` build compilers that
cannot run on the runner, so a `make` there fails.

With `make`, nothing is built up front: each check target builds what it
tests when it is missing. The targets run one after the other in a single
job, because the gcc testsuites share `gcc.sum`. Any `VAR=value` word, such
as `board=`, is passed to every target.

- **Results.** The comment gets a rocket and a reply with the run's link.
  The run shows in the pull request's checks as a commit status named after
  the command, for example `/ci linux-arm make check-c`: pending, then
  success or failure. Posting the same command again rebuilds and updates
  that line.
- **In parallel.** One comment is one run, and only its first line counts.
  To run `check-c` and `check-c++` side by side, post two comments.
  Several platforms in one comment build in parallel, with the same make
  arguments.
- **Who.** Only owners, members and collaborators can start a build.
- **Which workflows.** `/ci` always runs the workflows on `master`, as
  GitHub does for every comment-triggered workflow. A pull request that
  changes the workflows themselves is not tested by `/ci`: use a label or
  a dispatch for it.

## Labels

A `ci-*` label on a pull request builds it with the pull request's own
workflows, so it is the way to test a change to them. Remove and re-add a
label to rebuild after a push. The platform labels are the `/ci` platforms
above (`ci-linux`, `ci-linux-arm`, ...). The `ci-check-*` labels build only
what the tests need (`make min`) on `linux-arm`, and run a testsuite after
the default tests. Their board applies to `check-gcc-amigaos` too:

| label | runs | board |
|---|---|---|
| `ci-check-c` | `make check-c` | `volamos` |
| `ci-check-c-fpu` | `make check-c` | `volamos-fpu` |
| `ci-check-c-ixemul` | `make check-c` | `volamos-ixemul` |
| `ci-check-c-newlib` | `make check-c` | `volamos-newlib` |
| `ci-check-c++` | `make check-c++` | `volamos` |
| `ci-check-c++-newlib` | `make check-c++` | `volamos-newlib` |
| `ci-check-newlib` | `make check-newlib` | `volamos-newlib`, `volamos-newlib-fpu` |

Each of these is `/ci linux-arm make <target> board=<board>` too.

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

A module repository (AmigaPorts/gcc today) has a small
`.github/workflows/toolchain-ci.yml` that calls this repository's
workflows. Labels and `/ci` comments on its pull requests build this
repository's `master` with the module's pull request, as merged into its
base, swapped in for the module. That swap is the `repos` input,
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
