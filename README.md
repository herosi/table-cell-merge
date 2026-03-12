# Table-cell-merge Extension For Quarto

A Quarto filter extension that enables `colspan` and `rowspan` in Markdown tables.


## Installing

```bash
quarto add herosi/table-cell-merge
```

This will install the extension under the `_extensions` subdirectory.
If you're using version control, you will want to check in this directory.


## Using

1. Add the following line to your `.qmd` file or `_quarto.yaml` to enable the extension.
   ```yaml
   filters:
     - { at: post-quarto, path: table-cell-merge }
   ```

   **Note**: The extension must be loaded using the format shown above. Otherwise, it will not work with `tbl-colwidths`.

2. Add a line like the following after the table.
   ```json
   : {tbl-merge="[1:2:col:2, 2:1:row:3]"}
   ```

- `tbl-merge` format: 
  ```
  [row:col:direction:span, ...]
  ```

| Key       | Value                                                         |
| :-------- | :------------------------------------------------------------ |
| row       | **1-based** row index (**header rows first**, then body rows) |
| col       | **1-based** column index                                         |
| direction | `col` (`colspan`) or `row` (`rowspan`)                                |
| span      | number of cells to merge (>= 2)                               |


## Notes

- The contents of merged cells are ignored; only the content of the leading cell is preserved.
- When `colspan` and `rowspan` are specified together, the cells are merged into a rectangular region (following the HTML `colspan`/`rowspan` behavior).


## Example

Here is the source code for a minimal example: [example.qmd](example.qmd). View an example presentation at [example.html](https://herosi.github.io/table-cell-merge/demo/example.html).


