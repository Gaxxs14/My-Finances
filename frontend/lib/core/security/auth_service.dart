import 'dart:convert';
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

  // Register user with Username, Master Password, and PIN
  Future<bool> registerUser({
    required String username,
    required String masterPassword,
    required String pin,
  }) async {
    try {
      if (username.isEmpty || masterPassword.length < 8 || pin.length < 4) {
        return false;
      }

      // 1. Try to register on the server first to link cloud DB
      await registerOnServer(username, masterPassword);

      // 2. Derive the 256-bit DB Encryption Key (Master Key) from the Master Password
      final vaultKey = _encryptionService.deriveKey(masterPassword, username);
      final masterKeyString = base64Url.encode(vaultKey.bytes);

      // 3. Hash the PIN for local validation
      final pinHash = _encryptionService.hashString(pin, username);

      // 4. Encrypt the Master Key with the PIN hash
      final pinEncryptedKey = _encryptionService.encryptWithKey(masterKeyString, vaultKey);

      // 5. Save credentials to secure hardware storage (via consistent SecureStorageService)
      await _secureStorage.saveUserPin(pinHash);
      await _secureStorage.saveMasterKey(masterKeyString);
      await _secureStorage.saveUsername(username);
      await _secureStorage.savePinEncryptedMasterKey(pinEncryptedKey);

      // 6. Unlock the local database
      await _dbHelper.initDatabase(masterKeyString);

      return true;
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

      // 1. Authenticate with C# server to refresh token and support sync
      await loginOnServer(username, masterPassword);

      // 2. Re-derive the key from the password
      final vaultKey = _encryptionService.deriveKey(masterPassword, username);
      final masterKeyString = base64Url.encode(vaultKey.bytes);

      // 3. Verify key by attempting to unlock the SQLCipher database.
      await _dbHelper.initDatabase(masterKeyString);
      
      // Update hardware-secured key
      await _secureStorage.saveMasterKey(masterKeyString);
      
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
        // Authenticated! Now we decrypt the Master Key using the PIN-derived key
        final pinKey = _encryptionService.deriveKey(pin, username);
        final decryptedMasterKey = _encryptionService.decryptWithKey(pinEncryptedKey, pinKey);

        if (decryptedMasterKey == 'ERROR_DECRYPTION_FAILED') {
          return false;
        }

        // Unlock DB
        await _dbHelper.initDatabase(decryptedMasterKey);
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
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Logout & Lock Database (Wipes keys from memory)
  Future<void> logout() async {
    await _dbHelper.closeDatabase();
  }
}
