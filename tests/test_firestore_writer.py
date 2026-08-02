from types import SimpleNamespace

from monk_importer.firestore_writer import prune_collection, prune_generated_collections


class FakeDocumentReference:
    def __init__(self, document_id: str) -> None:
        self.id = document_id


class FakeBatch:
    def __init__(self, client: "FakeClient") -> None:
        self.client = client
        self.deletions: list[str] = []

    def delete(self, document_ref: FakeDocumentReference) -> None:
        self.deletions.append(document_ref.id)

    def commit(self) -> None:
        self.client.commits.append(self.deletions.copy())


class FakeClient:
    def __init__(self) -> None:
        self.commits: list[list[str]] = []

    def batch(self) -> FakeBatch:
        return FakeBatch(self)


class FakeCollection:
    def __init__(self, client: FakeClient, document_ids: list[str]) -> None:
        self._client = client
        self.document_ids = document_ids

    def list_documents(self) -> list[FakeDocumentReference]:
        return [FakeDocumentReference(document_id) for document_id in self.document_ids]


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
