import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

String _readFunctionErrorMessage(Object e) {
  if (e is FirebaseFunctionsException) {
    return e.message ?? 'Cloud function error (${e.code}).';
  }
  return e.toString();
}

/// Generic Cloud Functions caller service.
class CloudFunctionsService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _ensureAuthenticated() async {
    if (_auth.currentUser == null) {
      debugPrint('No authenticated user found. Signing in anonymously...');
      await _auth.signInAnonymously();
    }
  }

  /// Evaluate if the player qualifies for a loan based on their credit score
  Future<Map<String, dynamic>> evaluateLoan(
    double amount,
    int termMonths,
  ) async {
    await _ensureAuthenticated();
    try {
      final callable = _functions.httpsCallable('evaluateLoan');
      final result = await callable.call({
        'amount': amount,
        'termMonths': termMonths,
      });
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      debugPrint('Error calling evaluateLoan: $e');
      return {'approved': false, 'reason': 'Server error: $e'};
    }
  }

  /// Calculate penalty for an overdue BNPL plan
  Future<Map<String, dynamic>> calculateBnplPenalty(
    String planId,
    int currentDay,
  ) async {
    await _ensureAuthenticated();
    try {
      final callable = _functions.httpsCallable('calculateBnplPenalty');
      final result = await callable.call({
        'planId': planId,
        'currentDay': currentDay,
      });
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      debugPrint('Error calling calculateBnplPenalty: $e');
      return {
        'penalty': 0,
        'error': e.toString(),
        'message': _readFunctionErrorMessage(e),
      };
    }
  }

  /// Repay one BNPL installment using selected wallet method.
  Future<Map<String, dynamic>> repayBnplInstallment(
    String planId,
    String paymentMethod,
    int currentDay,
  ) async {
    await _ensureAuthenticated();
    try {
      final callable = _functions.httpsCallable('repayBnplInstallment');
      final result = await callable.call({
        'planId': planId,
        'paymentMethod': paymentMethod,
        'currentDay': currentDay,
      });
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      debugPrint('Error calling repayBnplInstallment: $e');
      return {
        'paidInstallment': false,
        'error': e.toString(),
        'message': _readFunctionErrorMessage(e),
      };
    }
  }

  /// Request the server to check the weather at the given coordinates
  Future<Map<String, dynamic>> checkWeather(double lat, double lng) async {
    await _ensureAuthenticated();
    try {
      final callable = _functions.httpsCallable('weatherCheck');
      final result = await callable.call({'lat': lat, 'lng': lng});
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      debugPrint('Error calling weatherCheck: $e');
      return {'hasDisaster': false};
    }
  }

  /// Recalculate credit score based on historical bank transactions
  /// @deprecated Use CreditScoreService (local) instead. This Cloud Function
  /// is broken and always fails with INTERNAL error.
  Future<Map<String, dynamic>> calculateCreditScore() async {
    await _ensureAuthenticated();
    try {
      final callable = _functions.httpsCallable('calculateCreditScore');
      final result = await callable.call();
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      debugPrint('Error calling calculateCreditScore: $e');
      // Return empty map — callers must NOT overwrite local score with defaults
      return {};
    }
  }
}
