import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/server.dart';

class ServerDatabase {
  ServerDatabase._();

  static final ServerDatabase instance = ServerDatabase._();

  static const _databaseName = 'server_manager.db';
  static const _databaseVersion = 4;
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
      onUpgrade: _upgradeDatabase,
      onOpen: _ensureDatabaseSchema,
    );
    _database = database;
    return database;
  }

  Future<void> _createDatabase(Database database, int version) async {
    await database.execute('''
      CREATE TABLE $serversTable (
        id TEXT PRIMARY KEY,
        parent_id TEXT,
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
        client_phone TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL,
        notes TEXT NOT NULL,
        vm_cpu_cores INTEGER,
        vm_memory_gb REAL,
        vm_disk_gb REAL,
        vm_storage TEXT,
        vm_role TEXT
      )
    ''');

    await database.execute(
      'CREATE INDEX idx_servers_renewal_date ON $serversTable (renewal_date)',
    );
    await database.execute(
      'CREATE INDEX idx_servers_parent_id ON $serversTable (parent_id)',
    );
    await database.execute(
      'CREATE INDEX idx_servers_assigned_client ON $serversTable (assigned_client)',
    );
  }

  Future<void> _upgradeDatabase(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    await _ensureDatabaseSchema(database);
  }

  Future<void> _ensureDatabaseSchema(Database database) async {
    if (kIsWeb) {
      return;
    }

    final columns = await _columnNames(database);
    if (!columns.contains('parent_id')) {
      await database.execute('ALTER TABLE $serversTable ADD COLUMN parent_id TEXT');
    }
    if (!columns.contains('vm_cpu_cores')) {
      await database.execute('ALTER TABLE $serversTable ADD COLUMN vm_cpu_cores INTEGER');
    }
    if (!columns.contains('vm_memory_gb')) {
      await database.execute('ALTER TABLE $serversTable ADD COLUMN vm_memory_gb REAL');
    }
    if (!columns.contains('vm_disk_gb')) {
      await database.execute('ALTER TABLE $serversTable ADD COLUMN vm_disk_gb REAL');
    }
    if (!columns.contains('vm_storage')) {
      await database.execute('ALTER TABLE $serversTable ADD COLUMN vm_storage TEXT');
    }
    if (!columns.contains('vm_role')) {
      await database.execute('ALTER TABLE $serversTable ADD COLUMN vm_role TEXT');
    }
    if (!columns.contains('client_phone')) {
      await database.execute(
        "ALTER TABLE $serversTable ADD COLUMN client_phone TEXT NOT NULL DEFAULT ''",
      );
    }

    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_servers_renewal_date ON $serversTable (renewal_date)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_servers_parent_id ON $serversTable (parent_id)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_servers_assigned_client ON $serversTable (assigned_client)',
    );
  }

  Future<Set<String>> _columnNames(Database database) async {
    final rows = await database.rawQuery('PRAGMA table_info($serversTable)');
    return rows.map((row) => row['name'].toString()).toSet();
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
      where: 'id = ? OR parent_id = ?',
      whereArgs: [id, id],
    );
  }

  Future<void> deleteServerOnly(String id) async {
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
