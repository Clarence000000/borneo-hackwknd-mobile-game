import * as functions from "firebase-functions";
import { CallableRequest } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

function toMillis(value: any): number {
    if (!value) return 0;
    if (typeof value === "number") return value;
    if (typeof value?.toMillis === "function") return value.toMillis();
    if (value instanceof Date) return value.getTime();
    const parsed = Date.parse(String(value));
    return Number.isNaN(parsed) ? 0 : parsed;
}

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
export const calculateCreditScore = functions.https.onCall(
    async (request: CallableRequest<any>) => {
        const uid = request.auth?.uid;
        if (!uid) throw new functions.https.HttpsError("unauthenticated", "Must be logged in");

        const userDoc = await db.collection("users").doc(uid).get();
        const previousScore = (userDoc.data()?.creditScore as number | undefined) ?? 400;

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
            return {
                score: 400,
                previousScore,
                delta: 400 - previousScore,
                breakdown: {
                    frequency: 0,
                    consistency: 50,
                    amount: 0,
                    onTimePayments: 100,
                },
            };
        }

        // ── Factor 1: Payment Frequency (25%) ─────────────────────
        // More transactions per 30-day window = higher score
        const thirtyDaysAgo = Date.now() - 30 * 24 * 60 * 60 * 1000;
        const recentTx = transactions.filter(
            (tx: any) => toMillis(tx.timestamp) > thirtyDaysAgo
        );
        const frequencyScore = Math.min(recentTx.length / 10, 1.0); // Cap at 10 tx/month

        // ── Factor 2: Payment Consistency (25%) ───────────────────
        // Check if they transact regularly (low variance in gaps)
        let consistencyScore = 0.5; // Default mid
        if (totalTx >= 3) {
            const timestamps = transactions
                .map((tx: any) => toMillis(tx.timestamp))
                .filter((timestamp: number) => timestamp > 0)
                .sort((a: number, b: number) => a - b);
            if (timestamps.length >= 3) {
                const gaps: number[] = [];
                for (let i = 1; i < timestamps.length; i++) {
                    gaps.push(timestamps[i] - timestamps[i - 1]);
                }
                const avgGap = gaps.reduce((a, b) => a + b, 0) / gaps.length;
                const variance =
                    gaps.reduce((sum, g) => sum + Math.pow(g - avgGap, 2), 0) / gaps.length;
                const stdDev = Math.sqrt(variance);
                // Lower stdDev relative to avgGap = more consistent
                consistencyScore = Math.max(0, 1 - stdDev / (avgGap || 1));
            }
        }

        // ── Factor 3: Average Transaction Amount (20%) ────────────
        const totalAmount = transactions.reduce(
            (sum: number, tx: any) => sum + Math.abs(tx.amount || 0),
            0
        );
        const avgAmount = totalAmount / totalTx;
        const amountScore = Math.min(avgAmount / 100, 1.0); // Cap at 100 units

        // ── Factor 4: On-time Bill Payments (30%) ─────────────────
        const billCategories = ["loanPayment", "insurancePremium", "bnplPayment"];
        const billTx = transactions.filter((tx: any) =>
            billCategories.includes(tx.category)
        );
        let onTimeRatio = 1.0; // Perfect if no bills
        if (billTx.length > 0) {
            // Check against due dates in the loan/bnpl collections
            // Simplified: assume all bank bill payments are on-time for now
            // (full implementation would cross-reference due dates)
            onTimeRatio = 0.9; // Placeholder — will be computed from actual due dates
        }

        // ── Final Score ───────────────────────────────────────────
        const weightedScore =
            frequencyScore * 0.25 +
            consistencyScore * 0.25 +
            amountScore * 0.2 +
            onTimeRatio * 0.3;

        // Map 0.0-1.0 → 300-850
        const finalScore = Math.round(300 + weightedScore * 550);
        const clampedScore = Math.max(300, Math.min(850, finalScore));
        const breakdown = {
            frequency: Math.round(frequencyScore * 100),
            consistency: Math.round(consistencyScore * 100),
            amount: Math.round(amountScore * 100),
            onTimePayments: Math.round(onTimeRatio * 100),
        };

        await _updateScore(uid, clampedScore);
        return {
            score: clampedScore,
            previousScore,
            delta: clampedScore - previousScore,
            breakdown,
        };
    }
);

async function _updateScore(uid: string, score: number) {
    await db.collection("users").doc(uid).update({
        "creditScore": score,
        "creditScoreUpdatedAt": admin.firestore.FieldValue.serverTimestamp(),
    });
}
