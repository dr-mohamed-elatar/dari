import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../db/repositories.dart';
import '../../services/backup_service.dart';
import '../../services/crypto_service.dart';
import '../../services/license_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _company = TextEditingController();
  final _branch = TextEditingController();
  final _minDown = TextEditingController(text: '20');
  String? _devHash;
  String? _devSalt;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsRepo>();
    s.all().then((m) => setState(() {
          _company.text = m['company_name'] ?? '';
          _branch.text = m['branch_address'] ?? '';
          _minDown.text = m['min_down_pct'] ?? '20';
          _devHash = m['dev_password_hash'];
          _devSalt = m['dev_password_salt'];
        }));
  }

  Future<void> _saveSettings() async {
    final s = context.read<SettingsRepo>();
    await s.set('company_name', _company.text.trim());
    await s.set('branch_address', _branch.text.trim());
    await s.set('min_down_pct', _minDown.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ')));
    }
  }

  Future<void> _openDevSection() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_devHash == null ? 'تعيين كلمة سر المطور' : 'قسم المطور'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(
              labelText: _devHash == null ? 'كلمة سر جديدة' : 'كلمة السر',
              border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('دخول')),
        ],
      ),
    );
    if (ok != true || controller.text.isEmpty || !mounted) return;
    final s = context.read<SettingsRepo>();
    if (_devHash == null) {
      final salt = CryptoService.newSalt();
      await s.set('dev_password_salt', salt);
      await s.set('dev_password_hash', CryptoService.hashPassword(controller.text, salt));
    } else {
      final hash = CryptoService.hashPassword(controller.text, _devSalt ?? '');
      if (hash != _devHash) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(backgroundColor: Colors.red, content: Text('كلمة سر خطأ')));
        return;
      }
    }
    if (mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const DevSectionScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MediaQuery.of(context).size.width >= 800 ? AppBar(title: const Text('الإعدادات')) : null,
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
            controller: _company,
            decoration: const InputDecoration(labelText: 'اسم النظام / المحل', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(
            controller: _branch,
            decoration: const InputDecoration(labelText: 'العنوان الفرعي', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(
            controller: _minDown,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'الحد الأدنى للمقدم %', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        FilledButton.icon(icon: const Icon(Icons.save), label: const Text('حفظ الإعدادات'), onPressed: _saveSettings),
        const Divider(height: 32),
        ListTile(
          leading: const Icon(Icons.image),
          title: const Text('شعار النظام'),
          subtitle: const Text('اختر من المكتبة أو ارفع شعارًا خاصًا — يظهر أعلى الرئيسية وفي طباعة العقد'),
          onTap: _openLogoLibrary,
        ),
        const Divider(height: 32),
        ListTile(
          leading: const Icon(Icons.backup),
          title: const Text('نسخة احتياطية كاملة (مشفرة بكلمة سر)'),
          onTap: () async {
            final pw = await _askPassword(context, 'كلمة سر التشفير (اتركها فارغة بدون تشفير)');
            if (pw == null) return;
            await BackupService().shareBackup(password: pw);
          },
        ),
        ListTile(
          leading: const Icon(Icons.restore),
          title: const Text('استيراد نسخة احتياطية'),
          subtitle: const Text('لا ينقل الترخيص — بيانات العملاء والعقود فقط'),
          onTap: () => _importBackup(context),
        ),
        ListTile(
          leading: const Icon(Icons.lock),
          title: const Text('قسم المطور (محمي بكلمة سر)'),
          subtitle: const Text('حدود النسخ، الأجهزة، سجل الأكواد'),
          onTap: _openDevSection,
        ),
      ]),
    );
  }

  /// مكتبة الشعارات: شعارات مدمجة + رفع شعار مخصص (يُحفظ base64 في الإعدادات).
  Future<void> _openLogoLibrary() async {
    final repo = context.read<SettingsRepo>();
    final current = await repo.get('logo_builtin');
    final customB64 = await repo.get('logo_data');
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مكتبة الشعارات'),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Wrap(spacing: 12, runSpacing: 12, children: [
              for (final e in const {
                'store': Icons.storefront,
                'receipt': Icons.receipt_long,
                'payments': Icons.payments,
                'account_balance': Icons.account_balance,
                'handshake': Icons.handshake,
                'home_work': Icons.home_work,
              }.entries)
                InkWell(
                  onTap: () async {
                    await repo.set('logo_builtin', e.key);
                    await repo.set('logo_data', '');
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: current == e.key ? Colors.teal.shade100 : Colors.grey.shade200,
                    ),
                    child: Icon(e.value, size: 32),
                  ),
                ),
            ]),
            const SizedBox(height: 16),
            if (customB64 != null && customB64.isNotEmpty)
              Column(children: [
                const Text('الشعار المخصص الحالي:'),
                const SizedBox(height: 8),
                Image.memory(base64Decode(customB64), height: 64),
                const SizedBox(height: 8),
              ]),
            FilledButton.icon(
              icon: const Icon(Icons.upload),
              label: const Text('رفع شعار خاص'),
              onPressed: () async {
                final picked = await FilePicker.platform
                    .pickFiles(type: FileType.image, withData: true);
                final bytes = picked?.files.first.bytes;
                if (bytes == null) return;
                if (bytes.length > 512 * 1024) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        backgroundColor: Colors.red,
                        content: Text('الصورة كبيرة — الحد الأقصى 512 كيلوبايت')));
                  }
                  return;
                }
                await repo.set('logo_data', base64Encode(bytes));
                await repo.set('logo_builtin', '');
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            TextButton(
              onPressed: () async {
                await repo.set('logo_builtin', '');
                await repo.set('logo_data', '');
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('بدون شعار'),
            ),
          ]),
        ),
      ),
    );
  }

  /// استيراد نسخة احتياطية من ملف .dari بكلمة سر النسخة (لا ينقل الترخيص).
  Future<void> _importBackup(BuildContext context) async {
    final pass = await _askPassword(context, 'كلمة سر النسخة الاحتياطية');
    if (pass == null) return;
    final picked = await FilePicker.platform.pickFiles(
        dialogTitle: 'اختر ملف النسخة الاحتياطية', withData: true);
    final file = picked?.files.first;
    if (file == null) return;
    final content = file.bytes != null
        ? utf8.decode(file.bytes!)
        : file.path != null
            ? File(file.path!).readAsStringSync()
            : null;
    if (content == null) return;
    try {
      final n = await context.read<BackupService>().restore(content, password: pass);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تم الاستيراد: $n سجل')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: Colors.red,
            content: Text('فشل الاستيراد — تحقق من الملف وكلمة السر')));
      }
    }
  }

  Future<String?> _askPassword(BuildContext context, String label) async {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(controller: c, obscureText: true, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('تأكيد')),
        ],
      ),
    );
  }
}

