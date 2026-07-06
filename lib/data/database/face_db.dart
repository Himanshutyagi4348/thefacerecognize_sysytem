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
            imagePath TEXT,
            created_at TEXT,
            embedding_front TEXT,
            embedding_left TEXT,
            embedding_right TEXT,
            embedding_top TEXT,
            embedding_bottom TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE attendance (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER,
            date TEXT,
            time TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE admin (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE,
            password TEXT
          )
        ''');

        await db.insert('admin', {'username': 'admin', 'password': 'admin'});
      },
    );
  }

  /// =========================
  /// VALIDATE ADMIN
  /// =========================
  static Future<bool> validateAdmin({
    required String username,
    required String password,
  }) async {
    final db = _db!;

    final rows = await db.query(
      'admin',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
    );

    return rows.isNotEmpty;
  }

  /// =========================
  /// GET ALL REGISTERED USERS
  /// =========================
  static Future<List<RegisteredFace>> getAllFaces() async {
    final db = _db!;

    final users = await db.query('users');

    return users.map((user) {
      return RegisteredFace.fromMap(user);
    }).toList();
  }

  /// =========================
  /// GET USER BY NAME
  /// =========================
  static Future<RegisteredFace?> getUserByName(String name) async {
    final db = _db!;

    final users = await db.query(
      'users',
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );

    if (users.isEmpty) return null;

    return RegisteredFace.fromMap(users.first);
  }

  /// =========================
  /// GET USER ID BY NAME
  /// =========================
  static Future<int?> getUserIdByName(String name) async {
    final user = await getUserByName(name);
    return user?.id;
  }

  /// =========================
  /// INSERT SINGLE FACE (BACKWARD COMPATIBILITY)
  /// =========================
  static Future<int> insertFace({
    required String name,
    required String imagePath,
    required List<double> embedding,
  }) async {
    if (embedding.isEmpty) {
      throw Exception('Embedding is required');
    }

    final batchEmbeddings = List<List<double>>.filled(
      5,
      embedding,
      growable: false,
    );

    return await insertFaceBatch(
      name: name,
      imagePath: imagePath,
      embeddings: batchEmbeddings,
    );
  }

  /// =========================
  /// INSERT USER WITH 5 EMBEDDINGS
  /// =========================
  static Future<int> insertFaceBatch({
    required String name,
    required String imagePath,
    required List<List<double>> embeddings,
  }) async {
    if (embeddings.length != 5) {
      throw Exception('Exactly 5 embeddings are required');
    }

    final db = _db!;

    final existing = await db.query(
      'users',
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final id = existing.first['id'] as int;

      await db.update(
        'users',
        {
          'imagePath': imagePath,
          'embedding_front': jsonEncode(embeddings[0]),
          'embedding_left': jsonEncode(embeddings[1]),
          'embedding_right': jsonEncode(embeddings[2]),
          'embedding_top': jsonEncode(embeddings[3]),
          'embedding_bottom': jsonEncode(embeddings[4]),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      return id;
    }

    return await db.insert('users', {
      'name': name,
      'imagePath': imagePath,
      'created_at': DateTime.now().toIso8601String(),
      'embedding_front': jsonEncode(embeddings[0]),
      'embedding_left': jsonEncode(embeddings[1]),
      'embedding_right': jsonEncode(embeddings[2]),
      'embedding_top': jsonEncode(embeddings[3]),
      'embedding_bottom': jsonEncode(embeddings[4]),
    });
  }

  /// =========================
  /// ADD ATTENDANCE ENTRY IF NOT ALREADY MARKED TODAY
  /// =========================
  static Future<bool> markAttendance(int userId) async {
    final db = _db!;
    final today = DateTime.now().toIso8601String().split('T').first;

    final existing = await db.query(
      'attendance',
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, today],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      return false;
    }

    await db.insert('attendance', {
      'user_id': userId,
      'date': today,
      'time': DateTime.now().toIso8601String(),
    });

    return true;
  }

  /// =========================
  /// DELETE USER
  /// =========================
  static Future<void> deleteUser(int userId) async {
    final db = _db!;

    await db.delete('attendance', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('users', where: 'id = ?', whereArgs: [userId]);
  }

  /// =========================
  /// CLEAR DATABASE
  /// =========================
  static Future<void> clearAll() async {
    final db = _db!;

    await db.delete('attendance');
    await db.delete('users');
    await db.delete('admin');
  }
}
