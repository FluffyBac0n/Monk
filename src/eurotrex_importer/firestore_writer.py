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
            project=project_id or "eurotrex-local",
            credentials=AnonymousCredentials(),
        )

    if not firebase_admin._apps:
        if service_account_path:
            cred = credentials.Certificate(service_account_path)
            firebase_admin.initialize_app(cred, {"projectId": project_id} if project_id else None)
        else:
            firebase_admin.initialize_app(options={"projectId": project_id} if project_id else None)
    return firestore.client()


def write_import_payload(
    db: Client,
    payload: ImportPayload,
    *,
    merge: bool = True,
    prune: bool = False,
) -> dict[str, int | dict[str, int]]:
    now = datetime.now(UTC)
    trail_ref = db.collection("trails").document(payload.trailId)
    trail_ref.set({**compact_doc(payload.trail), "updatedAt": now}, merge=merge)

    counts = {
        "trails": 1,
        "stages": write_collection(trail_ref.collection("stages"), payload.stages, merge=merge),
        "lodgings": write_collection(
            trail_ref.collection("lodgings"), payload.lodgings, merge=merge
        ),
        "routeChunks": write_collection(
            trail_ref.collection("routeChunks"),
            payload.routeChunks,
            merge=merge,
            max_batch_docs=1,
        ),
        "routeMarkers": write_collection(
            trail_ref.collection("routeMarkers"),
            payload.routeMarkers,
            merge=merge,
        ),
        "excursions": write_collection(
            trail_ref.collection("excursions"),
            payload.excursions,
            merge=merge,
        ),
        "excursionRouteChunks": write_excursion_route_chunks(
            trail_ref,
            payload,
            merge=merge,
        ),
        "detours": write_collection(
            trail_ref.collection("detours"),
            payload.detours,
            merge=merge,
        ),
        "detourRouteChunks": write_detour_route_chunks(
            trail_ref,
            payload,
            merge=merge,
        ),
    }

    metadata = payload.routeMetadata.model_dump(mode="json", exclude_none=True)
    trail_ref.collection("routeMetadata").document("main").set(
        {**metadata, "updatedAt": now},
        merge=merge,
    )
    counts["routeMetadata"] = 1

    pruned: dict[str, int] = {}
    if prune:
        pruned = prune_generated_collections(trail_ref, payload)
        counts["pruned"] = pruned

    import_ref = trail_ref.collection("imports").document(now.strftime("%Y%m%dT%H%M%SZ"))
    audit_data: dict[str, Any] = {
        "createdAt": now,
        "stageCount": len(payload.stages),
        "lodgingCount": len(payload.lodgings),
        "routePointCount": payload.routeMetadata.pointCount,
        "routeChunkCount": len(payload.routeChunks),
        "routeMarkerCount": len(payload.routeMarkers),
        "excursionCount": len(payload.excursions),
        "excursionRouteChunkCount": sum(
            len(chunks) for chunks in payload.excursionRouteChunks.values()
        ),
        "detourCount": len(payload.detours),
        "detourRouteChunkCount": sum(len(chunks) for chunks in payload.detourRouteChunks.values()),
        "warnings": payload.warnings,
    }
    if prune:
        audit_data["pruned"] = pruned
    import_ref.set(audit_data)
    counts["imports"] = 1
    return counts


def prune_generated_collections(trail_ref: Any, payload: ImportPayload) -> dict[str, int]:
    """Delete generated documents whose IDs are absent from the current payload.

    Import audit documents are intentionally excluded so that upload history is
    retained. Pruning runs only after all current documents have been written.
    """

    expected_ids = {
        "stages": {stage.id for stage in payload.stages},
        "lodgings": {lodging.id for lodging in payload.lodgings},
        "routeChunks": {chunk.id for chunk in payload.routeChunks},
        "routeMarkers": {marker.id for marker in payload.routeMarkers},
        "routeMetadata": {"main"},
    }
    counts = {
        collection_name: prune_collection(
            trail_ref.collection(collection_name),
            document_ids,
        )
        for collection_name, document_ids in expected_ids.items()
    }
    if hasattr(payload, "excursions"):
        counts.update(prune_excursion_collections(trail_ref, payload))
    if hasattr(payload, "detours"):
        counts.update(prune_detour_collections(trail_ref, payload))
    return counts


