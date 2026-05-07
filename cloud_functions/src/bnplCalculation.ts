import { onCall, HttpsError } from "firebase-functions/v2/https";
import { initializeApp, getApps } from "firebase-admin/app";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";

if (!getApps().length) initializeApp();
const db = getFirestore();

// Penalty config (realistic Malaysian BNPL fees)
const ADMIN_FEE = 10; // RM10 admin fee per missed payment
const LATE_FEE = 23; // RM23 late payment fee
const GAME_DAYS_PER_MONTH = 30;
const DAY_MS = 24 * 60 * 60 * 1000;
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

function readNextDueDateMillis(plan: any): number {
    return (plan.nextDueDate?.toMillis?.() || plan.nextDueDate || Date.now()) as number;
}

function readNextDueDay(plan: any): number | null {
    return typeof plan.nextDueDay === "number" ? plan.nextDueDay : null;
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
    const paidInstallments = readPaidInstallments(plan);
    const monthlyAmount = readMonthlyAmount(plan);
    const lateFees = (plan.lateFees ?? 0) as number;
    const amountDue = monthlyAmount + lateFees;

    if (installments <= 0 || monthlyAmount <= 0) {
        throw new HttpsError("failed-precondition", "Invalid BNPL plan configuration");
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

    const nextPaidInstallments = paidInstallments + 1;
    const isFullyPaid = nextPaidInstallments >= installments;
    const dueDateMillis = readNextDueDateMillis(plan);
    const nextDueDay = readNextDueDay(plan);
    const nextDueDate = new Date(Math.max(Date.now(), dueDateMillis) + GAME_DAYS_PER_MONTH * DAY_MS);

    await planRef.update({
        paidInstallments: nextPaidInstallments,
        paidMonths: nextPaidInstallments,
        remainingAmount: Math.max(0, (installments - nextPaidInstallments) * monthlyAmount),
        lateFees: 0,
        nextDueDate: Timestamp.fromDate(nextDueDate),
        nextDueDay: nextDueDay != null ? nextDueDay + GAME_DAYS_PER_MONTH : null,
        status: isFullyPaid ? "paid" : "active",
    });

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
        remainingInstallments: Math.max(0, installments - nextPaidInstallments),
        completed: isFullyPaid,
        message: isFullyPaid
            ? "BNPL plan fully paid. Great job!"
            : `Installment paid from ${wallet}.`,
    };
}

export const repayBnplInstallment = onCall(
    async (request) => {
        const uid = request.auth?.uid;
        const email = request.auth?.token?.email as string | undefined;
        if (!uid) throw new HttpsError("unauthenticated", "Must be logged in");

        const {planId, paymentMethod, currentDay} = request.data;
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

        const dueGameDay = readNextDueDay(plan);
        if (typeof currentDay === "number" && dueGameDay != null && currentDay < dueGameDay) {
            return {
                paidInstallment: false,
                message: `Installment is not due yet. Next due on game day ${dueGameDay}.`,
            };
        }

        // Legacy fallback for plans without nextDueDay.
        if (dueGameDay == null) {
            const dueDate = readNextDueDateMillis(plan);
            if (Date.now() < dueDate) {
                return {
                    paidInstallment: false,
                    message: "Installment is not due yet.",
                };
            }
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
 * Called when a BNPL installment is overdue.
 * Applies realistic penalty charges to teach the dangers of BNPL debt traps.
 */
export const calculateBnplPenalty = onCall(
    async (request) => {
        const uid = request.auth?.uid;
        const email = request.auth?.token?.email as string | undefined;
        if (!uid) throw new HttpsError("unauthenticated", "Must be logged in");

        const { planId, currentDay } = request.data;
        if (!planId) {
            throw new HttpsError("invalid-argument", "planId required");
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
        const userRef = db.collection("users").doc(uid);
        const userDoc = await userRef.get();
        const userData = userDoc.data()!;
        const adminAccount = isAdminUser(userData, email);

        const dueGameDay = readNextDueDay(plan);
        if (typeof currentDay === "number" && dueGameDay != null) {
            if (currentDay <= dueGameDay) {
                return {
                    penalty: 0,
                    message: `Payment is not yet overdue (due on game day ${dueGameDay})`,
                };
            }
        } else {
            const now = Date.now();
            const dueDate = readNextDueDateMillis(plan);

            if (now <= dueDate) {
                return { penalty: 0, message: "Payment is not yet overdue" };
            }
        }

        // First try to collect normal installment (cash first then bank).
        const payResult = await applyInstallmentPayment(uid, planRef, plan, "auto", adminAccount);
        if (payResult.paidInstallment === true) {
            return {
                penalty: 0,
                autoPaid: true,
                ...payResult,
                message: "Overdue installment recovered before penalty.",
            };
        }

        // Calculate days overdue
        const daysOverdue =
            typeof currentDay === "number" && dueGameDay != null
                ? currentDay - dueGameDay
                : Math.floor((Date.now() - readNextDueDateMillis(plan)) / DAY_MS);
        const totalPenalty = ADMIN_FEE + LATE_FEE;

        // Apply penalty
        await planRef.update({
            lateFees: FieldValue.increment(totalPenalty),
        });

        // Deduct from player's wallet (cash first, then bank)
        let deductedFrom = "cash";
        if (userData.cashBalance >= totalPenalty) {
            await userRef.update({
                cashBalance: FieldValue.increment(-totalPenalty),
            });
        } else if (userData.bankBalance >= totalPenalty) {
            await userRef.update({
                bankBalance: FieldValue.increment(-totalPenalty),
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

        const nextDueDate = new Date(Date.now() + GAME_DAYS_PER_MONTH * DAY_MS);
        const startDay = typeof data.startDay === "number" ? data.startDay : null;
        const nextDueDay = startDay != null ? startDay + GAME_DAYS_PER_MONTH : null;

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
            lateFees: 0,
            status: "active",
            paymentMethod,
            merchant,
            description,
            createdAt: FieldValue.serverTimestamp(),
            nextDueDate: Timestamp.fromDate(nextDueDate),
            nextDueDay,
        };

        const planRef = await db.collection("users").doc(uid).collection("bnplPlans").add(plan);

        const created = await planRef.get();
        return { planId: planRef.id, plan: created.data() };
    },
);
