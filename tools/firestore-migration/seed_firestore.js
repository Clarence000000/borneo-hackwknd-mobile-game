#!/usr/bin/env node
/**
 * Seed Firestore in target project with sample data.
 * Usage:
 *   node seed_firestore.js --targetKey ./target-sa.json [--dry-run] [--numPlayers 10]
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

async function main() {
  const opts = parseArgs();
  if (!opts.targetKey) {
    console.error('Missing --targetKey path to service account JSON');
    process.exit(1);
  }

  const numPlayers = parseInt(opts.numPlayers || '5', 10);
  const dryRun = !!opts['dry-run'] || !!opts.dryRun;

  const targetKeyPath = path.resolve(opts.targetKey);
  if (!fs.existsSync(targetKeyPath)) {
    console.error('Target key not found:', targetKeyPath);
    process.exit(1);
  }

  const targetCred = JSON.parse(fs.readFileSync(targetKeyPath, 'utf8'));
  const targetApp = admin.initializeApp({ credential: admin.credential.cert(targetCred) }, 'seed');
  const db = targetApp.firestore();

  console.log('Seeding target project. dryRun=', dryRun);

  // Seed players
  const players = [];
  const countries = ['MY', 'PH', 'ID', 'SG'];
  for (let i = 1; i <= numPlayers; i++) {
    const uid = `player-seed-${Date.now()}-${i}`;
    const country = countries[(i - 1) % countries.length];
    players.push({
      uid,
      displayName: `Player ${i}`,
      netWorth: Math.floor(Math.random() * 10000),
      cashBalance: Math.floor(Math.random() * 1000) / 100,
      bankBalance: Math.floor(Math.random() * 5000) / 100,
      creditScore: 500 + Math.floor(Math.random() * 400),
      country,
      currency: { MY: 'XMYR', PH: 'XPHP', ID: 'XIDR', SG: 'XSGD' }[country] || 'XMYR',
      tutorialCompleted: true,
      tractorOwned: false,
      autoHarvestEnabled: false,
      fertilizerPackCount: 0,
      inventory: { wheat: Math.floor(Math.random() * 50) },
      currentDay: Math.floor(Math.random() * 30),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  // Seed users collection with player data
  for (const p of players) {
    console.log(`  user -> users/${p.uid}`);
    if (!dryRun) {
      await db.collection('users').doc(p.uid).set({
        displayName: p.displayName,
        cashBalance: p.cashBalance,
        bankBalance: p.bankBalance,
        creditScore: p.creditScore,
        country: p.country,
        currency: p.currency,
        tutorialCompleted: p.tutorialCompleted,
        gpsLat: 0,
        gpsLng: 0,
        bankRegistered: false,
        tractorOwned: p.tractorOwned,
        autoHarvestEnabled: p.autoHarvestEnabled,
        fertilizerPackCount: p.fertilizerPackCount,
        inventory: p.inventory,
        currentDay: p.currentDay,
        isAdmin: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  }

  // Seed leaderboard rankings per country
  for (const country of countries) {
    const countryPlayers = players.filter(p => p.country === country)
      .sort((a, b) => b.netWorth - a.netWorth)
      .slice(0, 10);
    
    for (let rank = 0; rank < countryPlayers.length; rank++) {
      const p = countryPlayers[rank];
      console.log(`  leaderboard -> leaderboards/${country}/rankings/${p.uid}`);
      if (!dryRun) {
        await db.collection('leaderboards').doc(country)
          .collection('rankings').doc(p.uid).set({
          displayName: p.displayName,
          netWorth: p.netWorth,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }
  }

  // Seed sample transactions under each user
  for (const p of players) {
    const numTx = Math.floor(Math.random() * 3) + 1;
    for (let j = 0; j < numTx; j++) {
      console.log(`  transaction -> users/${p.uid}/transactions/${j}`);
      if (!dryRun) {
        await db.collection('users').doc(p.uid).collection('transactions').add({
          amount: Math.floor(Math.random() * 500) / 100,
          type: 'seed_topup',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }
  }

  console.log('Seeding complete.');
  await targetApp.delete();
}

main().catch(err => {
  console.error('Seed failed:', err);
  process.exit(1);
});
