Project: SAP Business One + TSQL + Power BI

Formatting rules for Power Query (M) steps, applied by the script
`Format-PowerQuery.ps1` (located in this same folder):

- Auto-generated quoted step names (`#"Added Custom"`) are replaced
  with the name of the applied function without the namespace, e.g.
  `Table.AddColumn` -> `AddColumn`.
- If the function name is already used in this query - a numeric
  index is added: `AddColumn`, `AddColumn2`, `AddColumn3`, ...
- All references to the renamed step throughout the query (subsequent steps and
  the final `in`) are updated accordingly.
- A step with the `Table.ReorderColumns` function is removed (it does not change the data), references
  to it are redirected to its input.
- A `Table.SelectRows(..., each true)` step is removed (a filter that lets through
  all rows - is meaningless), references to it are redirected to its input.
- Steps whose name is already meaningful (unquoted, e.g. `Source`) - are
  left alone.
- A `Table.AddColumn` immediately followed by a `Table.TransformColumnTypes`
  that types exactly the column that was just added - are merged
  into a single `Table.AddColumn(..., type)` (the 4th argument). The merge happens
  only if the result of `AddColumn` is not used anywhere else except this
  `TransformColumnTypes`.

Exceptions to "name = function name" (short names instead of the full
function name):

| Function                      | Step name |
|-------------------------------|-----------|
| `Table.TransformColumnTypes`  | `Typed`   |

Keep the exceptions list up to date both in this file and in
`$script:NameOverrides` in `Format-PowerQuery.ps1`.

## File naming

If a PQ query has no transformation steps (only `Source` and a direct
reference to a SQL table/view, without a single `Table.*`/`Text.*`/... call) -
the suffix `_clean` is added to the file name, e.g. `Items_clean.pq`. This
is a one-off naming rule - it is not yet automated in the `Format-PowerQuery.ps1` script
(the script itself does not rename files).