class DevSectionScreen extends StatelessWidget {
  const DevSectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lic = context.read<LicenseService>();
    return Scaffold(
      appBar: AppBar(title: const Text('قسم المطور')),
      body: FutureBuilder<(bool, LicenseInfo?, String, List<String>)>(
        future: (() async => (await lic.devSecret() != null, await lic.current(), await lic.deviceFingerprint(), await lic.activationLog()))(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final (hasSecret, current, fp, log) = snap.data!;
          return ListView(padding: const EdgeInsets.all(16), children: [
            ListTile(
              leading: const Icon(Icons.fingerprint),
              title: const Text('بصمة هذا الجهاز'),
              subtitle: Text(fp),
            ),
            ListTile(
              leading: Icon(hasSecret ? Icons.vpn_key : Icons.key_off),
              title: Text(hasSecret ? 'سر المطور مضبوط' : 'تعيين سر المطور (لتوليد الأكواد)'),
              onTap: hasSecret
                  ? null
                  : () async {
                      final c = TextEditingController();
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('سر المطور'),
                          content: TextField(
                              controller: c,
                              obscureText: true,
                              decoration: const InputDecoration(
                                  labelText: 'سر طويل يعرفه المالك فقط', border: OutlineInputBorder())),
                          actions: [
                            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
                          ],
                        ),
                      );
                      if (ok == true && c.text.length >= 8) {
                        await lic.setDevSecret(c.text);
                        if (context.mounted) {
                          Navigator.pushReplacement(
                              context, MaterialPageRoute(builder: (_) => const DevSectionScreen()));
                        }
                      }
                    },
            ),
            ListTile(
              leading: const Icon(Icons.verified),
              title: Text(current == null
                  ? 'لا ترخيص نشط'
                  : 'ترخيص حتى ${current.expiresAt.day}/${current.expiresAt.month}/${current.expiresAt.year} (متبقي ${current.daysLeft} يوم)'),
              subtitle: current == null
                  ? null
                  : Text(
                      'حدود: عملاء ${current.maxClients == 0 ? "∞" : current.maxClients} — ضامنين ${current.maxGuarantors == 0 ? "∞" : current.maxGuarantors} — عقود ${current.maxContracts == 0 ? "∞" : current.maxContracts}'),
            ),
            const Divider(),
            const Text('سجل التفعيل:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...log.reversed.take(20).map((e) => ListTile(dense: true, title: Text(e))),
          ]);
        },
      ),
    );
  }
}
