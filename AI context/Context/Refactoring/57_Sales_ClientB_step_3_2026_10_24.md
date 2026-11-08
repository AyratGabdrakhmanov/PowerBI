Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## Sales_ClientB — step 3 (2026-10-24)

`DynamicSelected_CurrencyType` → `CT_CurrencyType`, `DynamicSelected_Measure` → `CT_MeasureType`,
`DynamicSelected_Open/All` → `CT_OpenAll`, `Top N` → `CT_TopN`, `Period` → `CT_Period`, `Rate` → `CT_Rate`,
`Target` → `CT_Target`. `Aggregate` (only 10 measures, data unused) → measures moved to `_Measures` (hidden, as
before), table deleted. `CT_Language` hidden. `FP_*` already compliant. Values equal before / after; 0 missing report
fields. Backup `ClientB\BackUp\CT_Naming_2026-10-24_205801`.
