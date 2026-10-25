#!/usr/bin/env python3
# Parse a /ci comment, read from stdin, and start its builds, for
# ci-command.yml.  The syntax is in doc/ci.md.
#
# --dry-run prints the gh commands instead of running them, as if on an open
# pull request, so a comment can be tried without GitHub:
#
#   echo '/ci linux-arm make check-c board=volamos-fpu' | .github/scripts/ci-command.py --dry-run
#
# The outputs for the workflow go to $GITHUB_OUTPUT, or to stdout without it.

import json
import os
import re
import shlex
import subprocess
import sys
from pathlib import Path

dry_run = sys.argv[1:] == ["--dry-run"]

env = dict(os.environ)
if dry_run:
    # Stand-ins for what ci-command.yml sets.
    for name, value in {
            "ASSOCIATION": "OWNER",
            "GH_REPO": "AmigaPorts/m68k-amigaos-gcc",
            "PR": "68040",
            "COMMENT_ID": "666",
            "RUN_URL": "https://github.com/runs/42"
        }.items():
        env.setdefault(name, value)


def gh(*args):
    if dry_run:
        print("gh", shlex.join(args), flush=True)
        # The only answer used: the pull request's, open and mergeable.
        return json.dumps({"state": "open", "mergeable": True,
                           "base": {"ref": "master"}, "head": {"sha": "0" * 40}})
    return subprocess.run(["gh", *args], check=True, capture_output=True, text=True).stdout


def reply(text):
    gh("pr", "comment", env["PR"], "--body", text)


def fail(text):
    print(f"::error::{text}", flush=True)
    reply(text)
    sys.exit(1)


repo = env["GH_REPO"]
if env["ASSOCIATION"] not in ("OWNER", "MEMBER", "COLLABORATOR"):
    sys.exit(f"::error::{env['ASSOCIATION']} may not start /ci builds")

# Seen: whatever happens next, a reply says.
gh("api", "-X", "POST", f"repos/{repo}/issues/comments/{env['COMMENT_ID']}/reactions", "-f", "content=rocket")

# The platforms: the ci-* labels of toolchain.yml, but for the ci-check-* ones.
labels = re.findall(r'"ci-([a-z0-9+-]+)"', (Path(__file__).parent.parent / "workflows" / "toolchain.yml").read_text())
platforms = [l for l in dict.fromkeys(labels) if not l.startswith("check")]
usage = (f"Usage: `/ci <platform> [make <target>... [VAR=value]...]`, one per line. "
         f"Platforms: `{' '.join(platforms)}`")

# One job per /ci line.
jobs = []
for line in sys.stdin.read().splitlines():
    words = line.split()
    if not words or words[0] != "/ci":
        continue
    platform = words[1].lower().removeprefix("ci-") if len(words) > 1 else ""
    if platform not in platforms:
        fail(f"`{platform}` is not a platform. {usage}" if platform else usage)
    if len(words) > 2 and words[2] != "make":
        fail(f"Did you mean `/ci {platform} make {' '.join(words[2:])}`? {usage}")
    jobs.append({"label": "ci-" + platform, "make_args": " ".join(words[3:])})
if not jobs:
    fail(usage)
matrix = json.dumps(jobs, separators=(",", ":"))
# The commit status's name: the comment's /ci lines.
context = "; ".join(f"/ci {j['label'].removeprefix('ci-')}" + (f" make {j['make_args']}" if j["make_args"] else "")
                    for j in jobs)

pr = json.loads(gh("api", f"repos/{repo}/pulls/{env['PR']}"))
base = pr["base"]["ref"]
if pr["state"] != "open":
    fail("Pull request is not open.")
# No refs/pull/N/merge to build.  Asking also makes GitHub refresh it.
if pr["mergeable"] is False:
    fail(f"The pull request conflicts with {base}: rebase it first.")
head = pr["head"]["sha"]
# A gcc pull request builds the toolchain for its own branch: amiga6 for gcc 6,
# amiga16.2 for 16.2.
gcc_version = base.removeprefix("amiga") if env.get("MODULE") == "gcc" else ""

with open(env.get("GITHUB_OUTPUT", "/dev/stdout"), "a") as out:
    out.write(f"matrix={matrix}\nhead={head}\ngcc_version={gcc_version}\ncontext={context}\n")

# A commit status on the head, so the run shows in the pull request's checks.
# The same comment again updates it.
gh("api", f"repos/{repo}/statuses/{head}", "-f", "state=pending", "-f", f"context={context}",
   "-f", f"target_url={env['RUN_URL']}")
builds = "\n".join(f"- On {j['label'].removeprefix('ci-')}: "
                   + (f"`make {j['make_args']}`" if j["make_args"] else "the default build and tests")
                   for j in jobs)
reply(f"Building {head[:9]} merged into {base}: {env['RUN_URL']}\n\n{builds}")
