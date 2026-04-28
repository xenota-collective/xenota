#!/usr/bin/env bash
# Durable autonomous landing poll loop for the xc:landing pane.
#
# Keep this script the source of truth for the loop body so the empty-rollup
# rule survives restarts. The live codex pane should source / paste this
# rather than carrying its own ad-hoc heredoc; the heredoc form is what got
# us xc-3knt (treated "no checks reported" as "no green check, skip").
#
# Rules the loop enforces:
#   - mergeStateStatus=CLEAN + checks_success → squash, fall back to rebase
#   - mergeStateStatus=DIRTY → one-shot rebase merge, else file/dedupe a
#     landing blocker bead and skip
#   - any other state → skip silently
#
# checks_success treats statusCheckRollup as a *negative* gate: a PR passes
# unless any reported check has not finished or did not succeed. Empty
# rollups (no CI configured) therefore pass — that is xc-3knt's fix. Without
# this, CLEAN handbook / pointer-bump PRs sit in queue forever.

set -u

leader_file=/Users/jv/projects/xenota/.xsm-local/leader-backlog.jsonl
repos=("xenota-collective/xenota" "xenota-collective/xenon")
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
landing_blocker_helper="${script_dir}/landing_blocker.sh"

# all((.statusCheckRollup // [])[]; ...) returns true on empty arrays — that
# is the "no checks reported" path xc-3knt requires. Do not tighten this to
# require at least one reported check.
checks_success() {
  jq -e 'all((.statusCheckRollup // [])[]; .status == "COMPLETED" and .conclusion == "SUCCESS")' >/dev/null
}

# Sets blocker_reconciled=1 when find closed stale duplicate blockers — the
# helper does that as a side effect to keep the "at most one open blocker"
# invariant durable, but those bd close calls are local until we push.
blocker_exists() {
  local ref="$1"
  local out
  if ! out="$("$landing_blocker_helper" find --external-ref "$ref")"; then
    return 1
  fi
  if [ -n "$out" ] && jq -e '(.reconciled // 0) > 0' <<<"$out" >/dev/null 2>&1; then
    blocker_reconciled=1
  fi
  return 0
}

file_dirty_blocker() {
  local repo="$1" num="$2" branch="$3" signal_source="$4" reason="$5"
  local short_repo="${repo##*/}"
  local title="Resolve dirty landing PR ${short_repo}#${num}"
  local desc="Landing lane attempted: gh pr merge ${num} --repo ${repo} --rebase. GitHub reported the PR is not mergeable because the merge commit cannot be cleanly created. Resolve conflicts or refresh branch, then return PR to landing queue. PR branch: ${branch}."
  local result action bead_id
  if ! result=$("$landing_blocker_helper" file \
    --repo "$repo" \
    --pr "$num" \
    --branch "$branch" \
    --producer "landing_poll" \
    --signal-source "$signal_source" \
    --reason "$reason" \
    --title "$title" \
    --description "$desc"); then
    echo "$(date -u +%H:%M:%S) landing blocker helper failed for ${repo}#${num}; continuing"
    return 1
  fi
  action=$(jq -r '.action' <<<"$result")
  bead_id=$(jq -r '.bead_id' <<<"$result")
  if [ "$action" = "created" ]; then
    jq -cn \
      --arg repo "$repo" \
      --argjson pr "$num" \
      --arg branch "$branch" \
      --arg bead "$bead_id" \
      --arg created_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{type:"landing_dirty",agent:"landing",state:"blocked",reason:("DIRTY PR failed gh pr merge --rebase: " + $repo + "#" + ($pr|tostring) + " cannot be cleanly merged"),metadata:{repo:$repo,pr:$pr,branch:$branch,blocker_bead:$bead,label:"landing-dirty",producer:"landing_poll",signal_source:"gh_pr_merge_rebase_conflict"},created_at:$created_at}' \
      >> "$leader_file"
    echo "$(date -u +%H:%M:%S) filed ${bead_id} for ${repo}#${num}"
  else
    echo "$(date -u +%H:%M:%S) appended landing-blocker evidence to ${bead_id} for ${repo}#${num}"
  fi
}

