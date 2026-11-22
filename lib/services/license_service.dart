import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';

import '../db/database.dart';

/// التفعيل والترخيص — تصميم نظيف قابل للتبديل.
/// لا يحمل أي أكواد أو أسرار من النسخة القديمة: المفتاح السري يضعه المالك
/// في الإعدادات (قسم مطور محمي بكلمة سر)، ويستطيع لاحقًا استبدال المولّد
/// بخادم ترخيص (Supabase) دون تغيير باقي التطبيق.
///
/// صيغة كود التفعيل: XXXXX-XXXXX-XXXXX-XXXXX-XXXXX (مرتبط ببصمة الجهاز).
/// التحقق: HMAC-SHA256(سر المطور, بصمة الجهاز | تاريخ الانتهاء | الحدود)
/// ثم أخذ أجزاء سداسية منه بصيغة الكود.

class LicenseInfo {
  final String code;
  final DateTime expiresAt;
  final int maxClients;
  final int maxGuarantors;
  final int maxContracts;
  final String deviceFp;
  const LicenseInfo({
    required this.code,
    required this.expiresAt,
    this.maxClients = 0, // 0 = بلا حد
    this.maxGuarantors = 0,
    this.maxContracts = 0,
    required this.deviceFp,
  });

  bool get active => expiresAt.isAfter(DateTime.now());
  int get daysLeft => expiresAt.difference(DateTime.now()).inDays;

  Map<String, dynamic> toJson() => {
        'code': code,
        'expires_at': expiresAt.toIso8601String(),
        'max_clients': maxClients,
        'max_guarantors': maxGuarantors,
        'max_contracts': maxContracts,
        'device_fp': deviceFp,
      };
  factory LicenseInfo.fromJson(Map<String, dynamic> m) => LicenseInfo(
        code: m['code'] ?? '',
        expiresAt: DateTime.tryParse(m['expires_at'] ?? '') ?? DateTime(2000),
        maxClients: (m['max_clients'] as num?)?.toInt() ?? 0,
        maxGuarantors: (m['max_guarantors'] as num?)?.toInt() ?? 0,
        maxContracts: (m['max_contracts'] as num?)?.toInt() ?? 0,
        deviceFp: m['device_fp'] ?? '',
      );
}

class LicenseService {
  static const _currentKey = 'current_license';
  static const _secretKey = 'dev_secret';
  static const _logKey = 'activation_log';

  Future<Database> get _db async => (await AppDatabase.instance.db);

  Future<String> deviceFingerprint() async {
    final info = DeviceInfoPlugin();
    String raw;
    if (kIsWeb) {
      final w = await info.webBrowserInfo;
      raw = 'web:${w.userAgent}';
    } else {
      final a = await info.androidInfo;
      raw = 'android:${a.id}';
    }
    return sha256.convert(utf8.encode(raw)).toString().substring(0, 16).toUpperCase();
  }

  Future<String?> devSecret() async {
    final d = await _db;
    final r = await d.query('licenses', where: 'key = ?', whereArgs: [_secretKey], limit: 1);
    return r.isEmpty ? null : r.first['value'] as String?;
  }

  Future<void> setDevSecret(String secret) async {
    final d = await _db;
    await d.insert('licenses', {'key': _secretKey, 'value': secret},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// توليد كود تفعيل لجهاز ببصمة معينة (يُستخدم في قسم المطور فقط)
  String generateCode({
    required String secret,
    required String deviceFp,
    required DateTime expiresAt,
    int maxClients = 0,
    int maxGuarantors = 0,
    int maxContracts = 0,
  }) {
    final payload = '$deviceFp|${expiresAt.toIso8601String().substring(0, 10)}|$maxClients|$maxGuarantors|$maxContracts';
    final h = hmacHex(secret, payload);
    final groups = <String>[];
    for (var i = 0; i < 5; i++) {
      groups.add(h.substring(i * 5, i * 5 + 5).toUpperCase());
    }
    return groups.join('-');
  }

  String hmacHex(String secret, String payload) =>
      Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(payload)).toString();

  /// تفعيل النسخة بكود — يتحقق محليًا بسر المطور وبصمة الجهاز
  Future<LicenseInfo?> activate(String code, {DateTime? expiresAt, int maxClients = 0, int maxGuarantors = 0, int maxContracts = 0}) async {
    final secret = await devSecret();
    if (secret == null) return null;
    final fp = await deviceFingerprint();
    final exp = expiresAt ?? DateTime.now().add(const Duration(days: 365));
    final expected = generateCode(
        secret: secret, deviceFp: fp, expiresAt: exp,
        maxClients: maxClients, maxGuarantors: maxGuarantors, maxContracts: maxContracts);
    if (expected != code.trim().toUpperCase()) return null;
    final info = LicenseInfo(
        code: expected, expiresAt: exp, maxClients: maxClients,
        maxGuarantors: maxGuarantors, maxContracts: maxContracts, deviceFp: fp);
    final d = await _db;
    await d.insert('licenses', {'key': _currentKey, 'value': jsonEncode(info.toJson())},
        conflictAlgorithm: ConflictAlgorithm.replace);
    await _log('تفعيل ناجح حتى ${exp.toIso8601String().substring(0, 10)}');
    return info;
  }

  Future<LicenseInfo?> current() async {
    final d = await _db;
    final r = await d.query('licenses', where: 'key = ?', whereArgs: [_currentKey], limit: 1);
    if (r.isEmpty) return null;
    try {
      final info = LicenseInfo.fromJson(jsonDecode(r.first['value'] as String));
      return info.active ? info : null;
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> activationLog() async {
    final d = await _db;
    final r = await d.query('licenses', where: 'key = ?', whereArgs: [_logKey], limit: 1);
    if (r.isEmpty) return [];
    return List<String>.from(jsonDecode(r.first['value'] as String));
  }

  Future<void> _log(String entry) async {
    final log = await activationLog();
    log.add('${DateTime.now().toIso8601String()} — $entry');
    final d = await _db;
    await d.insert('licenses', {'key': _logKey, 'value': jsonEncode(log)},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// التحقق من الحدود (0 = بلا حد)
  String? checkLimit(LicenseInfo? info, {required String kind, required int current}) {
    if (info == null) return 'النسخة غير مفعّلة';
    final max = kind == 'clients'
        ? info.maxClients
        : kind == 'guarantors'
            ? info.maxGuarantors
            : info.maxContracts;
    if (max > 0 && current >= max) return 'بلوغ حد الباقة ($max)';
    return null;
  }
}
