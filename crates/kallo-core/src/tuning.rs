//! The scalars a stock recipe may move.
//!
//! The catalogue says which fields have controls and what interval each control
//! may take; this module is the values themselves, as the renderer consumes
//! them. Every field is an identity multiplier — 1.0 is the file's own number —
//! so a default [`Tuning`] leaves the model bit-identical, and a renderer may
//! skip the arithmetic when [`Tuning::is_identity`] says so.
//!
//! The mapping from a control key (`grain.strength`, `halation.strength`, …) to
//! a field here is the one place the vocabulary is spelled; the CLI, the recipe
//! file and the app all go through [`Tuning::set`].

/// The ten scalars a recipe may move, keyed by their catalogue name.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Tuning {
    /// Multiplies the developed grain density of every layer.
    pub grain_strength: f64,
    /// Scales the grain's correlation length; above one is a coarser grain.
    pub grain_size: f64,
    /// Multiplies the orange mask's density.
    pub mask_strength: f64,
    /// Divides the borrowed blur's width; above one is a sharper borrow.
    pub blur_sharpness: f64,
    /// Multiplies the borrowed dye set's absorption.
    pub dye_saturation: f64,
    /// Multiplies both halation components' strengths.
    pub halation_strength: f64,
    /// Multiplies the DIR couplers' inhibition matrix.
    pub couplers_strength: f64,
    /// Multiplies the cyan-sensitive layer's gain.
    pub interimage_strength: f64,
    /// Multiplies the print's slope on the paper: above one is a harder print.
    pub print_contrast: f64,
    /// Scales the print's span from the paper's white to its deepest black.
    pub print_black: f64,
}

impl Default for Tuning {
    fn default() -> Self {
        Self {
            grain_strength: 1.0,
            grain_size: 1.0,
            mask_strength: 1.0,
            blur_sharpness: 1.0,
            dye_saturation: 1.0,
            halation_strength: 1.0,
            couplers_strength: 1.0,
            interimage_strength: 1.0,
            print_contrast: 1.0,
            print_black: 1.0,
        }
    }
}

/// A control key the model does not have.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct UnknownControl<'a>(pub &'a str);

impl std::fmt::Display for UnknownControl<'_> {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            formatter,
            "unknown control `{}`; expected one of {}",
            self.0,
            Tuning::KEYS.join(", ")
        )
    }
}

impl Tuning {
    /// The control keys, in the catalogue's reading order.
    pub const KEYS: [&'static str; 10] = [
        "grain.strength",
        "grain.size",
        "mask.strength",
        "blur.sharpness",
        "dyes.saturation",
        "halation.strength",
        "couplers.strength",
        "interimage.strength",
        "print.contrast",
        "print.black",
    ];

    /// Every key still at the file's own value.
    #[must_use]
    pub fn is_identity(&self) -> bool {
        *self == Self::default()
    }

    /// The value of one control.
    #[must_use]
    pub fn get(&self, key: &str) -> Option<f64> {
        match key {
            "grain.strength" => Some(self.grain_strength),
            "grain.size" => Some(self.grain_size),
            "mask.strength" => Some(self.mask_strength),
            "blur.sharpness" => Some(self.blur_sharpness),
            "dyes.saturation" => Some(self.dye_saturation),
            "halation.strength" => Some(self.halation_strength),
            "couplers.strength" => Some(self.couplers_strength),
            "interimage.strength" => Some(self.interimage_strength),
            "print.contrast" => Some(self.print_contrast),
            "print.black" => Some(self.print_black),
            _ => None,
        }
    }

    /// Set one control, refusing a key the model does not have.
    pub fn set<'a>(&mut self, key: &'a str, value: f64) -> Result<(), UnknownControl<'a>> {
        let slot = match key {
            "grain.strength" => &mut self.grain_strength,
            "grain.size" => &mut self.grain_size,
            "mask.strength" => &mut self.mask_strength,
            "blur.sharpness" => &mut self.blur_sharpness,
            "dyes.saturation" => &mut self.dye_saturation,
            "halation.strength" => &mut self.halation_strength,
            "couplers.strength" => &mut self.couplers_strength,
            "interimage.strength" => &mut self.interimage_strength,
            "print.contrast" => &mut self.print_contrast,
            "print.black" => &mut self.print_black,
            _ => return Err(UnknownControl(key)),
        };
        *slot = value;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_default_is_the_file() {
        let tuning = Tuning::default();
        assert!(tuning.is_identity());
        for key in Tuning::KEYS {
            assert_eq!(tuning.get(key), Some(1.0), "{key}");
        }
    }

    #[test]
    fn every_key_maps_to_a_field() {
        for (index, key) in Tuning::KEYS.into_iter().enumerate() {
            let mut tuning = Tuning::default();
            tuning.set(key, 0.25 + index as f64).expect("a known key");
            assert!(!tuning.is_identity(), "{key} did not move");
            assert_eq!(tuning.get(key), Some(0.25 + index as f64));
        }
        assert_eq!(
            Tuning::default().set("made.up", 1.0),
            Err(UnknownControl("made.up"))
        );
    }
}
