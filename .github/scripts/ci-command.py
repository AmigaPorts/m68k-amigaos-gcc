#!/usr/bin/env python3
# Parse a /ci comment, read from stdin, and start its builds, for
# ci-command.yml.  The syntax is in doc/ci.md.
#
# --dry-run prints the gh commands instead of running them, as if on an open
# pull request, so a comment can be tried without GitHub:
#
#   echo '/ci linux-arm make check-c board=volamos/-mcrt=nix20/-m68020-60/-m68881' | .github/scripts/ci-command.py --dry-run
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
    # a workflow command ends at the first newline: encode them for the annotation
    print("::error::" + text.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A"), flush=True)
    reply(text)
    sys.exit(1)


# A failed gh call shows gh's message, not just its exit status; ci-command.yml
# posts the output of a crash as a reply.
def crashed(kind, value, tb):
    stderr = getattr(value, "stderr", None)
    if stderr:
        print(stderr.strip(), file=sys.stderr, flush=True)
    sys.__excepthook__(kind, value, tb)


sys.excepthook = crashed


repo = env["GH_REPO"]
if env["ASSOCIATION"] not in ("OWNER", "MEMBER", "COLLABORATOR"):
    sys.exit(f"::error::{env['ASSOCIATION']} may not start /ci builds")

# Seen: whatever happens next, a reply says.
gh("api", "-X", "POST", f"repos/{repo}/issues/comments/{env['COMMENT_ID']}/reactions", "-f", "content=rocket")

# The platforms: the ci-* labels of toolchain.yml, but for the ci-check-* ones.
labels = re.findall(r'"ci-([a-z0-9+-]+)"', (Path(__file__).parent.parent / "workflows" / "toolchain.yml").read_text())
platforms = [l for l in dict.fromkeys(labels) if not l.startswith("check")]
usage = (f"Usage: `/ci <platform> [<module>=<branch>...] [make <target>... [VAR=value]...]`, one per line.\n\n"
         f"Platforms: `{' '.join(platforms)}`")
# The modules a <module>=<branch> word can name: default-repos, at the top of
# the sparse checkout.
modules = re.findall(r"^([a-z0-9-]+)\s", (Path(__file__).parent.parent.parent / "default-repos").read_text(), re.M)

# One job per /ci line.
jobs = []
for line in sys.stdin.read().splitlines():
    if line.split()[:1] != ["/ci"]:
        continue
    # Split as a shell would, so that a quoted make argument keeps its spaces:
    # make_args goes on re-quoted, and toolchain.yml splits it the same way.
    try:
        words = shlex.split(line)
    except ValueError as e:
        fail(f"`{line}`: {e}.\n\n{usage}")
    platform = words[1].lower().removeprefix("ci-") if len(words) > 1 else ""
    if platform not in platforms:
        fail(f"`{platform}` is not a platform.\n\n{usage}" if platform else usage)
    rest = words[2:]
    repos = []
    while rest and (m := re.fullmatch(r"([a-z0-9-]+)=([A-Za-z0-9._/-]+)", rest[0])) and m[1] in modules:
        repos.append(rest.pop(0))
    if rest and rest[0] != "make":
        fail(f"Did you mean `/ci {' '.join(words[1:2] + repos)} make {shlex.join(rest)}`?\n\n{usage}")
    jobs.append({"label": "ci-" + platform, "repos": " ".join(repos), "make_args": shlex.join(rest[1:])})
if not jobs:
    fail(usage)
matrix = json.dumps(jobs, separators=(",", ":"))
# The commit status's name: the comment's /ci lines.
context = "; ".join(f"/ci {j['label'].removeprefix('ci-')}" + (f" {j['repos']}" if j["repos"] else "")
                    + (f" make {j['make_args']}" if j["make_args"] else "")
                    for j in jobs)
# GitHub rejects a long one: five /ci lines were too many.
if len(context) > 100:
    context = context[:97] + "..."

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
builds = "\n".join(f"- On {j['label'].removeprefix('ci-')}"
                   + (f" with {j['repos']}" if j["repos"] else "") + ": "
                   + (f"`make {j['make_args']}`" if j["make_args"] else "the default build and tests")
                   for j in jobs)
reply(f"Building {head[:9]} merged into {base}: {env['RUN_URL']}\n\n{builds}")
