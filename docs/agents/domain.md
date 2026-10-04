# Domain Docs

This repository uses a single domain context.

## Before exploring

Read root `GLOSSARY.md` and existing ADRs under `docs/adr/` that concern the work.
If these files or directories are absent, proceed silently. Create domain docs
lazily when terms or decisions are resolved, not merely to fill the layout.

## Layout

- `GLOSSARY.md`: canonical domain terms; already present.
- `docs/adr/NNNN-slug.md`: architecture decisions, when needed.

There is no per-package glossary layout. If a root `GLOSSARY-MAP.md` is introduced
later, follow it to the relevant context glossaries and ADRs.

## Consumer rules

Use the glossary's canonical vocabulary in issues, proposals, tests, and docs;
avoid synonyms it explicitly rejects. Note genuine terminology gaps for
`domain-modeling` rather than inventing competing terms.

Surface conflicts with an existing ADR explicitly instead of silently overriding
its decision. `domain-modeling`, including its use through `grill-with-docs`,
records resolved terminology and qualifying architecture decisions.
