#!/usr/bin/env bash
# Verify every submodule pointer recorded in the working tree is reachable
# from that submodule's `origin/main`. Used as a pre-merge gate so a xenota
# pointer PR cannot land while it still references a feature-branch SHA
# (e.g. a PR head that will be a different commit after squash merge) or a
# commit that has not been merged at all.
#
# Behaviour:
#   - For each `[submodule]` entry in `.gitmodules`:
#       1. Read the path's gitlink SHA from `HEAD`.
#       2. Inside the submodule, ensure `origin/main` is fetched.
#       3. Require the gitlink SHA to be an ancestor of `origin/main`
#          (i.e. it is, or is included in, the submodule main history).
#   - Exits 0 only when every submodule check passes.
#   - Exits 1 with a per-submodule diagnosis when any pointer is stale.
#
# Environment knobs:
#   SUBMODULE_POINTER_SKIP_FETCH=1  Skip `git fetch origin main` inside each
#                                   submodule. Used in CI when the workflow
#                                   has already arranged the refs.

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

if [[ ! -f .gitmodules ]]; then
    echo "submodule pointer gate: no .gitmodules; nothing to check"
    exit 0
fi

mapfile -t paths < <(
    git config --file .gitmodules --get-regexp '^submodule\..*\.path$' \
        | awk '{print $2}'
)

if [[ ${#paths[@]} -eq 0 ]]; then
    echo "submodule pointer gate: .gitmodules has no submodules"
    exit 0
fi

failures=()

for path in "${paths[@]}"; do
    if [[ ! -d "$path/.git" && ! -f "$path/.git" ]]; then
        failures+=("$path: submodule not initialized; cannot resolve pointer")
        continue
    fi

    pointer_sha="$(git ls-tree HEAD -- "$path" | awk '$2 == "commit" {print $3}')"
    if [[ -z "$pointer_sha" ]]; then
        failures+=("$path: HEAD does not record a gitlink for this submodule")
        continue
    fi

    if [[ "${SUBMODULE_POINTER_SKIP_FETCH:-0}" != "1" ]]; then
        if ! git -C "$path" fetch --quiet origin main 2>/dev/null; then
            failures+=("$path: failed to fetch origin/main; cannot verify $pointer_sha")
            continue
        fi
    fi

    if ! git -C "$path" rev-parse --verify --quiet origin/main >/dev/null; then
        failures+=("$path: origin/main is not available locally; cannot verify $pointer_sha")
        continue
    fi

    main_sha="$(git -C "$path" rev-parse origin/main)"

    if ! git -C "$path" cat-file -e "${pointer_sha}^{commit}" 2>/dev/null; then
        failures+=("$path: pointer $pointer_sha does not exist in the submodule (force-pushed or unfetched)")
        continue
    fi

    if git -C "$path" merge-base --is-ancestor "$pointer_sha" origin/main; then
        echo "submodule pointer ok: $path -> $pointer_sha (ancestor of origin/main $main_sha)"
        continue
    fi

    failures+=(
        "$path: pointer $pointer_sha is not reachable from origin/main ($main_sha). \
This usually means the submodule PR has not merged yet, or it was \
squash-merged into a different commit. Refresh the pointer to a SHA on \
origin/main before merging."
    )
done

if [[ ${#failures[@]} -gt 0 ]]; then
    echo "submodule pointer gate failed:" >&2
    for failure in "${failures[@]}"; do
        echo "  - $failure" >&2
    done
    exit 1
fi

echo "submodule pointer gate passed: all submodule pointers are reachable from origin/main"
