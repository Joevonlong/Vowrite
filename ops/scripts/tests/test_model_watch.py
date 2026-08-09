#!/usr/bin/env python3
"""Offline behavioral regression tests for model-watch (F-085)."""

import copy
import hashlib
import importlib.util
import io
import json
import multiprocessing
import os
import sys
import tempfile
import urllib.error
import unittest
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse
from unittest import mock


REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT_PATH = REPO_ROOT / "ops/scripts/model-watch.py"
FIXTURES = REPO_ROOT / "ops/model-watch/fixtures"

spec = importlib.util.spec_from_file_location("vowrite_model_watch", SCRIPT_PATH)
model_watch = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = model_watch
spec.loader.exec_module(model_watch)


def _concurrent_update_worker(
    role,
    providers_path,
    state_path,
    manifest_path,
    first_fetch_entered,
    release_first_fetch,
    second_started,
    second_fetch_entered,
    results,
):
    os.environ["OPENAI_API_KEY"] = "test-only"
    if role == "second":
        second_started.set()

    def fetch(url, headers=None, timeout=25):
        if role == "first":
            if url == model_watch.OPENROUTER_URL:
                first_fetch_entered.set()
                if not release_first_fetch.wait(5):
                    return None, {
                        "code": "ERROR_TIMEOUT",
                        "detail": "test coordination timed out",
                    }
                return {"data": [{"id": "openai/first-process"}]}, None
            return None, {"code": "ERROR_NETWORK", "detail": "offline"}

        if url == model_watch.OPENROUTER_URL:
            second_fetch_entered.set()
            return None, {"code": "ERROR_NETWORK", "detail": "offline"}
        if url.endswith("/models"):
            return {"data": [{"id": "direct-second-process"}]}, None
        return None, {"code": "ERROR_NETWORK", "detail": "offline"}

    code = model_watch.main(
        ["--update-state"],
        fetch_json=fetch,
        now=datetime(2026, 8, 9, tzinfo=timezone.utc),
        stdout=io.StringIO(),
        stderr=io.StringIO(),
        providers_path=Path(providers_path),
        state_path=Path(state_path),
        deprecations_path=Path(manifest_path),
    )
    results.put((role, code))


class SignalNormalizationTests(unittest.TestCase):
    def test_fixed_alias_fixture_reduces_65_raw_signals_to_seven_actions(self):
        fixture = json.loads(
            (FIXTURES / "openrouter-alias-noise-65.json").read_text(encoding="utf-8")
        )

        result = model_watch.canonical_discoveries(
            source="openrouter",
            raw_ids=fixture["signals"],
            known_raw_ids=fixture["knownRawIDs"],
        )

        self.assertEqual(len(fixture["signals"]), 65)
        self.assertEqual(result["rawNewCount"], 65)
        self.assertEqual(len(result["signals"]), 7)
        self.assertEqual(result["collapsedAliasCount"], 58)
        self.assertEqual(
            [row["canonicalID"] for row in result["signals"]],
            [
                "anthropic/claude-opus-5",
                "google/gemini-3.5-flash-lite",
                "google/gemini-3.6-flash",
                "mistralai/voxtral-small-24b-2507",
                "openai/gpt-5.6-terra",
                "qwen/qwen3.7-max",
                "x-ai/grok-4.20",
            ],
        )

    def test_only_terminal_openrouter_batch_alias_is_collapsed(self):
        cases = {
            "vendor/model:batch": ("vendor/model", "batch"),
            "vendor/model:free": ("vendor/model:free", None),
            "vendor/model:thinking": ("vendor/model:thinking", None),
            "vendor/model:batch:free": ("vendor/model:batch:free", None),
        }

        for raw_id, expected in cases.items():
            with self.subTest(raw_id=raw_id):
                signal = model_watch.normalize_model_signal("openrouter", raw_id)
                self.assertEqual(
                    (signal["canonicalID"], signal["variant"]), expected
                )

        direct = model_watch.normalize_model_signal("openai", "vendor/model:batch")
        self.assertEqual(direct["canonicalID"], "vendor/model:batch")
        self.assertIsNone(direct["variant"])

    def test_aggregator_and_direct_signals_have_distinct_namespaces(self):
        aggregator = model_watch.normalize_model_signal(
            "openrouter", "openai/shared-model"
        )
        direct = model_watch.normalize_model_signal("openai", "openai/shared-model")

        self.assertEqual(aggregator["namespace"], "aggregator:openrouter")
        self.assertEqual(direct["namespace"], "direct:openai")
        self.assertNotEqual(aggregator["signalKey"], direct["signalKey"])
        self.assertEqual(aggregator["providerHint"], "openai")
        self.assertEqual(direct["providerHint"], "openai")


class _Response:
    def __init__(self, body):
        self.body = body

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, traceback):
        return False

    def read(self):
        return self.body


