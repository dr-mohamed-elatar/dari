import 'dart:convert';

class Client {
  final String id;
  String name;
  String nationalId;
  String phone;
  String phone2;
  String address;
  String notes;
  bool isSample;
  DateTime createdAt;

  Client({
    required this.id,
    required this.name,
    this.nationalId = '',
    this.phone = '',
    this.phone2 = '',
    this.address = '',
    this.notes = '',
    this.isSample = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id, 'name': name, 'national_id': nationalId, 'phone': phone,
        'phone2': phone2, 'address': address, 'notes': notes,
        'is_sample': isSample ? 1 : 0, 'created_at': createdAt.toIso8601String(),
      };
  factory Client.fromMap(Map<String, dynamic> m) => Client(
        id: m['id'], name: m['name'] ?? '', nationalId: m['national_id'] ?? '',
        phone: m['phone'] ?? '', phone2: m['phone2'] ?? '', address: m['address'] ?? '',
        notes: m['notes'] ?? '', isSample: (m['is_sample'] ?? 0) == 1,
        createdAt: DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now(),
      );
}

class Guarantor {
  final String id;
  String name;
  String nationalId;
  String phone;
  String address;
  String relation;
  bool isSample;
  DateTime createdAt;

  Guarantor({
    required this.id,
    required this.name,
    this.nationalId = '',
    this.phone = '',
    this.address = '',
    this.relation = '',
    this.isSample = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id, 'name': name, 'national_id': nationalId, 'phone': phone,
        'address': address, 'relation': relation,
        'is_sample': isSample ? 1 : 0, 'created_at': createdAt.toIso8601String(),
      };
  factory Guarantor.fromMap(Map<String, dynamic> m) => Guarantor(
        id: m['id'], name: m['name'] ?? '', nationalId: m['national_id'] ?? '',
        phone: m['phone'] ?? '', address: m['address'] ?? '', relation: m['relation'] ?? '',
        isSample: (m['is_sample'] ?? 0) == 1,
        createdAt: DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now(),
      );
}

class Installment {
  final String id;
  final String contractId;
  final int n;
  final DateTime dueDate;
  final double amount;
  double paidAmount;
  DateTime? paidDate;
  String status; // 'قادم' / 'مدفوع' / 'جزئي' / 'متأخر'

  Installment({
    required this.id,
    required this.contractId,
    required this.n,
    required this.dueDate,
    required this.amount,
    this.paidAmount = 0,
    this.paidDate,
    this.status = 'قادم',
  });

  double get outstanding => (amount - paidAmount) < 0 ? 0 : amount - paidAmount;

  void refreshStatus([DateTime? now]) {
    if (paidAmount >= amount - 0.001) {
      status = 'مدفوع';
    } else if (paidAmount > 0) {
      status = 'جزئي';
    } else {
      status = dueDate.isBefore(now ?? DateTime.now()) ? 'متأخر' : 'قادم';
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id, 'contract_id': contractId, 'n': n,
        'due_date': dueDate.toIso8601String(), 'amount': amount,
        'paid_amount': paidAmount,
        'paid_date': paidDate?.toIso8601String(), 'status': status,
      };
  factory Installment.fromMap(Map<String, dynamic> m) => Installment(
        id: m['id'], contractId: m['contract_id'], n: m['n'],
        dueDate: DateTime.parse(m['due_date']), amount: (m['amount'] as num).toDouble(),
        paidAmount: (m['paid_amount'] as num?)?.toDouble() ?? 0,
        paidDate: m['paid_date'] != null ? DateTime.tryParse(m['paid_date']) : null,
        status: m['status'] ?? 'قادم',
      );
}

class ProductLine {
  String name;
  int qty;
  double price;
  ProductLine(this.name, this.qty, this.price);
  double get total => qty * price;
  Map<String, dynamic> toJson() => {'name': name, 'qty': qty, 'price': price};
  factory ProductLine.fromJson(Map<String, dynamic> m) =>
      ProductLine(m['name'] ?? '', (m['qty'] as num?)?.toInt() ?? 1, (m['price'] as num?)?.toDouble() ?? 0);
}

class Contract {
  final String id;
  String clientId;
  String clientName;
  String guarantor1Id;
  String guarantor2Id;
  String product;
  List<ProductLine> productLines;
  double total;
  double downPayment;
  double paid;
  double monthly;
  double lastInstallment;
  int months;
  double interestPct;
  String status; // 'نشط' / 'مكتمل' / 'متعثر'
  DateTime createdAt;
  List<Installment> installments;

