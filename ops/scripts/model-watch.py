#!/usr/bin/env python3
"""model-watch — detect model-catalog drift for Vowrite's providers.json.

F-082 established model update detection; F-085 adds normalization and
deprecation guardrails. Network signal sources:

  1. OpenRouter public catalog (`GET /api/v1/models`, no key) — cross-vendor
     "new model released" signal with created timestamps and pricing.
  2. Cerebras's public direct model catalog (no key).
  3. Each provider's own OpenAI-compatible `GET /models` (API key from env,
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
import fcntl
import hashlib
import json
import os
import socket
import sys
import tempfile
import urllib.error
import urllib.request
from math import ceil
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
PROVIDERS_JSON = REPO_ROOT / "VowriteKit/Sources/VowriteKit/Resources/providers.json"
STATE_PATH = REPO_ROOT / "ops/model-watch/state.json"
DEPRECATIONS_PATH = REPO_ROOT / "ops/model-watch/deprecations.json"

OPENROUTER_URL = "https://openrouter.ai/api/v1/models"
CEREBRAS_PUBLIC_MODELS_URL = "https://api.cerebras.ai/public/v1/models"
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

# Alias normalization is deliberately source-scoped.  OpenRouter documents
# terminal ``:batch`` variants; a similarly shaped direct-provider ID is not
# assumed to have the same semantics.
ALIAS_SUFFIXES = {
    "openrouter": {":batch": "batch"},
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


def signal_namespace(source):
    """Return the provenance namespace for a model signal source."""
    if source == "openrouter":
        return "aggregator:openrouter"
    return "direct:%s" % source


def signal_provider_hint(source, raw_id):
    """Return a research hint, never a direct-provider identity assertion."""
    if source == "openrouter" and "/" in raw_id:
        return raw_id.split("/", 1)[0]
    return source


def normalize_model_signal(source, raw_id):
    """Normalize one signal while retaining its source and raw evidence."""
    if not isinstance(source, str) or not source:
        raise ValueError("signal source must be a non-empty string")
    if not isinstance(raw_id, str) or not raw_id:
        raise ValueError("model signal ID must be a non-empty string")

    canonical_id = raw_id
    variant = None
    for suffix, variant_name in ALIAS_SUFFIXES.get(source, {}).items():
        if raw_id.endswith(suffix) and len(raw_id) > len(suffix):
            canonical_id = raw_id[:-len(suffix)]
            variant = variant_name
            break

    namespace = signal_namespace(source)
    return {
        "rawID": raw_id,
        "canonicalID": canonical_id,
        "namespace": namespace,
        "variant": variant,
        "providerHint": signal_provider_hint(source, canonical_id),
        "collapsedAliases": [raw_id] if variant else [],
        "signalKey": "%s|%s" % (namespace, canonical_id),
    }


def canonical_discoveries(source, raw_ids, known_raw_ids):
    """Collapse allow-listed aliases and return stable, actionable signals."""
    known_raw = set(known_raw_ids or [])
    known_canonical = {
        normalize_model_signal(source, raw_id)["canonicalID"]
        for raw_id in known_raw
    }
    raw_new = sorted(set(raw_ids or []) - known_raw)
    groups = {}
    suppressed_aliases = []
    collapsed_count = 0

    for raw_id in raw_new:
        signal = normalize_model_signal(source, raw_id)
        if signal["variant"]:
            collapsed_count += 1
        if signal["canonicalID"] in known_canonical:
            if signal["variant"]:
                suppressed_aliases.append(signal["rawID"])
            continue

        key = signal["signalKey"]
        row = groups.setdefault(key, {
            "canonicalID": signal["canonicalID"],
            "namespace": signal["namespace"],
            "providerHint": signal["providerHint"],
            "rawIDs": [],
            "collapsedAliases": [],
        })
        row["rawIDs"].append(signal["rawID"])
        if signal["variant"]:
            row["collapsedAliases"].append(signal["rawID"])

    rows = list(groups.values())
    for row in rows:
        row["rawIDs"].sort()
        row["collapsedAliases"].sort()
    rows.sort(key=lambda row: (row["providerHint"], row["canonicalID"]))
    return {
        "rawNewCount": len(raw_new),
        "collapsedAliasCount": collapsed_count,
        "suppressedAliases": sorted(suppressed_aliases),
        "signals": rows,
    }


def http_get_json(url, headers=None, timeout=25):
    """Return parsed JSON or a stable, non-secret structured source error."""
    req = urllib.request.Request(url)
    req.add_header("User-Agent", USER_AGENT)
    req.add_header("Accept", "application/json")
    req.add_header("Accept-Encoding", "identity")
    for k, v in (headers or {}).items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = resp.read()
    except urllib.error.HTTPError as e:
        return None, {
            "code": "ERROR_HTTP_%d" % e.code,
            "detail": "HTTP %d" % e.code,
        }
    except (TimeoutError, socket.timeout):
        return None, {"code": "ERROR_TIMEOUT", "detail": "request timed out"}
    except urllib.error.URLError as e:
        if isinstance(e.reason, (TimeoutError, socket.timeout)):
            return None, {"code": "ERROR_TIMEOUT", "detail": "request timed out"}
        return None, {"code": "ERROR_NETWORK", "detail": "network request failed"}
    except Exception:
        return None, {"code": "ERROR_NETWORK", "detail": "network request failed"}

    try:
        raw = body.decode("utf-8")
    except UnicodeDecodeError:
        return None, {
            "code": "ERROR_PARSE",
            "detail": "response was not valid UTF-8",
        }

    try:
        return json.loads(raw), None
    except json.JSONDecodeError:
        return None, {
            "code": "ERROR_MALFORMED_JSON",
            "detail": "response was not valid JSON",
        }


class PayloadSchemaError(ValueError):
    """A source responded successfully but with an unknown JSON shape."""


class ManifestError(ValueError):
    """The reviewed deprecation manifest is missing or invalid."""


class StateError(ValueError):
    """The model-watch state is corrupt or uses an unknown schema."""


def parse_utc_datetime(value, field_name):
    if not isinstance(value, str) or not value:
        raise ManifestError("%s must be a non-empty ISO date" % field_name)
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as e:
        raise ManifestError("%s is not a valid ISO date: %s" % (field_name, e))
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def validate_deprecation_manifest(manifest):
    """Validate reviewed facts while allowing a missing suggested replacement."""
    if not isinstance(manifest, dict) or manifest.get("schema") != 1:
        raise ManifestError("unsupported deprecation manifest schema")
    freshness_days = manifest.get("evidenceFreshnessDays")
    if not isinstance(freshness_days, int) or freshness_days <= 0:
        raise ManifestError("evidenceFreshnessDays must be a positive integer")
    entries = manifest.get("deprecations")
    if not isinstance(entries, list):
        raise ManifestError("deprecations must be an array")

    required = (
        "provider", "model", "capability", "retireAt", "scope",
        "unaffectedScope", "sourceURL", "verifiedAt",
    )
    seen = set()
    for index, entry in enumerate(entries):
        if not isinstance(entry, dict):
            raise ManifestError("deprecations[%d] must be an object" % index)
        for field in required:
            if not isinstance(entry.get(field), str) or not entry[field]:
                raise ManifestError(
                    "deprecations[%d].%s must be a non-empty string"
                    % (index, field)
                )
        if entry["capability"] not in ("stt", "polish"):
            raise ManifestError(
                "deprecations[%d].capability must be stt or polish" % index
            )
        if not entry["sourceURL"].startswith("https://"):
            raise ManifestError(
                "deprecations[%d].sourceURL must use https" % index
            )
        parse_utc_datetime(entry["retireAt"], "retireAt")
        parse_utc_datetime(entry["verifiedAt"], "verifiedAt")
        key = (
            entry["provider"], entry["model"], entry["capability"],
            entry["scope"],
        )
        if key in seen:
            raise ManifestError("duplicate deprecation entry: %s" % (key,))
        seen.add(key)
    return manifest


def load_deprecation_manifest(path=DEPRECATIONS_PATH):
    try:
        manifest = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError) as e:
        raise ManifestError("cannot read deprecation manifest: %s" % e)
    return validate_deprecation_manifest(manifest)


def build_catalog_index(providers):
    index = {}
    for provider in providers:
        capabilities = {}
        for capability in ("stt", "polish"):
            capabilities[capability] = set(
                catalog_model_ids({capability: provider.get(capability) or {}})
            )
        index[provider["id"]] = capabilities
    return index


def evaluate_deprecations(manifest, catalog, now=None):
    """Evaluate tier-aware retirement facts without mutating the catalog."""
    validate_deprecation_manifest(manifest)
    now = (now or datetime.now(timezone.utc)).astimezone(timezone.utc)
    freshness_days = manifest["evidenceFreshnessDays"]
    rows = []

    for entry in manifest["deprecations"]:
        retire_at = parse_utc_datetime(entry["retireAt"], "retireAt")
        verified_at = parse_utc_datetime(entry["verifiedAt"], "verifiedAt")
        seconds_remaining = (retire_at - now).total_seconds()
        days_remaining = ceil(seconds_remaining / 86400)
        catalog_ids = catalog.get(entry["provider"], {}).get(
            entry["capability"], set()
        )
        in_catalog = entry["model"] in catalog_ids
        alerts = []

        if in_catalog:
            if seconds_remaining <= 0:
                alerts.append({
                    "code": "BLOCKER_RETIRED",
                    "severity": "BLOCKER",
                })
            elif seconds_remaining <= 7 * 86400:
                alerts.append({"code": "CRITICAL_7D", "severity": "CRITICAL"})
            elif seconds_remaining <= 14 * 86400:
                alerts.append({"code": "URGENT_14D", "severity": "URGENT"})
            elif seconds_remaining <= 30 * 86400:
                alerts.append({"code": "WARNING_30D", "severity": "WARNING"})
            if not entry.get("replacement"):
                alerts.append({
                    "code": "WARNING_MISSING_REPLACEMENT",
                    "severity": "WARNING",
                })

        evidence_age_days = (now.date() - verified_at.date()).days
        if evidence_age_days > freshness_days:
            alerts.append({
                "code": "WARNING_STALE_EVIDENCE",
                "severity": "WARNING",
            })

        rows.append({
            "provider": entry["provider"],
            "model": entry["model"],
            "capability": entry["capability"],
            "retireAt": entry["retireAt"],
            "daysRemaining": days_remaining,
            "scope": entry["scope"],
            "unaffectedScope": entry["unaffectedScope"],
            "replacement": entry.get("replacement"),
            "sourceURL": entry["sourceURL"],
            "verifiedAt": entry["verifiedAt"],
            "evidenceAgeDays": evidence_age_days,
            "inCatalog": in_catalog,
            "alerts": alerts,
        })

    rows.sort(key=lambda row: (
        row["provider"], row["retireAt"], row["model"], row["scope"]
    ))
    return rows


def validate_complete_model_list(payload, items):
    """Reject empty or explicitly paginated model lists as unsafe snapshots."""
    if not items:
        raise PayloadSchemaError("model array was empty")
    if not isinstance(payload, dict):
        return
    if payload.get("has_more") is True or payload.get("hasMore") is True:
        raise PayloadSchemaError("model array was truncated (has more pages)")
    for field in ("next", "next_page", "nextPage", "continuation"):
        if payload.get(field):
            raise PayloadSchemaError("model array was truncated (%s present)" % field)
    for field in ("total", "total_count", "totalCount"):
        total = payload.get(field)
        if isinstance(total, int) and not isinstance(total, bool) and total > len(items):
            raise PayloadSchemaError(
                "model array was truncated (%s=%d, rows=%d)"
                % (field, total, len(items))
            )


def extract_model_ids(payload):
    """Normalize a complete /models response to a sorted ID list."""
    if isinstance(payload, list):
        items = payload
    elif isinstance(payload, dict):
        if "data" in payload:
            items = payload["data"]
        elif "models" in payload:
            items = payload["models"]
        else:
            raise PayloadSchemaError("missing data/models array")
    else:
        raise PayloadSchemaError("top-level payload must be an array or object")
    if not isinstance(items, list):
        raise PayloadSchemaError("data/models must be an array")
    validate_complete_model_list(payload, items)
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
    if not ids:
        raise PayloadSchemaError("model array contained no usable IDs")
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


def fetch_openrouter(timeout, fetch_json=None):
    fetch_json = fetch_json or http_get_json
    payload, err = fetch_json(OPENROUTER_URL, timeout=timeout)
    if err:
        return None, err
    if not isinstance(payload, dict) or not isinstance(payload.get("data"), list):
        return None, {
            "code": "ERROR_SCHEMA",
            "detail": "OpenRouter payload missing data array",
        }
    try:
        validate_complete_model_list(payload, payload["data"])
    except PayloadSchemaError as e:
        return None, {"code": "ERROR_SCHEMA", "detail": str(e)}
    models = {}
    for item in payload["data"]:
        if not isinstance(item, dict):
            continue
        mid = item.get("id")
        if not isinstance(mid, str):
            continue
        models[mid] = item
    if not models:
        return None, {
            "code": "ERROR_SCHEMA",
            "detail": "OpenRouter data array contained no usable model IDs",
        }
    return models, None


def reconcile_providers(providers, timeout, fetch_json=None, environ=None):
    """Fetches each provider's /models where possible.

    Returns list of dicts: {id, status, detail, missing, new_relevant, fetched_ids}.
    status: OK | SKIPPED_MANUAL | SKIPPED_NO_KEY | ERROR_*
    """
    fetch_json = fetch_json or http_get_json
    environ = os.environ if environ is None else environ
    results = []
    for p in providers:
        pid = p["id"]
        base = (p.get("baseURL") or "").rstrip("/")
        entry = {"id": pid, "missing": [], "new_relevant": [], "fetched_ids": None}
        if pid in SKIP_REASONS:
            entry.update(status="SKIPPED_MANUAL", detail=SKIP_REASONS[pid])
            results.append(entry)
            continue
        if not base.startswith("http"):
            entry.update(status="SKIPPED_MANUAL", detail="no HTTP base URL")
            results.append(entry)
            continue

        if pid == "cerebras":
            url = CEREBRAS_PUBLIC_MODELS_URL
            headers = {}
        else:
            env = KEY_ENV.get(pid)
            key = environ.get(env, "") if env else ""
            if not key:
                entry.update(
                    status="SKIPPED_NO_KEY",
                    detail="set %s to enable" % (env or "a key env var"),
                )
                results.append(entry)
                continue
            if pid == "claude":
                headers = {"x-api-key": key, "anthropic-version": "2023-06-01"}
            else:
                headers = {"Authorization": "Bearer %s" % key}
            url = base + "/models"
        payload, err = fetch_json(url, headers=headers, timeout=timeout)
        if err:
            entry.update(status=err["code"], detail=err["detail"])
            results.append(entry)
            continue
        try:
            upstream = extract_model_ids(payload)
        except PayloadSchemaError as e:
            entry.update(status="ERROR_SCHEMA", detail=str(e))
            results.append(entry)
            continue
        upstream_set = set(upstream)
        entry["fetched_ids"] = upstream
        entry["missing"] = [m for m in catalog_model_ids(p) if m not in upstream_set]
        entry.update(status="OK", detail="%d upstream models" % len(upstream))
        results.append(entry)
    return results


def make_state_layer(source, raw_ids):
    raw = sorted(set(raw_ids or []))
    canonical = sorted({
        normalize_model_signal(source, raw_id)["canonicalID"]
        for raw_id in raw
    })
    return {
        "source": source,
        "namespace": signal_namespace(source),
        "raw_ids": raw,
        "canonical_ids": canonical,
    }


def empty_state():
    return {
        "schema": 2,
        "last_run": None,
        "signal_layers": [make_state_layer("openrouter", [])],
    }


def migrate_state_v1(state):
    if not isinstance(state.get("openrouter_known_ids", []), list):
        raise StateError("schema 1 openrouter_known_ids must be an array")
    provider_models = state.get("provider_models", {})
    if not isinstance(provider_models, dict):
        raise StateError("schema 1 provider_models must be an object")

    layers = [make_state_layer("openrouter", state.get("openrouter_known_ids", []))]
    for source, raw_ids in sorted(provider_models.items()):
        if not isinstance(source, str) or not isinstance(raw_ids, list):
            raise StateError("schema 1 provider model layer is invalid")
        layers.append(make_state_layer(source, raw_ids))
    return {
        "schema": 2,
        "last_run": state.get("last_run"),
        "signal_layers": layers,
    }


def validate_state_v2(state):
    if not isinstance(state, dict) or state.get("schema") != 2:
        raise StateError("unsupported model-watch state schema")
    if state.get("last_run") is not None and not isinstance(state["last_run"], str):
        raise StateError("state last_run must be null or a string")
    layers = state.get("signal_layers")
    if not isinstance(layers, list):
        raise StateError("state signal_layers must be an array")

    normalized_layers = []
    seen = set()
    for index, layer in enumerate(layers):
        if not isinstance(layer, dict):
            raise StateError("signal_layers[%d] must be an object" % index)
        source = layer.get("source")
        namespace = layer.get("namespace")
        raw_ids = layer.get("raw_ids")
        canonical_ids = layer.get("canonical_ids")
        if not isinstance(source, str) or not source:
            raise StateError("signal layer source must be a non-empty string")
        if namespace != signal_namespace(source):
            raise StateError("signal layer namespace does not match its source")
        if not isinstance(raw_ids, list) or not all(
            isinstance(item, str) and item for item in raw_ids
        ):
            raise StateError("signal layer raw_ids must contain non-empty strings")
        if not isinstance(canonical_ids, list) or not all(
            isinstance(item, str) and item for item in canonical_ids
        ):
            raise StateError(
                "signal layer canonical_ids must contain non-empty strings"
            )
        key = (source, namespace)
        if key in seen:
            raise StateError("duplicate signal layer for %s" % source)
        seen.add(key)
        normalized = make_state_layer(source, raw_ids)
        if sorted(set(canonical_ids)) != normalized["canonical_ids"]:
            raise StateError("signal layer canonical_ids do not match raw evidence")
        normalized_layers.append(normalized)

    normalized_layers.sort(key=lambda layer: (layer["namespace"], layer["source"]))
    return {
        "schema": 2,
        "last_run": state.get("last_run"),
        "signal_layers": normalized_layers,
    }


def load_state(path=STATE_PATH):
    path = Path(path)
    if not path.exists():
        return empty_state()
    try:
        state = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as e:
        raise StateError("cannot read model-watch state: %s" % e)
    if not isinstance(state, dict):
        raise StateError("model-watch state must be an object")
    if state.get("schema") == 1:
        return migrate_state_v1(state)
    if state.get("schema") == 2:
        return validate_state_v2(state)
    raise StateError("unsupported model-watch state schema")


def state_layer(state, source):
    for layer in state.get("signal_layers", []):
        if layer.get("source") == source:
            return layer
    return make_state_layer(source, [])


def atomic_write_state(path, state, replace_fn=os.replace):
    """Durably replace state with a validated, byte-stable schema-2 snapshot."""
    path = Path(path)
    normalized = validate_state_v2(state)
    payload = json.dumps(normalized, indent=2, ensure_ascii=False) + "\n"
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary_name = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            dir=str(path.parent),
            prefix=".%s." % path.name,
            suffix=".tmp",
            delete=False,
        ) as temporary:
            temporary_name = temporary.name
            temporary.write(payload)
            temporary.flush()
            os.fsync(temporary.fileno())
        os.chmod(temporary_name, 0o644)
        replace_fn(temporary_name, path)
        temporary_name = None

        directory_fd = os.open(str(path.parent), os.O_RDONLY)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    finally:
        if temporary_name:
            try:
                os.unlink(temporary_name)
            except FileNotFoundError:
                pass


def maybe_write_state(update_requested, path, state):
    if not update_requested:
        return False
    atomic_write_state(path, state)
    return True


def state_update_lock_path(state_path):
    """Return a stable per-state lock path outside the repository."""
    resolved = str(Path(state_path).resolve())
    digest = hashlib.sha256(resolved.encode("utf-8")).hexdigest()[:24]
    return Path(tempfile.gettempdir()) / (
        "vowrite-model-watch-state-%s.lock" % digest
    )


@contextmanager
def state_update_lock(state_path):
    """Serialize an explicit state update from read through fetch and replace."""
    lock_path = state_update_lock_path(state_path)
    flags = os.O_CREAT | os.O_RDWR
    if hasattr(os, "O_CLOEXEC"):
        flags |= os.O_CLOEXEC
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    file_descriptor = os.open(str(lock_path), flags, 0o600)
    try:
        fcntl.flock(file_descriptor, fcntl.LOCK_EX)
        yield
    finally:
        try:
            fcntl.flock(file_descriptor, fcntl.LOCK_UN)
        finally:
            os.close(file_descriptor)


def build_state_snapshot(state, now_iso, openrouter_models, openrouter_err, recon):
    """Build schema-2 state, preserving any source that did not reconcile."""
    validated = validate_state_v2(state)
    layers = {
        (layer["source"], layer["namespace"]): layer
        for layer in validated["signal_layers"]
    }
    if not openrouter_err:
        layer = make_state_layer("openrouter", openrouter_models.keys())
        layers[(layer["source"], layer["namespace"])] = layer
    for result in recon:
        if result.get("status") == "OK" and result.get("fetched_ids") is not None:
            layer = make_state_layer(result["id"], result["fetched_ids"])
            layers[(layer["source"], layer["namespace"])] = layer
    snapshot = {
        "schema": 2,
        "last_run": now_iso,
        "signal_layers": list(layers.values()),
    }
    return validate_state_v2(snapshot)


def watched_openrouter_ids(openrouter_models):
    return sorted(
        model_id
        for model_id in openrouter_models
        if any(model_id.startswith(prefix) for prefix in WATCH_PREFIXES)
    )


def build_report(
    now_iso,
    state,
    openrouter_models,
    openrouter_err,
    recon,
    deprecations,
    limit_new,
    show_aliases=False,
):
    lines = ["# Model Watch Report — %s" % now_iso[:10], ""]
    findings = False

    # Section 1 — OpenRouter cross-vendor signal.
    lines.append("## 1. Canonical discoveries (OpenRouter signal)")
    lines += [
        "",
        "Namespace: `aggregator:openrouter`. Provider hints are research aids;",
        "an aggregator signal never proves or generates a direct-provider API ID.",
    ]
    if openrouter_err:
        lines += [
            "",
            "⚠️ OpenRouter catalog unavailable: `%s` (%s)"
            % (openrouter_err["code"], openrouter_err["detail"]),
            "",
        ]
    else:
        known_layer = state_layer(state, "openrouter")
        discovery = canonical_discoveries(
            "openrouter",
            watched_openrouter_ids(openrouter_models),
            known_layer["raw_ids"],
        )
        action_rows = discovery["signals"]
        lines += [
            "",
            "Normalization: %d raw new signals -> %d canonical actions; "
            "%d allow-listed aliases collapsed."
            % (
                discovery["rawNewCount"],
                len(action_rows),
                discovery["collapsedAliasCount"],
            ),
        ]
        if not action_rows:
            lines += ["", "No canonical discoveries from watched vendors.", ""]
        else:
            findings = True
            lines += [
                "",
                "| Released | Canonical ID | Provider hint (research only) | Namespace | Ctx | $/1M in | $/1M out | Kind |",
                "|---|---|---|---|---|---|---|---|",
            ]
            for row in action_rows[:limit_new]:
                representative_id = row["canonicalID"]
                if representative_id not in openrouter_models:
                    representative_id = row["rawIDs"][0]
                item = openrouter_models.get(representative_id) or {}
                created = item.get("created") or 0
                date = (
                    datetime.fromtimestamp(created, tz=timezone.utc).strftime("%Y-%m-%d")
                    if created else "?"
                )
                pricing = item.get("pricing") or {}
                arch = item.get("architecture") or {}
                modality = arch.get("modality") or ",".join(
                    arch.get("input_modalities") or []
                )
                kind = classify(row["canonicalID"])
                if "audio" in (modality or "") and kind != "stt":
                    kind += "+audio-in"
                lines.append(
                    "| %s | `%s` | %s | `%s` | %s | %s | %s | %s |"
                    % (
                        date,
                        row["canonicalID"],
                        row["providerHint"],
                        row["namespace"],
                        item.get("context_length") or "?",
                        per_1m(pricing.get("prompt")),
                        per_1m(pricing.get("completion")),
                        kind,
                    )
                )
            if len(action_rows) > limit_new:
                lines.append("")
                lines.append(
                    "… and %d more (raise --limit-new to see all)."
                    % (len(action_rows) - limit_new)
                )
            lines.append("")

        if show_aliases and discovery["collapsedAliasCount"]:
            aliases = list(discovery["suppressedAliases"])
            for row in action_rows:
                aliases.extend(row["collapsedAliases"])
            lines += [
                "### Collapsed raw aliases (audit view)",
                "",
                ", ".join("`%s`" % alias for alias in sorted(set(aliases))),
                "",
            ]

    # Section 2 — per-provider reconciliation.
    lines.append("## 2. Provider `/models` reconciliation")
    lines.append("")
    known_sources = {
        layer["source"] for layer in state.get("signal_layers", [])
    }
    for r in sorted(recon, key=lambda row: row["id"]):
        pid = r["id"]
        if r["status"] == "OK":
            known = set(state_layer(state, pid)["raw_ids"])
            new_relevant = []
            if pid in known_sources and r["fetched_ids"] is not None:
                new_relevant = [
                    model_id for model_id in r["fetched_ids"]
                    if model_id not in known and classify(model_id) != "other"
                ]
            marker = "✅" if not (r["missing"] or new_relevant) else "⚠️"
            lines.append(
                "- %s **%s** — `OK`, namespace `direct:%s`; %s"
                % (marker, pid, pid, r["detail"])
            )
            if pid not in known_sources:
                lines.append(
                    "  - no curated direct-source baseline; aggregator data was not used"
                )
            if r["missing"]:
                findings = True
                lines.append(
                    "  - possibly retired (in catalog, not direct upstream): %s"
                    % ", ".join("`%s`" % model_id for model_id in r["missing"])
                )
            if new_relevant:
                findings = True
                shown = new_relevant[:20]
                more = len(new_relevant) - len(shown)
                lines.append(
                    "  - new direct upstream since baseline: %s%s"
                    % (
                        ", ".join("`%s`" % model_id for model_id in shown),
                        (" … +%d more" % more) if more > 0 else "",
                    )
                )
        else:
            lines.append(
                "- ⏭️ **%s** — `%s` (%s)" % (pid, r["status"], r["detail"])
            )
    lines.append("")

    # Section 3 — reviewed, tier-aware deprecation facts.
    lines += [
        "## 3. Tier-aware deprecation guardrails",
        "",
        "Replacements below are reviewed suggestions only; the watcher never migrates the catalog.",
        "",
        "| Alert | Provider / model | Retires | Scope | Unaffected scope | Replacement | Evidence |",
        "|---|---|---|---|---|---|---|",
    ]
    severity_counts = {"BLOCKER": 0, "CRITICAL": 0, "URGENT": 0, "WARNING": 0}
    for row in deprecations:
        for alert in row["alerts"]:
            severity_counts[alert["severity"]] += 1
        if row["alerts"]:
            findings = True
            alert_text = ", ".join(alert["code"] for alert in row["alerts"])
        elif row["inCatalog"]:
            alert_text = "CLEAR"
        else:
            alert_text = "MONITORED_NOT_IN_CATALOG"
        replacement = (
            "reviewed suggestion: `%s`" % row["replacement"]
            if row["replacement"] else "missing"
        )
        lines.append(
            "| %s | `%s/%s` | %s | `%s` | `%s` | %s | [%s](%s), verified %s |"
            % (
                alert_text,
                row["provider"],
                row["model"],
                row["retireAt"],
                row["scope"],
                row["unaffectedScope"],
                replacement,
                row["provider"],
                row["sourceURL"],
                row["verifiedAt"],
            )
        )
    if not deprecations:
        lines.append("| CLEAR | No reviewed deprecation facts | — | — | — | — | — |")
    lines += [
        "",
        "Alert summary: BLOCKER %(BLOCKER)d; CRITICAL %(CRITICAL)d; "
        "URGENT %(URGENT)d; WARNING %(WARNING)d." % severity_counts,
        "",
    ]

    # Section 4 — pointer to procedure.
    lines += [
        "## 4. Next steps",
        "",
        "Findings are **signals, not catalog edits**. Follow `ops/MODEL_UPDATE_PLAYBOOK.md`:",
        "verify against official provider docs, curate `providers.json`, build + test,",
        "sync the website (Track A), then explicitly re-baseline with",
        "`model-watch.py --update-state`. Never derive a direct API ID from an",
        "aggregator signal only.",
        "",
    ]
    return "\n".join(lines), findings


def load_providers(path=PROVIDERS_JSON):
    try:
        payload = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError) as e:
        raise PayloadSchemaError("cannot read provider catalog: %s" % e)
    if not isinstance(payload, dict) or not isinstance(payload.get("providers"), list):
        raise PayloadSchemaError("provider catalog missing providers array")
    if not all(
        isinstance(provider, dict)
        and isinstance(provider.get("id"), str)
        and provider["id"]
        for provider in payload["providers"]
    ):
        raise PayloadSchemaError("provider catalog contains an invalid provider")
    return payload["providers"]


def run_model_watch(
    args,
    fetch_json,
    now,
    stdout,
    stderr,
    providers_path,
    state_path,
    deprecations_path,
):
    try:
        providers = load_providers(providers_path)
        state = load_state(state_path)
        manifest = load_deprecation_manifest(deprecations_path)
    except (PayloadSchemaError, StateError, ManifestError) as e:
        print("fatal: %s" % e, file=stderr)
        return 1

    now = (now or datetime.now(timezone.utc)).astimezone(timezone.utc)
    now_iso = now.isoformat(timespec="seconds")

    openrouter_models, openrouter_err = fetch_openrouter(
        args.timeout, fetch_json=fetch_json
    )
    recon = reconcile_providers(
        providers, args.timeout, fetch_json=fetch_json
    )
    deprecations = evaluate_deprecations(
        manifest, build_catalog_index(providers), now=now
    )

    ok_sources = sum(1 for result in recon if result["status"] == "OK")
    ok_sources += 0 if openrouter_err else 1
    report, findings = build_report(
        now_iso,
        state,
        openrouter_models or {},
        openrouter_err,
        recon,
        deprecations,
        args.limit_new,
        show_aliases=args.show_aliases,
    )

    print(report, file=stdout)
    if args.report:
        try:
            Path(args.report).write_text(report + "\n", encoding="utf-8")
        except OSError as e:
            print("fatal: cannot write report: %s" % e, file=stderr)
            return 1

    if args.update_state:
        if ok_sources == 0:
            print("state not written: no network source succeeded", file=stderr)
        else:
            snapshot = build_state_snapshot(
                state, now_iso, openrouter_models or {}, openrouter_err, recon
            )
            maybe_write_state(True, state_path, snapshot)
            print("state written: %s" % state_path, file=stderr)

    if findings:
        return 10
    if ok_sources == 0:
        return 3
    return 0


def main(
    argv=None,
    fetch_json=None,
    now=None,
    stdout=None,
    stderr=None,
    providers_path=PROVIDERS_JSON,
    state_path=STATE_PATH,
    deprecations_path=DEPRECATIONS_PATH,
):
    stdout = stdout or sys.stdout
    stderr = stderr or sys.stderr
    ap = argparse.ArgumentParser(description="Detect provider model catalog drift.")
    ap.add_argument("--report", metavar="FILE", help="also write the markdown report here")
    ap.add_argument("--update-state", action="store_true",
                    help="write ops/model-watch/state.json from this run's fetches")
    ap.add_argument("--show-aliases", action="store_true",
                    help="include collapsed raw aliases for audit")
    ap.add_argument("--timeout", type=int, default=25, help="per-request timeout (s)")
    ap.add_argument("--limit-new", type=int, default=40,
                    help="max rows in the OpenRouter new-model table")
    args = ap.parse_args(argv)

    run_args = (
        args,
        fetch_json,
        now,
        stdout,
        stderr,
        providers_path,
        state_path,
        deprecations_path,
    )
    if not args.update_state:
        return run_model_watch(*run_args)

    try:
        with state_update_lock(state_path):
            return run_model_watch(*run_args)
    except OSError as e:
        print("fatal: cannot coordinate state update: %s" % e, file=stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
