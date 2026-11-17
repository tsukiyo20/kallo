//! One print, at the size a print is.

use crate::frb_generated::StreamSink;
use kallo_api::{render_image_with_progress, resolve, Exposure, RenderOptions, StockChoice};
use kallo_core::Tuning;
use kallo_io::save_with_progress;

/// What a print asks for.
#[derive(Debug, Clone)]
pub struct PrintJob {
    /// The photograph.
    pub input: String,
    /// Film stock id.
    pub film: String,
    /// Paper stock id.
    pub paper: String,
    /// Development time in minutes.
    pub minutes: f64,
    /// Developer temperature in degrees Celsius.
    pub temp_c: f64,
    /// Width in pixels; zero keeps the photograph's own.
    pub width: u32,
    /// Expose through the spectral path.
    pub spectral: bool,
    /// Meter the frame instead of naming an offset.
    pub ev_auto: bool,
    /// The offset, when the exposure is named.
    pub ev_stops: f64,
    /// Extra print exposure in stops.
    pub print_ev: f64,
    /// Print on the balance solved for this development instead of this one.
    ///
    /// This is a test strip's one exposure: every print keeps the enlarger
    /// where the first print set it.
    pub balance_from: Option<f64>,
    /// The enlarger's colour pack, in Kodak CC units: `30M`, `20Y+10M`.
    pub filters: String,
    /// A heat-absorbing glass in the light path, by name: `kg1` … `kg5`.
    pub heat_glass: Option<String>,
    /// Width of the film frame the image represents, in millimetres.
    pub frame_mm: f64,
    /// Add grain.
    pub grain: bool,
    /// Grain seed.
    pub grain_seed: u64,
    /// Add halation.
    pub halation: bool,
    /// Add DIR couplers.
    pub couplers: bool,
    /// The scalars a stock recipe moves, in the order of [`Tuning::KEYS`].
    ///
    /// Empty is the file's own numbers, which is the render the app made
    /// before a recipe existed. Eight values are the eight controls; anything
    /// else is a programming mistake and is refused rather than guessed at.
    pub tuning: Vec<f64>,
    /// Render on the device.
    pub gpu: bool,
    /// Where the print goes.
    pub output: String,
}

/// One step of a print on its way to the disk.
///
/// The fraction is the model's, not a clock's: the decode, the resize, the
/// render's own stages and the file's rows each report themselves. A bar built
/// from these moves when the work moves and stops when it stops.
#[derive(Debug, Clone)]
pub struct PrintStep {
    /// How much of the print is done, 0..1.
    pub fraction: f64,
    /// `reading`, `resizing`, `rendering`, `writing` or `done`.
    pub stage: String,
    /// The backend that rendered it, on the `done` step.
    pub backend: Option<String>,
}

