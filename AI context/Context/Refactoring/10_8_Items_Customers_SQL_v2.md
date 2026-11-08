Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 8. Items / Customers SQL v2

Company dimension (all clients, user 2026-10-27): `Companies` from `ETL_MD_CompanyWithCurr` (`CompanyID` → fact `CompanyID`, `CompanyName`, `Local` / `System` currency codes for the currency selector) — reference: Sales Channels `Companies` + `CT_Currency[Selected Currency]`.

Supplier dimension (all clients, 2026-10-26): `PROD\ETL_MD_Suppliers.sql` (OCRD `CardType = S`: `BP_Key`, `CardCode`, `CardName`, `CodeNameBP`) — the model `Supplier` loads it instead of the full `ETL_MD_BP`.

Dimensions on `PROD\ETL_MD_Items.sql` / `ETL_MD_Customers*.sql` (ClientB: `ETL_MD_Items_ClientB`, `ETL_MD_Customers`),
same switch pattern as step 7.
