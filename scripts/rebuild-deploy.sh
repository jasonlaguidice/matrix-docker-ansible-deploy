#!/usr/bin/env bash
# Rebuilds the local `deploy` branch: upstream/master + every branch in scripts/deploy-branches.txt.
# Stops on the first conflict; rerere remembers resolutions, so re-run after resolving.
set -euo pipefail

stashed=0

main() {
	local repo list base status=0 b ref role
	repo="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
	cd "$repo"
	list="$repo/scripts/deploy-branches.txt"
	base="${BASE_REF:-upstream/master}"

	git config rerere.enabled true
	git config rerere.autoupdate true

	if ! git diff --quiet; then
		echo "Unstaged changes to tracked files; stage or stash them first." >&2
		return 1
	fi

	local -a branches
	mapfile -t branches < <(sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$list" | grep -v '^$' || true)

	# These scripts live outside the deploy history: set the staged copies aside while merging.
	# (Everything is inside this function, so bash has already parsed it when the files vanish.)
	if ! git diff --cached --quiet; then
		git stash push --staged --quiet
		stashed=1
	fi
	restore() { [ "$stashed" -eq 1 ] && git stash pop --index --quiet && stashed=0; return 0; }
	trap restore EXIT

	git fetch upstream
	git fetch origin

	# Prefer the local branch (it may be unpushed), fall back to origin.
	resolve_ref() {
		if git rev-parse --verify -q "refs/heads/$1" >/dev/null; then echo "$1"
		elif git rev-parse --verify -q "refs/remotes/origin/$1" >/dev/null; then echo "origin/$1"
		else echo "Branch '$1' not found locally or on origin." >&2; return 1; fi
	}

	git checkout -q --no-track -B deploy "$base"

	for b in "${branches[@]}"; do
		ref="$(resolve_ref "$b")"
		echo "==> merging $ref"
		if ! git merge --no-edit -m "Merge $b into deploy" "$ref"; then
			# rerere may have replayed a recorded resolution; if nothing is left unmerged, finish the merge.
			if [ -z "$(git diff --name-only --diff-filter=U)" ] && git commit --no-edit -q; then
				echo "    (conflicts resolved by rerere)"
				continue
			fi
			echo "Conflict merging $ref. Resolve, 'git commit', then re-run." >&2
			trap - EXIT
			return 1
		fi
	done

	# Every role a branch adds must have survived into the result and be listed in setup.yml.
	for b in "${branches[@]}"; do
		ref="$(resolve_ref "$b")"
		while read -r role; do
			[ -n "$role" ] || continue
			if [ ! -d "roles/custom/$role" ]; then echo "MISSING role dir: $role (from $b)" >&2; status=1
			elif ! grep -q "$role" setup.yml; then echo "NOT in setup.yml: $role (from $b)" >&2; status=1; fi
		done < <(git diff --name-only --diff-filter=A "$base...$ref" -- 'roles/custom/*/tasks/main.yml' | cut -d/ -f3)
	done
	[ "$status" -eq 0 ] && echo "deploy rebuilt OK from $base + ${#branches[@]} branch(es)."
	return "$status"
}

main "$@"
exit $?
