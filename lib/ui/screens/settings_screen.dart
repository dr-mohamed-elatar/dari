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
          onTap: () async {
            // اختيار الملف عبر share dialog في الأندرويد يحتاج file_picker؛
            // النسخة الأولى تقرأ آخر نسخة تلقائية كتأكيد للمسار.
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('الاستيراد من ملف يُضاف في البناء النهائي (file_picker)')));
          },
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
