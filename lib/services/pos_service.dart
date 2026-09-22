import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/paymongo_config.dart';
import '../core/utils/bir_tax_breakdown.dart';
import '../data/mock_pos_data.dart';
import '../models/daily_expense_model.dart';
import '../models/cashier_duty_session_model.dart';
import '../models/pos_product_model.dart';
import '../models/pos_transaction_model.dart';
import 'auth_service.dart';
import 'booking_service.dart';
import 'pos_database.dart';
import 'sync_service.dart';

class PosService {
  PosService._internal();
  static final PosService instance = PosService._internal();

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

  bool get isSupabaseActive => _supabase != null;

  RealtimeChannel? _posChannel;
  StreamController<void>? _posUpdatesController;
  StreamController<void> get _controller =>
      _posUpdatesController ??= StreamController<void>.broadcast();
  Stream<void> get onPosUpdates => _controller.stream;

  /// Initialize Supabase Realtime channel on pos_transactions and pos_products
  void initRealtimeSubscription() {
    final client = _supabase;
    if (client == null || _posChannel != null) return;

    try {
      _posChannel = client.channel('public:pos_realtime')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'pos_transactions',
          callback: (payload) {
            debugPrint('Realtime: pos_transactions changed (${payload.eventType})');
            _controller.add(null);
          },
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'pos_products',
          callback: (payload) {
            debugPrint('Realtime: pos_products changed (${payload.eventType})');
            _controller.add(null);
          },
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'daily_expenses',
          callback: (payload) {
            debugPrint('Realtime: daily_expenses changed (${payload.eventType})');
            _controller.add(null);
          },
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'cashier_duty_sessions',
          callback: (payload) {
            debugPrint('Realtime: cashier_duty_sessions changed (${payload.eventType})');
            _controller.add(null);
          },
        )
        ..subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('Supabase Realtime pos_realtime channel connected.');
          }
        });
    } catch (e) {
      debugPrint('Error initializing POS Realtime channel: $e');
    }
  }

  void notifyPosUpdates() {
    _controller.add(null);
  }

  /// Fetch all active products
  Future<List<PosProductModel>> fetchProducts() async {
    final client = _supabase;
    if (client == null) {
      return MockPosData.getProducts();
    }

    try {
      final response = await client
          .from('pos_products')
          .select()
          .eq('is_active', true)
          .order('category')
          .order('name');

      final list = (response as List<dynamic>)
          .map((item) => PosProductModel.fromJson(item as Map<String, dynamic>))
          .toList();

      if (list.isEmpty) {
        return MockPosData.getProducts();
      }
      return list;
    } catch (e) {
      debugPrint('PosService.fetchProducts fallback notice: $e');
      return MockPosData.getProducts();
    }
  }

  /// Fetch all inventory products (for table view and stock adjustments)
  Future<List<PosProductModel>> fetchInventoryProducts() async {
    final client = _supabase;
    if (client == null) {
      return MockPosData.getProducts();
    }

    try {
      final response = await client
          .from('pos_products')
          .select()
          .order('category')
          .order('name');

      final list = (response as List<dynamic>)
          .map((item) => PosProductModel.fromJson(item as Map<String, dynamic>))
          .toList();

      if (list.isEmpty) {
        return MockPosData.getProducts();
      }
      return list;
    } catch (e) {
      debugPrint('PosService fetchInventoryProducts fallback notice: $e');
      return MockPosData.getProducts();
    }
  }

  /// Update product stock level in Supabase & local cache
  Future<bool> updateProductStock(String productId, int newStock) async {
    MockPosData.updateProductStock(productId, newStock);
    final client = _supabase;
    if (client == null) {
      notifyPosUpdates();
      return true;
    }

    try {
      await client
          .from('pos_products')
          .update({'stock_level': newStock})
          .eq('id', productId);
      notifyPosUpdates();
      return true;
    } catch (e) {
      debugPrint('PosService updateProductStock error: $e');
      notifyPosUpdates();
      return false;
    }
  }

  /// Fetch daily expenses from Supabase with offline fallback
  Future<List<DailyExpenseModel>> fetchDailyExpenses({DateTime? date}) async {
    final client = _supabase;
    if (client == null) {
      return MockPosData.getDailyExpenses(date: date);
    }

    try {
      var query = client.from('daily_expenses').select();
      if (date != null) {
        final dateStr =
            "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
        query = query.eq('expense_date', dateStr);
      }
      final response = await query
          .order('expense_date', ascending: false)
          .order('created_at', ascending: false);

      final list = (response as List<dynamic>)
          .map((item) => DailyExpenseModel.fromJson(item as Map<String, dynamic>))
          .toList();

      if (list.isEmpty && date == null) {
        return MockPosData.getDailyExpenses();
      }
      return list;
    } catch (e) {
      debugPrint('PosService fetchDailyExpenses fallback notice: $e');
      return MockPosData.getDailyExpenses(date: date);
    }
  }

  /// Record a new daily expense in Supabase
  Future<DailyExpenseModel?> createDailyExpense(DailyExpenseModel expense) async {
    MockPosData.addDailyExpense(expense);
    final client = _supabase;
    if (client == null) {
      notifyPosUpdates();
      return expense;
    }

    try {
      final payload = expense.toJson();
      if (expense.id.isEmpty) {
        payload.remove('id');
      }
      final response = await client
          .from('daily_expenses')
          .insert(payload)
          .select()
          .single();

      final created =
          DailyExpenseModel.fromJson(response);
      notifyPosUpdates();
      return created;
    } catch (e) {
      debugPrint('PosService createDailyExpense error: $e');
      notifyPosUpdates();
      return expense;
    }
  }

  /// Fetch transactions (alias for fetchRecentTransactions with larger limit)
  Future<List<PosTransactionModel>> fetchTransactions({int limit = 500}) async {
    return fetchRecentTransactions(limit: limit);
  }

  /// Fetch cashier duty sessions
  Future<List<CashierDutySessionModel>> fetchDutySessions() async {
    final client = _supabase;
    if (client == null) {
      return MockPosData.getDutySessions();
    }

    try {
      final response = await client
          .from('cashier_duty_sessions')
          .select()
          .order('started_at', ascending: false);

      final list = (response as List<dynamic>)
          .map((item) =>
              CashierDutySessionModel.fromJson(item as Map<String, dynamic>))
          .toList();

      if (list.isEmpty) {
        return MockPosData.getDutySessions();
      }
      return list;
    } catch (e) {
      debugPrint('PosService fetchDutySessions fallback notice: $e');
      return MockPosData.getDutySessions();
    }
  }

  /// Compute Daily Financial Margins (Gross Revenue, COGS, Gross Profit, Operating Expenses, Net Profit)
  Future<Map<String, dynamic>> computeDailyMargins({DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final transactions = await fetchTransactions();
    final products = await fetchInventoryProducts();
    final expenses = await fetchDailyExpenses(date: targetDate);

    // Create a product map for fast cost_price lookup
    final productMap = {for (final p in products) p.id: p};

    // Filter non-voided transactions for the day
    final dayTxs = transactions.where((t) {
      if (t.isVoided) return false;
      return t.createdAt.year == targetDate.year &&
          t.createdAt.month == targetDate.month &&
          t.createdAt.day == targetDate.day;
    }).toList();

    double grossRevenue = 0.0;
    double cogs = 0.0;
    int itemsSold = 0;

    for (final tx in dayTxs) {
      grossRevenue += tx.totalAmount;
      for (final item in tx.items) {
        itemsSold += item.quantity;
        final product = productMap[item.productId];
        final cost = product?.costPrice ?? (item.priceAtTime * 0.5);
        cogs += cost * item.quantity;
      }
    }

    double totalOperatingExpenses = 0.0;
    final expensesByCategory = <String, double>{};
    for (final exp in expenses) {
      totalOperatingExpenses += exp.amount;
      expensesByCategory[exp.category] =
          (expensesByCategory[exp.category] ?? 0.0) + exp.amount;
    }

    final grossProfit = grossRevenue - cogs;
    final grossMarginPercent =
        grossRevenue > 0 ? (grossProfit / grossRevenue) * 100 : 0.0;
    final netProfit = grossProfit - totalOperatingExpenses;
    final netMarginPercent =
        grossRevenue > 0 ? (netProfit / grossRevenue) * 100 : 0.0;

    return {
      'date': targetDate,
      'grossRevenue': grossRevenue,
      'cogs': cogs,
      'grossProfit': grossProfit,
      'grossMarginPercent': grossMarginPercent,
      'totalOperatingExpenses': totalOperatingExpenses,
      'expensesByCategory': expensesByCategory,
      'netProfit': netProfit,
      'netMarginPercent': netMarginPercent,
      'transactionCount': dayTxs.length,
      'itemsSold': itemsSold,
    };
  }

  /// Verify supervisor master PIN against system_settings or fallback
  Future<bool> verifySupervisorPin(String enteredPin) async {
    final cleanPin = enteredPin.trim();
    if (cleanPin.isEmpty) return false;

    final client = _supabase;
    if (client == null) {
      return cleanPin == MockPosData.defaultMasterPin;
    }

    try {
      final response = await client
          .from('system_settings')
          .select('value')
          .eq('key', 'pos_master_pin')
          .maybeSingle();

      if (response != null && response['value'] != null) {
        final dbPin = (response['value'] as String).trim();
        return cleanPin == dbPin;
      }
    } catch (e) {
      debugPrint('PosService.verifySupervisorPin fallback notice: $e');
    }
    return cleanPin == MockPosData.defaultMasterPin;
  }

  /// Generate next sequential invoice number (via RPC or fallback)
  Future<String> generateInvoiceNumber() async {
    final client = _supabase;
    if (client == null) {
      return MockPosData.generateInvoiceNumber();
    }

    try {
      final res = await client.rpc('generate_pos_invoice_number');
      if (res != null && res is String && res.trim().isNotEmpty) {
        return res.trim();
      }
    } catch (e) {
      debugPrint('PosService.generateInvoiceNumber RPC fallback: $e');
    }
    return MockPosData.generateInvoiceNumber();
  }

  /// Create and record a new POS transaction
  Future<PosTransactionModel> createTransaction({
    required String cashierId,
    required String? cashierName,
    required String? customerName,
    required String? customerTin,
    required String discountType,
    required String? discountIdNumber,
    required BirTaxBreakdown taxBreakdown,
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
  }) async {
    final client = _supabase;
    if (client == null) {
      final tx = MockPosData.recordTransaction(
        cashierId: cashierId,
        cashierName: cashierName,
        customerName: customerName,
        customerTin: customerTin,
        discountType: discountType,
        discountIdNumber: discountIdNumber,
        taxBreakdown: taxBreakdown,
        paymentMethod: paymentMethod,
        items: items,
      );
      await SyncService.instance.saveOrderAndPush(tx);
      return tx;
    }

    try {
      final invoiceNum = await generateInvoiceNumber();

      final resolvedCashierId = isValidUuid(cashierId)
          ? cashierId
          : (isValidUuid(client.auth.currentUser?.id) ? client.auth.currentUser!.id : null);

      final txInsert = await client.from('pos_transactions').insert({
        'invoice_number': invoiceNum,
        'cashier_id': resolvedCashierId,
        'customer_name': customerName?.trim().isEmpty ?? true ? null : customerName!.trim(),
        'customer_tin': customerTin?.trim().isEmpty ?? true ? null : customerTin!.trim(),
        'discount_type': discountType,
        'discount_id_number': discountIdNumber?.trim().isEmpty ?? true ? null : discountIdNumber!.trim(),
        'gross_amount': taxBreakdown.grossSubtotal,
        'discount_amount': taxBreakdown.discountAmount,
        'vatable_sales': taxBreakdown.vatableSales,
        'vat_amount': taxBreakdown.vatAmount,
        'vat_exempt_sales': taxBreakdown.vatExemptSales,
        'zero_rated_sales': 0.0,
        'total_amount': taxBreakdown.netPayable,
        'payment_method': paymentMethod,
        'status': 'completed',
      }).select().single();

      final txId = txInsert['id'] as String;

      // Insert line items & decrement stock
      final transactionItems = <PosTransactionItemModel>[];
      for (final item in items) {
        final prodId = item['product_id'] as String;
        final resolvedProdId = isValidUuid(prodId) ? prodId : null;
        final qty = item['quantity'] as int;
        final price = (item['price_at_time'] as num).toDouble();
        final rawName = item['product_name'] as String?;
        final name = (rawName != null && rawName.trim().isNotEmpty) ? rawName.trim() : 'Item';

        Map<String, dynamic>? itemInsert;
        try {
          itemInsert = await client.from('pos_transaction_items').insert({
            'transaction_id': txId,
            if (resolvedProdId != null) 'product_id': resolvedProdId,
            'product_name': name,
            'quantity': qty,
            'price_at_time': price,
          }).select().maybeSingle();
        } catch (itemErr) {
          debugPrint('pos_transaction_items insert notice: $itemErr');
        }

        transactionItems.add(PosTransactionItemModel(
          id: itemInsert?['id'] as String? ?? generateUuidV4(),
          transactionId: txId,
          productId: prodId,
          productName: name,
          quantity: qty,
          priceAtTime: price,
        ));

        // Decrement product stock
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
          debugPrint('Stock decrement error: $stockErr');
        }
      }

      final tx = PosTransactionModel.fromJson(txInsert).copyWith(items: transactionItems);
      // Mirror to local SQLite store for offline viewing and audit
      await PosDatabase.instance.insertTransactionWithQueue(tx);
      // Remove from queue since it already succeeded on Supabase directly
      final pending = await PosDatabase.instance.getPendingQueue(limit: 1);
      if (pending.isNotEmpty && pending.last['mutation_type'] == 'CREATE_TRANSACTION') {
        await PosDatabase.instance.deleteQueueItem(pending.last['id'] as int);
      }
      return tx;
    } catch (e) {
      debugPrint('PosService.createTransaction error fallback to offline SQLite: $e');
      final tx = MockPosData.recordTransaction(
        cashierId: cashierId,
        cashierName: cashierName,
        customerName: customerName,
        customerTin: customerTin,
        discountType: discountType,
        discountIdNumber: discountIdNumber,
        taxBreakdown: taxBreakdown,
        paymentMethod: paymentMethod,
        items: items,
      );
      await SyncService.instance.saveOrderAndPush(tx);
      return tx;
    }
  }

  /// Repository method: atomically records order to local SQLite + sync queue, then triggers push
  Future<PosTransactionModel> saveOrderAndPush(PosTransactionModel tx) async {
    return await SyncService.instance.saveOrderAndPush(tx);
  }

  /// Fetch recent transactions for audit and receipt reprinting.
  /// Automatically fetches past invoices from Supabase and caches them to local SQLite
  /// so transaction history persists across application restarts and reinstalls.
  Future<List<PosTransactionModel>> fetchRecentTransactions({int limit = 50}) async {
    final client = _supabase;
    List<PosTransactionModel> remoteList = [];

    if (client != null) {
      try {
        final response = await client
            .from('pos_transactions')
            .select('*, pos_transaction_items(*)')
            .order('created_at', ascending: false)
            .limit(limit);

        remoteList = (response as List<dynamic>)
            .map((item) => PosTransactionModel.fromJson(item as Map<String, dynamic>))
            .toList();

        if (remoteList.isNotEmpty) {
          await PosDatabase.instance.upsertLocalTransactions(remoteList);
        }
      } catch (e) {
        debugPrint('PosService.fetchRecentTransactions query notice: $e');
      }
    }

    // Check local database (which now has auto-fetched remote transactions + locally created transactions)
    final localList = await PosDatabase.instance.getLocalTransactions(limit: limit);
    if (localList.isNotEmpty) {
      return localList;
    }

    if (remoteList.isNotEmpty) {
      return remoteList;
    }

    return MockPosData.getTransactions();
  }

  /// Void an existing transaction and restore product stock
  Future<bool> voidTransaction({
    required String transactionId,
    required String voidReason,
    required String voidedBy,
  }) async {
    // 1. Immediately reflect in local SQLite and in-memory mock store
    await PosDatabase.instance.voidLocalTransaction(
      transactionId: transactionId,
      voidReason: voidReason,
      voidedBy: voidedBy,
    );
    MockPosData.voidTransaction(
      transactionId: transactionId,
      voidReason: voidReason,
      voidedBy: voidedBy,
    );
    notifyPosUpdates();

    final client = _supabase;
    if (client == null) {
      return true;
    }

    try {
      // 2. Validate UUID format before passing to PostgreSQL UUID column
      final isValidUuid = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(voidedBy);

      // 3. Prefer security-definer RPC for atomic voiding & stock restoration
      try {
        await client.rpc('void_pos_transaction', params: {
          'p_transaction_id': transactionId,
          'p_void_reason': voidReason,
          if (isValidUuid) 'p_voided_by': voidedBy,
        });
      } catch (rpcErr) {
        debugPrint('RPC void_pos_transaction notice: $rpcErr. Falling back to direct update.');
        final updatePayload = <String, dynamic>{
          'status': 'voided',
          'void_reason': voidReason,
          'voided_at': DateTime.now().toUtc().toIso8601String(),
          if (isValidUuid) 'voided_by': voidedBy,
        };

        await client
            .from('pos_transactions')
            .update(updatePayload)
            .eq('id', transactionId);

        // 4. Get transaction items to restore stock in pos_products
        final itemsRes = await client
            .from('pos_transaction_items')
            .select('product_id, quantity')
            .eq('transaction_id', transactionId);

        // 5. Restore stock in pos_products
        for (final item in (itemsRes as List<dynamic>)) {
          final prodId = item['product_id'] as String;
          final qty = item['quantity'] as int;

          final prodRes = await client
              .from('pos_products')
              .select('stock_level')
              .eq('id', prodId)
              .maybeSingle();

          if (prodRes != null && prodRes['stock_level'] != null) {
            final current = prodRes['stock_level'] as int;
            await client
                .from('pos_products')
                .update({'stock_level': current + qty})
                .eq('id', prodId);
          }
        }
      }

      notifyPosUpdates();
      return true;
    } catch (e) {
      debugPrint('PosService.voidTransaction Supabase notice: $e');
      return true;
    }
  }

  /// Create PayMongo Checkout Session for POS active order
  Future<Map<String, dynamic>> createPayMongoCheckoutSession({
    required double totalAmount,
    required List<Map<String, dynamic>> items,
    String? customerName,
    String? customerEmail,
    String? customerPhone,
  }) async {
    final secretKey = PayMongoConfig.secretKey;
    if (secretKey.isEmpty) {
      // Offline / unconfigured fallback: generate simulated checkout session
      final mockId = 'pos_cs_${DateTime.now().millisecondsSinceEpoch}';
      return {
        'sessionId': mockId,
        'checkoutUrl': 'https://checkout.paymongo.com/mock_pos_$mockId',
        'status': 'active',
        'isMock': true,
      };
    }

    final totalCentavos = (totalAmount * 100).round();
    final lineItems = <Map<String, dynamic>>[];

    for (final item in items) {
      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      final qty = (item['quantity'] as int?) ?? 1;
      final name = (item['name'] as String?) ?? 'Item';
      lineItems.add({
        'currency': 'PHP',
        'amount': (price * 100).round(),
        'name': name,
        'quantity': qty,
      });
    }

    // Ensure line items sum matches totalCentavos
    final sumCentavos = lineItems.fold<int>(0, (sum, i) => sum + ((i['amount'] as int) * (i['quantity'] as int)));
    final finalLineItems = (sumCentavos == totalCentavos && lineItems.isNotEmpty)
        ? lineItems
        : [
            {
              'currency': 'PHP',
              'amount': totalCentavos,
              'name': 'C&J Arena Pro Shop & Café POS Order',
              'quantity': 1,
            }
          ];

    final payload = {
      'data': {
        'attributes': {
          'send_email_receipt': true,
          'show_description': true,
          'show_line_items': true,
          'line_items': finalLineItems,
          'payment_method_types': ['gcash', 'paymaya', 'grab_pay', 'card'],
          'description': 'C&J Arena POS Order - Pro Shop & Café',
          'billing': {
            'name': customerName?.trim().isNotEmpty == true ? customerName!.trim() : 'Cashier Customer',
            if (customerEmail?.trim().isNotEmpty == true) 'email': customerEmail!.trim().toLowerCase(),
            if (customerPhone?.trim().isNotEmpty == true) 'phone': customerPhone!.trim(),
          },
          'success_url': 'https://checkout.paymongo.com/success',
          'cancel_url': 'https://checkout.paymongo.com/cancel',
        }
      }
    };

    try {
      final response = await http
          .post(
            Uri.parse('https://api.paymongo.com/v1/checkout_sessions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': PayMongoConfig.basicAuthHeader,
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final data = json['data'] as Map<String, dynamic>;
        final attributes = data['attributes'] as Map<String, dynamic>;
        return {
          'sessionId': data['id'] as String,
          'checkoutUrl': attributes['checkout_url'] as String,
          'status': attributes['status'] as String? ?? 'active',
          'isMock': false,
        };
      } else {
        throw Exception('PayMongo error (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('PosService createPayMongoCheckoutSession fallback: $e');
      final mockId = 'pos_cs_${DateTime.now().millisecondsSinceEpoch}';
      return {
        'sessionId': mockId,
        'checkoutUrl': 'https://checkout.paymongo.com/mock_pos_$mockId',
        'status': 'active',
        'isMock': true,
      };
    }
  }

  /// Check PayMongo checkout session status
  Future<bool> checkPayMongoPaymentStatus(String sessionId) async {
    if (sessionId.startsWith('pos_cs_')) {
      return false;
    }
    try {
      final statusData = await BookingService.instance.getPayMongoSessionStatus(sessionId);
      return statusData['isPaid'] == true;
    } catch (e) {
      debugPrint('PosService checkPayMongoPaymentStatus notice: $e');
      return false;
    }
  }
}
