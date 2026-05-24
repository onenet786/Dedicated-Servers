import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/server.dart';

class ServerDatabase {
  ServerDatabase._();

  static final ServerDatabase instance = ServerDatabase._();

  static const _databaseName = 'server_manager.db';
  static const _databaseVersion = 1;
  static const serversTable = 'servers';

  Database? _database;

  Future<Database> get database async {
    final existingDatabase = _database;
    if (existingDatabase != null) {
      return existingDatabase;
    }

    final databasePath = await getDatabasesPath();
    final database = await openDatabase(
      path.join(databasePath, _databaseName),
      version: _databaseVersion,
      onCreate: _createDatabase,
    );
    _database = database;
    return database;
  }

  Future<void> _createDatabase(Database database, int version) async {
    await database.execute('''
      CREATE TABLE $serversTable (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        ip_address TEXT NOT NULL,
        provider TEXT NOT NULL,
        location TEXT NOT NULL,
        specification TEXT NOT NULL,
        operating_system TEXT NOT NULL,
        login_user TEXT NOT NULL,
        monthly_cost REAL NOT NULL,
        purchase_date TEXT NOT NULL,
        renewal_date TEXT NOT NULL,
        assigned_client TEXT NOT NULL,
        status TEXT NOT NULL,
        notes TEXT NOT NULL
      )
    ''');

    await database.execute(
      'CREATE INDEX idx_servers_renewal_date ON $serversTable (renewal_date)',
    );
    await database.execute(
      'CREATE INDEX idx_servers_assigned_client ON $serversTable (assigned_client)',
    );
  }

  Future<List<ManagedServer>> fetchServers() async {
    if (kIsWeb) {
      return [];
    }

    final db = await database;
    final rows = await db.query(serversTable, orderBy: 'renewal_date ASC');
    return rows.map(ManagedServer.fromMap).toList();
  }

  Future<void> insertServer(ManagedServer server) async {
    if (kIsWeb) {
      return;
    }

    final db = await database;
    await db.insert(
      serversTable,
      server.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> replaceServers(List<ManagedServer> servers) async {
    if (kIsWeb) {
      return;
    }

    final db = await database;
    await db.transaction((transaction) async {
      await transaction.delete(serversTable);
      for (final server in servers) {
        await transaction.insert(
          serversTable,
          server.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> updateServer(ManagedServer server) async {
    if (kIsWeb) {
      return;
    }

    final db = await database;
    await db.update(
      serversTable,
      server.toMap(),
      where: 'id = ?',
      whereArgs: [server.id],
    );
  }

  Future<void> deleteServer(String id) async {
    if (kIsWeb) {
      return;
    }

    final db = await database;
    await db.delete(
      serversTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
