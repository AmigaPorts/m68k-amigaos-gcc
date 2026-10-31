Part of the [Amiga GCC Development Manual](devel.md).

# Testing

The testsuites are ordinary make targets. They run the compiled tests under
[volamos](https://github.com/sidick/volamos), which emulates the AmigaOS
APIs, so no Amiga is needed. CI runs the same targets (see [ci.md](ci.md)),
so a failure in CI can be reproduced with the same command here.

## Setup

Install dejagnu and shellcheck:

- Debian and Ubuntu: `sudo apt install dejagnu shellcheck`
- Fedora: `sudo dnf install dejagnu ShellCheck`
- macOS: `brew install dejagnu shellcheck`

volamos itself needs nothing: a target that needs it downloads its release
binary into `$PREFIX/bin` first (`make volamos` does just that).

## Running

```shell
make -j$(nproc) check                                  # the usual set, see below
make -j$(nproc) check-c board=volamos/-mcrt=newlib     # one testsuite on one board
make -j$(nproc) check-c++                              # the g++ testsuite (slow)
```

In a fresh tree a check target first builds what it tests (`min`, or just
`binutils` or `gcc`). In an existing tree it tests the build as it is, even
an old one: rebuild with `make min` (or `make all`) first after changing
sources.

| target | what |
|---|---|
| `check-c` | gcc's `execute.exp` under the simulator |
| `check-gcc-amigaos` | gcc's AmigaOS target tests (`amigaos.exp`) |
| `check-c++` | the whole g++ testsuite (slow) |
| `check-newlib` | newlib's own testsuite, on both newlib boards |
| `check-libc-test` | musl's testsuite, [libc-test](https://wiki.musl-libc.org/libc-test.html), see below. It has known failures ([#239](https://github.com/AmigaPorts/m68k-amigaos-gcc/issues/239)) |
| `check-libnix` | libnix's target tests |
| `check-libpthread` | builds libpthread's test programs; the simulator cannot run them |
| `check-binutils` | the gas and ld tests for the Amiga hunk format |
| `check-multilib` | the multilib list against the driver's |
| `check-shell` | shellcheck on `scripts/` and `.github/scripts/` |
| `check` | the pre-release test: all of the above except `check-libc-test`, on the boards marked in [Tested configurations](#tested-configurations) |

Run the gcc testsuite targets one at a time, not together in one `make -j`
or in two shells on the same build tree: they share `gcc.sum`.

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

## libc-test

[libc-test](https://wiki.musl-libc.org/libc-test.html) is musl's testsuite:
plain C tests of the C library against the standards, which build for
m68k-amigaos and run under volamos. `check-libc-test` runs one group of them
on one C runtime, chosen with three variables:

- `libc-test-group=math`, the default, runs all of libc-test's `src/math`;
  `libc-test-group=functional` runs the part of its `src/functional` that
  needs no POSIX process or resource calls: the printf, scanf, `strto*`,
  `fnmatch`, `qsort` and string tests.
- `libc-test-crt=nix20`, the default, or `newlib` picks the C runtime.
- `libc-test-cflags=` adds compiler flags, such as `-m68020-60 -m68881`;
  volamos then emulates that CPU and FPU.
- `libc-test-timeout=120` is the seconds a test may run before it is killed
  and counted as failed; the summary names the tests that timed out.

```shell
make check-libc-test libc-test-group=functional libc-test-crt=newlib libc-test-cflags="-m68020-60 -m68881"
```

The failures it finds are tracked in
[#239](https://github.com/AmigaPorts/m68k-amigaos-gcc/issues/239).

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
| `volamos/-mcrt=ixemul` | ✅ | ? | |
| `volamos/-mcrt=ixemul/-m68020-60` | ✅ | ? | |
| `volamos/-mcrt=ixemul/-m68020-60/-m68881` | ✅ | ? | yes |
| `volamos/-mcrt=ixemul/-m68020-60/-m68881/-fbaserel32` | ? | ? | |
| `volamos/-mcrt=clib2` | [❌ 6](https://github.com/AmigaPorts/m68k-amigaos-gcc/issues/255) | ? | |

[^check]: `make check` runs `check-c` on these, and gates releases.
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
