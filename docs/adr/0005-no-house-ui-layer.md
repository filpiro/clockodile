# 5. No house UI layer: shadcn_flutter directly

Date: 2026-09-26

## Status

Accepted.

## Context

The UI came from `catui`, a house package of atoms, tokens and theme on top of
Material and Catppuccin. The move to shadcn_flutter could have kept a thin house
layer on top of shadcn. Most catui widgets had a native shadcn equivalent.

## Decision

`catui` is dropped, and nothing replaces it. Screens use `shadcn_flutter`
directly. Coherence is held by `style/components.md`, a conventions doc, not by
a widget package. A shared widget needs three or more call sites and logic of
its own to earn a file.

## Consequences

- One fewer package to version and keep in step with shadcn.
- Coherence depends on sessions reading `style/components.md`. A gap found in
  shadcn goes into that file.
