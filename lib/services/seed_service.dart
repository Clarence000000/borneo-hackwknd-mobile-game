import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class SeedService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final Random _random = Random();

  static final _aseanNames = [
    'Siti Aminah', 'Budi Santoso', 'Somchai', 'Nguyen Van', 'Maria Clara', 
    'Ahmad Zaki', 'Rina Wati', 'Tan Kah Kee', 'Minh Thu', 'Juan Dela Cruz'
  ];

  static final _countries = ['MY', 'ID', 'TH', 'VN', 'PH', 'SG'];

  static Future<void> seedLeaderboard() async {
    for (final country in _countries) {
      final batch = _db.batch();
      final rankingsRef = _db
          .collection('leaderboards')
          .doc(country)
          .collection('rankings');

      for (var i = 0; i < 5; i++) {
        final name = _aseanNames[_random.nextInt(_aseanNames.length)];
        final fakeUid = 'fake_${country}_$i';
        // Base net worth between 2000 and 15000
        final netWorth = 2000.0 + _random.nextDouble() * 13000.0;

        batch.set(rankingsRef.doc(fakeUid), {
          'displayName': '$name ($country)',
          'netWorth': netWorth,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }
}
