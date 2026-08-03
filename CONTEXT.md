# Time Tracker

A single-user, local-only desktop time tracking app. The user runs a timer against a client, producing editable time entries.

Called Clockodile

## Language

**Client**:
The party a time entry is tracked against. Has a name (unique, case-insensitive) and a color.
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
How long an Entry is kept, counted in days from the start of its most recent Session. User-configurable, default 60 days, minimum 30, can never be disabled. An Entry whose newest Session started before the cutoff is purged together with all its Sessions; the Active Entry is never purged, whatever its age. Sessions are never purged individually — an Entry's total never silently shrinks.
_Avoid_: Lifetime, rotation, expiry

**Report**:
A portal-ready view of one day's closed Sessions, with all boundaries rounded to quarter-hour marks. Contiguous Sessions stay contiguous (one shared rounded boundary); real gaps may shrink but are never invented. A preview the user copies into the portal by hand — never a correction of stored Sessions. Only Sessions started on the chosen day are included; the Open Session never is.
_Avoid_: Normalization page, export page, summary

## Example dialogue

> **Dev:** What happens if I tap an Entry while another is active?
> **Expert:** The Open Session is closed — its end becomes now — and a new Session opens under the tapped Entry, atomically. There is never more than one Open Session.
> **Dev:** I tap an Entry from last Tuesday. Does its old time change?
> **Expert:** Never. A new Session starts now under that Entry; past Sessions are untouched. Its total grows, and it appears under today in the list as well as under Tuesday.
> **Dev:** And if I close the app with a Session open?
> **Expert:** Nothing. The Open Session stays open until the user closes it — via Stop or by setting an end time in the edit dialog. The app has no say in it.
> **Dev:** I set the Retention Period to 30 days but I have a year of Entries. What happens?
> **Expert:** You are warned that Entries whose newest Session started over 30 days ago will be deleted; on confirm they are purged with all their Sessions. The Active Entry survives whatever its age. Clients left with no Entries survive — only Entries are purged.
