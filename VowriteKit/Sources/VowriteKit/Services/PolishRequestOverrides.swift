import Foundation

// MARK: - F-073: Per-model polish request overrides

/// Applies per-model `polishOverrides` (declared in providers.json) into a
/// `[String: Any]` payload before the HTTP request is serialized.
///
/// All providers in Vowrite currently use the OpenAI-compatible `/chat/completions`
/// endpoint (including Gemini via its `/v1beta/openai` compatibility layer), so
/// the merge is always a shallow top-level merge. Override keys win over any
/// existing key in the payload.
///
/// - Parameters:
///   - payload: The mutable request body dictionary to patch in-place.
///   - overrides: The per-model overrides from `ModelDef.polishOverrides`.
///               If nil or empty, this function is a no-op.
func applyPolishOverrides(
    to payload: inout [String: Any],
    overrides: [String: JSONValue]?
) {
    guard let overrides, !overrides.isEmpty else { return }
    for (key, value) in overrides {
        payload[key] = value.toAny()
    }
}
