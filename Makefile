# =================================================
# Makefile based Amiga compiler setup.
# (c) Stefan "Bebbo" Franke in 2018
# (c) Marlon Beijer in 2025-2026
#
# Riding a dead horse...
# =================================================
include disable_implicite_rules.mk

# Keep variable-only invocations such as `make sdk=ahi` working even when
# helper targets are declared before the dispatcher below.
.DEFAULT_GOAL := x

# =================================================
# variables
# =================================================
$(eval SHELL = $(shell which bash 2>/dev/null) )

HOST ?=
TARGET ?= m68k-amigaos

# Keep native builds identical to the original build.  HOST is only set when
# building tools that will run on another system (for example MinGW or AmigaOS).
ifneq (,$(strip $(HOST)))
  BUILD_TRIPLET ?= $(shell cc -dumpmachine 2>/dev/null)
  HOST_CONFIGURE := --build=$(BUILD_TRIPLET) --host=$(HOST)
endif

HOST_RUNNER ?=
BUILD_CC ?= cc
BUILD_CXX ?= c++
HOST_TOOL_PREFIX ?=
TARGET_TOOL_PREFIX ?=

# Default empty; set to .exe for MinGW targets
ifneq (,$(findstring mingw,$(HOST)))
  EXEEXT := .exe
else
  EXEEXT :=
endif

ifneq (,$(findstring amigaos,$(HOST)))
  HOST_CPU_FLAGS := -mcpu=68040 -mhard-float
  HOST_CRT_FLAGS := -mcrt=nix20
  # The AmigaOS libstdc++ supports the old string ABI reliably.  This affects
  # only GCC executables that run on HOST; target libraries retain their own
  # configuration and ABI defaults.
  HOST_CXX_ABI_FLAGS := -D_GLIBCXX_USE_CXX11_ABI=0
  HOST_LINK_FLAGS := $(HOST_CPU_FLAGS) $(HOST_CRT_FLAGS)
else
  HOST_CPU_FLAGS :=
  HOST_CRT_FLAGS :=
  HOST_CXX_ABI_FLAGS :=
  HOST_LINK_FLAGS :=
endif

UNAME_S := $(shell uname -s)
BUILD := $(shell pwd)/build-$(UNAME_S)-$(TARGET)
ifneq (,$(strip $(HOST)))
  BUILD := $(BUILD)-$(HOST)
endif

# Goals that touch nothing under PREFIX, so they run without one
NO_PREFIX_GOALS := clean% drop-prefix help info print-% update% branch release-tag v

# PREFIX has no default: the first build names it, the build tree records
# it (written on the first build, checked below) and a make without PREFIX
# takes it from there, so check-*, install and sdk runs need no PREFIX=...
PREFIX_STAMP := $(BUILD)/.prefix
ifeq ($(origin PREFIX),undefined)
  ifneq ($(wildcard $(PREFIX_STAMP)),)
    PREFIX := $(shell cat $(PREFIX_STAMP))
    # quiet for print-%, whose output scripts read
    ifneq ($(if $(MAKECMDGOALS),$(filter-out print-%,$(MAKECMDGOALS)),all),)
      $(info PREFIX=$(PREFIX), from $(PREFIX_STAMP))
    endif
  else
    ifneq ($(filter-out $(NO_PREFIX_GOALS),$(MAKECMDGOALS)),)
      $(error PREFIX is not set: pass PREFIX=<install directory> once, the build tree remembers it)
    endif
  endif
endif
# the module makefiles (libnix's Makefile.gcc6, ...) have defaults of their
# own: they see ours the way a PREFIX=... on the command line reached them
export PREFIX
ifeq (,$(strip $(HOST)))
export PATH := $(PREFIX)/bin:$(PATH)
endif
BUILD_TOOLS := $(BUILD)/build-tools
# Helpers which must run on the build machine are private build artifacts.
# Keep them out of PREFIX so they cannot leak into target packages.
BUILD_TOOLS_PREFIX ?= $(BUILD_TOOLS)/prefix

# A Canadian cross needs a compiler which runs on BUILD and emits TARGET
# objects.  Using the newly built MinGW compiler through Wine for every target
# library source eventually exhausts Wine's process launcher.  Build the
# build-to-target tools privately instead; GCC and binutils for HOST are still
# built once and only the private bootstrap compiler is duplicated.
ifneq (,$(findstring mingw,$(HOST)))
ifeq (,$(strip $(TARGET_TOOL_PREFIX)))
TARGET_BUILD_TOOLS_PREFIX := $(BUILD_TOOLS)/target-cross/prefix
TARGET_BUILD_TOOLS_BUILD := $(BUILD_TOOLS)/target-cross/build
TARGET_BUILD_TOOLS_PREREQ := $(TARGET_BUILD_TOOLS_BUILD)/_done
TARGET_TOOL_PREFIX := $(TARGET_BUILD_TOOLS_PREFIX)/bin/$(TARGET)-
endif
endif

# GitHub container jobs may provide a HOME owned by a different uid.  Keep
# Wine's prefix in the writable build tree and initialize it once before a
# Windows-hosted compiler can be executed.  XDG_RUNTIME_DIR must stay short:
# Wine appends socket names to it, and Unix domain socket paths are limited to
# 108 bytes even when the build itself lives below a much longer CI workspace.
ifneq (,$(findstring mingw,$(HOST)))
WINEPREFIX ?= $(BUILD)/wine-prefix
WINEDEBUG ?= -all
WINEBOOT ?= wineboot
WINEPATH ?= Z:$(abspath $(PREFIX)/bin)
WINE_RUNTIME_DIR ?= /tmp/m68k-amigaos-gcc-wine-$(shell id -u)
WINE_RUNNER_LOCK ?= $(BUILD_TOOLS)/wine-runner.lock
# Wine becomes unreliable when several Windows-hosted GCC drivers launch
# cc1/as at once.  Bound only those Wine invocations; the rest of the build
# keeps the parallelism requested from make.  Two slots avoid the runtime
# failures without reducing a Canadian cross build to fully serial execution.
WINE_RUNNER_SLOTS ?= 2
XDG_RUNTIME_DIR := $(WINE_RUNTIME_DIR)
MINGW_HOST_RUNTIME_SOURCE ?= $(shell $(CC) -print-file-name=libwinpthread-1.dll)
MINGW_HOST_RUNTIME := $(PREFIX)/bin/libwinpthread-1.dll
export WINEPREFIX WINEDEBUG WINEPATH XDG_RUNTIME_DIR
HOST_RUNNER_SETUP_PREREQ := $(WINEPREFIX)/.initialized $(MINGW_HOST_RUNTIME)
endif

# Prefer a build-machine TARGET compiler when the environment already
# provides one (as it does for an AmigaOS host build).  Otherwise create
# wrappers that run the newly built HOST tools through HOST_RUNNER.  GCC and
# binutils themselves are still built only once, for HOST.
ifneq (,$(strip $(HOST)))
ifeq (,$(strip $(HOST_TOOL_PREFIX)))
ifeq ($(strip $(HOST)),$(strip $(TARGET)))
HOST_TOOL_PREFIX := $(patsubst %gcc,%,$(shell command -v $(HOST)-gcc 2>/dev/null))
endif
endif
ifneq (,$(strip $(TARGET_TOOL_PREFIX)))
TARGET_CC_FOR_BUILD := $(TARGET_TOOL_PREFIX)gcc
TARGET_CXX_FOR_BUILD := $(TARGET_TOOL_PREFIX)g++
TARGET_AR_FOR_BUILD := $(TARGET_TOOL_PREFIX)ar
TARGET_RANLIB_FOR_BUILD := $(TARGET_TOOL_PREFIX)ranlib
TARGET_EXEC_PREFIX_FOR_BUILD := $(TARGET_TOOL_PREFIX)
else ifneq (,$(strip $(HOST_TOOL_PREFIX)))
TARGET_CC_FOR_BUILD := $(HOST_TOOL_PREFIX)gcc
TARGET_CXX_FOR_BUILD := $(HOST_TOOL_PREFIX)g++
TARGET_AR_FOR_BUILD := $(HOST_TOOL_PREFIX)ar
TARGET_RANLIB_FOR_BUILD := $(HOST_TOOL_PREFIX)ranlib
TARGET_EXEC_PREFIX_FOR_BUILD := $(HOST_TOOL_PREFIX)
else
TARGET_RUNNER_WRAPPER_DIR := $(BUILD_TOOLS)/target-runner
TARGET_RUNNER_TOOL_NAMES := gcc g++ c++ cpp gcc-ar gcc-nm gcc-ranlib \
	addr2line ar as c++filt elfedit ld ld.bfd nm objcopy objdump ranlib \
	readelf size strings strip
TARGET_RUNNER_COMPILER_TOOL_NAMES := gcc g++ c++ cpp
ifneq (,$(findstring mingw,$(HOST)))
# The hosted driver relocates its internal include directory to Z:/... under
# Wine.  Use its Unix spelling while target libraries are built so dependency
# files remain readable by the build machine's make.
TARGET_RUNNER_COMPILER_FLAGS = -fno-canonical-system-headers \
	-isystem "$(PREFIX)/lib/gcc/$(TARGET)/$(GCC_DIR_VERSION)/include"
endif
TARGET_RUNNER_FLAGS = $(if $(filter $*,$(TARGET_RUNNER_COMPILER_TOOL_NAMES)),$(TARGET_RUNNER_COMPILER_FLAGS))
TARGET_RUNNER_WRAPPERS := $(patsubst %,$(TARGET_RUNNER_WRAPPER_DIR)/$(TARGET)-%,$(TARGET_RUNNER_TOOL_NAMES))
TARGET_CC_FOR_BUILD := $(TARGET_RUNNER_WRAPPER_DIR)/$(TARGET)-gcc
TARGET_AR_FOR_BUILD := $(TARGET_RUNNER_WRAPPER_DIR)/$(TARGET)-ar
TARGET_RANLIB_FOR_BUILD := $(TARGET_RUNNER_WRAPPER_DIR)/$(TARGET)-ranlib
TARGET_CXX_FOR_BUILD := $(TARGET_RUNNER_WRAPPER_DIR)/$(TARGET)-c++
export PATH := $(TARGET_RUNNER_WRAPPER_DIR):$(PATH)
endif
SDK_CC_FOR_BUILD := $(TARGET_CC_FOR_BUILD)
SDK_AR_FOR_BUILD := $(TARGET_AR_FOR_BUILD)
ifneq (,$(strip $(TARGET_EXEC_PREFIX_FOR_BUILD)))
TARGET_EXEC_WRAPPER_DIR := $(BUILD_TOOLS)/target-exec
TARGET_EXEC_TOOL_NAMES := ar as ld ld.bfd nm objcopy objdump ranlib strip
TARGET_EXEC_WRAPPERS := $(patsubst %,$(TARGET_EXEC_WRAPPER_DIR)/%,$(TARGET_EXEC_TOOL_NAMES))
TARGET_GCC_INCLUDE_FOR_BUILD = $(shell $(TARGET_CC_FOR_BUILD) -print-file-name=include 2>/dev/null)
TARGET_COMPILER_WRAPPER_DIR := $(BUILD_TOOLS)/target-compiler
TARGET_COMPILER_TOOL_NAMES := gcc g++ c++ cpp
TARGET_COMPILER_WRAPPERS := $(patsubst %,$(TARGET_COMPILER_WRAPPER_DIR)/$(TARGET)-%,$(TARGET_COMPILER_TOOL_NAMES))
TARGET_PREFIXED_EXEC_WRAPPERS := $(patsubst %,$(TARGET_COMPILER_WRAPPER_DIR)/$(TARGET)-%,$(TARGET_EXEC_TOOL_NAMES))
TARGET_CC_COMMAND_FOR_BUILD := $(TARGET_COMPILER_WRAPPER_DIR)/$(TARGET)-gcc
TARGET_CXX_COMMAND_FOR_BUILD := $(TARGET_COMPILER_WRAPPER_DIR)/$(TARGET)-g++
export PATH := $(TARGET_COMPILER_WRAPPER_DIR):$(PATH)
else
TARGET_CC_COMMAND_FOR_BUILD := $(TARGET_CC_FOR_BUILD)
TARGET_CXX_COMMAND_FOR_BUILD := $(TARGET_CXX_FOR_BUILD)
endif
else
TARGET_CC_FOR_BUILD ?= $(shell command -v $(TARGET)-gcc 2>/dev/null)
TARGET_AR_FOR_BUILD := $(PREFIX)/bin/$(TARGET)-ar
TARGET_RANLIB_FOR_BUILD := $(PREFIX)/bin/$(TARGET)-ranlib
endif

ifneq (,$(strip $(HOST_RUNNER_SETUP_PREREQ)))
$(WINEPREFIX)/.initialized:
	@mkdir -p $(@D) $(WINE_RUNTIME_DIR)
	@chmod 700 $(WINE_RUNTIME_DIR)
	@$(WINEBOOT) --init
	@touch $@

$(MINGW_HOST_RUNTIME): $(MINGW_HOST_RUNTIME_SOURCE)
	@mkdir -p $(@D)
	@install -m 755 "$<" "$@"
endif

ifneq (,$(strip $(TARGET_RUNNER_WRAPPER_DIR)))
$(TARGET_RUNNER_WRAPPER_DIR)/$(TARGET)-%: Makefile
	@mkdir -p $(@D)
	@test -n "$(HOST_RUNNER)" || { echo "HOST_RUNNER is required to execute HOST=$(HOST) tools while building TARGET=$(TARGET) libraries"; exit 1; }
ifneq (,$(findstring wine,$(HOST_RUNNER)))
	@printf '%s\n' '#!/bin/sh' \
		'response_file=' \
		'case "$*" in' \
		'  ar|gcc-ar)' \
		'    arg_bytes=0' \
		'    for arg do arg_bytes=$$((arg_bytes + $${#arg} + 1)); done' \
		'    if [ "$$arg_bytes" -gt 16000 ]; then' \
		'      response_file=.m68k-amigaos-tool-$$$$.rsp' \
		'      cr=$$(printf '\''\r'\'')' \
		'      for arg do arg=$${arg%"$$cr"}; printf '\''"%s"\n'\'' "$$arg"; done >"$$response_file"' \
		'      set -- "@$$response_file"' \
		'    fi' \
		'    ;;' \
		'esac' \
		'trap '\''[ -z "$$response_file" ] || rm -f "$$response_file"'\'' EXIT HUP INT TERM' \
		'slot=1' \
		'while :; do' \
		'  exec 9>"$(WINE_RUNNER_LOCK).$$slot"' \
		'  if /usr/bin/flock -n 9; then break; fi' \
		'  exec 9>&-' \
		'  slot=$$((slot + 1))' \
		'  if [ "$$slot" -gt "$(WINE_RUNNER_SLOTS)" ]; then slot=1; sleep 0.05; fi' \
		'done' \
		'attempt=1' \
		'while :; do' \
		'  stdout_file=$$(mktemp)' \
		'  stderr_file=$$(mktemp)' \
		'  $(HOST_RUNNER) "$(PREFIX)/bin/$(TARGET)-$*$(EXEEXT)" $(TARGET_RUNNER_FLAGS) "$$@" >"$$stdout_file" 2>"$$stderr_file"' \
		'  status=$$?' \
		'  if [ "$$status" -ne 0 ] && [ "$$attempt" -lt 3 ] && grep -Eq "wine client error:.*(Connection reset by peer|Broken pipe)|wineserver.*(crash|terminated)|fatal error: cannot execute .*: CreateProcess: No such file or directory" "$$stderr_file"; then' \
		'    cat "$$stderr_file" >&2' \
		'    rm -f "$$stdout_file" "$$stderr_file"' \
		'    attempt=$$((attempt + 1))' \
		'    sleep 1' \
		'    continue' \
		'  fi' \
		'  cat "$$stdout_file"' \
		'  cat "$$stderr_file" >&2' \
		'  rm -f "$$stdout_file" "$$stderr_file"' \
		'  exit "$$status"' \
		'done' >$@
else
	@printf '%s\n' '#!/bin/sh' 'exec $(HOST_RUNNER) "$(PREFIX)/bin/$(TARGET)-$*$(EXEEXT)" $(TARGET_RUNNER_FLAGS) "$$@"' >$@
endif
	@chmod +x $@
endif

ifneq (,$(strip $(TARGET_EXEC_WRAPPER_DIR)))
$(TARGET_EXEC_WRAPPERS): $(TARGET_BUILD_TOOLS_PREREQ)

$(TARGET_EXEC_WRAPPER_DIR)/%:
	@mkdir -p $(@D)
	@test -x "$(TARGET_EXEC_PREFIX_FOR_BUILD)$*"
	@ln -sf "$(TARGET_EXEC_PREFIX_FOR_BUILD)$*" $@

$(TARGET_COMPILER_WRAPPERS): $(TARGET_COMPILER_WRAPPER_DIR)/$(TARGET)-%: $(TARGET_EXEC_WRAPPERS) Makefile
	@mkdir -p $(@D)
	@test -x "$(TARGET_EXEC_PREFIX_FOR_BUILD)$*"
	@test -n "$(TARGET_GCC_INCLUDE_FOR_BUILD)"
	@printf '%s\n' '#!/bin/sh' 'exec "$(TARGET_EXEC_PREFIX_FOR_BUILD)$*" -B"$(TARGET_EXEC_WRAPPER_DIR)/" -B"$(PREFIX)/lib/gcc/$(TARGET)/$(GCC_DIR_VERSION)/" -B"$(PREFIX)/$(TARGET)/lib/" -isystem "$(TARGET_GCC_INCLUDE_FOR_BUILD)" "$$@"' >$@
	@chmod +x $@

$(TARGET_PREFIXED_EXEC_WRAPPERS): $(TARGET_COMPILER_WRAPPER_DIR)/$(TARGET)-%: $(TARGET_EXEC_WRAPPER_DIR)/%
	@mkdir -p $(@D)
	@ln -sf "$<" $@
endif
PROJECTS := $(shell pwd)/projects
DOWNLOAD := $(shell pwd)/download
__BUILDDIR := $(shell mkdir -p $(BUILD))

# Don't build and install the texinfo documentation, which isn't very
# useful for a cross toolchain, particularly one that lives in a container.
export MAKEINFO = true
MAKEOVERRIDES += MAKEINFO=$(MAKEINFO)

# binutils, gcc and newlib record the prefix in their configured build
# trees: building the same tree for another PREFIX installs into both
ifeq ($(filter $(NO_PREFIX_GOALS),$(MAKECMDGOALS)),)
ifneq ($(wildcard $(PREFIX_STAMP)),)
ifneq ($(shell cat $(PREFIX_STAMP)),$(abspath $(PREFIX)))
$(error $(BUILD) was configured for PREFIX=$(shell cat $(PREFIX_STAMP)); use that PREFIX, another BUILD, or make clean)
endif
# the _done stamps describe what was installed there
ifeq ($(wildcard $(PREFIX)),)
$(error $(BUILD) was configured for PREFIX=$(PREFIX), which no longer exists; run make clean first)
endif
endif
endif

$(PREFIX_STAMP):
	@echo "$(abspath $(PREFIX))" >$@
__PROJECTDIR := $(shell mkdir -p $(PROJECTS))
__DOWNLOADDIR := $(shell mkdir -p $(DOWNLOAD))

GCC_VERSION ?= $(shell cat 2>/dev/null $(PROJECTS)/gcc/gcc/BASE-VER)
# gcc 13 and 16 omit the frame pointer at -O1 and up on every target; gcc 6
# left that to each target, and m68k never turned it on.
GCC6_OMIT_FRAME_POINTER = $(if $(filter 6.%,$(GCC_VERSION)),-fomit-frame-pointer)
# gcc 7 and later are configured with --with-gcc-major-version-only, so
# lib/gcc/<target>/ and the versioned driver are named after the major
# version (16, not 16.2.1b) and stay put across point releases.  gcc 6
# predates the option.
GCC_DIR_VERSION = $(if $(filter 6.%,$(GCC_VERSION)),$(GCC_VERSION),$(firstword $(subst ., ,$(GCC_VERSION))))

# The release a build is part of, after the gcc it was built from: projects/gcc's release tag without its m68k-amigaos-gcc-v prefix, plus commit count and hash past it.
# A gcc branch without release tags, such as amiga6, gives its name and hash instead.
PACKAGE_VERSION ?= $(shell cd $(PROJECTS)/gcc 2>/dev/null && \
	{ v=$$(git describe --tags --match 'm68k-amigaos-gcc-v*' --dirty 2>/dev/null) && \
	  echo "$${v#m68k-amigaos-gcc-v}" || \
	  echo "$$(git rev-parse --abbrev-ref HEAD)-g$$(git rev-parse --short HEAD)"; })
PACKAGE_VERSION := $(strip $(PACKAGE_VERSION))

