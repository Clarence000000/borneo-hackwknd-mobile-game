import { onCall, HttpsError } from "firebase-functions/v2/https";
import { initializeApp, getApps } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

if (!getApps().length) initializeApp();
const db = getFirestore();

const LATE_FEE_PERCENT = 0.5; // 50% of monthly installment
const GAME_DAYS_PER_MONTH = 30;
const ADMIN_TEST_EMAILS = new Set(["admin@farmfintech.test"]);

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

function readStartDay(plan: any): number | null {
    if (typeof plan.startDay === "number") return plan.startDay;
    // Legacy reconstruction: nextDueDay was the due day of installment (paid+1).
    // dueDayOf(paid+1) = startDay + paid*30  →  startDay = nextDueDay - paid*30
    if (typeof plan.nextDueDay === "number") {
        const paid = readPaidInstallments(plan);
        return plan.nextDueDay - paid * GAME_DAYS_PER_MONTH;
    }
    return null;
}

function readMonthlyFines(plan: any): Record<string, number> {
    const m = plan.monthlyFines;
    if (m && typeof m === "object") return m as Record<string, number>;
    return {};
}

function isAdminUser(userData: any, email?: string): boolean {
    if (userData?.isAdmin === true) return true;
    if (!email) return false;
    return ADMIN_TEST_EMAILS.has(String(email).trim().toLowerCase());
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
    isAdmin: boolean,
) {
    const installments = readInstallments(plan);
    const paid = readPaidInstallments(plan);
    const monthly = readMonthlyAmount(plan);
    const fines = readMonthlyFines(plan);

    if (installments <= 0 || monthly <= 0) {
        throw new HttpsError("failed-precondition", "Invalid BNPL plan configuration");
    }
    if (paid >= installments) {
        await planRef.update({status: "paid"});
        return {
            paidInstallment: false,
            alreadyPaid: true,
            message: "This BNPL plan is already fully paid.",
        };
    }

    const nextIdx = paid + 1;
    const fineForNext = Number(fines[String(nextIdx)] ?? 0);
    const amountDue = monthly + fineForNext;

    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();
    const userData = userDoc.data();
    if (!userData) {
        throw new HttpsError("not-found", "User not found");
    }

    let wallet: "cash" | "bank" | "admin" | null = "admin";
    if (!isAdmin) {
        wallet = resolveWalletToCharge(userData, amountDue, method);
        if (!wallet) {
            return {
                paidInstallment: false,
                insufficientFunds: true,
                amountDue,
                message: `Insufficient funds. Need RM${amountDue.toFixed(2)}.`,
            };
        }

        await userRef.update({
            [`${wallet}Balance`]: FieldValue.increment(-amountDue),
        });
    }

    const nextPaid = paid + 1;
    const isFullyPaid = nextPaid >= installments;

    const update: Record<string, any> = {
        paidInstallments: nextPaid,
        paidMonths: nextPaid,
        remainingAmount: Math.max(0, (installments - nextPaid) * monthly),
        status: isFullyPaid ? "paid" : "active",
    };
    if (fineForNext > 0) {
        update[`monthlyFines.${nextIdx}`] = FieldValue.delete();
    }
    await planRef.update(update);

    await userRef.collection("transactions").add({
        amount: amountDue,
        paymentType: wallet,
        category: "bnplPayment",
        timestamp: FieldValue.serverTimestamp(),
    });

    return {
        paidInstallment: true,
        deductedFrom: wallet,
        amountPaid: amountDue,
        fineApplied: fineForNext,
        paidInstallmentIndex: nextIdx,
        remainingInstallments: Math.max(0, installments - nextPaid),
        completed: isFullyPaid,
        message: isFullyPaid
            ? "BNPL plan fully paid. Great job!"
            : `Installment ${nextIdx} paid from ${wallet}.`,
    };
}

/**
 * Repay a single BNPL installment.
 * Always pays the oldest unpaid installment (paidInstallments + 1), charging
 * monthlyAmount + that month's fine (if any). Prepayment is allowed.
 */
export const repayBnplInstallment = onCall(
    async (request) => {
        const uid = request.auth?.uid;
        const email = request.auth?.token?.email as string | undefined;
        if (!uid) throw new HttpsError("unauthenticated", "Must be logged in");

        const {planId, paymentMethod} = request.data;
        if (!planId) {
            throw new HttpsError("invalid-argument", "planId required");
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
            throw new HttpsError("not-found", "BNPL plan not found");
        }
        const plan = planDoc.data()!;

        if ((plan.status ?? "active") !== "active") {
            return {
                paidInstallment: false,
                message: `Plan status is ${(plan.status ?? "unknown")} and cannot be paid.`,
            };
        }

        const userRef = db.collection("users").doc(uid);
        const userDoc = await userRef.get();
        const userData = userDoc.data()!;
        const adminAccount = isAdminUser(userData, email);

        return applyInstallmentPayment(uid, planRef, plan, normalizedMethod, adminAccount);
    },
);

