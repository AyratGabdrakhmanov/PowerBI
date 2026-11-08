# Formats Power Query (.pq) M step names:
#  1. Renames auto-generated quoted step names (#"...") to the name of the top-level
#     function they call, e.g. #"Added Custom" = Table.AddColumn(...)  ->  AddColumn = Table.AddColumn(...)
#  2. If the resulting name repeats within the same query, appends a numeric index
#     (AddColumn, AddColumn2, AddColumn3, ...).
#  3. Updates every reference to a renamed step throughout the rest of the query
#     (later steps and the final `in` line) so the chain stays consistent.
#  4. Removes no-op steps - Table.ReorderColumns, and Table.SelectRows(..., each true)
#     (a filter that keeps every row) - and rewires references to each removed step's
#     own input, so the chain skips over it.
#  5. Merges a Table.AddColumn step with an immediately-following
#     Table.TransformColumnTypes step that types only the column just added,
#     into a single Table.AddColumn(..., type) call - only when nothing else
#     references the AddColumn step's output.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File "Format-PowerQuery.ps1" "C:\...\SomeFile.pq"
#   powershell -ExecutionPolicy Bypass -File "Format-PowerQuery.ps1" "C:\...\PowerQuery"   (folder: processes all *.pq)
#
# Limitations: assumes the standard Power BI Desktop-generated flat `let ... in` shape
# (a `let` line, one or more `name = expression,` steps, an `in` line, then the result
# expression). Does not handle a step whose own expression contains a nested `let...in`.
# Review unusual/hand-written queries manually after running.

# Step-name overrides: function -> short name to use instead of the function's own name
# (kept in sync with "Power Query Formatting Rules.md" in this folder).
$script:NameOverrides = @{
    'Table.TransformColumnTypes' = 'Typed'
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
    $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwshCmd) {
        Write-Host "Relaunching under PowerShell 7+ (pwsh)..."
        & $pwshCmd.Source -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath @args
        exit $LASTEXITCODE
    } else {
        Write-Error "PowerShell 7+ (pwsh) is required but was not found. Install it from https://aka.ms/PSWindows and re-run this script."
        exit 1
    }
}

if ($args.Count -lt 1) {
    Write-Error "Usage: Format-PowerQuery.ps1 -Path <file.pq | folder>"
    exit 1
}
$Path = $args[-1]

function Split-TopLevel {
    # Splits $Text on top-level commas (depth 0, outside M string/quoted-identifier literals).
    # Returns an array of trimmed substrings. Depth tracks (), [], {}.
    param([string]$Text)

    $parts = New-Object System.Collections.Generic.List[string]
    $depth = 0
    $inString = $false
    $start = 0
    $chars = $Text.ToCharArray()
    $i = 0
    while ($i -lt $chars.Length) {
        $ch = $chars[$i]
        if ($inString) {
            if ($ch -eq '"') {
                if ($i + 1 -lt $chars.Length -and $chars[$i + 1] -eq '"') {
                    $i++ # escaped "" inside string - skip both
                } else {
                    $inString = $false
                }
            }
        } else {
            switch ($ch) {
                '"' { $inString = $true }
                { $_ -in '(', '[', '{' } { $depth++ }
                { $_ -in ')', ']', '}' } { $depth-- }
                ',' {
                    if ($depth -eq 0) {
                        $parts.Add($Text.Substring($start, $i - $start))
                        $start = $i + 1
                    }
                }
            }
        }
        $i++
    }
    $parts.Add($Text.Substring($start))
    return , @($parts | ForEach-Object { $_.Trim() })
}

function Get-TopLevelCallArgs {
    # Given an expression starting with `Namespace.Func(...)`, returns the top-level
    # (depth-1) comma-separated arguments as an array of trimmed strings, or $null if
    # the expression doesn't start with a recognizable function call.
    param([string]$Expr)

    if ($Expr -notmatch '^\s*[A-Za-z_][A-Za-z0-9_.]*\s*\(') { return $null }
    $openIdx = $Expr.IndexOf('(')
    $depth = 0
    $inString = $false
    $chars = $Expr.ToCharArray()
    for ($i = $openIdx; $i -lt $chars.Length; $i++) {
        $ch = $chars[$i]
        if ($inString) {
            if ($ch -eq '"') {
                if ($i + 1 -lt $chars.Length -and $chars[$i + 1] -eq '"') { $i++ } else { $inString = $false }
            }
            continue
        }
        if ($ch -eq '"') { $inString = $true; continue }
        if ($ch -eq '(') { $depth++; continue }
        if ($ch -eq ')') {
            $depth--
            if ($depth -eq 0) {
                $inner = $Expr.Substring($openIdx + 1, $i - $openIdx - 1)
                return Split-TopLevel $inner
            }
        }
    }
    return $null
}

