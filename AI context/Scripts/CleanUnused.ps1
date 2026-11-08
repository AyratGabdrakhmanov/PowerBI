# Find (and delete) DAX measures, Field Parameter tables, and other unused
# data tables.
#
# Change log (newest first):
#   2026-11-06.1 - -ThinReports: live-connected thin reports of the model are scanned for usage (visuals, filters,
#                  bookmarks, report-level measure DAX) and never edited; some measures are used only there
#                  (Semantic Model -> Thin Collector Assignment / Thin Scorecard). Without it a WARNING is printed.
#   2026-11-03.2 - orphan-translation sweep: table name read with (?m) - a table file starting with /// description
#                  lines was taken as missing and its whole translation block dropped (ClientC: 9 tables)
#   2026-11-03.1 - Step Q removed: Q&A linguisticMetadata is no longer deleted (Desktop regenerates it on every save, user 2026-11-03)
#   2026-11-02.2 - split into CleanUnused\*.ps1 (Common, Cultures, Report.Pre, Model, Report.Post), behaviour unchanged (regression on 4 projects)
#   2026-11-02.1 - CT_BlankTable (info-icon table, refactoring step 42) is never deleted.
#   2026-11-01.2 - (ClientF Sales v2) LF / mixed cultures files no longer fail the integrity
#                  check (every translation cleanup was skipped -> Desktop could not open);
#                  final sweep removes translations of any table / column / measure /
#                  hierarchy / level no longer in the model; hidden visuals named in a
#                  dead bookmark are kept with a WARN (popups to re-link), not deleted.
#   2026-11-01.1 - drillthrough fields (howCreated = Drillthrough) of a drillthrough page
#                  are never removed as "empty page filter cards" (ClientF Sales v2:
#                  8 fields of DT Sales Analysis were deleted, drillthrough broke).
#   2026-10-28.2 - no "Value cannot be null" error when the model has no Field
#                  Parameters ($fpTableNames built from @()).
#   2026-10-28.1 - a calculated column that is a relationship key (fromColumn/
#                  toColumn of any relationship, active or inactive) counts as
#                  used; column cleanup never deletes relationships (ClientC
#                  Sales NEW: Customers[קוד סוכן], Items[Tbl_Family.קוד אב] -
#                  keys of the TargetFamily relationships - were deleted with
#                  them). Unused TABLES still go with their relationships (Step 8).
#
# ORDER MATTERS: Field Parameter tables are evaluated and deleted FIRST, THEN
# measures, THEN other tables - not any other order. A Field Parameter's
# NAMEOF(...) entries count as root usage for measures (e.g. FP_Measure
# listing [BB Net %] keeps BB Net % - and transitively BB Net -> BB
# LaterMonth -> BB - alive). If measures were evaluated first using a Field
# Parameter that is ITSELF about to be deleted as unused, the measure-usage
# decision would be based on a root usage source that won't exist once this
# run finishes - exactly what happened the first time this was split into two
# independent passes: BB Net %/BB Net/BB LaterMonth/BB survived a run that
# deleted FP_Measure (their only reason to be considered "used"), leaving
# them orphaned until a second run. Evaluating Field Parameters first and
# excluding deleted ones from the measure root-usage scan closes that gap in
# a single run. Other (non-Field-Parameter) tables are evaluated LAST, after
# measures are finalized, so their DAX-reference check reads the model's
# final surviving state, not a stale pre-deletion snapshot.
#
# A measure that references a table which doesn't exist in this model at all
# (confirmed expected/by-design for e.g. LoanData in Collector Assignment\
# Report - a narrower report copy that deliberately excludes it) is deleted
# REGARDLESS of usage - it can't evaluate, so being placed in a visual
# doesn't make it viable. See Step 2b below.
#
# "Used" (measures) means referenced from any of:
#   - a visual/page/report/filter field in the .Report folder (the "Measure":
#     {...}, "Property": Name JSON shape, regardless of which table hosts the
#     measure - Entity is NOT required to literally be "Measure"; or a
#     "Measure.Name"-shaped queryRef/metadata selector, a weaker secondary
#     signal that only fires for measures actually hosted in the "Measure"
#     table)
#   - a calculated COLUMN's DAX
#   - a calculated TABLE's partition DAX (a surviving Field Parameter's
#     NAMEOF(...) entries included - see ORDER MATTERS above)
#   - a calculation group's calculationItem DAX (CG Dynamic Format / CG Time
#     Intelligence / CG Journal Entries in this model)
#   - ANOTHER measure that is itself used (transitively) - so a whole chain of
#     measures that only reference each other, with nothing live at the root,
#     is found and removed as a unit. A measure referenced only by another
#     now-unused measure is NOT considered "used".
#
# EXEMPT (user, 2026-10-24, ClientB): calculated columns whose DAX uses USERCULTURE() -
# culture-aware translation columns (He / En by the viewer's culture) - are never
# deleted, even when no visual uses them yet; their DAX counts as root usage.
#
# "Used" (calculated DAX columns - `column X = <expr>`, NOT a plain
# Power-Query-sourced column with no DAX) is a THIRD kind of candidate,
# evaluated together with measures in the SAME fixed-point loop (Step 3c
# below), because each can protect the other: a calculated column often
# exists only to expose a measure's result as a column (e.g. `column
# MileageColumn = [Mileage Avg]`), and a measure/another calculated column can
# just as easily read a calculated column back via `Table[Column]`. Before
# this, EVERY calculated column's DAX was unconditional root usage for
# whatever measure it referenced - regardless of whether the COLUMN itself
# was used anywhere. Found via the ZIPDim/AutoCount investigation
# (2026-09-13): a five-measure chain (BB #/BB SameMonth #/Sales #/Loans #/
# Mileage Avg) survived for no reason other than `LoanData[MileageColumn] =
# [Mileage Avg]` unconditionally counting as "used" - MileageColumn itself was
# never placed in a visual/filter or read by anything else, but nothing ever
# checked THAT. A calculated column now counts as "used" if ANY of:
#   - "Column": {...}, "Property": "<ColumnName>" for its own table/Entity
#     appears in .Report (the column-shaped counterpart of the Measure-
#     wrapper check above)
#   - `Table[Column]`/`'Table Name'[Column]` appears in any OTHER surviving
#     construct's DAX (a live measure, another live calculated column, a
#     calculated table's partition, a calculation group's calculationItem, or
#     a surviving Field Parameter's NAMEOF entries - NAMEOF('Table'[Column])
#     matches the same qualified-bracket shape, so a column offered as a
#     Field Parameter choice counts as used, same as a measure would)
#   - its bare name appears as a `sortByColumn:`/`groupByColumn:`/hierarchy
#     `column:` value elsewhere in its OWN table's file - deliberately loose,
#     same reasoning as the bare-word fallback for tables below: a false
#     "used" here only over-protects, never wrongly deletes
#   - it is a relationship key - `fromColumn:`/`toColumn:` of any relationship
#     in relationships.tmdl, active or inactive (2026-10-28). Column cleanup
#     never deletes relationships; a relationship goes only with an unused
#     TABLE (Step 8, Remove-TablesCompletely).
# CAVEAT: the dangling-translation cleanup for a deleted column matches by
# column NAME only, not table-qualified - if two different tables happen to
# have a same-named calculated column and only one is deleted, the survivor's
# translation entry could be stripped too. Not handled (narrow edge case);
# review cultures/*.tmdl if this model ever has same-named calculated columns
# in different tables.
#
# Detection is bare-bracket-reference based: `[Measure Name]` (no table
# qualifier) = a measure reference; `Table[Column]` / 'Table Name'[Column]` =
# a column reference, never counted. This matches this project's own DAX
# convention (Best Practice.txt: "table-name-qualify columns but not
# measures") - it is NOT a general DAX parser. PLUS: NAMEOF(...) is a
# deliberate, narrow exception to that rule - Field Parameter tables store
# their entries as NAMEOF('Measure'[Name]) or NAMEOF(Measure[Name]), ALWAYS
# table-qualified even when Name is a measure, because Power BI Desktop
# generates that syntax regardless of column vs. measure. A qualified bracket
# everywhere else in DAX still means "column, not measure" and is correctly
# excluded - but inside NAMEOF specifically, qualified must NOT be excluded.
# See the printed CAVEATS section every run - read it before trusting the
# result, especially the calculation-group one (SELECTEDMEASURE()/
# SELECTEDMEASURENAME() can apply a format string to a measure dynamically;
# that usage is invisible to this script).
#
# "Used" (Field Parameter tables) is a different, simpler check: a Field
# Parameter is placed into a visual as an ordinary Column-type field, so it
# counts as used if "Entity": "<TableName>" appears anywhere in .Report (every
# .json, not just an obvious spot) - Rows/Values/Legend/axis, slicers,
# filters, sort, at visual/page/report level alike. No transitive graph here
# (unlike measures) - Field Parameters aren't referenced from other DAX the
# way measures reference each other; table-level Entity presence is the whole
# check. EXCLUDED UNCONDITIONALLY, regardless of usage: any Field Parameter
# with at least one NAMEOF entry referencing the 'Calendar' table (date-grain
# switchers like FP_D-M-Q-Y/FP_Y-Q-M-D, or a mixed table like FP_Categories
# where only 1 of 13 entries touches Calendar) - considered too high-risk/hard
# to verify reliably to auto-delete.
#
# "Used" (other tables AND calculation groups, evaluated LAST) - HIGHER RISK
# than the above two: this can delete a genuine data/dimension table (or a
# whole calculation group), not just a measure or a synthetic Field Parameter
# selector. Excluded from consideration entirely: any table that hosts
# measures (protects the "Measure" table itself; until 2026-10-17 any table
# NAMED '*Measure*', which also kept measure-less tables), and every Field Parameter (detected the same way as
# the step above, regardless of whether it survived or was deleted - Field
# Parameters have their own dedicated handling and must not be re-evaluated
# here). CALCULATION GROUPS (detected structurally via the `calculationGroup`
# keyword - NOT by a "CG "-prefix naming convention, which is just this
# project's habit, not something to rely on) are NOT excluded - they are
# checked and deleted by these SAME rules, alongside ordinary tables (added
# 2026-09-13, by explicit request: "remove calculation groups if they are not
# referenced in measures, visuals, or as filters ... checks are the same as
# for unused measures"). Before this, calculation groups were excluded
# entirely from deletion and only used to gate whether THEIR OWN
# calculationItem DAX could protect other tables - found the hard way
# 2026-09-13: 5 of the first 6 tables this step ever deleted turned out to be
# calculation groups with no "CG " prefix (AutocountTargetDealer,
# CreditSummary, LoanCriteria, Operational, DateContext), restored from
# backup, because a calculation group applies via SELECTEDMEASURE()/
# SELECTEDMEASURENAME() to whatever measure is already in a visual and needs
# no "Entity" placement of its own to be functioning - so an ACTIVELY used
# calc group can still show zero Entity usage. That risk doesn't go away now
# that calc groups are deletable too: a calc group applied only via
# SELECTEDMEASURE()/SELECTEDMEASURENAME() (never named literally, and never
# placed as an "Entity" either) is invisible to every check below and can be
# wrongly deleted. Review the CAVEATS output and the deleted list against
# your own knowledge of the model's calculation groups specifically before
# trusting this step blindly. Everything (table or calculation group) counts
# as "used" if ANY of:
#   - any OTHER surviving measure/calculated-column/calculated-table DAX
#     references it (the candidate's OWN constructs are excluded from this
#     search - otherwise a plain single-word table name like parPTI always
#     "finds itself" inside its own `partition parPTI = calculated`
#     declaration line, a false positive also found in the same incident),
#     either as Table[Column]/'Table Name'[Column], or as a bare whole-table
#     reference (ALL(Table), VALUES(Table), CALCULATETABLE(...), etc. -
#     matched as a bare word, deliberately loose/generous since a false
#     "used" here only means over-protecting, never wrongly deleting)
#   - "Entity": "<TableName>" appears anywhere in .Report (same check as
#     Field Parameters)
# NOTE: having a relationship in relationships.tmdl is NOT by itself enough to
# count as "used" - a relationship only matters if something actually reads a
# column through it (a DAX reference, a USERELATIONSHIP, or the table's own
# column placed in a visual/filter/slicer); an unused table can still sit at
# one end of a relationship (e.g. a hidden lookup table nobody ever put a
# column from into a visual, filter, or formula) and that relationship alone
# does nothing. Found via user's explicit example (2026-09-13): DealerData
# had 3 relationships and NOTHING else - no DAX reference to
# DealerData[Column] anywhere, no "Entity": "DealerData" in .Report (the only
# other hit was DealerComparison's columns having `sourceColumn:
# DealerData[...]` - a Power Query-level lineage property, not DAX, and
# explicitly out of scope, see below) - yet it was being protected by the
# relationship check alone. Per this rule it is now correctly flagged
# unused, and Remove-TablesCompletely drops its relationship block(s) too
# when the table itself is deleted. Relationship presence is still computed
# and printed per deleted table below, purely as an FYI (a relationship-only
# deletion is a bigger structural change than deleting an already-orphaned
# table with zero relationships, worth a second look before trusting).
# SAME TREATMENT for a reference from inside a calculation group's
# calculationItem DAX (2026-09-13, parVehicleAge example): since a
# calculation group is now just another candidate in the same fixed-point
# loop below, its calculationItem DAX only keeps counting as usage evidence
# for another table for as long as the calc group itself remains
# NOT-yet-confirmed-unused - once the fixed-point loop confirms the calc
# group itself has nothing else protecting it, its DAX drops out of every
# other candidate's search on the next pass, same as any ordinary table's
# construct would. Found via investigating why parVehicleAge/parMileage/
# parLTV/parPTI survived (before this rule existed, when calc groups were
# still excluded from deletion and only gated as a protector): LoanCriteria
# (a calculation group) has calculationItem DAX containing bare-bracket text
# like `[parVehicleAge Value]` - which by this project's convention reads as
# a MEASURE reference, except no measure by that name exists anywhere in
# this model OR Model_v2 (a pre-existing dangling reference in LoanCriteria's
# own DAX, unrelated to anything this script did) - yet the bare-word
# fallback match still treated it as evidence the parVehicleAge TABLE was
# used.
# This does NOT see: RLS role filters (none exist in this model as of the
# last check), a Power Query M-level reference/merge from another table (not
# modeled in TMDL DAX - e.g. a plain `column X / sourceColumn: OtherTable[Y]`
# with no `=` DAX expression, which is a Power Query lineage property, not a
# calculated column), or a dynamically-built table reference (e.g. a table
# name assembled via string concatenation). Given the higher stakes, review
# the deleted list against your own knowledge of the model before trusting it
# blindly - same as for the measure caveats below, but more so.
#
# Deletes on the spot, in the same run that identifies them - no separate
# report file/list. Read the CAVEATS this script prints BEFORE running it
# against a model you haven't checked with it before.
#
# Also cleans up now-dangling entries left behind in definition\cultures\
# *.tmdl's TMDL-native `translations` block (`measure 'Name'`/`table 'Name'`
# + caption) for anything this script deletes - left alone, that fails Power
# BI Desktop's model load ENTIRELY (not a cosmetic Q&A issue - that's the
# separate, tolerated linguisticMetadata JSON blob further down the same
# file), found the hard way 2026-09-13.
#
# -Port N (2026-10-17, ClientB): the .pbip is OPEN in Power BI Desktop. The run
# itself is the same (files on disk, backup), then Sync-OpenModel (end of the
# script) carries it into Desktop: report edits via the bridge (apply
# external changes), model deletions via TOM into the open model on port N
# (the bridge apply does NOT pick up model deletions - 2026-10-15/17, the
# next Ctrl+S wrote them back), then Ctrl+S and a check of the saved files.
# Unsaved Desktop changes are saved first. -DesktopPid: only when the .pbip
# path does not identify the Desktop process.
#
# SCRIPT_VERSION: 2026-10-17.2
param(
    [string]$RootPath = $PSScriptRoot,
    [int]$Port = 0,
    [int]$DesktopPid = 0,
    # -Port only: skip the Ctrl+S before the backup. Desktop sets "unsaved changes" by itself right after it
    # opens a file or applies external changes, and then Ctrl+S writes nothing (the run stopped: "did not reach
    # the files in 120 s", ClientD Finance 2026-10-23). Use only when the files are known to match Desktop.
    [switch]$SkipInitialSave,
    # Thin (live-connected) reports of this model, ';'-separated: *.Report folders or folders that hold one.
    # Their visuals / filters / bookmarks / report-level measures count as usage; their files are never edited.
    # Semantic Model: "..\Collector Assignment\Thin Collector Assignment;..\Collector Assignment\Thin Scorecard".
    [string]$ThinReports = "",
    [int]$Pass = 1   # internal - set by the script itself when it re-runs (see the end)
)

