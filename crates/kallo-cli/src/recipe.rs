//! The stock recipe: the departures a person asked for, and their bounds.
//!
//! A recipe is a JSON document — `kallo/stock-recipe/1` — naming a stock and
//! the packed file's digest it was written against:
//!
//! ```json
//! {
//!   "schema": "kallo/stock-recipe/1",
//!   "stock": "kodak_portra_400",
//!   "stock_digest": "sha256:…",
//!   "overrides": {
//!     "grain.strength": { "value": 0.6, "against": "placeholder" }
//!   }
//! }
//! ```
//!
//! The catalogue says which fields have controls and what interval each may
//! take; this module is where a typed value becomes a [`Tuning`], and where a
//! recipe that no longer names the same packed file is refused instead of
//! silently applied to a stock that has moved.

use std::path::Path;

use kallo_api::Error;
use kallo_core::{FilmStock, MeasuredState, Tuning};

/// One control a recipe (or `--set`) moved.
#[derive(Debug, Clone, PartialEq)]
pub struct Departure {
    /// The catalogue's control key, e.g. `grain.strength`.
    pub key: String,
    /// The value the file was moved to.
    pub value: f64,
    /// The verdict the field carried when the departure was written.
    pub against: String,
}

/// The tuning and its record, from `--recipe` files and `--set` expressions.
///
/// The film's own record is the authority on bounds: a control that a measured
/// field does not expose is locked, and a value outside the field's interval is
/// refused rather than clamped.
pub fn resolve(
    sets: &[String],
    recipes: &[std::path::PathBuf],
    film: &FilmStock,
    allow_stale: bool,
) -> Result<(Tuning, Vec<Departure>, Vec<String>), Error> {
    let mut tuning = Tuning::default();
    let mut departures = Vec::new();
    let mut warnings = Vec::new();

    for path in recipes {
        apply_recipe(
            path,
            film,
            allow_stale,
            &mut tuning,
            &mut departures,
            &mut warnings,
        )?;
    }
    for expression in sets {
        apply_set(expression, film, &mut tuning, &mut departures)?;
    }
    Ok((tuning, departures, warnings))
}

fn apply_set(
    expression: &str,
    film: &FilmStock,
    tuning: &mut Tuning,
    departures: &mut Vec<Departure>,
) -> Result<(), Error> {
    let Some((head, value)) = expression.split_once('=') else {
        return Err(Error::Recipe {
            path: None,
            message: format!("`--set {expression}` is missing `=value`"),
        });
    };
    let value: f64 = value.parse().map_err(|_| Error::Recipe {
        path: None,
        message: format!("`--set {expression}`: {value:?} is not a number"),
    })?;
    let key = if head.split('.').count() == 3 {
        let (stock, rest) = head.split_once('.').expect("three parts have a dot");
        if stock != film.id {
            return Err(Error::Recipe {
                path: None,
                message: format!(
                    "`--set {expression}` names {stock}, but this render develops {}",
                    film.id
                ),
            });
        }
        rest
    } else {
        head
    };
    let against = apply_control(key, value, film, tuning)?;
    departures.push(Departure {
        key: key.to_owned(),
        value,
        against,
    });
    Ok(())
}

fn apply_recipe(
    path: &Path,
    film: &FilmStock,
    allow_stale: bool,
    tuning: &mut Tuning,
    departures: &mut Vec<Departure>,
    warnings: &mut Vec<String>,
) -> Result<(), Error> {
    let text = std::fs::read_to_string(path).map_err(|source| Error::Recipe {
        path: Some(path.to_path_buf()),
        message: source.to_string(),
    })?;
    let document: serde_json::Value =
        serde_json::from_str(&text).map_err(|source| Error::Recipe {
            path: Some(path.to_path_buf()),
            message: source.to_string(),
        })?;
    let string = |key: &str| -> Option<&str> { document.get(key).and_then(|value| value.as_str()) };
    let stock = string("stock").ok_or_else(|| Error::Recipe {
        path: Some(path.to_path_buf()),
        message: "no `stock`".to_owned(),
    })?;
    if stock != film.id {
        return Err(Error::Recipe {
            path: Some(path.to_path_buf()),
            message: format!(
                "the recipe is for {stock}, but this render develops {}",
                film.id
            ),
        });
    }
    let digest = string("stock_digest").unwrap_or("");
    let stale = !digest.is_empty() && digest != film.digest;
    if stale && !allow_stale {
        return Err(Error::Recipe {
            path: Some(path.to_path_buf()),
            message: format!(
                "the recipe was written against {digest}, but this file is {}; \
                 pass --allow-stale to apply what still fits",
                film.digest
            ),
        });
    }
    if stale {
        warnings.push(format!(
            "stale recipe {path:?}: written against {digest}, the file is {}",
            film.digest
        ));
    }
    let overrides = document
        .get("overrides")
        .and_then(|value| value.as_object())
        .ok_or_else(|| Error::Recipe {
            path: Some(path.to_path_buf()),
            message: "no `overrides` object".to_owned(),
        })?;
    for (key, override_value) in overrides {
        let Some(value) = override_value.get("value").and_then(|value| value.as_f64()) else {
            return Err(Error::Recipe {
                path: Some(path.to_path_buf()),
                message: format!("`{key}` has no numeric value"),
            });
        };
        let recorded = override_value
            .get("against")
            .and_then(|value| value.as_str())
            .unwrap_or("");
        if let Some(field) = field_of(film, key) {
            if field.state.is_some_and(MeasuredState::is_measured) {
                warnings.push(format!(
                    "dropped {key}: the field is measured now, and a recipe cannot move it"
                ));
                continue;
            }
        }
        let against = apply_control(key, value, film, tuning)?;
        if !recorded.is_empty() && recorded != against {
            warnings.push(format!(
                "{key}: the recipe was written against {recorded}, the file says {against}"
            ));
        }
        departures.push(Departure {
            key: key.to_owned(),
            value,
            against,
        });
    }
    Ok(())
}

