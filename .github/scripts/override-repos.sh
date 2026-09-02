#!/bin/sh
# Apply module source overrides from the workflow's `repos` input to the
# build tree. Each space-separated word in $REPOS is one of:
#   module=branch     - select a branch on the module's default remote
#   module=URL#ref    - build ref (a branch or an exact commit sha) from URL
# Run after the gcc branch has been selected and before `make update`, so a
# module=branch form is not overwritten by the gcc branch selection.
set -e
for spec in $REPOS; do
	mod=${spec%%=*}
	ref=${spec#*=}
	grep -q "^$mod[[:blank:]]" .repos || { echo "unknown module: $mod"; exit 1; }
	case "$ref" in
	*"#"*)
		# Fetch the exact ref into projects/<mod> and check it out, so
		# `make update` finds it in place and skips cloning. `git fetch`
		# takes a branch or a commit sha, so passing a PR head sha here
		# builds that exact revision even if the branch is force-pushed
		# before the checkout runs.
		url=${ref%%#*}
		want=${ref##*#}
		echo "fetching $mod from $url @ $want"
		rm -rf "projects/$mod"
		git init -q "projects/$mod"
		git -C "projects/$mod" remote add origin "$url"
		git -C "projects/$mod" fetch -q --depth 16 origin "$want"
		git -C "projects/$mod" checkout -q FETCH_HEAD
		;;
	*)
		make branch mod="$mod" branch="$ref"
		;;
	esac
done
cat .repos
