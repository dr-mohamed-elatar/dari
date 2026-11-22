import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../db/repositories.dart' show DbPage, ClientRepo, GuarantorRepo, ContractRepo, PaymentRepo, SettingsRepo;
import '../../logic/egyptian_validators.dart';
import '../../models/models.dart';
import '../../services/license_service.dart';
import '../widgets/paged_controls.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});
  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  int _page = 1, _size = 25;
  String _query = '';
  final _selected = <String>{};
  Future<DbPage<Client>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<ClientRepo>().page(page: _page, pageSize: _size, query: _query);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MediaQuery.of(context).size.width >= 800 ? AppBar(title: const Text('العملاء')) : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await Navigator.push<bool>(
              context, MaterialPageRoute(builder: (_) => const ClientFormScreen()));
          if (saved == true) _load();
        },
        icon: const Icon(Icons.person_add),
        label: const Text('إضافة عميل'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'بحث بالاسم / الرقم القومي / الهاتف',
                border: OutlineInputBorder()),
            onChanged: (v) {
              _query = v;
              _page = 1;
              _load();
            },
          ),
        ),
        if (_selected.isNotEmpty)
          ListTile(
            leading: Text('محدد: ${_selected.length}'),
            trailing: TextButton.icon(
              icon: const Icon(Icons.delete, color: Colors.red),
              label: const Text('حذف جماعي', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                final ok = await _confirm(context, 'حذف ${_selected.length} عميلًا وعقودهم؟');
                if (ok == true) {
                  await context.read<ClientRepo>().deleteMany(_selected.toList());
                  _selected.clear();
                  _load();
                }
              },
            ),
          ),
        Expanded(
          child: FutureBuilder<DbPage<Client>>(
            future: _future,
            builder: (ctx, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final p = snap.data!;
              if (p.rows.isEmpty) return const Center(child: Text('لا يوجد عملاء'));
              return Column(children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: p.rows.length,
                    itemBuilder: (ctx, i) {
                      final c = p.rows[i];
                      return CheckboxListTile(
                        value: _selected.contains(c.id),
                        onChanged: (v) => setState(
                            () => v == true ? _selected.add(c.id) : _selected.remove(c.id)),
                        title: Text(c.name),
                        subtitle: Text('${c.phone}  •  ${c.nationalId}'),
                        secondary: const Icon(Icons.person),
                      );
                    },
                  ),
                ),
                PagedControls(
                    page: p,
                    onPage: (v) {
                      _page = v;
                      _load();
                    },
                    onPageSize: (v) {
                      _size = v;
                      _page = 1;
                      _load();
                    }),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}

Future<bool?> _confirm(BuildContext context, String message) => showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد')),
        ],
      ),
    );

class ClientFormScreen extends StatefulWidget {
  final Client? existing;
  const ClientFormScreen({super.key, this.existing});
  @override
  State<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<ClientFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _nid = TextEditingController(text: widget.existing?.nationalId ?? '');
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');
  late final _phone2 = TextEditingController(text: widget.existing?.phone2 ?? '');
  late final _address = TextEditingController(text: widget.existing?.address ?? '');
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  String? _nidInfo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'إضافة عميل' : 'تعديل عميل')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'الاسم', border: OutlineInputBorder()),
            validator: (v) => validatePersonName(v ?? ''),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nid,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
                labelText: 'الرقم القومي (14 رقمًا)',
                border: const OutlineInputBorder(),
                helperText: _nidInfo),
            validator: (v) {
              final r = validateEgyptianNationalId(v ?? '');
              return r.valid ? null : r.error;
            },
            onChanged: (v) {
              final r = validateEgyptianNationalId(v);
              setState(() =>
                  _nidInfo = r.valid ? '${r.governorate} — ${r.gender} — مولود ${r.birthDate!.year}/${r.birthDate!.month}/${r.birthDate!.day}' : null);
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'الهاتف (01xxxxxxxxx)', border: OutlineInputBorder()),
            validator: (v) => validateEgyptianPhone(v ?? ''),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone2,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'هاتف إضافي (اختياري)', border: OutlineInputBorder()),
            validator: (v) => (v == null || v.trim().isEmpty) ? null : validateEgyptianPhone(v),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _address,
            decoration: const InputDecoration(labelText: 'العنوان', border: OutlineInputBorder()),
            validator: (v) => validateAddress(v ?? ''),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'ملاحظات', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('حفظ'),
            onPressed: _save,
          ),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final repo = context.read<ClientRepo>();
    final dup = await repo.findDuplicate(nationalId: _nid.text.trim(), phone: _phone.text.trim());
    if (dup != null && dup.id != widget.existing?.id) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: Colors.red,
            content: Text('الرقم القومي أو الهاتف مسجّل باسم «${dup.name}» — ممنوع الازدواج')));
      }
      return;
    }
    // حدود الباقة
    final lic = context.read<LicenseService>();
    final info = await lic.current();
    if (widget.existing == null) {
      final err = lic.checkLimit(info, kind: 'clients', current: await repo.count());
      if (err != null && info != null) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(err)));
        }
        return;
      }
    }
    final c = widget.existing ??
        Client(id: DateTime.now().microsecondsSinceEpoch.toString(), name: '');
    c
      ..name = sanitizeName(_name.text)
      ..nationalId = normalizeDigits(_nid.text).replaceAll(RegExp(r'[^0-9]'), '')
      ..phone = normalizeDigits(_phone.text).replaceAll(RegExp(r'[^0-9]'), '')
      ..phone2 = normalizeDigits(_phone2.text).replaceAll(RegExp(r'[^0-9]'), '')
      ..address = _address.text.trim()
      ..notes = _notes.text.trim();
    await repo.upsert(c);
    if (mounted) Navigator.pop(context, true);
  }
}
