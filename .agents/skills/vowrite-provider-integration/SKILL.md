---
name: vowrite-provider-integration
description: "Integrate or update a Vowrite STT or polish provider through the current registry-first architecture. Use for provider, model catalog, auth, endpoint, or adapter changes."
---

# Vowrite provider integration

Read `docs/PROVIDER_GUIDE.md`, `VowriteKit/Sources/VowriteKit/Resources/README.md`, and the current registry/adapter code before designing the change. Provider behavior is registry-first; historical F-030 enum-computed-property instructions are not the architecture.

## 1. Establish evidence

Use first-party provider documentation. Record access date, endpoint, protocol, auth, model IDs, regional availability, pricing/free-tier claims, rate limits, data handling, and license or redistribution constraints. Separate verified facts, inference, and runtime-untested claims. Never add a model ID from secondary marketing copy alone.

## 2. Choose the smallest path

- Existing provider model/metadata change: edit `providers.json` only unless a migration or request behavior changes.
- New provider: add the `providers.json` definition and an `APIProvider` case plus `providerID` mapping because persisted configuration uses the enum.
- OpenAI-compatible STT: use `sttAdapter: "openai-compatible"` only after confirming `/audio/transcriptions` accepts Vowrite's multipart contract.
- Custom STT: add an adapter under `Services/Adapters/`, conform to the current `STTAdapter` signature, register its ID in `WhisperService.adapterMap`, and use the same ID in `providers.json`.
- OpenAI-compatible polish: use the generic polish path. Put model-specific request changes in `polishOverrides` when the schema can express them.
- Native/non-compatible polish or auth: introduce a dedicated service/router seam only when the real protocol requires it; document why registry headers and overrides are insufficient.

Do not add an `APIPreset` unless the provider belongs in a deliberate multi-provider recommended combination. Do not hardcode UI lists when `APIProvider.availableCases` and registry capabilities already drive them.

## 3. Protect data and migration behavior

Check KeyVault account identity, OAuth token identity, stored `APIProvider.rawValue`, base-URL overrides, and existing-user migrations. Regional splits or enum renames require an idempotent migration that runs before old values can decode to `nil`.

Never place keys or live credentials in tests, logs, specs, fixtures, or `providers.json`.

## 4. Test at public seams

Extend `ProviderRegistryDataTests` for registry integrity and `STTAdapterRoutingTests` for adapter IDs. Add focused URL, request, override, migration, or error-mapping tests at the public boundary affected by the provider.

Run:

```bash
cd VowriteKit && swift test
cd ../VowriteMac && swift build
cd .. && scripts/check-parity.sh
ops/scripts/test.sh
```

Network-free tests prove structure, not provider availability. A real connection, STT, polish, and full dictation smoke require authorized credentials and must be reported as separate manual/live gates.

## 5. Finish the lifecycle

Use `vowrite-feature-lifecycle` for spec, task, handoff, integration, platform/changelog routing, and tracking sync. Completion evidence names the exact provider docs, test commands, result SHA, and every live check not exercised.
