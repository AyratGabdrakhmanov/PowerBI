Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 7. Sales SQL on `ETL_SA_Sales` (ClientB + ClientC, user 2026-10-26)

`Power Loader\PROD\ETL_SA_Sales.sql` (all row logic in SQL, only the columns the model uses — ClientC set of
2026-10-26: 24 columns, `DocFatherCard` and `VatX` (bare `[VatX]` in `Val_PayNoVat_*` — a scan for `T[Col]` misses
bare refs) kept, `Project_KEY` / `QuantityOpen` commented; still missing for ClientC: `Doc_ItemCode` / `Doc_ItemName` /
`Doc_BPCode` / `Doc_BPName` (41–51 visuals each). 26.10: codes repointed to `Customers` / `Items` (identical); **names stay
as on the document** (user: as at the beginning) → v3 must also output `Doc_BPName` / `Doc_ItemName` (ClientB SQL has them).
`ETL_MD_Customers.sql` for ClientC must output `GroupCode` (area allocation), `CardSlpName`, `CodeNameBP`;
`ETL_MD_Items.sql` `CodeGroup`, `PriceList` — coverage check `Refactoring\ClientC\prod_coverage.py`).
**ClientC SQL readiness (26.10):** `ETL_SA_Sales.sql` covers all 26 used `DocsSales` columns (`Doc_BPName` =
`DocHeader.CardName`, `Doc_ItemName` = `DocLines.Dscription`, as the deployed standard query); `ETL_MD_Customers.sql`
complete (`CodeNameBP` uncommented, `GroupCode` added; ⚠️ it casts `CardCode` to int — check non-numeric ClientC codes in
the reconciliation); items: **`PROD\ClientC\ETL_MD_Items_ClientC.sql`** = ClientC's deployed query (`Repo\ETL_MD_Items_ClientC.txt`) in the SQL
rules, same 20 output names; ClientC rule `PriceList` = SAP price list 1, item groups 114 / 116 `/ 0.7` (behind
`AvgDidcounts`, 62 visuals) — kept out of the shared `ETL_MD_Items.sql`. `ItemProperties_v2`
outputs `GroupName` → rename to `ItmsGrpNam` in ClientC's M at the switch. `Targets_v2` fits `TargetFamily` only
(daily target / working days would move to DAX); area `Targets` keep their current source.. Deployed as a **new** table
next to the old one; reconcile old vs new (totals by month / document type / agent, one agent-month line by line vs
SAP); then `DocsSales` M = navigation + one typing step. Customer / item names from the dimensions, not `Doc_*`.
