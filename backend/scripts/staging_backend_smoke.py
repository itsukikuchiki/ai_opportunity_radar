#!/usr/bin/env python3
"""Reproducible staging-only backend smoke with guaranteed account cleanup."""

from __future__ import annotations

import argparse
import sys
from datetime import datetime, timedelta
from typing import Any
from uuid import uuid4
from zoneinfo import ZoneInfo

import httpx


def _assert(condition: bool, message: str, checks: list[str]) -> None:
    if not condition:
        raise AssertionError(message)
    checks.append(message)


def _json_request(
    client: httpx.Client,
    method: str,
    path: str,
    *,
    headers: dict[str, str] | None = None,
    body: dict[str, Any] | None = None,
) -> dict[str, Any]:
    response = client.request(method, path, headers=headers, json=body)
    if response.status_code != 200:
        raise AssertionError(
            f"{method} {path} returned {response.status_code}: "
            f"{response.text[:700]}"
        )
    payload = response.json()
    if not isinstance(payload, dict):
        raise AssertionError(f"{method} {path} did not return a JSON object")
    return payload


def run(base_url: str) -> list[str]:
    normalized = base_url.rstrip("/")
    if "staging" not in normalized.lower() or "production" in normalized.lower():
        raise ValueError("refusing to run destructive smoke outside a staging URL")

    run_id = uuid4().hex[:12]
    user_id = f"staging-smoke-{run_id}"
    account_session: str | None = None
    checks: list[str] = []
    failure: BaseException | None = None
    now = datetime.now(ZoneInfo("Asia/Tokyo"))
    week_start = (now.date() - timedelta(days=now.weekday())).isoformat()
    week_end = (now.date() + timedelta(days=6 - now.weekday())).isoformat()

    with httpx.Client(base_url=normalized, timeout=90) as client:
        try:
            health = _json_request(client, "GET", "/health")
            _assert(
                health.get("status") == "ok" and health.get("version") == "0.9.0",
                "health and DB readiness",
                checks,
            )

            auth = _json_request(
                client,
                "POST",
                "/api/v1/auth/apple",
                body={
                    "apple_user_id": f"staging-smoke-apple-{run_id}",
                    "local_user_id": user_id,
                    "device_id": "codex-staging-smoke",
                },
            )
            account_session = auth.get("data", {}).get("session_token")
            _assert(
                isinstance(account_session, str) and len(account_session) > 20,
                "temporary account created (session omitted)",
                checks,
            )

            headers = {"X-User-Id": user_id}
            capture_specs = (
                ("quick_capture", "会议切换后有点累，需要十分钟恢复。", "text"),
                ("voice", "下午连续沟通后注意力有些零散。", "voice"),
                ("status", "现在精力偏低，但情绪平稳。", "status"),
            )
            signal_ids: list[str] = []
            first_body: dict[str, Any] | None = None
            for input_mode, content, suffix in capture_specs:
                body = {
                    "content": content,
                    "input_mode": input_mode,
                    "language": "zh-Hans",
                    "timezone": "Asia/Tokyo",
                    "client_id": f"{run_id}-{suffix}",
                    "raw_payload_json": {"source_kind": "staging_smoke"},
                }
                first_body = first_body or body
                result = _json_request(
                    client, "POST", "/api/v1/captures", headers=headers, body=body
                ).get("data", {})
                _assert(bool(result.get("acknowledgement")), f"{input_mode} acknowledged", checks)
                matching = next(
                    (
                        item
                        for item in result.get("recent_signals", [])
                        if item.get("client_id") == body["client_id"]
                    ),
                    None,
                )
                signal_id = matching.get("signal_card_id") if matching else None
                _assert(
                    isinstance(signal_id, str) and signal_id.startswith("sig_"),
                    f"{input_mode} produced SignalCard",
                    checks,
                )
                signal_ids.append(signal_id)

            replay = _json_request(
                client,
                "POST",
                "/api/v1/captures",
                headers=headers,
                body=first_body,
            )
            replay_match = next(
                (
                    item
                    for item in replay.get("data", {}).get("recent_signals", [])
                    if item.get("client_id") == first_body["client_id"]
                ),
                None,
            )
            _assert(
                replay_match and replay_match.get("signal_card_id") == signal_ids[0],
                "client_id replay is idempotent",
                checks,
            )

            recent = _json_request(
                client, "GET", "/api/v1/captures/recent", headers=headers
            )
            _assert(
                len(recent.get("data", {}).get("recent_signals", [])) == 3,
                "recent contains 3 SignalCards",
                checks,
            )

            confirmed = _json_request(
                client,
                "PATCH",
                f"/api/v1/captures/signal-cards/{signal_ids[0]}/confirmation",
                headers=headers,
                body={
                    "user_confirmation": "confirmed",
                    "user_correction_json": {
                        "edited_text": "会议切换后很累，需要十分钟恢复。",
                        "smoke_test": True,
                    },
                },
            )
            _assert(
                confirmed.get("data", {}).get("user_correction_json", {}).get("smoke_test")
                is True,
                "confirmation and correction persisted",
                checks,
            )

            deleted = _json_request(
                client,
                "DELETE",
                f"/api/v1/captures/signal-cards/{signal_ids[0]}",
                headers=headers,
                body={"reason": "staging_smoke"},
            )
            _assert(
                deleted.get("data", {}).get("status") == "deleted"
                and deleted.get("data", {}).get("tombstone_version") == 1,
                "soft-delete tombstone persisted",
                checks,
            )
            recent = _json_request(
                client, "GET", "/api/v1/captures/recent", headers=headers
            )
            _assert(
                len(recent.get("data", {}).get("recent_signals", [])) == 2,
                "deleted SignalCard excluded from recent",
                checks,
            )

            restored = _json_request(
                client,
                "POST",
                f"/api/v1/captures/signal-cards/{signal_ids[0]}/restore",
                headers=headers,
                body={},
            )
            _assert(
                restored.get("data", {}).get("status") == "restored"
                and restored.get("data", {}).get("deleted_at") is None,
                "SignalCard restored",
                checks,
            )

            weekly = _json_request(
                client, "GET", f"/api/v1/weekly/{week_start}", headers=headers
            )
            weekly_data = weekly.get("data", {})
            _assert(
                weekly.get("success") is True
                and weekly_data.get("status") == "light_ready",
                "Weekly aggregation is light_ready",
                checks,
            )
            _assert(
                weekly_data.get("week_start") == week_start
                and weekly_data.get("week_end") == week_end,
                "Weekly uses local Monday-Sunday",
                checks,
            )

            reflection_body = {
                "week_start": week_start,
                "week_end": week_end,
                "key_insight": "切换密集后更容易疲惫。",
                "patterns": [{"name": "切换密集", "summary": "会议之间缺少缓冲。"}],
                "frictions": [{"name": "恢复不足", "summary": "切换后没有恢复时间。"}],
                "best_action": "留十分钟缓冲。",
                "chart_data": [
                    {
                        "date": now.date().isoformat(),
                        "signal_count": 3,
                        "mood_score": -0.3,
                        "friction_score": 0.7,
                        "has_positive_signal": False,
                    }
                ],
                "focus_area": "energy",
            }
            reflected = _json_request(
                client,
                "POST",
                "/api/v1/ai/reflect-weekly",
                headers=headers,
                body=reflection_body,
            ).get("data", {})
            _assert(
                all(
                    key in reflected
                    for key in (
                        "summary",
                        "root_tension",
                        "hidden_pattern",
                        "next_focus",
                        "risk_note",
                        "key_nodes",
                    )
                ),
                "reflect-weekly contract complete",
                checks,
            )
            compatibility_headers = {
                **headers,
                "X-Client-Version": "staging-smoke",
                "X-Platform": "codex",
            }
            compatible = _json_request(
                client,
                "POST",
                "/api/v1/ai/deep-weekly",
                headers=compatibility_headers,
                body=reflection_body,
            )
            _assert(
                bool(compatible.get("data", {}).get("summary")),
                "deep-weekly compatibility path",
                checks,
            )
            usage = _json_request(
                client, "GET", "/api/v1/usage/summary", headers=headers
            ).get("data", {})
            _assert(
                usage.get("entitlement") == "free"
                and isinstance(usage.get("quotas"), list),
                "usage read path",
                checks,
            )
        except BaseException as exc:  # cleanup must run even on Ctrl-C
            failure = exc
        finally:
            if account_session:
                cleanup = client.delete(
                    "/api/v1/account",
                    headers={
                        "X-Account-Session": account_session,
                        "X-User-Id": user_id,
                    },
                )
                if cleanup.status_code == 200 and cleanup.json().get("data", {}).get(
                    "account_deleted"
                ):
                    checks.append("temporary account and user data cleaned")
                elif failure is None:
                    failure = AssertionError(
                        f"cleanup returned {cleanup.status_code}: {cleanup.text[:500]}"
                    )

    if failure is not None:
        raise failure
    return checks


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", required=True)
    args = parser.parse_args()
    try:
        checks = run(args.base_url)
    except BaseException as exc:
        print(f"SMOKE FAILED: {exc}", file=sys.stderr)
        return 1
    for check in checks:
        print(f"PASS {check}")
    print(f"SMOKE PASSED: {len(checks)} checks")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
