# Version management

Part of the [Amiga GCC Development Manual](devel.md).

## Notable branches

gcc:
* `amiga6`: the legacy GCC 6.5.0b
* `amiga13.4`: GCC 13.4, unsupported
* `amiga16.2`: GCC 16.2, the default branch, built and tested by CI

binutils:
* `amiga-2.46`: binutils 2.46 with amigaos support and dwarf2 debugging, the default
* `amiga-2.47`: binutils 2.47, the next default, with no known regressions

## Switching modules

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
