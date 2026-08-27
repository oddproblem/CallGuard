import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../models/call_history_entry.dart';
import '../models/classification_entry.dart';

/// Singleton SQLite database manager for call history and classification logs.
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._();
  factory DatabaseService() => _instance;
  DatabaseService._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/callguard.db';

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE call_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            remoteId TEXT NOT NULL,
            savedName TEXT,
            isIncoming INTEGER NOT NULL,
            startTime TEXT NOT NULL,
            endTime TEXT,
            durationSeconds INTEGER NOT NULL,
            status TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE classification_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            inputType TEXT NOT NULL,
            fileName TEXT,
            transcript TEXT NOT NULL,
            matchedKeywords TEXT NOT NULL,
            unmatchedWords TEXT NOT NULL,
            confidenceScore REAL NOT NULL,
            verdict TEXT NOT NULL
          )
        ''');

        debugPrint('[DB] Tables created');
      },
    );
  }

  // ── Call History ──

  Future<int> insertCallHistory(CallHistoryEntry entry) async {
    final db = await database;
    return db.insert('call_history', entry.toMap());
  }

  Future<List<CallHistoryEntry>> getAllCallHistory() async {
    final db = await database;
    final maps = await db.query(
      'call_history',
      orderBy: 'startTime DESC',
    );
    return maps.map((m) => CallHistoryEntry.fromMap(m)).toList();
  }

  Future<int> updateSavedName(String remoteId, String name) async {
    final db = await database;
    return db.update(
      'call_history',
      {'savedName': name},
      where: 'remoteId = ?',
      whereArgs: [remoteId],
    );
  }

  Future<int> deleteCallHistory(int id) async {
    final db = await database;
    return db.delete('call_history', where: 'id = ?', whereArgs: [id]);
  }

  // ── Classification History ──

  Future<int> insertClassification(ClassificationEntry entry) async {
    final db = await database;
    return db.insert('classification_history', entry.toMap());
  }

  Future<List<ClassificationEntry>> getAllClassifications() async {
    final db = await database;
    final maps = await db.query(
      'classification_history',
      orderBy: 'timestamp DESC',
    );
    return maps.map((m) => ClassificationEntry.fromMap(m)).toList();
  }

  Future<int> deleteClassification(int id) async {
    final db = await database;
    return db.delete('classification_history', where: 'id = ?', whereArgs: [id]);
  }
}
