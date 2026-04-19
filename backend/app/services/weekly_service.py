from __future__ import annotations

from collections import Counter
from datetime import date, timedelta
from typing import Any

from sqlalchemy.orm import Session

from app.repositories.core_repository import ensure_demo_user
from app.repositories.memory_repository import MemoryRepository
from app.repositories.weekly_repository import WeeklyRepository
from app.services.llm_service import LlmService


class WeeklyService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.memory_repo = MemoryRepository(db)
        self.weekly_repo = WeeklyRepository(db)
        self.llm = LlmService()

    def get_current_weekly(self, user_id: str) -> dict:
        today = date.today()
        first_signal_date = self.memory_repo.get_first_signal_date(user_id)
        weekly_started = first_signal_date is not None and today >= (
            first_signal_date + timedelta(days=1)
        )

        if not weekly_started:
            week_start = today - timedelta(days=6)
            return {
                "week_start": week_start.isoformat(),
                "week_end": today.isoformat(),
                "status": "not_started",
                "message": "Weekly 将从首条记录后的第 2 天开始展示。",
                "first_signal_date": first_signal_date.isoformat()
                if first_signal_date
                else None,
                "chart_data": [],
            }

        week_start = today - timedelta(days=6)
        return self.get_weekly_by_start(user_id, week_start)

    def get_weekly_by_start(self, user_id: str, week_start: date) -> dict:
        ensure_demo_user(self.db, user_id)
        existing = self.weekly_repo.find_by_user_and_week(user_id, week_start)
        if existing:
            return {
                "week_start": existing.week_start.isoformat(),
                "week_end": existing.week_end.isoformat(),
                "status": existing.status,
                "key_insight": existing.key_insight,
                "patterns": existing.top_patterns_json,
                "frictions": existing.top_frictions_json,
                "best_action": existing.best_action,
                "opportunity_snapshot": existing.opportunity_snapshot_json,
                "feedback_submitted": existing.feedback_value is not None,
                "chart_data": existing.chart_data_json or [],
            }
        return self.generate_weekly(user_id, week_start)

    def submit_feedback(
        self,
        user_id: str,
        week_start: date,
        feedback_value: str,
    ) -> dict:
        weekly = self.weekly_repo.submit_feedback(user_id, week_start, feedback_value)
        self.db.commit()
        if not weekly:
            raise ValueError("Weekly insight not found")
        return {
            "week_start": week_start.isoformat(),
            "feedback_value": feedback_value,
            "message": "周报反馈已记录。",
        }

    def generate_weekly(self, user_id: str, week_start: date) -> dict:
        week_end = week_start + timedelta(days=6)
        summary = self.memory_repo.raw_summary(user_id, week_start, week_end)

        signal_count = int(summary.get("signal_count") or 0)
        active_days = self._resolve_active_days(summary)
        chart_data = self._build_chart_data(summary, week_start, week_end)

        if signal_count < 1:
            payload = {
                "week_start": week_start.isoformat(),
                "week_end": week_end,
                "status": "insufficient_data",
                "chart_data": chart_data,
            }
            self.weekly_repo.upsert(user_id, week_start, payload)
            self.db.commit()
            return {
                "week_start": week_start.isoformat(),
                "week_end": week_end.isoformat(),
                "status": "insufficient_data",
                "message": "这一周的信号还不够多，我还不想太早下判断。",
                "chart_data": chart_data,
            }

        patterns = self.memory_repo.list_patterns(user_id, limit=3)
        frictions = self.memory_repo.list_frictions(user_id, limit=2)
        opportunities = self.memory_repo.list_opportunities(
            user_id,
            maturity=None,
            status="open",
        )[:1]

        generated = self.llm.generate_weekly(
            {
                "user_profile": self.memory_repo.get_profile(user_id),
                "week_range": {
                    "start": week_start.isoformat(),
                    "end": week_end.isoformat(),
                },
                "raw_memory_summary": summary,
                "patterns": [
                    {
                        "id": p.id,
                        "name": p.name,
                        "description": p.description or "",
                    }
                    for p in patterns
                ],
                "frictions": [
                    {
                        "id": f.id,
                        "name": f.name,
                        "description": f.description or "",
                    }
                    for f in frictions
                ],
                "opportunities": [
                    {
                        "id": o.id,
                        "name": o.name,
                        "description": o.description or "",
                        "maturity": o.maturity,
                    }
                    for o in opportunities
                ],
                "recent_feedback": self.memory_repo.get_recent_feedback(user_id),
            }
        )

        status = self._resolve_status(signal_count=signal_count, active_days=active_days)
        generated_payload = self._build_payload(
            week_start=week_start,
            week_end=week_end,
            status=status,
            generated=generated,
            chart_data=chart_data,
        )

        self.weekly_repo.upsert(user_id, week_start, generated_payload)
        self.db.commit()

        return {
            "week_start": week_start.isoformat(),
            "week_end": week_end.isoformat(),
            "status": status,
            "key_insight": generated_payload["key_insight"],
            "patterns": generated_payload["patterns"],
            "frictions": generated_payload["frictions"],
            "best_action": generated_payload["best_action"],
            "opportunity_snapshot": generated_payload["opportunity_snapshot"],
            "feedback_submitted": False,
            "chart_data": chart_data,
        }

    def _resolve_active_days(self, summary: dict) -> int:
        day_counts = summary.get("day_counts")
        if isinstance(day_counts, dict) and day_counts:
            return len([k for k, v in day_counts.items() if (v or 0) > 0])

        daily_points = summary.get("daily_points")
        if isinstance(daily_points, list):
            count = 0
            for item in daily_points:
                if not isinstance(item, dict):
                    continue
                if (item.get("count") or 0) > 0:
                    count += 1
            if count > 0:
                return count

        return 1 if (summary.get("signal_count") or 0) > 0 else 0

    def _resolve_status(self, signal_count: int, active_days: int) -> str:
        if signal_count < 1:
            return "insufficient_data"
        if signal_count < 4 or active_days < 2:
            return "light_ready"
        return "ready"

    def _build_payload(
        self,
        week_start: date,
        week_end: date,
        status: str,
        generated: dict[str, Any],
        chart_data: list[dict[str, Any]],
    ) -> dict:
        key_insight = generated.get("key_insight")
        patterns = generated.get("top_patterns") or []
        frictions = generated.get("top_frictions") or []
        best_action = generated.get("best_action")
        opportunity_snapshot = generated.get("opportunity_snapshot")

        if status == "light_ready":
            key_insight = self._lighten_key_insight(key_insight)
            patterns = self._lighten_items(patterns, default_name="这周先冒头的线索")
            frictions = self._lighten_items(frictions, default_name="这周先看到的消耗点")
            best_action = self._lighten_best_action(best_action)
            opportunity_snapshot = self._lighten_opportunity(opportunity_snapshot)

        return {
            "week_start": week_start.isoformat(),
            "week_end": week_end,
            "status": status,
            "key_insight": key_insight,
            "patterns": patterns,
            "frictions": frictions,
            "best_action": best_action,
            "opportunity_snapshot": opportunity_snapshot,
            "chart_data": chart_data,
        }

    def _build_chart_data(
        self,
        summary: dict[str, Any],
        week_start: date,
        week_end: date,
    ) -> list[dict[str, Any]]:
        day_counts: dict[str, int] = {}
        raw_day_counts = summary.get("day_counts")
        if isinstance(raw_day_counts, dict):
            for key, value in raw_day_counts.items():
                try:
                    day_counts[str(key)] = int(value or 0)
                except Exception:
                    day_counts[str(key)] = 0

        signal_tokens = self._collect_signal_tokens(summary)
        positive_tokens = {
            "开心", "高兴", "顺利", "喜欢", "放松", "舒服", "满足", "期待", "有成就感",
            "嬉しい", "楽しい", "よかった", "満足", "安心",
            "happy", "good", "great", "relieved", "nice",
        }
        negative_tokens = {
            "烦", "累", "焦虑", "生气", "压力", "麻烦", "受不了", "打断", "失控", "疲惫",
            "しんどい", "つらい", "疲れた", "イライラ", "不安",
            "annoyed", "tired", "upset", "angry", "anxious", "stressed",
        }

        total_tokens = max(sum(signal_tokens.values()), 1)
        positive_ratio = sum(v for k, v in signal_tokens.items() if k in positive_tokens) / total_tokens
        negative_ratio = sum(v for k, v in signal_tokens.items() if k in negative_tokens) / total_tokens

        points: list[dict[str, Any]] = []
        cursor = week_start
        max_count = max(day_counts.values()) if day_counts else 1

        while cursor <= week_end:
            day_key = cursor.isoformat()
            count = day_counts.get(day_key, 0)

            mood_score = 0.0
            friction_score = 0.0
            has_positive_signal = False

            if count > 0:
                density = count / max(max_count, 1)
                mood_score = round((positive_ratio - negative_ratio) * density, 3)
                friction_score = round(negative_ratio * density, 3)
                has_positive_signal = positive_ratio > 0 and count > 0

            points.append(
                {
                    "date": day_key,
                    "signal_count": count,
                    "mood_score": mood_score,
                    "friction_score": friction_score,
                    "has_positive_signal": has_positive_signal,
                }
            )
            cursor += timedelta(days=1)

        return points

    def _collect_signal_tokens(self, summary: dict[str, Any]) -> Counter[str]:
        counter: Counter[str] = Counter()

        top_tokens = summary.get("top_tokens")
        if isinstance(top_tokens, list):
            for item in top_tokens:
                if isinstance(item, dict):
                    token = str(item.get("token") or "").strip().lower()
                    if not token:
                        continue
                    counter[token] += int(item.get("count") or 1)
                elif isinstance(item, str):
                    token = item.strip().lower()
                    if token:
                        counter[token] += 1

        raw_tokens = summary.get("tokens")
        if isinstance(raw_tokens, list):
            for token in raw_tokens:
                token = str(token or "").strip().lower()
                if token:
                    counter[token] += 1

        return counter

    def _lighten_key_insight(self, text: str | None) -> str:
        base = text or "这周已经开始有线索冒出来了，不过现在更适合先轻轻看着。"
        if "这周" in base:
            return base
        return f"这周已经开始有线索冒出来了：{base}"

    def _lighten_items(self, items: list, default_name: str) -> list[dict]:
        if not items:
            return [
                {
                    "name": default_name,
                    "summary": "记录还不多，但已经能看见一个开始重复的方向。",
                }
            ]

        lightened: list[dict] = []
        for item in items[:2]:
            if isinstance(item, dict):
                lightened.append(
                    {
                        "name": item.get("name") or default_name,
                        "summary": item.get("summary")
                        or "线索已经出现了，但还不适合下太重的判断。",
                    }
                )
        return lightened or [
            {
                "name": default_name,
                "summary": "记录还不多，但已经能看见一个开始重复的方向。",
            }
        ]

    def _lighten_best_action(self, text: str | None) -> str:
        if text and text.strip():
            return text
        return "这周先别急着总结完整，只要继续记下重复出现的场景就可以。"

    def _lighten_opportunity(self, item: dict | None) -> dict | None:
        if not item:
            return {
                "id": "opp_light_weekly",
                "name": "先把线索留住",
                "summary": "现在更适合先继续收集线索，等轮廓再清楚一点，再判断值不值得进一步整理。",
                "maturity": "emerging",
            }
        return item
