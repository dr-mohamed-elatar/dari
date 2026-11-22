import 'package:flutter/material.dart';

import '../widgets/system_logo.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../db/repositories.dart' show DbPage, ClientRepo, GuarantorRepo, ContractRepo, PaymentRepo, SettingsRepo;

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  static final _money = NumberFormat('#,##0', 'ar_EG');

  @override
  Widget build(BuildContext context) {
    final contracts = context.read<ContractRepo>();
    final clients = context.read<ClientRepo>();
    return Scaffold(
      appBar: MediaQuery.of(context).size.width >= 800 ? AppBar(title: const Text('الرئيسية')) : null,
      body: FutureBuilder<(Map<String, double>, int, int)>(
        future: (() async => (await contracts.dashboardStats(), await clients.count(), await contracts.count()))(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final (stats, clientCount, contractCount) = snap.data!;
          final cards = [
            ('إجمالي العملاء', '$clientCount', Icons.people, Colors.teal),
            ('إجمالي العقود', '$contractCount', Icons.description, Colors.indigo),
            ('إجمالي الكاش', _money.format(stats['cashTotal']), Icons.paid, Colors.green),
            ('إجمالي التقسيط', _money.format(stats['installmentsTotal']), Icons.credit_card, Colors.blue),
            ('إجمالي المقدمات', _money.format(stats['downTotal']), Icons.savings, Colors.orange),
            ('المتبقي', _money.format(stats['remainingTotal']), Icons.hourglass_bottom, Colors.purple),
            ('الربح (الفائدة)', _money.format(stats['profitTotal']), Icons.trending_up, Colors.lightGreen),
            ('عقود متأخرة', '${stats['lateContracts']?.toInt() ?? 0}', Icons.warning, Colors.red),
            ('مبالغ المتأخرات', _money.format(stats['lateAmount']), Icons.money_off, Colors.redAccent),
          ];
          return Column(children: [
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: SystemLogo(size: 56),
            ),
            Expanded(
              child: GridView.count(
            padding: const EdgeInsets.all(16),
            crossAxisCount: MediaQuery.of(context).size.width >= 800 ? 3 : 2,
            childAspectRatio: 1.6,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: cards
                .map((c) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(c.$3, color: c.$4),
                          const Spacer(),
                          Text(c.$2, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text(c.$1, style: const TextStyle(color: Colors.grey)),
                        ]),
                      ),
                    ))
                .toList(),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
