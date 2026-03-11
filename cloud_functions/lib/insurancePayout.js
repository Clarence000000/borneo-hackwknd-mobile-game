"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.processInsurancePayout = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
if (!admin.apps.length)
    admin.initializeApp();
const db = admin.firestore();
/**
 * Insurance Payout Cloud Function
 *
 * When a disaster event occurs, checks if the player has active insurance.
 * If insured, calculates and deposits the payout into their virtual wallet.
 */
exports.processInsurancePayout = functions.https.onCall(async (request) => {
    var _a, _b, _c;
    const uid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!uid)
        throw new functions.https.HttpsError("unauthenticated", "Must be logged in");
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
    const event = eventDoc.data();
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
    const claimedPolicies = [];
    for (const doc of insuranceSnapshot.docs) {
        const policy = doc.data();
        // Check if policy hasn't expired
        const expiresAt = ((_c = (_b = policy.expiresAt) === null || _b === void 0 ? void 0 : _b.toMillis) === null || _c === void 0 ? void 0 : _c.call(_b)) || policy.expiresAt;
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
});
//# sourceMappingURL=insurancePayout.js.map