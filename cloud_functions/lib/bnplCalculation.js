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
exports.calculateBnplPenalty = exports.repayBnplInstallment = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
if (!admin.apps.length)
    admin.initializeApp();
const db = admin.firestore();
// Penalty config (realistic Malaysian BNPL fees)
const ADMIN_FEE = 10; // RM10 admin fee per missed payment
const LATE_FEE = 23; // RM23 late payment fee
const GAME_DAYS_PER_MONTH = 30;
const DAY_MS = 24 * 60 * 60 * 1000;
const ADMIN_TEST_EMAILS = new Set(["admin@farmfintech.test"]);
function readInstallments(plan) {
    var _a, _b;
    return ((_b = (_a = plan.installments) !== null && _a !== void 0 ? _a : plan.termMonths) !== null && _b !== void 0 ? _b : 0);
}
function readPaidInstallments(plan) {
    var _a, _b;
    return ((_b = (_a = plan.paidInstallments) !== null && _a !== void 0 ? _a : plan.paidMonths) !== null && _b !== void 0 ? _b : 0);
}
function readMonthlyAmount(plan) {
    var _a;
    if (plan.monthlyAmount != null)
        return plan.monthlyAmount;
    if (plan.monthlyPayment != null)
        return plan.monthlyPayment;
    const installments = readInstallments(plan);
    const totalAmount = ((_a = plan.totalAmount) !== null && _a !== void 0 ? _a : 0);
    return installments > 0 ? totalAmount / installments : 0;
}
function readNextDueDateMillis(plan) {
    var _a, _b;
    return (((_b = (_a = plan.nextDueDate) === null || _a === void 0 ? void 0 : _a.toMillis) === null || _b === void 0 ? void 0 : _b.call(_a)) || plan.nextDueDate || Date.now());
}
function readNextDueDay(plan) {
    return typeof plan.nextDueDay === "number" ? plan.nextDueDay : null;
}
function isAdminUser(userData, email) {
    if ((userData === null || userData === void 0 ? void 0 : userData.isAdmin) === true)
        return true;
    if (!email)
        return false;
    return ADMIN_TEST_EMAILS.has(String(email).trim().toLowerCase());
}
function resolveWalletToCharge(userData, amountDue, method) {
    if (method === "cash") {
        return userData.cashBalance >= amountDue ? "cash" : null;
    }
    if (method === "bank") {
        return userData.bankBalance >= amountDue ? "bank" : null;
    }
    if (userData.cashBalance >= amountDue)
        return "cash";
    if (userData.bankBalance >= amountDue)
        return "bank";
    return null;
}
async function applyInstallmentPayment(uid, planRef, plan, method, isAdmin) {
    var _a;
    const installments = readInstallments(plan);
    const paidInstallments = readPaidInstallments(plan);
    const monthlyAmount = readMonthlyAmount(plan);
    const lateFees = ((_a = plan.lateFees) !== null && _a !== void 0 ? _a : 0);
    const amountDue = monthlyAmount + lateFees;
    if (installments <= 0 || monthlyAmount <= 0) {
        throw new functions.https.HttpsError("failed-precondition", "Invalid BNPL plan configuration");
    }
    if (paidInstallments >= installments) {
        await planRef.update({ status: "paid" });
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
    let wallet = "admin";
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
            [`${wallet}Balance`]: admin.firestore.FieldValue.increment(-amountDue),
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
        nextDueDate: admin.firestore.Timestamp.fromDate(nextDueDate),
        nextDueDay: nextDueDay != null ? nextDueDay + GAME_DAYS_PER_MONTH : null,
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
exports.repayBnplInstallment = functions.https.onCall(async (request) => {
    var _a, _b, _c, _d, _e;
    const uid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    const email = (_c = (_b = request.auth) === null || _b === void 0 ? void 0 : _b.token) === null || _c === void 0 ? void 0 : _c.email;
    if (!uid)
        throw new functions.https.HttpsError("unauthenticated", "Must be logged in");
    const { planId, paymentMethod, currentDay } = request.data;
    if (!planId) {
        throw new functions.https.HttpsError("invalid-argument", "planId required");
    }
    const normalizedMethod = ["cash", "bank", "auto"].includes(paymentMethod)
        ? paymentMethod
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
    const plan = planDoc.data();
    if (((_d = plan.status) !== null && _d !== void 0 ? _d : "active") !== "active") {
        return {
            paidInstallment: false,
            message: `Plan status is ${((_e = plan.status) !== null && _e !== void 0 ? _e : "unknown")} and cannot be paid.`,
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
    const userData = userDoc.data();
    const adminAccount = isAdminUser(userData, email);
    return applyInstallmentPayment(uid, planRef, plan, normalizedMethod, adminAccount);
});
/**
 * BNPL Penalty Calculation
 *
 * Called when a BNPL installment is overdue.
 * Applies realistic penalty charges to teach the dangers of BNPL debt traps.
 */
exports.calculateBnplPenalty = functions.https.onCall(async (request) => {
    var _a, _b, _c;
    const uid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    const email = (_c = (_b = request.auth) === null || _b === void 0 ? void 0 : _b.token) === null || _c === void 0 ? void 0 : _c.email;
    if (!uid)
        throw new functions.https.HttpsError("unauthenticated", "Must be logged in");
    const { planId, currentDay } = request.data;
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
    const plan = planDoc.data();
    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();
    const userData = userDoc.data();
    const adminAccount = isAdminUser(userData, email);
    const dueGameDay = readNextDueDay(plan);
    if (typeof currentDay === "number" && dueGameDay != null) {
        if (currentDay <= dueGameDay) {
            return {
                penalty: 0,
                message: `Payment is not yet overdue (due on game day ${dueGameDay})`,
            };
        }
    }
    else {
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
    const daysOverdue = typeof currentDay === "number" && dueGameDay != null
        ? currentDay - dueGameDay
        : Math.floor((Date.now() - readNextDueDateMillis(plan)) / DAY_MS);
    const totalPenalty = ADMIN_FEE + LATE_FEE;
    // Apply penalty
    await planRef.update({
        lateFees: admin.firestore.FieldValue.increment(totalPenalty),
    });
    // Deduct from player's wallet (cash first, then bank)
    let deductedFrom = "cash";
    if (userData.cashBalance >= totalPenalty) {
        await userRef.update({
            cashBalance: admin.firestore.FieldValue.increment(-totalPenalty),
        });
    }
    else if (userData.bankBalance >= totalPenalty) {
        await userRef.update({
            bankBalance: admin.firestore.FieldValue.increment(-totalPenalty),
        });
        deductedFrom = "bank";
    }
    else {
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
});
//# sourceMappingURL=bnplCalculation.js.map