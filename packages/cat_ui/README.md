# cat_ui

Catppuccin-based house style for desktop Flutter apps: a Material 3 theme, a
token set, and the atomic widgets built on them. Re-exports
`catppuccin_flutter` and `lucide_icons_flutter`, so a consuming app depends on
`cat_ui` alone and stays version-locked to the same glyphs and flavors.

**How to style with it: [DESIGN.md](DESIGN.md).** This file is only about how to
depend on it.

## Depending on it

The package lives inside the clockodile repo but is not clockodile's. Pub's git
dependency takes a subdirectory, so it needs no repo of its own:

```yaml
# a consuming app's pubspec.yaml
dependencies:
  cat_ui:
    git:
      url: <clockodile remote>
      path: packages/cat_ui
      ref: main
```

Clockodile itself stays on a path dependency — same checkout, no reason to go
through git.

### Why `ref: main` and not a tag

`pubspec.lock` records the resolved **commit hash**, not the ref. An app that
commits its lockfile is pinned to an exact commit whether the ref is a branch or
a tag, and stays there until someone runs:

```bash
flutter pub upgrade cat_ui
```

Tags only buy a readable name in the pubspec, and cost a release ritual on every
change. Add them when an app ships to someone who isn't you.

The `version:` field in this package's `pubspec.yaml` is inert under git
dependencies — pub resolves the ref, never the version. Don't maintain it as if
it means something.

## Editing cat_ui while an app consumes it

Git deps otherwise force a push before every test. In the *consuming* app:

```yaml
dependency_overrides:
  cat_ui:
    path: ../clockodile/packages/cat_ui
```

Edit live, push when it settles, then drop the override — it also silently
defeats the pin, so leaving it in is a good way to be confused about why two
apps look different.

## When to split this into its own repo

Not yet. Today a consumer clones all of clockodile (pub caches the whole repo,
then reaches into `path:`) and cat_ui's history is tangled with an app's. Both
are tolerable at two apps and one developer.

Split when a third consumer appears, or when the history stops being readable
past clockodile's commits. Nothing about the current layout blocks it —
`packages/cat_ui` is already self-contained with its own pubspec, tests and
`analysis_options.yaml`, so it's a `git filter-repo` and a URL change.

## Deliberately not used

A private pub server, melos, and pub workspaces all solve coordination problems
that appear at more apps than this.
