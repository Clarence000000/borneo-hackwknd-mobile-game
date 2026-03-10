import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

// Penalty config (realistic Malaysian BNPL fees)
const ADMIN_FEE = 10; // RM10 admin fee per missed payment
const LATE_FEE = 23; // RM23 late payment fee

/**
 * BNPL Penalty Calculation
 *
 * Called when a BNPL installment is overdue.
 * Applies realistic penalty charges to teach the dangers of BNPL debt traps.
 */
export const calculateBnplPenalty = functions.https.onCall(
    async (request) => {
        const uid = request.auth?.uid;
        if (!uid) throw new functions.https.HttpsError("unauthenticated", "Must be logged in");

        const { planId } = request.data;
        if (!planId) {
            throw new functions.https.HttpsError("invalid-argument", "planId required");
        }

        const planRef = db
            .collection("users")
            .doc(uid)
            .collection("bnplPlans")
            .doc(planId);

        const planDoc = await planRef.get();
        if (!planDoc.exists) {
            throw new functions.https.HttpsError("not-found", "BNPL plan not found");
        }

        const plan = planDoc.data()!;
        const now = Date.now();
        const dueDate = plan.nextDueDate?.toMillis?.() || plan.nextDueDate;

        if (now <= dueDate) {
            return { penalty: 0, message: "Payment is not yet overdue" };
        }

        // Calculate days overdue
        const daysOverdue = Math.floor((now - dueDate) / (24 * 60 * 60 * 1000));
        const totalPenalty = ADMIN_FEE + LATE_FEE;

        // Apply penalty
        await planRef.update({
            lateFees: admin.firestore.FieldValue.increment(totalPenalty),
        });

        // Deduct from player's wallet (cash first, then bank)
        const userRef = db.collection("users").doc(uid);
        const userDoc = await userRef.get();
        const userData = userDoc.data()!;

        let deductedFrom = "cash";
        if (userData.cashBalance >= totalPenalty) {
            await userRef.update({
                cashBalance: admin.firestore.FieldValue.increment(-totalPenalty),
            });
        } else if (userData.bankBalance >= totalPenalty) {
            await userRef.update({
                bankBalance: admin.firestore.FieldValue.increment(-totalPenalty),
            });
            deductedFrom = "bank";
        } else {
            // Can't pay → default the plan
            await planRef.update({ status: "defaulted" });
            return {
                penalty: totalPenalty,
                deductedFrom: "none",
                defaulted: true,
                message: `Payment defaulted! You owe RM${totalPenalty} (RM${ADMIN_FEE} admin + RM${LATE_FEE} late fee). Insufficient funds.`,
            };
        }

        return {
            penalty: totalPenalty,
            adminFee: ADMIN_FEE,
            lateFee: LATE_FEE,
            daysOverdue,
            deductedFrom,
            defaulted: false,
            message: `Late payment penalty: RM${ADMIN_FEE} admin fee + RM${LATE_FEE} late fee = RM${totalPenalty} deducted from ${deductedFrom}.`,
        };
    }
);
