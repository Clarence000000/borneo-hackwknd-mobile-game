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
exports.calculateBnplPenalty = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
if (!admin.apps.length)
    admin.initializeApp();
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
exports.calculateBnplPenalty = functions.https.onCall(async (request) => {
    var _a, _b, _c;
    const uid = (_a = request.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!uid)
        throw new functions.https.HttpsError("unauthenticated", "Must be logged in");
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
    const plan = planDoc.data();
    const now = Date.now();
    const dueDate = ((_c = (_b = plan.nextDueDate) === null || _b === void 0 ? void 0 : _b.toMillis) === null || _c === void 0 ? void 0 : _c.call(_b)) || plan.nextDueDate;
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
    const userData = userDoc.data();
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