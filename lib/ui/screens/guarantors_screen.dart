import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../db/repositories.dart' show DbPage, ClientRepo, GuarantorRepo, ContractRepo, PaymentRepo, SettingsRepo;
import '../../logic/egyptian_validators.dart';
import '../../models/models.dart';
import '../widgets/paged_controls.dart';

class GuarantorsScreen extends StatefulWidget {
  const GuarantorsScreen({super.key});
  @override
  State<GuarantorsScreen> createState() => _GuarantorsScreenState();
}

class _GuarantorsScreenState extends State<GuarantorsScreen> {
  int _page = 1, _size = 25;
  String _query = '';
  Future<DbPage<Guarantor>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<GuarantorRepo>().page(page: _page, pageSize: _size, query: _query);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MediaQuery.of(context).size.width >= 800 ? AppBar(title: const Text('الضامنين')) : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await Navigator.push<bool>(
              context, MaterialPageRoute(builder: (_) => const GuarantorFormScreen()));
          if (saved == true) _load();
        },
        icon: const Icon(Icons.person_add),
        label: const Text('إضافة ضامن'),
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
        Expanded(
          child: FutureBuilder<DbPage<Guarantor>>(
            future: _future,
            builder: (ctx, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final p = snap.data!;
              if (p.rows.isEmpty) return const Center(child: Text('لا يوجد ضامنون'));
              return Column(children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: p.rows.length,
                    itemBuilder: (ctx, i) {
                      final g = p.rows[i];
                      return ListTile(
                        leading: const Icon(Icons.handshake),
                        title: Text(g.name),
                        subtitle: Text('${g.relation}  •  ${g.phone}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await context.read<GuarantorRepo>().deleteMany([g.id]);
                            _load();
                          },
                        ),
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

class GuarantorFormScreen extends StatefulWidget {
  final Guarantor? existing;
  const GuarantorFormScreen({super.key, this.existing});
  @override
  State<GuarantorFormScreen> createState() => _GuarantorFormScreenState();
}

class _GuarantorFormScreenState extends State<GuarantorFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _nid = TextEditingController(text: widget.existing?.nationalId ?? '');
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');
  late final _address = TextEditingController(text: widget.existing?.address ?? '');
  late final _relation = TextEditingController(text: widget.existing?.relation ?? '');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'إضافة ضامن' : 'تعديل ضامن')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'الاسم', border: OutlineInputBorder()),
              validator: (v) => validatePersonName(v ?? '')),
          const SizedBox(height: 12),
          TextFormField(
              controller: _nid,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'الرقم القومي', border: OutlineInputBorder()),
              validator: (v) {
                final r = validateEgyptianNationalId(v ?? '');
                return r.valid ? null : r.error;
              }),
          const SizedBox(height: 12),
          TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'الهاتف', border: OutlineInputBorder()),
              validator: (v) => validateEgyptianPhone(v ?? '')),
          const SizedBox(height: 12),
          TextFormField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'العنوان', border: OutlineInputBorder()),
              validator: (v) => validateAddress(v ?? '')),
          const SizedBox(height: 12),
          TextFormField(
              controller: _relation,
              decoration: const InputDecoration(labelText: 'صلة القرابة', border: OutlineInputBorder()),
              validator: (v) => validateRelation(v ?? '')),
          const SizedBox(height: 16),
          FilledButton.icon(icon: const Icon(Icons.save), label: const Text('حفظ'), onPressed: _save),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final repo = context.read<GuarantorRepo>();
    final dup = await repo.findDuplicate(nationalId: _nid.text.trim(), phone: _phone.text.trim());
    if (dup != null && dup.id != widget.existing?.id) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: Colors.red,
            content: Text('الرقم القومي أو الهاتف مسجّل باسم «${dup.name}» — ممنوع الازدواج')));
      }
      return;
    }
    final g = widget.existing ??
        Guarantor(id: DateTime.now().microsecondsSinceEpoch.toString(), name: '');
    g
      ..name = sanitizeName(_name.text)
      ..nationalId = normalizeDigits(_nid.text).replaceAll(RegExp(r'[^0-9]'), '')
      ..phone = normalizeDigits(_phone.text).replaceAll(RegExp(r'[^0-9]'), '')
      ..address = _address.text.trim()
      ..relation = sanitizeName(_relation.text);
    await repo.upsert(g);
    if (mounted) Navigator.pop(context, true);
  }
}
