import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Generic Cloud Functions caller service.
class CloudFunctionsService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Evaluate if the player qualifies for a loan based on their credit score
  Future<Map<String, dynamic>> evaluateLoan(
    double amount,
    int termMonths,
  ) async {
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
  Future<Map<String, dynamic>> calculateBnplPenalty(String planId) async {
    try {
      final callable = _functions.httpsCallable('calculateBnplPenalty');
      final result = await callable.call({'planId': planId});
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      debugPrint('Error calling calculateBnplPenalty: $e');
      return {'penalty': 0, 'error': e.toString()};
    }
  }

  /// Repay one BNPL installment using selected wallet method.
  Future<Map<String, dynamic>> repayBnplInstallment(
    String planId,
    String paymentMethod,
  ) async {
    try {
      final callable = _functions.httpsCallable('repayBnplInstallment');
      final result = await callable.call({
        'planId': planId,
        'paymentMethod': paymentMethod,
      });
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      debugPrint('Error calling repayBnplInstallment: $e');
      return {'paidInstallment': false, 'error': e.toString()};
    }
  }

  /// Request the server to check the weather at the given coordinates
  Future<Map<String, dynamic>> checkWeather(double lat, double lng) async {
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
  Future<Map<String, dynamic>> calculateCreditScore() async {
    try {
      final callable = _functions.httpsCallable('calculateCreditScore');
      final result = await callable.call();
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      debugPrint('Error calling calculateCreditScore: $e');
      return {'score': 400};
    }
  }
}
