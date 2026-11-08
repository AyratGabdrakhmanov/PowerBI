# DAX Contracts

Source: Marco Russo and Alberto Ferrari, SQLBI, *Understanding DAX contracts
when using AI* (October 5, 2026) —
https://www.sqlbi.com/articles/understanding-dax-contracts-when-using-ai/

## What a contract is

A contract is "a text that identifies the rules at work in a specific
semantic model" — documentation of how calculations are performed in one
model.

- **Not an algorithm.** A contract is not limited to one algorithm; it can
  cover several measures and algorithms at once.
- **Not a model description.** It does not describe entities and
  relationships in general. It sits between the two: it documents
  calculation behavior.
- **Business language.** It avoids obvious statements and defines the rules
  for computing values over the data — who is included, which filters apply
  or are ignored, ordering and ties, blanks, how results are displayed.
- **More important than the code.** "The measure is not the most important
  part of the work" — when coding with an AI assistant, defining the contract
  is the most important task. The DAX follows from it.

## Why it matters

The article describes three eras of BI:

- **Traditional BI** — long meetings to define calculations; documentation
  was written but rarely read or kept current, so the logic ended up hidden
  in DAX/MDX and SQL.
- **Self-service BI** — users became developers, and business logic was again
  buried in measures and transformations.
- **AI era** — users prompt AI agents to write the code. Agents, unlike
  people, are good at reading and maintaining documentation, so contracts can
  keep the logic visible and current.

Benefits listed by the authors:

1. Concise documentation that can be read without the DAX code and shared
   with people and AI.
2. A precise specification for the agent to implement.
3. Easier future changes: edit the contract first, then have the agent update
   the measure.

## Workflow

The article's example is a customer ranking. The wrong approach is to prompt
"Create a measure to compute the ranking of a customer" directly. The right
approach is to start with the contract:

1. **Questions first.** Ask the agent what must be answered before writing
   the measure (in the example: who competes in the ranking, which filters
   apply, ranking direction, ties, which customers qualify, how customers are
   identified, where the measure appears).
2. **Save the contract.** Give the answers and rules; the agent saves them to
   a contract file and flags unresolved points.
3. **Resolve open issues.** Add rules for the unresolved points and update the
   contract.
4. **Review the contract.** Ask the agent to show the contract it actually
   saved — its wording may differ from yours (in the article it was clearer).
5. **Generate the measure last.** Only then ask for the DAX, which follows the
   contract. The result still has to be validated before production (the
   authors call their own measure "far from perfect").
6. **Change through the contract.** When behavior must change, edit the
   contract first, then update the code from it.

The example contract has four sections: *Customer cohort*, *Filter
behavior*, *Ranking and ties*, *Customer identity and display*.

Conclusions: create a contract before any measure, however simple. Contracts
can be simple or complex, but they compactly store how values are computed
and any calculation quirks. The authors call them "the new first-class
citizens in the BI world".

## Our contract template

The article has no fixed template; we use fixed sections so contracts look
the same. **Contracts are written in English** (Hebrew only for data values,
each with its English translation).

- **Two languages** (user, 2026-10-30): every contract has an English file and a client-language copy
  (`<ID>_<Topic>_HE.md`, RTL) with the same sections; the client gets the client-language one.
- **ID / project / status** — `Draft` (open questions) → `Agreed` (approved
  by the user) → `Implemented` (code applied and verified).
- **Goal** — what changes and why.
- **Names** — every Hebrew value with its English translation.
- **Objects** — columns / measures / tables created or changed, and what is
  **not** changed.
- **Rules** — numbered `R1…`, in priority order.
- **Implementation** — the DAX, with an English comment for each Hebrew
  literal.
- **Invariants** — what must always hold (checkable by a query).
- **Check** — the query result on current data, before / after.
- **Open questions** — `Q1…` (ours) and questions for the client, with the
  answer once decided.
- **History** — date and what changed.

## Contracts and Azure DevOps tasks (user, 2026-10-16)

"Contract = Azure task": a work item is implemented through this workflow, contract ID =
task number (`C-CA-49` ↔ #49). On finishing the task or on new comments — update the
contract, then the task Description with the contract's data (rules in
`Azure_DevOps.md`).

## Where contracts live

Each contract is a separate file `<ID>_<Short_name>.md` in the `Contracts\`
folder **of its own project** (ClientB — `Agency\ClientB\Contracts\`). ID format:
`C-<PROJECT>-<NN>`, numbered within the project. The project's open
questions file for the client is in the same folder. This folder keeps only
the definition, the template and the overall list. New contract → new file
in the project folder + a row in the list below.

| ID | Project | Topic | Status | File |
|---|---|---|---|---|
| C-ClientB-01 | ClientB | Beauty Department subgroups in `CardGroup Subcategory` (formerly `CardName2`) | Implemented | [C-ClientB-01_Beauty_Subgroups.md](../../../../../Agency/ClientB/Contracts/C-ClientB-01_Beauty_Subgroups.md) |
| C-ClientB-02 | ClientB | Target Achievement MTD % — actual MTD / monthly target | Implemented (2026-10-13) | [C-ClientB-02_Target_Achievement.md](../../../../../Agency/ClientB/Contracts/C-ClientB-02_Target_Achievement.md) |
| C-ClientB-03 | ClientB | B2B segment subgroups by card properties 54/55/15 in `CardGroup Subcategory` | Implemented | [C-ClientB-03_B2B_Subgroups.md](../../../../../Agency/ClientB/Contracts/C-ClientB-03_B2B_Subgroups.md) |
| C-ClientB-04 | ClientB | Miscellaneous customers → subgroup of Trade – private stores | Implemented | [C-ClientB-04_Misc_To_Private_Stores.md](../../../../../Agency/ClientB/Contracts/C-ClientB-04_Misc_To_Private_Stores.md) |
| C-ClientB-05 | ClientB | Spare parts & service → Brand stores (priority); External labs subgroups | Agreed (SQL (7) not deployed) | [C-ClientB-05_Spare_Parts_To_Brand_Stores.md](../../../../../Agency/ClientB/Contracts/C-ClientB-05_Spare_Parts_To_Brand_Stores.md) |
| C-ClientB-06 | ClientB | Inventory Coverage report — stock, availability, 2-month sales, coverage, stock value waterfall; warnings W1–W4 | Implemented (2026-10-30), client Q1/Q3/Q4 open | [C-ClientB-06_Inventory_Coverage.md](../../../../../Agency/ClientB/Contracts/C-ClientB-06_Inventory_Coverage.md) |
| C-CA-49 | Collector Assignment | Ending Balance by DPD (10–31) by date, page DPD by Date (Azure #49) | Implemented (2026-10-16) | [C-CA-49_DPD_By_Date.md](../../../../Semantic%20Model/Contracts/C-CA-49_DPD_By_Date.md) |
| C-CA-37 | PAC model | Buyback (BB) activity table + was cancelling buybacks a good idea (Azure #37) | Draft (2026-11-03) | [C-CA-37_Buyback_Activity.md](../../../../Model/Contracts/C-CA-37_Buyback_Activity.md) |

ClientB open questions for the client (English + Hebrew) —
[ClientB_Open_Questions.md](../../../../../Agency/ClientB/Contracts/ClientB_Open_Questions.md).
Add each new ClientB question there in both languages.
