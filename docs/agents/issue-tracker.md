# Issue tracker: Local Beads

Issues and specs live in this repository's local Beads (`bd`) workspace under
`.beads/`, not GitHub Issues or Markdown ticket files. Run commands from the
repository root. Use returned issue IDs rather than invented numbers.

## Local setup

Initialize only when `.beads/` is absent:

```sh
BEADS_DIR="$PWD/.beads" bd init --prefix tern-ui --non-interactive \
  --skip-hooks --skip-agents --remote ""
```

Explicit `BEADS_DIR` avoids implicit Git initialization. Embedded Dolt is local;
no external server, global tracker, remote sync, or Git hooks are configured.
Keep `.beads/` private via the root `.gitignore`; commit these instructions.
Initialization may append broader Dolt/database ignore patterns. Review those
changes; this project ignores `.beads/`, not every `*.db` file.
Verify `bd where` and `bd info --json` identify this project's database.
In a directory without Git metadata, `bd context` cannot resolve a repository
root and `bd ready` may warn that `beads.role` is unset. Database operations
still work; do not initialize Git just to silence those diagnostics.

## Issue gate and agent lifecycle

Create a Bead for every actionable problem and non-trivial repository change
before work begins. A genuine no-op or Q&A needs no ticket. A ticket may be
omitted only for a typo/trivial file or a bounded, low-risk single-file change
with no public API, persistence, or cross-component impact. These exceptions
waive ticket creation only: role, verification, and commit steps still apply.
Use the issue as the scope and acceptance source; if essential details are
missing or conflict, send a clarification request through Main/Lead before
proceeding.

Main/Lead spawns a task-scoped Implementer for every change; use generic
`task` agent instances with explicit role prompts and names, not persistent
custom agent types. The Implementer reads the assigned issue, checks
prerequisites, relays clarification requests to Main/Lead, claims the issue
with `bd update ISSUE --claim`, and implements only its agreed scope.

For each completed implementation pass, the Implementer spawns a task-scoped
Committer. The Committer inspects the final diff, authors the commit message,
and commits only that task's tracked changes. Commit before testing. Then the
Implementer moves the Bead to `test` and spawns a task-scoped Tester. The Tester
is read-only for implementation: inspect the code for mistakes and in-scope
better solutions, and actively exercise relevant edge cases. Report blocking
defects or acceptance failures separately from optional in-scope suggestions;
only failures block approval. Treat out-of-scope improvements as separate
Beads. After reporting, return findings and control to the Implementer and
terminate.

On failure, the Tester comments findings on the Bead and returns it to
`in_progress`. The Implementer repairs the change, commits the repair, then
starts a fresh Tester pass; repeat until pass. On pass, the Tester records
concise evidence on the Bead and moves it to `review`, then terminates.

Human review closes the issue (`closed` / Done). Main/Lead may close only when
the human explicitly requests closure; implementation and test pass alone do
not authorize closure.

## Status lanes

Configure Beads custom statuses for every workspace. For a new workspace run:

```sh
bd config set status.custom "test,review"
```

This project's local `status.custom` is `test,review`. The Ghostex Kanban lanes
map to Beads statuses as follows; there is no Backlog lane:

| Ghostex lane | Beads status |
| --- | --- |
| Todo | `open` |
| In Progress | `in_progress` |
| Test | `test` |
| Review | `review` |
| Done | `closed` |

Triage labels remain separate from status lanes: labels express triage/readiness,
not execution state. Preserve existing labels when changing status.

## Issue operations

```sh
bd create "Title" --type task --priority 2 --labels needs-triage --description "Problem, scope, acceptance criteria"
bd list --status open
bd ready
bd show ISSUE_ID
bd comments ISSUE_ID
bd update ISSUE_ID --claim
bd comment ISSUE_ID "Progress, decision, or handoff"
bd label add ISSUE_ID ready-for-agent
bd label remove ISSUE_ID needs-triage
bd close ISSUE_ID --reason "Completed and verified"
```

Use structured type, priority, and status fields; triage labels come from
`triage-labels.md`. Claim ready work before implementation. Assign native
`in_progress` through `--claim`; labels describe triage readiness, not execution
status. For wontfix, apply the label and close with a reason. Resolve only after
acceptance criteria and verification are satisfied.
Claims carry a lease. During long-running work, renew it with
`bd heartbeat ISSUE_ID` before its TTL expires; stop if ownership was lost.

## Specs and wayfinding

Store a spec in the issue/epic description and subsequent decisions in comments.
Use an epic as the map and child issues for individual tickets:

```sh
bd create "Effort map" --type epic --description "Notes, Decisions-so-far, Fog"
bd create "Child task" --type task --parent EPIC_ID
bd children EPIC_ID
bd dep add DEPENDENT_ID BLOCKER_ID
bd ready --parent EPIC_ID
```

Parent membership organizes work; blocker dependencies determine readiness.
Claim an unblocked child, record its answer, close it, then append an ID and
summary to the map. Preserve existing issue data; avoid reinitialization,
force-close, or deletion as routine workflow. Serialize local embedded database
writes when multiple agents are active. Consult the installed `bd COMMAND
--help` for flags before extending this workflow.
