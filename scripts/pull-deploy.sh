#!/usr/bin/env bash
# Run on the Ansible machine: make the local `deploy` branch exactly match origin/deploy.
# `deploy` is force-pushed on every rebuild, so a plain `git pull` would try to merge; reset instead.
# Untracked files (e.g. vars.yaml) are left alone; edits to tracked files are discarded.
set -euo pipefail
cd "$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
git fetch origin deploy
git checkout -q -B deploy origin/deploy
git log --oneline -1
