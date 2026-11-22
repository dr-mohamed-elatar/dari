import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// قاعدة البيانات المحلية: كل البيانات على الجهاز، والاستعلامات بترقيم حقيقي
/// (LIMIT/OFFSET على الخادم الداخلي لـ SQLite) فلا تُرسم إلا صفحة واحدة مهما كبر العدد.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    DatabaseFactory factory;
    String path;
    if (kIsWeb) {
      factory = databaseFactoryFfiWeb;
      path = 'dari_web.db';
    } else if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      final dir = await getApplicationDocumentsDirectory();
      factory = databaseFactory;
      path = p.join(dir.path, 'dari.db');
    } else {
      sqfliteFfiInit();
      factory = databaseFactoryFfi;
      path = p.join((await getApplicationDocumentsDirectory()).path, 'dari.db');
    }
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (d, v) async {
          await d.execute('''CREATE TABLE clients(
            id TEXT PRIMARY KEY, name TEXT NOT NULL, national_id TEXT DEFAULT '',
            phone TEXT DEFAULT '', phone2 TEXT DEFAULT '', address TEXT DEFAULT '',
            notes TEXT DEFAULT '', is_sample INTEGER DEFAULT 0, created_at TEXT)''');
          await d.execute('CREATE INDEX idx_clients_name ON clients(name)');
          await d.execute('''CREATE TABLE guarantors(
            id TEXT PRIMARY KEY, name TEXT NOT NULL, national_id TEXT DEFAULT '',
            phone TEXT DEFAULT '', address TEXT DEFAULT '', relation TEXT DEFAULT '',
            is_sample INTEGER DEFAULT 0, created_at TEXT)''');
          await d.execute('''CREATE TABLE contracts(
            id TEXT PRIMARY KEY, client_id TEXT NOT NULL, client_name TEXT NOT NULL,
            guarantor1_id TEXT DEFAULT '', guarantor2_id TEXT DEFAULT '',
            product TEXT DEFAULT '', product_lines TEXT DEFAULT '[]',
            total REAL DEFAULT 0, down_payment REAL DEFAULT 0, paid REAL DEFAULT 0,
            monthly REAL DEFAULT 0, last_installment REAL DEFAULT 0,
            months INTEGER DEFAULT 1, interest_pct REAL DEFAULT 0,
            status TEXT DEFAULT 'نشط', created_at TEXT)''');
          await d.execute('CREATE INDEX idx_contracts_client ON contracts(client_id)');
          await d.execute('''CREATE TABLE installments(
            id TEXT PRIMARY KEY, contract_id TEXT NOT NULL, n INTEGER,
            due_date TEXT, amount REAL, paid_amount REAL DEFAULT 0,
            paid_date TEXT, status TEXT DEFAULT 'قادم')''');
          await d.execute('CREATE INDEX idx_inst_contract ON installments(contract_id)');
          await d.execute('CREATE INDEX idx_inst_due ON installments(due_date)');
          await d.execute('''CREATE TABLE payments(
            id TEXT PRIMARY KEY, contract_id TEXT NOT NULL,
            installment_id TEXT DEFAULT '', amount REAL, date TEXT,
            method TEXT DEFAULT 'كاش', notes TEXT DEFAULT '')''');
          await d.execute('CREATE INDEX idx_pay_contract ON payments(contract_id)');
          await d.execute('''CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT)''');
          await d.execute('''CREATE TABLE licenses(
            key TEXT PRIMARY KEY, value TEXT)''');
        },
      ),
    );
  }
}
