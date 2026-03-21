# xc-pyuh: Narrative Versioning Review

> **Scope**: Review artifact only. No handbook edits. No runtime behavior changes.

## Question

`xc-t5gt.5` introduced custom narrative versioning in the nucleus and framed it as
"git-like history". This review answers whether that custom system is justified,
what it does that git cannot, and what it would take to replace it with native
git-backed storage.

## Verdict

**Replace the custom narrative versioning with git-backed narrative storage.**

The current implementation duplicates VCS responsibilities that git already
solves, does not appear to have active production consumers on `main`, and does
not solve a concurrency problem that requires a bespoke history model.

The only real missing capability is that runtime xenon data is not currently
stored in a git repo. That is a storage-layout choice, not a reason to keep a
parallel version-control system inside `mind/narratives.json`.

## Reviewed Implementation

### Commit `2d00551` in `xenon`

`2d00551` ("add narrative versioning with git-like history") adds:

- `MindStore.update_narrative(...)`
- `MindStore.read_narrative_history(...)`
- `MindStore.read_all_narrative_histories(...)`
- `NarrativeCommit` and `NarrativeHistory` models
- semantic diff generation via `_compute_narrative_diff`
- periodic full snapshots every 10 commits
- new tests focused on snapshot/diff/history behavior

This is a custom append-only commit log embedded into `mind/narratives.json`.

### Follow-on refinement wiring

`6b33503` ("Add narrative update phase during refinement") adds:

- `nucleus/src/nucleus/narratives.py`
- `NarrativeUpdater`
- `update_narratives` routine prompt/config
- refinement integration that uses the custom history model

That follow-on work stores a second history format in `narrative_history.json`
and uses LLM-provided diff text or full snapshots. It is a second custom VCS
layer, not a thin wrapper around git.

## Findings

### 1. The implementation duplicates git rather than adding domain logic

The custom layer reimplements:

- commit objects (`tick`, `reason`, `timestamp`)
- snapshots
- diffs
- history traversal
- storage compaction via periodic snapshots

Those are baseline VCS concerns. The only domain-specific fields are `tick`,
`reason`, and `source_phase`, and those fit naturally in git commit messages,
structured trailers, notes, or sidecar metadata files.

### 2. The diff model is weaker than git's native text history

`_compute_narrative_diff` is sentence-splitting plus a word-overlap heuristic.
That means:

- diff fidelity depends on punctuation layout
- reordering sentences can be misclassified
- edits can emit both add/remove and "~Changed" records
- the stored diff is not a canonical patch and cannot be safely replayed

Git already provides a tested text diff engine, rename detection, blame, and
full-file recovery without inventing semantic heuristics.

### 3. Current `main` does not show active production consumers of custom history

On current `origin/main` in `xenon` (`9e97d5c` in this review workspace):

- `update_narrative`, `read_narrative_history`, and `read_all_narrative_histories`
  remain in `nucleus/src/nucleus/mind.py`
- `NarrativeCommit` and `NarrativeHistory` remain in
  `nucleus/src/nucleus/mind_models.py`
- repo-wide references are limited to those modules and `nucleus/tests/test_mind_store.py`

I did not find any current production path that reads the custom narrative
history to make decisions, render UI, or drive downstream logic.

Historical commits do show an earlier refinement integration (`6b33503`,
`eb7a706` lineage), but those files are not present in the current checked-out
tree.

### 4. The runtime data model does not currently require custom merge semantics

The strongest argument for a bespoke versioning system would be frequent
concurrent narrative writers during active ticks. I did not find evidence for
that.

Relevant current behavior:

- tick opening is serialized by `current_tick`
- the daemon runs one tick loop at a time
- the historical narrative updater ran as a refinement phase, not as a
  multi-writer background subsystem
- awakening writes the initial narratives once via `write_narratives(...)`

That means git would not be fighting an inherently high-conflict, many-writer
stream. Narrative updates are naturally batchable and serializable.

### 5. The real gap is repo placement, not versioning semantics

Runtime xenon state currently lives under `~/.xenons/<name>/...` as flat files
and databases. The inspected live xenon data contained:

