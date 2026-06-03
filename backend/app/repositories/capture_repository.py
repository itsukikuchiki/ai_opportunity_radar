from __future__ import annotations

from datetime import datetime, timezone
from typing import Any
from uuid import uuid4
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from sqlalchemy import select

from app.models import Capture, RawMemory, SignalCard
from app.repositories.core_repository import ensure_demo_user


class CaptureRepository:
    def __init__(self, db: Any):
        self.db = db

    def create_capture(
        self,
        user_id: str,
        content: str,
        input_mode: str = "quick_capture",
        tag_hint: str | None = None,
        acknowledgement: str | None = None,
        language: str = "en",
        timezone_name: str = "UTC",
    ) -> dict[str, Any]:
        created = self.create_capture_skeleton(
            user_id=user_id,
            content=content,
            input_mode=input_mode,
            tag_hint=tag_hint,
            language=language,
            timezone_name=timezone_name,
        )
        if acknowledgement:
            self.update_signal_card_ai_result(
                signal_card_id=created["signal_card_id"],
                acknowledgement=acknowledgement,
                model_used="local_rules_v2",
                fallback_used=False,
                quota_decision="legacy_allowed",
                commit=True,
            )
            created["acknowledgement"] = acknowledgement
        return created

    def create_capture_skeleton(
        self,
        user_id: str,
        content: str,
        input_mode: str = "quick_capture",
        tag_hint: str | None = None,
        language: str = "en",
        timezone_name: str = "UTC",
        raw_payload: dict[str, Any] | None = None,
        commit: bool = True,
    ) -> dict[str, Any]:
        ensure_demo_user(self.db, user_id)

        created_at = datetime.now(timezone.utc)
        capture_id = f"cap_{uuid4().hex[:12]}"
        raw_id = f"raw_{uuid4().hex[:12]}"
        signal_card_id = f"sig_{uuid4().hex[:12]}"
        source_type = self._source_type_from_input_mode(input_mode)
        local_date = self._local_date(created_at, timezone_name)

        capture = Capture(
            id=capture_id,
            user_id=user_id,
            content=content,
            input_mode=input_mode,
            tag_hint=tag_hint,
            created_at=created_at,
        )
        self.db.add(capture)

        raw_memory = RawMemory(
            id=raw_id,
            user_id=user_id,
            capture_id=capture_id,
            source="capture",
            content=content,
            signal_type=None,
            scene_type=None,
            friction_type=None,
            emotion_strength=None,
            repetition_flag=False,
            desire_flag=False,
            related_pattern_id=None,
            related_friction_id=None,
            metadata_json={
                "signal_card_id": signal_card_id,
                "save_first": True,
            },
            created_at=created_at,
        )
        self.db.add(raw_memory)

        signal_card = SignalCard(
            id=signal_card_id,
            user_id=user_id,
            capture_id=capture_id,
            raw_memory_id=raw_id,
            source_type=source_type,
            raw_text=content,
            raw_payload_json=raw_payload or {},
            ai_reply=None,
            created_at=created_at,
            local_date=local_date,
            timezone=timezone_name or "UTC",
            language=language or "en",
            emotion=None,
            intensity=None,
            scene=None,
            friction=None,
            positive_signal=None,
            energy_load=None,
            linked_life_chain_stage={},
            confidence_score=None,
            user_confirmation="unconfirmed",
            user_correction_json={},
            included_in_summary=False,
            included_in_weekly=False,
            included_in_journey=False,
            linked_experiment_id=None,
            parser_version="v3_rules_1",
            model_used=None,
            prompt_version=None,
            token_usage_json={},
            privacy_level="private",
            schema_version=1,
            is_legacy=False,
            migration_status="native",
            metadata_json={"tag_hint": tag_hint} if tag_hint else {},
        )
        self.db.add(signal_card)
        if commit:
            self.db.commit()
        else:
            self.db.flush()

        return {
            "id": raw_id,
            "capture_id": capture_id,
            "raw_memory_id": raw_id,
            "signal_card_id": signal_card_id,
            "content": content,
            "created_at": created_at,
            "local_date": local_date,
            "acknowledgement": None,
        }

    def update_signal_card_parser_result(
        self,
        *,
        signal_card_id: str,
        parsed_signal: dict[str, Any] | None,
        parser_version: str = "v3_rules_1",
        model_used: str | None = None,
        confidence_score: float | None = None,
        error: str | None = None,
        commit: bool = True,
    ) -> SignalCard | None:
        signal_card = self.db.get(SignalCard, signal_card_id)
        if signal_card is None:
            return None

        signal_card.parser_version = parser_version
        signal_card.model_used = model_used or signal_card.model_used
        metadata = dict(signal_card.metadata_json or {})

        if parsed_signal:
            signal_card.emotion = parsed_signal.get("signal_type")
            signal_card.scene = parsed_signal.get("scene_type")
            signal_card.friction = parsed_signal.get("friction_type")
            signal_card.intensity = self._intensity_from_legacy_strength(
                parsed_signal.get("emotion_strength")
            )
            signal_card.energy_load = self._energy_load_from_signal(parsed_signal)
            signal_card.linked_life_chain_stage = self._life_chain_stage(parsed_signal)
            signal_card.confidence_score = (
                confidence_score if confidence_score is not None else 0.72
            )
            metadata["parser_status"] = "parsed"
            metadata["parsed_signal"] = parsed_signal

            raw_memory = self.db.get(RawMemory, signal_card.raw_memory_id)
            if raw_memory is not None:
                raw_memory.signal_type = parsed_signal.get("signal_type")
                raw_memory.scene_type = parsed_signal.get("scene_type")
                raw_memory.friction_type = parsed_signal.get("friction_type")
                raw_memory.emotion_strength = parsed_signal.get("emotion_strength")
                raw_memory.repetition_flag = bool(parsed_signal.get("repetition_flag"))
                raw_memory.desire_flag = bool(parsed_signal.get("desire_flag"))
        else:
            metadata["parser_status"] = "failed"
            metadata["parser_error"] = error or "unknown_parser_failure"
            signal_card.confidence_score = None

        signal_card.metadata_json = metadata
        if commit:
            self.db.commit()
        else:
            self.db.flush()
        return signal_card

    def update_signal_card_ai_result(
        self,
        *,
        signal_card_id: str,
        acknowledgement: str,
        model_used: str | None,
        fallback_used: bool,
        quota_decision: str,
        token_usage: dict[str, Any] | None = None,
        commit: bool = True,
    ) -> SignalCard | None:
        signal_card = self.db.get(SignalCard, signal_card_id)
        if signal_card is None:
            return None

        signal_card.ai_reply = acknowledgement
        signal_card.model_used = model_used
        signal_card.token_usage_json = token_usage or {}
        metadata = dict(signal_card.metadata_json or {})
        metadata["ai_reply_status"] = "fallback" if fallback_used else "generated"
        metadata["quota_decision"] = quota_decision
        signal_card.metadata_json = metadata

        raw_memory = self.db.get(RawMemory, signal_card.raw_memory_id)
        if raw_memory is not None:
            raw_metadata = dict(raw_memory.metadata_json or {})
            raw_metadata["acknowledgement"] = acknowledgement
            raw_metadata["ai_reply_status"] = metadata["ai_reply_status"]
            raw_metadata["quota_decision"] = quota_decision
            raw_memory.metadata_json = raw_metadata

        if commit:
            self.db.commit()
        else:
            self.db.flush()
        return signal_card

    def backfill_missing_raw_memories(
        self,
        user_id: str,
        commit: bool = True,
    ) -> int:
        """
        将旧版本只存在于 Capture、但还没有对应 RawMemory 的数据补齐。
        """
        ensure_demo_user(self.db, user_id)

        capture_stmt = (
            select(Capture)
            .where(Capture.user_id == user_id)
            .order_by(Capture.created_at.asc())
        )
        captures = list(self.db.scalars(capture_stmt))

        raw_stmt = select(RawMemory.capture_id).where(
            RawMemory.user_id == user_id,
            RawMemory.capture_id.is_not(None),
        )
        existing_capture_ids = {
            capture_id
            for capture_id in self.db.scalars(raw_stmt)
            if capture_id
        }

        created_count = 0

        for capture in captures:
            if capture.id in existing_capture_ids:
                continue

            raw_memory = RawMemory(
                id=f"raw_{uuid4().hex[:12]}",
                user_id=user_id,
                capture_id=capture.id,
                source="capture",
                content=capture.content or "",
                signal_type=None,
                scene_type=None,
                friction_type=None,
                emotion_strength=None,
                repetition_flag=False,
                desire_flag=False,
                related_pattern_id=None,
                related_friction_id=None,
                metadata_json={},
                created_at=capture.created_at,
            )
            self.db.add(raw_memory)
            created_count += 1

        if created_count > 0:
            self.db.flush()
            if commit:
                self.db.commit()
        elif commit:
            # 保持调用方逻辑简单
            self.db.rollback()

        return created_count

    def migrate_legacy_signal_cards(
        self,
        user_id: str,
        commit: bool = True,
    ) -> dict[str, int]:
        ensure_demo_user(self.db, user_id)
        self.backfill_missing_raw_memories(user_id=user_id, commit=False)

        raw_stmt = (
            select(RawMemory)
            .where(RawMemory.user_id == user_id)
            .order_by(RawMemory.created_at.asc())
        )
        raw_memories = list(self.db.scalars(raw_stmt))

        existing_stmt = select(SignalCard.raw_memory_id).where(
            SignalCard.user_id == user_id,
            SignalCard.raw_memory_id.is_not(None),
        )
        existing_raw_ids = {
            raw_id for raw_id in self.db.scalars(existing_stmt) if raw_id
        }

        created_count = 0
        skipped_count = 0
        partial_count = 0

        for raw in raw_memories:
            if raw.id in existing_raw_ids:
                skipped_count += 1
                continue

            capture = self.db.get(Capture, raw.capture_id) if raw.capture_id else None
            metadata = raw.metadata_json if isinstance(raw.metadata_json, dict) else {}
            acknowledgement = (
                metadata.get("acknowledgement")
                or metadata.get("ai_acknowledgement")
                or metadata.get("response")
            )
            created_at = raw.created_at or datetime.now(timezone.utc)
            timezone_name = metadata.get("timezone") or "UTC"
            language = metadata.get("language") or "en"

            signal_card = SignalCard(
                id=f"sig_{uuid4().hex[:12]}",
                user_id=user_id,
                capture_id=raw.capture_id,
                raw_memory_id=raw.id,
                source_type=self._source_type_from_input_mode(
                    capture.input_mode if capture else raw.source
                ),
                raw_text=raw.content or "",
                raw_payload_json={},
                ai_reply=acknowledgement,
                created_at=created_at,
                local_date=self._local_date(created_at, timezone_name),
                timezone=timezone_name,
                language=language,
                emotion=raw.signal_type,
                intensity=self._intensity_from_legacy_strength(raw.emotion_strength),
                scene=raw.scene_type,
                friction=raw.friction_type,
                positive_signal=None,
                energy_load=self._energy_load_from_signal({
                    "signal_type": raw.signal_type,
                    "friction_type": raw.friction_type,
                    "emotion_strength": raw.emotion_strength,
                }),
                linked_life_chain_stage=self._life_chain_stage({
                    "signal_type": raw.signal_type,
                    "friction_type": raw.friction_type,
                }),
                confidence_score=None,
                user_confirmation="unconfirmed",
                user_correction_json={},
                included_in_summary=False,
                included_in_weekly=False,
                included_in_journey=False,
                linked_experiment_id=None,
                parser_version="legacy_migration_v1",
                model_used=metadata.get("model_used"),
                prompt_version=metadata.get("prompt_version"),
                token_usage_json={},
                privacy_level="private",
                schema_version=1,
                is_legacy=True,
                migration_status="migrated_partial",
                metadata_json={
                    "legacy_source_id": raw.id,
                    "legacy_source_table": "raw_memories",
                    "legacy_capture_id": raw.capture_id,
                    "legacy_metadata": metadata,
                },
            )
            self.db.add(signal_card)
            created_count += 1
            partial_count += 1

        if created_count > 0:
            self.db.flush()
        if commit:
            self.db.commit()

        return {
            "created": created_count,
            "skipped": skipped_count,
            "migrated_partial": partial_count,
            "source_raw_memories": len(raw_memories),
        }

    def list_recent_raw_memories(
        self,
        user_id: str,
        limit: int = 50,
    ) -> list[dict[str, Any]]:
        """
        读取 recent signals 前，先把旧 Capture 回填到 RawMemory，
        这样旧版本数据也能被 Today 正常读到。
        """
        self.backfill_missing_raw_memories(user_id=user_id, commit=True)

        stmt = (
            select(RawMemory)
            .where(RawMemory.user_id == user_id)
            .order_by(RawMemory.created_at.desc())
            .limit(limit)
        )
        rows = list(self.db.scalars(stmt))

        def _ack(meta: Any) -> str | None:
            if not isinstance(meta, dict):
                return None
            return (
                meta.get("acknowledgement")
                or meta.get("ai_acknowledgement")
                or meta.get("response")
            )

        return [
            {
                "id": row.id,
                "content": row.content or "",
                "created_at": row.created_at,
                "acknowledgement": _ack(row.metadata_json),
            }
            for row in rows
        ]

    def list_recent_signal_cards(
        self,
        user_id: str,
        limit: int = 50,
    ) -> list[SignalCard]:
        self.migrate_legacy_signal_cards(user_id=user_id, commit=True)
        stmt = (
            select(SignalCard)
            .where(SignalCard.user_id == user_id)
            .order_by(SignalCard.created_at.desc())
            .limit(limit)
        )
        return list(self.db.scalars(stmt))

    def update_signal_card_confirmation(
        self,
        *,
        user_id: str,
        signal_card_id: str,
        user_confirmation: str,
        user_correction: dict[str, Any] | None = None,
        commit: bool = True,
    ) -> SignalCard | None:
        stmt = select(SignalCard).where(
            SignalCard.user_id == user_id,
            SignalCard.id == signal_card_id,
        )
        signal_card = self.db.scalars(stmt).first()
        if signal_card is None:
            return None

        signal_card.user_confirmation = user_confirmation
        signal_card.user_correction_json = user_correction or {}
        if commit:
            self.db.commit()
        else:
            self.db.flush()
        return signal_card

    def _source_type_from_input_mode(self, input_mode: str | None) -> str:
        value = (input_mode or "").strip().lower()
        if value in {"voice", "voice_input", "speech"}:
            return "voice"
        if value in {"one_tap", "one_tap_state", "status"}:
            return "one_tap"
        if value in {"ai_predicted", "prediction"}:
            return "ai_predicted"
        if value in {"library_saved", "library"}:
            return "library_saved"
        if value == "calendar":
            return "calendar"
        if value == "health":
            return "health"
        return "text"

    def _local_date(self, created_at: datetime, timezone_name: str | None):
        try:
            tz = ZoneInfo(timezone_name or "UTC")
        except ZoneInfoNotFoundError:
            tz = ZoneInfo("UTC")
        if created_at.tzinfo is None:
            created_at = created_at.replace(tzinfo=timezone.utc)
        return created_at.astimezone(tz).date()

    def _intensity_from_legacy_strength(self, value: Any) -> int | None:
        if value is None:
            return None
        if isinstance(value, int):
            return max(1, min(value, 5))
        mapping = {
            "low": 1,
            "medium": 3,
            "high": 5,
        }
        text = str(value).strip().lower()
        if text.isdigit():
            return max(1, min(int(text), 5))
        return mapping.get(text)

    def _energy_load_from_signal(self, parsed_signal: dict[str, Any] | None) -> str | None:
        if not parsed_signal:
            return None
        signal_type = parsed_signal.get("signal_type")
        friction_type = parsed_signal.get("friction_type")
        if signal_type in {"friction", "repetition"} or friction_type not in {None, "", "unknown"}:
            return "draining"
        if signal_type == "desire":
            return "mixed"
        return "neutral"

    def _life_chain_stage(self, parsed_signal: dict[str, Any] | None) -> dict[str, Any]:
        if not parsed_signal:
            return {}
        friction_type = parsed_signal.get("friction_type")
        stages = []
        if friction_type in {"time", "coordination"}:
            stages.extend(["schedule_structure", "attention_switching"])
        elif friction_type in {"information", "decision", "execution"}:
            stages.extend(["attention_switching", "energy_drain"])
        elif friction_type == "emotional":
            stages.extend(["energy_drain", "emotional_response"])
        elif parsed_signal.get("signal_type") in {"friction", "repetition"}:
            stages.extend(["energy_drain", "behavior_pattern"])
        return {"stages": stages}
