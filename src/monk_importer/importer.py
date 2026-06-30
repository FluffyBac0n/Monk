from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

from .workbook import build_import_payload


DEFAULT_WORKBOOK_PATH = Path("data/Cyprus_E4_Data_v4 - Cleaned-nopass.xlsx")


def run_import(
    *,
    workbook_path: Path = DEFAULT_WORKBOOK_PATH,
    trail_id: str = "cyprus-e4",
    route_chunk_size: int = 500,
    route_version: int = 1,
    dry_run: bool = True,
    output_path: Path | None = None,
    project_id: str | None = None,
    service_account_path: str | None = None,
    merge: bool = True,
) -> dict[str, Any]:
    try:
        from dotenv import load_dotenv

        load_dotenv()
    except ModuleNotFoundError:
        pass

    workbook_path = workbook_path.expanduser().resolve()
    payload = build_import_payload(
        workbook_path,
        trail_id=trail_id,
        route_chunk_size=route_chunk_size,
        route_version=route_version,
    )

    summary = {
        "trailId": payload.trailId,
        "stageCount": len(payload.stages),
        "lodgingCount": len(payload.lodgings),
        "routePointCount": payload.routeMetadata.pointCount,
        "routeChunkCount": len(payload.routeChunks),
        "routeMarkerCount": len(payload.routeMarkers),
        "warnings": payload.warnings,
        "dryRun": dry_run,
    }

    if output_path:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(
            json.dumps(payload.model_dump(mode="json"), indent=2, ensure_ascii=False),
            encoding="utf-8",
        )

    if dry_run:
        return summary

    from .firestore_writer import get_firestore_client, write_import_payload

    db = get_firestore_client(
        project_id=project_id or os.getenv("FIREBASE_PROJECT_ID") or None,
        service_account_path=service_account_path or os.getenv("GOOGLE_APPLICATION_CREDENTIALS") or None,
    )
    summary["written"] = write_import_payload(db, payload, merge=merge)
    return summary
