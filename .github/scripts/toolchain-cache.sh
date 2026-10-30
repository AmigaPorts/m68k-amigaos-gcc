#!/bin/bash
# Reuse a toolchain restored from the Actions cache.
#
#   .github/scripts/toolchain-cache.sh record <build-dir>
#   .github/scripts/toolchain-cache.sh prepare <build-dir> [<restored-path>...]
#
# record saves the module commits next to the build, for a later prepare.
# prepare runs after make update, on a build tree and prefix the cache just
# restored: a fresh checkout gives every source a new mtime, so it touches
# the whole build tree, except the build directories of the modules whose
# commit changed since the build, and the other restored paths, such as the
# unpacked NDK, whose rules depend on this repository's patches.  The cache
# key covers the Makefile and the patches, so those match the restored trees.
# make then rebuilds the changed modules and what depends on them, and leaves
# the rest alone.
set -euo pipefail
cmd=${1:?usage: $0 record|prepare <build-dir>}
build=${2:?usage: $0 record|prepare <build-dir>}
here=$(git -C "$(dirname "$(readlink -f "$0")")" rev-parse --show-toplevel)
manifest=$build/.cache-manifest

case $cmd in
record)
	"$here/scripts/manifest" > "$manifest"
	;;
prepare)
	if [ ! -f "$manifest" ]; then
		echo "no recorded manifest: nothing to reuse"
		exit 0
	fi
	# Modules whose commit differs from the build's, by their build
	# directory: newlib-cygwin builds in newlib, amiga-netinclude in
	# _netinclude, every other module in a directory of its own name.
	changed=()
	while read -r name _ commit; do
		case $name in "#"*) continue ;; esac
		dir=$name
		case $name in
		newlib-cygwin) dir=newlib ;;
		amiga-netinclude) dir=_netinclude ;;
		esac
		was=$(awk -v n="$name" '$1 == n { print $3 }' "$manifest")
		if [ "$was" != "$commit" ]; then
			echo "changed: $name (${was:-new} -> $commit)"
			changed+=("$build/$dir")
		fi
	done < <("$here/scripts/manifest")
	prune=()
	for d in ${changed[@]+"${changed[@]}"}; do
		prune+=(-path "$d" -prune -o)
	done
	# the other restored paths first: the build depends on them, so it must
	# come out newer
	shift 2
	for p in "$@"; do
		[ -e "$p" ] && find "$p" -exec touch -h {} +
	done
	find "$build" ${prune[@]+"${prune[@]}"} -exec touch -h {} +
	echo "touched the build tree, except ${#changed[@]} changed module(s), and $# other restored path(s)"
	;;
*)
	echo "usage: $0 record|prepare <build-dir>" >&2
	exit 1
	;;
esac
