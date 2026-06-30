from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from .importer import DEFAULT_WORKBOOK_PATH, run_import


def main() -> None:
    parser = argparse.ArgumentParser(description="Import Cyprus E4 workbook data into Firestore.")
    parser.add_argument(
        "--workbook",
        type=Path,
        default=Path(os.getenv("MONK_WORKBOOK_PATH", DEFAULT_WORKBOOK_PATH)),
        help="Path to the source Excel workbook.",
    )
    parser.add_argument(
        "--trail-id",
        default=os.getenv("MONK_TRAIL_ID", "cyprus-e4"),
        help="Firestore trail document ID.",
    )
    parser.add_argument("--chunk-size", type=int, default=500, help="Route points per chunk.")
    parser.add_argument("--route-version", type=int, default=1, help="Route data version.")
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("outputs/import-preview.json"),
        help="JSON preview path for dry runs.",
    )
    parser.add_argument("--project-id", default=os.getenv("FIREBASE_PROJECT_ID"))
    parser.add_argument("--service-account", default=os.getenv("GOOGLE_APPLICATION_CREDENTIALS"))
    parser.add_argument("--commit", action="store_true", help="Write to Firestore.")
    parser.add_argument(
        "--replace",
        action="store_true",
        help="Use non-merge writes for generated documents.",
    )

    args = parser.parse_args()
    summary = run_import(
        workbook_path=args.workbook,
        trail_id=args.trail_id,
        route_chunk_size=args.chunk_size,
        route_version=args.route_version,
        dry_run=not args.commit,
        output_path=args.output if not args.commit else None,
        project_id=args.project_id,
        service_account_path=args.service_account,
        merge=not args.replace,
    )
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()

