import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/supabase_config.dart';
import '../models/pos_transaction_model.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';
import 'pos_database.dart';

/// Immediate-sync pipeline manager for POS transactions.
/// Flushes local SQLite FIFO sync queue to Supabase, coordinates stock updates,
/// handles network retries, and keeps terminal UI responsive.
class SyncService {
  SyncService._internal();
  static final SyncService instance = SyncService._internal();

  bool _isFlushing = false;

  SupabaseClient? get _supabase {
    try {
      if (AuthService.instance.isSupabaseReady) {
        return Supabase.instance.client;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Hook to override remote push handler in tests
  @visibleForTesting
  Future<bool> Function(Map<String, dynamic> queueItem)? testPushHandler;

  /// Initializes the sync engine and binds it to ConnectivityService auto-flush
  void initialize() {
    ConnectivityService.instance.registerSyncEngine(flushPendingQueue);
  }

  /// Core cashier mutation trigger pattern:
  /// 1. Atomically writes to local SQLite (source of truth) and enqueues mutation.
  /// 2. If terminal is currently online, launches immediate non-blocking background queue flush.
  Future<PosTransactionModel> saveOrderAndPush(PosTransactionModel tx) async {
    // 1. Local atomic write
    await PosDatabase.instance.insertTransactionWithQueue(tx);
    await ConnectivityService.instance.refreshPendingCount();

    // 2. Immediate push attempt (non-blocking background dispatch)
    if (ConnectivityService.instance.isOnline) {
      unawaited(flushPendingQueue());
    }

    return tx;
  }

  /// Flushes all pending mutations in the local SQLite queue to Supabase in FIFO order.
  Future<void> flushPendingQueue() async {
    if (_isFlushing) {
      debugPrint('SyncService: Flush already in progress, skipping concurrent trigger.');
      return;
    }

    _isFlushing = true;
    final connectivity = ConnectivityService.instance;

    try {
      final queueItems = await PosDatabase.instance.getPendingQueue();
      if (queueItems.isEmpty) {
        connectivity.setSyncState(SyncState.idle);
        await connectivity.refreshPendingCount();
        _isFlushing = false;
        return;
      }

      connectivity.setSyncState(SyncState.syncing);
      debugPrint('SyncService: Starting flush for ${queueItems.length} queued mutations.');

      bool hasFailure = false;
      String? lastFailureReason;

      for (final item in queueItems) {
        final queueId = item['id'] as int;
        final mutationType = item['mutation_type'] as String;
        final rawPayload = item['payload'] as String;

        await PosDatabase.instance.markQueueItemSyncing(queueId);

        try {
          final success = await _dispatchMutation(mutationType, rawPayload, item);
          if (success) {
            await PosDatabase.instance.deleteQueueItem(queueId);
            debugPrint('SyncService: Successfully synced queue item #$queueId ($mutationType)');
          } else {
            hasFailure = true;
            lastFailureReason = 'Sync rejected by remote server';
            await PosDatabase.instance.markQueueItemFailed(queueId, lastFailureReason);
          }
        } catch (e) {
          hasFailure = true;
          lastFailureReason = e.toString();
          debugPrint('SyncService: Error syncing queue item #$queueId: $e');
          await PosDatabase.instance.markQueueItemFailed(queueId, lastFailureReason);
        }
      }

      await connectivity.refreshPendingCount();

      if (hasFailure) {
        connectivity.setSyncState(SyncState.error, error: lastFailureReason);
      } else {
        connectivity.setSyncState(SyncState.idle);
      }
    } catch (globalErr) {
      debugPrint('SyncService.flushPendingQueue fatal error: $globalErr');
      connectivity.setSyncState(SyncState.error, error: globalErr.toString());
    } finally {
      _isFlushing = false;
    }
  }

  /// Dispatches a single mutation to Supabase or testing mock
  Future<bool> _dispatchMutation(
    String mutationType,
    String rawPayload,
    Map<String, dynamic> queueItem,
  ) async {
    if (testPushHandler != null) {
      return await testPushHandler!(queueItem);
    }

    if (SupabaseConfig.enforceReadOnlyBackend) {
      debugPrint('SyncService: Read-only backend enforced. Skipping remote mutation push.');
      return true;
    }

    final client = _supabase;
    if (client == null) {
      // Supabase is not active/configured; keep in queue or consider offline
      debugPrint('SyncService: Supabase unconfigured or offline.');
      return false;
    }

    final payload = jsonDecode(rawPayload) as Map<String, dynamic>;

    switch (mutationType) {
      case 'CREATE_TRANSACTION':
        return await _syncCreateTransaction(client, payload);
      default:
        debugPrint('SyncService: Unknown mutation type: $mutationType');
        return true; // Dismiss unknown mutation to avoid queue stalling
    }
  }

  /// Syncs transaction and line items to Supabase tables
  Future<bool> _syncCreateTransaction(
    SupabaseClient client,
    Map<String, dynamic> payload,
  ) async {
    if (SupabaseConfig.enforceReadOnlyBackend) {
      debugPrint('SyncService: Read-only backend enforced. Skipping remote push to pos_transactions, pos_transaction_items, and pos_products.');
      return true;
    }

    final txData = payload['transaction'] as Map<String, dynamic>;
    final itemsData = (payload['items'] as List<dynamic>?) ?? [];

    // Resolve valid UUID for transaction
    final rawTxId = txData['id'] as String?;
    final txId = isValidUuid(rawTxId) ? rawTxId! : generateUuidV4();

    // Resolve valid UUID for cashier; if demo string or invalid, fallback to authenticated user or null
    final rawCashierId = txData['cashier_id'] as String?;
    final cashierId = isValidUuid(rawCashierId)
        ? rawCashierId
        : (isValidUuid(client.auth.currentUser?.id) ? client.auth.currentUser!.id : null);

    // 1. Upsert transaction record into pos_transactions
    await client.from('pos_transactions').upsert({
      'id': txId,
      'invoice_number': txData['invoice_number'],
      'cashier_id': cashierId,
      'customer_name': txData['customer_name'],
      'customer_tin': txData['customer_tin'],
      'discount_type': txData['discount_type'] ?? 'none',
      'discount_id_number': txData['discount_id_number'],
      'gross_amount': txData['gross_amount'],
      'discount_amount': txData['discount_amount'],
      'vatable_sales': txData['vatable_sales'],
      'vat_amount': txData['vat_amount'],
      'vat_exempt_sales': txData['vat_exempt_sales'],
      'zero_rated_sales': txData['zero_rated_sales'] ?? 0.0,
      'total_amount': txData['total_amount'],
      'payment_method': txData['payment_method'],
      'status': txData['status'] ?? 'completed',
      'created_at': txData['created_at'],
    }, onConflict: 'id');

    // 2. Insert line items & update stock
    for (final rawItem in itemsData) {
      final item = rawItem as Map<String, dynamic>;
      final rawItemId = item['id'] as String?;
      final itemId = isValidUuid(rawItemId) ? rawItemId! : generateUuidV4();
      final rawProdId = item['product_id'] as String?;
      final prodId = isValidUuid(rawProdId) ? rawProdId : null;
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
      final price = (item['price_at_time'] as num?)?.toDouble() ?? 0.0;
      final name = item['product_name'] as String? ?? 'Item';

      try {
        await client.from('pos_transaction_items').upsert({
          'id': itemId,
          'transaction_id': txId,
          if (prodId != null) 'product_id': prodId,
          'product_name': name,
          'quantity': qty,
          'price_at_time': price,
        }, onConflict: 'id');
      } catch (itemErr) {
        debugPrint('SyncService: Line item sync notice: $itemErr');
      }

      // Decrement stock in Supabase pos_products if product exists
      if (prodId != null) {
        try {
          final prodRes = await client
              .from('pos_products')
              .select('stock_level')
              .eq('id', prodId)
              .maybeSingle();

          if (prodRes != null && prodRes['stock_level'] != null) {
            final currentStock = prodRes['stock_level'] as int;
            final updatedStock = (currentStock - qty).clamp(0, 999999);
            await client
                .from('pos_products')
                .update({'stock_level': updatedStock})
                .eq('id', prodId);
          }
        } catch (stockErr) {
          debugPrint('SyncService: Stock update notice: $stockErr');
        }
      }
    }

    return true;
  }
}
