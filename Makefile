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

PREFIX ?= /opt/amiga
HOST ?=
ifeq (,$(strip $(HOST)))
export PATH := $(PREFIX)/bin:$(PATH)
endif

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
BUILD_TOOLS := $(BUILD)/build-tools
# Helpers which must run on the build machine are private build artifacts.
# Keep them out of PREFIX so they cannot leak into target packages.
BUILD_TOOLS_PREFIX ?= $(BUILD_TOOLS)/prefix

# GitHub container jobs may provide a HOME owned by a different uid.  Keep
# Wine's state in the writable build tree and initialize it once before a
# Windows-hosted compiler can be executed.
ifneq (,$(findstring mingw,$(HOST)))
WINEPREFIX ?= $(BUILD)/wine-prefix
WINEDEBUG ?= -all
WINEBOOT ?= wineboot
WINEPATH ?= Z:$(abspath $(PREFIX)/bin)
WINE_RUNTIME_DIR ?= $(BUILD)/wine-runtime
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
TARGET_EXEC_PREFIX_FOR_BUILD := $(TARGET_TOOL_PREFIX)
else ifneq (,$(strip $(HOST_TOOL_PREFIX)))
TARGET_CC_FOR_BUILD := $(HOST_TOOL_PREFIX)gcc
TARGET_CXX_FOR_BUILD := $(HOST_TOOL_PREFIX)g++
TARGET_AR_FOR_BUILD := $(HOST_TOOL_PREFIX)ar
TARGET_EXEC_PREFIX_FOR_BUILD := $(HOST_TOOL_PREFIX)
else
TARGET_RUNNER_WRAPPER_DIR := $(BUILD_TOOLS)/target-runner
TARGET_RUNNER_TOOL_NAMES := gcc g++ c++ cpp gcc-ar gcc-nm gcc-ranlib \
	addr2line ar as c++filt elfedit ld ld.bfd nm objcopy objdump ranlib \
	readelf size strings strip
TARGET_RUNNER_WRAPPERS := $(patsubst %,$(TARGET_RUNNER_WRAPPER_DIR)/$(TARGET)-%,$(TARGET_RUNNER_TOOL_NAMES))
TARGET_CC_FOR_BUILD := $(TARGET_RUNNER_WRAPPER_DIR)/$(TARGET)-gcc
TARGET_AR_FOR_BUILD := $(TARGET_RUNNER_WRAPPER_DIR)/$(TARGET)-ar
TARGET_CXX_FOR_BUILD := $(TARGET_RUNNER_WRAPPER_DIR)/$(TARGET)-c++
export PATH := $(TARGET_RUNNER_WRAPPER_DIR):$(PATH)
endif
SDK_CC_FOR_BUILD := $(TARGET_CC_FOR_BUILD)
SDK_AR_FOR_BUILD := $(TARGET_AR_FOR_BUILD)
ifneq (,$(strip $(TARGET_EXEC_PREFIX_FOR_BUILD)))
TARGET_EXEC_WRAPPER_DIR := $(BUILD_TOOLS)/target-exec
TARGET_EXEC_TOOL_NAMES := ar as ld ld.bfd nm objcopy objdump ranlib strip
TARGET_EXEC_WRAPPERS := $(patsubst %,$(TARGET_EXEC_WRAPPER_DIR)/%,$(TARGET_EXEC_TOOL_NAMES))
TARGET_GCC_INCLUDE_FOR_BUILD := $(shell $(TARGET_CC_FOR_BUILD) -print-file-name=include 2>/dev/null)
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
$(TARGET_RUNNER_WRAPPER_DIR)/$(TARGET)-%:
	@mkdir -p $(@D)
	@test -n "$(HOST_RUNNER)" || { echo "HOST_RUNNER is required to execute HOST=$(HOST) tools while building TARGET=$(TARGET) libraries"; exit 1; }
	@printf '%s\n' '#!/bin/sh' 'exec $(HOST_RUNNER) "$(PREFIX)/bin/$(TARGET)-$*$(EXEEXT)" "$$@"' >$@
	@chmod +x $@
endif

ifneq (,$(strip $(TARGET_EXEC_WRAPPER_DIR)))
$(TARGET_EXEC_WRAPPER_DIR)/%:
	@mkdir -p $(@D)
	@test -x "$(TARGET_EXEC_PREFIX_FOR_BUILD)$*"
	@ln -sf "$(TARGET_EXEC_PREFIX_FOR_BUILD)$*" $@

$(TARGET_COMPILER_WRAPPERS): $(TARGET_COMPILER_WRAPPER_DIR)/$(TARGET)-%: $(TARGET_EXEC_WRAPPERS)
	@mkdir -p $(@D)
	@test -x "$(TARGET_EXEC_PREFIX_FOR_BUILD)$*"
	@test -n "$(TARGET_GCC_INCLUDE_FOR_BUILD)"
	@printf '%s\n' '#!/bin/sh' 'exec "$(TARGET_EXEC_PREFIX_FOR_BUILD)$*" -B"$(TARGET_EXEC_WRAPPER_DIR)/" -isystem "$(TARGET_GCC_INCLUDE_FOR_BUILD)" "$$@"' >$@
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
PREFIX_STAMP := $(BUILD)/.prefix
ifeq ($(filter clean% drop-prefix help info update% branch,$(MAKECMDGOALS)),)
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

ifeq ($(UNAME_S), Darwin)
	SED := gsed
else ifeq ($(UNAME_S), FreeBSD)
	SED := gsed
else
	SED := sed
endif

# get git urls and branches from .repos file
$(shell  [ ! -f .repos ] && cp default-repos .repos)
modules := $(shell cat .repos | $(SED) -e 's/[[:blank:]]\+/ /g' | cut -d' ' -f1)
get_url = $(shell grep '^$(1)[[:blank:]]' .repos | $(SED) -e 's/[[:blank:]]\+/ /g' | cut -d' ' -f2)
get_branch = $(shell grep '^$(1)[[:blank:]]' .repos | $(SED) -e 's/[[:blank:]]\+/ /g' | cut -d' ' -f3)
$(foreach modu,$(modules),$(eval $(modu)_URL=$(call get_url,$(modu))))
$(foreach modu,$(modules),$(eval $(modu)_BRANCH=$(call get_branch,$(modu))))

ifneq ($(NDK),3.9)
NDK_URL              := https://aminet.net/dev/misc/NDK3.2.lha
NDK_SHA256           := 96cabd4ad683dced632e147bf86dee0f50dcb1254386216c25c362916a6409bb
NDK_ARC_NAME         := NDK3.2
NDK_FOLDER_NAME      := NDK3.2
NDK_FOLDER_NAME_H    := NDK3.2/Include_H
NDK_FOLDER_NAME_I    := NDK3.2/Include_I
NDK_FOLDER_NAME_FD   := NDK3.2/FD
NDK_FOLDER_NAME_SFD  := NDK3.2/SFD
NDK_FOLDER_NAME_LIBS := NDK3.2/lib
else
NDK_URL              := http://hp.alinea-computer.de/AmigaOS/NDK39.lha
NDK_SHA256           :=
NDK_ARC_NAME         := NDK3.9
NDK_FOLDER_NAME      := NDK_3.9/Include
NDK_FOLDER_NAME_H    := NDK_3.9/Include/include_h
NDK_FOLDER_NAME_I    := NDK_3.9/Include/include_i
NDK_FOLDER_NAME_FD   := NDK_3.9/Include/fd
NDK_FOLDER_NAME_SFD  := NDK_3.9/Include/sfd
NDK_FOLDER_NAME_LIBS := NDK_3.9/Include/linker_libs
endif

ifeq (,$(strip $(HOST)))
CFLAGS ?= -Os
CXXFLAGS ?= $(CFLAGS)
BUILD_CFLAGS ?= $(CFLAGS)
BUILD_CXXFLAGS ?= $(CXXFLAGS)
CFLAGS_FOR_TARGET ?= -O2 -fomit-frame-pointer
CXXFLAGS_FOR_TARGET ?= $(CFLAGS_FOR_TARGET) -fno-exceptions -fno-rtti

# Preserve the original native configure environment exactly.
E:=CFLAGS="$(CFLAGS)" CXXFLAGS="$(CXXFLAGS)" CFLAGS_FOR_BUILD="$(CFLAGS)" CXXFLAGS_FOR_BUILD="$(CXXFLAGS)"  CFLAGS_FOR_TARGET="$(CFLAGS_FOR_TARGET)" CXXFLAGS_FOR_TARGET="$(CFLAGS_FOR_TARGET)"
else
CFLAGS ?= -Os $(HOST_CPU_FLAGS) $(HOST_CRT_FLAGS)
CXXFLAGS ?= $(CFLAGS) $(HOST_CXX_ABI_FLAGS)
LDFLAGS ?= $(HOST_LINK_FLAGS)
BUILD_CFLAGS ?= -Os
BUILD_CXXFLAGS ?= $(BUILD_CFLAGS)
BUILD_LDFLAGS ?=
CFLAGS_FOR_TARGET ?= -O2 -fomit-frame-pointer
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

