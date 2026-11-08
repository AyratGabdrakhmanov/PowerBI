# CleanUnused\Common.ps1 - part of CleanUnused.ps1, dot-sourced by it (same scope: shares its variables).
# Shared helpers: TMDL constructs, DAX / JSON reference parsing, translation and table removal, integrity check.
# Not runnable on its own. No `exit` here: an exit in a dot-sourced file does not stop CleanUnused.ps1.

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Every "top-level construct" line inside a table .tmdl. measure/column/
# hierarchy/partition sit directly under `table X` (1-tab indent);
# calculationItem sits one level deeper, under `table X / calculationGroup`
# (2-tab indent) - `\t*` (zero or more) rather than a fixed `\t` covers both,
# found the hard way 2026-09-13: the old fixed-1-tab regex NEVER matched any
# calculationItem in this model (all 10 calculation groups indent it at 2
# tabs), so calc-group DAX silently never contributed to measure root usage
# (Step 3) or the other-tables DAX check (Step 8) - e.g. DateContext's calc
# items reference PaymentData[PaymentDate]/LoanParameterChange[CreatedDate]/
# etc. via USERELATIONSHIP, invisibly to this script until this fix. A
# construct's block runs from its own line to just before the next one (or
# EOF) - covers its multi-line/fenced DAX and its metadata (formatString,
# displayFolder, lineageTag, annotation, changedProperty) in one span, which
# is all we need for reference-scanning (metadata lines don't contain
# `[Name]`-shaped text in practice).
$constructLineRegex = '(?m)^\t*(measure|column|hierarchy|partition|calculationItem)\s'

function Get-TmdlConstructs {
    param([string]$Text, [string]$FilePath, [string]$TableName)

    $starts = [regex]::Matches($Text, $constructLineRegex)
    $result = @()
    for ($i = 0; $i -lt $starts.Count; $i++) {
        $kind = $starts[$i].Groups[1].Value
        $startIdx = $starts[$i].Index
        $endIdx = if ($i + 1 -lt $starts.Count) { $starts[$i + 1].Index } else { $Text.Length }
        $block = $Text.Substring($startIdx, $endIdx - $startIdx)

        $name = $null
        if ($kind -in @('measure', 'column', 'calculationItem')) {
            # Normal case: name followed by "= <DAX>". Fallback handles the rare
            # measure that's just a name + metadata with no expression at all
            # (e.g. 'Sales vs. Goal Title' in this model) - no "=" on that line.
            $nameMatch = [regex]::Match($block, "^\t*$kind\s+(?:'([^']+)'|(\S+?))\s*=")
            if (-not $nameMatch.Success) {
                $nameMatch = [regex]::Match($block, "^\t*$kind\s+(?:'([^']+)'|(\S+))\s*(?:\r?\n|$)")
            }
            if ($nameMatch.Success) {
                $name = if ($nameMatch.Groups[1].Success) { $nameMatch.Groups[1].Value } else { $nameMatch.Groups[2].Value }
            }
        } elseif ($kind -eq 'partition') {
            $nameMatch = [regex]::Match($block, "^\t*partition\s+(?:'([^']+)'|(\S+))")
            if ($nameMatch.Success) {
                $name = if ($nameMatch.Groups[1].Success) { $nameMatch.Groups[1].Value } else { $nameMatch.Groups[2].Value }
            }
        }

        $result += [PSCustomObject]@{
            Kind      = $kind
            Name      = $name
            IsCalcDax = ($kind -eq 'measure') -or ($kind -eq 'calculationItem') -or ($kind -eq 'partition') -or (($kind -eq 'column') -and ($block -match "^\tcolumn\s+(?:'[^']+'|\S+)\s*="))
            IsMeasure = ($kind -eq 'measure')
            FilePath  = $FilePath
            Table     = $TableName
            StartIdx  = $startIdx
            EndIdx    = $endIdx
            Block     = $block
        }
    }
    return $result
}

