#!/usr/bin/env bash
# Shared landing-blocker bead deduplication helper.
#
# Key invariant: a PR external_ref may have at most one non-closed landing
# blocker bead. Repeated signals from any producer append evidence to the
# existing bead instead of creating a duplicate.

set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  landing_blocker.sh find --external-ref gh:OWNER/REPO#N
  landing_blocker.sh file --repo OWNER/REPO --pr N --branch BRANCH \
    --producer NAME --signal-source SOURCE --reason TEXT \
    [--title TITLE] [--description TEXT] [--priority P1] [--labels A,B]

The file command prints JSON:
  {"action":"created"|"deduplicated","bead_id":"...","external_ref":"..."}
EOF
}

die() {
  echo "landing_blocker.sh: $*" >&2
  exit 2
}

now_utc() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

list_open_blockers_for_ref() {
  local ref="$1"
  # Sort key includes .id as a tie-breaker: when two beads share .created_at
  # (or it is missing) the winner must still be deterministic, otherwise
  # concurrent producers can disagree on which bead is the canonical one.
  bd list --all --limit 0 --json \
    | jq -c --arg ref "$ref" '
        [
          .[]
          | select(.external_ref == $ref)
          | select(.status != "closed")
          | select(((.labels // []) | any(. == "landing-dirty" or . == "landing-blocker")))
        ]
        | sort_by([(.created_at // ""), (.id // "")])
      '
}

first_nonclosed_for_ref() {
  local ref="$1"
  list_open_blockers_for_ref "$ref" | jq -c '.[0] // empty'
}

# Closes every non-winning open blocker for ref as a duplicate of the
# deterministic winner. Idempotent: a no-op when 0 or 1 open blockers exist.
# Prints the winner JSON augmented with .reconciled (count of losers closed),
# or empty when no candidates exist.
reconcile_blockers_for_ref() {
  local ref="$1"
  local all count winner_id loser_id
  all="$(list_open_blockers_for_ref "$ref")"
  count="$(jq 'length' <<<"$all")"
  if [[ "$count" -le 1 ]]; then
    jq -c '.[0] // empty | if . == null then empty else . + {reconciled:0} end' <<<"$all"
    return 0
  fi
  winner_id="$(jq -r '.[0].id' <<<"$all")"
  local reconciled=0
  while IFS= read -r loser_id; do
    [[ -n "$loser_id" ]] || continue
    bd close "$loser_id" --reason "duplicate of ${winner_id} (stale open blocker reconcile)" >/dev/null
    reconciled=$((reconciled + 1))
  done < <(jq -r '.[1:][].id' <<<"$all")
  jq -c --argjson n "$reconciled" '.[0] + {reconciled:$n}' <<<"$all"
}

canonical_ref_from_repo_pr() {
  local repo="$1" pr="$2"
  [[ -n "$repo" ]] || die "--repo is required"
  [[ -n "$pr" ]] || die "--pr is required"
  printf 'gh:%s#%s\n' "$repo" "$pr"
}

add_evidence_comment() {
  local bead_id="$1" producer="$2" signal_source="$3" external_ref="$4"
  local repo="$5" pr="$6" branch="$7" observed_at="$8" reason="$9" action="${10}"
  local comment
  comment=$(
    cat <<EOF
Landing-blocker evidence (${action}):
- producer: ${producer}
- signal_source: ${signal_source}
- external_ref: ${external_ref}
- repo: ${repo}
- pr: ${pr}
- branch: ${branch}
- observed_at: ${observed_at}
- evidence: ${reason}
EOF
  )
  bd comments add "$bead_id" "$comment" >/dev/null
}

cmd_find() {
  local external_ref=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --external-ref)
        external_ref="${2:-}"
        shift 2
        ;;
      --repo)
        local repo="${2:-}"
        shift 2
        ;;
      --pr)
        local pr="${2:-}"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown find argument: $1"
        ;;
    esac
  done
  if [[ -z "$external_ref" ]]; then
    external_ref="$(canonical_ref_from_repo_pr "${repo:-}" "${pr:-}")"
  fi
  # Reconcile so a `find` from any caller (e.g. the landing poll loop's
  # blocker_exists pre-check) repairs stale open duplicates left by a prior
  # failed loser-close, instead of silently returning one of N open blockers.
  # The output includes .reconciled so callers (which treated `find` as a
  # pure read) can detect that local bd writes happened and push them.
  local existing
  existing="$(reconcile_blockers_for_ref "$external_ref")"
  [[ -n "$existing" ]] || return 1
  jq -c --arg ref "$external_ref" '{bead_id:.id, title:.title, status:.status, external_ref:$ref, reconciled:(.reconciled // 0)}' <<<"$existing"
}

cmd_file() {
  local repo="" pr="" branch="" producer="" signal_source="" reason=""
  local title="" description="" priority="1" labels="landing-dirty,landing-blocker"
  local observed_at
  observed_at="$(now_utc)"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo) repo="${2:-}"; shift 2 ;;
      --pr) pr="${2:-}"; shift 2 ;;
      --branch) branch="${2:-}"; shift 2 ;;
      --producer) producer="${2:-}"; shift 2 ;;
      --signal-source) signal_source="${2:-}"; shift 2 ;;
      --reason) reason="${2:-}"; shift 2 ;;
      --title) title="${2:-}"; shift 2 ;;
      --description) description="${2:-}"; shift 2 ;;
      --priority) priority="${2:-}"; shift 2 ;;
      --labels) labels="${2:-}"; shift 2 ;;
      --observed-at) observed_at="${2:-}"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown file argument: $1" ;;
    esac
  done

  [[ -n "$producer" ]] || die "--producer is required"
  [[ -n "$signal_source" ]] || die "--signal-source is required"
  [[ -n "$reason" ]] || die "--reason is required"

  local external_ref short_repo existing existing_id created_json bead_id full_description metadata
  external_ref="$(canonical_ref_from_repo_pr "$repo" "$pr")"
  short_repo="${repo##*/}"
  if [[ -z "$title" ]]; then
    title="Resolve dirty landing PR ${short_repo}#${pr}"
  fi
  if [[ -z "$description" ]]; then
    description="Landing producer ${producer} observed ${external_ref}: ${reason}. Refresh or resolve the PR branch, then return it to the landing queue. PR branch: ${branch}."
  fi

  # Reconcile any stale duplicates left by a prior failed close (e.g. a race
  # where bd create succeeded but the loser-close failed, leaving multiple
  # open blockers). After this call, at most one open blocker remains.
  existing="$(reconcile_blockers_for_ref "$external_ref")"
  if [[ -n "$existing" ]]; then
    existing_id="$(jq -r '.id' <<<"$existing")"
    add_evidence_comment "$existing_id" "$producer" "$signal_source" "$external_ref" "$repo" "$pr" "$branch" "$observed_at" "$reason" "deduplicated"
    jq -cn \
      --arg action "deduplicated" \
      --arg bead_id "$existing_id" \
      --arg external_ref "$external_ref" \
      --arg producer "$producer" \
      --arg signal_source "$signal_source" \
      '{action:$action, bead_id:$bead_id, external_ref:$external_ref, producer:$producer, signal_source:$signal_source}'
    return 0
  fi

  full_description=$(
    cat <<EOF
${description}

Landing-blocker record:
- producer: ${producer}
- signal_source: ${signal_source}
- external_ref: ${external_ref}
- label_aliases: landing-dirty, landing-blocker
EOF
  )
  metadata="$(jq -cn \
    --arg producer "$producer" \
    --arg signal_source "$signal_source" \
    --arg external_ref "$external_ref" \
    '{landing_blocker:{producer:$producer, signal_source:$signal_source, external_ref:$external_ref}}')"

  created_json="$(bd create "$title" \
    --description "$full_description" \
    --type bug \
    --priority "$priority" \
    --labels "$labels" \
    --external-ref "$external_ref" \
    --metadata "$metadata" \
    --json)"
  bead_id="$(jq -r '.id' <<<"$created_json")"

  # Race-recheck: a concurrent producer may have created a competing blocker
  # between the initial reconcile above and bd create. reconcile_blockers_for_ref
  # picks a deterministic winner (created_at, then id) and closes every
  # non-winner — including the bead we just created when an older bead exists.
  local winner winner_id
  winner="$(reconcile_blockers_for_ref "$external_ref")"
  winner_id="$(jq -r '.id // empty' <<<"$winner")"
  if [[ -n "$winner_id" && "$winner_id" != "$bead_id" ]]; then
    add_evidence_comment "$winner_id" "$producer" "$signal_source" "$external_ref" "$repo" "$pr" "$branch" "$observed_at" "$reason" "deduplicated"
    jq -cn \
      --arg action "deduplicated" \
      --arg bead_id "$winner_id" \
      --arg external_ref "$external_ref" \
      --arg producer "$producer" \
      --arg signal_source "$signal_source" \
      '{action:$action, bead_id:$bead_id, external_ref:$external_ref, producer:$producer, signal_source:$signal_source}'
    return 0
  fi

  add_evidence_comment "$bead_id" "$producer" "$signal_source" "$external_ref" "$repo" "$pr" "$branch" "$observed_at" "$reason" "created"
  jq -cn \
    --arg action "created" \
    --arg bead_id "$bead_id" \
    --arg external_ref "$external_ref" \
    --arg producer "$producer" \
    --arg signal_source "$signal_source" \
    '{action:$action, bead_id:$bead_id, external_ref:$external_ref, producer:$producer, signal_source:$signal_source}'
}

main() {
  [[ $# -gt 0 ]] || { usage; exit 2; }
  local command="$1"
  shift
  case "$command" in
    find) cmd_find "$@" ;;
    file) cmd_file "$@" ;;
    -h|--help) usage ;;
    *) die "unknown command: $command" ;;
  esac
}

main "$@"