GMP := gmp-6.2.1
GMPFILE := $(GMP).tar.bz2
GMP_SHA256 := eae9326beb4158c386e39a356818031bd28f3124cf915f8c5b1dc4c7a36b4d7c
MPC := mpc-1.2.1
MPCFILE := $(MPC).tar.gz
MPC_SHA256 := 17503d2c395dfcf106b622dc142683c1199431d095367c6aacba6eec30340459
MPFR := mpfr-4.1.0
MPFRFILE := $(MPFR).tar.bz2
MPFR_SHA256 := feced2d430dd5a97805fa289fed3fc8ff2b094c02d05287fd6133e7f1f0ec926
GCC_INFRASTRUCTURE ?= https://gcc.gnu.org/pub/gcc/infrastructure

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
   $(SED) -n '1,/\*\*\*/p' "$$__l" | tail -n 100; \
  echo -e \\033[31m$$__p...failed\\033[0m; \
  echo -e use \\033[1mless \"$$__l\"\\033[0m to view the full log and search for \*\*\*; \
  else echo -e \\n\\033[K\\033[32m$$__p...done\\033[0m; fi \
  ;grep -v "$$__p" .state >.state0 2>/dev/null; mv .state0 .state ;echo -n $$(cat .state | paste -sd " " -); ) 200>.lock; [[ $$__r -gt 0 ]] && exit $$__r; echo -n ""
else
L1 = ;(
L2 = )
endif

# =================================================
# download files
# =================================================
# get-file(label, url, archive name, optional SHA-256)
define get-file
$(L0)"downloading $(1)"$(L1) cd "$(DOWNLOAD)" || exit 1; \
  archive="$(3)"; \
  archive_tmp="$${archive}.neu"; \
  expected_sha256="$(4)"; \
  url="$(2)"; \
  if [ -n "$$AMINET_MIRROR" ]; then \
    url=$$(printf '%s' "$$url" | sed -E "s|^https?://(www\.)?aminet\.net|$$AMINET_MIRROR|"); \
  fi; \
  rm -f "$$archive_tmp"; \
  download_status=1; \
  for download_attempt in 1 2 3 4; do \
    if wget --timeout=10 --tries=1 "$$url" -O "$$archive_tmp"; then \
      download_status=0; \
      break; \
    fi; \
    rm -f "$$archive_tmp"; \
    if [ "$$download_attempt" -lt 4 ]; then \
      echo "download attempt $$download_attempt/4 failed; retrying" >&2; \
      sleep "$$download_attempt"; \
    fi; \
  done; \
  if [ "$$download_status" -ne 0 ]; then \
    echo "failed to download $$url" >&2; \
    exit 1; \
  fi; \
  if [ ! -s "$$archive_tmp" ]; then \
    echo "downloaded archive is empty: $$archive_tmp" >&2; \
    rm -f "$$archive_tmp"; \
    exit 1; \
  fi; \
  if [ -n "$$expected_sha256" ]; then \
    if command -v sha256sum >/dev/null 2>&1; then \
      actual_sha256=$$(sha256sum "$$archive_tmp"); \
    elif command -v shasum >/dev/null 2>&1; then \
      actual_sha256=$$(shasum -a 256 "$$archive_tmp"); \
    else \
      echo "cannot verify $$archive_tmp: sha256sum or shasum is required" >&2; \
      rm -f "$$archive_tmp"; \
      exit 1; \
    fi; \
    actual_sha256=$${actual_sha256%%[[:space:]]*}; \
    if [ "$$actual_sha256" != "$$expected_sha256" ]; then \
      echo "checksum mismatch for $$archive_tmp" >&2; \
      echo "expected: $$expected_sha256" >&2; \
      echo "actual:   $$actual_sha256" >&2; \
      rm -f "$$archive_tmp"; \
      exit 1; \
    fi; \
  fi; \
  if [ -e "$$archive" ] && cmp --silent "$$archive_tmp" "$$archive"; then \
    rm -f "$$archive_tmp"; \
  else \
    mv -f "$$archive_tmp" "$$archive"; \
  fi $(L2)
endef

# =================================================

.PHONY: x init
x:
	@if [ "$(sdk)" == "" ]; then \
		$(MAKE) help; \
	else \
		$(MAKE) sdk; \
	fi

# =================================================
# help
# =================================================
.PHONY: help
help:
	@echo "make help					display this help"
	@echo "make info					print prefix and other flags"
	@echo "make all 					build and install all"
	@echo "make min 					build and install the minimal to use gcc"
	@echo "make <target>					builds a target: binutils, gcc, gprof, fd2sfd, fd2pragma, ira, sfdc, vasm, vbcc, vlink, libnix, ixemul, libgcc, clib2, libdebug, libpthread, ndk, ndk13"
	@echo "make clean					remove the build folder"
	@echo "make clean-<target>				remove the target's build folder"
	@echo "make drop-prefix				remove all content from the prefix folder"
	@echo "make package [PACKAGE_FORMAT=tar.xz|lha]	package the prefix folder for the destination host"
	@echo "make package-lha				package the prefix folder as an .lha archive"
	@echo "make update					perform git pull for all targets"
	@echo "make update-<target>				perform git pull for the given target"
	@echo "make sdk=<sdk>					install the sdk <sdk>"
	@echo "make all-sdk					install all sdks"
	@echo "make l   					print the last log entry for each project"
	@echo "make b   					print the branch for each project"
	@echo "make r   					print the remote for each project"
	@echo "make v [date=<date>]				checkout all projects for a given date, checkout to branch if no date given"
	@echo "make branch branch=<branch> mod=<module>	switch the module to the given branch"
	@echo ""
	@echo "the optional parameter THREADS=posix will build it with thread support"

# =================================================
# all
# =================================================
.PHONY: all gcc gdb gprof binutils fd2sfd fd2pragma ira sfdc vasm libnix ixemul libgcc clib2 libdebug libpthread ndk ndk13 min libnix4.library
ifeq (,$(strip $(HOST)))
all: gcc binutils gdb gprof fd2sfd fd2pragma ira sfdc vasm libnix ixemul libgcc clib2 libdebug libpthread ndk ndk13 libnix4.library
else
all: gcc binutils gprof fd2sfd fd2pragma ira sfdc vasm libnix ixemul libgcc clib2 libdebug libpthread ndk ndk13 libnix4.library
endif

min: binutils gcc gprof libnix libgcc libnix4.library

# =================================================
# clean
# =================================================
ifneq ($(OWNMPC),)
.PHONY: clean-gmp clean-mpc clean-mpfr
clean: clean-gmp clean-mpc clean-mpfr
endif

.PHONY: drop-prefix clean clean-gcc clean-binutils clean-fd2sfd clean-fd2pragma clean-ira clean-sfdc clean-vasm clean-vbcc clean-vlink clean-libnix clean-ixemul clean-libgcc clean-clib2 clean-libdebug clean-libpthread clean-newlib clean-ndk
clean: clean-gcc clean-binutils clean-fd2sfd clean-fd2pragma clean-ira clean-sfdc clean-vasm clean-vbcc clean-vlink clean-libnix clean-ixemul clean-clib2 clean-libdebug clean-libpthread clean-newlib clean-ndk clean-gmp clean-mpc clean-mpfr
	rm -rf $(BUILD)
	rm -rf *.log
	mkdir -p $(BUILD)

clean-gcc:
	rm -rf $(BUILD)/gcc

clean-gmp:
	rm -rf $(PROJECTS)/gcc/gmp

clean-mpc:
	rm -rf $(PROJECTS)/gcc/mpc

clean-mpfr:
	rm -rf $(PROJECTS)/gcc/mpfr

clean-libgcc:
	rm -rf $(BUILD)/gcc/$(TARGET)
	rm -rf $(BUILD)/gcc/_libgcc_done

clean-binutils:
	rm -rf $(BUILD)/binutils

clean-gprof:
	rm -rf $(BUILD)/binutils/gprof

clean-fd2sfd:
	rm -rf $(BUILD)/fd2sfd

clean-fd2pragma:
	rm -rf $(BUILD)/fd2pragma

clean-ira:
	rm -rf $(BUILD)/ira

clean-sfdc:
	rm -rf $(BUILD)/sfdc

clean-vasm:
	rm -rf $(BUILD)/vasm

clean-vbcc:
	rm -rf $(BUILD)/vbcc

clean-vlink:
	rm -rf $(BUILD)/vlink

clean-ndk:
	rm -rf $(BUILD)/ndk*

clean-libnix:
	rm -rf $(BUILD)/libnix

clean-ixemul:
	rm -rf $(BUILD)/ixemul

clean-clib2:
	rm -rf $(BUILD)/clib2

clean-libdebug:
	rm -rf $(BUILD)/libdebug

clean-libpthread:
	rm -rf $(BUILD)/libpthread

clean-newlib:
	rm -rf $(BUILD)/newlib

# drop-prefix drops the files from prefix folder.  It also removes
# build-machine helpers left by versions predating the build-local prefix.
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
PACKAGE_PLATFORM ?= $(UNAME_S)-$(shell uname -m)
else
PACKAGE_PLATFORM ?= $(HOST)
endif
PACKAGE_FORMAT ?= tar.xz
PACKAGE_BASENAME ?= m68k-amigaos-gcc-$(GCC_VERSION)-$(PACKAGE_PLATFORM)
PACKAGE ?= $(PACKAGE_BASENAME).$(PACKAGE_FORMAT)
PACKAGE_LHA ?= lha

.PHONY: package package-lha
package-lha: PACKAGE_FORMAT=lha
package-lha: package

package:
	@test -n "$(GCC_VERSION)" || { echo "GCC_VERSION is empty - run make update first"; exit 1; }
	@case "$(PACKAGE_FORMAT)" in \
	  tar.xz) \
	    XZ_OPT=-T0 tar -C "$(dir $(abspath $(PREFIX)))" -cJf "$(abspath $(PACKAGE))" "$(notdir $(abspath $(PREFIX)))"; \
	    ;; \
	  lha) \
	    command -v "$(PACKAGE_LHA)" >/dev/null || { echo "$(PACKAGE_LHA) is required for PACKAGE_FORMAT=lha"; exit 1; }; \
	    rm -f "$(abspath $(PACKAGE))"; \
	    cd "$(dir $(abspath $(PREFIX)))" && "$(PACKAGE_LHA)" aq "$(abspath $(PACKAGE))" "$(notdir $(abspath $(PREFIX)))"; \
	    ;; \
	  *) \
	    echo "unsupported PACKAGE_FORMAT=$(PACKAGE_FORMAT); use tar.xz or lha"; \
	    exit 2; \
	    ;; \
	esac

# =================================================
# update all projects
# =================================================

.PHONY: update update-gcc update-binutils update-fd2sfd update-fd2pragma update-ira update-sfdc update-vasm update-vbcc update-vlink update-libnix update-ixemul update-clib2 update-libdebug update-libpthread update-ndk update-newlib update-netinclude
update: update-gcc update-binutils update-fd2sfd update-fd2pragma update-ira update-sfdc update-vasm update-vbcc update-vlink update-libnix update-ixemul update-clib2 update-libdebug update-libpthread update-ndk update-newlib update-netinclude
	+$(MAKE) -B $(DOWNLOAD)/vbcc_target_m68k-amigaos.lha
	+$(MAKE) -B $(DOWNLOAD)/vbcc_target_m68k-kick13.lha
	+$(MAKE) -B $(DOWNLOAD)/$(NDK_ARC_NAME).lha
	+$(MAKE) -B $(DOWNLOAD)/ixemul-sdk.lha
	+$(MAKE) -B $(DOWNLOAD)/$(ZLIB).tar.gz
	+$(MAKE) -B $(DOWNLOAD)/$(LIBPNG).tar.xz
	+$(MAKE) -B $(DOWNLOAD)/$(LIBFREETYPE).tar.xz

update-gcc: $(PROJECTS)/gcc/configure
	@cd $(PROJECTS)/gcc && git pull || (export DEPTH=16; while true; do echo "trying depth=$$DEPTH"; git pull --depth $$DEPTH && break; export DEPTH=$$(($$DEPTH+$$DEPTH));done)

update-binutils: $(PROJECTS)/binutils/configure
	@cd $(PROJECTS)/binutils && git pull || (export DEPTH=16; while true; do echo "trying depth=$$DEPTH"; git pull --depth $$DEPTH && break; export DEPTH=$$(($$DEPTH+$$DEPTH));done)

