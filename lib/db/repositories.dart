import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import '../logic/installment_calculator.dart' show round2;
import '../models/models.dart';
import '../services/crypto_service.dart';
import 'database.dart';

class DbPage<T> {
  final List<T> rows;
  final int total;
  final int page;
  final int pageSize;
  const DbPage(this.rows, this.total, this.page, this.pageSize);
  int get pageCount => total == 0 ? 1 : ((total - 1) ~/ pageSize) + 1;
}

/// العملاء: ترقيم وبحث وفلاتر كلها داخل SQL
class ClientRepo {
  final CryptoService crypto;
  ClientRepo(this.crypto);

  Client _decode(Map<String, dynamic> m) {
    final c = Client.fromMap(m);
    c.nationalId = crypto.decryptText(c.nationalId);
    c.phone = crypto.decryptText(c.phone);
    c.phone2 = crypto.decryptText(c.phone2);
    return c;
  }

  Future<DbPage<Client>> page({
    int page = 1,
    int pageSize = 20,
    String query = '',
    bool hideSamples = true,
    String debtFilter = 'all', // all | overdue | clear
  }) async {
    final d = await AppDatabase.instance.db;
    final where = <String>[];
    final args = <Object?>[];
    if (hideSamples) {
      where.add('is_sample = 0');
    }
    if (query.trim().isNotEmpty) {
      where.add('(name LIKE ? OR national_id LIKE ? OR phone LIKE ?)');
      final q = '%${query.trim()}%';
      // البحث بالهاتف/الرقم القومي يمر على النص المشفر بالتطابق الكامل فقط
      final enc = crypto.encryptText(query.trim());
      where.clear();
      if (hideSamples) where.add('is_sample = 0');
      where.add('(name LIKE ? OR national_id = ? OR phone = ? OR national_id LIKE ?)');
      args.addAll([q, enc, enc, q]);
    }
    if (debtFilter == 'overdue') {
      where.add('''EXISTS (SELECT 1 FROM contracts ct JOIN installments i ON i.contract_id = ct.id
          WHERE ct.client_id = clients.id AND i.status != 'مدفوع' AND i.due_date < ?)''');
      args.add(DateTime.now().toIso8601String().substring(0, 10));
    } else if (debtFilter == 'clear') {
      where.add('''NOT EXISTS (SELECT 1 FROM contracts ct JOIN installments i ON i.contract_id = ct.id
          WHERE ct.client_id = clients.id AND i.status != 'مدفوع' AND i.due_date < ?)''');
      args.add(DateTime.now().toIso8601String().substring(0, 10));
    }
    final w = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final total = (await d.rawQuery('SELECT COUNT(*) c FROM clients $w', args)).first['c'] as int;
    final rows = await d.rawQuery(
        'SELECT * FROM clients $w ORDER BY created_at DESC LIMIT ? OFFSET ?',
        [...args, pageSize, (page - 1) * pageSize]);
    return DbPage(rows.map(_decode).toList(), total, page, pageSize);
  }

  Future<Client?> findDuplicate({String nationalId = '', String phone = ''}) async {
    final d = await AppDatabase.instance.db;
    if (nationalId.isNotEmpty) {
      final enc = crypto.encryptText(nationalId);
      final r = await d.query('clients',
          where: 'national_id = ? AND is_sample = 0', whereArgs: [enc], limit: 1);
      if (r.isNotEmpty) return _decode(r.first);
    }
    if (phone.isNotEmpty) {
      final enc = crypto.encryptText(phone);
      final r = await d.query('clients',
          where: '(phone = ? OR phone2 = ?) AND is_sample = 0', whereArgs: [enc, enc], limit: 1);
      if (r.isNotEmpty) return _decode(r.first);
    }
    return null;
  }

