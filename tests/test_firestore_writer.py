from __future__ import annotations

from types import SimpleNamespace

from monk_importer.firestore_writer import (
    prune_collection,
    prune_detour_collections,
    prune_excursion_collections,
    prune_generated_collections,
    write_detour_route_chunks,
    write_excursion_route_chunks,
)
from monk_importer.models import RouteChunk


class FakeDocumentReference:
    def __init__(
        self,
        document_id: str,
        client: "FakeClient" | None = None,
        collections: dict[str, "FakeCollection"] | None = None,
    ) -> None:
        self.id = document_id
        self._client = client
        self.collections = collections or {}

    def collection(self, name: str) -> "FakeCollection":
        if name not in self.collections:
            assert self._client is not None
            self.collections[name] = FakeCollection(self._client, [])
        return self.collections[name]


class FakeBatch:
    def __init__(self, client: "FakeClient") -> None:
        self.client = client
        self.deletions: list[str] = []

    def delete(self, document_ref: FakeDocumentReference) -> None:
        self.deletions.append(document_ref.id)

    def set(self, document_ref: FakeDocumentReference, data: object, *, merge: bool) -> None:
        self.client.sets.append((document_ref.id, data, merge))

    def commit(self) -> None:
        self.client.commits.append(self.deletions.copy())


class FakeClient:
    def __init__(self) -> None:
        self.commits: list[list[str]] = []
        self.sets: list[tuple[str, object, bool]] = []

    def batch(self) -> FakeBatch:
        return FakeBatch(self)


class FakeCollection:
    def __init__(
        self,
        client: FakeClient,
        document_ids: list[str],
        nested_collections: dict[str, dict[str, "FakeCollection"]] | None = None,
    ) -> None:
        self._client = client
        self.document_ids = document_ids
        self.nested_collections = nested_collections or {}
        self.documents: dict[str, FakeDocumentReference] = {}

    def list_documents(self) -> list[FakeDocumentReference]:
        return [
            FakeDocumentReference(
                document_id,
                self._client,
                self.nested_collections.get(document_id),
            )
            for document_id in self.document_ids
        ]

    def document(self, document_id: str) -> FakeDocumentReference:
        if document_id not in self.documents:
            self.documents[document_id] = FakeDocumentReference(document_id, self._client)
        return self.documents[document_id]


class FakeTrailReference:
    def __init__(self, collections: dict[str, FakeCollection]) -> None:
        self.collections = collections

    def collection(self, name: str) -> FakeCollection:
        return self.collections[name]


def test_prune_collection_deletes_only_unexpected_documents_in_batches() -> None:
    client = FakeClient()
    collection = FakeCollection(client, ["keep", "stale-a", "stale-b"])

    count = prune_collection(collection, {"keep"}, max_batch_docs=1)

    assert count == 2
    assert client.commits == [["stale-a"], ["stale-b"]]


def test_prune_generated_collections_preserves_expected_docs_and_audits() -> None:
    client = FakeClient()
    collections = {
        "stages": FakeCollection(client, ["123-pafos-airport", "124-pafos-airport"]),
        "lodgings": FakeCollection(client, ["lodging-current", "lodging-stale"]),
        "routeChunks": FakeCollection(client, ["0000", "0001"]),
        "routeMarkers": FakeCollection(client, ["123-pafos-airport", "old-marker"]),
        "routeMetadata": FakeCollection(client, ["main", "legacy"]),
        "imports": FakeCollection(client, ["old-audit"]),
    }
    payload = SimpleNamespace(
        stages=[SimpleNamespace(id="123-pafos-airport")],
        lodgings=[SimpleNamespace(id="lodging-current")],
        routeChunks=[SimpleNamespace(id="0000")],
        routeMarkers=[SimpleNamespace(id="123-pafos-airport")],
    )

    counts = prune_generated_collections(FakeTrailReference(collections), payload)

    assert counts == {
        "stages": 1,
        "lodgings": 1,
        "routeChunks": 1,
        "routeMarkers": 1,
        "routeMetadata": 1,
    }
    assert collections["imports"].document_ids == ["old-audit"]


