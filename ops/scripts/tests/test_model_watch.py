#!/usr/bin/env python3
"""Offline behavioral regression tests for model-watch (F-085)."""

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


if __name__ == "__main__":
    unittest.main(verbosity=2)
