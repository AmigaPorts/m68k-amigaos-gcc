#!/bin/bash
# Reuse a toolchain restored from the Actions cache.
#
#   .github/scripts/toolchain-cache.sh record <build-dir>
#   .github/scripts/toolchain-cache.sh prepare <build-dir> <prefix> [<restored-path>...]
#
# record saves the module commits next to the build, for a later prepare.
# prepare runs after make update, on what the cache just restored: the build
# tree, the prefix and the other paths, such as the unpacked NDK.  A fresh
# checkout gives every source a new mtime, newer than the restored build, so:
#  - every restored file gets the same mtime T, now: later than the checkout,
#    and equal times are up to date to make, whichever of them a rule
#    produces from which;
#  - the sources of the modules whose commit changed since the build get the
#    current time, after T.
# make then rebuilds the changed modules and what depends on them, also where
# a rule installs into the prefix directly, and leaves the rest alone.  The
# cache key covers the Makefile and the patches, so the restored trees match
# them.
set -euo pipefail
usage="usage: $0 record <build-dir> | prepare <build-dir> <prefix> [<restored-path>...]"
cmd=${1:?$usage}
build=${2:?$usage}
here=$(git -C "$(dirname "$(readlink -f "$0")")" rev-parse --show-toplevel)
projects=${PROJECTS:-$here/projects}
manifest=$build/.cache-manifest

case $cmd in
record)
	"$here/scripts/manifest" > "$manifest"
	;;
prepare)
	[ $# -ge 3 ] || { echo "$usage" >&2; exit 1; }
	if [ ! -f "$manifest" ]; then
		echo "no recorded manifest: nothing to reuse"
		exit 0
	fi
	changed=()
	while read -r name _ commit; do
		case $name in "#"*) continue ;; esac
		was=$(awk -v n="$name" '$1 == n { print $3 }' "$manifest")
		if [ "$was" != "$commit" ]; then
			echo "changed: $name (${was:-new} -> $commit)"
			changed+=("$name")
		fi
	done < <("$here/scripts/manifest")
	shift 1
	t=$(date +%s)
	for p in "$@"; do
		[ -e "$p" ] && find "$p" -exec touch -h -d "@$t" {} +
	done
	# mtimes compare by the second here: be sure to be past T
	sleep 2
	for m in ${changed[@]+"${changed[@]}"}; do
		find "$projects/$m" -path "$projects/$m/.git" -prune -o -exec touch -h {} +
	done
	echo "restored files at $(date -d "@$t" +%T), the sources of ${#changed[@]} changed module(s) after"
	;;
*)
	echo "$usage" >&2
	exit 1
	;;
esac
