import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import '../models/pos_transaction_model.dart';
import 'pos_database_ffi_stub.dart' if (dart.library.io) 'pos_database_ffi.dart';

/// Local SQLite database interface and implementation for offline POS transactions and sync queue.
/// Supports native SQLite via `sqflite` with FFI on Windows/Linux/macOS,
/// and provides a persistent storage fallback for Web & unit tests.
class PosDatabase {
  PosDatabase._internal();
  static final PosDatabase instance = PosDatabase._internal();

  sqflite.Database? _db;
  bool _isInitialized = false;

  static const String _prefTransactionsKey = 'c_and_j_pos_transactions_cache';
  static const String _prefSyncQueueKey = 'c_and_j_pos_sync_queue_cache';

  // In-memory fallback stores for web / headless test environments
  final List<Map<String, dynamic>> _memTransactions = [];
  final List<Map<String, dynamic>> _memSyncQueue = [];
  int _memQueueSeq = 1;

  bool get isUsingMemoryFallback => _db == null;
  bool get isInitialized => _isInitialized;

  /// Initialize database connection and schemas.
  Future<void> initialize({bool forceMemory = false}) async {
    if (_isInitialized && !forceMemory) return;

    if (forceMemory || kIsWeb) {
      _isInitialized = true;
      _db = null;
      await _loadWebFallbackFromPrefs();
      debugPrint('PosDatabase: Initialized with persistent storage fallback (Web/Test).');
      return;
    }

    try {
      initSqfliteFfi();

      final dbPath = await sqflite.getDatabasesPath();
      final path = '$dbPath/c_and_j_pos.db';

      _db = await sqflite.openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE local_transactions (
              id TEXT PRIMARY KEY,
              invoice_number TEXT NOT NULL,
              cashier_id TEXT NOT NULL,
              customer_name TEXT,
              customer_tin TEXT,
              discount_type TEXT NOT NULL,
              discount_id_number TEXT,
              gross_amount REAL NOT NULL,
              discount_amount REAL NOT NULL,
              vatable_sales REAL NOT NULL,
              vat_amount REAL NOT NULL,
              vat_exempt_sales REAL NOT NULL,
              zero_rated_sales REAL NOT NULL,
              total_amount REAL NOT NULL,
              payment_method TEXT NOT NULL,
              status TEXT NOT NULL,
              created_at TEXT NOT NULL,
              items_json TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE sync_queue (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              mutation_type TEXT NOT NULL,
              payload TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'pending',
              attempts INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL,
              error_message TEXT
            )
          ''');

          await db.execute(
            'CREATE INDEX idx_sync_queue_status_id ON sync_queue (status, id ASC)',
          );
        },
      );
      _isInitialized = true;
      debugPrint('PosDatabase: SQLite opened successfully at $path');
    } catch (e) {
      debugPrint('PosDatabase: Failed to open native SQLite ($e). Falling back to memory storage.');
      _db = null;
      _isInitialized = true;
      await _loadWebFallbackFromPrefs();
    }
  }

  Future<void> _loadWebFallbackFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final txString = prefs.getString(_prefTransactionsKey);
      if (txString != null && txString.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(txString);
        _memTransactions.clear();
        for (final item in decoded) {
          _memTransactions.add(Map<String, dynamic>.from(item as Map));
        }
        debugPrint('PosDatabase: Loaded ${_memTransactions.length} transactions from persistent web cache.');
      }
      final queueString = prefs.getString(_prefSyncQueueKey);
      if (queueString != null && queueString.isNotEmpty) {
        final List<dynamic> decodedQueue = jsonDecode(queueString);
        _memSyncQueue.clear();
        for (final item in decodedQueue) {
          _memSyncQueue.add(Map<String, dynamic>.from(item as Map));
        }
        debugPrint('PosDatabase: Loaded ${_memSyncQueue.length} pending mutations from persistent web cache.');
      }
    } catch (e) {
      debugPrint('PosDatabase: Failed loading web cache prefs: $e');
    }
  }

  Future<void> _saveWebFallbackToPrefs() async {
    if (_db != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefTransactionsKey, jsonEncode(_memTransactions));
      await prefs.setString(_prefSyncQueueKey, jsonEncode(_memSyncQueue));
    } catch (e) {
      debugPrint('PosDatabase: Failed saving web cache prefs: $e');
    }
  }

  /// Atomic transaction: writes order to local store AND enqueues pending sync mutation.
  Future<void> insertTransactionWithQueue(PosTransactionModel tx) async {
    if (!_isInitialized) await initialize();

    final txJson = tx.toJson();
    final itemsJson = jsonEncode(tx.items.map((i) => i.toJson()).toList());
    final nowIso = tx.createdAt.toIso8601String();

    final payloadMap = {
      'transaction': txJson,
      'items': tx.items.map((i) => i.toJson()).toList(),
    };
    final payloadJson = jsonEncode(payloadMap);

    final db = _db;
    if (db != null) {
      await db.transaction((txn) async {
        await txn.insert(
          'local_transactions',
          {
            'id': tx.id,
            'invoice_number': tx.invoiceNumber,
            'cashier_id': tx.cashierId,
            'customer_name': tx.customerName,
            'customer_tin': tx.customerTin,
            'discount_type': tx.discountType,
            'discount_id_number': tx.discountIdNumber,
            'gross_amount': tx.grossAmount,
            'discount_amount': tx.discountAmount,
            'vatable_sales': tx.vatableSales,
            'vat_amount': tx.vatAmount,
            'vat_exempt_sales': tx.vatExemptSales,
            'zero_rated_sales': tx.zeroRatedSales,
            'total_amount': tx.totalAmount,
            'payment_method': tx.paymentMethod,
            'status': tx.status,
            'created_at': nowIso,
            'items_json': itemsJson,
          },
          conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
        );

        await txn.insert(
          'sync_queue',
          {
            'mutation_type': 'CREATE_TRANSACTION',
            'payload': payloadJson,
            'status': 'pending',
            'attempts': 0,
            'created_at': nowIso,
          },
        );
      });
    } else {
      // In-memory fallback
      _memTransactions.removeWhere((t) => t['id'] == tx.id);
      _memTransactions.insert(0, {
        'id': tx.id,
        'invoice_number': tx.invoiceNumber,
        'cashier_id': tx.cashierId,
        'customer_name': tx.customerName,
        'customer_tin': tx.customerTin,
        'discount_type': tx.discountType,
        'discount_id_number': tx.discountIdNumber,
        'gross_amount': tx.grossAmount,
        'discount_amount': tx.discountAmount,
        'vatable_sales': tx.vatableSales,
        'vat_amount': tx.vatAmount,
        'vat_exempt_sales': tx.vatExemptSales,
        'zero_rated_sales': tx.zeroRatedSales,
        'total_amount': tx.totalAmount,
        'payment_method': tx.paymentMethod,
        'status': tx.status,
        'created_at': nowIso,
        'items_json': itemsJson,
      });

      _memSyncQueue.add({
        'id': _memQueueSeq++,
        'mutation_type': 'CREATE_TRANSACTION',
        'payload': payloadJson,
        'status': 'pending',
        'attempts': 0,
        'created_at': nowIso,
        'error_message': null,
      });
      unawaited(_saveWebFallbackToPrefs());
    }
  }

  /// Retrieve pending items from sync queue in FIFO order.
  Future<List<Map<String, dynamic>>> getPendingQueue({int limit = 50}) async {
    if (!_isInitialized) await initialize();

    final db = _db;
    if (db != null) {
      return await db.query(
        'sync_queue',
        where: 'status IN (?, ?)',
        whereArgs: ['pending', 'failed'],
        orderBy: 'id ASC',
        limit: limit,
      );
    } else {
      return _memSyncQueue
          .where((item) => item['status'] == 'pending' || item['status'] == 'failed')
          .take(limit)
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
  }

  /// Mark queue item as in-progress syncing.
  Future<void> markQueueItemSyncing(int queueId) async {
    if (!_isInitialized) await initialize();

    final db = _db;
    if (db != null) {
      await db.update(
        'sync_queue',
        {'status': 'syncing'},
        where: 'id = ?',
        whereArgs: [queueId],
      );
    } else {
      final index = _memSyncQueue.indexWhere((item) => item['id'] == queueId);
      if (index != -1) {
        _memSyncQueue[index]['status'] = 'syncing';
      }
    }
  }

  /// Delete item from queue upon successful sync.
  Future<void> deleteQueueItem(int queueId) async {
    if (!_isInitialized) await initialize();

    final db = _db;
    if (db != null) {
      await db.delete('sync_queue', where: 'id = ?', whereArgs: [queueId]);
    } else {
      _memSyncQueue.removeWhere((item) => item['id'] == queueId);
      unawaited(_saveWebFallbackToPrefs());
    }
  }

  /// Mark item as failed with incremented attempts and error message.
  Future<void> markQueueItemFailed(int queueId, String errorMessage) async {
    if (!_isInitialized) await initialize();

    final db = _db;
    if (db != null) {
      await db.rawUpdate('''
        UPDATE sync_queue
        SET status = 'failed',
            attempts = attempts + 1,
            error_message = ?
        WHERE id = ?
      ''', [errorMessage, queueId]);
    } else {
      final index = _memSyncQueue.indexWhere((item) => item['id'] == queueId);
      if (index != -1) {
        _memSyncQueue[index]['status'] = 'failed';
        _memSyncQueue[index]['attempts'] = (_memSyncQueue[index]['attempts'] as int? ?? 0) + 1;
        _memSyncQueue[index]['error_message'] = errorMessage;
        unawaited(_saveWebFallbackToPrefs());
      }
    }
  }

  /// Mark a local transaction as voided in SQLite / memory store.
  Future<void> voidLocalTransaction({
    required String transactionId,
    required String voidReason,
    String? voidedBy,
  }) async {
    if (!_isInitialized) await initialize();

    final db = _db;
    if (db != null) {
      await db.update(
        'local_transactions',
        {'status': 'voided'},
        where: 'id = ?',
        whereArgs: [transactionId],
      );
    }

    final index = _memTransactions.indexWhere((t) => t['id'] == transactionId);
    if (index != -1) {
      _memTransactions[index]['status'] = 'voided';
      unawaited(_saveWebFallbackToPrefs());
    }
  }

  /// Total count of pending or failed queue items.
  Future<int> getPendingQueueCount() async {
    if (!_isInitialized) await initialize();

    final db = _db;
    if (db != null) {
      final countRes = await db.rawQuery(
        "SELECT COUNT(*) as cnt FROM sync_queue WHERE status IN ('pending', 'failed', 'syncing')",
      );
      return sqflite.Sqflite.firstIntValue(countRes) ?? 0;
    } else {
      return _memSyncQueue
          .where((item) => item['status'] == 'pending' || item['status'] == 'failed' || item['status'] == 'syncing')
          .length;
    }
  }

  /// Cache/upsert transactions directly into local storage without queueing a sync mutation.
  /// Used for syncing historical transactions down from Supabase.
  Future<void> upsertLocalTransactions(List<PosTransactionModel> txList) async {
    if (!_isInitialized) await initialize();
    if (txList.isEmpty) return;

    final db = _db;
    if (db != null) {
      final batch = db.batch();
      for (final tx in txList) {
        final itemsJson = jsonEncode(tx.items.map((i) => i.toJson()).toList());
        batch.insert(
          'local_transactions',
          {
            'id': tx.id,
            'invoice_number': tx.invoiceNumber,
            'cashier_id': tx.cashierId,
            'customer_name': tx.customerName,
            'customer_tin': tx.customerTin,
            'discount_type': tx.discountType,
            'discount_id_number': tx.discountIdNumber,
            'gross_amount': tx.grossAmount,
            'discount_amount': tx.discountAmount,
            'vatable_sales': tx.vatableSales,
            'vat_amount': tx.vatAmount,
            'vat_exempt_sales': tx.vatExemptSales,
            'zero_rated_sales': tx.zeroRatedSales,
            'total_amount': tx.totalAmount,
            'payment_method': tx.paymentMethod,
            'status': tx.status,
            'created_at': tx.createdAt.toUtc().toIso8601String(),
            'items_json': itemsJson,
          },
          conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } else {
      for (final tx in txList) {
        final itemsJson = jsonEncode(tx.items.map((i) => i.toJson()).toList());
        _memTransactions.removeWhere((t) => t['id'] == tx.id);
        _memTransactions.add({
          'id': tx.id,
          'invoice_number': tx.invoiceNumber,
          'cashier_id': tx.cashierId,
          'customer_name': tx.customerName,
          'customer_tin': tx.customerTin,
          'discount_type': tx.discountType,
          'discount_id_number': tx.discountIdNumber,
          'gross_amount': tx.grossAmount,
          'discount_amount': tx.discountAmount,
          'vatable_sales': tx.vatableSales,
          'vat_amount': tx.vatAmount,
          'vat_exempt_sales': tx.vatExemptSales,
          'zero_rated_sales': tx.zeroRatedSales,
          'total_amount': tx.totalAmount,
          'payment_method': tx.paymentMethod,
          'status': tx.status,
          'created_at': tx.createdAt.toUtc().toIso8601String(),
          'items_json': itemsJson,
        });
      }
      unawaited(_saveWebFallbackToPrefs());
    }
  }

  /// Total count of local stored transactions.
  Future<int> getLocalTransactionCount() async {
    if (!_isInitialized) await initialize();
    final db = _db;
    if (db != null) {
      final res = await db.rawQuery('SELECT COUNT(*) as cnt FROM local_transactions');
      return sqflite.Sqflite.firstIntValue(res) ?? 0;
    }
    return _memTransactions.length;
  }

  /// Retrieve locally stored transactions.
  Future<List<PosTransactionModel>> getLocalTransactions({int limit = 50}) async {
    if (!_isInitialized) await initialize();

    final List<Map<String, dynamic>> rows;
    final db = _db;
    if (db != null) {
      rows = await db.query(
        'local_transactions',
        orderBy: 'created_at DESC',
        limit: limit,
      );
    } else {
      rows = _memTransactions.take(limit).toList();
    }

    final result = <PosTransactionModel>[];
    for (final row in rows) {
      try {
        final itemsRaw = jsonDecode(row['items_json'] as String) as List<dynamic>;
        final items = itemsRaw
            .map((i) => PosTransactionItemModel.fromJson(i as Map<String, dynamic>))
            .toList();

        result.add(PosTransactionModel(
          id: row['id'] as String,
          invoiceNumber: row['invoice_number'] as String,
          cashierId: row['cashier_id'] as String,
          customerName: row['customer_name'] as String?,
          customerTin: row['customer_tin'] as String?,
          discountType: row['discount_type'] as String,
          discountIdNumber: row['discount_id_number'] as String?,
          grossAmount: (row['gross_amount'] as num).toDouble(),
          discountAmount: (row['discount_amount'] as num).toDouble(),
          vatableSales: (row['vatable_sales'] as num).toDouble(),
          vatAmount: (row['vat_amount'] as num).toDouble(),
          vatExemptSales: (row['vat_exempt_sales'] as num).toDouble(),
          zeroRatedSales: (row['zero_rated_sales'] as num).toDouble(),
          totalAmount: (row['total_amount'] as num).toDouble(),
          paymentMethod: row['payment_method'] as String,
          status: row['status'] as String,
          createdAt: DateTime.tryParse(row['created_at'] as String) ?? DateTime.now(),
          items: items,
        ));
      } catch (e) {
        debugPrint('PosDatabase.getLocalTransactions row decode notice: $e');
      }
    }
    return result;
  }

  /// Clear all local transactions and queue records (used for test teardown).
  Future<void> clearAll() async {
    final db = _db;
    if (db != null) {
      await db.delete('sync_queue');
      await db.delete('local_transactions');
    }
    _memTransactions.clear();
    _memSyncQueue.clear();
    _memQueueSeq = 1;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefTransactionsKey);
      await prefs.remove(_prefSyncQueueKey);
    } catch (_) {}
  }
}
