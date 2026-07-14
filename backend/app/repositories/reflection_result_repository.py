from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import ReflectionResult, ReflectionVersionRegistry


DEFAULT_PROMPT_VERSION = "prompt_reflect_v1"
DEFAULT_MODEL_VERSION = "model_reflect_default"
DEFAULT_PIPELINE_VERSION = "v4_p0_05"


class ReflectionResultRepository:
    def __init__(self, db: Session):
        self.db = db

    def save_current(
        self,
        *,
        user_id: str,
        source_type: str,
        source_id: str,
        reflection_type: str,
        ai_level: str,
        content: dict,
        status: str = "generated",
        schema_version: int = 1,
        prompt_version: str | None = None,
        model_version: str | None = None,
        pipeline_version: str | None = None,
        source_hash: str | None = None,
    ) -> ReflectionResult:
        now = datetime.now(timezone.utc)
        registry = self.get_or_create_registry(
            source_type=source_type,
            reflection_type=reflection_type,
            ai_level=ai_level,
        )
        resolved_prompt_version = prompt_version or registry.prompt_version
        resolved_model_version = model_version or registry.model_version
        resolved_pipeline_version = pipeline_version or registry.pipeline_version
        row_id = "_".join(
            [
                "refl",
                self._stable_id_part(user_id),
                self._stable_id_part(source_type),
                self._stable_id_part(source_id),
                self._stable_id_part(reflection_type),
                str(int(now.timestamp() * 1_000_000)),
            ]
        )

        existing_stmt = select(ReflectionResult).where(
            ReflectionResult.user_id == user_id,
            ReflectionResult.source_type == source_type,
            ReflectionResult.source_id == source_id,
            ReflectionResult.reflection_type == reflection_type,
            ReflectionResult.status.in_(("generated", "confirmed")),
        )
        for existing in self.db.scalars(existing_stmt).all():
            existing.status = "superseded"
            existing.superseded_by = row_id

        row = ReflectionResult(
            id=row_id,
            user_id=user_id,
            source_type=source_type,
            source_id=source_id,
            reflection_type=reflection_type,
            ai_level=ai_level,
            content_json=content,
            status=status,
            schema_version=schema_version,
            prompt_version=resolved_prompt_version,
            model_version=resolved_model_version,
            pipeline_version=resolved_pipeline_version,
            source_hash=source_hash,
            generated_at=now,
        )
        self.db.add(row)
        self.db.flush()
        return row

    def get_latest_current(
        self,
        *,
        user_id: str,
        source_type: str,
        source_id: str,
        reflection_type: str,
        ai_level: str,
    ) -> ReflectionResult | None:
        registry = self.get_or_create_registry(
            source_type=source_type,
            reflection_type=reflection_type,
            ai_level=ai_level,
        )
        stmt = (
            select(ReflectionResult)
            .where(
                ReflectionResult.user_id == user_id,
                ReflectionResult.source_type == source_type,
                ReflectionResult.source_id == source_id,
                ReflectionResult.reflection_type == reflection_type,
                ReflectionResult.ai_level == ai_level,
                ReflectionResult.status.in_(("generated", "confirmed")),
            )
            .order_by(ReflectionResult.generated_at.desc())
        )
        for row in self.db.scalars(stmt):
            if self._matches_registry(row, registry):
                if row.dirty == 0 and row.is_stale == 0:
                    return row
                continue
            self._mark_row_stale_for_rollout(row, "prompt_model_version_changed")
        self.db.flush()
        return None

    def rollout_versions(
        self,
        *,
        source_type: str,
        reflection_type: str,
        ai_level: str,
        prompt_version: str | None = None,
        model_version: str | None = None,
        pipeline_version: str | None = None,
        reason: str = "prompt_model_version_changed",
    ) -> int:
        registry = self.get_or_create_registry(
            source_type=source_type,
            reflection_type=reflection_type,
            ai_level=ai_level,
        )
        next_prompt = prompt_version or registry.prompt_version
        next_model = model_version or registry.model_version
        next_pipeline = pipeline_version or registry.pipeline_version
        if (
            registry.prompt_version == next_prompt
            and registry.model_version == next_model
            and registry.pipeline_version == next_pipeline
        ):
            return 0

        registry.prompt_version = next_prompt
        registry.model_version = next_model
        registry.pipeline_version = next_pipeline
        registry.rollout_reason = reason

        stmt = select(ReflectionResult).where(
            ReflectionResult.source_type == source_type,
            ReflectionResult.reflection_type == reflection_type,
            ReflectionResult.ai_level == ai_level,
            ReflectionResult.status.in_(("generated", "confirmed")),
        )
        stale_count = 0
        for row in self.db.scalars(stmt):
            if not self._matches_registry(row, registry):
                self._mark_row_stale_for_rollout(row, reason)
                stale_count += 1
        self.db.flush()
        return stale_count

    def get_or_create_registry(
        self,
        *,
        source_type: str,
        reflection_type: str,
        ai_level: str,
    ) -> ReflectionVersionRegistry:
        stmt = select(ReflectionVersionRegistry).where(
            ReflectionVersionRegistry.source_type == source_type,
            ReflectionVersionRegistry.reflection_type == reflection_type,
            ReflectionVersionRegistry.ai_level == ai_level,
        )
        existing = self.db.scalars(stmt).first()
        if existing is not None:
            return existing

        row = ReflectionVersionRegistry(
            id="reflver_"
            + "_".join(
                [
                    self._stable_id_part(source_type),
                    self._stable_id_part(reflection_type),
                    self._stable_id_part(ai_level),
                ]
            ),
            source_type=source_type,
            reflection_type=reflection_type,
            ai_level=ai_level,
            prompt_version=DEFAULT_PROMPT_VERSION,
            model_version=DEFAULT_MODEL_VERSION,
            pipeline_version=DEFAULT_PIPELINE_VERSION,
        )
        self.db.add(row)
        self.db.flush()
        return row

    def _matches_registry(
        self,
        row: ReflectionResult,
        registry: ReflectionVersionRegistry,
    ) -> bool:
        return (
            row.prompt_version == registry.prompt_version
            and row.model_version == registry.model_version
            and row.pipeline_version == registry.pipeline_version
        )

    def _mark_row_stale_for_rollout(
        self,
        row: ReflectionResult,
        reason: str,
    ) -> None:
        row.is_stale = 1
        row.dirty = 0
        row.stale_reason = reason
        row.invalidated_at = datetime.now(timezone.utc)

    @staticmethod
    def _stable_id_part(raw: str) -> str:
        return "".join(ch if ch.isalnum() or ch == "_" else "_" for ch in raw)
