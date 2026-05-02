# Firestore Migration (programmatic)

This folder contains a small Node.js script that copies Firestore documents (and subcollections) from a source Firebase project to a target Firebase project using two service account JSON keys.

Important notes:
- This script is intended for moderate-sized datasets. For very large datasets prefer using managed export/import with `gcloud firestore export` / `gcloud firestore import`.
- Make sure service accounts have the appropriate IAM roles:
  - Source SA: Firestore Viewer (or Firestore Reader)
  - Target SA: Firestore Owner / Editor / Cloud Datastore Import

Usage:

1. Install dependencies:

```bash
cd tools/firestore-migration
npm install
```

2. Run migration:

```bash
# Copy all top-level collections
node migrate_firestore.js --sourceKey ../keys/source-sa.json --targetKey ../keys/target-sa.json

# Copy specific collections only
node migrate_firestore.js --sourceKey ../keys/source-sa.json --targetKey ../keys/target-sa.json --collections players,transactions

# Dry-run (no writes)
node migrate_firestore.js --sourceKey ../keys/source-sa.json --targetKey ../keys/target-sa.json --dry-run
```

3. Tips:
- If your dataset is large, consider exporting with:

  ```bash
  gcloud firestore export gs://BUCKET/EXPORT_PATH --project=OLD_PROJECT_ID
  gcloud firestore import gs://BUCKET/EXPORT_PATH --project=NEW_PROJECT_ID
  ```

- Keep service account JSON files outside the repository and add them to `.gitignore`.
