#!/usr/bin/env python3
"""model-watch — detect model-catalog drift for Vowrite's providers.json.

Part of F-082 (model update architecture). Two signal sources:

  1. OpenRouter public catalog (`GET /api/v1/models`, no key) — cross-vendor
     "new model released" signal with created timestamps and pricing.
  2. Each provider's own OpenAI-compatible `GET /models` (API key from env,
     source skipped when the env var is unset) — exact reconciliation of the
     model IDs we ship in providers.json. Catalog IDs missing upstream are
     flagged as possibly retired.

State (ops/model-watch/state.json, committed) holds the last curated snapshot;
a run reports only what changed since. After curating providers.json, run
`--update-state` and commit the new baseline. Full procedure:
ops/MODEL_UPDATE_PLAYBOOK.md.

Usage:
  python3 ops/scripts/model-watch.py                 # report to stdout
  python3 ops/scripts/model-watch.py --report FILE   # also write markdown file
  python3 ops/scripts/model-watch.py --update-state  # re-baseline state.json

Exit codes: 0 = no drift, 10 = findings, 3 = no source reachable, 1 = fatal.
Stdlib only (Python >= 3.9); safe on macOS system python3 and ubuntu runners.
"""

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
PROVIDERS_JSON = REPO_ROOT / "VowriteKit/Sources/VowriteKit/Resources/providers.json"
STATE_PATH = REPO_ROOT / "ops/model-watch/state.json"

OPENROUTER_URL = "https://openrouter.ai/api/v1/models"
USER_AGENT = "vowrite-model-watch/1 (+https://vowrite.com)"

# providers.json id -> env var holding that provider's API key.
# The /models URL is derived from the provider's baseURL in providers.json,
# so a base-URL change in the catalog is picked up automatically.
KEY_ENV = {
    "openai": "OPENAI_API_KEY",
    "groq": "GROQ_API_KEY",
    "deepseek": "DEEPSEEK_API_KEY",
    "together": "TOGETHER_API_KEY",
    "siliconflow": "SILICONFLOW_API_KEY",
    "kimi": "MOONSHOT_API_KEY",
    "qwen": "DASHSCOPE_API_KEY",
    "gemini": "GEMINI_API_KEY",
    "zhipu": "ZHIPU_API_KEY",
    "qianfan": "QIANFAN_API_KEY",
    "claude": "ANTHROPIC_API_KEY",
    "xai": "XAI_API_KEY",
    "cerebras": "CEREBRAS_API_KEY",
    "volcengine": "ARK_API_KEY",
    "minimax_intl": "MINIMAX_INTL_API_KEY",
    "minimax_cn": "MINIMAX_CN_API_KEY",
}

# Providers we never reconcile via GET /models, with the reason shown in the report.
SKIP_REASONS = {
    "openrouter": "aggregator — its public catalog is signal source #1",
    "deepgram": "native (non-OpenAI) API shape — reconcile manually via docs",
    "iflytek": "WebSocket protocol, no HTTP model listing",
    "sherpa": "offline local models, managed by SherpaModelManager",
    "ollama": "local runtime",
    "mlxServer": "local runtime",
    "custom": "user-defined endpoint",
}

# OpenRouter vendor prefix -> label used in the report (usually our provider id).
WATCH_PREFIXES = {
    "openai/": "openai",
    "anthropic/": "claude",
    "google/": "gemini",
    "deepseek/": "deepseek",
    "qwen/": "qwen / siliconflow",
    "moonshotai/": "kimi",
    "z-ai/": "zhipu",
    "minimax/": "minimax",
    "bytedance/": "volcengine (doubao)",
    "baidu/": "qianfan",
    "mistralai/": "mistral — not in catalog yet",
    "x-ai/": "xai",
    "meta-llama/": "llama (groq / together)",
}

# Model-id classification. STT wins over the exclusion list ("whisper" is in both).
STT_KEYWORDS = (
    "whisper", "transcribe", "transcription", "asr", "speech", "voxtral",
    "paraformer", "sensevoice", "canary", "parakeet", "stt", "fun-asr",
)
NON_POLISH_KEYWORDS = (
    "embed", "tts", "image", "dall-e", "moderation", "rerank", "guard",
    "ocr", "video", "sora", "realtime", "audio", "voice", "music", "robotics",
)


def http_get_json(url, headers=None, timeout=25):
    """Returns (parsed_json, None) on success, (None, error_string) on failure."""
    req = urllib.request.Request(url)
    req.add_header("User-Agent", USER_AGENT)
    req.add_header("Accept", "application/json")
    req.add_header("Accept-Encoding", "identity")
    for k, v in (headers or {}).items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode("utf-8")), None
    except urllib.error.HTTPError as e:
        return None, "HTTP %d" % e.code
    except Exception as e:  # URLError, timeout, JSON decode, ...
        return None, str(e)[:120]