update-fd2sfd: $(PROJECTS)/fd2sfd/configure
	@cd $(PROJECTS)/fd2sfd && git pull

update-fd2pragma: $(PROJECTS)/fd2pragma/makefile
	@cd $(PROJECTS)/fd2pragma && git pull

update-ira: $(PROJECTS)/ira/Makefile
	@cd $(PROJECTS)/ira && git pull

update-sfdc: $(PROJECTS)/sfdc/configure
	@cd $(PROJECTS)/sfdc && git pull

update-vasm: $(PROJECTS)/vasm/Makefile
	@cd $(PROJECTS)/vasm && git pull

update-vbcc: $(PROJECTS)/vbcc/Makefile
	@cd $(PROJECTS)/vbcc && git pull

update-vlink: $(PROJECTS)/vlink/Makefile
	@cd $(PROJECTS)/vlink && git pull

update-libnix: $(PROJECTS)/libnix/Makefile.gcc6
	@cd $(PROJECTS)/libnix && git pull

update-ixemul: $(PROJECTS)/ixemul/configure
	@cd $(PROJECTS)/ixemul && git pull

update-clib2: $(PROJECTS)/clib2/LICENSE
	@cd $(PROJECTS)/clib2 && git pull

update-libdebug: $(PROJECTS)/libdebug/configure
	@cd $(PROJECTS)/libdebug && git pull

update-libpthread: $(PROJECTS)/aros-stuff/pthreads/Makefile
	@cd $(PROJECTS)/aros-stuff && git pull

update-ndk: $(DOWNLOAD)/$(NDK_ARC_NAME).lha
	$(MAKE) $(PROJECTS)/$(NDK_FOLDER_NAME).info

update-newlib: $(PROJECTS)/newlib-cygwin/newlib/configure
	@cd $(PROJECTS)/newlib-cygwin && git pull

update-netinclude: $(PROJECTS)/amiga-netinclude/README.md
	@cd $(PROJECTS)/amiga-netinclude && git pull

.PHONY: gcc-prerequisites update-gmp update-mpc update-mpfr
gcc-prerequisites: $(PROJECTS)/$(GMP)/configure $(PROJECTS)/$(MPFR)/configure $(PROJECTS)/$(MPC)/configure

$(DOWNLOAD)/$(GMPFILE):
	$(call get-file,gmp,$(GCC_INFRASTRUCTURE)/$(GMPFILE),$(GMPFILE),$(GMP_SHA256))

$(DOWNLOAD)/$(MPFRFILE):
	$(call get-file,mpfr,$(GCC_INFRASTRUCTURE)/$(MPFRFILE),$(MPFRFILE),$(MPFR_SHA256))

$(DOWNLOAD)/$(MPCFILE):
	$(call get-file,mpc,$(GCC_INFRASTRUCTURE)/$(MPCFILE),$(MPCFILE),$(MPC_SHA256))

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

update-gmp:
	@rm -rf $(PROJECTS)/$(GMP) $(PROJECTS)/gcc/gmp
	@$(MAKE) $(PROJECTS)/$(GMP)/configure

update-mpfr:
	@rm -rf $(PROJECTS)/$(MPFR) $(PROJECTS)/gcc/mpfr
	@$(MAKE) $(PROJECTS)/$(MPFR)/configure

update-mpc:
	@rm -rf $(PROJECTS)/$(MPC) $(PROJECTS)/gcc/mpc
	@$(MAKE) $(PROJECTS)/$(MPC)/configure

# =================================================
# B I N
# =================================================

# =================================================
# binutils
# =================================================
CONFIG_BINUTILS = --prefix=$(PREFIX) --target=$(TARGET) $(HOST_CONFIGURE) --disable-werror --disable-nls

ifeq (,$(strip $(HOST)))
CONFIG_BINUTILS += --enable-tui --enable-plugins --without-msgpack
else
CONFIG_BINUTILS += --disable-doc --disable-plugins --disable-gdb --disable-gdbserver --without-msgpack
LD_CROSS_MAKE_ENV := bfdplugin_LTLIBRARIES= noinst_LTLIBRARIES=
LD_CROSS_MAKE_FLAGS := -e
endif

# FreeBSD, OSX : libs added by the command brew install gmp
ifeq (Darwin, $(findstring Darwin, $(UNAME_S)))
	BREW_PREFIX := $$(brew --prefix)
	CONFIG_BINUTILS += --with-gmp=$(BREW_PREFIX) --with-mpfr=$(BREW_PREFIX)
endif

ifeq (FreeBSD, $(findstring FreeBSD, $(UNAME_S)))
	PORTS_PREFIX?=/usr/local
	CONFIG_BINUTILS += --with-libgmp-prefix=$(PORTS_PREFIX)
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

BINUTILS_DIR := . bfd gas ld binutils opcodes
BINUTILSD := $(patsubst %,$(PROJECTS)/binutils/%, $(BINUTILS_DIR))

ALL_GDB := all-gdb
INSTALL_GDB := install-gdb

binutils: $(BUILD)/binutils/_done

$(BUILD)/binutils/_done: $(BUILD)/binutils/Makefile $(shell find 2>/dev/null $(PROJECTS)/binutils -not \( -path $(PROJECTS)/binutils/.git -prune \) -not \( -path $(PROJECTS)/binutils/gprof -prune \) -type f)
	@touch -t 0001010000 $(PROJECTS)/binutils/binutils/arparse.y
	@touch -t 0001010000 $(PROJECTS)/binutils/binutils/arlex.l
	@touch -t 0001010000 $(PROJECTS)/binutils/ld/ldgram.y
	@touch -t 0001010000 $(PROJECTS)/binutils/intl/plural.y
	$(L0)"make binutils bfd"$(L1)$(MAKE) -C $(BUILD)/binutils all-bfd $(L2)
	$(L0)"make binutils gas"$(L1)$(MAKE) -C $(BUILD)/binutils all-gas $(L2)
	$(L0)"make binutils binutils"$(L1)$(MAKE) -C $(BUILD)/binutils all-binutils $(L2)
	$(L0)"make binutils ld"$(L1)$(LD_CROSS_MAKE_ENV) $(MAKE) $(LD_CROSS_MAKE_FLAGS) -C $(BUILD)/binutils all-ld $(L2)
	$(L0)"install binutils"$(L1)$(MAKE) -C $(BUILD)/binutils install-gas install-binutils $(L2)
	$(L0)"install binutils ld"$(L1)$(LD_CROSS_MAKE_ENV) $(MAKE) $(LD_CROSS_MAKE_FLAGS) -C $(BUILD)/binutils install-ld $(L2)
	@for tool in $(BINUTILS_HOST_ALIAS_CMD); do \
		ln -f "$(PREFIX)/bin/$$tool$(EXEEXT)" "$(PREFIX)/bin/$(TARGET)-$$tool$(EXEEXT)"; \
	done
	@echo "done" >$@

$(BUILD)/binutils/Makefile: $(PROJECTS)/binutils/configure | $(PREFIX_STAMP)
	@mkdir -p $(BUILD)/binutils
	$(L0)"configure binutils"$(L1) cd $(BUILD)/binutils && $(E) $(PROJECTS)/binutils/configure $(CONFIG_BINUTILS) $(L2)


# GCC and binutils normally need no local patches: AmigaPorts fixes are
# maintained upstream.  Their clone rules retain optional downstream hooks.
$(PROJECTS)/binutils/configure:
	@cd $(PROJECTS) && git clone -b $(binutils_BRANCH) --depth 16 $(binutils_URL) binutils
	for i in $$(find patches/binutils/ -type f 2>/dev/null); \
	do if [[ "$$i" == *.diff ]] ; \
		then j=$${i:8}; patch -N "$(PROJECTS)/$${j%.diff}" "$$i"; fi ; done

# =================================================
# gdb
# =================================================

GDB_CC ?= $(if $(strip $(HOST)),$(CC),gcc)
GDB_CXX ?= $(if $(strip $(HOST)),$(CXX),g++)

gdb: $(BUILD)/binutils/_gdb

$(BUILD)/binutils/_gdb: $(BUILD)/binutils/_done
	$(L0)"make binutils configure gdb"$(L1)$(MAKE) -C $(BUILD)/binutils CC=$(GDB_CC) CXX=$(GDB_CXX) configure-gdb $(L2)
	$(L0)"make binutils gdb libs"$(L1)$(MAKE) -C $(BUILD)/binutils/gdb CC=$(GDB_CC) CXX=$(GDB_CXX) all-lib $(L2)
	$(L0)"make binutils gdb"$(L1)$(MAKE) -C $(BUILD)/binutils CC=$(GDB_CC) CXX=$(GDB_CXX) $(ALL_GDB) $(L2)
	$(L0)"install binutils gdb"$(L1)$(MAKE) -C $(BUILD)/binutils CC=$(GDB_CC) CXX=$(GDB_CXX) install-gas install-binutils install-ld $(INSTALL_GDB) $(L2)
	@echo "done" >$@

# =================================================
# gprof
# =================================================
CONFIG_GRPOF := --prefix=$(PREFIX) --target=$(TARGET) $(HOST_CONFIGURE) --disable-werror

gprof: $(BUILD)/binutils/_gprof

$(BUILD)/binutils/_gprof: $(BUILD)/binutils/gprof/Makefile $(shell find 2>/dev/null $(PROJECTS)/binutils/gprof -type f)
	$(L0)"make gprof"$(L1)$(MAKE) -C $(BUILD)/binutils/gprof all $(L2)
	$(L0)"install gprof"$(L1)$(MAKE) -C $(BUILD)/binutils/gprof install $(L2)
	@echo "done" >$@

$(BUILD)/binutils/gprof/Makefile: $(PROJECTS)/binutils/configure $(BUILD)/binutils/_done
	@mkdir -p $(BUILD)/binutils/gprof
	$(L0)"configure gprof"$(L1) cd $(BUILD)/binutils/gprof && $(E) $(PROJECTS)/binutils/gprof/configure $(CONFIG_GRPOF) $(L2)

# =================================================
# gcc
# =================================================
CONFIG_GCC = --prefix=$(PREFIX) --target=$(TARGET) $(HOST_CONFIGURE) --enable-languages=c,c++,objc,$(ADDLANG) --enable-version-specific-runtime-libs --disable-libssp --disable-nls --without-zstd  \
	--disable-shared --enable-threads=$(THREADS)

ifneq ($(strip $(HOST)),$(TARGET))
CONFIG_GCC += --with-headers=$(PROJECTS)/newlib-cygwin/newlib/libc/sys/amigaos/include/
endif

