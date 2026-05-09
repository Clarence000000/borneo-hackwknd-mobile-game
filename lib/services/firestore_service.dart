import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:farm_fintech/models/financial/bnpl_plan.dart';
import 'package:farm_fintech/models/player.dart';
import 'package:farm_fintech/services/admin_account_service.dart';
import 'package:farm_fintech/models/tile.dart';
import 'package:farm_fintech/models/financial/transaction.dart';
import 'package:farm_fintech/config/constants.dart';

/// Firestore CRUD service for player data.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Player? _cachedPlayer;

  /// Ensure we always use a singleton or a cached reference if needed,
  /// but for this simple app, instantiating it is fine.
  FirestoreService();

  FirebaseFirestore getDb() => _db;

  /// Clear the cached player to prevent stale data on account switch.
  void clearCache() {
    _cachedPlayer = null;
  }

  /// Creates a new player profile in Firestore after registration
  Future<void> createPlayer(Player player) async {
    AdminAccountService.applyAdminPrivileges(player);
    await _db.collection('users').doc(player.uid).set(player.toMap());
    _cachedPlayer = player;
  }

  /// Get the player from Firestore
  Future<Player?> getPlayer(String uid, {bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedPlayer != null && _cachedPlayer!.uid == uid) {
      return _cachedPlayer;
    }

    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;

    final data = doc.data()!;
    _cachedPlayer = Player.fromMap(uid, data);

    final wasAdmin = _cachedPlayer!.isAdmin;
    AdminAccountService.applyAdminPrivileges(_cachedPlayer!);
    if (_cachedPlayer!.isAdmin && !wasAdmin) {
      await savePlayer(_cachedPlayer!);
    }

    return _cachedPlayer;
  }

  /// Update an existing player's profile data
  Future<void> savePlayer(Player player) async {
    AdminAccountService.applyAdminPrivileges(player);
    _cachedPlayer = player;
    await _db
        .collection('users')
        .doc(player.uid)
        .set(player.toMap(), SetOptions(merge: true));
  }

  /// Create a new BNPL plan in the user's subcollection
  Future<void> createBnplPlan(String uid, BnplPlan plan) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('bnplPlans')
        .doc(plan.id)
        .set({
          'id': plan.id,
          'itemName': plan.itemName,
          'totalAmount': plan.totalAmount,
          'remainingAmount': plan.remainingAmount,
          'installments': plan.installments,
          'paidInstallments': plan.paidInstallments,
          'monthlyAmount': plan.monthlyAmount,
          'termMonths': plan.installments,
          'paidMonths': plan.paidInstallments,
          'monthlyPayment': plan.monthlyAmount,
          'status': plan.status.name,
          'nextDueDate': Timestamp.fromDate(plan.nextDueDate),
          'nextDueDay': plan.nextDueDay,
          'lateFees': plan.lateFees,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

    /// Stream BNPL plans for a user for realtime updates
    Stream<List<BnplPlan>> streamBnplPlans(String uid) {
      return _db
          .collection('users')
          .doc(uid)
          .collection('bnplPlans')
          .orderBy('createdAt', descending: false)
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => BnplPlan.fromMap(d.id, d.data()))
              .toList());
    }

    /// Stream recent transactions for a user (useful for realtime feed)
    Stream<List<Map<String, dynamic>>> streamTransactions(String uid,
        {int limit = 50}) {
      return _db
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .snapshots()
          .map((snap) => snap.docs.map((d) => d.data()).toList());
    }

  /// Update the leaderboard rankings (simple implementation for now)
  Future<void> updateLeaderboard(Player player) async {
    await _db
        .collection('leaderboards')
        .doc(player.country)
        .collection('rankings')
        .doc(player.uid)
        .set({
          'displayName': player.displayName,
          'netWorth': player.totalNetWorth,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  /// Log a transaction to build credit score (Legacy)
  Future<void> logTransaction(
    String uid, {
    required double amount,
    required String paymentType,
    required String category,
  }) async {
    await _db.collection('users').doc(uid).collection('transactions').add({
      'amount': amount,
      'paymentType': paymentType, // 'bank' or 'cash'
      'category': category, // e.g. 'deposit', 'withdrawal', 'bnplPayment'
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Add a full transaction record
  Future<void> addTransaction(String uid, Transaction tx) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .add(tx.toMap());
  }

  /// Save the entire game grid state
  Future<void> saveGrid(String uid, List<List<Tile>> grid) async {
    final batch = _db.batch();
    final gridRef = _db.collection('users').doc(uid).collection('grid');

    for (final row in grid) {
      for (final tile in row) {
        final docId = '${tile.row}_${tile.col}';
        batch.set(gridRef.doc(docId), tile.toMap());
      }
    }
    await batch.commit();
  }

  /// Load grid state for a user
  Future<List<List<Tile>>?> getGrid(String uid) async {
    final snapshot = await _db.collection('users').doc(uid).collection('grid').get();
    if (snapshot.docs.isEmpty) return null;

    final List<List<Tile>> grid = List.generate(
      kGridRows,
      (row) => List.generate(kGridCols, (col) => Tile(col: col, row: row, type: TileType.grass)),
    );

    for (final doc in snapshot.docs) {
      final tile = Tile.fromMap(doc.data());
      if (tile.row < kGridRows && tile.col < kGridCols) {
        grid[tile.row][tile.col] = tile;
      }
    }
    return grid;
  }

  /// Delete all documents in a subcollection
  Future<void> _clearSubcollection(String uid, String subcollection) async {
    final ref = _db.collection('users').doc(uid).collection(subcollection);
    final snapshot = await ref.get();
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> clearBnplPlans(String uid) => _clearSubcollection(uid, 'bnplPlans');
  Future<void> clearInsurancePolicies(String uid) => _clearSubcollection(uid, 'insurancePolicies');
  Future<void> clearBankAccounts(String uid) => _clearSubcollection(uid, 'bankAccounts');
}