$ScriptVersion = "2026-11-06.1"   # 11-06.1: -ThinReports (usage of live-connected reports); 11-03.2: orphan sweep reads table names after /// lines; 11-03.1: Step Q (Q&A data) removed;11-02.2: split into CleanUnused\*.ps1, behaviour unchanged; 11-02.1: CT_BlankTable kept; 11-01.2: LF cultures, orphan-translation sweep, popups of dead bookmarks kept; 11-01.1: drillthrough fields kept; .2: no null error without Field Parameters; .1: relationship-key columns kept (see Change log)

if ($PSVersionTable.PSVersion.Major -lt 7) {
    $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwshCmd) {
        Write-Host "Relaunching under PowerShell 7+ (pwsh)..."
        # Forward the bound parameters explicitly - with a param() block @args
        # is empty, so -RootPath was silently dropped (2026-10-13).
        $fwd = foreach ($k in $PSBoundParameters.Keys) { $v = $PSBoundParameters[$k]; if ($v -is [switch]) { if ($v) { "-$k" } } else { "-$k"; "$v" } }
        & $pwshCmd.Source -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath @fwd
        exit $LASTEXITCODE
    } else {
        Write-Error "PowerShell 7+ (pwsh) is required but was not found. Install it from https://aka.ms/PSWindows and re-run this script."
        exit 1
    }
}

