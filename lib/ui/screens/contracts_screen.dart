import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../db/repositories.dart' show DbPage, ClientRepo, GuarantorRepo, ContractRepo, PaymentRepo, SettingsRepo;
import '../../logic/egyptian_validators.dart';
import '../../logic/installment_calculator.dart';
import '../../models/models.dart';
import '../../services/export_service.dart';
import '../widgets/paged_controls.dart';
import 'clients_screen.dart' show ClientFormScreen;
import 'guarantors_screen.dart' show GuarantorFormScreen;

final _money = NumberFormat('#,##0.00', 'ar_EG');

class ContractsScreen extends StatefulWidget {
  const ContractsScreen({super.key});
  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen> {
  int _page = 1, _size = 25;
  String _query = '', _status = '';
  Future<DbPage<Contract>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context
        .read<ContractRepo>()
        .page(page: _page, pageSize: _size, query: _query, status: _status);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MediaQuery.of(context).size.width >= 800
          ? AppBar(title: const Text('العقود / الأقساط'))
          : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await Navigator.push<bool>(
              context, MaterialPageRoute(builder: (_) => const ContractFormScreen()));
          if (saved == true) _load();
        },
        icon: const Icon(Icons.post_add),
        label: const Text('عقد جديد'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'بحث بالعميل / المنتج',
                    border: OutlineInputBorder()),
                onChanged: (v) {
                  _query = v;
                  _page = 1;
                  _load();
                },
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _status,
              items: const [
                DropdownMenuItem(value: '', child: Text('الكل')),
                DropdownMenuItem(value: 'نشط', child: Text('نشط')),
                DropdownMenuItem(value: 'مكتمل', child: Text('مكتمل')),
                DropdownMenuItem(value: 'متعثر', child: Text('متعثر')),
              ],
              onChanged: (v) {
                _status = v ?? '';
                _page = 1;
                _load();
              },
            ),
          ]),
        ),
        Expanded(
          child: FutureBuilder<DbPage<Contract>>(
            future: _future,
            builder: (ctx, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final p = snap.data!;
              if (p.rows.isEmpty) return const Center(child: Text('لا توجد عقود'));
              return Column(children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: p.rows.length,
                    itemBuilder: (ctx, i) {
                      final c = p.rows[i];
                      return ListTile(
                        leading: Icon(Icons.description,
                            color: c.status == 'مكتمل'
                                ? Colors.green
                                : c.status == 'متعثر'
                                    ? Colors.red
                                    : Colors.blue),
                        title: Text('${c.clientName} — ${c.product}'),
                        subtitle: Text(
                            'القسط: ${_money.format(c.monthly)} × ${c.months}  •  المتبقي: ${_money.format(c.remaining)}  •  ${c.status}'),
                        onTap: () async {
                          await Navigator.push(context,
                              MaterialPageRoute(builder: (_) => ContractDetailsScreen(contractId: c.id)));
                          _load();
                        },
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

/// إنشاء عقد: عميل موجود أو جديد + ضامن أول وثاني + بند المنتج + جدول الأقساط
class ContractFormScreen extends StatefulWidget {
  const ContractFormScreen({super.key});
  @override
  State<ContractFormScreen> createState() => _ContractFormScreenState();
}

class _ContractFormScreenState extends State<ContractFormScreen> {
  final _form = GlobalKey<FormState>();
  Client? _client;
  Guarantor? _g1, _g2;
  final _product = TextEditingController();
  final _total = TextEditingController();
  final _down = TextEditingController(text: '0');
  final _months = TextEditingController(text: '12');
  final _interest = TextEditingController(text: '0');
  double _minDownPct = 20;
  PaymentPlan? _preview;
  String? _error;

  @override
  void initState() {
    super.initState();
    context.read<SettingsRepo>().get('min_down_pct').then((v) {
      if (v != null) setState(() => _minDownPct = double.tryParse(v) ?? 20);
    });
  }

  void _recalc() {
    final total = double.tryParse(normalizeDigits(_total.text)) ?? 0;
    var down = double.tryParse(normalizeDigits(_down.text)) ?? 0;
    final months = int.tryParse(normalizeDigits(_months.text)) ?? 0;
    final interest = double.tryParse(normalizeDigits(_interest.text)) ?? 0;
    setState(() {
      _error = null;
      _preview = null;
      if (total <= 0 || months < 1 || months > 60) {
        if (months != 0 && (months < 1 || months > 60)) _error = 'المدة يجب أن تكون من 1 إلى 60 شهرًا';
        return;
      }
      down = clampDownPayment(total, down);
      _error = validateDownPayment(total: total, downPayment: down, minDownPct: _minDownPct);
      if (_error != null) return;
      _preview = computePlan(
          total: total, downPayment: down, months: months, interestPct: interest, startDate: DateTime.now());
    });
  }

  Future<void> _pickClient() async {
    final repo = context.read<ClientRepo>();
    Future<List<Client>> load() async => (await repo.page(page: 1, pageSize: 100)).rows;
    var rows = await load();
    if (!mounted) return;
    final picked = await showDialog<Client>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => SimpleDialog(
        title: const Text('اختيار عميل'),
        children: [
          SimpleDialogOption(
            onPressed: () async {
              final created = await Navigator.push<bool>(ctx,
                  MaterialPageRoute(builder: (_) => const ClientFormScreen()));
              if (created == true) { rows = await load(); setD(() {}); }
            },
            child: const Row(children: [
              Icon(Icons.person_add, size: 18),
              SizedBox(width: 8),
              Text('عميل جديد', style: TextStyle(fontWeight: FontWeight.bold)),
            ]),
          ),
          ...rows.map((c) => SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, c),
              child: Text('${c.name} — ${c.phone}'))),
        ],
      )),
    );
    if (picked != null) setState(() => _client = picked);
  }

  Future<void> _pickGuarantor(bool first) async {
    final list = await context.read<GuarantorRepo>().all();
    if (!mounted) return;
    final picked = await showDialog<Guarantor>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(first ? 'الضامن الأول' : 'الضامن الثاني'),
        children: list
            .map((g) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, g),
                child: Text('${g.name} — ${g.relation}')))
            .toList(),
      ),
    );
    if (picked != null) setState(() => first ? _g1 = picked : _g2 = picked);
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_client == null) {
      setState(() => _error = 'اختر العميل أولًا');
      return;
    }
    _recalc();
    if (_preview == null) return;
    final repo = context.read<ContractRepo>();
    final shift = await repo.clientHadContractStartingAtCreation(_client!.id);
    final plan = computePlan(
        total: double.parse(normalizeDigits(_total.text)),
        downPayment: clampDownPayment(
            double.parse(normalizeDigits(_total.text)), double.tryParse(normalizeDigits(_down.text)) ?? 0),
        months: int.parse(normalizeDigits(_months.text)),
        interestPct: double.tryParse(normalizeDigits(_interest.text)) ?? 0,
        startDate: DateTime.now(),
        shiftOneMonth: shift);
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final c = Contract(
      id: id,
      clientId: _client!.id,
      clientName: _client!.name,
      guarantor1Id: _g1?.id ?? '',
      guarantor2Id: _g2?.id ?? '',
      product: _product.text.trim(),
      total: double.parse(normalizeDigits(_total.text)),
      downPayment: plan.schedule.isEmpty ? 0 : (double.parse(normalizeDigits(_total.text)) - plan.financed),
      paid: 0,
      monthly: plan.monthly,
      lastInstallment: plan.lastInstallment,
      months: plan.schedule.length,
      interestPct: double.tryParse(normalizeDigits(_interest.text)) ?? 0,
      installments: plan.schedule
          .map((r) => Installment(
              id: '${id}_${r.n}', contractId: id, n: r.n, dueDate: r.dueDate, amount: r.amount))
          .toList(),
    );
    await repo.insertContract(c);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('عقد جديد')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(_client?.name ?? 'اختيار العميل'),
            subtitle: _client == null ? null : Text(_client!.phone),
            trailing: const Icon(Icons.chevron_left),
            onTap: _pickClient,
            shape: RoundedRectangleBorder(
                side: const BorderSide(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: ListTile(
                leading: const Icon(Icons.handshake),
                title: Text(_g1?.name ?? 'الضامن الأول'),
                onTap: () => _pickGuarantor(true),
                shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ListTile(
                leading: const Icon(Icons.handshake),
                title: Text(_g2?.name ?? 'الضامن الثاني'),
                onTap: () => _pickGuarantor(false),
                shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          TextFormField(
              controller: _product,
              decoration: const InputDecoration(labelText: 'المنتج', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'المنتج مطلوب' : null),
          const SizedBox(height: 12),
          TextFormField(
              controller: _total,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'الإجمالي', border: OutlineInputBorder()),
              onChanged: (_) => _recalc(),
              validator: (v) => (double.tryParse(normalizeDigits(v ?? '')) ?? 0) > 0 ? null : 'الإجمالي مطلوب'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextFormField(
                  controller: _down,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: 'المقدم (حد أدنى ${_minDownPct.toStringAsFixed(0)}%)',
                      border: const OutlineInputBorder()),
                  onChanged: (_) => _recalc()),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                  controller: _months,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'المدة (1-60 شهر)', border: OutlineInputBorder()),
                  onChanged: (_) => _recalc()),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                  controller: _interest,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'الفائدة %', border: OutlineInputBorder()),
                  onChanged: (_) => _recalc()),
            ),
          ]),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            ),
          if (_preview != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('القسط الشهري: ${_money.format(_preview!.monthly)}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('القسط الأخير: ${_money.format(_preview!.lastInstallment)} (يساوي المتبقي بالظبط)'),
                  Text('الربح: ${_money.format(_preview!.interestAmount)}'),
                  Text('أول قسط: ${_preview!.schedule.first.dueDate.day}/${_preview!.schedule.first.dueDate.month}/${_preview!.schedule.first.dueDate.year}'),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(icon: const Icon(Icons.save), label: const Text('حفظ العقد'), onPressed: _save),
        ]),
      ),
    );
  }
}

