const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const fetch = require('node-fetch');

function getArg(name, fallback = null) {
  const prefix = `--${name}=`;
  const match = process.argv.find((arg) => arg.startsWith(prefix));
  return match ? match.slice(prefix.length) : fallback;
}

async function callCallable(functionName, idToken, data, projectId) {
  const url = `https://us-central1-${projectId}.cloudfunctions.net/${functionName}`;
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${idToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ data }),
  });

  const body = await response.json();
  if (!response.ok || body.error) {
    throw new Error(`${functionName} failed: ${JSON.stringify(body)}`);
  }

  return body.result;
}

async function signInWithCustomToken(apiKey, customToken) {
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${apiKey}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        token: customToken,
        returnSecureToken: true,
      }),
    },
  );

  const body = await response.json();
  if (!response.ok || body.error) {
    throw new Error(`signInWithCustomToken failed: ${JSON.stringify(body)}`);
  }

  return body.idToken;
}

async function main() {
  const serviceAccountPath = getArg('serviceAccount');
  const apiKey = getArg('apiKey');
  const projectId = getArg('projectId', 'borneo-hackhathon-richi');
  const amount = Number(getArg('amount', '120'));
  const installments = Number(getArg('installments', '3'));
  const currentDay = Number(getArg('currentDay', '31'));

  if (!serviceAccountPath || !apiKey) {
    console.error('Usage: node scripts/test_bnpl_realtime.js --serviceAccount=C:\\path\\key.json --apiKey=... [--projectId=...]');
    process.exit(1);
  }

  const serviceAccount = JSON.parse(fs.readFileSync(path.resolve(serviceAccountPath), 'utf8'));
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId,
  });

  const uid = `bnpl-test-${Date.now()}`;
  const db = admin.firestore();

  await db.collection('users').doc(uid).set({
    displayName: 'BNPL Realtime Test',
    country: 'MY',
    currency: 'XMYR',
    gpsLat: 0,
    gpsLng: 0,
    tutorialCompleted: true,
    createdAt: Date.now(),
    cashBalance: 1000,
    bankBalance: 500,
    bankRegistered: true,
    creditScore: 500,
    isAdmin: false,
    tractorOwned: false,
    autoHarvestEnabled: false,
    fertilizerPackCount: 0,
    inventory: {},
    currentDay,
    manualNextDayUsedToday: 0,
    manualNextDayUsageDate: Date.now(),
  });

  const customToken = await admin.auth().createCustomToken(uid);
  const idToken = await signInWithCustomToken(apiKey, customToken);

  const planEvents = [];
  let resolveUpdate;
  const updateObserved = new Promise((resolve) => {
    resolveUpdate = resolve;
  });

  const planListener = db
    .collection('users')
    .doc(uid)
    .collection('bnplPlans')
    .onSnapshot((snapshot) => {
      snapshot.docChanges().forEach((change) => {
        if (change.type === 'added' || change.type === 'modified') {
          const data = change.doc.data();
          planEvents.push({
            type: change.type,
            id: change.doc.id,
            paidInstallments: data.paidInstallments,
            status: data.status,
            lateFees: data.lateFees,
          });
          if (change.type === 'modified' && data.paidInstallments === 1 && data.status === 'active') {
            resolveUpdate({ id: change.doc.id, data });
          }
        }
      });
    });

  try {
    const created = await callCallable(
      'createBnplPlan',
      idToken,
      {
        totalAmount: amount,
        installments,
        startDay: 0,
        currentDay,
        itemName: 'Realtime BNPL Test Item',
        merchant: 'Test Merchant',
        description: 'Realtime BNPL test',
      },
      projectId,
    );

    const planId = created.planId;
    const planRef = db.collection('users').doc(uid).collection('bnplPlans').doc(planId);

    const firstSnapshot = await planRef.get();
    if (!firstSnapshot.exists) {
      throw new Error(`Created plan ${planId} was not found in Firestore`);
    }

    const repayResult = await callCallable(
      'repayBnplInstallment',
      idToken,
      {
        planId,
        paymentMethod: 'auto',
        currentDay,
      },
      projectId,
    );

    const updated = await Promise.race([
      updateObserved,
      new Promise((_, reject) => setTimeout(() => reject(new Error('Timed out waiting for realtime plan update')), 30000)),
    ]);

    const finalSnapshot = await planRef.get();

    console.log(JSON.stringify({
      uid,
      planId,
      createdResult: created,
      repayResult,
      realtimeEvents: planEvents,
      observedUpdate: updated,
      finalPlan: finalSnapshot.data(),
    }, null, 2));
  } finally {
    planListener();
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});