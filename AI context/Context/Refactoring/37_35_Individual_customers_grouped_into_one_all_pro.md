Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 35. Individual customers grouped into one (all projects, user 2026-11-01)

**Client decision first** — never applied without it (customer allocation changes only after client confirmation). Ask: are individual
(private, not legal-entity) customers really needed one by one in the reports? Suggest grouping them into one customer, to
cut the rows and make the refresh faster — important with the 8 refreshes a day (Power Loader schedule, step 11).
- **Facts for the question:** customers in total / legal entities / individuals; their share of sales and of fact rows;
  pages, slicers and top-N lists where individual names show today; current refresh time (Power Loader task + Service).
  How an individual is recognised comes from the client (customer group such as ClientC 100 `לקוחות - כללי` (Customers –
  general), a SAP flag / UDF, or the tax-ID type) — never guessed.
- **Grouping keeps the allocation:** one row per company + customer group (+ area agent where the agent is per customer),
  e.g. `לקוחות פרטיים – <group>` (Private customers – <group>), so area / agent / team / target numbers do not change.
  Done in SQL: `ETL_MD_Customers*` returns the grouped row, the fact SQL maps the individuals' `BP_Key` to it. Fact lines
  are aggregated (date × item × document type × grouped customer) only if the client also drops document-level detail
  for them.
- **Verify:** totals by company / group / area / agent / family / month equal before and after; customer row count, fact
  row count, model size and refresh time before / after (record in the project context file).
