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
  Future<void> initDatabase(String masterKey, {bool isNewRegistration = false}) async {
    if (_database != null) {
      await closeDatabase();
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'my_finances_secure.db');

    if (isNewRegistration) {
      try {
        await deleteDatabase(path);
      } catch (_) {}
    }

    try {
      // openDatabase from sqflite_sqlcipher unlocks the database with the password key
      _database = await openDatabase(
        path,
        password: masterKey,
        version: 3,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      if (isNewRegistration) {
        try {
          await deleteDatabase(path);
        } catch (_) {}
        _database = await openDatabase(
          path,
          password: masterKey,
          version: 3,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        );
      } else {
        rethrow;
      }
    }

    // Auto-migration: ensure 'color' column exists in accounts table
    try {
      await _database!.execute('ALTER TABLE accounts ADD COLUMN color TEXT');
    } catch (_) {
      // Column already exists
    }

    // Auto-migration: ensure 'currency' column exists in transactions table
    try {
      await _database!.execute("ALTER TABLE transactions ADD COLUMN currency TEXT NOT NULL DEFAULT 'VES'");
    } catch (_) {
      // Column already exists
    }

    // Auto-migration: ensure savings_goals table exists
    try {
      await _database!.execute('''
        CREATE TABLE IF NOT EXISTS savings_goals (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          target_amount REAL NOT NULL,
          current_amount REAL NOT NULL DEFAULT 0.0,
          target_date TEXT,
          icon_name TEXT,
          color_hex TEXT,
          is_completed INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');
    } catch (_) {}

    // Auto-migration: ensure recurring_payments table exists
    try {
      await _database!.execute('''
        CREATE TABLE IF NOT EXISTS recurring_payments (
          id TEXT PRIMARY KEY,
          account_id TEXT,
          name TEXT NOT NULL,
          amount REAL NOT NULL,
          currency TEXT NOT NULL DEFAULT 'VES',
          category TEXT NOT NULL,
          due_day INTEGER NOT NULL,
          icon_name TEXT,
          is_active INTEGER NOT NULL DEFAULT 1,
          last_paid_month TEXT
        )
      ''');
    } catch (_) {}
  }

  // Delete database file from disk completely
  Future<void> deleteDatabaseFile() async {
    await closeDatabase();
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'my_finances_secure.db');
    try {
      await deleteDatabase(path);
    } catch (_) {}
  }

  // Close database and lock it (Logout)
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  // Handle schema upgrades between versions
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute("ALTER TABLE transactions ADD COLUMN currency TEXT NOT NULL DEFAULT 'VES'");
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE accounts ADD COLUMN color TEXT');
      } catch (_) {}
    }
    if (oldVersion < 3) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS savings_goals (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            target_amount REAL NOT NULL,
            current_amount REAL NOT NULL DEFAULT 0.0,
            target_date TEXT,
            icon_name TEXT,
            color_hex TEXT,
            is_completed INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');
      } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS recurring_payments (
            id TEXT PRIMARY KEY,
            account_id TEXT,
            name TEXT NOT NULL,
            amount REAL NOT NULL,
            currency TEXT NOT NULL DEFAULT 'VES',
            category TEXT NOT NULL,
            due_day INTEGER NOT NULL,
            icon_name TEXT,
            is_active INTEGER NOT NULL DEFAULT 1,
            last_paid_month TEXT
          )
        ''');
      } catch (_) {}
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
        color TEXT,
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
        currency TEXT NOT NULL DEFAULT 'VES',
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

    // Savings Goals Table
    await db.execute('''
      CREATE TABLE savings_goals (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        target_amount REAL NOT NULL,
        current_amount REAL NOT NULL DEFAULT 0.0,
        target_date TEXT,
        icon_name TEXT,
        color_hex TEXT,
        is_completed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // Recurring Payments / Subscriptions Table
    await db.execute('''
      CREATE TABLE recurring_payments (
        id TEXT PRIMARY KEY,
        account_id TEXT,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        currency TEXT NOT NULL DEFAULT 'VES',
        category TEXT NOT NULL,
        due_day INTEGER NOT NULL,
        icon_name TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        last_paid_month TEXT
      )
    ''');
  }
}