def extract_model_ids(payload):
    """Normalizes the three common /models response shapes to a sorted id list."""
    if isinstance(payload, list):
        items = payload
    elif isinstance(payload, dict):
        items = payload.get("data") or payload.get("models") or []
    else:
        items = []
    ids = set()
    for item in items:
        if isinstance(item, str):
            mid = item
        elif isinstance(item, dict):
            mid = item.get("id") or item.get("model") or item.get("name")
        else:
            continue
        if isinstance(mid, str) and mid:
            # Gemini's OpenAI-compat layer prefixes ids with "models/".
            ids.add(mid[7:] if mid.startswith("models/") else mid)
    return sorted(ids)


def classify(model_id):
    low = model_id.lower()
    if any(k in low for k in STT_KEYWORDS):
        return "stt"
    if any(k in low for k in NON_POLISH_KEYWORDS):
        return "other"
    return "polish"


def catalog_model_ids(provider):
    ids = []
    for section in ("stt", "polish"):
        cfg = provider.get(section) or {}
        for m in cfg.get("models") or []:
            if m.get("id"):
                ids.append(m["id"])
    return ids


def per_1m(price_str):
    """OpenRouter pricing is USD per token (string). Returns display $/1M."""
    try:
        v = float(price_str) * 1_000_000
    except (TypeError, ValueError):
        return "?"
    if v == 0:
        return "0"
    return ("%.4g" % v)


def fetch_openrouter(timeout):
    payload, err = http_get_json(OPENROUTER_URL, timeout=timeout)
    if err:
        return None, err
    models = {}
    for item in payload.get("data", []):
        mid = item.get("id")
        if not isinstance(mid, str):
            continue
        models[mid] = item
    return models, None


def reconcile_providers(providers, timeout):
    """Fetches each provider's /models where possible.

    Returns list of dicts: {id, status, detail, missing, new_relevant, fetched_ids}.
    status: ok | skipped | no-key | error
    """
    results = []
    for p in providers:
        pid = p["id"]
        base = (p.get("baseURL") or "").rstrip("/")
        entry = {"id": pid, "missing": [], "new_relevant": [], "fetched_ids": None}
        if pid in SKIP_REASONS:
            entry.update(status="skipped", detail=SKIP_REASONS[pid])
            results.append(entry)
            continue
        if not base.startswith("http"):
            entry.update(status="skipped", detail="no HTTP base URL")
            results.append(entry)
            continue
        env = KEY_ENV.get(pid)
        key = os.environ.get(env, "") if env else ""
        if not key:
            entry.update(status="no-key", detail="set %s to enable" % (env or "a key env var"))
            results.append(entry)
            continue
        if pid == "claude":
            headers = {"x-api-key": key, "anthropic-version": "2023-06-01"}
        else:
            headers = {"Authorization": "Bearer %s" % key}
        payload, err = http_get_json(base + "/models", headers=headers, timeout=timeout)
        if err:
            entry.update(status="error", detail=err)
            results.append(entry)
            continue
        upstream = extract_model_ids(payload)
        upstream_set = set(upstream)
        entry["fetched_ids"] = upstream
        entry["missing"] = [m for m in catalog_model_ids(p) if m not in upstream_set]
        entry.update(status="ok", detail="%d upstream models" % len(upstream))
        results.append(entry)
    return results


