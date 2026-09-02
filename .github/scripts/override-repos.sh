#!/bin/sh
# Apply module source overrides from the workflow's `repos` input to .repos.
# Each space-separated word in $REPOS is module=branch or module=URL#branch.
# Run after the gcc branch has been selected and before `make update`, so a
# module=branch form is not overwritten by the gcc branch selection.
set -e
for spec in $REPOS; do
	mod=${spec%%=*}
	ref=${spec#*=}
	grep -q "^$mod[[:blank:]]" .repos || { echo "unknown module: $mod"; exit 1; }
	case "$ref" in
		*"#"*) sed -i "s|^$mod[[:blank:]].*|$mod ${ref%%#*} ${ref##*#}|" .repos ;;
		*)     make branch mod="$mod" branch="$ref" ;;
	esac
done
cat .repos
