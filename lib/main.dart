import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'services/ads_service.dart';

import 'db/database.dart';
import 'db/repositories.dart';
import 'services/backup_service.dart';
import 'services/crypto_service.dart';
import 'services/export_service.dart';
import 'services/license_service.dart';
import 'ui/home_shell.dart';
import 'ui/screens/activation_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdsService.init();
  await AppDatabase.instance.db; // فتح/إنشاء قاعدة البيانات
  final crypto = CryptoService();
  await crypto.init();
  await BackupService().autoBackupIfDue();
  runApp(DariApp(crypto: crypto));
}

class DariApp extends StatelessWidget {
  final CryptoService crypto;
  const DariApp({super.key, required this.crypto});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<CryptoService>.value(value: crypto),
        Provider<ClientRepo>(create: (_) => ClientRepo(crypto)),
        Provider<GuarantorRepo>(create: (_) => GuarantorRepo(crypto)),
        Provider<ContractRepo>(create: (_) => ContractRepo()),
        Provider<PaymentRepo>(create: (_) => PaymentRepo()),
        Provider<SettingsRepo>(create: (_) => SettingsRepo()),
        Provider<ExportService>(create: (_) => ExportService(crypto)),
        Provider<LicenseService>(create: (_) => LicenseService()),
      ],
      child: MaterialApp(
        title: 'نظام التقسيط الذكي',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E6E5C)),
          fontFamilyFallback: const ['Amiri'],
        ),
        home: const _Gate(),
      ),
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate();
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: FutureBuilder(
        future: (() async {
          final lic = context.read<LicenseService>();
          return (await lic.devSecret(), await lic.current());
        })(),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final (secret, current) = snap.data!;
          // لم يضبط المالك سرَّ مطور → وضع شخصي بلا قفل. ضبط السر يفعّل بوابة التفعيل.
          if (secret != null && current == null) return const ActivationScreen();
          return const HomeShell();
        },
      ),
    );
  }
}
