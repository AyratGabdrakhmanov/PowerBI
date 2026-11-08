Part of [PBIP_Scripts.md](../PBIP_Scripts.md) (split 2026-11-06).

## `SavePbipAsPbix.ps1` — "save pbix" (added 2026-11-01)

`pwsh -File Scripts\SavePbipAsPbix.ps1 -Pbip "<X.pbip>" [-Pbix <target>] [-ResumePid <pid>]` — user shortcut **"save pbix"**:
saves the PBIP as `<X>.pbix` next to it **without data**, for the user's refresh (then `ConvertPbixToPbip.ps1` brings
model + data back). Backup of the old `.pbix` → nearest `BackUp\SavePbix_<time>\`; opens the PBIP in its own window;
TOM `ClearValues` (not a source refresh); **F12 = Save As** (Desktop 2.158) after the foreground check; Desktop proposes
the **last used type** (`<X>.pbix` or `<X>.pbip`, both seen 2026-11-01) in the PBIP folder — the name / type boxes expose no
UIA patterns, so with the `.pbix` default the script presses Enter + Alt+Y on "Confirm Save As". With `.pbip` (since
2026-11-02): Alt+T, Alt+Down opens the type list, Home (entry 0 = "Power BI file (*.pbix)"), Enter closes it — the dialog swaps
the extension **only when the list closes** (arrows on the closed list and Win32 `CB_SETCURSEL` change the type but not the
name). Enter is sent only while the list (`ComboLBox` of the Desktop pid) is visible, and Save only when the name box shows
`<X>.pbix`; any mismatch throws with nothing saved. Tested on a copy, then ClientB Inventory Coverage (.pbip → .pbix) 2026-11-02;
waits for the `.pbix`, closes the window, reports PBIP files
changed (must be 0). ⚠️ An active **Remote Desktop** window keeps the foreground — the script waits ~2 min and asks to
click the Power BI window; after a failure continue with `-ResumePid`. ClientC Sales NEW 2026-11-01: 1.4 MB, DataModel 270 KB.