/// The measured field a control key belongs to, when the stock carries it.
fn field_of<'a>(film: &'a FilmStock, key: &str) -> Option<&'a kallo_core::MeasuredField> {
    let module = key.split('.').next()?;
    let name = match module {
        "blur" => "mtf",
        other => other,
    };
    film.measured.iter().find(|field| field.field == name)
}

/// Validate one control against the stock's record and set it.
fn apply_control(
    key: &str,
    value: f64,
    film: &FilmStock,
    tuning: &mut Tuning,
) -> Result<String, Error> {
    if !value.is_finite() {
        return Err(Error::Recipe {
            path: None,
            message: format!("{key} = {value} is not a finite number"),
        });
    }
    if tuning.get(key).is_none() {
        return Err(Error::Recipe {
            path: None,
            message: format!(
                "unknown control `{key}`; expected one of {}",
                Tuning::KEYS.join(", ")
            ),
        });
    }
    let Some(field) = field_of(film, key) else {
        return Err(Error::Recipe {
            path: None,
            message: format!("{} has no {key} to move", film.id),
        });
    };
    let against = field.state.map(MeasuredState::word).unwrap_or("unknown");
    if field.state.is_some_and(MeasuredState::is_measured) {
        return Err(Error::Recipe {
            path: None,
            message: format!("{key} is measured on {} and locked", film.id),
        });
    }
    let control_name = key.split('.').nth(1).unwrap_or("");
    let Some(control) = field
        .controls
        .iter()
        .find(|control| control.name == control_name)
    else {
        return Err(Error::Recipe {
            path: None,
            message: format!(
                "{}.{} has no `{}` control in this file",
                film.id, field.field, control_name
            ),
        });
    };
    if value < control.min || value > control.max {
        return Err(Error::InvalidNumber {
            flag: "--set",
            value,
            expected: "a value inside the control's range",
        });
    }
    tuning.set(key, value).map_err(|unknown| Error::Recipe {
        path: None,
        message: unknown.to_string(),
    })?;
    Ok(against.to_owned())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn stock() -> &'static FilmStock {
        kallo_core::emulsion::film_stock("vision3_250d").expect("a compiled stock")
    }

    #[test]
    fn a_set_moves_one_control() {
        let (tuning, departures, warnings) =
            resolve(&["grain.strength=0.5".to_owned()], &[], stock(), false).expect("a valid set");
        assert_eq!(tuning.grain_strength, 0.5);
        assert!(!tuning.is_identity());
        assert_eq!(departures.len(), 1);
        assert!(warnings.is_empty());
    }

    #[test]
    fn a_set_outside_the_range_is_refused() {
        assert!(resolve(&["grain.strength=9".to_owned()], &[], stock(), false).is_err());
    }

    #[test]
    fn a_measured_control_is_locked() {
        // VISION3 250D's curves are measured and expose no control.
        assert!(resolve(&["curves.slope=2".to_owned()], &[], stock(), false).is_err());
    }

    #[test]
    fn a_stale_recipe_is_refused_without_the_flag() {
        let path = std::env::temp_dir().join("kallo-recipe-stale.json");
        std::fs::write(
            &path,
            r#"{"schema":"kallo/stock-recipe/1","stock":"vision3_250d","stock_digest":"sha256:00","overrides":{"grain.strength":{"value":0.5,"against":"placeholder"}}}"#,
        )
        .expect("write a recipe");
        let refused = resolve(&[], std::slice::from_ref(&path), stock(), false);
        assert!(refused.is_err());
        let (tuning, departures, warnings) = resolve(&[], &[path], stock(), true)
            .expect("a stale recipe is a warning with --allow-stale");
        assert_eq!(tuning.grain_strength, 0.5);
        assert_eq!(departures.len(), 1);
        assert_eq!(warnings.len(), 1);
    }
}
