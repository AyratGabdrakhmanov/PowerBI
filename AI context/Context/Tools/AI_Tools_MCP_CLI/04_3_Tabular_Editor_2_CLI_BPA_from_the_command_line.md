Part of [AI_Tools_MCP_CLI.md](../AI_Tools_MCP_CLI.md) (split 2026-11-06).

## 3. Tabular Editor 2 CLI — BPA from the command line

- Already installed: `C:\Program Files (x86)\Tabular Editor\TabularEditor.exe`
  **2.29.0** (free, MIT). The CLI is built into the same exe.
- BPA against our rules (read-only, does not change the model):
  ```powershell
  $te = 'C:\Program Files (x86)\Tabular Editor\TabularEditor.exe'
  $p = Start-Process $te -ArgumentList '"<…>.SemanticModel\definition"','-A','"<…>\BPARules_ClientA.json"' `
       -Wait -PassThru -NoNewWindow -RedirectStandardOutput bpa.txt
  $p.ExitCode   # 1 = violations found
  ```
  Output: `Column 'T'[C] violates rule "..."` — one line per violation.
  Verified on `ClientA\Model\Model_v2.SemanticModel` — ~2,940 violation lines
  (raw, not yet analyzed).
- Without `-RedirectStandardOutput` the output does not reach the console (GUI exe).
- The new cross-platform **`te` CLI** (Tabular Editor, preview until
  2026-11-30, requires a TE account) — not installed: does the same + model diff,
  BPA with auto-fix, DAX queries; licensing after GA is unknown.
