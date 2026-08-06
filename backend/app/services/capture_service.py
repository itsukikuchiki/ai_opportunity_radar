from __future__ import annotations

from time import perf_counter

from app.schemas.capture_schema import (
    CaptureSubmitResponseSchema,
    RecentSignalSchema,
)
from app.services.energy_state_service import classify_signal_energy_state
from app.services.classification_service import ClassificationService
from app.repositories.capture_repository import CaptureRepository
from app.services.ai_orchestrator import AiOrchestrator
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
        self.parse_profile = AiOrchestrator.L1_ASSIST_DAILY_FLOW
        self.attune_profile = AiOrchestrator.L1_ATTUNE_DIALOGUE

    def submit_capture(
        self,
        user_id: str,
        content: str,
        input_mode: str = "quick_capture",
        tag_hint: str | None = None,
        language: str = "en",
        timezone_name: str = "UTC",
        client_id: str | None = None,
        raw_payload_json: dict | None = None,
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
            client_id=client_id,
            raw_payload=raw_payload_json,
            commit=True,
        )
        if created.get("deleted"):
            return CaptureSubmitResponseSchema(
                acknowledgement=created.get("acknowledgement")
                or self._deleted_capture_reply(language),
                followup=None,
                recent_signals=self.list_recent_signal_cards(user_id=user_id, limit=50),
            )
        signal_card_id = created["signal_card_id"]

        risk_checker = getattr(
            self.classification_service,
            "is_immediate_safety_risk",
            lambda _: False,
        )
        if risk_checker(content):
            acknowledgement = (
                self.classification_service.immediate_safety_acknowledgement(
                    language
                )
            )
            self.capture_repository.mark_signal_card_immediate_safety_risk(
                signal_card_id=signal_card_id,
                commit=True,
            )
            self.capture_repository.update_signal_card_ai_result(
                signal_card_id=signal_card_id,
                acknowledgement=acknowledgement,
                model_used="local_safety_rules",
                fallback_used=False,
                quota_decision="safety_bypass",
                token_usage={},
                commit=True,
            )
            self._log_model_usage(
                user_id=user_id,
                feature_key=self.attune_profile.feature_key,
                model_used="local_safety_rules",
                request_payload={"source_type": input_mode, "safety_branch": True},
                response_payload={"safety_response": True},
                source_event_id=signal_card_id,
                started_at=perf_counter(),
                fallback_used=False,
                quota_decision="safety_bypass",
                metadata={"reply_status": "safety"},
            )
            return CaptureSubmitResponseSchema(
                acknowledgement=acknowledgement,
                followup=None,
                recent_signals=self.list_recent_signal_cards(
                    user_id=user_id,
                    limit=50,
                ),
            )

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
                feature_key=self.parse_profile.feature_key,
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
                feature_key=self.parse_profile.feature_key,
                model_used="local_rules_parser",
                request_payload={"source_type": input_mode, "tag_hint": tag_hint},
                response_payload={"error": "parser_failed"},
                source_event_id=signal_card_id,
                started_at=parser_started_at,
                fallback_used=True,
                quota_decision="allowed",
                metadata={"parser_status": "failed", "error_type": type(exc).__name__},
            )

        previous_recent_cards = self.capture_repository.list_recent_signal_cards(
            user_id=user_id,
            limit=10,
        )
        recent_assistant_texts = [
            card.ai_reply
            for card in previous_recent_cards
            if card.ai_reply
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
            acknowledgement = self._fallback_reply(language, content)
            fallback_used = True
            model_used = "local_fallback"
        else:
            try:
                acknowledgement = self.classification_service.generate_acknowledgement(
                    content,
                    classified_signal=parsed_signal,
                    recent_assistant_texts=recent_assistant_texts,
                    language=language,
                )
            except Exception:
                acknowledgement = self._fallback_reply(language, content)
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
            feature_key=self.attune_profile.feature_key,
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
        return self.list_recent_signal_cards(user_id=user_id, limit=limit)

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
                id=card.id,
                signal_card_id=card.id,
                client_id=card.client_id,
                server_id=card.server_id or card.id,
                source_type=card.source_type,
                raw_payload_json=card.raw_payload_json or {},
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
                energy_state=classify_signal_energy_state(
                    source_type=card.source_type,
                    raw_payload=card.raw_payload_json or {},
                    energy_load=card.energy_load,
                    friction=card.friction,
                    positive_signal=card.positive_signal,
                    linked_life_chain_stage=card.linked_life_chain_stage or {},
                    content=card.raw_text or "",
                ),
                linked_life_chain_stage=self._life_chain_stages(
                    card.linked_life_chain_stage
                ),
                user_confirmation=card.user_confirmation,
                user_correction_json=card.user_correction_json or {},
                included_in_summary=card.included_in_summary,
                included_in_weekly=card.included_in_weekly,
                included_in_journey=card.included_in_journey,
                is_legacy=card.is_legacy,
                migration_status=card.migration_status,
                deleted_at=card.deleted_at,
                deletion_reason=card.deletion_reason,
                tombstone_version=card.tombstone_version or 0,
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

    def _life_chain_stages(self, raw) -> list[str]:
        if isinstance(raw, dict):
            raw = raw.get("stages", [])
        if isinstance(raw, str):
            raw = [raw]
        if not isinstance(raw, (list, tuple, set)):
            return []
        return [
            value
            for item in raw
            if (value := str(item or "").strip())
        ]

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
            feature_key=self.attune_profile.feature_key,
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
            feature_key=self.attune_profile.feature_key,
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
            parser_version="v3_rules_1" if model_used == "local_rules_parser" else None,
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

    def _fallback_reply(self, language: str, content: str = "") -> str:
        normalized_language = (language or "").strip().lower().replace("_", "-")
        if normalized_language.startswith("ja"):
            display_language = "ja"
        elif normalized_language in {"zh-hant", "zh-tw", "zh-hk", "zh-mo"}:
            display_language = "zh-Hant"
        elif normalized_language.startswith("zh"):
            display_language = "zh-Hans"
        else:
            display_language = "en"
        normalized = (content or "").strip().lower()
        overload = any(token in normalized for token in [
            "事情太多", "太多了", "一堆事", "忙不过来", "忙不完",
            "事情太雜", "忙不過來", "多すぎ", "やることが多",
            "too much", "too many", "overwhelmed",
        ])
        fatigue = any(token in normalized for token in [
            "好累", "很累", "累了", "疲惫", "疲憊", "撑不住", "撐不住",
            "疲れた", "しんどい", "tired", "exhausted",
        ])
        if display_language == "ja":
            if overload:
                return "いろいろなことが一度に重なると、息をつく余裕もなくなるほど苦しくなりますよね。"
            if fatigue:
                return "今、本当に疲れているのですね。その疲れはきちんと受け止めたいです。"
            return "今話してくれたことを、こちらで意味を決めつけずに受け止めます。"
        if display_language == "zh-Hant":
            if overload:
                return "一下子有這麼多事壓過來，確實很容易讓人喘不過氣。"
            if fatigue:
                return "聽起來你現在真的很累，這份疲憊值得被好好看見。"
            return "我聽見你剛才說的這件事了，先不替你的感受下結論。"
        if display_language == "zh-Hans":
            if overload:
                return "一下子有这么多事压过来，确实很容易让人喘不过气。"
            if fatigue:
                return "听起来你现在真的很累，这份疲惫值得被好好看见。"
            return "我听见你刚才说的这件事了，先不替你的感受下结论。"
        if overload:
            return "Having so many things land at once can feel genuinely overwhelming."
        if fatigue:
            return "You sound genuinely tired, and that exhaustion deserves to be noticed."
        return "I hear what you just said without deciding what it means for you."

    def _deleted_capture_reply(self, language: str) -> str:
        normalized = (language or "").strip().lower().replace("_", "-")
        if normalized.startswith("ja"):
            return "このシグナルカードは削除されました。"
        if normalized in {"zh-hant", "zh-tw", "zh-hk", "zh-mo"}:
            return "這張信號卡已刪除。"
        if normalized.startswith("zh"):
            return "这张信号卡已删除。"
        return "This Signal card was deleted."
