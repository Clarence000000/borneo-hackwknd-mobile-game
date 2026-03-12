import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

// Penalty config (realistic Malaysian BNPL fees)
const ADMIN_FEE = 10; // RM10 admin fee per missed payment
const LATE_FEE = 23; // RM23 late payment fee

type PaymentMethod = "cash" | "bank" | "auto";

function readInstallments(plan: any): number {
    return (plan.installments ?? plan.termMonths ?? 0) as number;
}

function readPaidInstallments(plan: any): number {
    return (plan.paidInstallments ?? plan.paidMonths ?? 0) as number;
}

function readMonthlyAmount(plan: any): number {
    if (plan.monthlyAmount != null) return plan.monthlyAmount as number;
    if (plan.monthlyPayment != null) return plan.monthlyPayment as number;

    const installments = readInstallments(plan);
    const totalAmount = (plan.totalAmount ?? 0) as number;
    return installments > 0 ? totalAmount / installments : 0;
}

function readNextDueDateMillis(plan: any): number {
    return (plan.nextDueDate?.toMillis?.() || plan.nextDueDate || Date.now()) as number;
}

function resolveWalletToCharge(
    userData: any,
    amountDue: number,
    method: PaymentMethod,
): "cash" | "bank" | null {
    if (method === "cash") {
        return userData.cashBalance >= amountDue ? "cash" : null;
    }
    if (method === "bank") {
        return userData.bankBalance >= amountDue ? "bank" : null;
    }

    if (userData.cashBalance >= amountDue) return "cash";
    if (userData.bankBalance >= amountDue) return "bank";
    return null;
}

async function applyInstallmentPayment(
    uid: string,
    planRef: any,
    plan: any,
    method: PaymentMethod,
) {
    const installments = readInstallments(plan);
    const paidInstallments = readPaidInstallments(plan);
    const monthlyAmount = readMonthlyAmount(plan);
    const lateFees = (plan.lateFees ?? 0) as number;
    const amountDue = monthlyAmount + lateFees;

    if (installments <= 0 || monthlyAmount <= 0) {
        throw new functions.https.HttpsError("failed-precondition", "Invalid BNPL plan configuration");
    }
    if (paidInstallments >= installments) {
        await planRef.update({status: "paid"});
        return {
            paidInstallment: false,
            alreadyPaid: true,
            message: "This BNPL plan is already fully paid.",
        };
    }

    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();
    const userData = userDoc.data();
    if (!userData) {
        throw new functions.https.HttpsError("not-found", "User not found");
    }

    const wallet = resolveWalletToCharge(userData, amountDue, method);
    if (!wallet) {
        return {
            paidInstallment: false,
            insufficientFunds: true,
            amountDue,
            message: `Insufficient funds. Need RM${amountDue.toFixed(2)}.`,
        };
    }

    await userRef.update({
        [`${wallet}Balance`]: admin.firestore.FieldValue.increment(-amountDue),
    });

    const nextPaidInstallments = paidInstallments + 1;
    const isFullyPaid = nextPaidInstallments >= installments;
    const dueDateMillis = readNextDueDateMillis(plan);
    const nextDueDate = new Date(Math.max(Date.now(), dueDateMillis) + 30 * 24 * 60 * 60 * 1000);

    await planRef.update({
        paidInstallments: nextPaidInstallments,
        paidMonths: nextPaidInstallments,
        remainingAmount: Math.max(0, (installments - nextPaidInstallments) * monthlyAmount),
        lateFees: 0,
        nextDueDate: admin.firestore.Timestamp.fromDate(nextDueDate),
        status: isFullyPaid ? "paid" : "active",
    });

    await userRef.collection("transactions").add({
        amount: amountDue,
        paymentType: wallet,
        category: "bnplPayment",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
        paidInstallment: true,
        deductedFrom: wallet,
        amountPaid: amountDue,
        remainingInstallments: Math.max(0, installments - nextPaidInstallments),
        completed: isFullyPaid,
        message: isFullyPaid
            ? "BNPL plan fully paid. Great job!"
            : `Installment paid from ${wallet}.`,
    };
}

export const repayBnplInstallment = functions.https.onCall(
    async (request) => {
        const uid = request.auth?.uid;
        if (!uid) throw new functions.https.HttpsError("unauthenticated", "Must be logged in");

        const {planId, paymentMethod} = request.data;
        if (!planId) {
            throw new functions.https.HttpsError("invalid-argument", "planId required");
        }

        const normalizedMethod = (["cash", "bank", "auto"] as PaymentMethod[]).includes(paymentMethod)
            ? (paymentMethod as PaymentMethod)
            : "auto";

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

        if ((plan.status ?? "active") !== "active") {
            return {
                paidInstallment: false,
                message: `Plan status is ${(plan.status ?? "unknown")} and cannot be paid.`,
            };
        }

        return applyInstallmentPayment(uid, planRef, plan, normalizedMethod);
    },
);

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
        const dueDate = readNextDueDateMillis(plan);

        if (now <= dueDate) {
            return { penalty: 0, message: "Payment is not yet overdue" };
        }

        // First try to collect normal installment (cash first then bank).
        const payResult = await applyInstallmentPayment(uid, planRef, plan, "auto");
        if (payResult.paidInstallment === true) {
            return {
                penalty: 0,
                autoPaid: true,
                ...payResult,
                message: "Overdue installment recovered before penalty.",
            };
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
