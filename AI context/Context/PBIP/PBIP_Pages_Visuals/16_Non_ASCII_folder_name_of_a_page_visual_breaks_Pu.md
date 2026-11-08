Part of [PBIP_Pages_Visuals.md](../PBIP_Pages_Visuals.md) (split 2026-11-06).

## ⚠️⚠️ Non-ASCII folder name of a page/visual breaks Publish/template export

**Found on another PBIP project (Hebrew in page names), 2026-09-08, after a
long bisection** — but the rule is universal for any non-ASCII text
(Hebrew, Cyrillic, etc.), so it also applies to this project if a
non-ASCII `displayName` ever gets in here.

**Symptom:**
```
An error occurred while attempting to publish/export '...':
Part URI is not valid per rules defined in the Open Packaging Conventions specification.
```
Occurs on **Publish** to the Power BI Service and on **Export → Power BI
Template (.pbit)**. Ordinary `Save`/opening of `.pbix`/`.pbip` is not affected —
only these two scenarios use the stricter OPC packaging (the argument
`forceStaticResourceUrisValid` in the `PowerBIPackager.Save` stack trace).

**Root cause (confirmed experimentally):** the folder name of a page/
visual (`definition/pages/<name>/...`) becomes part of the package Part URI
during packaging. If it contains non-ASCII characters, the validation
`System.IO.Packaging.PackUriHelper.ValidatePartUri` throws this error,
**regardless of which specific page/visual it is**. Pages with a
pure ASCII name (including any page Desktop creates itself —
it always has a hex name like `577c6991bc39d800dd20`) never caused the error.

**How it was found — page bisection (the method, not just the result):**
1. The `.pbit` export failed consistently, regardless of the model content —
   even when the model was cut down to a few tables, the report with the full set of
   pages still failed. So the issue was not in the model's DAX/M.
2. Removing pages from the report one by one (save → publish →
   see whether the error went away) narrowed it down to "any page with a non-ASCII
   folder name causes the error — regardless of which one".
   Pages with an ASCII name (in that original project — `tooltip1`/`tooltip2`/
   `tooltip3`/`PGP`, whose `displayName` was already in Latin script, so
   `rename_pages.ps1` never renamed their folder to Hebrew) never
   reproduced the error in any combination.
3. Specific hypotheses that **were not confirmed** along the way (mentioned
   so as not to waste time on them again if the error resurfaces in another form):
   `/` in a DAX object name (a real bug, but not this error — fixed
   separately, see below about `%`/`#` in DAX names, relevant to *this*
   project separately from Part URI), `#` in a measure name, duplicate
   `lineageTag`/annotations between two model objects, a non-standard
   `pageBinding.name` format, a dot in a `syncGroup` name, a
   cross-report drillthrough configuration. All these things are technically suspicious for a
   URI, but in the specific reproduction none of them was the cause —
   the real cause was precisely non-ASCII in the page/visual folder name.

**Fix in `rename_pages.ps1` (done):** `Get-SafeName` is now
ASCII-only (see above). For pages whose `displayName` does not yield an ASCII name
(for example, entirely in Hebrew) — a fallback to `Page<position in pageOrder>`.

**One-time migration of an existing project:** if the project already has
pages/visuals with non-ASCII folder names (created before this fix
or by Power BI Desktop with a localized UI) — use
`fix_nonascii_names.ps1` (see "Scripts" below) once to switch them
all to hex names in bulk, before `rename_pages.ps1` takes over
maintaining them in ASCII-only mode.
