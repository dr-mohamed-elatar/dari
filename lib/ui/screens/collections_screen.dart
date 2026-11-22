import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../db/repositories.dart' show DbPage, ClientRepo, GuarantorRepo, ContractRepo, PaymentRepo, SettingsRepo;
import 'contracts_screen.dart';

final _money = NumberFormat('#,##0.00', 'ar_EG');

/// التحصيل: تسجيل تحصيلات الأقساط ومتابعة المتأخرات
class CollectionsScreen extends StatelessWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MediaQuery.of(context).size.width >= 800 ? AppBar(title: const Text('التحصيل')) : null,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: context.read<ContractRepo>().arrears(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final rows = snap.data!;
          if (rows.isEmpty) return const Center(child: Text('لا توجد متأخرات 🎉'));
          return ListView.builder(
            itemCount: rows.length,
            itemBuilder: (ctx, i) {
              final r = rows[i];
              return ListTile(
                leading: const Icon(Icons.warning, color: Colors.red),
                title: Text(r['client_name'] as String),
                subtitle: Text(
                    'أقساط متأخرة: ${r['late_count']}  •  المبلغ: ${_money.format((r['late_amount'] as num).toDouble())}'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            ContractDetailsScreen(contractId: r['contract_id'] as String))),
              );
            },
          );
        },
      ),
    );
  }
}
