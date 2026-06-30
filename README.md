# Monk Firestore Importer

Python project for reading the Cyprus E4 workbook, normalizing trail data, and writing it to Firestore with deterministic document IDs.

The project is designed to run locally first, while keeping the import logic separated so it can later be wrapped by a Firebase/Google Cloud Function.

## Firestore Shape

```text
trails/cyprus-e4
trails/cyprus-e4/stages/{stageId}
trails/cyprus-e4/lodgings/{lodgingId}
trails/cyprus-e4/routeMetadata/main
trails/cyprus-e4/routeChunks/{chunkId}
trails/cyprus-e4/routeMarkers/{stageId}
trails/cyprus-e4/imports/{importId}
```

Route chunks are only a transport/storage format. The mobile app can fetch all chunks ordered by `chunkIndex`, flatten their `points`, and cache the full route locally for offline map and elevation rendering.

## Setup

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install -e ".[dev,functions]"
```

## Local Dry Run

This reads the workbook and writes a JSON import preview without connecting to Firestore.

```bash
monk-import --dry-run
```

The default workbook path is:

```text
data/Cyprus_E4_Data_v4 - Cleaned-nopass.xlsx
```

## Firestore Import

Create a Firebase service account JSON file and point the importer to it:

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/service-account.json
monk-import --commit
```

Or use `.env`:

```text
GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/service-account.json
FIREBASE_PROJECT_ID=your-project-id
```

Then:

```bash
monk-import --commit
```

By default, the importer uses `set()` with stable document IDs, so rerunning it updates the same Firestore documents rather than creating duplicates.

## Function-Friendly Entry Point

The callable import logic lives in:

```text
src/monk_importer/importer.py
```

The optional HTTP-style function wrapper lives in:

```text
src/monk_importer/function_entry.py
```

For production automation, prefer uploading the workbook to Cloud Storage and triggering a Cloud Function or Cloud Run job with the file path.

