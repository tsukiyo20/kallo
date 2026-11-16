//! The measured files the model is generated from, as bytes.
//!
//! The `.kalofilm` and `.kalopaper` files are the model: a build of
//! `kallo-core` reads them and writes the stock tables from them, so the
//! program text holds no measurements. They are also why this crate exists:
//! `kallo-core` used to read the repository's `data/` directory directly, and a
//! crate built away from the repository has no such directory. This crate
//! carries the same files beside the code, and the build reads them from here,
//! so a packaged build is enough on its own.
//!
//! # Licence
//!
//! The files are **CC BY-SA 4.0**, not the program licence, because the
//! digitisation is a work of its own: every curve in them was read from a
//! manufacturer's data sheet and shares the terms that keep it open. The
//! boundary is a file read: nothing measured is compiled into program text, and
//! the renderer stays GPL-3.0-or-later. The full text is in `LICENSE`, and what
//! is not redistributed, with the trademarks, is in `NOTICE.md`.
//!
//! # Where the files come from
//!
//! They are a copy of the repository's `data/` directory, made with
//! `just sync-data`. The test below compares the copy with the originals when
//! the repository is present; away from the repository the copy is the only
//! data there is.

/// One measured file: the stock's id and the file itself.
pub struct Source {
    /// The stock's id: the directory name for a film, the file stem for a paper.
    pub name: &'static str,
    /// The file, byte for byte: a `.kalofilm` or a `.kalopaper`.
    pub bytes: &'static [u8],
}

include!(concat!(env!("OUT_DIR"), "/sources.rs"));

#[cfg(test)]
mod tests {
    use super::{FILMS, PAPERS};
    use std::fs;
    use std::path::{Path, PathBuf};

    /// The repository's `data/` directory, when there is a repository around
    /// the crate. A packaged crate has none.
    fn repository_data() -> Option<PathBuf> {
        let data = Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("..")
            .join("..")
            .join("data");
        data.is_dir().then_some(data)
    }

    #[test]
    fn the_films_match_the_repository() {
        let Some(data) = repository_data() else {
            return;
        };
        let directory = data.join("films");
        let mut in_repository = 0;
        for entry in fs::read_dir(&directory).expect("data/films").flatten() {
            let film = entry
                .path()
                .join(format!("{}.kalofilm", entry.file_name().to_string_lossy()));
            if film.is_file() {
                in_repository += 1;
            }
        }
        assert_eq!(
            in_repository,
            FILMS.len(),
            "the crate and {} hold a different number of films",
            directory.display()
        );
        for source in FILMS {
            let path = directory
                .join(source.name)
                .join(format!("{}.kalofilm", source.name));
            let bytes = fs::read(&path).expect("a film in the repository");
            assert_eq!(
                bytes,
                source.bytes,
                "{} drifted from its copy — run `just sync-data`",
                path.display()
            );
        }
    }

    #[test]
    fn the_papers_match_the_repository() {
        let Some(data) = repository_data() else {
            return;
        };
        let directory = data.join("papers");
        let mut in_repository = 0;
        for entry in fs::read_dir(&directory).expect("data/papers").flatten() {
            let path = entry.path();
            if path
                .extension()
                .is_some_and(|extension| extension == "kalopaper")
            {
                in_repository += 1;
            }
        }
        assert_eq!(
            in_repository,
            PAPERS.len(),
            "the crate and {} hold a different number of papers",
            directory.display()
        );
        for source in PAPERS {
            let path = directory.join(format!("{}.kalopaper", source.name));
            let bytes = fs::read(&path).expect("a paper in the repository");
            assert_eq!(
                bytes,
                source.bytes,
                "{} drifted from its copy — run `just sync-data`",
                path.display()
            );
        }
    }

    #[test]
    fn the_licence_copies_match_the_repository() {
        let Some(data) = repository_data() else {
            return;
        };
        let crate_root = Path::new(env!("CARGO_MANIFEST_DIR"));
        for name in ["LICENSE", "NOTICE.md"] {
            let original = fs::read(data.join("films").join(name)).expect("the data licence");
            let copy = fs::read(crate_root.join(name)).expect("the crate's copy");
            assert_eq!(
                original, copy,
                "{name} drifted from its copy — run `just sync-data`"
            );
        }
    }
}
