# Flutter Environment

* Flutter is installed on Windows.
* The workspace lives on Windows.
* Claude Code, Codex, Opencode runs from WSL.

All path handling and shell commands must account for this split environment.

## Commands

**Always** run Flutter/Dart commands through PowerShell using `pws` (alias for `pwsh.exe`).

```bash
pws -c flutter run
pws -c dart pub get
```

**Do not** run Flutter/Dart commands directly from WSL.


# Rules

- Before editing any file, read it first. Before modifying a function, use `ast-grep` to retrive all callers. Research before you edit.

## Agent skills

### Issue tracker

Issues live as markdown files under `.scratch/<feature-slug>/` — this repo has no git remote, so no `gh`/`glab`. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical roles, each label string equal to its name. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.