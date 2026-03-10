import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

/**
 * Insurance Payout Cloud Function
 *
 * When a disaster event occurs, checks if the player has active insurance.
 * If insured, calculates and deposits the payout into their virtual wallet.
 */
export const processInsurancePayout = functions.https.onCall(
    async (request) => {
        const uid = request.auth?.uid;
        if (!uid) throw new functions.https.HttpsError("unauthenticated", "Must be logged in");

        const { eventId } = request.data;
        if (!eventId) {
            throw new functions.https.HttpsError("invalid-argument", "eventId required");
        }

        // Get the disaster event
        const eventDoc = await db
            .collection("users")
            .doc(uid)
            .collection("disasterEvents")
            .doc(eventId)
            .get();

        if (!eventDoc.exists) {
            throw new functions.https.HttpsError("not-found", "Disaster event not found");
        }

        const event = eventDoc.data()!;

        // Get all active insurance policies
        const insuranceSnapshot = await db
            .collection("users")
            .doc(uid)
            .collection("insurance")
            .where("status", "==", "active")
            .get();

        if (insuranceSnapshot.empty) {
            return {
                hasPayout: false,
                totalPayout: 0,
                message: "No active insurance policies. All crop losses are unrecovered.",
            };
        }

        let totalPayout = 0;
        const claimedPolicies: string[] = [];

        for (const doc of insuranceSnapshot.docs) {
            const policy = doc.data();

            // Check if policy hasn't expired
            const expiresAt = policy.expiresAt?.toMillis?.() || policy.expiresAt;
            if (Date.now() > expiresAt) {
                await doc.ref.update({ status: "expired" });
                continue;
            }

            // Calculate payout based on severity
            const payout = policy.coverageAmount * (event.severity || 0.5);
            totalPayout += payout;
            claimedPolicies.push(doc.id);

            // Mark policy as claimed
            await doc.ref.update({ status: "claimed" });
        }

        if (totalPayout > 0) {
            // Deposit payout into bank balance
            await db.collection("users").doc(uid).update({
                bankBalance: admin.firestore.FieldValue.increment(totalPayout),
            });

            // Update disaster event with payout info
            await db
                .collection("users")
                .doc(uid)
                .collection("disasterEvents")
                .doc(eventId)
                .update({
                    insurancePayout: totalPayout,
                    claimedPolicies,
                });
        }

        return {
            hasPayout: totalPayout > 0,
            totalPayout: Math.round(totalPayout * 100) / 100,
            policiesClaimed: claimedPolicies.length,
            message: totalPayout > 0
                ? `Insurance payout: ${totalPayout.toFixed(2)} deposited to your bank! ${claimedPolicies.length} policy(ies) claimed.`
                : "Insurance policies found but no valid coverage for this event.",
        };
    }
);