- `mind/narratives.json`
- no `.git/` directory under the xenon data dir
- `schema_version: "1.0"` narratives with no custom history payload

So the practical design question is:

**Where should git history live for runtime narrative artifacts?**

That is solvable without keeping a custom VCS layer in the file format.

## Answers To Review Questions

### 1. Is there a genuine reason narratives need versioning semantics that git does not provide?

**No evidence found.**

Everything observed maps cleanly onto git primitives:

- full history: git commits
- textual diff: git diff
- snapshot recovery: checkout/show any revision
- attribution: author/commit metadata
- rationale: commit message and trailers

The domain-specific metadata (`tick`, `source_phase`, reason strings) can ride
alongside git rather than requiring a parallel history store.

### 2. Does the custom system handle concurrent narrative edits across ticks in a way git would struggle with?

**No.**

The observed model is effectively serialized already. The custom layer does not
provide CRDT behavior, three-way merge semantics, conflict resolution policy, or
multi-writer reconciliation beyond "append another entry". Git is at least as
capable for the actual concurrency profile shown here.

### 3. What is the maintenance cost of keeping a parallel versioning system?

**High relative to value delivered.**

Ongoing costs include:

- schema complexity in narrative storage
- custom data models and compatibility rules
- diff heuristic correctness burden
- test surface for snapshots/history/diffs
- future migration burden if UIs or APIs start depending on custom history
- conceptual overhead: operators now need to understand both git and a second,
  weaker git-like system

The maintenance burden is especially hard to justify because the system does not
currently appear to power any live feature on `main`.

### 4. Can we get the same outcomes by committing narrative files to a git-tracked directory?

**Yes, with a cleaner storage design.**

Recommended shape:

1. Store each narrative as its own text file under a dedicated directory such as
   `~/.xenons/<name>/mind/narratives/`.
2. Initialize a git repo for that directory, or for a narrow parent directory
   that only tracks narrative artifacts.
3. On awakening, write initial files and create the first commit.
4. On accepted refinement updates, overwrite changed files and commit once per
   refinement batch.
5. Encode `tick`, `source_phase`, and update reason in the commit message and/or
   a structured metadata file committed alongside the narrative files.

This yields:

- real diffs
- real history
- standard tooling
- simpler file format
- lower implementation and maintenance cost

## Recommended Replacement Design

### Preferred option: dedicated git-tracked narrative directory

Use a directory such as:

`~/.xenons/<name>/mind/narratives/`

Layout:

- `self_narrative.md`
- `resource_narrative.md`
- `reputation_narrative.md`
- `social_narrative.md`
- `work_narrative.md`
- `purpose_narrative.md`
- `recent_narrative.md`
- `trajectory_narrative.md`
- `metadata.json` or commit trailers for `tick` and `source_phase`

Why this shape:

- avoids committing secrets and volatile DB files from the xenon root
- keeps git history scoped to text artifacts that benefit from VCS
- makes narrative review legible with standard tooling
- avoids bloating a single JSON blob with embedded history

### Avoid

- tracking the entire xenon runtime directory in git by default
  because it includes DBs, keys, audit files, and volatile runtime artifacts
- keeping both custom history and git history in parallel
  because that preserves the complexity without delivering a clear benefit

## Migration Cost

### Low-risk path

1. Stop adding new custom history writes.
2. Introduce file-per-narrative storage under a git-tracked directory.
3. Migrate current `content` fields from `mind/narratives.json` into files.
4. If preserving old custom history matters, import it once as a best-effort
   linear git history using commit timestamps/reasons.
5. Remove unused custom history models, diff logic, and tests after callers are
   switched.

### Estimated code removal opportunity

At minimum, replacement would let us delete or simplify:

- `NarrativeCommit`
- `NarrativeHistory`
- `_compute_narrative_diff`
- custom history read/write helpers
- the tests that exist only to validate bespoke snapshot/diff behavior

## Recommendation

**Decision: replace, do not keep.**

Keep only the domain logic that decides *when* a narrative should change and
*why*. Move the version-history responsibility to git.

If the team wants an intermediate step, the acceptable short-term option is to
keep plain `mind/narratives.json` as current-state storage only and explicitly
drop embedded history until the git-backed directory lands.