# Stamp gcc and binutils with the release, so bug reports carry it: "m68k-amigaos-gcc (AmigaDev 16.2-rc19) 16.2.1b 2026...".
# It is captured when the build tree is configured, not tracked afterwards:
# use a fresh BUILD to refresh it, or reconfigure and remove $(BUILD)/gcc/gcc/build/genversion.o so gcc regenerates version.h.
PKGVERSION ?= AmigaDev $(PACKAGE_VERSION)
BUGURL ?= https://github.com/AmigaPorts/m68k-amigaos-gcc/issues
CONFIG_VERSION := --with-pkgversion="$(PKGVERSION)" --with-bugurl="$(BUGURL)"

ifeq ($(UNAME_S), Darwin)
	SED := gsed
else ifeq ($(UNAME_S), FreeBSD)
	SED := gsed
else
	SED := sed
endif

# get git urls and branches from .repos file
$(shell  [ ! -f .repos ] && cp default-repos .repos)

# .repos is copied once and then is the user's to edit, so a later change to default-repos
# never reaches it: name the modules whose line differs. Touching .repos silences this.
ifeq ($(MAKELEVEL),0)
  ifneq ($(shell [ default-repos -nt .repos ] && echo y),)
    repos_drift := $(shell awk '!NF || substr($$1, 1, 1) == "\043" { next } NR == FNR { d[$$1] = $$2 " " $$3; next } { r[$$1] = $$2 " " $$3 } END { for (m in d) if (r[m] != d[m]) print m }' default-repos .repos)
    ifneq ($(repos_drift),)
      $(info )
      $(info WARNING: default-repos changed after .repos was made from it, and differs for: $(repos_drift).)
      $(info WARNING: Update .repos to match, or delete it to start over.)
      $(info )
    endif
  endif
endif

# Blank lines and comments are skipped (a .manifest records this repository
# in its first line, as a comment).
modules := $(shell $(SED) -e '/^[[:blank:]]*\#/d' -e '/^[[:blank:]]*$$/d' -e 's/[[:blank:]]\+/ /g' .repos | cut -d' ' -f1)
get_url = $(shell grep '^$(1)[[:blank:]]' .repos | $(SED) -e 's/[[:blank:]]\+/ /g' | cut -d' ' -f2)
get_branch = $(shell grep '^$(1)[[:blank:]]' .repos | $(SED) -e 's/[[:blank:]]\+/ /g' | cut -d' ' -f3)
$(foreach modu,$(modules),$(eval $(modu)_URL=$(call get_url,$(modu))))
$(foreach modu,$(modules),$(eval $(modu)_BRANCH=$(call get_branch,$(modu))))

# get file names, checksums and urls of the downloaded archives from
# default-archives; <name>_DIR is the file without its extension, the
# directory most of them unpack into
archives := $(shell $(SED) -e '/^[[:blank:]]*\#/d' -e '/^[[:blank:]]*$$/d' -e 's/[[:blank:]]\+/ /g' default-archives | cut -d' ' -f1)
get_archive = $(shell grep '^$(1)[[:blank:]]' default-archives | $(SED) -e 's/[[:blank:]]\+/ /g' | cut -d' ' -f2)
get_sha256 = $(shell grep '^$(1)[[:blank:]]' default-archives | $(SED) -e 's/[[:blank:]]\+/ /g' | cut -d' ' -f3)
get_urls = $(shell grep '^$(1)[[:blank:]]' default-archives | $(SED) -e 's/[[:blank:]]\+/ /g' | cut -d' ' -f4-)
$(foreach arch,$(archives),$(eval $(arch)_ARCHIVE=$(call get_archive,$(arch))))
$(foreach arch,$(archives),$(eval $(arch)_SHA256=$(call get_sha256,$(arch))))
$(foreach arch,$(archives),$(eval $(arch)_URLS=$(call get_urls,$(arch))))
$(foreach arch,$(archives),$(eval $(arch)_DIR=$(patsubst %.tar,%,$(basename $($(arch)_ARCHIVE)))))

# The archives depend on the table, so a changed sha256 fetches the new
# file; for an unchanged one scripts/sdk-download finds its hash in the
# archive's .sha256 note and returns at once, and nothing downstream is remade.
define archive_rules
$(DOWNLOAD)/$($(1)_ARCHIVE): default-archives
	@$(PWD)/scripts/sdk-download --sha256 $($(1)_SHA256) $$@ $($(1)_URLS)
endef
$(foreach arch,$(archives),$(eval $(call archive_rules,$(arch))))

NDK_ARC_NAME         := $(ndk_DIR)
NDK_FOLDER_NAME      := NDK3.2
NDK_FOLDER_NAME_H    := NDK3.2/Include_H
NDK_FOLDER_NAME_I    := NDK3.2/Include_I
NDK_FOLDER_NAME_FD   := NDK3.2/FD
NDK_FOLDER_NAME_SFD  := NDK3.2/SFD
NDK_FOLDER_NAME_LIBS := NDK3.2/lib

ifeq (,$(strip $(HOST)))
CFLAGS ?= -O2
CXXFLAGS ?= $(CFLAGS)
BUILD_CFLAGS ?= $(CFLAGS)
BUILD_CXXFLAGS ?= $(CXXFLAGS)
CFLAGS_FOR_TARGET ?= $(strip -O2 $(GCC6_OMIT_FRAME_POINTER))
CXXFLAGS_FOR_TARGET ?= $(CFLAGS_FOR_TARGET)

# Preserve the original native configure environment exactly.
E:=CFLAGS="$(CFLAGS)" CXXFLAGS="$(CXXFLAGS)" CFLAGS_FOR_BUILD="$(CFLAGS)" CXXFLAGS_FOR_BUILD="$(CXXFLAGS)"  CFLAGS_FOR_TARGET="$(CFLAGS_FOR_TARGET)" CXXFLAGS_FOR_TARGET="$(CFLAGS_FOR_TARGET)"
else
CFLAGS ?= -Os $(HOST_CPU_FLAGS) $(HOST_CRT_FLAGS)
CXXFLAGS ?= $(CFLAGS) $(HOST_CXX_ABI_FLAGS)
LDFLAGS ?= $(HOST_LINK_FLAGS)
BUILD_CFLAGS ?= -O2
BUILD_CXXFLAGS ?= $(BUILD_CFLAGS)
BUILD_LDFLAGS ?=
CFLAGS_FOR_TARGET ?= $(strip -O2 $(GCC6_OMIT_FRAME_POINTER))
CXXFLAGS_FOR_TARGET ?= $(CFLAGS_FOR_TARGET)

E:=CFLAGS="$(CFLAGS)" CXXFLAGS="$(CXXFLAGS)" LDFLAGS="$(LDFLAGS)" CFLAGS_FOR_BUILD="$(BUILD_CFLAGS)" CXXFLAGS_FOR_BUILD="$(BUILD_CXXFLAGS)" LDFLAGS_FOR_BUILD="$(BUILD_LDFLAGS)" CFLAGS_FOR_TARGET="$(CFLAGS_FOR_TARGET)" CXXFLAGS_FOR_TARGET="$(CXXFLAGS_FOR_TARGET)"
endif

THREADS ?= no

# =================================================
# determine exe extension for cygwin
$(eval MYMAKE = $(shell which $(MAKE) 2>/dev/null) )
$(eval MYMAKEEXE = $(shell which "$(MYMAKE:%=%.exe)" 2>/dev/null) )
ifeq (,$(EXEEXT))
  EXEEXT:=$(MYMAKEEXE:%=.exe)
endif

# Files for GMP, MPC and MPFR

GMP := $(gmp_DIR)
GMPFILE := $(gmp_ARCHIVE)
MPC := $(mpc_DIR)
MPCFILE := $(mpc_ARCHIVE)
MPFR := $(mpfr_DIR)
MPFRFILE := $(mpfr_ARCHIVE)

# =================================================
# pretty output ^^
# =================================================
TEEEE := >&

ifeq ($(sdk),)
__LINIT := $(shell rm .state 2>/dev/null)
endif

$(eval has_flock = $(shell which flock 2>/dev/null))
ifeq ($(has_flock),)
FLOCK := echo >/dev/null
else
FLOCK := $(has_flock)
endif

