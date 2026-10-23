#!/bin/sh
# Merge a pull request's head commit into the checkout in DIR, which is at
# the base branch commit to test it against, as merging the pull request
# would.  For a /ci comment (ci-command.yml): GitHub's refs/pull/N/merge is
# only recomputed when the pull request changes, not when its base moves.
# A shallow checkout is deepened until the two share a merge base.
#   merge-pr.sh DIR HEAD_SHA
set -e
dir=$1
head=$2
base=$(git -C "$dir" rev-parse HEAD)
if [ "$(git -C "$dir" rev-parse --is-shallow-repository)" = true ]; then
	git -C "$dir" fetch -q --depth 64 origin "$head"
else
	git -C "$dir" fetch -q origin "$head"
fi
depth=64
while ! git -C "$dir" merge-base HEAD "$head" >/dev/null 2>&1; do
	if [ "$(git -C "$dir" rev-parse --is-shallow-repository)" != true ]; then
		echo "no merge base between $base and $head"
		exit 1
	fi
	depth=$((depth * 4))
	if [ $depth -gt 16384 ]; then
		git -C "$dir" fetch -q --unshallow origin "$base" "$head"
	else
		git -C "$dir" fetch -q --deepen=$depth origin "$base" "$head"
	fi
done
echo "merging $head into $base"
git -C "$dir" -c user.name=ci -c user.email=ci@localhost \
	merge -q --no-ff --no-edit "$head"
