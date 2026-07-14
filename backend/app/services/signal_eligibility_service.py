from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from enum import StrEnum
from typing import Any


class SignalEligibilityStage(StrEnum):
    DAILY = "daily"
    WEEKLY = "weekly"
    JOURNEY = "journey"
    EXPERIMENT = "experiment"
    AI_REASON = "ai_reason"
    AI_REFLECT = "ai_reflect"
    ENERGY_BUDGET = "energy_budget"


@dataclass(frozen=True)
class SignalEligibilityResult:
    eligible: bool
    stage: SignalEligibilityStage
    reasons: list[str]
    evaluated_at: datetime
    policy_version: str


class SignalEligibilityService:
    policy_version = "v5_current_objects_only_1"

    def evaluate(
        self,
        signal: Any,
        stage: SignalEligibilityStage | str,
    ) -> SignalEligibilityResult:
        resolved_stage = self._resolve_stage(stage)
        reasons: list[str] = []
        metadata = self._metadata(signal)
        processing_state = getattr(signal, "processing_state", None)
        analysis_policy = getattr(signal, "analysis_policy", None)

        if getattr(signal, "deleted_at", None) is not None:
            reasons.append("deleted")

        if self._truthy(metadata.get("is_local_draft")):
            reasons.append("draft")
        if (
            self._text(getattr(processing_state, "sync_status", "")) == "pending"
            and self._truthy(getattr(processing_state, "is_local_draft", False))
        ):
            reasons.append("draft")
        if (
            self._truthy(metadata.get("sync_failed"))
            or metadata.get("sync_status") == "failed"
            or self._text(getattr(processing_state, "sync_status", "")) == "failed"
            or self._truthy(getattr(processing_state, "sync_failed", False))
        ):
            reasons.append("sync_failed")

        policy_inaccurate = self._truthy(getattr(analysis_policy, "inaccurate", False))
        if policy_inaccurate or self._text(getattr(signal, "user_confirmation", "")) == "inaccurate":
            reasons.append("inaccurate")

        privacy = self._text(
            getattr(analysis_policy, "privacy_level", None)
            or getattr(signal, "privacy_level", "")
        )
        if privacy == "sensitive":
            reasons.append("sensitive")
        if privacy == "excluded":
            reasons.append("excluded")
        if privacy == "do_not_analyze":
            reasons.append("do_not_analyze")

        source_type = self._text(getattr(signal, "source_type", ""))
        if source_type == "library_saved" and not self._has_confirmed_personal_context(signal):
            reasons.append("library_unconfirmed")
        if source_type == "ai_predicted" and not self._has_confirmed_personal_context(signal):
            reasons.append("ai_prediction_unconfirmed")

        if self._requires_non_legacy(resolved_stage) and (
            bool(getattr(signal, "is_legacy", False))
            or self._is_legacy_compatibility_source(source_type)
        ):
            reasons.append("legacy_reference")

        return SignalEligibilityResult(
            eligible=len(reasons) == 0,
            stage=resolved_stage,
            reasons=reasons,
            evaluated_at=datetime.now(timezone.utc),
            policy_version=self.policy_version,
        )

    def is_eligible(
        self,
        signal: Any,
        stage: SignalEligibilityStage | str,
    ) -> bool:
        return self.evaluate(signal, stage).eligible

    def filter(
        self,
        signals: list[Any],
        stage: SignalEligibilityStage | str,
    ) -> list[Any]:
        return [signal for signal in signals if self.is_eligible(signal, stage)]

    def _resolve_stage(self, stage: SignalEligibilityStage | str) -> SignalEligibilityStage:
        if isinstance(stage, SignalEligibilityStage):
            return stage
        return SignalEligibilityStage(stage)

    def _metadata(self, signal: Any) -> dict[str, Any]:
        metadata = getattr(signal, "metadata_json", None)
        return metadata if isinstance(metadata, dict) else {}

    def _has_confirmed_personal_context(self, signal: Any) -> bool:
        confirmation = self._text(getattr(signal, "user_confirmation", ""))
        if confirmation not in {"edited", "supplemented"}:
            return False

        correction = getattr(signal, "user_correction_json", None)
        if not isinstance(correction, dict):
            return False

        edited = str(correction.get("edited_text") or "").strip()
        supplement = str(correction.get("supplement_text") or "").strip()
        return bool(edited or supplement)

    def _requires_non_legacy(self, stage: SignalEligibilityStage) -> bool:
        # Schedule/Goal rows remain readable for migration, deletion and old
        # backups, but never participate in a current product analysis stage.
        return stage in set(SignalEligibilityStage)

    def _is_legacy_compatibility_source(self, source_type: str) -> bool:
        normalized = self._text(source_type)
        return (
            normalized == "calendar"
            or "schedule" in normalized
            or normalized == "goal"
            or normalized.startswith("goal_")
        )

    def _text(self, value: Any) -> str:
        return str(value or "").strip().lower()

    def _truthy(self, value: Any) -> bool:
        if isinstance(value, bool):
            return value
        if isinstance(value, int):
            return value != 0
        if isinstance(value, str):
            return value.strip().lower() in {"1", "true", "yes"}
        return False
