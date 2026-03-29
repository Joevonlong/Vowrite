# Provider Integration Guide

This guide explains how to add new AI providers to Vowrite by editing `providers.json`. This is a developer/contributor guide — not runtime configuration.

## Overview

Vowrite uses a JSON registry (`providers.json`) to define all supported AI providers. Each provider entry describes its API endpoint, authentication, capabilities (STT and/or polish), and available models.

**File location:**
```
VowriteKit/Sources/VowriteKit/Resources/providers.json
```

## providers.json Structure

The file contains a top-level object with a `version` field and a `providers` array:

```json
{
  "version": 1,
  "providers": [
    { /* provider entry */ },
    { /* provider entry */ }
  ]
}
```

## Provider Entry Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | String | Yes | Unique identifier (lowercase, no spaces). Used as the internal key. |
| `name` | String | Yes | Display name shown in the UI. |
| `baseURL` | String | Yes | Base URL for API requests (e.g., `https://api.openai.com/v1`). |
| `isOpenAICompatible` | Boolean | Yes | Whether the provider uses OpenAI-compatible API format. |
| `auth` | Object | Yes | Authentication configuration (see below). |
| `capabilities` | Object | Yes | `{ "stt": true/false, "polish": true/false }` |
| `sttAdapter` | String | No | STT adapter ID. Use `"openai-compatible"` for standard providers. Omit if `stt` capability is false. |
| `sttNote` | String | No | Optional note about STT capabilities shown in the UI. |
| `headers` | Object | No | Extra HTTP headers to include with every request. |
| `stt` | Object | Yes | STT configuration with `defaultModel` and `models` array. |
| `polish` | Object | Conditional | Polish configuration. Required if `capabilities.polish` is true. |

### auth Object

```json
{
  "style": "bearer",
  "keyPlaceholder": "sk-...",
  "keyURL": "https://example.com/api-keys",
  "requiresKey": true
}
```

| Field | Description |
|-------|-------------|
| `style` | Auth method: `"bearer"` (most common), `"query"`, or `"custom"` |
| `keyPlaceholder` | Placeholder text for the API key input field |
| `keyURL` | URL where users can obtain an API key |
| `requiresKey` | Whether an API key is required (`false` for local providers like Ollama) |

### stt / polish Objects

```json
{
  "defaultModel": "whisper-large-v3-turbo",
  "models": [
    { "id": "whisper-large-v3-turbo", "description": "Fastest option" },
    { "id": "whisper-large-v3", "description": "Higher accuracy" }
  ]
}
```

## Adding an OpenAI-Compatible Provider

Most providers use the OpenAI-compatible API format. Here's how to add one:

### Step 1: Add the entry to providers.json

```json
{
  "id": "example-provider",
  "name": "Example Provider",
  "baseURL": "https://api.example.com/v1",
  "isOpenAICompatible": true,
  "auth": {
    "style": "bearer",
    "keyPlaceholder": "ep-...",
    "keyURL": "https://example.com/api-keys",
    "requiresKey": true
  },
  "capabilities": { "stt": true, "polish": true },
  "sttAdapter": "openai-compatible",
  "stt": {
    "defaultModel": "whisper-1",
    "models": [
      { "id": "whisper-1", "description": "Standard Whisper" }
    ]
  },
  "polish": {
    "defaultModel": "example-model-v1",
    "models": [
      { "id": "example-model-v1", "description": "Default model" },
      { "id": "example-model-v2", "description": "Higher quality" }
    ]
  }
}
```

### Step 2: Build and test

```bash
cd VowriteMac && swift build
./build.sh   # build, sign, and launch
```

The new provider will appear in the Settings UI automatically. No code changes needed.

### Step 3: Verify

1. Launch the app
2. Go to Settings > STT (or Polish)
3. Select the new provider
4. Enter an API key
5. Test with a recording

## Adding a Non-Standard Provider

Providers that don't use the OpenAI-compatible API (e.g., Deepgram's binary upload, iFlytek's WebSocket protocol) require a custom STT adapter.

### Step 1: Create an STT adapter

Create a new file in `VowriteKit/Sources/VowriteKit/Services/` that conforms to the `STTAdapter` protocol:

```swift
// VowriteKit/Sources/VowriteKit/Services/ExampleSTTAdapter.swift
import Foundation

final class ExampleSTTAdapter: STTAdapter {
    func transcribe(audioURL: URL, language: String?) async throws -> String {
        // Implement your provider's API protocol here
        // ...
        return transcribedText
    }
}
```

### Step 2: Register the adapter

Register your adapter in the STT router (`WhisperService`) so it's used when your provider is selected.

### Step 3: Add the providers.json entry

```json
{
  "id": "example-custom",
  "name": "Example Custom",
  "baseURL": "https://api.example.com",
  "isOpenAICompatible": false,
  "auth": { ... },
  "capabilities": { "stt": true, "polish": false },
  "sttAdapter": "example-custom",
  "stt": {
    "defaultModel": "default",
    "models": [
      { "id": "default", "description": "Default model" }
    ]
  }
}
```

**Reference implementations:**
- `DeepgramSTTAdapter` — HTTP POST with binary audio body + Token auth
- `IFlytekSTTAdapter` — WebSocket streaming with HMAC-SHA256 auth
- `ClaudePolishAdapter` — Anthropic native API (non-OpenAI chat format)

## Important Notes

- Changes to `providers.json` take effect after rebuilding the app.
- Provider `id` values must be unique and lowercase.
- The `models` array can be empty (`[]`) if the provider uses a fixed model or auto-selects.
- For polish-only providers, set `"stt": false` in capabilities and include a minimal `stt` block.
- When submitting a PR to add a new provider, include the provider name, a link to their API docs, and a note about any free tier availability.
