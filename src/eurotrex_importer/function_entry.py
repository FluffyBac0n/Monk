from __future__ import annotations

from pathlib import Path
from typing import Any

from .importer import run_import


def import_trail_http(request: Any) -> tuple[dict[str, Any], int]:
    """HTTP-style function wrapper.

    This is intentionally thin. In production, the request should usually point
    to a workbook in Cloud Storage, download it to /tmp, then call run_import().
    """
    body = request.get_json(silent=True) or {}
    workbook_path = Path(body.get("workbookPath", "data/Cyprus_E4_Data_v4 - Cleaned-nopass.xlsx"))
    summary = run_import(
        workbook_path=workbook_path,
        trail_id=body.get("trailId", "cyprus-e4"),
        route_chunk_size=int(body.get("chunkSize", 500)),
        route_version=int(body.get("routeVersion", 1)),
        dry_run=bool(body.get("dryRun", True)),
        project_id=body.get("projectId"),
        merge=bool(body.get("merge", True)),
        prune=bool(body.get("prune", False)),
    )
    return summary, 200
