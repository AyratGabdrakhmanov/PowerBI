Part of [AI_Tools_MCP_CLI.md](../AI_Tools_MCP_CLI.md) (split 2026-11-06).

## Not installed — for reference

| Tool | What | Why not installed |
|---|---|---|
| **SemanticOps MCP** (Maxim Anatsko), <https://github.com/maxanatsko/mcp-engine-public>, v3.9.119 | 16 tools on the live model (Desktop/XMLA); rollback, tests, impact analysis — in Pro ($349/year) | No offline PBIP, no report, no BPA; closed source; the free part ≈ MS MCP |
| **MS skills-for-fabric `powerbi-authoring`**, <https://github.com/microsoft/skills-for-fabric> | Skills for editing PBIR + MS MCP + Bridge | Preview; installed as a Copilot CLI plugin (compatible with Claude Code) — candidate for later |
| **data-goblin `power-bi-agentic-development`** (Kurt Buhler), <https://github.com/data-goblin/power-bi-agentic-development> | Claude Code plugins on top of `te`/`fab`/`pbir` (model, PBIR, Fabric) | GPL-3.0, weekly breaking changes; candidate for later |
| **Tabular Editor 3 MCP + AI Assistant** | The most mature engine (C# scripts, BPA, VertiPaq, undo, permissions) | Paid TE3 |
| **MinaSaad1 `pbi-cli`**, <https://github.com/MinaSaad1/pbi-cli> | Python CLI: TOM against Desktop + PBIR editing | Overlaps with MS MCP + pbir |
| **sulaiman013 `powerbi-mcp`**, <https://github.com/sulaiman013/powerbi-mcp> | 82 tools: Desktop, XMLA, PBIP, PBIR | Single author, no releases |
| **Fabric CLI `fab`** (`pip install ms-fabric-cli`) | Export/import/deploy of TMDL and reports, refresh via API | Needed for deployment/CI in Fabric — not used yet |
| **Remote MCP / Fabric IQ MCP** (MS) | DAX queries against published models, read-only | We work with local PBIPs |
| **SQLBI DAX Formatter MCP**, `https://api.daxformatter.com/mcp` | DAX formatting/validation, free | Can be connected if needed (HTTP, no key) |