# Bare `[Name]` = measure reference (see header comment). PLUS: NAMEOF(...)
# is a deliberate, narrow exception - Field Parameter tables (this model has
# several: Dynamic Numeric Parameter, FP_Measure, etc.) store their entries as
# NAMEOF('Measure'[Name]) or NAMEOF(Measure[Name]) - ALWAYS table-qualified,
# even when Name is a measure, because Power BI Desktop generates that syntax
# regardless of column vs. measure. A qualified bracket everywhere else in DAX
# still means "column, not measure" and is correctly excluded - but inside
# NAMEOF specifically, qualified must NOT be excluded, or a measure used only
# via a Field Parameter looks unused. (Found the hard way: NAMEOF('Measure'
# [Borrower Age]) in Dynamic Numeric Parameter.tmdl was invisible to the old
# bare-only regex, and "Borrower Age" got deleted while still in use.)
# Report JSON stores names JSON-escaped: `Credit\Debit balance` is
# "Credit\\Debit balance" in the file. Regex captures of report names must be
# unescaped before comparing with model names, and a model name searched for
# in report text must be escaped first (2026-10-23, ClientD Finance: two used
# measures with `\` in the name were deleted as unused).
# $JsonStr - the capture group for a JSON string body: escaped chars allowed.
$JsonStr = '((?:[^"\\]|\\.)+)'
function ConvertFrom-JsonStringBody { param([string]$s) if ($s.Contains('\')) { [regex]::Unescape($s) } else { $s } }
function ConvertTo-JsonStringBody { param([string]$s) $s.Replace('\', '\\').Replace('"', '\"') }

function Get-BracketRefs {
    param([string]$Text)
    $bare = [regex]::Matches($Text, "(?<![\w'\]])\[([^\[\]]+)\]") | ForEach-Object { $_.Groups[1].Value }
    $nameofQualified = [regex]::Matches($Text, "NAMEOF\s*\(\s*(?:'[^']+'|[A-Za-z_]\w*)\[([^\[\]]+)\]\s*\)") | ForEach-Object { $_.Groups[1].Value }
    return $bare + $nameofQualified
}

# DAX with /* block */, // line and -- line comments removed. Used only by
# Get-QualifiedTableRefs (Step 2b "references a nonexistent table") - found
# 2026-10-06 in ClientE Sales Main: 'New Customers' and 'Sales Last Period'
# were deleted although used in the report, because their OLD, commented-out
# code (/* ... DocsSales[DocDate] ... */) named a table that no longer exists.
# Deliberately NOT applied to usage detection elsewhere - a stripped comment
# there could only turn "used" into "unused".
#
# A character scanner, not a regex (2026-10-23, ClientD Finance): DAX block
# comments NEST (`1 /* a /* b */ c */ + 1` = 2, checked on the engine), and
# `//` / `--` inside a "string" is not a comment. The old non-greedy
# `/\*.*?\*/` closed the outer comment at the inner `*/`, so commented-out
# code after it counted as live - [Cumulative Balance] was deleted as
# "references a nonexistent table" ('Date&Periods' only in nested comments)
# although a visible visual used it.
function Remove-DaxComments {
    param([string]$Text)
    $sb = [System.Text.StringBuilder]::new($Text.Length)
    $depth = 0; $inStr = $false; $i = 0
    while ($i -lt $Text.Length) {
        $ch = $Text[$i]; $nx = if ($i + 1 -lt $Text.Length) { $Text[$i + 1] } else { [char]0 }
        if ($depth -gt 0) {
            if ($ch -eq '/' -and $nx -eq '*') { $depth++; $i += 2; continue }
            if ($ch -eq '*' -and $nx -eq '/') { $depth--; $i += 2; continue }
            if ($ch -eq "`n") { [void]$sb.Append($ch) }   # keep line numbers
            $i++; continue
        }
        if ($inStr) {
            [void]$sb.Append($ch)
            if ($ch -eq '"') { if ($nx -eq '"') { [void]$sb.Append($nx); $i += 2; continue }; $inStr = $false }
            $i++; continue
        }
        if ($ch -eq '"') { $inStr = $true; [void]$sb.Append($ch); $i++; continue }
        if ($ch -eq '/' -and $nx -eq '*') { $depth = 1; $i += 2; continue }
        if (($ch -eq '/' -and $nx -eq '/') -or ($ch -eq '-' -and $nx -eq '-')) {
            while ($i -lt $Text.Length -and $Text[$i] -ne "`n") { $i++ }
            continue
        }
        [void]$sb.Append($ch); $i++
    }
    return $sb.ToString()
}

# Every TABLE name a qualified reference names - `'Table Name'[Column]` or
# `Table[Column]`, wherever it appears in the DAX (including inside NAMEOF).
# Used only to check "does this measure name a table that doesn't exist" -
# unlike Get-BracketRefs, this deliberately returns the qualifier, not the
# bracket content.
function Get-QualifiedTableRefs {
    param([string]$Text)
    $Text = Remove-DaxComments -Text $Text
    return [regex]::Matches($Text, "(?:'([^']+)'|(?<![\w'\]])([A-Za-z_]\w*))\[") | ForEach-Object {
        if ($_.Groups[1].Success) { $_.Groups[1].Value } else { $_.Groups[2].Value }
    }
}

# Same shape as Get-QualifiedTableRefs, but keeps the bracket content too -
# needed to tell exactly which TABLE[COLUMN] pair a piece of DAX reads, so a
# calculated column's own usage can be judged the same way (Step 3c below).
# Also matches NAMEOF('Table'[Column]) - NAMEOF doesn't change the
# qualifier-bracket shape this regex looks for.
function Get-QualifiedColumnRefs {
    param([string]$Text)
    return [regex]::Matches($Text, "(?:'([^']+)'|(?<![\w'\]])([A-Za-z_]\w*))\[([^\[\]]+)\]") | ForEach-Object {
        [PSCustomObject]@{
            Table  = if ($_.Groups[1].Success) { $_.Groups[1].Value } else { $_.Groups[2].Value }
            Column = $_.Groups[3].Value
        }
    }
}

# Start/end index of each top-level object in the JSON array that opens at
# $ArrayStart ('['), skipping over strings. Returns @(@(start,end), ...).
function Get-JsonArrayObjectSpans {
    param([string]$Text, [int]$ArrayStart)
    $spans = @(); $depth = 0; $inStr = $false; $start = -1
    for ($i = $ArrayStart + 1; $i -lt $Text.Length; $i++) {
        $ch = $Text[$i]
        if ($inStr) { if ($ch -eq '\') { $i++ } elseif ($ch -eq '"') { $inStr = $false }; continue }
        if ($ch -eq '"') { $inStr = $true }
        elseif ($ch -eq '{' -or $ch -eq '[') { if ($depth -eq 0 -and $ch -eq '{') { $start = $i }; $depth++ }
        elseif ($ch -eq '}' -or $ch -eq ']') {
            if ($depth -eq 0) { break }   # end of the array itself
            $depth--
            if ($depth -eq 0 -and $ch -eq '}') { $spans += , @($start, $i) }
        }
    }
    # Unary comma: without it PowerShell unrolls a ONE-span result into a
    # flat @(start, end) (hit on the first test - a visual with one card).
    return , $spans
}

# CRLF + triple-backtick fence-parity check (same invariant the project's own
# POWERBI_PBIP_STRUCTURE.md documents for hand-edits to Measure.tmdl/
# functions.tmdl) - run after every write so a corrupted file is caught
# immediately, not discovered later when Power BI Desktop fails to open it.
function Test-TmdlIntegrity {
    param([string]$Text, [string]$FilePath)
    $bareLf = [regex]::Matches($Text, "(?<!\r)\n").Count
    $fenceCount = ([regex]::Matches($Text, '```')).Count
    # (2026-11-01) an LF / mixed file on disk keeps its endings - bare LF is only an error in a CRLF-only file
    # (ClientF Sales v2: LF cultures files failed this check, every translation cleanup was skipped)
    $diskLf = if ($FilePath -and (Test-Path $FilePath)) { [regex]::Matches([System.IO.File]::ReadAllText($FilePath), "(?<!\r)\n").Count } else { 0 }
    $ok = (($bareLf -eq 0) -or ($diskLf -gt 0)) -and ($fenceCount % 2 -eq 0)
    if (-not $ok) {
        Write-Host "  FAIL integrity check: $FilePath (bare LF: $bareLf, fence count: $fenceCount)" -ForegroundColor Red
    }
    return $ok
}

# Remove a `translations` sub-entry (`measure 'Name'` or `table 'Name'`, plus
# everything nested more deeply under it - captions, nested column/measure
# entries) for every name in $NamesToRemove, from the TMDL-native header
# portion of a cultures file (never linguisticMetadata - see the cleanup
# steps below for why that split matters).
function Remove-TranslationEntries {
    param([string]$Header, [string]$Keyword, [System.Collections.Generic.HashSet[string]]$NamesToRemove)
    $lineStarts = [regex]::Matches($Header, "(?m)^(\t+)$Keyword\s+(?:'([^']+)'|(\S+))\s*`$")
    $removed = 0
    $sb = New-Object System.Text.StringBuilder
    $cursor = 0
    for ($i = 0; $i -lt $lineStarts.Count; $i++) {
        $m = $lineStarts[$i]
        $name = if ($m.Groups[2].Success) { $m.Groups[2].Value } else { $m.Groups[3].Value }
        if (-not $NamesToRemove.Contains($name)) { continue }
        $indent = $m.Groups[1].Value.Length
        $entryStart = $m.Index
        $entryEnd = $Header.Length
        $nextLineMatches = [regex]::Matches($Header.Substring($m.Index + $m.Length), '(?m)^(\t*)\S')
        foreach ($nl in $nextLineMatches) {
            if ($nl.Groups[1].Value.Length -le $indent) { $entryEnd = $m.Index + $m.Length + $nl.Index; break }
        }
        [void]$sb.Append($Header.Substring($cursor, $entryStart - $cursor))
        $cursor = $entryEnd
        $removed++
    }
    [void]$sb.Append($Header.Substring($cursor))
    return [PSCustomObject]@{ Text = $sb.ToString(); Removed = $removed }
}

# Removes a whole table's dangling `translations` entry (table + measure, in
# whichever cultures file has it), same integrity-checked write as everywhere
# else. Shared by the Field Parameter, measure, and other-table cleanup steps.
function Remove-DanglingTranslations {
    param([string]$CulturesPath, [string]$Keyword, [System.Collections.Generic.HashSet[string]]$NamesToRemove, [string]$LabelSingular, [string]$LabelPlural)
    if (-not (Test-Path $CulturesPath)) { return }
    Get-ChildItem -Path $CulturesPath -Filter "*.tmdl" | ForEach-Object {
        $text = Get-Content $_.FullName -Raw
        $splitIdx = $text.IndexOf("`tlinguisticMetadata")
        $header = if ($splitIdx -ge 0) { $text.Substring(0, $splitIdx) } else { $text }
        $rest = if ($splitIdx -ge 0) { $text.Substring($splitIdx) } else { "" }
        $result = Remove-TranslationEntries -Header $header -Keyword $Keyword -NamesToRemove $NamesToRemove
        if ($result.Removed -gt 0) {
            $newText = $result.Text + $rest
            if (Test-TmdlIntegrity -Text $newText -FilePath $_.FullName) {
                [System.IO.File]::WriteAllText($_.FullName, $newText, (New-Object System.Text.UTF8Encoding($false)))
                $label = if ($result.Removed -eq 1) { $LabelSingular } else { $LabelPlural }
                Write-Host "  OK $($_.Name): removed $($result.Removed) $label"
            } else {
                Write-Host "  SKIPPED $($_.Name) - integrity check failed, file left untouched." -ForegroundColor Red
            }
        }
    }
}

# Deletes a set of whole tables completely: model.tmdl's "ref table" line,
# any relationships.tmdl block touching them, their cultures/*.tmdl
# translation entry, and finally the .tmdl file itself. Shared by the Field
# Parameter step and the other-tables step - the only difference between them
# is how "unused" gets decided, not what deleting one looks like.
function Remove-TablesCompletely {
    param(
        [System.Collections.Generic.HashSet[string]]$NamesToRemove,
        [string[]]$FilePaths,
        [string]$ModelPath,
        [string]$RelationshipsPath,
        [string]$CulturesPath
    )
    if ($NamesToRemove.Count -eq 0) { return }

    $modelText = Get-Content $ModelPath -Raw
    foreach ($name in $NamesToRemove) {
        $escaped = [regex]::Escape($name)
        $modelText = [regex]::Replace($modelText, "(?im)^ref table (?:'$escaped'|$escaped)\r?\n", "")
    }
    [System.IO.File]::WriteAllText($ModelPath, $modelText, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "  OK model.tmdl: removed ref table line(s)"

    if (Test-Path $RelationshipsPath) {
        $relText = Get-Content $RelationshipsPath -Raw
        $firstRelMatch = [regex]::Match($relText, '(?m)^relationship ')
        $leadingText = if ($firstRelMatch.Success) { $relText.Substring(0, $firstRelMatch.Index) } else { $relText }
        $relBlocks = [regex]::Matches($relText, '(?ms)^relationship .*?(?=^relationship |\z)')
        $keptBlocks = @()
        $droppedCount = 0
        foreach ($rb in $relBlocks) {
            $touches = $false
            foreach ($name in $NamesToRemove) {
                $escaped = [regex]::Escape($name)
                if ([regex]::IsMatch($rb.Value, "(?i)(?:from|to)Column:\s*(?:'$escaped'|$escaped)\.")) { $touches = $true; break }
            }
            if ($touches) { $droppedCount++ } else { $keptBlocks += $rb.Value }
        }
        if ($droppedCount -gt 0) {
            $newRelText = $leadingText + ($keptBlocks -join "")
            [System.IO.File]::WriteAllText($RelationshipsPath, $newRelText, (New-Object System.Text.UTF8Encoding($false)))
            Write-Host "  OK relationships.tmdl: removed $droppedCount relationship(s) touching deleted table(s)"
        }
    }

    Remove-DanglingTranslations -CulturesPath $CulturesPath -Keyword 'table' -NamesToRemove $NamesToRemove -LabelSingular "dangling table translation entry" -LabelPlural "dangling table translation entries"

    foreach ($fp in $FilePaths) {
        Remove-Item -Path $fp -Force
        Write-Host "  OK Deleted $fp"
    }
    Write-Host "  NOTE: diagramLayout.json may still reference deleted table(s) (canvas box position only) - cosmetic, not changed."
}

