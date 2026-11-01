#!/bin/sh
# Report a dispatched run on the module pull requests it builds, as a commit
# status on each one's head: a run of this repository's workflow otherwise
# shows nowhere on the module's pull request.
#
#   pr-status.sh pending|success|failure|error
#
# Takes from the environment:
#   REPOS      the workflow's repos input; each module=URL#refs/pull/N/merge
#              word whose URL is on github.com gets a status
#   HEADS      for the final state: the heads that pending wrote to
#              $GITHUB_OUTPUT, so the result lands on the commits marked
#              pending even if a pull request moved on during the run
#   MAKE_ARGS  the run's make arguments, which name the status, so that
#              runs with different ones are separate checks
#   RUN_URL    the link the status points to
#   GH_TOKEN   a token that may write commit statuses in the module repos;
#              without one the script only says so
#
# A status that cannot be written is a warning, never a failed run.
set -u
state=$1

[ -n "$GH_TOKEN" ] || { echo "::notice::no PR_STATUS_TOKEN: not reporting on the module pull requests"; exit 0; }

# GitHub rejects a context longer than 100 characters
context=$(printf '%.100s' "toolchain${MAKE_ARGS:+ (make $MAKE_ARGS)}")
case $state in
pending) description="running" ;;
success) description="passed" ;;
failure) description="failed" ;;
*) description="did not finish" ;;
esac

# repo#pr=sha for each pull request in REPOS
heads() {
	for spec in $REPOS; do
		ref=${spec#*=}
		url=${ref%%#*}
		want=${ref##*#}
		case "$url#$want" in
		https://github.com/*/*#refs/pull/*/merge) ;;
		*) continue ;;
		esac
		repo=${url#https://github.com/}
		repo=${repo%.git}
		pr=${want#refs/pull/}
		pr=${pr%/merge}
		sha=$(gh api "repos/$repo/pulls/$pr" --jq .head.sha) || { echo "::warning::$repo#$pr: cannot read its head" >&2; continue; }
		echo "$repo#$pr=$sha"
	done
}

if [ "$state" = pending ]; then
	HEADS=$(heads | tr '\n' ' ')
	echo "heads=$HEADS" >> "${GITHUB_OUTPUT:-/dev/null}"
fi

for head in ${HEADS-}; do
	sha=${head#*=}
	repo=${head%%#*}
	gh api -X POST "repos/$repo/statuses/$sha" -f state="$state" -f context="$context" \
		-f description="$description" -f target_url="$RUN_URL" > /dev/null &&
		echo "${head%%=*} ($sha): $state" ||
		echo "::warning::${head%%=*}: cannot write its status"
done
exit 0
