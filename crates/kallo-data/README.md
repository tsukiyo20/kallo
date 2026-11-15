# kallo-data

The `.kalofilm` and `.kalopaper` files behind the model, as bytes.

`kallo-core`'s build script reads them from this crate to generate the stock
tables. They are a copy of the repository's
[`data/`](https://github.com/tsukiyo20/kallo/blob/main/data/README.md)
directory: the program text stays MIT OR Apache-2.0 and the measurements stay
CC BY-SA 4.0, with the boundary at a file read — the same boundary as in a
checkout, moved into a crate so that `kallo-core` can be built from crates.io.

The copy is made with `just sync-data` and compared with the originals by this
crate's tests; do not edit it by hand. The licence is CC BY-SA 4.0 — the full
text is in [`LICENSE`](LICENSE), and what is not redistributed, with the
trademarks, is in [`NOTICE.md`](NOTICE.md).