class ProviderSourceTests(unittest.TestCase):
    def setUp(self):
        fixture = json.loads(
            (FIXTURES / "provider-sources.json").read_text(encoding="utf-8")
        )
        self.providers = fixture["providers"]

    def test_cerebras_public_catalog_needs_no_key_and_missing_keys_are_visible(self):
        requests = []

        def fetch(url, headers=None, timeout=25):
            requests.append((url, headers or {}))
            return {"data": [{"id": "gpt-oss-120b"}]}, None

        results = model_watch.reconcile_providers(
            self.providers, timeout=1, fetch_json=fetch, environ={}
        )
        by_id = {row["id"]: row for row in results}

        self.assertEqual(by_id["openai"]["status"], "SKIPPED_NO_KEY")
        self.assertEqual(by_id["cerebras"]["status"], "OK")
        self.assertEqual(
            requests,
            [("https://api.cerebras.ai/public/v1/models", {})],
        )

    def test_unknown_provider_payload_schema_fails_safe(self):
        def fetch(url, headers=None, timeout=25):
            return {"unexpected": []}, None

        result = model_watch.reconcile_providers(
            [self.providers[0]],
            timeout=1,
            fetch_json=fetch,
            environ={"OPENAI_API_KEY": "test-only"},
        )[0]

        self.assertEqual(result["status"], "ERROR_SCHEMA")
        self.assertEqual(result["missing"], [])
        self.assertIsNone(result["fetched_ids"])

    def test_http_failures_keep_401_429_timeout_and_malformed_json_distinct(self):
        errors = {}
        cases = {
            "401": urllib.error.HTTPError("https://example.test", 401, "", {}, None),
            "429": urllib.error.HTTPError("https://example.test", 429, "", {}, None),
            "timeout": TimeoutError("timed out"),
        }

        for name, exception in cases.items():
            with self.subTest(name=name), mock.patch.object(
                model_watch.urllib.request, "urlopen", side_effect=exception
            ):
                _, errors[name] = model_watch.http_get_json("https://example.test")

        with mock.patch.object(
            model_watch.urllib.request,
            "urlopen",
            return_value=_Response(b"not-json"),
        ):
            _, errors["malformed"] = model_watch.http_get_json(
                "https://example.test"
            )

        with mock.patch.object(
            model_watch.urllib.request,
            "urlopen",
            return_value=_Response(b"\xff"),
        ):
            _, errors["invalid_utf8"] = model_watch.http_get_json(
                "https://example.test"
            )

        expected = json.loads(
            (FIXTURES / "partial-source-failures.json").read_text(
                encoding="utf-8"
            )
        )["expectedCodes"]
        self.assertEqual(
            {name: error["code"] for name, error in errors.items()},
            expected,
        )

    def test_empty_openrouter_catalog_is_an_untrusted_source_failure(self):
        models, error = model_watch.fetch_openrouter(
            1, fetch_json=lambda url, headers=None, timeout=25: (
                {"data": []}, None
            )
        )

        self.assertIsNone(models)
        self.assertEqual(error["code"], "ERROR_SCHEMA")

    def test_truncated_cerebras_catalog_does_not_emit_missing_models(self):
        def fetch(url, headers=None, timeout=25):
            return {
                "data": [{"id": "gpt-oss-120b"}],
                "has_more": True,
            }, None

        result = model_watch.reconcile_providers(
            [self.providers[1]], timeout=1, fetch_json=fetch, environ={}
        )[0]

        self.assertEqual(result["status"], "ERROR_SCHEMA")
        self.assertEqual(result["missing"], [])
        self.assertIsNone(result["fetched_ids"])


class DeprecationGuardrailTests(unittest.TestCase):
    def setUp(self):
        self.now = datetime(2026, 8, 9, tzinfo=timezone.utc)
        self.fixture = model_watch.load_deprecation_manifest(
            FIXTURES / "deprecation-cases.json"
        )
        self.catalog = {
            "fixture": {
                "polish": {
                    entry["model"]
                    for entry in self.fixture["deprecations"]
                }
            }
        }

    def test_deadline_bands_and_retired_catalog_entry_are_actionable(self):
        rows = model_watch.evaluate_deprecations(
            self.fixture, self.catalog, now=self.now
        )
        alert_codes = {
            row["model"]: [alert["code"] for alert in row["alerts"]]
            for row in rows
        }

        self.assertIn("BLOCKER_RETIRED", alert_codes["retired-model"])
        self.assertIn("CRITICAL_7D", alert_codes["seven-day-model"])
        self.assertIn("URGENT_14D", alert_codes["fourteen-day-model"])
        self.assertIn("WARNING_30D", alert_codes["thirty-day-model"])

    def test_scope_replacement_and_evidence_freshness_are_preserved(self):
        rows = model_watch.evaluate_deprecations(
            self.fixture, self.catalog, now=self.now
        )
        by_model = {row["model"]: row for row in rows}

        scoped = by_model["seven-day-model"]
        self.assertEqual(scoped["scope"], "free_developer")
        self.assertEqual(
            scoped["unaffectedScope"], "committed_spend_enterprise"
        )
        self.assertEqual(scoped["replacement"], "replacement-b")

        self.assertIn(
            "WARNING_MISSING_REPLACEMENT",
            [
                alert["code"]
                for alert in by_model["missing-replacement-model"]["alerts"]
            ],
        )
        self.assertIn(
            "WARNING_STALE_EVIDENCE",
            [
                alert["code"]
                for alert in by_model["stale-evidence-model"]["alerts"]
            ],
        )

    def test_absent_retired_model_is_not_a_false_blocker(self):
        rows = model_watch.evaluate_deprecations(
            self.fixture, {}, now=self.now
        )
        retired = next(row for row in rows if row["model"] == "retired-model")
        self.assertNotIn(
            "BLOCKER_RETIRED", [alert["code"] for alert in retired["alerts"]]
        )

    def test_current_groq_manifest_records_tier_scope_and_replacements(self):
        manifest = model_watch.load_deprecation_manifest(
            REPO_ROOT / "ops/model-watch/deprecations.json"
        )

        self.assertEqual(
            {entry["model"] for entry in manifest["deprecations"]},
            {
                "qwen/qwen3-32b",
                "llama-3.1-8b-instant",
                "llama-3.3-70b-versatile",
            },
        )
        for entry in manifest["deprecations"]:
            self.assertEqual(entry["scope"], "free_developer")
            self.assertEqual(
                entry["unaffectedScope"], "committed_spend_enterprise"
            )
            self.assertTrue(entry["replacement"])

    def test_unknown_manifest_schema_fails_closed(self):
        with self.assertRaises(model_watch.ManifestError):
            model_watch.validate_deprecation_manifest(
                {"schema": 999, "deprecations": []}
            )