Write-Host ""
Write-Host "Find-UnusedMeasures.ps1 version $ScriptVersion - pass $Pass"
Write-Host ""

$semanticFolders = Get-ChildItem -Path $RootPath -Directory -Filter "*.SemanticModel"
$reportFolders = Get-ChildItem -Path $RootPath -Directory -Filter "*.Report"
if ($semanticFolders.Count -ne 1 -or $reportFolders.Count -ne 1) {
    Write-Error "Expected exactly one *.SemanticModel and one *.Report folder under: $RootPath (found $($semanticFolders.Count) / $($reportFolders.Count)). Pass -RootPath if this script isn't sitting next to them."
    exit 1
}
$semanticPath = $semanticFolders[0].FullName
$reportFolderPath = $reportFolders[0].FullName
$tablesPath = Join-Path $semanticPath "definition\tables"
$modelPath = Join-Path $semanticPath "definition\model.tmdl"
$relationshipsPath = Join-Path $semanticPath "definition\relationships.tmdl"
$culturesPath = Join-Path $semanticPath "definition\cultures"
$rolesPath = Join-Path $semanticPath "definition\roles"

# -ThinReports: resolve each entry (relative to -RootPath) to exactly one *.Report folder; a wrong path stops the run.
$thinReportFolders = @()
foreach ($t in @($ThinReports -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
    $p = if ([System.IO.Path]::IsPathRooted($t)) { $t } else { Join-Path $RootPath $t }
    if (-not (Test-Path $p -PathType Container)) { Write-Error "-ThinReports: folder not found: $p"; exit 1 }
    $rf = if ((Split-Path $p -Leaf) -like '*.Report') { @(Get-Item $p) } else { @(Get-ChildItem -Path $p -Directory -Filter "*.Report") }
    if ($rf.Count -ne 1) { Write-Error "-ThinReports: expected one *.Report folder in $p (found $($rf.Count))"; exit 1 }
    $thinReportFolders += $rf[0].FullName
}
if ($thinReportFolders.Count -gt 0) {
    Write-Host "Thin reports (usage only, never edited):"; $thinReportFolders | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "WARNING: no -ThinReports - measures used only in live-connected thin reports would be deleted." -ForegroundColor Yellow
}
Write-Host ""

# ---------------------------------------------------------------------------
# -Port: Desktop is open on this .pbip (see the header). Checked BEFORE the
# backup: the port must be this model, and Desktop must be saved - the run
# reads the files, so unsaved Desktop changes would be lost by the apply.
# ---------------------------------------------------------------------------
# Names of the model objects in a *.SemanticModel folder: tables, their
# measures/columns ("measure|Name", "column|Name") and relationship names.
# Sync-OpenModel compares the
# backup with the cleaned files to know what to delete in the open model.
function Get-ModelObjectNames {
    param([string]$SemanticPath)
    $o = @{ Tables = @{}; Relationships = @() }
    foreach ($tf in Get-ChildItem (Join-Path $SemanticPath "definition\tables") -Filter "*.tmdl") {
        $text = Get-Content $tf.FullName -Raw
        $h = [regex]::Match($text, "(?m)^table\s+(?:'((?:[^']|'')+)'|(\S+))")
        $name = if ($h.Groups[1].Success) { $h.Groups[1].Value -replace "''", "'" } else { $h.Groups[2].Value }
        $o.Tables[$name] = @([regex]::Matches($text, "(?m)^\t(measure|column)\s+(?:'((?:[^']|'')+)'|([^\s=]+))") | ForEach-Object {
            "$($_.Groups[1].Value)|$(if ($_.Groups[2].Success) { $_.Groups[2].Value -replace "''", "'" } else { $_.Groups[3].Value })"
        })
    }
    $relFile = Join-Path $SemanticPath "definition\relationships.tmdl"
    if (Test-Path $relFile) { $o.Relationships = @([regex]::Matches((Get-Content $relFile -Raw), "(?m)^relationship\s+(\S+)") | ForEach-Object { $_.Groups[1].Value }) }
    return $o
}

if ($Port -and $Pass -eq 1) {
    [void][Reflection.Assembly]::LoadFrom("C:\Program Files\DAX Studio\bin\Microsoft.AnalysisServices.Tabular.dll")
    $srv = New-Object Microsoft.AnalysisServices.Tabular.Server
    $srv.Connect("Data Source=localhost:$Port")
    $diskTables = @((Get-ModelObjectNames $semanticPath).Tables.Keys)
    $notInModel = @($diskTables | Where-Object { -not $srv.Databases[0].Model.Tables.Contains($_) })
    $srv.Disconnect()
    if ($notInModel.Count) { Write-Error "Port $Port is not this model - tables on disk missing there: $($notInModel -join ', ')"; exit 1 }

    $status = (& powerbi-desktop status | Out-String | ConvertFrom-Json).instances
    $pbip = @(Get-ChildItem -Path $RootPath -Filter *.pbip)[0].FullName
    $inst = if ($DesktopPid) { $status | Where-Object pid -eq $DesktopPid } else { $status | Where-Object { $_.currentFilePath -eq $pbip } }
    if (@($inst).Count -ne 1) { Write-Error "Desktop with $pbip not found (powerbi-desktop status) - pass -DesktopPid"; exit 1 }
    $DesktopPid = $inst.pid
    Write-Host "-Port $Port : Desktop pid $DesktopPid, unsaved changes: $($inst.hasUnsavedChanges)"

    # Ctrl+S to THIS Desktop window only (same logic as ReplaceModelTable.ps1
    # Save-Desktop): bring it forward, check the foreground window belongs to
    # $DesktopPid, only then send the keys; wait until a SemanticModel file is
    # newer than the keypress.
    function Save-Desktop {
        if (-not ('Cu.Win' -as [type])) {
            Add-Type -Namespace Cu -Name Win -MemberDefinition @'
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
[DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
'@
        }
        $h = (Get-Process -Id $DesktopPid).MainWindowHandle
        $fgPid = 0
        foreach ($try in 1..5) {
            [void][Cu.Win]::ShowWindow($h, 9)                            # restore if minimized
            [Cu.Win]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)           # Alt down/up: lets SetForegroundWindow work
            [Cu.Win]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
            [void][Cu.Win]::SetForegroundWindow($h)
            Start-Sleep -Milliseconds 500
            [uint32]$fg = 0; [void][Cu.Win]::GetWindowThreadProcessId([Cu.Win]::GetForegroundWindow(), [ref]$fg); $fgPid = $fg
            if ($fgPid -eq $DesktopPid) { break }
        }
        if ($fgPid -ne $DesktopPid) { Write-Error "Could not bring Desktop pid $DesktopPid to the front (foreground: pid $fgPid) - no keys sent; save it by hand"; exit 1 }
        $since = Get-Date
        (New-Object -ComObject WScript.Shell).SendKeys('^s')
        $newer = { @(Get-ChildItem $semanticPath -Recurse -File | Where-Object LastWriteTime -gt $since).Count -gt 0 }
        do { Start-Sleep 3 } until ((& $newer) -or (Get-Date) -gt $since.AddSeconds(120))
        if (-not (& $newer)) { Write-Error "Ctrl+S did not reach the files in 120 s - save in Desktop by hand"; exit 1 }
        Start-Sleep 5   # let Desktop finish writing every file
        Write-Host "  OK Desktop saved"
    }

    # Carry this run into the open Desktop: report via the bridge apply FIRST
    # (a Ctrl+S after TOM writes Desktop's in-memory report over the files),
    # then every model object the run removed from the files (backup vs now)
    # is removed from the open model via TOM, then Ctrl+S, then the saved
    # files are checked - none of the removed objects may come back.
    function Sync-OpenModel {
        Write-Host ""
        Write-Host "-Port: applying this run to the open Desktop (pid $DesktopPid, port $Port)..."
        $before = Get-ModelObjectNames $backupDest
        $after = Get-ModelObjectNames $semanticPath
        $goneTables = @($before.Tables.Keys | Where-Object { -not $after.Tables.ContainsKey($_) })
        # Objects, not "Table|kind|Name" strings: a table name can contain "|"
        # (ClientD Finance 'P&L|Balance Sheet Labels' - the split went wrong and
        # $coll was $null, 2026-10-23). $x is "kind|Name" - kind has no "|".
        $goneMembers = @(foreach ($t in $after.Tables.Keys) { if ($before.Tables.ContainsKey($t)) { foreach ($x in $before.Tables[$t]) { if ($after.Tables[$t] -notcontains $x) { $k, $n = $x -split '\|', 2; [pscustomobject]@{ Table = $t; Kind = $k; Name = $n; Key = $x } } } } })
        $goneRels = @($before.Relationships | Where-Object { $after.Relationships -notcontains $_ })

        $r = & powerbi-desktop reload --pid $DesktopPid | Out-String | ConvertFrom-Json
        if (-not $r.result.success) { Write-Error "powerbi-desktop reload failed - the open model was NOT changed; do not save Desktop"; exit 1 }
        Write-Host "  OK Applied external changes (bridge) - report edits"

        $srv = New-Object Microsoft.AnalysisServices.Tabular.Server
        $srv.Connect("Data Source=localhost:$Port")
        $model = $srv.Databases[0].Model
        $changed = 0
        foreach ($n in $goneRels) { $rel = $model.Relationships.Find($n); if ($rel) { [void]$model.Relationships.Remove($rel); $changed++ } }
        foreach ($m in $goneMembers) {
            $tbl = $model.Tables.Find($m.Table); if (-not $tbl) { continue }
            # Not `$coll = if (...) { $tbl.Measures } ...` - an if-expression enumerates the collection and $coll
            # became a Measure / an array ("does not contain a method named 'Find'", 2026-10-23).
            if ($m.Kind -eq 'measure') { $coll = $tbl.Measures } else { $coll = $tbl.Columns }
            $obj = $coll.Find($m.Name); if ($obj) { [void]$coll.Remove($obj); $changed++; Write-Host "  TOM removed $($m.Kind) $($m.Table)[$($m.Name)]" }
        }
        foreach ($t in $goneTables) { $tbl = $model.Tables.Find($t); if ($tbl) { [void]$model.Tables.Remove($tbl); $changed++; Write-Host "  TOM removed table $t" } }
        if ($changed) { $model.SaveChanges() | Out-Null }
        $srv.Disconnect()
        Write-Host "  OK open model: $changed change(s) ($($goneRels.Count) relationship(s) removed on disk)"
        if (-not $changed) { Write-Host "  Nothing to save - the apply already matches the files."; return }

        Save-Desktop
        $saved = Get-ModelObjectNames $semanticPath
        $back = @($goneTables | Where-Object { $saved.Tables.ContainsKey($_) }) +
                @($goneMembers | Where-Object { $saved.Tables.ContainsKey($_.Table) -and $saved.Tables[$_.Table] -contains $_.Key } | ForEach-Object { "$($_.Table)[$($_.Name)]" }) +
                @($goneRels | Where-Object { $saved.Relationships -contains $_ })
        if ($back.Count) { Write-Host "  FAIL after Ctrl+S these are back in the files: $($back -join ', ')" -ForegroundColor Red; exit 1 }
        Write-Host "  OK saved files match - nothing removed came back"
    }

    if ($inst.hasUnsavedChanges -and $SkipInitialSave) { Write-Host "  -SkipInitialSave: no Ctrl+S before the backup (files assumed to match Desktop)" }
    elseif ($inst.hasUnsavedChanges) { Save-Desktop }
}

# ---------------------------------------------------------------------------
# Backup - this script deletes content. Always copy the WHOLE *.SemanticModel
# folder (not just definition\tables\ - it also writes to definition\
# cultures\*.tmdl, model.tmdl and relationships.tmdl for Field Parameter and
# other table deletions) to ClientA\BackUp\ first. Not a switch, not optional - a
# prior run of this exact script deleted 475 measures with no backup taken,
# and this project isn't a git repo, so there was no local revert path
# afterward (see feedback_backup_before_changes memory).
# ---------------------------------------------------------------------------
# Only before the FIRST pass - later passes (see the end of the script) work
# on files this same run already backed up.
if ($Pass -eq 1) {
    $backupRoot = Join-Path (Split-Path $RootPath -Parent) "BackUp"
    $backupDest = Join-Path $backupRoot ("Find-UnusedMeasures_" + (Get-Date -Format "yyyy-MM-dd_HHmmss") + "\" + $semanticFolders[0].Name)
    New-Item -ItemType Directory -Path $backupDest -Force | Out-Null
    Copy-Item -Path (Join-Path $semanticPath "*") -Destination $backupDest -Recurse -Force
    Write-Host "OK Backed up $($semanticFolders[0].Name) to $backupDest"
    # Step 9 edits *.Report filter cards - back the report up too (2026-10-06).
    $reportBackupDest = Join-Path (Split-Path $backupDest -Parent) $reportFolders[0].Name
    New-Item -ItemType Directory -Path $reportBackupDest -Force | Out-Null
    Copy-Item -Path (Join-Path $reportFolderPath "*") -Destination $reportBackupDest -Recurse -Force
    Write-Host "OK Backed up $($reportFolders[0].Name) to $reportBackupDest"
    Write-Host ""
}

# ---------------------------------------------------------------------------
# The stages live in CleanUnused\*.ps1 (split 2026-11-02, behaviour unchanged). Dot-sourced in this order,
# in this scope - they share every variable. Order matters: Step R frees model objects for Steps 0-8, Steps
# 9-11 clean the report after the model deletions. Common.ps1 only defines helpers (no output).
# ---------------------------------------------------------------------------
. (Join-Path $PSScriptRoot "CleanUnused\Common.ps1")
. (Join-Path $PSScriptRoot "CleanUnused\Cultures.ps1")
. (Join-Path $PSScriptRoot "CleanUnused\Report.Pre.ps1")
. (Join-Path $PSScriptRoot "CleanUnused\Model.ps1")
. (Join-Path $PSScriptRoot "CleanUnused\Report.Post.ps1")

# ---------------------------------------------------------------------------
# Safety net, not the normal path: empty filter cards no longer count as
# usage (see $usageText), so a single pass normally finishes the job. One
# case still needs another pass - a calculated TABLE that Step 8 deletes was
# root usage for a measure in Steps 3-6 (its partition DAX referenced it;
# Targets_YTD, ClientE 2026-10-06). If a pass deleted anything, the script
# re-checks itself on the same files (no new backup) until a pass deletes
# nothing - no manual re-run. Capped at 10 passes.
Write-Host "Final check: culture translations of objects that are no longer in the model..."
Remove-OrphanTranslations

$deletedThisPass = @($unusedFP).Count + @($unused).Count + @($unusedColumns).Count + @($unusedTables).Count + $cardsRemoved + $bmDeleted + $visDeleted + $s10Visuals + $s10BmItems
if ($deletedThisPass -gt 0) {
    if ($Pass -lt 10) {
        Write-Host ""
        Write-Host "Pass $Pass deleted $deletedThisPass item(s) - running pass $($Pass + 1) to catch what they were protecting..." -ForegroundColor Cyan
        & $PSCommandPath -RootPath $RootPath -ThinReports $ThinReports -Pass ($Pass + 1)
        if ($LASTEXITCODE -or -not ($Port -and $Pass -eq 1)) { exit $LASTEXITCODE }
        Sync-OpenModel
        exit 0
    }
    Write-Host "Stopped after 10 passes although the last one still deleted something - check the log." -ForegroundColor Red
}

if ($Port -and $Pass -eq 1) { Sync-OpenModel }
Write-Host ""
Write-Host "Nothing left to delete after pass $Pass."
Write-Host "Done! Re-open the model in Power BI Desktop and confirm it loads/refreshes cleanly."
