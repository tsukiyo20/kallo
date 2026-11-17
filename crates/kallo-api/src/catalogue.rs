//! The catalogue: what is compiled in, as a document a program can read.
//!
//! The catalogue is the model's own list of stocks, read from the same files the
//! renderer uses. Since the measured table became structured it also carries
//! what each field admits to — the verdict, the sentence, and the controls a
//! recipe may move — plus the digest of the packed file the stock was read
//! from, which is what a recipe is bound to.

use kallo_core::{
    FILM_STOCKS, FilmProcess, FilmStock, MeasuredField, MeasuredState, PAPER_STOCKS, PaperEmulsion,
    PaperStock, Provenance,
};
use serde_json::{Map, Value, json};

/// Every stock, as a document a program can read.
///
/// The same data the renderer uses, produced by the same build from the same
/// files: a shelf that showed a film the model did not have would be an
/// interface lying about its own model, and a catalogue generated separately
/// would be that lie with a schema.
#[must_use]
pub fn value() -> Value {
    json!({
        "schema": "kallo/catalogue/2",
        "films": FILM_STOCKS.iter().map(film).collect::<Vec<Value>>(),
        "papers": PAPER_STOCKS.iter().map(paper).collect::<Vec<Value>>(),
        "model": model(),
    })
}

fn film(stock: &FilmStock) -> Value {
    json!({
        "id": stock.id,
        "short": stock.short,
        "label": stock.label,
        "process": process(stock.process),
        "note": stock.note,
        "reference": {
            "minutes": stock.reference_time_min,
            "temp_c": stock.reference_temp_c,
        },
        "provenance": provenance(&stock.provenance),
        "stock_digest": stock.digest,
        "measured": measured(stock.measured),
    })
}

fn paper(stock: &PaperStock) -> Value {
    json!({
        "id": stock.id,
        "short": stock.short,
        "label": stock.label,
        // What the paper carries, in the word the app groups the shelf by.
        "emulsion": match stock.emulsion {
            PaperEmulsion::Colour => "colour",
            PaperEmulsion::Silver => "silver",
        },
        "note": stock.note,
        "provenance": provenance(&stock.provenance),
        "stock_digest": stock.digest,
        "measured": measured(stock.measured),
    })
}

fn process(process: FilmProcess) -> &'static str {
    match process {
        FilmProcess::Negative => "negative",
        FilmProcess::Reversal => "reversal",
        FilmProcess::Monochrome => "monochrome",
    }
}

fn provenance(provenance: &Provenance) -> Value {
    json!({
        "publication": provenance.publication,
        "page": provenance.page,
        "retrieved": provenance.retrieved,
        "checksum": provenance.checksum,
    })
}

/// One field's record: the verdict, the author's sentence, and the controls.
///
/// `claim` and `detail` are the v1 shape kept for readers that predate the
/// structured table; `state` and `source` are the same content as data. A field
/// the vocabulary could not classify keeps its sentence, has no state, and
/// stays locked.
fn measured(rows: &[MeasuredField]) -> Vec<Value> {
    rows.iter()
        .map(|field| {
            let mut row = Map::new();
            let state = field.state.map(MeasuredState::word).unwrap_or("");
            let grade = field.state.and_then(|state| match state {
                MeasuredState::Measured
                | MeasuredState::Estimate
                | MeasuredState::Borrowed
                | MeasuredState::Placeholder => Some(json!(state.grade())),
                MeasuredState::None => None,
            });
            row.insert("field".to_owned(), json!(field.field));
            row.insert("claim".to_owned(), json!(state));
            row.insert("detail".to_owned(), json!(field.source));
            row.insert(
                "state".to_owned(),
                match field.state {
                    Some(state) => json!(state.word()),
                    None => Value::Null,
                },
            );
            row.insert("grade".to_owned(), grade.unwrap_or(Value::Null));
            row.insert("source".to_owned(), json!(field.source));
            row.insert(
                "locked".to_owned(),
                json!(
                    field.state.is_none_or(MeasuredState::is_measured) || field.controls.is_empty()
                ),
            );
            row.insert(
                "advanced_unlock".to_owned(),
                json!(
                    field.state.is_some_and(MeasuredState::is_measured)
                        && !field.controls.is_empty()
                ),
            );
            row.insert(
                "controls".to_owned(),
                Value::Array(
                    field
                        .controls
                        .iter()
                        .map(|control| {
                            json!({
                                "name": control.name,
                                "value": control.value,
                                "min": control.min,
                                "max": control.max,
                            })
                        })
                        .collect(),
                ),
            );
            Value::Object(row)
        })
        .collect()
}

