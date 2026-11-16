# data

Everything the renderer is built from, and nothing it is not: two kinds of
measured stock, each in the file format its own sheet produced.

| directory | what is in it |
|---|---|
| [`films/`](films/) | the published series — twenty-four films, each a directory with its `.kalofilm`, its report, its digitised points and its figures. Start at [`films/README.md`](films/README.md). |
| [`papers/`](papers/) | six measured papers, one `.kalopaper` each. [`papers/README.md`](papers/README.md) says which and why. |

The program holds none of these numbers. `kallo-core`'s build script reads the
`.kalofilm` and `.kalopaper` files at build time and generates the stock tables
from them, so the program text is GPL-3.0-or-later and this directory is
CC BY-SA 4.0, with the boundary at a file read rather than at a comment.
`crates/kallo-data` carries a copy of these files so the build reads them from a
crate of their own; `just sync-data` refreshes it, and its tests fail when the
copy and this directory disagree.

Both formats are specified in [`films/FORMAT.md`](films/FORMAT.md), which also
documents the TOML source file a stock is authored in and the four things
`kalo stock check` refuses. No image of a data sheet is reproduced here: the
sheets stay with their publishers, and each file names the publication, the page
and the SHA-256 of the document its numbers were read from.

The data is **CC BY-SA 4.0** — use it for anything, including commercially,
provided the adaptation is shared under the same terms. The full text is in
[`films/LICENSE`](films/LICENSE); what is not redistributed, and the trademarks,
are in [`films/NOTICE.md`](films/NOTICE.md).
