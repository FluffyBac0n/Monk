from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

from .validator import build_validation_report, write_validation_report
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
    prune: bool = False,
    validate: bool = False,
    validation_report_path: Path | None = None,
    validation_json_path: Path | None = None,
    emulator_host: str | None = None,
) -> dict[str, Any]:
    if prune and dry_run:
        raise ValueError("Pruning requires a committed import (dry_run=False).")

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
        "excursionCount": len(payload.excursions),
        "excursionRouteChunkCount": sum(
            len(chunks) for chunks in payload.excursionRouteChunks.values()
        ),
        "detourCount": len(payload.detours),
        "detourRouteChunkCount": sum(len(chunks) for chunks in payload.detourRouteChunks.values()),
        "routePointCount": payload.routeMetadata.pointCount,
        "routeChunkCount": len(payload.routeChunks),
        "routeMarkerCount": len(payload.routeMarkers),
        "warnings": payload.warnings,
        "dryRun": dry_run,
    }

    if validate or validation_report_path or validation_json_path or prune:
        report = build_validation_report(payload)
        summary["validationOk"] = report["ok"]
        summary["validationIssues"] = report["issues"]
        if validation_report_path:
            write_validation_report(report, validation_report_path, validation_json_path)
            summary["validationReport"] = str(validation_report_path)
            if validation_json_path:
                summary["validationJson"] = str(validation_json_path)
        if prune and not report["ok"]:
            raise ValueError(
                "Refusing to prune because workbook validation failed: "
                + "; ".join(report["issues"])
            )

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
        service_account_path=service_account_path
        or os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
        or None,
        emulator_host=emulator_host or os.getenv("FIRESTORE_EMULATOR_HOST") or None,
    )
    summary["written"] = write_import_payload(db, payload, merge=merge, prune=prune)
    return summary