ifeq (,$(strip $(HOST)))
CONFIG_GCC += --with-stage1-ldflags="-dynamic-libgcc -dynamic-libstdc++" --with-boot-ldflags="-dynamic-libgcc -dynamic-libstdc++"
else
CONFIG_GCC += --disable-werror
endif
ifneq (,$(findstring amigaos,$(HOST)))
# LTO remains enabled for AmigaOS hosts.  GCC omits only the shared
# lto-plugin, which AmigaOS cannot load, while retaining lto1/lto-wrapper.
CONFIG_GCC += --disable-libcc1 --without-static-standard-libraries
# The bootstrap toolchain may predate C++ linkage fixes in the AmigaOS
# headers.  Its libnix also declares popen/pclose despite not providing a
# usable pair.  Keep GCC's optional host probes from enabling those paths;
# this affects only the compiler executables that run on HOST.
GCC_HOST_CONFIGURE_ENV := host_configargs="ac_cv_func_clock_gettime=no ac_cv_func_getrlimit=no ac_cv_func_pclose=no ac_cv_func_popen=no ac_cv_func_setrlimit=no"
GCC_HOST_COMPAT_LIBRARY := $(BUILD)/libamiga-host-compat.a
GCC_HOST_COMPAT_PREREQ := $(GCC_HOST_COMPAT_LIBRARY)
# Use a library here rather than adding the object directly: GCC's top-level
# LDFLAGS are also inherited by libbacktrace's libtool link, and libtool does
# not permit an ordinary non-libtool object in a .la library.
GCC_HOST_LDFLAGS := LDFLAGS="$(LDFLAGS) -Wl,--whole-archive -L$(BUILD) -lamiga-host-compat -Wl,--no-whole-archive"
GCC_HOST_AR := $(if $(strip $(HOST_TOOL_PREFIX)),$(HOST_TOOL_PREFIX)ar,$(TARGET)-ar)
endif

# FreeBSD, OSX : libs added by the command brew install gmp mpfr libmpc
ifeq (Darwin, $(findstring Darwin, $(UNAME_S)))
	BREW_PREFIX := $$(brew --prefix)
	CONFIG_GCC += --with-gmp=$(BREW_PREFIX) \
		--with-mpfr=$(BREW_PREFIX) \
		--with-mpc=$(BREW_PREFIX)
endif

ifeq (FreeBSD, $(findstring FreeBSD, $(UNAME_S)))
	PORTS_PREFIX?=/usr/local
	CONFIG_GCC += --with-gmp=$(PORTS_PREFIX) \
		--with-mpfr=$(PORTS_PREFIX) \
		--with-mpc=$(PORTS_PREFIX)
endif

GCC_CMD := $(TARGET)-c++ $(TARGET)-g++ $(TARGET)-gcc-$(GCC_VERSION) $(TARGET)-gcc-nm \
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
	AR_FOR_TARGET="$(TARGET_AR_FOR_BUILD)"
endif
endif

ifneq (,$(strip $(GCC6_TARGET_CXX_WRAPPER)))
$(GCC6_TARGET_CXX_WRAPPER): $(BUILD)/gcc/_done
	@mkdir -p $(@D)
	@test -n "$(TARGET_CXX_FOR_BUILD)"
	@printf '%s\n' '#!/bin/sh' 'exec "$(TARGET_CXX_FOR_BUILD)" -std=gnu++98 "$$@"' > $@
	@chmod +x $@
endif

GCC_DIR := . gcc gcc/c gcc/c-family gcc/cp gcc/objc gcc/config/m68k libiberty libcpp libdecnumber
GCCD := $(patsubst %,$(PROJECTS)/gcc/%, $(GCC_DIR))

gcc: $(BUILD)/gcc/_done

$(BUILD)/gcc/_done: $(BUILD)/gcc/Makefile $(shell find 2>/dev/null $(GCCD) -maxdepth 1 -type f ) $(HOST_RUNNER_SETUP_PREREQ) $(TARGET_RUNNER_WRAPPERS)
	$(L0)"make gcc"$(L1) $(MAKE) -C $(BUILD)/gcc $(GCC_HOST_TOOLS) $(GCC_BUILD_MAKE_FLAGS) $(GCC_HOST_LDFLAGS) all-gcc $(L2)
	$(L0)"install gcc"$(L1) $(MAKE) -C $(BUILD)/gcc $(GCC_HOST_TOOLS) $(GCC_BUILD_MAKE_FLAGS) $(GCC_HOST_LDFLAGS) install-gcc $(L2)
	@for tool in $(GCC_HOST_ALIAS_CMD); do \
		ln -f "$(PREFIX)/bin/$$tool$(EXEEXT)" "$(PREFIX)/bin/$(TARGET)-$$tool$(EXEEXT)"; \
	done
	@echo "done" >$@

ifneq ($(OWNGMP),)
GCC_PREREQUISITE_SOURCES := $(PROJECTS)/$(GMP)/configure $(PROJECTS)/$(MPFR)/configure $(PROJECTS)/$(MPC)/configure
endif

$(BUILD)/gcc/Makefile: $(PROJECTS)/gcc/configure $(BUILD)/binutils/_done $(GCC_PREREQUISITE_SOURCES) $(GCC_HOST_COMPAT_PREREQ) | $(PREFIX_STAMP)
	@mkdir -p $(BUILD)/gcc