/// Develop and print one frame, at the size the export asks for.
///
/// This is the same pipeline as a roll's frames; it exists separately because a
/// print is rendered from the photograph again, at a size the bench never uses.
/// The steps are reported as they land, so the interface draws the print's
/// progress rather than its own guess at how long a print takes.
pub fn make_print(job: PrintJob, progress: StreamSink<PrintStep>) -> Result<(), String> {
    let mut emitted = 0.0_f64;
    let mut started = false;
    let mut report = |stage: &str, fraction: f64| {
        // A GPU render that falls back to the CPU starts its stages again. The
        // bar is the print's, not a backend's, so it must not go backwards.
        let fraction = emitted.max(fraction.clamp(0.0, 1.0));
        // A save reports every row; the bar moves in half-percent steps so a
        // large print does not send a message per row across the bridge.
        if started && fraction < emitted + 0.005 {
            return;
        }
        started = true;
        emitted = fraction;
        let _ = progress.add(PrintStep {
            fraction: emitted,
            stage: stage.to_owned(),
            backend: None,
        });
    };

    let choice = StockChoice {
        film: job.film,
        paper: job.paper,
        temp: Some(job.temp_c),
        dev_time: Some(job.minutes),
        filters: job.filters,
        heat_glass: job.heat_glass,
        spectral: job.spectral,
        // The app's switch is the whole spectral path. The subprocess model
        // spells the three stages out as three flags; the library says the same
        // thing at once, or a preview and the print it stands for would be two
        // different photographs.
        spectral_print: job.spectral,
        spectral_scan: job.spectral,
        ..StockChoice::default()
    };
    let selection = resolve(&choice).map_err(|error| error.to_string())?;
    let tuning = tuning_from(&job.tuning)?;

    report("reading", 0.0);
    // A print is rendered at the size it is exported at; reading the photograph
    // at that width is the same average a decode and a resize made, without
    // the full-resolution f64 frame in between.
    let input = std::path::Path::new(&job.input);
    let mut image = if job.width > 0 {
        kallo_api::read_input_at_width(input, kallo_io::InputEncoding::Srgb, job.width)
    } else {
        kallo_api::read_input(input, kallo_io::InputEncoding::Srgb)
    }
    .map_err(|error| error.to_string())?;
    report("reading", 0.1);
    report("resizing", 0.14);

    let options = RenderOptions {
        ev: if job.ev_auto {
            Exposure::Auto
        } else {
            Exposure::Stops(job.ev_stops)
        },
        print_ev: job.print_ev,
        balance_from: job.balance_from,
        frame_mm: job.frame_mm,
        grain: job.grain,
        grain_seed: job.grain_seed,
        halation: job.halation,
        couplers: job.couplers,
        tuning,
        gpu: job.gpu,
        ..RenderOptions::default()
    };
    let outcome = {
        let mut render = |fraction: f32| {
            report("rendering", 0.14 + f64::from(fraction) * 0.58);
        };
        render_image_with_progress(&mut image, None, &selection, &options, &mut render)
            .map_err(|error| error.to_string())?
    };

    let output = std::path::Path::new(&job.output);
    {
        let mut writing = |fraction: f32| {
            report("writing", 0.72 + f64::from(fraction) * 0.28);
        };
        save_with_progress(output, &image, &mut writing).map_err(|error| error.to_string())?;
    }

    let backend = outcome.backend.to_string();
    let _ = progress.add(PrintStep {
        fraction: 1.0,
        stage: "done".to_owned(),
        backend: Some(backend),
    });
    Ok(())
}

/// The scalars a stock recipe moves, from the bridge's list.
///
/// Empty is the identity: the print is the file's own numbers, which is the
/// render the app made before a recipe existed. Eight values are the eight
/// controls in [`Tuning::KEYS`] order. Any other length, or a value that is not
/// a finite number, is refused rather than applied to the wrong control.
fn tuning_from(values: &[f64]) -> Result<Tuning, String> {
    if values.is_empty() {
        return Ok(Tuning::default());
    }
    if values.len() != Tuning::KEYS.len() {
        return Err(format!(
            "tuning has {} values; expected eight, in the order of `Tuning::KEYS`",
            values.len()
        ));
    }
    let mut tuning = Tuning::default();
    for (key, value) in Tuning::KEYS.into_iter().zip(values) {
        if !value.is_finite() {
            return Err(format!("{key} = {value} is not a finite number"));
        }
        tuning.set(key, *value).map_err(|error| error.to_string())?;
    }
    Ok(tuning)
}

#[cfg(test)]
mod tests {
    use super::tuning_from;
    use kallo_core::Tuning;

    #[test]
    fn an_empty_list_is_the_file() {
        assert_eq!(tuning_from(&[]), Ok(Tuning::default()));
        assert!(Tuning::default().is_identity());
    }

    #[test]
    fn eight_values_map_in_the_model_key_order() {
        // The bridge takes a list, so the order is the contract the app's
        // `Tuning.toList` writes and this reader has to keep.
        let values: Vec<f64> = (0..8).map(|index| 0.25 + index as f64).collect();
        let tuning = tuning_from(&values).expect("eight values");
        for (index, key) in Tuning::KEYS.into_iter().enumerate() {
            assert_eq!(tuning.get(key), Some(values[index]), "{key}");
        }
    }

    #[test]
    fn a_list_that_is_not_eight_is_refused() {
        assert!(tuning_from(&[1.0]).is_err());
        assert!(tuning_from(&[1.0; 7]).is_err());
        assert!(tuning_from(&[1.0; 9]).is_err());
    }

    #[test]
    fn a_value_that_is_not_a_number_is_refused() {
        assert!(tuning_from(&[f64::NAN; 8]).is_err());
        assert!(tuning_from(&[f64::INFINITY; 8]).is_err());
    }
}
