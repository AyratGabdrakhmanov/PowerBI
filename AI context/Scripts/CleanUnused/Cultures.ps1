# CleanUnused\Cultures.ps1 - part of CleanUnused.ps1, dot-sourced by it (same scope: shares its variables).
# Remove-OrphanTranslations (final sweep, called by CleanUnused.ps1). Step Q (Q&A linguisticMetadata) removed
# 2026-11-03: Desktop regenerates that data on every save, so it is left as is (user).
# Not runnable on its own. No `exit` here: an exit in a dot-sourced file does not stop CleanUnused.ps1.

# ---------------------------------------------------------------------------
# (2026-11-01) Safety net: a `translations` entry (table / column / measure / hierarchy / level) whose object is no
# longer in the model stops Desktop from opening the PBIP ("Property Object of object 'Translation in culture …'
# refers to an object which cannot be found" - ClientF Sales v2). Every pass ends with a sweep over all cultures.
function Remove-OrphanTranslations {
    $model = @{}
    foreach ($tf in (Get-ChildItem -Path $tablesPath -Filter "*.tmdl" -File)) {
        $s = [System.IO.File]::ReadAllText($tf.FullName) -replace "`r", ""
        $tn = ([regex]::Match($s, "(?m)^table (.+)")).Groups[1].Value.Trim().Trim("'")   # (?m): /// description lines may come first
        $o = @{ column = [System.Collections.Generic.HashSet[string]]::new(); measure = [System.Collections.Generic.HashSet[string]]::new(); hierarchy = @{} }
        foreach ($m in [regex]::Matches($s, "(?m)^\t(column|measure) ('[^']*(?:''[^']*)*'|[^\s=\n]+)")) { [void]$o[$m.Groups[1].Value].Add($m.Groups[2].Value.Trim("'").Replace("''", "'")) }
        foreach ($h in [regex]::Matches($s, "(?ms)^\thierarchy ([^\n]+)\n(.*?)(?=^\t[a-z]|\z)")) {
            $lv = [System.Collections.Generic.HashSet[string]]::new()
            foreach ($l in [regex]::Matches($h.Groups[2].Value, "(?m)^\t\tlevel ([^\n]+)")) { [void]$lv.Add($l.Groups[1].Value.Trim().Trim("'")) }
            $o.hierarchy[$h.Groups[1].Value.Trim().Trim("'")] = $lv
        }
        $model[$tn] = $o
    }
    $total = 0
    foreach ($cf in (Get-ChildItem -Path $culturesPath -Filter "*.tmdl" -File -ErrorAction SilentlyContinue)) {
        $text = [System.IO.File]::ReadAllText($cf.FullName)
        $splitIdx = $text.IndexOf("`tlinguisticMetadata")
        $header = if ($splitIdx -ge 0) { $text.Substring(0, $splitIdx) } else { $text }
        $rest = if ($splitIdx -ge 0) { $text.Substring($splitIdx) } else { "" }
        $lines = $header -split "(?<=\n)"; $sb = New-Object System.Text.StringBuilder; $skip = -1; $t = $null; $h = $null; $dropped = @()
        foreach ($ln in $lines) {
            $body = $ln.TrimEnd("`r", "`n"); $ind = $body.Length - $body.TrimStart("`t").Length
            if ($skip -ge 0) { if ($body.Trim() -eq '' -or $ind -gt $skip) { continue }; $skip = -1 }
            $m = [regex]::Match($body.Trim(), "^(table|column|measure|hierarchy|level) (.+)$")
            if ($m.Success -and $ind -ge 3) {
                $k = $m.Groups[1].Value; $n = $m.Groups[2].Value.Trim().Trim("'").Replace("''", "'"); $ok = $true
                if ($k -eq 'table' -and $ind -eq 3) { $t = $n; $ok = $model.ContainsKey($n) }
                elseif ($k -in 'column', 'measure' -and $ind -eq 4) { $ok = $model.ContainsKey($t) -and $model[$t][$k].Contains($n) }
                elseif ($k -eq 'hierarchy' -and $ind -eq 4) { $h = $n; $ok = $model.ContainsKey($t) -and $model[$t].hierarchy.ContainsKey($n) }
                elseif ($k -eq 'level' -and $ind -eq 5) { $ok = $model.ContainsKey($t) -and $model[$t].hierarchy.ContainsKey($h) -and $model[$t].hierarchy[$h].Contains($n) }
                if (-not $ok) { $dropped += "$k $t$(if ($k -ne 'table') { "[$n]" })"; $skip = $ind; continue }
            }
            [void]$sb.Append($ln)
        }
        if ($dropped.Count -eq 0) { continue }
        $newText = $sb.ToString() + $rest
        if (Test-TmdlIntegrity -Text $newText -FilePath $cf.FullName) {
            [System.IO.File]::WriteAllText($cf.FullName, $newText, (New-Object System.Text.UTF8Encoding($false)))
            Write-Host "  OK $($cf.Name): removed $($dropped.Count) orphan translation(s): $($dropped -join '; ')"
            $total += $dropped.Count
        } else {
            Write-Host "  ERROR $($cf.Name): $($dropped.Count) orphan translation(s) NOT removed (integrity check) - Desktop will not open the PBIP" -ForegroundColor Red
        }
    }
    Write-Host "  Orphan translations removed: $total"
}
