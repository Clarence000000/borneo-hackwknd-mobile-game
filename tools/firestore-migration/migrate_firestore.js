#!/usr/bin/env node
/**
 * Simple Firestore migration script
 * Usage:
 *  node migrate_firestore.js --sourceKey ./srcKey.json --targetKey ./targetKey.json [--collections col1,col2] [--dry-run]
 *
 * Requirements:
 *  - service account JSON for source project with Firestore Viewer (or Reader) role
 *  - service account JSON for target project with Firestore Owner/Editor/Datastore Import role
 *
 * Note: This script performs a simple copy of documents and subcollections.
 * It is not optimized for very large datasets; consider using exported backups for large migrations.
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

function parseArgs() {
  const args = process.argv.slice(2);
  const opts = {};
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (!a.startsWith('--')) continue;
    const key = a.replace(/^--/, '');
    const next = args[i + 1];
    if (!next || next.startsWith('--')) {
      opts[key] = true;
    } else {
      opts[key] = next;
      i++;
    }
  }
  return opts;
}

function die(msg) {
  console.error(msg);
  process.exit(1);
}

async function main() {
  const opts = parseArgs();
  if (!opts.sourceKey || !opts.targetKey) {
    die('Missing required args. See README. Example: --sourceKey ./src.json --targetKey ./tgt.json');
  }

  const dryRun = !!opts['dry-run'] || !!opts.dryRun;

  const sourceKeyPath = path.resolve(opts.sourceKey);
  const targetKeyPath = path.resolve(opts.targetKey);

  if (!fs.existsSync(sourceKeyPath)) die('Source key file not found: ' + sourceKeyPath);
  if (!fs.existsSync(targetKeyPath)) die('Target key file not found: ' + targetKeyPath);

  const sourceCred = JSON.parse(fs.readFileSync(sourceKeyPath, 'utf8'));
  const targetCred = JSON.parse(fs.readFileSync(targetKeyPath, 'utf8'));

  const sourceApp = admin.initializeApp({ credential: admin.credential.cert(sourceCred) }, 'source');
  const targetApp = admin.initializeApp({ credential: admin.credential.cert(targetCred) }, 'target');

  const sourceDb = sourceApp.firestore();
  const targetDb = targetApp.firestore();

  // get top-level collections
  let collectionsToCopy = null;
  if (opts.collections) {
    collectionsToCopy = opts.collections.split(',').map(s => s.trim()).filter(Boolean);
  } else {
    const cols = await sourceDb.listCollections();
    collectionsToCopy = cols.map(c => c.id);
  }

  console.log('Collections to copy:', collectionsToCopy);
  for (const colName of collectionsToCopy) {
    console.log('Copying collection:', colName);
    const colRef = sourceDb.collection(colName);
    const snapshot = await colRef.get();
    console.log(`  documents: ${snapshot.size}`);
    for (const doc of snapshot.docs) {
      const targetDocRef = targetDb.collection(colName).doc(doc.id);
      await copyDocument(doc.ref, targetDocRef, dryRun);
    }
  }

  console.log('Migration finished.');
  // cleanup apps
  await sourceApp.delete();
  await targetApp.delete();
}

async function copyDocument(sourceDocRef, targetDocRef, dryRun) {
  const snap = await sourceDocRef.get();
  if (!snap.exists) return;
  const data = snap.data();
  console.log(`    writing doc ${targetDocRef.path} ${dryRun ? '(dry-run)' : ''}`);
  if (!dryRun) {
    await targetDocRef.set(data);
  }
  // copy subcollections recursively
  const subcols = await sourceDocRef.listCollections();
  for (const sub of subcols) {
    const subSnapshot = await sub.get();
    for (const subDoc of subSnapshot.docs) {
      const targetSubDocRef = targetDocRef.collection(sub.id).doc(subDoc.id);
      await copyDocument(subDoc.ref, targetSubDocRef, dryRun);
    }
  }
}

main().catch(err => {
  console.error('Migration failed:', err);
  process.exit(1);
});
