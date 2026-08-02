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
        "--validate",
        action="store_true",
        help="Build a human-readable validation report before writing.",
    )
    parser.add_argument(
        "--report",
        type=Path,
        default=Path("outputs/validation-report.md"),
        help="Markdown validation report path.",
    )
    parser.add_argument(
        "--report-json",
        type=Path,
        default=Path("outputs/validation-report.json"),
        help="JSON validation report path.",
    )
    parser.add_argument(
        "--emulator",
        action="store_true",
        help="Write to the local Firestore Emulator instead of production.",
    )
    parser.add_argument(
        "--emulator-host",
        default=os.getenv("FIRESTORE_EMULATOR_HOST", "127.0.0.1:8080"),
        help="Firestore Emulator host used with --emulator.",
    )
    parser.add_argument(
        "--replace",
        action="store_true",
        help="Use non-merge writes for generated documents.",
    )
    parser.add_argument(
        "--prune",
        action="store_true",
        help=(
            "After writing, delete generated documents that are absent from the workbook. "
            "Import audit history is preserved. Requires --commit."
        ),
    )

    args = parser.parse_args()
    if args.prune and not args.commit:
        parser.error("--prune requires --commit")
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
        prune=args.prune,
        validate=args.validate,
        validation_report_path=args.report if args.validate else None,
        validation_json_path=args.report_json if args.validate else None,
        emulator_host=args.emulator_host if args.emulator else None,
    )
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
