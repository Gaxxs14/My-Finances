import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'dart:io';
import '../database/db_helper.dart';
import '../network/api_client.dart';
import 'biometric_service.dart';
import 'encryption_service.dart';
import 'secure_storage_service.dart';

class AuthService {
  final SecureStorageService _secureStorage;
  final EncryptionService _encryptionService;
  final BiometricService _biometricService;
  final DbHelper _dbHelper;
  final ApiClient _apiClient;

  AuthService({
    required SecureStorageService secureStorage,
    required EncryptionService encryptionService,
    required BiometricService biometricService,
    required DbHelper dbHelper,
    required ApiClient apiClient,
  })  : _secureStorage = secureStorage,
        _encryptionService = encryptionService,
        _biometricService = biometricService,
        _dbHelper = dbHelper,
        _apiClient = apiClient;

  // Check if a user is registered locally
  Future<bool> isUserRegistered() async {
    final savedUsername = await _getSavedUsername();
    return savedUsername != null && savedUsername.isNotEmpty;
  }

  Future<String?> _getSavedUsername() async {
    return await _secureStorage.getUsername();
  }

  // Generate a random Zero-Knowledge Recovery Key (Format: MYFIN-XXXX-XXXX-XXXX)
  String _generateRecoveryKey() {
    final random = Random.secure();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    String part() => List.generate(4, (i) => chars[random.nextInt(chars.length)]).join();
    return 'MYFIN-${part()}-${part()}-${part()}';
  }

