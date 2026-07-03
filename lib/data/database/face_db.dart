import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/registered_faces.dart';

class FaceDB {
  static Database? _db;

  /// =========================
  /// INIT DATABASE
  /// =========================
  static Future<void> init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'faces.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE,
            imagePath TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE embeddings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER,
            vector TEXT
          )
        ''');
      },
    );
  }

  /// =========================
  /// INSERT SINGLE FACE
  /// =========================
  static Future<int> insertFace({
    required String name,
    required String imagePath,
    required List<double> embedding,
  }) async {
    final db = _db!;

    int userId;

    final existing = await db.query(
      'users',
      where: 'name = ?',
      whereArgs: [name],
    );

    if (existing.isNotEmpty) {
      userId = existing.first['id'] as int;
    } else {
      userId = await db.insert('users', {'name': name, 'imagePath': imagePath});
    }

    await db.insert('embeddings', {
      'user_id': userId,
      'vector': jsonEncode(embedding),
    });

    return userId;
  }

  /// =========================
  /// INSERT MULTIPLE EMBEDDINGS (BEST FOR ACCURACY)
  /// =========================
  static Future<void> insertFaceBatch({
    required String name,
    required String imagePath,
    required List<List<double>> embeddings,
  }) async {
    final db = _db!;

    int userId;

    final existing = await db.query(
      'users',
      where: 'name = ?',
      whereArgs: [name],
    );

    if (existing.isNotEmpty) {
      userId = existing.first['id'] as int;
    } else {
      userId = await db.insert('users', {'name': name, 'imagePath': imagePath});
    }

    final batch = db.batch();

    for (final emb in embeddings) {
      batch.insert('embeddings', {
        'user_id': userId,
        'vector': jsonEncode(emb),
      });
    }

    await batch.commit(noResult: true);
  }

  /// =========================
  /// GET ALL FACES (FOR RECOGNITION)
  /// =========================
  static Future<List<RegisteredFace>> getAllFaces() async {
    final db = _db!;

    final users = await db.query('users');

    List<RegisteredFace> result = [];

    for (final user in users) {
      final embeddings = await db.query(
        'embeddings',
        where: 'user_id = ?',
        whereArgs: [user['id']],
      );

      List<List<double>> vectors = embeddings.map((e) {
        final List raw = jsonDecode(e['vector'] as String);
        return raw.map((v) => (v as num).toDouble()).toList();
      }).toList();

      result.add(
        RegisteredFace(
          name: user['name'] as String,
          imagePath: user['imagePath'] as String? ?? '',
          embeddings: vectors,
        ),
      );
    }

    return result;
  }

  /// =========================
  /// DELETE USER
  /// =========================
  static Future<void> deleteUser(int userId) async {
    final db = _db!;

    await db.delete('embeddings', where: 'user_id = ?', whereArgs: [userId]);

    await db.delete('users', where: 'id = ?', whereArgs: [userId]);
  }

  /// =========================
  /// CLEAR DATABASE
  /// =========================
  static Future<void> clearAll() async {
    final db = _db!;

    await db.delete('embeddings');
    await db.delete('users');
  }
}
