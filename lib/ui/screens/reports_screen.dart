import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../db/repositories.dart' show DbPage, ClientRepo, GuarantorRepo, ContractRepo, PaymentRepo, SettingsRepo;
import '../../services/export_service.dart';

final _money = NumberFormat('#,##0.00', 'ar_EG');

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final contracts = context.read<ContractRepo>();
    final clients = context.read<ClientRepo>();
    final guarantors = context.read<GuarantorRepo>();
    return Scaffold(
      appBar: MediaQuery.of(context).size.width >= 800 ? AppBar(title: const Text('التقارير')) : null,
      body: FutureBuilder<(Map<String, double>, int, int, int)>(
        future: (() async => (
              await contracts.dashboardStats(),
              await clients.count(),
              await guarantors.count(),
              await contracts.count(),
            ))(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final (stats, clientCount, guarantorCount, contractCount) = snap.data!;
          Widget row(String label, String value) => ListTile(
                title: Text(label),
                trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
              );
          return ListView(padding: const EdgeInsets.all(8), children: [
            row('إجمالي العملاء', '$clientCount'),
            row('إجمالي الضامنين', '$guarantorCount'),
            row('إجمالي العقود', '$contractCount'),
            const Divider(),
            row('إجمالي الكاش', _money.format(stats['cashTotal'])),
            row('إجمالي التقسيط', _money.format(stats['installmentsTotal'])),
            row('إجمالي المقدمات', _money.format(stats['downTotal'])),
            row('المتبقي', _money.format(stats['remainingTotal'])),
            row('الربح (الفائدة)', _money.format(stats['profitTotal'])),
            const Divider(),
            row('عقود متأخرة', '${stats['lateContracts']?.toInt() ?? 0}'),
            row('مبالغ المتأخرات', _money.format(stats['lateAmount'])),
            const Divider(),
            FilledButton.icon(
              icon: const Icon(Icons.file_download),
              label: const Text('تصدير Excel (عملاء + عقود)'),
              onPressed: () => context.read<ExportService>().exportExcel(),
            ),
          ]);
        },
      ),
    );
  }
}