ifneq ($(OWNGMP),)
	@mkdir -p $(PROJECTS)/gcc/gmp
	@mkdir -p $(PROJECTS)/gcc/mpc
	@mkdir -p $(PROJECTS)/gcc/mpfr
	@rsync -a --no-group $(PROJECTS)/$(GMP)/* $(PROJECTS)/gcc/gmp
	@rsync -a --no-group $(PROJECTS)/$(MPC)/* $(PROJECTS)/gcc/mpc
	@rsync -a --no-group $(PROJECTS)/$(MPFR)/* $(PROJECTS)/gcc/mpfr
endif
	$(L0)"configure gcc"$(L1) cd $(BUILD)/gcc && $(E) $(GCC_HOST_TOOLS) $(GCC_HOST_CONFIGURE_ENV) $(GCC_HOST_LDFLAGS) $(PROJECTS)/gcc/configure $(CONFIG_GCC) $(L2)

$(BUILD)/libamiga-host-compat.a: $(BUILD)/gcc-host-compat.o
	$(L0)"archive Amiga host compatibility library"$(L1) $(GCC_HOST_AR) rcs $@ $< $(L2)

$(BUILD)/gcc-host-compat.o: support/amiga-host-compat.c
	@mkdir -p $(@D)
	$(L0)"make Amiga host compatibility object"$(L1) $(CC) $(CFLAGS) -c $< -o $@ $(L2)

$(PROJECTS)/gcc/configure:
	@cd $(PROJECTS) &&	git clone -b $(gcc_BRANCH) --depth 16 $(gcc_URL)
	for i in $$(find patches/gcc/ -type f 2>/dev/null); \
	do if [[ "$$i" == *.diff ]] ; \
		then j=$${i:8}; patch -N "$(PROJECTS)/$${j%.diff}" "$$i"; fi ; done

# =================================================
# fd2sfd
# =================================================
CONFIG_FD2SFD := --prefix=$(PREFIX) --target=$(TARGET) $(HOST_CONFIGURE)
ifneq (,$(strip $(HOST)))
FD2SFD_INSTALL_ARGS := INSTALL_PROGRAM="install --strip-program=$(HOST)-strip"
FD2SFD_BUILD_PREREQ := $(BUILD_TOOLS)/fd2sfd/_done
endif

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
	$(L0)"make fd2sfd for the build machine"$(L1) $(MAKE) -C $(BUILD_TOOLS)/fd2sfd all $(L2)
	@mkdir -p $(BUILD_TOOLS_PREFIX)/bin
	$(L0)"install build-machine fd2sfd"$(L1) $(MAKE) -C $(BUILD_TOOLS)/fd2sfd install $(L2)

$(BUILD_TOOLS)/fd2sfd/Makefile: $(PROJECTS)/fd2sfd/configure
	@mkdir -p $(BUILD_TOOLS)/fd2sfd
	$(L0)"configure fd2sfd for the build machine"$(L1) cd $(BUILD_TOOLS)/fd2sfd && CC="$(BUILD_CC)" CFLAGS="$(BUILD_CFLAGS)" $(PROJECTS)/fd2sfd/configure --prefix=$(BUILD_TOOLS_PREFIX) --target=$(TARGET) $(L2)

$(PROJECTS)/fd2sfd/configure:
	@cd $(PROJECTS) &&	git clone -b $(fd2sfd_BRANCH) --depth 4 $(fd2sfd_URL)
	for i in $$(find patches/fd2sfd/ -type f); \
	do if [[ "$$i" == *.diff ]] ; \
		then j=$${i:8}; patch -N "$(PROJECTS)/$${j%.diff}" "$$i"; fi ; done

# =================================================
# fd2pragma
# =================================================
ifneq (,$(findstring amigaos,$(HOST)))
FD2PRAGMA_TARGET_CFLAGS := -DFD2PRAGMA_READARGS
endif

ifneq (,$(strip $(HOST)))
FD2PRAGMA_BUILD_PREREQ := $(BUILD_TOOLS)/fd2pragma/_done
endif

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
	@cd $(PROJECTS) &&	git clone -b $(fd2pragma_BRANCH) --depth 4 $(fd2pragma_URL)

# =================================================
# ira
# =================================================
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
	@cd $(PROJECTS) &&	git clone -b $(ira_BRANCH) --depth 4 $(ira_URL)

# =================================================
# sfdc
# =================================================
CONFIG_SFDC := --prefix=$(PREFIX) --target=$(TARGET)

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
	@cd $(PROJECTS) &&	git clone -b $(sfdc_BRANCH) --depth 4 $(sfdc_URL)

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
	@cd $(PROJECTS) &&	git clone -b $(vasm_BRANCH) --depth 4 $(vasm_URL)

# =================================================
# vbcc
# =================================================
VBCC_CMD := vbccm68k vprof vc
VBCC := $(patsubst %,$(PREFIX)/bin/%$(EXEEXT), $(VBCC_CMD))

vbcc: $(BUILD)/vbcc/_done

$(BUILD)/vbcc/_done: $(BUILD)/vbcc/Makefile
	$(L0)"make vbcc dtgen"$(L1) TARGET=m68k $(MAKE) -C $(BUILD)/vbcc bin/dtgen $(L2)
	@cd $(BUILD)/vbcc && echo -e "y\\ny\\nsigned char\\ny\\nunsigned char\\nn\\ny\\nsigned short\\nn\\ny\\nunsigned short\\nn\\ny\\nsigned int\\nn\\ny\\nunsigned int\\nn\\ny\\nsigned long long\\nn\\ny\\nunsigned long long\\nn\\ny\\nfloat\\nn\\ny\\ndouble\\n" >c.txt
	$(L0)"run vbcc dtgen"$(L1) cd $(BUILD)/vbcc && bin/dtgen machines/m68k/machine.dt machines/m68k/dt.h machines/m68k/dt.c <c.txt $(L2)
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
	@cd $(PROJECTS) &&	git clone -b $(vbcc_BRANCH) --depth 4 $(vbcc_URL)

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
	@cd $(PROJECTS) &&	git clone -b $(vlink_BRANCH) --depth 4 $(vlink_URL)

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

$(LHA):
	@mkdir -p $(BUILD) && rm -rf $(BUILD)/lha
	$(L0)"clone lha"$(L1) cd $(BUILD) && git clone -b $(lha_BRANCH) --depth 1 $(lha_URL) $(L2)
	$(L0)"configure lha"$(L1) cd $(BUILD)/lha && autoreconf -fi && ./configure $(HOST_CONFIGURE) $(L2)
	$(L0)"make lha"$(L1) cd $(BUILD)/lha && $(MAKE) all $(L2)
	$(L0)"install lha"$(L1) mkdir -p $(PREFIX)/bin && install $(BUILD)/lha/src/lha$(EXEEXT) $(LHA) $(L2)


.PHONY: vbcc-target
vbcc-target: $(BUILD)/vbcc_target_$(TARGET)/_done $(BUILD)/vbcc_target_m68k-kick13/_done

$(BUILD)/vbcc_target_m68k-kick13/_done: $(BUILD)/vbcc_target_m68k-kick13.info patches/vbcc/kick13.config $(BUILD)/vasm/_done
	@mkdir -p $(PREFIX)/m68k-kick13/vbcc/include
	$(L0)"copying vbcc headers"$(L1) rsync --no-group $(BUILD)/vbcc_target_m68k-kick13/targets/m68k-kick13/include/* $(PREFIX)/m68k-kick13/vbcc/include $(L2)
	@mkdir -p $(PREFIX)/m68k-kick13/vbcc/lib
	$(L0)"copying vbcc headers"$(L1) rsync --no-group $(BUILD)/vbcc_target_m68k-kick13/targets/m68k-kick13/lib/* $(PREFIX)/m68k-kick13/vbcc/lib $(L2)
	@mkdir -p $(PREFIX)/bin
	$(L0)"creating vbcc kick13 config"$(L1) $(SED) -e "s|PREFIX|$(PREFIX)|g" patches/vbcc/kick13.config >$(BUILD)/vasm/kick13.config ;\
	install $(BUILD)/vasm/kick13.config $(PREFIX)/bin/ $(L2)
	@echo "done" >$@

$(BUILD)/vbcc_target_m68k-amigaos/_done: $(BUILD)/vbcc_target_m68k-amigaos.info $(wildcard patches/vbcc/*.config) $(BUILD)/vasm/_done
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


$(BUILD)/vbcc_target_m68k-kick13.info: $(DOWNLOAD)/vbcc_target_m68k-kick13.lha $(LHA_PREREQ)
	$(L0)"unpack vbcc_target_m68k-kick13"$(L1) cd $(BUILD) && $(LHA_FOR_BUILD) xf $(DOWNLOAD)/vbcc_target_m68k-kick13.lha $(L2)
	@touch $(BUILD)/vbcc_target_m68k-kick13.info

$(BUILD)/vbcc_target_m68k-amigaos.info: $(DOWNLOAD)/vbcc_target_m68k-amigaos.lha $(LHA_PREREQ)
	$(L0)"unpack vbcc_target_m68k-amigaos"$(L1) cd $(BUILD) && $(LHA_FOR_BUILD) xf $(DOWNLOAD)/vbcc_target_m68k-amigaos.lha $(L2)
	@touch $(BUILD)/vbcc_target_m68k-amigaos.info

$(DOWNLOAD)/vbcc_target_m68k-kick13.lha:
	$(call get-file,vbcc_target13,http://aminet.net/dev/c/vbcc_target_m68k-kick13.lha,vbcc_target_m68k-kick13.lha)

$(DOWNLOAD)/vbcc_target_m68k-amigaos.lha:
	$(call get-file,vbcc_target,http://aminet.net/dev/c/vbcc_target_m68k-amiga.lha,vbcc_target_m68k-amigaos.lha)

# =================================================
# L I B R A R I E S
# =================================================
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

.PHONY: ndk-inline ndk-inline-vbcc ndk-lvo ndk-proto

ndk: $(BUILD)/ndk-include_ndk

$(BUILD)/ndk-include_ndk: $(BUILD)/ndk-include_ndk0 $(NDK_INCLUDE_INLINE) $(NDK_INCLUDE_INLINE_VBCC) $(NDK_INCLUDE_LVO) $(NDK_INCLUDE_PROTO) $(PROJECTS)/fd2sfd/configure $(PROJECTS)/fd2pragma/makefile
	$(MAKE) ndk_inc=1 ndk-proto ndk-lvo ndk-inline ndk-inline-vbcc
	@mkdir -p $(BUILD)/ndk-include/
	@echo "done" >$@

$(BUILD)/ndk-include_ndk0: $(PROJECTS)/$(NDK_FOLDER_NAME).info $(NDK_INCLUDE) $(NDK_FD2SFD_PREREQ) $(NDK_FD2PRAGMA_PREREQ)
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
	@rsync -a --no-group $(PROJECTS)/$(NDK_FOLDER_NAME_FD)/* $(PREFIX)/$(TARGET)/ndk/lib/fd
	@rsync -a --no-group $(PROJECTS)/$(NDK_FOLDER_NAME_SFD)/* $(PREFIX)/$(TARGET)/ndk/lib/sfd
	@rsync -a --no-group $(PROJECTS)/$(NDK_FOLDER_NAME_LIBS)/* $(PREFIX)/$(TARGET)/ndk/lib/libs
	@mkdir -p $(PREFIX)/$(TARGET)/ndk-include/proto
	@cp -p $(PROJECTS)/$(NDK_FOLDER_NAME_H)/proto/alib.h $(PREFIX)/$(TARGET)/ndk-include/proto
	@cp -p $(PROJECTS)/$(NDK_FOLDER_NAME_H)/proto/cardres.h $(PREFIX)/$(TARGET)/ndk-include/proto
	@mkdir -p $(PREFIX)/$(TARGET)/ndk-include/inline
	@cp -p $(PROJECTS)/fd2sfd/cross/share/m68k-amigaos/alib.h $(PREFIX)/$(TARGET)/ndk-include/inline
	@cp -p $(PROJECTS)/fd2pragma/Include/inline/stubs.h $(PREFIX)/$(TARGET)/ndk-include/inline
	@cp -p $(PROJECTS)/fd2pragma/Include/inline/macros.h $(PREFIX)/$(TARGET)/ndk-include/inline
	@mkdir -p $(BUILD)/ndk-include/
	@echo "done" >$@

ndk-inline: $(NDK_INCLUDE_INLINE) sfdc $(BUILD)/ndk-include_inline
$(NDK_INCLUDE_INLINE): $(PREFIX)/bin/sfdc $(NDK_INCLUDE_SFD) $(BUILD)/ndk-include_inline $(BUILD)/ndk-include_lvo $(BUILD)/ndk-include_proto $(BUILD)/ndk-include_ndk0
	$(L0)"sfdc inline $(@F)"$(L1) $(SFDC_FOR_BUILD) --target=m68k-gcc-amigaos --mode=macros --output=$@ $(patsubst $(PREFIX)/$(TARGET)/ndk-include/inline/%.h,$(PROJECTS)/$(NDK_FOLDER_NAME_SFD)/%_lib.sfd,$@) $(L2)

ndk-inline-vbcc: $(NDK_INCLUDE_INLINE_VBCC) sfdc $(BUILD)/ndk-include_inline
$(NDK_INCLUDE_INLINE_VBCC): $(PREFIX)/bin/sfdc $(NDK_INCLUDE_SFD) $(BUILD)/ndk-include_inline $(BUILD)/ndk-include_lvo $(BUILD)/ndk-include_proto $(BUILD)/ndk-include_ndk0
	$(L0)"sfdc inline vbcc $(@F)"$(L1) $(SFDC_FOR_BUILD) --target=m68kvbcc-amigaos --mode=macros --output=$@ $(patsubst $(PREFIX)/$(TARGET)/ndk-include/inline/%_protos.h,$(PROJECTS)/$(NDK_FOLDER_NAME_SFD)/%_lib.sfd,$@) $(L2)

ndk-lvo: $(NDK_INCLUDE_LVO) sfdc
$(NDK_INCLUDE_LVO): $(PREFIX)/bin/sfdc $(NDK_INCLUDE_SFD) $(BUILD)/ndk-include_lvo $(BUILD)/ndk-include_ndk0
	$(L0)"sfdc lvo $(@F)"$(L1) $(SFDC_FOR_BUILD) --target=m68k-amigaos --mode=lvo --output=$@ $(patsubst $(PREFIX)/$(TARGET)/ndk-include/lvo/%_lib.i,$(PROJECTS)/$(NDK_FOLDER_NAME_SFD)/%_lib.sfd,$@) $(L2)

ndk-proto: $(NDK_INCLUDE_PROTO) sfdc
$(NDK_INCLUDE_PROTO): $(PREFIX)/bin/sfdc $(NDK_INCLUDE_SFD)	$(BUILD)/ndk-include_proto $(BUILD)/ndk-include_ndk0
	$(L0)"sfdc proto $(@F)"$(L1) $(SFDC_FOR_BUILD) --target=m68k-amigaos --mode=proto --output=$@ $(patsubst $(PREFIX)/$(TARGET)/ndk-include/proto/%.h,$(PROJECTS)/$(NDK_FOLDER_NAME_SFD)/%_lib.sfd,$@) $(L2)

$(BUILD)/ndk-include_inline: $(PROJECTS)/$(NDK_FOLDER_NAME).info
	@mkdir -p $(PREFIX)/$(TARGET)/ndk-include/inline
	@mkdir -p $(BUILD)/ndk-include/
	@echo "done" >$@

$(BUILD)/ndk-include_lvo: $(PROJECTS)/$(NDK_FOLDER_NAME).info
	@mkdir -p $(PREFIX)/$(TARGET)/ndk-include/lvo
	@mkdir -p $(PREFIX)/$(TARGET)/ndk13-include/lvo
	@mkdir -p $(BUILD)/ndk-include/
	@echo "done" >$@

$(BUILD)/ndk-include_proto: $(PROJECTS)/$(NDK_FOLDER_NAME).info
	@mkdir -p $(PREFIX)/$(TARGET)/ndk-include/proto
	@mkdir -p $(PREFIX)/$(TARGET)/ndk13-include/proto
	@mkdir -p $(BUILD)/ndk-include/
	@echo "done" >$@

$(PROJECTS)/$(NDK_FOLDER_NAME).info: $(LHA_PREREQ) $(DOWNLOAD)/$(NDK_ARC_NAME).lha $(shell find 2>/dev/null patches/$(NDK_FOLDER_NAME)/ -type f)
	$(L0)"unpack ndk"$(L1) cd $(PROJECTS) && if [[ $(NDK_ARC_NAME) == "NDK3.2" ]] ; \
	   then mkdir NDK3.2 ; cd NDK3.2 ; fi ; \
	   $(LHA_FOR_BUILD) xf $(DOWNLOAD)/$(NDK_ARC_NAME).lha $(L2)
	@touch -t 0001010000 $(DOWNLOAD)/$(NDK_ARC_NAME).lha
	$(L0)"patch ndk"$(L1) for i in $$(find patches/$(NDK_FOLDER_NAME)/ -type f); do \
	   if [[ "$$i" == *.diff ]] ; \
		then j=$${i:8}; patch -N "$(PROJECTS)/$${j%.diff}" "$$i"; \
		else cp -pv "$$i" "$(PROJECTS)/$${i:8}"; fi ; done $(L2)
	@touch $(PROJECTS)/$(NDK_FOLDER_NAME).info

$(DOWNLOAD)/$(NDK_ARC_NAME).lha:
	$(call get-file,$(NDK_ARC_NAME),$(NDK_URL),$(NDK_ARC_NAME).lha,$(NDK_SHA256))


# =================================================
# NDK1.3 - emulated from NDK
# =================================================
.PHONY: ndk_13
ndk13: $(BUILD)/ndk-include_ndk13

$(BUILD)/ndk-include_ndk13: $(BUILD)/ndk-include_ndk $(NDK_FD2SFD_PREREQ) $(BUILD)/sfdc/_done
	@while read p; do p=$$(echo $$p|tr -d '\n'); mkdir -p $(PREFIX)/$(TARGET)/ndk13-include/$$(dirname $$p); cp $(PREFIX)/$(TARGET)/ndk-include/$$p $(PREFIX)/$(TARGET)/ndk13-include/$$p; done < patches/ndk13/hfiles
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
	@cd $(PROJECTS) &&	git clone -b $(amiga-netinclude_BRANCH) --depth 4 $(amiga-netinclude_URL)

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
	@cp lib/libamiga.a $@

$(LIBBAMIGA):
	@mkdir -p $(@D)
	@cp lib/libb/libamiga.a $@

# =================================================
# libnix
# =================================================

LIBNIX_SRC = $(shell find 2>/dev/null $(PROJECTS)/libnix -not \( -path $(PROJECTS)/libnix/.git -prune \) -not \( -path $(PROJECTS)/libnix/sources/stubs/libbases -prune \) -not \( -path $(PROJECTS)/libnix/sources/stubs/libnames -prune \) -type f)

libnix: $(BUILD)/libnix/_done

$(BUILD)/libnix/_done: $(BUILD)/newlib/_done $(BUILD)/ndk-include_ndk $(BUILD)/ndk-include_ndk13 $(BUILD)/_netinclude $(BUILD)/binutils/_done $(BUILD)/gcc/_done $(PROJECTS)/libnix/Makefile.gcc6 $(LIBAMIGA) $(LIBNIX_SRC)
	@mkdir -p $(PREFIX)/$(TARGET)/libnix/lib/libnix
	@mkdir -p $(BUILD)/libnix
	@mkdir -p $(PREFIX)/lib/gcc/$(TARGET)/$(GCC_VERSION)
	@if [ ! -e $(PREFIX)/lib/gcc/$(TARGET)/$(GCC_VERSION)/libgcc.a ]; then $(TARGET_AR_FOR_BUILD) rcs $(PREFIX)/lib/gcc/$(TARGET)/$(GCC_VERSION)/libgcc.a; fi
	$(L0)"make libnix"$(L1) CFLAGS="$(CFLAGS_FOR_TARGET)" $(MAKE) -C $(BUILD)/libnix -f $(PROJECTS)/libnix/Makefile.gcc6 root=$(PROJECTS)/libnix all $(L2)
	$(L0)"install libnix"$(L1) $(MAKE) -C $(BUILD)/libnix -f $(PROJECTS)/libnix/Makefile.gcc6 root=$(PROJECTS)/libnix install $(L2)
	@rsync --delete -a --no-group $(PROJECTS)/libnix/sources/headers/* $(PREFIX)/$(TARGET)/libnix/include/
	@echo "done" >$@

$(PROJECTS)/libnix/Makefile.gcc6:
	@cd $(PROJECTS) &&	git clone -b $(libnix_BRANCH) --depth 4 $(libnix_URL)

# =================================================
# gcc libs
# =================================================
LIBGCCS_NAMES := libgcov.a libstdc++.a libsupc++.a
LIBGCCS := $(patsubst %,$(PREFIX)/lib/gcc/$(TARGET)/$(GCC_VERSION)/%,$(LIBGCCS_NAMES))

libgcc: $(BUILD)/gcc/_libgcc_done

$(BUILD)/gcc/_libgcc_done: $(BUILD)/libnix/_done $(BUILD)/libpthread/_done $(LIBAMIGA) $(GCC_TARGET_PREREQ) $(shell find 2>/dev/null $(PROJECTS)/gcc/libgcc -type f)
	$(L0)"make libgcc"$(L1) $(MAKE) -C $(BUILD)/gcc $(GCC_TARGET_MAKE_FLAGS) all-target $(L2)
	$(L0)"install libgcc"$(L1) $(MAKE) -C $(BUILD)/gcc $(GCC_TARGET_MAKE_FLAGS) install-target $(L2)
	@echo "done" >$@

# =================================================
# libnix4.library
# =================================================
libnix4.library: $(BUILD)/libnix/libb/libnix4.library
$(BUILD)/libnix/libb/libnix4.library: $(BUILD)/gcc/_libgcc_done $(BUILD)/libnix/_done
	$(L0)"make libnix4.library"$(L1) CFLAGS="$(CFLAGS_FOR_TARGET)" \
	$(MAKE) -C $(BUILD)/libnix -f $(PROJECTS)/libnix/Makefile.gcc6 root=$(PROJECTS)/libnix libb/libnix4.library $(L2)

# =================================================
# clib2
# =================================================

clib2: $(BUILD)/clib2/_done

$(BUILD)/clib2/_done: $(PROJECTS)/clib2/LICENSE $(shell find 2>/dev/null $(PROJECTS)/clib2 -not \( -path $(PROJECTS)/clib2/.git -prune \) -type f) $(BUILD)/libnix/_done $(LIBAMIGA)
	@mkdir -p $(BUILD)/clib2/
	@rsync -a --no-group $(PROJECTS)/clib2/library/* $(BUILD)/clib2
	@cd $(BUILD)/clib2 && find * -name lib\*.a -delete
	$(L0)"make clib2"$(L1) $(MAKE) -C $(BUILD)/clib2 -f GNUmakefile.68k -j1 $(L2)
	@mkdir -p $(PREFIX)/$(TARGET)/clib2
	@rsync -a --no-group $(BUILD)/clib2/include $(PREFIX)/$(TARGET)/clib2
	@rsync -a --no-group $(BUILD)/clib2/lib $(PREFIX)/$(TARGET)/clib2
	@echo "done" >$@

$(PROJECTS)/clib2/LICENSE:
	@cd $(PROJECTS) && git clone -b $(clib2_BRANCH) --depth 4 $(clib2_URL)

# =================================================
# libdebug
# =================================================
CONFIG_LIBDEBUG := --prefix=$(PREFIX) --target=$(TARGET) --host=$(TARGET)

libdebug: $(BUILD)/libdebug/_done

$(BUILD)/libdebug/_done: $(BUILD)/libdebug/Makefile
	$(L0)"make libdebug"$(L1) $(MAKE) -C $(BUILD)/libdebug $(L2)
	@cp $(BUILD)/libdebug/libdebug.a $(PREFIX)/$(TARGET)/lib/
	@echo "done" >$@

$(BUILD)/libdebug/Makefile: $(BUILD)/gcc/_libgcc_done $(BUILD)/libnix/_done $(PROJECTS)/libdebug/configure $(shell find 2>/dev/null $(PROJECTS)/libdebug -not \( -path $(PROJECTS)/libdebug/.git -prune \) -type f)
	@mkdir -p $(BUILD)/libdebug
	$(L0)"configure libdebug"$(L1) cd $(BUILD)/libdebug && LD=$(TARGET)-ld CC=$(TARGET)-gcc CFLAGS="$(CFLAGS_FOR_TARGET)" $(PROJECTS)/libdebug/configure $(CONFIG_LIBDEBUG) $(L2)

$(PROJECTS)/libdebug/configure:
	@cd $(PROJECTS) &&	git clone -b $(libdebug_BRANCH) --depth 4 $(libdebug_URL)
	@touch -t 0001010000 $(PROJECTS)/libdebug/configure.ac

# =================================================
# libpthread
# =================================================

libpthread: $(BUILD)/libpthread/_done

$(BUILD)/libpthread/_done: $(BUILD)/libpthread/Makefile
	@rsync -a --no-group --exclude=debug.h $(BUILD)/libpthread/*.h $(PREFIX)/$(TARGET)/include/
	$(L0)"make libpthread"$(L1) cd $(BUILD)/libpthread && $(MAKE) -f Makefile.gcc6 $(L2)
	$(L0)"install libpthread lib"$(L1) cp $(BUILD)/libpthread/lib/libpthread.a $(PREFIX)/$(TARGET)/lib/ $(L2)
	$(L0)"install libpthread libb"$(L1) cp $(BUILD)/libpthread/libb/libpthread.a $(PREFIX)/$(TARGET)/lib/libb/ $(L2)
	$(L0)"install libpthread libm020"$(L1) cp $(BUILD)/libpthread/libm020/libpthread.a $(PREFIX)/$(TARGET)/lib/libm020/ $(L2)
	$(L0)"install libpthread libm020bb"$(L1) cp $(BUILD)/libpthread/libm020bb/libpthread.a $(PREFIX)/$(TARGET)/lib/libb/libm020/ $(L2)
	$(L0)"install libpthread libm020bb32"$(L1) cp $(BUILD)/libpthread/libm020bb32/libpthread.a $(PREFIX)/$(TARGET)/lib/libb32/libm020/ $(L2)
	@echo "done" >$@

$(BUILD)/libpthread/Makefile: $(BUILD)/libnix/_done $(PROJECTS)/aros-stuff/pthreads/Makefile $(shell find 2>/dev/null $(PROJECTS)/aros-stuff/pthreads -type f)
	@mkdir -p $(BUILD)/libpthread
	@rsync -a --no-group $(PROJECTS)/aros-stuff/pthreads/* $(BUILD)/libpthread
	@touch $(BUILD)/libpthread/Makefile

$(PROJECTS)/aros-stuff/pthreads/Makefile:
	@cd $(PROJECTS) &&	git clone -b $(aros-stuff_BRANCH) --depth 4 $(aros-stuff_URL)

# =================================================
# newlib
# =================================================
NEWLIB_CONFIG := CC=$(TARGET)-gcc CXX=$(TARGET)-g++
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

$(BUILD)/newlib/newlib/libc.a: $(BUILD)/newlib/newlib/Makefile $(NEWLIB_BINUTILS_PREREQ) $(NEWLIB_FILES)
	@rsync -a --no-group $(PROJECTS)/newlib-cygwin/newlib/libc/include/ $(PREFIX)/$(TARGET)/sys-include
	@rsync -a --no-group $(PROJECTS)/newlib-cygwin/newlib/libc/sys/amigaos/include/ $(PREFIX)/$(TARGET)/sys-include
	$(L0)"make newlib"$(L1) $(MAKE) -C $(BUILD)/newlib/newlib $(L2)
	$(L0)"install newlib"$(L1) $(MAKE) -C $(BUILD)/newlib/newlib install $(L2)
	@touch $@

$(BUILD)/newlib/newlib/Makefile: $(PROJECTS)/newlib-cygwin/newlib/configure $(BUILD)/ndk-include_ndk $(BUILD)/gcc/_done | $(PREFIX_STAMP)
	@mkdir -p $(BUILD)/newlib/newlib
	@if [ ! -f "$(BUILD)/newlib/newlib/Makefile" ]; then \
	$(L00)"configure newlib"$(L1) cd $(BUILD)/newlib/newlib && $(NEWLIB_CONFIG) CFLAGS="$(CFLAGS_FOR_TARGET)" CC_FOR_BUILD="$(CC)" CXXFLAGS="$(CXXFLAGS_FOR_TARGET)" $(PROJECTS)/newlib-cygwin/newlib/configure --host=$(TARGET) --prefix=$(PREFIX) --enable-newlib-io-long-long --enable-newlib-io-c99-formats --enable-newlib-reent-small --enable-newlib-mb --enable-newlib-long-time_t $(L2) \
	; else touch "$(BUILD)/newlib/newlib/Makefile"; fi

$(PROJECTS)/newlib-cygwin/newlib/configure:
	@cd $(PROJECTS) &&	git clone -b $(newlib-cygwin_BRANCH) --depth 4  $(newlib-cygwin_URL)

# =================================================
# ixemul
# =================================================
$(PROJECTS)/ixemul/configure:
	@cd $(PROJECTS) &&	git clone -b $(ixemul_BRANCH) $(ixemul_URL)

.PHONY: ixemul
ixemul:	$(PREFIX)/$(TARGET)/ixemul/lib/libc.a

$(PREFIX)/$(TARGET)/ixemul/lib/libc.a: $(BUILD)/ixemul/lib/libc.a
	@mkdir -p $(PREFIX)/$(TARGET)/ixemul
	$(L0)"installing ixemul-sdk"$(L1) rsync -a --no-group $(BUILD)/ixemul/* $(PREFIX)/$(TARGET)/ixemul/ $(L2)


$(BUILD)/ixemul/lib/libc.a: $(DOWNLOAD)/ixemul-sdk.lha $(LHA_PREREQ)
	@mkdir -p $(BUILD)/ixemul
	$(L0)"unpacking ixemul-sdk.lha"$(L1) cd $(BUILD)/ixemul && $(LHA_FOR_BUILD) xf $(DOWNLOAD)/ixemul-sdk.lha $(L2)

$(DOWNLOAD)/ixemul-sdk.lha:
	$(call get-file,ixemul-sdk,https://aminet.net/util/libs/ixemul-sdk.lha,ixemul-sdk.lha)

# =================================================
# sdk installation
# =================================================
.PHONY: sdk all-sdk
sdk: libnix $(LHA_PREREQ)
	$(L0)"sdk $(sdk)"$(L1) TOOL_RUNNER="$(HOST_RUNNER)" HOST_EXEEXT="$(EXEEXT)" CC_FOR_SDK="$(SDK_CC_FOR_BUILD)" AR_FOR_SDK="$(SDK_AR_FOR_BUILD)" FD2SFD_FOR_BUILD="$(FD2SFD_FOR_BUILD)" SFDC_FOR_BUILD="$(SFDC_FOR_BUILD)" LHA_FOR_BUILD="$(LHA_FOR_BUILD)" $(PWD)/sdk/install install $(sdk) $(PREFIX) $(L2)

SDKS0=$(shell find sdk/*.sdk)
SDKS=$(patsubst sdk/%.sdk,%,$(SDKS0))
.PHONY: $(SDKS)
all-sdk: $(SDKS)

$(SDKS): libnix $(LHA_PREREQ)
	$(MAKE) sdk sdk=$@

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
# run gcc torture check
# =================================================
ifeq (,$(board))
board = amigaos
endif

# Point dejagnu at the in-repo board descriptions in baseboards/ which wire up
# vamos as the simulator.
export DEJAGNU ?= $(CURDIR)/dejagnu-site.exp
# Directory where dejagnu writes gcc.sum / gcc.log.
TESTSUITE = $(BUILD)/gcc/gcc/testsuite/gcc
# The C++ testsuite writes into a separate g++ directory.
CXXTESTSUITE = $(BUILD)/gcc/gcc/testsuite/g++

.PHONY: check check-gcc-execute check-gcc-amigaos check-gcc-c++
# Run the two sequentially (recipe lines run in order even under make -j): both
# drive check-gcc-c in the same build tree, sharing gcc.sum and
# testsuite/gcc-parallel, so they must not run at the same time.
check:
	@$(MAKE) --no-print-directory check-gcc-amigaos
	@$(MAKE) --no-print-directory check-gcc-execute

check-gcc-execute:
	@ln -sf $(PREFIX)/$(TARGET)/libnix $(BUILD)/gcc/$(TARGET)/libnix
	$(L0)"check execute.exp"$(L1)$(MAKE) -C $(BUILD)/gcc check-gcc-c "RUNTESTFLAGS=--target_board=$(board) execute.exp=* SIM=vamos"$(L2)
	@cp -f $(TESTSUITE)/gcc.sum $(TESTSUITE)/gcc-execute.sum; cp -f $(TESTSUITE)/gcc.log $(TESTSUITE)/gcc-execute.log
	@{ echo '----- execute.exp -----'; grep '^# of' $(TESTSUITE)/gcc-execute.sum || echo '(no tests run)'; grep -E '^(FAIL|ERROR|XPASS)' $(TESTSUITE)/gcc-execute.sum || true; } | tee $@.summary.txt

# amiga-specific target tests; a no-op on gcc branches that predate them (a .exp filter matching no file runs nothing).
check-gcc-amigaos:
	@ln -sf $(PREFIX)/$(TARGET)/libnix $(BUILD)/gcc/$(TARGET)/libnix
	$(L0)"check amigaos.exp"$(L1)$(MAKE) -C $(BUILD)/gcc check-gcc-c "RUNTESTFLAGS=--target_board=$(board) gcc.target/m68k/amigaos/amigaos.exp SIM=vamos"$(L2)
	@cp -f $(TESTSUITE)/gcc.sum $(TESTSUITE)/gcc-amigaos.sum; cp -f $(TESTSUITE)/gcc.log $(TESTSUITE)/gcc-amigaos.log
	@{ echo '----- amigaos.exp -----'; grep '^# of' $(TESTSUITE)/gcc-amigaos.sum || echo '(no tests run)'; grep -E '^(FAIL|ERROR|XPASS)' $(TESTSUITE)/gcc-amigaos.sum || true; } | tee $@.summary.txt

# The full C++ testsuite is large and slow under vamos, so it is not part of
# `check`; run it on demand with `make check-gcc-c++`.
check-gcc-c++:
	@ln -sf $(PREFIX)/$(TARGET)/libnix $(BUILD)/gcc/$(TARGET)/libnix
	$(L0)"check c++"$(L1)$(MAKE) -C $(BUILD)/gcc check-gcc-c++ "RUNTESTFLAGS=--target_board=$(board) SIM=vamos"$(L2)
	@{ echo '----- c++ -----'; grep '^# of' $(CXXTESTSUITE)/g++.sum || echo '(no tests run)'; grep -E '^(FAIL|ERROR|XPASS)' $(CXXTESTSUITE)/g++.sum || true; } | tee $@.summary.txt


# =================================================
# info
# =================================================
.PHONY: info v r b l branch
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

# print the latest git log entry for all projects
l:
	@for i in $(PROJECTS)/* ; do pushd . >/dev/null; cd $$i 2>/dev/null && ([[ -d ".git" ]] && echo $$i && git log -n1 --pretty=format:'%C(yellow)%h %Cred%ad %Cblue%an%Cgreen%d %Creset%s' --date=short); popd >/dev/null; done
	@echo "." && git log -n1 --pretty=format:'%C(yellow)%h %Cred%ad %Cblue%an%Cgreen%d %Creset%s' --date=short

# print the git remotes for all projects
r:
	@for i in $(PROJECTS)/* ; do pushd . >/dev/null; cd $$i 2>/dev/null && ([[ -d ".git" ]] && echo $$i && git remote -v); popd >/dev/null; done
	@echo "." && git remote -v

# print the git branches for all projects
b:
	@for i in $(PROJECTS)/* ; do pushd . >/dev/null; cd $$i 2>/dev/null && ([[ -d ".git" ]] && echo $$i && (git branch | grep '*')); popd >/dev/null; done
	@echo "." && git remote -v


# checkout for a given date
v:
	@D="$(date)"; \
	for i in $(modules); do \
		bra=$$(grep $$i .repos | $(SED) -e 's/[[:blank:]]\+/ /g' | cut -d' ' -f3); \
		bra=$${bra/$$'\n'} ;\
		bra=$${bra/$$'\r'} ;\
		if [ -e projects/$$i ]; then \
			pushd projects/$$i >/dev/null; \
			echo $$i;\
			git checkout $$bra; \
			if [ "$$D" != "" ]; then \
				(export DEPTH=16; while [ "" == "$$( git rev-list -n 1 --first-parent --before="$$D" $$bra)" ]; \
					do echo "trying depth=$$DEPTH"; git pull --depth $$DEPTH ; export DEPTH=$$(($$DEPTH+$$DEPTH)); done); \
				git checkout `git rev-list -n 1 --first-parent --before="$$D" $$bra`; \
			fi;\
			popd >/dev/null; \
		fi;\
	done; \
	echo .; \
	B=master; \
	git checkout $$B; \
	if [ "$$D" != "" ]; then \
		git checkout `git rev-list -n 1 --first-parent --before="$$D" $$B`; \
	fi

# change version to the given branch
branch:
	@set -e; if [ "" != "$(branch)" ] && [ "1" == "$$(grep -c '^$(mod)[[:blank:]]' .repos)" ]; then \
		echo $(mod) $(branch) ; \
	    url=$$(grep '^$(mod)[[:blank:]]' .repos | $(SED) -e 's/[[:blank:]]\+/ /g' | cut -d' ' -f2); \
	    mv .repos .repos.bak; \
	    grep -v '^$(mod)[[:blank:]]' .repos.bak > .repos; \
	    echo "$(mod) $$url $(branch)" >> .repos; \
	    if [ -d  projects/$(mod) ]; then \
	      pushd projects/$(mod); \
	      git fetch origin +refs/heads/$(branch):refs/remotes/origin/$(branch); \
	      git checkout -B $(branch) refs/remotes/origin/$(branch); \
	      popd ; \
	   fi \
	else \
		echo "$(mod) $(branch) does NOT exist!"; \
	fi


# =================================================
# multilib support
# =================================================
MULTI = MODNAME/.: \
		MODNAME/libm060:-m68060 \
		MODNAME/libm020:-m68020 \
		MODNAME/libm020/libm881:-m68020_-m68881 \
		MODNAME/libb:-fbaserel \
		MODNAME/libb/libm060:-fbaserel_-m68060 \
		MODNAME/libb/libm020:-fbaserel_-m68020 \
		MODNAME/libb/libm020/libm881:-fbaserel_-m68020_-m68881 \
		MODNAME/libb32/libm060:-fbaserel32_-m68060 \
		MODNAME/libb32/libm020:-fbaserel32_-m68020 \
		MODNAME/libb32/libm020/libm881:-fbaserel32_-m68020_-m68881

# 1=module name, 2=from name, 3 = to name
COPY_MULTILIBS = $(foreach T, $(subst MODNAME,$1,$(MULTI)),cp $(BUILD)/$(word 1,$(subst :, ,${T}))/$2 $(BUILD)/$(word 1,$(subst :, ,${T}))/$3;)

# 1=module name, 2=lib name
INSTALL_MULTILIBS = $(L0)"install $1"$(L1) $(foreach T, $(subst MODNAME,$1,$(MULTI)),rsync -av --no-group $(BUILD)/$(word 1,$(subst :, ,${T}))/$2 $(PREFIX)/$(TARGET)/lib/$(word 1,$(subst :, ,$(subst $1/,,${T})))/;) $(L2)

# 1=module name 3,4... = params for make
MULTIMAKE = $(L0)"make $1"$(L1) $(foreach T,$(subst MODNAME,$1,$(MULTI)), $(MAKE) -C $(BUILD)/$(word 1,$(subst :, ,${T})) $3 $4 $5 $6 $7 $8;) $(L2)

# 1=module name 2=multilib path 3=cflags
MULTICONFIGURE1 = mkdir -p $(BUILD)/$2 && cd $(BUILD)/$2 && \
	PKG_CONFIG=/bin/false CC=$(TARGET)-gcc CXX=$(TARGET)-g++ AR=$(TARGET)-ar LD=$(TARGET)-ld CFLAGS="$(subst _, ,$3) -noixemul $(CFLAGS_FOR_TARGET)" $(PROJECTS)/$1/configure

# 1=module name 3,4...= params for configure
MULTICONFIGURE = $(L0)"configure $1"$(L1) $(foreach T,$(subst MODNAME,$1,$(MULTI)),$(call MULTICONFIGURE1,$1,$(word 1,$(subst :, ,${T})),$(word 2,$(subst :, ,${T}))) $3 $4 $5 $6 $7 $8;)$(L2)

# =================================================
# zlib
# =================================================
ZLIB=zlib-1.3.2

.PHONY: zlib clean-zlib

clean-zlib:
	rm -rf $(BUILD)/$(ZLIB)

zlib: $(BUILD)/$(ZLIB)/_done

$(BUILD)/$(ZLIB)/_done: $(PREFIX)/$(TARGET)/lib/libz.a
	@echo "done" >$@

$(PREFIX)/$(TARGET)/lib/libz.a: $(BUILD)/$(ZLIB)/libz.a
	@rsync -a --no-group $(PROJECTS)/$(ZLIB)/zlib.h $(PREFIX)/$(TARGET)/include/
	@rsync -a --no-group $(BUILD)/$(ZLIB)/zconf.h $(PREFIX)/$(TARGET)/include/
	$(call INSTALL_MULTILIBS,$(ZLIB),libz.a)
	@touch $@

$(BUILD)/$(ZLIB)/libz.a: $(BUILD)/$(ZLIB)/Makefile
	+$(call MULTIMAKE,$(ZLIB),libz.a,AR=$(TARGET)-ar,ARFLAGS=rc)
	@touch $@

$(BUILD)/$(ZLIB)/Makefile: $(PROJECTS)/$(ZLIB)/configure
	$(call MULTICONFIGURE,$(ZLIB),libz.a,)
	@# zlib 1.3.2 adds -fPIC unconditionally; the Amiga assembler has no GOT
	@$(foreach T,$(subst MODNAME,$(ZLIB),$(MULTI)),$(SED) -i 's/ -fPIC//' $(BUILD)/$(word 1,$(subst :, ,${T}))/Makefile;)
	@touch $@

$(PROJECTS)/$(ZLIB)/configure: $(DOWNLOAD)/$(ZLIB).tar.gz
	tar -C $(PROJECTS) -xf $(DOWNLOAD)/$(ZLIB).tar.gz
	@touch $@

$(DOWNLOAD)/$(ZLIB).tar.gz:
	$(call get-file,zlib,https://zlib.net/fossils/$(ZLIB).tar.gz,$(ZLIB).tar.gz,bb329a0a2cd0274d05519d61c667c062e06990d72e125ee2dfa8de64f0119d16)

# =================================================
# libpng
# =================================================
LIBPNG=libpng-1.6.58

.PHONY: libpng clean-libpng

clean-libpng:
	rm -rf $(BUILD)/$(LIBPNG)

libpng: $(BUILD)/$(LIBPNG)/_done

$(BUILD)/$(LIBPNG)/_done: $(PREFIX)/$(TARGET)/lib/libpng.a
	@echo "done" >$@

$(PREFIX)/$(TARGET)/lib/libpng.a: $(BUILD)/$(LIBPNG)/libpng.a
	@rsync -a --no-group $(PROJECTS)/$(LIBPNG)/png.h $(PREFIX)/$(TARGET)/include/
	@rsync -a --no-group $(PROJECTS)/$(LIBPNG)/pngconf.h $(PREFIX)/$(TARGET)/include/
	@rsync -a --no-group $(BUILD)/$(LIBPNG)/pnglibconf.h $(PREFIX)/$(TARGET)/include/
	@$(call COPY_MULTILIBS,$(LIBPNG),.libs/libpng16.a,libpng.a)
	$(call INSTALL_MULTILIBS,$(LIBPNG),libpng.a)
	@touch $@

$(BUILD)/$(LIBPNG)/libpng.a: $(BUILD)/$(LIBPNG)/Makefile
	+$(call MULTIMAKE,$(LIBPNG),libpng.a)
	@touch $@

$(BUILD)/$(LIBPNG)/Makefile: $(PROJECTS)/$(LIBPNG)/configure
	$(call MULTICONFIGURE,$(LIBPNG),libpng.a,--host=$(TARGET))
	@touch $@

$(PROJECTS)/$(LIBPNG)/configure: $(DOWNLOAD)/$(LIBPNG).tar.xz $(BUILD)/$(ZLIB)/_done $(BUILD)/libnix/_done
	tar -C $(PROJECTS) -xf $(DOWNLOAD)/$(LIBPNG).tar.xz
	@touch $@

$(DOWNLOAD)/$(LIBPNG).tar.xz:
	$(call get-file,libpng16,https://sourceforge.net/projects/libpng/files/libpng16/$(subst libpng-,,$(LIBPNG))/$(LIBPNG).tar.xz,$(LIBPNG).tar.xz,28eb403f51f0f7405249132cecfe82ea5c0ef97f1b32c5a65828814ae0d34775)

# =================================================
# libfreetype
# =================================================
LIBFREETYPE=freetype-2.12.1

.PHONY: libfreetype2 clean-libfreetype2

clean-libfreetype2:
	rm -rf $(BUILD)/$(LIBFREETYPE)

libfreetype2: $(BUILD)/$(LIBFREETYPE)/_done

$(BUILD)/$(LIBFREETYPE)/_done: $(PREFIX)/$(TARGET)/lib/libfreetype.a
	@echo "done" >$@

$(PREFIX)/$(TARGET)/lib/libfreetype.a: $(BUILD)/$(LIBFREETYPE)/libfreetype.a
	@rsync -a --no-group $(PROJECTS)/$(LIBFREETYPE)/include/ft2build.h $(PREFIX)/$(TARGET)/include/
	@rsync -a --no-group $(PROJECTS)/$(LIBFREETYPE)/include/freetype $(PREFIX)/$(TARGET)/include/
	@$(call COPY_MULTILIBS,$(LIBFREETYPE),.libs/libfreetype.a,libfreetype.a)
	$(call INSTALL_MULTILIBS,$(LIBFREETYPE),libfreetype.a)
	@touch $@

$(BUILD)/$(LIBFREETYPE)/libfreetype.a: $(BUILD)/$(LIBFREETYPE)/Makefile
	+$(call MULTIMAKE,$(LIBFREETYPE),libfreetype.a)
	@touch $@

$(BUILD)/$(LIBFREETYPE)/Makefile: $(PROJECTS)/$(LIBFREETYPE)/configure
	$(call MULTICONFIGURE,$(LIBFREETYPE),libfreetype.a,--host=$(TARGET),--disable-shared)
	@touch $@

$(PROJECTS)/$(LIBFREETYPE)/configure: $(DOWNLOAD)/$(LIBFREETYPE).tar.xz $(BUILD)/libnix/_done
	tar -C $(PROJECTS) -xf $(DOWNLOAD)/$(LIBFREETYPE).tar.xz
	@touch $@

$(DOWNLOAD)/$(LIBFREETYPE).tar.xz:
	$(call get-file,$(LIBFREETYPE),https://download-mirror.savannah.gnu.org/releases/freetype/$(LIBFREETYPE).tar.xz,$(LIBFREETYPE).tar.xz)