def test_prune_excursions_removes_stale_chunks_before_stale_excursions() -> None:
    client = FakeClient()
    current_chunks = FakeCollection(client, ["0000", "0001"])
    stale_chunks = FakeCollection(client, ["0000"])
    excursions = FakeCollection(
        client,
        ["current", "stale"],
        {
            "current": {"routeChunks": current_chunks},
            "stale": {"routeChunks": stale_chunks},
        },
    )
    payload = SimpleNamespace(
        excursions=[SimpleNamespace(id="current")],
        excursionRouteChunks={"current": [SimpleNamespace(id="0000")]},
    )

    counts = prune_excursion_collections(
        FakeTrailReference({"excursions": excursions}),
        payload,
    )

    assert counts == {"excursions": 1, "excursionRouteChunks": 2}
    assert client.commits == [["0001"], ["0000"], ["stale"]]


def test_write_excursion_chunks_uses_nested_route_chunks_collection() -> None:
    client = FakeClient()
    excursions = FakeCollection(client, [])
    trail = FakeTrailReference({"excursions": excursions})
    chunk = RouteChunk(
        id="0000",
        chunkIndex=0,
        startPointIndex=0,
        endPointIndex=1,
        startDistanceKm=0,
        endDistanceKm=1,
        bounds={"minLat": 0, "maxLat": 0, "minLng": 0, "maxLng": 1},
        points=[0, 0, 0, 0, 1, 0, 1, 0, 1, 0],
    )
    payload = SimpleNamespace(
        excursions=[SimpleNamespace(id="ridge-walk")],
        excursionRouteChunks={"ridge-walk": [chunk]},
    )

    count = write_excursion_route_chunks(trail, payload, merge=True)

    assert count == 1
    excursion_document = excursions.documents["ridge-walk"]
    assert "routeChunks" in excursion_document.collections
    assert client.sets[0][0] == "0000"
    assert client.sets[0][2] is True


def test_prune_detours_removes_stale_chunks_before_stale_detours() -> None:
    client = FakeClient()
    current_chunks = FakeCollection(client, ["0000", "0001"])
    stale_chunks = FakeCollection(client, ["0000"])
    detours = FakeCollection(
        client,
        ["current", "stale"],
        {
            "current": {"routeChunks": current_chunks},
            "stale": {"routeChunks": stale_chunks},
        },
    )
    payload = SimpleNamespace(
        detours=[SimpleNamespace(id="current")],
        detourRouteChunks={"current": [SimpleNamespace(id="0000")]},
    )

    counts = prune_detour_collections(
        FakeTrailReference({"detours": detours}),
        payload,
    )

    assert counts == {"detours": 1, "detourRouteChunks": 2}
    assert client.commits == [["0001"], ["0000"], ["stale"]]


def test_write_detour_chunks_uses_nested_route_chunks_collection() -> None:
    client = FakeClient()
    detours = FakeCollection(client, [])
    trail = FakeTrailReference({"detours": detours})
    chunk = RouteChunk(
        id="0000",
        chunkIndex=0,
        startPointIndex=0,
        endPointIndex=1,
        startDistanceKm=0,
        endDistanceKm=1,
        bounds={"minLat": 0, "maxLat": 0, "minLng": 0, "maxLng": 1},
        points=[0, 0, 0, 0, 1, 0, 1, 0, 1, 0],
    )
    payload = SimpleNamespace(
        detours=[SimpleNamespace(id="ridge-alternative")],
        detourRouteChunks={"ridge-alternative": [chunk]},
    )

    count = write_detour_route_chunks(trail, payload, merge=True)

    assert count == 1
    detour_document = detours.documents["ridge-alternative"]
    assert "routeChunks" in detour_document.collections
    assert client.sets[0][0] == "0000"
    assert client.sets[0][2] is True
