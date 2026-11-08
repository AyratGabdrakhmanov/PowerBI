Part of [PBIP_Recipes.md](../PBIP_Recipes.md) (split 2026-11-06).

## Recipe: "Make summary" for a client call (2026-10-29)

When the user says "make summary" for a call recording (`<Project>\Calls\<yyyy-mm-dd hh-mm-ss>.mkv`, the latest
one unless named):

1. **Transcript + frames.** `py -3.12 ClientA\_Documentation\Scripts\CallPrep.py "<video>.mkv" en` (language: ask if
   unknown; ClientB = en). Writes `Calls\transcripts\<video>.txt/.srt/.log` and `Calls\<date>\prep\` (`kf\` shared-screen
   keyframes, `ocr.md`, `transcript.md`). Only Python 3.12 has faster-whisper. Long calls: start with `pythonw` as a
   separate process, done when the `.log` ends with `DONE`. Check the real length (`ffprobe` stream `DURATION`): the
   file time span can be longer than the recording (pauses).
2. **Read** `transcript.md` + `ocr.md`, then open only the keyframes the talk points at (≤ 10–15). Read the client's
   follow-up email and attachments (Outlook COM, inbox, sender / subject match, last few days); save attachments to
   `Calls\<date>\mail\` and render marked-up PDF headers at 300 dpi (PyMuPDF) to read stamps.
3. **Write** `Calls\<date>\<date>_Call_Summary.md`: work list (call + email, numbered, status), Part 1 — the call
   (requests in the client's words, "What the recording shows" time | frame | finding), Part 2 — the email (quote,
   markup table current → new), open points, next steps. Do not guess: ambiguous items go to open points.
