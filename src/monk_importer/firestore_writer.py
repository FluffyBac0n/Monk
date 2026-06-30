from __future__ import annotations

from datetime import UTC, datetime
import os
from typing import Any, Iterable

import firebase_admin
from firebase_admin import credentials, firestore
from google.auth.credentials import AnonymousCredentials
from google.cloud import firestore as google_firestore
from google.cloud.firestore_v1 import Client

from .models import ImportPayload
from .utils import compact_doc


def get_firestore_client(
    *,
    project_id: str | None = None,
    service_account_path: str | None = None,
    emulator_host: str | None = None,
) -> Client:
    if emulator_host:
        os.environ["FIRESTORE_EMULATOR_HOST"] = emulator_host
        return google_firestore.Client(
            project=project_id or "monk-local",
            credentials=AnonymousCredentials(),
        )

    if not firebase_admin._apps:
        if service_account_path:
            cred = credentials.Certificate(service_account_path)
            firebase_admin.initialize_app(cred, {"projectId": project_id} if project_id else None)
        else:
            firebase_admin.initialize_app(options={"projectId": project_id} if project_id else None)
    return firestore.client()


def write_import_payload(db: Client, payload: ImportPayload, *, merge: bool = True) -> dict[str, int]:
    now = datetime.now(UTC)
    trail_ref = db.collection("trails").document(payload.trailId)
    trail_ref.set({**compact_doc(payload.trail), "updatedAt": now}, merge=merge)

    counts = {
        "trails": 1,
        "stages": write_collection(trail_ref.collection("stages"), payload.stages, merge=merge),
        "lodgings": write_collection(trail_ref.collection("lodgings"), payload.lodgings, merge=merge),
        "routeChunks": write_collection(
            trail_ref.collection("routeChunks"),
            payload.routeChunks,
            merge=merge,
        ),
        "routeMarkers": write_collection(
            trail_ref.collection("routeMarkers"),
            payload.routeMarkers,
            merge=merge,
        ),
    }

    metadata = payload.routeMetadata.model_dump(mode="json", exclude_none=True)
    trail_ref.collection("routeMetadata").document("main").set(
        {**metadata, "updatedAt": now},
        merge=merge,
    )
    counts["routeMetadata"] = 1

    import_ref = trail_ref.collection("imports").document(now.strftime("%Y%m%dT%H%M%SZ"))
    import_ref.set(
        {
            "createdAt": now,
            "stageCount": len(payload.stages),
            "lodgingCount": len(payload.lodgings),
            "routePointCount": payload.routeMetadata.pointCount,
            "routeChunkCount": len(payload.routeChunks),
            "routeMarkerCount": len(payload.routeMarkers),
            "warnings": payload.warnings,
        }
    )
    counts["imports"] = 1
    return counts


def write_collection(collection_ref: Any, models: Iterable[Any], *, merge: bool) -> int:
    batch = collection_ref._client.batch()
    pending = 0
    total = 0
    for model in models:
        data = compact_doc(model.model_dump(mode="json", exclude_none=True, exclude={"id"}))
        data["updatedAt"] = datetime.now(UTC)
        batch.set(collection_ref.document(model.id), data, merge=merge)
        pending += 1
        total += 1
        if pending == 450:
            batch.commit()
            batch = collection_ref._client.batch()
            pending = 0
    if pending:
        batch.commit()
    return total
