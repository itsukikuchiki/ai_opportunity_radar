from __future__ import annotations

from datetime import date, datetime, timezone
from typing import Any
from uuid import uuid4
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from sqlalchemy import select

from app.models import (
    Capture,
    ExperimentCandidate,
    RawMemory,
    ReflectionResult,
    SignalAnalysisPolicy,
    SignalCard,
    SignalProcessingState,
    TraceLink,
    WeeklyInsight,
)
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
        client_id: str | None = None,
        raw_payload: dict[str, Any] | None = None,
        commit: bool = True,
    ) -> dict[str, Any]:
        ensure_demo_user(self.db, user_id)

        normalized_client_id = (client_id or "").strip() or None
        if normalized_client_id:
            existing_stmt = select(SignalCard).where(
                SignalCard.user_id == user_id,
                SignalCard.client_id == normalized_client_id,
            )
            existing = self.db.scalars(existing_stmt).first()
            if existing is not None:
                if existing.deleted_at is not None:
                    return {
                        "capture_id": existing.capture_id,
                        "raw_memory_id": existing.raw_memory_id,
                        "signal_card_id": existing.id,
                        "client_id": normalized_client_id,
                        "server_id": existing.server_id or existing.id,
                        "created_at": existing.created_at,
                        "local_date": existing.local_date,
                        "acknowledgement": existing.ai_reply or "",
                        "deleted": True,
                    }
                metadata = dict(existing.metadata_json or {})
                metadata["client_id"] = normalized_client_id
                metadata["server_id"] = existing.server_id or existing.id
                existing.metadata_json = metadata
                existing.server_id = existing.server_id or existing.id
                self._ensure_processing_state(
                    signal_card_id=existing.id,
                    sync_status="synced",
                    daily_status="included" if existing.included_in_summary else "not_started",
                    weekly_status="included" if existing.included_in_weekly else "not_started",
                    journey_status="included" if existing.included_in_journey else "not_started",
                )
                self._ensure_analysis_policy(
                    signal_card_id=existing.id,
                    privacy_level=existing.privacy_level,
                    user_confirmation=existing.user_confirmation,
                )
                if commit:
                    self.db.commit()
                else:
                    self.db.flush()
                return {
                    "id": existing.raw_memory_id,
                    "capture_id": existing.capture_id,
                    "raw_memory_id": existing.raw_memory_id,
                    "signal_card_id": existing.id,
                    "content": existing.raw_text,
                    "created_at": existing.created_at,
                    "local_date": existing.local_date,
                    "acknowledgement": existing.ai_reply,
                }

        created_at = datetime.now(timezone.utc)
        capture_id = f"cap_{uuid4().hex[:12]}"
        raw_id = f"raw_{uuid4().hex[:12]}"
        signal_card_id = f"sig_{uuid4().hex[:12]}"
        server_id = signal_card_id
        source_type = self._source_type_from_input_mode(input_mode)
        local_date = self._local_date(created_at, timezone_name)
        payload = dict(raw_payload or {})
        if normalized_client_id:
            payload["client_id"] = normalized_client_id
            payload["server_id"] = server_id

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
            raw_payload_json=payload,
            client_id=normalized_client_id,
            server_id=server_id,
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
            metadata_json={
                **({"tag_hint": tag_hint} if tag_hint else {}),
                **({"client_id": normalized_client_id} if normalized_client_id else {}),
                "server_id": server_id,
            },
        )
        self.db.add(signal_card)
        # These split tables reference SignalCard without ORM relationships.
        # Flush the parent first so strict FK backends cannot schedule either
        # child INSERT ahead of its SignalCard INSERT.
        self.db.flush()
        self._ensure_processing_state(
            signal_card_id=signal_card_id,
            sync_status="synced",
            daily_status="not_started",
            weekly_status="not_started",
            journey_status="not_started",
        )
        self._ensure_analysis_policy(
            signal_card_id=signal_card_id,
            privacy_level="private",
            user_confirmation="unconfirmed",
        )
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

    def mark_signal_card_immediate_safety_risk(
        self,
        *,
        signal_card_id: str,
        commit: bool = True,
    ) -> SignalCard | None:
        signal_card = self.db.get(SignalCard, signal_card_id)
        if signal_card is None:
            return None

        signal_card.privacy_level = "sensitive"
        metadata = dict(signal_card.metadata_json or {})
        metadata["safety_branch"] = "immediate_risk"
        signal_card.metadata_json = metadata

        policy = self._ensure_analysis_policy(
            signal_card_id=signal_card_id,
            privacy_level="sensitive",
            user_confirmation=signal_card.user_confirmation,
        )
        policy.is_sensitive = True
        policy.is_excluded = True
        policy.do_not_analyze = True
        policy.exclusion_reason = "immediate_safety_risk"

        state = self._ensure_processing_state(
            signal_card_id=signal_card_id,
            sync_status="synced",
            daily_status="excluded",
            weekly_status="excluded",
            journey_status="excluded",
        )
        state.reason_status = "excluded"

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
            # Keep the same parent-before-child guarantee for legacy backfill.
            self.db.flush()
            self._ensure_processing_state(
                signal_card_id=signal_card.id,
                sync_status="synced",
                daily_status="not_started",
                weekly_status="not_started",
                journey_status="not_started",
            )
            self._ensure_analysis_policy(
                signal_card_id=signal_card.id,
                privacy_level="private",
                user_confirmation="unconfirmed",
            )
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
        self._backfill_split_tables(user_id=user_id, commit=True)
        stmt = (
            select(SignalCard)
            .where(SignalCard.user_id == user_id)
            .where(SignalCard.deleted_at.is_(None))
            .order_by(SignalCard.created_at.desc())
            .limit(limit)
        )
        return list(self.db.scalars(stmt))

    def soft_delete_signal_card(
        self,
        *,
        user_id: str,
        signal_card_id: str,
        reason: str = "user_deleted",
        commit: bool = True,
    ) -> SignalCard | None:
        signal_card = self._find_signal_card_for_user(
            user_id=user_id,
            signal_card_id=signal_card_id,
            include_deleted=True,
        )
        if signal_card is None:
            return None

        now = datetime.now(timezone.utc)
        ids = self._signal_identity_ids(signal_card)
        signal_card.deleted_at = signal_card.deleted_at or now
        signal_card.deletion_reason = (reason or "user_deleted").strip() or "user_deleted"
        signal_card.tombstone_version = (signal_card.tombstone_version or 0) + 1
        signal_card.restored_at = None
        signal_card.included_in_summary = False
        signal_card.included_in_weekly = False
        signal_card.included_in_journey = False
        metadata = dict(signal_card.metadata_json or {})
        metadata["tombstone"] = {
            "deleted_at": signal_card.deleted_at.isoformat(),
            "reason": signal_card.deletion_reason,
            "version": signal_card.tombstone_version,
        }
        signal_card.metadata_json = metadata

        state = self._ensure_processing_state(
            signal_card_id=signal_card.id,
            sync_status="deleted",
            daily_status="excluded",
            weekly_status="excluded",
            journey_status="excluded",
            last_error=None,
        )
        state.assist_status = "excluded"
        state.reason_status = "excluded"

        policy = self._ensure_analysis_policy(
            signal_card_id=signal_card.id,
            privacy_level=signal_card.privacy_level,
            user_confirmation=signal_card.user_confirmation,
        )
        policy.is_excluded = True
        policy.do_not_analyze = True
        policy.exclusion_reason = "signal_deleted"

        self._propagate_signal_tombstone(
            user_id=user_id,
            signal_ids=ids,
            reason="signal_deleted",
        )
        if commit:
            self.db.commit()
        else:
            self.db.flush()
        return signal_card

    def restore_signal_card(
        self,
        *,
        user_id: str,
        signal_card_id: str,
        commit: bool = True,
    ) -> SignalCard | None:
        signal_card = self._find_signal_card_for_user(
            user_id=user_id,
            signal_card_id=signal_card_id,
            include_deleted=True,
        )
        if signal_card is None:
            return None

        now = datetime.now(timezone.utc)
        ids = self._signal_identity_ids(signal_card)
        signal_card.deleted_at = None
        signal_card.deletion_reason = None
        signal_card.restored_at = now
        metadata = dict(signal_card.metadata_json or {})
        metadata.pop("tombstone", None)
        metadata["restored_at"] = now.isoformat()
        signal_card.metadata_json = metadata

        self._ensure_processing_state(
            signal_card_id=signal_card.id,
            sync_status="synced",
            daily_status="not_started",
            weekly_status="not_started",
            journey_status="not_started",
            last_error=None,
        )
        self._ensure_analysis_policy(
            signal_card_id=signal_card.id,
            privacy_level=signal_card.privacy_level,
            user_confirmation=signal_card.user_confirmation,
        )
        self._mark_trace_links_for_signal(
            user_id=user_id,
            signal_ids=ids,
            status="active",
        )
        self._mark_related_cache_stale(
            user_id=user_id,
            affected_sources=self._affected_trace_sources(
                user_id=user_id,
                signal_ids=ids,
            ),
            signal_ids=ids,
            reason="signal_restored",
        )
        if commit:
            self.db.commit()
        else:
            self.db.flush()
        return signal_card

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
        self._ensure_analysis_policy(
            signal_card_id=signal_card.id,
            privacy_level=signal_card.privacy_level,
            user_confirmation=user_confirmation,
        )
        if commit:
            self.db.commit()
        else:
            self.db.flush()
        return signal_card

    def _find_signal_card_for_user(
        self,
        *,
        user_id: str,
        signal_card_id: str,
        include_deleted: bool = False,
    ) -> SignalCard | None:
        stmt = select(SignalCard).where(
            SignalCard.user_id == user_id,
            (
                (SignalCard.id == signal_card_id)
                | (SignalCard.client_id == signal_card_id)
                | (SignalCard.server_id == signal_card_id)
            ),
        )
        if not include_deleted:
            stmt = stmt.where(SignalCard.deleted_at.is_(None))
        return self.db.scalars(stmt).first()

    def _signal_identity_ids(self, signal_card: SignalCard) -> set[str]:
        return {
            value
            for value in {
                signal_card.id,
                signal_card.client_id,
                signal_card.server_id,
                signal_card.raw_memory_id,
                signal_card.capture_id,
            }
            if value
        }

    def _propagate_signal_tombstone(
        self,
        *,
        user_id: str,
        signal_ids: set[str],
        reason: str,
    ) -> None:
        affected_sources = self._affected_trace_sources(
            user_id=user_id,
            signal_ids=signal_ids,
        )
        self._mark_trace_links_for_signal(
            user_id=user_id,
            signal_ids=signal_ids,
            status="inactive",
        )
        self._mark_related_cache_stale(
            user_id=user_id,
            affected_sources=affected_sources,
            signal_ids=signal_ids,
            reason=reason,
        )

    def _affected_trace_sources(
        self,
        *,
        user_id: str,
        signal_ids: set[str],
    ) -> set[tuple[str, str]]:
        if not signal_ids:
            return set()
        stmt = select(TraceLink).where(
            TraceLink.user_id == user_id,
            (
                ((TraceLink.target_type == "signal_card") & TraceLink.target_id.in_(signal_ids))
                | ((TraceLink.source_type == "signal_card") & TraceLink.source_id.in_(signal_ids))
            ),
        )
        links = list(self.db.scalars(stmt))
        sources = {
            (link.source_type, link.source_id)
            for link in links
            if not (link.source_type == "signal_card" and link.source_id in signal_ids)
        }
        return sources

    def _mark_trace_links_for_signal(
        self,
        *,
        user_id: str,
        signal_ids: set[str],
        status: str,
    ) -> None:
        if not signal_ids:
            return
        now = datetime.now(timezone.utc)
        stmt = select(TraceLink).where(
            TraceLink.user_id == user_id,
            (
                ((TraceLink.target_type == "signal_card") & TraceLink.target_id.in_(signal_ids))
                | ((TraceLink.source_type == "signal_card") & TraceLink.source_id.in_(signal_ids))
            ),
        )
        for link in self.db.scalars(stmt):
            link.status = status
            link.updated_at = now

    def _mark_related_cache_stale(
        self,
        *,
        user_id: str,
        affected_sources: set[tuple[str, str]],
        signal_ids: set[str],
        reason: str,
    ) -> None:
        now = datetime.now(timezone.utc)
        for source_type, source_id in affected_sources:
            for reflection in self.db.scalars(
                select(ReflectionResult).where(
                    ReflectionResult.user_id == user_id,
                    ReflectionResult.source_type == source_type,
                    ReflectionResult.source_id == source_id,
                    ReflectionResult.status.in_(("generated", "confirmed")),
                )
            ):
                reflection.dirty = 1
                reflection.is_stale = 1
                reflection.stale_reason = reason
                reflection.invalidated_at = now

            if source_type == "weekly_snapshot":
                week_start = self._parse_date(source_id)
                if week_start is not None:
                    weekly = self.db.scalars(
                        select(WeeklyInsight).where(
                            WeeklyInsight.user_id == user_id,
                            WeeklyInsight.week_start == week_start,
                        )
                    ).first()
                    if weekly is not None:
                        weekly.status = "stale"

        for candidate in self.db.scalars(
            select(ExperimentCandidate).where(ExperimentCandidate.user_id == user_id)
        ):
            linked_ids = set(candidate.linked_signal_card_ids or [])
            if linked_ids.intersection(signal_ids):
                candidate.status = "stale"
                metadata = dict(candidate.metadata_json or {})
                metadata["stale_reason"] = reason
                metadata["invalidated_at"] = now.isoformat()
                metadata["affected_signal_card_ids"] = sorted(linked_ids.intersection(signal_ids))
                candidate.metadata_json = metadata

    def _parse_date(self, value: str) -> date | None:
        try:
            return date.fromisoformat(value)
        except ValueError:
            return None

    def _ensure_processing_state(
        self,
        *,
        signal_card_id: str,
        sync_status: str = "synced",
        daily_status: str = "not_started",
        weekly_status: str = "not_started",
        journey_status: str = "not_started",
        last_error: str | None = None,
    ) -> SignalProcessingState:
        state = self.db.get(SignalProcessingState, signal_card_id)
        if state is None:
            state = SignalProcessingState(
                signal_id=signal_card_id,
                sync_status=sync_status,
                daily_status=daily_status,
                weekly_status=weekly_status,
                journey_status=journey_status,
                last_error=last_error,
                processing_version="v4_p0_02",
            )
            self.db.add(state)
            return state

        state.sync_status = sync_status
        state.daily_status = daily_status
        state.weekly_status = weekly_status
        state.journey_status = journey_status
        state.last_error = last_error
        state.processing_version = "v4_p0_02"
        return state

    def _ensure_analysis_policy(
        self,
        *,
        signal_card_id: str,
        privacy_level: str = "private",
        user_confirmation: str = "unconfirmed",
    ) -> SignalAnalysisPolicy:
        privacy = (privacy_level or "private").strip().lower()
        confirmation = (user_confirmation or "unconfirmed").strip().lower()
        policy = self.db.get(SignalAnalysisPolicy, signal_card_id)
        if policy is None:
            policy = SignalAnalysisPolicy(signal_id=signal_card_id)
            self.db.add(policy)

        policy.privacy_level = privacy
        policy.is_sensitive = privacy == "sensitive"
        policy.is_excluded = privacy in {
            "sensitive",
            "excluded",
            "do_not_analyze",
        }
        policy.do_not_analyze = privacy in {
            "sensitive",
            "excluded",
            "do_not_analyze",
        }
        policy.confirmed_by_user = confirmation in {
            "confirmed",
            "edited",
            "supplemented",
        }
        policy.inaccurate = confirmation == "inaccurate"
        if policy.exclusion_reason != "immediate_safety_risk":
            policy.exclusion_reason = "inaccurate" if policy.inaccurate else (
                privacy
                if privacy in {"sensitive", "excluded", "do_not_analyze"}
                else None
            )
        return policy

    def _backfill_split_tables(self, user_id: str, commit: bool = True) -> None:
        stmt = select(SignalCard).where(SignalCard.user_id == user_id)
        for signal_card in self.db.scalars(stmt):
            is_deleted = signal_card.deleted_at is not None
            is_analysis_excluded = (
                is_deleted
                or signal_card.privacy_level
                in {"sensitive", "excluded", "do_not_analyze"}
                or signal_card.user_confirmation == "inaccurate"
            )
            daily_status = (
                "excluded"
                if is_analysis_excluded
                else "included" if signal_card.included_in_summary else "not_started"
            )
            weekly_status = (
                "excluded"
                if is_analysis_excluded
                else "included" if signal_card.included_in_weekly else "not_started"
            )
            journey_status = (
                "excluded"
                if is_analysis_excluded
                else "included" if signal_card.included_in_journey else "not_started"
            )
            # This runs from a read path.  It may repair rows missing because
            # they predate the split tables, but it must never reset an
            # existing in-flight/failed state or a user-modified policy.
            state = self.db.get(SignalProcessingState, signal_card.id)
            if state is None:
                self._ensure_processing_state(
                    signal_card_id=signal_card.id,
                    sync_status="deleted" if is_deleted else "synced",
                    daily_status=daily_status,
                    weekly_status=weekly_status,
                    journey_status=journey_status,
                )

            policy = self.db.get(SignalAnalysisPolicy, signal_card.id)
            if policy is None:
                policy = self._ensure_analysis_policy(
                    signal_card_id=signal_card.id,
                    privacy_level=signal_card.privacy_level,
                    user_confirmation=signal_card.user_confirmation,
                )
                if is_deleted:
                    policy.is_excluded = True
                    policy.do_not_analyze = True
                    policy.exclusion_reason = "signal_deleted"
        if commit:
            self.db.commit()
        else:
            self.db.flush()

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
        if value == "time_use":
            return "time_use"
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