L0 = @__p=
L00 = __p=
ifneq ($(VERBOSE),)
verbose = $(VERBOSE)
endif
ifeq ($(verbose),)
L1 = ; ($(FLOCK) 200; echo -e \\033[33m$$__p...\\033[0m >>.state; echo -ne \\033[33m$$__p...\\033[0m ) 200>.lock; mkdir -p log; __l="log/$$__p.log" ; (
L2 = )$(TEEEE) "$$__l"; __r=$$?; ($(FLOCK) 200; if (( $$__r > 0 )); then \
  echo -e \\n\\033[K\\033[31m$$__p...failed\\033[0m; \
   $(SED) -n '1,/^make\(\[[0-9]*\]\)\?: \*\*\*/p' "$$__l" | tail -n 100; \
  echo -e \\033[31m$$__p...failed\\033[0m; \
  echo -e use \\033[1mless \"$$__l\"\\033[0m to view the full log; \
  else echo -e \\n\\033[K\\033[32m$$__p...done\\033[0m; fi \
  ;grep -v "$$__p" .state >.state0 2>/dev/null; mv .state0 .state ;echo -n $$(cat .state | paste -sd " " -); ) 200>.lock; [[ $$__r -gt 0 ]] && exit $$__r; echo -n ""
else
L1 = ;(
L2 = )
endif

# Recipes do not echo their commands, as if every line started with @. The
# modules' own makefiles are not affected: their commands still reach log/.
.SILENT:

# =================================================

.PHONY: x init
x:
	@if [ "$(sdk)" == "" ]; then \
		$(MAKE) --no-print-directory help; \
	else \
		$(MAKE) --no-print-directory sdk; \
	fi

# =================================================
# help
# =================================================
.PHONY: help
help:
	@echo "make help                display this help"
	@echo "make info                print prefix and other flags"
	@echo "make all                 build and install all"
	@echo "make min                 build only the compiler and its runtimes (no gdb, gprof, libnix4.library)"
	@echo "make <target>            builds a target: binutils, gcc, gprof, fd2sfd, fd2pragma, ira, sfdc, vasm, vbcc, vlink, libnix, ixemul, libgcc, clib2, libdebug, libpthread, ndk, ndk13"
	@echo "make clean               remove the build folder"
	@echo "make clean-<target>      remove the target's build folder"
	@echo "make drop-prefix         remove all content from the prefix folder"
	@echo "make package             package the prefix folder for the destination host"
	@echo "make package-lha         package the prefix folder as an .lha archive"
	@echo "make volamos             install the volamos simulator used by the testsuite"
	@echo "make update              perform git pull for all targets"
	@echo "make update-<target>     perform git pull for the given target"
	@echo "make sdk=<sdk>           install the sdk <sdk>"
	@echo "make all-sdk             install all sdks"
	@echo "make l                   print the last log entry for each project"
	@echo "make b                   print the branch for each project"
	@echo "make r                   print the remote for each project"
	@echo "make v [ref=<ref>|date=<date>]  checkout all modules at a tag, branch or commit, or as of a date; or at their branches"
	@echo "make branch branch=<branch> mod=<module>  switch the module to the given branch"
	@echo ""
	@echo "Parameters:"
	@echo "PREFIX=<path>            install directory; required once, the build tree remembers it"
	@echo "THREADS=posix            build gcc with thread support"
	@echo "ADDLANG=lang,lang...     configure additional language frontends"

# =================================================
# all
# =================================================
# gdb is built for the native and the MinGW hosts, not for AmigaOS.
ifneq (,$(findstring amigaos,$(HOST)))
  ALL_GDB :=
else
  ALL_GDB := gdb
endif

.PHONY: all
all: gcc binutils $(ALL_GDB) gprof fd2sfd fd2pragma ira sfdc vasm libnix ixemul libgcc clib2 libdebug libpthread ndk ndk13 libnix4.library
	@echo "Creating .manifest..."
	@$(MAKE) --no-print-directory manifest

# Record what was built in .manifest, in the format of .repos with the
# commit of each checkout; see scripts/manifest.  Installed to $(PREFIX), so
# that the release packages carry it.  A build from checkouts without git
# history, like the Nix package, passes the one it recorded in MANIFEST.
MANIFEST ?=
.PHONY: manifest
manifest:
ifneq (,$(strip $(MANIFEST)))
	@cp $(MANIFEST) .manifest
else
	@PROJECTS=$(PROJECTS) scripts/manifest > .manifest
endif
	@mkdir -p $(PREFIX)
	@install -m 644 .manifest $(PREFIX)/.manifest

# the compiler and the runtimes it links by default: what the testsuites need
.PHONY: min
min: binutils gcc libnix libgcc ixemul

.PHONY: build-target-tools
build-target-tools: $(TARGET_BUILD_TOOLS_PREREQ)

# =================================================
# clean
# =================================================
.PHONY: clean
clean: clean-gcc clean-binutils clean-fd2sfd clean-lha clean-fd2pragma clean-ira clean-sfdc clean-vasm clean-vbcc clean-vlink clean-libnix clean-ixemul clean-clib2 clean-libdebug clean-libpthread clean-newlib clean-ndk clean-gmp clean-mpc clean-mpfr
	rm -rf $(BUILD)
	rm -rf *.log
	mkdir -p $(BUILD)

.PHONY: clean-gcc
clean-gcc:
	rm -rf $(BUILD)/gcc

.PHONY: clean-gmp
clean-gmp:
	rm -rf $(PROJECTS)/gcc/gmp $(PROJECTS)/binutils/gmp

.PHONY: clean-mpc
clean-mpc:
	rm -rf $(PROJECTS)/gcc/mpc

.PHONY: clean-mpfr
clean-mpfr:
	rm -rf $(PROJECTS)/gcc/mpfr $(PROJECTS)/binutils/mpfr

.PHONY: clean-libgcc
clean-libgcc:
	rm -rf $(BUILD)/gcc/$(TARGET)
	rm -rf $(BUILD)/gcc/_libgcc_done

.PHONY: clean-binutils
clean-binutils:
	rm -rf $(BUILD)/binutils

.PHONY: clean-gprof
clean-gprof:
	rm -rf $(BUILD)/binutils/gprof

.PHONY: clean-fd2sfd
clean-fd2sfd:
	rm -rf $(BUILD)/fd2sfd

.PHONY: clean-fd2pragma
clean-fd2pragma:
	rm -rf $(BUILD)/fd2pragma

.PHONY: clean-ira
clean-ira:
	rm -rf $(BUILD)/ira

.PHONY: clean-sfdc
clean-sfdc:
	rm -rf $(BUILD)/sfdc

.PHONY: clean-lha
clean-lha:
	rm -rf $(BUILD)/lha

.PHONY: clean-vasm
clean-vasm:
	rm -rf $(BUILD)/vasm

.PHONY: clean-vbcc
clean-vbcc:
	rm -rf $(BUILD)/vbcc

.PHONY: clean-vlink
clean-vlink:
	rm -rf $(BUILD)/vlink

.PHONY: clean-ndk
clean-ndk:
	rm -rf $(BUILD)/ndk*

.PHONY: clean-libnix
clean-libnix:
	rm -rf $(BUILD)/libnix

.PHONY: clean-ixemul
clean-ixemul:
	rm -rf $(BUILD)/ixemul

.PHONY: clean-clib2
clean-clib2:
	rm -rf $(BUILD)/clib2

.PHONY: clean-libdebug
clean-libdebug:
	rm -rf $(BUILD)/libdebug

.PHONY: clean-libpthread
clean-libpthread:
	rm -rf $(BUILD)/libpthread

.PHONY: clean-newlib
clean-newlib:
	rm -rf $(BUILD)/newlib

# drop-prefix drops the files from prefix folder.  It also removes
# build-machine helpers left by versions predating the build-local prefix.
.PHONY: drop-prefix
drop-prefix:
	rm -rf $(PREFIX)/bin
	rm -rf $(PREFIX)/build-tools
	rm -rf $(PREFIX)/etc
	rm -rf $(PREFIX)/info
	rm -rf $(PREFIX)/libexec
	rm -rf $(PREFIX)/lib/gcc
	rm -rf $(PREFIX)/$(TARGET)
	rm -rf $(PREFIX)/man
	rm -rf $(PREFIX)/share
	@mkdir -p $(PREFIX)/bin

# Package native builds for the build machine and cross builds for the machine
# on which the produced tools run.  PACKAGE_PLATFORM may be overridden for a
# more user-facing platform label without changing the configured HOST.
ifeq (,$(strip $(HOST)))
# short CPU-first cpu-os pair (x86_64-linux, arm64-darwin), stable across
# distros unlike a full config triple; cross/hosted builds use $(HOST) below
PACKAGE_PLATFORM ?= $(shell uname -m)-$(shell uname -s | tr '[:upper:]' '[:lower:]')
else
PACKAGE_PLATFORM ?= $(HOST)
endif
PACKAGE_FORMAT ?= tar.xz
PACKAGE_BASENAME ?= m68k-amigaos-gcc-$(PACKAGE_VERSION)-$(PACKAGE_PLATFORM)
PACKAGE_FILENAME ?= $(PACKAGE_BASENAME).$(PACKAGE_FORMAT)
PACKAGE_LHA ?= lha

.PHONY: package package-lha
package-lha: PACKAGE_FORMAT=lha
package-lha: package

package:
	@test -n "$(GCC_VERSION)" || { echo "GCC_VERSION is empty - run make update first"; exit 1; }
	$(L0)"packaging $(notdir $(PACKAGE_FILENAME))"$(L1) case "$(PACKAGE_FORMAT)" in \
	  tar.xz) \
	    XZ_OPT=-T0 tar -C "$(dir $(abspath $(PREFIX)))" -cJf "$(abspath $(PACKAGE_FILENAME))" "$(notdir $(abspath $(PREFIX)))"; \
	    ;; \
	  lha) \
	    command -v "$(PACKAGE_LHA)" >/dev/null || { echo "$(PACKAGE_LHA) is required for PACKAGE_FORMAT=lha"; exit 1; }; \
	    rm -f "$(abspath $(PACKAGE_FILENAME))"; \
	    cd "$(dir $(abspath $(PREFIX)))" && "$(PACKAGE_LHA)" aq "$(abspath $(PACKAGE_FILENAME))" "$(notdir $(abspath $(PREFIX)))"; \
	    ;; \
	  *) \
	    echo "unsupported PACKAGE_FORMAT=$(PACKAGE_FORMAT); use tar.xz or lha"; \
	    exit 2; \
	    ;; \
	esac $(L2)

# =================================================
# update all projects
# =================================================

.PHONY: update
update: update-gcc update-binutils update-fd2sfd update-lha update-fd2pragma update-ira update-sfdc update-vasm update-vbcc update-vlink update-libnix update-clib2 update-libdebug update-libpthread update-ndk update-newlib update-netinclude

# Each pulls a module checkout forward; see scripts/update-module.
.PHONY: update-gcc
update-gcc: $(PROJECTS)/gcc/configure
	@scripts/update-module $(PROJECTS)/gcc

.PHONY: update-binutils
update-binutils: $(PROJECTS)/binutils/configure
	@scripts/update-module $(PROJECTS)/binutils

.PHONY: update-fd2sfd
update-fd2sfd: $(PROJECTS)/fd2sfd/configure
	@scripts/update-module $(PROJECTS)/fd2sfd

.PHONY: update-lha
update-lha: $(PROJECTS)/lha/configure
	@scripts/update-module $(PROJECTS)/lha

.PHONY: update-fd2pragma
update-fd2pragma: $(PROJECTS)/fd2pragma/makefile
	@scripts/update-module $(PROJECTS)/fd2pragma

.PHONY: update-ira
update-ira: $(PROJECTS)/ira/Makefile
	@scripts/update-module $(PROJECTS)/ira

.PHONY: update-sfdc
update-sfdc: $(PROJECTS)/sfdc/configure
	@scripts/update-module $(PROJECTS)/sfdc

.PHONY: update-vasm
update-vasm: $(PROJECTS)/vasm/Makefile
	@scripts/update-module $(PROJECTS)/vasm

.PHONY: update-vbcc
update-vbcc: $(PROJECTS)/vbcc/Makefile
	@scripts/update-module $(PROJECTS)/vbcc

.PHONY: update-vlink
update-vlink: $(PROJECTS)/vlink/Makefile
	@scripts/update-module $(PROJECTS)/vlink

.PHONY: update-libnix
update-libnix: $(PROJECTS)/libnix/Makefile.gcc6
	@scripts/update-module $(PROJECTS)/libnix

.PHONY: update-clib2
update-clib2: $(PROJECTS)/clib2/LICENSE
	@scripts/update-module $(PROJECTS)/clib2

.PHONY: update-libdebug
update-libdebug: $(PROJECTS)/libdebug/configure
	@scripts/update-module $(PROJECTS)/libdebug

.PHONY: update-libpthread
update-libpthread: $(PROJECTS)/aros-stuff/pthreads/Makefile
	@scripts/update-module $(PROJECTS)/aros-stuff

.PHONY: update-ndk
update-ndk: $(DOWNLOAD)/$(NDK_ARC_NAME).lha

.PHONY: update-newlib
update-newlib: $(PROJECTS)/newlib-cygwin/newlib/configure
	@scripts/update-module $(PROJECTS)/newlib-cygwin

.PHONY: update-netinclude
update-netinclude: $(PROJECTS)/amiga-netinclude/README.md
	@scripts/update-module $(PROJECTS)/amiga-netinclude

.PHONY: gcc-prerequisites
gcc-prerequisites: $(PROJECTS)/$(GMP)/configure $(PROJECTS)/$(MPFR)/configure $(PROJECTS)/$(MPC)/configure

define extract-gcc-prerequisite
	@tmp=$$(mktemp -d "$(PROJECTS)/.$(1).XXXXXX"); \
	trap 'rm -rf "$$tmp"' EXIT; \
	tar -C "$$tmp" -xf $<; \
	if ! mv "$$tmp/$(1)" "$(PROJECTS)/$(1)" 2>/dev/null; then \
		test -x "$(PROJECTS)/$(1)/configure"; \
	fi
endef

$(PROJECTS)/$(GMP)/configure: $(DOWNLOAD)/$(GMPFILE)
	$(call extract-gcc-prerequisite,$(GMP))

$(PROJECTS)/$(MPFR)/configure: $(DOWNLOAD)/$(MPFRFILE)
	$(call extract-gcc-prerequisite,$(MPFR))

$(PROJECTS)/$(MPC)/configure: $(DOWNLOAD)/$(MPCFILE)
	$(call extract-gcc-prerequisite,$(MPC))

# gmp, mpfr and mpc are always built in-tree, so the binaries do not
# depend on the distribution's versions of those libraries: gcc and
# binutils (for gdb) each get a copy in their source tree.  The copies
# are real targets so that every configure sharing a source tree, such
# as the two binutils builds of a Canadian cross, waits for the same
# single copy instead of racing it under make -j.
GCC_PREREQUISITE_SOURCES := $(PROJECTS)/gcc/gmp/configure $(PROJECTS)/gcc/mpfr/configure $(PROJECTS)/gcc/mpc/configure
BINUTILS_PREREQUISITE_SOURCES := $(PROJECTS)/binutils/gmp/configure $(PROJECTS)/binutils/mpfr/configure

$(PROJECTS)/gcc/gmp/configure $(PROJECTS)/binutils/gmp/configure: $(PROJECTS)/$(GMP)/configure
	@mkdir -p $(@D) && rsync -a --no-group --delete $(<D)/ $(@D)

$(PROJECTS)/gcc/mpfr/configure $(PROJECTS)/binutils/mpfr/configure: $(PROJECTS)/$(MPFR)/configure
	@mkdir -p $(@D) && rsync -a --no-group --delete $(<D)/ $(@D)

$(PROJECTS)/gcc/mpc/configure: $(PROJECTS)/$(MPC)/configure
	@mkdir -p $(@D) && rsync -a --no-group --delete $(<D)/ $(@D)

.PHONY: update-gmp
update-gmp:
	@rm -rf $(PROJECTS)/$(GMP) $(PROJECTS)/gcc/gmp $(PROJECTS)/binutils/gmp
	@$(MAKE) --no-print-directory $(PROJECTS)/$(GMP)/configure

.PHONY: update-mpfr
update-mpfr:
	@rm -rf $(PROJECTS)/$(MPFR) $(PROJECTS)/gcc/mpfr $(PROJECTS)/binutils/mpfr
	@$(MAKE) --no-print-directory $(PROJECTS)/$(MPFR)/configure

.PHONY: update-mpc
update-mpc:
	@rm -rf $(PROJECTS)/$(MPC) $(PROJECTS)/gcc/mpc
	@$(MAKE) --no-print-directory $(PROJECTS)/$(MPC)/configure

# =================================================
# binutils
# =================================================
CONFIG_BINUTILS = --prefix=$(PREFIX) --target=$(TARGET) $(HOST_CONFIGURE) $(CONFIG_VERSION) --disable-werror --disable-nls --without-msgpack

# Also read, convert and link m68k ELF objects.  Not on the AmigaOS host,
# where bfd's ELF code does not build: elf-sframe.c assumes uint32_t is
# unsigned int, but there it is unsigned long.
ifeq (,$(findstring amigaos,$(HOST)))
  CONFIG_BINUTILS += --enable-targets=m68k-elf
endif

# Portable release binaries: no libpython, and a static libstdc++ and libgcc
# (the MinGW package ships neither DLL).
CONFIG_BINUTILS += --without-python --without-guile --with-static-standard-libraries

ifneq (,$(findstring mingw,$(HOST)))
  CONFIG_BINUTILS += --enable-plugins
endif

ifneq (,$(findstring amigaos,$(HOST)))
  CONFIG_BINUTILS += --disable-gdb --disable-plugins
endif

ifneq (,$(strip $(HOST)))
  LD_CROSS_MAKE_ENV := bfdplugin_LTLIBRARIES= noinst_LTLIBRARIES=
  LD_CROSS_MAKE_FLAGS := -e
endif

BINUTILS_CMD := $(TARGET)-addr2line $(TARGET)-ar $(TARGET)-as $(TARGET)-c++filt \
	$(TARGET)-ld $(TARGET)-nm $(TARGET)-objcopy $(TARGET)-objdump $(TARGET)-ranlib \
	$(TARGET)-readelf $(TARGET)-size $(TARGET)-strings $(TARGET)-strip
BINUTILS := $(patsubst %,$(PREFIX)/bin/%$(EXEEXT), $(BINUTILS_CMD))
ifneq (,$(strip $(HOST)))
ifeq ($(strip $(HOST)),$(TARGET))
BINUTILS_HOST_ALIAS_CMD := addr2line ar as c++filt elfedit ld ld.bfd nm objcopy objdump ranlib readelf size strings strip
endif
endif

.PHONY: binutils
binutils: $(BUILD)/binutils/_done

$(BUILD)/binutils/_done: $(BUILD)/binutils/Makefile $(shell find 2>/dev/null $(PROJECTS)/binutils -not \( -path $(PROJECTS)/binutils/.git -prune \) -not \( -path $(PROJECTS)/binutils/gprof -prune \) -not \( -path $(PROJECTS)/binutils/gmp -prune \) -not \( -path $(PROJECTS)/binutils/mpfr -prune \) -type f)
	$(L0)"make binutils bfd"$(L1)$(MAKE) -C $(BUILD)/binutils all-bfd $(L2)
	$(L0)"make binutils gas"$(L1)$(MAKE) -C $(BUILD)/binutils all-gas $(L2)
	$(L0)"make binutils binutils"$(L1)$(MAKE) -C $(BUILD)/binutils all-binutils $(L2)
	$(L0)"make binutils ld"$(L1)$(LD_CROSS_MAKE_ENV) $(MAKE) $(LD_CROSS_MAKE_FLAGS) -C $(BUILD)/binutils all-ld $(L2)
	$(L0)"install binutils"$(L1)$(MAKE) -C $(BUILD)/binutils install-strip-gas install-strip-binutils $(L2)
	$(L0)"install binutils ld"$(L1)$(LD_CROSS_MAKE_ENV) $(MAKE) $(LD_CROSS_MAKE_FLAGS) -C $(BUILD)/binutils install-strip-ld $(L2)
	@for tool in $(BINUTILS_HOST_ALIAS_CMD); do \
		ln -f "$(PREFIX)/bin/$$tool$(EXEEXT)" "$(PREFIX)/bin/$(TARGET)-$$tool$(EXEEXT)"; \
	done
	@echo "done" >$@

$(BUILD)/binutils/Makefile: $(PROJECTS)/binutils/configure $(BINUTILS_PREREQUISITE_SOURCES) | $(PREFIX_STAMP)
	@mkdir -p $(BUILD)/binutils
	$(L0)"configure binutils"$(L1) cd $(BUILD)/binutils && $(E) $(PROJECTS)/binutils/configure $(CONFIG_BINUTILS) $(L2)

$(PROJECTS)/binutils/configure:
	@cd $(PROJECTS) && git clone -b $(binutils_BRANCH) --depth 16 $(binutils_URL) binutils

# =================================================
# gdb
# =================================================

.PHONY: gdb
gdb: $(BUILD)/binutils/_gdb

$(BUILD)/binutils/_gdb: $(BUILD)/binutils/_done
	$(L0)"make binutils configure gdb"$(L1)$(MAKE) -C $(BUILD)/binutils configure-gdb $(L2)
	$(L0)"make binutils gdb libs"$(L1)$(MAKE) -C $(BUILD)/binutils/gdb all-lib $(L2)
	$(L0)"make binutils gdb"$(L1)$(MAKE) -C $(BUILD)/binutils all-gdb $(L2)
	$(L0)"install binutils gdb"$(L1)$(MAKE) -C $(BUILD)/binutils install-strip-gas install-strip-binutils install-strip-gdb $(L2)
	$(L0)"install binutils ld"$(L1)$(LD_CROSS_MAKE_ENV) $(MAKE) $(LD_CROSS_MAKE_FLAGS) -C $(BUILD)/binutils install-strip-ld $(L2)
	@echo "done" >$@

# =================================================
# gprof
# =================================================
CONFIG_GPROF := --prefix=$(PREFIX) --target=$(TARGET) $(HOST_CONFIGURE) $(CONFIG_VERSION) --disable-werror

.PHONY: gprof
gprof: $(BUILD)/binutils/_gprof

$(BUILD)/binutils/_gprof: $(BUILD)/binutils/gprof/Makefile $(shell find 2>/dev/null $(PROJECTS)/binutils/gprof -type f)
	$(L0)"make gprof"$(L1)$(MAKE) -C $(BUILD)/binutils/gprof all $(L2)
	$(L0)"install gprof"$(L1)$(MAKE) -C $(BUILD)/binutils/gprof install $(L2)
	@echo "done" >$@

$(BUILD)/binutils/gprof/Makefile: $(PROJECTS)/binutils/configure $(BUILD)/binutils/_done
	@mkdir -p $(BUILD)/binutils/gprof
	$(L0)"configure gprof"$(L1) cd $(BUILD)/binutils/gprof && $(E) $(PROJECTS)/binutils/gprof/configure $(CONFIG_GPROF) $(L2)

# =================================================
# gcc
# =================================================
CONFIG_GCC = --prefix=$(PREFIX) --target=$(TARGET) $(HOST_CONFIGURE) $(CONFIG_VERSION) --enable-languages=c,c++,objc,$(ADDLANG) --enable-version-specific-runtime-libs --disable-libssp --disable-nls --without-zstd  \
	--disable-shared --enable-threads=$(THREADS)
# m68k has no __float128, so libquadmath's configure decides to build
# nothing; skip its 14 multilib configure runs.
CONFIG_GCC += --disable-libquadmath
# libstdc++: no experimental filesystem TS, and only the "C" locale.
CONFIG_GCC += --disable-libstdcxx-filesystem-ts --enable-clocale=generic
ifeq (,$(filter 6.%,$(GCC_VERSION)))
CONFIG_GCC += --with-gcc-major-version-only
endif

ifneq ($(strip $(HOST)),$(TARGET))
CONFIG_GCC += --with-headers=$(PROJECTS)/newlib-cygwin/newlib/libc/sys/amigaos/include/
endif

ifneq (,$(findstring mingw,$(HOST)))
# A MinGW-hosted compiler run through Wine canonicalizes Unix system-header
# paths to Z:/... in dependency files.  Those drive-letter paths are not valid
# prerequisites for the Unix make process building the target libraries.
# Also omit libstdc++'s prebuilt standard-header files: their output paths
# exceed the Windows path limit in deep CI workspaces.  This does not disable
# PCH support in the compiler itself.
CONFIG_GCC += --disable-canonical-system-headers --disable-libstdcxx-pch
endif

ifeq (,$(strip $(HOST)))
CONFIG_GCC += --with-stage1-ldflags="-dynamic-libgcc -dynamic-libstdc++" --with-boot-ldflags="-dynamic-libgcc -dynamic-libstdc++"
else
CONFIG_GCC += --disable-werror
endif
ifneq (,$(findstring amigaos,$(HOST)))
# AmigaOS cannot load shared objects: skip libcc1 (gdb's compile plugin).
# GCC leaves out lto-plugin by itself and keeps lto1/lto-wrapper, so -flto
# still works.  Host programs are static anyway; don't add
# -static-libstdc++ -static-libgcc to their links.
CONFIG_GCC += --disable-libcc1 --without-static-standard-libraries
# The bootstrap toolchain may predate C++ linkage fixes in the AmigaOS
# headers, and older libnix versions (including the bootstrap image's)
# declare popen/pclose without a usable pair; GCC uses them only in a
# debugging helper.  Keep GCC's optional host probes from enabling those
# paths; this affects only the compiler executables that run on HOST.
GCC_HOST_CONFIGURE_ENV := host_configargs="ac_cv_func_clock_gettime=no ac_cv_func_getrlimit=no ac_cv_func_pclose=no ac_cv_func_popen=no ac_cv_func_setrlimit=no"
endif

GCC_CMD := $(TARGET)-c++ $(TARGET)-g++ $(TARGET)-gcc-$(GCC_DIR_VERSION) $(TARGET)-gcc-nm \
	$(TARGET)-gcov $(TARGET)-gcov-tool $(TARGET)-cpp $(TARGET)-gcc $(TARGET)-gcc-ar \
	$(TARGET)-gcc-ranlib $(TARGET)-gcov-dump
GCC := $(patsubst %,$(PREFIX)/bin/%$(EXEEXT), $(GCC_CMD))
ifneq (,$(strip $(HOST)))
ifeq ($(strip $(HOST)),$(TARGET))
GCC_HOST_ALIAS_CMD := c++ g++ cpp gcc gcc-ar gcc-nm gcc-ranlib gcov gcov-dump gcov-tool
endif
endif

ifneq (,$(strip $(HOST_TOOL_PREFIX)))
GCC_HOST_TOOLS := AR="$(HOST_TOOL_PREFIX)ar" AS="$(HOST_TOOL_PREFIX)as" \
	LD="$(HOST_TOOL_PREFIX)ld" NM="$(HOST_TOOL_PREFIX)nm" \
	OBJCOPY="$(HOST_TOOL_PREFIX)objcopy" OBJDUMP="$(HOST_TOOL_PREFIX)objdump" \
	RANLIB="$(HOST_TOOL_PREFIX)ranlib" READELF="$(HOST_TOOL_PREFIX)readelf" \
	STRIP="$(HOST_TOOL_PREFIX)strip"
endif
ifneq (,$(strip $(HOST)))
GCC_BUILD_MAKE_FLAGS := CFLAGS_FOR_BUILD="$(BUILD_CFLAGS)" CXXFLAGS_FOR_BUILD="$(BUILD_CXXFLAGS)" LDFLAGS_FOR_BUILD="$(BUILD_LDFLAGS)"
# GCC's EXTRA_BUILD_FLAGS overrides the host flags propagated through
# BASE_FLAGS_TO_PASS when recursing into build-machine C++ libraries.  GCC 16
# otherwise compiles build-libcpp with HOST CXXFLAGS (for example -mcrt=nix20)
# even though it correctly selects CXX_FOR_BUILD as the compiler.
GCC_BUILD_MAKE_FLAGS += EXTRA_BUILD_FLAGS='CFLAGS="$(BUILD_CFLAGS)" CXXFLAGS="$(BUILD_CXXFLAGS)" LDFLAGS="$(BUILD_LDFLAGS)"'
GCC_FOR_TARGET_BUILD := $(TARGET_CC_COMMAND_FOR_BUILD)
ifneq (,$(strip $(TARGET_RUNNER_WRAPPER_DIR)))
# GCC's Canadian-cross top-level make defaults GCC_FOR_TARGET to the installed
# target compiler.  It is not installed until install-gcc, so run the hosted
# driver from GCC's build directory while all-gcc creates its specs instead.
GCC_FOR_TARGET_BUILD := $(HOST_RUNNER) ./xgcc$(EXEEXT) -B./ \
	-B$(PREFIX)/$(TARGET)/bin/ -isystem $(PREFIX)/$(TARGET)/include \
	-isystem $(PREFIX)/$(TARGET)/sys-include -L$(BUILD)/gcc/ld
endif
ifneq (,$(strip $(GCC_FOR_TARGET_BUILD)))
GCC_BUILD_MAKE_FLAGS += GCC_FOR_TARGET="$(GCC_FOR_TARGET_BUILD)"
endif
ifneq (,$(filter 6.%,$(GCC_VERSION)))
# GCC 16 defaults to C++17, which cannot parse GCC 6's libstdc++ headers.
# Put a same-named wrapper first in PATH only while building target libraries.
# Supplying -std=gnu++98 in CXX_FOR_TARGET makes GCC move it to the end of
# CXXFLAGS_FOR_TARGET, after libstdc++'s per-directory -std=gnu++11.  A PATH
# wrapper supplies the baseline first, so those later source-specific flags win.
TARGET_CXX_FOR_BUILD ?= $(shell command -v $(TARGET)-c++ 2>/dev/null)
GCC6_TARGET_CXX_WRAPPER_DIR := $(BUILD_TOOLS)/gcc6/bin
GCC6_TARGET_CXX_WRAPPER := $(GCC6_TARGET_CXX_WRAPPER_DIR)/$(TARGET)-c++
GCC_TARGET_MAKE_FLAGS += PATH="$(GCC6_TARGET_CXX_WRAPPER_DIR):$(PATH)"
GCC_TARGET_PREREQ += $(GCC6_TARGET_CXX_WRAPPER)
endif
GCC_TARGET_PREREQ += $(TARGET_EXEC_WRAPPERS) $(TARGET_COMPILER_WRAPPERS) $(TARGET_PREFIXED_EXEC_WRAPPERS)
ifneq (,$(strip $(GCC_FOR_TARGET_BUILD)))
GCC_TARGET_MAKE_FLAGS += GCC_FOR_TARGET="$(GCC_FOR_TARGET_BUILD)" \
	CC_FOR_TARGET="$(TARGET_CC_COMMAND_FOR_BUILD)" \
	CXX_FOR_TARGET="$(TARGET_CXX_COMMAND_FOR_BUILD)" \
	AR_FOR_TARGET="$(TARGET_AR_FOR_BUILD)" \
	RANLIB_FOR_TARGET="$(TARGET_RANLIB_FOR_BUILD)"
ifneq (,$(strip $(TARGET_RUNNER_WRAPPER_DIR)))
# GCC discovers the remaining target tools by running the hosted compiler.
# A Windows compiler prints CRLF-terminated Z:/ paths, which the Unix parent
# make cannot execute.  Keep every directly invoked target tool behind the
# HOST_RUNNER wrappers; use GCC's archive wrappers so LTO plugin handling is
# retained.
GCC_TARGET_CONFIGURE_ENV := \
	AR_FOR_TARGET="$(TARGET_RUNNER_WRAPPER_DIR)/$(TARGET)-ar" \
	AS_FOR_TARGET="$(TARGET_RUNNER_WRAPPER_DIR)/$(TARGET)-as" \
	LD_FOR_TARGET="$(TARGET_RUNNER_WRAPPER_DIR)/$(TARGET)-ld" \
	NM_FOR_TARGET="$(TARGET_RUNNER_WRAPPER_DIR)/$(TARGET)-nm" \
	OBJCOPY_FOR_TARGET="$(TARGET_RUNNER_WRAPPER_DIR)/$(TARGET)-objcopy" \
	OBJDUMP_FOR_TARGET="$(TARGET_RUNNER_WRAPPER_DIR)/$(TARGET)-objdump" \
	RANLIB_FOR_TARGET="$(TARGET_RUNNER_WRAPPER_DIR)/$(TARGET)-ranlib" \
	READELF_FOR_TARGET="$(TARGET_RUNNER_WRAPPER_DIR)/$(TARGET)-readelf" \
	STRIP_FOR_TARGET="$(TARGET_RUNNER_WRAPPER_DIR)/$(TARGET)-strip"
GCC_TARGET_TOOL_ENV := \
	AR_FOR_TARGET="$(TARGET_RUNNER_WRAPPER_DIR)/$(TARGET)-gcc-ar" \
	AS_FOR_TARGET="$(TARGET_RUNNER_WRAPPER_DIR)/$(TARGET)-as" \
	LD_FOR_TARGET="$(TARGET_RUNNER_WRAPPER_DIR)/$(TARGET)-ld" \
	NM_FOR_TARGET="$(TARGET_RUNNER_WRAPPER_DIR)/$(TARGET)-gcc-nm" \
	OBJCOPY_FOR_TARGET="$(TARGET_RUNNER_WRAPPER_DIR)/$(TARGET)-objcopy" \
	OBJDUMP_FOR_TARGET="$(TARGET_RUNNER_WRAPPER_DIR)/$(TARGET)-objdump" \
	RANLIB_FOR_TARGET="$(TARGET_RUNNER_WRAPPER_DIR)/$(TARGET)-gcc-ranlib" \
	READELF_FOR_TARGET="$(TARGET_RUNNER_WRAPPER_DIR)/$(TARGET)-readelf" \
	STRIP_FOR_TARGET="$(TARGET_RUNNER_WRAPPER_DIR)/$(TARGET)-strip"
GCC_TARGET_MAKE_FLAGS += $(GCC_TARGET_TOOL_ENV)
endif
endif
endif

ifneq (,$(strip $(GCC6_TARGET_CXX_WRAPPER)))
# A hosted build puts a wrapper named $(TARGET)-c++ first in PATH
# (TARGET_COMPILER_WRAPPER_DIR) which adds -B$(PREFIX)/lib/gcc/$(TARGET)/
# $(GCC_DIR_VERSION)/, so libstdc++ finds the unwind.h that
# install-target-libgcc put there.  This wrapper shadows that one, and the
# raw build-to-target g++ has no libgcc installed: exec the -B wrapper when
# there is one.  A native build has none and keeps the raw compiler.
$(GCC6_TARGET_CXX_WRAPPER): $(BUILD)/gcc/_done $(TARGET_COMPILER_WRAPPERS)
	@mkdir -p $(@D)
	@test -n "$(TARGET_CXX_FOR_BUILD)"
	@printf '%s\n' '#!/bin/sh' 'exec "$(or $(TARGET_CXX_COMMAND_FOR_BUILD),$(TARGET_CXX_FOR_BUILD))" -std=gnu++98 "$$@"' > $@
	@chmod +x $@
endif

GCC_DIR := . gcc gcc/c gcc/c-family gcc/cp gcc/objc gcc/config/m68k libiberty libcpp libdecnumber
GCCD := $(patsubst %,$(PROJECTS)/gcc/%, $(GCC_DIR))

.PHONY: gcc
gcc: $(BUILD)/gcc/_done

$(BUILD)/gcc/_done: $(BUILD)/gcc/Makefile $(shell find 2>/dev/null $(GCCD) -maxdepth 1 -type f ) $(HOST_RUNNER_SETUP_PREREQ) $(TARGET_RUNNER_WRAPPERS)
	$(L0)"make gcc"$(L1) $(MAKE) -C $(BUILD)/gcc $(GCC_HOST_TOOLS) $(GCC_BUILD_MAKE_FLAGS) all-gcc $(L2)
	$(L0)"install gcc"$(L1) $(MAKE) -C $(BUILD)/gcc $(GCC_HOST_TOOLS) $(GCC_BUILD_MAKE_FLAGS) install-strip-gcc $(L2)
	for tool in $(GCC_HOST_ALIAS_CMD); do \
		ln -f "$(PREFIX)/bin/$$tool$(EXEEXT)" "$(PREFIX)/bin/$(TARGET)-$$tool$(EXEEXT)"; \
	done
	echo "done" >$@

$(BUILD)/gcc/Makefile: Makefile $(PROJECTS)/gcc/configure $(BUILD)/binutils/_done $(GCC_PREREQUISITE_SOURCES) $(TARGET_RUNNER_WRAPPERS) $(TARGET_BUILD_TOOLS_PREREQ) $(TARGET_EXEC_WRAPPERS) $(TARGET_COMPILER_WRAPPERS) $(TARGET_PREFIXED_EXEC_WRAPPERS) | $(PREFIX_STAMP)
	mkdir -p $(BUILD)/gcc
	$(L0)"configure gcc"$(L1) cd $(BUILD)/gcc && $(E) $(GCC_HOST_TOOLS) $(GCC_HOST_CONFIGURE_ENV) $(GCC_TARGET_CONFIGURE_ENV) $(PROJECTS)/gcc/configure $(CONFIG_GCC) $(L2)

$(PROJECTS)/gcc/configure:
	@cd $(PROJECTS) && git clone -b $(gcc_BRANCH) --depth 16 $(gcc_URL)

ifneq (,$(strip $(TARGET_BUILD_TOOLS_PREREQ)))
TARGET_BUILD_MACHINE := $(if $(strip $(BUILD_TRIPLET)),$(BUILD_TRIPLET),$(shell $(BUILD_CC) -dumpmachine 2>/dev/null))
TARGET_BUILD_TOOL_PREFIX := $(TARGET_BUILD_MACHINE)-
TARGET_BUILD_TOOLS_ENV := CC="$(BUILD_CC)" CXX="$(BUILD_CXX)" \
	CC_FOR_BUILD="$(BUILD_CC)" CXX_FOR_BUILD="$(BUILD_CXX)" \
	AR="$(TARGET_BUILD_TOOL_PREFIX)ar" AS="$(TARGET_BUILD_TOOL_PREFIX)as" \
	LD="$(TARGET_BUILD_TOOL_PREFIX)ld" NM="$(TARGET_BUILD_TOOL_PREFIX)nm" \
	OBJCOPY="$(TARGET_BUILD_TOOL_PREFIX)objcopy" OBJDUMP="$(TARGET_BUILD_TOOL_PREFIX)objdump" \
	RANLIB="$(TARGET_BUILD_TOOL_PREFIX)ranlib" READELF="$(TARGET_BUILD_TOOL_PREFIX)readelf" \
	STRIP="$(TARGET_BUILD_TOOL_PREFIX)strip" \
	PATH="$(TARGET_BUILD_TOOLS_PREFIX)/bin:$(PATH)"
TARGET_BUILD_BINUTILS_CONFIG := --prefix=$(TARGET_BUILD_TOOLS_PREFIX) \
	--build=$(TARGET_BUILD_MACHINE) --host=$(TARGET_BUILD_MACHINE) \
	--target=$(TARGET) --disable-werror --disable-nls --without-msgpack \
	--disable-gdb --disable-gdbserver --enable-plugins
TARGET_BUILD_GCC_CONFIG := --prefix=$(TARGET_BUILD_TOOLS_PREFIX) \
	--build=$(TARGET_BUILD_MACHINE) --host=$(TARGET_BUILD_MACHINE) \
	--target=$(TARGET) --enable-languages=c,c++,objc,$(ADDLANG) \
	--enable-version-specific-runtime-libs --enable-lto \
	--disable-bootstrap --disable-libssp --disable-nls --without-zstd \
	--disable-shared --disable-werror --enable-threads=$(THREADS) \
	--with-headers=$(PROJECTS)/newlib-cygwin/newlib/libc/sys/amigaos/include/ \
	--with-build-time-tools=$(TARGET_BUILD_TOOLS_PREFIX)/$(TARGET)/bin \
	--with-gmp=/usr --with-mpfr=/usr --with-mpc=/usr

$(TARGET_BUILD_TOOLS_PREREQ): $(TARGET_BUILD_TOOLS_BUILD)/gcc/_done
	@touch $@

$(TARGET_BUILD_TOOLS_BUILD)/binutils/_done: $(TARGET_BUILD_TOOLS_BUILD)/binutils/Makefile
	$(L0)"make build-to-target binutils"$(L1) $(TARGET_BUILD_TOOLS_ENV) $(MAKE) -C $(TARGET_BUILD_TOOLS_BUILD)/binutils all-gas all-binutils all-ld $(L2)
	$(L0)"install build-to-target binutils"$(L1) $(TARGET_BUILD_TOOLS_ENV) $(MAKE) -C $(TARGET_BUILD_TOOLS_BUILD)/binutils install-gas install-binutils install-ld $(L2)
	@touch $@

$(TARGET_BUILD_TOOLS_BUILD)/binutils/Makefile: Makefile $(PROJECTS)/binutils/configure $(BINUTILS_PREREQUISITE_SOURCES)
	@mkdir -p $(@D)
	$(L0)"configure build-to-target binutils"$(L1) cd $(@D) && $(E) $(TARGET_BUILD_TOOLS_ENV) $(PROJECTS)/binutils/configure $(TARGET_BUILD_BINUTILS_CONFIG) $(L2)

$(TARGET_BUILD_TOOLS_BUILD)/gcc/_done: $(TARGET_BUILD_TOOLS_BUILD)/gcc/Makefile $(TARGET_BUILD_TOOLS_BUILD)/binutils/_done
	$(L0)"make build-to-target gcc"$(L1) $(TARGET_BUILD_TOOLS_ENV) $(MAKE) -C $(TARGET_BUILD_TOOLS_BUILD)/gcc all-gcc $(L2)
	$(L0)"install build-to-target gcc"$(L1) $(TARGET_BUILD_TOOLS_ENV) $(MAKE) -C $(TARGET_BUILD_TOOLS_BUILD)/gcc install-gcc $(L2)
	@if [ -d "$(TARGET_BUILD_TOOLS_PREFIX)/$(TARGET)/sys-include" ] && [ ! -L "$(TARGET_BUILD_TOOLS_PREFIX)/$(TARGET)/sys-include" ]; then \
		mv "$(TARGET_BUILD_TOOLS_PREFIX)/$(TARGET)/sys-include" "$(TARGET_BUILD_TOOLS_PREFIX)/$(TARGET)/bootstrap-sys-include"; \
	fi
	@for dir in include sys-include ndk-include ndk13-include libnix ixemul clib2; do \
		ln -sfn "$(PREFIX)/$(TARGET)/$$dir" "$(TARGET_BUILD_TOOLS_PREFIX)/$(TARGET)/$$dir"; \
	done
	@touch $@

$(TARGET_BUILD_TOOLS_BUILD)/gcc/Makefile: Makefile $(PROJECTS)/gcc/configure $(PROJECTS)/newlib-cygwin/newlib/configure $(TARGET_BUILD_TOOLS_BUILD)/binutils/_done
	@mkdir -p $(@D)
	$(L0)"configure build-to-target gcc"$(L1) cd $(@D) && $(E) $(TARGET_BUILD_TOOLS_ENV) $(PROJECTS)/gcc/configure $(TARGET_BUILD_GCC_CONFIG) $(L2)
endif

# =================================================
# fd2sfd
# =================================================
CONFIG_FD2SFD := --prefix=$(PREFIX) --target=$(TARGET) $(HOST_CONFIGURE)
ifneq (,$(strip $(HOST)))
FD2SFD_INSTALL_ARGS := INSTALL_PROGRAM="install --strip-program=$(HOST)-strip"
FD2SFD_BUILD_PREREQ := $(BUILD_TOOLS)/fd2sfd/_done
endif

.PHONY: fd2sfd
fd2sfd: $(BUILD)/fd2sfd/_done $(FD2SFD_BUILD_PREREQ)

$(BUILD)/fd2sfd/_done: $(PREFIX)/bin/fd2sfd$(EXEEXT)
	@echo "done" >$@

$(PREFIX)/bin/fd2sfd$(EXEEXT): $(BUILD)/fd2sfd/Makefile $(shell find 2>/dev/null $(PROJECTS)/fd2sfd -not \( -path $(PROJECTS)/fd2sfd/.git -prune \) -type f)
	$(L0)"make fd2sfd"$(L1) $(MAKE) -C $(BUILD)/fd2sfd all $(L2)
	@mkdir -p $(PREFIX)/bin/
	$(L0)"install fd2sfd"$(L1) $(MAKE) -C $(BUILD)/fd2sfd install $(FD2SFD_INSTALL_ARGS) $(L2)

$(BUILD)/fd2sfd/Makefile: $(PROJECTS)/fd2sfd/configure
	@mkdir -p $(BUILD)/fd2sfd
	$(L0)"configure fd2sfd"$(L1) cd $(BUILD)/fd2sfd && $(E) $(PROJECTS)/fd2sfd/configure $(CONFIG_FD2SFD) $(L2)

$(BUILD_TOOLS)/fd2sfd/_done: $(BUILD_TOOLS_PREFIX)/bin/fd2sfd
	@echo "done" >$@

$(BUILD_TOOLS_PREFIX)/bin/fd2sfd: $(BUILD_TOOLS)/fd2sfd/Makefile $(shell find 2>/dev/null $(PROJECTS)/fd2sfd -not \( -path $(PROJECTS)/fd2sfd/.git -prune \) -type f)
	$(L0)"make fd2sfd for the build machine"$(L1) $(MAKE) -C $(BUILD_TOOLS)/fd2sfd all CC="$(BUILD_CC)" CFLAGS="$(BUILD_CFLAGS)" $(L2)
	@mkdir -p $(BUILD_TOOLS_PREFIX)/bin
	$(L0)"install build-machine fd2sfd"$(L1) $(MAKE) -C $(BUILD_TOOLS)/fd2sfd install $(L2)

$(BUILD_TOOLS)/fd2sfd/Makefile: $(PROJECTS)/fd2sfd/configure
	@mkdir -p $(BUILD_TOOLS)/fd2sfd
	$(L0)"configure fd2sfd for the build machine"$(L1) cd $(BUILD_TOOLS)/fd2sfd && CC="$(BUILD_CC)" CFLAGS="$(BUILD_CFLAGS)" $(PROJECTS)/fd2sfd/configure --prefix=$(BUILD_TOOLS_PREFIX) --target=$(TARGET) $(L2)

$(PROJECTS)/fd2sfd/configure:
	@cd $(PROJECTS) && git clone -b $(fd2sfd_BRANCH) --depth 4 $(fd2sfd_URL)

# =================================================
# fd2pragma
# =================================================
ifneq (,$(findstring amigaos,$(HOST)))
FD2PRAGMA_TARGET_CFLAGS := -DFD2PRAGMA_READARGS
endif

ifneq (,$(strip $(HOST)))
FD2PRAGMA_BUILD_PREREQ := $(BUILD_TOOLS)/fd2pragma/_done
endif

.PHONY: fd2pragma
fd2pragma: $(BUILD)/fd2pragma/_done $(FD2PRAGMA_BUILD_PREREQ)

$(BUILD)/fd2pragma/_done: $(PREFIX)/bin/fd2pragma$(EXEEXT)
	@echo "done" >$@

$(PREFIX)/bin/fd2pragma$(EXEEXT): $(BUILD)/fd2pragma/fd2pragma$(EXEEXT)
	@mkdir -p $(PREFIX)/bin/
	$(L0)"install fd2pragma"$(L1) install $(BUILD)/fd2pragma/fd2pragma$(EXEEXT) $(PREFIX)/bin/ $(L2)

$(BUILD)/fd2pragma/fd2pragma$(EXEEXT): $(PROJECTS)/fd2pragma/makefile $(shell find 2>/dev/null $(PROJECTS)/fd2pragma -not \( -path $(PROJECTS)/fd2pragma/.git -prune \) -type f)
	@mkdir -p $(BUILD)/fd2pragma
	$(L0)"make fd2pragma for $(if $(HOST),$(HOST),the build host)"$(L1) cd $(PROJECTS)/fd2pragma && $(CC) -o $@ $(CFLAGS) $(FD2PRAGMA_TARGET_CFLAGS) fd2pragma.c $(LDFLAGS) $(L2)

$(BUILD_TOOLS)/fd2pragma/_done: $(BUILD_TOOLS)/fd2pragma/fd2pragma
	@mkdir -p $(BUILD_TOOLS_PREFIX)/bin
	$(L0)"install build-machine fd2pragma"$(L1) install $< $(BUILD_TOOLS_PREFIX)/bin/ $(L2)
	@echo "done" >$@

$(BUILD_TOOLS)/fd2pragma/fd2pragma: $(PROJECTS)/fd2pragma/makefile $(shell find 2>/dev/null $(PROJECTS)/fd2pragma -not \( -path $(PROJECTS)/fd2pragma/.git -prune \) -type f)
	@mkdir -p $(@D)
	$(L0)"make fd2pragma for the build machine"$(L1) cd $(PROJECTS)/fd2pragma && $(BUILD_CC) -o $@ $(BUILD_CFLAGS) fd2pragma.c $(L2)

$(PROJECTS)/fd2pragma/makefile:
	@cd $(PROJECTS) && git clone -b $(fd2pragma_BRANCH) --depth 4 $(fd2pragma_URL)

# =================================================
# ira
# =================================================
.PHONY: ira
ira: $(BUILD)/ira/_done

$(BUILD)/ira/_done: $(PREFIX)/bin/ira$(EXEEXT)
	@echo "done" >$@

$(PREFIX)/bin/ira$(EXEEXT): $(BUILD)/ira/ira$(EXEEXT)
	@mkdir -p $(PREFIX)/bin/
	$(L0)"install ira"$(L1) install $(BUILD)/ira/ira$(EXEEXT) $(PREFIX)/bin/ $(L2)

$(BUILD)/ira/ira$(EXEEXT): $(PROJECTS)/ira/Makefile $(shell find 2>/dev/null $(PROJECTS)/ira -not \( -path $(PROJECTS)/ira/.git -prune \) -type f)
	@mkdir -p $(BUILD)/ira
	$(L0)"make ira"$(L1) cd $(PROJECTS)/ira && $(CC) -o $@ $(CFLAGS) *.c -std=c99 $(LDFLAGS) $(L2)

$(PROJECTS)/ira/Makefile:
	@cd $(PROJECTS) && git clone -b $(ira_BRANCH) --depth 4 $(ira_URL)

# =================================================
# sfdc
# =================================================
CONFIG_SFDC := --prefix=$(PREFIX) --target=$(TARGET)

.PHONY: sfdc
sfdc: $(BUILD)/sfdc/_done

$(BUILD)/sfdc/_done: $(PREFIX)/bin/sfdc
	@echo "done" >$@

$(PREFIX)/bin/sfdc: $(BUILD)/sfdc/Makefile
	$(L0)"make sfdc"$(L1) $(MAKE) -C $(BUILD)/sfdc sfdc $(L2)
	@mkdir -p $(PREFIX)/bin/
	$(L0)"install sfdc"$(L1) install $(BUILD)/sfdc/sfdc $(PREFIX)/bin $(L2)

$(BUILD)/sfdc/Makefile: $(PROJECTS)/sfdc/configure $(shell find 2>/dev/null $(PROJECTS)/sfdc -not \( -path $(PROJECTS)/sfdc/.git -prune \)  -type f)
	@rsync -a --no-group $(PROJECTS)/sfdc $(BUILD)/ --exclude .git
	$(L0)"configure sfdc"$(L1) cd $(BUILD)/sfdc && $(E) $(BUILD)/sfdc/configure $(CONFIG_SFDC) $(L2)

$(PROJECTS)/sfdc/configure:
	@cd $(PROJECTS) && git clone -b $(sfdc_BRANCH) --depth 4 $(sfdc_URL)

# =================================================
# vasm
# =================================================
VASM_CMD := vasmm68k_mot
VASM := $(patsubst %,$(PREFIX)/bin/%$(EXEEXT), $(VASM_CMD))
VASM_OUTFMTS := -DOUTAOUT -DOUTBIN -DOUTELF -DOUTGST -DOUTHANS -DOUTHUNK -DOUTIHEX -DOUTO65 -DOUTPAP -DOUTSREC -DOUTTOS -DOUTVOBJ -DOUTWOZ -DOUTXFIL

ifneq (,$(findstring amigaos,$(HOST)))
VASM_TARGET_MAKEFILE := Makefile.68k
VASM_TARGET_MAKE_ARGS := CC="$(CC)" LD="$(CC)" CCOUT="-o " CFLAGS="-c -O2 $(HOST_CPU_FLAGS) $(HOST_CRT_FLAGS) -DAMIGA $(VASM_OUTFMTS)" LDFLAGS="-lm $(LDFLAGS)" TARGET= TARGETEXTENSION=$(EXEEXT)
else ifneq (,$(strip $(HOST)))
VASM_TARGET_MAKEFILE := Makefile
VASM_TARGET_MAKE_ARGS := CC="$(CC)" LD="$(CC)"
else
VASM_TARGET_MAKEFILE := Makefile
VASM_TARGET_MAKE_ARGS :=
endif

ifneq (,$(strip $(HOST)))
VASM_BUILD_PREREQ := $(BUILD_TOOLS)/vasm/_done
endif

.PHONY: vasm
vasm: $(BUILD)/vasm/_done $(VASM_BUILD_PREREQ)

$(BUILD)/vasm/_done: $(BUILD)/vasm/Makefile
	$(L0)"make vasm for $(if $(HOST),$(HOST),the build host)"$(L1) $(MAKE) -C $(BUILD)/vasm -f $(VASM_TARGET_MAKEFILE) CPU=m68k SYNTAX=mot $(VASM_TARGET_MAKE_ARGS) $(L2)
	@mkdir -p $(PREFIX)/bin/
	$(L0)"install vasm"$(L1) install $(BUILD)/vasm/vasmm68k_mot$(EXEEXT) $(PREFIX)/bin/ ;\
	install $(BUILD)/vasm/vobjdump$(EXEEXT) $(PREFIX)/bin/ $(L2)
	@echo "done" >$@

$(BUILD)/vasm/Makefile: $(PROJECTS)/vasm/Makefile $(shell find 2>/dev/null $(PROJECTS)/vasm -not \( -path $(PROJECTS)/vasm/.git -prune \) -type f)
	@rsync -a --no-group $(PROJECTS)/vasm $(BUILD)/ --exclude .git
	@touch $(BUILD)/vasm/Makefile

$(BUILD_TOOLS)/vasm/_done: $(BUILD_TOOLS)/vasm/Makefile
	$(L0)"make vasm for the build machine"$(L1) $(MAKE) -C $(BUILD_TOOLS)/vasm CPU=m68k SYNTAX=mot CC="$(BUILD_CC)" LD="$(BUILD_CC)" $(L2)
	@mkdir -p $(BUILD_TOOLS_PREFIX)/bin
	$(L0)"install build-machine vasm"$(L1) install $(BUILD_TOOLS)/vasm/vasmm68k_mot $(BUILD_TOOLS_PREFIX)/bin/ ;\
	install $(BUILD_TOOLS)/vasm/vobjdump $(BUILD_TOOLS_PREFIX)/bin/ $(L2)
	@echo "done" >$@

$(BUILD_TOOLS)/vasm/Makefile: $(PROJECTS)/vasm/Makefile $(shell find 2>/dev/null $(PROJECTS)/vasm -not \( -path $(PROJECTS)/vasm/.git -prune \) -type f)
	@mkdir -p $(BUILD_TOOLS)
	@rsync -a --no-group $(PROJECTS)/vasm $(BUILD_TOOLS)/ --exclude .git
	@touch $(BUILD_TOOLS)/vasm/Makefile

$(PROJECTS)/vasm/Makefile:
	@cd $(PROJECTS) && git clone -b $(vasm_BRANCH) --depth 4 $(vasm_URL)

# =================================================
# vbcc
# =================================================
VBCC_CMD := vbccm68k vprof vc
VBCC := $(patsubst %,$(PREFIX)/bin/%$(EXEEXT), $(VBCC_CMD))

vbcc: $(BUILD)/vbcc/_done

$(BUILD)/vbcc/_done: $(BUILD)/vbcc/Makefile
	$(L0)"make vbcc dtgen"$(L1) TARGET=m68k $(MAKE) -C $(BUILD)/vbcc bin/dtgen $(L2)
	@cd $(BUILD)/vbcc && echo -e "y\\ny\\nsigned char\\ny\\nunsigned char\\nn\\ny\\nsigned short\\nn\\ny\\nunsigned short\\nn\\ny\\nsigned int\\nn\\ny\\nunsigned int\\nn\\ny\\nsigned long long\\nn\\ny\\nunsigned long long\\nn\\ny\\nfloat\\nn\\ny\\ndouble\\n" >c.txt
	$(L0)"run vbcc dtgen"$(L1) cd $(BUILD)/vbcc && mkdir -p objects/m68k && bin/dtgen machines/m68k/machine.dt objects/m68k/dt.h objects/m68k/dt.c <c.txt $(L2)
	$(L0)"make vbcc"$(L1) TARGET=m68k $(MAKE) -C $(BUILD)/vbcc $(L2)
	@mkdir -p $(PREFIX)/bin/
	@rm -rf $(BUILD)/vbcc/bin/*.dSYM
	$(L0)"install vbcc"$(L1) install $(BUILD)/vbcc/bin/v* $(PREFIX)/bin/ $(L2)
	@echo "done" >$@

$(BUILD)/vbcc/Makefile: $(PROJECTS)/vbcc/Makefile $(shell find 2>/dev/null $(PROJECTS)/vbcc -not \( -path $(PROJECTS)/vbcc/.git -prune \) -type f)
	@rsync -a --no-group $(PROJECTS)/vbcc $(BUILD)/ --exclude .git
	@mkdir -p $(BUILD)/vbcc/bin
	@touch $(BUILD)/vbcc/Makefile

$(PROJECTS)/vbcc/Makefile:
	@cd $(PROJECTS) && git clone -b $(vbcc_BRANCH) --depth 4 $(vbcc_URL)

# =================================================
# vlink
# =================================================
VLINK_CMD := vlink
VLINK := $(patsubst %,$(PREFIX)/bin/%$(EXEEXT), $(VLINK_CMD))

vlink: $(BUILD)/vlink/_done vbcc-target

$(BUILD)/vlink/_done: $(BUILD)/vlink/Makefile $(shell find 2>/dev/null $(PROJECTS)/vlink -not \( -path $(PROJECTS)/vlink/.git -prune \) -type f)
	$(L0)"make vlink"$(L1) cd $(BUILD)/vlink && TARGET=m68k $(MAKE) $(L2)
	@mkdir -p $(PREFIX)/bin/
	$(L0)"install vlink"$(L1) install $(BUILD)/vlink/vlink $(PREFIX)/bin/ $(L2)
	@echo "done" >$@

$(BUILD)/vlink/Makefile: $(PROJECTS)/vlink/Makefile
	@rsync -a --no-group $(PROJECTS)/vlink $(BUILD)/ --exclude .git

$(PROJECTS)/vlink/Makefile:
	@cd $(PROJECTS) && git clone -b $(vlink_BRANCH) --depth 4 $(vlink_URL)

# Always built, so the toolchain ships its own lha instead of relying
# on the host: brew only has lhasa, which cannot create archives and
# parses some options differently
LHA := $(PREFIX)/bin/lha$(EXEEXT)
ifeq (,$(strip $(HOST)))
LHA_PREREQ := $(LHA)
LHA_FOR_BUILD ?= $(LHA)
else
LHA_PREREQ :=
LHA_FOR_BUILD ?= $(shell command -v lha 2>/dev/null)
endif
ifneq (,$(strip $(HOST)))
FD2SFD_FOR_BUILD ?= $(BUILD_TOOLS_PREFIX)/bin/fd2sfd
else
FD2SFD_FOR_BUILD ?= $(PREFIX)/bin/fd2sfd$(EXEEXT)
endif
SFDC_FOR_BUILD ?= $(PREFIX)/bin/sfdc

.PHONY: lha
lha: $(LHA)

$(LHA): $(BUILD)/lha/Makefile
	$(L0)"make lha"$(L1) $(MAKE) -C $(BUILD)/lha all $(L2)
	$(L0)"install lha"$(L1) mkdir -p $(PREFIX)/bin && install $(BUILD)/lha/src/lha$(EXEEXT) $(LHA) $(L2)

$(BUILD)/lha/Makefile: $(PROJECTS)/lha/configure $(shell find 2>/dev/null $(PROJECTS)/lha -not \( -path $(PROJECTS)/lha/.git -prune \) -type f)
	@rm -rf $(BUILD)/lha && mkdir -p $(BUILD)/lha
	$(L0)"configure lha"$(L1) cd $(BUILD)/lha && $(PROJECTS)/lha/configure $(HOST_CONFIGURE) $(L2)

$(PROJECTS)/lha/configure:
	@cd $(PROJECTS) && git clone -b $(lha_BRANCH) --depth 4 $(lha_URL)


.PHONY: vbcc-target
vbcc-target: $(BUILD)/vbcc_target_$(TARGET)/_done $(BUILD)/vbcc_target_m68k-kick13/_done

$(BUILD)/vbcc_target_m68k-kick13/_done: $(BUILD)/vbcc_target_m68k-kick13/_unpacked patches/vbcc/kick13.config $(BUILD)/vasm/_done
	@mkdir -p $(PREFIX)/m68k-kick13/vbcc/include
	$(L0)"copying vbcc headers"$(L1) rsync --no-group $(BUILD)/vbcc_target_m68k-kick13/targets/m68k-kick13/include/* $(PREFIX)/m68k-kick13/vbcc/include $(L2)
	@mkdir -p $(PREFIX)/m68k-kick13/vbcc/lib
	$(L0)"copying vbcc headers"$(L1) rsync --no-group $(BUILD)/vbcc_target_m68k-kick13/targets/m68k-kick13/lib/* $(PREFIX)/m68k-kick13/vbcc/lib $(L2)
	@mkdir -p $(PREFIX)/bin
	$(L0)"creating vbcc kick13 config"$(L1) $(SED) -e "s|PREFIX|$(PREFIX)|g" patches/vbcc/kick13.config >$(BUILD)/vasm/kick13.config ;\
	install $(BUILD)/vasm/kick13.config $(PREFIX)/bin/ $(L2)
	@echo "done" >$@

$(BUILD)/vbcc_target_m68k-amigaos/_done: $(BUILD)/vbcc_target_m68k-amigaos/_unpacked $(wildcard patches/vbcc/*.config) $(BUILD)/vasm/_done
	@mkdir -p $(PREFIX)/m68k-amigaos/vbcc/include
	$(L0)"copying vbcc headers"$(L1) rsync --no-group $(BUILD)/vbcc_target_m68k-amigaos/targets/m68k-amigaos/include/* $(PREFIX)/m68k-amigaos/vbcc/include $(L2)
	@mkdir -p $(PREFIX)/m68k-amigaos/vbcc/lib
	$(L0)"copying vbcc headers"$(L1) rsync --no-group $(BUILD)/vbcc_target_m68k-amigaos/targets/m68k-amigaos/lib/* $(PREFIX)/m68k-amigaos/vbcc/lib $(L2)
	@mkdir -p $(PREFIX)/bin
	$(L0)"creating vbcc config"$(L1) $(SED) -e "s|PREFIX|$(PREFIX)|g" patches/vbcc/vc.config >$(BUILD)/vasm/vc.config ;\
	install $(BUILD)/vasm/vc.config $(PREFIX)/bin/ $(L2)
	$(L0)"creating vbcc aos68k configs"$(L1) for c in aos68k aos68km aos68kr; do \
		$(SED) -e "s|PREFIX|$(PREFIX)|g" patches/vbcc/$$c.config >$(BUILD)/vasm/$$c && \
		install $(BUILD)/vasm/$$c $(PREFIX)/bin/ || exit 1; \
	done $(L2)
	@echo "done" >$@


$(BUILD)/vbcc_target_m68k-kick13/_unpacked: $(DOWNLOAD)/vbcc_target_m68k-kick13.lha | $(LHA_PREREQ)
	$(L0)"unpack vbcc_target_m68k-kick13"$(L1) cd $(BUILD) && $(LHA_FOR_BUILD) xf $(DOWNLOAD)/vbcc_target_m68k-kick13.lha $(L2)
	@echo "done" >$@

$(BUILD)/vbcc_target_m68k-amigaos/_unpacked: $(DOWNLOAD)/vbcc_target_m68k-amigaos.lha | $(LHA_PREREQ)
	$(L0)"unpack vbcc_target_m68k-amigaos"$(L1) cd $(BUILD) && $(LHA_FOR_BUILD) xf $(DOWNLOAD)/vbcc_target_m68k-amigaos.lha $(L2)
	@echo "done" >$@

# =================================================
# NDK - no git
# =================================================

NDK_INCLUDE = $(shell find 2>/dev/null $(PROJECTS)/$(NDK_FOLDER_NAME_H) -type f)
NDK_INCLUDE_SFD = $(shell find 2>/dev/null $(PROJECTS)/$(NDK_FOLDER_NAME_SFD) -type f -name *.sfd)
NDK_FD2PRAGMA_PREREQ := $(BUILD)/fd2pragma/_done
ifneq (,$(strip $(HOST)))
NDK_FD2SFD_PREREQ := $(BUILD_TOOLS)/fd2sfd/_done
else
NDK_FD2SFD_PREREQ := $(BUILD)/fd2sfd/_done
endif
NDK_INCLUDE_INLINE = $(patsubst $(PROJECTS)/$(NDK_FOLDER_NAME_SFD)/%_lib.sfd,$(PREFIX)/$(TARGET)/ndk-include/inline/%.h,$(NDK_INCLUDE_SFD))
NDK_INCLUDE_INLINE_VBCC = $(patsubst $(PROJECTS)/$(NDK_FOLDER_NAME_SFD)/%_lib.sfd,$(PREFIX)/$(TARGET)/ndk-include/inline/%_protos.h,$(NDK_INCLUDE_SFD))
NDK_INCLUDE_LVO    = $(patsubst $(PROJECTS)/$(NDK_FOLDER_NAME_SFD)/%_lib.sfd,$(PREFIX)/$(TARGET)/ndk-include/lvo/%_lib.i,$(NDK_INCLUDE_SFD))
NDK_INCLUDE_PROTO  = $(patsubst $(PROJECTS)/$(NDK_FOLDER_NAME_SFD)/%_lib.sfd,$(PREFIX)/$(TARGET)/ndk-include/proto/%.h,$(NDK_INCLUDE_SFD))
SYS_INCLUDE2 = $(filter-out $(NDK_INCLUDE_PROTO),$(patsubst $(PROJECTS)/$(NDK_FOLDER_NAME_H)/%,$(PREFIX)/$(TARGET)/ndk-include/%, $(NDK_INCLUDE)))


.PHONY: ndk
ndk: $(BUILD)/ndk-include_ndk

$(BUILD)/ndk-include_ndk: $(BUILD)/ndk-include_ndk0 $(NDK_INCLUDE_INLINE) $(NDK_INCLUDE_INLINE_VBCC) $(NDK_INCLUDE_LVO) $(NDK_INCLUDE_PROTO) $(PROJECTS)/fd2sfd/configure $(PROJECTS)/fd2pragma/makefile
	$(MAKE) --no-print-directory ndk_inc=1 ndk-proto ndk-lvo ndk-inline ndk-inline-vbcc
	@mkdir -p $(BUILD)/ndk-include/
	@echo "done" >$@

$(BUILD)/ndk-include_ndk0: $(PROJECTS)/$(NDK_FOLDER_NAME)/_unpacked $(NDK_INCLUDE) $(NDK_FD2SFD_PREREQ) $(NDK_FD2PRAGMA_PREREQ)
	@mkdir -p $(PREFIX)/$(TARGET)/ndk-include
	@rsync -a --no-group $(PROJECTS)/$(NDK_FOLDER_NAME_H)/* $(PREFIX)/$(TARGET)/ndk-include --exclude proto --exclude inline
	$(L0)"STDARGing ndk"$(L1) for i in $$(find $(PREFIX)/$(TARGET)/ndk-include/clib/*protos.h -type f); do \
		echo $$i; \
		LC_CTYPE=C $(SED) -i.bak -E 's/([a-zA-Z0-9 _]*)([[:blank:]]+|\*)([a-zA-Z0-9_]+)\(/\1\2 __stdargs \3(/g' $$i; \
		rm $$i.bak; done $(L2)
	@rsync -a --no-group $(PROJECTS)/$(NDK_FOLDER_NAME_I)/* $(PREFIX)/$(TARGET)/ndk-include
	@mkdir -p $(PREFIX)/$(TARGET)/ndk/lib/fd
	@mkdir -p $(PREFIX)/$(TARGET)/ndk/lib/sfd
	@mkdir -p $(PREFIX)/$(TARGET)/ndk/lib/libs
	@rsync -a --no-group --delete $(PROJECTS)/$(NDK_FOLDER_NAME_FD)/ $(PREFIX)/$(TARGET)/ndk/lib/fd/
	@rsync -a --no-group --delete $(PROJECTS)/$(NDK_FOLDER_NAME_SFD)/ $(PREFIX)/$(TARGET)/ndk/lib/sfd/
	@rsync -a --no-group --delete $(PROJECTS)/$(NDK_FOLDER_NAME_LIBS)/ $(PREFIX)/$(TARGET)/ndk/lib/libs/
	@mkdir -p $(PREFIX)/$(TARGET)/ndk-include/proto
	@install -p -m 644 $(PROJECTS)/$(NDK_FOLDER_NAME_H)/proto/alib.h $(PREFIX)/$(TARGET)/ndk-include/proto
	@install -p -m 644 $(PROJECTS)/$(NDK_FOLDER_NAME_H)/proto/cardres.h $(PREFIX)/$(TARGET)/ndk-include/proto
	@mkdir -p $(PREFIX)/$(TARGET)/ndk-include/inline
	@install -p -m 644 $(PROJECTS)/fd2sfd/cross/share/m68k-amigaos/alib.h $(PREFIX)/$(TARGET)/ndk-include/inline
	@install -p -m 644 $(PROJECTS)/fd2pragma/Include/inline/stubs.h $(PREFIX)/$(TARGET)/ndk-include/inline
	@install -p -m 644 $(PROJECTS)/fd2pragma/Include/inline/macros.h $(PREFIX)/$(TARGET)/ndk-include/inline
	@mkdir -p $(BUILD)/ndk-include/
	@echo "done" >$@

.PHONY: ndk-inline
ndk-inline: $(NDK_INCLUDE_INLINE) sfdc $(BUILD)/ndk-include_inline
$(NDK_INCLUDE_INLINE): $(PREFIX)/bin/sfdc $(NDK_INCLUDE_SFD) $(BUILD)/ndk-include_inline $(BUILD)/ndk-include_lvo $(BUILD)/ndk-include_proto $(BUILD)/ndk-include_ndk0
	$(L0)"sfdc inline $(@F)"$(L1) $(SFDC_FOR_BUILD) --target=m68k-gcc-amigaos --mode=macros --output=$@ $(patsubst $(PREFIX)/$(TARGET)/ndk-include/inline/%.h,$(PROJECTS)/$(NDK_FOLDER_NAME_SFD)/%_lib.sfd,$@) $(L2)

.PHONY: ndk-inline-vbcc
ndk-inline-vbcc: $(NDK_INCLUDE_INLINE_VBCC) sfdc $(BUILD)/ndk-include_inline
$(NDK_INCLUDE_INLINE_VBCC): $(PREFIX)/bin/sfdc $(NDK_INCLUDE_SFD) $(BUILD)/ndk-include_inline $(BUILD)/ndk-include_lvo $(BUILD)/ndk-include_proto $(BUILD)/ndk-include_ndk0
	$(L0)"sfdc inline vbcc $(@F)"$(L1) $(SFDC_FOR_BUILD) --target=m68kvbcc-amigaos --mode=macros --output=$@ $(patsubst $(PREFIX)/$(TARGET)/ndk-include/inline/%_protos.h,$(PROJECTS)/$(NDK_FOLDER_NAME_SFD)/%_lib.sfd,$@) $(L2)

.PHONY: ndk-lvo
ndk-lvo: $(NDK_INCLUDE_LVO) sfdc
$(NDK_INCLUDE_LVO): $(PREFIX)/bin/sfdc $(NDK_INCLUDE_SFD) $(BUILD)/ndk-include_lvo $(BUILD)/ndk-include_ndk0
	$(L0)"sfdc lvo $(@F)"$(L1) $(SFDC_FOR_BUILD) --target=m68k-amigaos --mode=lvo --output=$@ $(patsubst $(PREFIX)/$(TARGET)/ndk-include/lvo/%_lib.i,$(PROJECTS)/$(NDK_FOLDER_NAME_SFD)/%_lib.sfd,$@) $(L2)

.PHONY: ndk-proto
ndk-proto: $(NDK_INCLUDE_PROTO) sfdc
$(NDK_INCLUDE_PROTO): $(PREFIX)/bin/sfdc $(NDK_INCLUDE_SFD)	$(BUILD)/ndk-include_proto $(BUILD)/ndk-include_ndk0
	$(L0)"sfdc proto $(@F)"$(L1) $(SFDC_FOR_BUILD) --target=m68k-amigaos --mode=proto --output=$@ $(patsubst $(PREFIX)/$(TARGET)/ndk-include/proto/%.h,$(PROJECTS)/$(NDK_FOLDER_NAME_SFD)/%_lib.sfd,$@) $(L2)

$(BUILD)/ndk-include_inline: $(PROJECTS)/$(NDK_FOLDER_NAME)/_unpacked
	@mkdir -p $(PREFIX)/$(TARGET)/ndk-include/inline
	@mkdir -p $(BUILD)/ndk-include/
	@echo "done" >$@

$(BUILD)/ndk-include_lvo: $(PROJECTS)/$(NDK_FOLDER_NAME)/_unpacked
	@mkdir -p $(PREFIX)/$(TARGET)/ndk-include/lvo
	@mkdir -p $(PREFIX)/$(TARGET)/ndk13-include/lvo
	@mkdir -p $(BUILD)/ndk-include/
	@echo "done" >$@

$(BUILD)/ndk-include_proto: $(PROJECTS)/$(NDK_FOLDER_NAME)/_unpacked
	@mkdir -p $(PREFIX)/$(TARGET)/ndk-include/proto
	@mkdir -p $(PREFIX)/$(TARGET)/ndk13-include/proto
	@mkdir -p $(BUILD)/ndk-include/
	@echo "done" >$@

$(PROJECTS)/$(NDK_FOLDER_NAME)/_unpacked: $(DOWNLOAD)/$(NDK_ARC_NAME).lha $(shell find 2>/dev/null patches/$(NDK_FOLDER_NAME)/ -type f) | $(LHA_PREREQ)
	$(L0)"unpack ndk"$(L1) mkdir -p $(PROJECTS)/NDK3.2 && cd $(PROJECTS)/NDK3.2 && \
	   $(LHA_FOR_BUILD) xf $(DOWNLOAD)/$(NDK_ARC_NAME).lha $(L2)
	$(L0)"patch ndk"$(L1) for i in $$(find patches/$(NDK_FOLDER_NAME)/ -type f); do \
	   if [[ "$$i" == *.diff ]] ; \
		then j=$${i:8}; patch -N "$(PROJECTS)/$${j%.diff}" "$$i"; \
		else cp -pv "$$i" "$(PROJECTS)/$${i:8}"; fi ; done $(L2)
	@echo "done" >$@


# =================================================
# NDK1.3 - emulated from NDK
# =================================================
.PHONY: ndk13
ndk13: $(BUILD)/ndk-include_ndk13

$(BUILD)/ndk-include_ndk13: $(BUILD)/ndk-include_ndk $(NDK_FD2SFD_PREREQ) $(BUILD)/sfdc/_done
	@while read p; do p=$$(echo $$p|tr -d '\n'); mkdir -p $(PREFIX)/$(TARGET)/ndk13-include/$$(dirname $$p); install -m 644 $(PREFIX)/$(TARGET)/ndk-include/$$p $(PREFIX)/$(TARGET)/ndk13-include/$$p; done < patches/ndk13/hfiles
	$(L0)"extract ndk13"$(L1) while read p; do p=$$(echo $$p|tr -d '\n'); \
	  mkdir -p $(PREFIX)/$(TARGET)/ndk13-include/$$(dirname $$p); \
	  if grep V36 $(PREFIX)/$(TARGET)/ndk-include/$$p; then \
	  LC_CTYPE=C $(SED) -n -e '/#ifndef[[:space:]]*CLIB/,/V36/p' $(PREFIX)/$(TARGET)/ndk-include/$$p | $(SED) -e 's/__stdargs//g' >$(PREFIX)/$(TARGET)/ndk13-include/$$p; \
	  echo -e "#ifdef __cplusplus\n}\n#endif /* __cplusplus */\n#endif" >>$(PREFIX)/$(TARGET)/ndk13-include/$$p; \
	  else LC_CTYPE=C $(SED) $(PREFIX)/$(TARGET)/ndk-include/$$p -e 's/__stdargs//g' >$(PREFIX)/$(TARGET)/ndk13-include/$$p; fi \
	done < patches/ndk13/chfiles $(L2)
	@while read p; do p=$$(echo $$p|tr -d '\n'); mkdir -p $(PREFIX)/$(TARGET)/ndk13-include/$$(dirname $$p); echo "" >$(PREFIX)/$(TARGET)/ndk13-include/$$p; done < patches/ndk13/ehfiles
	@echo '#undef	EXECNAME' > $(PREFIX)/$(TARGET)/ndk13-include/exec/execname.h
	@echo '#define	EXECNAME	"exec.library"' >> $(PREFIX)/$(TARGET)/ndk13-include/exec/execname.h
	@mkdir -p $(PREFIX)/$(TARGET)/ndk/lib/fd13
	@while read p; do p=$$(echo $$p|tr -d '\n'); LC_CTYPE=C $(SED) -n -e '/##base/,/V36/P'  $(PREFIX)/$(TARGET)/ndk/lib/fd/$$p >$(PREFIX)/$(TARGET)/ndk/lib/fd13/$$p; done < patches/ndk13/fdfiles
	@mkdir -p $(PREFIX)/$(TARGET)/ndk/lib/sfd13
	@for i in $(PREFIX)/$(TARGET)/ndk/lib/fd13/*; do $(FD2SFD_FOR_BUILD) $$i $(PREFIX)/$(TARGET)/ndk13-include/clib/$$(basename $$i _lib.fd)_protos.h > $(PREFIX)/$(TARGET)/ndk/lib/sfd13/$$(basename $$i .fd).sfd; done
	$(L0)"macros+protos ndk13"$(L1) for i in $(PREFIX)/$(TARGET)/ndk/lib/sfd13/*; do \
	  $(SFDC_FOR_BUILD) --target=m68k-gcc-amigaos --mode=macros --output=$(PREFIX)/$(TARGET)/ndk13-include/inline/$$(basename $$i _lib.sfd).h $$i; \
	  $(SFDC_FOR_BUILD) --target=m68k-amigaos --mode=proto --output=$(PREFIX)/$(TARGET)/ndk13-include/proto/$$(basename $$i _lib.sfd).h $$i; \
	done $(L2)
	$(L0)"STDARGing ndk13"$(L1) for i in $$(find $(PREFIX)/$(TARGET)/ndk13-include/clib/*protos.h -type f); do \
	echo $$i; \
	LC_CTYPE=C $(SED) -i.bak -E 's/([a-zA-Z0-9 _]*)([[:blank:]]+|\*)([a-zA-Z0-9_]+)\(/\1\2 __stdargs \3(/g' $$i; \
	rm $$i.bak; done $(L2)
	@echo "done" >$@

# =================================================
# netinclude
# =================================================
.PHONY: netinclude
netinclude: $(BUILD)/_netinclude

$(BUILD)/_netinclude: $(PROJECTS)/amiga-netinclude/README.md $(BUILD)/ndk-include_ndk $(shell find 2>/dev/null $(PROJECTS)/amiga-netinclude/include -type f)
	@mkdir -p $(PREFIX)/$(TARGET)/ndk-include
	@rsync -a --no-group $(PROJECTS)/amiga-netinclude/include/* $(PREFIX)/$(TARGET)/ndk-include
	@echo "done" >$@

$(PROJECTS)/amiga-netinclude/README.md:
	@cd $(PROJECTS) && git clone -b $(amiga-netinclude_BRANCH) --depth 4 $(amiga-netinclude_URL)

# =================================================
# libamiga
# =================================================
LIBAMIGA := $(PREFIX)/$(TARGET)/lib/libamiga.a
LIBBAMIGA := $(PREFIX)/$(TARGET)/lib/libb/libamiga.a

libamiga: $(LIBAMIGA) $(LIBBAMIGA)
	@echo "built $(LIBAMIGA) and $(LIBBAMIGA)"

$(LIBAMIGA):
	@mkdir -p $(@D)
	#@cp $(PROJECTS)/$(NDK_FOLDER_NAME_LIBS)/amiga.lib $@
	@install -m 644 lib/libamiga.a $@

$(LIBBAMIGA):
	@mkdir -p $(@D)
	@install -m 644 lib/libb/libamiga.a $@

# =================================================
# libnix
# =================================================

LIBNIX_SRC = $(shell find 2>/dev/null $(PROJECTS)/libnix -not \( -path $(PROJECTS)/libnix/.git -prune \) -not \( -path $(PROJECTS)/libnix/sources/stubs/libbases -prune \) -not \( -path $(PROJECTS)/libnix/sources/stubs/libnames -prune \) -type f)

.PHONY: libnix
libnix: $(BUILD)/libnix/_done

$(BUILD)/libnix/_done: $(BUILD)/newlib/_done $(BUILD)/ndk-include_ndk $(BUILD)/ndk-include_ndk13 $(BUILD)/_netinclude $(BUILD)/binutils/_done $(BUILD)/gcc/_done $(PROJECTS)/libnix/Makefile.gcc6 $(LIBAMIGA) $(LIBNIX_SRC)
	@mkdir -p $(PREFIX)/$(TARGET)/libnix/lib/libnix
	@mkdir -p $(BUILD)/libnix
	@mkdir -p $(PREFIX)/lib/gcc/$(TARGET)/$(GCC_DIR_VERSION)
	@if [ ! -e $(PREFIX)/lib/gcc/$(TARGET)/$(GCC_DIR_VERSION)/libgcc.a ]; then $(TARGET_AR_FOR_BUILD) rcs $(PREFIX)/lib/gcc/$(TARGET)/$(GCC_DIR_VERSION)/libgcc.a; fi
	$(L0)"make libnix"$(L1) CFLAGS="$(CFLAGS_FOR_TARGET)" $(MAKE) -C $(BUILD)/libnix -f $(PROJECTS)/libnix/Makefile.gcc6 root=$(PROJECTS)/libnix all $(L2)
	$(L0)"install libnix"$(L1) $(MAKE) -C $(BUILD)/libnix -f $(PROJECTS)/libnix/Makefile.gcc6 root=$(PROJECTS)/libnix install $(L2)
	@rsync --delete -a --no-group $(PROJECTS)/libnix/sources/headers/* $(PREFIX)/$(TARGET)/libnix/include/
	@echo "done" >$@

$(PROJECTS)/libnix/Makefile.gcc6:
	@cd $(PROJECTS) && git clone -b $(libnix_BRANCH) --depth 4 $(libnix_URL)

# =================================================
# gcc libs
# =================================================
LIBGCCS_NAMES := libgcov.a libstdc++.a libsupc++.a
LIBGCCS := $(patsubst %,$(PREFIX)/lib/gcc/$(TARGET)/$(GCC_DIR_VERSION)/%,$(LIBGCCS_NAMES))

.PHONY: libgcc
libgcc: $(BUILD)/gcc/_libgcc_done

$(BUILD)/gcc/_libgcc_done: $(BUILD)/libnix/_done $(BUILD)/libpthread/_done $(LIBAMIGA) $(GCC_TARGET_PREREQ) $(shell find 2>/dev/null $(PROJECTS)/gcc/libgcc -type f)
ifneq (,$(strip $(HOST)))
	# Hosted target compilers do not search GCC's build-tree include directory.
	# Install libgcc first so libstdc++ can find generated headers such as
	# unwind.h through the installed compiler include directory.
	$(L0)"make target libgcc"$(L1) $(MAKE) -C $(BUILD)/gcc $(GCC_TARGET_MAKE_FLAGS) all-target-libgcc $(L2)
	$(L0)"install target libgcc"$(L1) $(MAKE) -C $(BUILD)/gcc $(GCC_TARGET_MAKE_FLAGS) install-target-libgcc $(L2)
endif
	$(L0)"make libgcc"$(L1) $(MAKE) -C $(BUILD)/gcc $(GCC_TARGET_MAKE_FLAGS) all-target $(L2)
	$(L0)"install libgcc"$(L1) $(MAKE) -C $(BUILD)/gcc $(GCC_TARGET_MAKE_FLAGS) install-target $(L2)
	@echo "done" >$@

# =================================================
# libnix4.library
# =================================================
.PHONY: libnix4.library
libnix4.library: $(BUILD)/libnix/libb/libnix4.library
$(BUILD)/libnix/libb/libnix4.library: $(BUILD)/gcc/_libgcc_done $(BUILD)/libnix/_done
	$(L0)"make libnix4.library"$(L1) CFLAGS="$(CFLAGS_FOR_TARGET)" \
	$(MAKE) -C $(BUILD)/libnix -f $(PROJECTS)/libnix/Makefile.gcc6 root=$(PROJECTS)/libnix libb/libnix4.library $(L2)

# =================================================
# clib2
# =================================================

.PHONY: clib2
clib2: $(BUILD)/clib2/_done

$(BUILD)/clib2/_done: $(PROJECTS)/clib2/LICENSE $(shell find 2>/dev/null $(PROJECTS)/clib2 -not \( -path $(PROJECTS)/clib2/.git -prune \) -type f) $(BUILD)/libnix/_done $(LIBAMIGA)
	@mkdir -p $(BUILD)/clib2/
	@rsync -a --no-group $(PROJECTS)/clib2/library/* $(BUILD)/clib2
	@rsync -a --no-group --delete $(PROJECTS)/clib2/library/include/ $(BUILD)/clib2/include/
	@cd $(BUILD)/clib2 && find * -name lib\*.a -delete
	$(L0)"make clib2"$(L1) $(MAKE) -C $(BUILD)/clib2 -f GNUmakefile.68k$(L2)
	@mkdir -p $(PREFIX)/$(TARGET)/clib2
	@rsync -a --no-group --delete $(BUILD)/clib2/include $(PREFIX)/$(TARGET)/clib2
	@rsync -a --no-group --delete $(BUILD)/clib2/lib $(PREFIX)/$(TARGET)/clib2
	@echo "done" >$@

$(PROJECTS)/clib2/LICENSE:
	@cd $(PROJECTS) && git clone -b $(clib2_BRANCH) --depth 4 $(clib2_URL)

# =================================================
# libdebug
# =================================================
CONFIG_LIBDEBUG := --prefix=$(PREFIX) --target=$(TARGET) --host=$(TARGET)

.PHONY: libdebug
libdebug: $(BUILD)/libdebug/_done

# libdebug's configure is only told CC and LD; in a hosted build its AR
# can resolve to the build machine's, which cannot read hunk objects and
# writes the archive without a symbol index ("archive has no index; run
# ranlib" at link time, seen with the MinGW amiga6 package). Index it.
$(BUILD)/libdebug/_done: $(BUILD)/libdebug/Makefile
	$(L0)"make libdebug"$(L1) $(MAKE) -C $(BUILD)/libdebug $(L2)
	@install -m 644 $(BUILD)/libdebug/libdebug.a $(PREFIX)/$(TARGET)/lib/
	@$(TARGET_RANLIB_FOR_BUILD) $(PREFIX)/$(TARGET)/lib/libdebug.a
	@echo "done" >$@

$(BUILD)/libdebug/Makefile: $(BUILD)/gcc/_libgcc_done $(BUILD)/libnix/_done $(PROJECTS)/libdebug/configure $(shell find 2>/dev/null $(PROJECTS)/libdebug -not \( -path $(PROJECTS)/libdebug/.git -prune \) -type f)
	@mkdir -p $(BUILD)/libdebug
	$(L0)"configure libdebug"$(L1) cd $(BUILD)/libdebug && LD=$(TARGET)-ld CC=$(TARGET)-gcc AR="$(TARGET_AR_FOR_BUILD)" RANLIB="$(TARGET_RANLIB_FOR_BUILD)" CFLAGS="$(CFLAGS_FOR_TARGET)" $(PROJECTS)/libdebug/configure $(CONFIG_LIBDEBUG) $(L2)

$(PROJECTS)/libdebug/configure:
	@cd $(PROJECTS) && git clone -b $(libdebug_BRANCH) --depth 4 $(libdebug_URL)
	@touch -t 0001010000 $(PROJECTS)/libdebug/configure.ac

# =================================================
# libpthread
# =================================================

.PHONY: libpthread
libpthread: $(BUILD)/libpthread/_done

$(BUILD)/libpthread/_done: $(BUILD)/libpthread/Makefile
	@rsync -a --no-group --exclude=debug.h $(BUILD)/libpthread/*.h $(PREFIX)/$(TARGET)/include/
	$(L0)"make libpthread"$(L1) cd $(BUILD)/libpthread && $(MAKE) -f Makefile.gcc6 $(L2)
	$(L0)"install libpthread"$(L1) cd $(BUILD)/libpthread && $(MAKE) -f Makefile.gcc6 install PREFIX=$(PREFIX) $(L2)
	@echo "done" >$@

$(BUILD)/libpthread/Makefile: $(BUILD)/libnix/_done $(PROJECTS)/aros-stuff/pthreads/Makefile $(shell find 2>/dev/null $(PROJECTS)/aros-stuff/pthreads -type f)
	@mkdir -p $(BUILD)/libpthread
	@rsync -a --no-group $(PROJECTS)/aros-stuff/pthreads/* $(BUILD)/libpthread
	@touch $(BUILD)/libpthread/Makefile

$(PROJECTS)/aros-stuff/pthreads/Makefile:
	@cd $(PROJECTS) && git clone -b $(aros-stuff_BRANCH) --depth 4 $(aros-stuff_URL)

# =================================================
# newlib
# =================================================
# The only C++ in newlib, its AmigaOS malloc, must not need the C++ runtime,
# in hosted builds too.
NEWLIB_CFLAGS ?= $(CFLAGS_FOR_TARGET)
NEWLIB_CXXFLAGS ?= $(NEWLIB_CFLAGS) -fno-exceptions -fno-rtti

NEWLIB_CONFIG := CC=$(TARGET)-gcc CXX=$(TARGET)-g++
ifneq (,$(strip $(HOST)))
# A Canadian-cross build inherits HOST binutils from the environment.  Newlib
# contains TARGET objects, so its archives must instead be created and indexed
# by the newly built TARGET tools running through the appropriate runner.
NEWLIB_CONFIG += AR=$(TARGET_AR_FOR_BUILD) RANLIB=$(TARGET_RANLIB_FOR_BUILD)
endif
NEWLIB_FILES = $(shell find 2>/dev/null $(PROJECTS)/newlib-cygwin/newlib -type f)

.PHONY: newlib
newlib: $(BUILD)/newlib/_done

$(BUILD)/newlib/_done: $(BUILD)/newlib/newlib/libc.a
	@echo "done" >$@

ifeq (,$(strip $(HOST)))
NEWLIB_BINUTILS_PREREQ := $(BUILD)/binutils/_gdb
else
NEWLIB_BINUTILS_PREREQ := $(BUILD)/binutils/_done
endif

$(BUILD)/newlib/newlib/libc.a: $(BUILD)/newlib/newlib/Makefile $(BUILD)/newlib/_headers $(NEWLIB_BINUTILS_PREREQ) $(NEWLIB_FILES)
	$(L0)"make newlib"$(L1) $(MAKE) -C $(BUILD)/newlib/newlib $(L2)
	$(L0)"install newlib"$(L1) $(MAKE) -C $(BUILD)/newlib/newlib install $(L2)
	@touch $@

# newlib's headers in sys-include, after gcc's build put the amigaos copies
# there.  Before configure as well as before the build: configure checks the
# preprocessor by including <limits.h> with the installed cross compiler,
# and the amigaos limits.h and assert.h include newlib.h and _ansi.h from
# libc/include (on Linux a host /lib/cpp masked the failure; macOS has none).
NEWLIB_HEADERS = $(shell find 2>/dev/null $(PROJECTS)/newlib-cygwin/newlib/libc/include $(PROJECTS)/newlib-cygwin/newlib/libc/sys/amigaos/include -type f)
$(BUILD)/newlib/_headers: $(NEWLIB_HEADERS) $(BUILD)/gcc/_done | $(PREFIX_STAMP)
	@mkdir -p $(BUILD)/newlib
	@rsync -a --no-group $(PROJECTS)/newlib-cygwin/newlib/libc/include/ $(PREFIX)/$(TARGET)/sys-include
	@rsync -a --no-group $(PROJECTS)/newlib-cygwin/newlib/libc/sys/amigaos/include/ $(PREFIX)/$(TARGET)/sys-include
	@touch $@

# --disable-newlib-reent-check-verify: with reent-small, newlib otherwise
# asserts on every lazily allocated reent field, so rand(), strtok() or
# gmtime() alone link assert(), fiprintf() and all of stdio.
$(BUILD)/newlib/newlib/Makefile: $(PROJECTS)/newlib-cygwin/newlib/configure $(BUILD)/ndk-include_ndk $(BUILD)/gcc/_done $(BUILD)/newlib/_headers | $(PREFIX_STAMP)
	@mkdir -p $(BUILD)/newlib/newlib
	@if [ ! -f "$(BUILD)/newlib/newlib/Makefile" ]; then \
	$(L00)"configure newlib"$(L1) cd $(BUILD)/newlib/newlib && $(NEWLIB_CONFIG) CFLAGS="$(NEWLIB_CFLAGS)" CC_FOR_BUILD="$(CC)" CXXFLAGS="$(NEWLIB_CXXFLAGS)" $(PROJECTS)/newlib-cygwin/newlib/configure --host=$(TARGET) --prefix=$(PREFIX) --enable-newlib-io-long-long --enable-newlib-io-c99-formats --enable-newlib-reent-small --enable-newlib-mb --enable-newlib-long-time_t --disable-newlib-reent-check-verify $(L2) \
	; else touch "$(BUILD)/newlib/newlib/Makefile"; fi

$(PROJECTS)/newlib-cygwin/newlib/configure:
	@cd $(PROJECTS) && git clone -b $(newlib-cygwin_BRANCH) --depth 4 $(newlib-cygwin_URL)

# =================================================
# ixemul
# =================================================
.PHONY: ixemul
ixemul:	$(BUILD)/ixemul/_done

# The SDK is the gg/ tree of the ixemul release archive: headers, startup
# files and the libc.a stubs.  The archive also carries ixemul.library and
# ixnet.library for each CPU, the ixpipe handler and the sources; only the
# 68000 libraries are installed, in ixemul/libs, and the 68020 FPU ones, in
# ixemul/libs-020fpu, for the volamos-ixemul and volamos-ixemul-fpu testsuite
# boards.  ranlib: the libc.a files of 80.1 ship with a stale symbol
# index that misses poll.o, so poll() did not link.
#
# patches/ixemul has the headers the SDK lacks or gets wrong:
# - <inttypes.h> is missing, so newlib's came from sys-include, with its own int32_t (long) clashing with ixemul's (int);
# - <assert.h> calls libgcc's __eprintf, which writes to newlib's stderr and fails to link;
# - <machine/ansi.h> makes wchar_t and ptrdiff_t int, while GCC's <stddef.h> has long.
# The SDK's own <stddef.h>, <stdarg.h>, <float.h>, <varargs.h> and <math-68881.h> are removed,
# so that GCC's are used: its <stdarg.h> broke variadic functions that GCC inlines, and its
# <float.h> gave long double 53 bits.
IXEMUL_HEADERS = $(addprefix patches/ixemul/,inttypes.h assert.h machine/ansi.h)
IXEMUL_COMPILER_HEADERS = stddef.h stdarg.h float.h varargs.h math-68881.h

$(BUILD)/ixemul/_done: $(DOWNLOAD)/$(ixemul-sdk_ARCHIVE) $(IXEMUL_HEADERS) $(BUILD)/binutils/_done | $(LHA_PREREQ)
	mkdir -p $(BUILD)/ixemul $(PREFIX)/$(TARGET)/ixemul
	$(L0)"unpacking $(ixemul-sdk_ARCHIVE)"$(L1) cd $(BUILD)/ixemul && $(LHA_FOR_BUILD) xf $(DOWNLOAD)/$(ixemul-sdk_ARCHIVE) 'gg/include/*' 'gg/lib/*' Sys/libs/ixemul000.library Sys/libs/ixnet000.library Sys/libs/ixemul020-fpu.library Sys/libs/ixnet020.library $(L2)
	$(L0)"installing ixemul-sdk"$(L1) rsync -a --no-group --delete $(BUILD)/ixemul/gg/ $(PREFIX)/$(TARGET)/ixemul/ $(L2)
	$(TARGET_RANLIB_FOR_BUILD) $(PREFIX)/$(TARGET)/ixemul/lib/libc.a $(PREFIX)/$(TARGET)/ixemul/lib/libc_p.a $(PREFIX)/$(TARGET)/ixemul/lib/libb/libc.a $(PREFIX)/$(TARGET)/ixemul/lib/libb32/libm020/libc.a
	rsync -a --no-group patches/ixemul/ $(PREFIX)/$(TARGET)/ixemul/include/
	rm -f $(addprefix $(PREFIX)/$(TARGET)/ixemul/include/,$(IXEMUL_COMPILER_HEADERS))
	mkdir -p $(PREFIX)/$(TARGET)/ixemul/libs
	cp $(BUILD)/ixemul/Sys/libs/ixemul000.library $(PREFIX)/$(TARGET)/ixemul/libs/ixemul.library
	cp $(BUILD)/ixemul/Sys/libs/ixnet000.library $(PREFIX)/$(TARGET)/ixemul/libs/ixnet.library
	# -m68881 code expects doubles back in fp0, which only the FPU libraries return
	mkdir -p $(PREFIX)/$(TARGET)/ixemul/libs-020fpu
	cp $(BUILD)/ixemul/Sys/libs/ixemul020-fpu.library $(PREFIX)/$(TARGET)/ixemul/libs-020fpu/ixemul.library
	cp $(BUILD)/ixemul/Sys/libs/ixnet020.library $(PREFIX)/$(TARGET)/ixemul/libs-020fpu/ixnet.library
	# ixemul's libc.a has the math functions, and the SDK ships no libm.a, so
	# -lm fell through to newlib's libm.a and failed on _impure_ptr.  An
	# empty archive in ixemul/lib, which -mcrt=ixemul searches first,
	# satisfies -lm.
	printf '!<arch>\n' >$(PREFIX)/$(TARGET)/ixemul/lib/libm.a
	echo "done" >$@

# =================================================
# sdk installation
# =================================================
.PHONY: sdk all-sdk
sdk: libnix | $(LHA_PREREQ)
	$(L0)"sdk $(sdk)"$(L1) TOOL_RUNNER="$(HOST_RUNNER)" HOST_EXEEXT="$(EXEEXT)" CC_FOR_SDK="$(SDK_CC_FOR_BUILD)" AR_FOR_SDK="$(SDK_AR_FOR_BUILD)" FD2SFD_FOR_BUILD="$(FD2SFD_FOR_BUILD)" SFDC_FOR_BUILD="$(SFDC_FOR_BUILD)" LHA_FOR_BUILD="$(LHA_FOR_BUILD)" $(PWD)/scripts/sdk-install install $(sdk) $(PREFIX) $(L2)

SDKS0=$(shell find sdk/*.sdk)
SDKS=$(patsubst sdk/%.sdk,%,$(SDKS0))
.PHONY: $(SDKS)
all-sdk: $(SDKS)

$(SDKS): libnix | $(LHA_PREREQ)
	@$(MAKE) --no-print-directory sdk sdk=$@

# =================================================
# tag a release
# =================================================
# Tag TAG in every module of default-repos and in this repository; see
# scripts/release-tag.  A dry run unless CONFIRM=yes:
#   make release-tag TAG=v16.2-rc18 NOTES=notes.md [CONFIRM=yes]
.PHONY: release-tag
release-tag:
	@PROJECTS=$(PROJECTS) scripts/release-tag "$(TAG)" "$(NOTES)" $(if $(filter yes,$(CONFIRM)),--confirm)

# =================================================
# update repos
# =================================================
.PHONY: update-repos
update-repos:
	@for i in $(modules); do \
		url=$$(grep "^$$i[[:blank:]]" .repos | $(SED) -e 's/[[:blank:]]\+/ /g' | cut -d' ' -f2); \
		bra=$$(grep "^$$i[[:blank:]]" .repos | $(SED) -e 's/[[:blank:]]\+/ /g' | cut -d' ' -f3); \
		bra=$${bra/$$'\n'} ;\
		bra=$${bra/$$'\r'} ;\
		if [ -e projects/$$i ]; then \
			pushd projects/$$i; \
			echo setting remote origin from $$(git remote get-url origin) to $$url using branch $$bra.; \
			git remote remove origin; \
			git remote add origin $$url; \
			git remote set-branches origin $$bra; \
			git pull --depth 4; \
			git checkout $$bra; \
			popd; \
		fi; \
	done

# =================================================
# volamos
# =================================================
# The simulator the volamos* boards run the target testsuite under.  A
# published release binary is used rather than a source build, so neither CI
# nor a contributor needs a Rust toolchain; hosts without a release build it
# themselves and put it on PATH.
VOLAMOS_UNAME_S := $(shell uname -s)
VOLAMOS_UNAME_M := $(shell uname -m)

ifeq ($(VOLAMOS_UNAME_S),Linux)
  ifeq ($(VOLAMOS_UNAME_M),x86_64)
    VOLAMOS_HOST := x86_64-unknown-linux-musl
  endif
  ifneq (,$(filter $(VOLAMOS_UNAME_M),aarch64 arm64))
    VOLAMOS_HOST := aarch64-unknown-linux-musl
  endif
endif
ifeq ($(VOLAMOS_UNAME_S),Darwin)
  ifneq (,$(filter $(VOLAMOS_UNAME_M),aarch64 arm64))
    VOLAMOS_HOST := aarch64-apple-darwin
  endif
endif

.PHONY: volamos
volamos: $(PREFIX)/bin/volamos

ifeq (,$(VOLAMOS_HOST))
$(PREFIX)/bin/volamos:
	@echo "volamos has no release for $(VOLAMOS_UNAME_S) $(VOLAMOS_UNAME_M)." >&2
	@echo "Build it from https://github.com/sidick/volamos and copy it to $(PREFIX)/bin." >&2
	@exit 1
else
VOLAMOS_DIR := $(volamos-$(VOLAMOS_HOST)_DIR)
VOLAMOS_ARC := $(volamos-$(VOLAMOS_HOST)_ARCHIVE)

$(PREFIX)/bin/volamos: $(DOWNLOAD)/$(VOLAMOS_ARC)
	@mkdir -p $(PREFIX)/bin
	$(L0)"unpack volamos"$(L1) tar xzf $(DOWNLOAD)/$(VOLAMOS_ARC) -C $(PREFIX)/bin \
	  --strip-components=1 $(VOLAMOS_DIR)/volamos && touch $@$(L2)
endif

# =================================================
# run gcc torture check
# =================================================
# The volamos* boards are the default; the amigaos* ones run the same tests
# under vamos, for comparison.
ifeq (,$(board))
board = volamos
endif

# The board's own baseboards/*.exp defaults its simulator (vamos/volamos)
# unless overridden; forward SIM= to runtest only when the caller set one,
# e.g. `make check SIM=/path/to/wrapper`.
RUNTEST_SIM = $(if $(SIM), SIM=$(SIM))

# A volamos board installs volamos first, unless SIM= names another binary.
BOARD_SIM_PREREQ = $(if $(and $(filter volamos%,$(board)),$(if $(SIM),,y)),$(PREFIX)/bin/volamos)

# Point dejagnu at the in-repo board descriptions in baseboards/ which wire up
# vamos/volamos as the simulator.
export DEJAGNU ?= $(CURDIR)/dejagnu-site.exp

# The ixemul.library the volamos-ixemul and volamos-ixemul-fpu boards run the tests with.
export IXEMUL_LIBS ?= $(PREFIX)/$(TARGET)/ixemul/libs
export IXEMUL_FPU_LIBS ?= $(PREFIX)/$(TARGET)/ixemul/libs-020fpu

# Directory where dejagnu writes gcc.sum / gcc.log.
TESTSUITE = $(BUILD)/gcc/gcc/testsuite/gcc

# The C++ testsuite writes into a separate g++ directory.
CXXTESTSUITE = $(BUILD)/gcc/gcc/testsuite/g++
RUSTTESTSUITE = $(BUILD)/gcc/gcc/testsuite/rust

# A check-* target builds what it tests (min, or just binutils or gcc) when
# its stamps are missing, so it also works in a fresh tree, as a /ci make
# comment runs it; an existing build is left alone, even an old one.
# $(call if-missing,FILES,TARGET) is TARGET if any of FILES is missing.
if-missing = $(if $(filter-out $(wildcard $(1)),$(1)),$(2))

# _libgcc_done comes after binutils, gcc and libnix
MIN_IF_MISSING = $(call if-missing,$(BUILD)/gcc/_libgcc_done $(BUILD)/ixemul/_done,min)

# What a release must pass; the release workflow runs it.  The GCC testsuites run
# sequentially: they drive check-gcc-c in the same build tree, sharing gcc.sum
# and testsuite/gcc-parallel, so they must not run at the same time.
# volamos-fpu-baserel32 covers 68020 code with FPU instructions on a4-relative
# data in one run.
.PHONY: check
check:
	$(MAKE) --no-print-directory check-multilib
	$(MAKE) --no-print-directory check-binutils
	$(MAKE) --no-print-directory check-gcc-amigaos
	$(MAKE) --no-print-directory check-libnix
	$(MAKE) --no-print-directory check-libpthread
	$(MAKE) --no-print-directory check-c
	$(MAKE) --no-print-directory check-c board=volamos/-mcrt=ixemul
	$(MAKE) --no-print-directory check-c board=volamos/-mcrt=nix20/-m68020-60/-m68881/-fbaserel32

# The gas and ld dump tests for the hunk target run on the build machine under DejaGnu.
# The gas m68k tests written for ELF expect % register syntax and fail on this target,
# so gas's own exit status is ignored and only the Amiga tests decide.
.PHONY: check-binutils
check-binutils: check-binutils-gas check-binutils-ld

.PHONY: check-binutils-gas
check-binutils-gas: $(call if-missing,$(BUILD)/binutils/_done,binutils)
	@rm -f $(BUILD)/binutils/gas/testsuite/gas.sum
	$(L0)"check gas"$(L1)$(MAKE) -C $(BUILD)/binutils/gas check "RUNTESTFLAGS=all.exp" || true$(L2)
	@{ echo '----- gas -----'; grep -E '^(PASS|FAIL|ERROR|XPASS|UNRESOLVED).*[Aa]miga' $(BUILD)/binutils/gas/testsuite/gas.sum 2>/dev/null || echo '(no tests run)'; } | tee $@.summary.txt
	@echo "results: $(BUILD)/binutils/gas/testsuite/gas.{sum,log}"
	@grep -qE '^PASS.*[Aa]miga' $(BUILD)/binutils/gas/testsuite/gas.sum
	@! grep -qE '^(FAIL|ERROR|XPASS|UNRESOLVED).*[Aa]miga' $(BUILD)/binutils/gas/testsuite/gas.sum

.PHONY: check-binutils-ld
check-binutils-ld: $(call if-missing,$(BUILD)/binutils/_done,binutils)
	@rm -f $(BUILD)/binutils/ld/ld.sum
	$(L0)"check ld"$(L1)$(MAKE) -C $(BUILD)/binutils/ld check "RUNTESTFLAGS=amiga.exp"$(L2)
	@{ echo '----- ld -----'; grep -E '^(PASS|FAIL|ERROR|XPASS|UNRESOLVED)' $(BUILD)/binutils/ld/ld.sum 2>/dev/null || echo '(no tests run)'; } | tee $@.summary.txt
	@echo "results: $(BUILD)/binutils/ld/ld.{sum,log}"
	@grep -qE '^PASS' $(BUILD)/binutils/ld/ld.sum
	@! grep -qE '^(FAIL|ERROR|XPASS|UNRESOLVED)' $(BUILD)/binutils/ld/ld.sum

# check-c runs all of execute.exp, and the gcc.dg tests that need the C library's C99
# math functions (c99_runtime, or HAVE_C99_RUNTIME from builtins-config.h), which only
# some of the C libraries have. Override check-c-exp to run other tests, as runtest
# arguments: check-c check-c-exp="'dg.exp=pr12*.c'"
c99-runtime-tests = $(notdir $(shell grep -l -e c99_runtime -e builtins-config.h $(PROJECTS)/gcc/gcc/testsuite/gcc.dg/$2*.c 2>/dev/null))
c99-runtime-exp = $(if $(call c99-runtime-tests,$1,$2),'$1=$(call c99-runtime-tests,$1,$2)')
check-c-exp ?= 'execute.exp=*' \
  $(call c99-runtime-exp,dg.exp,) \
  $(call c99-runtime-exp,dg-torture.exp,torture/) \
  $(call c99-runtime-exp,tree-ssa.exp,tree-ssa/) \
  $(call c99-runtime-exp,ipa.exp,ipa/)

# The C suites are expected to be clean, so any FAIL, ERROR or XPASS fails the target.
# UNRESOLVED is tolerated: DejaGnu cannot tell whether the "amiga" object format
# supports weak symbols, so dg-require-weak tests (20030125-1.c) come out unresolved.
# On a board other than volamos the results are named after it, so that make check
# keeps both runs: gcc-execute-volamos-ixemul.sum, check-c-volamos-ixemul.summary.txt.
# Board options lose their slashes: volamos/-mcrt=clib2 gives gcc-execute-volamos-mcrt=clib2.sum.
check-c-board = $(if $(filter volamos,$(board)),,-$(subst /,,$(board)))
.PHONY: check-c
check-c: $(MIN_IF_MISSING) $(BOARD_SIM_PREREQ)
	ln -sfn $(PREFIX)/$(TARGET)/libnix $(BUILD)/gcc/$(TARGET)/libnix
	$(L0)"check execute.exp"$(L1)$(MAKE) -C $(BUILD)/gcc check-gcc-c "RUNTESTFLAGS=--target_board=$(board) $(strip $(check-c-exp))$(RUNTEST_SIM)"$(L2)
	cp -f $(TESTSUITE)/gcc.sum $(TESTSUITE)/gcc-execute$(check-c-board).sum; cp -f $(TESTSUITE)/gcc.log $(TESTSUITE)/gcc-execute$(check-c-board).log
	{ echo '----- execute.exp $(board) -----'; grep '^# of' $(TESTSUITE)/gcc-execute$(check-c-board).sum || echo '(no tests run)'; grep -E '^(FAIL|ERROR|XPASS)' $(TESTSUITE)/gcc-execute$(check-c-board).sum || true; } | tee $@$(check-c-board).summary.txt
	echo "results: $(TESTSUITE)/gcc-execute$(check-c-board).{sum,log}"
	grep -q '^# of expected passes' $(TESTSUITE)/gcc-execute$(check-c-board).sum
	! grep -qE '^(FAIL|ERROR|XPASS)' $(TESTSUITE)/gcc-execute$(check-c-board).sum

# A no-op on gcc branches that predate amigaos.exp, such as amiga6.
.PHONY: check-gcc-amigaos
check-gcc-amigaos: $(MIN_IF_MISSING) $(BOARD_SIM_PREREQ)
	@ln -sfn $(PREFIX)/$(TARGET)/libnix $(BUILD)/gcc/$(TARGET)/libnix
	$(L0)"check amigaos.exp"$(L1)$(MAKE) -C $(BUILD)/gcc check-gcc-c "RUNTESTFLAGS=--target_board=$(board) gcc.target/m68k/amigaos/amigaos.exp$(RUNTEST_SIM)"$(L2)
	@cp -f $(TESTSUITE)/gcc.sum $(TESTSUITE)/gcc-amigaos.sum; cp -f $(TESTSUITE)/gcc.log $(TESTSUITE)/gcc-amigaos.log
	@{ echo '----- amigaos.exp -----'; grep '^# of' $(TESTSUITE)/gcc-amigaos.sum || echo '(no tests run)'; grep -E '^(FAIL|ERROR|XPASS)' $(TESTSUITE)/gcc-amigaos.sum || true; } | tee $@.summary.txt
	@echo "results: $(TESTSUITE)/gcc-amigaos.{sum,log}"
	@test ! -f $(PROJECTS)/gcc/gcc/testsuite/gcc.target/m68k/amigaos/amigaos.exp || grep -q '^# of expected passes' $(TESTSUITE)/gcc-amigaos.sum
	@! grep -qE '^(FAIL|ERROR|XPASS)' $(TESTSUITE)/gcc-amigaos.sum

# libnix's own target tests (test/Makefile check-target): built from the
# libnix sources with the installed cross compiler and run under volamos
# with its memory sanitizer.  The objects are left in projects/libnix/test
# and rebuilt on every run (-B), since they do not depend on the compiler.
.PHONY: check-libnix
check-libnix: $(MIN_IF_MISSING) $(PREFIX)/bin/volamos
	@set -o pipefail; $(MAKE) --no-print-directory -B -C $(PROJECTS)/libnix/test check-target \
	  CROSS_CC=$(PREFIX)/bin/$(TARGET)-gcc SIM=$(PREFIX)/bin/volamos \
	  SIMFLAGS="--stack 4K --sanitize" 2>&1 | tee $@.summary.txt

# Build libpthread's regression programs for each multilib.  They cannot run
# under the single-tasking simulator because it lacks CreateNewProc().
.PHONY: check-libpthread
check-libpthread: $(BUILD)/libpthread/_done
	@set -o pipefail; if grep -q '^check:' $(BUILD)/libpthread/Makefile.gcc6; then \
	  $(MAKE) --no-print-directory -C $(BUILD)/libpthread -f Makefile.gcc6 check \
	    CC=$(PREFIX)/bin/$(TARGET)-gcc CXX=$(PREFIX)/bin/$(TARGET)-g++ \
	    AR=$(PREFIX)/bin/$(TARGET)-ar; \
	  else echo 'SKIP: aros-stuff does not yet have the pthread check target'; fi \
	  2>&1 | tee $@.summary.txt

# newlib's own testsuite, linked against the installed newlib: the base
# multilib without an FPU (volamos-newlib) and the 68020/68881 one with an
# FPU (volamos-newlib-fpu).
# newlib's check-DEJAGNU runs a single runtest in one directory, where every
# test program is written to a fixed name, so it uses one core.  Instead, one
# runtest per board and .exp file runs in its own directory, with a site.exp
# whose tmpdir points there, and make -j runs them side by side; the results
# are merged per board with gcc's dg-extract-results.sh.  site.exp is
# regenerated with build_alias as its host_alias, which the automake rule
# otherwise leaves empty, and CC_FOR_TARGET spares the PATH lookup.  All the
# runs go to the end, then any FAIL, or a board without results, fails the
# target.
NEWLIBTESTSUITE = $(BUILD)/newlib/newlib/testsuite
NEWLIB_BOARDS = volamos-newlib volamos-newlib-fpu
NEWLIB_TESTSRC = $(PROJECTS)/newlib-cygwin/newlib/testsuite
NEWLIB_EXPS = $(patsubst $(NEWLIB_TESTSRC)/%,%,$(sort $(wildcard $(NEWLIB_TESTSRC)/newlib.*/*.exp)))
# the results directory of board $(1) and .exp file $(2)
newlib-check-dir = $(NEWLIBTESTSUITE)/$(1)/$(subst /,_,$(2:.exp=))
NEWLIB_CHECKS = $(foreach b,$(NEWLIB_BOARDS),$(foreach e,$(NEWLIB_EXPS),$(call newlib-check-dir,$(b),$(e))/newlib.sum))

.PHONY: newlib-site-exp $(NEWLIB_CHECKS)
newlib-site-exp: $(MIN_IF_MISSING) $(PREFIX)/bin/volamos
	@rm -f $(BUILD)/newlib/newlib/site.exp
	@$(MAKE) --no-print-directory -C $(BUILD)/newlib/newlib site.exp build_alias=`$(BUILD_CC) -dumpmachine` >/dev/null

# Each board and .exp file runs in its own directory, in parallel: runtest reads
# newlib's site.exp from there, and DEJAGNU_TMPDIR (see dejagnu-site.exp) keeps
# the test executables apart, or the 68000 board would run the FPU board's.
define newlib-check-rule
$(call newlib-check-dir,$(1),$(2))/newlib.sum: newlib-site-exp
	mkdir -p $$(@D)
	cp $(BUILD)/newlib/newlib/site.exp $$(@D)/site.exp
	cd $$(@D) && DEJAGNU_TMPDIR=$$(@D) runtest --tool newlib --srcdir $(NEWLIB_TESTSRC) --target_board=$(1) \
	  --outdir $$(@D) CC_FOR_TARGET=$(PREFIX)/bin/$(TARGET)-gcc $(2) >runtest.out 2>&1 || true
endef
$(foreach b,$(NEWLIB_BOARDS),$(foreach e,$(NEWLIB_EXPS),$(eval $(call newlib-check-rule,$(b),$(e)))))

.PHONY: check-newlib
check-newlib: $(NEWLIB_CHECKS)
	@for b in $(NEWLIB_BOARDS); do \
	  sums=; for e in $(NEWLIB_EXPS); do sums="$$sums $(NEWLIBTESTSUITE)/$$b/`echo $${e%.exp} | tr / _`/newlib.sum"; done; \
	  $(PROJECTS)/gcc/contrib/dg-extract-results.sh $$sums >$(NEWLIBTESTSUITE)/$$b/newlib.sum; \
	  $(PROJECTS)/gcc/contrib/dg-extract-results.sh -L `echo $$sums | sed 's/newlib\.sum/newlib.log/g'` >$(NEWLIBTESTSUITE)/$$b/newlib.log; \
	done
	@for b in $(NEWLIB_BOARDS); do echo "----- newlib $$b -----"; grep -E '^(# of|FAIL|ERROR|XPASS)' $(NEWLIBTESTSUITE)/$$b/newlib.sum || echo '(no tests run)'; done | tee $@.summary.txt
	@echo "results: $(NEWLIBTESTSUITE)/<board>/newlib.{sum,log}"
	@for b in $(NEWLIB_BOARDS); do grep -q '^# of expected passes' $(NEWLIBTESTSUITE)/$$b/newlib.sum || exit 1; done
	@! grep -qE '^(FAIL|ERROR|XPASS)' $(foreach b,$(NEWLIB_BOARDS),$(NEWLIBTESTSUITE)/$(b)/newlib.sum)

# The full C++ testsuite is large and slow, so it is not part of `check`;
# run it on demand with `make check-c++`.
#
# This suite still has standing failures (AmigaPorts/m68k-amigaos-gcc#57),
# so only an ERROR fails it.
#
# SANITIZE=0 keeps the volamos boards' --sanitize off: the -fstrub tests
# read the scrubbed stack below the stack pointer on purpose.
.PHONY: check-c++
check-c++: $(MIN_IF_MISSING) $(BOARD_SIM_PREREQ)
	@ln -sfn $(PREFIX)/$(TARGET)/libnix $(BUILD)/gcc/$(TARGET)/libnix
	$(L0)"check c++"$(L1)$(MAKE) -C $(BUILD)/gcc check-gcc-c++ "RUNTESTFLAGS=--target_board=$(board)$(RUNTEST_SIM) SANITIZE=0"$(L2)
	@{ echo '----- c++ -----'; grep '^# of' $(CXXTESTSUITE)/g++.sum || echo '(no tests run)'; grep -E '^(FAIL|ERROR|XPASS)' $(CXXTESTSUITE)/g++.sum || true; } | tee $@.summary.txt
	@echo "results: $(CXXTESTSUITE)/g++.{sum,log}"
	@grep -q '^# of expected passes' $(CXXTESTSUITE)/g++.sum
	@! grep -q '^ERROR' $(CXXTESTSUITE)/g++.sum

# shellcheck the build's own shell scripts
.PHONY: check-shell
check-shell:
	shellcheck scripts/* .github/scripts/*.sh

# A libpython dependency would tie the gdb in a release to the build machine's distro
.PHONY: check-gdb-libpython
check-gdb-libpython:
	@! { command -v ldd >/dev/null && test -e $(PREFIX)/bin/$(TARGET)-gdb && ldd $(PREFIX)/bin/$(TARGET)-gdb | grep libpython; }

# The gccrs testsuite, for a toolchain built with ADDLANG=rust. It only
# reports: its standing failures are test bugs on a big-endian ILP32 target
# and CR+LF output through the simulator's pty.
.PHONY: check-rust
check-rust: $(BOARD_SIM_PREREQ)
	@ln -sfn $(PREFIX)/$(TARGET)/libnix $(BUILD)/gcc/$(TARGET)/libnix
	$(L0)"check rust"$(L1)$(MAKE) -C $(BUILD)/gcc check-gcc-rust "RUNTESTFLAGS=--target_board=$(board)$(RUNTEST_SIM)"$(L2)
	@{ echo '----- rust -----'; grep '^# of' $(RUSTTESTSUITE)/rust.sum || echo '(no tests run)'; grep -E '^(FAIL|ERROR|XPASS)' $(RUSTTESTSUITE)/rust.sum || true; } | tee $@.summary.txt
	@echo "results: $(RUSTTESTSUITE)/rust.{sum,log}"

# libc-test, musl's testsuite: its math tests on one C runtime, built with
# libc-test-cflags and run under volamos, see scripts/libc-test.  Not part of
# make check: they still have failures to sort out.
#   make check-libc-test libc-test-crt=newlib libc-test-cflags="-m68020-60 -m68881"
LIBC_TEST_URL = https://repo.or.cz/libc-test.git
libc-test-crt ?= nix20
libc-test-cflags ?=

$(PROJECTS)/libc-test/Makefile:
	cd $(PROJECTS) && git clone --depth 1 $(LIBC_TEST_URL)

# + for the jobserver: libc-test's make, which the script runs, shares this one's -j
.PHONY: check-libc-test
check-libc-test: $(PROJECTS)/libc-test/Makefile $(MIN_IF_MISSING) $(PREFIX)/bin/volamos
	+set -o pipefail; scripts/libc-test $(PROJECTS)/libc-test \
	  $(BUILD)/libc-test/$(libc-test-crt)$(subst $() ,,$(libc-test-cflags)) \
	  $(PREFIX) $(libc-test-crt) $(libc-test-cflags) | tee $@.summary.txt


# =================================================
# info
# =================================================
.PHONY: info
info:
	@echo $@ $(UNAME_S)
	@echo PREFIX=$(PREFIX)
	@echo GCC_VERSION=$(GCC_VERSION)
	@echo CFLAGS=$(CFLAGS)
	@echo CFLAGS_FOR_TARGET=$(CFLAGS_FOR_TARGET)
	@$(CC) -v -E - </dev/null |& grep " version "
	@$(CXX) -v -E - </dev/null |& grep " version "
	@echo $(BUILD)
	@echo $(PROJECTS)
	@echo MODULES = $(modules)

# make -s print-PACKAGE_VERSION prints one variable, for scripts
print-%:
	@echo '$($*)'

# print the latest git log entry for all projects
.PHONY: l
l:
	@for i in $(PROJECTS)/* ; do pushd . >/dev/null; cd $$i 2>/dev/null && ([[ -d ".git" ]] && echo $$i && git log -n1 --pretty=format:'%C(yellow)%h %Cred%ad %Cblue%an%Cgreen%d %Creset%s' --date=short); popd >/dev/null; done
	@echo "." && git log -n1 --pretty=format:'%C(yellow)%h %Cred%ad %Cblue%an%Cgreen%d %Creset%s' --date=short

# print the git remotes for all projects
.PHONY: r
r:
	@for i in $(PROJECTS)/* ; do pushd . >/dev/null; cd $$i 2>/dev/null && ([[ -d ".git" ]] && echo $$i && git remote -v); popd >/dev/null; done
	@echo "." && git remote -v

# print the git branches for all projects
.PHONY: b
b:
	@for i in $(PROJECTS)/* ; do pushd . >/dev/null; cd $$i 2>/dev/null && ([[ -d ".git" ]] && echo $$i && (git branch | grep '*')); popd >/dev/null; done
	@echo "." && git remote -v


# Check out every module at one point, see scripts/checkout: the tag,
# branch or commit ref in all of them, or each module's branch as it was at
# date.  With neither, each module's .repos branch.
#   make v ref=m68k-amigaos-gcc-v16.2-rc18
#   make v date=2026-09-01
.PHONY: v
v:
	@scripts/checkout $(if $(ref),ref $(ref),$(if $(date),date "$(date)"))

# change version to the given branch
.PHONY: branch
branch:
	@set -e; if [ "" != "$(branch)" ] && [ "1" == "$$(grep -c '^$(mod)[[:blank:]]' .repos)" ]; then \
		echo $(mod) $(branch) ; \
	    url=$$(grep '^$(mod)[[:blank:]]' .repos | $(SED) -e 's/[[:blank:]]\+/ /g' | cut -d' ' -f2); \
	    mv .repos .repos.bak; \
	    grep -v '^$(mod)[[:blank:]]' .repos.bak > .repos; \
	    echo "$(mod) $$url $(branch)" >> .repos; \
	    if [ -d  projects/$(mod) ]; then \
	      pushd projects/$(mod); \
	      git remote set-branches --add origin $(branch); \
	      depth=; test "$$(git rev-parse --is-shallow-repository)" = true && depth="--depth 16"; \
	      git fetch $$depth origin +refs/heads/$(branch):refs/remotes/origin/$(branch); \
	      git checkout -B $(branch) refs/remotes/origin/$(branch); \
	      popd ; \
	   fi \
	else \
		echo "$(mod) $(branch) does NOT exist!"; \
	fi


# =================================================
# multilib support
# =================================================
# The libm020 directories serve every CPU from the 68020 up, so they are
# built with -m68020-60, the instructions all of them implement.
MULTI = MODNAME/.: \
		MODNAME/libm020:-m68020-60 \
		MODNAME/libm020/libm881:-m68020-60_-m68881 \
		MODNAME/libb:-fbaserel \
		MODNAME/libb/libm020:-fbaserel_-m68020-60 \
		MODNAME/libb/libm020/libm881:-fbaserel_-m68020-60_-m68881 \
		MODNAME/libb32/libm020:-fbaserel32_-m68020-60 \
		MODNAME/libb32/libm020/libm881:-fbaserel32_-m68020-60_-m68881

# MULTI and gcc/config/m68k/t-amigaos describe the same set of multilibs
# twice: t-amigaos tells the driver which directory a set of flags selects,
# MULTI tells this Makefile which directories to build the libraries for.
# If they drift, a library is built for a directory the driver never selects,
# or the driver selects a directory with nothing in it. check-multilib
# compares MULTI's directories with the built driver's -print-multi-lib.
# A MinGW or AmigaOS hosted driver is run through HOST_RUNNER.
MULTI_DIRS := $(sort $(foreach T,$(MULTI),$(patsubst MODNAME/%,%,$(word 1,$(subst :, ,$(T))))))

.PHONY: check-multilib
check-multilib: $(call if-missing,$(BUILD)/gcc/_done,gcc)
	@driver="$(PREFIX)/bin/$(TARGET)-gcc$(EXEEXT)"; \
	test -f "$$driver" || { echo "check-multilib: $$driver is not built"; exit 1; }; \
	want="$(BUILD)/check-multilib.want"; have="$(BUILD)/check-multilib.have"; mkdir -p "$(BUILD)"; \
	printf '%s\n' $(MULTI_DIRS) | sort > "$$want"; \
	$(HOST_RUNNER) "$$driver" -print-multi-lib | cut -d';' -f1 | sort > "$$have"; \
	if cmp -s "$$want" "$$have"; then \
		echo "check-multilib: MULTI and $$driver agree on $$(wc -l < "$$have" | tr -d ' ') multilib directories"; \
	else \
		echo "check-multilib: MULTI (this Makefile) and t-amigaos (the driver) disagree:"; \
		echo "  only in MULTI:   $$(comm -23 "$$want" "$$have" | tr '\n' ' ')"; \
		echo "  only in driver:  $$(comm -13 "$$want" "$$have" | tr '\n' ' ')"; \
		exit 1; \
	fi

# 1=module name, 2=from name, 3 = to name
COPY_MULTILIBS = $(foreach T, $(subst MODNAME,$1,$(MULTI)),cp $(BUILD)/$(word 1,$(subst :, ,${T}))/$2 $(BUILD)/$(word 1,$(subst :, ,${T}))/$3;)

# 1=module name, 2=lib name
INSTALL_MULTILIBS = $(L0)"install $1"$(L1) $(foreach T, $(subst MODNAME,$1,$(MULTI)),rsync -av --no-group $(BUILD)/$(word 1,$(subst :, ,${T}))/$2 $(PREFIX)/$(TARGET)/lib/$(word 1,$(subst :, ,$(subst $1/,,${T})))/;) $(L2)

# Stop at the first multilib that fails: a plain "cmd; cmd; ..." list
# reported only the status of the last one.
MULTI_STEP_END = || exit 1;

# 1=module name 3,4... = params for make
MULTIMAKE = $(L0)"make $1"$(L1) $(foreach T,$(subst MODNAME,$1,$(MULTI)), $(MAKE) -C $(BUILD)/$(word 1,$(subst :, ,${T})) $3 $4 $5 $6 $7 $8 $(MULTI_STEP_END)) $(L2)

# 1=module name 2=multilib path 3=cflags
MULTICONFIGURE1 = mkdir -p $(BUILD)/$2 && cd $(BUILD)/$2 && \
	PKG_CONFIG=/bin/false CC=$(TARGET)-gcc CXX=$(TARGET)-g++ AR=$(TARGET)-ar LD=$(TARGET)-ld CFLAGS="$(subst _, ,$3) -mcrt=nix20 $(CFLAGS_FOR_TARGET)" $(PROJECTS)/$1/configure

# 1=module name 3,4...= params for configure
MULTICONFIGURE = $(L0)"configure $1"$(L1) $(foreach T,$(subst MODNAME,$1,$(MULTI)),( $(call MULTICONFIGURE1,$1,$(word 1,$(subst :, ,${T})),$(word 2,$(subst :, ,${T}))) $3 $4 $5 $6 $7 $8 ) $(MULTI_STEP_END))$(L2)

# =================================================
# zlib
# =================================================
.PHONY: zlib clean-zlib

clean-zlib:
	rm -rf $(BUILD)/$(zlib_DIR)

zlib: $(BUILD)/$(zlib_DIR)/_done

$(BUILD)/$(zlib_DIR)/_done: $(PREFIX)/$(TARGET)/lib/libz.a
	@echo "done" >$@

$(PREFIX)/$(TARGET)/lib/libz.a: $(BUILD)/$(zlib_DIR)/libz.a
	@rsync -a --no-group $(PROJECTS)/$(zlib_DIR)/zlib.h $(PREFIX)/$(TARGET)/include/
	@rsync -a --no-group $(BUILD)/$(zlib_DIR)/zconf.h $(PREFIX)/$(TARGET)/include/
	$(call INSTALL_MULTILIBS,$(zlib_DIR),libz.a)
	@touch $@

$(BUILD)/$(zlib_DIR)/libz.a: $(BUILD)/$(zlib_DIR)/Makefile
	+$(call MULTIMAKE,$(zlib_DIR),libz.a,AR=$(TARGET)-ar,ARFLAGS=rc)
	@touch $@

$(BUILD)/$(zlib_DIR)/Makefile: $(PROJECTS)/$(zlib_DIR)/configure
	$(call MULTICONFIGURE,$(zlib_DIR),libz.a,)
	@touch $@

# zlib 1.3.2's configure adds -fPIC unconditionally and test-compiles with
# it; the hunk linker has no GOT and gcc rejects -fPIC, so drop it before
# configure runs.
$(PROJECTS)/$(zlib_DIR)/configure: $(DOWNLOAD)/$(zlib_DIR).tar.gz
	tar -C $(PROJECTS) -xf $(DOWNLOAD)/$(zlib_DIR).tar.gz
	$(SED) -i 's/ -fPIC"/"/' $@
	@touch $@

# =================================================
# libpng
# =================================================
.PHONY: libpng clean-libpng

clean-libpng:
	rm -rf $(BUILD)/$(libpng_DIR)

libpng: $(BUILD)/$(libpng_DIR)/_done

$(BUILD)/$(libpng_DIR)/_done: $(PREFIX)/$(TARGET)/lib/libpng.a
	@echo "done" >$@

$(PREFIX)/$(TARGET)/lib/libpng.a: $(BUILD)/$(libpng_DIR)/libpng.a
	@rsync -a --no-group $(PROJECTS)/$(libpng_DIR)/png.h $(PREFIX)/$(TARGET)/include/
	@rsync -a --no-group $(PROJECTS)/$(libpng_DIR)/pngconf.h $(PREFIX)/$(TARGET)/include/
	@rsync -a --no-group $(BUILD)/$(libpng_DIR)/pnglibconf.h $(PREFIX)/$(TARGET)/include/
	@$(call COPY_MULTILIBS,$(libpng_DIR),.libs/libpng16.a,libpng.a)
	$(call INSTALL_MULTILIBS,$(libpng_DIR),libpng.a)
	@touch $@

$(BUILD)/$(libpng_DIR)/libpng.a: $(BUILD)/$(libpng_DIR)/Makefile
	+$(call MULTIMAKE,$(libpng_DIR),libpng.a)
	@touch $@

$(BUILD)/$(libpng_DIR)/Makefile: $(PROJECTS)/$(libpng_DIR)/configure
	$(call MULTICONFIGURE,$(libpng_DIR),libpng.a,--host=$(TARGET))
	@touch $@

$(PROJECTS)/$(libpng_DIR)/configure: $(DOWNLOAD)/$(libpng_DIR).tar.xz $(BUILD)/$(zlib_DIR)/_done $(BUILD)/libnix/_done
	tar -C $(PROJECTS) -xf $(DOWNLOAD)/$(libpng_DIR).tar.xz
	@touch $@

# =================================================
# libfreetype
# =================================================
.PHONY: libfreetype2 clean-libfreetype2

clean-libfreetype2:
	rm -rf $(BUILD)/$(freetype_DIR)

libfreetype2: $(BUILD)/$(freetype_DIR)/_done

$(BUILD)/$(freetype_DIR)/_done: $(PREFIX)/$(TARGET)/lib/libfreetype.a
	@echo "done" >$@

$(PREFIX)/$(TARGET)/lib/libfreetype.a: $(BUILD)/$(freetype_DIR)/libfreetype.a
	@rsync -a --no-group $(PROJECTS)/$(freetype_DIR)/include/ft2build.h $(PREFIX)/$(TARGET)/include/
	@rsync -a --no-group --delete $(PROJECTS)/$(freetype_DIR)/include/freetype $(PREFIX)/$(TARGET)/include/
	@$(call COPY_MULTILIBS,$(freetype_DIR),.libs/libfreetype.a,libfreetype.a)
	$(call INSTALL_MULTILIBS,$(freetype_DIR),libfreetype.a)
	@touch $@

$(BUILD)/$(freetype_DIR)/libfreetype.a: $(BUILD)/$(freetype_DIR)/Makefile
	+$(call MULTIMAKE,$(freetype_DIR),libfreetype.a)
	@touch $@

$(BUILD)/$(freetype_DIR)/Makefile: $(PROJECTS)/$(freetype_DIR)/configure
	$(call MULTICONFIGURE,$(freetype_DIR),libfreetype.a,--host=$(TARGET),--disable-shared)
	@touch $@

$(PROJECTS)/$(freetype_DIR)/configure: $(DOWNLOAD)/$(freetype_DIR).tar.xz $(BUILD)/libnix/_done
	tar -C $(PROJECTS) -xf $(DOWNLOAD)/$(freetype_DIR).tar.xz
	@touch $@
