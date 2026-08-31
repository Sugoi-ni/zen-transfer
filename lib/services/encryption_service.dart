import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;

class EncryptionService {
  static const int _keySize = 32; // AES-256
  static const int _ivSize = 16;

  late encrypt.Key _key;
  late encrypt.IV _iv;
  late encrypt.Encrypter _encrypter;

  EncryptionService() {
    _generateKeys();
  }

  void _generateKeys() {
    final random = Random.secure();
    final keyBytes = Uint8List.fromList(
      List.generate(_keySize, (_) => random.nextInt(256)),
    );
    _key = encrypt.Key(keyBytes);
    _iv = encrypt.IV.fromSecureRandom(_ivSize);
    _encrypter = encrypt.Encrypter(
      encrypt.AES(_key, mode: encrypt.AESMode.cbc),
    );
  }

  /// Generate a shared key from a PIN code for device pairing
  factory EncryptionService.fromPin(String pin) {
    final service = EncryptionService._fromPin(pin);
    return service;
  }

  EncryptionService._fromPin(String pin) {
    final pinBytes = utf8.encode(pin);
    final keyBytes = Uint8List(_keySize);
    for (var i = 0; i < _keySize; i++) {
      keyBytes[i] = i < pinBytes.length ? pinBytes[i] : 0;
    }
    // Mix in some derivation
    for (var i = 0; i < _keySize; i++) {
      keyBytes[i] = keyBytes[i] ^ (i * 7 + 13);
    }
    _key = encrypt.Key(keyBytes);
    _iv = encrypt.IV.fromSecureRandom(_ivSize);
    _encrypter = encrypt.Encrypter(
      encrypt.AES(_key, mode: encrypt.AESMode.cbc),
    );
  }

  /// Encrypt text content
  String encryptText(String plainText) {
    final encrypted = _encrypter.encrypt(plainText, iv: _iv);
    return encrypted.base64;
  }

  /// Decrypt text content
  String decryptText(String encryptedText) {
    final encrypted = encrypt.Encrypted.fromBase64(encryptedText);
    return _encrypter.decrypt(encrypted, iv: _iv);
  }

  /// Encrypt binary data
  Uint8List encryptData(Uint8List data) {
    return _encrypter.encryptBytes(data, iv: _iv).bytes;
  }

  /// Decrypt binary data
  Uint8List decryptData(Uint8List data) {
    return Uint8List.fromList(
      _encrypter.decryptBytes(encrypt.Encrypted(data), iv: _iv),
    );
  }

  /// Get key as base64 for sharing during pairing
  String get keyBase64 => base64Encode(_key.bytes);

  /// Get IV as base64 for sharing
  String get ivBase64 => base64Encode(_iv.bytes);

  /// Create pairing payload
  Map<String, String> get pairingPayload => {
    'key': keyBase64,
    'iv': ivBase64,
  };

  /// Initialize from pairing payload
  factory EncryptionService.fromPayload(Map<String, String> payload) {
    final service = EncryptionService._empty();
    service._key = encrypt.Key(base64Decode(payload['key']!));
    service._iv = encrypt.IV(base64Decode(payload['iv']!));
    service._encrypter = encrypt.Encrypter(
      encrypt.AES(service._key, mode: encrypt.AESMode.cbc),
    );
    return service;
  }

  EncryptionService._empty();
}
