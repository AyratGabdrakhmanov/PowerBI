Part of [PBIP_Pages_Visuals.md](../PBIP_Pages_Visuals.md) (split 2026-11-06).

## ⚠️ CRITICAL RULES

### Rule 1: Name synchronization (no spaces)
```
Folder name = page.json "name" = reference in pages.json
```
All three must match **and must not contain spaces**. If even one does not match
or contains a space → Power BI silently fails to find the page (no error — the page
simply does not appear in the report's page list).

**Verified experimentally:** pages with a space in the folder name
(`"Sales YTD"`, `"Collector Assignment TEST"`) were invisible in Power BI Desktop,
while names without spaces (`Blank`, `CA_DQ`, `Overview`) displayed normally.
After removing the spaces from the folder names, all pages became visible.

### Rule 2: displayName — the only place with spaces
- `displayName` in page.json — what the user sees in Power BI Desktop
- Can (and usually should) contain spaces and nice formatting
- Updates in real time, does not need to be synchronized with the folder name

### Rule 3: UTF-8 without BOM
```
pages.json (and probably any other definition JSON file) MUST be
saved as UTF-8 WITHOUT BOM.
```
If saved with a BOM → Power BI shows an explicit error:
`"Only text with UTF8 encoding without BOM (byte order marks) is supported"`.

`Set-Content -Encoding UTF8` in PowerShell adds a BOM! You have to write via:
```powershell
$utf8NoBOM = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($path, $content, $utf8NoBOM)
```

### Rule 4: JSON formatting — 2 spaces per level
Power BI's own files use an indent of **2 spaces** per nesting level.

⚠️ **`ConvertTo-Json` formats differently in different PowerShell editions:**
- **PowerShell 7+ (pwsh)**: neat 2 spaces per level (already matches Power BI)
- **Windows PowerShell 5.1 (`powershell.exe`)**: a "floating" indent aligned
  to the content (not a multiple of 2 or 4!). Example of real output:
  ```
  {
      "pageOrder":  [
                        "SalesYTD",
                        "CA_DQ"
                    ],
      "activePageName":  "SalesYTD"
  }
  ```
  A regular expression like `-replace '^    ', '  '` **does not work** for such
  output — it fixes only the first level and breaks everything else.

✅ **Final solution** — don't fight the Windows PowerShell 5.1 format, but
**guarantee that both scripts run under PowerShell 7+ (`pwsh`)**. Verified
experimentally even on deeply nested real `page.json` files (`filterConfig`
with several levels of nested objects) — `pwsh` always produces exactly 2
spaces per level, without exception. Therefore:
- Both scripts check `$PSVersionTable.PSVersion.Major` at the start and, if it is
  less than 7, **relaunch themselves** via `pwsh -File $PSCommandPath`
- If `pwsh` is not installed — the script **stops with an explicit error**
  (does not silently continue on 5.1) and asks you to install PowerShell 7+
  (https://aka.ms/PSWindows)

### Rule 5: Folder name/`name` — ASCII only (not just "no spaces")

Besides spaces, the folder name of a page/visual and its `"name"` must not contain
**any non-ASCII characters at all** (Hebrew, Cyrillic, etc.) — otherwise
**Publish** and **Export → Power BI Template (.pbit)** fail with the error:

```
Part URI is not valid per rules defined in the Open Packaging Conventions specification.
```

Ordinary local saving/opening of `.pbix`/`.pbip` does not suffer from this
problem — only Publish/template export breaks. For details on how this
was found (a long bisection on another project, 2026-09-08) and how it was fixed
— see the section "⚠️⚠️ Non-ASCII folder name of a page/visual breaks Publish/template
export" below.
