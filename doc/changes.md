# Changes

Part of the [development guide](devel.md).

How to make a change to the toolchain, get it reviewed and merge it, in
this repository or in one of its modules.

## Making a change

The toolchain is spread over several repositories:
- **this repository**: the build (`Makefile`, `scripts/`), CI and these
  notes;
- **the modules**: the compiler (`gcc`), the assembler, linker and debugger
  (`binutils-gdb`), the runtime libraries (`libnix`, `newlib`...) and various
  tools and SDKs, each in its own AmigaPorts repository and branch,
  as `default-repos` lists them.

Fork the repository the change belongs in, push a branch, and open a pull
request (PR) against the branch `default-repos` names. Keep each commit to one
logical change, described as in [Commit messages](#commit-messages).

`gcc` has a second maintained branch, `amiga6` (gcc 6). A change to how a
runtime is installed or linked (start files, link specs, multilibs) needs a
matching change there.

A change that spans repositories goes in two steps: first the module's PR,
then the one here that depends on it. Link them with full
references (`AmigaPorts/gcc#131`), which GitHub turns into links in both
directions.

Test the change before asking for a review: comment `/ci` on the PR,
or label it (see [ci.md](ci.md)). The module repositories with CI (`gcc` today)
build the whole toolchain with the pull request swapped in.

## Commit messages

A commit message is read by someone chasing a bug years later, possibly
without the full context of the pull request at hand.

It should tell in a few lines **what** changed and **why** it changed.
The full analysis, measurements and alternatives go in the PR.

- **Subject**: one line under 72 columns, saying what the commit does,
  prefixed with the area it touches, without a full stop at the end. For
  example: `m68k: end doloop loops with the stock dbne_hi/dbne_si insns`,
  or `fstat: set errno on a bad fd (EBADF) and a null buffer (EFAULT)`.
- **Body**: after a blank line, why the change is needed (the symptom it
  fixes, or what it makes possible) and anything surprising about how.
- **References**: the issue or pull request it fixes, in full
  (`AmigaPorts/m68k-amigaos-gcc#215`), and the upstream commit or bug for
  a backport.
- **One logical change per commit**: no fix mixed with reformatting or an
  unrelated cleanup, so that a reviewer, a bisect or `git revert` can take
  one without the other.

Subjects like "fix", "update", "more fixes", "WIP" or "review comments" say
nothing about the change.

Fold fixups into the commit they fix before merging, rather than keeping
"fix typo in previous commit". To push fixes, use `git commit --amend`
and `git push --force-with-lease` to achieve this.

## Code reviews

### Requesting a code review

Say in the pull request's description what the change does and why, what
it affects, and how it was tested, with links to the CI runs. Then request
a review from someone who knows that part of the toolchain, in the
"Reviewers" box. Open a draft pull request for work in progress, and mark
it ready when it is.

Answer every comment, either with a change or with the reason not to make
one. Push fixes as new commits during the review, or fold them into the
commits they fix when that keeps the history clearer; say which in a
reply.

### Reviewing a pull request

A review checks that the change:
- does what its description says, and nothing unrelated;
- does not break other targets, runtimes or the gcc 6 branch;
- comes with a test when it fixes a bug or adds a feature, and has passed
  CI;
- reads like the code around it, with commit messages that explain it.

Mark minor points as "Nit": the author may take them or leave them.
Approve when only nits are left. Use "Request changes" only for a problem
that has to be fixed before merging.

### Pre-approved changes

These can be merged before approval, and reviewed at any time:
- trivial, cosmetic or non-functional changes;
- documentation-only changes;
- CI-only changes;
- fixes forward for a broken build;
- new tests, testsuites or make targets added for experiments;
- reverts of changes that broke the build, a test, or a feature without
  test coverage;
- reverts of any change that was merged before approval and that a
  reviewer objects to.

## Merging

The author merges, once the pull request is approved (or pre-approved) and
CI is green. Merge a module's pull request before the one here that
depends on it.

Use "Rebase and merge" to keep the commits as they are, one per logical
change. Use "Squash and merge" for a pull request whose commits are fixups
of each other. Delete the branch after merging.
