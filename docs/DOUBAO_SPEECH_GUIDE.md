# Doubao Speech BigASR Flash

Vowrite's `Doubao Speech (豆包语音)` provider is a speech-recognition integration separate from Volcengine Ark. Create a [Speech console API Key](https://console.volcengine.com/speech/new/setting/apikeys?projectName=default), grant the BigASR Flash resource in the project, then paste that key into Vowrite. It is sent only as `X-Api-Key`; an Ark text-model key is not interchangeable.

## Supported path

The only selectable resource is `volc.bigasr.auc_turbo`, the documented BigASR Flash recording-file route:

- `POST https://openspeech.bytedance.com/api/v3/auc/bigmodel/recognize/flash`
- `X-Api-Resource-Id: volc.bigasr.auc_turbo`
- `request.model_name: bigmodel`, with ITN and punctuation enabled and DDC disabled
- a random request ID and random `user.uid` for each upload

Vowrite converts the local recording to a 16 kHz, 16-bit, mono WAV before base64 encoding it. Input and converted files are limited to 100 MB; recordings over two hours are rejected before upload. Temporary source and conversion files are removed on success, failure, and cancellation. The adapter does not retry an upload automatically because retries can create duplicate billable requests.

For an explicit supported language, Vowrite sends that exact code in `audio.language`. For other selections it uses the documented `enable_auto_lang` request option. Flash documents corpus support, but Vowrite deliberately defers corpus/hotword configuration in this release because corpus and automatic-language detection conflict; it does not reinterpret the generic Vowrite prompt as provider corpus.

## Connection test and privacy

Test & Save sends a generated all-zero WAV through the same Flash adapter. It does not send a microphone recording and does not call an OpenAI-style `/models` route, but it is a real inference request and may consume quota. User-visible errors contain fixed guidance plus only HTTP or numeric provider status; response bodies, request headers, audio data, and keys are never shown.

## Evidence boundary

The latest official [Flash page](https://docs.volcengine.com/docs/DoubaoVoice/recording-file-recognition-lite-http?lang=zh) (updated 2026-09-11) documents the resource, endpoint, headers, response status codes, language behavior, and request options. See the official [access requirements](https://docs.volcengine.com/docs/DoubaoVoice/Accessmust-read?lang=zh) before enabling a project. Its current audio table omits the `audio.data` representation; this implementation uses raw base64 because the [historical official page for the same endpoint](https://www.volcengine.com/docs/6561/1631584?lang=zh) specifies it. Unit tests validate the generated request, but no credentialed provider call was made for this feature.

Doubao Standard 2.0 is documented separately: `volc.seedasr.auc` submits an asynchronous task to `/api/v3/auc/bigmodel/submit`, requires an `audio.url`, then uses task-status query. It is intentionally deferred because immediate local dictation would require separate durable audio storage and polling. Idle and streaming services have their own session protocols and are also not selectable; see the official [access requirements](https://docs.volcengine.com/docs/DoubaoVoice/Accessmust-read?lang=zh) for their distinct service constraints.
