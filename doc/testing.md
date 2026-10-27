# Testing

Part of the [development notes](devel.md).

The testsuites are ordinary make targets. They run the compiled tests under
[volamos](https://github.com/sidick/volamos), which emulates the AmigaOS
APIs, so no Amiga is needed. CI runs the same targets (see [ci.md](ci.md)),
so a failure in CI can be reproduced with the same command here.

## Setup

Install dejagnu: `sudo apt install dejagnu` on Debian and Ubuntu,
`sudo dnf install dejagnu` on Fedora, `brew install dejagnu` on macOS.
volamos itself needs nothing: a target that needs it downloads its release
binary into `$PREFIX/bin` first (`make volamos` does just that).

The `amigaos*` boards run the tests under
[vamos](https://github.com/AmigaPorts/amitools) instead, for comparison.
Install amitools in a venv, to keep it out of the system Python:

```shell
python3 -m venv .venv
.venv/bin/pip install "amitools[vamos] @ git+https://github.com/AmigaPorts/amitools.git"
source .venv/bin/activate
make -j$(nproc) check board=amigaos
```

## Running

```shell
make -j$(nproc) check                          # the usual set, see below
make -j$(nproc) check-c board=volamos-fpu      # one testsuite on one board
make -j$(nproc) check-c++                      # the g++ testsuite (slow)
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
| `check-libc-test` | the math tests of [libc-test](https://wiki.musl-libc.org/libc-test.html), musl's testsuite, on one runtime (`libc-test-crt=nix20`, and `libc-test-cflags=` for the CPU and FPU); not part of `check`, it has known failures | a test that fails or doesn't build |
| `check-libnix` | libnix's target tests | any failure |
| `check-libpthread` | builds libpthread's test programs (the simulator cannot run them) | a build failure |
| `check-binutils` | the gas and ld tests for the Amiga hunk format | a failing Amiga test, or none run |
| `check-multilib` | the multilib list against the driver's | any difference |
| `check-shell` | shellcheck on `scripts/` and `.github/scripts/` | any finding |
| `check` | `check-multilib` to `check-c` in turn, then `check-c` on `volamos-ixemul` and `volamos-fpu-baserel32`: what a release must pass | any of them |

"No PASS at all" catches a misspelled `board=`, which runtest reports only
in its log. Run the gcc testsuite targets one at a time, not together in
one `make -j` or in two shells on the same build tree: they share `gcc.sum`.

## Boards

A board is a `baseboards/*.exp` file: the compiler flags the tests are built
with and the simulator that runs them. `board=` picks one for `check-c`,
`check-gcc-amigaos` and `check-c++`, and defaults to `volamos`:

| board | code | runtime |
|---|---|---|
| `volamos` | 68000 | libnix |
| `volamos-020` | 68020 | libnix |
| `volamos-fpu` | 68020 + 68881, on an emulated FPU | libnix |
| `volamos-baserel`, `volamos-020-baserel` | 68000 / 68020, `-fbaserel` | libnix |
| `volamos-020-baserel32` | 68020, `-fbaserel32` | libnix |
| `volamos-fpu-baserel32` | 68020 + 68881, `-fbaserel32` | libnix |
| `volamos-newlib` | 68000 | newlib |
| `volamos-newlib-fpu` | 68020 + 68881 | newlib |
| `volamos-newlib-fpu-baserel32` | 68020 + 68881, `-fbaserel32` | newlib |
| `volamos-ixemul` | 68000 | ixemul |
| `volamos-ixemul-fpu` | 68020 + 68881, with the 68020 FPU ixemul.library | ixemul |
| `amigaos`, `amigaos-020`, `amigaos-baserel`, ... | as the `volamos*` board of the same name | under vamos |

`SIM=/path/to/volamos` runs a volamos other than the one in `$PREFIX/bin`,
such as a local build.

## Results

Each target prints a summary, saves it as `<target>.summary.txt` in the
top directory, and names its `.sum` and `.log` files on a `results:` line:

| target | results |
|---|---|
| `check-c` | `build-*/gcc/gcc/testsuite/gcc/gcc-execute.{sum,log}`, or `gcc-execute-<board>.{sum,log}` on another board |
| `check-gcc-amigaos` | `build-*/gcc/gcc/testsuite/gcc/gcc-amigaos.{sum,log}` |
| `check-c++` | `build-*/gcc/gcc/testsuite/g++/g++.{sum,log}` |
| `check-newlib` | `build-*/newlib/newlib/testsuite/<board>/newlib.{sum,log}` |
| `check-libc-test` | `build-*/libc-test/<runtime><cflags>/math/REPORT`, and a `<test>.err` per test |
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
  RUNTESTFLAGS="--target_board=volamos-fpu gcc.target/m68k/amigaos/amigaos.exp=regparm*.c"
```

They write `gcc.sum` and `gcc.log` in `build-*/gcc/gcc/testsuite/gcc/`.
`SANITIZE=0` in `RUNTESTFLAGS` turns off volamos's memory sanitizer, which
`check-c++` always does.
