from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.models import PipelineRun


class PipelineRunRepository:
    default_pipeline_version = "v4_p0_05"

    def __init__(self, db: Session):
        self.db = db

    def start(
        self,
        *,
        user_id: str,
        pipeline_type: str,
        source_type: str,
        source_id: str,
        input_hash: str | None = None,
        pipeline_version: str = default_pipeline_version,
    ) -> PipelineRun:
        now = datetime.now(timezone.utc)
        row = PipelineRun(
            id=self._build_run_id(user_id, pipeline_type, source_type, source_id, now),
            user_id=user_id,
            pipeline_type=pipeline_type,
            source_type=source_type,
            source_id=source_id,
            status="running",
            started_at=now,
            input_hash=input_hash,
            pipeline_version=pipeline_version,
        )
        self.db.add(row)
        self.db.flush()
        return row

    def complete(
        self,
        run: PipelineRun,
        *,
        output_hash: str | None = None,
    ) -> PipelineRun:
        run.status = "completed"
        run.finished_at = datetime.now(timezone.utc)
        run.output_hash = output_hash
        run.can_retry = 0
        self.db.flush()
        return run

    def fail(
        self,
        run: PipelineRun,
        *,
        error_code: str | None = None,
        error_message: str | None = None,
        can_retry: bool = True,
    ) -> PipelineRun:
        run.status = "failed"
        run.finished_at = datetime.now(timezone.utc)
        run.error_code = error_code
        run.error_message = error_message
        run.can_retry = 1 if can_retry else 0
        run.retry_count += 1
        self.db.flush()
        return run

    def record_completed(
        self,
        *,
        user_id: str,
        pipeline_type: str,
        source_type: str,
        source_id: str,
        input_hash: str | None = None,
        output_hash: str | None = None,
        pipeline_version: str = default_pipeline_version,
    ) -> PipelineRun:
        run = self.start(
            user_id=user_id,
            pipeline_type=pipeline_type,
            source_type=source_type,
            source_id=source_id,
            input_hash=input_hash,
            pipeline_version=pipeline_version,
        )
        return self.complete(run, output_hash=output_hash)

    def _build_run_id(
        self,
        user_id: str,
        pipeline_type: str,
        source_type: str,
        source_id: str,
        now: datetime,
    ) -> str:
        return "_".join(
            [
                "pipe",
                self._stable_id_part(user_id),
                self._stable_id_part(pipeline_type),
                self._stable_id_part(source_type),
                self._stable_id_part(source_id),
                str(int(now.timestamp() * 1_000_000)),
            ]
        )

    @staticmethod
    def _stable_id_part(raw: str) -> str:
        return "".join(ch if ch.isalnum() or ch == "_" else "_" for ch in raw)
