# Model maintenance ledger

Audit date: 2026-09-19. This ledger records catalog decisions for the F-092 refresh and the F-093 Doubao Speech addition. “Verified” means the model ID and request contract are documented by the provider; no paid or credentialed runtime calls were made. Hidden rows remain decodable for saved configurations and retain their request overrides.

F-092 supersedes the older F-086 catalog-freeze fixture for the documented current and local choices below. The historical fixture remains useful for regression context; it is not a live availability result or an approval of provider runtime access.

| Provider | Model | Pipeline | Decision | Official evidence | Rationale |
|---|---|---|---|---|---|
| OpenAI | `gpt-transcribe` | STT | default | [speech guide](https://developers.openai.com/api/docs/guides/speech-to-text) | Current file transcription model; adapter sends text and `languages[]`. |
| OpenAI | `gpt-4o-mini-transcribe`, `gpt-4o-transcribe` | STT | visible compatible | [audio reference](https://developers.openai.com/api/reference/cli/resources/audio) | Provider documents JSON-only response; adapter selects JSON and decodes the returned `.text`. |
| OpenAI | `gpt-4o-transcribe-diarize` | STT | hidden compatibility | [diarization guide](https://developers.openai.com/api/docs/guides/speech-to-text) | Speaker output requires `diarized_json` and `chunking_strategy=auto`, outside the generic path. |
| OpenAI | `whisper-1` | STT | visible fallback | [audio reference](https://developers.openai.com/api/reference/cli/resources/audio) | Existing text response contract remains compatible. |
| OpenAI | `gpt-6-astra`, `gpt-5.4-mini`, `gpt-5.4-nano` | Polish | shortlist/default | [model catalog](https://developers.openai.com/api/docs/models), [latest-model migration](https://developers.openai.com/api/docs/guides/latest-model?model=gpt-6-astra) | Astra uses low reasoning effort and removes temperature/top_p/top_logprobs/logprobs, per the migration contract; mini/nano remain value choices. |
| OpenAI | `gpt-5.6-terra` | Polish | deferred | [model catalog](https://developers.openai.com/api/docs/models) | Deferred from the visible shortlist in favor of Astra plus the 5.4 mini/nano value choices. |
| OpenRouter | `openai/whisper-large-v3`, `qwen/qwen3-asr-flash-2026-02-10` | STT | hidden compatibility | [live catalog](https://openrouter.ai/api/v1/models) | No matching current IDs or verified multipart transcription route; provider STT capability disabled. |
| OpenRouter | dynamic catalog | Polish | dynamic | [quickstart](https://openrouter.ai/docs/quickstart) | Static polish rows would stale; retain provider default and runtime discovery. |
| Groq | `whisper-large-v3`, `whisper-large-v3-turbo` | STT | maintain | [STT docs](https://console.groq.com/docs/speech-to-text) | Exact OpenAI-compatible endpoint and models documented. |
| Groq | `openai/gpt-oss-120b`, `openai/gpt-oss-20b` | Polish | maintain | [models](https://console.groq.com/docs/models) | Current production models; `reasoning_effort=low` documented. |
| Deepgram | `nova-3`, `nova-2` | STT | shortlist/default | [model overview](https://developers.deepgram.com/docs/models-languages-overview) | Current general models for file STT. |
| Deepgram | `nova-3-medical` | STT | deferred | [model overview](https://developers.deepgram.com/docs/models-languages-overview) | Account availability requires direct model-list confirmation. |
| Together | `openai/whisper-large-v3` | STT | maintain | [transcription docs](https://docs.together.ai/docs/inference/transcription/translation) | Official audio path and limits documented. |
| Together | `nvidia/parakeet-tdt-0.6b-v3` | STT | deferred | [transcription docs](https://docs.together.ai/docs/inference/transcription/transcription) | Exact Together endpoint support not reconfirmed. |
| Together | `meta-llama/Llama-3.3-70B-Instruct-Turbo`, `Qwen/Qwen3.5-9B` | Polish | visible shortlist | [serverless models](https://docs.together.ai/docs/serverless-models) | Current documented serverless choices retained for capable and economical polish. |
| Together | `Qwen/Qwen3.7-Plus`, `LiquidAI/LFM2.5-8B-A1B`, `deepseek-ai/DeepSeek-V4-Pro` | Polish | hidden compatibility | [serverless models](https://docs.together.ai/docs/serverless-models) | Existing saved IDs retained; current serverless availability was not reconfirmed. |
| DeepSeek | `deepseek-flash`, `deepseek-v4-pro` | Polish | shortlist/default | [API docs](https://api-docs.deepseek.com/) | Flash is the fresh economical default; V4 Pro remains a visible capable option. |
| DeepSeek | `deepseek-v4-flash` | Polish | hidden compatibility | [API docs](https://api-docs.deepseek.com/) | Existing saved ID retained with its thinking override; omitted from the picker. |
| Qwen | `qwen3-asr-flash` | STT | sole visible model | [DashScope docs](https://www.alibabacloud.com/help/en/model-studio/qwen-audio) | Sync multimodal file path only; realtime and async/file models hidden. |
| Qwen | `qwen3-asr-flash-realtime`, `paraformer-realtime-v2`, `fun-asr` | STT | hidden compatibility | [DashScope docs](https://www.alibabacloud.com/help/en/model-studio/qwen-audio) | These IDs require contracts outside Vowrite's synchronous file path. |
| Qwen | `qwen3.8-flash`, `qwen3.8-max` | Polish | shortlist/default | [Qwen model docs](https://help.aliyun.com/zh/model-studio/text-generation-model) | Current economical and capable models; OpenAI-compatible request overrides remain conservative. |
| Qwen | `qwen3.7-plus`, `qwen3.7-max`, `qwen3.6-flash` | Polish | hidden compatibility | [Qwen model docs](https://help.aliyun.com/zh/model-studio/text-generation-model) | Existing saved IDs retained; older rows are omitted from the picker. |
| Gemini | `gemini-3.8-flash`, `gemini-3.5-flash-lite`, `gemini-2.5-flash` | Polish | shortlist/default | [models](https://ai.google.dev/gemini-api/docs/models), [OpenAI compatibility](https://ai.google.dev/gemini-api/docs/openai) | Current capable, economical, and stable fallback choices; older documented rows remain hidden compatibility entries. |
| Claude | `claude-sonnet-5`, `claude-haiku-4-5`, `claude-opus-5` | Polish | shortlist/default | [model overview](https://platform.claude.com/docs/en/models/overview), [Opus migration](https://platform.claude.com/docs/en/models/opus-5/migration-guide) | Opus 5 is current capable; adapter override disables thinking with low output effort and null temperature. Haiku remains value; native `/messages` service remains required. |
| Claude | `claude-opus-4-8` | Polish | hidden compatibility | [model overview](https://platform.claude.com/docs/en/models/overview) | Superseded by Opus 5; saved IDs remain decodable. |
| Claude | `claude-fable-5-1` | Polish | deferred | [model overview](https://platform.claude.com/docs/en/models/overview) | Always-on thinking and slower profile do not fit the current low-latency/value shortlist. |
| xAI | `grok-4.6`, `grok-4.3` | Polish | shortlist/default | [models API](https://docs.x.ai/developers/rest-api-reference/inference/models) | Current capable and balanced choices; STT remains disabled pending adapter. |
| Cerebras | `gpt-oss-120b`, `qwen-3.8-27b` | Polish | shortlist/default | [public models](https://inference-docs.cerebras.ai/models/overview) | Current public production models. |
| Cerebras | `zai-glm-4.7`, `gemma-4-31b` | Polish | deferred | [public models](https://inference-docs.cerebras.ai/models/overview) | Not in current public model catalog; no destructive removal from saved values. |
| SiliconFlow | `FunAudioLLM/SenseVoiceSmall`, `TeleAI/TeleSpeechASR` | STT | visible maintain | [API docs](https://docs.siliconflow.cn/) | Official OpenAI-compatible multipart STT surface remains enabled. |
| SiliconFlow | `deepseek-ai/DeepSeek-V4-Flash`, `Qwen/Qwen3.5-4B` | Polish | visible shortlist | [API docs](https://docs.siliconflow.cn/) | Current capable/economical CN options; price and quota remain account-specific. |
| SiliconFlow | `deepseek-ai/DeepSeek-V3`, `deepseek-ai/DeepSeek-V3.1-Terminus`, `Qwen/Qwen3-8B`, `Qwen/Qwen2.5-72B-Instruct` | Polish | hidden compatibility | [API docs](https://docs.siliconflow.cn/) | Existing saved IDs retained but omitted from the picker. |
| Kimi | `kimi-k3`, `kimi-k2.6` | Polish | shortlist/default | [model overview](https://platform.kimi.com/docs/api/models-overview) | K3 is latest capable with always-on thinking; K2.6 is the lower-latency default. |
| Kimi | `kimi-k2.5` | Polish | hidden compatibility | [model overview](https://platform.kimi.com/docs/api/models-overview) | Existing saved ID retained but omitted from the picker. |
| MiniMax International / CN | `MiniMax-M3`, `MiniMax-M2.7-highspeed` | Polish | visible shortlist/default | [international API](https://platform.minimax.io/docs/api-reference/text-openai-api), [CN API](https://platform.minimax.cn/docs/api-reference/text-openai-api) | M3 supports disabled thinking; highspeed is a lower-latency alternative; CN registry default uses documented `api.minimax.cn`. |
| MiniMax International / CN | `MiniMax-M2.7` | Polish | hidden compatibility | [international API](https://platform.minimax.io/docs/api-reference/text-openai-api), [CN API](https://platform.minimax.cn/docs/api-reference/text-openai-api) | Existing saved ID retained but omitted from the picker. |
| Volcengine | `doubao-seed-2-1-turbo-260628`, `doubao-seed-2-1-pro-260628` | Polish | visible shortlist/default | [Ark docs](https://www.volcengine.com/docs/82379/1099455) | Current balanced and capable CN options; STT remains outside the current contract. |
| Volcengine | `doubao-seed-1-8-251228`, `doubao-seed-1-6-flash-250828` | Polish | hidden compatibility | [Ark docs](https://www.volcengine.com/docs/82379/1099455) | Existing saved IDs retained but omitted from the picker. |
| Doubao Speech | `volc.bigasr.auc_turbo` | STT | visible/default | [Flash recording-file recognition](https://docs.volcengine.com/docs/DoubaoVoice/recording-file-recognition-lite-http?lang=zh) | Dedicated synchronous Flash adapter with a Speech console API Key and `X-Api-Key`; static request-contract tests cover encoding, but no credentialed runtime call was made. |
| Doubao Speech | `volc.seedasr.auc` | STT | deferred | [standard task submission](https://docs.volcengine.com/docs/DoubaoVoice/task-submission-http-1?lang=zh) | Standard 2.0 is documented as asynchronous `submit`/query with required `audio.url`; it does not fit immediate local recording without additional upload storage. |
| Doubao Speech | idle and streaming resources | STT | deferred | [access requirements](https://docs.volcengine.com/docs/DoubaoVoice/Accessmust-read?lang=zh) | Different session contracts are outside the one-shot recording pipeline and are intentionally not selectable. |
| Zhipu | `glm-4.7-flash`, `glm-5.2` | Polish | visible shortlist | [GLM-5.2 docs](https://docs.bigmodel.cn/cn/guide/models/text/glm-5.2) | Current economical and capable CN options. |
| Zhipu | `glm-5.1`, `glm-4.6` | Polish | hidden compatibility | [GLM-5.2 docs](https://docs.bigmodel.cn/cn/guide/models/text/glm-5.2) | Existing saved IDs retained but omitted from the picker. |
| Qianfan | `ernie-4.5-turbo-128k` | Polish | maintain | [Qianfan docs](https://cloud.baidu.com/doc/WENXINWORKSHOP/s/jlil56u11) | Existing documented chat model retained; STT uses a separate non-compatible surface. |
| Qianfan | `ernie-5.1` | Polish | deferred | [Qianfan model docs](https://cloud.baidu.com/doc/WENXINWORKSHOP/s/jlil56u11) | Exact ID and account availability were not reconfirmed during this audit. |
| Ollama | `qwen3.5:9b`, `qwen3.5:4b`, `gemma3:4b` | Polish | visible shortlist/default | [OpenAI compatibility](https://github.com/ollama/ollama/blob/main/docs/openai.md) | Local economical shortlist; terms and installed model availability are local. |
| Ollama | `qwen3:8b`, `llama3.1:8b`, `llama4:16x17b`, `deepseek-r1:8b`, `mistral:7b` | Polish | hidden compatibility | [OpenAI compatibility](https://github.com/ollama/ollama/blob/main/docs/openai.md) | Existing saved IDs retained but omitted from the picker to keep the local shortlist small. |
| MLX Server | `mlx-community/Qwen3.5-9B-MLX-4bit`, `mlx-community/Qwen3.5-4B-MLX-4bit` | Polish | visible local shortlist/default | [9B model](https://huggingface.co/mlx-community/Qwen3.5-9B-MLX-4bit), [4B model](https://huggingface.co/mlx-community/Qwen3.5-4B-MLX-4bit) | Viable local 9B/4B choices; model files remain user-managed. |
| MLX Server | `mlx-community/Qwen3-4B-Instruct-2507-4bit` | Polish | hidden compatibility | [MLX-LM](https://github.com/ml-explore/mlx-lm) | Existing saved ID retained but omitted from the picker. |
| MLX Server | `mlx-community/Llama-3.3-70B-Instruct-4bit`, `mlx-community/Mistral-Small-24B-Instruct-2501-4bit`, `mlx-community/gemma-3-4b-it-4bit` | Polish | hidden compatibility | [MLX-LM](https://github.com/ml-explore/mlx-lm) | Existing saved IDs retained but omitted from the picker. |
| Sherpa | `sensevoice-small`, `zipformer-en`, `fire-red-asr2` | STT | hidden/unavailable | [sherpa-onnx](https://k2-fsa.github.io/sherpa/onnx/) | Capability disabled until the product model download/runtime path is validated. |
| iFlytek | `iat`, `xfime-mianqie` | STT | maintain | [iFlytek IAT](https://www.xfyun.cn/doc/asr/iat前端SDK/iat麦克风实时识别.html) | Native WebSocket adapter remains compatible; quota/price terms are account-specific. |
| Custom | user model IDs | STT/Polish | editable defaults | [provider guide](PROVIDER_GUIDE.md) | User-owned endpoint; defaults remain editable and are not upstream claims. |

A successful build or catalog decode does not prove a live provider call; credentialed smoke tests remain a release gate.

The model-watch F-086 freeze tests retain the pending manifest and empty evaluation/approval contract. Their only F-092 exception is the exact provider/capability/model tuple for the three documented public rows added by this refresh; the negative guard test confirms the exception cannot release the same IDs from unrelated source files or broaden to other candidates.
## Complete model-ID accounting

Baseline: `8d3b50a8eb7ccde2ece6e136555b65b41b3c5828`; audit date: 2026-09-19. Every baseline and new static model row is accounted for below. Provider-specific rationale and first-party references are in the decision table above. Hidden means excluded from Vowrite recommendations, not proof of upstream shutdown. Account availability and measured value remain unverified.

| Provider | Pipeline | Exact model ID | Decision | Reason |
|---|---|---|---|---|
| cerebras | polish | `gemma-4-31b` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| cerebras | polish | `gpt-oss-120b` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| cerebras | polish | `qwen-3.8-27b` | Added recommendation | Current documented ID selected for the curated shortlist. |
| cerebras | polish | `zai-glm-4.7` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| claude | polish | `claude-haiku-4-5` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| claude | polish | `claude-opus-4-8` | Hidden compatibility | Superseded by current Opus 5; preserve saved ID and overrides. |
| claude | polish | `claude-opus-5` | Added recommendation | Current capable model with documented low-effort disabled-thinking override. |
| claude | polish | `claude-fable-5-1` | Deferred | Always-on thinking and slower profile are outside the current shortlist. |
| claude | polish | `claude-sonnet-5` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| deepgram | stt | `nova-2` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| deepgram | stt | `nova-3` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| deepgram | stt | `nova-3-medical` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| deepseek | polish | `deepseek-flash` | Added recommendation | Current documented ID selected for the curated shortlist. |
| deepseek | polish | `deepseek-v4-flash` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| deepseek | polish | `deepseek-v4-pro` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| doubaoSpeech | stt | `volc.bigasr.auc_turbo` | Added recommendation | Dedicated synchronous Flash path with a separate Speech console API Key. |
| gemini | polish | `gemini-2.5-flash` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| gemini | polish | `gemini-2.5-flash-lite` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| gemini | polish | `gemini-2.5-pro` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| gemini | polish | `gemini-3.1-flash-lite` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| gemini | polish | `gemini-3.5-flash` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| gemini | polish | `gemini-3.5-flash-lite` | Added recommendation | Current documented ID selected for the curated shortlist. |
| gemini | polish | `gemini-3.8-flash` | Added recommendation | Current documented ID selected for the curated shortlist. |
| groq | polish | `openai/gpt-oss-120b` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| groq | polish | `openai/gpt-oss-20b` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| groq | stt | `whisper-large-v3` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| groq | stt | `whisper-large-v3-turbo` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| iflytek | stt | `iat` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| iflytek | stt | `xfime-mianqie` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| kimi | polish | `kimi-k2.5` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| kimi | polish | `kimi-k2.6` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| kimi | polish | `kimi-k3` | Added recommendation | Current documented ID selected for the curated shortlist. |
| minimax_cn | polish | `MiniMax-M2.7` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| minimax_cn | polish | `MiniMax-M2.7-highspeed` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| minimax_cn | polish | `MiniMax-M3` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| minimax_intl | polish | `MiniMax-M2.7` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| minimax_intl | polish | `MiniMax-M2.7-highspeed` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| minimax_intl | polish | `MiniMax-M3` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| mlxServer | polish | `mlx-community/Llama-3.3-70B-Instruct-4bit` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| mlxServer | polish | `mlx-community/Mistral-Small-24B-Instruct-2501-4bit` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| mlxServer | polish | `mlx-community/Qwen3-4B-Instruct-2507-4bit` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| mlxServer | polish | `mlx-community/Qwen3.5-4B-MLX-4bit` | Added recommendation | Current documented ID selected for the curated shortlist. |
| mlxServer | polish | `mlx-community/Qwen3.5-9B-MLX-4bit` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| mlxServer | polish | `mlx-community/gemma-3-4b-it-4bit` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| ollama | polish | `deepseek-r1:8b` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| ollama | polish | `gemma3:4b` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| ollama | polish | `llama3.1:8b` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| ollama | polish | `llama4:16x17b` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| ollama | polish | `mistral:7b` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| ollama | polish | `qwen3.5:4b` | Added recommendation | Current documented ID selected for the curated shortlist. |
| ollama | polish | `qwen3.5:9b` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| ollama | polish | `qwen3:8b` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| openai | polish | `gpt-5.4-mini` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| openai | polish | `gpt-5.4-nano` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| openai | polish | `gpt-5.6-luna` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| openai | polish | `gpt-5.6-sol` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| openai | polish | `gpt-6-astra` | Added recommendation | Current documented ID selected for the curated shortlist. |
| openai | stt | `gpt-4o-mini-transcribe` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| openai | stt | `gpt-4o-transcribe` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| openai | stt | `gpt-4o-transcribe-diarize` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| openai | stt | `gpt-transcribe` | Added recommendation | Current documented ID selected for the curated shortlist. |
| openai | stt | `whisper-1` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| openrouter | stt | `openai/whisper-large-v3` | Unavailable capability | Protocol/runtime not integrated or not confirmed; identity retained. |
| openrouter | stt | `qwen/qwen3-asr-flash-2026-02-10` | Unavailable capability | Protocol/runtime not integrated or not confirmed; identity retained. |
| qianfan | polish | `ernie-4.5-turbo-128k` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| qwen | polish | `qwen3.6-flash` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| qwen | polish | `qwen3.7-max` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| qwen | polish | `qwen3.7-plus` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| qwen | polish | `qwen3.8-flash` | Added recommendation | Current documented ID selected for the curated shortlist. |
| qwen | polish | `qwen3.8-max` | Added recommendation | Current documented ID selected for the curated shortlist. |
| qwen | stt | `fun-asr` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| qwen | stt | `paraformer-realtime-v2` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| qwen | stt | `qwen3-asr-flash` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| qwen | stt | `qwen3-asr-flash-realtime` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| sherpa | stt | `fire-red-asr2` | Unavailable capability | Protocol/runtime not integrated or not confirmed; identity retained. |
| sherpa | stt | `sensevoice-small` | Unavailable capability | Protocol/runtime not integrated or not confirmed; identity retained. |
| sherpa | stt | `zipformer-en` | Unavailable capability | Protocol/runtime not integrated or not confirmed; identity retained. |
| siliconflow | polish | `Qwen/Qwen2.5-72B-Instruct` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| siliconflow | polish | `Qwen/Qwen3-8B` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| siliconflow | polish | `Qwen/Qwen3.5-4B` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| siliconflow | polish | `deepseek-ai/DeepSeek-V3` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| siliconflow | polish | `deepseek-ai/DeepSeek-V3.1-Terminus` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| siliconflow | polish | `deepseek-ai/DeepSeek-V4-Flash` | Added recommendation | Current documented ID selected for the curated shortlist. |
| siliconflow | stt | `FunAudioLLM/SenseVoiceSmall` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| siliconflow | stt | `TeleAI/TeleSpeechASR` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| together | polish | `LiquidAI/LFM2.5-8B-A1B` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| together | polish | `Qwen/Qwen3.5-9B` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| together | polish | `Qwen/Qwen3.7-Plus` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| together | polish | `deepseek-ai/DeepSeek-V4-Pro` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| together | polish | `meta-llama/Llama-3.3-70B-Instruct-Turbo` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| together | stt | `nvidia/parakeet-tdt-0.6b-v3` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| together | stt | `openai/whisper-large-v3` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| volcengine | polish | `doubao-seed-1-6-flash-250828` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| volcengine | polish | `doubao-seed-1-8-251228` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| volcengine | polish | `doubao-seed-2-1-pro-260628` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| volcengine | polish | `doubao-seed-2-1-turbo-260628` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| xai | polish | `grok-4.3` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| xai | polish | `grok-4.5` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| xai | polish | `grok-4.6` | Added recommendation | Current documented ID selected for the curated shortlist. |
| zhipu | polish | `glm-4.6` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| zhipu | polish | `glm-4.7-flash` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |
| zhipu | polish | `glm-5.1` | Hidden compatibility | Superseded shortlist or unsupported specialized path; preserve saved ID/overrides. |
| zhipu | polish | `glm-5.2` | Maintained recommendation | Retained capable, economical or compatible fallback choice. |

Dynamic OpenRouter polish and custom endpoint models have no fixed static list. Their current defaults are `openai/gpt-5.4-mini` and custom `whisper-1` / `gpt-5.4-mini`; user IDs remain editable. No static model metadata was deleted if the table contains no Removed metadata rows.
