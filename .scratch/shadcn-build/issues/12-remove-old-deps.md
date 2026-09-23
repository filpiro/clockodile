# 12 — Remove old deps, all tests green

**What to build:** The app builds and runs with no catui, no sonner, no Material. Every test and the integration test pass on Windows. This is the integrate-and-verify ticket: green is promised here.

**Blocked by:** 01 — 11 (all)

**Status:** ready-for-agent

**Model:** Opus, effort high — all surprises from the other tickets land here

Spec: `../../shadcn-migration/spec.md` (phase 5)

- [ ] `catui`, `sonner_toast`, `flutter_localizations` and `uses-material-design` removed from pubspec
- [ ] `lib/main.dart`: `localizationsDelegates` is only `[ShadcnLocalizationsIt.delegate]` — drop `...GlobalMaterialLocalizations.delegates` (kept by ticket 04 while Material widgets remain)
- [ ] No file in lib, test or integration_test names catui, catppuccin, sonner or imports `package:flutter/material.dart`
- [ ] `pws -c flutter analyze` has no errors
- [ ] Full `pws -c flutter test` green
- [ ] `pws -c flutter test integration_test` green on Windows
- [ ] Full Windows eyeball pass (spec phase 4 list), light and dark