class StateMigrationTests(unittest.TestCase):
    def test_v1_state_upgrades_in_memory_without_losing_raw_evidence(self):
        source_path = FIXTURES / "state-v1.json"
        original = source_path.read_bytes()

        state = model_watch.load_state(source_path)

        self.assertEqual(state["schema"], 2)
        openrouter = model_watch.state_layer(state, "openrouter")
        direct = model_watch.state_layer(state, "openai")
        self.assertEqual(
            openrouter["raw_ids"],
            ["openai/known-model", "openai/known-model:batch"],
        )
        self.assertEqual(openrouter["canonical_ids"], ["openai/known-model"])
        self.assertEqual(
            direct["canonical_ids"], ["gpt-direct", "gpt-direct:batch"]
        )
        self.assertEqual(source_path.read_bytes(), original)

    def test_unknown_state_schema_fails_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "state.json"
            path.write_text('{"schema": 999}\n', encoding="utf-8")

            with self.assertRaises(model_watch.StateError):
                model_watch.load_state(path)

    def test_atomic_write_preserves_old_state_when_replace_fails(self):
        state = model_watch.load_state(FIXTURES / "state-v1.json")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "state.json"
            original = b'{"schema": 1, "sentinel": true}\n'
            path.write_bytes(original)

            def fail_replace(source, destination):
                raise OSError("simulated crash before replace")

            with self.assertRaises(OSError):
                model_watch.atomic_write_state(path, state, replace_fn=fail_replace)

            self.assertEqual(path.read_bytes(), original)
            self.assertEqual(list(Path(directory).glob(".state.json.*.tmp")), [])

    def test_identical_state_writes_are_byte_stable(self):
        state = model_watch.load_state(FIXTURES / "state-v1.json")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "state.json"

            model_watch.atomic_write_state(path, state)
            first = path.read_bytes()
            model_watch.atomic_write_state(path, state)

            self.assertEqual(path.read_bytes(), first)

    def test_state_write_is_a_noop_without_explicit_update_flag(self):
        state = model_watch.load_state(FIXTURES / "state-v1.json")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "state.json"

            wrote = model_watch.maybe_write_state(False, path, state)

            self.assertFalse(wrote)
            self.assertFalse(path.exists())

    def test_snapshot_updates_successful_layers_and_preserves_failed_layers(self):
        previous = model_watch.load_state(FIXTURES / "state-v1.json")
        snapshot = model_watch.build_state_snapshot(
            previous,
            "2026-08-09T00:00:00+00:00",
            {"openai/new-openrouter-model": {"id": "openai/new-openrouter-model"}},
            None,
            [
                {
                    "id": "openai",
                    "status": "ERROR_HTTP_429",
                    "fetched_ids": None,
                },
                {
                    "id": "cerebras",
                    "status": "OK",
                    "fetched_ids": ["gpt-oss-120b"],
                },
            ],
        )

        self.assertEqual(
            model_watch.state_layer(snapshot, "openrouter")["raw_ids"],
            ["openai/new-openrouter-model"],
        )
        self.assertEqual(
            model_watch.state_layer(snapshot, "openai")["raw_ids"],
            ["gpt-direct", "gpt-direct:batch"],
        )
        self.assertEqual(
            model_watch.state_layer(snapshot, "cerebras")["raw_ids"],
            ["gpt-oss-120b"],
        )


class ReportTests(unittest.TestCase):
    def setUp(self):
        fixture = json.loads(
            (FIXTURES / "openrouter-alias-noise-65.json").read_text(
                encoding="utf-8"
            )
        )
        self.state = model_watch.migrate_state_v1({
            "schema": 1,
            "last_run": "2026-07-16T00:00:00+00:00",
            "openrouter_known_ids": fixture["knownRawIDs"],
            "provider_models": {},
        })
        self.models = {
            model_id: {
                "id": model_id,
                "created": 1786233600,
                "context_length": 128000,
                "pricing": {"prompt": "0.000001", "completion": "0.000002"},
                "architecture": {"modality": "text->text"},
            }
            for model_id in fixture["signals"]
        }

    def test_report_is_stable_and_alias_noise_is_not_an_action_row(self):
        manifest = model_watch.load_deprecation_manifest(
            REPO_ROOT / "ops/model-watch/deprecations.json"
        )
        deprecations = model_watch.evaluate_deprecations(
            manifest, {}, now=datetime(2026, 8, 9, tzinfo=timezone.utc)
        )

        first, findings = model_watch.build_report(
            "2026-08-09T00:00:00+00:00",
            self.state,
            self.models,
            None,
            [{"id": "openai", "status": "SKIPPED_NO_KEY", "detail": "key absent", "missing": [], "new_relevant": [], "fetched_ids": None}],
            deprecations,
            limit_new=40,
            show_aliases=False,
        )
        second, _ = model_watch.build_report(
            "2026-08-09T00:00:00+00:00",
            self.state,
            self.models,
            None,
            [{"id": "openai", "status": "SKIPPED_NO_KEY", "detail": "key absent", "missing": [], "new_relevant": [], "fetched_ids": None}],
            deprecations,
            limit_new=40,
            show_aliases=False,
        )

        self.assertTrue(findings)
        self.assertEqual(first, second)
        self.assertIn("65 raw new signals -> 7 canonical actions", first)
        self.assertIn("58 allow-listed aliases collapsed", first)
        self.assertNotIn("baseline-01:batch", first)
        self.assertIn("SKIPPED_NO_KEY", first)
        self.assertIn("aggregator signal only", first)

    def test_show_aliases_exposes_suppressed_raw_evidence(self):
        report, _ = model_watch.build_report(
            "2026-08-09T00:00:00+00:00",
            self.state,
            self.models,
            None,
            [],
            [],
            limit_new=40,
            show_aliases=True,
        )

        self.assertIn("openai/baseline-01:batch", report)
        self.assertIn("openai/baseline-58:batch", report)

    def test_retirement_rows_always_state_scope_and_unaffected_scope(self):
        fixture = model_watch.load_deprecation_manifest(
            FIXTURES / "deprecation-cases.json"
        )
        catalog = {
            "fixture": {
                "polish": {
                    entry["model"] for entry in fixture["deprecations"]
                }
            }
        }
        deprecations = model_watch.evaluate_deprecations(
            fixture, catalog, now=datetime(2026, 8, 9, tzinfo=timezone.utc)
        )

        report, findings = model_watch.build_report(
            "2026-08-09T00:00:00+00:00",
            model_watch.empty_state(),
            {},
            {"code": "ERROR_NETWORK", "detail": "offline"},
            [],
            deprecations,
            limit_new=40,
            show_aliases=False,
        )

        self.assertTrue(findings)
        self.assertIn("BLOCKER_RETIRED", report)
        self.assertIn("free_developer", report)
        self.assertIn("committed_spend_enterprise", report)
        self.assertIn("reviewed suggestion", report)


