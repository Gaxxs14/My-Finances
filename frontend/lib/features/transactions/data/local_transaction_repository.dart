import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../../core/database/db_helper.dart';

class LocalTransactionRepository {
  final DbHelper _dbHelper;

  LocalTransactionRepository(this._dbHelper);

  Database get _db => _dbHelper.database;

  // --- ACCOUNTS ---
  
  Future<List<Map<String, dynamic>>> getAccounts() async {
    return await _db.query('accounts', where: 'is_active = 1');
  }

  Future<void> addAccount(Map<String, dynamic> account) async {
    await _db.insert('accounts', account, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- TRANSACTIONS ---

  Future<List<Map<String, dynamic>>> getTransactions({String? accountId, int limit = 50}) async {
    if (accountId != null) {
      return await _db.query(
        'transactions',
        where: 'account_id = ?',
        whereArgs: [accountId],
        orderBy: 'date DESC',
        limit: limit,
      );
    }
    return await _db.query('transactions', orderBy: 'date DESC', limit: limit);
  }

  Future<void> addTransaction(Map<String, dynamic> transaction) async {
    await _db.transaction((txn) async {
      // 1. Insert transaction
      await txn.insert('transactions', transaction);

      // 2. Adjust account balance
      final double amount = transaction['amount'] as double;
      final String type = transaction['type'] as String; // 'income', 'expense', 'savings'
      final String accountId = transaction['account_id'] as String;

      // Fetch current balance
      final List<Map<String, dynamic>> res = await txn.query(
        'accounts',
        columns: ['balance'],
        where: 'id = ?',
        whereArgs: [accountId],
      );

      if (res.isNotEmpty) {
        double currentBalance = res.first['balance'] as double;
        if (type == 'income') {
          currentBalance += amount;
        } else if (type == 'expense' || type == 'savings') {
          currentBalance -= amount;
        }

        await txn.update(
          'accounts',
          {'balance': currentBalance},
          where: 'id = ?',
          whereArgs: [accountId],
        );
      }
    });
  }

  // --- STATISTICS / DASHBOARD ---
  
  Future<Map<String, double>> getDashboardSummary() async {
    final List<Map<String, dynamic>> accounts = await getAccounts();
    double totalBalance = 0.0;
    for (var acc in accounts) {
      totalBalance += acc['balance'] as double;
    }

    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1).toIso8601String();

    final List<Map<String, dynamic>> monthTransactions = await _db.query(
      'transactions',
      where: 'date >= ?',
      whereArgs: [firstDayOfMonth],
    );

    double totalIncome = 0.0;
    double totalExpense = 0.0;

    for (var tx in monthTransactions) {
      final double amt = tx['amount'] as double;
      final String type = tx['type'] as String;
      if (type == 'income') {
        totalIncome += amt;
      } else if (type == 'expense') {
        totalExpense += amt;
      }
    }

    return {
      'totalBalance': totalBalance,
      'income': totalIncome,
      'expense': totalExpense,
    };
  }
}
