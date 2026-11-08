Part of [PBIP_Pages_Visuals.md](../PBIP_Pages_Visuals.md) (split 2026-11-06).

## Core structure of a PBIP project

```
Model_v2.pbip
├── Model_v2.Report/
│   ├── definition/
│   │   ├── report.json (report config)
│   │   ├── version.json (version)
│   │   └── pages/
│   │       ├── pages.json ⭐ MAIN FILE (order and landing page)
│   │       ├── SalesYTD/ (page folder, NO SPACES)
│   │       │   ├── page.json ⭐ PAGE SETTINGS
│   │       │   └── visuals/ (visualizations)
│   │       ├── CA_DQ/
│   │       └── ... (other pages)
│   └── .pbi/
│       └── localSettings.json (local Power BI cache)
└── Model_v2.SemanticModel/ (data and measures)
```