class CLIContractTests(unittest.TestCase):
    def _paths(self, directory, state):
        root = Path(directory)
        providers_path = root / "providers.json"
        state_path = root / "state.json"
        manifest_path = root / "deprecations.json"
        providers_path.write_text(
            json.dumps({
                "providers": [{
                    "id": "openrouter",
                    "baseURL": "https://openrouter.ai/api/v1",
                    "stt": {"models": []},
                    "polish": {"models": []},
                }]
            }) + "\n",
            encoding="utf-8",
        )
        state_path.write_text(
            json.dumps(state, indent=2) + "\n", encoding="utf-8"
        )
        manifest_path.write_text(
            json.dumps({
                "schema": 1,
                "evidenceFreshnessDays": 30,
                "deprecations": [],
            }) + "\n",
            encoding="utf-8",
        )
        return providers_path, state_path, manifest_path

    def test_exit_contract_and_read_only_default(self):
        now = datetime(2026, 8, 9, tzinfo=timezone.utc)
        state = {
            "schema": 2,
            "last_run": "2026-08-01T00:00:00+00:00",
            "signal_layers": [
                model_watch.make_state_layer("openrouter", ["openai/known"])
            ],
        }
        cases = {
            "quiet": ({"data": [{"id": "openai/known"}]}, None, 0),
            "finding": ({"data": [{"id": "openai/new"}]}, None, 10),
            "unavailable": (
                None,
                {"code": "ERROR_NETWORK", "detail": "offline"},
                3,
            ),
        }

        for name, (payload, error, expected_code) in cases.items():
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                paths = self._paths(directory, state)
                original_state = paths[1].read_bytes()

                def fetch(url, headers=None, timeout=25):
                    return payload, error

                code = model_watch.main(
                    [],
                    fetch_json=fetch,
                    now=now,
                    stdout=io.StringIO(),
                    stderr=io.StringIO(),
                    providers_path=paths[0],
                    state_path=paths[1],
                    deprecations_path=paths[2],
                )

                self.assertEqual(code, expected_code)
                self.assertEqual(paths[1].read_bytes(), original_state)

    def test_local_unknown_state_schema_returns_fatal_exit(self):
        with tempfile.TemporaryDirectory() as directory:
            paths = self._paths(directory, {"schema": 999})
            requests = []

            def fetch(url, headers=None, timeout=25):
                requests.append(url)
                return {"data": []}, None

            stderr = io.StringIO()
            code = model_watch.main(
                [],
                fetch_json=fetch,
                now=datetime(2026, 8, 9, tzinfo=timezone.utc),
                stdout=io.StringIO(),
                stderr=stderr,
                providers_path=paths[0],
                state_path=paths[1],
                deprecations_path=paths[2],
            )

            self.assertEqual(code, 1)
            self.assertIn("fatal:", stderr.getvalue())
            self.assertEqual(requests, [])

    def test_actionable_blocker_wins_when_every_network_source_fails(self):
        fixture = json.loads(
            (FIXTURES / "blocker-all-sources-failed.json").read_text(
                encoding="utf-8"
            )
        )
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            providers_path = root / "providers.json"
            state_path = root / "state.json"
            manifest_path = root / "deprecations.json"
            providers_path.write_text(
                json.dumps({"providers": fixture["providers"]}) + "\n",
                encoding="utf-8",
            )
            state_path.write_text(
                json.dumps(fixture["state"]) + "\n", encoding="utf-8"
            )
            manifest_path.write_text(
                json.dumps(fixture["manifest"]) + "\n", encoding="utf-8"
            )

            def fetch(url, headers=None, timeout=25):
                if url == model_watch.OPENROUTER_URL:
                    return None, {
                        "code": "ERROR_NETWORK",
                        "detail": "offline",
                    }
                return None, {"code": "ERROR_HTTP_429", "detail": "HTTP 429"}

            stdout = io.StringIO()
            code = model_watch.main(
                [],
                fetch_json=fetch,
                now=datetime(2026, 8, 9, tzinfo=timezone.utc),
                stdout=stdout,
                stderr=io.StringIO(),
                providers_path=providers_path,
                state_path=state_path,
                deprecations_path=manifest_path,
            )

            self.assertEqual(code, 10)
            self.assertIn("BLOCKER_RETIRED", stdout.getvalue())
            self.assertIn("ERROR_NETWORK", stdout.getvalue())
            self.assertIn("ERROR_HTTP_429", stdout.getvalue())

    def test_explicit_update_preserves_untrusted_public_source_layers(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            providers_path = root / "providers.json"
            state_path = root / "state.json"
            manifest_path = root / "deprecations.json"
            providers_path.write_text(
                json.dumps({
                    "providers": [
                        {
                            "id": "openai",
                            "baseURL": "https://api.openai.com/v1",
                            "stt": {"models": []},
                            "polish": {
                                "models": [{"id": "direct-new"}]
                            },
                        },
                        {
                            "id": "cerebras",
                            "baseURL": "https://api.cerebras.ai/v1",
                            "stt": {"models": []},
                            "polish": {
                                "models": [{"id": "gpt-oss-120b"}]
                            },
                        },
                    ]
                }) + "\n",
                encoding="utf-8",
            )
            initial_state = {
                "schema": 2,
                "last_run": "2026-08-01T00:00:00+00:00",
                "signal_layers": [
                    model_watch.make_state_layer(
                        "openrouter", ["openai/known-public"]
                    ),
                    model_watch.make_state_layer(
                        "cerebras", ["gpt-oss-120b"]
                    ),
                    model_watch.make_state_layer("openai", ["direct-old"]),
                ],
            }
            state_path.write_text(
                json.dumps(initial_state, indent=2) + "\n", encoding="utf-8"
            )
            manifest_path.write_text(
                json.dumps({
                    "schema": 1,
                    "evidenceFreshnessDays": 30,
                    "deprecations": [],
                }) + "\n",
                encoding="utf-8",
            )

            def fetch(url, headers=None, timeout=25):
                if url == model_watch.OPENROUTER_URL:
                    return {"data": []}, None
                if url == model_watch.CEREBRAS_PUBLIC_MODELS_URL:
                    return {
                        "data": [{"id": "gpt-oss-120b"}],
                        "has_more": True,
                    }, None
                return {"data": [{"id": "direct-new"}]}, None

            with mock.patch.dict(
                model_watch.os.environ, {"OPENAI_API_KEY": "test-only"}, clear=True
            ):
                code = model_watch.main(
                    ["--update-state"],
                    fetch_json=fetch,
                    now=datetime(2026, 8, 9, tzinfo=timezone.utc),
                    stdout=io.StringIO(),
                    stderr=io.StringIO(),
                    providers_path=providers_path,
                    state_path=state_path,
                    deprecations_path=manifest_path,
                )

            self.assertEqual(code, 10)
            updated = model_watch.load_state(state_path)
            self.assertEqual(
                model_watch.state_layer(updated, "openrouter")["raw_ids"],
                ["openai/known-public"],
            )
            self.assertEqual(
                model_watch.state_layer(updated, "cerebras")["raw_ids"],
                ["gpt-oss-120b"],
            )
            self.assertEqual(
                model_watch.state_layer(updated, "openai")["raw_ids"],
                ["direct-new"],
            )


class UpdateCoordinationTests(unittest.TestCase):
    def test_two_process_updates_are_serialized_before_fetch_and_do_not_lose_layers(self):
        context = multiprocessing.get_context("fork")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            providers_path = root / "providers.json"
            state_path = root / "state.json"
            manifest_path = root / "deprecations.json"
            providers_path.write_text(
                json.dumps({
                    "providers": [
                        {
                            "id": "openai",
                            "baseURL": "https://api.openai.com/v1",
                            "stt": {"models": []},
                            "polish": {
                                "models": [{"id": "direct-second-process"}]
                            },
                        }
                    ]
                }) + "\n",
                encoding="utf-8",
            )
            state_path.write_text(
                json.dumps({
                    "schema": 2,
                    "last_run": "2026-08-01T00:00:00+00:00",
                    "signal_layers": [
                        model_watch.make_state_layer(
                            "openrouter", ["openai/original"]
                        ),
                        model_watch.make_state_layer(
                            "openai", ["direct-original"]
                        ),
                    ],
                }, indent=2) + "\n",
                encoding="utf-8",
            )
            manifest_path.write_text(
                json.dumps({
                    "schema": 1,
                    "evidenceFreshnessDays": 30,
                    "deprecations": [],
                }) + "\n",
                encoding="utf-8",
            )

            first_fetch_entered = context.Event()
            release_first_fetch = context.Event()
            second_started = context.Event()
            second_fetch_entered = context.Event()
            results = context.Queue()
            common = (
                str(providers_path),
                str(state_path),
                str(manifest_path),
                first_fetch_entered,
                release_first_fetch,
                second_started,
                second_fetch_entered,
                results,
            )
            first = context.Process(
                target=_concurrent_update_worker, args=("first",) + common
            )
            second = context.Process(
                target=_concurrent_update_worker, args=("second",) + common
            )

            first.start()
            self.assertTrue(first_fetch_entered.wait(3))
            second.start()
            self.assertTrue(second_started.wait(3))
            self.assertFalse(second_fetch_entered.wait(0.25))
            release_first_fetch.set()
            self.assertTrue(second_fetch_entered.wait(3))
            first.join(5)
            second.join(5)

            self.assertEqual(first.exitcode, 0)
            self.assertEqual(second.exitcode, 0)
            self.assertEqual(
                sorted([results.get(timeout=1), results.get(timeout=1)]),
                [("first", 10), ("second", 10)],
            )
            state = model_watch.load_state(state_path)
            self.assertEqual(
                model_watch.state_layer(state, "openrouter")["raw_ids"],
                ["openai/first-process"],
            )
            self.assertEqual(
                model_watch.state_layer(state, "openai")["raw_ids"],
                ["direct-second-process"],
            )
            self.assertNotIn("lock", json.dumps(state).lower())
            self.assertNotEqual(
                model_watch.state_update_lock_path(state_path).parent,
                state_path.parent,
            )


class WorkflowContractTests(unittest.TestCase):
    def test_model_watch_runs_are_serialized_without_cancelling_inflight_work(self):
        workflow = (REPO_ROOT / ".github/workflows/model-watch.yml").read_text(
            encoding="utf-8"
        )

        self.assertRegex(
            workflow,
            r"(?m)^concurrency:\n  group: model-watch\n  cancel-in-progress: false$",
        )
        self.assertIn("if: steps.watch.outputs.exit_code == '10'", workflow)


EXPECTED_F086_CANDIDATES = (
    ("openai", "polish", "gpt-5.6-terra", "https://api.openai.com/v1", "target-account-region", "add_non_default_after_acceptance", "pending_external_validation", None),
    ("claude", "polish", "claude-opus-5", "https://api.anthropic.com/v1", "target-account-region", "replace_after_acceptance", "pending_external_validation", "claude-opus-4-8"),
    ("gemini", "polish", "gemini-3.6-flash", "https://generativelanguage.googleapis.com/v1beta/openai", "target-account-region", "replace_after_acceptance", "pending_external_validation", "gemini-3.5-flash"),
    ("gemini", "polish", "gemini-3.5-flash-lite", "https://generativelanguage.googleapis.com/v1beta/openai", "target-account-region", "replace_after_acceptance", "pending_external_validation", "gemini-3.1-flash-lite"),
    ("siliconflow", "polish", "deepseek-ai/DeepSeek-V4-Flash", "https://api.siliconflow.cn/v1", "cn-endpoint-target-account", "add_non_default_after_acceptance", "pending_external_validation", None),
    ("siliconflow", "polish", "deepseek-ai/DeepSeek-V4-Pro", "https://api.siliconflow.cn/v1", "cn-endpoint-target-account", "replace_after_acceptance", "pending_external_validation", "deepseek-ai/DeepSeek-V3.1-Terminus"),
    ("siliconflow", "polish", "zai-org/GLM-5.2", "https://api.siliconflow.cn/v1", "cn-endpoint-target-account", "add_non_default_after_acceptance", "pending_external_validation", None),
    ("qianfan", "polish", "placeholder:ERNIE 5.1 exact direct ID pending", "https://qianfan.baidubce.com/v2", "cn-endpoint-target-account", "add_non_default_after_acceptance", "pending_external_validation", None),
    ("openrouter", "stt", "openai/whisper-large-v3-turbo", "https://openrouter.ai/api/v1", "openrouter-routing-region", "add_non_default_after_acceptance", "pending_external_validation", None),
    ("qwen", "polish", "qwen3.7-flash", "https://dashscope.aliyuncs.com/compatible-mode/v1", "target-dashscope-region", "replace_after_acceptance", "pending_external_validation", "qwen3.6-flash"),
    ("minimax_intl", "polish", "MiniMax-M3", "https://api.minimax.io/v1", "international", "revalidate_existing", "pending_external_validation", None),
    ("minimax_cn", "polish", "MiniMax-M3", "https://api.minimaxi.com/v1", "cn", "revalidate_existing", "pending_external_validation", None),
)

EXPECTED_F086_EXCLUSIONS = [
    "claude-fable-5",
    "claude-mythos-5",
    "kimi-k3",
    "kimi-k2.7-code",
    "qwen3.8-max-preview",
    "ollama:*:cloud",
    "volcengine-seed-evolving",
    "xai-stt-f088",
]

ALLOWED_F086_EVIDENCE_DOMAINS = {
    "developers.openai.com",
    "platform.claude.com",
    "ai.google.dev",
    "www.siliconflow.com",
    "docs.siliconflow.com",
    "cloud.baidu.com",
    "openrouter.ai",
    "help.aliyun.com",
    "platform.minimax.io",
    "platform.minimaxi.com",
}

F086_CANDIDATE_KEYS = {
    "providerID",
    "capability",
    "modelID",
    "modelPlaceholder",
    "displayName",
    "identityStatus",
    "validationScope",
    "action",
    "replacesModelID",
    "incumbentDefault",
    "incumbentModelID",
    "proposedRequestOverrides",
    "firstPartyEvidence",
    "target",
    "liveRequests",
    "evaluation",
    "status",
    "approval",
}

F086_ALLOWED_IDENTITY_STATUSES = {
    "first_party_documented_pending_target_account",
    "pending_exact_direct_id",
    "pending_target_region_visibility",
    "pending_target_account_revalidation",
}

F086_EXPECTED_OVERRIDES = {
    ("openai", "gpt-5.6-terra"): {"reasoning_effort": "none"},
    ("claude", "claude-opus-5"): {"thinking": {"type": "disabled"}, "temperature": None},
    ("gemini", "gemini-3.6-flash"): {"reasoning_effort": "none", "temperature": None},
    ("gemini", "gemini-3.5-flash-lite"): {"reasoning_effort": "none", "temperature": None},
    ("siliconflow", "deepseek-ai/DeepSeek-V4-Flash"): {"thinking": {"type": "disabled"}},
    ("siliconflow", "deepseek-ai/DeepSeek-V4-Pro"): {"thinking": {"type": "disabled"}},
    ("siliconflow", "zai-org/GLM-5.2"): {"thinking": {"type": "disabled"}},
    ("qianfan", "ERNIE 5.1 exact direct ID pending"): None,
    ("openrouter", "openai/whisper-large-v3-turbo"): None,
    ("qwen", "qwen3.7-flash"): {"enable_thinking": False},
    ("minimax_intl", "MiniMax-M3"): {"thinking": {"type": "disabled"}},
    ("minimax_cn", "MiniMax-M3"): {"thinking": {"type": "disabled"}},
}

F086_PRODUCTION_ROOTS = (
    "VowriteKit/Sources",
    "VowriteMac/Sources",
    "VowriteIOS/Sources",
    "VowriteKeyboard/Sources",
)

F086_ACTIVATION_TOKENS = (
    "catalog-refresh-2026-08-v1",
    "providerCatalogRefresh.migrationID",
    "providerCatalogRefresh.rulesetHash",
    "ProviderModelMigration202608",
    "ProviderCatalogRefreshMigration202608",
    "ProviderCatalogRefreshRules",
    "ProviderModelRequestResolver",
)

F084_ALLOWED_SHARED_MIGRATION_SYMBOL_OCCURRENCES = {
    "VowriteKit/Sources/VowriteKit/Config/ProviderModelMigration202608.swift": 1,
    "VowriteKit/Sources/VowriteKit/Config/ProviderModelMigration202608+Execution.swift": 1,
    "VowriteKit/Sources/VowriteKit/Config/ProviderModelMigration202608+Journal.swift": 1,
    "VowriteKit/Sources/VowriteKit/Config/ProviderModelMigration202608+JournalValidation.swift": 1,
    "VowriteMac/Sources/App/VowriteApp.swift": 1,
    "VowriteIOS/Sources/App/VowriteApp.swift": 1,
    "VowriteKeyboard/Sources/KeyboardViewController.swift": 1,
}


def find_f086_activation_violations(repo_root):
    repo_root = Path(repo_root)
    violations = []
    excluded_parts = {"tests", "fixtures", "docs", "documentation", ".build", "build"}
    pending_source_ids = {
        row[2]
        for row in EXPECTED_F086_CANDIDATES
        if not row[2].startswith("placeholder:") and row[5] != "revalidate_existing"
    }
    pending_source_ids.add("ERNIE 5.1")
    providers_path = (
        repo_root / "VowriteKit/Sources/VowriteKit/Resources/providers.json"
    )

    for relative_root in F086_PRODUCTION_ROOTS:
        source_root = repo_root / relative_root
        if not source_root.exists():
            continue
        for path in source_root.rglob("*"):
            if not path.is_file():
                continue
            relative = path.relative_to(repo_root)
            if any(part.lower() in excluded_parts for part in relative.parts):
                continue
            if path.suffix.lower() == ".md":
                continue
            source = path.read_text(encoding="utf-8", errors="ignore")
            for token in F086_ACTIVATION_TOKENS:
                if token == "ProviderModelMigration202608":
                    actual_count = source.count(token)
                    expected_count = F084_ALLOWED_SHARED_MIGRATION_SYMBOL_OCCURRENCES.get(
                        str(relative), 0
                    )
                    if actual_count != expected_count:
                        violations.append(
                            f"{relative}: shared migration symbol count "
                            f"{actual_count}, expected F-084 count {expected_count}"
                        )
                    continue
                if token in source:
                    violations.append(f"{relative}: activation token {token}")
            if path == providers_path:
                continue
            for model_id in pending_source_ids:
                if model_id in source:
                    violations.append(f"{relative}: pending candidate {model_id}")

    if providers_path.exists():
        providers = json.loads(providers_path.read_text(encoding="utf-8"))["providers"]
        provider_by_id = {row["id"]: row for row in providers}
        for provider_id, capability, identity, _, _, action, _, _ in EXPECTED_F086_CANDIDATES:
            if action == "revalidate_existing":
                continue
            capability_data = provider_by_id[provider_id].get(capability, {})
            capability_text = json.dumps(capability_data, sort_keys=True)
            needle = "ERNIE 5.1" if identity.startswith("placeholder:") else identity
            if needle.lower() in capability_text.lower():
                violations.append(
                    f"VowriteKit/Sources/VowriteKit/Resources/providers.json: "
                    f"pending {provider_id}/{capability} candidate {needle}"
                )

    return sorted(violations)


def f086_candidate_schema_violations(manifest):
    violations = []
    candidates = manifest.get("candidates")
    if not isinstance(candidates, list):
        return ["candidates must be a list"]

    allowed_capabilities = {"polish", "stt"}
    allowed_actions = {
        "add_non_default_after_acceptance",
        "replace_after_acceptance",
        "revalidate_existing",
    }
    for index, candidate in enumerate(candidates):
        prefix = f"candidate[{index}]"
        if not isinstance(candidate, dict):
            violations.append(f"{prefix} must be an object")
            continue
        if set(candidate) != F086_CANDIDATE_KEYS:
            violations.append(f"{prefix} keys must exactly match the schema")

        provider_id = candidate.get("providerID")
        capability = candidate.get("capability")
        model_id = candidate.get("modelID")
        placeholder = candidate.get("modelPlaceholder")
        action = candidate.get("action")

        if not isinstance(provider_id, str) or not provider_id:
            violations.append(f"{prefix}.providerID must be a non-empty string")
        if capability not in allowed_capabilities:
            violations.append(f"{prefix}.capability is invalid")
        if not isinstance(candidate.get("displayName"), str) or not candidate.get("displayName", "").strip():
            violations.append(f"{prefix}.displayName must be a non-empty string")
        if candidate.get("identityStatus") not in F086_ALLOWED_IDENTITY_STATUSES:
            violations.append(f"{prefix}.identityStatus is invalid")
        if action not in allowed_actions:
            violations.append(f"{prefix}.action is invalid")
        if candidate.get("status") != "pending_external_validation":
            violations.append(f"{prefix}.status must remain pending")

        if model_id is None:
            if provider_id != "qianfan" or not isinstance(placeholder, str) or not placeholder:
                violations.append(f"{prefix} null modelID is allowed only for Qianfan with a placeholder")
        elif not isinstance(model_id, str) or not model_id or placeholder is not None:
            violations.append(f"{prefix} modelID/placeholder types are invalid")

        if type(candidate.get("incumbentDefault")) is not bool:
            violations.append(f"{prefix}.incumbentDefault must be boolean")
        if not isinstance(candidate.get("incumbentModelID"), str) or not candidate.get("incumbentModelID", ""):
            violations.append(f"{prefix}.incumbentModelID must be a non-empty string")

        replacement = candidate.get("replacesModelID")
        if action == "replace_after_acceptance":
            if not isinstance(replacement, str) or not replacement:
                violations.append(f"{prefix}.replacesModelID is required for replacement")
        elif replacement is not None:
            violations.append(f"{prefix}.replacesModelID must be null for non-replacements")

        identity = model_id if model_id is not None else placeholder
        expected_overrides = F086_EXPECTED_OVERRIDES.get((provider_id, identity), object())
        if candidate.get("proposedRequestOverrides") != expected_overrides:
            violations.append(f"{prefix}.proposedRequestOverrides does not match the exact contract")

        scope = candidate.get("validationScope")
        if not isinstance(scope, dict) or set(scope) != {"endpoint", "region"}:
            violations.append(f"{prefix}.validationScope keys are invalid")
        elif not all(isinstance(scope[key], str) and scope[key] for key in ("endpoint", "region")):
            violations.append(f"{prefix}.validationScope values must be non-empty strings")

        evidence = candidate.get("firstPartyEvidence")
        if not isinstance(evidence, list) or not evidence or not all(isinstance(url, str) and url for url in evidence):
            violations.append(f"{prefix}.firstPartyEvidence must be a non-empty string list")

        target = candidate.get("target")
        if not isinstance(target, dict) or set(target) != {"account", "tier", "region"}:
            violations.append(f"{prefix}.target keys are invalid")
        elif any(value is not None for value in target.values()):
            violations.append(f"{prefix}.target must remain empty")

        live = candidate.get("liveRequests")
        if not isinstance(live, dict) or set(live) != {"required", "successful", "schemaOrParameter4xx"}:
            violations.append(f"{prefix}.liveRequests keys are invalid")
        else:
            if type(live["required"]) is not int or live["required"] != 5:
                violations.append(f"{prefix}.liveRequests.required must equal 5")
            if live["successful"] is not None or live["schemaOrParameter4xx"] is not None:
                violations.append(f"{prefix}.liveRequests results must remain empty")

        evaluation = candidate.get("evaluation")
        if not isinstance(evaluation, dict) or set(evaluation) != {"kind", "requiredSamples", "result"}:
            violations.append(f"{prefix}.evaluation keys are invalid")
        else:
            expected_kind = "stt" if capability == "stt" else "polish"
            expected_count = 30 if expected_kind == "stt" else 36
            if evaluation["kind"] != expected_kind:
                violations.append(f"{prefix}.evaluation.kind is invalid")
            if type(evaluation["requiredSamples"]) is not int or evaluation["requiredSamples"] != expected_count:
                violations.append(f"{prefix}.evaluation.requiredSamples is invalid")
            if evaluation["result"] is not None:
                violations.append(f"{prefix}.evaluation.result must remain empty")

        if candidate.get("approval") is not None:
            violations.append(f"{prefix}.approval must remain empty")

    return violations


class F086ActivationGuardTests(unittest.TestCase):
    def setUp(self):
        self.manifest = json.loads(
            (FIXTURES / "f086-pending-candidates.json").read_text(encoding="utf-8")
        )
        self.providers = json.loads(
            (
                REPO_ROOT
                / "VowriteKit/Sources/VowriteKit/Resources/providers.json"
            ).read_text(encoding="utf-8")
        )["providers"]

    def test_pending_manifest_keeps_results_targets_and_approval_empty(self):
        self.assertEqual(self.manifest["schema"], 1)
        self.assertEqual(self.manifest["feature"], "F-086")
        self.assertEqual(self.manifest["status"], "pending_external_validation")
        self.assertFalse(self.manifest["activationPolicy"]["publicCatalog"])
        self.assertFalse(self.manifest["activationPolicy"]["defaultsChanged"])
        self.assertIsNone(self.manifest["activationPolicy"]["joeApproval"])

        for candidate in self.manifest["candidates"]:
            with self.subTest(provider=candidate["providerID"], model=candidate["modelID"]):
                self.assertEqual(candidate["status"], "pending_external_validation")
                self.assertEqual(candidate["liveRequests"]["required"], 5)
                self.assertIsNone(candidate["liveRequests"]["successful"])
                self.assertIsNone(candidate["liveRequests"]["schemaOrParameter4xx"])
                self.assertIsNone(candidate["target"]["account"])
                self.assertIsNone(candidate["target"]["tier"])
                self.assertIsNone(candidate["target"]["region"])
                self.assertIsNone(candidate["evaluation"]["result"])
                self.assertIsNone(candidate["approval"])
                self.assertTrue(candidate["firstPartyEvidence"])

                expected_samples = 30 if candidate["capability"] == "stt" else 36
                self.assertEqual(candidate["evaluation"]["requiredSamples"], expected_samples)

    def test_manifest_matches_exact_candidate_tuples_and_enums(self):
        actual = []
        for candidate in self.manifest["candidates"]:
            identity = candidate["modelID"]
            if identity is None:
                identity = f"placeholder:{candidate['modelPlaceholder']}"
            actual.append((
                candidate["providerID"],
                candidate["capability"],
                identity,
                candidate["validationScope"]["endpoint"],
                candidate["validationScope"]["region"],
                candidate["action"],
                candidate["status"],
                candidate["replacesModelID"],
            ))

        self.assertEqual(tuple(actual), EXPECTED_F086_CANDIDATES)
        self.assertEqual(len(actual), 12)
        self.assertEqual(
            len({row[:3] for row in actual}),
            len(actual),
            "provider/capability/model-or-placeholder tuples must be unique",
        )
        self.assertEqual({row["capability"] for row in self.manifest["candidates"]}, {"polish", "stt"})
        self.assertEqual(
            {row["action"] for row in self.manifest["candidates"]},
            {"add_non_default_after_acceptance", "replace_after_acceptance", "revalidate_existing"},
        )
        self.assertEqual(
            {row["status"] for row in self.manifest["candidates"]},
            {"pending_external_validation"},
        )

    def test_manifest_null_identity_evidence_and_exclusions_are_strict(self):
        null_identity_rows = [row for row in self.manifest["candidates"] if row["modelID"] is None]
        self.assertEqual(len(null_identity_rows), 1)
        qianfan = null_identity_rows[0]
        self.assertEqual(qianfan["providerID"], "qianfan")
        self.assertEqual(qianfan["modelPlaceholder"], "ERNIE 5.1 exact direct ID pending")
        self.assertEqual(qianfan["identityStatus"], "pending_exact_direct_id")

        for candidate in self.manifest["candidates"]:
            if candidate["modelID"] is not None:
                self.assertIsNone(candidate["modelPlaceholder"])
            for raw_url in candidate["firstPartyEvidence"]:
                parsed = urlparse(raw_url)
                self.assertEqual(parsed.scheme, "https")
                self.assertIn(parsed.hostname, ALLOWED_F086_EVIDENCE_DOMAINS)
                self.assertNotIn("search", parsed.path.lower())
                self.assertNotIn("q=", parsed.query.lower())

        self.assertEqual(self.manifest["explicitExclusions"], EXPECTED_F086_EXCLUSIONS)

    def test_candidate_schema_is_exact(self):
        self.assertEqual(f086_candidate_schema_violations(self.manifest), [])

    def test_candidate_schema_rejects_unknown_fields_and_type_mutations(self):
        mutations = []

        unknown = copy.deepcopy(self.manifest)
        unknown["candidates"][0]["unexpected"] = True
        mutations.append(("unknown candidate key", unknown))

        empty_name = copy.deepcopy(self.manifest)
        empty_name["candidates"][0]["displayName"] = ""
        mutations.append(("empty display name", empty_name))

        bad_default = copy.deepcopy(self.manifest)
        bad_default["candidates"][0]["incumbentDefault"] = "false"
        mutations.append(("non-boolean incumbent default", bad_default))

        bad_override = copy.deepcopy(self.manifest)
        bad_override["candidates"][0]["proposedRequestOverrides"]["unknown"] = True
        mutations.append(("unknown override", bad_override))

        bad_evaluation = copy.deepcopy(self.manifest)
        bad_evaluation["candidates"][0]["evaluation"]["unknown"] = None
        mutations.append(("unknown evaluation key", bad_evaluation))

        bad_result = copy.deepcopy(self.manifest)
        bad_result["candidates"][0]["evaluation"]["result"] = {}
        mutations.append(("premature result", bad_result))

        bad_target = copy.deepcopy(self.manifest)
        bad_target["candidates"][0]["target"]["region"] = "us"
        mutations.append(("premature target", bad_target))

        bad_approval = copy.deepcopy(self.manifest)
        bad_approval["candidates"][0]["approval"] = False
        mutations.append(("typed approval", bad_approval))

        for label, mutated in mutations:
            with self.subTest(label=label):
                self.assertTrue(f086_candidate_schema_violations(mutated))

    def test_pending_public_candidates_are_absent_from_their_bundled_catalogs(self):
        provider_by_id = {provider["id"]: provider for provider in self.providers}
        for candidate in self.manifest["candidates"]:
            if candidate["action"] == "revalidate_existing":
                continue
            model_id = candidate["modelID"]
            if model_id is None:
                continue
            provider = provider_by_id[candidate["providerID"]]
            capability = provider.get(candidate["capability"], {})
            bundled_ids = {row["id"] for row in capability.get("models", [])}
            with self.subTest(provider=candidate["providerID"], model=model_id):
                self.assertNotIn(model_id, bundled_ids)

    def test_complete_production_tree_has_no_f086_activation_touch(self):
        self.assertEqual(find_f086_activation_violations(REPO_ROOT), [])

    def test_recursive_guard_catches_real_activation_names_in_an_unlisted_file(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            injected = root / "VowriteMac/Sources/Deferred/UnexpectedRefresh.swift"
            injected.parent.mkdir(parents=True)
            injected.write_text(
                'struct ProviderModelMigration202608 {}\n'
                'let migrationID = "catalog-refresh-2026-08-v1"\n'
                'let candidate = "claude-opus-5"\n',
                encoding="utf-8",
            )
            violations = find_f086_activation_violations(root)
            self.assertTrue(any("shared migration symbol count" in row for row in violations))
            self.assertTrue(any("catalog-refresh-2026-08-v1" in row for row in violations))
            self.assertTrue(any("claude-opus-5" in row for row in violations))

    def test_watcher_state_remains_the_pre_f086_baseline(self):
        state_bytes = (REPO_ROOT / "ops/model-watch/state.json").read_bytes()
        self.assertEqual(
            hashlib.sha256(state_bytes).hexdigest(),
            "038d6c635f36e38c2970447109299babf3d9e5cf712ccbd2f0ca2b7ca94a0535",
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
