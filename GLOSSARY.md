# Tern UI

Language for the reusable UI library and the Tern plugins that consume it.

## Language

**Tern UI component**:
A reusable description of a Tern view whose appearance and action names are supplied by its consumer. The consuming application owns its state, event handling, and persistence.
_Avoid_: Widget controller, stateful component

**Consuming plugin**:
A Tern plugin that incorporates Tern UI components into its own views and interprets their actions.
_Avoid_: Component host
