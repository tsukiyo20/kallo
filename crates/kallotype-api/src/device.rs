//! What this machine would render on.
//!
//! The model runs on two engines. An interface that lets a person choose between
//! them needs to know what the machine has before it can say anything true about
//! the choice, so this asks the renderer's own question: open the adapter a print
//! would open, or say why there is not one.
//!
//! It is deliberately not a benchmark and not a capability list. "There is an
//! adapter" is the one fact a settings screen needs; whether a particular frame
//! fits on it is a property of the frame, and the renderer answers that with a
//! fallback rather than with a form.

/// What the machine offers for rendering.
#[derive(Debug, Clone)]
pub struct RenderDevice {
    /// The adapter a render would open, as wgpu names it:
    /// `Adreno (TM) 730 (Vulkan)`.
    pub gpu: Option<String>,
    /// Why there is no adapter, when there is none.
    pub gpu_error: Option<String>,
}

/// Ask the machine what it would render on.
///
/// Exactly one of [`RenderDevice::gpu`] and [`RenderDevice::gpu_error`] is set:
/// a machine either names its adapter or gives the reason it has none.
#[must_use]
pub fn render_device() -> RenderDevice {
    #[cfg(feature = "gpu")]
    {
        match kallotype_gpu::describe_adapter() {
            Ok(gpu) => RenderDevice {
                gpu: Some(gpu),
                gpu_error: None,
            },
            Err(error) => RenderDevice {
                gpu: None,
                gpu_error: Some(error.to_string()),
            },
        }
    }
    #[cfg(not(feature = "gpu"))]
    {
        RenderDevice {
            gpu: None,
            gpu_error: Some("this build has no GPU backend".to_owned()),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::render_device;

    #[test]
    fn an_adapter_is_either_named_or_its_absence_explained() {
        let device = render_device();
        assert_ne!(device.gpu.is_some(), device.gpu_error.is_some());
    }
}
