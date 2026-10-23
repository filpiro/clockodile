# Research: .eml parsing and file drop in Flutter on Windows

Ticket: [#17](https://github.com/filpiro/clockodile/issues/17), part of [#6](https://github.com/filpiro/clockodile/issues/6). Researched 2026-10-24.

## Short answer

- **.eml parsing:** `enough_mail` (MPL-2.0, pure Dart). Use `MimeMessage.parseFromData(bytes)`, then `decodeSubject()`, `decodeDate()` and `decodeSender()`/`from`. These decode RFC 2047 encoded words (`=?UTF-8?B?...?=`, `?Q?`). Publishing is slow: the last pub release, 2.1.7, came out on 2025-08-19.
- **File drop:** `desktop_drop` (Apache-2.0, publisher mixin.dev, actively maintained). Its Windows code is a real OLE `IDropTarget`, so drag enter and drag leave events work, and an overlay can use them.
- **Version catch:** desktop_drop 0.9.x needs Flutter >= 3.47.7. The local toolchain is Flutter 3.47.6 / Dart 3.13.5. Either pin `desktop_drop: ^0.8.4` (callbacks `onDragEntered` / `onDragExited` / `onDragDone`), or upgrade Flutter and use 0.9.x (`onEnter` / `onLeave` / `onDrop`).

## 1. .eml parsing: enough_mail

| Fact | Value | Source |
|---|---|---|
| Latest on pub | 2.1.7, published 2025-08-19 (the release before it was 2.1.6 on 2023-12-08) | [pub API](https://pub.dev/api/packages/enough_mail) |
| GitHub main | 2.2.3, SDK `>=3.11.5`, not yet on pub | [pubspec.yaml on main](https://github.com/Enough-Software/enough_mail/blob/main/pubspec.yaml) |
| Licence | MPL-2.0. This is file-level copyleft: it applies only to changes made to the package's own files, so using the package does not bind the app | [pub page](https://pub.dev/packages/enough_mail) |
| Publisher | enough.de (verified) | [pub page](https://pub.dev/packages/enough_mail) |
| Platforms | Android, iOS, Linux, macOS, Windows; Dart and Flutter | [pub page](https://pub.dev/packages/enough_mail) |
| Native code | None. Every dependency is pure Dart: basic_utils, collection, crypto, encrypter_plus, enough_convert, event_bus, intl (`any`), json_annotation, pointycastle, synchronized, xml `<7` | [pub API, 2.1.7 pubspec](https://pub.dev/api/packages/enough_mail) |

### API

From the [MimeMessage API docs](https://pub.dev/documentation/enough_mail/latest/enough_mail/MimeMessage-class.html):

- `MimeMessage.parseFromData(Uint8List data)` and `MimeMessage.parseFromText(String text)` are constructors. Prefer `parseFromData` with the file bytes, because .eml files can contain 8-bit bodies.
- `decodeSubject() -> String?`
- `decodeDate() -> DateTime?` (inherited from `MimePart`). It parses the `Date` header and returns local time.
- `decodeSender({bool combine = false}) -> List<MailAddress>`, plus `from` (a `List<MailAddress>?`) and `fromEmail`.

### Encoded-word headers

`MailCodec.decodeHeader` handles RFC 2047 encoded words. The source is [`lib/src/codecs/mail_codec.dart`](https://github.com/Enough-Software/enough_mail/blob/main/lib/src/codecs/mail_codec.dart):

- It finds each encoded word with the regex `\=\?.+?\?.+?\?.+?\?\=`, and removes the whitespace between adjacent encoded words.
- It looks up the charset in `_charsetCodecsByName`, a table of the many charsets that enough_convert supports.
- The letter `q` selects quoted-printable and `b` selects base64.
- If a word fails to decode, the raw word is kept and parsing continues. If the charset is unknown, it prints an error and outputs the rest of the header as is. Bad headers therefore produce raw text and never throw.

### Risks

- The pub release cadence is slow: two years passed between 2.1.6 and 2.1.7. The feature is small (header fields only), and the parser is stable, so this risk is low.
- `intl: any` follows whatever version the app resolves, so it causes no conflict.
- If enough_mail turns out to be too heavy, the fallback is to write our own header splitter that uses only `MailCodec.decodeHeader`, which is still from this package. No other maintained pure-Dart package parses full MIME messages. The `mime` package from dart.dev only handles multipart and MIME types, not RFC 5322 headers.

## 2. File drop from Explorer: desktop_drop

| Fact | Value | Source |
|---|---|---|
| Latest | 0.9.2 (2026-10-20). Releases 0.9.0, 0.9.1 and 0.9.2 all shipped in October 2026, so the package is active | [pub API](https://pub.dev/api/packages/desktop_drop) |
| Licence | Apache-2.0 | [pub page](https://pub.dev/packages/desktop_drop) |
| Publisher | mixin.dev (verified); repo is MixinNetwork/flutter-plugins | [pub page](https://pub.dev/packages/desktop_drop) |
| Platforms | Windows, Linux, macOS, iOS 13+, Android, Web | [pub page](https://pub.dev/packages/desktop_drop) |
| SDK, 0.9.x | `sdk ^3.13.5`, `flutter >=3.47.7` | [pub API](https://pub.dev/api/packages/desktop_drop) |
| SDK, 0.8.4 | `sdk ^3.5.0`, `flutter >=3.0.0` (2026-09-01) | [pub API](https://pub.dev/api/packages/desktop_drop) |

### Windows implementation

[`windows/desktop_drop_plugin.cpp`](https://github.com/MixinNetwork/flutter-plugins/blob/main/packages/desktop_drop/windows/desktop_drop_plugin.cpp) defines `class Destination final : public IDropTarget` and calls `RegisterDragDrop(window_, this)`. It implements `DragEnter` and `DragLeave`, and draws the shell drag image through `IDropTargetHelper`. Enter and leave therefore come from real OLE events. They are not inferred from `WM_DROPFILES`, which only reports the final drop.

### Callbacks for the overlay

From the [changelog](https://pub.dev/packages/desktop_drop/changelog) migration table:

| 0.8.x | 0.9.x |
|---|---|
| `onDragEntered(details)` | `onEnter(DragDetails)` |
| `onDragUpdated(details)` | `onMove(DragDetails)` |
| `onDragExited(details)` | `onLeave()` |
| `onDragDone(DropDoneDetails)` | required `onDrop(DropDetails)`, which can be async; items are typed |
| none | `onWillAccept` (synchronous filter that returns a bool) |

Other 0.9.0 changes:

- It adds Windows virtual files. One example is an attachment dragged straight out of Outlook. This may matter if users drag mails from Outlook rather than from Explorer.
- Provider access and temporary transfer files only last for the duration of `onDrop`, so read the bytes inside the callback.
- 0.9.1 fixed a Windows startup crash.

### Toolchain constraint

The local toolchain is Flutter 3.47.6 / Dart 3.13.5 (`flutter --version`), and 0.9.x requires Flutter 3.47.7. There are two options:

1. Pin `desktop_drop: ^0.8.4` and use the `onDragEntered` / `onDragExited` / `onDragDone` callbacks.
2. Upgrade Flutter first, then use 0.9.x. This adds Outlook virtual-file drops and the `onWillAccept` filter for `.eml`.

### Windows limitation: elevation

Windows User Interface Privilege Isolation (UIPI) blocks drag and drop from a lower-integrity process into an elevated one. In practice, Explorer cannot drop onto the app while the app runs as administrator. This is an OS rule, not a desktop_drop bug, and it affects any drop target ([Microsoft: UIPI / integrity levels](https://learn.microsoft.com/en-us/windows/win32/secauthz/mandatory-integrity-control)). Do not run the app elevated.

## Alternative considered: super_drag_and_drop

[super_drag_and_drop](https://pub.dev/packages/super_drag_and_drop) is MIT-licensed and published by nativeshell.dev. Its `DropRegion` has `onDropEnter` / `onDropLeave` and supports Windows virtual files. Two things count against it:

- Its native layer is written in Rust. Without a Rust toolchain, the build downloads precompiled binaries.
- The last stable release, 0.9.1, is 16 months old. Only `0.10.0-dev.2` has appeared since.

It is heavier and less active than desktop_drop, so it was rejected.
