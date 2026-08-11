import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class EncryptionService {
  // Strong Key Stretching (50,000 rounds of SHA-256 with a unique salt)
  // This derives a secure 256-bit AES key from the user's password.
  encrypt.Key deriveKey(String password, String salt) {
    final keyBytes = utf8.encode(password + salt);
    var digest = sha256.convert(keyBytes);
    for (int i = 0; i < 50000; i++) {
      digest = sha256.convert(digest.bytes);
    }
    return encrypt.Key(Uint8List.fromList(digest.bytes));
  }

  // Encrypt plain text using AES-256-CBC with a random IV and a pre-derived key
  // Returns a Base64 string containing both the IV and the encrypted content (separated by a dot)
  String encryptWithKey(String plainText, encrypt.Key key) {
    if (plainText.isEmpty) return '';
    
    final iv = encrypt.IV.fromLength(16); // Generates a random 16-byte IV
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    
    // Concatenate IV (Base64) + "." + EncryptedData (Base64)
    return '${iv.base64}.${encrypted.base64}';
  }

  // Decrypt cipher text (formatted as "IV.EncryptedData") using AES-256-CBC and a pre-derived key
  String decryptWithKey(String encryptedTextWithIv, encrypt.Key key) {
    if (encryptedTextWithIv.isEmpty) return '';
    
    try {
      final parts = encryptedTextWithIv.split('.');
      if (parts.length != 2) {
        throw const FormatException('Formato de datos cifrados inválido.');
      }
      
      final iv = encrypt.IV.fromBase64(parts[0]);
      final encryptedData = encrypt.Encrypted.fromBase64(parts[1]);
      
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      return encrypter.decrypt(encryptedData, iv: iv);
    } catch (e) {
      return 'ERROR_DECRYPTION_FAILED';
    }
  }

  // Double-hash utility for secure local verification (e.g. PIN hashing)
  String hashString(String input, String salt) {
    final bytes = utf8.encode(input + salt);
    final firstHash = sha256.convert(bytes);
    return sha256.convert(firstHash.bytes).toString();
  }
}
