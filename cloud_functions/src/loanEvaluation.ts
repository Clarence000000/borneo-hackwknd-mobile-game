import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

const MIN_CREDIT_SCORE = 600; // Minimum score to qualify
const INTEREST_RATE = 0.05; // 5% monthly interest

/**
 * Loan Evaluation Cloud Function
 *
 * Evaluates whether a player qualifies for a bank loan based on their
 * Credit Score. If approved, creates the loan and deposits funds.
 */
export const evaluateLoan = functions.https.onCall(
    async (request) => {
        const uid = request.auth?.uid;
        if (!uid) throw new functions.https.HttpsError("unauthenticated", "Must be logged in");

        const { amount, termMonths } = request.data;
        if (!amount || !termMonths) {
            throw new functions.https.HttpsError("invalid-argument", "amount and termMonths required");
        }

        // Get player's credit score
        const userDoc = await db.collection("users").doc(uid).get();
        if (!userDoc.exists) {
            throw new functions.https.HttpsError("not-found", "User not found");
        }

        const userData = userDoc.data()!;
        const creditScore = userData.creditScore || 400;
        const bankRegistered = userData.bankRegistered || false;

        // Must have a registered bank
        if (!bankRegistered) {
            return {
                approved: false,
                reason: "You must register for a bank account first.",
            };
        }

        // Check credit score
        if (creditScore < MIN_CREDIT_SCORE) {
            return {
                approved: false,
                reason: `Credit score too low (${creditScore}). Minimum required: ${MIN_CREDIT_SCORE}. Improve your score by making more digital payments through your bank.`,
                currentScore: creditScore,
                requiredScore: MIN_CREDIT_SCORE,
            };
        }

        // Calculate loan terms
        const monthlyInterest = INTEREST_RATE;
        const totalInterest = amount * monthlyInterest * termMonths;
        const totalRepayment = amount + totalInterest;
        const monthlyPayment = totalRepayment / termMonths;

        // Create the loan
        const loanRef = db
            .collection("users")
            .doc(uid)
            .collection("loans")
            .doc();

        await loanRef.set({
            principal: amount,
            interestRate: monthlyInterest,
            termMonths,
            monthlyPayment,
            totalRepayment,
            remainingBalance: totalRepayment,
            paidMonths: 0,
            status: "active",
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Deposit loan amount into bank balance
        await db.collection("users").doc(uid).update({
            bankBalance: admin.firestore.FieldValue.increment(amount),
        });

        return {
            approved: true,
            loanId: loanRef.id,
            principal: amount,
            interestRate: monthlyInterest,
            termMonths,
            monthlyPayment: Math.round(monthlyPayment * 100) / 100,
            totalRepayment: Math.round(totalRepayment * 100) / 100,
            totalInterest: Math.round(totalInterest * 100) / 100,
            message: `Loan approved! ${amount} deposited to your bank. Monthly payment: ${monthlyPayment.toFixed(2)} for ${termMonths} months.`,
        };
    }
);
