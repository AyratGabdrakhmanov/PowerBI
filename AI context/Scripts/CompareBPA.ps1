# BPA (BPARules_ClientA.json, Tabular Editor 2 CLI) on the OPEN model vs a TMDL baseline (a backup taken before the
# change); prints only the NEW violations (and the count of fixed ones). Read-only. Raw TE2 output is ~60k tokens -
# never read it, this script groups it.
#   pwsh -File CompareBPA.ps1 -Port <port> -Baseline "<backup>\X.SemanticModel\definition" [-RenameMap "Old=New;Old2=New2"]
# -RenameMap: tables renamed since the baseline, so their old violations are not reported as new.
# -Report "<...\X.Report>": BPA sees only the model - "Remove unnecessary measures / columns" hits for objects that the
# report uses (visuals, filters, bookmarks: any "Property" in its JSON) are dropped and counted as "used in report".
# Port: QueryOpenModel.ps1 -ListInstances. Rule after every model change: [[bpa-after-model-changes]] (memory).
# SCRIPT_VERSION: 2026-10-25.1
param(
    [Parameter(Mandatory)][int]$Port,
    [Parameter(Mandatory)][string]$Baseline,
    [string]$RenameMap = '',
    [string]$Report = '',
    [string]$Rules = 'C:\Users\ayrat\OneDrive\Документы\ClientA\_Documentation\Context\Rules\BPARules_ClientA.json',
    [string]$TabularEditor = 'C:\Program Files (x86)\Tabular Editor\TabularEditor.exe'
)
Set-StrictMode -Version Latest
[Console]::OutputEncoding = [Text.Encoding]::UTF8
[void][Reflection.Assembly]::LoadFrom("C:\Program Files\DAX Studio\bin\Microsoft.AnalysisServices.Tabular.dll")
$srv = New-Object Microsoft.AnalysisServices.Tabular.Server; $srv.Connect("Data Source=localhost:$Port"); $db = $srv.Databases[0].Name; $srv.Disconnect()
$tmp = Join-Path ([IO.Path]::GetTempPath()) "CompareBPA_$PID"; New-Item -ItemType Directory -Force $tmp | Out-Null
Start-Process $TabularEditor -ArgumentList "`"$Baseline`"", '-A', "`"$Rules`"" -Wait -NoNewWindow -RedirectStandardOutput "$tmp\base.txt"
Start-Process $TabularEditor -ArgumentList "localhost:$Port", "`"$db`"", '-A', "`"$Rules`"" -Wait -NoNewWindow -RedirectStandardOutput "$tmp\live.txt"
function Read-Violations([string]$f) {
    Get-Content $f | Where-Object { $_ -match 'violates rule' } | ForEach-Object { $_ -replace '^.*?(\w[^\r]*violates rule.*)$', '$1' } | Sort-Object -Unique }
$base = Read-Violations "$tmp\base.txt"; $live = Read-Violations "$tmp\live.txt"
foreach ($pair in ($RenameMap -split ';' | Where-Object { $_ })) {
    $o, $n = $pair -split '=', 2; $base = $base | ForEach-Object { $_.Replace("'$o'", "'$n'") } }
$inReport = 0
if ($Report) {
    $used = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    Get-ChildItem $Report -Recurse -Filter *.json | ForEach-Object {
        foreach ($mt in [regex]::Matches((Get-Content $_.FullName -Raw), '"Property":\s*"([^"]+)"')) { [void]$used.Add($mt.Groups[1].Value) } }
    $isUsed = { param($v) $v -match 'violates rule "\[Maintenance\] Remove unnecessary' -and $v -match "\[([^\]]+)\] violates" -and $used.Contains($Matches[1]) }
    $inReport = @($live | Where-Object { & $isUsed $_ }).Count
    $base = @($base | Where-Object { -not (& $isUsed $_) }); $live = @($live | Where-Object { -not (& $isUsed $_) }) }
$new = @($live | Where-Object { $base -notcontains $_ }); $gone = @($base | Where-Object { $live -notcontains $_ })
"baseline: $(@($base).Count)  live: $(@($live).Count)  new: $($new.Count)  fixed: $($gone.Count)" + $(if ($Report) { "  used in report (dropped): $inReport" })
$new | ForEach-Object { "  NEW  $_" }
Remove-Item -Recurse -Force $tmp
