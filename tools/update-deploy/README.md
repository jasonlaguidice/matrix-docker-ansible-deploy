<!--
SPDX-FileCopyrightText: 2026 Jason Laguidice

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# update-deploy

Rebuilds the local `deploy` branch of the playbook checkout from the latest `upstream/master` plus the branches
listed in `branches.txt`, then installs roles. Run it on the Ansible host as `update`.

- `update`: rebuild `deploy`, then `just roles`
- `update --install`: also `just install-all`
- `update --sync-fork`: also fast-forward your fork's `master` to `upstream/master`
- `update --no-roles`: only rebuild the branch

Add a work-in-progress branch by pushing it to `origin` and adding its name to `branches.txt`.

A failed rebuild leaves the previous `deploy` untouched. The one known conflict (snapchat-bridge vs. nether-voicebridge,
both editing `group_vars/matrix_servers`) is resolved by `resolve_matrix_servers.py`; any other conflict stops the run.
Do not use `just update` on this checkout: it runs `git pull`, which this setup deliberately avoids.
