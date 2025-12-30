import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/home_state.dart';

class SqliteCacheService {
  static const _dbName = 'smartmaison.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> _getDb() async {
    if (_db != null) return _db!;

    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, _dbName);

    _db = await openDatabase(
      fullPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE home_state (
            k TEXT PRIMARY KEY,
            json TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            text TEXT NOT NULL,
            ts INTEGER NOT NULL
          )
        ''');
      },
    );

    return _db!;
  }

  // =========================
  // HOME STATE (JSON)
  // =========================
  Future<void> saveHomeState(HomeState state) async {
    final db = await _getDb();
    final jsonStr = jsonEncode(state.toJson());

    await db.insert(
      'home_state',
      {'k': 'home', 'json': jsonStr},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<HomeState?> loadHomeState() async {
    final db = await _getDb();
    final rows = await db.query(
      'home_state',
      where: 'k = ?',
      whereArgs: const ['home'],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final jsonStr = rows.first['json'] as String;
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return HomeState.fromJson(map);
  }

  Future<void> clearHomeState() async {
    final db = await _getDb();
    await db.delete('home_state', where: 'k = ?', whereArgs: const ['home']);
  }

  // =========================
  // LOGS (HISTORY)
  // =========================
  Future<void> saveLogLine(String text) async {
    final db = await _getDb();
    await db.insert(
      'logs',
      {
        'text': text,
        'ts': DateTime.now().millisecondsSinceEpoch,
      },
    );

    // Optionnel: garder seulement 200 lignes max en DB
    // (le Dashboard lit seulement 30 de toute façon)
    await db.execute('''
      DELETE FROM logs
      WHERE id NOT IN (
        SELECT id FROM logs ORDER BY ts DESC LIMIT 200
      )
    ''');
  }

  Future<List<String>> loadLogs({int limit = 30}) async {
    final db = await _getDb();
    final rows = await db.query(
      'logs',
      orderBy: 'ts DESC',
      limit: limit,
    );

    return rows.map((e) => e['text'] as String).toList();
  }

  Future<void> clearLogs() async {
    final db = await _getDb();
    await db.delete('logs');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