  Contract({
    required this.id,
    required this.clientId,
    required this.clientName,
    this.guarantor1Id = '',
    this.guarantor2Id = '',
    this.product = '',
    List<ProductLine>? productLines,
    required this.total,
    required this.downPayment,
    this.paid = 0,
    required this.monthly,
    required this.lastInstallment,
    required this.months,
    this.interestPct = 0,
    this.status = 'نشط',
    DateTime? createdAt,
    List<Installment>? installments,
  })  : productLines = productLines ?? [],
        createdAt = createdAt ?? DateTime.now(),
        installments = installments ?? [];

  double get financed => total - downPayment;
  double get totalWithInterest => financed * (1 + interestPct / 100);
  double get remaining {
    final r = totalWithInterest - paid;
    return r < 0 ? 0 : r;
  }

  Map<String, dynamic> toMap() => {
        'id': id, 'client_id': clientId, 'client_name': clientName,
        'guarantor1_id': guarantor1Id, 'guarantor2_id': guarantor2Id,
        'product': product,
        'product_lines': jsonEncode(productLines.map((e) => e.toJson()).toList()),
        'total': total, 'down_payment': downPayment, 'paid': paid,
        'monthly': monthly, 'last_installment': lastInstallment, 'months': months,
        'interest_pct': interestPct, 'status': status,
        'created_at': createdAt.toIso8601String(),
      };
  factory Contract.fromMap(Map<String, dynamic> m) => Contract(
        id: m['id'], clientId: m['client_id'], clientName: m['client_name'] ?? '',
        guarantor1Id: m['guarantor1_id'] ?? '', guarantor2Id: m['guarantor2_id'] ?? '',
        product: m['product'] ?? '',
        productLines: (jsonDecode(m['product_lines'] ?? '[]') as List)
            .map((e) => ProductLine.fromJson(e)).toList(),
        total: (m['total'] as num).toDouble(),
        downPayment: (m['down_payment'] as num).toDouble(),
        paid: (m['paid'] as num?)?.toDouble() ?? 0,
        monthly: (m['monthly'] as num).toDouble(),
        lastInstallment: (m['last_installment'] as num?)?.toDouble() ?? 0,
        months: (m['months'] as num).toInt(),
        interestPct: (m['interest_pct'] as num?)?.toDouble() ?? 0,
        status: m['status'] ?? 'نشط',
        createdAt: DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now(),
      );
}

class Payment {
  final String id;
  final String contractId;
  final String installmentId;
  final double amount;
  final DateTime date;
  final String method;
  final String notes;

  const Payment({
    required this.id,
    required this.contractId,
    this.installmentId = '',
    required this.amount,
    required this.date,
    this.method = 'كاش',
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id, 'contract_id': contractId, 'installment_id': installmentId,
        'amount': amount, 'date': date.toIso8601String(), 'method': method, 'notes': notes,
      };
  factory Payment.fromMap(Map<String, dynamic> m) => Payment(
        id: m['id'], contractId: m['contract_id'], installmentId: m['installment_id'] ?? '',
        amount: (m['amount'] as num).toDouble(), date: DateTime.parse(m['date']),
        method: m['method'] ?? 'كاش', notes: m['notes'] ?? '',
      );
}
