Part of the [Amiga GCC Development Manual](devel.md).

# Version management

## Notable branches

gcc:
* `amiga16.2`: GCC 16.2, built and tested by CI (default)
* `amiga13.4`: GCC 13.4, no longer supported
* `amiga6`: GCC 6.5.0b, no longer supported

binutils:
* `amiga-2.47`: binutils 2.47 with AmigaOS support and DWARF2 debugging (default)
* `amiga-2.46`: binutils 2.46, no longer supported

## Switching modules

The Makefile has targets that switch all the modules to an older state. To
rebuild a release, see [releng.md](releng.md).

### Switching all modules to a given date

`make v date=` switches every module to its state at a date, or at a date
and time:

```
make v date=2021-04-01
```

### Switching all modules back to their branches

`make v` without arguments switches every module back to its branch:

```
make v
```

A module on another branch, such as that of a pull request, stays there
with a warning; `make branch` moves it. After `make v ref=...`, the branches
in `.repos` must be restored first: `cp default-repos .repos`, then
`make branch` for any module that was not on its default branch.

### Showing the current commit of all modules

`make b` lists each module with its remote, its commit, and the branch or
tag it is on, as in `.manifest`. After a switch to a given date, it shows
the state of each module.

```
make b
```

### Switching a module to a different branch

`make branch` switches one module to another branch:

```
make branch mod=binutils branch=devel1
```

| file | contents |
|---|---|
| `default-repos` | the default branches and repositories |
| `.repos` | the local state |
| `default-archives` | the archives the build downloads, with their checksums |