  Future<void> upsert(Client c, {bool encrypt = true}) async {
    final d = await AppDatabase.instance.db;
    final m = c.toMap();
    if (encrypt) {
      m['national_id'] = crypto.encryptText(c.nationalId);
      m['phone'] = crypto.encryptText(c.phone);
      m['phone2'] = crypto.encryptText(c.phone2);
    }
    await d.insert('clients', m, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteMany(List<String> ids) async {
    final d = await AppDatabase.instance.db;
    final batch = d.batch();
    for (final id in ids) {
      batch.delete('clients', where: 'id = ?', whereArgs: [id]);
      batch.delete('contracts', where: 'client_id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  Future<int> count() async =>
      (await (await AppDatabase.instance.db).rawQuery(
              'SELECT COUNT(*) c FROM clients WHERE is_sample = 0'))
          .first['c'] as int;
}

class GuarantorRepo {
  final CryptoService crypto;
  GuarantorRepo(this.crypto);

  Guarantor _decode(Map<String, dynamic> m) {
    final g = Guarantor.fromMap(m);
    g.nationalId = crypto.decryptText(g.nationalId);
    g.phone = crypto.decryptText(g.phone);
    return g;
  }

  Future<DbPage<Guarantor>> page({int page = 1, int pageSize = 20, String query = ''}) async {
    final d = await AppDatabase.instance.db;
    final where = <String>['is_sample = 0', "name NOT LIKE 'ضامن تجريبي%'", "name NOT LIKE 'Guarantor Sample%'"];
    final args = <Object?>[];
    if (query.trim().isNotEmpty) {
      where.add('(name LIKE ? OR national_id = ? OR phone = ?)');
      final enc = crypto.encryptText(query.trim());
      args.addAll(['%${query.trim()}%', enc, enc]);
    }
    final w = 'WHERE ${where.join(' AND ')}';
    final total = (await d.rawQuery('SELECT COUNT(*) c FROM guarantors $w', args)).first['c'] as int;
    final rows = await d.rawQuery(
        'SELECT * FROM guarantors $w ORDER BY created_at DESC LIMIT ? OFFSET ?',
        [...args, pageSize, (page - 1) * pageSize]);
    return DbPage(rows.map(_decode).toList(), total, page, pageSize);
  }

  Future<List<Guarantor>> all({int limit = 500}) async {
    final d = await AppDatabase.instance.db;
    final rows = await d.query('guarantors',
        where: "is_sample = 0 AND name NOT LIKE 'ضامن تجريبي%'",
        orderBy: 'name', limit: limit);
    return rows.map(_decode).toList();
  }

  Future<Guarantor?> findDuplicate({String nationalId = '', String phone = ''}) async {
    final d = await AppDatabase.instance.db;
    if (nationalId.isNotEmpty) {
      final r = await d.query('guarantors',
          where: 'national_id = ? AND is_sample = 0',
          whereArgs: [crypto.encryptText(nationalId)], limit: 1);
      if (r.isNotEmpty) return _decode(r.first);
    }
    if (phone.isNotEmpty) {
      final r = await d.query('guarantors',
          where: 'phone = ? AND is_sample = 0',
          whereArgs: [crypto.encryptText(phone)], limit: 1);
      if (r.isNotEmpty) return _decode(r.first);
    }
    return null;
  }

  Future<void> upsert(Guarantor g, {bool encrypt = true}) async {
    final d = await AppDatabase.instance.db;
    final m = g.toMap();
    if (encrypt) {
      m['national_id'] = crypto.encryptText(g.nationalId);
      m['phone'] = crypto.encryptText(g.phone);
    }
    await d.insert('guarantors', m, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteMany(List<String> ids) async {
    final d = await AppDatabase.instance.db;
    final batch = d.batch();
    for (final id in ids) {
      batch.delete('guarantors', where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  Future<int> count() async =>
      (await (await AppDatabase.instance.db).rawQuery(
              "SELECT COUNT(*) c FROM guarantors WHERE is_sample = 0 AND name NOT LIKE 'ضامن تجريبي%'"))
          .first['c'] as int;
}

class ContractRepo {
  Future<List<Installment>> installmentsOf(String contractId) async {
    final d = await AppDatabase.instance.db;
    final rows = await d.query('installments',
        where: 'contract_id = ?', whereArgs: [contractId], orderBy: 'n');
    return rows.map((m) => Installment.fromMap(m)).toList();
  }

  Future<DbPage<Contract>> page({
    int page = 1,
    int pageSize = 20,
    String query = '',
    String status = '',
  }) async {
    final d = await AppDatabase.instance.db;
    final where = <String>[];
    final args = <Object?>[];
    if (status.isNotEmpty) {
      where.add('status = ?');
      args.add(status);
    }
    if (query.trim().isNotEmpty) {
      where.add('(client_name LIKE ? OR product LIKE ?)');
      args.addAll(['%${query.trim()}%', '%${query.trim()}%']);
    }
    final w = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final total = (await d.rawQuery('SELECT COUNT(*) c FROM contracts $w', args)).first['c'] as int;
    final rows = await d.rawQuery(
        'SELECT * FROM contracts $w ORDER BY created_at DESC LIMIT ? OFFSET ?',
        [...args, pageSize, (page - 1) * pageSize]);
    return DbPage(rows.map((m) => Contract.fromMap(m)).toList(), total, page, pageSize);
  }

  Future<Contract?> byId(String id) async {
    final d = await AppDatabase.instance.db;
    final r = await d.query('contracts', where: 'id = ?', whereArgs: [id], limit: 1);
    if (r.isEmpty) return null;
    final c = Contract.fromMap(r.first);
    c.installments = await installmentsOf(id);
    return c;
  }

  Future<bool> clientHadContractStartingAtCreation(String clientId) async {
    final d = await AppDatabase.instance.db;
    final contracts = await d.query('contracts', where: 'client_id = ?', whereArgs: [clientId]);
    for (final m in contracts) {
      final c = Contract.fromMap(m);
      final inst = await d.query('installments',
          where: 'contract_id = ? AND n = 1', whereArgs: [c.id], limit: 1);
      if (inst.isNotEmpty) {
        final first = Installment.fromMap(inst.first);
        if (first.dueDate.year == c.createdAt.year &&
            first.dueDate.month == c.createdAt.month &&
            first.dueDate.day == c.createdAt.day) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> insertContract(Contract c) async {
    final d = await AppDatabase.instance.db;
    final batch = d.batch();
    batch.insert('contracts', c.toMap());
    for (final i in c.installments) {
      batch.insert('installments', i.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateContract(Contract c) async {
    final d = await AppDatabase.instance.db;
    await d.update('contracts', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
  }

  Future<void> updateInstallment(Installment i) async {
    final d = await AppDatabase.instance.db;
    i.refreshStatus();
    await d.update('installments', i.toMap(), where: 'id = ?', whereArgs: [i.id]);
  }

  /// تعديل آخر قسط تلقائيًا ليساوي المتبقي بالظبط
  Future<void> fixLastInstallment(String contractId) async {
    final d = await AppDatabase.instance.db;
    final c = await byId(contractId);
    if (c == null || c.installments.isEmpty) return;
    final last = c.installments.last;
    final others = c.installments.take(c.installments.length - 1).fold<double>(0, (a, b) => a + b.amount);
    final target = round2(c.totalWithInterest - others);
    if (target > 0 && (target - last.amount).abs() > 0.001) {
      final fixed = Installment(
          id: last.id, contractId: last.contractId, n: last.n, dueDate: last.dueDate,
          amount: target, paidAmount: last.paidAmount, paidDate: last.paidDate, status: last.status);
      await updateInstallment(fixed);
    }
  }

  Future<List<Map<String, dynamic>>> arrears() async {
    final d = await AppDatabase.instance.db;
    final now = DateTime.now().toIso8601String();
    return d.rawQuery('''SELECT c.id contract_id, c.client_name, c.monthly,
        COUNT(i.id) late_count, SUM(i.amount - i.paid_amount) late_amount
        FROM installments i JOIN contracts c ON c.id = i.contract_id
        WHERE i.due_date < ? AND i.paid_amount < i.amount AND c.status = 'نشط'
        GROUP BY c.id ORDER BY late_amount DESC''', [now]);
  }

  Future<Map<String, double>> dashboardStats() async {
    final d = await AppDatabase.instance.db;
    Future<double> sum(String sql, [List<Object?>? a]) async =>
        ((await d.rawQuery(sql, a)).first.values.first as num?)?.toDouble() ?? 0;
    return {
      'cashTotal': await sum("SELECT COALESCE(SUM(down_payment + paid),0) FROM contracts"),
      'installmentsTotal': await sum("SELECT COALESCE(SUM(total * 1),0) FROM contracts WHERE status = 'نشط'"),
      'downTotal': await sum("SELECT COALESCE(SUM(down_payment),0) FROM contracts"),
      'remainingTotal': await sum(
          "SELECT COALESCE(SUM((total - down_payment) * (1 + interest_pct/100.0) - paid),0) FROM contracts WHERE status = 'نشط'"),
      'profitTotal': await sum(
          "SELECT COALESCE(SUM((total - down_payment) * interest_pct/100.0),0) FROM contracts"),
      'lateContracts': await sum(
          "SELECT COALESCE(COUNT(DISTINCT c.id),0) FROM installments i JOIN contracts c ON c.id = i.contract_id WHERE i.due_date < ? AND i.paid_amount < i.amount AND c.status = 'نشط'",
          [DateTime.now().toIso8601String()]),
      'lateAmount': await sum(
          "SELECT COALESCE(SUM(i.amount - i.paid_amount),0) FROM installments i JOIN contracts c ON c.id = i.contract_id WHERE i.due_date < ? AND i.paid_amount < i.amount AND c.status = 'نشط'",
          [DateTime.now().toIso8601String()]),
    };
  }

  Future<int> count() async =>
      (await (await AppDatabase.instance.db).rawQuery('SELECT COUNT(*) c FROM contracts'))
          .first['c'] as int;
}

class PaymentRepo {
  Future<List<Payment>> ofContract(String contractId) async {
    final d = await AppDatabase.instance.db;
    final rows = await d.query('payments',
        where: 'contract_id = ?', whereArgs: [contractId], orderBy: 'date DESC');
    return rows.map((m) => Payment.fromMap(m)).toList();
  }

  Future<void> recordPayment(Contract c, Installment inst, Payment p) async {
    final d = await AppDatabase.instance.db;
    await d.insert('payments', p.toMap());
    inst.paidAmount = round2(inst.paidAmount + p.amount);
    if (inst.paidAmount >= inst.amount - 0.001) inst.paidDate = p.date;
    inst.refreshStatus();
    await d.update('installments', inst.toMap(), where: 'id = ?', whereArgs: [inst.id]);
    c.paid = round2(c.paid + p.amount);
    if (c.remaining <= 0.001) c.status = 'مكتمل';
    await d.update('contracts', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
  }
}

class SettingsRepo {
  Future<String?> get(String key) async {
    final d = await AppDatabase.instance.db;
    final r = await d.query('settings', where: 'key = ?', whereArgs: [key], limit: 1);
    return r.isEmpty ? null : r.first['value'] as String?;
  }

  Future<void> set(String key, String value) async {
    final d = await AppDatabase.instance.db;
    await d.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, String>> all() async {
    final d = await AppDatabase.instance.db;
    final rows = await d.query('settings');
    return {for (final r in rows) r['key'] as String: (r['value'] ?? '') as String};
  }
}
