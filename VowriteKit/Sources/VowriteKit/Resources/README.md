# Resources

This directory contains bundled runtime data loaded at app startup.

## `providers.json`

The single source of truth for all built-in AI provider definitions (STT and polish). Loaded at startup by `ProviderRegistry` (see `../Config/`) and rendered automatically into the Settings UI.

**Do not edit `providers.json` blindly.** It has a defined schema and is consumed by Swift `Codable` structs.

For the full reference — field schema, auth styles, capabilities, OpenAI-compatible vs custom-adapter flows, and complete examples — see:

**📖 [`docs/PROVIDER_GUIDE.md`](../../../../docs/PROVIDER_GUIDE.md)** (at the repo root)

JSON does not support comments, which is why this guidance lives in an external Markdown file rather than inline in `providers.json` itself.
