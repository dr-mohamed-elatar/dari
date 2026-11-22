import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'dart:convert';
import 'dart:io';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db/database.dart';

/// النسخ الاحتياطي الكامل: تصدير/استيراد كل البيانات بملف JSON مشفر بكلمة سر
/// (AES-256)، مع نسخ تلقائي يومي محلي على الجهاز.
class BackupService {
  static const _tables = ['clients', 'guarantors', 'contracts', 'installments', 'payments', 'settings'];

  Future<Map<String, dynamic>> exportAll() async {
    final d = await AppDatabase.instance.db;
    final data = <String, dynamic>{'version': 1, 'exported_at': DateTime.now().toIso8601String()};
    for (final t in _tables) {
      data[t] = await d.query(t);
    }
    return data;
  }

  String encryptPayload(Map<String, dynamic> data, String password) {
    final key = enc.Key.fromUtf8(password.padRight(32, '#').substring(0, 32));
    final iv = enc.IV.fromLength(16);
    return enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc))
        .encrypt(jsonEncode(data), iv: iv)
        .base64;
  }

  Map<String, dynamic> decryptPayload(String payload, String password) {
    final key = enc.Key.fromUtf8(password.padRight(32, '#').substring(0, 32));
    final iv = enc.IV.fromLength(16);
    final plain = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc))
        .decrypt(enc.Encrypted.fromBase64(payload), iv: iv);
    return jsonDecode(plain) as Map<String, dynamic>;
  }

  Future<String> exportToFile({String password = ''}) async {
    final data = await exportAll();
    final content = password.isEmpty
        ? jsonEncode(data)
        : jsonEncode({'encrypted': true, 'payload': encryptPayload(data, password)});
    final dir = await _backupDir();
    final file = File(p.join(
        dir.path, 'dari-backup-${DateTime.now().toIso8601String().replaceAll(':', '-')}.json'));
    await file.writeAsString(content);
    return file.path;
  }

  Future<int> restore(String content, {String password = ''}) async {
    var data = jsonDecode(content) as Map<String, dynamic>;
    if (data['encrypted'] == true) {
      data = decryptPayload(data['payload'] as String, password);
    }
    final d = await AppDatabase.instance.db;
    var count = 0;
    await d.transaction((txn) async {
      for (final t in _tables) {
        final rows = (data[t] as List?) ?? [];
        await txn.delete(t);
        for (final r in rows) {
          await txn.insert(t, Map<String, dynamic>.from(r as Map),
              conflictAlgorithm: ConflictAlgorithm.replace);
          count++;
        }
      }
    });
    return count;
  }

  Future<Directory> _backupDir() async {
    if (kIsWeb) return Directory.systemTemp.createTempSync('dari-backup');
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'backups'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// نسخة تلقائية يومية (مرة كل تشغيل على الأكثر) داخل مجلد التطبيق
  Future<void> autoBackupIfDue() async {
    if (kIsWeb) return;
    final dir = await _backupDir();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final marker = File(p.join(dir.path, '.last-auto'));
    if (await marker.exists() && await marker.readAsString() == today) return;
    final data = await exportAll();
    final file = File(p.join(dir.path, 'auto-$today.json'));
    await file.writeAsString(jsonEncode(data));
    await marker.writeAsString(today);
    // الاحتفاظ بآخر 14 نسخة تلقائية
    final files = (await dir.list().where((f) => f.path.contains('auto-')).toList())
      ..sort((a, b) => b.path.compareTo(a.path));
    for (final f in files.skip(14)) {
      await f.delete();
    }
  }

  Future<void> shareBackup({String password = ''}) async {
    final path = await exportToFile(password: password);
    await Share.shareXFiles([XFile(path)], text: 'نسخة احتياطية — نظام التقسيط الذكي');
  }
}