def load_state():
    if STATE_PATH.exists():
        try:
            return json.loads(STATE_PATH.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            pass
    return {"schema": 1, "last_run": None, "openrouter_known_ids": [], "provider_models": {}}


def build_report(now_iso, state, openrouter_models, openrouter_err, recon, limit_new):
    known_or = set(state.get("openrouter_known_ids") or [])
    known_pm = state.get("provider_models") or {}

    lines = ["# Model Watch Report — %s" % now_iso[:10], ""]
    findings = False

    # Section 1 — OpenRouter cross-vendor signal.
    lines.append("## 1. New upstream releases (OpenRouter signal)")
    if openrouter_err:
        lines += ["", "⚠️ OpenRouter catalog unreachable: %s" % openrouter_err, ""]
    else:
        fresh = []
        for mid, item in openrouter_models.items():
            if mid in known_or:
                continue
            for prefix, label in WATCH_PREFIXES.items():
                if mid.startswith(prefix):
                    fresh.append((item.get("created") or 0, mid, label, item))
                    break
        fresh.sort(reverse=True)
        if not fresh:
            lines += ["", "No new models from watched vendors since last baseline.", ""]
        else:
            findings = True
            lines += ["", "| Released | Model ID | Maps to | Ctx | $/1M in | $/1M out | Kind |",
                      "|---|---|---|---|---|---|---|"]
            for created, mid, label, item in fresh[:limit_new]:
                date = datetime.fromtimestamp(created, tz=timezone.utc).strftime("%Y-%m-%d") if created else "?"
                pricing = item.get("pricing") or {}
                arch = item.get("architecture") or {}
                modality = arch.get("modality") or ",".join(arch.get("input_modalities") or [])
                kind = classify(mid)
                if "audio" in (modality or "") and kind != "stt":
                    kind += "+audio-in"
                lines.append("| %s | `%s` | %s | %s | %s | %s | %s |" % (
                    date, mid, label, item.get("context_length") or "?",
                    per_1m(pricing.get("prompt")), per_1m(pricing.get("completion")), kind))
            if len(fresh) > limit_new:
                lines.append("")
                lines.append("… and %d more (raise --limit-new to see all)." % (len(fresh) - limit_new))
            lines.append("")

    # Section 2 — per-provider reconciliation.
    lines.append("## 2. Provider `/models` reconciliation")
    lines.append("")
    for r in recon:
        pid = r["id"]
        if r["status"] == "ok":
            known = set(known_pm.get(pid) or [])
            if r["fetched_ids"] is not None and known:
                for mid in r["fetched_ids"]:
                    if mid not in known and classify(mid) != "other":
                        r["new_relevant"].append(mid)
            marker = "✅" if not (r["missing"] or r["new_relevant"]) else "⚠️"
            lines.append("- %s **%s** — %s" % (marker, pid, r["detail"]))
            if r["missing"]:
                findings = True
                lines.append("  - possibly retired (in catalog, not upstream): %s"
                             % ", ".join("`%s`" % m for m in r["missing"]))
            if r["new_relevant"]:
                findings = True
                shown = r["new_relevant"][:20]
                more = len(r["new_relevant"]) - len(shown)
                lines.append("  - new upstream since baseline: %s%s"
                             % (", ".join("`%s`" % m for m in shown),
                                (" … +%d more" % more) if more > 0 else ""))
        else:
            lines.append("- ⏭️ %s — %s (%s)" % (pid, r["status"], r["detail"]))
    lines.append("")

    # Section 3 — pointer to procedure.
    lines += [
        "## 3. Next steps",
        "",
        "Findings are **signals, not catalog edits**. Follow `ops/MODEL_UPDATE_PLAYBOOK.md`:",
        "verify against official provider docs, curate `providers.json`, build + test,",
        "sync the website (Track A), then re-baseline with `model-watch.py --update-state`.",
        "",
    ]
    return "\n".join(lines), findings


def main():
    ap = argparse.ArgumentParser(description="Detect provider model catalog drift.")
    ap.add_argument("--report", metavar="FILE", help="also write the markdown report here")
    ap.add_argument("--update-state", action="store_true",
                    help="write ops/model-watch/state.json from this run's fetches")
    ap.add_argument("--timeout", type=int, default=25, help="per-request timeout (s)")
    ap.add_argument("--limit-new", type=int, default=40,
                    help="max rows in the OpenRouter new-model table")
    args = ap.parse_args()

    try:
        providers = json.loads(PROVIDERS_JSON.read_text(encoding="utf-8"))["providers"]
    except (OSError, ValueError, KeyError) as e:
        print("fatal: cannot read %s: %s" % (PROVIDERS_JSON, e), file=sys.stderr)
        return 1

    state = load_state()
    now_iso = datetime.now(timezone.utc).isoformat(timespec="seconds")

    openrouter_models, openrouter_err = fetch_openrouter(args.timeout)
    recon = reconcile_providers(providers, args.timeout)

    ok_sources = sum(1 for r in recon if r["status"] == "ok") + (0 if openrouter_err else 1)
    report, findings = build_report(
        now_iso, state, openrouter_models or {}, openrouter_err, recon, args.limit_new)

    print(report)
    if args.report:
        Path(args.report).write_text(report, encoding="utf-8")

    if args.update_state:
        if not openrouter_err:
            state["openrouter_known_ids"] = sorted(openrouter_models.keys())
        pm = state.setdefault("provider_models", {})
        for r in recon:
            if r["status"] == "ok" and r["fetched_ids"] is not None:
                pm[r["id"]] = r["fetched_ids"]
        state["schema"] = 1
        state["last_run"] = now_iso
        STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
        STATE_PATH.write_text(json.dumps(state, indent=2, ensure_ascii=False) + "\n",
                              encoding="utf-8")
        print("state written: %s" % STATE_PATH, file=sys.stderr)

    if ok_sources == 0:
        return 3
    return 10 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
