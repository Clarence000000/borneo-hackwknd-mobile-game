import 'package:firebase_auth/firebase_auth.dart';
import 'package:farm_fintech/config/constants.dart';
import 'package:farm_fintech/models/player.dart';

/// Handles recognition and setup of test admin accounts.
class AdminAccountService {
  const AdminAccountService._();

  static bool isAdminEmail(String? email) {
    if (email == null || email.isEmpty) return false;
    return kAdminTestEmails.contains(email.trim().toLowerCase());
  }

  static bool isCurrentUserAdmin() {
    final email = FirebaseAuth.instance.currentUser?.email;
    return isAdminEmail(email);
  }

  static void applyAdminPrivileges(Player player) {
    if (!isCurrentUserAdmin()) return;

    player.isAdmin = true;
    player.bankRegistered = true;
    player.creditScore = kMaxCreditScore;
    player.tutorialCompleted = true;

    if (player.cashBalance < kAdminUnlimitedBalance) {
      player.cashBalance = kAdminUnlimitedBalance;
    }
    if (player.bankBalance < kAdminUnlimitedBalance) {
      player.bankBalance = kAdminUnlimitedBalance;
    }
  }
}
