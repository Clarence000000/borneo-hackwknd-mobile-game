import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:farm_fintech/models/player.dart';
import 'package:farm_fintech/services/firestore_service.dart';
import 'package:farm_fintech/services/location_service.dart';

/// Firebase Auth service wrapper.
///
/// Combines FirebaseAuth events with Player creation stored via FirestoreService.
class AuthService {
  final auth.FirebaseAuth _firebaseAuth = auth.FirebaseAuth.instance;
  final FirestoreService _firestore = FirestoreService();
  final LocationService _location = LocationService();

  /// Stream of Firebase native auth changes
  Stream<auth.User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Get the currently logged-in user UID or null
  auth.User? get currentUser => _firebaseAuth.currentUser;

  /// Register an account, detect country via GPS, and save to Firestore
  Future<Player?> register(String email, String password, String displayName) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        // 1. Detect region/country from GPS dummy
        final loc = await _location.getCurrentLocation();
        final country = _location.detectCountry(loc.lat, loc.lng);
        final currency = _location.getCurrency(country);

        // 2. Build new player profile with defaults
        final player = Player(
          uid: user.uid,
          displayName: displayName,
          country: country,
          currency: currency,
          gpsLat: loc.lat,
          gpsLng: loc.lng,
        );

        // 3. Save profile to Firestore
        await _firestore.createPlayer(player);
        return player;
      }
    } catch (e) {
      debugPrint("Registration error: $e");
      rethrow;
    }
  }

  /// Sign into existing account, then fetch Player profile from Firestore
  Future<Player?> signIn(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        return await _firestore.getPlayer(credential.user!.uid);
      }
    } catch (e) {
      debugPrint("Login error: $e");
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }
}

void debugPrint(String message) {
  // Simple dev print wrapper to keep file cleanly isolated. 
  // Should ideally use flutter log or print.
  // ignore: avoid_print
  print(message);
}
