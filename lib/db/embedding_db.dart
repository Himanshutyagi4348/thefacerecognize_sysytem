// ============================================================
// embedding_db.dart
// SQLite database helper for the Face Recognition App.
// Handles users, pose embeddings, and verification logs.
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../constants.dart';
import '../models/user_model.dart';
import '../models/embedding_model.dart';

class EmbeddingDb {
  // ----------------------------------------------------------
  // SINGLETON
  // ----------------------------------------------------------
  EmbeddingDb._internal();
  static final EmbeddingDb instance = EmbeddingDb._internal();

  static Database? _database;

  // ----------------------------------------------------------
  // DATABASE INITIALIZATION
  // ----------------------------------------------------------
  Future<Database> get database async {
    if (_database != null) {
      kDebugLog('EmbeddingDb: returning existing database instance');
      return _database!;
    }
    kDebugLog('EmbeddingDb: initializing database');
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, kDatabaseName);

    kDebugLog('EmbeddingDb: opening database at $path');
    return await openDatabase(
      path,
      version: kDatabaseVersion,
      onCreate: _onCreate,
      onConfigure: (db) async {
        // Enforce foreign key constraints (cascade deletes, etc.)
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  // ----------------------------------------------------------
  // onCreate — TABLE + INDEX CREATION
  // ----------------------------------------------------------
  Future<void> _onCreate(Database db, int version) async {
    kDebugLog('EmbeddingDb: creating database schema version $version');
    // ---- users table ----
    await db.execute('''
      CREATE TABLE $kUsersTable (
        user_id TEXT PRIMARY KEY,
        user_name TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // ---- embeddings table ----
    await db.execute('''
      CREATE TABLE $kEmbeddingsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        pose TEXT NOT NULL,          -- front | up | down | left | right
        embedding TEXT NOT NULL,     -- JSON-encoded List<double>
        created_at TEXT NOT NULL,
        brightness REAL,             -- optional: luminance at capture
        sharpness REAL,               -- optional: Laplacian variance at capture
        capture_device TEXT,          -- optional: device model/identifier
        FOREIGN KEY (user_id) REFERENCES $kUsersTable (user_id)
          ON DELETE CASCADE
      )
    ''');

    // ---- verification_logs table ----
    await db.execute('''
      CREATE TABLE $kVerificationLogsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT,
        confidence_score REAL NOT NULL,
        matched INTEGER NOT NULL,     -- 0 = false, 1 = true
        aggregation_strategy TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES $kUsersTable (user_id)
          ON DELETE SET NULL
      )
    ''');

    // ---- indexes ----
    await db.execute(
      'CREATE INDEX idx_embeddings_user_id ON $kEmbeddingsTable (user_id)',
    );
    await db.execute(
      'CREATE INDEX idx_embeddings_pose ON $kEmbeddingsTable (pose)',
    );
    // Prevents duplicate pose records for the same user.
    await db.execute('''
      CREATE UNIQUE INDEX idx_user_pose
      ON $kEmbeddingsTable (user_id, pose)
    ''');
    await db.execute(
      'CREATE INDEX idx_logs_user_id ON $kVerificationLogsTable (user_id)',
    );
    await db.execute(
      'CREATE INDEX idx_logs_timestamp ON $kVerificationLogsTable (timestamp)',
    );
  }

  // ============================================================
  // USER CRUD
  // ============================================================

  /// Insert a new user. Throws if user_id already exists.
  Future<void> insertUser(UserModel user) async {
    kDebugLog('EmbeddingDb: insertUser ${user.userId}');
    final db = await database;
    await db.insert(
      kUsersTable,
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// Insert or replace a user (upsert).
  Future<void> upsertUser(UserModel user) async {
    kDebugLog('EmbeddingDb: upsertUser ${user.userId}');
    final db = await database;
    await db.insert(
      kUsersTable,
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<UserModel?> getUser(String userId) async {
    final db = await database;
    final result = await db.query(
      kUsersTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return UserModel.fromMap(result.first);
  }

  Future<String?> getUserName(String userId) async {
    final user = await getUser(userId);
    return user?.userName;
  }

  Future<List<UserModel>> getAllUsers() async {
    kDebugLog('EmbeddingDb: getAllUsers');
    final db = await database;
    final result = await db.query(kUsersTable, orderBy: 'created_at DESC');
    return result.map((row) => UserModel.fromMap(row)).toList();
  }

  Future<bool> userExists(String userId) async {
    final user = await getUser(userId);
    return user != null;
  }

  Future<int> updateUserName(String userId, String newName) async {
    final db = await database;
    return await db.update(
      kUsersTable,
      {'user_name': newName},
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  // ============================================================
  // EMBEDDING CRUD
  // ============================================================

  Future<int> insertEmbedding(EmbeddingModel embeddingModel) async {
    kDebugLog(
      'EmbeddingDb: insertEmbedding user=${embeddingModel.userId} pose=${embeddingModel.pose}',
    );
    final db = await database;
    return await db.insert(
      kEmbeddingsTable,
      embeddingModel.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert a batch of `EmbeddingModel` objects within a single transaction.
  Future<void> insertEmbeddingsBatch(List<EmbeddingModel> models) async {
    kDebugLog('EmbeddingDb: insertEmbeddingsBatch count=${models.length}');
    final db = await database;

    await db.transaction((txn) async {
      for (final model in models) {
        await txn.insert(
          kEmbeddingsTable,
          model.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// ------------------------------------------------------------
  /// BATCH TRANSACTION — save all 5 pose embeddings atomically.
  /// Used during registration. If any insert fails, the whole
  /// batch rolls back so a user never ends up with a partial
  /// (e.g. 3 out of 5) set of embeddings.
  /// ------------------------------------------------------------
  Future<void> saveRegistrationBatch({
    required String userId,
    required String userName,
    required Map<String, List<double>> poseEmbeddings, // pose -> embedding
    Map<String, double>? poseBrightness, // optional: pose -> brightness
    Map<String, double>? poseSharpness, // optional: pose -> sharpness
    String? captureDevice, // optional: device model/identifier
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      // Upsert the user record first
      await txn.insert(kUsersTable, {
        'user_id': userId,
        'user_name': userName,
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Remove any previous embeddings for this user so re-registration
      // doesn't leave stale poses behind.
      await txn.delete(
        kEmbeddingsTable,
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      // Insert all 5 pose embeddings within the same transaction
      for (final entry in poseEmbeddings.entries) {
        final pose = entry.key;
        final embedding = entry.value;

        await txn.insert(kEmbeddingsTable, {
          'user_id': userId,
          'pose': pose,
          'embedding': jsonEncode(embedding),
          'created_at': now,
          'brightness': poseBrightness?[pose],
          'sharpness': poseSharpness?[pose],
          'capture_device': captureDevice,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  /// Fetch all stored embeddings for a user, keyed by pose.
  Future<Map<String, List<double>>> getEmbeddingsForUser(String userId) async {
    final db = await database;
    final rows = await db.query(
      kEmbeddingsTable,
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    final Map<String, List<double>> result = {};
    for (final row in rows) {
      final pose = row['pose'] as String;
      final embeddingJson = row['embedding'] as String;
      final embedding = (jsonDecode(embeddingJson) as List)
          .map((e) => (e as num).toDouble())
          .toList();
      result[pose] = embedding;
    }
    return result;
  }

  /// Fetch all stored embeddings for a user as full EmbeddingModel
  /// objects (rather than just raw vectors). Preferred for the
  /// similarity engine, since it also carries pose, id, and timestamp.
  Future<List<EmbeddingModel>> getEmbeddingModels(String userId) async {
    kDebugLog('EmbeddingDb: getEmbeddingModels for user=$userId');
    final db = await database;
    final rows = await db.query(
      kEmbeddingsTable,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return rows.map((row) => EmbeddingModel.fromMap(row)).toList();
  }

  /// Fetch a single pose embedding for a user (e.g. just 'front').
  Future<List<double>?> getEmbeddingForPose(String userId, String pose) async {
    final db = await database;
    final rows = await db.query(
      kEmbeddingsTable,
      where: 'user_id = ? AND pose = ?',
      whereArgs: [userId, pose],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final embeddingJson = rows.first['embedding'] as String;
    return (jsonDecode(embeddingJson) as List)
        .map((e) => (e as num).toDouble())
        .toList();
  }

  /// Fetch embeddings for ALL users, grouped by user_id.
  /// Useful for a 1:N identification scan (vs 1:1 verification).
  Future<Map<String, Map<String, List<double>>>> getAllUsersEmbeddings() async {
    final db = await database;
    final rows = await db.query(kEmbeddingsTable);

    final Map<String, Map<String, List<double>>> result = {};
    for (final row in rows) {
      final userId = row['user_id'] as String;
      final pose = row['pose'] as String;
      final embeddingJson = row['embedding'] as String;
      final embedding = (jsonDecode(embeddingJson) as List)
          .map((e) => (e as num).toDouble())
          .toList();

      result.putIfAbsent(userId, () => {});
      result[userId]![pose] = embedding;
    }
    return result;
  }

  /// Update a single pose embedding (e.g. re-capture just "left" pose
  /// without redoing the full registration).
  Future<int> updateEmbedding({
    required String userId,
    required String pose,
    required List<double> newEmbedding,
  }) async {
    final db = await database;
    return await db.update(
      kEmbeddingsTable,
      {
        'embedding': jsonEncode(newEmbedding),
        'created_at': DateTime.now().toIso8601String(),
      },
      where: 'user_id = ? AND pose = ?',
      whereArgs: [userId, pose],
    );
  }

  /// Delete a single pose embedding for a user.
  Future<int> deleteEmbedding(String userId, String pose) async {
    final db = await database;
    return await db.delete(
      kEmbeddingsTable,
      where: 'user_id = ? AND pose = ?',
      whereArgs: [userId, pose],
    );
  }

  /// Delete ALL embeddings for a user (keeps the user record itself).
  Future<int> deleteAllEmbeddingsForUser(String userId) async {
    final db = await database;
    return await db.delete(
      kEmbeddingsTable,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  /// Check whether a user has a complete 5-pose registration.
  Future<bool> hasCompleteRegistration(String userId) async {
    final embeddings = await getEmbeddingsForUser(userId);
    return kRequiredPoses.every((pose) => embeddings.containsKey(pose));
  }

  // ============================================================
  // VERIFICATION LOGS CRUD
  // ============================================================

  Future<int> logVerification({
    required String? userId,
    required double confidenceScore,
    required bool matched,
    required AggregationStrategy aggregationStrategy,
  }) async {
    final db = await database;
    return await db.insert(kVerificationLogsTable, {
      'user_id': userId,
      'confidence_score': confidenceScore,
      'matched': matched ? 1 : 0,
      'aggregation_strategy': aggregationStrategy.name,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getLogsForUser(String userId) async {
    final db = await database;
    return await db.query(
      kVerificationLogsTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getRecentLogs({int limit = 50}) async {
    final db = await database;
    return await db.query(
      kVerificationLogsTable,
      orderBy: 'timestamp DESC',
      limit: limit,
    );
  }

  // ----------------------------------------------------------
  // STATISTICS — useful for tuning kMatchThreshold after testing
  // ----------------------------------------------------------

  /// Returns overall match rate (0.0 - 1.0) across all logged attempts.
  Future<double> getOverallMatchRate() async {
    final db = await database;
    final total = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $kVerificationLogsTable'),
    );
    if (total == null || total == 0) return 0.0;

    final matched = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM $kVerificationLogsTable WHERE matched = 1',
      ),
    );
    return (matched ?? 0) / total;
  }

  /// Returns average confidence score across all logged attempts.
  Future<double> getAverageConfidence() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT AVG(confidence_score) as avg_score FROM $kVerificationLogsTable',
    );
    final avg = result.first['avg_score'];
    return avg == null ? 0.0 : (avg as num).toDouble();
  }

  /// Returns min/max confidence for matched vs unmatched attempts —
  /// useful for visualizing where the threshold should sit.
  Future<Map<String, double?>> getConfidenceStats() async {
    final db = await database;

    final matchedStats = await db.rawQuery('''
      SELECT MIN(confidence_score) as min_score,
             MAX(confidence_score) as max_score,
             AVG(confidence_score) as avg_score
      FROM $kVerificationLogsTable WHERE matched = 1
    ''');

    final unmatchedStats = await db.rawQuery('''
      SELECT MIN(confidence_score) as min_score,
             MAX(confidence_score) as max_score,
             AVG(confidence_score) as avg_score
      FROM $kVerificationLogsTable WHERE matched = 0
    ''');

    double? asDouble(dynamic v) => v == null ? null : (v as num).toDouble();

    return {
      'matched_min': asDouble(matchedStats.first['min_score']),
      'matched_max': asDouble(matchedStats.first['max_score']),
      'matched_avg': asDouble(matchedStats.first['avg_score']),
      'unmatched_min': asDouble(unmatchedStats.first['min_score']),
      'unmatched_max': asDouble(unmatchedStats.first['max_score']),
      'unmatched_avg': asDouble(unmatchedStats.first['avg_score']),
    };
  }

  Future<int> getTotalUserCount() async {
    final db = await database;
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $kUsersTable'),
        ) ??
        0;
  }

  /// Returns the total number of logged verification attempts
  /// (matched + unmatched). Useful for analytics and threshold tuning.
  Future<int> getTotalVerificationCount() async {
    final db = await database;
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $kVerificationLogsTable'),
        ) ??
        0;
  }

  /// Returns just the user_id column for every registered user —
  /// cheaper than fetching full embeddings when the verification
  /// engine only needs to know which IDs exist before fetching
  /// embeddings for a subset.
  Future<List<String>> getRegisteredUserIds() async {
    kDebugLog('EmbeddingDb: getRegisteredUserIds');
    final db = await database;
    final rows = await db.query(kUsersTable, columns: ['user_id']);
    return rows.map((row) => row['user_id'] as String).toList();
  }

  // ============================================================
  // DELETE USER + CASCADE CLEANUP
  // ============================================================

  /// Deletes a user and all associated embeddings + logs.
  /// Relies on ON DELETE CASCADE / SET NULL foreign keys, but also
  /// runs explicit deletes inside a transaction as a safety net in
  /// case foreign_keys pragma isn't enabled on some platforms.
  Future<void> deleteUserCascade(String userId) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete(
        kEmbeddingsTable,
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      await txn.delete(
        kVerificationLogsTable,
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      await txn.delete(kUsersTable, where: 'user_id = ?', whereArgs: [userId]);
    });
  }

  // ============================================================
  // DATABASE MAINTENANCE
  // ============================================================

  /// Deletes verification logs older than [days] days, to keep the
  /// local database from growing unbounded over time.
  Future<int> pruneOldLogs({int days = 90}) async {
    final db = await database;
    final cutoff = DateTime.now()
        .subtract(Duration(days: days))
        .toIso8601String();
    return await db.delete(
      kVerificationLogsTable,
      where: 'timestamp < ?',
      whereArgs: [cutoff],
    );
  }

  /// Wipes ALL data from every table (users, embeddings, logs).
  /// Use with caution — intended for debug/reset flows only.
  Future<void> resetDatabase() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(kVerificationLogsTable);
      await txn.delete(kEmbeddingsTable);
      await txn.delete(kUsersTable);
    });
  }

  /// Runs SQLite VACUUM to reclaim disk space after large deletes.
  Future<void> vacuum() async {
    final db = await database;
    await db.execute('VACUUM');
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  /// Converts a stored JSON string back into `List<double>`.
  List<double> decodeEmbedding(String embeddingJson) {
    return (jsonDecode(embeddingJson) as List)
        .map((e) => (e as num).toDouble())
        .toList();
  }

  /// Converts a `List<double>` into a JSON string for storage.
  String encodeEmbedding(List<double> embedding) {
    return jsonEncode(embedding);
  }

  // ============================================================
  // CLOSE DATABASE
  // ============================================================

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
