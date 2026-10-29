# Testing

Part of the [Amiga GCC Development Manual](devel.md).

The testsuites are ordinary make targets. They run the compiled tests under
[volamos](https://github.com/sidick/volamos), which emulates the AmigaOS
APIs, so no Amiga is needed. CI runs the same targets (see [ci.md](ci.md)),
so a failure in CI can be reproduced with the same command here.

## Setup

Install dejagnu: `sudo apt install dejagnu` on Debian and Ubuntu,
`sudo dnf install dejagnu` on Fedora, `brew install dejagnu` on macOS.
volamos itself needs nothing: a target that needs it downloads its release
binary into `$PREFIX/bin` first (`make volamos` does just that).

## Running

```shell
make -j$(nproc) check                                  # the usual set, see below
make -j$(nproc) check-c board=volamos/-mcrt=newlib     # one testsuite on one board
make -j$(nproc) check-c++                              # the g++ testsuite (slow)
```

The build tree remembers its `PREFIX`, so no `PREFIX=` is needed after
the first build. In a fresh tree a check target first builds what it tests
(`min`, or just `binutils` or `gcc`). In an existing tree it tests the build
as it is, even an old one: rebuild with `make min` (or `make all`) first
after changing sources.

| target | what | fails on |
|---|---|---|
| `check-c` | gcc's `execute.exp` under the simulator | any FAIL, ERROR or XPASS, or no PASS at all |
| `check-gcc-amigaos` | gcc's AmigaOS target tests (`amigaos.exp`) | the same |
| `check-c++` | the whole g++ testsuite (slow) | ERROR lines, or no PASS at all: it has standing failures |
| `check-newlib` | newlib's own testsuite, on both newlib boards | any FAIL, ERROR or XPASS, or a board without results |
| `check-libc-test` | one group of [libc-test](https://wiki.musl-libc.org/libc-test.html), musl's testsuite, on one runtime: `libc-test-group=math` (the default) or `functional` (printf, scanf, `strto*`, `fnmatch`, `qsort` and the string functions), `libc-test-crt=nix20`, and `libc-test-cflags=` for the CPU and FPU; not part of `check`, it has known failures | a test that fails or doesn't build |
| `check-libnix` | libnix's target tests | any failure |
| `check-libpthread` | builds libpthread's test programs (the simulator cannot run them) | a build failure |
| `check-binutils` | the gas and ld tests for the Amiga hunk format | a failing Amiga test, or none run |
| `check-multilib` | the multilib list against the driver's | any difference |
| `check-shell` | shellcheck on `scripts/` and `.github/scripts/` | any finding |
| `check` | `check-multilib` to `check-c` in turn, then `check-c` on `volamos/-mcrt=ixemul` and `volamos/-mcrt=nix20/-m68020-60/-m68881/-fbaserel32`: what a release must pass | any of them |

"No PASS at all" catches a misspelled `board=`, which runtest reports only
in its log. Run the gcc testsuite targets one at a time, not together in
one `make -j` or in two shells on the same build tree: they share `gcc.sum`.

## Boards

A board is a `baseboards/*.exp` file: the compiler flags the tests are built
with and the simulator that runs them. `board=` picks one for `check-c`,
`check-gcc-amigaos` and `check-c++`, and defaults to `volamos`, which runs
the tests on a 68000 under volamos.

Options after `volamos` and a slash are added to every compile and link, so
any combination of runtime, CPU, FPU and code model works without a board
file of its own:

```shell
make check-c board=volamos/-mcrt=clib2
make check-c board=volamos/-mcrt=newlib/-m68020-60/-m68881/-fbaserel32
```

volamos follows them: it emulates the CPU that `-m680x0` or `-mcpu=680x0`
names, the 68020 for `-m68020-60`, adds the FPU for `-m68881`, and loads
ixemul.library for `-mcrt=ixemul`. Test the 68020 and later with
`-m68020-60`, which the libraries are built with and which we recommend for
programs, rather than `-m68020` alone.

**Always give the runtime with `-mcrt=`.** Without one, the board uses
`-mcrt=nix20` today, but that default may change.

`SIM=/path/to/volamos` runs a volamos other than the one in `$PREFIX/bin`,
such as a local build.

## Tested configurations

The board combinations worth running, and their latest results:

| board | `check-c` | `check-c++` | `check`[^check] |
|---|---|---|---|
| `volamos/-mcrt=nix20` | ✅ | ✅ | yes |
| `volamos/-mcrt=nix20/-m68020-60` | ✅ | ✅ | |
| `volamos/-mcrt=nix20/-m68020-60/-m68881` | ✅ | ? | |
| `volamos/-mcrt=nix20/-m68020-60/-m68881/-fbaserel32` | ✅ | [❌ 376](https://github.com/AmigaPorts/m68k-amigaos-gcc/issues/253) | yes |
| `volamos/-mcrt=newlib` | ✅ | ✅ | |
| `volamos/-mcrt=newlib/-m68020-60` | ✅ | ? | |
| `volamos/-mcrt=newlib/-m68020-60/-m68881` | ✅ | [❌ 2](https://github.com/AmigaPorts/m68k-amigaos-gcc/issues/254) | |
| `volamos/-mcrt=newlib/-m68020-60/-m68881/-fbaserel32` | ✅ | ? | |
| `volamos/-mcrt=ixemul` | ✅ | ? | yes |
| `volamos/-mcrt=ixemul/-m68020-60` | ✅ | ? | |
| `volamos/-mcrt=ixemul/-m68020-60/-m68881` | [❌ 24](https://github.com/AmigaPorts/m68k-amigaos-gcc/issues/208)[^ixemul] | ? | |
| `volamos/-mcrt=ixemul/-m68020-60/-m68881/-fbaserel32` | [❌ 24](https://github.com/AmigaPorts/m68k-amigaos-gcc/issues/208)[^ixemul] | ? | |
| `volamos/-mcrt=clib2` | [❌ 6](https://github.com/AmigaPorts/m68k-amigaos-gcc/issues/255) | ? | |

[^check]: `make check` runs `check-c` on these, and gates releases.
[^ixemul]: `-m68881` needs the FPU build of ixemul.library, which rounds wrongly until ixemul 80.2.

## Results

Each target prints a summary, saves it as `<target>.summary.txt` in the
top directory, and names its `.sum` and `.log` files on a `results:` line:

| target | results |
|---|---|
| `check-c` | `build-*/gcc/gcc/testsuite/gcc/gcc-execute.{sum,log}`, or `gcc-execute-<board>.{sum,log}` on another board |
| `check-gcc-amigaos` | `build-*/gcc/gcc/testsuite/gcc/gcc-amigaos.{sum,log}` |
| `check-c++` | `build-*/gcc/gcc/testsuite/g++/g++.{sum,log}` |
| `check-newlib` | `build-*/newlib/newlib/testsuite/<board>/newlib.{sum,log}` |
| `check-libc-test` | `build-*/libc-test/<runtime><cflags>/<group>/REPORT`, and a `<test>.err` per test |
| `check-binutils` | `build-*/binutils/gas/testsuite/gas.{sum,log}`, `build-*/binutils/ld/ld.{sum,log}` |

The `.log` has each test's command line and output. Search it for the
test's name to see why it failed.

## Running a few tests

To rerun some tests, call gcc's own check target with a filter, as
`check-c` and `check-gcc-amigaos` do. Outside the top Makefile it needs the
boards (`DEJAGNU`) and the installed tools on the `PATH`. Run `make check-c`
once first: it links the installed libnix into the gcc build tree, where
the tests look for it.

```shell
export DEJAGNU=$PWD/dejagnu-site.exp PATH=$(cat build-*/.prefix)/bin:$PATH
make -C build-*/gcc check-gcc-c \
  RUNTESTFLAGS="--target_board=volamos execute.exp=pr58831*.c"
make -C build-*/gcc check-gcc-c \
  RUNTESTFLAGS="--target_board=volamos/-mcrt=nix20/-m68020-60/-m68881 gcc.target/m68k/amigaos/amigaos.exp=regparm*.c"
```

They write `gcc.sum` and `gcc.log` in `build-*/gcc/gcc/testsuite/gcc/`.
`SANITIZE=0` in `RUNTESTFLAGS` turns off volamos's memory sanitizer, which
`check-c++` always does.

## vamos

The `vamos` board runs the tests under
[vamos](https://github.com/AmigaPorts/amitools) instead of volamos, always as
a 68020, and takes the same options after a slash: `board=vamos/-mcrt=newlib`.
CI doesn't run it. Install amitools in a venv, to keep it out of the system
Python:

```shell
python3 -m venv .venv
.venv/bin/pip install "amitools[vamos] @ git+https://github.com/AmigaPorts/amitools.git"
source .venv/bin/activate
make -j$(nproc) check-c board=vamos
```
