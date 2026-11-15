//! The machine the app is running on.
//!
//! Two questions a settings page asks: whether this machine has a GPU to render
//! on, and what CPU is behind the fallback. The first is answered by the model
//! itself — the same adapter probe a print would use — so the screen cannot
//! promise an engine a print would not get. The second is the operating
//! system's answer, and it is allowed to be absent: a phone that will not name
//! its processor is still a phone with cores.

use sysinfo::{CpuRefreshKind, RefreshKind, System};

/// What this machine offers for rendering.
#[derive(Debug, Clone)]
pub struct DeviceReport {
    /// The GPU adapter a render would open, as wgpu names it:
    /// `Adreno (TM) 730 (Vulkan)`.
    pub gpu: Option<String>,
    /// Why there is no GPU, when there is none.
    pub gpu_error: Option<String>,
    /// The CPU's own name, when the platform lets an app read it.
    pub cpu: Option<String>,
    /// Logical processors: the width the CPU renderer works at.
    pub cores: u32,
    /// The target architecture: `aarch64`, `x86_64`, …
    pub architecture: String,
    /// The operating system: `macos`, `android`, …
    pub platform: String,
}

/// Ask the machine what it offers.
pub fn describe_device() -> DeviceReport {
    let device = kallo_api::render_device();
    let (cpu, cores) = cpu();
    DeviceReport {
        gpu: device.gpu,
        gpu_error: device.gpu_error,
        cpu,
        cores,
        architecture: std::env::consts::ARCH.to_owned(),
        platform: std::env::consts::OS.to_owned(),
    }
}

/// The processor's own name, and how many threads it gives a render.
///
/// The name is not promised: Android restricts what `/proc` may say to an app,
/// and a platform without a name is not a platform without a CPU. The core
/// count is the standard library's answer, so it is there even when the name is
/// not.
fn cpu() -> (Option<String>, u32) {
    let cores = std::thread::available_parallelism()
        .map_or(1, |count| u32::try_from(count.get()).unwrap_or(u32::MAX));
    let Ok(system) =
        System::new_with_specifics(RefreshKind::nothing().with_cpu(CpuRefreshKind::everything()))
    else {
        return (None, cores);
    };
    let brand = system
        .cpus()
        .first()
        .map(|cpu| cpu.brand().trim().to_owned())
        .filter(|brand| !brand.is_empty());
    (brand, cores)
}

#[cfg(test)]
mod tests {
    use super::describe_device;

    #[test]
    fn a_machine_names_its_engines_or_its_cores() {
        let device = describe_device();
        assert!(device.cores > 0);
        assert!(device.gpu.is_some() || device.gpu_error.is_some());
        assert_eq!(device.platform, std::env::consts::OS);
        assert_eq!(device.architecture, std::env::consts::ARCH);
    }
}
