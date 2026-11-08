Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## Sales_ClientB — step 5 (2026-10-24)

Currency: 18 money columns (`DocsSales` SalesVal…, `DocsPurchs` PurchVal…, `Supplier` Balance / CreditLine / DebtLine,
`Items` Price22 / Price67) + `VatX`, `VatPrecent`, `DiscountPrcnt`, `CommissionRate`, `LIneFactor`, `CT_Rate[Rate]`.
Whole number: `DocsSales` / `DocsPurchs` Quantity, OpenQty, `DocumentTypes[Custom]`. Date: `DocsPurchs` DocDate /
TaxDate / DueDate, `Supplier[CardCreatedate]`, `CT_Target[Month]` (`Date Last Refreshed` stays Date/time). Rows equal;
sums move by 4-decimal rounding only (sales total 0.0006 of 92.6M); measures ≤ 1e-10 relative. Backup
`ClientB\BackUp\DataTypes_2026-10-24_223113`.
