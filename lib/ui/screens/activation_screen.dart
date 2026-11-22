import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/license_service.dart';
import '../home_shell.dart';

/// شاشة التفعيل: تظهر فقط عندما يضبط المالك سرَّ مطور ولا يوجد ترخيص نشط.
class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});
  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _code = TextEditingController();
  String? _error;
  String _fp = '';

  @override
  void initState() {
    super.initState();
    context.read<LicenseService>().deviceFingerprint().then((v) => setState(() => _fp = v));
  }

  Future<void> _activate() async {
    final info = await context.read<LicenseService>().activate(_code.text);
    if (info == null) {
      setState(() => _error = 'كود غير صالح لهذا الجهاز');
    } else if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeShell()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(24), children: [
              const Icon(Icons.lock_outline, size: 64),
              const SizedBox(height: 12),
              const Text('تفعيل النسخة',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('بصمة الجهاز: $_fp', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextField(
                controller: _code,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                    labelText: 'كود التفعيل XXXXX-XXXXX-XXXXX-XXXXX-XXXXX',
                    border: OutlineInputBorder()),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _activate, child: const Text('تفعيل')),
            ]),
          ),
        ),
      ),
    );
  }
}
