import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// تشفير الحقول الحساسة (الرقم القومي والهواتف) قبل التخزين.
/// المفتاح في التخزين الآمن (Keystore على أندرويد). على الويب (نسخة العرض فقط)
/// يُحفظ المفتاح محليًا في قاعدة البيانات — موثق كقيود لنسخة المتصفح.
class CryptoService {
  static const _keyName = 'dari_aes_key_v1';
  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  enc.Key? _key;
  final _iv = enc.IV.fromLength(16); // IV ثابت للبحث بالتطابق؛ القيم حساسة لكن غير مالية
  String? _fallbackKey; // للويب فقط

  Future<void> init([String? webStoredKey]) async {
    String? b64;
    if (kIsWeb) {
      b64 = webStoredKey;
      if (b64 == null) {
        b64 = base64Encode(List<int>.generate(32, (_) => Random.secure().nextInt(256)));
        _fallbackKey = b64; // على المالك حفظها في الإعدادات
      }
    } else {
      b64 = await _secure.read(key: _keyName);
      if (b64 == null) {
        b64 = base64Encode(List<int>.generate(32, (_) => Random.secure().nextInt(256)));
        await _secure.write(key: _keyName, value: b64);
      }
    }
    _key = enc.Key.fromBase64(b64);
  }

  String? get webGeneratedKey => _fallbackKey;

  String encryptText(String plain) {
    if (plain.isEmpty) return plain;
    final e = enc.Encrypter(enc.AES(_key!, mode: enc.AESMode.cbc));
    return e.encrypt(plain, iv: _iv).base64;
  }

  String decryptText(String cipher) {
    if (cipher.isEmpty) return cipher;
    try {
      final e = enc.Encrypter(enc.AES(_key!, mode: enc.AESMode.cbc));
      return e.decrypt(enc.Encrypted.fromBase64(cipher), iv: _iv);
    } catch (_) {
      return cipher; // بيانات قديمة غير مشفرة
    }
  }

  static String hashPassword(String password, String salt) =>
      sha256.convert(utf8.encode('$salt::$password')).toString();

  static String newSalt() =>
      base64Encode(List<int>.generate(16, (_) => Random.secure().nextInt(256)));
}
