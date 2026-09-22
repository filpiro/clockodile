# Time Tracker

A single-user, local-only desktop time tracking app. The user runs a timer against a client, producing editable time entries.

Called Clockodile

## Language

**Client**:
The party a time entry is tracked against. Has a name (unique, case-insensitive), which the user chooses. Shown with an identicon generated from the client itself — never chosen by the user, and unchanged by a rename.
_Avoid_: Tag, project, category

**Entry**:
A named item of work tracked against exactly one Client, with a note. Its time is the sum of its Sessions, which may be non-contiguous and span multiple days. An Entry always has at least one Session — it is born with one, and its last Session cannot be deleted (delete the Entry instead). UI (Italian) calls it "Attività".
_Avoid_: Session, record, log, task

**Session**:
A span of tracked time belonging to exactly one Entry: a start time and an optional end time. Created only by activating an Entry; a closed Session is never reopened or extended.
_Avoid_: Interval, segment, slot

**Open Session**:
A Session with no end time. At most one Session system-wide is open at a time; "open" is derived (`end IS NULL`), never stored. Activating an Entry closes the Open Session (if any) and opens a new Session under the tapped Entry, atomically. Activating the Entry that already owns the Open Session is a no-op. The explicit Stop action (the only dedicated control) closes the Open Session without opening another; editing the Active Entry may also close it by setting a custom end time. Both lead to zero open Sessions. UI (Italian) shows the owning Entry with an "in corso" badge.
_Avoid_: Active session, running timer

**Active Entry**:
The Entry owning the Open Session. At most one at a time; derived, never stored. Tapping an inactive Entry makes it the Active Entry (reactivation — always a new Session, even for an Entry idle for days). Tapping the Active Entry does nothing.
_Avoid_: Open entry, active task, current task

**Retention Period**:
How long an Entry is kept, counted in days from the start of its most recent Session. Chosen from 30, 45 or 60 days, default 60, can never be disabled. An Entry whose newest Session started before the cutoff is purged together with all its Sessions; the Active Entry is never purged, whatever its age. Sessions are never purged individually — an Entry's total never silently shrinks.
_Avoid_: Lifetime, rotation, expiry

**Report**:
A portal-ready view of one day's closed Sessions, with all boundaries rounded to quarter-hour marks. Contiguous Sessions stay contiguous (one shared rounded boundary); real gaps may shrink but are never invented. A preview the user copies into the portal by hand — never a correction of stored Sessions. Only Sessions started on the chosen day are included; the Open Session never is.
_Avoid_: Normalization page, export page, summary

**Note Summary**:
A short Italian line an AI writes to replace the text a user pasted into an Entry's Note — typically a client email condensed to its core request. Produced on demand, only when the user presses Riassumi, by the AI Provider — the Local Model by default. It is not a second field: it overwrites the Note in place, the pasted source is not kept, and there is no undo. The user still has the original email wherever they copied it from. Only a non-empty line counts; anything else is a failure that leaves the Note untouched. The one kind of summary in the app — the Report is never called a summary.
_Avoid_: Summary (bare), AI note, generated note, abstract, condensation

**AI Provider**:
Whatever produces a Note Summary, behind one interface the UI talks to without knowing which it is. Given the Note's text it returns the Note Summary or a normalized failure with a short Italian message. The Local Model is the only one the user can reach; the coding-agent CLI providers (see AI Provider Kind) still exist behind the same interface but are hidden, and nothing ever falls back to them — that would silently send a client's text to a remote model.
_Avoid_: Backend, engine, model, integration, service

**AI Provider Kind**:
Which coding-agent CLI a hidden CLI AI Provider runs — Claude Code, Codex, or OpenCode. A stored setting left over from before the Local Model; each kind keeps its own model and effort values. Never names the Local Model, which is not a kind of CLI.
_Avoid_: Provider (for the enum), provider type, backend

**Local Model**:
The AI Provider that runs on the user's own machine: a small language model served by `llama-server` on localhost, started when the app opens and stopped when it closes. Its two files — the runtime and the model weights, about 1,3 GB together — are downloaded once, only after the user confirms, pinned to exact versions and checksum-verified. Turning AI off stops it but keeps the files; "Elimina modello" removes them. Note text never leaves the machine. Windows only.
_Avoid_: Llama (bare), offline AI, embedded model, bundled model, SLM

**WSL Mode**:
A Windows-only setting routing every CLI provider command through a WSL login shell instead of running it on Windows. Needed because the CLIs are commonly installed only inside WSL, under paths (`~/.local/bin`, `~/.nvm`, `~/.opencode/bin`) that exist on no Windows PATH and on no non-login WSL PATH either. Off means the CLI is executed directly. Concerns only the hidden CLI providers — never the Local Model — and is no longer shown in Settings.
_Avoid_: Linux mode, shell mode, compatibility mode

## Example dialogue

> **Dev:** What happens if I tap an Entry while another is active?
> **Expert:** The Open Session is closed — its end becomes now — and a new Session opens under the tapped Entry, atomically. There is never more than one Open Session.
> **Dev:** I tap an Entry from last Tuesday. Does its old time change?
> **Expert:** Never. A new Session starts now under that Entry; past Sessions are untouched. Its total grows, and it appears under today in the list as well as under Tuesday.
> **Dev:** And if I close the app with a Session open?
> **Expert:** Nothing. The Open Session stays open until the user closes it — via Stop or by setting an end time in the edit dialog. The app has no say in it.
> **Dev:** I set the Retention Period to 30 days but I have a year of Entries. What happens?
> **Expert:** You are warned that Entries whose newest Session started over 30 days ago will be deleted; on confirm they are purged with all their Sessions. The Active Entry survives whatever its age. Clients left with no Entries survive — only Entries are purged.
> **Dev:** I paste an email into the Note and generate a summary. Can I get the email back?
> **Expert:** Not from Clockodile. The Note Summary overwrites the Note, nothing is kept, and there is no undo. The email is still in your mail client — that is the copy that matters.
> **Dev:** Why is the generate button greyed out?
> **Expert:** Either AI is off in Settings, in which case the button is not there at all; or the Local Model is still starting — the strip at the bottom says so; or the Note is under ten words. There is nothing to summarise in a line already short enough to be a note.
> **Dev:** The model fails halfway through. What happens to my text?
> **Expert:** Nothing. The Note is only ever written on success, and an empty or malformed answer counts as a failure. The field unlocks and a short Italian message says what went wrong.
> **Dev:** I updated Clockodile and the strip says the AI files need updating.
> **Expert:** The new release pins a different runtime or model. Nothing downloads until you press Aggiorna and confirm the size — and only the file that changed is fetched.
> **Dev:** Can I use Claude Code instead?
> **Expert:** Not from Settings any more. The CLI providers still exist behind the AI Provider interface, but they are hidden, and a failing Local Model never falls back to them.
