# Tern Extension Repository

Language for the Tern plugin package maintained in this repository.

## Language

**Extension package**:
A self-contained Tern plugin directory with a root `plugin.toml`, entry points,
and any package-local modules and definitions. This repository's package is
`extensions/beads`.
_Avoid_: Example package

**Beads board**:
The read-only native Tern view of Beads issues provided by the Beads extension.
The plugin reads issue data through `bd`; it does not mutate the project database.
