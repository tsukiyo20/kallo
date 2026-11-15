//! Failures a user can cause, with enough context to fix them.
//!
//! The variants live in `kallo-api`, because the app reaches the same
//! failures through the same functions. The name here is the CLI's; the type is
//! the model's.

pub use kallo_api::Error as CliError;
