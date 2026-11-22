import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../db/repositories.dart';

/// شعار النظام: مخصص مرفوع (base64) أو شعار مدمج من المكتبة أو أيقونة افتراضية.
class SystemLogo extends StatelessWidget {
  final double size;
  const SystemLogo({super.key, this.size = 48});

  static const builtinIcons = {
    'store': Icons.storefront,
    'receipt': Icons.receipt_long,
    'payments': Icons.payments,
    'account_balance': Icons.account_balance,
    'handshake': Icons.handshake,
    'home_work': Icons.home_work,
  };

  @override
  Widget build(BuildContext context) {
    final repo = context.read<SettingsRepo>();
    return FutureBuilder<(String?, String?)>(
      future: (() async => (await repo.get('logo_builtin'), await repo.get('logo_data')))(),
      builder: (ctx, snap) {
        final (builtin, data) = snap.data ?? (null, null);
        if (data != null && data.isNotEmpty) {
          try {
            return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(base64Decode(data), width: size, height: size, fit: BoxFit.contain));
          } catch (_) {}
        }
        final icon = builtinIcons[builtin] ?? Icons.storefront;
        return Icon(icon, size: size, color: Theme.of(context).colorScheme.primary);
      },
    );
  }
}