refresh_xenon_pointer() {
  echo "$(date -u +%H:%M:%S) refreshing xenon pointer after xenon merge"
  if ! git fetch origin || ! git pull --rebase; then
    echo "$(date -u +%H:%M:%S) top-level pull/rebase failed; continuing poll loop"
    return 1
  fi
  if ! git -C xenon fetch origin || ! git -C xenon checkout origin/main; then
    echo "$(date -u +%H:%M:%S) xenon fetch/checkout failed; continuing poll loop"
    return 1
  fi
  git add xenon
  if git diff --cached --quiet -- xenon; then
    echo "$(date -u +%H:%M:%S) xenon pointer already current"
  else
    if git commit -m "refresh xenon pointer post-merge"; then
      git push origin HEAD:main \
        || echo "$(date -u +%H:%M:%S) pointer push failed; continuing poll loop"
    else
      echo "$(date -u +%H:%M:%S) pointer commit failed; continuing poll loop"
    fi
  fi
}

# bd_push_pending persists across cycles. We only clear it on a successful
# push, so a transient `bd dolt push` failure does not strand local-only bd
# writes (e.g. a stale-duplicate close performed by `find`) — the next cycle
# retries the push even if no new write happened.
bd_push_pending=0

while true; do
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) landing poll start"
  merged_xenon=0
  blocker_created=0
  blocker_reconciled=0
  for repo in "${repos[@]}"; do
    pr_json=$(gh pr list --repo "$repo" --state open --json number,mergeStateStatus,headRefName,statusCheckRollup 2>&1) || {
      echo "$(date -u +%H:%M:%S) gh pr list failed for $repo: $pr_json"
      continue
    }
    while IFS= read -r pr; do
      [ -n "$pr" ] || continue
      num=$(jq -r '.number' <<<"$pr")
      state=$(jq -r '.mergeStateStatus' <<<"$pr")
      branch=$(jq -r '.headRefName' <<<"$pr")
      ref="gh:${repo}#${num}"
      if [ "$state" = "CLEAN" ] && checks_success <<<"$pr"; then
        echo "$(date -u +%H:%M:%S) merging CLEAN successful ${repo}#${num} (${branch})"
        if gh pr merge "$num" --repo "$repo" --squash; then
          [ "$repo" = "xenota-collective/xenon" ] && merged_xenon=1
        else
          echo "$(date -u +%H:%M:%S) squash merge failed for ${repo}#${num}; trying rebase merge"
          if gh pr merge "$num" --repo "$repo" --rebase; then
            [ "$repo" = "xenota-collective/xenon" ] && merged_xenon=1
          else
            echo "$(date -u +%H:%M:%S) CLEAN merge failed for ${repo}#${num}; continuing"
          fi
        fi
      elif [ "$state" = "DIRTY" ]; then
        if blocker_exists "$ref"; then
          # Existing landing-blocker bead is enough — do not append another evidence
          # comment every poll cycle, that just spams bd. The bead already records
          # the producer; new producers / new conflict reasons are picked up the next
          # time the existing blocker is closed.
          echo "$(date -u +%H:%M:%S) ${repo}#${num} DIRTY; landing-blocker bead already open, skipping"
          continue
        fi
        echo "$(date -u +%H:%M:%S) trying one-shot rebase merge for DIRTY ${repo}#${num} (${branch})"
        merge_output=$(gh pr merge "$num" --repo "$repo" --rebase 2>&1) && {
          echo "$(date -u +%H:%M:%S) DIRTY ${repo}#${num} merged by rebase"
          [ "$repo" = "xenota-collective/xenon" ] && merged_xenon=1
          continue
        }
        echo "$merge_output"
        if grep -qiE 'not mergeable|conflict|cannot be cleanly' <<<"$merge_output"; then
          if file_dirty_blocker "$repo" "$num" "$branch" "gh_pr_merge_rebase_conflict" "$merge_output"; then
            blocker_created=1
          fi
        else
          echo "$(date -u +%H:%M:%S) DIRTY ${repo}#${num} failed for non-conflict reason; continuing"
        fi
      else
        echo "$(date -u +%H:%M:%S) skipping ${repo}#${num}: state=${state}"
      fi
    done < <(jq -c '.[]' <<<"$pr_json")
  done
  if [ "$merged_xenon" = "1" ]; then
    refresh_xenon_pointer
  fi
  if [ "$blocker_created" = "1" ] || [ "$blocker_reconciled" = "1" ]; then
    bd_push_pending=1
  fi
  if [ "$bd_push_pending" = "1" ]; then
    if bd dolt push; then
      bd_push_pending=0
    else
      echo "$(date -u +%H:%M:%S) bd dolt push failed; will retry next cycle"
    fi
  fi
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) landing poll complete; sleeping 60s"
  sleep 60
done
