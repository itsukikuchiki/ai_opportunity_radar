from __future__ import annotations

from time import perf_counter

from app.schemas.capture_schema import (
    CaptureSubmitResponseSchema,
    RecentSignalSchema,
)
from app.services.classification_service import ClassificationService
from app.repositories.capture_repository import CaptureRepository
from app.services.usage_service import UsageService


class CaptureService:
    def __init__(
        self,
        capture_repository: CaptureRepository,
        classification_service: ClassificationService,
        usage_service: UsageService | None = None,
    ):
        self.capture_repository = capture_repository
        self.classification_service = classification_service
        self.usage_service = usage_service

    def submit_capture(
        self,
        user_id: str,
        content: str,
        input_mode: str = "quick_capture",
        tag_hint: str | None = None,
        language: str = "en",
        timezone_name: str = "UTC",
    ) -> CaptureSubmitResponseSchema:
        content = (content or "").strip()
        if not content:
            raise ValueError("content is required")

        created = self.capture_repository.create_capture_skeleton(
            user_id=user_id,
            content=content,
            input_mode=input_mode,
            tag_hint=tag_hint,
            language=language,
            timezone_name=timezone_name,
            commit=True,
        )
        signal_card_id = created["signal_card_id"]

        parser_started_at = perf_counter()
        parsed_signal = None
        try:
            parsed_signal = self.classification_service.classify_capture(
                content,
                tag_hint,
            )
            self.capture_repository.update_signal_card_parser_result(
                signal_card_id=signal_card_id,
                parsed_signal=parsed_signal,
                parser_version="v3_rules_1",
                model_used="local_rules_parser",
                commit=True,
            )
            self._log_model_usage(
                user_id=user_id,
                feature_key="signal_parser",
                model_used="local_rules_parser",
                request_payload={"source_type": input_mode, "tag_hint": tag_hint},
                response_payload=parsed_signal,
                source_event_id=signal_card_id,
                started_at=parser_started_at,
                fallback_used=False,
                quota_decision="allowed",
                metadata={"parser_status": "parsed"},
            )
        except Exception as exc:  # parser failure must not undo saved raw input
            self.capture_repository.update_signal_card_parser_result(
                signal_card_id=signal_card_id,
                parsed_signal=None,
                parser_version="v3_rules_1",
                model_used="local_rules_parser",
                error=str(exc),
                commit=True,
            )
            self._log_model_usage(
                user_id=user_id,
                feature_key="signal_parser",
                model_used="local_rules_parser",
                request_payload={"source_type": input_mode, "tag_hint": tag_hint},
                response_payload={"error": "parser_failed"},
                source_event_id=signal_card_id,
                started_at=parser_started_at,
                fallback_used=True,
                quota_decision="allowed",
                metadata={"parser_status": "failed", "error_type": type(exc).__name__},
            )

        previous_recent = self.capture_repository.list_recent_raw_memories(
            user_id=user_id,
            limit=10,
        )
        recent_assistant_texts = [
            item.get("acknowledgement")
            for item in previous_recent
            if item.get("acknowledgement")
        ]

        quota_decision = self._check_quota(
            user_id=user_id,
            local_date=created["local_date"],
            source_event_id=signal_card_id,
        )
        reply_started_at = perf_counter()
        fallback_used = False
        model_used = "local_rules_reply"
        if quota_decision == "quota_exceeded":
            acknowledgement = self._fallback_reply(language)
            fallback_used = True
            model_used = "local_fallback"
        else:
            try:
                acknowledgement = self.classification_service.generate_acknowledgement(
                    content,
                    classified_signal=parsed_signal,
                    recent_assistant_texts=recent_assistant_texts,
                )
            except Exception:
                acknowledgement = self._fallback_reply(language)
                fallback_used = True
                model_used = "local_fallback"

        self.capture_repository.update_signal_card_ai_result(
            signal_card_id=signal_card_id,
            acknowledgement=acknowledgement,
            model_used=model_used,
            fallback_used=fallback_used,
            quota_decision=quota_decision,
            token_usage={},
            commit=True,
        )
        self._log_model_usage(
            user_id=user_id,
            feature_key="today_high_quality_reply",
            model_used=model_used,
            request_payload={"source_type": input_mode, "language": language},
            response_payload={"fallback_used": fallback_used},
            source_event_id=signal_card_id,
            started_at=reply_started_at,
            fallback_used=fallback_used,
            quota_decision=quota_decision,
            metadata={"reply_status": "fallback" if fallback_used else "generated"},
        )
        if quota_decision == "allowed" and not fallback_used:
            self._consume_quota(
                user_id=user_id,
                local_date=created["local_date"],
                model_used=model_used,
                source_event_id=signal_card_id,
            )

        return CaptureSubmitResponseSchema(
            acknowledgement=acknowledgement,
            followup=None,
            recent_signals=self.list_recent_signal_cards(user_id=user_id, limit=50),
        )

    def list_recent_signals(
        self,
        user_id: str,
        limit: int = 200,
    ) -> list[RecentSignalSchema]:
        recent = self.capture_repository.list_recent_raw_memories(
            user_id=user_id,
            limit=limit,
        )
        return [
            RecentSignalSchema(
                id=item.get("id"),
                content=item.get("content") or "",
                created_at=item.get("created_at"),
                acknowledgement=item.get("acknowledgement"),
            )
            for item in recent
        ]

    def list_recent_signal_cards(
        self,
        user_id: str,
        limit: int = 200,
    ) -> list[RecentSignalSchema]:
        cards = self.capture_repository.list_recent_signal_cards(
            user_id=user_id,
            limit=limit,
        )
        return [
            RecentSignalSchema(
                id=card.raw_memory_id,
                signal_card_id=card.id,
                content=card.raw_text or "",
                created_at=card.created_at,
                local_date=card.local_date,
                timezone=card.timezone,
                language=card.language,
                acknowledgement=card.ai_reply,
                emotion=self._recent_emotion(card.emotion, card.energy_load),
                intensity=self._recent_intensity(card.intensity),
                scene=card.scene,
                friction=card.friction,
                positive_signal=card.positive_signal,
                energy_load=card.energy_load,
                user_confirmation=card.user_confirmation,
                user_correction_json=card.user_correction_json or {},
                included_in_summary=card.included_in_summary,
                included_in_weekly=card.included_in_weekly,
                included_in_journey=card.included_in_journey,
                is_legacy=card.is_legacy,
                migration_status=card.migration_status,
            )
            for card in cards
        ]

    def _recent_emotion(self, emotion: str | None, energy_load: str | None) -> str:
        value = (emotion or "").strip().lower()
        if value in {"positive", "negative", "mixed", "neutral"}:
            return value
        load = (energy_load or "").strip().lower()
        if load == "restorative":
            return "positive"
        if load == "draining":
            return "negative"
        return "neutral"

    def _recent_intensity(self, intensity) -> str:
        if isinstance(intensity, str):
            value = intensity.strip().lower()
            if value in {"low", "medium", "high"}:
                return value
            try:
                intensity = int(value)
            except ValueError:
                return "low"
        if isinstance(intensity, (int, float)):
            if intensity >= 3:
                return "high"
            if intensity >= 2:
                return "medium"
        return "low"

    def _check_quota(
        self,
        *,
        user_id: str,
        local_date,
        source_event_id: str,
    ) -> str:
        if self.usage_service is None:
            return "allowed"
        decision = self.usage_service.check_quota(
            user_id=user_id,
            feature_key="today_high_quality_reply",
            local_date=local_date,
            source_event_id=source_event_id,
            commit=True,
        )
        return decision.decision

    def _consume_quota(
        self,
        *,
        user_id: str,
        local_date,
        model_used: str,
        source_event_id: str,
    ) -> None:
        if self.usage_service is None:
            return
        self.usage_service.consume_quota(
            user_id=user_id,
            feature_key="today_high_quality_reply",
            local_date=local_date,
            model_used=model_used,
            source_event_id=source_event_id,
            commit=True,
        )

    def _log_model_usage(
        self,
        *,
        user_id: str,
        feature_key: str,
        model_used: str,
        request_payload: object,
        response_payload: object,
        source_event_id: str,
        started_at: float,
        fallback_used: bool,
        quota_decision: str,
        metadata: dict,
    ) -> None:
        if self.usage_service is None:
            return
        self.usage_service.log_model_usage(
            user_id=user_id,
            feature_key=feature_key,
            model_used=model_used,
            parser_version="v3_rules_1" if feature_key == "signal_parser" else None,
            prompt_version="today_reply_v3_local",
            request_payload=request_payload,
            response_payload=response_payload,
            fallback_used=fallback_used,
            quota_decision=quota_decision,
            source_event_id=source_event_id,
            started_at=started_at,
            metadata=metadata,
            commit=True,
        )

    def _fallback_reply(self, language: str) -> str:
        if language == "ja":
            return "保存しました。意味づけはあとで一緒に見直せます。"
        if language in {"zh", "zh-Hans", "zh-Hant"}:
            return "我先帮你保存下来了，后面我们再一起看它意味着什么。"
        return "I saved this. We can come back to what it means later."
