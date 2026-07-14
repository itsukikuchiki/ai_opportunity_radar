from __future__ import annotations

from dataclasses import dataclass
from typing import Literal


AiLayer = Literal["L1_ASSIST", "L2_REASON", "L3_REFLECT"]


@dataclass(frozen=True)
class AiTaskProfile:
    layer: AiLayer
    feature_key: str
    usage_endpoint: str
    model_label: str
    product_role: str
    user_participation: str
    prompt_principle: str


class AiOrchestrator:
    """Routes AI work by problem depth instead of provider model names."""

    L1_ASSIST_DAILY_FLOW = AiTaskProfile(
        layer="L1_ASSIST",
        feature_key="l1_assist_daily_flow",
        usage_endpoint="l1_assist_daily_flow",
        model_label="l1_assist",
        product_role="keep_recording_flow_smooth",
        user_participation="can_accept_directly",
        prompt_principle="help_record_not_think",
    )
    L1_ATTUNE_DIALOGUE = AiTaskProfile(
        layer="L1_ASSIST",
        feature_key="l1_attune_dialogue",
        usage_endpoint="l1_attune_dialogue",
        model_label="l1_attune",
        product_role="receive_emotion_and_offer_light_feedback",
        user_participation="user_leads_the_conversation",
        prompt_principle="acknowledge_current_feeling_without_pattern_claims",
    )
    L2_REASON_PATTERN_CHECK = AiTaskProfile(
        layer="L2_REASON",
        feature_key="l2_reason_pattern_check",
        usage_endpoint="l2_reason_pattern_check",
        model_label="l2_reason",
        product_role="hypothesis_not_conclusion",
        user_participation="requires_confirmation",
        prompt_principle="ai_judgment_then_human_confirm",
    )
    L3_REFLECT_WEEKLY = AiTaskProfile(
        layer="L3_REFLECT",
        feature_key="l3_reflect_weekly",
        usage_endpoint="l3_reflect_weekly",
        model_label="l3_reflect",
        product_role="deep_weekly_reflection",
        user_participation="read_edit_adopt",
        prompt_principle="deep_only_when_needed",
    )
    L3_REFLECT_JOURNEY = AiTaskProfile(
        layer="L3_REFLECT",
        feature_key="l3_reflect_journey",
        usage_endpoint="l3_reflect_journey",
        model_label="l3_reflect",
        product_role="long_term_life_map",
        user_participation="read_edit_adopt",
        prompt_principle="deep_only_when_needed",
    )
    L3_REFLECT_LIFE_EXPERIMENT = AiTaskProfile(
        layer="L3_REFLECT",
        feature_key="l3_reflect_life_experiment",
        usage_endpoint="l3_reflect_life_experiment",
        model_label="l3_reflect",
        product_role="evaluate_life_experiment_effect",
        user_participation="read_edit_adopt",
        prompt_principle="deep_only_when_needed",
    )

    LEGACY_FEATURE_KEYS = {
        "l1_assist_daily_flow": L1_ASSIST_DAILY_FLOW,
        "l1_attune_dialogue": L1_ATTUNE_DIALOGUE,
        "l2_reason_pattern_check": L2_REASON_PATTERN_CHECK,
        "l3_reflect_weekly": L3_REFLECT_WEEKLY,
        "l3_reflect_journey": L3_REFLECT_JOURNEY,
        "l3_reflect_life_experiment": L3_REFLECT_LIFE_EXPERIMENT,
        "signal_parser": L1_ASSIST_DAILY_FLOW,
        "today_high_quality_reply": L1_ASSIST_DAILY_FLOW,
        "weekly_basic": L2_REASON_PATTERN_CHECK,
        "life_experiment_light": L2_REASON_PATTERN_CHECK,
        "light_dialogue_turn": L2_REASON_PATTERN_CHECK,
        "deep_weekly": L3_REFLECT_WEEKLY,
        "gpt55_deep_upgrade": L3_REFLECT_WEEKLY,
        "journey_monthly_life_map": L3_REFLECT_JOURNEY,
        "misunderstanding_check": L2_REASON_PATTERN_CHECK,
    }

    ENDPOINTS = {
        "capture_reply": L1_ATTUNE_DIALOGUE,
        "today_summary": L1_ASSIST_DAILY_FLOW,
        "light_dialog": L1_ATTUNE_DIALOGUE,
        "followup_question": L2_REASON_PATTERN_CHECK,
        "weekly_generate": L2_REASON_PATTERN_CHECK,
        "deep_weekly": L3_REFLECT_WEEKLY,
        "reflect_weekly": L3_REFLECT_WEEKLY,
        "journey_generate": L3_REFLECT_JOURNEY,
        "monthly_generate": L3_REFLECT_JOURNEY,
    }

    @classmethod
    def from_feature_key(cls, feature_key: str) -> AiTaskProfile:
        return cls.LEGACY_FEATURE_KEYS.get(feature_key, cls.L2_REASON_PATTERN_CHECK)

    @classmethod
    def from_endpoint(cls, endpoint: str) -> AiTaskProfile:
        return cls.ENDPOINTS.get(endpoint, cls.L2_REASON_PATTERN_CHECK)

    @staticmethod
    def metadata(profile: AiTaskProfile) -> dict[str, str]:
        return {
            "ai_layer": profile.layer,
            "product_role": profile.product_role,
            "user_participation": profile.user_participation,
            "prompt_principle": profile.prompt_principle,
        }