/// The model's own placeholders, which are not any stock's data.
///
/// The couplers, interimage and halation values are compiled behaviour for a
/// colour negative in general; no stock file carries them, so the catalogue
/// carries them once.
fn model() -> Vec<Value> {
    [
        ("halation", "the strengths describe a modern colour negative in general; the reflection width is geometry"),
        ("couplers", "the inhibition matrix is the compiled typical pair, not this stock's couplers"),
        ("interimage", "the interimage strength is the compiled typical value for colour negative in general"),
    ]
    .into_iter()
    .map(|(field, source)| {
        json!({
            "field": field,
            "claim": "placeholder",
            "detail": source,
            "state": "placeholder",
            "grade": MeasuredState::Placeholder.grade(),
            "source": source,
            "locked": false,
            "advanced_unlock": false,
            "controls": [{ "name": "strength", "value": 1.0, "min": 0.0, "max": 2.0 }],
        })
    })
    .collect()
}

/// The catalogue as one document for a caller that speaks JSON.
#[must_use]
pub fn json() -> String {
    serde_json::to_string(&value()).expect("a catalogue of strings is serialisable")
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The catalogue is the model's own list, not a list about it.
    #[test]
    fn every_stock_is_in_the_catalogue() {
        let Value::Array(films) = &value()["films"] else {
            panic!("no films");
        };
        assert_eq!(films.len(), FILM_STOCKS.len());
        assert!(!films.is_empty());
        let Value::Array(papers) = &value()["papers"] else {
            panic!("no papers");
        };
        assert_eq!(papers.len(), PAPER_STOCKS.len());
        assert_eq!(value()["schema"], "kallo/catalogue/2");
    }

    /// Every field says what it is, and what may move.
    #[test]
    fn every_field_has_a_verdict_and_a_sentence() {
        for stock in FILM_STOCKS {
            assert!(
                !stock.provenance.publication.is_empty(),
                "{} cites no publication",
                stock.id
            );
            assert!(!stock.measured.is_empty(), "{} admits to nothing", stock.id);
            assert!(!stock.note.trim().is_empty(), "{} has no note", stock.id);
            assert!(
                stock.digest.starts_with("sha256:") && stock.digest.len() == 71,
                "{} has no file digest",
                stock.id
            );
            for field in stock.measured {
                assert!(
                    !field.field.trim().is_empty(),
                    "{} has a nameless field",
                    stock.id
                );
                for control in field.controls {
                    assert!(
                        control.min <= control.value && control.value <= control.max,
                        "{}.{} default {} is outside {}..{}",
                        stock.id,
                        control.name,
                        control.value,
                        control.min,
                        control.max
                    );
                }
            }
        }
        for stock in PAPER_STOCKS {
            assert!(!stock.measured.is_empty(), "{} admits to nothing", stock.id);
            assert!(stock.digest.starts_with("sha256:"));
        }
    }

    /// Only fields that are not this stock's own measurement expose controls,
    /// and a control's default is the file's value.
    #[test]
    fn controls_are_the_unknowns() {
        for stock in FILM_STOCKS {
            for field in stock.measured {
                if field.state.is_some_and(MeasuredState::is_measured) {
                    assert!(
                        field.controls.is_empty(),
                        "{} exposes a control on measured {}",
                        stock.id,
                        field.field
                    );
                }
            }
        }
    }

    /// A paper says what it carries, and a silver one says so.
    #[test]
    fn the_papers_say_what_they_carry() {
        let silver: Vec<&str> = PAPER_STOCKS
            .iter()
            .filter(|paper| paper.emulsion == PaperEmulsion::Silver)
            .map(|paper| paper.id)
            .collect();
        assert_eq!(
            silver,
            [
                "brovira_speed",
                "multicontrast_classic",
                "multicontrast_premium",
                "polymax_ii_rc"
            ]
        );
        assert!(
            PAPER_STOCKS
                .iter()
                .any(|paper| paper.emulsion == PaperEmulsion::Colour),
            "no colour paper to print a colour film on"
        );
        let Value::Array(papers) = &value()["papers"] else {
            panic!("no papers");
        };
        for paper in papers {
            let emulsion = paper["emulsion"].as_str().expect("an emulsion");
            assert!(emulsion == "colour" || emulsion == "silver", "{emulsion}");
        }
    }

    /// The model carries its own placeholders once, not on every stock.
    #[test]
    fn the_model_placeholders_are_catalogued() {
        let Value::Array(model) = &value()["model"] else {
            panic!("no model section");
        };
        let fields: Vec<&str> = model
            .iter()
            .map(|entry| entry["field"].as_str().expect("a field"))
            .collect();
        assert_eq!(fields, ["halation", "couplers", "interimage"]);
        for entry in model {
            assert_eq!(entry["locked"], false);
            assert_eq!(entry["controls"][0]["value"], 1.0);
        }
    }
}
