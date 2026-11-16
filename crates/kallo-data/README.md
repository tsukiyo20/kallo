# kallo-data

The `.kalofilm` and `.kalopaper` files behind the model, as bytes.

`kallo-core`'s build script reads them from this crate to generate the stock
tables. They are a copy of the repository's
[`data/`](https://github.com/tsukiyo20/kallo/blob/main/data/README.md)
directory: the program text stays GPL-3.0-or-later and the measurements stay
CC BY-SA 4.0, with the boundary at a file read — the same boundary as in a
checkout, kept in a crate so the build reads the measurements through it.

The copy is made with `just sync-data` and compared with the originals by this
crate's tests; do not edit it by hand. Like the rest of the workspace, this
crate is not published to crates.io: it ships in this repository. The licence is
CC BY-SA 4.0 — the full text is in [`LICENSE`](LICENSE), and what is not
redistributed, with the trademarks, is in [`NOTICE.md`](NOTICE.md).
