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
/// A `null` override value removes the key from the payload entirely (F-082):
/// some models reject a parameter outright rather than ignoring it — Claude
/// Sonnet 5 / Opus 4.7+ return HTTP 400 when `temperature` is non-default —
/// so `"temperature": null` in providers.json means "never send it".
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
        if case .null = value {
            payload.removeValue(forKey: key)
        } else {
            payload[key] = value.toAny()
        }
    }
}

/// Shared OpenAI-compatible payload builder used by both the ordinary and
/// speculative paths. Keeping construction at one seam prevents a model
/// override from being honored by one path but silently skipped by the other.
func makeOpenAICompatiblePolishPayload(
    model: String,
    systemPrompt: String,
    userPrompt: String,
    temperature: Double,
    stream: Bool,
    overrides: [String: JSONValue]?
) -> [String: Any] {
    var payload: [String: Any] = [
        "model": model,
        "messages": [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userPrompt]
        ],
        "temperature": temperature,
        "max_tokens": 4096
    ]
    if stream {
        payload["stream"] = true
    }
    applyPolishOverrides(to: &payload, overrides: overrides)
    return payload
}
