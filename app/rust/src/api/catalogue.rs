//! What the model carries, as one document.

/// Every film and paper, in the app's catalogue schema.
#[must_use]
pub fn catalogue() -> String {
    kallo_api::catalogue::json()
}
