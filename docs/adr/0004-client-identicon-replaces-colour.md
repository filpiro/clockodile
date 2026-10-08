# 4. A generated identicon replaces the client colour

Date: 2026-09-22

## Status

Accepted.

## Context

Each Client had a colour, picked at random when the client was created and
stored in `Clients.colorHex`. The colour came from the catppuccin palette. The
move to shadcn_flutter drops catppuccin, and the colour was decoration only:
nothing in the domain depends on it.

## Decision

A Client is shown with an **identicon**: a small mirrored block grid generated
from the client's id. It is drawn in-app with a `CustomPainter` and a hash from
`crypto`, which is already a dependency.

- **Seeded by client id**, so a rename never changes the picture.
- **Not dicebear.** dicebear needs three packages, runs a JSON-schema check on
  every avatar, and gives SVG that shadcn's `Avatar` cannot take directly. Its
  look was not the point.
- **`colorHex` is dropped** by a Drift migration that removes only that column.
  The database is never cleared: all clients, entries and sessions survive.
- The report board keeps one bar colour; clients are told apart by label and
  identicon.

## Consequences

- Colours users saw on existing clients are lost and cannot be restored.
- Users can no longer choose how a client looks. They still choose its name.
- If data is ever moved to a new database with new ids, identicons change.