  // Register on C# backend and store JWT token
  Future<bool> registerOnServer(String username, String password) async {
    try {
      final response = await _apiClient.post(
        '/api/auth/register',
        data: {
          'username': username,
          'password': password,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final token = response.data['token'] as String?;
        if (token != null) {
          await _secureStorage.saveJwtToken(token);
          return true;
        }
      }
      return false;
    } on DioException catch (de) {
      if (de.type == DioExceptionType.connectionTimeout || 
          de.type == DioExceptionType.receiveTimeout) {
        throw const SocketException("El servidor en la nube está despertando. Reintenta en unos segundos.");
      }
      rethrow;
    } catch (_) {
      return false;
    }
  }

  // Login on C# backend and store JWT token
  Future<bool> loginOnServer(String username, String password) async {
    try {
      final response = await _apiClient.post(
        '/api/auth/login',
        data: {
          'username': username,
          'password': password,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final token = response.data['token'] as String?;
        if (token != null) {
          await _secureStorage.saveJwtToken(token);
          return true;
        }
      }
      return false;
    } on DioException catch (de) {
      if (de.type == DioExceptionType.connectionTimeout || 
          de.type == DioExceptionType.receiveTimeout) {
        throw const SocketException("El servidor en la nube está despertando. Reintenta en unos segundos.");
      }
      rethrow;
    } catch (_) {
      return false;
    }
  }

  // Register user locally and on cloud. Returns the recovery key.
  Future<String?> registerUser({
    required String username,
    required String masterPassword,
    required String pin,
  }) async {
    try {
      if (username.isEmpty || masterPassword.length < 8 || pin.length < 4) {
        return null;
      }

      // 1. Try to register on the cloud server first to sync accounts later
      await registerOnServer(username, masterPassword);

      // 2. Derive the 256-bit DB Encryption Key (Master Key) from the Master Password
      final vaultKey = _encryptionService.deriveKey(masterPassword, username);
      final masterKeyString = base64Url.encode(vaultKey.bytes);

      // 3. Hash the PIN for local validation
      final pinHash = _encryptionService.hashString(pin, username);

      // 4. Encrypt the Master Key with the PIN hash
      final pinEncryptedKey = _encryptionService.encryptWithKey(masterKeyString, vaultKey);

      // 5. Generate Zero-Knowledge Recovery Key
      final recoveryKey = _generateRecoveryKey();
      final recoveryKeyHash = _encryptionService.hashString(recoveryKey, username);
      final recoveryDerivationKey = _encryptionService.deriveKey(recoveryKey, username);
      final recoveryEncryptedMasterKey = _encryptionService.encryptWithKey(masterKeyString, recoveryDerivationKey);

      // 6. Save credentials to secure storage
      await _secureStorage.saveUserPin(pinHash);
      await _secureStorage.saveMasterKey(masterKeyString);
      await _secureStorage.saveUsername(username);
      await _secureStorage.savePinEncryptedMasterKey(pinEncryptedKey);
      await _secureStorage.saveRecoveryKeyHash(recoveryKeyHash);
      await _secureStorage.saveRecoveryEncryptedMasterKey(recoveryEncryptedMasterKey);

      // 7. Unlock the local database
      await _dbHelper.initDatabase(masterKeyString);

      // 8. Process background pending transactions
      await processPendingSmsTransactions();

      return recoveryKey;
    } catch (e) {
      rethrow;
    }
  }

  // Get current registered username
  Future<String> getUsername() async {
    return await _secureStorage.getUsername() ?? '';
  }

  // Login using Username + Master Password
  Future<bool> loginWithPassword(String username, String masterPassword) async {
    try {
      final savedUsername = await _secureStorage.getUsername();
      if (savedUsername == null || savedUsername.toLowerCase() != username.toLowerCase()) {
        return false;
      }

      // 1. Authenticate with server to fetch fresh JWT token
      await loginOnServer(username, masterPassword);

      // 2. Re-derive the key from the password
      final vaultKey = _encryptionService.deriveKey(masterPassword, username);
      final masterKeyString = base64Url.encode(vaultKey.bytes);

      // 3. Verify key by attempting to unlock the SQLCipher database.
      await _dbHelper.initDatabase(masterKeyString);
      
      // Update hardware-secured key
      await _secureStorage.saveMasterKey(masterKeyString);

      // 4. Process background pending transactions
      await processPendingSmsTransactions();
      
      return true;
    } catch (e) {
      rethrow;
    }
  }

  // Login using PIN code
  Future<bool> loginWithPin(String pin) async {
    try {
      final username = await _secureStorage.getUsername();
      final savedPinHash = await _secureStorage.getUserPin();
      final pinEncryptedKey = await _secureStorage.getPinEncryptedMasterKey();

      if (username == null || savedPinHash == null || pinEncryptedKey == null) {
        return false;
      }

      final enteredPinHash = _encryptionService.hashString(pin, username);

      if (savedPinHash == enteredPinHash) {
        // Decrypt the Master Key using the PIN-derived key
        final pinKey = _encryptionService.deriveKey(pin, username);
        final decryptedMasterKey = _encryptionService.decryptWithKey(pinEncryptedKey, pinKey);

        if (decryptedMasterKey == 'ERROR_DECRYPTION_FAILED') {
          return false;
        }

        // Unlock DB
        await _dbHelper.initDatabase(decryptedMasterKey);

        // Process background pending transactions
        await processPendingSmsTransactions();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Login using Biometrics
  Future<bool> loginWithBiometrics() async {
    try {
      final hasBiometrics = await _biometricService.canCheckBiometrics();
      final isSupported = await _biometricService.isDeviceSupported();

      if (!hasBiometrics || !isSupported) return false;

      final authenticated = await _biometricService.authenticate(
        localizedReason: 'Inicia sesión de forma segura para acceder a tus finanzas',
      );

      if (authenticated) {
        final masterKey = await _secureStorage.getMasterKey();
        if (masterKey == null) return false;

        await _dbHelper.initDatabase(masterKey);

        // Process background pending transactions
        await processPendingSmsTransactions();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Recovery account using Zero-Knowledge Recovery Key
  Future<String?> recoverAccess({
    required String recoveryKey,
    required String newMasterPassword,
    required String newPin,
  }) async {
    try {
      final username = await _secureStorage.getUsername();
      final savedKeyHash = await _secureStorage.getRecoveryKeyHash();
      final recoveryEncryptedMasterKey = await _secureStorage.getRecoveryEncryptedMasterKey();

      if (username == null || savedKeyHash == null || recoveryEncryptedMasterKey == null) {
        return null;
      }

      final formattedKey = recoveryKey.trim().toUpperCase();
      final enteredKeyHash = _encryptionService.hashString(formattedKey, username);

      if (savedKeyHash != enteredKeyHash) {
        return null;
      }

      // Decrypt the Master Key using the recovery key
      final recoveryDerivationKey = _encryptionService.deriveKey(formattedKey, username);
      final masterKeyString = _encryptionService.decryptWithKey(recoveryEncryptedMasterKey, recoveryDerivationKey);

      if (masterKeyString == 'ERROR_DECRYPTION_FAILED') {
        return null;
      }

      // Update password hash in C# server
      await registerOnServer(username, newMasterPassword); // Updates key derivation endpoint

      // Encrypt the master key with the new password
      final vaultKey = _encryptionService.deriveKey(newMasterPassword, username);
      final newPinEncryptedKey = _encryptionService.encryptWithKey(masterKeyString, vaultKey);
      final newPinHash = _encryptionService.hashString(newPin, username);

      // Save credentials
      await _secureStorage.saveUserPin(newPinHash);
      await _secureStorage.saveMasterKey(masterKeyString);
      await _secureStorage.savePinEncryptedMasterKey(newPinEncryptedKey);

      // Generate a brand new recovery key for future use
      final newRecoveryKey = _generateRecoveryKey();
      final newRecoveryKeyHash = _encryptionService.hashString(newRecoveryKey, username);
      final newRecoveryDerivation = _encryptionService.deriveKey(newRecoveryKey, username);
      final newRecoveryEncryptedMasterKey = _encryptionService.encryptWithKey(masterKeyString, newRecoveryDerivation);

      await _secureStorage.saveRecoveryKeyHash(newRecoveryKeyHash);
      await _secureStorage.saveRecoveryEncryptedMasterKey(newRecoveryEncryptedMasterKey);

      // Unlock DB
      await _dbHelper.initDatabase(masterKeyString);
      await processPendingSmsTransactions();

      return newRecoveryKey;
    } catch (_) {
      return null;
    }
  }

  // Process pending background SMS transactions after unlocking the database
  Future<void> processPendingSmsTransactions() async {
    try {
      final db = _dbHelper.database;
      final pendingJsonList = await _secureStorage.getPendingSmsTransactions();
      if (pendingJsonList.isEmpty) return;

      for (var jsonStr in pendingJsonList) {
        final tx = jsonDecode(jsonStr) as Map<String, dynamic>;
        
        // Find default account to assign the parsed transaction
        final accounts = await db.query('accounts', limit: 1);
        String accountId;
        if (accounts.isNotEmpty) {
          accountId = accounts.first['id'] as String;
        } else {
          // Fallback account
          accountId = 'default_cash';
          await db.insert('accounts', {
            'id': accountId,
            'name': 'Efectivo General',
            'type': 'cash',
            'balance': 0.0,
            'currency': 'USD',
            'is_active': 1,
          });
        }

        // Insert transaction
        await db.insert('transactions', {
          'id': tx['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
          'account_id': accountId,
          'type': 'expense',
          'amount': tx['amount'],
          'category': tx['category'] ?? 'Otros',
          'description': tx['description'] ?? 'Transacción automática (SMS)',
          'date': tx['date'] ?? DateTime.now().toIso8601String(),
          'is_synced': 0,
        });

        // Update account balance
        await db.rawUpdate(
          'UPDATE accounts SET balance = balance - ? WHERE id = ?',
          [tx['amount'], accountId],
        );
      }

      await _secureStorage.clearPendingSmsTransactions();
    } catch (_) {
      // Prevent post-auth errors from blocking access
    }
  }

  // Logout & Lock Database (Wipes keys from memory)
  Future<void> logout() async {
    await _dbHelper.closeDatabase();
  }
}
