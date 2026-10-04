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
