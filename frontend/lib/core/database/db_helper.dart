import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class DbHelper {
  static final DbHelper _instance = DbHelper._internal();
  factory DbHelper() => _instance;
  DbHelper._internal();

  Database? _database;

  // Get the active database instance. Throws exception if database is not unlocked/initialized.
  Database get database {
    if (_database == null) {
      throw StateError('La base de datos no ha sido desbloqueada. Inicia sesión primero.');
    }
    return _database!;
  }

  // Initialize and unlock the database using the user's Master Key
  Future<void> initDatabase(String masterKey) async {
    if (_database != null) return; // Already unlocked

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'my_finances_secure.db');

    // openDatabase from sqflite_sqlcipher unlocks the database with the password key
    _database = await openDatabase(
      path,
      password: masterKey,
      version: 1,
      onCreate: _onCreate,
    );
  }

  // Close database and lock it (Logout)
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  // Define tables schema
  Future<void> _onCreate(Database db, int version) async {
    // Accounts Table (e.g. Bank accounts, cash, savings goal cards)
    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL, -- 'bank', 'cash', 'card', 'savings'
        balance REAL NOT NULL DEFAULT 0.0,
        currency TEXT NOT NULL DEFAULT 'USD',
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Transactions Table
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL,
        type TEXT NOT NULL, -- 'income', 'expense', 'savings'
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        description TEXT,
        date TEXT NOT NULL, -- ISO 8601 String
        is_synced INTEGER NOT NULL DEFAULT 0, -- 0 = Pending, 1 = Synced with C#
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
      )
    ''');

    // Passwords / Credentials Vault Table (Zero-Knowledge AES encrypted payload)
    await db.execute('''
      CREATE TABLE password_vault (
        id TEXT PRIMARY KEY,
        service_name TEXT NOT NULL, -- e.g. 'Bank of America', 'Netflix'
        username TEXT NOT NULL,
        encrypted_password TEXT NOT NULL, -- AES-256 base64 string
        website_url TEXT,
        encrypted_notes TEXT, -- AES-256 base64 string
        updated_at TEXT NOT NULL
      )
    ''');
  }
}
