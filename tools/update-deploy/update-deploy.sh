#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Jason Laguidice
#
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Rebuilds the local `deploy` branch from the latest upstream master plus the branches in branches.txt, then installs roles.
# Nothing is force-pushed or pulled: `deploy` exists only on this machine and is rebuilt from scratch every run.
# The rebuild is atomic: on any failure the previous `deploy` is left exactly as it was.
#
# Usage: update [--sync-fork] [--install] [--no-roles]
#   --sync-fork  fast-forward your fork's master (origin) to upstream/master
#   --install    also run `just install-all` after the roles are installed
#   --no-roles   only rebuild the branch; skip `just roles`
# Environment: DEPLOY_REPO = the playbook checkout (default: $HOME).
set -euo pipefail

tools_dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
repo="${DEPLOY_REPO:-$HOME}"
sync_fork=0 install=0 roles=1
for arg in "$@"; do
	case "$arg" in
		--sync-fork) sync_fork=1 ;;
		--install) install=1 ;;
		--no-roles) roles=0 ;;
		*) echo "Unknown option: $arg" >&2; exit 2 ;;
	esac
done

cd "$repo"
git rev-parse --git-dir >/dev/null 2>&1 || { echo "$repo is not a git repository (set DEPLOY_REPO)." >&2; exit 1; }
git diff --quiet HEAD || { echo "Tracked files have uncommitted changes; commit or stash them first." >&2; exit 1; }

git config rerere.enabled true
git config rerere.autoupdate true
git config user.email >/dev/null || git config user.email "deploy@$(hostname)"
git config user.name >/dev/null || git config user.name "deploy"
git remote get-url upstream >/dev/null 2>&1 || git remote add upstream https://github.com/spantaleev/matrix-docker-ansible-deploy.git

git fetch --prune upstream
git fetch --prune origin
base="upstream/master"

if [ "$sync_fork" -eq 1 ]; then
	echo "==> syncing fork master to $base"
	git push origin "$base:refs/heads/master"
fi

mapfile -t branches < <(sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$tools_dir/branches.txt" | grep -v '^$' || true)
previous="$(git rev-parse --short -q --verify refs/heads/deploy || echo none)"
start_branch="$(git symbolic-ref -q --short HEAD || true)"

abort_build() {
	git merge --abort 2>/dev/null || true
	git checkout -q -f "${start_branch:-deploy}" 2>/dev/null || true
	git branch -D deploy-build >/dev/null 2>&1 || true
	echo "Rebuild failed; deploy is unchanged (still $previous)." >&2
	exit 1
}

git checkout -q --no-track -B deploy-build "$base"

for b in "${branches[@]}"; do
	if git rev-parse --verify -q "refs/remotes/origin/$b" >/dev/null; then ref="origin/$b"
	else echo "Branch '$b' is not on origin; push it first." >&2; abort_build; fi
	echo "==> merging $ref"
	if git merge --no-edit -m "Merge $b into deploy" "$ref"; then continue; fi
	conflicted="$(git diff --name-only --diff-filter=U)"
	if [ -z "$conflicted" ]; then  # rerere already replayed a recorded resolution
		git commit --no-edit -q && { echo "    (conflict resolved from rerere)"; continue; }
	fi
	if [ "$conflicted" != "group_vars/matrix_servers" ]; then
		echo "Unexpected conflict in: $conflicted" >&2; abort_build
	fi
	echo "    known conflict in group_vars/matrix_servers; applying the baked-in resolution"
	if python3 "$tools_dir/resolve_matrix_servers.py" group_vars/matrix_servers \
		&& ! grep -qE '^(<<<<<<<|=======|>>>>>>>)' group_vars/matrix_servers; then
		git add group_vars/matrix_servers
		git commit --no-edit -q
	else
		echo "The resolver did not recognise this conflict; resolve it by hand (see docs in this tool)." >&2; abort_build
	fi
done

# Every role a branch adds must be present and listed in setup.yml.
for b in "${branches[@]}"; do
	while read -r role; do
		[ -n "$role" ] || continue
		if [ ! -d "roles/custom/$role" ] || ! grep -q "$role" setup.yml; then
			echo "Role '$role' (from $b) is missing from the result or from setup.yml." >&2; abort_build
		fi
	done < <(git diff --name-only --diff-filter=A "$base...origin/$b" -- 'roles/custom/*/tasks/main.yml' | cut -d/ -f3)
done

# Catch template syntax errors before they reach a playbook run (needs python3 with PyYAML and Jinja2, as in Ansible's).
python3 - group_vars/matrix_servers <<'PY' || { echo "group_vars/matrix_servers failed its template check." >&2; abort_build; }
import sys
try:
    import yaml, jinja2
except ImportError:
    print("    (PyYAML/Jinja2 not available: skipping the template check)"); sys.exit(0)
env, bad = jinja2.Environment(), []
def walk(v, name=""):
    if isinstance(v, str) and ("{{" in v or "{%" in v):
        try: env.parse(v)
        except Exception as e: bad.append((name, str(e)))
    elif isinstance(v, dict):
        for k, x in v.items(): walk(x, k)
    elif isinstance(v, list):
        for x in v: walk(x, name)
walk(yaml.safe_load(open(sys.argv[1])))
for n, e in bad: print("TEMPLATE ERROR in %s: %s" % (n, e), file=sys.stderr)
sys.exit(1 if bad else 0)
PY

git checkout -q -B deploy deploy-build
git branch -D deploy-build >/dev/null
git branch --unset-upstream deploy 2>/dev/null || true   # so an accidental `git pull` cannot touch it
echo "deploy rebuilt OK: $base + ${#branches[@]} branch(es) (was $previous, now $(git rev-parse --short HEAD))."

if [ "$roles" -eq 1 ]; then just roles; fi
if [ "$install" -eq 1 ]; then just install-all; fi
