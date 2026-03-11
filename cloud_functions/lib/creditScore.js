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
exports.calculateCreditScore = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
if (!admin.apps.length)
    admin.initializeApp();
const db = admin.firestore();
/**
 * Credit Score Algorithm
 *
 * Calculated ENTIRELY from Bank digital payment records (NOT BNPL).
 * Score range: 300 - 850
 *
 * Factors:
 * 1. Payment Frequency     (25%) — How often they use digital payments
 * 2. Payment Consistency   (25%) — Regularity over time windows
 * 3. Average Tx Amount     (20%) — Higher avg → more financial activity
 * 4. On-time Bill Payments (30%) — Loan/insurance payments made on time
 */
exports.calculateCreditScore = functions.https.onCall(async (request) => {
    var _a;
    const uid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!uid)
        throw new functions.https.HttpsError("unauthenticated", "Must be logged in");
    // Fetch all bank-type transactions
    const txSnapshot = await db
        .collection("users")
        .doc(uid)
        .collection("transactions")
        .where("paymentType", "==", "bank")
        .orderBy("timestamp", "desc")
        .get();
    const transactions = txSnapshot.docs.map((doc) => doc.data());
    const totalTx = transactions.length;
    if (totalTx === 0) {
        // No bank history → baseline score
        await _updateScore(uid, 400);
        return { score: 400 };
    }
    // ── Factor 1: Payment Frequency (25%) ─────────────────────
    // More transactions per 30-day window = higher score
    const thirtyDaysAgo = Date.now() - 30 * 24 * 60 * 60 * 1000;
    const recentTx = transactions.filter((tx) => tx.timestamp > thirtyDaysAgo);
    const frequencyScore = Math.min(recentTx.length / 10, 1.0); // Cap at 10 tx/month
    // ── Factor 2: Payment Consistency (25%) ───────────────────
    // Check if they transact regularly (low variance in gaps)
    let consistencyScore = 0.5; // Default mid
    if (totalTx >= 3) {
        const timestamps = transactions
            .map((tx) => tx.timestamp)
            .sort((a, b) => a - b);
        const gaps = [];
        for (let i = 1; i < timestamps.length; i++) {
            gaps.push(timestamps[i] - timestamps[i - 1]);
        }
        const avgGap = gaps.reduce((a, b) => a + b, 0) / gaps.length;
        const variance = gaps.reduce((sum, g) => sum + Math.pow(g - avgGap, 2), 0) / gaps.length;
        const stdDev = Math.sqrt(variance);
        // Lower stdDev relative to avgGap = more consistent
        consistencyScore = Math.max(0, 1 - stdDev / (avgGap || 1));
    }
    // ── Factor 3: Average Transaction Amount (20%) ────────────
    const totalAmount = transactions.reduce((sum, tx) => sum + Math.abs(tx.amount || 0), 0);
    const avgAmount = totalAmount / totalTx;
    const amountScore = Math.min(avgAmount / 100, 1.0); // Cap at 100 units
    // ── Factor 4: On-time Bill Payments (30%) ─────────────────
    const billCategories = ["loanPayment", "insurancePremium", "bnplPayment"];
    const billTx = transactions.filter((tx) => billCategories.includes(tx.category));
    let onTimeRatio = 1.0; // Perfect if no bills
    if (billTx.length > 0) {
        // Check against due dates in the loan/bnpl collections
        // Simplified: assume all bank bill payments are on-time for now
        // (full implementation would cross-reference due dates)
        onTimeRatio = 0.9; // Placeholder — will be computed from actual due dates
    }
    // ── Final Score ───────────────────────────────────────────
    const weightedScore = frequencyScore * 0.25 +
        consistencyScore * 0.25 +
        amountScore * 0.2 +
        onTimeRatio * 0.3;
    // Map 0.0-1.0 → 300-850
    const finalScore = Math.round(300 + weightedScore * 550);
    const clampedScore = Math.max(300, Math.min(850, finalScore));
    await _updateScore(uid, clampedScore);
    return { score: clampedScore };
});
async function _updateScore(uid, score) {
    await db.collection("users").doc(uid).update({
        "creditScore": score,
        "creditScoreUpdatedAt": admin.firestore.FieldValue.serverTimestamp(),
    });
}
//# sourceMappingURL=creditScore.js.map