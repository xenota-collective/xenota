#!/usr/bin/env bash
#
# pre-commit pointer guard
#
# Rejects a commit that moves the `xenon` or `handbook` submodule pointer to a
# commit that is not reachable from that submodule's origin/main.
#
# Why: a worktree whose submodule is on a stale or feature-branch checkout can
# have that gitlink swept into an unrelated commit (`git add`, `git commit -a`),
# silently regressing the top-level pointer. This happened with xc-m6f8 (#469),
# which pointed `xenon` at off-main desktop work.
#
# Install: ln -s ../../scripts/pointer-guard-pre-commit.sh .git/hooks/pre-commit
# Bypass an intentional off-main pointer: XENOTA_SKIP_POINTER_CHECK=1 git commit ...

set -u

[ "${XENOTA_SKIP_POINTER_CHECK:-}" = "1" ] && exit 0

repo_root=$(git rev-parse --show-toplevel) || exit 0
status=0

for sub in xenon handbook; do
	# Skip unless this submodule's gitlink is staged for change.
	git diff --cached --name-only -- "$sub" | grep -qx "$sub" || continue

	new_sha=$(git ls-files --stage -- "$sub" | awk '$1 == "160000" { print $2 }')
	[ -n "$new_sha" ] || continue   # gitlink removed, not moved

	sub_dir="$repo_root/$sub"
	if [ ! -e "$sub_dir/.git" ]; then
		echo "pointer-guard: '$sub' submodule not initialized — cannot verify, skipping" >&2
		continue
	fi

	# Refresh origin/main so a stale local ref does not cause a false reject.
	git -C "$sub_dir" fetch --quiet origin main 2>/dev/null \
		|| echo "pointer-guard: could not fetch $sub origin/main — checking local ref" >&2

	if ! git -C "$sub_dir" rev-parse --verify --quiet origin/main >/dev/null; then
		echo "pointer-guard: $sub has no origin/main ref — cannot verify, skipping" >&2
		continue
	fi

	if git -C "$sub_dir" merge-base --is-ancestor "$new_sha" origin/main 2>/dev/null; then
		continue   # pointer is on origin/main — good
	fi

	short=$(git -C "$sub_dir" rev-parse --short "$new_sha" 2>/dev/null || printf '%s' "$new_sha")
	subj=$(git -C "$sub_dir" log -1 --format='%s' "$new_sha" 2>/dev/null || echo '(commit not found locally)')
	echo "pointer-guard: REJECTED — '$sub' pointer is not on origin/main:" >&2
	echo "    $short  $subj" >&2
	echo "  The top-level pointer must reference a commit merged into ${sub}'s main branch." >&2
	echo "  Likely cause: the '$sub' submodule in this worktree is on a stale or feature checkout." >&2
	echo "  Fix:  git -C $sub checkout main && git -C $sub pull --ff-only   (then re-stage $sub)" >&2
	echo "  Intentional override:  XENOTA_SKIP_POINTER_CHECK=1 git commit ..." >&2
	status=1
done

exit $status
