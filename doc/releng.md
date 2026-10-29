Part of the [Amiga GCC Development Manual](devel.md).

# Release engineering

A release is a tag in this repository, `v<version>` (`v16.2-rc19`), plus a
tag in every module of `default-repos`, `m68k-amigaos-gcc-v<version>`. The
module tags record exactly what the release was built from, so it can be
rebuilt later.

## Making a release

1. Write the release notes in a file: a subject line, a blank line, then
   the notes in Markdown. They become the tag message, and the notes after
   the subject become the GitHub release's text. Following the previous
   release's layout keeps them consistent.
2. See what would be tagged:
   ```
   make release-tag TAG=v16.2-rc19 NOTES=notes.md
   ```
3. Tag and push:
   ```
   make release-tag TAG=v16.2-rc19 NOTES=notes.md CONFIRM=yes
   ```

`release-tag` tags each module at the head of its `default-repos` branch on
the remote, and this repository at the head of `master`. It pushes over ssh,
so it needs push access to every module repository. This repository's tag
goes last, because pushing it starts the release. A rerun after a failure
skips what is already tagged at the right commit.

It tags the remote branch heads, not the local checkouts. So test what is
on the branches, and do not merge anything between the test and the
tagging.

## What CI does with the tag

Pushing the tag starts the release build, which tests and publishes it:
see [ci.md](ci.md#releases).

## Rebuilding a release

Check out the release here, then every module at its tag:
```
git checkout v16.2-rc17
make v ref=m68k-amigaos-gcc-v16.2-rc17
```
This also pins `.repos` to the tag, so `make update` clones any module
not checked out yet at the same tag. A module without the tag is an
error. Any tag, branch or commit that exists in every module works.

Each package also carries a `.manifest` with the commit of every module it
was built from.
