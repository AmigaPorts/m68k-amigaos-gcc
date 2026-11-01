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

context="toolchain${MAKE_ARGS:+ (make $MAKE_ARGS)}"
case $state in
pending) description="running" ;;
success) description="passed" ;;
failure) description="failed" ;;
*) description="did not finish" ;;
esac

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
	sha=$(gh api "repos/$repo/pulls/$pr" --jq .head.sha) || { echo "::warning::$repo#$pr: cannot read its head"; continue; }
	gh api -X POST "repos/$repo/statuses/$sha" -f state="$state" -f context="$context" \
		-f description="$description" -f target_url="$RUN_URL" > /dev/null &&
		echo "$repo#$pr ($sha): $state" ||
		echo "::warning::$repo#$pr: cannot write its status"
done
exit 0