class ContractDetailsScreen extends StatelessWidget {
  final String contractId;
  const ContractDetailsScreen({super.key, required this.contractId});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ContractRepo>();
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل العقد')),
      body: FutureBuilder<Contract?>(
        future: repo.byId(contractId),
        builder: (ctx, snap) {
          final c = snap.data;
          if (c == null) return const Center(child: CircularProgressIndicator());
          return Column(children: [
            ListTile(
              title: Text('${c.clientName} — ${c.product}'),
              subtitle: Text(
                  'الإجمالي: ${_money.format(c.total)}  •  المدفوع: ${_money.format(c.paid)}  •  المتبقي: ${_money.format(c.remaining)}'),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              TextButton.icon(
                icon: const Icon(Icons.print),
                label: const Text('طباعة العقد'),
                onPressed: () async {
                  final clients = context.read<ClientRepo>();
                  final p = await clients.page(page: 1, pageSize: 1, query: c.clientName);
                  if (p.rows.isNotEmpty) {
                    await context
                        .read<ExportService>()
                        .printContract(c, p.rows.first);
                  }
                },
              ),
              TextButton.icon(
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('تسوية آخر قسط'),
                onPressed: () async {
                  await repo.fixLastInstallment(c.id);
                  if (context.mounted) {
                    Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ContractDetailsScreen(contractId: contractId)));
                  }
                },
              ),
            ]),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: c.installments.length,
                itemBuilder: (ctx, i) {
                  final inst = c.installments[i]..refreshStatus();
                  return ListTile(
                    leading: CircleAvatar(child: Text('${inst.n}')),
                    title: Text(
                        '${_money.format(inst.amount)}  —  ${inst.dueDate.day}/${inst.dueDate.month}/${inst.dueDate.year}'),
                    subtitle: Text(
                        'المدفوع: ${_money.format(inst.paidAmount)}  •  ${inst.status}'),
                    trailing: inst.status == 'مدفوع'
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : TextButton(
                            child: const Text('تحصيل'),
                            onPressed: () => _collect(context, c, inst),
                          ),
                  );
                },
              ),
            ),
          ]);
        },
      ),
    );
  }

  Future<void> _collect(BuildContext context, Contract c, Installment inst) async {
    final controller = TextEditingController(text: inst.outstanding.toStringAsFixed(2));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تحصيل القسط ${inst.n}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'المبلغ', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد')),
        ],
      ),
    );
    if (ok == true) {
      final amount = double.tryParse(normalizeDigits(controller.text)) ?? 0;
      if (amount <= 0) return;
      final p = Payment(
          id: '${inst.id}_${DateTime.now().microsecondsSinceEpoch}',
          contractId: c.id,
          installmentId: inst.id,
          amount: amount,
          date: DateTime.now());
      await context.read<PaymentRepo>().recordPayment(c, inst, p);
      if (context.mounted) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => ContractDetailsScreen(contractId: c.id)));
      }
    }
  }
}