/**
 * BNPL Penalty Calculation
 *
 * Fine-only: for each unpaid installment whose due day is strictly past
 * `currentDay` and that doesn't already have a fine, attach a one-time
 * 50% fine to that installment via monthlyFines[k]. Idempotent.
 *
 * No wallet deduction, no auto-pay, no auto-default.
 */
export const calculateBnplPenalty = onCall(
    async (request) => {
        const uid = request.auth?.uid;
        if (!uid) throw new HttpsError("unauthenticated", "Must be logged in");

        const { planId, currentDay } = request.data;
        if (!planId || typeof currentDay !== "number") {
            throw new HttpsError("invalid-argument", "planId and currentDay required");
        }

        const planRef = db
            .collection("users")
            .doc(uid)
            .collection("bnplPlans")
            .doc(planId);

        const planDoc = await planRef.get();
        if (!planDoc.exists) {
            throw new HttpsError("not-found", "BNPL plan not found");
        }

        const plan = planDoc.data()!;
        if ((plan.status ?? "active") !== "active") {
            return { penalty: 0, finesAdded: 0, message: "Plan not active." };
        }

        const installments = readInstallments(plan);
        const paid = readPaidInstallments(plan);
        const monthly = readMonthlyAmount(plan);
        const fines = readMonthlyFines(plan);
        const startDay = readStartDay(plan);

        if (startDay == null) {
            return { penalty: 0, finesAdded: 0, message: "Plan missing startDay." };
        }

        const fineAmount = monthly * LATE_FEE_PERCENT;
        const update: Record<string, any> = {};
        let newFines = 0;

        for (let k = paid + 1; k <= installments; k++) {
            const due = startDay + (k - 1) * GAME_DAYS_PER_MONTH;
            if (currentDay <= due) break; // strict >; later k also not overdue
            if (fines[String(k)] != null) continue;
            update[`monthlyFines.${k}`] = fineAmount;
            newFines++;
        }

        if (newFines > 0) await planRef.update(update);

        return {
            penalty: newFines * fineAmount,
            finesAdded: newFines,
            message: newFines === 0
                ? "No new fines."
                : `Added ${newFines} late fee(s) of RM${fineAmount.toFixed(2)} each.`,
        };
    }
);

/**
 * Create BNPL Plan
 * Callable: Expects { totalAmount, installments|termMonths, monthlyAmount?, paymentMethod?, startDay?, merchant?, description? }
 * Writes a document under users/{uid}/bnplPlans/{autoId}
 */
export const createBnplPlan = onCall(
    async (request) => {
        const uid = request.auth?.uid;
        if (!uid) throw new HttpsError("unauthenticated", "Must be logged in");

        const data = request.data || {};
        const totalAmount = Number(data.totalAmount ?? data.amount ?? 0);
        const installments = Number(data.installments ?? data.termMonths ?? 0);
        let monthlyAmount = data.monthlyAmount != null ? Number(data.monthlyAmount) : null;
        const paymentMethod = (data.paymentMethod as PaymentMethod) ?? "auto";
        const merchant = typeof data.merchant === "string" ? data.merchant : "merchant";
        const description = typeof data.description === "string" ? data.description : "BNPL purchase";
        const startDay = typeof data.startDay === "number" ? data.startDay : 0;

        if (!(totalAmount > 0)) {
            throw new HttpsError("invalid-argument", "totalAmount required and must be > 0");
        }
        if (!(installments > 0) && !(monthlyAmount && monthlyAmount > 0)) {
            throw new HttpsError(
                "invalid-argument",
                "Either installments (termMonths) or monthlyAmount must be provided and > 0",
            );
        }

        if (!monthlyAmount) {
            monthlyAmount = installments > 0 ? totalAmount / installments : totalAmount;
        }

        const plan: any = {
            itemName: description,
            totalAmount,
            installments,
            termMonths: installments,
            monthlyAmount,
            monthlyPayment: monthlyAmount,
            paidInstallments: 0,
            paidMonths: 0,
            remainingAmount: totalAmount,
            status: "active",
            paymentMethod,
            merchant,
            description,
            startDay,
            monthlyFines: {},
            createdAt: FieldValue.serverTimestamp(),
        };

        const planRef = await db.collection("users").doc(uid).collection("bnplPlans").add(plan);

        const created = await planRef.get();
        return { planId: planRef.id, plan: created.data() };
    },
);
