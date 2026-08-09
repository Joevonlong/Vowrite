# Provider Integration Guide

Vowrite's built-in provider catalog is registry-first. Runtime metadata lives in `VowriteKit/Sources/VowriteKit/Resources/providers.json`, is decoded by `ProviderDefinition`, and is queried through `ProviderRegistry`. The Settings UI reads the registry through `APIProvider`.

## Decide the change type

- Existing provider metadata or model refresh: edit `providers.json` and tests.
- New provider: add a registry entry and an `APIProvider` enum case plus `providerID` mapping, because persisted configuration stores the enum raw value.
- OpenAI-compatible STT: route to `openai-compatible` only after verifying the provider implements the multipart `/audio/transcriptions` contract.
- Custom STT protocol: add an adapter under `VowriteKit/Sources/VowriteKit/Services/Adapters/`, register it in `WhisperService.adapterMap`, and reference the same adapter ID from the registry.
- OpenAI-compatible polish: use the shared `AIPolishService` path. Put per-model request fields in `polishOverrides` when possible.
- Native polish protocol or nonstandard auth: add a dedicated request service/router only when the real API cannot be represented by the shared path.

## Registry schema

The catalog currently uses schema version 2:

```json
{
  "version": 2,
  "providers": [
    {
      "id": "example",
      "name": "Example",
      "baseURL": "https://api.example.com/v1",
      "isOpenAICompatible": true,
      "platformFilter": null,
      "auth": {
        "style": "bearer",
        "keyPlaceholder": "ex-...",
        "keyURL": "https://example.com/keys",
        "requiresKey": true,
        "supportsOAuth": false
      },
      "capabilities": { "stt": true, "polish": true },
      "sttAdapter": "openai-compatible",
      "headers": { "X-Optional-Header": "value" },
      "stt": {
        "defaultModel": "speech-model",
        "models": [
          { "id": "speech-model", "description": "Default speech model" }
        ]
      },
      "polish": {
        "defaultModel": "chat-model",
        "models": [
          {
            "id": "chat-model",
            "description": "Default polish model",
            "polishOverrides": { "reasoning_effort": "none" }
          }
        ]
      }
    }
  ]
}
```

Core fields:

| Field | Meaning |
|---|---|
| `id` | Unique registry ID used by `APIProvider.providerID`. |
| `name` | UI display name. |
| `baseURL` | Base endpoint without a trailing slash. |
| `platformFilter` | Optional platform exclusion; local providers are omitted on iOS. |
| `auth` | Key requirement, placeholder/link, and optional OAuth metadata. |
| `capabilities` | Whether STT and/or polish are selectable. |
| `sttAdapter` | Router key; defaults to `openai-compatible` when absent. |
| `headers` | Static provider headers added by `APIProvider.applyHeaders`. |
| `stt` / `polish` | Default model and selectable model definitions. Omit an unsupported pipeline. |
| `polishOverrides` | Typed request-body patch for one polish model; JSON `null` removes a default field. |

The Codable source in `Config/ProviderDefinition.swift` is authoritative when this guide and code differ.

## Custom STT adapter contract

Adapters conform to the current public seam:

```swift
public protocol STTAdapter {
    func transcribe(
        audioURL: URL,
        model: String,
        language: String?,
        prompt: String?,
        apiKey: String?,
        baseURL: String,
        provider: APIProvider
    ) async throws -> String
}
```

Use `DeepgramSTTAdapter`, `QwenSTTAdapter`, and `IflytekSTTAdapter` as protocol-specific references. Unknown adapter IDs currently fall back to OpenAI-compatible routing, so `STTAdapterRoutingTests` must include every enabled adapter ID.

## Evidence and validation

Use first-party provider documentation for endpoint, auth, model IDs, geographic constraints, pricing, data handling, and license. Mark any API behavior not exercised with authorized credentials as unverified.

Run:

```bash
cd VowriteKit && swift test
cd ../VowriteMac && swift build
cd .. && scripts/check-parity.sh
ops/scripts/test.sh
```

`ProviderRegistryDataTests` protects catalog integrity; add focused adapter, URL, request, override, migration, and error tests for changed behavior. A successful build is not a live provider connection test.
