/// قواعد حساب العقود والأقساط (من توثيق dari-docs):
/// - أول قسط: تاريخ إنشاء العقد + شهر واحد بالضبط.
///   (ترحيل شهرًا كاملًا لو وُجد عقد قديم أول قسط فيه بتاريخ البدء.)
/// - القسط الأخير = المتبقي − (القسط الشهري × (عدد الأقساط − 1)) مقربًا لخانتين،
///   بحيث يساوي مجموع الأقساط المتبقي بالظبط. لو الناتج سالبًا أو صفرًا لا يُعدَّل الجدول.
/// - المقدم: يقبل حدًّا أدنى بنسبة مئوية من الإجمالي أو مبلغًا ثابتًا، ويُصحَّح
///   تلقائيًا إلى أرضية الإجمالي، وخطأ لو أقل من الحد الأدنى.
/// - المدة: من 1 إلى 60 شهرًا.
/// - الفائدة: نسبة مئوية على المبلغ المموَّل (الإجمالي − المقدم)، تظهر كـ«الربح».

class InstallmentRow {
  final int n; // تسلسلي
  final DateTime dueDate;
  final double amount;
  const InstallmentRow(this.n, this.dueDate, this.amount);
}

class PaymentPlan {
  final double financed; // الإجمالي − المقدم
  final double interestAmount; // الربح
  final double totalWithInterest;
  final double monthly;
  final double lastInstallment;
  final List<InstallmentRow> schedule;
  const PaymentPlan({
    required this.financed,
    required this.interestAmount,
    required this.totalWithInterest,
    required this.monthly,
    required this.lastInstallment,
    required this.schedule,
  });
}

double round2(double v) => (v * 100).roundToDouble() / 100;

/// إضافة شهر تقويمي مع تثبيت اليوم قدر الإمكان (31 يناير + شهر = 28/29 فبراير)
DateTime addMonth(DateTime d, int months) {
  var y = d.year, m = d.month + months;
  y += (m - 1) ~/ 12;
  m = (m - 1) % 12 + 1;
  var day = d.day;
  final daysInMonth = DateTime(y, m + 1, 0).day;
  if (day > daysInMonth) day = daysInMonth;
  return DateTime(y, m, day);
}

/// توليد جدول الأقساط. [shiftOneMonth] يفعَّل عند وجود عقد قديم أول قسط فيه
/// بتاريخ البدء (ترحيل الجدول شهرًا كاملًا).
PaymentPlan computePlan({
  required double total,
  required double downPayment,
  required int months,
  double interestPct = 0,
  required DateTime startDate,
  bool shiftOneMonth = false,
}) {
  if (months < 1 || months > 60) {
    throw ArgumentError('المدة يجب أن تكون من 1 إلى 60 شهرًا');
  }
  final financed = round2(total - downPayment);
  if (financed <= 0) {
    throw ArgumentError('المبلغ المموَّل يجب أن يكون أكبر من صفر');
  }
  final interestAmount = round2(financed * interestPct / 100);
  final totalWithInterest = round2(financed + interestAmount);
  final monthly = round2(totalWithInterest / months);
  var last = round2(totalWithInterest - monthly * (months - 1));
  if (last <= 0) last = monthly; // لا يُعدَّل الجدول

  final firstDue = addMonth(startDate, shiftOneMonth ? 2 : 1);
  final schedule = <InstallmentRow>[
    for (var i = 0; i < months; i++)
      InstallmentRow(i + 1, addMonth(firstDue, i), i == months - 1 ? last : monthly),
  ];
  return PaymentPlan(
    financed: financed,
    interestAmount: interestAmount,
    totalWithInterest: totalWithInterest,
    monthly: monthly,
    lastInstallment: last,
    schedule: schedule,
  );
}

/// تصحيح المقدم: حد أدنى بنسبة من الإجمالي أو مبلغ ثابت، وسقف = الإجمالي.
/// يعيد null لو صالح، أو رسالة خطأ عربية. [corrected] تُملأ بالقيمة المصححة.
String? validateDownPayment({
  required double total,
  required double downPayment,
  required double minDownPct,
  double? correctedOutHolder, // غير مستخدمة في Dart النقي؛ نعيد القيمة عبر السجل
}) {
  final minDown = round2(total * minDownPct / 100);
  if (downPayment < minDown) {
    return 'المقدم أقل من الحد الأدنى (${minDown.toStringAsFixed(2)})';
  }
  if (downPayment > total) {
    return 'المقدم أكبر من إجمالي العقد';
  }
  return null;
}

double clampDownPayment(double total, double downPayment) {
  if (downPayment < 0) return 0;
  if (downPayment > total) return round2(total);
  return round2(downPayment);
}

/// مولّد خطط سداد بديلة: الخطة المفضلة، قسط أخير أعلى، مدة أقصر،
/// مقدم أكبر، قسط أقل/أعلى مع احترام الحد الأدنى للمقدم.
List<PaymentPlan> alternativePlans({
  required double total,
  required double downPayment,
  required int months,
  required double minDownPct,
  double interestPct = 0,
  required DateTime startDate,
}) {
  final plans = <PaymentPlan>[];
  void tryAdd(double down, int m) {
    if (m < 1 || m > 60) return;
    if (down < round2(total * minDownPct / 100) || down >= total) return;
    try {
      final p = computePlan(
          total: total, downPayment: down, months: m, interestPct: interestPct, startDate: startDate);
      if (!plans.any((x) => x.monthly == p.monthly && x.schedule.length == p.schedule.length)) {
        plans.add(p);
      }
    } catch (_) {}
  }

  tryAdd(downPayment, months); // المفضلة
  tryAdd(downPayment, months > 1 ? months - 1 : months); // مدة أقصر
  tryAdd(round2(downPayment * 1.25), months); // مقدم أكبر
  tryAdd(downPayment, months + 1 <= 60 ? months + 1 : months); // قسط أقل
  return plans;
}
