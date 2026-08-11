import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../../core/database/db_helper.dart';
import '../../../../core/security/encryption_service.dart';
import '../../../../core/security/secure_storage_service.dart';

class LocalPasswordRepository {
  final DbHelper _dbHelper;
  final EncryptionService _encryptionService;
  final SecureStorageService _secureStorage;

  LocalPasswordRepository({
    required DbHelper dbHelper,
    required EncryptionService encryptionService,
    required SecureStorageService secureStorage,
  })  : _dbHelper = dbHelper,
        _encryptionService = encryptionService,
        _secureStorage = secureStorage;

  Database get _db => _dbHelper.database;

  // Retrieve the master key to perform AES encryption/decryption
  Future<String> _getMasterKey() async {
    final key = await _secureStorage.getMasterKey();
    if (key == null) {
      throw StateError('El llavero maestro está bloqueado.');
    }
    return key;
  }

  // Get all passwords in decrypted format
  Future<List<Map<String, String>>> getCredentials() async {
    final rawList = await _db.query('password_vault', orderBy: 'service_name ASC');
    final masterKey = await _getMasterKey();

    final List<Map<String, String>> decryptedList = [];

    for (var raw in rawList) {
      final String id = raw['id'] as String;
      final String serviceName = raw['service_name'] as String;
      final String username = raw['username'] as String;
      final String encryptedPass = raw['encrypted_password'] as String;
      final String? websiteUrl = raw['website_url'] as String?;
      final String? encryptedNotes = raw['encrypted_notes'] as String?;
      final String updatedAt = raw['updated_at'] as String;

      final decryptedPass = _encryptionService.decryptData(encryptedPass, masterKey);
      final decryptedNotes = encryptedNotes != null
          ? _encryptionService.decryptData(encryptedNotes, masterKey)
          : '';

      decryptedList.add({
        'id': id,
        'serviceName': serviceName,
        'username': username,
        'password': decryptedPass,
        'websiteUrl': websiteUrl ?? '',
        'notes': decryptedNotes,
        'updatedAt': updatedAt,
      });
    }

    return decryptedList;
  }

  // Add or update credentials (with encryption)
  Future<void> saveCredential({
    required String id,
    required String serviceName,
    required String username,
    required String clearPassword,
    String? websiteUrl,
    String? clearNotes,
  }) async {
    final masterKey = await _getMasterKey();

    final encryptedPassword = _encryptionService.encryptData(clearPassword, masterKey);
    final encryptedNotes = clearNotes != null && clearNotes.isNotEmpty
        ? _encryptionService.encryptData(clearNotes, masterKey)
        : null;

    final data = {
      'id': id,
      'service_name': serviceName,
      'username': username,
      'encrypted_password': encryptedPassword,
      'website_url': websiteUrl,
      'encrypted_notes': encryptedNotes,
      'updated_at': DateTime.now().toIso8601String(),
    };

    await _db.insert('password_vault', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Delete credential
  Future<void> deleteCredential(String id) async {
    await _db.delete('password_vault', where: 'id = ?', whereArgs: [id]);
  }
}