def prune_excursion_collections(trail_ref: Any, payload: ImportPayload) -> dict[str, int]:
    excursion_collection = trail_ref.collection("excursions")
    expected_excursion_ids = {excursion.id for excursion in payload.excursions}
    route_chunks_pruned = 0
    for document_ref in excursion_collection.list_documents():
        expected_chunk_ids = {
            chunk.id for chunk in payload.excursionRouteChunks.get(document_ref.id, [])
        }
        route_chunks_pruned += prune_collection(
            document_ref.collection("routeChunks"),
            expected_chunk_ids if document_ref.id in expected_excursion_ids else set(),
        )
    excursions_pruned = prune_collection(excursion_collection, expected_excursion_ids)
    return {
        "excursions": excursions_pruned,
        "excursionRouteChunks": route_chunks_pruned,
    }


def prune_detour_collections(trail_ref: Any, payload: ImportPayload) -> dict[str, int]:
    detour_collection = trail_ref.collection("detours")
    expected_detour_ids = {detour.id for detour in payload.detours}
    route_chunks_pruned = 0
    for document_ref in detour_collection.list_documents():
        expected_chunk_ids = {
            chunk.id for chunk in payload.detourRouteChunks.get(document_ref.id, [])
        }
        route_chunks_pruned += prune_collection(
            document_ref.collection("routeChunks"),
            expected_chunk_ids if document_ref.id in expected_detour_ids else set(),
        )
    detours_pruned = prune_collection(detour_collection, expected_detour_ids)
    return {
        "detours": detours_pruned,
        "detourRouteChunks": route_chunks_pruned,
    }


def prune_collection(
    collection_ref: Any,
    expected_ids: set[str],
    *,
    max_batch_docs: int = 450,
) -> int:
    """Delete documents not included in expected_ids and return the count."""

    batch = collection_ref._client.batch()
    pending = 0
    total = 0
    for document_ref in collection_ref.list_documents():
        if document_ref.id in expected_ids:
            continue
        batch.delete(document_ref)
        pending += 1
        total += 1
        if pending == max_batch_docs:
            batch.commit()
            batch = collection_ref._client.batch()
            pending = 0
    if pending:
        batch.commit()
    return total


def write_collection(
    collection_ref: Any,
    models: Iterable[Any],
    *,
    merge: bool,
    max_batch_docs: int = 450,
) -> int:
    batch = collection_ref._client.batch()
    pending = 0
    total = 0
    for model in models:
        data = compact_doc(model.model_dump(mode="json", exclude_none=True, exclude={"id"}))
        data["updatedAt"] = datetime.now(UTC)
        batch.set(collection_ref.document(model.id), data, merge=merge)
        pending += 1
        total += 1
        if pending == max_batch_docs:
            batch.commit()
            batch = collection_ref._client.batch()
            pending = 0
    if pending:
        batch.commit()
    return total


def write_excursion_route_chunks(
    trail_ref: Any,
    payload: ImportPayload,
    *,
    merge: bool,
) -> int:
    total = 0
    for excursion in payload.excursions:
        chunk_collection = (
            trail_ref.collection("excursions").document(excursion.id).collection("routeChunks")
        )
        total += write_collection(
            chunk_collection,
            payload.excursionRouteChunks.get(excursion.id, []),
            merge=merge,
            max_batch_docs=1,
        )
    return total


def write_detour_route_chunks(
    trail_ref: Any,
    payload: ImportPayload,
    *,
    merge: bool,
) -> int:
    total = 0
    for detour in payload.detours:
        chunk_collection = (
            trail_ref.collection("detours").document(detour.id).collection("routeChunks")
        )
        total += write_collection(
            chunk_collection,
            payload.detourRouteChunks.get(detour.id, []),
            merge=merge,
            max_batch_docs=1,
        )
    return total
