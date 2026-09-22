# 01 — Client identicon replaces colour

**What to build:** Each client shows a generated identicon (seeded by client id) instead of its colour dot, in entry rows, group headers, report labels and the clients list. The stored client colour leaves the database; every client, entry and session row survives. Lands on today's catui UI — no shadcn yet.

**Blocked by:** None — can start immediately

**Status:** resolved

**Model:** Opus, effort high — changes the real database; a miss can lose data

Spec: `../../shadcn-migration/spec.md` (phase 0)

- [x] Identicon drawn by our own painter using `crypto`; no new dependency
- [x] Two sizes: small (~20px) and normal (~32px)
- [x] Renaming a client does not change its identicon
- [x] Drift migration drops only the colour column; migration test proves all rows survive
- [x] Colour helpers, the colour control on Clienti, the client dot widget and the colour test are deleted
- [x] Full `pws -c flutter test` green (catui still present, so the whole suite runs here)
- [x] Eyeballed on Windows against a **copy** of the real database file