function Get-CalledFunction {
    # Returns the dotted function name at the start of $Expr (e.g. "Table.AddColumn"),
    # or $null if $Expr isn't a direct function call.
    param([string]$Expr)
    if ($Expr -match '^\s*([A-Za-z_][A-Za-z0-9_.]*)\s*\(') { return $Matches[1] }
    return $null
}

function Get-StepRefPattern {
    # Regex matching references to a step named $NameToken elsewhere in the query.
    # For bare (unquoted) names, excludes a preceding "." (e.g. the "AddColumn" inside
    # "Table.AddColumn(") and a following "(" so a step name never collides with a
    # same-named M function/namespace segment.
    param([string]$NameToken)
    if ($NameToken.StartsWith('#"')) {
        return [regex]::Escape($NameToken)
    }
    return "(?<!\.)\b$([regex]::Escape($NameToken))\b(?!\()"
}

function Format-OnePqFile {
    param([string]$FilePath)

    $raw = Get-Content -LiteralPath $FilePath -Raw -Encoding utf8
    $lines = $raw -split "`r?`n"

    $letIdx = -1
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i].Trim() -eq 'let') { $letIdx = $i; break }
    }
    $inIdx = -1
    for ($i = $lines.Length - 1; $i -gt $letIdx; $i--) {
        if ($lines[$i].Trim() -eq 'in') { $inIdx = $i; break }
    }
    if ($letIdx -eq -1 -or $inIdx -eq -1) {
        Write-Warning "  Skipped (no flat 'let'/'in' block found): $FilePath"
        return
    }

    $preamble = ($lines[0..$letIdx] -join "`n")
    $letBlockText = ($lines[($letIdx + 1)..($inIdx - 1)] -join "`n")
    $inText = ($lines[($inIdx + 1)..($lines.Length - 1)] -join "`n").Trim()

    $rawSteps = Split-TopLevel $letBlockText
    $steps = @()
    foreach ($seg in $rawSteps) {
        if ($seg -match '^(?<name>#"(?:[^"]|"")*"|[A-Za-z_][A-Za-z0-9_]*)\s*=\s*(?<body>[\s\S]*)$') {
            $steps += [PSCustomObject]@{ NameToken = $Matches['name']; Body = $Matches['body'] }
        } else {
            Write-Warning "  Skipped (couldn't parse a step in): $FilePath"
            return
        }
    }

    # --- Pass 0: merge Table.AddColumn + an immediately-following single-column
    #     Table.TransformColumnTypes into one Table.AddColumn(..., type) call ---
    for ($i = 0; $i -lt $steps.Count - 1; $i++) {
        $addStep = $steps[$i]
        $typedStep = $steps[$i + 1]
        if ($null -eq $addStep -or $null -eq $typedStep) { continue }

        if ((Get-CalledFunction $addStep.Body) -ne 'Table.AddColumn') { continue }
        if ((Get-CalledFunction $typedStep.Body) -ne 'Table.TransformColumnTypes') { continue }

        $addArgs = Get-TopLevelCallArgs $addStep.Body
        if (-not $addArgs -or $addArgs.Count -ne 3) { continue } # already typed, or malformed

        $typedArgs = Get-TopLevelCallArgs $typedStep.Body
        if (-not $typedArgs -or $typedArgs.Count -lt 2) { continue }
        if ($typedArgs[0] -ne $addStep.NameToken) { continue } # Typed must consume AddColumn's own output

        $listArg = $typedArgs[1].Trim()
        if ($listArg.Length -lt 2 -or $listArg[0] -ne '{' -or $listArg[-1] -ne '}') { continue }
        $entries = Split-TopLevel $listArg.Substring(1, $listArg.Length - 2)
        if ($entries.Count -ne 1) { continue } # only merge when exactly one column is being typed

        $entry = $entries[0].Trim()
        if ($entry.Length -lt 2 -or $entry[0] -ne '{' -or $entry[-1] -ne '}') { continue }
        $pair = Split-TopLevel $entry.Substring(1, $entry.Length - 2)
        if ($pair.Count -ne 2) { continue }
        $typedColName = $pair[0].Trim()
        $typeExpr = $pair[1].Trim()

        $addColName = $addArgs[1].Trim()
        if ($typedColName -ne $addColName) { continue } # must type the column AddColumn just created

        # AddColumn's output must not be used anywhere else besides this Typed step
        $rxAdd = [regex](Get-StepRefPattern $addStep.NameToken)
        $otherRefs = 0
        foreach ($s in $steps) {
            if ($null -eq $s -or $s -eq $addStep -or $s -eq $typedStep) { continue }
            $otherRefs += $rxAdd.Matches($s.Body).Count
        }
        $otherRefs += $rxAdd.Matches($inText).Count
        if ($otherRefs -gt 0) { continue }

        $addStep.Body = "Table.AddColumn($($addArgs[0]), $($addArgs[1]), $($addArgs[2]), $typeExpr)"

        $rxTyped = [regex](Get-StepRefPattern $typedStep.NameToken)
        $addStepName = $addStep.NameToken
        foreach ($s in $steps) { if ($null -ne $s) { $s.Body = $rxTyped.Replace($s.Body, { param($m) $addStepName }) } }
        $inText = $rxTyped.Replace($inText, { param($m) $addStepName })

        $steps[$i + 1] = $null
    }
    $steps = $steps | Where-Object { $null -ne $_ }

    # --- Pass 1: rename auto-generated quoted step names to their called function ---
    $usedNames = @{}
    $renameMap = @{}
    foreach ($step in $steps) {
        if ($step.NameToken.StartsWith('#"')) {
            $func = Get-CalledFunction $step.Body
            if ($func) {
                $baseName = if ($script:NameOverrides.ContainsKey($func)) { $script:NameOverrides[$func] } else { ($func -split '\.')[-1] }
                if ($baseName -match '^[A-Za-z_][A-Za-z0-9_]*$') {
                    if (-not $usedNames.ContainsKey($baseName)) {
                        $usedNames[$baseName] = 1
                        $newName = $baseName
                    } else {
                        $usedNames[$baseName]++
                        $newName = "$baseName$($usedNames[$baseName])"
                    }
                    $renameMap[$step.NameToken] = $newName
                    $step.NameToken = $newName
                }
            }
        }
    }
    foreach ($old in $renameMap.Keys) {
        $new = $renameMap[$old]
        foreach ($step in $steps) { $step.Body = $step.Body.Replace($old, $new) }
        $inText = $inText.Replace($old, $new)
    }

    # --- Pass 2: drop no-op steps (Table.ReorderColumns; Table.SelectRows(..., each true)),
    #     rewiring references to each removed step's own input ---
    $newSteps = New-Object System.Collections.Generic.List[object]
    foreach ($step in $steps) {
        $func = Get-CalledFunction $step.Body
        $callArgs = Get-TopLevelCallArgs $step.Body
        $isNoOp = $false
        if ($func -eq 'Table.ReorderColumns') {
            $isNoOp = $true
        } elseif ($func -eq 'Table.SelectRows' -and $callArgs -and $callArgs.Count -ge 2 -and $callArgs[1].Trim() -eq 'each true') {
            $isNoOp = $true
        }
        if ($isNoOp) {
            if ($callArgs -and $callArgs.Count -ge 1) {
                $inputRef = $callArgs[0]
                $rx = [regex](Get-StepRefPattern $step.NameToken)
                foreach ($s in $steps) { $s.Body = $rx.Replace($s.Body, { param($m) $inputRef }) }
                $inText = $rx.Replace($inText, { param($m) $inputRef })
            } else {
                Write-Warning "  Couldn't extract input for no-op step '$($step.NameToken)' in $FilePath - leaving step as-is"
                $newSteps.Add($step)
            }
        } else {
            $newSteps.Add($step)
        }
    }

    # --- Rebuild ---
    # Step names from the 3rd step onward are padded so their "=" aligns vertically
    # (the first two steps are typically "Source" and the raw source-table reference,
    # whose names don't belong in that alignment group).
    $alignFrom = 2
    $maxNameLen = 0
    for ($i = $alignFrom; $i -lt $newSteps.Count; $i++) {
        if ($newSteps[$i].NameToken.Length -gt $maxNameLen) { $maxNameLen = $newSteps[$i].NameToken.Length }
    }

    $stepLines = @()
    for ($i = 0; $i -lt $newSteps.Count; $i++) {
        $s = $newSteps[$i]
        $comma = if ($i -lt $newSteps.Count - 1) { ',' } else { '' }
        $name = if ($i -ge $alignFrom) { $s.NameToken.PadRight($maxNameLen) } else { $s.NameToken }
        $stepLines += "    $name = $($s.Body)$comma"
    }

    $output = $preamble + "`n" + ($stepLines -join "`n") + "`nin`n    $inText`n"

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($FilePath, $output, $utf8NoBom)
    Write-Host "Formatted: $FilePath"
}

if (Test-Path -LiteralPath $Path -PathType Container) {
    $files = Get-ChildItem -LiteralPath $Path -Filter '*.pq' -File
    foreach ($f in $files) { Format-OnePqFile $f.FullName }
} elseif (Test-Path -LiteralPath $Path -PathType Leaf) {
    Format-OnePqFile $Path
} else {
    Write-Error "Path not found: $Path"
    exit 1
}
