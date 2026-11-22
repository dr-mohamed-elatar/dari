import 'package:flutter/material.dart';

import '../../db/repositories.dart' show DbPage, ClientRepo, GuarantorRepo, ContractRepo, PaymentRepo, SettingsRepo;

/// شريط ترقيم حقيقي: يجلب صفحة واحدة فقط من قاعدة البيانات في كل مرة
class PagedControls extends StatelessWidget {
  final DbPage<dynamic> page;
  final ValueChanged<int> onPage;
  final ValueChanged<int> onPageSize;
  static const sizes = [15, 25, 50, 100];
  const PagedControls({super.key, required this.page, required this.onPage, required this.onPageSize});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text('الإجمالي: ${page.total}'),
      const Spacer(),
      DropdownButton<int>(
        value: sizes.contains(page.pageSize) ? page.pageSize : 25,
        items: sizes.map((s) => DropdownMenuItem(value: s, child: Text('$s / صفحة'))).toList(),
        onChanged: (v) => onPageSize(v ?? 25),
      ),
      IconButton(
        icon: const Icon(Icons.chevron_right),
        onPressed: page.page > 1 ? () => onPage(page.page - 1) : null,
      ),
      Text('${page.page} / ${page.pageCount}'),
      IconButton(
        icon: const Icon(Icons.chevron_left),
        onPressed: page.page < page.pageCount ? () => onPage(page.page + 1) : null,
      ),
    ]);
  }
}
