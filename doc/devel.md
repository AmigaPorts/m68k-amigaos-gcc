# Amiga GCC Development Manual

Working on the toolchain itself. The
[Amiga GCC User's Manual](manual.md) covers using it.

- [Building](build.md): prerequisites, getting the sources, and building the toolchain.
- [Packaging](package.md): archives of the installed toolchain, and the Nix package.
- [Testing](testing.md): the testsuites under [volamos](https://github.com/sidick/volamos), which emulates the AmigaOS APIs, their boards and the results.
- [Changes](changes.md): making, reviewing and merging changes.
- [Continuous integration](ci.md): testing pull requests on GitHub Actions.
- [Release engineering](releng.md): making and rebuilding releases.

## Version management

The **Makefile** provides some targets to switch to an older state
for all modules. To rebuild a release, see [releng.md](releng.md).

### Switching amiga-gcc to a given date
Use make to switch all modules to a given date. You may also add the time
```
make v date=2021-04-01
```
### Switching amiga-gcc back to the branches
Run make to switch all modules back to the branch
```
make v
```
After `make v ref=...`, restore the branches in `.repos` first:
`cp default-repos .repos`, then `make branch` for any module that was not
on its default branch.
### Show the current commit for all submodules
This lists all modules with the last commit. Useful if you switched to a given date to show what's where.
```
make l
```
### Switch a module to a different branch
You can switch modules to different branches. E.g.
```
make branch mod=binutils branch=devel1
```
The default branches and repositories are in the file **default-repos**, the local state is managed in the file **.repos**.
The archives the build downloads, with their checksums, are in the file **default-archives**.
