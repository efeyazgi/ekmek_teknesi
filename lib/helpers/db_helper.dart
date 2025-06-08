import 'package:sqflite/sqflite.dart' as sql;
import 'package:path/path.dart' as path;
import 'dart:async';

class DBHelper {
  static const String _dbName = 'ekmek_teknemiz.db';
  static const int _dbVersion = 2;
  static sql.Database? _database;

  static Future<sql.Database> _getDatabaseInstance() async {
    final dbPath = await sql.getDatabasesPath();
    final fullPath = path.join(dbPath, _dbName);
    return await sql.openDatabase(
      fullPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        final batch = db.batch();
        batch.execute(
            'CREATE TABLE siparisler(id TEXT PRIMARY KEY, musteriId TEXT, musteriAdi TEXT, ekmekAdedi INTEGER, teslimTarihi TEXT, odemeAlindiMi INTEGER, durum TEXT, satilanEkmekTuru TEXT, notlar TEXT)');
        batch.execute(
            'CREATE TABLE uretim_kayitlari(id TEXT PRIMARY KEY, tarih TEXT, adet INTEGER)');
        batch.execute(
            'CREATE TABLE giderler(id TEXT PRIMARY KEY, tarih TEXT, giderTuru TEXT, aciklama TEXT, tutar REAL)');
        batch.execute(
            'CREATE TABLE musteriler(id TEXT PRIMARY KEY, adSoyad TEXT, telefon TEXT, notlar TEXT)');
        await batch.commit();
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE siparisler ADD COLUMN durum TEXT');
          await db.execute(
              'ALTER TABLE siparisler ADD COLUMN satilanEkmekTuru TEXT');
        }
      },
    );
  }

  static Future<sql.Database> get database async {
    return _database ??= await _getDatabaseInstance();
  }

  static Future<void> insert(String table, Map<String, Object?> data) async {
    final db = await DBHelper.database;
    await db.insert(table, data,
        conflictAlgorithm: sql.ConflictAlgorithm.replace);
  }

  static Future<int> update(
      String table, String id, Map<String, Object?> data) async {
    final db = await DBHelper.database;
    return await db.update(table, data, where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> delete(String table, String id) async {
    final db = await DBHelper.database;
    return await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<Map<String, dynamic>>> getData(String table) async {
    final db = await DBHelper.database;
    return db.query(table);
  }

  static Future<String> getDatabasePath() async {
    final dbPath = await sql.getDatabasesPath();
    return path.join(dbPath, _dbName);
  }

  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
