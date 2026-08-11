import 'package:dio/dio.dart';
import '../database/db_helper.dart';
import 'api_client.dart';

class SyncService {
  final ApiClient _apiClient;
  final DbHelper _dbHelper;

  SyncService({
    required ApiClient apiClient,
    required DbHelper dbHelper,
  })  : _apiClient = apiClient,
        _dbHelper = dbHelper;

  // --- ACCOUNTS SYNC ---
  Future<void> syncAccounts() async {
    try {
      final db = _dbHelper.database;
      
      // 1. Fetch all local accounts
      final List<Map<String, dynamic>> localAccounts = await db.query('accounts');
      if (localAccounts.isEmpty) return;

      // 2. Push to C# backend
      final response = await _apiClient.post('/api/sync/accounts', data: localAccounts);
      
      if (response.statusCode == 200) {
        final List<dynamic> serverAccounts = response.data as List<dynamic>;
        
        // 3. Update local database with server records to ensure parity
        await db.transaction((txn) async {
          for (var item in serverAccounts) {
            final acc = item as Map<String, dynamic>;
            await txn.insert(
              'accounts',
              {
                'id': acc['id'],
                'name': acc['name'],
                'type': acc['type'],
                'balance': double.parse(acc['balance'].toString()),
                'currency': acc['currency'],
                'is_active': acc['isActive'] == true ? 1 : 0,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        });
      }
    } catch (e) {
      // Offline or network error
      rethrow;
    }
  }

  // --- TRANSACTIONS SYNC ---
  Future<void> syncTransactions() async {
    try {
      final db = _dbHelper.database;

      // 1. Fetch all unsynced local transactions (is_synced = 0)
      final List<Map<String, dynamic>> unsynced = await db.query(
        'transactions',
        where: 'is_synced = 0',
      );

      // Reformat dates/types matching C# naming conventions
      final payload = unsynced.map((tx) {
        return {
          'id': tx['id'],
          'accountId': tx['account_id'],
          'type': tx['type'],
          'amount': tx['amount'],
          'category': tx['category'],
          'description': tx['description'],
          'date': tx['date'], // ISO String
        };
      }).toList();

      // 2. Push payload to C# backend
      final response = await _apiClient.post('/api/sync/transactions', data: payload);

      if (response.statusCode == 200) {
        final List<dynamic> serverTxList = response.data as List<dynamic>;

        // 3. Save server records and mark all as synced
        await db.transaction((txn) async {
          for (var item in serverTxList) {
            final tx = item as Map<String, dynamic>;
            await txn.insert(
              'transactions',
              {
                'id': tx['id'],
                'account_id': tx['accountId'],
                'type': tx['type'],
                'amount': double.parse(tx['amount'].toString()),
                'category': tx['category'],
                'description': tx['description'],
                'date': tx['date'],
                'is_synced': 1, // Marked as synced
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  // --- CREDENTIALS SYNC (End-to-End Encrypted Payload) ---
  Future<void> syncCredentials() async {
    try {
      final db = _dbHelper.database;

      // 1. Fetch local credentials
      final List<Map<String, dynamic>> localCreds = await db.query('password_vault');
      
      final payload = localCreds.map((c) {
        return {
          'id': c['id'],
          'serviceName': c['service_name'],
          'username': c['username'],
          'encryptedPassword': c['encrypted_password'],
          'websiteUrl': c['website_url'],
          'encryptedNotes': c['encrypted_notes'],
          'updatedAt': c['updated_at'],
        };
      }).toList();

      // 2. Push to C# backend
      final response = await _apiClient.post('/api/sync/credentials', data: payload);

      if (response.statusCode == 200) {
        final List<dynamic> serverCredsList = response.data as List<dynamic>;

        // 3. Save to local SQLite
        await db.transaction((txn) async {
          for (var item in serverCredsList) {
            final c = item as Map<String, dynamic>;
            await txn.insert(
              'password_vault',
              {
                'id': c['id'],
                'service_name': c['serviceName'],
                'username': c['username'],
                'encrypted_password': c['encryptedPassword'],
                'website_url': c['websiteUrl'],
                'encrypted_notes': c['encryptedNotes'],
                'updated_at': c['updatedAt'],
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  // --- FULL SYNC ---
  Future<void> triggerFullSync() async {
    await syncAccounts();
    await syncTransactions();
    await syncCredentials();
  }
}
