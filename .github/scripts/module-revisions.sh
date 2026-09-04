#!/bin/sh
# Print a markdown table of the checked-out module revisions to stdout, so a
# build (its testsuite counts, its release tarball) can be tied to the exact
# sources it came from. Loops over every git checkout under projects/, so new
# modules need no change here. Run from the build tree root; the workflow
# appends the output to the run summary, but it works standalone for testing.
set -u

echo "### Module revisions"
echo "| module | latest commit |"
echo "|---|---|"
for d in projects/*/; do
  [ -d "$d/.git" ] || continue
  line=$(git -C "$d" log -1 --format='`%h` %s' 2>/dev/null) || continue
  printf '| %s | %s |\n' "$(basename "$d")" "$(printf '%s' "$line" | tr '|' '/')"
done
