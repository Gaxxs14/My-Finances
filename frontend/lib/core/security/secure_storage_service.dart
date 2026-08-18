import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
          ),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock,
          ),
        );

  static const String _keyMasterKey = 'master_key';
  static const String _keyUserPin = 'user_pin';
  static const String _keyJwtToken = 'jwt_token';

  // Master Key for AES Encryption
  Future<void> saveMasterKey(String masterKey) async {
    await _storage.write(key: _keyMasterKey, value: masterKey);
  }

  Future<String?> getMasterKey() async {
    return await _storage.read(key: _keyMasterKey);
  }

  Future<void> deleteMasterKey() async {
    await _storage.delete(key: _keyMasterKey);
  }

  // User PIN (Local Backup / Quick Access)
  Future<void> saveUserPin(String pinHash) async {
    await _storage.write(key: _keyUserPin, value: pinHash);
  }

  Future<String?> getUserPin() async {
    return await _storage.read(key: _keyUserPin);
  }

  Future<void> deleteUserPin() async {
    await _storage.delete(key: _keyUserPin);
  }

  // JWT Security Tokens
  Future<void> saveJwtToken(String token) async {
    await _storage.write(key: _keyJwtToken, value: token);
  }

  Future<String?> getJwtToken() async {
    return await _storage.read(key: _keyJwtToken);
  }

  Future<void> deleteJwtToken() async {
    await _storage.delete(key: _keyJwtToken);
  }

  static const String _keyUsername = 'auth_username';
  static const String _keyPinEncryptedMasterKey = 'pin_encrypted_master_key';

  Future<void> saveUsername(String username) async {
    await _storage.write(key: _keyUsername, value: username);
  }

  Future<String?> getUsername() async {
    return await _storage.read(key: _keyUsername);
  }

  Future<void> savePinEncryptedMasterKey(String key) async {
    await _storage.write(key: _keyPinEncryptedMasterKey, value: key);
  }

  Future<String?> getPinEncryptedMasterKey() async {
    return await _storage.read(key: _keyPinEncryptedMasterKey);
  }

  static const String _keyPendingSms = 'pending_sms_transactions';

  Future<void> addPendingSmsTransaction(String jsonTx) async {
    final existing = await _storage.read(key: _keyPendingSms);
    List<String> list = [];
    if (existing != null) {
      list = List<String>.from(jsonDecode(existing) as List);
    }
    list.add(jsonTx);
    await _storage.write(key: _keyPendingSms, value: jsonEncode(list));
  }

  Future<List<String>> getPendingSmsTransactions() async {
    final existing = await _storage.read(key: _keyPendingSms);
    if (existing == null) return [];
    return List<String>.from(jsonDecode(existing) as List);
  }

  Future<void> clearPendingSmsTransactions() async {
    await _storage.delete(key: _keyPendingSms);
  }

  static const String _keyRecoveryKeyHash = 'recovery_key_hash';
  static const String _keyRecoveryEncryptedMasterKey = 'recovery_encrypted_master_key';

  Future<void> saveRecoveryKeyHash(String hash) async {
    await _storage.write(key: _keyRecoveryKeyHash, value: hash);
  }

  Future<String?> getRecoveryKeyHash() async {
    return await _storage.read(key: _keyRecoveryKeyHash);
  }

  Future<void> saveRecoveryEncryptedMasterKey(String key) async {
    await _storage.write(key: _keyRecoveryEncryptedMasterKey, value: key);
  }

  Future<String?> getRecoveryEncryptedMasterKey() async {
    return await _storage.read(key: _keyRecoveryEncryptedMasterKey);
  }

  static const String _keySmsEnabled = 'sms_reading_enabled';

  Future<void> saveSmsReadingEnabled(bool enabled) async {
    await _storage.write(key: _keySmsEnabled, value: enabled ? 'true' : 'false');
  }

  Future<bool> getSmsReadingEnabled() async {
    final val = await _storage.read(key: _keySmsEnabled);
    return val == 'true';
  }

  Future<void> saveData(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> readData(String key) async {
    return await _storage.read(key: key);
  }

  // Clear all secure storage (Logout / Reset)
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
