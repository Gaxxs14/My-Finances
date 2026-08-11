import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class EncryptionService {
  // Hash a master key or password to exactly 32 bytes (256 bits) for AES key
  encrypt.Key _deriveKey(String masterKey) {
    final keyBytes = utf8.encode(masterKey);
    final hash = sha256.convert(keyBytes);
    return encrypt.Key(Uint8List.fromList(hash.bytes));
  }

  // Encrypt plain text using AES-256-CBC with a random IV
  // Returns a Base64 string containing both the IV and the encrypted content (separated by a dot)
  String encryptData(String plainText, String masterKey) {
    if (plainText.isEmpty) return '';
    
    final key = _deriveKey(masterKey);
    final iv = encrypt.IV.fromLength(16); // Generates a random 16-byte IV
    
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    
    // Concatenate IV (Base64) + "." + EncryptedData (Base64)
    return '${iv.base64}.${encrypted.base64}';
  }

  // Decrypt cipher text (formatted as "IV.EncryptedData") using AES-256-CBC
  String decryptData(String encryptedTextWithIv, String masterKey) {
    if (encryptedTextWithIv.isEmpty) return '';
    
    try {
      final parts = encryptedTextWithIv.split('.');
      if (parts.length != 2) {
        throw const FormatException('Formato de datos cifrados inválido.');
      }
      
      final iv = encrypt.IV.fromBase64(parts[0]);
      final encryptedData = encrypt.Encrypted.fromBase64(parts[1]);
      
      final key = _deriveKey(masterKey);
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      
      return encrypter.decrypt(encryptedData, iv: iv);
    } catch (e) {
      // Return empty or throw decryption failure
      return 'ERROR_DECRYPTION_FAILED';
    }
  }

  // Double-hash utility for PIN / password local verification
  String hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final firstHash = sha256.convert(bytes);
    return sha256.convert(firstHash.bytes).toString();
  }
}
